# UI brush hover and rough parchment

Native execution, limited to the user's latest requested UI refinement. Preserve the current post-v16 changes, including weapon replacement/sellback, growth, save and pickup updates; baseline is `docs/ui_v22_baseline.json`, not the historical v16 snapshot.

- [x] Snapshot current source/assets/tests and real saves, record the latest user changes; establish the current 43-group baseline.
- [x] Add a pointer-entry hover cue with debounce, no disabled/hidden/busy-button sound, no repeated cue while staying on a button. Keep click/page/scroll cues intact.
- [x] Share a textured directional brush fill between home paper actions and other paper buttons: 0.18s left-to-right, feathered irregular front, fast retreat, immediate disabled state. Keep text readable and input paths unchanged.
- [x] Fray parchment/button silhouettes with deterministic edge chips and larger occasional tears, weathered edges and fine fibres; protect scroll content margins and physical roll caps. Existing source textures remain unchanged.
- [x] Add meaningful interaction/direction/geometry regressions, run the full current suite, and inspect native before/mid/after hover frames, opened scrolls and real hover audio playback.
- [x] Fresh-context read-only review, preserve latest saves, publish the local preview and open the updated game.

Implementation uses existing Godot canvas/shader and WAV assets. No external generation, gameplay changes, UI layout replacement or restoration from an old version. Tests and captures use isolated SaveStore paths. Headless checks prove state/geometry; native pixel checks and recorded audio separately verify the rendered sweep and emitted sound.

Evidence: latest 43-group baseline passed before edits. Final 44 groups / 8121 checks and native 11/0 pass; native pixels show left-to-right coverage at progress 0.185, 0.463 and 1.0. Three recorded hover cues correlate with the pitched source at 0.991. Independent review's deferred text-color flash was reproduced (2 RED) and fixed (24/0); no remaining P1/P2. All 156 previous asset files and 72 protected source files match the current-user baseline, Main differs only in the title and HUD only in hover binding. Four real-save JSON files were preserved and backed up. Native final3 images inspected; 308 decoded frames at 60fps with matching 5.133s audio/video. New normal v0.22 opened; evidence in docs/ui_v22_opened.json. User acceptance and subjective listening remain unclaimed.
