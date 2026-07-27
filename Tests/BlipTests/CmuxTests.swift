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
}
