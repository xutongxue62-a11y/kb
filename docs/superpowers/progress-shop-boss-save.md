# SDD ledger — plan: docs/superpowers/plans/2026-11-14-shop-boss-save.md

- Latest user request captured in shop-boss-save design; no repeated permission needed.
- Snapshot: ../原始人大作战_快照/20261114_v05_before_shop_boss_151158.
- Baseline: eight groups162/162 pass.
- Main owns shared integration; independent agents own SaveStore+tests and Armory+WeaponArt+tests only. Spec fixed their interfaces.
- Test stores must use injected runtime/tests paths. Existing user game may be running; do not close/relaunch it until the new version is ready.
- Task1 and Task2: in progress.
- SaveStore:128 checks passed, then known optional encounter/shop corruption validation extended;354 checks passed, all isolated runtime fixtures.
- Armory delegate failed transport before writing files. Root took over, observed missing-feature RED, implemented four mechanisms/icons; armory_first_green.log16/16 passed.
- Main: coin pickup, paid shop/end/leave, separate wave_elapsed, untimed Boss and save/continue integration written. Existing main-using tests now inject isolated SaveStore paths before add_child.
- XP pacing decision tightened to8 first, then8+level*3. No free completion growth.
- HUD delegate also failed transport before saving implementation; root took ownership, preserved its input-event/navigation tests and implemented all required menus. HUD228 checks pass.
- Tasks1–3 complete: Main/Campaign/Armory/Store/SessionState/Economy/HUD integrated; 12groups826/826 pass. Original162 retained with intentional XP/shop timing changes. Native8 captures succeeded and layouts inspected; home hides battleHUD, settings checked text readable, purchased tiers display accurately.
- Independent read-only review completed with3P2 findings. Added RED regressions for trial save failure, ended marker with autosave off, and invalid consumed restore counters; all fixed in one pass, whole suite green. No deferred minor findings.
- Asset preservation:32 original asset hashes,0 changed; no original image/audio/old preview removed. Task4 final documentation done; actual final launch remains.
- Task4 complete: original启动样板.cmd launched v0.6, parent exec session65530 kept alive. Native Windows window854456 title“原始人大作战 · 营地与Boss v0.6” observed; actual player battle showed gold43, drops, no permanent foot circles and successful save notice. User already had control; no further app input was sent.
- Final delivery: all requested changes saved,12groups826/826, native screenshots inspected,32original assets unchanged, snapshots retained. Long-session economy/Boss feel remains a user playtest decision.
