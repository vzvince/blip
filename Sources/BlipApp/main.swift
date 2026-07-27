// Sources/BlipApp/main.swift
import SwiftUI
import Blip
import AtollExtensionKit

@main
struct BlipApp: App {
    @StateObject private var engine = BlipEngine()
    var body: some Scene { Settings { EmptyView() } }
}

/// Adapter making AtollSession (@MainActor) satisfy AtollPresenting.
@MainActor
final class AtollSessionAdapter: AtollPresenting {
    func presentActivity(_ d: AtollLiveActivityDescriptor) async throws { try await AtollSession.shared.presentActivity(d) }
    func updateActivity(_ d: AtollLiveActivityDescriptor) async throws { try await AtollSession.shared.updateActivity(d) }
    func dismissActivity() async throws { try await AtollSession.shared.dismissActivity() }
    func presentTab(_ d: AtollNotchExperienceDescriptor) async throws { try await AtollSession.shared.presentTab(d) }
    func updateTab(_ d: AtollNotchExperienceDescriptor) async throws { try await AtollSession.shared.updateTab(d) }
    func dismissTab() async throws { try await AtollSession.shared.dismissTab() }
}

@MainActor
final class BlipEngine: ObservableObject {
    private let store = Store()
    private let cmux: CmuxRPC
    private let jump: CmuxJumpExecutor
    private let action: ActionHandler
    private let ingress: IngressServer
    private let presenter: AtollPresenter
    private var poll: Task<Void, Never>?
    private var config: BlipConfig

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
                self.presenter.reload(unread: self.store.unreadCount, rows: self.store.rows(), connection: .connected)
            }
        }
        try? ingress.start()
        print("blip: up — ingress http://127.0.0.1:\(cfg.port) | cmux socket: \(cfg.cmuxSocket) | Atoll installed: \(AtollSession.shared.isAtollInstalled)")
        Task { @MainActor in
            let ok = (try? await AtollSession.shared.requestAuthorization()) ?? false
            print("blip: Atoll authorized=\(ok)" + (ok ? "" : " — open Atoll → Settings → Extensions → authorize Blip, enable 'extension notch experiences' + 'show extension tabs'"))
            AtollSession.shared.registerDismiss()
        }
        startPolling()
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
