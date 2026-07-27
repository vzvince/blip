// Sources/Blip/IngressRoutes.swift
import Foundation

/// Routing target the ingress layer needs from an action handler. Task 6's concrete
/// `ActionHandler` conforms to this.
public protocol ActionRouting: AnyObject {
    func activate(rowID: String)
    func clearAll()
}

public struct IngressResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data
    public static let cors: [String:String] = [
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type"
    ]
}

public enum IngressRoutes {
    public static func respond(method: String, path: String, query: [String:String],
                               body: Data, store: Store, action: ActionRouting, port: Int) -> IngressResponse {
        if method == "OPTIONS" {
            return IngressResponse(statusCode: 200, headers: IngressResponse.cors, body: Data())
        }
        let h = IngressResponse.cors
        switch (method, path) {
        case ("POST", "/push"):
            guard let obj = try? JSONSerialization.jsonObject(with: body) as? [String:Any] else {
                return json(400, ["error":"bad json"], cors: h)
            }
            store.upsert(PushPayload.make(for: obj))
            return IngressResponse(statusCode: 204, headers: h, body: Data())
        case ("GET", "/jump"):
            guard let id = query["id"], !id.isEmpty else {
                return json(400, ["error":"missing id"], cors: h)
            }
            action.activate(rowID: id)
            return IngressResponse(statusCode: 204, headers: h, body: Data())
        case ("GET", "/ls"):
            let rows = store.rows().map { row -> [String:Any] in
                ["id": row.id, "source": row.sourceLabel, "title": row.title,
                 "subtitle": row.subtitle, "body": row.body,
                 "unread": row.unreadCount, "priority": row.isPriority ? "high":"normal",
                 "jumpID": row.jumpID]
            }
            return json(200, ["unread": store.unreadCount, "items": rows], cors: h)
        case ("POST", "/clear"), ("GET", "/clear"):
            action.clearAll()
            return IngressResponse(statusCode: 204, headers: h, body: Data())
        default:
            return json(404, ["error":"not found"], cors: h)
        }
    }
    static func json(_ code: Int, _ obj: [String:Any], cors h: [String:String]) -> IngressResponse {
        var hh = h; hh["Content-Type"] = "application/json"
        let data = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data()
        return IngressResponse(statusCode: code, headers: hh, body: data)
    }
}

public enum PushPayload {
    public static func make(for d: [String:Any]) -> AgentNotification {
        let s = (d["source"] as? String) ?? "unknown"
        let title = (d["title"] as? String) ?? ""
        let body = (d["body"] as? String) ?? ""
        let ws = d["workspaceId"] as? String ?? d["workspace_id"] as? String
        let sf = d["surfaceId"] as? String ?? d["surface_id"] as? String
        let pri = (d["priority"] as? String) == "high" ? Priority.high : .normal
        let id = (d["id"] as? String) ?? "\(s):\(sf ?? "?"):\(Date().timeIntervalSince1970)"
        let jump: JumpTarget
        if let sf = sf, !sf.isEmpty, let ws = ws, !ws.isEmpty {
            jump = .cmuxSurface(workspaceId: ws, surfaceId: sf)
        } else if let bid = d["openAppBundleId"] as? String {
            jump = .openApp(bundleId: bid)
        } else {
            jump = .none
        }
        return AgentNotification(id: id, source: s, title: title,
                                 subtitle: d["subtitle"] as? String ?? "", body: body,
                                 priority: pri, jump: jump, sourceLabel: d["sourceLabel"] as? String)
    }
}
