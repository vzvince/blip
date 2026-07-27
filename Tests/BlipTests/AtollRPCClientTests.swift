import XCTest
@testable import Blip

final class AtollRPCClientTests: XCTestCase {
    func testAuthorizationRequestUsesAtollJSONRPCShape() throws {
        let data = try AtollRPCRequestFactory.makeRequest(
            method: "atoll.requestAuthorization",
            params: ["bundleIdentifier": "dev.blip"],
            id: "1"
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(json["method"] as? String, "atoll.requestAuthorization")
        XCTAssertEqual(json["id"] as? String, "1")
        let params = try XCTUnwrap(json["params"] as? [String: Any])
        XCTAssertEqual(params["bundleIdentifier"] as? String, "dev.blip")
    }

    func testDescriptorRequestWrapsDescriptorObject() throws {
        let descriptor = AtollDescriptors.collapsed(
            unreadCount: 2,
            latest: AgentNotification(id: "n1", source: "codex", title: "Done", body: "Ready")
        )
        let data = try AtollRPCRequestFactory.makeDescriptorRequest(
            method: "atoll.presentLiveActivity",
            descriptor: descriptor,
            id: "2"
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let params = try XCTUnwrap(json["params"] as? [String: Any])
        let wrapped = try XCTUnwrap(params["descriptor"] as? [String: Any])

        XCTAssertEqual(wrapped["id"] as? String, AtollDescriptors.activityID)
        XCTAssertEqual(wrapped["title"] as? String, "Blip")
        XCTAssertEqual(wrapped["bundleIdentifier"] as? String, Bundle.main.bundleIdentifier ?? "dev.blip")
    }

    func testSuccessAndAuthorizationResponsesAreDecoded() throws {
        let success = try AtollRPCResponse.parse(Data(#"{"jsonrpc":"2.0","result":{"success":true},"id":"3"}"#.utf8))
        XCTAssertTrue(success.isSuccess)

        let authorized = try AtollRPCResponse.parse(Data(#"{"jsonrpc":"2.0","result":{"authorized":true},"id":"4"}"#.utf8))
        XCTAssertEqual(authorized.boolResult("authorized"), true)
    }

    func testErrorResponseThrowsReadableMessage() {
        let data = Data(#"{"jsonrpc":"2.0","error":{"code":-32002,"message":"Extensions are disabled"},"id":"5"}"#.utf8)
        XCTAssertThrowsError(try AtollRPCResponse.parse(data)) { error in
            XCTAssertTrue(String(describing: error).contains("Extensions are disabled"))
        }
    }
}
