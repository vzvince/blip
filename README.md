# Blip

> A blip on the radar when agents need you.

A native macOS app that aggregates notifications from multiple AI-coding-agent / terminal sources (cmux, Codex, Claude Code, any CLI) and surfaces them in the **Atoll Dynamic Island** (v1) — and, later, a **macOS menu-bar app** (v2): a persistent unread-count indicator, an expandable list, and click-a-row-to-jump-back-to-that-terminal.

- **No source modification.** Reads cmux via its public control socket; renders via `AtollExtensionKit` (Atoll's third-party extension SDK). Neither cmux nor Atoll is forked.
- **Multi-source by design.** A generic `blip push` CLI lets any agent / CI feed events; a cmux adapter mirrors its native notification stream.
- **Swappable surface.** A `Presenter` port means the island and the menu bar are interchangeable implementations sharing one store and one action handler.

## Status
Design phase. See the [design spec](docs/superpowers/specs/2026-07-27-blip-design.md).


## Quick look
```sh
blip push -s codex        -t "Build failed"   -b "see logs"          # any source
blip ls                                                       # current inbox
blip focus <id>                                               # jump to that terminal
blip clear                                                    # clear all
```



## Build note
Fresh builds need `GIT_LFS_SKIP_SMUDGE=1` because the AtollExtensionKit dep has a broken
LFS pointer (a `.mov` asset not stored on the remote). Run:
```sh
GIT_LFS_SKIP_SMUDGE=1 swift build      # or swift test
```
Once `.build/checkouts/AtollExtensionKit` is cached, plain `swift build` works in that clone.
