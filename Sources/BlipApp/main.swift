// Sources/BlipApp/main.swift
import SwiftUI
import AppKit
import Darwin
import Blip
import AtollExtensionKit

@main
struct BlipApp: App {
    @StateObject private var engine = BlipEngine()
    init() {
        // Unbuffered stdout/stderr so background/redirected runs (file logs, launchd) stream prints.
        setvbuf(stdout, nil, _IONBF, 0)
        setvbuf(stderr, nil, _IONBF, 0)
    }
    var body: some Scene {
        MenuBarExtra {
            Text(engine.status.title)
                .font(.headline)
            Text(engine.status.atollLine)
            Text(engine.status.cmuxLine)
                .font(.caption)
            Divider()
            Button("Send Test Notification") { engine.sendTestNotification() }
            Button("Show in Atoll") { engine.showInAtoll() }
            Button("Hide from Atoll") { engine.hideFromAtoll() }
            Button("Clear All") { engine.clearAll() }
                .disabled(engine.unreadCount == 0)
            Divider()
            Button("Quit Blip") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Label(engine.status.title, systemImage: engine.status.systemImage)
        }
        Settings { EmptyView() }
    }
}

/// Adapter using Atoll's current JSON-RPC WebSocket extension transport.
/// Atoll 2.3.x exposes localhost:9020 for extensions; its legacy XPC mach service may
/// not be registered even while the app is running.
@MainActor
final class AtollRPCSessionAdapter: AtollPresenting {
    let client = AtollRPCClient()

    private func guardAtollRunning() throws {
        guard AtollSession.shared.isAtollInstalled && AtollSession.shared.isAtollRunning else {
            throw AtollAvailabilityError.notRunning
        }
    }

    func requestAuthorization() async throws -> Bool { try guardAtollRunning(); return try await client.requestAuthorization() }
    func checkAuthorization() async throws -> Bool { try guardAtollRunning(); return try await client.checkAuthorization() }
    func presentActivity(_ d: AtollLiveActivityDescriptor) async throws { try guardAtollRunning(); try await client.presentActivity(d) }
    func updateActivity(_ d: AtollLiveActivityDescriptor) async throws { try guardAtollRunning(); try await client.updateActivity(d) }
    func dismissActivity() async throws { try guardAtollRunning(); try await client.dismissActivity(activityID: AtollDescriptors.activityID) }
    func presentTab(_ d: AtollNotchExperienceDescriptor) async throws { try guardAtollRunning(); try await client.presentTab(d) }
    func updateTab(_ d: AtollNotchExperienceDescriptor) async throws { try guardAtollRunning(); try await client.updateTab(d) }
    func dismissTab() async throws { try guardAtollRunning(); try await client.dismissTab(experienceID: AtollDescriptors.tabID) }
}

@MainActor
final class BlipEngine: ObservableObject {
    @Published private(set) var unreadCount: Int = 0

    private let store = Store()
    private let cmux: CmuxRPC
    private let jump: CmuxJumpExecutor
    private let action: ActionHandler
    private let ingress: IngressServer
    private let presenter: AtollPresenter
    private var poll: Task<Void, Never>?
    private var config: BlipConfig

    var status: MenuBarStatus {
        MenuBarStatus(unreadCount: unreadCount,
                      atollInstalled: AtollSession.shared.isAtollInstalled,
                      atollRunning: AtollSession.shared.isAtollRunning,
                      cmuxSocket: config.cmuxSocket)
    }

    init() {
        let cfg = BlipConfig.load(); self.config = cfg
        let cmux = CmuxRPC(socketPath: cfg.cmuxSocket); self.cmux = cmux
        let jump = CmuxJumpExecutor(rpc: cmux); self.jump = jump
        let action = ActionHandler(store: store, jump: jump); self.action = action
        let ingress = IngressServer(port: cfg.port, store: store, action: action); self.ingress = ingress
        let atollAdapter = AtollRPCSessionAdapter()
        let presenter = AtollPresenter(session: atollAdapter, port: cfg.port); self.presenter = presenter
        store.onChange = { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let unread = self.store.unreadCount
                self.unreadCount = unread
                self.presenter.reload(unread: unread, rows: self.store.rows(), connection: .connected)
            }
        }
        try? ingress.start()
        print("blip: up — ingress http://127.0.0.1:\(cfg.port) | cmux socket: \(cfg.cmuxSocket) | Atoll installed: \(AtollSession.shared.isAtollInstalled) | Atoll running: \(AtollSession.shared.isAtollRunning)")
        Task { @MainActor in
            do {
                let ok = try await atollAdapter.requestAuthorization()
                print("blip: Atoll RPC authorized=\(ok)")
                await presenter.resetRemoteSurfaces()
                presenter.reload(unread: store.unreadCount, rows: store.rows(), connection: .connected)
            } catch {
                print("blip: Atoll RPC authorization failed — \(error)")
            }
        }
        startPolling()
    }

    func sendTestNotification() {
        store.upsert(AgentNotification(id: "menu-test:\(Date().timeIntervalSince1970)",
                                       source: "blip",
                                       title: "Blip is running",
                                       body: "Opened from the menu bar",
                                       sourceLabel: "Blip"))
        showInAtoll(after: 350_000_000)
    }

    func showInAtoll() { showInAtoll(after: 0) }

    func hideFromAtoll() {
        Task { @MainActor in await presenter.setExpanded(false) }
    }

    func clearAll() { action.clearAll() }

    private func showInAtoll(after delayNanos: UInt64) {
        Task { @MainActor in
            if delayNanos > 0 { try? await Task.sleep(nanoseconds: delayNanos) }
            await presenter.setExpanded(true)
        }
    }

    private func startPolling() {
        poll = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollOnce()
                try? await Task.sleep(nanoseconds: UInt64((self?.config.pollIntervalSeconds ?? 1.5) * 1_000_000_000))
            }
        }
    }
    private func pollOnce() async {
        guard config.sources.contains("cmux") else { return }
        // notification.list returns a BARE top-level JSON ARRAY — CmuxRPC.call expects [String:Any]
        // and throws .badResponse on it. So we send the frame and recv the raw bytes ourselves,
        // parse [Any], wrap as ["array": items], then map.
        do {
            let frame = CmuxFrames.encode(id: "list", method: "notification.list", params: [:])
            let raw = try cmux.recvRaw(frame: frame)
            let items = (try? JSONSerialization.jsonObject(with: raw, options: [.allowFragments]) as? [Any]) ?? []
            let wrapped: [String:Any] = ["array": items]
            for n in CmuxMapper.mapList(wrapped) { store.upsert(n) }
        } catch {
            // socket absent / not allowAll / parse issue — log once per poll cycle (≤1/sec)
            print("blip: cmux poll failed: \(error) — ensure CMUX_SOCKET_MODE=allowAll and cmux running; generic push via `blip push` still works")
        }
    }
}
