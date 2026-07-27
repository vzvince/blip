// Sources/Blip/AtollAvailability.swift
import Foundation

public enum AtollAvailability {
    public static func shouldContactXPC(isInstalled: Bool, isRunning: Bool) -> Bool {
        isInstalled && isRunning
    }
}

public enum AtollAvailabilityError: Error, Sendable {
    case notRunning
}
