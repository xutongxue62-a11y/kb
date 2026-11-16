# SDD ledger — plan: docs/superpowers/plans/2026-11-16-v16-art-performance.md

Ruling: Native in-place execution in the existing non-Git project, backed by an immutable source/assets/save snapshot — preserves the user's established launch path and accepted game.
Ruling: Use code-native SVG/part art instead of a raster replacement — the repo already renders its weapon/enemy additions this way and animated hinges need separable parts.
Pre-flight: Tasks 1 and 2 share only support impact art; combat remains driven by existing events. Task 3 profiles the same simulation fixture before and after. Task 4 reads the final hashes and isolated capture paths.

Task 1: complete. Immutable baseline contains 466 files and matches v15 source hashes. Ordinary ground chase is 225px/s with acceleration, contact stopping, distance-driven feet and articulated wings. Added RED/GREEN regressions for leash-edge contact, 286px/s player travel for 30s, and offscreen regroup without long beams. Final support group: 199/0; existing supports/feedback remain green.

Task 2: complete. Fifteen bounded six-frame ink caches replace repeated immediate impact/smoke geometry; fourteen weapon families remain visually distinct. Expanded fire/drum/crystal visuals use the same art. Lv3/Lv5 weapon constructions strengthened within the accepted footprint. Decorative words limited to six; actual damage numbers intact. Art tests: 75/0; all 1242 v15 pose checks pass. Native effect/weapon sheets inspected.

Task 3: complete. All eight monster types have original-silhouette-masked surface details; source PNGs unchanged. Normal terrain movement excludes distant rock polygons. Review found initial embedded double-rock recovery outside the original sweep; the exact fixture failed 2 assertions, then passed after retaining the full legacy neighbourhood for initial recovery. Terrain group: 165/0. Loot presentation uses two instance batches; all 5000 unit objects remain separate and unmodified. Native MultiMesh readback: 6/0; headless Dummy cannot read transforms and explicitly defers that check to the native run.

Task 4: complete. Final full suite: 42 groups / 7092 checks, zero failures. Native v4: 14/0, clean engine and console logs, 600 decoded video frames at 60fps with 10.0s recorded audio/video. Final sheets and walking/combat images inspected. Fresh-context read-only review confirmed the follower and embedded-stone P2 fixes; no remaining P1/P2. Verification: docs/v16_verification.json.

Performance: same initial 42-enemy, six-max-weapon, two-max-support, 1500-unit fixture and seed, native OpenGL, no recording, vsync off. Simulation median 6.350→5.136ms; native frame median 26.666→20.158ms, p95 36.354→35.390ms. All 42 enemies and at least 1500 uncollected resources remain. Hardware/scheduling limits are recorded, not generalized to all scenes.

Preservation: all 156 earlier asset files and 67 protected source files match baseline; all four current real-save JSON files were independently backed up and stayed unchanged during tests. New normal v0.16 window verified using a fresh executable identity, versioned title and nonzero native handle; startup evidence in docs/v16_opened.json. User acceptance and subjective listening remain unclaimed.
