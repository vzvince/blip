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

    func testNotificationRowsShowEveryUnreadItemWithinSameSurface() {
        let s = Store()
        s.upsert(mk("1", "a", "first", 1))
        s.upsert(mk("2", "a", "second", 2))
        s.upsert(mk("3", "a", "third", 3))

        let rows = s.notificationRows()

        XCTAssertEqual(rows.map(\.id), ["3", "2", "1"], "Atoll inbox needs individual notification rows, not only one collapsed surface row")
        XCTAssertEqual(rows.map(\.body), ["third", "second", "first"])
        XCTAssertTrue(rows.allSatisfy { $0.unreadCount == 1 }, "individual rows should not display the collapsed group badge")
    }

    func testMarkReadRemovesAndSuppressesOneNotification() {
        let s = Store()
        let n1 = mk("1", "a", "first", 1)
        let n2 = mk("2", "a", "second", 2)
        s.upsert(n1)
        s.upsert(n2)

        s.markRead(id: "2")
        s.upsert(n2)

        XCTAssertEqual(s.unreadCount, 1, "handled notification should not be reimported by the next cmux poll")
        XCTAssertEqual(s.notificationRows().map(\.id), ["1"])
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
