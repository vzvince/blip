# Blip Menu Bar Open Experience Design

## Goal
Make `open Blip.app` feel visible and trustworthy while preserving Blip as a lightweight companion app.

## Chosen Approach
Use a macOS menu bar app experience. Blip remains `LSUIElement=true` so it does not occupy Dock space, but opening it creates a persistent menu bar item with a recognizable bell badge icon and a status menu.

## User Experience
- `open Blip.app` starts Blip and shows a menu bar item.
- The menu bar label shows unread count when there are pending notifications.
- Clicking the menu shows:
  - unread count;
  - Atoll installed/running status;
  - cmux socket path;
  - actions: send test notification, clear all, quit.
- Finder shows a Blip app icon via `Blip.icns`.

## Architecture
Add a small pure `MenuBarStatus` formatter in the `Blip` library so labels are testable without AppKit UI. `BlipEngine` publishes unread count and status values, and `BlipApp.body` renders a `MenuBarExtra` scene. App icon packaging remains script-driven: `Resources/Blip.icns` is copied into `Blip.app/Contents/Resources`, and `Info.plist` declares `CFBundleIconFile`.

## Non-goals
- No full preferences window in this change.
- No Dock icon.
- No custom drawn menu popover beyond standard SwiftUI menu items.
