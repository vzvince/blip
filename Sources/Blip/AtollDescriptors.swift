// Sources/Blip/AtollDescriptors.swift
import Foundation
import AtollExtensionKit

public enum AtollDescriptors {
    public static let activityID = "blip.inbox"
    public static let tabID = "blip.inbox.tab"

    public static func collapsed(unreadCount: Int, latest: AgentNotification?) -> AtollLiveActivityDescriptor {
        AtollLiveActivityDescriptor(
            id: activityID,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "dev.blip",
            priority: latest?.priority == .high ? .high : .normal,
            title: "Blip",
            subtitle: latest.map { "\($0.sourceLabel) · \($0.title)" },
            leadingIcon: .symbol(name: "bell.badge.fill"),
            trailingContent: .marquee(unreadCount > 0 ? "Blip \(unreadCount)" : "Blip"),
            accentColor: .accent,
            badgeIcon: nil,
            allowsMusicCoexistence: true,
            centerTextStyle: .inheritUser,
            sneakPeekConfig: .standard(duration: 3.0),
            sneakPeekTitle: latest?.title,
            sneakPeekSubtitle: latest?.subtitle
        )
    }

    public static func tab(rows: [RowViewModel], unreadCount: Int, port: Int) -> AtollNotchExperienceDescriptor {
        AtollNotchExperienceDescriptor(
            id: tabID,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "dev.blip",
            priority: .normal,
            accentColor: .accent,
            tab: .init(
                title: "Blip",
                iconSymbolName: "bell.badge.fill",
                badgeIcon: nil,
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
