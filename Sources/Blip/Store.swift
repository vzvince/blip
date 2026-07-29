// Sources/Blip/Store.swift
import Foundation

public final class Store: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: AgentNotification] = [:]
    private var suppressedIDs: Set<String> = []
    private let capacity: Int
    public var onChange: ((ConnectionState) -> Void)?

    public init(capacity: Int = 200) { self.capacity = capacity }

    public func upsert(_ n: AgentNotification) {
        lock.lock(); defer { lock.unlock() }
        guard !suppressedIDs.contains(n.id) else { return }
        items[n.id] = n
        trimLocked()
        onChange?(.connected)
    }

    public func markRead(id: String) {
        lock.lock(); defer { lock.unlock() }
        if items.removeValue(forKey: id) != nil {
            suppressedIDs.insert(id)
            trimSuppressedLocked()
        }
        onChange?(.connected)
    }

    public func markGroupRead(key collapseKey: String) {
        lock.lock(); defer { lock.unlock() }
        for id in Array(items.keys) where items[id]?.collapseKey == collapseKey {
            suppressedIDs.insert(id)
            items.removeValue(forKey: id)
        }
        trimSuppressedLocked()
        onChange?(.connected)
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        suppressedIDs.formUnion(items.keys)
        items.removeAll()
        trimSuppressedLocked()
        onChange?(.disconnected)
    }

    public var unreadCount: Int {
        lock.lock(); defer { lock.unlock() }
        return items.count
    }

    /// Oldest-first snapshot (most recent first).
    public func snapshot() -> [AgentNotification] {
        lock.lock(); defer { lock.unlock() }
        return items.values.sorted { $0.createdAt > $1.createdAt }
    }

    /// Individual unread notifications, newest first. This is used for compact
    /// Atoll inbox rendering so repeated messages from one cmux surface remain
    /// visible as separate rows instead of collapsing behind a count badge.
    public func notificationRows() -> [RowViewModel] {
        lock.lock(); defer { lock.unlock() }
        return items.values.sorted { $0.createdAt > $1.createdAt }.map { n in
            RowViewModel(id: n.id, sourceLabel: n.sourceLabel, title: n.title,
                         subtitle: n.subtitle, body: n.body, unreadCount: 1,
                         isPriority: n.priority == .high, jumpID: n.id)
        }
    }

    /// Collapsed unread rows, highest-priority then newest first.
    public func rows() -> [RowViewModel] {
        lock.lock(); defer { lock.unlock() }
        var groups: [String: [AgentNotification]] = [:]
        for n in items.values {
            groups[n.collapseKey, default: []].append(n)
        }
        func newest(_ g: [AgentNotification]) -> AgentNotification {
            g.sorted { $0.createdAt > $1.createdAt }.first!
        }
        let rows = groups.map { (k, g) -> RowViewModel in
            let top = newest(g)
            return RowViewModel(id: k, sourceLabel: top.sourceLabel, title: top.title,
                                subtitle: top.subtitle, body: top.body, unreadCount: g.count,
                                isPriority: g.contains { $0.priority == .high },
                                jumpID: top.id)
        }
        return rows.sorted {
            if $0.isPriority != $1.isPriority { return $0.isPriority }
            return newest(groups[$0.id]!).createdAt > newest(groups[$1.id]!).createdAt
        }
    }

    private func trimLocked() {
        while items.count > capacity {
            let oldest = items.values.min(by: { $0.createdAt < $1.createdAt })!
            items.removeValue(forKey: oldest.id)
        }
    }

    private func trimSuppressedLocked() {
        while suppressedIDs.count > capacity {
            suppressedIDs.remove(suppressedIDs.first!)
        }
    }
}
