extends Node2D
const GameFonts=preload("res://src/game_fonts.gd")

const Rules = preload("res://src/rules.gd")
const Catalog = preload("res://src/catalog.gd")
const AssetLibrary = preload("res://src/asset_library.gd")
const ActorView = preload("res://src/actor_view.gd")
const DinoView = preload("res://src/dino_view.gd")
const Effects = preload("res://src/effects.gd")
const Hud = preload("res://src/hud.gd")
const AudioPool = preload("res://src/audio_pool.gd")
const Growth = preload("res://src/growth.gd")
const Companions = preload("res://src/companions.gd")
const Progression = preload("res://src/progression.gd")
const Economy = preload("res://src/economy.gd")
const SessionState = preload("res://src/session_state.gd")
const SaveStore = preload("res://src/save_store.gd")
const KeyBindings = preload("res://src/key_bindings.gd")
const Armory = preload("res://src/armory.gd")
const WorldMap = preload("res://src/world_map.gd")
const Music = preload("res://src/music_controller.gd")
const LootRules = preload("res://src/loot_rules.gd")
const LootDrops = preload("res://src/loot_drops.gd")
const BattleVisuals = preload("res://src/battle_visuals.gd")
const PickupRenderer=preload("res://src/pickup_renderer.gd")
var pickup_renderer: Node2D
const Evolution = preload("res://src/weapon_evolution.gd")
const EnemyRoster = preload("res://src/enemy_roster.gd")
const FIELD: Rect2 = Rect2(42, 147, 1196, 514)
const WAVE_SECONDS: float = 30.0
const WAVE_BUFFER: float = 0.9
const CHARGE_SPEED: float = 560.0
const CHARGE_DURATION: float = 0.4
const DODGE_DURATION: float = 0.20
const DODGE_DISTANCE: float = 140.0
const DODGE_COOLDOWN: float = 1.4
const FORMATION_SPEED: float = 10.0

var world_camera: Camera2D
var library
var actors: Node2D
var weapons_layer: Node2D
var hero
var effects
var hud
var audio
var music
var map_view
var companions
var buff_levels: Dictionary = {}
var stats: Dictionary = Growth.stats({})
var pickups: Array = []
var starting_weapon: String = "sling"
var character_id: String = "caveman"
var _combat_targets_cache: Array = []
var _combat_targets_ready: bool = false
var _simulating: bool = false
var stats_open: bool = false
var stats_return_paused: bool = false
var wave: int = 1
var pending_wave_rewards: int = 0
var upgrade_reason: String = "xp"
var heal_display: float = 0.0
var impact_strength: float = 0.0
var enemy_adaptation: float = 1.0
var save_store
var settings: Dictionary = {"autosave":true}
var restoring: bool = false
var armory
var coins: int = 0
var wave_elapsed: float = 0.0
var boss_round: bool = false
var boss_defeated: bool = false
var boss_pending: bool = false
var shop_open: bool = false
var shop_stock: Array = []
var shop_rerolls: int = 0
var wave_closing: bool = false
var wave_buffer: float = 0.0
var departure_left: float = 0.0
var stats_home_return: String = "title"
var player_frozen: bool = false
var trial_preset: String = "base"
var formation_phase: float = 0.0
var active_link: Dictionary = {}
var available_links: Array = []
var pending_link: String = ""
var burning_fields: Array = []
var link_demo: bool = false
var demo_link_stage: String = ""
var inventory: Array = []
var weapon_views: Dictionary = {}
var weapon_runtime: Dictionary = {}
var enemies: Array = []
var projectiles: Array = []
var groups: Array = []
var counters: Dictionary = {}
var combo_cooldowns: Dictionary = {}
var upgrade_choices: Array = []
var upgrade_offer_levels: Dictionary = {}
var replace_pending: Dictionary = {}
var chest_queue: int = 0
var chest_marks: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var player_position: Vector2 = Vector2(640, 401)
var player_hp: float = 8.0
var invulnerable: float = 0.0
var dodge_left: float = 0.0
var dodge_cooldown: float = 0.0
var dodge_direction: Vector2 = Vector2.RIGHT
var last_facing: Vector2 = Vector2.RIGHT
var elapsed: float = 0.0
var kills: int = 0
var xp: float = 0.0
var xp_needed: int = 8
var player_level: int = 1
var enemy_serial: int = 0
var elite_budget: int = 0
var spawn_clock: float = 0.0
var running: bool = false
var paused: bool = false
var touch_input: Vector2 = Vector2.ZERO
var game_ready: bool = false
var upgrade_pending: bool = false
var collapsed: bool = false
var combo_mode: String = "none"
var prefer_elite: bool = false
var trial_mode: bool = false
var debug_cheats: bool = false
var force_elite_chests: bool = false
var hurt_flash: float = 0.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var demo: bool = false
var animation_demo: bool = false
var combo_message: String = ""
var combo_message_time: float = 0.0
var demo_caption: String = ""
var demo_font: SystemFont
var demo_weapon: Sprite2D

func _ready() -> void:
    get_window().set_deferred("title", "原始人大作战 · 荒野交锋 v%s" % str(ProjectSettings.get_setting("application/config/version","0.23.0")))
    get_tree().auto_accept_quit = false
    if save_store == null:
        save_store = SaveStore.new()
    settings = save_store.read_settings()
    KeyBindings.apply_settings(settings)
    music = Music.new()
    music_volume = clampf(float(settings.get("music_volume", 1.0)), 0.0, 1.0)
    sfx_volume = clampf(float(settings.get("sfx_volume", 1.0)), 0.0, 1.0)
    music.set_enabled(bool(settings.get("music_enabled",true)))
    if music.has_method("set_volume"):
        music.set_volume(music_volume)
    if audio != null and audio.has_method("set_volume"):
        audio.set_volume(sfx_volume)
    add_child(music)
    apply_display_mode(bool(settings.get("fullscreen", false)))
    _fit_playable_window()
    map_view = WorldMap.new()
    map_view.z_index = -50
    add_child(map_view)
    map_view.set_view(player_position,wave)
    rng.seed = 2180411
    library = AssetLibrary.new()
    active_link = Catalog.LINKS["none"].duplicate(true)
    actors = Node2D.new()
    actors.y_sort_enabled = true
    add_child(actors)
    hero = ActorView.new()
    hero.setup(library)
    actors.add_child(hero)
    hero.position = player_position
    world_camera = Camera2D.new()
    world_camera.name = "WorldCamera"
    world_camera.position = player_position
    world_camera.position_smoothing_enabled = false
    add_child(world_camera)
    world_camera.make_current()
    weapons_layer = Node2D.new()
    weapons_layer.z_index = 0
    add_child(weapons_layer)
    pickup_renderer=PickupRenderer.new()
    pickup_renderer.z_index=-2
    add_child(pickup_renderer)
    effects = Effects.new()
    if DisplayServer.get_name()!="headless": Effects.CombatArt.warm()
    effects.z_index = 35
    add_child(effects)
    audio = AudioPool.new()
    add_child(audio)
    if audio.has_method("set_volume"):
        audio.set_volume(sfx_volume)
    companions = Companions.new()
    companions.terrain = map_view
    companions.z_index = 7
    add_child(companions)
    armory = Armory.new()
    armory.z_index = 14
    add_child(armory)
    hud = Hud.new()
    hud.configure_volumes(music_volume, sfx_volume)
    add_child(hud)
    hud.setup(library)
    hud.start_requested.connect(begin_departure)
    hud.formation_requested.connect(switch_formation)
    hud.combo_requested.connect(switch_combo_mode)
    hud.elite_requested.connect(switch_elite)
    hud.trial_requested.connect(func(): start_run(true, "base"))
    hud.new_trial_requested.connect(start_expanded_trial)
    hud.pause_requested.connect(toggle_pause)
    hud.restart_requested.connect(restart_current_run)
    hud.choice_selected.connect(on_choice)
    hud.reward_sell_requested.connect(sell_reward)
    hud.starter_selected.connect(set_start_weapon)
    hud.stats_requested.connect(toggle_stats)
    hud.growth_requested.connect(request_trial_growth)
    hud.buy_requested.connect(buy_shop_item)
    hud.reroll_requested.connect(reroll_shop)
    hud.replace_requested.connect(confirm_replace)
    hud.replace_cancelled.connect(cancel_replace)
    hud.next_round_requested.connect(leave_shop)
    hud.save_requested.connect(save_game)
    hud.continue_requested.connect(begin_continue)
    hud.home_requested.connect(go_home)
    hud.settings_changed.connect(set_autosave)
    hud.music_changed.connect(set_music)
    hud.volume_changed.connect(set_volume)
    hud.damage_numbers_changed.connect(set_damage_numbers)
    hud.display_mode_changed.connect(set_fullscreen)
    hud.key_bindings_changed.connect(set_key_bindings)
    hud.configure_music(bool(settings.get("music_enabled",true)))
    hud.configure_volumes(music_volume, sfx_volume)
    hud.configure_display(bool(settings.get("damage_numbers", true)), bool(settings.get("fullscreen", false)))
    refresh_save_status()
    demo_font = GameFonts.create_system(PackedStringArray(["Microsoft YaHei", "Arial"]))
    demo_font.font_names = PackedStringArray(["Microsoft YaHei", "Arial"])
    var arguments: PackedStringArray = OS.get_cmdline_user_args()
    link_demo = arguments.has("--links-demo")
    demo = arguments.has("--demo") or link_demo
    animation_demo = arguments.has("--animation-demo")
    if animation_demo:
        DisplayServer.window_set_title("原始人 · 动作预览")
        start_run(true)
        hero.scale = Vector2.ONE * 3.0
        hud.root.visible = false
        weapons_layer.visible = false
        demo_weapon = library.make_weapon("club", 90.0)
        demo_weapon.z_index = 25
        demo_weapon.visible = false
        add_child(demo_weapon)
    elif demo:
        DisplayServer.window_set_title("原始人大作战 · 二联动有声演示")
        start_run(true)
    if arguments.has("--debug") or arguments.has("--dev"):
        debug_cheats = true
        if hud != null:
            hud.debug_cheats = true
            hud.refresh_debug_controls()
    elif arguments.has("--trial"):
        start_run(true)
    if OS.has_feature("android") or DisplayServer.is_touchscreen_available() or arguments.has("--touch-controls"):
        var mobile=load("res://src/mobile_controls.gd").new()
        mobile.world=self
        add_child(mobile)
        get_tree().quit_on_go_back=false
    update_hud()
    queue_redraw()
    game_ready=true

func _cheats_allowed() -> bool:
    return debug_cheats or trial_mode

func _fit_playable_window() -> void:
    if DisplayServer.get_name() == "headless" or OS.has_feature("editor") == false and OS.get_name() == "Android":
        return
    # Official window stays 16:9-safe: the 1280x800 viewport scales uniformly into the screen.
    var usable: Rect2i = DisplayServer.screen_get_usable_rect()
    if usable.size.x < 640 or usable.size.y < 400:
        return
    var target := Vector2i(1280, 800)
    var scale: float = minf(float(usable.size.x) / 1280.0, float(usable.size.y) / 800.0)
    if scale < 0.999:
        target = Vector2i(maxi(640, int(1280.0 * scale)), maxi(400, int(800.0 * scale)))
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
    DisplayServer.window_set_size(target)

func start_run(trial: bool = false, preset: String = "") -> void:
    if hud != null:
        hud.debug_cheats = debug_cheats
        hud.refresh_debug_controls()
    # Protect the current normal run before resetting any world or transient data.
    if trial and running and not trial_mode and not restoring:
        if settings.get("autosave",true) and not demo and not animation_demo and not save_game():
            return
    map_view.reset_terrain()
    dodge_left = 0.0
    dodge_cooldown = 0.0
    dodge_direction = Vector2.RIGHT
    last_facing = Vector2.RIGHT
    departure_left = 0.0
    audio.stop_all()
    audio.set_paused(false)
    buff_levels.clear()
    refresh_stats()
    pickups.clear()
    companions.reset()
    armory.reset()
    _combat_targets_ready = false
    _simulating = false
    coins = 0
    wave_elapsed = 0.0
    boss_round = false
    boss_defeated = false
    boss_pending = false
    shop_open = false
    shop_stock.clear()
    wave_closing = false
    wave_buffer = 0.0
    player_frozen = false
    if not preset.is_empty():
        trial_preset = preset
    elif not trial:
        trial_preset = "base"
    stats_open = false
    stats_return_paused = false
    wave = 1
    pending_wave_rewards = 0
    upgrade_reason = "xp"
    heal_display = 0.0
    impact_strength = 0.0
    enemy_adaptation = 1.0
    position = Vector2.ZERO
    if world_camera != null:
        world_camera.offset = Vector2.ZERO
    active_link = Catalog.LINKS["none"].duplicate(true)
    pending_link = ""
    burning_fields.clear()
    demo_link_stage = ""
    for enemy in enemies:
        if is_instance_valid(enemy["view"]):
            enemy["view"].queue_free()
    enemies.clear()
    projectiles.clear()
    effects.particles.clear()
    for view in weapon_views.values():
        view.queue_free()
    inventory.clear()
    weapon_views.clear()
    weapon_runtime.clear()
    counters.clear()
    combo_cooldowns.clear()
    upgrade_choices.clear()
    upgrade_offer_levels.clear()
    replace_pending.clear()
    chest_queue = 0
    chest_marks.clear()
    player_position = Vector2(640, 401)
    player_hp = stats["max_hp"]
    invulnerable = 1.0
    elapsed = 0.0
    kills = 0
    xp = 0
    player_level = 1
    xp_needed = Growth.xp_needed_for(player_level)
    spawn_clock = 0.55
    enemy_serial = 0
    reset_elite_budget()
    paused = false
    upgrade_pending = false
    collapsed = false
    combo_mode = "none"
    formation_phase = 0.0
    trial_mode = trial
    refresh_stats()
    running = true
    player_hp = stats["max_hp"]
    combo_message_time = 0.0
    hero.scale = Vector2.ONE * (3.0 if animation_demo else 1.0)
    hero.phase = 0.0
    hero.amplitude = 0.0
    hero.position = player_position
    apply_character_view()
    if trial:
        var trial_ids: Array = Catalog.EXPANDED_IDS+["sling","totem"] if trial_preset=="expanded" else (Catalog.NEW_IDS + ["club","staff"] if trial_preset == "new" else Catalog.TRIAL_IDS)
        for key in trial_ids:
            grant_weapon(key)
    else:
        grant_weapon(starting_weapon)
    set_loadout_visible(true)
    sync_idle_loadout()
    hud.hide_menu()
    update_hud()
    queue_redraw()
    auto_save()

func clear_enemies() -> void:
    for enemy in enemies:
        if is_instance_valid(enemy["view"]):
            enemy["view"].queue_free()
    enemies.clear()
    projectiles.clear()
    burning_fields.clear()

func start_expanded_trial() -> void:
    start_run(true,"expanded" if trial_mode and trial_preset=="new" else "new")

func sync_idle_loadout() -> void:
    update_weapons(0.0,false)
    armory.advance(0.0,player_position,[],inventory,stats,prefer_elite,weapon_views,current_weapon_mounts())
    refresh_weapon_draw_order()

func expire_combat_fx() -> void:
    if effects != null:
        effects.expire_all()

func clear_weapons() -> void:
    for view in weapon_views.values():
        view.queue_free()
    inventory.clear()
    weapon_views.clear()
    weapon_runtime.clear()
    armory.reset()

func refresh_save_status(note: String = "") -> void:
    if hud != null and save_store != null:
        var result: Dictionary = save_store.read_run()
        var summary: Dictionary = result.get("state", {}) if result.get("ok", false) else {}
        var available: bool = result.get("ok", false) and not summary.get("finished", true)
        hud.configure_save(available, bool(settings.get("autosave", true)), note, summary)
        if not note.is_empty() and running and hud.screen == "combat":
            combo_message = note
            combo_message_time = 3.0

