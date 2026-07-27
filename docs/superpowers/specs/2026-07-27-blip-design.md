# Blip — Design Spec

- **Date:** 2026-07-27
- **Status:** Draft — brainstormed, pending implementation plan
- **Repo:** `~/Development/global_notifications/Blip`

## 1. Problem

cmux (and other AI-coding-agent / terminal harnesses) fire notifications that are easy to miss: the macOS banner lasts seconds, and cmux's in-window unread badges are invisible when you are focused on another app. We want a **system-level, persistent, always-visible** indicator of pending agent notifications — show unread count, expand to a list with content, and **click a row to jump back to the originating terminal**.

Scope now **(A)**: persistent global indicator + list + click-to-jump. **Deferred (B)**: periodic reminders until acknowledged.

## 2. Solution in one line

`Blip` is a native SwiftUI macOS agent app (no Dock icon, `LSUIElement`) that aggregates notifications from multiple agent / terminal sources and presents them either as an **Atoll Dynamic Island extension** (v1) or a **macOS menu-bar app** (v2), behind a swappable `Presenter` port. **Neither cmux nor Atoll source is modified** — both expose public APIs (cmux control socket; `AtollExtensionKit` SDK).

## 3. Non-goals / deferred

- Periodic re-reminders **(B)**.
- Per-agent rich adapters beyond the generic push adapter.
- Cross-machine / remote aggregation.
- Read-history search.

## 4. Architecture

```
[cmux socket]            [Codex CLI hook]    [Claude Code hook]    [any script]
   │ notification.list       │ push              │ push                │ push
   ▼                          ▼                   ▼                    ▼
┌────────────────────── Ingress (127.0.0.1:PORT + CLI: blip push) ────────────┐
│                              ↓                                                │
│              Store (source-agnostic model + dedup + read/clear + reconcile)   │
│                              ↓                                                │
│              Presenter (port)                                                │
│   ├ AtollPresenter (v1): live-activity + notch tab (interactive webContent)  │
│   └ MenuBarPresenter (v2): NSStatusItem + SwiftUI popover                     │
└───────────────────────────────────────────────────────────────────────────────┘
                              ↓ row click (localhost callback)
                ActionHandler → cmux surface.focus / open -a / mark read
```

**Isolation:** Ingress knows nothing of Store internals; Store knows nothing of Presenter tech; Presenter knows nothing of how notifications arrive. Each is independently testable. Adding `MenuBarPresenter` is purely additive — one new file, zero changes elsewhere.

## 5. Components

### 5.1 Ingress / CLI
- Local HTTP server on `127.0.0.1:<port>` (from config).
- `blip push -s <source> -t <title> [-b <body>] [--subtitle <s>] [--workspace-id <id> --surface-id <id>] [--priority <p>]` — universal adapter; any agent/CI can call it.
- `blip ls`, `blip focus <id>`, `blip clear`.
- Validates payload; drops malformed silently + logs.

### 5.2 Source adapters
- **cmux adapter:** every ~1.5s (config), connect to `${CMUX_SOCKET_PATH:-/tmp/cmux.sock}` and send `{"id":"...","method":"notification.list","params":{}}`; map returned notifications → `AgentNotification{source:"cmux", workspaceId, surfaceId, ...}`; reconcile store to reflect cmux read/clear state. Backoff while the socket is absent.
- **generic push adapter:** parse CLI/HTTP payload → `AgentNotification{source:<given>, jump:.none | .openApp(bundleId)}`.
- Each adapter maps to the common model and depends only on the Store's upsert/clear APIs.

### 5.3 Store (common model)
```swift
struct AgentNotification {
    let id: String                 // stable; cmux notif id, or a uuid for push
    let source: String             // "cmux" | "codex" | "claude-code" | custom
    let title, subtitle, body: String
    let createdAt: Date
    let priority: Priority         // .normal | .high
    let jump: JumpTarget           // .cmuxSurface(workspaceId, surfaceId) | .openApp(bundleId) | .none
    let sourceLabel: String        // group display label, e.g. "Codex"
}
```
- In-memory ring (last 200) + JSON snapshot on disk for restore.
- Dedup by `(source, id)`. Unread set. `clear()` / `markRead(id)`.
- Surfaces `ConnectionState` (`.connected` / `.disconnected`) to presenters.

