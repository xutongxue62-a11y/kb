extends SceneTree

const LootRules = preload("res://src/loot_rules.gd")
const LootDrops = preload("res://src/loot_drops.gd")
const SaveStore = preload("res://src/save_store.gd")
const Catalog = preload("res://src/catalog.gd")
const ActorView = preload("res://src/actor_view.gd")
const Companions = preload("res://src/companions.gd")
const Music = preload("res://src/music_controller.gd")
var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + message)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    # This is a backwards-compatibility check on the actual user:// resolver,
    # not a check of a product title shown to the player.
    if OS.get_name() != "Android":
        expect(OS.get_user_data_dir().replace("\\", "/").ends_with("/原始人大作战 · 战斗样板"), "default storage still resolves to the existing desktop save namespace")
    test_early_rewards()
    test_blood_restore()
    var world = load("res://src/main.gd").new()
    world.save_store = SaveStore.new("res://runtime/tests/feedback_takeover_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.settings.autosave = false
    world.start_run(false)
    world.clear_enemies()
    await test_saved_blood(world)
    test_legacy_buff_save(world)
    test_blood_is_for_monsters(world)
    test_range_scoped_priority(world)
    test_magnet_and_text_budget(world)
    await test_continue_panel(world)
    world.hud.show_help("keys", false)
    var help_copy := text_of(world.hud.overlay)
    expect(not help_copy.contains("F2") and not help_copy.contains("F3") and not help_copy.contains("R 重开"), "official help does not advertise disabled debug hotkeys")
    test_sfx_preference(world)
    if DisplayServer.get_name() != "headless":
        await test_native_audio(world)
        await test_native_pet_markers()
        await test_native_ground_ring(world)
    else:
        print("NATIVE CHECK REQUIRED: the player ground ring is checked with a real renderer")
    world.queue_free()
    await process_frame
    await process_frame
    print("FEEDBACK TAKEOVER V32 RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)

func test_early_rewards() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 404
    var gold := 0
    var experience := 0.0
    var guaranteed := true
    for _index in range(600):
        var reward: Dictionary = LootRules.enemy_reward("hunter", 1, false, 24.0, rng)
        gold += int(reward.coin)
        experience += float(reward.xp)
        guaranteed = guaranteed and int(reward.coin) >= 1 and float(reward.xp) >= 1.0
    expect(guaranteed, "ordinary kills still provide both gold and experience")
    # The previous 1..2 band averaged 1.5. A scale setting which rounds 2
    # back to 2 must not silently leave the early economy unchanged.
    expect(gold < 840 and experience < 840.0, "the early 1..2 reward band actually becomes less generous")
    expect(gold > 660 and experience > 660.0, "the small reduction preserves variation instead of flattening every early reward to one")

func test_blood_restore() -> void:
    var point := Vector2(315, 287)
    var restored: Array = []
    for _index in range(4):
        LootDrops.restore(restored, {"kind": "blood", "value": 2.0}, point)
        expect(restored.size() == 1 and restored[0].position.is_equal_approx(point), "loading a health pack does not add another spawn offset")
        point = restored[0].position
        restored.clear()

func test_saved_blood(world) -> void:
    world.pickups = [{"kind": "blood", "position": Vector2(315, 287), "value": 2.0}]
    var saved: Dictionary = world.SessionState.capture(world)
    var result: Dictionary = world.save_store.write_run(saved)
    expect(bool(result.get("ok", false)), "an uncollected health pack is a valid saved drop")
    if result.get("ok", false):
        expect(world.continue_game(), "a save containing a health pack resumes")
        expect(world.pickups.size() == 1 and world.pickups[0].position.is_equal_approx(Vector2(315, 287)), "resume restores the one health pack at its saved position")
        world.player_position = Vector2(315, 287)
        world.player_hp = 3.0
        var coins: int = world.coins
        var xp: float = world.xp
        world.update_pickups(1.0)
        expect(world.pickups.is_empty() and is_equal_approx(world.player_hp, 5.0), "the resumed pack heals once for two HP")
        expect(world.coins == coins and is_equal_approx(world.xp, xp), "health packs never become gold or experience on resume")

func test_legacy_buff_save(world) -> void:
    world.start_run(false)
    var saved: Dictionary = world.SessionState.capture(world)
    saved.buff_levels = {"power": 20, "haste": 20, "crit_chance": 15, "crit_power": 15}
    saved.player_hp = 7.25
    saved.coins = 44
    saved.xp = 3.25
    expect(world.save_store.write_run(saved).get("ok", false), "older high-stack Buff saves remain valid data")
    expect(world.continue_game(), "an older high-stack save can continue under the approved new caps")
    expect(world.buff_levels.power == 10 and world.buff_levels.haste == 10 and world.buff_levels.crit_chance == 8 and world.buff_levels.crit_power == 8, "old Buff stacks load at the newly approved play caps")
    expect(world.coins == 44 and is_equal_approx(world.player_hp, 7.25) and is_equal_approx(world.xp, 3.25), "cap normalization preserves the save's wallet, exact HP and XP")

func prepare_target(world, state: String) -> Dictionary:
    world.clear_enemies()
    world.pickups.clear()
    world.spawn_enemy("hunter", world.player_position + Vector2(240, 0), false, state)
    var enemy: Dictionary = world.enemies.back()
    enemy.hp = 1.0
    enemy.dodge = 0.0
    enemy.elite = false
    enemy.view.display_width = 64.0
    return enemy

func test_blood_is_for_monsters(world) -> void:
    world.start_run(false)
    world.wave = 1
    var blood_seed := -1
    # Use real game combat and a real seeded RNG. Find a repeatable rare drop,
    # then present the same random stream to an unhatched egg.
    for seed in range(256):
        var enemy := prepare_target(world, "chase")
        world.rng.seed = seed
        world.hurt_enemy(enemy, 100.0, "sling", true, Vector2.RIGHT)
        if world.pickups.any(func(drop): return drop.kind == "blood"):
            blood_seed = seed
            break
    expect(blood_seed >= 0, "a killed ordinary dinosaur can produce a rare health pack")
    if blood_seed >= 0:
        var egg := prepare_target(world, "egg")
        world.rng.seed = blood_seed
        world.hurt_enemy(egg, 100.0, "sling", true, Vector2.RIGHT)
        expect(not world.pickups.any(func(drop): return drop.kind == "blood"), "smashing an unhatched egg does not qualify as a small-monster health drop")
    world.clear_enemies()
    world.pickups.clear()

func test_range_scoped_priority(world) -> void:
    world.start_run(false)
    world.clear_enemies()
    for x in range(-2, 5):
        for y in range(-2, 5):
            world.map_view.chunks[Vector2i(x, y)] = []
    world.spawn_enemy("hunter", world.player_position + Vector2(1100, 0), false, "chase")
    var monster: Dictionary = world.enemies.back()
    monster.hp = 100.0
    monster.dodge = 0.0
    world.spawn_enemy("hunter", world.player_position + Vector2(80, 0), false, "egg")
    var egg: Dictionary = world.enemies.back()
    egg.hp = 100.0
    egg.dodge = 0.0
    world.fire_projectile(world.player_position, Vector2.RIGHT, "sling", 3.2, 220.0)
    world.update_projectiles(0.15)
    expect(egg.hp < 100.0, "a monster outside projectile reach cannot make the aimed-at egg immune")
    world.projectiles.clear()
    egg.hp = 100.0
    monster.position = world.player_position + Vector2(170, 0)
    world.fire_projectile(world.player_position, Vector2.RIGHT, "sling", 3.2, 220.0)
    world.update_projectiles(0.15)
    expect(is_equal_approx(egg.hp, 100.0), "a projectile passes an egg when a living monster is in reach")
    world.update_projectiles(0.15)
    expect(monster.hp < 100.0, "the projectile then lands on the preferred living monster")
    world.projectiles.clear()
    world.clear_weapons()
    world.grant_weapon("club")
    world.grant_weapon("powder")
    world.select_link("chain_club")
    monster.position = world.player_position + Vector2(1100, 0)
    egg.position = world.chain_anchor() + Vector2(80, 0)
    egg.hp = 100.0
    world.launch_chain("club", egg.position)
    world.update_chain_weapon(world.inventory[0], 0.15)
    expect(egg.hp < 100.0, "a monster outside chain reach cannot make the aimed-at egg immune")
    world.clear_enemies()
    world.pickups.clear()

func test_magnet_and_text_budget(world) -> void:
    world.wave = 1
    var at: Vector2 = world.player_position + Vector2(float(world.stats.pickup_radius) + 50.0, 0)
    world.pickups = [{"kind": "coin", "value": 1, "position": at}]
    var coins: int = world.coins
    world.update_pickups(0.1)
    expect(world.pickups.size() == 1 and world.pickups[0].position == at, "early pickup range does not collect distant drops")
    world.wave = 9
    world.update_pickups(0.1)
    expect(world.pickups.size() == 1 and world.pickups[0].position.distance_to(world.player_position) < at.distance_to(world.player_position), "late-game attraction moves a drop which was outside the original pickup range")
    expect(world.coins == coins, "attraction does not grant coins before the drop reaches the hero")
    world.effects.particles.clear()
    for index in range(80):
        world.effects.damage_number(Vector2(index * 160, 100), float(index + 1))
        world.effects.floating_text(Vector2(index * 160, 200), "提示" + str(index), Color.WHITE)
    var numbers: Array = world.effects.particles.filter(func(particle): return particle.kind == "number")
    expect(numbers.size() <= 10, "mixed damage and status floating text share the ten-number screen budget")
    expect(numbers.any(func(particle): return particle.text == "提示79"), "the floating-text budget keeps recent feedback")
    world.pickups.clear()

func test_continue_panel(world) -> void:
    var inventory: Array = []
    for index in range(6):
        inventory.append({"id": Catalog.IDS[index], "level": index % 5 + 1})
    var character_id: String = Catalog.CHARACTER_ORDER[1]
    world.hud.save_summary = {"starting_weapon": "sling", "inventory": inventory, "player_hp": 6.5, "coins": 44, "wave": 3, "player_level": 2, "buff_levels": {}, "character_id": character_id}
    world.hud.save_available = true
    world.hud.show_continue()
    await process_frame
    await process_frame
    var all_text := text_of(world.hud.overlay)
    for item in inventory:
        expect(all_text.contains(str(Catalog.WEAPONS[item.id].name)), "the saved loadout includes " + str(Catalog.WEAPONS[item.id].name))
    var character_name: String = str(Catalog.character(character_id).name)
    expect(all_text.contains(character_name), "the save panel identifies the saved character rather than the currently previewed one")
    var title: Label
    for node in world.hud.overlay.find_children("*", "Label", true, false):
        if node.text == character_name:
            title = node
            break
    var preview: Control = world.hud.overlay.find_child("SavePreview", true, false) as Control
    var readable := true
    var separated := title != null
    for node in preview.find_children("*", "Label", true, false):
        var is_weapon := false
        for item in inventory:
            if node.text.contains(str(Catalog.WEAPONS[item.id].name)):
                is_weapon = true
        if is_weapon:
            var rect: Rect2 = node.get_global_rect()
            readable = readable and rect.end.x <= preview.get_global_rect().position.x + 774.0 and rect.end.y <= preview.get_global_rect().position.y + 384.0
            separated = separated and title != null and not rect.intersects(title.get_global_rect())
    expect(readable, "all six saved weapon labels fit inside the loadout area")
    expect(separated, "saved character and weapon names do not overlap")

func test_sfx_preference(world) -> void:
    world.set_volume("sfx", 0.0)
    expect(is_zero_approx(world.audio.volume), "the SFX preference reaches combat audio")
    var ui = world.hud.ui_audio
    var volume_supported: bool = ui != null and ui.has_method("set_volume")
    expect(volume_supported, "the SFX preference also controls UI cues")
    if volume_supported:
        expect(is_zero_approx(float(ui.get("volume"))), "the persisted SFX mute reaches the UI pool")
    world.set_volume("sfx", 1.0)

func test_native_audio(world) -> void:
    Engine.max_fps = 60
    world.set_volume("sfx", 0.0)
    world.set_volume("sfx", 0.01)
    world.audio.play("hurt")
    var combat: Array = world.audio.voices.filter(func(voice): return voice.playing)
    expect(not combat.is_empty() and combat.all(func(voice): return voice.volume_db < -60.0), "one-percent SFX attenuation is not raised back to the old -36dB floor")
    world.set_volume("sfx", 0.0)
    expect(world.audio.voices.all(func(voice): return not voice.playing), "muting immediately stops already-playing combat sounds")
    var ui = world.hud.ui_audio
    if ui.has_method("set_volume"):
        world.set_volume("sfx", 0.25)
        ui.play("choice_confirm")
        var voices: Array = ui.get("_voices")
        var sounding: Array = voices.filter(func(voice): return voice.playing)
        var expected: float = -1.0 + linear_to_db(0.25)
        expect(not sounding.is_empty() and sounding.all(func(voice): return absf(voice.volume_db - expected) < 0.1), "UI playback uses the same quarter-volume setting")
        world.set_volume("sfx", 0.0)
        expect(voices.all(func(voice): return not voice.playing), "muting immediately stops already-playing UI sounds")
        ui.play("button_hover")
        expect(voices.all(func(voice): return not voice.playing), "new UI hover requests remain silent while muted")
    world.set_volume("sfx", 1.0)
    var music := Music.new()
    root.add_child(music)
    await create_timer(0.05).timeout
    music.set_context("battle")
    await create_timer(0.05).timeout
    music.set_volume(0.0)
    expect(music._players.all(func(voice): return voice.volume_db <= -79.0), "muting music immediately covers both crossfade voices")
    await create_timer(0.45).timeout
    expect(music._players.all(func(voice): return voice.volume_db <= -79.0), "an old crossfade cannot undo music mute")
    music.set_volume(1.0)
    music.set_context("pause")
    await create_timer(0.05).timeout
    music.set_volume(0.25)
    await create_timer(0.45).timeout
    expect(absf(music._players[music._active].volume_db - (-18.0 + linear_to_db(0.25))) < 0.1, "a pause fade retains the newly selected quarter music volume")
    music.set_enabled(false)
    music.queue_free()
    await process_frame
    var store := SaveStore.new("res://runtime/tests/muted_startup_" + str(Time.get_ticks_usec()))
    expect(store.write_settings({"autosave": false, "music_enabled": false, "music_volume": 0.0, "sfx_volume": 0.0}).get("ok", false), "an isolated saved mute preference is written")
    var muted_world = load("res://src/main.gd").new()
    muted_world.save_store = store
    root.add_child(muted_world)
    muted_world.set_physics_process(false)
    var muted_ui = muted_world.hud.ui_audio
    expect(muted_ui.has_method("set_volume") and is_zero_approx(float(muted_ui.get("volume"))) and muted_ui.get("_last_play_ms").is_empty(), "saved SFX mute applies before the first title popup cue")
    muted_world.queue_free()
    await process_frame
    await process_frame

func test_native_pet_markers() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(360, 220)
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var points := [Vector2(95, 130), Vector2(265, 130)]
    for index in range(2):
        var pet := Companions.new()
        pet.states.pet = {"position": points[index], "facing": 1.0 if index == 0 else -1.0, "stride": 0.0, "moving": false, "attack": 0.0, "aim": Vector2.RIGHT}
        viewport.add_child(pet)
        pet.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = viewport.get_texture().get_image()
    for point in points:
        var red_pixels := 0
        var gold_pixels := 0
        for y in range(int(point.y) - 57, int(point.y) - 12):
            for x in range(int(point.x) - 42, int(point.x) + 43):
                var color: Color = image.get_pixel(x, y)
                if color.a > 0.9 and color.r > 0.68 and color.g < 0.4 and color.b < 0.35:
                    red_pixels += 1
                if color.a > 0.9 and color.r > 0.8 and color.g > 0.65 and color.b < 0.5:
                    gold_pixels += 1
        expect(red_pixels > 25 and gold_pixels > 10, "red collar and gold marker stay beside the pet at nonzero positions in either facing")
    viewport.queue_free()
    await process_frame

func test_native_ground_ring(world) -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(240, 180)
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var actor := ActorView.new()
    actor.setup(world.library)
    actor.position = Vector2(120, 70)
    viewport.add_child(actor)
    for child in actor.get_children():
        if child is CanvasItem:
            child.visible = false
    actor.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = viewport.get_texture().get_image()
    var center: Vector2 = actor.position + actor.ground_shadow_anchor()
    var ring_pixels := 0
    for y in range(maxi(0, int(center.y) - 15), mini(image.get_height(), int(center.y) + 16)):
        for x in range(maxi(0, int(center.x) - 37), mini(image.get_width(), int(center.x) + 38)):
            var normalized := Vector2((x - center.x) / 30.0, (y - center.y) / 10.0)
            var color: Color = image.get_pixel(x, y)
            if normalized.length() > 0.8 and color.a > 0.1 and color.g - color.r > 0.12 and color.g - color.b > 0.035:
                ring_pixels += 1
    expect(ring_pixels > 40, "the player has a visible colored ground ring outside the dark shadow")
    viewport.queue_free()
    await process_frame

func text_of(node: Node) -> String:
    var lines: PackedStringArray = []
    for child in node.find_children("*", "Control", true, false):
        if child is Label or child is Button:
            lines.append(child.text)
    return "\n".join(lines)
