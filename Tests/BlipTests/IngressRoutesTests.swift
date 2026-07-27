import XCTest
@testable import Blip
final class IngressRoutesTests: XCTestCase {
    func testPushPersistsNotification() throws {
        let store = Store()
        let action = StubAction()
        let body = try JSONSerialization.data(withJSONObject:
            ["source":"codex","title":"done","body":"ok","workspaceId":"w","surfaceId":"s"])
        let res = IngressRoutes.respond(method: "POST", path: "/push", query: [:], body: body,
                                        store: store, action: action, port: 9999)
        XCTAssertEqual(res.statusCode, 204)
        XCTAssertEqual(store.unreadCount, 1)
    }
    func testJumpActivatesRowByCollapseKey() {
        let store = Store()
        store.upsert(AgentNotification(id:"n1", source:"cmux", title:"Codex", body:"x",
            jump: .cmuxSurface(workspaceId:"w", surfaceId:"s")))
        let action = StubAction()
        // jumpID here is the row's jumpID; the route receives the ROW id (collapseKey) ? or the jumpID?
        // Per design: the island row onclick does fetch('/jump?id=<rowID>'). row.id == collapseKey.
        let rows = store.rows()
        let rowID = rows.first!.id
        let res = IngressRoutes.respond(method: "GET", path: "/jump", query: ["id": rowID],
                                        body: Data(), store: store, action: action, port: 9999)
        XCTAssertEqual(res.statusCode, 204)
        XCTAssertEqual(action.activatedRowID, rowID)
        XCTAssertEqual(res.headers["Access-Control-Allow-Origin"], "*")
    }
    func testCorsPreflightReturns200() {
        let store = Store(); let action = StubAction()
        let res = IngressRoutes.respond(method: "OPTIONS", path: "/push", query: [:], body: Data(),
                                        store: store, action: action, port: 9999)
        XCTAssertEqual(res.statusCode, 200)
        XCTAssertEqual(res.headers["Access-Control-Allow-Methods"], "GET, POST, OPTIONS")
        XCTAssertEqual(res.headers["Access-Control-Allow-Origin"], "*")
    }
    func testLsReturnsRowsJson() throws {
        let store = Store()
        store.upsert(AgentNotification(id:"n1", source:"cmux", title:"Codex", body:"x",
            jump: .cmuxSurface(workspaceId:"w", surfaceId:"s")))
        let action = StubAction()
        let res = IngressRoutes.respond(method: "GET", path: "/ls", query: [:], body: Data(),
                                        store: store, action: action, port: 9999)
        XCTAssertEqual(res.statusCode, 200)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: res.body) as? [String:Any])
        XCTAssertEqual(obj["unread"] as? Int, 1)
        let arr = try XCTUnwrap(obj["items"] as? [[String:Any]])
        XCTAssertEqual(arr.first?["id"] as? String, "cmux:s")
    }
    func testClearCallsClearAll() {
        let store = Store()
        store.upsert(AgentNotification(id:"n1", source:"cmux", title:"Codex", body:"x",
            jump: .cmuxSurface(workspaceId:"w", surfaceId:"s")))
        let action = StubAction()
        _ = IngressRoutes.respond(method: "POST", path: "/clear", query: [:], body: Data(),
                                        store: store, action: action, port: 9999)
        XCTAssertTrue(action.cleared)
    }
}

final class StubAction: ActionRouting {
    var activatedRowID: String? = nil
    var cleared = false
    func activate(rowID: String) { activatedRowID = rowID }
    func clearAll() { cleared = true }
}
