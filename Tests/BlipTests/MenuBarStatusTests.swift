import XCTest
@testable import Blip

final class MenuBarStatusTests: XCTestCase {
    func testTitleOmitsCountWhenUnreadIsZero() {
        let status = MenuBarStatus(unreadCount: 0, atollInstalled: true, atollRunning: true, cmuxSocket: "/tmp/cmux.sock")
        XCTAssertEqual(status.title, "Blip")
    }

    func testTitleIncludesUnreadCount() {
        let status = MenuBarStatus(unreadCount: 3, atollInstalled: true, atollRunning: true, cmuxSocket: "/tmp/cmux.sock")
        XCTAssertEqual(status.title, "Blip 3")
    }

    func testLinesDescribeAtollAndCmuxState() {
        let status = MenuBarStatus(unreadCount: 1, atollInstalled: true, atollRunning: false, cmuxSocket: "/Users/me/.local/state/cmux/cmux.sock")
        XCTAssertEqual(status.atollLine, "Atoll: installed, not running")
        XCTAssertEqual(status.cmuxLine, "cmux: /Users/me/.local/state/cmux/cmux.sock")
        XCTAssertEqual(status.systemImage, "bell.badge.fill")
    }
}
