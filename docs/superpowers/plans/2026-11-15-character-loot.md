# Character art and individual loot implementation plan

**Goal:** Deliver three visibly different playable characters and one physical pickup per base coin/XP, in the current non-Git project.
**Spec:** `docs/handoffs/2026-11-15-character-loot-continuation.md` and the delegated user request.
**Architecture:** Versioned imagegen body sprites; portraits rendered from ActorView itself. A shared unit-drop builder handles new rewards and legacy migration without consuming the combat RNG. Cache resource icons and cull off-screen drawing; retain every uncollected entity.
**Tech stack:** Godot 4.7.2, GDScript, built-in imagegen, existing PowerShell runner.

## Constraints and rulings

- Work in place; no Git/worktree, no old ZIP restoration. User explicitly authorized implementation without design approval pauses.
- Preserve character IDs, abilities, starter weapons, eggs, weapon arrangement, UI layout/transitions/music, and latest real player saves.
- Snapshot `character_loot_baseline_20261115_210401` protects current source/art; real run/settings files copied afterward. Fresh 33-group baseline passed.
- Every new pickup has value=1. Preserve valid legacy fractional XP via optional fractional entitlement on a unit, never convert it to coins/XP early. Integer legacy bundles split into exact independent units.
- Remove 240 auto-accounting; optimize iteration and drawing. Raise the separate save pickup limit so ordinary unit drops can actually round-trip. Keep bounded validation against corrupt/unallocatable legacy quantities.
- No normal player saves are used by tests or preview fixtures. No user data is restored from the baseline.

## Review focus

- Partial collection and repeated save/load must preserve both earned and remaining totals, including XP multipliers and fractional legacy XP.
- Moving the pickup count above 240 and 256 must neither collect nor reject ordinary drops.
- Migration must preserve combat RNG state and already-unit positions.
- Normal, elite, boss, egg, and stone deaths must each reward once; damage numbers and HUD totals stay visible.
- Character body, portrait, resumed identity and trial-mode stats must agree; transparent padding cannot distort limb anchors.

## Task 1: Unit drops and persistence

- [x] Add `tests/test_character_loot.gd`: literal 5XP/3coin => 8 units, independent partial pickup, save/load twice, legacy 5/3 migration, fractional legacy entitlement, >240 and >256 storage, every source reward once, XP multiplier.
- [x] Run against baseline and observe the intended failures.
- [x] Add shared `src/loot_drops.gd`; modify only the relevant pickup code in main/session_state/save_store/battle_visuals. Cache two native SVG icons and cull drawing. Keep gameplay RNG stream unchanged.
- [x] Update only obsolete package-count expectations in existing regressions. Re-run focused tests.

## Task 2: Versioned character art

- [x] Generate three body-only sprites with imagegen: orange-haired cheerful hunter, silver-haired teal-cloaked chief, black-haired fur-clad red-kilt brawler. Save prompts and originals under `assets/characters/v13/`.
- [x] Add actor/art consistency tests and observe failures before integration.
- [x] Configure Catalog, normalize body rendering to the existing 66px height and existing limb rig; render portraits from the same actor using a native viewport exporter.
- [x] Check all three at normal gameplay size and on existing selection screens.

## Task 3: Verification and delivery

- [x] Run the complete current suite with the added group. Record fresh counts, timings and source fingerprints.
- [x] Render native selection, combat, dispersed loot, partial collection, legacy continuation and a multi-thousand-pickup performance fixture using isolated storage.
- [x] Visually inspect native screenshots/video. Perform final read-only review of changes and preservation checks.
- [x] Recheck running process identity; normally close only a project game window if needed. Back up latest saves again, then open the normal updated game for play. Leave real progress intact.

## Progress

- Baseline: all 33 groups pass. Three generated body designs visually inspected, original assets untouched. No Godot process was running at initial process check.

- Final: 34 groups / 5273 checks, native 49/0, independent review clean after portrait-edge repair. 5000 visible independent units: native frame median 10.616ms, update median 0.773ms on this run. All 131 prior asset files and 19 protected source files unchanged. Four live player JSON files were backed up unchanged before opening the normal game.
- Opened normal v0.13 using the existing APPDATA storage; current executable, fresh process and native window title verified in docs/character_loot_v13_opened.json. No process was killed and no old save was restored.
- Desktop inspection helper could not initialize (kernel assets path error); validation uses Godot native viewport screenshots/movie and the launched process native window metadata. User visual acceptance and subjective listening remain unverified.
