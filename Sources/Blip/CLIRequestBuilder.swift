// Sources/Blip/CLIRequestBuilder.swift
import Foundation

public enum CLIRequestBuilder {
    public static func push(base: URL, source: String, title: String, body: String,
                            workspaceId: String?, surfaceId: String?, priority: String?) -> URLRequest {
        var obj: [String:Any] = ["source": source, "title": title, "body": body]
        if let w = workspaceId { obj["workspaceId"] = w }
        if let s = surfaceId { obj["surfaceId"] = s }
        if let p = priority { obj["priority"] = p }
        var req = URLRequest(url: base.appendingPathComponent("push"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: obj)
        return req
    }
    public static func ls(base: URL) -> URLRequest {
        var req = URLRequest(url: base.appendingPathComponent("ls"))
        req.httpMethod = "GET"
        return req
    }
    public static func focus(base: URL, id: String) -> URLRequest {
        var comp = URLComponents(url: base.appendingPathComponent("jump"), resolvingAgainstBaseURL: false)!
        comp.queryItems = [URLQueryItem(name: "id", value: id)]
        var req = URLRequest(url: comp.url!)
        req.httpMethod = "GET"
        return req
    }
    public static func clear(base: URL) -> URLRequest {
        var req = URLRequest(url: base.appendingPathComponent("clear"))
        req.httpMethod = "POST"
        return req
    }
}