### 5.4 Presenter port
```swift
protocol Presenter {
    func reload(unread: Int, items: [RowViewModel], connection: ConnectionState)
    func activate(itemID: ItemID)   // user clicked a row
    func clearAll()
}
```
- Shared `RowViewModel` + shared `ActionHandler` so both presenters route clicks the same way.

**v1 `AtollPresenter`:**
- Collapsed `AtollLiveActivityDescriptor` (persistent id `blip.inbox`): icon + unread badge; `sneakPeekTitle/Subtitle` shows the newest arrival; `allowsMusicCoexistence`.
- Expanded `AtollNotchExperienceDescriptor` (persistent id `blip.inbox.tab`), presented/updated/dismissed via `AtollClient.presentNotchExperience` / `updateNotchExperience` / `dismissNotchExperience`, teardown via `onNotchExperienceDismiss`. Tab title "Blip" + unread badge; footer = totals + "Clear all". Updates coalesced at 250ms to respect Atoll rate limits.
- **List rendering + click-back (verified against AtollExtensionKit source):** `tab.webContent = AtollWidgetWebContentDescriptor(html:, preferredHeight:, isTransparent:, allowLocalhostRequests: true, allowRemoteRequests: false, ...)`, `allowWebInteraction = true`. The `html` is a small inline list (≤20KB) of rows grouped by source; each row's onclick does `fetch("http://127.0.0.1:<port>/jump?id=<notifId>")`. The bridge's local HTTP server handles `/jump?id=` → `ActionHandler.activate(id)`. `allowLocalhostRequests` is the SDK switch that lets the sandboxed webview reach the bridge — no Atoll source changes. Bridge server replies with `Access-Control-Allow-Origin: *`; use a simple GET so no CORS preflight is needed.

**v2 `MenuBarPresenter`** (later): `NSStatusItem` with unread badge + SwiftUI popover list; same rows, same ActionHandler.

### 5.4.1 Atoll island — product logic (states & interactions)

Two island surfaces, both via `AtollClient`:
- **Collapsed indicator** — `AtollLiveActivityDescriptor` (id `blip.inbox`): leading Blip icon (app icon / SF Symbol `bell.badge.fill`), trailing = unread count, `allowsMusicCoexistence`.
- **Expanded inbox tab** — `AtollNotchExperienceDescriptor` (id `blip.inbox.tab`): title "Blip" + unread badge; body = inline HTML list grouped by source; footer = "Clear all".

**States:**
| State | When | Island shows |
|---|---|---|
| Idle | unread = 0 | Nothing — Blip withdraws entirely; island is Atoll's normal surface. "Stays out of the way until needed." |
| Attention | unread ≥ 1, collapsed | Indicator: icon + count; each new arrival also fires a `sneakPeek` HUD (title + subtitle). |
| Expanded | user hovers/clicks the indicator, or hotkey | Inbox tab: grouped list; each row is clickable → jump. |

**Transitions:**
- Idle → Attention: first unread → `presentLiveActivity` + `sneakPeek`.
- Attention → Expanded: hover/click indicator → `presentNotchExperience`; badge copied into the tab header.
- Expanded → Attention: collapse/close. If unread ≥ 1, keep the indicator; if user clicked rows down to 0 → Idle.
- Attention/Expanded → Idle: unread hits 0 → `dismissLiveActivity` + `dismissNotchExperience` → island clears.

**New-arrival behavior:**
- Increment unread badge; if collapsed, `sneakPeek` (title + subtitle of newest); if tab open, push the row live (coalesced 250 ms).
- **Collapse repeats:** same surface/source already unread → fold into that surface's single row with a count badge and latest body (an agent waiting repeatedly = one row, not a wall). Generic-push sources (jump = none) group by source.

**Row click (exact):**
- Row onclick → `ActionHandler.activate(id)` → `surface.focus {surface_id}` (pin-point) → bring cmux to front.
- Mark that notification read; badge decrements; row becomes read-styled (visible until tab close, like a browser inbox).
- Keep the tab open so the user can act on more rows; only collapse to Idle when unread hits 0 or on explicit "Clear all"/close.

