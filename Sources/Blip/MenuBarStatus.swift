// Sources/Blip/MenuBarStatus.swift
import Foundation

public struct MenuBarStatus: Sendable, Equatable {
    public let unreadCount: Int
    public let atollInstalled: Bool
    public let atollRunning: Bool
    public let cmuxSocket: String

    public init(unreadCount: Int, atollInstalled: Bool, atollRunning: Bool, cmuxSocket: String) {
        self.unreadCount = unreadCount
        self.atollInstalled = atollInstalled
        self.atollRunning = atollRunning
        self.cmuxSocket = cmuxSocket
    }

    public var title: String {
        unreadCount > 0 ? "Blip \(unreadCount)" : "Blip"
    }

    public var systemImage: String {
        unreadCount > 0 ? "bell.badge.fill" : "bell"
    }

    public var atollLine: String {
        switch (atollInstalled, atollRunning) {
        case (true, true): return "Atoll: installed, running"
        case (true, false): return "Atoll: installed, not running"
        case (false, _): return "Atoll: not installed"
        }
    }

    public var cmuxLine: String { "cmux: \(cmuxSocket)" }
}
