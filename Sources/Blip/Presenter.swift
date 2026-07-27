// Sources/Blip/Presenter.swift
import Foundation
import AtollExtensionKit

/// The swappable presentation surface (Atoll island v1, menu bar v2). @MainActor
/// because presenters drive the @MainActor AtollSession and read @MainActor state.
@MainActor
public protocol Presenter: AnyObject {
    func reload(unread: Int, rows: [RowViewModel], connection: ConnectionState)
    func clearAll()
    func setExpanded(_ on: Bool) async
}

/// The slice of AtollSession the presenter needs — injected so the state machine
/// is testable without a live XPC session. Task 11 makes AtollSession conform (or wraps it).
/// @MainActor because the real AtollSession is @MainActor; this keeps the cross-actor
/// "sending" check satisfied when the @MainActor presenter calls into the session.
@MainActor
public protocol AtollPresenting: AnyObject {
    func presentActivity(_ d: AtollLiveActivityDescriptor) async throws
    func updateActivity(_ d: AtollLiveActivityDescriptor) async throws
    func dismissActivity() async throws
    func presentTab(_ d: AtollNotchExperienceDescriptor) async throws
    func updateTab(_ d: AtollNotchExperienceDescriptor) async throws
    func dismissTab() async throws
}