func begin_departure(trial: bool = false) -> void:
    if departure_left > 0.0:
        return
    if hud != null and not trial:
        character_id = hud.selected_character
        if not Catalog.CHARACTERS.has(character_id):
            character_id = "caveman"
        starting_weapon = str(Catalog.character(character_id).get("starting_weapon", starting_weapon))
    var previous: Texture2D = hud.snapshot_ui()
    start_run(trial)
    if not running:
        return
    departure_left = 2.4
    hud.show_departure(departure_left)
    hud.page_turn(previous, "burn")

func begin_continue() -> void:
    if departure_left > 0.0:
        return
    var previous: Texture2D = hud.snapshot_ui()
    if not continue_game():
        return
    if not shop_open:
        departure_left = 2.4
        hud.show_departure(departure_left)
        hud.page_turn(previous, "page")


func save_game(finished: bool = false) -> bool:
    if restoring or trial_mode or demo or animation_demo or (not running and not finished):
        refresh_save_status("试用/演示不会覆盖正常存档" if trial_mode or demo else "当前没有可保存的战斗")
        return false
    var result: Dictionary = save_store.write_run(SessionState.capture(self, finished))
    var note: String = "保存失败：" + str(result.get("error", "未知错误"))
    if result.get("ok", false):
        # A finished run is sealed, not continuable; saying 已保存 here made
        # players think they could pick the run back up from the death screen.
        # Leftover gems on the ground are discarded at wave end, so the toast
        # only shows coins already in the wallet.
        var shown_coins: int = coins
        note = "本局已结束 · 战绩已记录" if finished else "已保存 · 第%d关 · %d金币" % [wave, shown_coins]
    refresh_save_status(note)
    return result.get("ok",false)

func auto_save() -> void:
    if settings.get("autosave",true) and not restoring and running and not trial_mode and not demo and not animation_demo:
        save_game()

func continue_game() -> bool:
    var result: Dictionary = save_store.read_run()
    if not result.get("ok",false) or result.get("state",{}).get("finished",true):
        refresh_save_status("没有有效的未结束存档")
        return false
    restoring = true
    var accepted: bool = SessionState.apply(self,result["state"])
    restoring = false
    if accepted:
        if hud != null and Catalog.CHARACTERS.has(character_id):
            hud.selected_character = character_id
            hud.preview_character = character_id
        map_view.set_view(player_position,wave)
        player_position = map_view.move_body(player_position,player_position,18.0)
        hero.position = player_position
        for enemy in enemies:
            enemy["position"] = map_view.move_body(enemy["position"],enemy["position"],enemy["radius"])
            enemy["view"].position = enemy["position"]
        update_hud()
        recover_elite_budget()
    refresh_save_status(("已从有效备份恢复" if result.get("recovered",false) else "继续存档成功") if accepted else "存档内容无法恢复")
    return accepted

func set_autosave(enabled: bool) -> void:
    var previous: bool = bool(settings.get("autosave",true))
    settings["autosave"] = enabled
    var result: Dictionary = save_store.write_settings(settings)
    if not result.get("ok",false):
        settings["autosave"] = previous
    refresh_save_status("自动存档已" + ("开启" if enabled else "关闭") if result.get("ok",false) else "设置保存失败")

func go_home() -> void:
    if running and settings.get("autosave",true) and not trial_mode and not demo and not save_game():
        return
    departure_left = 0.0
    running = false
    paused = false
    stats_open = false
    stats_return_paused = false
    shop_open = false
    upgrade_pending = false
    wave_closing = false
    wave_buffer = 0.0
    player_frozen = false
    audio.stop_all()
    hud.show_menu("start",kills)
    update_hud()
    refresh_save_status()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        if running and settings.get("autosave",true) and not trial_mode and not demo and not save_game():
            return
        get_tree().quit()

func set_start_weapon(key: String) -> void:
    if Catalog.is_starter_weapon(key):
        starting_weapon = key

func refresh_stats() -> Dictionary:
    stats = Growth.stats(buff_levels)
    if not trial_mode:
        Catalog.apply_character_modifiers(stats, character_id)
    return stats

func apply_buff(key: String) -> bool:
    if not Growth.apply(buff_levels, key):
        return false
    refresh_stats()
    if key == "vitality":
        player_hp = minf(stats["max_hp"], player_hp + 2.0)
    combo_message = Growth.BUFFS[key]["name"] + " Lv.%d" % buff_levels[key]
    combo_message_time = 2.2
    update_hud()
    return true

func toggle_stats() -> void:
    if upgrade_pending or shop_open or animation_demo:
        return
    if not running:
        stats_open = not stats_open
        if stats_open:
            stats_home_return = hud.screen
            hud.show_stats(buff_levels,stats,{"wave":wave,"adaptive":enemy_adaptation,"enemy":Progression.enemy_profile(wave,"hunter",enemy_adaptation),"in_combat":false})
        else:
            _return_from_home_stats()
        return
    if not stats_open:
        stats_return_paused = paused
        stats_home_return = hud.screen
    stats_open = not stats_open
    paused = true if stats_open else stats_return_paused
    audio.set_paused(paused)
    if stats_open:
        hud.show_stats(buff_levels, stats, {"wave": wave, "adaptive": enemy_adaptation, "enemy": Progression.enemy_profile(wave, "hunter", enemy_adaptation),"in_combat":true})
    elif stats_home_return == "help":
        hud.show_help("gameplay", true)
    elif paused:
        hud.show_menu("pause",kills)
    else:
        hud.hide_menu()
    update_hud()

func _return_from_home_stats() -> void:
    match stats_home_return:
        "cast":
            hud.show_cast("ui_back")
        "help":
            hud.show_help("gameplay", false)
        "settings":
            hud.show_settings(false)
        "continue":
            hud.show_continue()
        _:
            hud.show_title()

func request_trial_growth() -> void:
    if trial_mode and running and not paused and not upgrade_pending and not shop_open:
        present_upgrade("trial")

func grant_weapon(key: String, level: int = 1) -> bool:
    var result: Dictionary = Rules.equip(inventory, key)
    if not result.get("accepted", false):
        return false
    if not result.get("upgraded", false):
        for item in inventory:
            if item["id"] == key:
                item["level"] = clampi(level, 1, Growth.MAX_WEAPON_LEVEL)
                break
    bind_weapon_view(key)
    rebuild_groups()
    return true

func bind_weapon_view(key: String) -> void:
    if not Catalog.WEAPONS.has(key):
        return
    if not weapon_views.has(key):
        var view: Sprite2D = library.make_weapon(key, Catalog.WEAPONS[key]["size"] * (1.0 if key == "sling" else 1.12))
        view.set_meta("base_scale", view.scale)
        weapons_layer.add_child(view)
        weapon_views[key] = view
        weapon_runtime[key] = {"position": player_position, "cooldown": 0.03, "hit_times": {}, "initialized": false, "recoil": 0.0, "chain_state": "rest", "chain_position": player_position, "chain_direction": Vector2.RIGHT, "chain_distance": 0.0, "chain_hit_ids": [], "chain_damage": 0.0, "blend_left": 0.0, "blend_start": player_position, "trail_next": 0.0, "orbit_phase": 0.0}
    var visual: Sprite2D = weapon_views[key]
    visual.texture = library.weapon_texture(key, weapon_level(key))
    var extent: float = float(visual.texture.get_meta("display_extent", maxf(visual.texture.get_width(), visual.texture.get_height())))
    visual.scale = Vector2.ONE * Catalog.WEAPONS[key].size * (1.0 if key == "sling" else 1.12) / extent
    visual.set_meta("base_scale", visual.scale)

func unbind_weapon_view(key: String) -> void:
    if weapon_views.has(key):
        var view: Sprite2D = weapon_views[key]
        if is_instance_valid(view):
            view.queue_free()
        weapon_views.erase(key)
    weapon_runtime.erase(key)
    if armory != null and armory.states.has(key):
        armory.states.erase(key)

func _fill_offer_levels(ids: Array) -> void:
    upgrade_offer_levels.clear()
    for key in ids:
        if Catalog.WEAPONS.has(str(key)) and Growth.item_level(str(key), inventory, {}) <= 0:
            upgrade_offer_levels[str(key)] = Growth.roll_new_weapon_level(rng, wave)

func rebuild_groups() -> void:
    var ids: Array = []
    for item in inventory:
        ids.append(item["id"])
    available_links = Rules.link_options(ids)
    active_link = Rules.link_profile(active_link.get("id", "none"), ids)
    groups = [] if active_link["id"] == "none" else [active_link]
    combo_mode = active_link["id"]
    announce_link_ready()

func select_link(link_id: String) -> void:
    var ids: Array = []
    for item in inventory:
        ids.append(item["id"])
    var profile: Dictionary = Rules.link_profile(link_id, ids)
    if active_link.get("kind", "none") == "chain":
        var key: String = active_link["weapons"][1]
        var runtime: Dictionary = weapon_runtime[key]
        if runtime["chain_state"] != "rest":
            if runtime["chain_state"] == "out":
                runtime["chain_state"] = "back"
                runtime["chain_hit_ids"] = []
                audio.play("chain_in", -1.0)
            pending_link = profile["id"]
            combo_message = "先收回锁链武器，再切换"
            combo_message_time = 1.2
            update_hud()
            return
    apply_link(profile)

func apply_link(profile: Dictionary) -> void:
    if active_link.get("kind", "none") == "chain":
        var key: String = active_link["weapons"][1]
        weapon_runtime[key]["blend_left"] = 0.2
        weapon_runtime[key]["blend_start"] = weapon_views[key].position
    active_link = profile
    pending_link = ""
    groups = [] if profile["id"] == "none" else [profile]
    combo_mode = profile["id"]
    update_hud()

func switch_formation() -> void:
    if upgrade_pending or wave_closing or shop_open or player_frozen:
        return
    collapsed = not collapsed
    update_hud()

func announce_link_ready() -> void:
    if available_links.size() <= 1 or bool(settings.get("seen_link_guide", false)):
        return
    var names: PackedStringArray = PackedStringArray()
    for recipe in available_links:
        if str(recipe.get("id", "none")) != "none":
            names.append(str(recipe.get("name", "")))
    if names.is_empty():
        return
    combo_message = "已集齐联动（%s）。按 Q 切换；锁链从火药筒炮口弹出。暂停菜单的「帮助」里有完整说明。" % " / ".join(names)
    combo_message_time = 6.5
    settings["seen_link_guide"] = true
    var result: Dictionary = save_store.write_settings(settings)
    if not result.get("ok", false):
        settings["seen_link_guide"] = false

func toggle_hud_hidden() -> void:
    if hud == null or not running or shop_open or upgrade_pending or not hud.has_method("toggle_hud_hidden"):
        return
    if paused or stats_open:
        return
    hud.toggle_hud_hidden()

func switch_combo_mode() -> void:
    if not running or upgrade_pending or wave_closing or shop_open or player_frozen or available_links.size() <= 1:
        return
    var current: String = pending_link if not pending_link.is_empty() else active_link["id"]
    var index: int = 0
    for i in range(available_links.size()):
        if available_links[i]["id"] == current:
            index = i
    select_link(available_links[(index + 1) % available_links.size()]["id"])

func switch_elite() -> void:
    prefer_elite = not prefer_elite
    update_hud()

func restart_current_run() -> void:
    start_run(trial_mode, trial_preset if trial_mode else "")

func toggle_pause() -> void:
    if departure_left > 0.0 or wave_closing:
        return
    if stats_open:
        toggle_stats()
        return
    if hud.screen in ["help", "settings", "continue"]:
        hud.close_front_modal()
        return
    if not running or upgrade_pending or shop_open or animation_demo:
        return
    paused = not paused
    audio.set_paused(paused)
    if paused:
        hud.show_menu("pause", kills)
    else:
        hud.hide_menu()
    update_hud()

func finish_run(won: bool) -> void:
    running = false
    paused = false
    upgrade_pending = false
    stats_open = false
    shop_open = false
    wave_closing = false
    wave_buffer = 0.0
    player_frozen = false
    impact_strength = 0.0
    position = Vector2.ZERO
    if world_camera != null:
        world_camera.offset = Vector2.ZERO
    if not trial_mode and not demo:
        save_game(true)
    if audio != null:
        audio.play("win" if won else "lose", -6.0)
    hud.show_menu("win" if won else "lose", kills, "ui_open", settlement_summary())
    update_hud()

func settlement_summary() -> Dictionary:
    var weapons: Array = []
    for item in inventory:
        weapons.append({"id": item.get("id", ""), "level": int(item.get("level", 1))})
    return {"wave": wave, "elapsed": elapsed, "level": player_level, "weapons": weapons, "kills": kills, "hp": player_hp, "max_hp": stats.get("max_hp", 0.0)}

func present_upgrade(reason: String = "xp") -> void:
    if upgrade_pending or not running or shop_open or reason == "wave":
        return
    upgrade_choices = Growth.choices(inventory, buff_levels, rng)
    if upgrade_choices.is_empty():
        if reason == "xp":
            xp = maxf(0.0, xp - xp_needed)
        player_hp = minf(stats["max_hp"], player_hp + 2.0)
        try_present_chest()
        return
    upgrade_reason = reason
    upgrade_pending = true
    _fill_offer_levels(upgrade_choices)
    audio.set_paused(true)
    hud.show_choices(upgrade_choices, inventory, buff_levels, reason, wave, upgrade_offer_levels)
    update_hud()

func reachable_chest_position(at: Vector2) -> Vector2:
    # Every finite world coordinate is reachable on the streamed map.
    return at

func offer_elite_chest(at: Vector2) -> void:
    if demo or animation_demo:
        return
    chest_marks.append({"position": reachable_chest_position(at), "age": 0.0})

func update_chests(delta: float) -> void:
    if not running or paused or upgrade_pending or shop_open or departure_left > 0.0 or player_frozen:
        return
    var remaining: Array = []
    for chest in chest_marks:
        chest["age"] = float(chest.get("age", 0.0)) + delta
        # Chest pickup is physical contact, independent of XP attraction buffs.
        if player_position.distance_to(chest["position"]) <= 28.0:
            chest_queue += 1
        else:
            remaining.append(chest)
    chest_marks = remaining

func try_present_chest() -> void:
    if chest_queue <= 0 or not running or upgrade_pending or shop_open or paused or departure_left > 0.0:
        return
    if wave_closing and wave_buffer > 0.000001:
        return
    var offers: Array = Growth.chest_choices(inventory, buff_levels, rng)
    chest_queue -= 1
    if offers.is_empty():
        try_present_chest()
        return
    upgrade_choices = offers
    upgrade_reason = "chest"
    upgrade_pending = true
    _fill_offer_levels(upgrade_choices)
    audio.set_paused(true)
    hud.show_choices(upgrade_choices, inventory, buff_levels, "chest", wave, upgrade_offer_levels)
    update_hud()

func on_choice(key: String) -> void:
    if not upgrade_pending or not upgrade_choices.has(key) or not replace_pending.is_empty():
        return
    if Growth.BUFFS.has(key):
        if not apply_buff(key):
            return
        _finish_successful_choice()
        return
    if Growth.item_level(key, inventory, {}) > 0:
        if not grant_weapon(key):
            return
        _finish_successful_choice()
        return
    var offered: int = int(upgrade_offer_levels.get(key, 1))
    if inventory.size() >= Rules.MAX_WEAPONS:
        begin_replace({"id": key, "level": offered, "source": "choice"})
        return
    if not grant_weapon(key, offered):
        return
    _finish_successful_choice()

