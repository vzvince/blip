import XCTest
@testable import Blip
import AtollExtensionKit
final class AtollDescriptorsTests: XCTestCase {
    func testCollapsedIndicatorIsValid() {
        let d = AtollDescriptors.collapsed(unreadCount: 3,
            latest: AgentNotification(id:"n", source:"cmux", title:"Codex", body:"input",
                jump: .cmuxSurface(workspaceId:"w", surfaceId:"s")))
        XCTAssertTrue(d.isValid, "collapsed descriptor failed validation")
    }
    func testCollapsedIndicatorNotHighPriorityWhenLatestIsNormal() {
        let d = AtollDescriptors.collapsed(unreadCount: 1,
            latest: AgentNotification(id:"n", source:"cmux", title:"T", body:"b"))
        XCTAssertEqual(d.priority, .normal)
    }
    func testCollapsedIndicatorHighPriorityWhenLatestHigh() {
        let d = AtollDescriptors.collapsed(unreadCount: 1,
            latest: AgentNotification(id:"n", source:"cmux", title:"T", body:"b", priority: .high))
        XCTAssertEqual(d.priority, .high)
    }

    func testCollapsedIndicatorDoesNotRenderDotBadge() {
        let d = AtollDescriptors.collapsed(unreadCount: 3,
            latest: AgentNotification(id:"n", source:"cmux", title:"Codex", body:"input"))
        XCTAssertNil(d.badgeIcon, "collapsed island should not render Blip as a standalone white dot")
    }


    func testCollapsedIndicatorHasNoTrailingWingToAvoidWhiteSquareArtifact() {
        let d = AtollDescriptors.collapsed(unreadCount: 1,
            latest: AgentNotification(id:"n", source:"cmux", title:"Codex", body:"input"))

        switch d.trailingContent {
        case .none:
            break
        default:
            XCTFail("collapsed island should only show the Blip app icon; Atoll clips trailing text into a white square artifact")
        }
    }



    func testTabInteractiveInboxUsesTopLevelWebContentNotClippedSectionWebView() {
        let rows = [RowViewModel(id:"n1", sourceLabel:"Codex", title:"Needs input", subtitle:"1m ago",
                                 body:"Please review", unreadCount: 2, isPriority: false, jumpID: "n1")]
        let d = AtollDescriptors.tab(rows: rows, unreadCount: 2, port: 9042)

        guard let webContent = d.tab?.webContent else {
            return XCTFail("interactive inbox should use top-level tab.webContent; Atoll clips inline section webViews")
        }
        XCTAssertFalse(webContent.html.contains("cmux · 2 unread"), "avoid a duplicate web header that pushes message rows below Atoll's visible area")
        XCTAssertTrue(webContent.html.contains("color:#fff"), "transparent Atoll web content must set a light foreground color instead of WebKit's black default")
        XCTAssertTrue(webContent.html.contains("Needs input"), "first visible web content should include the notification title")
        XCTAssertTrue(webContent.allowLocalhostRequests)
        XCTAssertTrue(webContent.html.contains("http://127.0.0.1:9042/jump?id=n1"))
        XCTAssertGreaterThanOrEqual(webContent.preferredHeight, 160, "top-level interactive web content should get enough room to show whole message rows")
    }

    func testTabSectionsDoNotContainInlineWebViewWhenUnreadBecauseAtollClipsIt() {
        let rows = [RowViewModel(id:"n1", sourceLabel:"Codex", title:"Needs input", subtitle:"1m ago",
                                 body:"Please review", unreadCount: 1, isPriority: false, jumpID: "n1")]
        let d = AtollDescriptors.tab(rows: rows, unreadCount: 1, port: 9042)

        let encoded = try! JSONEncoder().encode(d.tab?.sections ?? [])
        let json = String(data: encoded, encoding: .utf8)!
        XCTAssertFalse(json.contains("webView"), "inline section webViews are rendered inside Atoll's padded card slot and get clipped/non-scrollable")
    }

