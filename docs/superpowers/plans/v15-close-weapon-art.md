# v15 compact weapon presentation

User requests closer weapon presentation, explicitly including the crossbow, and a small art polish while keeping the accepted game. Work in place from `docs/v15_baseline.json`; source SHA-256 matches the verified v14 baseline.

- [x] Add visible-center and actual-alpha torso-clearance regressions across all 14 weapons, stages 1/3/5, mixed loadouts and both formations. Observe the old excessive hold-offset failure.
- [x] Reduce the extra hold offset with per-weapon grip lengths. Bring parked anchors and the melee orbit moderately closer. Match idle bow/spear orientation to the existing outward presentation cone; retain full attack motion, projectile targeting/range, damage and skills. Melee hits follow the new actual orbit position.
- [x] Polish native SVG wood/bone/metal/crystal materials with subtle warm gradients and gemstone facets; preserve the existing hand-drawn contours, characters, UI, music and earlier PNG files.
- [x] Verify opacity overlap rather than padded texture rectangles: transparent margins must not force weapons far from the body.
- [x] Run the fresh complete regression suite, read-only review and native before/after single-bow + full-loadout previews. Preserve live saves and open the new normal game.

Evidence: 37 regression groups / 6601 checks, including 1242 presentation checks; native v4 has 13 checks / zero failures and clean engine plus console logs. The MP4 decodes all 487 frames at 60 fps with 8.116667 seconds of video and recorded audio. All 156 earlier asset files and 72 protected source files match the baseline; only main.gd, rules.gd, weapon_art.gd and expanded_weapons.gd changed in production. All four current player JSON files were backed up and match the initial baseline. Details: `docs/v15_verification.json`.

Read-only review found and verified the fix for bow idle rotation overwriting true firing direction; no remaining P1/P2. Four out-of-cone bow regressions were observed failing before the fix, then passing. Old row-distance assumptions were updated for the requested closer orbit. Native capture cleanup releases its world and file references before exit, eliminating the earlier recorder shutdown warning without changing gameplay. Earlier captures and diagnostic evidence remain preserved.

Normal v0.15 was opened using a fresh engine process, with executable path, versioned window title and nonzero native handle recorded in `docs/v15_opened.json`. Native final screenshots were inspected. User gameplay acceptance and subjective listening remain unclaimed.
