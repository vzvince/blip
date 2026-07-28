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
