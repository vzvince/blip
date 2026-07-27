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
                try? await session.presentActivity(AtollDescriptors.collapsed(unreadCount: p.unread, latest: latest))
                state.activity = true
            } else {
                try? await session.updateActivity(AtollDescriptors.collapsed(unreadCount: p.unread, latest: latest))
            }
            if state.tab {
                try? await session.updateTab(AtollDescriptors.tab(rows: p.rows, unreadCount: p.unread, port: port))
            }
        } else {
            if state.activity { try? await session.dismissActivity(); state.activity = false }
            if state.tab { try? await session.dismissTab(); state.tab = false }
        }
    }

    public func clearAll() {
        reload(unread: 0, rows: [], connection: .disconnected)
    }

    public func setExpanded(_ on: Bool) async {
        state.tab = on
        if on {
            if !state.activity {
                try? await session.presentActivity(AtollDescriptors.collapsed(unreadCount: state.unread, latest: nil))
                state.activity = true
            }
            try? await session.presentTab(AtollDescriptors.tab(rows: state.rows, unreadCount: state.unread, port: port))
        } else {
            if state.tab { try? await session.dismissTab() }
        }
    }
}
