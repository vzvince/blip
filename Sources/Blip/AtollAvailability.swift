// Sources/Blip/AtollAvailability.swift
import Foundation

public enum AtollAvailability {
    public static let knownBundleIdentifiers: Set<String> = [
        "com.Ebullioscopic.Atoll",
        "com.ebullioscopic.Atoll",
    ]

    public static func isKnownAtollBundleIdentifier(_ bundleIdentifier: String) -> Bool {
        knownBundleIdentifiers.contains(bundleIdentifier)
    }

    public static func shouldContactXPC(isInstalled: Bool, isRunning: Bool) -> Bool {
        isInstalled && isRunning
    }
}

public enum AtollAvailabilityError: Error, Sendable {
    case notRunning
}
