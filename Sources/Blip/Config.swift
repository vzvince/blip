// Sources/Blip/Config.swift
import Foundation

public struct BlipConfig: Codable {
    public var port: Int = 9042
    public var cmuxSocket: String = ProcessInfo.processInfo.environment["CMUX_SOCKET_PATH"] ?? "/tmp/cmux.sock"
    public var cmuxUseHookPush: Bool = false
    public var pollIntervalSeconds: Double = 1.5
    public var sources: [String] = ["cmux"]
    public static let path = "\(NSHomeDirectory())/.config/blip/config.json"
    public static func load() -> BlipConfig {
        (try? JSONDecoder().decode(BlipConfig.self, from: Data(contentsOf: URL(fileURLWithPath: path)))) ?? .init()
    }
}