    func testTabUnreadSectionAvoidsNativeHeaderSoClickableCardFits() {
        let rows = [RowViewModel(id:"n1", sourceLabel:"Codex", title:"Needs input", subtitle:"1m ago",
                                 body:"Please review", unreadCount: 1, isPriority: false, jumpID: "n1")]
        let d = AtollDescriptors.tab(rows: rows, unreadCount: 1, port: 9042)

        XCTAssertTrue(d.tab?.sections.isEmpty == true, "Atoll tab is height-constrained; avoid native unread sections that push the clickable web content below the visible area")
    }

    func testCollapsedIndicatorUsesBlipAppIcon() {
        let d = AtollDescriptors.collapsed(unreadCount: 3,
            latest: AgentNotification(id:"n", source:"cmux", title:"Codex", body:"input"))
        switch d.leadingIcon {
        case .appIcon(let bundleIdentifier, _, _):
            XCTAssertFalse(bundleIdentifier.isEmpty)
        default:
            XCTFail("collapsed island should use the Blip app icon instead of a generic SF symbol")
        }
    }

    func testCollapsedIndicatorDisablesSneakPeekToAvoidAtollWhiteBlockArtifact() {
        let d = AtollDescriptors.collapsed(unreadCount: 3,
            latest: AgentNotification(id:"n", source:"cmux", title:"Codex", body:"input"))

        XCTAssertEqual(d.sneakPeekConfig?.enabled, false, "Atoll standard extension sneak peek renders a small accent rectangle that appears as a white block beside Blip's collapsed icon")
        XCTAssertNil(d.sneakPeekTitle, "disabled sneak peek should not carry stale title payload")
        XCTAssertNil(d.sneakPeekSubtitle, "disabled sneak peek should not carry stale subtitle payload")
    }

    func testTabUsesBlipAppIconBadgeForRecognizableTabButton() {
        let d = AtollDescriptors.tab(rows: [], unreadCount: 1, port: 9042)
        guard let badgeIcon = d.tab?.badgeIcon else {
            return XCTFail("tab should use the Blip app icon so Atoll's tab selector is recognizable")
        }
        switch badgeIcon {
        case .appIcon(let bundleIdentifier, _, _):
            XCTAssertFalse(bundleIdentifier.isEmpty)
        default:
            XCTFail("tab badge icon should be the Blip app icon")
        }
    }


    func testTabProvidesCompactInteractiveWebContentForJumpWithoutClearLink() {
        let rows = [RowViewModel(id:"n1", sourceLabel:"Codex", title:"Needs input", subtitle:"1m ago",
                                 body:"Please review", unreadCount: 1, isPriority: false, jumpID: "n1")]
        let d = AtollDescriptors.tab(rows: rows, unreadCount: 1, port: 9042)

        guard let tab = d.tab else { return XCTFail("tab descriptor should include tab configuration") }
        guard let webContent = tab.webContent else { return XCTFail("tab should include top-level web content so notification rows can be clicked without section clipping") }
        XCTAssertTrue(tab.allowWebInteraction, "Atoll must route clicks into the embedded web content for jump/clear actions")
        XCTAssertTrue(webContent.allowLocalhostRequests, "web content must be allowed to call the localhost bridge")
        XCTAssertTrue(webContent.isTransparent, "web content should blend into Atoll panel")
        XCTAssertEqual(webContent.preferredHeight, 220, "top-level interactive content should have enough room for readable rows")
        XCTAssertTrue(webContent.html.contains("http://127.0.0.1:9042/jump?id=n1"), "row click should call the Blip jump endpoint")
        XCTAssertFalse(webContent.html.contains("http://127.0.0.1:9042/clear"), "compact Atoll card should not reserve height for Clear all; clicking the visible row jumps and clears that notification")
    }

