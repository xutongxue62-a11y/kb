# SDD ledger — plan: docs/superpowers/plans/2026-11-14-playtest-buffs.md

- Preflight: old chat inactive (failed/systemError), Godot process list empty.
- Snapshot: ../原始人大作战_快照/20261114_v02_before_buffs_122728, source/tests/assets SHA256 manifest, 58 files.
- Baseline: rules 24, scene 19, controls 10, attack_links 28; 81/81 pass.
- Native execution: no Git repository; preserve snapshot and this ledger instead of git-only workspace/commit scripts. User explicitly authorized implementation and direct launch.
- Shared interfaces: main and HUD consume Growth.BUFFS/stats/choices; companions consumes the same stats; progression handles XP choices and wave rewards independently.
- Decision: use three 30-second waves and exploration pickup/XP Buff; retain 90-second choice as assistant's playtest decision.

Task 1: complete. growth_red.log failed for missing Buff rules; growth_green.log 14/14 passed. Added all 16 non-weapon growth choices and mixed-category selection. Confirmed existing fork-shaped sling artwork; display name is now 弹弓, internal ID unchanged.

Task 2: in progress.
Task 2: complete. feedback_red.log failed on missing scene integration; feedback_first_integration.log 28/28 passed. Existing rules/scene/controls/attack_links 81/81 retained; complete suite 123/123 passed before review.

Task 3: in progress. Native game opened through original launch script with foreground shell session kept alive (tool detached child lifetime otherwise ended the game). Observed real growth screen and active follower status; Chinese card content fits at current displayed window size.

Final review: independent read-only reviewer found one P2: pet could prioritize an unreachable elite spitter outside its leash. pet_target_red.log reproduced it (29 checks, 1 failure). Filter by leash plus bite reach before elite prioritization; re-run full suite below.
Review boundaries: final documentation/UI verification remain executor work; subjective difficulty, audiovisual quality and artwork remain user playtest acceptance, not static review claims.
Continuation: Task3 documentation/native verification completed in v0.5 during the user's subsequent playtest adjustments. README/design_v0.5/verification now current; eight groups162/162;32 original asset hashes unchanged. Follow progress-opening-impact.md for final launch status. Historical v0.3 interactive inspection ended when the user pressedEscape; no further Windows inputs were sent in that turn.