**Grouping & ordering:**
- High priority first, then newest. Row body shows the latest text; count badge = # unread on that surface. Sources ordered by latest activity.

**Clear semantics:**
- Per-row clear / click-to-read: bridge-local mark-read + best-effort reflect to cmux (cmux `notification.clear` is all-or-nothing in the documented API, so per-id clear may not be sent; rely on cmux read-state via next poll/reconcile).
- "Clear all" (footer): mark all read → `notification.clear` to cmux → dismiss indicator + tab → Idle.
- Read in cmux's own panel: next poll (or push + reconcile) drops the item → badge decrements → may go Idle.

**Atoll absent / unauthorized (v1):**
- Blip keeps ingest + store running; island surfaces no-op; resume presenting on `onAuthorizationChange → true` or when Atoll launches.
- **v1 decision (strict Atoll-only):** when Atoll is down/unauthorized, the indicator disappears entirely; the menu bar is deferred to v2 — consistent with the explicit v1=Atoll-only / v2=menubar choice.
- **Recommended later upgrade (cheap flip):** since the `Presenter` port is already abstracted, switching to "MenuBarPresenter auto-fallback whenever Atoll is absent" is one new file — recommended if always-on presence matters (the original motivation leans this way). Can be adopted before or during v2 without touching Store/Ingress.

### 5.5 ActionHandler
- `activate(id)`: resolve `jump`: `.cmuxSurface(_, surfaceId)` → `{"method":"surface.focus","params":{"surface_id":<id>}}` via cmux socket (pin-point); on failure → `workspace.select` → fallback `open -a cmux`. `.openApp(bundleId)` → `open -b <bundleId>`. `.none` → mark read only. Then `markRead(id)` + reload presenters.
- `clearAll()`: `store.clear()` + send `{"method":"notification.clear"}` to cmux to sync.

## 6. Data flow
- **Ingest:** cmux poll loop / external push → Ingress → `store.upsert(id, row)`.
- **Present:** Store change → `AtollPresenter.reload` (coalesced) updates the live-activity (badge + latest) and the notch tab (HTML list).
- **Interact:** row click (HTML `fetch("http://127.0.0.1:<port>/jump?id=<id>")`) → `ActionHandler.activate(id)` → cmux/open → mark read → Store → reload. "Clear all" is symmetric.
- **Lifecycle:** Atoll `onNotchDismiss` / `onActivityDismiss` → tear down the corresponding resources.

## 7. Why "只通知一次" gets fixed
- Unread count badge **persists in the island until cleared** — visible system-wide regardless of focused app.
- Per-arrival `sneakPeek` HUD re-surfaces title/subtitle, in addition to the (already-suppressed-when-focused) desktop banner.
- Expanded tab = actionable inbox, not a transient toast.

## 8. One-time environment setup
- **cmux:** enable external socket access — `CMUX_SOCKET_MODE=allowAll` (env) or via cmux Settings. (Default mode blocks non-cmux processes.)
- **Atoll:** Settings → Extensions → authorize the Blip app; enable "Allow extension notch experiences" + "Show extension tabs".
- Build Blip, launch once, grant any system prompts.

## 9. Error handling
- **Atoll absent/unauthorized:** `AtollPresenter` no-ops; keep ingest + store running; one-time desktop nudge "Authorize Blip in Atoll"; resume on `onAuthorizationChange`. If `MenuBarPresenter` is also enabled, it keeps showing.
- **cmux socket absent / not `allowAll`:** cmux adapter shows `.disconnected`; generic push still works; `surface.focus` degrades to `open -a cmux`. Retries with backoff.
- **Malformed payload:** drop + log.
- **Atoll rate-limit / invalid descriptor:** SDK throws → catch + backoff; respect limits (title 50/100 chars, payload ≤5MB, sections ≤6, notch height 160–420, tab badge valid).
- **Duplicates / stale:** dedup by `(source, id)`; reconcile read/clear from the cmux poll.

