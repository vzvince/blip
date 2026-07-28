// Sources/Blip/ActionHandler.swift
import Foundation

public final class ActionHandler: ActionRouting {
    public let store: Store
    public let jump: JumpExecutor
    public init(store: Store, jump: JumpExecutor) {
        self.store = store; self.jump = jump
    }
    public func activate(rowID: String) {
        guard let row = store.rows().first(where: { $0.id == rowID }) else { return }
        let newest = store.snapshot().first { $0.id == row.jumpID }
        switch newest?.jump {
        case .cmuxSurface(let w, let s): if let newest { jump.openCmuxNotification(id: newest.id, workspaceId: w, surfaceId: s) }
        case .openApp(let bid): jump.openApp(bundleId: bid)
        case .some(.none), nil: break
        }
        store.markGroupRead(key: row.id)
    }
    public func clearAll() {
        store.clear()
        jump.clearCmux()
    }
}
