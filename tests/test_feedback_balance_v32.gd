extends SceneTree
const Growth = preload("res://src/growth.gd")
const LootRules = preload("res://src/loot_rules.gd")
const LootDrops = preload("res://src/loot_drops.gd")
const Economy = preload("res://src/economy.gd")
const Progression = preload("res://src/progression.gd")
const Rules = preload("res://src/rules.gd")
const SaveStore = preload("res://src/save_store.gd")

var checks := 0
var failures := 0

func expect(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + label)

func key_event(code: int, pressed: bool) -> void:
    var event := InputEventKey.new()
    event.physical_keycode = code
    event.pressed = pressed
    event.echo = false
    Input.parse_input_event(event)

func tap(code: int) -> void:
    key_event(code, true)
    await process_frame
    key_event(code, false)
    await process_frame

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    _test_loot_and_xp()
    _test_weapon_levels()
    _test_chests_and_targets()
    _test_polish_numbers()
    await _test_world_behavior()
    print("FEEDBACK_BALANCE_V32 RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)

func _test_loot_and_xp() -> void:
    expect(is_equal_approx(LootRules.BLOOD_PACK_CHANCE, 0.03) and is_equal_approx(LootRules.BLOOD_PACK_HEAL, 2.0), "blood packs are a rare 3% drop that heal 2 HP")
    var rng := RandomNumberGenerator.new()
    rng.seed = 32
    var hits := 0
    for index in range(10000):
        if LootRules.should_drop_blood_pack("hunter", false, rng):
            hits += 1
    expect(hits > 200 and hits < 400, "blood pack chance is testable and stays rare, not a flood")
    expect(not LootRules.should_drop_blood_pack("hunter", true, rng) and not LootRules.should_drop_blood_pack("boss", false, rng), "elites and bosses do not drop blood packs")
    expect(is_equal_approx(LootRules.LOOT_SCALE, 0.75), "gold and XP drops are scaled down a bit, not turned into chance-only drops")
    var reward: Dictionary = LootRules.enemy_reward("hunter", 1, false, 24.0, rng)
    expect(int(reward.get("coin", 0)) >= 1 and float(reward.get("xp", 0.0)) >= 1.0, "kills still always drop at least some gold and XP")
    expect(Growth.xp_needed_for(1) == 15 and Growth.xp_needed_for(2) == 20 and Growth.xp_needed_for(3) == 25 and Growth.xp_needed_for(4) == 30, "the XP curve starts at 15 and rises by 5 each level")
    var early_xp := 0.0
    var early_gold := 0
    for wave in range(1, 3):
        for _kill in range(18):
            var drop: Dictionary = LootRules.enemy_reward("hunter", wave, false, 24.0, rng)
            early_xp += float(drop.get("xp", 0.0))
            early_gold += int(drop.get("coin", 0))
    var need_to_6 := 0
    for level in range(1, 7):
        need_to_6 += Growth.xp_needed_for(level)
    expect(early_xp < float(need_to_6), "the first two stages do not supply enough XP for a six-weapon / high-level rush")
    var long_xp := 0.0
    for wave in range(1, 11):
        for _kill in range(16):
            long_xp += float(LootRules.enemy_reward("hunter", wave, false, 24.0, rng).get("xp", 0.0))
    expect(long_xp >= float(need_to_6), "a moderate nerf still leaves enough XP for a full loadout around the later stages")
    var unit_drops: Array = []
    LootDrops.append_reward(unit_drops, {"coin": 3, "xp": 2.75}, Vector2.ZERO)
    var restored_xp := 0.0
    for drop in unit_drops:
        if drop.kind == "xp":
            restored_xp += LootDrops.experience_value(drop)
    expect(unit_drops.size() == 6 and unit_drops.all(func(drop): return drop.value == 1) and is_equal_approx(restored_xp, 2.75), "unit loot retains exact fractional XP without creating merged value packs")

func _test_weapon_levels() -> void:
    for level in range(1, 6):
        expect(Growth.new_weapon_level_chance(1, level) > 0.0 and Growth.new_weapon_level_chance(10, level) > 0.0, "every existing weapon level can appear early and late: Lv.%d" % level)
    expect(Growth.new_weapon_level_chance(1, 1) > 0.8 and Growth.new_weapon_level_chance(1, 5) < 0.01, "early offers are mostly Lv.1, with Lv.5 very uncommon")
    expect(Growth.new_weapon_level_chance(10, 1) < Growth.new_weapon_level_chance(1, 1), "later stages reduce the Lv.1 share")
    expect(Growth.new_weapon_level_chance(10, 5) > Growth.new_weapon_level_chance(1, 5) and Growth.new_weapon_level_chance(10, 5) < 0.12, "late stages raise high-level odds but keep the top end uncommon")
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var seen := {}
    for index in range(4000):
        seen[Growth.roll_new_weapon_level(rng, 10)] = true
    for level in range(1, 6):
        expect(seen.has(level), "a late roller can produce Lv.%d" % level)

func _test_chests_and_targets() -> void:
    expect(is_equal_approx(LootRules.ELITE_CHEST_CHANCE, 0.5), "a non-guaranteed elite chest has an even chance to drop")
    var living := {"id": 1, "kind": "hunter", "state": "chase", "hp": 4.0, "position": Vector2(80, 0), "stone": false}
    var egg := {"id": 2, "kind": "egg_dino", "state": "egg", "hp": 4.0, "position": Vector2(40, 0), "stone": false}
    var stone := {"id": 3, "kind": "stone", "state": "idle", "hp": 8.0, "position": Vector2(20, 0), "stone": true}
    expect(Rules.is_living_monster(living) and Rules.is_egg(egg) and not Rules.is_living_monster(egg), "unhatched eggs are not treated as living dinosaurs")
    expect(Rules.should_defer_target(egg, [living, egg, stone]) and Rules.should_defer_target(stone, [living, egg, stone]), "weapons skip eggs and stones when a living monster is available")
    expect(Rules.should_defer_target(stone, [egg, stone]) and not Rules.should_defer_target(egg, [egg, stone]), "eggs are preferred over stones when no living monster is in the set")
    var chosen: Dictionary = Rules.choose_target(Vector2.ZERO, 200.0, [egg, living, stone], false)
    expect(str(chosen.get("id", 0)) == "1" or int(chosen.get("id", 0)) == 1, "choose_target prefers the living dinosaur")

func _test_polish_numbers() -> void:
    expect(is_equal_approx(Progression.adapt_ceiling(5), 1.0 + 0.75 * 4.0 / 28.0) and Progression.adapt_ceiling(5) < 1.2, "adaptation still rises at stage 5 but no longer hits the cap")
    expect(is_equal_approx(Progression.adapt_ceiling(29), Progression.ADAPT_CAP), "the 1.75 adaptation cap is reached around stage 29")
    expect(Progression.adaptation(5, 1000.0, 1.0) <= Progression.adapt_ceiling(5), "strong builds cannot exceed the stage-scaled adaptation ceiling")
    expect(is_equal_approx(Progression.cap_boss_hp(100.0, 10.0), 480.0) and is_equal_approx(Progression.cap_boss_hp(100.0, 1.0), 100.0), "dynamic boss HP stays between the formula and its 4.8x cap")
    expect(int(Growth.BUFFS["power"]["max_level"]) == 999 and int(Growth.BUFFS["haste"]["max_level"]) == 999, "蛮力 and 迅捷 play caps are uncapped in normal play")
    expect(int(Growth.BUFFS["crit_chance"]["max_level"]) == 999 and int(Growth.BUFFS["crit_power"]["max_level"]) == 999, "猎手直觉 and 致命一击 play caps are uncapped in normal play")
    expect(int(Growth.BUFFS["power"]["save_max_level"]) == 999 and int(Growth.BUFFS["crit_chance"]["save_max_level"]) == 999, "save validation accepts the current uncapped buff stacks")
    var levels := {"power": 999}
    expect(not Growth.apply(levels, "power") and int(levels["power"]) == 999, "play apply refuses to stack 蛮力 past the catalog cap")
    expect(Economy.price("power", 1, 0) > Economy.price("crit_chance", 1, 0), "蛮力 costs more than 猎手直觉")
    expect(Economy.price("haste", 1, 0) > Economy.price("crit_power", 1, 0), "迅捷 costs more than 致命一击")
    expect(Economy.price("power", 1, 0) == 34 and Economy.price("haste", 1, 0) == 32, "strength-based shop bases are 34 for 蛮力 and 32 for 迅捷")
    expect(Economy.price("crit_chance", 1, 0) == 24 and Economy.price("crit_power", 1, 0) == 22, "crit shop bases are 24 and 22")
    var store = SaveStore.new("res://runtime/tests/feedback_balance_settings_" + str(Time.get_ticks_usec()))
    expect(store.write_settings({"autosave": true, "music_enabled": true, "music_volume": 0.4, "sfx_volume": 0.5}).get("ok", false), "optional volume fields persist")
    var loaded: Dictionary = store.read_settings()
    expect(is_equal_approx(float(loaded.get("music_volume", -1)), 0.4) and is_equal_approx(float(loaded.get("sfx_volume", -1)), 0.5), "saved volume sliders reload")
    expect(not store.write_settings({"autosave": true, "music_volume": 1.5}).get("ok", true), "volume values outside 0-1 are rejected")

func _test_world_behavior() -> void:
    var world = load("res://src/main.gd").new()
    world.save_store = SaveStore.new("res://runtime/tests/feedback_balance_world_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.settings.autosave = false
    world.start_run(false)
    expect(world.xp_needed == 15, "a fresh official run uses the steeper first-level XP requirement")
    expect(world.debug_cheats == false, "official play does not enable debug cheats")
    var trial_button: BaseButton = world.hud.root.find_child("BattleTrial", true, false) as BaseButton
    expect(trial_button == null or trial_button.visible == false, "official combat hides the six-weapon trial button")
    var before_wave: int = world.wave
    var before_elapsed: float = world.elapsed
    var before_inventory: int = world.inventory.size()
    await tap(KEY_F2)
    expect(not world.trial_mode and world.wave == before_wave and world.inventory.size() == before_inventory, "official F2 does not jump into the six-weapon trial")
    await tap(KEY_F3)
    expect(not world.trial_mode, "official F3 does not start the expanded trial")
    world.elapsed = 1.25
    await tap(KEY_R)
    expect(is_equal_approx(world.elapsed, 1.25) and not world.trial_mode, "official R does not soft-reset the current run")
    var official_store = world.save_store
    world.debug_cheats = true
    world.hud.debug_cheats = true
    world.hud.refresh_debug_controls()
    trial_button = world.hud.root.find_child("BattleTrial", true, false) as BaseButton
    expect(trial_button != null and trial_button.visible, "an explicit debug flag shows the in-combat trial button")
    await tap(KEY_F2)
    expect(world.trial_mode and world.inventory.size() == 6, "debug F2 still launches the six-weapon trial")
    expect(world.save_store == official_store, "trial launch does not swap the official save store")
    world.start_run(false)
    world.player_hp = 3.0
    world.stats["max_hp"] = 8.0
    LootDrops.append_blood_pack(world.pickups, world.player_position, LootRules.BLOOD_PACK_HEAL)
    expect(world.pickups.size() == 1 and str(world.pickups[0].get("kind", "")) == "blood", "a blood pack can be placed on the battlefield")
    world.update_pickups(0.2)
    expect(is_equal_approx(world.player_hp, 5.0), "picking up a blood pack heals 2 HP")
    world.wave = 9
    expect(world.pickup_magnet_radius() > float(world.stats["pickup_radius"]), "later waves extend auto-magnet range")
    var blood_pos: Vector2 = world.player_position + Vector2(60.0, 0.0)
    var coin_pos: Vector2 = world.player_position + Vector2(90.0, 0.0)
    var top_xp_pos: Vector2 = world.visible_world_rect().position + Vector2(320.0, 40.0)
    world.pickups = [
        {"kind": "blood", "position": blood_pos, "value": 2.0},
        {"kind": "coin", "position": coin_pos, "value": 1},
        {"kind": "xp", "position": top_xp_pos, "value": 1}
    ]
    world.update_pickups(0.1)
    expect(world.pickups.size() == 3, "non-collected pickups remain on field")
    expect(world.pickups[0]["position"].is_equal_approx(blood_pos), "blood packs are NOT magnetized toward the player")
    expect(world.pickups[1]["position"].x < coin_pos.x, "coins ARE magnetized toward the player")
    expect(world.pickups[2]["position"].is_equal_approx(top_xp_pos), "top-screen-edge pickups are NOT pushed downward")
    world.map_view.set_view(world.player_position, 9)
    var lava_center := Vector2.ZERO
    for key in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
        for prop in world.map_view.chunk_content(key):
            if prop["kind"] == "lava":
                lava_center = prop["point"]
                break
        if lava_center != Vector2.ZERO:
            break
    expect(lava_center != Vector2.ZERO, "volcano biome populates a lava pit in nearby chunks")
    if lava_center != Vector2.ZERO:
        expect(world.map_view.is_in_lava(lava_center), "volcano lava pool is detected by is_in_lava")
        var clip_res: Dictionary = world._clip_point_before_lava(lava_center + Vector2(-220.0, 0.0), lava_center, 4.0)
        expect(bool(clip_res["hit"]) and not world.map_view.is_in_lava(clip_res["point"], 3.5), "lightning vein stops cleanly before entering the lava rim")
        world.effects.expire_all()
        world.trigger_lava_lightning_splash(lava_center, 1.0)
        expect(world.effects.particles.any(func(p): return str(p.get("kind", "")) == "fire_blast"), "lightning hitting lava spawns a molten explosion splash")
    var evol = load("res://src/weapon_evolution.gd")
    expect(evol.damage_multiplier("club", 5) > evol.damage_multiplier("club", 3) and evol.damage_multiplier("club", 3) > evol.damage_multiplier("club", 2), "club gets a meaningful jump at Lv.3 and Lv.5")
    expect(is_equal_approx(evol.damage_multiplier("firepot", 5), evol.damage_multiplier("staff", 5)) and evol.damage_multiplier("staff", 5) > evol.damage_multiplier("staff", 4), "awakened fire and staff keep their shared Lv.5 amplification")
    expect(Economy.price("power", 20, 6) < 140 and Economy.price("sling", 20, 5) < 100, "repeat buff and high-level weapon upgrades are cut in price so builds scale smoothly")
    for key in ["sling", "powder"]:
        expect(evol.damage_multiplier(key, 10) > evol.damage_multiplier(key, 7) and evol.damage_multiplier(key, 7) > evol.damage_multiplier(key, 5), key + " gains damage through its late levels")
    expect(world.Growth.MAX_WEAPON_LEVEL == 10 and evol.damage_multiplier("hammer", 10) > evol.damage_multiplier("hammer", 7), "weapon level cap is 10 and late upgrades keep scaling cleanly")
    var fire_link := [{"id": "fire_cannon", "kind": "fire_enchant", "weapons": ["firepot", "powder"]}]
    expect(is_equal_approx(world.Rules.enchant_damage_bonus(fire_link, "powder", 0, 0, 0), 1.23) and is_equal_approx(world.Rules.enchant_damage_bonus(fire_link, "powder", 2, 0, 0), 1.46), "fire enchant retains a rising direct-hit bonus at the reduced rates")
    world.start_run(false)
    world.stats["crit_chance"] = 0.0
    world.stats["crit_multiplier"] = 2.0
    world.spawn_enemy("hunter", world.player_position + Vector2(80, 0))
    var red_target: Dictionary = world.enemies.back()
    red_target["hp"] = 500.0
    red_target["max_hp"] = 500.0
    red_target["dodge"] = 0.0
    world.hurt_enemy(red_target, 10.0, "totem", false, Vector2.RIGHT, 0)
    var normal_dealt: float = 500.0 - float(red_target["hp"])
    red_target["hp"] = 500.0
    world.hurt_enemy(red_target, 10.0, "totem", false, Vector2.RIGHT, 1)
    var red_dealt: float = 500.0 - float(red_target["hp"])
    expect(is_equal_approx(red_dealt, normal_dealt * float(world.stats["crit_multiplier"])), "red lightning guarantees a critical hit even with 0% crit chance")
    world.hurt_flash = 0.0
    world.hero.hurt()
    # Direct combat path
    world.invulnerable = 0.0
    var hp_before: float = world.player_hp
    world.hurt_player(Vector2.RIGHT, 1.0)
    expect(world.player_hp < hp_before and world.hurt_flash > 0.0, "taking damage flashes the hero feedback")
    expect(world.hud.hurt_flash_layer != null, "a screen-edge hurt flash layer exists")
    world.hud.show_stats(world.buff_levels, world.stats, {"wave": 2, "adaptive": 1.13, "enemy": Progression.enemy_profile(2, "hunter", 1.13), "in_combat": false})
    var stats_text := _overlay_text(world.hud)
    expect(stats_text.contains("适应倍率") and not stats_text.contains("普通猎手"), "the stats panel shows the adaptation multiplier and no longer calls enemies 普通猎手")
    world.running = false
    world.trial_mode = false
    world.stats_open = false
    world.hud.show_help("gameplay", false)
    expect(world.hud.screen == "help" and not world.running and not world.trial_mode, "the help attributes path does not start a trial battle")
    world.toggle_stats()
    expect(world.hud.screen == "stats" and not world.running, "角色属性 from help only opens the stats table")
    world.toggle_stats()
    expect(world.hud.screen == "help" and not world.running, "closing the stats tab returns to help instead of the title or a battle")
    world.hud.show_departure(2.0)
    var depart := _overlay_text(world.hud)
    expect(depart.contains("准备好，迎战恐龙") and not depart.contains("再迎战"), "the departure card wording drops the extra 再")
    world.hud.show_cast()
    var selected: String = world.hud.selected_character
    if Catalog_character_count() > 1:
        world.hud.change_character(1)
        expect(world.hud.selected_character == selected and world.hud.preview_character != selected, "arrows only preview a character")
        world.hud.commit_character(world.hud.preview_character)
        expect(world.hud.selected_character == world.hud.preview_character, "clicking the card or confirm commits the preview")
    world.hud.menu_summary = {"wave": 8, "elapsed": 125.0, "level": 7, "weapons": [{"id": "sling", "level": 1}, {"id": "club", "level": 3}]}
    world.hud.show_menu("lose", 12, "ui_open", world.hud.menu_summary)
    var settle := _overlay_text(world.hud)
    expect(settle.contains("第 8 关") and settle.contains("等级 7") and settle.contains("02:05"), "the settlement screen lists stage, time and level")
    world.hud.show_settings(false)
    expect(world.hud.overlay.find_child("MusicVolume", true, false) != null and world.hud.overlay.find_child("SfxVolume", true, false) != null, "settings include music and SFX volume sliders")
    world.hud.configure_volumes(0.3, 0.6)
    var music_slider: Slider = world.hud.overlay.find_child("MusicVolume", true, false) as Slider
    var sfx_slider: Slider = world.hud.overlay.find_child("SfxVolume", true, false) as Slider
    expect(music_slider != null and is_equal_approx(music_slider.value, 0.3), "the music slider reflects the configured volume")
    expect(sfx_slider != null and is_equal_approx(sfx_slider.value, 0.6), "the SFX slider reflects the configured volume")
    world.hud.save_summary = {"starting_weapon": "sling", "inventory": [{"id": "sling", "level": 1}, {"id": "club", "level": 3}], "player_hp": 6.5, "coins": 44, "wave": 3, "player_level": 2, "buff_levels": {}, "character_id": "caveman"}
    world.hud.save_available = true
    world.hud.show_continue()
    var hp_label: Label = world.hud.overlay.find_child("SaveHp", true, false) as Label
    var coin_label: Label = world.hud.overlay.find_child("SaveCoins", true, false) as Label
    expect(hp_label != null and hp_label.text.contains("6.5"), "the continue panel shows decimal HP")
    expect(coin_label != null and coin_label.text.contains("44"), "the continue panel coin count matches the saved/HUD value")
    var continue_text := _overlay_text(world.hud)
    expect(continue_text.contains("Lv.3") or continue_text.contains("进阶"), "the continue panel lists more than the starter weapon")
    world.queue_free()
    await process_frame

func Catalog_character_count() -> int:
    var catalog = load("res://src/catalog.gd")
    return catalog.CHARACTER_ORDER.size()

func _overlay_text(hud) -> String:
    var parts: PackedStringArray = PackedStringArray()
    for node in hud.overlay.find_children("*", "Label", true, false):
        parts.append(str(node.text))
    return "\n".join(parts)
