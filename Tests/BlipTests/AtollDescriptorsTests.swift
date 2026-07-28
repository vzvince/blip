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



    func testTabInteractiveInboxStartsWithReadableMessageCardNotDuplicateHeader() {
        let rows = [RowViewModel(id:"n1", sourceLabel:"Codex", title:"Needs input", subtitle:"1m ago",
                                 body:"Please review", unreadCount: 2, isPriority: false, jumpID: "n1")]
        let d = AtollDescriptors.tab(rows: rows, unreadCount: 2, port: 9042)

        guard case .webView(let webContent)? = d.tab?.sections.first?.elements.first else {
            return XCTFail("visible inbox content should be web content")
        }
        XCTAssertFalse(webContent.html.contains("cmux · 2 unread"), "section title already shows unread count; a duplicate web header pushes message cards below Atoll's visible area")
        XCTAssertTrue(webContent.html.contains("color:#fff"), "transparent Atoll web content must set a light foreground color instead of WebKit's black default")
        XCTAssertTrue(webContent.html.contains("Needs input"), "first visible web content should include the notification title")
        XCTAssertLessThanOrEqual(webContent.preferredHeight, 90, "embedded Atoll content must fit without relying on nested web view scrolling")
    }

    func testTabRendersInteractiveInboxAsFirstVisibleSectionElement() {
        let rows = [RowViewModel(id:"n1", sourceLabel:"Codex", title:"Needs input", subtitle:"1m ago",
                                 body:"Please review", unreadCount: 1, isPriority: false, jumpID: "n1")]
        let d = AtollDescriptors.tab(rows: rows, unreadCount: 1, port: 9042)

        guard let firstElement = d.tab?.sections.first?.elements.first else {
            return XCTFail("tab should render inbox content in the first visible section")
        }
        switch firstElement {
        case .webView(let webContent):
            XCTAssertTrue(webContent.allowLocalhostRequests)
            XCTAssertTrue(webContent.html.contains("http://127.0.0.1:9042/jump?id=n1"))
        default:
            XCTFail("the first visible inbox element must be a webView; native text rows are not clickable in Atoll")
        }
        XCTAssertNil(d.tab?.webContent, "avoid rendering a second duplicate interactive inbox below the visible section")
    }

    func testTabUnreadSectionAvoidsNativeHeaderSoClickableCardFits() {
        let rows = [RowViewModel(id:"n1", sourceLabel:"Codex", title:"Needs input", subtitle:"1m ago",
                                 body:"Please review", unreadCount: 1, isPriority: false, jumpID: "n1")]
        let d = AtollDescriptors.tab(rows: rows, unreadCount: 1, port: 9042)

        let section = d.tab?.sections.first
        XCTAssertNil(section?.title, "Atoll tab is height-constrained; avoid a native unread header that pushes the clickable card below the visible clipped area")
        XCTAssertNil(section?.subtitle, "Atoll tab is height-constrained; avoid instructional subtitle that makes the inbox feel cramped")
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
        guard let firstElement = tab.sections.first?.elements.first else { return XCTFail("tab should include visible inbox content") }
        guard case .webView(let webContent) = firstElement else { return XCTFail("visible inbox content should be web content so notification rows can be clicked") }
        XCTAssertTrue(tab.allowWebInteraction, "Atoll must route clicks into the embedded web content for jump/clear actions")
        XCTAssertTrue(webContent.allowLocalhostRequests, "web content must be allowed to call the localhost bridge")
        XCTAssertTrue(webContent.isTransparent, "web content should blend into Atoll panel")
        XCTAssertEqual(webContent.preferredHeight, 86, "interactive card should fit without nested scrolling in Atoll")
        XCTAssertTrue(webContent.html.contains("http://127.0.0.1:9042/jump?id=n1"), "row click should call the Blip jump endpoint")
        XCTAssertFalse(webContent.html.contains("http://127.0.0.1:9042/clear"), "compact Atoll card should not reserve height for Clear all; clicking the visible row jumps and clears that notification")
    }

    func testTabRequestsMaximumAtollHeightForReadableInbox() {
        let d = AtollDescriptors.tab(rows: [], unreadCount: 0, port: 9042)

        XCTAssertEqual(d.tab?.preferredHeight, 420, "Atoll clamps extension tabs; request the maximum supported height so the island expands as much as Atoll allows")
    }

    func testTabProvidesNativeSectionsSoAtollDoesNotRenderEmptyWhenWebContentIsUnavailable() {
        let rows = [
            RowViewModel(id:"n1", sourceLabel:"Codex", title:"Needs input", subtitle:"1m ago",
                         body:"Please review the generated plan", unreadCount: 1, isPriority: false, jumpID: "n1")
        ]

        let d = AtollDescriptors.tab(rows: rows, unreadCount: 1, port: 9042)

        guard let tab = d.tab else { return XCTFail("tab descriptor should include tab configuration") }
        XCTAssertFalse(tab.sections.isEmpty, "tab should include native sections as a fallback when Atoll web content is not selected or fails to render")
        let encoded = try! JSONEncoder().encode(tab.sections)
        let json = String(data: encoded, encoding: .utf8)!
        XCTAssertTrue(json.contains("Needs input"), "native fallback should include latest notification title")
        XCTAssertTrue(json.contains("Please review the generated plan"), "native fallback should include latest notification body")
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
