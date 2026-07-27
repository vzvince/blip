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

/// Adapter making AtollSession (@MainActor) satisfy AtollPresenting.
@MainActor
final class AtollSessionAdapter: AtollPresenting {
    private func guardXPC() throws {
        guard AtollSession.shared.shouldContactXPC else { throw AtollAvailabilityError.notRunning }
    }
    func presentActivity(_ d: AtollLiveActivityDescriptor) async throws { try guardXPC(); try await AtollSession.shared.presentActivity(d) }
    func updateActivity(_ d: AtollLiveActivityDescriptor) async throws { try guardXPC(); try await AtollSession.shared.updateActivity(d) }
    func dismissActivity() async throws { try guardXPC(); try await AtollSession.shared.dismissActivity() }
    func presentTab(_ d: AtollNotchExperienceDescriptor) async throws { try guardXPC(); try await AtollSession.shared.presentTab(d) }
    func updateTab(_ d: AtollNotchExperienceDescriptor) async throws { try guardXPC(); try await AtollSession.shared.updateTab(d) }
    func dismissTab() async throws { try guardXPC(); try await AtollSession.shared.dismissTab() }
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
        let presenter = AtollPresenter(session: AtollSessionAdapter(), port: cfg.port); self.presenter = presenter
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
            guard AtollSession.shared.shouldContactXPC else {
                print("blip: Atoll authorization skipped — Atoll is installed but not running, or unavailable. Start Atoll and re-launch Blip after enabling third-party extensions.")
                return
            }
            // AtollExtensionKit's requestAuthorization() leaks its continuation if the extension
            // XPC isn't reachable (e.g. Atoll's "Enable third-party extensions" toggle is off).
            // Race it with a 5s timeout so the engine never hangs; the SDK's cosmetic leak is
            // unavoidable but the app stays responsive + we get a clean "not authorized" log.
            let ok: Bool = await withTaskGroup(of: Bool?.self) { group in
                group.addTask { try? await AtollSession.shared.requestAuthorization() }
                group.addTask { try? await Task.sleep(nanoseconds: 5_000_000_000); return nil }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first ?? false
            }
            print("blip: Atoll authorized=\(ok)" + (ok ? "" : " — Atoll running, but extension XPC unreachable. Enable in Atoll → Settings → Extensions: 'Enable third-party extensions' + 'Allow extension notch experiences' + 'Show extension tabs', then re-launch Blip."))
            if ok { AtollSession.shared.registerDismiss() }
        }
        startPolling()
    }

    func sendTestNotification() {
        store.upsert(AgentNotification(id: "menu-test:\(Date().timeIntervalSince1970)",
                                       source: "blip",
                                       title: "Blip is running",
                                       body: "Opened from the menu bar",
                                       sourceLabel: "Blip"))
    }

    func clearAll() { action.clearAll() }

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