func _finish_successful_choice() -> void:
    if upgrade_reason == "xp":
        xp = maxf(0.0, xp - xp_needed)
        player_level += 1
        xp_needed = Growth.xp_needed_for(player_level)
        player_hp = minf(stats["max_hp"], player_hp + 1.0)
        if audio != null:
            audio.play("level_up", -6.0)
    elif upgrade_reason != "chest":
        player_hp = minf(stats["max_hp"], player_hp + 1.0)
    upgrade_pending = false
    upgrade_choices.clear()
    upgrade_offer_levels.clear()
    replace_pending.clear()
    audio.set_paused(false)
    hud.hide_menu()
    update_hud()
    auto_save()
    if wave_closing and wave_buffer <= 0.000001:
        continue_round_rewards()
    else:
        try_present_chest()

func sell_reward(key: String) -> bool:
    if not running or not upgrade_pending or shop_open or not replace_pending.is_empty():
        return false
    if not upgrade_choices.has(key) or (not Catalog.WEAPONS.has(key) and not Growth.BUFFS.has(key)):
        return false
    var owned: int = Growth.item_level(key, inventory, buff_levels)
    var offered: int=owned+1
    if Catalog.WEAPONS.has(key):
        offered=mini(Growth.MAX_WEAPON_LEVEL,owned+1) if owned>0 else clampi(int(upgrade_offer_levels.get(key,1)),1,Growth.MAX_WEAPON_LEVEL)
    elif owned>=int(Growth.BUFFS[key].max_level): return false
    # Convert only this offered reward. Equipped weapons and other candidates are untouched.
    coins += Economy.reward_sell_price(key, wave, offered)
    _finish_successful_choice()
    return true

func visible_world_rect() -> Rect2:
    return Rect2(player_position - Vector2(640,400), Vector2(1280,800))

func update_hud() -> void:
    if map_view != null:
        map_view.set_view(player_position,wave)
        map_view.animate_world = running and not paused and not upgrade_pending and not shop_open and not wave_closing
    if music != null:
        music.set_context("title" if not running else ("pause" if paused or upgrade_pending or shop_open or wave_closing else ("volcano" if wave >= 9 else ("grove" if wave >= 5 else "battle"))))
    if world_camera != null:
        world_camera.position = player_position
        world_camera.force_update_scroll()
    if hud == null:
        return
    hud.update_growth(buff_levels, stats, wave)
    hud.update_state(player_hp, elapsed, kills, xp, xp_needed, inventory, collapsed, active_link, prefer_elite, trial_mode)
    var boss: Dictionary = {}
    for enemy in enemies:
        if enemy["kind"] == "boss" and enemy["hp"] > 0.0:
            boss = enemy
            break
    hud.update_round(wave,wave_elapsed,boss_round,coins,boss.get("hp",0.0),boss.get("max_hp",0.0))
    hud.update_world_status(WorldMap.BIOMES[WorldMap.biome_for_wave(wave)],dodge_cooldown,DODGE_COOLDOWN,available_links,link_hint_text())
    if combo_message_time > 0.0:
        hud.notice_label.text = combo_message

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    var code: int = event.physical_keycode
    if hud != null and not str(hud.bind_listen_action).is_empty():
        hud.handle_bind_listen(code)
        return
    if departure_left > 0.0 or hud.handle_front_key(code):
        return
    if code == KEY_F2:
        if _cheats_allowed():
            start_run(true, "base")
        return
    if code == KEY_F3:
        if _cheats_allowed():
            start_expanded_trial()
        return
    if code == KEY_R:
        if _cheats_allowed() or trial_mode:
            start_run(trial_mode, trial_preset)
        return
    if code == KEY_SHIFT:
        request_dodge(read_movement())
        return
    if KeyBindings.matches_code(code, "save"):
        save_game()
        return
    if KeyBindings.matches_code(code, "scatter"):
        switch_formation()
        return
    if KeyBindings.matches_code(code, "link"):
        switch_combo_mode()
        return
    if KeyBindings.matches_code(code, "aim"):
        switch_elite()
        return
    if KeyBindings.matches_code(code, "hide_ui"):
        toggle_hud_hidden()
        return
    if KeyBindings.matches_code(code, "stats"):
        toggle_stats()
        return
    if KeyBindings.matches_code(code, "growth_trial"):
        request_trial_growth()
        return
    if KeyBindings.matches_code(code, "cancel"):
        if hud != null and hud.screen == "replace_confirm" and hud.has_method("cancel_replace_confirm"):
            hud.cancel_replace_confirm()
        elif not replace_pending.is_empty():
            cancel_replace()
        elif hud != null and hud.screen == "restart_confirm" and hud.has_method("cancel_restart"):
            hud.cancel_restart()
        elif hud != null and hud.screen == "help_confirm" and hud.has_method("cancel_help_trial"):
            hud.cancel_help_trial()
        else:
            toggle_pause()
        return
    if KeyBindings.matches_code(code, "confirm"):
        if hud != null:
            match hud.screen:
                "lose", "win":
                    hud.confirm_cast()
                "restart_confirm":
                    hud.confirm_restart()
                "replace_confirm":
                    hud.confirm_replace_choice()
                "help_confirm":
                    hud.confirm_help_trial()
                "pause":
                    toggle_pause()
                "shop":
                    hud.next_round_requested.emit()
        return
    var slot: int = KeyBindings.shop_slot(code)
    if slot >= 0:
        if not replace_pending.is_empty():
            if slot >= 0 and slot < inventory.size() and hud != null and hud.screen == "replace":
                hud.choose_replace_slot(str(inventory[slot]["id"]))
        elif hud != null and hud.screen == "shop":
            if hud.shop_index_available(slot):
                hud.request_shop_buy(slot)
        elif slot < hud.choice_ids.size():
            hud.choose_index(slot)

func read_movement() -> Vector2:
    return Vector2(
        float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
        float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))+touch_input

func request_dodge(direction: Vector2 = Vector2.ZERO) -> bool:
    if not running or player_hp <= 0.0 or paused or shop_open or upgrade_pending or stats_open or player_frozen or wave_closing or departure_left > 0.0 or animation_demo:
        return false
    if dodge_cooldown > 0.000001 or dodge_left > 0.000001:
        return false
    dodge_direction = direction.normalized() if direction.length_squared() > 0.001 else last_facing
    last_facing = dodge_direction
    dodge_left = DODGE_DURATION
    dodge_cooldown = DODGE_COOLDOWN
    invulnerable = maxf(invulnerable, DODGE_DURATION + 0.02)
    effects.dodge_streak(player_position, dodge_direction)
    return true

func get_dodge_state() -> Dictionary:
    return {"left": dodge_left, "cooldown": dodge_cooldown, "ready": dodge_cooldown <= 0.000001}

func _physics_process(delta: float) -> void:
    var movement: Vector2 = Vector2.ZERO
    if demo:
        var desired: Vector2 = Vector2(640 + sin(elapsed * 0.65) * 145, 403 + sin(elapsed * 1.15) * 75)
        if player_position.distance_to(desired) > 6:
            movement = (desired - player_position).normalized()
        if link_demo:
            var clock: float = fmod(elapsed, 30.0)
            var wanted: String = "none" if clock < 6.0 else ("rune_shell" if clock < 15.0 else ("chain_axe" if clock < 25.0 else "none"))
            if wanted != demo_link_stage:
                select_link(wanted)
                demo_link_stage = wanted
                if wanted != "none":
                    spawn_enemy("tank", player_position + Vector2(160, -12))
                    enemies.back()["hp"] = 140.0
                    enemies.back()["max_hp"] = 140.0
            collapsed = clock > 20.0
    else:
        movement = read_movement()
    simulate(delta, movement)

func simulate(delta: float, movement: Vector2) -> void:
    if hurt_flash > 0.0:
        hurt_flash = maxf(0.0, hurt_flash - delta * 2.6)
    if hud != null and hud.has_method("set_hurt_flash"):
        var warning: float = 0.0
        if running and player_hp > 0.0 and float(stats.get("max_hp", 0.0)) > 0.0:
            var fraction: float = player_hp / float(stats["max_hp"])
            if fraction <= 0.5:
                warning = 0.16 + 0.14 * (1.0 - clampf(fraction / 0.5, 0.0, 1.0))
        hud.set_hurt_flash(maxf(hurt_flash * 0.62, warning))
    if departure_left > 0.0 and running and not paused:
        departure_left = maxf(0.0, departure_left - delta)
        hud.update_departure(departure_left)
        if is_zero_approx(departure_left):
            hud.hide_menu()
        return
    if animation_demo:
        animate_showcase(delta)
        return
    if not running or paused or upgrade_pending or shop_open:
        return
    if player_frozen:
        movement = Vector2.ZERO
    if wave_closing:
        absorb_round_resources(delta)
        wave_buffer=maxf(0,wave_buffer-delta)
        effects.advance(delta)
        if wave_buffer<=0.000001: _finish_wave_closing()
        queue_redraw()
        return
    elapsed += delta
    wave_elapsed += delta
    _simulating = true
    _combat_targets_ready = false
    var terrain_exposure: float = maxf(0.0,delta-invulnerable)
    invulnerable = maxf(0.0, invulnerable - delta)
    combo_message_time = maxf(0.0, combo_message_time - delta)
    var old_position: Vector2 = player_position
    dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
    if movement.length_squared() > 0.001:
        last_facing = movement.normalized()
    var velocity: Vector2 = movement.limit_length(1.0) * stats["speed"]
    if player_frozen:
        dodge_left = 0.0
    if dodge_left > 0.000001:
        var dash_step: float = minf(delta, dodge_left)
        velocity = dodge_direction * DODGE_DISTANCE / DODGE_DURATION
        player_position = map_view.move_body(player_position, player_position + velocity * dash_step, 18.0)
        dodge_left = maxf(0.0, dodge_left - dash_step)
        effects.dodge_streak(old_position, dodge_direction)
    else:
        player_position = map_view.move_body(player_position, player_position + velocity * delta, 18.0)
    hero.position = player_position
    var previous_step: int = int(hero.phase / PI)
    hero.animate(velocity, old_position.distance_to(player_position), delta)
    audio.advance(delta)
    if velocity.length() > 10.0 and previous_step != int(hero.phase / PI):
        audio.play("step", -8.0)
    effects.advance(delta)
    impact_strength = move_toward(impact_strength, 0.0, delta * 16.0)
    world_camera.offset = Vector2(sin(elapsed * 81.0), cos(elapsed * 73.0)) * impact_strength
    var healed: float = minf(stats["max_hp"] - player_hp, stats["regen"] * delta)
    player_hp += maxf(0.0, healed)
    heal_display += maxf(0.0, healed)
    if heal_display >= 0.5:
        effects.floating_text(player_position, "+%.1f" % heal_display, Color("#9bf1a8"))
        heal_display = 0.0
    update_terrain_damage(delta,terrain_exposure)
    if not running:
        update_hud()
        _simulating = false
        return
    update_enemies(delta)
    if not running:
        update_hud()
        queue_redraw()
        _simulating = false
        return
    update_companions(delta)
    update_weapons(delta)
    update_armory(delta)
    update_projectiles(delta)
    update_burning_fields(delta)
    if not running:
        update_hud()
        queue_redraw()
        _simulating = false
        return
    var living: Array = []
    for enemy in enemies:
        if enemy["hp"] > 0.0:
            living.append(enemy)
        else:
            enemy["view"].queue_free()
    enemies = living
    update_pickups(delta)
    update_chests(delta)
    if (boss_round and boss_defeated) or (not boss_round and wave_elapsed >= WAVE_SECONDS - 0.000001):
        start_wave_closing()
        apply_weapon_glows(delta)
        update_hud()
        queue_redraw()
        _simulating = false
        return
    spawn_clock -= delta
    # Late game keeps swelling (Juniper, 2026-11-17): past wave 26 the alive cap
    # grows +3/wave to 126 by wave 40, and the spawn interval keeps falling to
    # a 0.18 s floor by wave 33, so deep waves feel denser than wave 29 instead
    # of freezing at the wave-26 density.
    var alive_cap: int = 42 + clampi((wave - 5) * 2, 0, 42) + clampi((wave - 26) * 3, 0, 42)
    if spawn_clock <= 0.0 and enemies.size() < alive_cap:
        var spawn_interval: float = 0.62 - (wave - 1) * 0.10 if wave <= 3 else maxf(0.18, 0.42 - (wave - 3) * 0.008)
        spawn_clock = maxf(1.5, 3.4 - float(maxi(0, wave / 5 - 1)) * 0.28) if boss_round else spawn_interval
        if boss_pending:
            spawn_enemy("boss",offscreen_point(1)+Vector2(48,0),false,"enter")
            var boss: Dictionary=enemies.back()
            var formula_hp: float = float(boss.max_hp)
            var capped_hp: float = Progression.cap_boss_hp(formula_hp, Progression.estimate_power(inventory,buff_levels,active_link))
            boss.hp=capped_hp
            boss.max_hp=capped_hp
            # Later bosses are the same species but visibly bigger specimens:
            # tier 2 (wave 10) +16% size, tier 3 (wave 15) +32%, and so on.
            var boss_tier: int = maxi(1, wave / 5)
            if boss_tier > 1 and boss.get("view") != null:
                boss["view"].scale = Vector2.ONE * (1.0 + 0.16 * float(boss_tier - 1))
            boss.timer=1.6
            boss_pending=false
            if audio != null:
                audio.play("boss_appear", -4.0)
        else:
            var kinds: Array=EnemyRoster.spawn_pool(wave,wave_elapsed,trial_mode,boss_round)
            spawn_enemy(kinds[rng.randi_range(0,kinds.size()-1)], Vector2(INF, INF), true,"enter" if wave_elapsed<2 else "")
    if not demo:
        if xp >= xp_needed:
            present_upgrade()
    try_present_chest()
    apply_weapon_glows(delta)
    update_hud()
    queue_redraw()
    _simulating = false

func advance_wave(next_wave: int) -> void:
    var old_wave: int = wave
    wave = next_wave
    var milestone: bool = wave / 5 > old_wave / 5
    if milestone:
        enemy_adaptation = Progression.adaptation(wave, Progression.estimate_power(inventory, buff_levels, active_link), enemy_adaptation)
    for enemy in enemies:
        var fraction: float = clampf(enemy["hp"] / maxf(0.001, enemy["max_hp"]), 0.0, 1.0)
        var profile: Dictionary = Progression.enemy_profile(wave, enemy["kind"], enemy_adaptation, enemy["elite"])
        enemy["max_hp"] = profile["hp"]
        enemy["hp"] = profile["hp"] * fraction
        for key in ["damage", "dodge", "speed_multiplier", "bullet_multiplier"]:
            enemy[key] = profile[key]
        enemy["view"].health_fraction = fraction
    combo_message = ("第 %d 关 · Boss来袭" if milestone else "第 %d 关 · 出发") % wave
    combo_message_time = 4.0

func begin_round(stage: int) -> void:
    wave_closing = false
    wave_buffer = 0.0
    clear_enemies()
    expire_combat_fx()
    pickups.clear()
    armory.reset()
    if not pending_link.is_empty():
        var owned_ids: Array=[]
        for item in inventory: owned_ids.append(item.id)
        apply_link(Rules.link_profile(pending_link,owned_ids))
    for runtime in weapon_runtime.values():
        runtime["hit_times"].clear()
        runtime["cooldown"] = 0.05
        runtime["chain_state"]="rest"
        runtime["chain_hit_ids"]=[]
        runtime["chain_position"]=chain_anchor()
        runtime["initialized"]=false
        runtime["recoil"]=0.0
        runtime["blend_left"]=0.0
    advance_wave(stage)
    wave_elapsed = 0.0
    shop_open = false
    boss_round = wave % 5 == 0
    boss_defeated = false
    spawn_clock = 0.55
    boss_pending=boss_round
    reset_elite_budget()
    player_frozen = false
    set_loadout_visible(true)
    sync_idle_loadout()
    audio.set_paused(false)
    hud.hide_menu()
    update_hud()
    auto_save()
    try_present_chest()

