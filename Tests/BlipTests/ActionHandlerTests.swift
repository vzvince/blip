import XCTest
@testable import Blip
final class ActionHandlerTests: XCTestCase {
    final class Stub: JumpExecutor {
        var surface: String?; var opened: String?; var cleared = false
        var focusedWorkspace: String? = nil
        var openedNotification: String? = nil
        func openCmuxNotification(id: String, workspaceId: String, surfaceId: String) { openedNotification = id; focusedWorkspace = workspaceId; surface = surfaceId }
        func openApp(bundleId: String) { opened = bundleId }
        func clearCmux() { cleared = true }
    }
    func testActivateCmuxGroupJumpsAndClearsGroup() {
        let store = Store()
        store.upsert(AgentNotification(id:"n1", source:"cmux", title:"Codex", body:"x",
            createdAt: Date(timeIntervalSince1970: 1),
            jump: .cmuxSurface(workspaceId:"w", surfaceId:"s1")))
        let jump = Stub()
        let action = ActionHandler(store: store, jump: jump)
        action.activate(rowID: "cmux:s1")
        XCTAssertEqual(jump.openedNotification, "n1")
        XCTAssertEqual(jump.surface, "s1")
        XCTAssertEqual(jump.focusedWorkspace, "w")
        XCTAssertEqual(store.unreadCount, 0)   // group marked read
    }
    func testActivateUsesNewestItemsJumpTarget() {
        // two items same surface; row.jumpID = newest id "n2"; activate should focus n2's surface
        let store = Store()
        store.upsert(AgentNotification(id:"n1", source:"cmux", title:"Codex", body:"first",
            createdAt: Date(timeIntervalSince1970: 1),
            jump: .cmuxSurface(workspaceId:"w", surfaceId:"s1")))
        store.upsert(AgentNotification(id:"n2", source:"cmux", title:"Codex", body:"second",
            createdAt: Date(timeIntervalSince1970: 5),
            jump: .cmuxSurface(workspaceId:"w", surfaceId:"s1")))
        let jump = Stub()
        let action = ActionHandler(store: store, jump: jump)
        // the row id is the collapseKey cmux:s1; row.jumpID should be n2
        XCTAssertEqual(store.rows().first { $0.id == "cmux:s1" }?.jumpID, "n2")
        action.activate(rowID: "cmux:s1")
        XCTAssertEqual(jump.openedNotification, "n2")
        XCTAssertEqual(jump.surface, "s1")
    }
    func testActivateUnknownRowIsNoop() {
        let store = Store(); let jump = Stub(); let action = ActionHandler(store: store, jump: jump)
        action.activate(rowID: "nope")
        XCTAssertNil(jump.surface); XCTAssertEqual(store.unreadCount, 0)
    }
    func testOpenAppJumpPath() {
        let store = Store()
        store.upsert(AgentNotification(id:"n2", source:"webhook", title:"T", body:"B",
            jump: .openApp(bundleId: "com.example.app")))
        let jump = Stub(); let action = ActionHandler(store: store, jump: jump)
        action.activate(rowID: "src:webhook")
        XCTAssertEqual(jump.opened, "com.example.app")
        XCTAssertEqual(store.unreadCount, 0)
    }
    func testClearAllCallsCmuxClearAndEmpties() {
        let store = Store()
        store.upsert(AgentNotification(id:"n1", source:"cmux", title:"Codex", body:"x",
            jump: .cmuxSurface(workspaceId:"w", surfaceId:"s")))
        let jump = Stub(); let action = ActionHandler(store: store, jump: jump)
        action.clearAll()
        XCTAssertTrue(jump.cleared); XCTAssertEqual(store.unreadCount, 0)
    }
}
