# v16 art and performance implementation plan

> **For agentic workers:** Use superpowers:executing-plans for native implementation and one fresh-context final review.

**Goal:** Refine combat art and support motion while keeping dense combat responsive and v15 spacing intact.
**Architecture:** Native SVG caches for reusable combat art and articulated support parts; keep simulation and rendering separate. Measure changes against an immutable v15 snapshot.
**Tech stack:** Godot 4.7.2 / GDScript, native SVG, local PyAV capture encoding.
**Spec:** `docs/superpowers/specs/2026-11-16-v16-art-performance-design.md`.

## Global constraints
Work in place in this non-Git project using a sibling immutable snapshot. Keep v15 spacing, UI, characters, music, catalog stats, recipes, loot and save compatibility. Tests/captures use isolated SaveStore paths. Old source art and previews are retained. No claims of user acceptance or general hardware performance.

## Review focus
Ground pet must not slide, fly, bite at range or cross blocked terrain; flyer must visibly articulate wings. Art must not change collision geometry or v15 alpha clearance. Visual resource caches must stay bounded. Render optimization must not suppress rewards, projectiles or required telegraphs. HUD state transitions remain immediate.

### Task 1: Baseline and support motion
- [x] Snapshot current files/saves and run tagged deterministic stress benchmark.
- [x] Add RED tests for bounded acceleration/speed, foot phase from actual travel, stationary feet and distinct articulated wings.
- [x] Implement `companions.gd` motion and cached part renderer `support_rig.gd`; preserve contact damage, terrain and existing support tests.
- [x] Run new support tests and existing support/terrain regression.

### Task 2: Combat and weapon art
- [x] Add RED render-boundary tests for distinct cached impact silhouettes, stage evolution and bounded texture cache.
- [x] Implement `combat_art.gd`; integrate with effects and expanded persistent fields. Keep effect lifetimes and actual attack radii.
- [x] Strengthen per-weapon Lv3/Lv5 art in `weapon_art.gd` without changing the v15 footprint.
- [x] Run existing effect/weapon/evolution/presentation tests and native art sheets.

### Task 3: Monster polish and measured optimizations
- [x] Refine monster surface/material details without changing body canvas, origins or combat radii.
- [x] Use baseline profiler to choose update/render hotspots; add behavioral regressions before changing them.
- [x] Compare tagged before/after stress samples and bounded live resources; keep all units and combat active.

### Task 4: Verification and handoff
- [x] Full suite, final native capture and independent read-only review; fix any P1/P2 then reverify affected code and suite.
- [x] Preserve latest live saves; write v16 notes and machine-readable evidence, encode and inspect preview.
- [x] Open a fresh normal v16 game and report the result concisely with preview.