func collect_all_drops() -> void:
    for drop in pickups:
        var kind: String = str(drop.get("kind","xp"))
        if kind == "coin":
            coins += int(drop["value"])
        elif kind == "blood":
            player_hp = minf(stats["max_hp"], player_hp + float(drop.get("value", LootRules.BLOOD_PACK_HEAL)))
        else:
            xp += LootDrops.experience_value(drop) * stats["xp_multiplier"]
    pickups.clear()

func discard_remaining_drops() -> void:
    # Uncollected gems and blood packs are not vacuumed in at wave end.
    pickups.clear()

func dismiss_remaining_enemies() -> void:
    var animate: bool = DisplayServer.get_name() != "headless"
    for enemy in enemies:
        var view = enemy.get("view")
        if animate and effects != null and float(enemy.get("hp", 0.0)) > 0.0:
            var at: Vector2 = enemy["position"]
            var size: float = 36.0
            if is_instance_valid(view):
                size = view.display_width
            effects.puff(at, Color("#f4ead6"), maxf(16.0, size * 0.42), absi(int(enemy.get("id", 0))) % 3)
        if is_instance_valid(view):
            view.queue_free()
    enemies.clear()
    projectiles.clear()
    burning_fields.clear()

func set_loadout_visible(value: bool) -> void:
    if animation_demo:
        value = false
    if weapons_layer != null:
        weapons_layer.visible = value
    if armory != null:
        armory.visible = value
    if companions != null:
        companions.visible = value
    for view in weapon_views.values():
        if is_instance_valid(view):
            view.visible = value

func is_loadout_visible() -> bool:
    if weapons_layer != null and not weapons_layer.visible:
        return false
    for view in weapon_views.values():
        if is_instance_valid(view) and view.visible:
            return true
    return false

func start_wave_closing() -> void:
    if wave_closing or shop_open or not running:
        return
    spawn_clock = 9999.0
    expire_combat_fx()
    dismiss_remaining_enemies()
    armory.reset()
    projectiles.clear()
    burning_fields.clear()
    player_frozen = true
    dodge_left=0.0
    set_loadout_visible(true)
    impact_strength = 0.0
    position = Vector2.ZERO
    if world_camera != null:
        world_camera.offset = Vector2.ZERO
    wave_closing = true
    wave_buffer = WAVE_BUFFER
    audio.stop_all()
    audio.set_paused(true)
    auto_save()

func _finish_wave_closing() -> void:
    wave_buffer = 0.0
    player_frozen = true
    discard_remaining_drops()
    collect_round_chests()
    if demo:
        begin_round(wave + 1)
    else:
        continue_round_rewards()

func absorb_round_resources(_delta: float) -> void:
    # Leftover gems stay put during the finish pause and are discarded when it
    # ends. Ground chests are queued afterwards, not pulled in during this beat.
    update_hud()

func collect_round_chests() -> void:
    chest_queue += chest_marks.size()
    chest_marks.clear()

func continue_round_rewards() -> void:
    if upgrade_pending or not running or shop_open:
        return
    while xp >= xp_needed:
        present_upgrade("xp")
        if upgrade_pending:
            return
    try_present_chest()
    if upgrade_pending:
        return
    open_round_shop()

func end_round() -> void:
    if not running or shop_open:
        return
    wave_closing = true
    wave_buffer = 0.0
    player_frozen = true
    dismiss_remaining_enemies()
    discard_remaining_drops()
    collect_round_chests()
    continue_round_rewards()

func open_round_shop() -> void:
    wave_closing = false
    wave_buffer = 0.0
    player_frozen = true
    discard_remaining_drops()
    clear_enemies()
    expire_combat_fx()
    armory.reset()
    set_loadout_visible(false)
    impact_strength = 0.0
    position = Vector2.ZERO
    if world_camera != null:
        world_camera.offset = Vector2.ZERO
    shop_open = true
    shop_rerolls = 0
    shop_stock = Economy.stock(inventory,buff_levels,wave,rng)
    audio.set_paused(true)
    show_current_shop()
    update_hud()
    auto_save()

func show_current_shop(animate: bool = true, highlight: int = -1) -> void:
    hud.show_shop(shop_stock,coins,wave,inventory,buff_levels,player_hp,stats["max_hp"],animate,highlight,Economy.reroll_price(wave,shop_rerolls))

func reroll_shop() -> void:
    if not shop_open:
        return
    var cost: int = Economy.reroll_price(wave, shop_rerolls)
    if coins < cost:
        return
    coins -= cost
    shop_rerolls += 1
    shop_stock = Economy.stock(inventory,buff_levels,wave,rng)
    show_current_shop(false)
    update_hud()
    auto_save()

# When no link is available yet but the player already holds one half of a
# recipe, name the missing half — the generic recipe list left players
# guessing which piece they were waiting for.
func link_hint_text() -> String:
    if available_links.size() > 1:
        var names: PackedStringArray = PackedStringArray()
        for recipe in available_links:
            if str(recipe.get("id", "none")) != "none":
                names.append(str(recipe.get("name", "")))
        var current: String = str(active_link.get("name", "不联动"))
        return "已可联动：按 Q 切换（当前：%s）。锁链从火药筒炮口弹出。帮助里有完整配方。" % current
    for link_id in Catalog.LINK_ORDER:
        if link_id == "none":
            continue
        var weapons: Array = Catalog.LINKS[link_id]["weapons"]
        if weapons.size() != 2:
            continue
        # weapon_level() defaults to 1 for unowned weapons, so ownership is
        # checked against the inventory itself.
        var first_owned: bool = Growth.item_level(str(weapons[0]), inventory, {}) > 0
        var second_owned: bool = Growth.item_level(str(weapons[1]), inventory, {}) > 0
        if first_owned == second_owned:
            continue
        var held: String = str(weapons[0]) if first_owned else str(weapons[1])
        var missing: String = str(weapons[1]) if first_owned else str(weapons[0])
        return "联动将成：已有%s，还差%s → %s（集齐后按 Q 切换）" % [Catalog.WEAPONS[held]["name"], Catalog.WEAPONS[missing]["name"], Catalog.LINKS[link_id]["name"]]
    return ""

func buy_shop_item(index: int) -> bool:
    if not shop_open or index < 0 or index >= shop_stock.size():
        return false
    var offer: Dictionary = shop_stock[index]
    if not Economy.valid(offer,coins,inventory,buff_levels,player_hp,stats["max_hp"]):
        return false
    var key: String = offer["id"]
    var accepted: bool = true
    if key == "heal":
        player_hp = minf(stats["max_hp"],player_hp + 3.0)
    elif Growth.BUFFS.has(key):
        accepted = apply_buff(key)
    elif Growth.item_level(key, inventory, {}) > 0:
        accepted = grant_weapon(key)
    elif inventory.size() >= Rules.MAX_WEAPONS:
        begin_replace({"id": key, "level": int(offer.get("level", 1)), "source": "shop", "shop_index": index, "price": int(offer["price"])})
        return true
    else:
        accepted = grant_weapon(key, int(offer.get("level", 1)))
    if not accepted:
        return false
    coins -= int(offer["price"])
    offer["sold"] = true
    show_current_shop(false, index)
    update_hud()
    auto_save()
    return true

func begin_replace(pending: Dictionary) -> void:
    if pending.is_empty() or not Catalog.WEAPONS.has(str(pending.get("id", ""))):
        return
    replace_pending = pending.duplicate(true)
    hud.show_replace(replace_pending, inventory, wave)

func confirm_replace(remove_id: String) -> bool:
    if replace_pending.is_empty():
        return false
    var new_id: String = str(replace_pending.get("id", ""))
    var new_level: int = int(replace_pending.get("level", 1))
    var source: String = str(replace_pending.get("source", ""))
    var price_paid: int = int(replace_pending.get("price", 0))
    var shop_index: int = int(replace_pending.get("shop_index", -1))
    if source == "shop":
        if not shop_open or shop_index < 0 or shop_index >= shop_stock.size() or coins < price_paid:
            return false
        if shop_stock[shop_index].get("sold", false) or str(shop_stock[shop_index].get("id", "")) != new_id:
            return false
    var old_level: int = 1
    for item in inventory:
        if str(item.get("id", "")) == str(remove_id):
            old_level = int(item.get("level", 1))
            break
    var refund: int = Economy.sell_price(remove_id, wave, old_level)
    var result: Dictionary = Rules.replace_weapon(inventory, remove_id, new_id, new_level)
    if not result.get("accepted", false):
        return false
    unbind_weapon_view(remove_id)
    bind_weapon_view(new_id)
    rebuild_groups()
    coins += refund
    if source == "shop":
        coins -= price_paid
        shop_stock[shop_index]["sold"] = true
        replace_pending.clear()
        show_current_shop(false, shop_index)
        update_hud()
        auto_save()
        return true
    _finish_successful_choice()
    return true

func cancel_replace() -> void:
    if replace_pending.is_empty():
        return
    var source: String = str(replace_pending.get("source", ""))
    replace_pending.clear()
    if source == "shop":
        show_current_shop(false)
    elif upgrade_pending:
        hud.show_choices(upgrade_choices, inventory, buff_levels, upgrade_reason, wave, upgrade_offer_levels)
    else:
        hud.hide_menu()
    update_hud()

func leave_shop() -> void:
    if not shop_open:
        return
    begin_round(wave + 1)

func pickup_magnet_radius() -> float:
    # Later waves pull a bit farther so large fields of loot don't sit idle.
    return float(stats["pickup_radius"]) + 18.0 * float(clampi(wave - 3, 0, 10))

func update_pickups(delta: float) -> void:
    var remaining: int = 0
    var bursts: int = 0
    var radius_squared: float = pickup_magnet_radius() * pickup_magnet_radius()
    # Hoisted out of the per-pickup loop (same math as pickup_visible_point).
    var view_area: Rect2 = visible_world_rect()
    var reveal_floor_y: float = view_area.position.y + PICKUP_TOP_HUD_PAD
    for index in range(pickups.size()):
        var stone: Dictionary = pickups[index]
        var revealed: Vector2 = stone["position"]
        if revealed.y < reveal_floor_y and revealed.y >= view_area.position.y - 12.0 and revealed.x >= view_area.position.x - 8.0 and revealed.x <= view_area.end.x + 8.0:
            revealed.y = reveal_floor_y
        if revealed.y > stone["position"].y:
            stone["position"] = stone["position"].move_toward(revealed, maxf(260.0 * delta, 1.0))
        if stone["position"].distance_squared_to(player_position) <= radius_squared:
            stone["position"] = stone["position"].move_toward(player_position, 420.0 * delta)
        if stone["position"].distance_squared_to(player_position) < 484.0:
            var kind: String = str(stone.get("kind","xp"))
            if kind == "coin":
                coins += int(stone["value"])
                if audio != null:
                    audio.play("pickup_gold", -10.0)
            elif kind == "blood":
                var healed: float = minf(stats["max_hp"] - player_hp, float(stone.get("value", LootRules.BLOOD_PACK_HEAL)))
                player_hp += maxf(0.0, healed)
                if healed > 0.0:
                    effects.floating_text(player_position, "+%.1f" % healed, Color("#ff8a8a"), 22)
                if audio != null:
                    audio.play("pickup_heal", -8.0)
            else:
                xp += LootDrops.experience_value(stone) * stats["xp_multiplier"]
                if audio != null:
                    audio.play("pickup_xp", -10.0)
            if bursts < 12:
                var burst_color := Color("#e2b85d") if kind == "coin" else (Color("#e07a7a") if kind == "blood" else Color("#87d5ae"))
                effects.burst(player_position + Vector2(0, 12), burst_color, 7)
                bursts += 1
        else:
            pickups[remaining] = stone
            remaining += 1
    pickups.resize(remaining)

func update_companions(delta: float) -> void:
    for attack in companions.advance(delta, player_position, combat_targets(), buff_levels, stats, prefer_elite):
        var enemy: Dictionary = attack["enemy"]
        if enemy["hp"] <= 0.0:
            continue
        if attack["kind"] == "drone":
            effects.beam(attack["position"] + Vector2(0, -7), enemy["position"], Color("#6ef6ff"))
            audio.play("magic", -8.0)
        else:
            audio.play("wood_hit", -6.0)
        hurt_enemy(enemy, attack["damage"], attack["kind"], false, (enemy["position"] - attack["position"]).normalized())

func reset_elite_budget() -> void:
    if boss_round:
        elite_budget = 1 if rng.randf() < 0.35 else 0
    else:
        var roll: float = rng.randf()
        if roll < 0.28:
            elite_budget = 0
        elif roll < 0.63:
            elite_budget = 1
        elif roll < 0.90:
            elite_budget = 2
        else:
            elite_budget = 3

func recover_elite_budget() -> void:
    var existing: int = 0
    for enemy in enemies:
        if enemy.get("kind", "") != "boss" and bool(enemy.get("elite", false)) and float(enemy.get("hp", 0.0)) > 0.0:
            existing += 1
    if boss_round:
        elite_budget = 0
    else:
        elite_budget = maxi(0, 2 - existing)

func take_wave_elite() -> bool:
    if elite_budget <= 0:
        return false
    var interval: float = 4.5 if boss_round else maxf(0.40, 0.62 - float(wave - 1) * 0.10)
    var remaining_time: float = 12.0 if boss_round else maxf(interval, WAVE_SECONDS - wave_elapsed)
    var expected_left: int = maxi(1, int(ceil(remaining_time / interval)))
    if rng.randf() <= float(elite_budget) / float(expected_left):
        elite_budget -= 1
        return true
    return false

func offscreen_point(side: int = -1) -> Vector2:
    var view: Rect2 = visible_world_rect()
    var edge: int = side if side >= 0 else rng.randi_range(0, 3)
    match edge:
        0:
            return Vector2(view.position.x - 48, rng.randf_range(view.position.y + 60, view.end.y - 60))
        1:
            return Vector2(view.end.x + 48, rng.randf_range(view.position.y + 60, view.end.y - 60))
        2:
            return Vector2(rng.randf_range(view.position.x + 60, view.end.x - 60), view.position.y - 48)
        _:
            return Vector2(rng.randf_range(view.position.x + 60, view.end.x - 60), view.end.y + 48)

func arrive_inside(point: Vector2) -> Vector2:
    var view: Rect2 = visible_world_rect().grow(-32.0)
    return Vector2(clampf(point.x,view.position.x,view.end.x),clampf(point.y,view.position.y,view.end.y))

func egg_point() -> Vector2:
    var view: Rect2 = visible_world_rect().grow(-80.0)
    for _attempt in range(10):
        var point: Vector2 = Vector2(rng.randf_range(view.position.x, view.end.x), rng.randf_range(view.position.y, view.end.y))
        if point.distance_to(player_position) >= 220.0:
            return point
    return arrive_inside(offscreen_point())

func recycle_distant_enemies() -> void:
    # Preserve HP, identity, elite status and boss progress: relocation grants no rewards.
    var keep: Rect2 = visible_world_rect().grow(900.0)
    for enemy in enemies:
        if float(enemy.get("hp",0.0)) <= 0.0 or keep.has_point(enemy["position"]):
            continue
        enemy["position"] = offscreen_point()
        enemy["position"] = map_view.move_body(enemy["position"], enemy["position"], enemy["radius"])
        enemy["velocity"] = Vector2.ZERO
        enemy["knock"] = Vector2.ZERO
        if enemy.get("state","") != "egg":
            enemy["state"] = "walk"
            enemy["timer"] = 0.6
        enemy["view"].position = enemy["position"]

