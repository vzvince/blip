// Sources/Blip/AtollDescriptors.swift
import Foundation
import AtollExtensionKit

public enum AtollDescriptors {
    public static let activityID = "blip.inbox"
    public static let tabID = "blip.inbox.tab"

    private static var bundleIdentifier: String { Bundle.main.bundleIdentifier ?? "dev.blip" }
    private static var appIcon: AtollIconDescriptor {
        .appIcon(bundleIdentifier: bundleIdentifier, size: CGSize(width: 22, height: 22), cornerRadius: 6)
    }

    public static func collapsed(unreadCount: Int, latest: AgentNotification?) -> AtollLiveActivityDescriptor {
        AtollLiveActivityDescriptor(
            id: activityID,
            bundleIdentifier: bundleIdentifier,
            priority: latest?.priority == .high ? .high : .normal,
            title: "Blip",
            subtitle: latest.map { "\($0.sourceLabel) · \($0.title)" },
            leadingIcon: appIcon,
            trailingContent: .marquee(unreadCount > 0 ? "Blip \(unreadCount)" : "Blip"),
            accentColor: .accent,
            badgeIcon: nil,
            allowsMusicCoexistence: true,
            centerTextStyle: .inheritUser,
            sneakPeekConfig: AtollSneakPeekConfig(enabled: true, duration: 6.0, style: .standard, showOnUpdate: true),
            sneakPeekTitle: latest?.title,
            sneakPeekSubtitle: latest?.subtitle
        )
    }

    public static func tab(rows: [RowViewModel], unreadCount: Int, port: Int) -> AtollNotchExperienceDescriptor {
        AtollNotchExperienceDescriptor(
            id: tabID,
            bundleIdentifier: bundleIdentifier,
            priority: .normal,
            accentColor: .accent,
            tab: .init(
                title: "Blip",
                iconSymbolName: "bell.badge.fill",
                badgeIcon: appIcon,
                preferredHeight: 420,
                sections: nativeSections(rows: rows, unreadCount: unreadCount),
                webContent: nil,
                allowWebInteraction: false,
                footnote: rows.isEmpty ? "Blip is running in the menu bar" : "Use Blip in the menu bar to jump or clear"
            ),
            minimalistic: nil,
            durationHint: nil
        )
    }

    private static func nativeSections(rows: [RowViewModel], unreadCount: Int) -> [AtollNotchContentSection] {
        let header = unreadCount > 0 ? "Blip · \(unreadCount) unread" : "Blip"
        var elements: [AtollWidgetContentElement] = [
            .text(header, font: .system(size: 13, weight: .semibold), color: .white),
            .divider(color: .gray, thickness: 0.5)
        ]

        if rows.isEmpty {
            elements.append(.text("All clear — no pending notifications", font: .system(size: 12, weight: .regular), color: .gray))
        } else {
            elements.append(contentsOf: rows.prefix(3).map { row in
                let prefix = row.isPriority ? "⚠︎ " : ""
                let summary = "\(prefix)\(row.sourceLabel): \(row.title) — \(row.body)"
                return .text(summary.truncatedForAtoll(maxLength: 140),
                             font: .system(size: 12, weight: row.isPriority ? .semibold : .regular),
                             color: row.isPriority ? .orange : .white)
            })
        }

        return [
            AtollNotchContentSection(
                id: "blip.native.inbox",
                title: rows.isEmpty ? "All clear" : "Latest notifications",
                subtitle: rows.isEmpty ? "Blip is listening in the menu bar." : "Open Blip from the menu bar for actions.",
                layout: .stack,
                elements: elements
            )
        ]
    }
}

private extension String {
    func truncatedForAtoll(maxLength: Int) -> String {
        guard count > maxLength else { return self }
        let end = index(startIndex, offsetBy: max(0, maxLength - 1))
        return String(self[..<end]) + "…"
    }
}
