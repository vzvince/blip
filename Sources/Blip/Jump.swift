// Sources/Blip/Jump.swift
import Foundation
import Darwin

/// Executes the physical jump/focus/clear against the terminal host (cmux) or the OS.
public protocol JumpExecutor: AnyObject {
    func focusSurface(workspaceId: String, surfaceId: String)
    func openApp(bundleId: String)
    func clearCmux()
}

/// Live jump executor: drives the cmux control socket; falls back to bringing cmux to front.
public final class CmuxJumpExecutor: JumpExecutor {
    public let rpc: CmuxRPC
    public init(rpc: CmuxRPC) { self.rpc = rpc }
    public func focusSurface(workspaceId: String, surfaceId: String) {
        do {
            _ = try rpc.call(method: "surface.focus", params: ["surface_id": surfaceId])
        } catch {
            // fallback: bring cmux to front (user can then ⌘⇧U to latest unread)
            _ = try? Self.shell("/usr/bin/open", ["-a", "cmux"])
        }
    }
    public func openApp(bundleId: String) {
        _ = try? Self.shell("/usr/bin/open", ["-b", bundleId])
    }
    public func clearCmux() {
        _ = try? rpc.call(method: "notification.clear", params: [:])
    }
    private static func shell(_ exe: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        try p.run()
    }
}
