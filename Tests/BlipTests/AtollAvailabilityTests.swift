import XCTest
@testable import Blip

final class AtollAvailabilityTests: XCTestCase {
    func testDoesNotContactXPCWhenAtollIsOnlyInstalledButNotRunning() {
        XCTAssertFalse(AtollAvailability.shouldContactXPC(isInstalled: true, isRunning: false))
    }

    func testContactsXPCOnlyWhenAtollInstalledAndRunning() {
        XCTAssertTrue(AtollAvailability.shouldContactXPC(isInstalled: true, isRunning: true))
        XCTAssertFalse(AtollAvailability.shouldContactXPC(isInstalled: false, isRunning: true))
        XCTAssertFalse(AtollAvailability.shouldContactXPC(isInstalled: false, isRunning: false))
    }
}
