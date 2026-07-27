// Sources/Blip/Cmux.swift
import Foundation
import Darwin

public enum CmuxError: Error { case badResponse, io(String) }

public enum CmuxFrames {
    /// Encode one newline-terminated JSON-RPC request frame.
    public static func encode(id: String, method: String, params: [String: String]) -> Data {
        let payload: [String: Any] = ["id": id, "method": method, "params": params]
        var data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        data.append(0x0A) // newline-terminated
        return data
    }
}

public enum CmuxMapper {
    static func str(_ d: [String:Any], _ keys: [String]) -> String {
        for k in keys { if let s = d[k] as? String { return s } }
        return ""
    }
    /// Maps a `notification.list` response (one of: {items:[...]}, {notifications:[...]}, or a bare array) to model notifications.
    /// Items with read=true are dropped. Items lacking a surface id cannot be jumped to and are dropped.
    public static func mapList(_ response: [String:Any]) -> [AgentNotification] {
        let arr = (response["items"] as? [[String:Any]])
               ?? (response["notifications"] as? [[String:Any]])
               ?? (response["result"] as? [[String:Any]])
               ?? []
        return arr.compactMap { d -> AgentNotification? in
            if (d["read"] as? Bool) == true { return nil }
            let ws = str(d, ["workspaceId","workspace_id","workspace"])
            let sf = str(d, ["surfaceId","surface_id","surface"])
            guard !sf.isEmpty else { return nil }        // nothing to jump to
            let id = str(d, ["id","notification_id"])
            let body = str(d, ["body","text"])
            return AgentNotification(
                id: id.isEmpty ? "cmux:\(sf):\(Date().timeIntervalSince1970)" : id,
                source: "cmux",
                title: str(d, ["title","workspace_name"]),
                subtitle: str(d, ["subtitle","sub"]),
                body: body,
                priority: (str(d, ["priority"]) == "high") ? .high : .normal,
                jump: .cmuxSurface(workspaceId: ws, surfaceId: sf),
                sourceLabel: { let s = str(d, ["sourceLabel"]); return s.isEmpty ? "cmux" : s }())
        }
    }
}

/// Live client over the cmux control Unix socket.
public final class CmuxRPC: Sendable {
    public let socketPath: String
    public init(socketPath: String) { self.socketPath = socketPath }
    /// Sends one JSON-RPC frame; returns the parsed response object.
    public func call(method: String, params: [String:String] = [:], id: String = UUID().uuidString) throws -> [String:Any] {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw CmuxError.io("socket()") }
        defer { close(fd) }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        let pathMax = MemoryLayout.size(ofValue: addr.sun_path)
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            pathBytes.withUnsafeBufferPointer { bp in
                memcpy(ptr, bp.baseAddress, min(bp.count, pathMax))
            }
        }
        let connRes = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                connect(fd, saPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connRes == 0 else { throw CmuxError.io("connect \(socketPath)") }
        let frame = CmuxFrames.encode(id: id, method: method, params: params)
        _ = frame.withUnsafeBytes { buf in
            send(fd, buf.baseAddress, buf.count, 0)
        }
        var buf = Data()
        var tmp = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = recv(fd, &tmp, tmp.count, 0)
            if n <= 0 { break }
            buf.append(contentsOf: tmp.prefix(n))
            if tmp[0..<min(n, tmp.count)].contains(0x0A) { break }
        }
        guard let obj = try? JSONSerialization.jsonObject(with: buf) as? [String:Any] else {
            throw CmuxError.badResponse
        }
        return obj
    }
}
