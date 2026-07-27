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
    func testTabWithInlineListIsValid() {
        let rows = [RowViewModel(id:"cmux:s", sourceLabel:"Codex", title:"Codex", subtitle:"Waiting",
                                 body:"input", unreadCount: 1, isPriority: false, jumpID: "n")]
        let d = AtollDescriptors.tab(rows: rows, unreadCount: 1, port: 9042)
        XCTAssertTrue(d.isValid, "tab descriptor failed validation")
    }
}
