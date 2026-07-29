// Sources/Blip/AtollSession.swift
import Foundation
import AppKit
import AtollExtensionKit

@MainActor
public final class AtollSession: AtollPresenting {
    public static let shared = AtollSession()
    public var onActivityDismiss: (() -> Void)?
    public var onTabDismiss: (() -> Void)?

    public var isAtollInstalled: Bool { AtollClient.shared.isAtollInstalled }
    public var isAtollRunning: Bool {
        AtollAvailability.knownBundleIdentifiers.contains { bundleID in
            !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
        }
    }
    public var shouldContactXPC: Bool {
        AtollAvailability.shouldContactXPC(isInstalled: isAtollInstalled, isRunning: isAtollRunning)
    }

    public func requestAuthorization() async throws -> Bool { try await AtollClient.shared.requestAuthorization() }
    public func isAuthorized() async throws -> Bool { try await AtollClient.shared.checkAuthorization() }
    public func presentActivity(_ d: AtollLiveActivityDescriptor) async throws { try await AtollClient.shared.presentLiveActivity(d) }
    public func updateActivity(_ d: AtollLiveActivityDescriptor) async throws { try await AtollClient.shared.updateLiveActivity(d) }
    public func dismissActivity() async throws { try await AtollClient.shared.dismissLiveActivity(activityID: AtollDescriptors.activityID) }
    public func presentTab(_ t: AtollNotchExperienceDescriptor) async throws { try await AtollClient.shared.presentNotchExperience(t) }
    public func updateTab(_ t: AtollNotchExperienceDescriptor) async throws { try await AtollClient.shared.updateNotchExperience(t) }
    public func dismissTab() async throws { try await AtollClient.shared.dismissNotchExperience(experienceID: AtollDescriptors.tabID) }
    public func registerDismiss() {
        AtollClient.shared.onActivityDismiss(activityID: AtollDescriptors.activityID) { [weak self] in self?.onActivityDismiss?() }
        AtollClient.shared.onNotchExperienceDismiss(experienceID: AtollDescriptors.tabID) { [weak self] in self?.onTabDismiss?() }
    }
}
