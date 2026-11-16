# UI integration ledger

- User explicitly authorized in-game implementation and launch after reviewed concepts; proceeding inline.
- No Git repository. Snapshot: ../原始人大作战_快照/20261114_before_handdrawn_ui_231819 (148 files, hash manifest, player JSON included).
- Related chats notLoaded; no running Godot before baseline.
- Baseline: 12 groups, 1401 checks, 0 failures.
- Ruling: “选爸爸” interpreted as the contextual Buff/成长选择页面; unify its parchment animation without changing growth rules.
- Original player saves remain in place; tests and captures must inject runtime/tests stores.


- TDD: test_frontend first failed 13 required behaviors; routes, selector, real continue summary and protected startup implemented. Paper triangulation error reproduced and fixed via non-overlapping contour corners, with Geometry2D regression.
- Native foreground Godot captures and real InputEventMouseButton clicks exercise home -> cast -> settings/back -> continue/back -> cast -> burn/preparation/combat -> growth -> pause/shop. Tests inject a fresh runtime/tests store.
- Independent requesting-code-review reviewer found 3 Important issues: retry submission lock persisted after defeat, stale continue had no visible error/disabled confirm, and choice/shop card callbacks bypassed scroll lock. All reproduced in ui_review_red.log (7 assertions), fixed in one pass, and 49 frontend checks passed; no deferred findings.
- Native screenshot revealed logo minimum-size expansion. Added logo bounds/overlap regression (ui_logo_red.log, 6 failures), set EXPAND_IGNORE_SIZE before texture assignment and verified ui_logo_green.log (442 checks, 0 failures).
- Style: same approved arena background and transparent handcut wordmark; paper texture reuses concept material, card corners made square/flat. Existing runtime sprites kept rather than redrawing gameplay characters.
- Preserved 25 original non-import asset files and 2 player-save JSON files against the pre-change snapshot hashes. No processes stopped and no old previews removed.
- Ruling: no Git branch/worktree exists, so branch finishing/merge menu does not apply; changes remain in the authorized original project with snapshot rollback.

- Final verification: 13 groups, 1103 checks, 0 failures; 12 final native captures at previews/ui_v07_verified, all1280x800; logs/ui_native_verified.log clean. Original asset/player save hashes rechecked unchanged.

- Final normal launch: existing console launcher kept in exec session 65586, default project/runtime user data paths, logs/play_v07.log. OpenGL initialized. Direct GUI invocation returned without log; default-sandbox process enumeration was inconclusive, so used the bundled console launcher (same native game executable and project). No other process stopped.

- Desktop launch independently confirmed with unsandboxed read-only process lookup: PID10636, MainWindowHandle524458, title 原始人大作战 · 手绘营地 v0.7 (DEBUG), exact project engine path. Kept exec session65586 alive; no further game input sent.
