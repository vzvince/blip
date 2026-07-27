import XCTest
@testable import Blip
final class CmuxTests: XCTestCase {
    func testEncodeListRequestHasMethodAndParams() throws {
        let data = CmuxFrames.encode(id: "q", method: "notification.list", params: ["k": "v"])
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String:Any])
        XCTAssertEqual(obj["id"] as? String, "q")
        XCTAssertEqual(obj["method"] as? String, "notification.list")
        XCTAssertEqual((obj["params"] as? [String:Any])?["k"] as? String, "v")
    }
    func testEncodeSurfaceFocus() throws {
        let data = CmuxFrames.encode(id: "f", method: "surface.focus", params: ["surface_id":"S"])
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String:Any])
        XCTAssertEqual((obj["params"] as? [String:Any])?["surface_id"] as? String, "S")
    }
    func testMapListResponseProducesNotificationsWithSurface() {
        let list: [String:Any] = ["items": [
            ["id":"n1","workspaceId":"w","surfaceId":"s","title":"Codex","subtitle":"Waiting","body":"input","read":false] as [String:Any]
        ]]
        let got = CmuxMapper.mapList(list)
        XCTAssertEqual(got.count, 1)
        XCTAssertEqual(got[0].id, "n1")
        XCTAssertEqual(got[0].jump, .cmuxSurface(workspaceId: "w", surfaceId: "s"))
        XCTAssertEqual(got[0].title, "Codex")
    }
    func testMapListResponseSkipsAlreadyReadItems() {
        let list: [String:Any] = ["items": [
            ["id":"n1","workspaceId":"w","surfaceId":"s","title":"x","body":"b","read":true] as [String:Any]
        ]]
        XCTAssertTrue(CmuxMapper.mapList(list).isEmpty)
    }
    func testMapListResponseToleratesAugmentedKeys() {
        // cmux may use snake_case variants; mapper reads both camel + snake
        let list: [String:Any] = ["items": [
            ["id":"n1","workspace_id":"w","surface_id":"s","title":"x","body":"b","read":false] as [String:Any]
        ]]
        XCTAssertEqual(CmuxMapper.mapList(list).first?.jump,
                       .cmuxSurface(workspaceId: "w", surfaceId: "s"))
    }
    // Live-shape calibration (measured against real cmux `list-notifications --json`)
    func testMapListBareArrayShapeIsRealCmux() {
        // Real cmux returns a BARE ARRAY, no wrapper. The mapper accepts the array under
        // `items`/`notifications`/`result`/`array`; the poller (Task 11) wraps the bare array
        // as `["array": items]` before calling mapList. This test exercises the `array` key.
        let bare: [String:Any] = ["array": [[
            "id":"EF8B7A6B","workspace_id":"w1","surface_id":"s1",
            "title":"Codex","subtitle":"","body":"input","is_read":false,
            "created_at":"2026-07-27T07:46:12Z","tab_title":"proj"
        ] as [String:Any], [
            "id":"2","workspace_id":"w2","surface_id":"s2",
            "title":"Claude","subtitle":"","body":"done","is_read":true,
            "created_at":"2026-07-27T07:46:13Z","tab_title":"build"
        ] as [String:Any]]]
        let got = CmuxMapper.mapList(bare)
        XCTAssertEqual(got.count, 1)                    // the is_read:true one is dropped
        XCTAssertEqual(got.first?.id, "EF8B7A6B")
        XCTAssertEqual(got.first?.jump, .cmuxSurface(workspaceId: "w1", surfaceId: "s1"))
    }
    func testMapListRealItemFields() {
        let wrapper: [String:Any] = ["items": [[
            "id":"EF8B7A6B","workspace_id":"w","surface_id":"s",
            "title":"Claude Code","subtitle":"","body":"Claude is waiting for your input",
            "is_read":false,"created_at":"2026-07-27T07:28:20Z","tab_title":"yc.atif"
        ] as [String:Any]]]
        let got = CmuxMapper.mapList(wrapper)
        XCTAssertEqual(got.count, 1)
        let n = got.first!
        XCTAssertEqual(n.id, "EF8B7A6B")
        XCTAssertEqual(n.title, "Claude Code")
        XCTAssertEqual(n.body, "Claude is waiting for your input")
        XCTAssertEqual(n.sourceLabel, "yc.atif")
        // createdAt parsed from the ISO8601 string
        let cal = Calendar(identifier: .gregorian)
        XCTAssertEqual(cal.component(.year, from: n.createdAt), 2026)
        XCTAssertEqual(cal.component(.month, from: n.createdAt), 7)
        XCTAssertEqual(cal.component(.day, from: n.createdAt), 27)
    }
    func testMapListDropsItemsAlreadyReadViaIsRead() {
        let wrapper: [String:Any] = ["items": [[
            "id":"x","workspace_id":"w","surface_id":"s","title":"t","body":"b",
            "is_read":true,"created_at":"2026-07-27T07:28:20Z"
        ] as [String:Any]]]
        XCTAssertTrue(CmuxMapper.mapList(wrapper).isEmpty)
    }
}
