# v0.8 execution ledger

- User explicitly requested redesign after v0.7 playtest; no repeated design approval needed for this corrective implementation.
- Snapshot166files: ../原始人大作战_快照/20261115_before_motion_audio_094458. No visible Godot process at preflight.
- Root cause: old burn uses identical horizontal texture crop as roll with only thin colored lines; play_transition always roll, most UI routes ui_open, press_motion applies same inflation.
- Reference0.00–0.88seconds inspected frame by frame: anchored background, compacting logo and staged paper menus. Root adapts staging rather than copying unrelated FPS world.
- Applicable dispatch skill: independent audio and weapon-clearance agents own disjoint files; root owns UI rendering/integration. No app control delegated.
- Audio input was emitted but model received “audio content omitted because you do not support audio input”. Listening remains unverified; provide user audition and mixed native preview.

- Audio and weapon agents completed disjoint changes. Original audio kept;7 new semantic cues with4voice cap, silent hover. Projectile mounts shifted outward and8angle sprite/close-hit checks added;3second damage unchanged.
- First motion regression RED:9checks8failures for old horizontal burn, duration, paper clipping and navigation. Implementation GREEN; later native v1 found invalid downward flame polygons that headless checks did not render. Added24orientation triangulation checks, fixed local-normal flame shape, refined irregular char ribbons. Final motion40checks0failures.
- Full final regression tools/run_tests.ps1:15groups1209checks0failures, native v2 render log has no ERROR/SCRIPT ERROR/Parse Error/FAIL and reports0capture failures.
- Native v2 capture uses real input events,390frames/30fps/13seconds,12process screenshots. Viewed early/mid/late burn, mid fold, physical scroll, character arrows, weapon gameplay. Encoded MP4 decoded390frames with actual48kHzstereo engine mix (peak0.122925,RMS0.010764). No listening acceptance claimed.
- Snapshot comparison:28old assets and2playerJSON SHA256 unchanged. Tests/capture use runtime/tests, all old previews retained. Current machine-readable evidence docs/ui_v08_verification.json, details docs/ui_motion_audio_v08.md.
- Final independent read-only review found one P2: Stats button layered button_press and paper_popup. Real paused-HUD button routing reproduced42checks1failure in logs/v08_stats_audio_red.log; Stats is now transition-owned. Final full suite15groups1211checks0failures, including42motion/routing checks. No other blocking review findings.
- After review and regression, opened normal player-path v0.8 via console launcher (live exec session88936). Escalated read-only desktop query verified GUI PID20008, correct project engine path, title 原始人大作战 · 纸墨动效 v0.8 (DEBUG), handle1377558. logs/play_v08.log has no startup errors. Preserve window and hand control to user; no further input sent.

