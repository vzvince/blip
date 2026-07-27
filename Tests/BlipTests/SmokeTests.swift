import XCTest
@testable import Blip
final class SmokeTests: XCTestCase {
    func testVersion() { XCTAssertEqual(BlipVersion.current, "0.1.0") }
}
