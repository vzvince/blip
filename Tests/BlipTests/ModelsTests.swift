import XCTest
@testable import Blip
final class ModelsTests: XCTestCase {
    func testCollapseKeyForCmuxSurface() {
        let n = AgentNotification(id: "1", source: "cmux", title: "Codex", body: "input",
                                  jump: .cmuxSurface(workspaceId: "w", surfaceId: "s"))
        XCTAssertEqual(n.collapseKey, "cmux:s")
    }
    func testCollapseKeyForGenericSource() {
        let n = AgentNotification(id: "2", source: "codex", title: "done", body: "")
        XCTAssertEqual(n.collapseKey, "src:codex")
    }
    func testCodableRoundTrip() throws {
        let n = AgentNotification(id: "3", source: "claude-code", title: "T", subtitle: "S", body: "B",
                                 priority: .high, jump: .cmuxSurface(workspaceId: "w", surfaceId: "u"))
        let data = try JSONEncoder().encode(n)
        let back = try JSONDecoder().decode(AgentNotification.self, from: data)
        XCTAssertEqual(back, n)
    }
}
