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
            trailingContent: .none,
            accentColor: .accent,
            badgeIcon: nil,
            allowsMusicCoexistence: true,
            centerTextStyle: .inheritUser,
            sneakPeekConfig: AtollSneakPeekConfig(enabled: false, duration: nil, style: nil, showOnUpdate: false),
            sneakPeekTitle: nil,
            sneakPeekSubtitle: nil
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
                sections: nativeSections(rows: rows, unreadCount: unreadCount, port: port),
                webContent: nil,
                allowWebInteraction: true,
                footnote: rows.isEmpty ? "Blip is running in the menu bar" : nil
            ),
            minimalistic: nil,
            durationHint: nil
        )
    }

    private static func interactiveInbox(rows: [RowViewModel], unreadCount: Int, port: Int) -> AtollWidgetWebContentDescriptor {
        AtollWidgetWebContentDescriptor(
            html: InboxHTMLRenderer.render(rows: rows, unreadCount: unreadCount, port: port, includeHeader: false, compact: true),
            preferredHeight: rows.isEmpty ? 120 : 86,
            isTransparent: true,
            allowLocalhostRequests: true,
            maximumContentWidth: 640
        )
    }

    private static func nativeSections(rows: [RowViewModel], unreadCount: Int, port: Int) -> [AtollNotchContentSection] {
        var elements: [AtollWidgetContentElement]

        if rows.isEmpty {
            elements = [
                .text("All clear — no pending notifications", font: .system(size: 12, weight: .regular), color: .gray)
            ]
        } else {
            elements = [
                .webView(interactiveInbox(rows: rows, unreadCount: unreadCount, port: port))
            ]
        }

        return [
            AtollNotchContentSection(
                id: "blip.native.inbox",
                title: rows.isEmpty ? "All clear" : nil,
                subtitle: nil,
                layout: .stack,
                elements: elements
            )
        ]
    }
}
