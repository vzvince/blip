// Sources/Blip/InboxHTMLRenderer.swift
import Foundation

public enum InboxHTMLRenderer {
    /// Renders the collapsed inbox as inline HTML (≤20KB). Rows group by source; each row's onclick
    /// fetches the bridge's /jump?id=<row.id>; a "Clear all" link fetches /clear.
    /// Escapes user content; never injects raw HTML.
    public static func render(rows: [RowViewModel], unreadCount: Int, port: Int, includeHeader: Bool = true, compact: Bool = false) -> String {
        let base = "http://127.0.0.1:\(port)"
        if rows.isEmpty && unreadCount == 0 {
            return """
            <div style="font-family:-apple-system;padding:14px;text-align:center;color:#999">
              <div style="font-size:20px;margin-bottom:6px">✓</div>
              <div>All clear</div>
            </div>
            """
        }
        let padding = compact ? "0" : "10px 12px"
        var out = """
        <div style="font-family:-apple-system;padding:\(padding);color:#fff;font-size:13px;line-height:1.25">
        """
        if includeHeader {
            out += """
              <div style="font-weight:600;margin-bottom:8px;color:#fff">cmux · \(esc(String(unreadCount))) unread</div>
            """
        }
        for r in rows {
            let url = "\(base)/jump?id=\(esc(r.id, forURL: true))"
            let dot = r.isPriority ? "🔴" : "🔵"
            let countBadge = r.unreadCount > 1 ? "<span style='background:#444;color:#fff;border-radius:8px;padding:1px 6px;font-size:11px;margin-left:6px'>\(esc(String(r.unreadCount)))</span>" : ""
            out += """
            <div onclick="fetch('\(url)')" style="cursor:pointer;padding:7px;border-radius:8px;border:1px solid #333;background:rgba(255,255,255,0.035);margin-bottom:6px;color:#fff">
              <div style="font-weight:600"><span style="color:#8e8e93;font-size:11px">\(esc(r.sourceLabel))</span> \(dot) \(esc(r.title))\(countBadge)</div>
              <div style="color:#aaa;font-size:12px">\(esc(r.subtitle))</div>
              <div style="color:#ddd;font-size:13px;margin-top:2px">\(esc(r.body))</div>
            </div>
            """
        }
        if unreadCount > 0 {
            out += """
              <div style="text-align:center;margin-top:8px"><a href="\(base)/clear"
                style="color:#999;font-size:12px" onclick="event.preventDefault();fetch('\(base)/clear')">Clear all</a></div>
            """
        }
        out += "</div>"
        return out
    }

    static func esc(_ s: String, forURL: Bool = false) -> String {
        if forURL { return s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s }
        return s
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