func hatch_enemy(enemy: Dictionary, fx: bool = true) -> void:
    enemy["state"] = "walk"
    enemy["timer"] = rng.randf_range(0.35, 0.8)
    enemy["arrival"] = "hatched"
    var view = enemy.get("view")
    if is_instance_valid(view) and view.has_method("set_shell"):
        view.set_shell("")
    if fx and DisplayServer.get_name() != "headless" and effects != null:
        effects.puff(enemy["position"], Color("#f3e2c4"), maxf(14.0, float(enemy.get("radius", 18.0)) * 0.9), absi(int(enemy.get("id", 0))) % 3)
        effects.burst(enemy["position"], Color("#d7b17a"), 10.0, "hit")

func spawn_enemy(kind: String, point: Vector2 = Vector2(INF, INF), wave_spawn: bool = false, arrival: String = "") -> void:
    map_view.set_view(player_position,wave)
    var data: Dictionary = Catalog.DINOS[kind]
    var placed: bool = point.is_finite()
    var mode: String = arrival
    if kind == "boss" and mode.is_empty():
        mode = "instant"
        if not placed:
            point = player_position + Vector2(400, 0)
    elif mode.is_empty():
        mode = "instant" if placed else ("egg" if rng.randf() < Rules.EGG_ARRIVAL_CHANCE else "enter")
    if mode == "enter" and not placed:
        point = offscreen_point()
    elif mode == "egg" and not placed:
        point = egg_point()
    elif not placed:
        point = arrive_inside(offscreen_point())
    enemy_serial += 1
    var elite: bool = wave_spawn and kind != "boss" and take_wave_elite()
    var profile: Dictionary = Progression.enemy_profile(wave, kind, enemy_adaptation, elite)
    var hp: float = profile["hp"]
    var view = DinoView.new()
    view.setup(library, kind, data["size"] * (1.1 if elite else 1.0), elite)
    var start_state: String = "walk"
    var start_timer: float = rng.randf_range(1.0, 2.0)
    if mode == "egg":
        start_state = "egg"
        start_timer = rng.randf_range(Rules.EGG_HATCH_MIN, Rules.EGG_HATCH_MAX)
        view.set_shell("egg")
    elif mode == "enter":
        start_state = "enter"
        start_timer = 0.0
    point = map_view.move_body(point, point, data["radius"])
    view.position = point
    actors.add_child(view)
    enemies.append({"id": enemy_serial, "kind": kind, "position": point, "hp": hp, "max_hp": hp, "elite": elite, "view": view, "radius": data["radius"], "state": start_state, "timer": start_timer, "direction": Vector2.RIGHT, "knock": Vector2.ZERO, "velocity": Vector2.ZERO, "attack_cycle":0, "slam_at":point, "arrival": mode})
    for key in ["damage", "dodge", "speed_multiplier", "bullet_multiplier"]:
        enemies.back()[key] = profile[key]

func update_enemies(delta: float) -> void:
    recycle_distant_enemies()
    # Frame snapshots for the separation pass: reading live dictionaries inside
    # the O(n^2) loop was a late-game hotspot. Positions are the frame-start
    # ones for every enemy, which also makes the pass order-independent.
    var sep_positions := PackedVector2Array()
    var sep_alive := PackedByteArray()
    sep_positions.resize(enemies.size())
    sep_alive.resize(enemies.size())
    for sep_index in range(enemies.size()):
        sep_positions[sep_index] = enemies[sep_index]["position"]
        sep_alive[sep_index] = 1 if float(enemies[sep_index]["hp"]) > 0.0 else 0
    var view_rect: Rect2 = visible_world_rect().grow(160.0)
    for enemy_index in range(enemies.size()):
        var enemy: Dictionary = enemies[enemy_index]
        if enemy["hp"] <= 0.0:
            continue
        if enemy.get("state", "walk") == "egg":
            # Only eggs need the settle pass: every other state reaches a real
            # move_body call below, and move_body already resolves embedding
            # at its start point. Settling all 84 enemies every frame was a
            # second full collision solve per enemy for nothing.
            enemy["position"] = map_view.move_body(enemy["position"], enemy["position"], enemy["radius"])
            enemy["timer"] -= delta
            enemy["velocity"] = Vector2.ZERO
            var egg_view = enemy.get("view")
            var crack_window: float = Rules.EGG_CRACK_TIME
            var cracking: bool = enemy["timer"] <= crack_window
            var crack_amount: float = 0.0 if not cracking else (1.0 - clampf(enemy["timer"] / maxf(crack_window, 0.001), 0.0, 1.0))
            if is_instance_valid(egg_view):
                egg_view.position = enemy["position"]
                egg_view.health_fraction = enemy["hp"] / enemy["max_hp"]
                if egg_view.has_method("set_crack"):
                    egg_view.set_crack(crack_amount)
                if view_rect.has_point(enemy["position"]):
                    egg_view.animate(Vector2.ZERO, delta, "egg")
            if cracking and not bool(enemy.get("crack_started", false)):
                enemy["crack_started"] = true
                if DisplayServer.get_name() != "headless" and effects != null:
                    effects.egg_crack(enemy["position"], float(enemy.get("view").display_width) if is_instance_valid(egg_view) else 36.0)
                    if audio != null:
                        audio.play("stone_hit", -10.0, 1.22)
            if enemy["timer"] <= 0.0:
                hatch_enemy(enemy)
            continue
        var difference: Vector2 = player_position - enemy["position"]
        var distance: float = difference.length()
        var direction: Vector2 = difference.normalized() if distance > 0.001 else Vector2.RIGHT
        if enemy.get("state", "walk") == "enter":
            var enter_speed: float = Catalog.DINOS[enemy["kind"]]["speed"] * float(enemy.get("speed_multiplier", 1.0))
            var enter_velocity: Vector2 = direction * enter_speed
            enemy["timer"] -= delta
            enemy["knock"] = enemy["knock"].move_toward(Vector2.ZERO, delta * 270.0)
            enter_velocity += enemy["knock"]
            enemy["velocity"] = enter_velocity
            enemy["position"] = map_view.move_body(enemy["position"], enemy["position"] + enter_velocity * delta, enemy["radius"])
            var enter_view = enemy.get("view")
            if is_instance_valid(enter_view):
                enter_view.position = enemy["position"]
                enter_view.health_fraction = enemy["hp"] / enemy["max_hp"]
                if view_rect.has_point(enemy["position"]):
                    enter_view.animate(enter_velocity, delta, "walk")
            if visible_world_rect().grow(-12.0).has_point(enemy["position"]):
                enemy["state"] = "walk"
                enemy["timer"] = rng.randf_range(0.35, 1.0)
            continue
        var velocity: Vector2 = direction * Catalog.DINOS[enemy["kind"]]["speed"]
        enemy["timer"] -= delta
        var behavior: Dictionary=EnemyRoster.advance(self,enemy,delta)
        if not running: break
        if behavior.handled:
            velocity=behavior.velocity
        elif enemy["kind"] == "boss" and enemy["state"] == "slam":
            velocity = Vector2.ZERO
            if enemy["timer"] <= 0.0:
                var impact: Vector2 = enemy["slam_at"]
                effects.burst(impact,Color("#d95770"),110.0,"blast")
                if player_position.distance_to(impact) <= 110.0 + 19.0:
                    hurt_player((player_position-impact).normalized(),enemy["damage"],true)
                for index in range(8):
                    var shot_direction: Vector2 = Vector2.from_angle(index * TAU / 8.0 + elapsed * 0.2)
                    projectiles.append({"position":enemy["position"] + shot_direction * 60, "velocity":shot_direction*175, "damage":enemy["damage"]*0.55, "kind":"hostile", "life":3.0, "radius":6.5, "weapon_id":"", "from_combo":false, "boss":true})
                enemy["state"] = "recover"
                enemy["timer"] = 0.9
        elif enemy["kind"] in ["charger","boss"]:
            match enemy["state"]:
                "walk":
                    if distance < (420.0 if enemy["kind"] == "boss" else 245.0) and enemy["timer"] <= 0.0:
                        enemy["attack_cycle"] += 1
                        enemy["state"] = "slam" if enemy["kind"] == "boss" and enemy["attack_cycle"] % 2 == 0 else "windup"
                        enemy["timer"] = 1.0 if enemy["kind"] == "boss" else 0.65
                        enemy["slam_at"] = player_position
                        enemy["direction"] = direction
                        velocity = Vector2.ZERO
                "windup":
                    velocity = Vector2.ZERO
                    if enemy["timer"] <= 0.0:
                        enemy["state"] = "dash"
                        enemy["timer"] = 0.55 if enemy["kind"] == "boss" else CHARGE_DURATION
                "dash":
                    velocity = enemy["direction"] * (420.0 if enemy["kind"] == "boss" else CHARGE_SPEED)
                    if enemy["timer"] <= 0.0:
                        enemy["state"] = "recover"
                        enemy["timer"] = 0.6
                        velocity = Vector2.ZERO
                "recover":
                    velocity = Vector2.ZERO
                    if enemy["timer"] <= 0.0:
                        enemy["state"] = "walk"
                        enemy["timer"] = 1.8 if enemy["kind"] == "boss" else 1.4
        elif enemy["kind"] == "spitter":
            if distance > 275:
                velocity = direction * 62.0
            elif distance < 155:
                velocity = -direction * 40.0
            else:
                velocity = Vector2.ZERO
            if enemy["state"] == "spit":
                velocity = Vector2.ZERO
                if enemy["timer"] <= 0.0:
                    projectiles.append({"position": enemy["position"] + direction * 25, "velocity": direction * 190 * enemy["bullet_multiplier"], "damage": enemy["damage"], "kind": "hostile", "life": 4.5, "radius": 6.5, "weapon_id": "", "from_combo": false})
                    enemy["state"] = "walk"
                    enemy["timer"] = 2.1
            elif distance < 395 and enemy["timer"] <= 0.0:
                enemy["state"] = "spit"
                enemy["timer"] = 0.4
        velocity *= enemy["speed_multiplier"]
        if enemy["state"] == "walk":
            var separation: Vector2 = Vector2.ZERO
            var self_position: Vector2 = enemy["position"]
            for other_index in range(sep_positions.size()):
                if other_index == enemy_index or sep_alive[other_index] == 0:
                    continue
                var offset: Vector2 = self_position - sep_positions[other_index]
                var offset_length_squared: float = offset.length_squared()
                if offset_length_squared < 1500.0 and offset_length_squared > 0.01:
                    separation += offset.normalized() * 28.0
            velocity += separation.limit_length(48)
        velocity += enemy["knock"]
        enemy["velocity"] = velocity
        enemy["knock"] = enemy["knock"].move_toward(Vector2.ZERO, delta * 270.0)
        # A stationary enemy whose position was already resolved by move_body
        # cannot become embedded (stones never move), so re-solving it every
        # frame is pure cost; spitters/throwers/chargers stand still a lot.
        if velocity.is_zero_approx() and bool(enemy.get("settled", false)):
            pass
        else:
            enemy["position"] = map_view.move_body(enemy["position"], enemy["position"] + velocity * delta, enemy["radius"])
            enemy["settled"] = true
        enemy["view"].position = enemy["position"]
        enemy["view"].health_fraction = enemy["hp"] / enemy["max_hp"]
        # Off-screen enemies skip the walk-cycle update and redraw; their view
        # position and health stay current, and animation resumes (with the
        # 160px margin) before they can walk into view.
        if view_rect.has_point(enemy["position"]):
            enemy["view"].animate(velocity, delta, behavior.get("pose",enemy["state"]))
        if enemy["position"].distance_to(player_position) < enemy["radius"] + 18.0:
            hurt_player((player_position - enemy["position"]).normalized(), enemy["damage"], enemy["kind"] == "boss")
            if not running:
                break

func charge_path(enemy: Dictionary) -> Vector2:
    var maximum: float = 0.55 if enemy.get("kind","") == "boss" else CHARGE_DURATION
    var speed: float = 420.0 if enemy.get("kind","") == "boss" else CHARGE_SPEED
    var duration: float = maximum if enemy["state"] == "windup" else maxf(enemy["timer"], 0.0)
    return enemy["direction"] * speed * enemy.get("speed_multiplier", 1.0) * duration

func apply_character_view() -> void:
    if hero == null or not hero.has_method("set_character"):
        return
    var visual: String = "caveman" if trial_mode else Catalog.resolve_character_id(character_id, starting_weapon)
    hero.set_character(visual)

func loadout_ids() -> Array:
    var ids: Array = []
    for item in inventory:
        ids.append(item["id"])
    return ids

func current_weapon_mounts() -> Dictionary:
    var layout: Dictionary = Rules.loadout_layout(loadout_ids(), formation_phase, collapsed)
    var mounts: Dictionary = {}
    for key in layout:
        mounts[key] = player_position + layout[key]
    return mounts

func advance_formation(delta: float) -> void:
    formation_phase = fposmod(formation_phase + maxf(0.0, delta) * FORMATION_SPEED * float(stats.get("attack_speed", 1.0)), TAU)

func refresh_weapon_draw_order() -> void:
    for key in weapon_views.keys():
        var view: Sprite2D = weapon_views[key]
        if not is_instance_valid(view):
            continue
        if view.position.y >= player_position.y + 2.0:
            view.z_index = 12
        elif view.position.y <= player_position.y - 2.0:
            view.z_index = 8
        else:
            view.z_index = 11 if view.position.y >= player_position.y else 9

func update_armory(delta: float) -> void:
    var options: Dictionary=stats.duplicate()
    options["link_kind"]=active_link.get("kind","none")
    options["suppressed_weapons"]=active_link.get("suppressed",[])
    options["reload_weapon"]=active_link.get("reload_weapon","")
    options["reload_multiplier"]=active_link.get("cooldown_multiplier",1.0)
    for command in armory.advance(delta,player_position,combat_targets(),inventory,options,prefer_elite,weapon_views,current_weapon_mounts()):
        match command.get("type",""):
            "motion":
                effects.weapon_motion(command["position"], command["direction"], command["weapon_id"])
            "flash":
                flash_weapon(command.get("weapon_id", ""))
            "hit":
                var before_hp: float=float(command.enemy.hp)
                var was_living_monster: bool = Rules.is_living_monster(command.enemy)
                hurt_enemy(command["enemy"],command["damage"],command["weapon_id"],false,command["direction"])
                if active_link.kind=="storm_arrow" and command.weapon_id=="bonebow" and was_living_monster and float(command.enemy.hp)<before_hp:
                    var others: Array=combat_targets().filter(func(e):return Rules.is_living_monster(e) and e.id!=command.enemy.id)
                    var neighbor: Dictionary=Rules.choose_target(command.enemy.position,130.0,others,false)
                    if not neighbor.is_empty():
                        effects.beam(command.enemy.position,neighbor.position,Color("#f3d89b"))
                        hurt_enemy(neighbor,command.damage*0.45,"totem",true,command.direction)
                flash_weapon(command["weapon_id"])
            "area":
                damage_area(command["position"],command["radius"]*stats["area_multiplier"],command["damage"],command["weapon_id"],true,Color("#e8c783"), "quake")
                audio.play("stone_hit", 0.0, 0.72)
                flash_weapon(command.get("weapon_id", "hammer"))
            "beam":
                effects.lightning(command["start"],command["end"],command["color"])
                audio.play("magic_hit", -2.0, 1.08)
                flash_weapon("totem")
                if active_link.kind=="thunder_crystal" and armory.states.has("crystal"):
                    for mine in armory.states.crystal.mines:
                        if Vector2(mine.position).distance_to(command["end"])<=120.0:
                            mine["charged"]=true
            "fan_fire":
                effects.burst(command.position,Color("#f5c66a"),command.radius,"ring")

