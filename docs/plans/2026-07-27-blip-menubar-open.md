# Blip Menu Bar Open Experience Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `open Blip.app` visibly start Blip by adding a menu bar item and a Finder app icon.

**Architecture:** Add a pure `MenuBarStatus` model in the Blip library for testable menu labels. Wire `BlipApp` to a SwiftUI `MenuBarExtra` backed by published `BlipEngine` state. Add `Resources/Blip.icns`, declare it in `Info.plist`, and package it into the `.app` bundle.

**Tech Stack:** Swift 6, SwiftUI `MenuBarExtra`, SwiftPM, XCTest, macOS `.icns` bundle resources.

---

### Task 1: Menu bar status model

**Files:**
- Create: `Sources/Blip/MenuBarStatus.swift`
- Create: `Tests/BlipTests/MenuBarStatusTests.swift`

**Step 1: Write failing tests**
- Verify title is `Blip` at unread 0.
- Verify title is `Blip 3` at unread 3.
- Verify status lines include Atoll running/not running and cmux socket.

**Step 2: Run RED**
Run: `swift test --filter MenuBarStatusTests`
Expected: compile fails because `MenuBarStatus` does not exist.

**Step 3: Implement minimal model**
Add a public sendable struct with computed `title`, `systemImage`, `atollLine`, `cmuxLine`.

**Step 4: Run GREEN**
Run: `swift test --filter MenuBarStatusTests`
Expected: tests pass.

### Task 2: App icon metadata and packaging

**Files:**
- Modify: `Resources/Info.plist`
- Modify: `Scripts/package-app.sh`
- Create: `Resources/Blip.icns`
- Create: `Tests/BlipTests/BundleMetadataTests.swift`

**Step 1: Write failing tests**
- Verify `Resources/Info.plist` has `CFBundleIconFile=Blip`.
- Verify `Scripts/package-app.sh` references copying `Resources/Blip.icns` into `Contents/Resources`.

**Step 2: Run RED**
Run: `swift test --filter BundleMetadataTests`
Expected: fails because icon metadata/copy is absent.

**Step 3: Implement metadata and asset**
Generate `Resources/Blip.icns`, add plist key, and update package script to copy it.

**Step 4: Run GREEN**
Run: `swift test --filter BundleMetadataTests`
Expected: tests pass.

### Task 3: SwiftUI MenuBarExtra wiring

**Files:**
- Modify: `Sources/BlipApp/main.swift`

**Step 1: Wire menu bar scene**
- Replace empty Settings-only body with `MenuBarExtra` plus empty Settings.
- Expose `BlipEngine.status` computed property using `MenuBarStatus`.
- Publish unread count on store changes.
- Add menu actions: test notification, clear all, quit.

**Step 2: Verify build**
Run: `swift test` and release package command.
Expected: tests pass and `built Blip.app`.

**Step 3: Manual smoke**
Run `open Blip.app`, confirm menu bar item appears; use menu test notification and clear all.

**Step 4: Commit**
Commit source, tests, docs, icon, and packaging changes; do not commit `session.txt`.
