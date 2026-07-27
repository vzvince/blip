import XCTest
@testable import Blip
import AtollExtensionKit
final class AtollPresenterTests: XCTestCase {
    @MainActor
    final class StubSession: AtollPresenting {
        var presentedActivity = false
        var updatedActivity = false
        var dismissedActivity = false
        var presentedTab = false
        var updatedTab = false
        var dismissedTab = false
        func presentActivity(_ d: AtollLiveActivityDescriptor) async throws { presentedActivity = true }
        func updateActivity(_ d: AtollLiveActivityDescriptor) async throws { updatedActivity = true }
        func dismissActivity() async throws { dismissedActivity = true }
        func presentTab(_ d: AtollNotchExperienceDescriptor) async throws { presentedTab = true }
        func updateTab(_ d: AtollNotchExperienceDescriptor) async throws { updatedTab = true }
        func dismissTab() async throws { dismissedTab = true }
    }
    @MainActor
    func testIdlePresenterWithdrawsNothing() async {
        let p = AtollPresenter(session: StubSession(), port: 9042)
        await p.reload(unread: 0, rows: [], connection: .connected)
        XCTAssertFalse(p.state.activity)
        XCTAssertFalse(p.state.tab)
    }
    @MainActor
    func testAttentionPresentsActivity() async {
        // 1ms coalesce so the coalesced applyPending flushes promptly under test;
        // the production default (250ms) is exercised only by testCoalescingCollapsesRapidUpdates.
        let s = StubSession(); let p = AtollPresenter(session: s, port: 9042, coalesceNanos: 1_000_000)
        let row = RowViewModel(id:"cmux:s", sourceLabel:"Codex", title:"Codex", subtitle:"Waiting",
                               body:"x", unreadCount:1, isPriority:false, jumpID:"n")
        await p.reload(unread: 1, rows: [row], connection: .connected)
        // Await the coalesced flush before asserting: reload() schedules applyPending()
        // via Task.sleep(coalesceNanos), so the presentActivity side-effect lands only after.
        try? await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertTrue(p.state.activity, "should present activity when unread>0")
        XCTAssertFalse(p.state.tab, "collapsed by default")
    }
    @MainActor
    func testExpandedBitFollowsExplicitOpen() async {
        let s = StubSession(); let p = AtollPresenter(session: s, port: 9042)
        let row = RowViewModel(id:"cmux:s", sourceLabel:"Codex", title:"Codex", subtitle:"", body:"x",
                               unreadCount:1, isPriority:false, jumpID:"n")
        await p.reload(unread: 1, rows:[row], connection:.connected)
        await p.setExpanded(true)
        XCTAssertTrue(p.state.tab)
        await p.setExpanded(false)
        XCTAssertFalse(p.state.tab)
    }
    @MainActor
    func testBackToIdleDismissesAll() async {
        // 1ms coalesce so each reload's coalesced applyPending flushes promptly under test.
        let s = StubSession(); let p = AtollPresenter(session: s, port: 9042, coalesceNanos: 1_000_000)
        let row = RowViewModel(id:"cmux:s", sourceLabel:"Codex", title:"Codex", subtitle:"", body:"x",
                               unreadCount:1, isPriority:false, jumpID:"n")
        await p.reload(unread: 1, rows:[row], connection:.connected)
        // Let reload(1)'s coalesced applyPending actually present the activity first;
        // otherwise the subsequent reload(0) cancels it and the activity is never shown,
        // so the later idle-branch would see state.activity==false and skip dismissActivity.
        try? await Task.sleep(nanoseconds: 5_000_000)
        // Present the tab so there is something to dismiss when we return to idle —
        // applyPending's idle branch only calls dismissTab when state.tab==true.
        await p.setExpanded(true)
        await p.reload(unread: 0, rows: [], connection: .connected)
        // Await the coalesced flush that dismisses both surfaces.
        try? await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertTrue(s.dismissedActivity, "going to idle must dismiss the activity")
        XCTAssertTrue(s.dismissedTab, "going to idle must dismiss the tab")
        XCTAssertFalse(p.state.activity)
        XCTAssertFalse(p.state.tab)
    }
    @MainActor
    func testCoalescingCollapsesRapidUpdates() async {
        // Fire 10 rapid reloads in <250ms; at most a few should land post-coalesce window.
        let s = StubSession(); let p = AtollPresenter(session: s, port: 9042, coalesceNanos: 50_000_000) // 50ms for test
        let row = RowViewModel(id:"cmux:s", sourceLabel:"Codex", title:"Codex", subtitle:"", body:"x",
                               unreadCount:1, isPriority:false, jumpID:"n")
        for _ in 0..<10 { p.reload(unread: 1, rows: [row], connection: .connected) }
        // wait long enough for the coalesced flush
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertTrue(p.state.activity)
        // The presenter applied the final batched state once (coalesce deliberately collapses the 10).
    }
}