func update_weapons(delta: float,allow_attacks: bool=true) -> void:
    advance_formation(delta)
    var mounts: Dictionary = current_weapon_mounts()
    var targets: Array=combat_targets() if allow_attacks else []
    var melee_items: Array = []
    var ranged_items: Array = []
    var chain_key: String = active_link["weapons"][1] if active_link.get("kind", "none") == "chain" else ""
    for item in inventory:
        if Catalog.WEAPONS[item["id"]]["kind"] == "special":
            continue
        if Catalog.WEAPONS[item["id"]]["kind"] == "melee":
            if item["id"] == chain_key or weapon_runtime[item["id"]]["chain_state"] != "rest":
                update_chain_weapon(item, delta)
            else:
                melee_items.append(item)
        else:
            ranged_items.append(item)
    for index in range(melee_items.size()):
        var item: Dictionary = melee_items[index]
        var key: String = item["id"]
        var runtime: Dictionary = weapon_runtime[key]
        var data: Dictionary = Catalog.WEAPONS[key]
        runtime["orbit_phase"] = formation_phase
        var point: Vector2 = mounts.get(key, player_position + Rules.orbit_position(index, melee_items.size(), formation_phase, collapsed))
        if runtime["blend_left"] > 0.0:
            runtime["blend_left"] = maxf(0.0, runtime["blend_left"] - delta)
            point = runtime["blend_start"].lerp(point, 1.0 - runtime["blend_left"] / 0.2)
        var previous: Vector2 = runtime["position"] if runtime["initialized"] else point
        runtime["position"] = point
        runtime["initialized"] = true
        var view: Sprite2D = weapon_views[key]
        view.position = point
        view.rotation = (point - player_position).angle() + (PI / 2.0 if key == "axe" else PI / 4.0)
        view.offset = Vector2.ZERO
        if allow_attacks and elapsed >= runtime.get("trail_next", 0.0):
            var tail: Vector2 = player_position + (point - player_position).rotated(-data["orbit_speed"] * 0.06)
            effects.swing_trail(tail, point, player_position, key)
            runtime["trail_next"] = elapsed + 0.035
        var orbit_reach: float = Rules.orbit_radius_for(key, collapsed) + 13.0
        var melee_near: Array = []
        if allow_attacks:
            for candidate in targets:
                if float(candidate.get("hp", 0.0)) <= 0.0:
                    continue
                if player_position.distance_to(candidate["position"]) <= orbit_reach + float(candidate.get("radius", 0.0)):
                    melee_near.append(candidate)
        for enemy in targets:
            if enemy["hp"] <= 0.0:
                continue
            if Rules.should_defer_target(enemy, melee_near):
                continue
            var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy["position"], previous, point)
            if closest.distance_to(enemy["position"]) > enemy["radius"] + 13.0 or float(runtime["hit_times"].get(enemy["id"], -INF)) > elapsed:
                continue
            runtime["hit_times"][enemy["id"]] = elapsed + data["cooldown"] / stats["attack_speed"]
            hurt_enemy(enemy, data["damage"] * (1.0 + (item["level"] - 1) * 0.35), key, false, (enemy["position"] - player_position).normalized())
            hero.recoil((point - player_position).normalized())
            audio.play("swing", -3.0 if key == "blade" else -1.0, 1.28 if key == "blade" else 0.88)
            flash_weapon(key)
    for item in ranged_items:
        var key: String = item["id"]
        var runtime: Dictionary = weapon_runtime[key]
        var data: Dictionary = Catalog.WEAPONS[key]
        var point: Vector2 = mounts.get(key, player_position + Rules.ranged_mount(key))
        runtime["position"] = point
        runtime["cooldown"] -= delta * stats["attack_speed"]
        runtime["recoil"] = maxf(0.0, runtime["recoil"] - delta)
        var attack_range: float = Rules.scaled_range(data, stats)
        if key == "staff":
            attack_range = (365.0 if collapsed else 265.0) * float(stats.get("range_multiplier", 1.0))
        if key == "powder" and active_link["weapons"].has("powder"):
            attack_range = float(active_link["range"]) * float(stats.get("range_multiplier", 1.0))
        var aim_limit: float = Rules.parked_aim_limit(key)
        var preview_aim: Vector2 = runtime.get("aim", (point - player_position).normalized())
        if preview_aim.length() < 0.001:
            preview_aim = Vector2.RIGHT
        var visual_aim: Vector2 = Rules.parked_aim_direction(point, player_position, preview_aim, aim_limit)
        var view: Sprite2D = weapon_views[key]
        view.position = point - visual_aim * runtime["recoil"] * 20.0
        view.rotation = visual_aim.angle() + (0.0 if key == "powder" else PI / 2.0)
        Rules.apply_parked_hold(view, key, player_position, visual_aim)
        # Pose first so the first shot of a new weapon already uses a real muzzle,
        # then retarget from that muzzle and snap the barrel again.
        var muzzle: Vector2 = weapon_muzzle_point(key, visual_aim)
        var target: Dictionary = Rules.choose_target(muzzle, attack_range, targets, prefer_elite)
        var direction: Vector2 = visual_aim
        if not target.is_empty():
            var aim_point: Vector2 = target["position"]
            var flight_time: float = muzzle.distance_to(aim_point) / maxf(1.0, data["speed"] * stats["bullet_speed"])
            aim_point += target.get("velocity", Vector2.ZERO) * minf(0.35, flight_time * 0.65)
            direction = (aim_point - muzzle).normalized() if aim_point.distance_to(muzzle) > 0.001 else visual_aim
            # Juniper (2026-11-17): with the idle cone clamp the cannon's barrel
            # stayed up to ~160 degrees away from its target, so shells visibly
            # left through the back of the barrel. While a target is tracked,
            # pose the weapon along the mount-to-target line (no cone clamp),
            # so the barrel, the muzzle and the shell all sit on one line;
            # the tight torso-safe cone only governs the idle pose.
            visual_aim = (aim_point - point).normalized() if aim_point.distance_to(point) > 0.001 else direction
            runtime["aim"] = visual_aim
            view.position = point - visual_aim * runtime["recoil"] * 20.0
            view.rotation = visual_aim.angle() + (0.0 if key == "powder" else PI / 2.0)
            Rules.apply_parked_hold(view, key, player_position, visual_aim, true, PI)
            muzzle = weapon_muzzle_point(key, visual_aim)
            if aim_point.distance_to(muzzle) > 0.001:
                direction = (aim_point - muzzle).normalized()
        else:
            runtime["aim"] = visual_aim
        view.modulate = Color(0.86, 0.98, 0.86) if active_link["suppressed"].has(key) else Color.WHITE
        if active_link["suppressed"].has(key) or target.is_empty() or runtime["cooldown"] > 0.0:
            continue
        if key == "powder" and active_link["kind"] == "chain":
            var linked: String = active_link["weapons"][1]
            if weapon_runtime[linked]["chain_state"] != "rest" or not pending_link.is_empty():
                continue
            launch_chain(linked, target["position"])
        else:
            var damage: float = data["damage"] * (1.0 + (item["level"] - 1) * 0.35)
            # Shells always leave the visual muzzle, and while a target is
            # tracked the barrel is posed along the shot (see above), so the
            # shell's origin and heading both sit on the barrel line.
            if key == "staff":
                var count: int=Evolution.shot_count(key,item.level)
                for index in range(count):
                    var offset: float=index-(count-1)*0.5
                    var shot_aim: Vector2 = direction.rotated(offset * (0.055 if collapsed else 0.24))
                    fire_projectile(muzzle, shot_aim, key, damage*(1.0 if count==3 else 0.85), attack_range)
                audio.play("magic", -2.0, 1.0)
                flash_weapon(key)
            else:
                var count: int=Evolution.shot_count(key,item.level) if key=="sling" else 1
                for index in range(count):
                    var offset: float=(index-(count-1)*0.5)*0.13
                    var shot_aim: Vector2 = direction.rotated(offset)
                    fire_projectile(muzzle, shot_aim, key, damage*(1.0 if count==1 else (0.70 if count==2 else 0.61)), attack_range, false, key == "powder" and active_link["kind"] == "rune")
                audio.play("powder" if key == "powder" else "sling", 0.0 if key == "powder" else -2.0, 0.86 if key == "powder" else 1.0)
                flash_weapon(key)
                if key == "powder" and active_link["kind"] == "rune":
                    effects.rune_ignition(mounts.get("staff", player_position + Rules.ranged_mount("staff")), muzzle)
                    audio.play("magic", -2.0)
        var penalty: float = active_link["cooldown_multiplier"] if key == "powder" and active_link["weapons"].has("powder") else 1.0
        runtime["cooldown"] = data["cooldown"] * penalty / (1.0 + (item["level"] - 1) * 0.12)
        runtime["recoil"] = 0.12
        hero.recoil(direction)
    if chain_key != "" and weapon_runtime.has(chain_key) and str(weapon_runtime[chain_key].get("chain_state", "rest")) == "rest":
        attach_chain_weapon(chain_key)
    refresh_weapon_draw_order()


func flash_weapon(key: String) -> void:
    if key.is_empty() or not weapon_views.has(key) or not Catalog.WEAPONS.has(key):
        return
    var view: Sprite2D = weapon_views[key]
    if not view.has_meta("base_scale"):
        view.set_meta("base_scale", view.scale)
    var remaining: float = 0.0
    if weapon_runtime.has(key):
        remaining = float(weapon_runtime[key].get("glow", 0.0))
        weapon_runtime[key]["glow"] = 0.2
    if remaining <= 0.06 and key not in ["sling","powder","staff","totem"]:
        var data: Dictionary = Catalog.WEAPONS[key]
        effects.weapon_aura(view.position, data["color"], data["size"] * 0.9)

func apply_weapon_glows(delta: float) -> void:
    refresh_weapon_draw_order()
    for key in weapon_views.keys():
        var view: Sprite2D = weapon_views[key]
        if not is_instance_valid(view):
            continue
        if not view.has_meta("base_scale"):
            view.set_meta("base_scale", view.scale)
        var glow: float = 0.0
        if weapon_runtime.has(key):
            weapon_runtime[key]["glow"] = maxf(0.0, float(weapon_runtime[key].get("glow", 0.0)) - delta)
            glow = float(weapon_runtime[key]["glow"])
        var t: float = clampf(glow / 0.2, 0.0, 1.0)
        var color: Color = Catalog.WEAPONS[key]["color"]
        var lit: Color = Color(minf(1.0, color.r * 1.45 + 0.28), minf(1.0, color.g * 1.3 + 0.22), minf(1.0, color.b * 1.15 + 0.18), 1.0)
        var suppressed: bool = active_link.get("suppressed", []).has(key)
        var rest: Color = Color(0.86, 0.98, 0.86) if suppressed else Color.WHITE
        view.modulate = rest.lerp(lit, t)
        view.scale = view.get_meta("base_scale") * (1.0 + 0.10 * t)

func draw_chest(point: Vector2, age: float) -> void:
    var bob: float = sin(elapsed * 3.4 + point.x) * 2.0
    var at: Vector2 = point + Vector2(0, bob - 6.0)
    var pulse: float = 1.0 + 0.04 * sin(elapsed * 5.0)
    var body: Rect2 = Rect2(at.x - 16.0 * pulse, at.y - 8.0, 32.0 * pulse, 20.0)
    draw_rect(Rect2(body.position.x + 2, body.position.y + 3, body.size.x, body.size.y), Color(0.12, 0.08, 0.05, 0.22), true)
    draw_rect(body, Color("#8b5a2b"), true)
    draw_rect(body, Color("#2a221c"), false, 2.4)
    draw_rect(Rect2(body.position.x + 3, body.position.y + 3, body.size.x - 6, 5), Color("#d7b07a"), true)
    var lid: PackedVector2Array = PackedVector2Array([
        Vector2(body.position.x - 2, body.position.y + 2),
        Vector2(body.position.x + body.size.x * 0.5, body.position.y - 10.0 * pulse),
        Vector2(body.end.x + 2, body.position.y + 2)
    ])
    draw_colored_polygon(lid, Color("#a46a34"))
    var rim: PackedVector2Array = lid.duplicate()
    rim.append(lid[0])
    draw_polyline(rim, Color("#2a221c"), 2.2, true)
    draw_circle(Vector2(body.position.x + body.size.x * 0.5, body.position.y + 8), 3.6, Color("#2a221c"))
    draw_circle(Vector2(body.position.x + body.size.x * 0.5, body.position.y + 8), 2.4, Color("#e2b85d"))
    draw_arc(at + Vector2(0, -4), 26.0 + sin(age * 6.0) * 2.0, 0.0, TAU, 24, Color("#e2b85d", 0.55), 1.6, true)

func weapon_level(key: String) -> int:
    for item in inventory:
        if item["id"] == key:
            return item["level"]
    return 1

func weapon_muzzle_point(key: String, aim: Vector2 = Vector2.ZERO) -> Vector2:
    var direction: Vector2 = aim
    var view: Sprite2D = weapon_views.get(key) as Sprite2D
    if direction.length() < 0.001 and weapon_runtime.has(key):
        direction = Vector2(weapon_runtime[key].get("aim", Vector2.ZERO))
    if direction.length() < 0.001 and view != null and is_instance_valid(view):
        direction = Vector2.from_angle(view.rotation if key == "powder" else view.rotation - PI / 2.0)
    if direction.length() < 0.001:
        direction = Vector2.RIGHT
    else:
        direction = direction.normalized()
    var mount: Vector2 = current_weapon_mounts().get(key, player_position + Rules.ranged_mount(key))
    if view == null or not is_instance_valid(view):
        var fallback: float = Rules.parked_hold_length(key) * 2.0 if Rules.is_parked_weapon(key) else 17.0
        return mount + direction * fallback
    var axis: float = absf(view.scale.x)
    var center: Vector2 = view.position + view.offset.rotated(view.rotation) * axis
    if Rules.is_parked_weapon(key):
        return center + direction * Rules.parked_hold_length(key)
    return center

func chain_anchor() -> Vector2:
    var aim: Vector2 = Vector2.ZERO
    if weapon_runtime.has("powder"):
        aim = Vector2(weapon_runtime["powder"].get("aim", Vector2.ZERO))
    return weapon_muzzle_point("powder", aim)

func attach_chain_weapon(key: String) -> void:
    if not weapon_views.has(key) or not is_instance_valid(weapon_views[key]):
        return
    var muzzle: Vector2 = chain_anchor()
    var aim: Vector2 = Vector2.RIGHT
    if weapon_runtime.has("powder") and Vector2(weapon_runtime["powder"].get("aim", Vector2.ZERO)).length() > 0.001:
        aim = Vector2(weapon_runtime["powder"]["aim"]).normalized()
    var view: Sprite2D = weapon_views[key]
    view.position = muzzle
    view.rotation = aim.angle() + (PI / 2.0 if key == "axe" else PI / 4.0)
    weapon_runtime[key]["position"] = muzzle
    weapon_runtime[key]["chain_position"] = muzzle

func launch_chain(key: String, target: Vector2) -> void:
    var runtime: Dictionary = weapon_runtime[key]
    var muzzle: Vector2 = chain_anchor()
    runtime["chain_state"] = "out"
    runtime["chain_position"] = muzzle
    var shot: Vector2 = target - muzzle
    runtime["chain_direction"] = shot.normalized() if shot.length() > 0.001 else Vector2(weapon_runtime.get("powder", {}).get("aim", Vector2.RIGHT))
    if runtime["chain_direction"].length() < 0.001:
        runtime["chain_direction"] = Vector2.RIGHT
    runtime["chain_distance"] = 0.0
    runtime["chain_hit_ids"] = []
    runtime["chain_damage"] = Catalog.WEAPONS[key]["damage"] * (1.0 + (weapon_level(key) - 1) * 0.35) + 1.6 * (1.0 + (weapon_level("powder") - 1) * 0.25)
    weapon_views[key].position = runtime["chain_position"]
    effects.burst(muzzle, Color("#d5b47c"), 12)
    audio.play("chain_out", -1.0)
    flash_weapon(key)
    flash_weapon("powder")

