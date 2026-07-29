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
        var presentActivityCount = 0
        var updateActivityCount = 0
        var dismissActivityCount = 0
        var presentTabCount = 0
        var updateTabCount = 0
        var dismissTabCount = 0
        var presentActivityError: Error? = nil
        var presentTabError: Error? = nil
        func presentActivity(_ d: AtollLiveActivityDescriptor) async throws {
            presentActivityCount += 1
            if let error = presentActivityError { presentActivityError = nil; throw error }
            presentedActivity = true
        }
        func updateActivity(_ d: AtollLiveActivityDescriptor) async throws { updatedActivity = true; updateActivityCount += 1 }
        func dismissActivity() async throws { dismissedActivity = true; dismissActivityCount += 1 }
        func presentTab(_ d: AtollNotchExperienceDescriptor) async throws {
            presentTabCount += 1
            if let error = presentTabError { throw error }
            presentedTab = true
        }
        func updateTab(_ d: AtollNotchExperienceDescriptor) async throws { updatedTab = true; updateTabCount += 1 }
        func dismissTab() async throws { dismissedTab = true; dismissTabCount += 1 }
    }

    @MainActor
    func testFallbackSessionUsesFallbackWhenPrimaryPresentActivityFails() async throws {
        let primary = StubSession()
        let fallback = StubSession()
        primary.presentActivityError = NSError(domain: "rpc", code: -1005)
        let session = AtollFallbackSession(primary: primary, fallback: fallback)

        try await session.presentActivity(AtollDescriptors.collapsed(unreadCount: 1, latest: nil))

        XCTAssertEqual(primary.presentActivityCount, 1)
        XCTAssertEqual(fallback.presentActivityCount, 1, "Atoll RPC can accept then immediately drop 9020 connections; Blip must fall back to AtollExtensionKit/XPC instead of getting stuck")
    }

    @MainActor
    func testFallbackSessionDoesNotUseFallbackWhenPrimarySucceeds() async throws {
        let primary = StubSession()
        let fallback = StubSession()
        let session = AtollFallbackSession(primary: primary, fallback: fallback)

        try await session.presentActivity(AtollDescriptors.collapsed(unreadCount: 1, latest: nil))

        XCTAssertEqual(primary.presentActivityCount, 1)
        XCTAssertEqual(fallback.presentActivityCount, 0)
    }

    @MainActor
    func testFallbackSessionTriesFallbackForTabUpdatesToo() async throws {
        let primary = StubSession()
        let fallback = StubSession()
        primary.presentTabError = NSError(domain: "rpc", code: -1005)
        let session = AtollFallbackSession(primary: primary, fallback: fallback)

        try await session.presentTab(AtollDescriptors.tab(rows: [], unreadCount: 0, port: 9042))

        XCTAssertEqual(primary.presentTabCount, 1)
        XCTAssertEqual(fallback.presentTabCount, 1)
    }
    @MainActor
    func testIdlePresenterWithdrawsNothing() async {
        let p = AtollPresenter(session: StubSession(), port: 9042)
        p.reload(unread: 0, rows: [], connection: .connected)
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
        p.reload(unread: 1, rows: [row], connection: .connected)
        // Await the coalesced flush before asserting: reload() schedules applyPending()
        // via Task.sleep(coalesceNanos), so the presentActivity side-effect lands only after.
        try? await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertTrue(p.state.activity, "should present activity when unread>0")
        XCTAssertTrue(p.state.tab, "Atoll only shows message details in extension tabs, so unread messages must register the Blip tab immediately")
        XCTAssertEqual(s.presentTabCount, 1, "unread reload should make the Blip tab visible in Atoll's tab bar")
    }
    @MainActor
    func testExpandedBitFollowsExplicitOpen() async {
        let s = StubSession(); let p = AtollPresenter(session: s, port: 9042)
        let row = RowViewModel(id:"cmux:s", sourceLabel:"Codex", title:"Codex", subtitle:"", body:"x",
                               unreadCount:1, isPriority:false, jumpID:"n")
        p.reload(unread: 1, rows:[row], connection:.connected)
        await p.setExpanded(true)
        XCTAssertTrue(p.state.tab)
        await p.setExpanded(false)
        XCTAssertFalse(p.state.tab)
        XCTAssertTrue(s.dismissedTab, "collapsing the tab must call dismissTab (state flag alone is not enough)")
    }
    @MainActor
    func testBackToIdleDismissesAll() async {
        // 1ms coalesce so each reload's coalesced applyPending flushes promptly under test.
        let s = StubSession(); let p = AtollPresenter(session: s, port: 9042, coalesceNanos: 1_000_000)
        let row = RowViewModel(id:"cmux:s", sourceLabel:"Codex", title:"Codex", subtitle:"", body:"x",
                               unreadCount:1, isPriority:false, jumpID:"n")
        p.reload(unread: 1, rows:[row], connection:.connected)
        // Let reload(1)'s coalesced applyPending actually present the activity first;
        // otherwise the subsequent reload(0) cancels it and the activity is never shown,
        // so the later idle-branch would see state.activity==false and skip dismissActivity.
        try? await Task.sleep(nanoseconds: 5_000_000)
        // Present the tab so there is something to dismiss when we return to idle —
        // applyPending's idle branch only calls dismissTab when state.tab==true.
        await p.setExpanded(true)
        p.reload(unread: 0, rows: [], connection: .connected)
        // Await the coalesced flush that dismisses both surfaces.
        try? await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertTrue(s.dismissedActivity, "going to idle must dismiss the activity")
        XCTAssertTrue(s.dismissedTab, "going to idle must dismiss the tab")
        XCTAssertFalse(p.state.activity)
        XCTAssertFalse(p.state.tab)
    }

    @MainActor
    func testFailedPresentDoesNotMarkActivityShownSoNextReloadCanRetry() async {
        let s = StubSession()
        s.presentActivityError = NSError(domain: "atoll", code: 1)
        let p = AtollPresenter(session: s, port: 9042, coalesceNanos: 1_000_000)
        let row = RowViewModel(id:"cmux:s", sourceLabel:"Codex", title:"Codex", subtitle:"", body:"x",
                               unreadCount:1, isPriority:false, jumpID:"n")
        p.reload(unread: 1, rows: [row], connection: .connected)
        try? await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertFalse(p.state.activity, "failed Atoll present must not poison presenter state")

        p.reload(unread: 1, rows: [row], connection: .connected)
        try? await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertTrue(p.state.activity)
        XCTAssertEqual(s.presentActivityCount, 2, "second reload should retry present, not update a missing activity")
        XCTAssertEqual(s.updateActivityCount, 0)
    }

    @MainActor
    func testFailedTabPresentDoesNotMarkTabShown() async {
        let s = StubSession()
        s.presentTabError = NSError(domain: "atoll", code: 2)
        let p = AtollPresenter(session: s, port: 9042)
        let row = RowViewModel(id:"cmux:s", sourceLabel:"Codex", title:"Codex", subtitle:"", body:"x",
                               unreadCount:1, isPriority:false, jumpID:"n")
        p.reload(unread: 1, rows: [row], connection: .connected)
        await p.setExpanded(true)
        XCTAssertFalse(p.state.tab, "failed Atoll tab present must not poison presenter state")
        XCTAssertEqual(s.presentTabCount, 1)
    }


    @MainActor
    func testResetRemoteSurfacesDismissesStaleAtollActivityAndTabEvenWhenLocalStateIsIdle() async {
        let s = StubSession()
        let p = AtollPresenter(session: s, port: 9042)

        await p.resetRemoteSurfaces()

        XCTAssertEqual(s.dismissActivityCount, 1, "startup reset must dismiss stale Atoll live activity persisted from an older Blip build")
        XCTAssertEqual(s.dismissTabCount, 1, "startup reset must dismiss stale Atoll tab persisted from an older Blip build")
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
        XCTAssertEqual(s.presentActivityCount, 1, "10 rapid reloads must collapse to a single presentActivity, not 10")
        XCTAssertEqual(s.updateActivityCount, 0)
        // The presenter applied the final batched state once (coalesce deliberately collapses the 10).
    }
}
