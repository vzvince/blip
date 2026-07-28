// Sources/Blip/AtollPresenter.swift
import Foundation
import AtollExtensionKit

/// Atoll island presenter. State machine: Idle (unread==0) -> Attention (collapsed
/// live-activity, unread>=1) -> Expanded (notch tab). Reloads coalesced at `coalesceNanos`
/// (default 250ms) to respect Atoll rate limits. @MainActor because AtollSession is
/// @MainActor and the presenters push descriptors to it.
@MainActor
public final class AtollPresenter: Presenter {
    public struct State {
        public var activity: Bool = false
        public var tab: Bool = false
        public var unread: Int = 0
        public var rows: [RowViewModel] = []
    }
    private(set) public var state = State()
    public let session: AtollPresenting
    public let port: Int
    private let coalesceNanos: UInt64
    private var pending: (unread: Int, rows: [RowViewModel], conn: ConnectionState)?
    private var coalesceTask: Task<Void, Never>?

    public init(session: AtollPresenting, port: Int, coalesceNanos: UInt64 = 250_000_000) {
        self.session = session; self.port = port; self.coalesceNanos = coalesceNanos
    }

    public func reload(unread: Int, rows: [RowViewModel], connection: ConnectionState) {
        pending = (unread, rows, connection)
        coalesceTask?.cancel()
        let nanos = coalesceNanos
        coalesceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            await self?.applyPending()
        }
    }

    private func applyPending() async {
        guard let p = pending else { return }
        state.unread = p.unread; state.rows = p.rows
        if p.unread > 0 {
            let latest = p.rows.first.map {
                AgentNotification(id: $0.jumpID, source: $0.sourceLabel, title: $0.title, body: $0.body)
            }
            if !state.activity {
                do {
                    try await session.presentActivity(AtollDescriptors.collapsed(unreadCount: p.unread, latest: latest))
                    state.activity = true
                } catch {
                    state.activity = false
                }
            } else {
                do {
                    try await session.updateActivity(AtollDescriptors.collapsed(unreadCount: p.unread, latest: latest))
                } catch {
                    // If Atoll lost the activity or became unavailable, retry with a fresh present later.
                    state.activity = false
                }
            }
            do {
                let tab = AtollDescriptors.tab(rows: p.rows, unreadCount: p.unread, port: port)
                if state.tab {
                    try await session.updateTab(tab)
                } else {
                    try await session.presentTab(tab)
                    state.tab = true
                }
            } catch {
                state.tab = false
            }
        } else {
            if state.activity { try? await session.dismissActivity(); state.activity = false }
            if state.tab { try? await session.dismissTab(); state.tab = false }
        }
    }

    public func clearAll() {
        reload(unread: 0, rows: [], connection: .disconnected)
    }

    /// Clears any surfaces Atoll may have persisted from an earlier Blip process/build.
    /// This intentionally talks to Atoll even when local state is idle because Atoll's
    /// extension managers persist descriptors independently of Blip's in-memory state.
    public func resetRemoteSurfaces() async {
        try? await session.dismissActivity()
        try? await session.dismissTab()
        state.activity = false
        state.tab = false
    }

    public func setExpanded(_ on: Bool) async {
        let wasTab = state.tab
        if on {
            if !state.activity {
                let latest = state.rows.first.map {
                    AgentNotification(id: $0.jumpID, source: $0.sourceLabel, title: $0.title, body: $0.body)
                }
                do {
                    try await session.presentActivity(AtollDescriptors.collapsed(unreadCount: state.unread, latest: latest))
                    state.activity = true
                } catch {
                    state.activity = false
                    state.tab = false
                    return
                }
            }
            do {
                try await session.presentTab(AtollDescriptors.tab(rows: state.rows, unreadCount: state.unread, port: port))
                state.tab = true
            } catch {
                state.tab = false
            }
        } else {
            if wasTab { try? await session.dismissTab() }
            state.tab = false
        }
    }
}
