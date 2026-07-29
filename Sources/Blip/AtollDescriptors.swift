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
                webContent: rows.isEmpty ? nil : interactiveInbox(rows: rows, unreadCount: unreadCount, port: port),
                allowWebInteraction: true,
                footnote: rows.isEmpty ? "Blip is running in the menu bar" : nil
            ),
            minimalistic: nil,
            durationHint: nil
        )
    }

    private static func interactiveInbox(rows: [RowViewModel], unreadCount: Int, port: Int) -> AtollWidgetWebContentDescriptor {
        let preferredHeight: Double
        if rows.isEmpty {
            preferredHeight = 120
        } else {
            // Use top-level TabConfiguration.webContent for interaction. Inline
            // section webViews are embedded in Atoll's padded card slot, which is
            // clipped and does not reliably scroll. Top-level content can occupy
            // enough of the expanded tab to show complete rows.
            preferredHeight = 220
        }
        return AtollWidgetWebContentDescriptor(
            html: InboxHTMLRenderer.render(rows: rows, unreadCount: unreadCount, port: port, includeHeader: false, compact: true),
            preferredHeight: preferredHeight,
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
            return [
                AtollNotchContentSection(
                    id: "blip.native.inbox",
                    title: "All clear",
                    subtitle: nil,
                    layout: .stack,
                    elements: elements
                )
            ]
        }

        // Non-empty inbox content must live in tab.webContent. Section webViews are
        // clipped inside Atoll's card renderer, producing a non-scrollable half-row.
        return []
    }
}
