import XCTest
@testable import Blip

final class HTTPParserTests: XCTestCase {
    func testAccumulatorWaitsForSplitPostBodyBeforeParsing() throws {
        let body = try JSONSerialization.data(withJSONObject: ["source": "codex", "title": "Build failed"])
        let head = "POST /push HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: \(body.count)\r\n\r\n"
        var acc = HTTPRequestAccumulator()

        XCTAssertNil(acc.append(Data(head.utf8)), "headers without the promised body are not a complete request")
        let req = try XCTUnwrap(acc.append(body))

        XCTAssertEqual(req.method, "POST")
        XCTAssertEqual(req.path, "/push")
        XCTAssertEqual(req.body, body)
    }
}
