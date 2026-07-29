import Foundation
import AtollExtensionKit

/// Tries a preferred Atoll transport first and falls back to another transport when
/// the preferred transport is unavailable. This keeps Blip resilient across Atoll
/// builds where the localhost RPC server is present but drops connections, while
/// the XPC service is still usable.
@MainActor
public final class AtollFallbackSession: AtollPresenting {
    public typealias FallbackObserver = (_ operation: String, _ error: Error) -> Void

    private let primary: AtollPresenting
    private let fallback: AtollPresenting
    private let onFallback: FallbackObserver?

    public init(primary: AtollPresenting, fallback: AtollPresenting, onFallback: FallbackObserver? = nil) {
        self.primary = primary
        self.fallback = fallback
        self.onFallback = onFallback
    }

    public func presentActivity(_ d: AtollLiveActivityDescriptor) async throws {
        try await run("presentActivity", primary: { try await primary.presentActivity(d) }, fallback: { try await fallback.presentActivity(d) })
    }

    public func updateActivity(_ d: AtollLiveActivityDescriptor) async throws {
        try await run("updateActivity", primary: { try await primary.updateActivity(d) }, fallback: { try await fallback.updateActivity(d) })
    }

    public func dismissActivity() async throws {
        try await run("dismissActivity", primary: { try await primary.dismissActivity() }, fallback: { try await fallback.dismissActivity() })
    }

    public func presentTab(_ d: AtollNotchExperienceDescriptor) async throws {
        try await run("presentTab", primary: { try await primary.presentTab(d) }, fallback: { try await fallback.presentTab(d) })
    }

    public func updateTab(_ d: AtollNotchExperienceDescriptor) async throws {
        try await run("updateTab", primary: { try await primary.updateTab(d) }, fallback: { try await fallback.updateTab(d) })
    }

    public func dismissTab() async throws {
        try await run("dismissTab", primary: { try await primary.dismissTab() }, fallback: { try await fallback.dismissTab() })
    }

    private func run(_ operation: String, primary: () async throws -> Void, fallback: () async throws -> Void) async throws {
        do {
            try await primary()
        } catch {
            onFallback?(operation, error)
            try await fallback()
        }
    }
}
