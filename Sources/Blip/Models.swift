// Sources/Blip/Models.swift
import Foundation

public enum Priority: String, Codable, Sendable, Hashable {
    case normal, high
}

public enum JumpTarget: Codable, Sendable, Hashable {
    case cmuxSurface(workspaceId: String, surfaceId: String)
    case openApp(bundleId: String)
    case none
}

public enum ConnectionState: Sendable, Equatable {
    case connected, disconnected
}

public struct AgentNotification: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let source: String
    public let title: String
    public let subtitle: String
    public let body: String
    public let createdAt: Date
    public let priority: Priority
    public let jump: JumpTarget
    public let sourceLabel: String

    public init(id: String, source: String, title: String, subtitle: String = "",
                body: String = "", createdAt: Date = Date(), priority: Priority = .normal,
                jump: JumpTarget = .none, sourceLabel: String? = nil) {
        self.id = id
        self.source = source
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.createdAt = createdAt
        self.priority = priority
        self.jump = jump
        self.sourceLabel = sourceLabel ?? source
    }

    /// Group key used to collapse repeats from the same surface/source into one inbox row.
    public var collapseKey: String {
        switch jump {
        case .cmuxSurface(_, let s): return "cmux:\(s)"
        default: return "src:\(source)"
        }
    }
}

public struct RowViewModel: Hashable, Sendable {
    public let id: String              // = collapseKey
    public let sourceLabel: String
    public let title: String
    public let subtitle: String
    public let body: String           // latest body in the group
    public let unreadCount: Int
    public let isPriority: Bool
    public let jumpID: String         // id of the newest unread item in this group
}
