# Distribution Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline, preserving the existing non-Git project and dated snapshots. Track task results in the release preparation ledger.

**Goal:** Deliver Windows/Linux archives and a signed Android APK, with an offline-safe, signed content-update entry point.

**Architecture:** Reuse Godot 4.7.2 and stage only runtime files. A release-only bootstrap mounts verified content before dynamically loading the unchanged gameplay scene. Server configuration is empty until the owner supplies hosting.

**Tech Stack:** Godot/GDScript, Python standard library, official templates, Noto Sans SC OFL.

**Spec:** `docs/superpowers/specs/2026-11-16-distribution-design.md`

## Global Constraints

- Preserve approved UI v31, original assets and current player saves.
- No external publishing or invented download address.
- Version 0.23.0, build 2026111601, launcher API 1, engine 4.7.2.
- Signing private key remains outside project and exported archives.
- No silent engine upgrade; no installation or termination of unrelated applications.

## Review Focus

- Missing Chinese fonts on Linux/web: explicitly force fallback in a font test.
- Stale, altered, truncated or incompatible updates: reject before activation.
- Wrong content cached during preload: bootstrap loads packs before loading game code.
- Accidental inclusion of player progress or keys: archive allowlist inspection.
- Platforms unavailable on this machine: report export and runtime evidence separately.

### Task 1: Reproducible exports and fonts

Files: `tools/build_release.py`, `src/game_fonts.gd`, font call sites in HUD/actor/effects/main, `tests/test_distribution_fonts.gd`.

- [x] Snapshot live source/art/saves and verify official template hash.
- [x] Write and run a failing Chinese fallback test.
- [x] Add bundled OFL font fallback while preserving Windows font selection.
- [x] Build isolated Windows, Linux and Android presets with runtime-only resources; retain Linux executable permissions and sign APK with private release key.

### Task 2: Signed content-update bootstrap

Files: `release/bootstrap.gd`, `release/update_policy.gd`, `release/update_client.gd`, bootstrap scene/config/public key, `tests/test_release_updates.gd`, publisher signing script.

- [x] RED: cover signature mismatch, stale build, wrong platform/engine/API, bad hash/length, and interrupted download.
- [x] GREEN: validate signed manifest and downloaded file; atomically register; keep the previous usable package.
- [x] Load cached content before the game scene; offline/no-feed launch makes no network request.
- [x] Exercise local signed update through real HTTP and launch twice to verify activation on next startup.

### Task 3: Android access

Files: touch module and small movement integration, tests and capture fixture if requested scope includes mobile.

- [x] User confirmed Windows, Linux, Android only; no macOS or Web export.
- [x] RED/GREEN: separate movement finger and action finger, release on focus loss/pause; desktop keyboard behavior preserved.
- [x] Verify the Android APK and native Windows touch simulation; explicitly record that Linux/Android device runs remain unavailable.

### Task 4: Release verification and handoff

- [x] Run the full formal suite plus distribution tests; inspect native Windows exported game.
- [x] Inspect package contents, hashes and platform executable formats; compare protected art/saves with fresh baseline.
- [x] Request one independent read-only review of release/update changes.
- [x] Deliver actual archives, usage/update instructions and explicit per-platform verification limits.
