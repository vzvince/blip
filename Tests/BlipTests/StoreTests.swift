import XCTest
@testable import Blip
final class StoreTests: XCTestCase {
    private func mk(_ id: String, _ surface: String, _ body: String, _ t: TimeInterval) -> AgentNotification {
        AgentNotification(id: id, source: "cmux", title: "Codex", body: body,
                          createdAt: Date(timeIntervalSince1970: t),
                          jump: .cmuxSurface(workspaceId: "w", surfaceId: surface))
    }
    func testUpsertDedupsById() {
        let s = Store()
        s.upsert(mk("1", "a", "first", 1))
        s.upsert(mk("1", "a", "second", 2))   // same id → replace
        XCTAssertEqual(s.unreadCount, 1)
        XCTAssertEqual(s.snapshot().first?.body, "second")
    }
    func testCollapsesBySurface() {
        let s = Store()
        s.upsert(mk("1", "a", "first", 1))
        s.upsert(mk("2", "a", "second", 2))   // same surface → one row, count 2
        s.upsert(mk("3", "b", "other", 3))
        let rows = s.rows()
        XCTAssertEqual(rows.count, 2)
        let aRow = rows.first { $0.id == "cmux:a" }!
        XCTAssertEqual(aRow.unreadCount, 2)
        XCTAssertEqual(aRow.jumpID, "2")           // newest in group
        XCTAssertEqual(aRow.body, "second")
    }
    func testMarkGroupReadClearsRow() {
        let s = Store()
        s.upsert(mk("1", "a", "x", 1))
        s.upsert(mk("2", "a", "y", 2))
        s.markGroupRead(key: "cmux:a")
        XCTAssertEqual(s.unreadCount, 0)
        XCTAssertTrue(s.rows().isEmpty)
    }
    func testMarkGroupReadSuppressesFutureReimportOfSameCmuxNotificationIDs() {
        let s = Store()
        let n = mk("1", "a", "x", 1)
        s.upsert(n)
        s.markGroupRead(key: "cmux:a")

        s.upsert(n)

        XCTAssertEqual(s.unreadCount, 0, "polling cmux after activation must not immediately re-import the same notification as unread")
        XCTAssertTrue(s.rows().isEmpty)
    }

    func testClearSuppressesFutureReimportOfCurrentItems() {
        let s = Store()
        let n = mk("1", "a", "x", 1)
        s.upsert(n)
        s.clear()

        s.upsert(n)

        XCTAssertEqual(s.unreadCount, 0, "clear should not let the next cmux poll resurrect locally cleared notifications")
    }

    func testCapacityTrimsOldest() {
        let s = Store(capacity: 2)
        s.upsert(mk("1", "a", "x", 1))
        s.upsert(mk("2", "a", "y", 2))
        s.upsert(mk("3", "b", "z", 3))
        XCTAssertEqual(s.snapshot().count, 2)
        XCTAssertNil(s.snapshot().first { $0.id == "1" })
    }
}
