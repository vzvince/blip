// Sources/Blip/Cmux.swift
import Foundation
import Darwin

public enum CmuxError: Error { case badResponse, io(String), rpc(String) }

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
    static func date(_ d: [String:Any]) -> Date {
        let s = str(d, ["created_at","createdAt","created"])
        if !s.isEmpty {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let dt = iso.date(from: s) { return dt }
            let iso2 = ISO8601DateFormatter()      // without fractional seconds
            if let dt = iso2.date(from: s) { return dt }
        }
        return Date()
    }
    /// Maps a cmux `notification.list` response to model notifications.
    /// Accepts: a bare array `{...}`-wrapped under one of items/notifications/result,
    /// OR (when the response is a bare array) the parser that fed us should have wrapped it.
    /// Drops items already read (is_read == true OR read == true) or lacking a surface id.
    public static func mapList(_ response: [String:Any], includeAlreadyReadCreatedAfter cutoff: Date? = nil) -> [AgentNotification] {
        let result = response["result"] as? [String: Any]
        let arr = (response["items"] as? [[String:Any]])
               ?? (response["notifications"] as? [[String:Any]])
               ?? (response["result"] as? [[String:Any]])
               ?? (result?["notifications"] as? [[String:Any]])
               ?? (result?["items"] as? [[String:Any]])
               ?? (response["array"] as? [[String:Any]])
               ?? []
        return arr.compactMap { d -> AgentNotification? in
            let alreadyRead = (d["is_read"] as? Bool) == true || (d["read"] as? Bool) == true
            let createdAt = date(d)
            if alreadyRead {
                guard let cutoff, createdAt >= cutoff else { return nil }
            }
            let ws = str(d, ["workspaceId","workspace_id","workspace"])
            let sf = str(d, ["surfaceId","surface_id","surface"])
            guard !sf.isEmpty else { return nil }     // nothing to jump to
            let id = str(d, ["id","notification_id"])
            let title = str(d, ["title","workspace_name"])
            let subtitle = str(d, ["subtitle","sub"])
            let body = str(d, ["body","text"])
            let tab = str(d, ["tab_title","tabTitle"])
            return AgentNotification(
                id: id.isEmpty ? "cmux:\(sf):\(Date().timeIntervalSince1970)" : id,
                source: "cmux",
                title: title,
                subtitle: subtitle,
                body: body,
                createdAt: createdAt,
                priority: (str(d, ["priority"]) == "high") ? .high : .normal,
                jump: .cmuxSurface(workspaceId: ws, surfaceId: sf),
                sourceLabel: tab.isEmpty ? "cmux" : tab)
        }
    }

    public static func mapListData(_ data: Data, includeAlreadyReadCreatedAfter cutoff: Date? = nil) throws -> [AgentNotification] {
        let object = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
        if let items = object as? [[String: Any]] {
            return mapList(["array": items], includeAlreadyReadCreatedAfter: cutoff)
        }
        if let response = object as? [String: Any] {
            return mapList(response, includeAlreadyReadCreatedAfter: cutoff)
        }
        throw CmuxError.badResponse
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
        // NOTE: method `notification.list` returns a bare top-level JSON array (not an object).
        // The current `as? [String:Any]` cast throws `.badResponse` for that case. The poller
        // (Tasks 5/11) must special-case `notification.list` to parse with `as? [Any]` and wrap
        // as `["array": items]` before calling `CmuxMapper.mapList`. Resolved in Task 11.
        guard let obj = try? JSONSerialization.jsonObject(with: buf) as? [String:Any] else {
            throw CmuxError.badResponse
        }
        if (obj["ok"] as? Bool) == false {
            let error = obj["error"] as? [String: Any]
            let message = error?["message"] as? String ?? "cmux RPC failed"
            throw CmuxError.rpc(message)
        }
        return obj
    }

    /// Send a pre-encoded frame and return the raw response bytes (no JSON parsing).
    /// Use for methods like `notification.list` whose response is a bare top-level array
    /// (which `call` can't `as? [String:Any]`-cast). The caller parses `[Any]` with allowFragments.
    public func recvRaw(frame: Data) throws -> Data {
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
        return buf
    }
}