func update_chain_weapon(item: Dictionary, delta: float) -> void:
    var key: String = item["id"]
    var runtime: Dictionary = weapon_runtime[key]
    var view: Sprite2D = weapon_views[key]
    if runtime["chain_state"] == "rest":
        attach_chain_weapon(key)
        runtime["initialized"] = false
        return
    var previous: Vector2 = runtime["chain_position"]
    var returning: bool = runtime["chain_state"] == "back"
    if returning:
        runtime["chain_position"] = runtime["chain_position"].move_toward(chain_anchor(), 800.0 * delta)
    else:
        runtime["chain_position"] += runtime["chain_direction"] * 650.0 * delta
        runtime["chain_distance"] += 650.0 * delta
    var point: Vector2 = runtime["chain_position"]
    view.position = point
    view.rotation = (point - previous).angle() + (PI / 2.0 if key == "axe" else PI / 4.0)
    var hit_target: bool = false
    var chain_targets: Array = combat_targets()
    var priority_targets: Array = chain_targets.filter(func(candidate):
        var reach: float = float(active_link["range"]) + float(candidate.get("radius", 0.0)) + 12.0
        return not runtime["chain_hit_ids"].has(candidate["id"]) and chain_anchor().distance_squared_to(candidate["position"]) <= reach * reach)
    for enemy in chain_targets:
        if enemy["hp"] <= 0.0 or runtime["chain_hit_ids"].has(enemy["id"]):
            continue
        if Rules.should_defer_target(enemy, priority_targets):
            continue
        if Geometry2D.get_closest_point_to_segment(enemy["position"], previous, point).distance_to(enemy["position"]) <= enemy["radius"] + 12.0:
            runtime["chain_hit_ids"].append(enemy["id"])
            hurt_enemy(enemy, runtime["chain_damage"] * (0.6 if returning else 1.0), key, true, (point - previous).normalized())
            effects.burst(point, Color("#e2ceb0"), 17)
            hit_target = true
    if not returning and (hit_target or runtime["chain_distance"] >= active_link["range"]):
        runtime["chain_state"] = "back"
        runtime["chain_hit_ids"] = []
        audio.play("chain_in", -1.0)
    elif returning and point.distance_to(chain_anchor()) < 7.0:
        runtime["chain_state"] = "rest"
        runtime["chain_position"] = chain_anchor()
        runtime["chain_hit_ids"] = []
        view.position = chain_anchor()
        weapon_runtime["powder"]["cooldown"] = maxf(0.35, weapon_runtime["powder"]["cooldown"])
        if not pending_link.is_empty():
            var desired: String = pending_link
            var ids: Array = []
            for owned in inventory:
                ids.append(owned["id"])
            apply_link(Rules.link_profile(desired, ids))

func fire_projectile(point: Vector2, direction: Vector2, key: String, damage: float, attack_range: float, from_combo: bool = false, enchanted: bool = false) -> void:
    var speed: float = Catalog.WEAPONS[key]["speed"] * stats["bullet_speed"]
    var aim: Vector2 = direction.normalized() if direction.length() > 0.001 else Vector2.RIGHT
    projectiles.append({"position": point, "velocity": aim * speed, "damage": damage, "kind": key, "weapon_id": key, "life": attack_range / speed, "radius": (9.0 if key == "powder" else 5.5) + stats["hit_radius"], "from_combo": from_combo, "enchanted": enchanted, "hit_ids": [], "pierce_left": 0 if key == "powder" else stats["pierce"], "bounces_left": 0 if key == "powder" else stats["ricochet"]})
    if not from_combo and weapon_level(key)>=5:
        if key=="sling": projectiles.back().bounces_left+=1
        if key=="staff": projectiles.back().pierce_left+=1
    effects.muzzle(point,aim,key,enchanted)

func update_projectiles(delta: float) -> void:
    var remaining: Array = []
    var targets: Array = combat_targets()
    for projectile in projectiles:
        # Cached once per projectile: the lambda filters below used to call
        # projectile.get("hit_ids", []) again for every candidate.
        var hit_ids: Array = projectile.get("hit_ids", [])
        if projectile["kind"] != "hostile" and stats["homing"] > 0.0:
            var candidates: Array = []
            for enemy in targets:
                if not hit_ids.has(enemy["id"]):
                    candidates.append(enemy)
            var target: Dictionary = Rules.choose_target(projectile["position"], 220.0, candidates, prefer_elite)
            if not target.is_empty():
                var speed: float = projectile["velocity"].length()
                var desired: Vector2 = (target["position"] - projectile["position"]).normalized()
                projectile["velocity"] = projectile["velocity"].normalized().lerp(desired, clampf(delta * stats["homing"], 0.0, 1.0)).normalized() * speed
        var previous: Vector2 = projectile["position"]
        # A distant dinosaur must not make a reachable egg or rock immune.
        # Keep passing through secondary targets when a living target is reachable.
        var remaining_reach: float = projectile["velocity"].length() * maxf(0.0, float(projectile["life"])) + float(projectile["radius"])
        var priority_targets: Array = []
        for candidate in targets:
            if hit_ids.has(candidate["id"]):
                continue
            var reach: float = remaining_reach + float(candidate.get("radius", 0.0))
            if previous.distance_squared_to(candidate["position"]) <= reach * reach:
                priority_targets.append(candidate)
        projectile["position"] += projectile["velocity"] * delta
        projectile["life"] -= delta
        if projectile["kind"] in ["staff", "powder","sling"]:
            projectile["trail_clock"] = float(projectile.get("trail_clock", 0.0)) - delta
            if projectile["trail_clock"] <= 0.0:
                effects.flight_trail(previous, projectile["position"], projectile["kind"] == "staff" or projectile.get("enchanted", false),projectile["kind"])
                projectile["trail_clock"] = 0.04
        var consumed: bool = false
        if projectile["kind"] == "hostile":
            if Geometry2D.get_closest_point_to_segment(player_position, previous, projectile["position"]).distance_to(player_position) < projectile["radius"] + 19.0:
                hurt_player(projectile["velocity"].normalized(), projectile["damage"], bool(projectile.get("boss", false)))
                consumed = true
        else:
            for enemy in targets:
                if enemy["hp"] <= 0.0 or hit_ids.has(enemy["id"]):
                    continue
                if Rules.should_defer_target(enemy, priority_targets):
                    continue
                if Geometry2D.get_closest_point_to_segment(enemy["position"], previous, projectile["position"]).distance_to(enemy["position"]) > enemy["radius"] + projectile["radius"]:
                    continue
                if projectile["kind"] == "powder":
                    explode_powder(projectile)
                else:
                    if not projectile.has("hit_ids"):
                        projectile["hit_ids"] = []
                    projectile["hit_ids"].append(enemy["id"])
                    hurt_enemy(enemy, projectile["damage"], projectile["weapon_id"], projectile["from_combo"], projectile["velocity"].normalized())
                    if projectile["kind"] == "staff":
                        audio.play("magic_hit", -5.0)
                        effects.burst(enemy["position"], Color("#67effa"), 24, "ring")
                    if int(projectile.get("bounces_left", 0)) > 0:
                        var candidates: Array = targets.filter(func(other): return not projectile["hit_ids"].has(other["id"]))
                        var next_target: Dictionary = Rules.choose_target(enemy["position"], 230.0, candidates, prefer_elite)
                        if not next_target.is_empty():
                            projectile["bounces_left"] -= 1
                            projectile["velocity"] = (next_target["position"] - projectile["position"]).normalized() * projectile["velocity"].length()
                            projectile["life"] = maxf(projectile["life"], 0.55)
                            effects.beam(enemy["position"], enemy["position"] + projectile["velocity"].normalized() * 30, Color("#7ecddb"))
                            break
                    if int(projectile.get("pierce_left", 0)) > 0:
                        projectile["pierce_left"] -= 1
                        effects.pierce_cue(enemy["position"], projectile["velocity"].normalized())
                        continue
                consumed = true
                break
        if not consumed and projectile["life"] <= 0.0 and projectile["kind"] == "powder":
            explode_powder(projectile)
        if not consumed and projectile["life"] > 0.0:
            remaining.append(projectile)
    projectiles = remaining

func explode_powder(projectile: Dictionary) -> void:
    var enchanted: bool = projectile.get("enchanted", false)
    var point: Vector2 = projectile["position"]
    damage_area(point, (85.0 if enchanted else 63.0) * stats["area_multiplier"], projectile["damage"] * (1.2 if enchanted else 1.0), "powder", true, Color("#ffad40") if not enchanted else Color("#6ee7f2"), "rune_blast" if enchanted else "blast")
    audio.play("blast", 0.0, 0.88)
    var stage: int=Evolution.tier(weapon_level("powder"))
    if stage>=1 and not enchanted:
        burning_fields.append({"position":point,"age":0.0,"life":1.4,"tick":0.18,"radius":56.0*stats.area_multiplier,"damage":projectile.damage*0.16,"weapon_id":"powder"})
    if stage>=2:
        for shard in range(4):
            fire_projectile(point,Vector2.from_angle(TAU*shard/4.0),"sling",projectile.damage*0.25,190.0,true)
            projectiles.back().weapon_id="powder"
    if burning_fields.size()>12: burning_fields.pop_front()
    if enchanted:
        burning_fields.append({"position": point, "age": 0.0, "life": 1.1, "tick": 0.18, "radius": 61.0 * stats["area_multiplier"], "damage": 0.7 * (1.0 + (weapon_level("staff") - 1) * 0.25)})
        if burning_fields.size() > 12:
            burning_fields.pop_front()
        effects.burst(point, Color("#65e7ec"), 45.0, "ring")
        audio.play("magic_hit", -5.0)

func update_burning_fields(delta: float) -> void:
    var remaining: Array = []
    for field in burning_fields:
        field["age"] += delta
        field["tick"] -= delta
        if field["tick"] <= 0.0:
            field["tick"] = 0.22
            for enemy in combat_targets():
                if enemy["hp"] > 0.0 and enemy["position"].distance_to(field["position"]) <= field["radius"] + enemy["radius"]:
                    hurt_enemy(enemy, field["damage"], str(field.get("weapon_id","staff")), true, Vector2.ZERO)
        if field["age"] < field["life"]:
            remaining.append(field)
    burning_fields = remaining

func combat_targets() -> Array:
    if _simulating and _combat_targets_ready:
        return _combat_targets_cache
    _combat_targets_cache = enemies + map_view.stone_targets(visible_world_rect().grow(80))
    _combat_targets_ready = _simulating
    return _combat_targets_cache

const PICKUP_TOP_HUD_PAD: float = 150.0

func pickup_visible_point(point: Vector2) -> Vector2:
    var area: Rect2 = visible_world_rect()
    var floor_y: float = area.position.y + PICKUP_TOP_HUD_PAD
    if point.y < floor_y and point.y >= area.position.y - 12.0 and point.x >= area.position.x - 8.0 and point.x <= area.end.x + 8.0:
        point.y = floor_y
    return point

func reveal_recent_pickups(start_index: int) -> void:
    for index in range(maxi(0, start_index), pickups.size()):
        pickups[index]["position"] = pickup_visible_point(pickups[index]["position"])

func spawn_loot(reward: Dictionary,at: Vector2) -> void:
    var start_index: int = pickups.size()
    LootDrops.append_reward(pickups, reward, at)
    reveal_recent_pickups(start_index)

func hurt_stone(target: Dictionary,damage: float) -> void:
    var result: Dictionary=map_view.damage_stone(target,damage*stats.damage_multiplier)
    if not result.hit: return
    effects.puff(target.position,Color("#bda78a"),20 if result.destroyed else 12,0)
    audio.play("stone_hit",-8.0,1.2)
    if result.destroyed:
        effects.burst(target.position,Color("#e3c995"),28,"hit")
        spawn_loot(LootRules.rock_reward(rng),target.position)

func hurt_enemy(enemy: Dictionary, damage: float, weapon_id: String, from_combo: bool, direction: Vector2) -> void:
    if enemy.get("stone",false):
        hurt_stone(enemy,damage)
        return
    if enemy["hp"] <= 0.0:
        return
    var smashed_egg: bool = str(enemy.get("state", "")) == "egg"
    var neutral: bool = weapon_id == "terrain_lava"
    var unavoidable: bool = neutral or weapon_id in ["powder","hammer"] or (weapon_id == "staff" and from_combo)
    var evade_chance: float = maxf(0.0, float(enemy.get("dodge", 0.0)) - stats["dodge_ignore"])
    if not unavoidable and evade_chance > 0.0 and rng.randf() < evade_chance:
        effects.floating_text(enemy["position"], "敌闪避", Color("#f4a8d3"), 23)
        return
    var critical: bool = not neutral and rng.randf() < stats["crit_chance"]
    var amount: float = damage if neutral else damage * stats["damage_multiplier"] * (stats["crit_multiplier"] if critical else 1.0)
    var slammed: bool = not neutral and float(stats.get("close_damage_bonus", 0.0)) > 0.0 and player_position.distance_to(enemy["position"]) <= float(stats.get("close_damage_range", 140.0))
    if slammed:
        amount *= 1.0 + float(stats["close_damage_bonus"])
    enemy["hp"] = maxf(0.0, enemy["hp"] - amount)
    var push: float = 180.0 if weapon_id == "club" else (145.0 if weapon_id == "axe" else (85.0 if weapon_id == "blade" else 36.0))
    if neutral: push = 0.0
    enemy["knock"] += direction * push * (0.12 if enemy["kind"] == "boss" else 1.0)
    var feedback: bool = not neutral or elapsed >= float(enemy.get("lava_feedback_next",-INF)) or enemy["hp"]<=0
    if neutral: enemy["lava_feedback_sum"] = float(enemy.get("lava_feedback_sum",0.0)) + amount
    if feedback:
        enemy["view"].hit()
        effects.impact(enemy["position"], direction, weapon_id)
        if slammed:
            effects.slam_cue(enemy["position"], direction)
        if bool(settings.get("damage_numbers", true)):
            effects.damage_number(enemy["position"],float(enemy.get("lava_feedback_sum",amount)) if neutral else amount,critical,Color("#ffbc65") if neutral else Color("#fffdf4"))
        if neutral:
            enemy["lava_feedback_sum"] = 0.0
            enemy["lava_feedback_next"] = elapsed+0.35
    enemy["view"].health_fraction = enemy["hp"] / enemy["max_hp"]
    if weapon_id == "club":
        impact_strength = maxf(impact_strength, 4.0)
        audio.play("wood_hit", 0.0, 0.9)
    elif weapon_id == "axe":
        impact_strength = maxf(impact_strength, 4.6)
        audio.play("stone_hit", 0.0, 0.96)
    elif weapon_id == "hammer":
        impact_strength = maxf(impact_strength, 6.2)
    elif weapon_id == "blade":
        impact_strength = maxf(impact_strength, 2.0)
    elif weapon_id == "spear":
        audio.play("stone_hit", -1.0, 1.18)
    elif weapon_id == "sling":
        audio.play("sling", -3.0, 1.22)
    elif weapon_id == "boomerang":
        audio.play("swing", -3.0, 1.15)
    if critical:
        impact_strength = maxf(impact_strength, 3.2)
    if enemy["hp"] <= 0.0:
        kills += 1
        var boss: bool = enemy["kind"] == "boss"
        if boss:
            boss_defeated = true
        spawn_loot(LootRules.enemy_reward(enemy.kind,wave,enemy.elite,enemy.view.display_width,rng),enemy.position)
        if not boss and not smashed_egg and LootRules.should_drop_blood_pack(str(enemy.kind), bool(enemy.get("elite", false)), rng):
            var blood_index: int = pickups.size()
            LootDrops.append_blood_pack(pickups, enemy.position, LootRules.BLOOD_PACK_HEAL)
            reveal_recent_pickups(blood_index)
        if smashed_egg:
            effects.egg_smash(enemy["position"], enemy["view"].display_width)
        else:
            effects.defeat(enemy["position"], direction, enemy["view"].display_width, enemy["view"].sprite.texture, library.region("dinosaurs",enemy["kind"]).size)
        if audio != null:
            audio.play("boss_defeat" if boss else "enemy_death", -5.0 if boss else -8.0)
        if (not boss) and bool(enemy.get("elite", false)) and (force_elite_chests or rng.randf() < LootRules.ELITE_CHEST_CHANCE):
            offer_elite_chest(enemy["position"])
    if not from_combo and not neutral:
        evolution_melee_hit(enemy,damage,weapon_id,direction)

