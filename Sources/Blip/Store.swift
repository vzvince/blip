// Sources/Blip/Store.swift
import Foundation

public final class Store: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: AgentNotification] = [:]
    private let capacity: Int
    public var onChange: ((ConnectionState) -> Void)?

    public init(capacity: Int = 200) { self.capacity = capacity }

    public func upsert(_ n: AgentNotification) {
        lock.lock(); defer { lock.unlock() }
        items[n.id] = n
        trimLocked()
        onChange?(.connected)
    }

    public func markRead(id: String) {
        lock.lock(); defer { lock.unlock() }
        // no-op read flag; see markGroupRead
        onChange?(.connected)
    }

    public func markGroupRead(key collapseKey: String) {
        lock.lock(); defer { lock.unlock() }
        for id in items.keys where items[id]?.collapseKey == collapseKey {
            items.removeValue(forKey: id)
        }
        onChange?(.connected)
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        items.removeAll()
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
}
