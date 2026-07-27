import XCTest
@testable import Blip
final class CLIRequestBuilderTests: XCTestCase {
    func testPushBuildsPostJson() throws {
        let req = CLIRequestBuilder.push(base: URL(string:"http://127.0.0.1:9999")!,
            source: "codex", title: "Build failed", body: "see logs",
            workspaceId: "w", surfaceId: "s", priority: "high")
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.url?.path, "/push")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: req.httpBody!) as? [String:Any])
        XCTAssertEqual(obj["source"] as? String, "codex")
        XCTAssertEqual(obj["title"] as? String, "Build failed")
        XCTAssertEqual(obj["body"] as? String, "see logs")
        XCTAssertEqual(obj["workspaceId"] as? String, "w")
        XCTAssertEqual(obj["surfaceId"] as? String, "s")
        XCTAssertEqual(obj["priority"] as? String, "high")
    }
    func testLsBuildsGet() {
        let req = CLIRequestBuilder.ls(base: URL(string:"http://127.0.0.1:9999")!)
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.url?.path, "/ls")
    }
    func testFocusBuildsGetWithEncodedID() {
        let req = CLIRequestBuilder.focus(base: URL(string:"http://127.0.0.1:9999")!, id: "cmux:s")
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.url?.path, "/jump")
        // URLQueryItem on macOS does not percent-encode ':' (RFC 3986 sub-delim, allowed in query);
        // the builder's output is canonical — assert the actual wire form.
        XCTAssertEqual(req.url?.query, "id=cmux:s")
    }
    func testClearBuildsPost() {
        let req = CLIRequestBuilder.clear(base: URL(string:"http://127.0.0.1:9999")!)
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.url?.path, "/clear")
    }
}
