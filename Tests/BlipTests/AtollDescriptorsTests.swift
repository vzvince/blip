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

    func testCollapsedIndicatorUsesReadableTrailingText() {
        let d = AtollDescriptors.collapsed(unreadCount: 3,
            latest: AgentNotification(id:"n", source:"cmux", title:"Codex", body:"input"))
        switch d.trailingContent {
        case .marquee(let text, _, _, _):
            XCTAssertEqual(text, "Blip 3")
        default:
            XCTFail("collapsed island should use readable trailing text instead of a bare count")
        }
    }


    func testCollapsedIndicatorUsesBlipAppIconAndSneakPeekOnEveryUpdate() {
        let d = AtollDescriptors.collapsed(unreadCount: 3,
            latest: AgentNotification(id:"n", source:"cmux", title:"Codex", body:"input"))
        switch d.leadingIcon {
        case .appIcon(let bundleIdentifier, _, _):
            XCTAssertFalse(bundleIdentifier.isEmpty)
        default:
            XCTFail("collapsed island should use the Blip app icon instead of a generic SF symbol")
        }
        XCTAssertEqual(d.sneakPeekConfig?.showOnUpdate, true, "updates to an existing Atoll activity must still show the message sneak peek")
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

    func testTabWithInlineListIsValid() {
        let rows = [RowViewModel(id:"cmux:s", sourceLabel:"Codex", title:"Codex", subtitle:"Waiting",
                                 body:"input", unreadCount: 1, isPriority: false, jumpID: "n")]
        let d = AtollDescriptors.tab(rows: rows, unreadCount: 1, port: 9042)
        XCTAssertTrue(d.isValid, "tab descriptor failed validation")
    }
}
