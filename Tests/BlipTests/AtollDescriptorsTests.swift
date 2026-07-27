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

    func testTabNativeSectionIsCompactWithoutInstructionSubtitle() {
        let rows = [RowViewModel(id:"n1", sourceLabel:"Codex", title:"Needs input", subtitle:"1m ago",
                                 body:"Please review", unreadCount: 1, isPriority: false, jumpID: "n1")]
        let d = AtollDescriptors.tab(rows: rows, unreadCount: 1, port: 9042)

        let section = d.tab?.sections.first
        XCTAssertEqual(section?.title, "1 unread")
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


    func testTabUsesNativeRenderingInsteadOfTallEmbeddedWebViewInAtoll() {
        let rows = [RowViewModel(id:"n1", sourceLabel:"Codex", title:"Needs input", subtitle:"1m ago",
                                 body:"Please review", unreadCount: 1, isPriority: false, jumpID: "n1")]
        let d = AtollDescriptors.tab(rows: rows, unreadCount: 1, port: 9042)

        XCTAssertNil(d.tab?.webContent, "Atoll tab should not embed a tall web view because Atoll clamps tab height and clips the inbox")
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