    func testTabShowsCompactListWhenMultipleRowsAreUnread() {
        let rows = [
            RowViewModel(id:"n1", sourceLabel:"Codex", title:"First", subtitle:"1m ago", body:"one", unreadCount: 1, isPriority: false, jumpID: "n1"),
            RowViewModel(id:"n2", sourceLabel:"Claude", title:"Second", subtitle:"1m ago", body:"two", unreadCount: 1, isPriority: false, jumpID: "n2"),
            RowViewModel(id:"n3", sourceLabel:"Aider", title:"Third", subtitle:"1m ago", body:"three", unreadCount: 1, isPriority: false, jumpID: "n3")
        ]
        let d = AtollDescriptors.tab(rows: rows, unreadCount: 3, port: 9042)

        guard let webContent = d.tab?.webContent else {
            return XCTFail("visible inbox content should be top-level web content")
        }
        XCTAssertTrue(webContent.html.contains("First"))
        XCTAssertTrue(webContent.html.contains("Second"), "Atoll should preserve the inbox-list experience when multiple messages are unread")
        XCTAssertTrue(webContent.html.contains("Third"), "compact list should fit multiple clickable rows without scrolling")
        XCTAssertEqual(webContent.preferredHeight, 220, "top-level compact list gets enough room because it is no longer trapped in Atoll's clipped inline webView slot")
    }

    func testTabCompactListRequestsOnlyVisibleRowHeight() {
        let rows = [
            RowViewModel(id:"n1", sourceLabel:"Codex", title:"First", subtitle:"1m ago", body:"one", unreadCount: 1, isPriority: false, jumpID: "n1"),
            RowViewModel(id:"n2", sourceLabel:"Claude", title:"Second", subtitle:"1m ago", body:"two", unreadCount: 1, isPriority: false, jumpID: "n2"),
            RowViewModel(id:"n3", sourceLabel:"Aider", title:"Third", subtitle:"1m ago", body:"three", unreadCount: 1, isPriority: false, jumpID: "n3")
        ]
        let d = AtollDescriptors.tab(rows: rows, unreadCount: 3, port: 9042)

        guard let webContent = d.tab?.webContent else {
            return XCTFail("visible inbox content should be top-level web content")
        }
        XCTAssertEqual(webContent.preferredHeight, 220, "top-level web content avoids Atoll's clipped inline webView slot and gets room for the visible compact rows")
    }

    func testTabRequestsMaximumAtollHeightForReadableInbox() {
        let d = AtollDescriptors.tab(rows: [], unreadCount: 0, port: 9042)

        XCTAssertEqual(d.tab?.preferredHeight, 420, "Atoll clamps extension tabs; request the maximum supported height so the island expands as much as Atoll allows")
    }

    func testTabProvidesTopLevelWebContentSoAtollDoesNotClipUnreadInbox() {
        let rows = [
            RowViewModel(id:"n1", sourceLabel:"Codex", title:"Needs input", subtitle:"1m ago",
                         body:"Please review the generated plan", unreadCount: 1, isPriority: false, jumpID: "n1")
        ]

        let d = AtollDescriptors.tab(rows: rows, unreadCount: 1, port: 9042)

        guard let tab = d.tab else { return XCTFail("tab descriptor should include tab configuration") }
        XCTAssertTrue(tab.sections.isEmpty, "unread inbox should not use section webViews because Atoll clips them")
        XCTAssertNotNil(tab.webContent, "unread inbox should render through top-level interactive webContent")
        XCTAssertTrue(tab.webContent?.html.contains("Needs input") == true)
        XCTAssertTrue(tab.webContent?.html.contains("Please review the generated plan") == true)
    }

    func testTabProvidesNativeAllClearSectionWhenInboxIsEmpty() {
        let d = AtollDescriptors.tab(rows: [], unreadCount: 0, port: 9042)

        guard let tab = d.tab else { return XCTFail("tab descriptor should include tab configuration") }
        XCTAssertFalse(tab.sections.isEmpty, "empty inbox should still render native content instead of a blank Atoll panel")
        let encoded = try! JSONEncoder().encode(tab.sections)
        let json = String(data: encoded, encoding: .utf8)!
        XCTAssertTrue(json.contains("All clear"), "native fallback should make the empty state visible")
    }

    func testTabWithInlineListIsValid() {
        let rows = [RowViewModel(id:"cmux:s", sourceLabel:"Codex", title:"Codex", subtitle:"Waiting",
                                 body:"input", unreadCount: 1, isPriority: false, jumpID: "n")]
        let d = AtollDescriptors.tab(rows: rows, unreadCount: 1, port: 9042)
        XCTAssertTrue(d.isValid, "tab descriptor failed validation")
    }
}
