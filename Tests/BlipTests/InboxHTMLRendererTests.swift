import XCTest
@testable import Blip
final class InboxHTMLRendererTests: XCTestCase {

    func testRowsRenderAsLocalhostAnchorsForAtollNavigationDelegate() {
        let rows = [RowViewModel(id:"cmux:s", sourceLabel:"Codex Engine", title:"Codex", subtitle:"Waiting",
                                 body:"needs input", unreadCount:1, isPriority:false, jumpID:"n2")]
        let html = InboxHTMLRenderer.render(rows: rows, unreadCount: 1, port: 9042, includeHeader: false, compact: true)
        XCTAssertTrue(html.contains(#"href="http://127.0.0.1:9042/jump?id=cmux:s""#), "Atoll WKWebView explicitly allows localhost navigations; anchors are more reliable than fetch-only onclick handlers")
        XCTAssertFalse(html.contains(#"onclick="fetch('http://127.0.0.1:9042/jump"#), "row activation should not depend solely on fetch from an about:blank web view")
    }

    func testRowsRenderWithClickableJumpAnchor() {
        let rows = [RowViewModel(id:"cmux:s", sourceLabel:"Codex Engine", title:"Codex", subtitle:"Waiting",
                                 body:"needs input", unreadCount:2, isPriority:false, jumpID:"n2")]
        let html = InboxHTMLRenderer.render(rows: rows, unreadCount: 2, port: 9042)
        XCTAssertTrue(html.contains(#"href="http://127.0.0.1:9042/jump?id=cmux:s""#))
        XCTAssertTrue(html.contains("Codex Engine"))   // sourceLabel now distinct & asserted
        XCTAssertTrue(html.contains("Codex"))           // title
        XCTAssertTrue(html.contains("needs input"))      // body
        XCTAssertLessThanOrEqual(html.utf8.count, 20000)
    }

    func testCompactRowsRenderShortClickableListWithoutClearLink() {
        let rows = [
            RowViewModel(id:"n1", sourceLabel:"/very/long/workspace/path", title:"First", subtitle:"Waiting", body:"body one", unreadCount:1, isPriority:false, jumpID:"n1"),
            RowViewModel(id:"n2", sourceLabel:"Other", title:"Second", subtitle:"Waiting", body:"body two", unreadCount:1, isPriority:false, jumpID:"n2"),
            RowViewModel(id:"n3", sourceLabel:"Third", title:"Third", subtitle:"Waiting", body:"body three", unreadCount:1, isPriority:false, jumpID:"n3"),
            RowViewModel(id:"n4", sourceLabel:"Fourth", title:"Fourth", subtitle:"Waiting", body:"body four", unreadCount:1, isPriority:false, jumpID:"n4")
        ]
        let html = InboxHTMLRenderer.render(rows: rows, unreadCount: 4, port: 9042, includeHeader: false, compact: true)
        XCTAssertTrue(html.contains("First"))
        XCTAssertTrue(html.contains("Second"), "Atoll compact mode should still show a message list, not only one card")
        XCTAssertTrue(html.contains("Third"), "Atoll compact mode should fit several rows without nested scrolling")
        XCTAssertFalse(html.contains("Fourth"), "Atoll compact list should cap visible rows to avoid clipping")
        XCTAssertFalse(html.contains("/clear"), "Atoll compact card should reserve height for notifications")
        XCTAssertTrue(html.contains("text-overflow:ellipsis"), "long workspace labels should not push messages out of view")
    }

    func testCompactRowsFitAtollClippedPanelWithoutNestedCardsOrScrolling() {
        let rows = [
            RowViewModel(id:"n1", sourceLabel:"global_notifications", title:"First", subtitle:"Waiting", body:"body one", unreadCount:1, isPriority:false, jumpID:"n1"),
            RowViewModel(id:"n2", sourceLabel:"global_notifications", title:"Second", subtitle:"Waiting", body:"body two", unreadCount:1, isPriority:false, jumpID:"n2"),
            RowViewModel(id:"n3", sourceLabel:"global_notifications", title:"Third", subtitle:"Waiting", body:"body three", unreadCount:1, isPriority:false, jumpID:"n3"),
            RowViewModel(id:"n4", sourceLabel:"global_notifications", title:"Fourth", subtitle:"Waiting", body:"body four", unreadCount:1, isPriority:false, jumpID:"n4")
        ]
        let html = InboxHTMLRenderer.render(rows: rows, unreadCount: 4, port: 9042, includeHeader: false, compact: true)

        XCTAssertTrue(html.contains("height:28px"), "Atoll clips embedded web views; compact rows must be thin enough for several rows to be visible without scrolling")
        XCTAssertTrue(html.contains("+1 more"), "when rows are capped, the visible content should hint that more notifications exist")
        XCTAssertFalse(html.contains("border:1px"), "avoid drawing a nested card inside Atoll's own card; the double border wastes visible height and makes clipping look broken")
        XCTAssertTrue(html.contains("margin:0"), "reset default HTML/body margin so Atoll does not crop the first row")
        XCTAssertFalse(html.contains("overflow:auto"), "Atoll nested web view scrolling is unreliable; compact content must not depend on scrolling")
    }

    func testCompactRowsUseFetchOnClickAsFallbackForAtollTopLevelWebContent() {
        let rows = [RowViewModel(id:"n1", sourceLabel:"cmux", title:"Needs input", subtitle:"", body:"body", unreadCount:1, isPriority:false, jumpID:"n1")]
        let html = InboxHTMLRenderer.render(rows: rows, unreadCount: 1, port: 9042, includeHeader: false, compact: true)

        XCTAssertTrue(html.contains(#"href="http://127.0.0.1:9042/jump?id=n1""#))
        XCTAssertTrue(html.contains(#"onclick="event.preventDefault();fetch('http://127.0.0.1:9042/jump?id=n1')""#), "Atoll top-level web content may not navigate anchors; use fetch as an activation fallback")
    }

    func testEmptyState() {
        let html = InboxHTMLRenderer.render(rows: [], unreadCount: 0, port: 9042)
        XCTAssertTrue(html.lowercased().contains("all clear"))
        XCTAssertFalse(html.contains("/clear"))
    }
    func testHtmlEscapesAngleBrackets() {
        let rows = [RowViewModel(id:"x", sourceLabel:"X", title:"a<b>c", subtitle:"", body:"d&e<f>g",
                                 unreadCount:1, isPriority:false, jumpID:"x")]
        let html = InboxHTMLRenderer.render(rows: rows, unreadCount:1, port:9042)
        XCTAssertTrue(html.contains("a&lt;b&gt;c"))
        XCTAssertFalse(html.contains("<script"))   // never inject
    }
    func testPriorityIndicatorPresent() {
        let rows = [RowViewModel(id:"x", sourceLabel:"X", title:"T", subtitle:"", body:"B",
                                 unreadCount:1, isPriority:true, jumpID:"x")]
        let html = InboxHTMLRenderer.render(rows: rows, unreadCount:1, port:9042)
        XCTAssertTrue(html.contains("🔴"))   // priority dot
    }
    func testClearAllLinkCallsClear() {
        let rows = [] as [RowViewModel]
        let html = InboxHTMLRenderer.render(rows: rows, unreadCount: 1, port: 9042)
        XCTAssertTrue(html.contains("fetch('http://127.0.0.1:9042/clear')"))
    }
}
