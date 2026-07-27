// Sources/Blip/AtollRPCClient.swift
import Foundation
import AtollExtensionKit

public struct AtollRPCError: Error, CustomStringConvertible {
    public let message: String
    public let code: Int?
    public init(_ message: String, code: Int? = nil) {
        self.message = message
        self.code = code
    }
    public var description: String {
        if let code { return "Atoll RPC error \(code): \(message)" }
        return "Atoll RPC error: \(message)"
    }
}

public enum AtollRPCRequestFactory {
    public static func makeRequest(method: String, params: [String: String], id: String = UUID().uuidString) throws -> Data {
        let object: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": id,
        ]
        return try JSONSerialization.data(withJSONObject: object, options: [])
    }

    public static func makeDescriptorRequest<T: Encodable>(method: String, descriptor: T, id: String = UUID().uuidString) throws -> Data {
        let descriptorData = try JSONEncoder().encode(descriptor)
        guard let descriptorObject = try JSONSerialization.jsonObject(with: descriptorData) as? [String: Any] else {
            throw AtollRPCError("Descriptor did not encode to a JSON object")
        }
        let object: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
            "params": ["descriptor": descriptorObject],
            "id": id,
        ]
        return try JSONSerialization.data(withJSONObject: object, options: [])
    }
}

public enum AtollRPCValue: Sendable, Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case object([String: AtollRPCValue])
    case array([AtollRPCValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let i = try? c.decode(Int.self) { self = .int(i) }
        else if let d = try? c.decode(Double.self) { self = .double(d) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let o = try? c.decode([String: AtollRPCValue].self) { self = .object(o) }
        else if let a = try? c.decode([AtollRPCValue].self) { self = .array(a) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported RPC JSON value") }
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
}

public struct AtollRPCResponse: Sendable {
    private struct Envelope: Sendable, Decodable {
        struct ErrorObject: Sendable, Decodable {
            let code: Int?
            let message: String
        }

        let result: [String: AtollRPCValue]?
        let error: ErrorObject?
    }

    public let result: [String: AtollRPCValue]

    public var isSuccess: Bool { boolResult("success") == true }

    public func boolResult(_ key: String) -> Bool? { result[key]?.boolValue }

    public static func parse(_ data: Data) throws -> AtollRPCResponse {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        if let error = envelope.error {
            throw AtollRPCError(error.message, code: error.code)
        }
        guard let result = envelope.result else {
            throw AtollRPCError("JSON-RPC response missing result")
        }
        return AtollRPCResponse(result: result)
    }
}


public final class AtollRPCClient: @unchecked Sendable {
    public let url: URL
    public let bundleIdentifier: String
    private let timeoutNanos: UInt64

    public init(url: URL = URL(string: "ws://127.0.0.1:9020")!, bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "dev.blip", timeoutSeconds: Double = 3.0) {
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.timeoutNanos = UInt64(timeoutSeconds * 1_000_000_000)
    }

    public func requestAuthorization() async throws -> Bool {
        let response = try await send(try AtollRPCRequestFactory.makeRequest(
            method: "atoll.requestAuthorization",
            params: ["bundleIdentifier": bundleIdentifier]
        ))
        return response.boolResult("authorized") == true
    }

    public func checkAuthorization() async throws -> Bool {
        let response = try await send(try AtollRPCRequestFactory.makeRequest(
            method: "atoll.checkAuthorization",
            params: ["bundleIdentifier": bundleIdentifier]
        ))
        return response.boolResult("authorized") == true
    }

    public func presentActivity(_ d: AtollLiveActivityDescriptor) async throws {
        try await expectSuccess(method: "atoll.presentLiveActivity", descriptor: d)
    }

    public func updateActivity(_ d: AtollLiveActivityDescriptor) async throws {
        try await expectSuccess(method: "atoll.updateLiveActivity", descriptor: d)
    }

    public func dismissActivity(activityID: String) async throws {
        try await expectSuccess(try AtollRPCRequestFactory.makeRequest(
            method: "atoll.dismissLiveActivity",
            params: ["activityID": activityID, "bundleIdentifier": bundleIdentifier]
        ))
    }

    public func presentTab(_ d: AtollNotchExperienceDescriptor) async throws {
        try await expectSuccess(method: "atoll.presentNotchExperience", descriptor: d)
    }

    public func updateTab(_ d: AtollNotchExperienceDescriptor) async throws {
        try await expectSuccess(method: "atoll.updateNotchExperience", descriptor: d)
    }

    public func dismissTab(experienceID: String) async throws {
        try await expectSuccess(try AtollRPCRequestFactory.makeRequest(
            method: "atoll.dismissNotchExperience",
            params: ["experienceID": experienceID, "bundleIdentifier": bundleIdentifier]
        ))
    }

    private func expectSuccess<T: Encodable>(method: String, descriptor: T) async throws {
        try await expectSuccess(try AtollRPCRequestFactory.makeDescriptorRequest(method: method, descriptor: descriptor))
    }

    private func expectSuccess(_ request: Data) async throws {
        let response = try await send(request)
        guard response.isSuccess else { throw AtollRPCError("RPC call did not return success=true") }
    }

    private func send(_ request: Data) async throws -> AtollRPCResponse {
        try await withThrowingTaskGroup(of: AtollRPCResponse.self) { group in
            group.addTask { try await self.sendWithoutTimeout(request) }
            group.addTask {
                try await Task.sleep(nanoseconds: self.timeoutNanos)
                throw AtollRPCError("Timed out connecting to Atoll RPC at \(self.url.absoluteString)")
            }
            let first = try await group.next()!
            group.cancelAll()
            return first
        }
    }

    private func sendWithoutTimeout(_ request: Data) async throws -> AtollRPCResponse {
        let task = URLSession.shared.webSocketTask(with: url)
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }

        try await task.send(.data(request))
        let message = try await task.receive()
        let data: Data
        switch message {
        case .data(let d): data = d
        case .string(let s): data = Data(s.utf8)
        @unknown default: throw AtollRPCError("Unsupported WebSocket response")
        }
        return try AtollRPCResponse.parse(data)
    }
}