func evolution_melee_hit(enemy: Dictionary,damage: float,key: String,direction: Vector2) -> void:
    var stage: int=Evolution.tier(weapon_level(key))
    if stage==0 or key not in ["club","axe","blade"]: return
    var runtime: Dictionary=weapon_runtime[key]
    runtime["evolution_hits"]=int(runtime.get("evolution_hits",0))+1
    var count: int=runtime.evolution_hits
    if key=="club" and count%(2 if stage>=2 else 3)==0:
        damage_area(enemy.position,84.0 if stage>=2 else 64.0,damage*0.45,key,true,Color("#e5c28a"),"quake")
    elif key=="axe" and (enemy.hp<=0 or (stage>=2 and count%3==0)):
        damage_area(enemy.position,96.0 if stage>=2 else 70.0,damage*0.40,key,true,Color("#e5b87d"),"cleave")
    elif key=="blade" and count%(3 if stage>=2 else 4)==0:
        if stage>=2:
            damage_area(enemy.position,60.0,damage*0.35,key,true,Color("#e4d4ad"),"cleave")
        elif enemy.hp>0:
            hurt_enemy(enemy,damage*0.35,key,true,direction)
        effects.swing_trail(enemy.position-Vector2(18,18),enemy.position+Vector2(18,18),enemy.position,key)

func damage_area(point: Vector2, radius: float, damage: float, weapon_id: String, from_combo: bool, color: Color, burst_kind: String = "blast") -> void:
    effects.burst(point, color, radius, burst_kind)
    impact_strength = maxf(impact_strength, 6.0 if weapon_id == "hammer" else 5.2)
    for enemy in combat_targets():
        if enemy["hp"] > 0.0 and enemy["position"].distance_to(point) < radius + enemy["radius"]:
            hurt_enemy(enemy, damage, weapon_id, from_combo, (enemy["position"] - point).normalized())



# Environmental DPS is the same for both teams: no armor, random dodge,
# weapon bonuses or criticals. Timed hero immunity still protects a short dodge.
func update_terrain_damage(delta: float, player_exposure: float = -1.0) -> void:
    if delta <= 0.0 or not running or paused or shop_open or upgrade_pending or stats_open or player_frozen or wave_closing or departure_left > 0.0 or animation_demo:
        return
    var exposure: float = (delta if invulnerable <= 0.0 else 0.0) if player_exposure < 0.0 else player_exposure
    if exposure > 0.0 and not demo and player_hp > 0.0:
        var amount: float = map_view.lava_damage_at(player_position) * exposure
        if amount > 0.0:
            player_hp = maxf(0.0,player_hp-amount)
            hero.hurt()
            hurt_flash = maxf(hurt_flash, 0.4)
            if player_hp <= 0.0:
                finish_run(false)
                return
    for enemy in enemies:
        if enemy["hp"] <= 0.0: continue
        var amount: float = map_view.lava_damage_at(enemy["position"]) * delta
        if amount > 0.0:
            hurt_enemy(enemy,amount,"terrain_lava",false,Vector2.ZERO)

func hurt_player(direction: Vector2, damage: float = 1.0, from_boss: bool = false) -> void:
    if not running or invulnerable > 0.0 or demo or animation_demo:
        return
    if rng.randf() < stats["dodge"]:
        invulnerable = 0.25
        effects.floating_text(player_position, "闪避", Color("#9ce7f0"), 22)
        return
    var amount: float = damage * (1.0 - stats["reduction"])
    # Cap every combat hit (contact, projectiles, quakes, elites, Boss).
    # Terrain DoT stays on update_terrain_damage and is intentionally uncapped.
    amount = minf(amount, Progression.HIT_CAP_RATIO * float(stats["max_hp"]))
    player_hp = maxf(0.0, player_hp - amount)
    invulnerable = 0.7
    hero.hurt()
    hurt_flash = maxf(hurt_flash, 0.42)
    audio.play("hurt", -3.0)
    effects.burst(player_position, Color("#bd7356"), 18.0, "ring")
    if bool(settings.get("damage_numbers", true)):
        effects.floating_text(player_position, "-%.1f" % amount, Color("#ff938a"), 24)
    player_position = map_view.move_body(player_position, player_position + direction * 8.0, 18.0)
    if player_hp <= 0:
        finish_run(false)

func animate_showcase(delta: float) -> void:
    elapsed += delta
    var clock: float = fmod(elapsed, 12.0)
    var velocity: Vector2 = Vector2.ZERO
    if clock < 1.4:
        demo_caption = "静止 · 双脚落位"
    elif clock < 3.4:
        demo_caption = "行走 · 双脚交替，双手反向摆动"
        velocity = Vector2(110, 0)
    elif clock < 5.4:
        demo_caption = "转向移动 · 步态随实际位移推进"
        velocity = Vector2(-110, 0)
    elif clock < 7.0:
        demo_caption = "停步 · 手脚平滑归位"
    elif clock < 9.8:
        demo_caption = "上下移动 · 身体与四肢协调"
        velocity = Vector2(0, 60.0 if clock < 8.4 else -60.0)
    else:
        demo_caption = "攻击 · 手部短促回摆"
        if fmod(clock, 0.62) < delta:
            hero.recoil(Vector2.RIGHT)
            audio.play("swing", -4.0)
            audio.play("wood_hit", -5.0)
            effects.burst(player_position + Vector2(145, 0), Color("#d6b672"), 18.0)
    player_position = map_view.move_body(player_position, player_position + velocity * delta, 18.0)
    hero.position = player_position
    var previous_step: int = int(hero.phase / PI)
    hero.animate(velocity, velocity.length() * delta, delta)
    audio.advance(delta)
    if velocity.length() > 10.0 and previous_step != int(hero.phase / PI):
        audio.play("step", -8.0)
    effects.advance(delta)
    if demo_weapon != null:
        demo_weapon.visible = clock >= 9.8
        demo_weapon.position = player_position + Vector2(150, 6)
        demo_weapon.rotation = -0.5 + sin(clock * 10.0) * 0.55
    queue_redraw()

func draw_grass(at: Vector2, size: float) -> void:
    var color: Color = Color("#a1ad73")
    draw_line(at, at + Vector2(-size * 0.45, -size), color, 4.0, true)
    draw_line(at, at + Vector2(size * 0.12, -size * 1.2), color, 4.5, true)
    draw_line(at, at + Vector2(size * 0.6, -size * 0.75), color, 4.0, true)

func _draw() -> void:
    if animation_demo:
        draw_string(demo_font, Vector2(64, 67), "原始人 · 动作预览", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#543b2c"))
        draw_string(demo_font, Vector2(360, 185), demo_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#64513a"))
        draw_string(demo_font, Vector2(325, 715), "同一角色的身体、双手、双脚独立运动", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#766449"))
    draw_link_shapes()
    var pickup_bounds: Rect2 = visible_world_rect().grow(40.0)
    if pickup_renderer!=null: pickup_renderer.sync(pickups,pickup_bounds,elapsed)
    for chest in chest_marks:
        chest["age"] = float(chest.get("age", 0.0))
        draw_chest(chest["position"], chest["age"])
    for enemy in enemies:
        if enemy["hp"] <= 0.0:
            continue
        if EnemyRoster.draw_warning(self,enemy): continue
        if enemy["state"] == "windup" or enemy["state"] == "dash":
            var start: Vector2 = enemy["position"]
            var direction: Vector2 = enemy["direction"]
            var end: Vector2 = start + charge_path(enemy)
            var contact_radius: float = enemy["radius"] + 18.0
            var normal: Vector2 = direction.orthogonal() * contact_radius
            var polygon: PackedVector2Array = PackedVector2Array([start - normal, end - normal, end + direction * contact_radius, end + normal, start + normal])
            draw_colored_polygon(polygon, Color(0.78, 0.36, 0.25, 0.14))
            var outline: PackedVector2Array = polygon.duplicate()
            outline.append(polygon[0])
            draw_polyline(outline, Color(0.76, 0.36, 0.25, 0.62), 2.0, true)
        elif enemy["state"] == "slam":
            var danger: Vector2 = enemy["slam_at"]
            draw_circle(danger,110.0,Color(0.70,0.12,0.26,0.15))
            draw_arc(danger,110.0,0,TAU,48,Color("#bf3f5e"),3.5,true)
            draw_line(danger+Vector2(-16,-16),danger+Vector2(16,16),Color("#b73558"),4.0,true)
            draw_line(danger+Vector2(-16,16),danger+Vector2(16,-16),Color("#b73558"),4.0,true)
        elif enemy["state"] == "spit":
            draw_arc(enemy["position"] + (player_position - enemy["position"]).normalized() * 28.0, 12.0, 0.0, TAU, 24, Color("#b82f83"), 3.0, true)
    for projectile in projectiles:
        BattleVisuals.draw_projectile(self,projectile,elapsed)

func draw_magic_shell(point: Vector2, direction: Vector2) -> void:
    var normal: Vector2 = direction.orthogonal()
    draw_colored_polygon(PackedVector2Array([point + direction * 9, point + normal * 7 - direction * 3, point - direction * 18, point - normal * 7 - direction * 3]), Color("#df9853"))
    draw_colored_polygon(PackedVector2Array([point - direction * 7 + normal * 4, point - direction * 25 + normal * 2, point - direction * 15 - normal * 3]), Color("#edc277"))
    draw_circle(point, 7.5, Color("#4f9ab4"))
    draw_circle(point, 4.7, Color("#a3fcff"))
    draw_arc(point, 8.0, 0.0, TAU, 20, Color("#edda9a"), 1.8, true)

func draw_link_shapes() -> void:
    for field in burning_fields:
        var alpha: float = 1.0 - field["age"] / field["life"]
        draw_circle(field["position"], field["radius"], Color(0.80, 0.43, 0.18, 0.10 * alpha))
        draw_arc(field["position"], field["radius"], 0.0, TAU, 32, Color(0.18, 0.70, 0.83, 0.80 * alpha), 2.5, true)
        for index in range(4):
            var point: Vector2 = field["position"] + Vector2.from_angle(index * PI / 2.0 + 0.6) * field["radius"] * 0.45
            var lift: float = sin(field["age"] * 15.0 + index) * 2.0
            draw_colored_polygon(PackedVector2Array([point + Vector2(-4, 3), point + Vector2(0, -9 - lift), point + Vector2(4, 3)]), Color(0.28, 0.95, 1.0, 0.72 * alpha))
    if active_link.get("kind", "none") != "chain":
        return
    var key: String = active_link["weapons"][1]
    var start: Vector2 = chain_anchor()
    var end: Vector2 = weapon_views[key].position
    var direction: Vector2 = end - start
    var length: float = direction.length()
    if length < 3.0:
        return
    var normal: Vector2 = direction.normalized().orthogonal()
    var returning: bool = weapon_runtime[key]["chain_state"] == "back"
    var points: PackedVector2Array = PackedVector2Array()
    var links: int = maxi(2, int(length / 8.0))
    for index in range(links + 1):
        var t: float = float(index) / links
        var point: Vector2 = start.lerp(end, t) + normal * sin(t * PI) * (9.0 if returning else 2.0)
        points.append(point)
    draw_polyline(points, Color("#372d26"), 5.0, true)
    draw_polyline(points, Color("#e9bb68") if not returning else Color("#8ce7eb"), 2.2, true)
    for index in range(1, points.size()):
        draw_set_transform(points[index], direction.angle(), Vector2(1.35, 0.73))
        draw_arc(Vector2.ZERO, 2.7, 0.0, TAU, 10, Color("#fff0b5"), 1.8, true)
    draw_set_transform(Vector2.ZERO)

func set_music(enabled: bool) -> void:
    var previous: bool = bool(settings.get("music_enabled",true))
    settings["music_enabled"] = enabled
    var result: Dictionary = save_store.write_settings(settings)
    if not result["ok"]:
        settings["music_enabled"] = previous
        hud.configure_music(previous)
        hud.save_note = "音乐设置未保存：" + result["error"]
        if is_instance_valid(hud.save_note_label): hud.save_note_label.text = hud.save_note
        return
    music.set_enabled(enabled)
    hud.configure_music(enabled)

func set_damage_numbers(enabled: bool) -> void:
    var previous: bool = bool(settings.get("damage_numbers", true))
    settings["damage_numbers"] = enabled
    var result: Dictionary = save_store.write_settings(settings)
    if not result.get("ok", false):
        settings["damage_numbers"] = previous
        hud.configure_display(previous, bool(settings.get("fullscreen", false)))
        hud.save_note = "显示设置未保存：" + str(result.get("error", ""))
        if is_instance_valid(hud.save_note_label): hud.save_note_label.text = hud.save_note
        return
    hud.configure_display(enabled, bool(settings.get("fullscreen", false)))

func apply_display_mode(fullscreen: bool) -> void:
    if DisplayServer.get_name() == "headless":
        return
    if fullscreen:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
        _fit_playable_window()
    _apply_content_scale()

func _apply_content_scale() -> void:
    if DisplayServer.get_name() == "headless" or not is_inside_tree():
        return
    var win := get_tree().root
    win.content_scale_size = Vector2i(1280, 800)
    win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

func set_key_bindings() -> void:
    var previous: Dictionary = settings.duplicate(true)
    settings["key_bindings"] = KeyBindings.export_bindings()
    var result: Dictionary = save_store.write_settings(settings)
    if not result.get("ok", false):
        settings = previous
        KeyBindings.apply_settings(settings)
        if hud != null and hud.has_method("refresh_key_hints"):
            hud.refresh_key_hints()

func set_fullscreen(enabled: bool) -> void:
    var previous: bool = bool(settings.get("fullscreen", false))
    settings["fullscreen"] = enabled
    var result: Dictionary = save_store.write_settings(settings)
    if not result.get("ok", false):
        settings["fullscreen"] = previous
        hud.configure_display(bool(settings.get("damage_numbers", true)), previous)
        hud.save_note = "显示设置未保存：" + str(result.get("error", ""))
        if is_instance_valid(hud.save_note_label): hud.save_note_label.text = hud.save_note
        return
    apply_display_mode(enabled)
    hud.configure_display(bool(settings.get("damage_numbers", true)), enabled)

func set_volume(kind: String, value: float) -> void:
    var key: String = "music_volume" if kind == "music" else "sfx_volume"
    var previous: float = float(settings.get(key, 1.0))
    settings[key] = clampf(value, 0.0, 1.0)
    var result: Dictionary = save_store.write_settings(settings)
    if not result.get("ok", false):
        settings[key] = previous
        hud.configure_volumes(float(settings.get("music_volume", 1.0)), float(settings.get("sfx_volume", 1.0)))
        hud.save_note = "音量设置未保存：" + str(result.get("error", ""))
        if is_instance_valid(hud.save_note_label): hud.save_note_label.text = hud.save_note
        return
    music_volume = float(settings["music_volume"]) if kind == "music" else music_volume
    sfx_volume = float(settings["sfx_volume"]) if kind != "music" else sfx_volume
    if kind == "music":
        music_volume = float(settings[key])
        if music != null and music.has_method("set_volume"):
            music.set_volume(music_volume)
    else:
        sfx_volume = float(settings[key])
        if audio != null and audio.has_method("set_volume"):
            audio.set_volume(sfx_volume)
    hud.configure_volumes(music_volume, sfx_volume)