## 10. Risks / open questions (resolve in impl spike; non-blocking)
1. ~~`AtollWidgetWebContentDescriptor` fields unknown / click-back unclear.~~ **RESOLVED (favorably) by reading AtollExtensionKit source:** `webContent` = inline `html: String` (≤20KB) rendered in a WKWebView, with explicit `allowLocalhostRequests: Bool` + `allowWebInteraction`. Island-list row clicks `fetch` the bridge's localhost HTTP server; bridge replies with CORS `Access-Control-Allow-Origin: *`. **Remaining spike (cheap):** one-line test in `AtollXcodeSampleApp` — `webContent.html` with `<button onclick="fetch('http://127.0.0.1:9999/x')">`, a tiny localhost listener, click, confirm the request lands and wire ACAO. Insurance fallback (only if the sandbox blocks localhost despite the flag): promote `MenuBarPresenter` to v1 as the click-exact-row surface; the island live-activity still does the persistent count badge.
2. cmux `notification.list` **response shape is undocumented** in cmux's client docs (only the request format is documented). The adapter needs each item to carry a stable `id` (dedup), `workspaceId`/`surfaceId` (jump target), and read/unread state (count + reconcile). Spike to settle, in order:
   1. `export CMUX_SOCKET_MODE=allowAll` (or enable in cmux Settings) — required for **any** external-bridge access (polling **and** `surface.focus`).
   2. `cmux notify --title T --body B` to create a notification.
   3. `printf '{"id":"q","method":"notification.list","params":{}}' | nc -U "${CMUX_SOCKET_PATH:-/tmp/cmux.sock}"` → read the returned JSON, note per-item fields.
   - If it carries id + workspaceId + surfaceId + read-state → **pull path** (design as written).
   - If thinner → **push path**: add a `notifications.hooks` entry in `~/.config/cmux/cmux.json` whose command pipes the hook JSON (which DOES carry `workspaceId`/`surfaceId`/title/subtitle/body/effects, verified) into `blip`; the bridge owns read/unread state and back-syncs clears via `notification.clear`. `surface.focus` still works — it only needs `surfaceId`, which the hook provides.
3. Codex non-cmux hook surface: confirm Codex CLI's event/notify hook; else rely on "Codex in cmux" (covered by the cmux adapter) or wire via generic `blip push`.
4. `AtollExtensionKit` breaking-change risk — pin the package version.
5. Update cadence / rate-limit headroom — coalesce to avoid Atoll limiting.

## 11. Testing
- **Unit:** Store upsert/dedup/clear/reconcile; `JumpTarget` resolution; adapter payload parsing (fixtures of cmux `notification.list` + Codex/Claude payloads); `RowViewModel` mapping.
- **Integration:** local cmux socket stub + `blip push` / `cmux notify` round-trip → assert Atoll descriptors emitted; row-click handler → assert `surface.focus` call shape.
- **SDK:** `ExtensionDescriptorValidator.validate` over our descriptors; confirm within size/length limits; smoke-test against a sample notifier (the `AtollXcodeSampleApp` pattern) before wiring to live Atoll.
- **Manual checklist:** authorize in Atoll → `cmux notify --title X --body Y` → see count + list → click → verify jump to that surface; disconnect socket → verify state; restart Blip → verify store restore.

## 12. Scope (YAGNI) — v1
- cmux adapter (poll) + generic push adapter.
- `AtollPresenter` (live-activity + notch tab with interactive webContent).
- Jump-back (`surface.focus`) + clear sync to cmux.
- Store with persistence.
- CLI: `push` / `ls` / `focus` / `clear`.
- Defined `Presenter` protocol + shared `RowViewModel`/`ActionHandler` (so v2 menu bar is additive).

**Deferred (v2+):** `MenuBarPresenter`; per-agent rich adapters; periodic reminders **(B)**; cross-machine.

## 13. Repo layout (initial)
```
Blip/
  README.md
  .gitignore
  Package.swift            (added in plan phase)
  Sources/Blip/...         (added in plan phase)
  docs/superpowers/specs/2026-07-27-blip-design.md   (this doc)
```
