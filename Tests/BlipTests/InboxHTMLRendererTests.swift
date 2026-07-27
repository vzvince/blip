import XCTest
@testable import Blip
final class InboxHTMLRendererTests: XCTestCase {
    func testRowsRenderWithClickableOnclick() {
        let rows = [RowViewModel(id:"cmux:s", sourceLabel:"Codex Engine", title:"Codex", subtitle:"Waiting",
                                 body:"needs input", unreadCount:2, isPriority:false, jumpID:"n2")]
        let html = InboxHTMLRenderer.render(rows: rows, unreadCount: 2, port: 9042)
        XCTAssertTrue(html.contains("fetch('http://127.0.0.1:9042/jump?id=cmux:s')"))
        XCTAssertTrue(html.contains("Codex Engine"))   // sourceLabel now distinct & asserted
        XCTAssertTrue(html.contains("Codex"))           // title
        XCTAssertTrue(html.contains("needs input"))      // body
        XCTAssertLessThanOrEqual(html.utf8.count, 20000)
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
