// Sources/Blip/IngressServer.swift
import Foundation
import Network

/// Minimal HTTP/1.1 server on 127.0.0.1 for /push /jump /ls /clear + OPTIONS.
/// Wiring is exercised in the app (Task 11); here it must compile and not crash on start.
public final class IngressServer: @unchecked Sendable {
    public let port: Int
    private let store: Store
    private let action: ActionRouting
    private var listener: NWListener?
    public init(port: Int, store: Store, action: ActionRouting) {
        self.port = port; self.store = store; self.action = action
    }
    public func start() throws {
        let params = NWParameters.tcp
        let l = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: UInt16(port)))
        l.newConnectionHandler = { [weak self] conn in
            guard let self else { conn.cancel(); return }
            conn.start(queue: .global())
            self.handle(conn)
        }
        self.listener = l
        l.start(queue: .global())
    }
    public func stop() { listener?.cancel(); listener = nil }
    private func handle(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, err in
            guard let self, let data, err == nil else { conn.cancel(); return }
            let req = HTTPParser.parse(data)
            // Observable request log — so the Task 8.5 webview click-back shows as `GET /jump?id=...`
            let qs = req.query.isEmpty ? "" : "?" + req.query.map { "\($0)=\($1)" }.joined(separator: "&")
            print("blip: ingress \(req.method) \(req.path)\(qs)")
            let res = IngressRoutes.respond(method: req.method, path: req.path,
                                            query: req.query, body: req.body,
                                            store: self.store, action: self.action, port: self.port)
            conn.send(content: HTTPParser.makeResponse(res), completion: .contentProcessed { _ in conn.cancel() })
        }
    }
}

enum HTTPParser {
    static func parse(_ data: Data) -> (method:String, path:String, query:[String:String], body:Data) {
        guard let str = String(data: data, encoding: .utf8) else { return ("GET","",[:],Data()) }
        let parts = str.components(separatedBy: "\r\n\r\n")
        let line = (parts.first ?? "").components(separatedBy: " ")
        let method = line.first ?? "GET"
        let rawPath = line.count > 1 ? line[1] : "/"
        let p = rawPath.split(separator: "?", maxSplits: 1).map(String.init)
        let path = p.first ?? "/"
        var query: [String:String] = [:]
        if p.count > 1 {
            for kv in p[1].split(separator: "&") {
                let pair = kv.split(separator: "=", maxSplits: 1).map(String.init)
                if pair.count == 2 { query[pair[0]] = pair[1].removingPercentEncoding ?? pair[1] }
            }
        }
        let body = parts.count > 1 ? (parts[1].data(using: .utf8) ?? Data()) : Data()
        return (method, path, query, body)
    }
    static func makeResponse(_ res: IngressResponse) -> Data {
        var h = res.headers
        h["Content-Length"] = "\(res.body.count)"
        let head = "HTTP/1.1 \(res.statusCode) OK\r\n" + h.map { "\($0.key): \($0.value)" }.joined(separator: "\r\n")
        return (head + "\r\n\r\n").data(using: .utf8)! + res.body
    }
}
