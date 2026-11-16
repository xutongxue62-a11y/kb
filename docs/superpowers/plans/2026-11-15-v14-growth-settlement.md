# v14: weapon milestones and round settlement

User authorizes direct implementation in the current non-Git project. Baseline and live player JSON files are protected by `docs/v14_baseline.json`. Preserve v13 images, IDs, class abilities, eggs, weapon mounts, UI layout and music.

## Decisions

- Remove the hero's cyan silhouette shader; retain original ink, ground shadow and player marker. Render new portraits into `assets/characters/v14/`, using the same ActorView as battle.
- Weapon milestones at level 3 and 5. Levels 1/2 retain current behavior. Existing 1–5 saves derive all milestones from weapon level, without new persisted counters or irreversible conversions.
- Club: periodic quake / faster stronger quake. Axe: defeat cleave / periodic cleave. Blade: echo cut / cross cut. Sling: twin shot / ricocheting triple shot. Powder: lingering fire / radial shrapnel. Staff: four bolts / piercing five bolts.
- Spear: fan thrust / second thrust. Hammer: outer shock / delayed second slam. Boomerang: two passes / three passes. Totem: four jumps / branching lightning. Bonebow: twin arrows / three arrows with deeper pierce. Firepot: two pots / three pots. Wardrum: four beats / five-beat finisher. Crystal: eight shards / rearmed second burst.
- Native hand-drawn upgrade ornaments (bone spikes, metal bands, runes/gems) extend existing weapon art. HUD and offer icons use the same derived textures; cards describe milestone unlocks without changing layout.
- Only add three coherent optional pairs: firepot + wardrum fans existing fire; crystal + totem charges nearby mines; bonebow + totem conducts lightning and suppresses standalone totem fire. Preserve existing valid recipes and no-link choice. No automatic pairing and no three-weapon stacking.
- Round sequence: dismiss living enemies without damage/kill/drop callbacks; absorb only existing physical drops/chests; resolve earned XP and chest choices; then open the shop with final totals. Save/resume during absorption or choices must not duplicate rewards.

## Work

- [x] Fresh baseline suite; protect source, art and current player files.
- [x] Write failing settlement/outline and milestone/combination behavior tests.
- [x] Implement absorption and resumable reward-to-shop flow; remove hero outline and export versioned portraits.
- [x] Implement all weapon milestones, stage textures, two-line upgrade descriptions, and three optional pairs.
- [x] Run full suite, independent review and native milestone/round-settlement previews.
- [x] Preserve latest player files again; normally launch the updated game for play.

## Review focus

- A cleared elite/egg may not create any new loot/chest or increase kills.
- Coins/XP and chest entitlement are conserved across partial absorption, XP choices, chest choices and reloads.
- A level-1 weapon retains original targeting, damage and projectile patterns; evolution cannot recurse into itself or trigger from dummy cleanup.
- An optional synergy acts only with the selected eligible pair; unowned/suppressed weapon behavior and old save IDs remain valid.
- Art/selection/battle/HUD agree; no cyan shader remains on hero limbs/body; previous accepted v13 art remains byte-identical.

## Final evidence

36 groups / 5359 checks pass (the complete suite plus the added same-frame double-arrow regression in the final focused rerun). Native 23 checks / 0 failures; movie and all fourteen stage textures visually inspected. Independent review fixes: conductive-arrow actual-hit guard and attached per-weapon ornaments. Previous 149 asset files and twelve protected gameplay/UI/music modules remain unchanged. Four current player JSON files backed up without restoration.

Normal v0.14 window opened using the existing player storage. Fresh executable path and native window title/handle verified in docs/v14_opened.json; startup log clean. No old process was killed and no player save was restored.
