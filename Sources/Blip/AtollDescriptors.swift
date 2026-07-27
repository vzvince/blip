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
                preferredHeight: 360,
                sections: [],
                webContent: AtollWidgetWebContentDescriptor(
                    html: InboxHTMLRenderer.render(rows: rows, unreadCount: unreadCount, port: port),
                    preferredHeight: 340,
                    isTransparent: true,
                    allowLocalhostRequests: true,
                    backgroundColor: nil,
                    maximumContentWidth: 420
                ),
                allowWebInteraction: true,
                footnote: "Clear all"
            ),
            minimalistic: nil,
            durationHint: nil
        )
    }
}
