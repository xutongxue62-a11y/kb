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
const TrainingPanelScript = preload("res://src/ui_training_panel.gd")
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
const BiomeEncounters = preload("res://src/biome_encounters.gd")
const FIELD: Rect2 = Rect2(42, 147, 1196, 514)
const WAVE_SECONDS: float = 30.0
const WAVE_BUFFER: float = 0.9
const BOSS_CLEAR_SECONDS: float = 30.0
const BOSS_WAVE_LIMIT_SECONDS: float = 180.0
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
var boss_clear_left: float = 0.0
var boss_pending: bool = false
var shop_open: bool = false
var shop_stock: Array = []
var shop_rerolls: int = 0
var wave_closing: bool = false
var closing_absorb_left: float = 0.0
var training_mode: bool = false
var training_godmode: bool = true
var training_enemy_wave: int = 10
var training_enemy_immortal: bool = false
var training_panel_open: bool = false
var training_panel: Control = null
var wave_buffer: float = 0.0
var departure_left: float = 0.0
var stats_home_return: String = "title"
var player_frozen: bool = false
var trial_preset: String = "base"
var formation_phase: float = 0.0
var active_link: Dictionary = {}
var active_links: Array = []
var available_links: Array = []
var pending_link: String = ""
var pending_link_ids: Array = []
var burning_fields: Array = []
var link_notice_open: bool = false
var link_pack_open: bool = false
var pending_link_notice: Array = []
var _run_bootstrapping: bool = false
var _link_notice_return: String = ""
var _link_pack_return: String = ""
var _hinted_complete_links: Dictionary = {}
var _pending_departure_discovery: bool = false
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
var _draw_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var ground_marks_layer: Node2D
var _had_burning_fields: bool = false
var _ground_marks_accum: float = 0.0
var _pickup_sync_accum: float = 0.0
var _last_pickup_count: int = -1
var _sep_parity: int = 0
var _armory_options_cache: Dictionary = {}
var _armory_options_dirty: bool = true
var _cached_stone_targets: Array = []
var _cached_stone_pos: Vector2 = Vector2(INF, INF)
var _cached_stone_biome: String = ""
var _stones_dirty: bool = true

class GroundMarksLayer:
    extends Node2D
    var owner_world
    func _draw() -> void:
        if owner_world != null:
            owner_world.draw_burning_fields(self)
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
var stage_hp_bonus: int = 0
var stage_hp_granted_wave: int = 0
var enemy_serial: int = 0
var elite_budget: int = 0
var spawn_clock: float = 0.0
var ward_ready: Dictionary = {}
var _hud_accum: float = 0.0
var pack_result_positions: Dictionary = {}
var pack_card_positions: Dictionary = {}
var pack_card_weapon_sig: String = ""
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
    sync_character_progress()
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
    map_view = WorldMap.new()
    map_view.z_index = -50
    add_child(map_view)
    map_view.set_view(player_position,wave)
    ground_marks_layer = GroundMarksLayer.new()
    ground_marks_layer.owner_world = self
    ground_marks_layer.z_as_relative = false
    ground_marks_layer.z_index = -20
    add_child(ground_marks_layer)
    rng.seed = 2180411
    library = AssetLibrary.new()
    active_link = Catalog.LINKS["none"].duplicate(true)
    active_links = []
    pending_link_ids = []
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
    pickup_renderer = PickupRenderer.new()
    pickup_renderer.z_index = 1
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
    hud.combo_requested.connect(toggle_link_pack)
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
    if hud.has_signal("link_discovery_enable"):
        hud.link_discovery_enable.connect(_on_link_discovery_enable)
    if hud.has_signal("link_discovery_closed"):
        hud.link_discovery_closed.connect(_on_link_discovery_closed)
    if hud.has_signal("link_pack_closed"):
        hud.link_pack_closed.connect(close_link_pack)
    if hud.has_signal("training_requested"):
        hud.training_requested.connect(start_training_camp)
    if hud.has_signal("training_panel_requested"):
        hud.training_panel_requested.connect(toggle_training_panel)
    hud.next_round_requested.connect(leave_shop)
    hud.save_requested.connect(save_game)
    hud.continue_requested.connect(begin_continue)
    hud.home_requested.connect(go_home)
    hud.settings_changed.connect(set_autosave)
    hud.music_changed.connect(set_music)
    hud.volume_changed.connect(set_volume)
    hud.damage_numbers_changed.connect(set_damage_numbers)
    hud.vfx_mode_changed.connect(set_vfx_mode)
    hud.display_mode_changed.connect(set_fullscreen)
    hud.key_bindings_changed.connect(set_key_bindings)
    hud.configure_music(bool(settings.get("music_enabled",true)))
    hud.configure_volumes(music_volume, sfx_volume)
    var init_vfx_mode: String = current_vfx_mode()
    effects.set_vfx_mode(init_vfx_mode)
    hud.configure_display(bool(settings.get("damage_numbers", true)), bool(settings.get("fullscreen", false)), init_vfx_mode)
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
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
    DisplayServer.window_set_size(target)
    var centered: Vector2i = usable.position + (usable.size - target) / 2
    DisplayServer.window_set_position(centered)

func start_run(trial: bool = false, preset: String = "") -> void:
    close_training_panel()
    training_mode = false
    if hud != null:
        if hud.has_method("set_training_mode"):
            hud.set_training_mode(false)
        hud.debug_cheats = debug_cheats
        hud.refresh_debug_controls()
    # Protect the current normal run before resetting any world or transient data.
    if trial and running and not trial_mode and not restoring:
        if settings.get("autosave",true) and not demo and not animation_demo and not save_game():
            return
    set_run_world_visible(true)
    map_view.reset_terrain()
    dodge_left = 0.0
    dodge_cooldown = 0.0
    dodge_direction = Vector2.RIGHT
    last_facing = Vector2.RIGHT
    departure_left = 0.0
    audio.stop_all()
    audio.set_paused(false)
    buff_levels.clear()
    stage_hp_bonus = 0
    stage_hp_granted_wave = 0
    refresh_stats()
    pickups.clear()
    companions.reset()
    armory.reset()
    _combat_targets_ready = false
    _simulating = false
    _stones_dirty = true
    _cached_stone_targets.clear()
    _had_burning_fields = false
    _ground_marks_accum = 0.0
    _pickup_sync_accum = 0.0
    _last_pickup_count = -1
    _sep_parity = 0
    _armory_options_dirty = true
    _armory_options_cache.clear()
    coins = 0
    wave_elapsed = 0.0
    boss_round = false
    boss_defeated = false
    boss_clear_left = 0.0
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
    active_links = []
    pending_link = ""
    pending_link_ids = []
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
    ward_ready.clear()
    pack_result_positions.clear()
    pack_card_positions.clear()
    pack_card_weapon_sig = ""
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
    stage_hp_bonus = 0
    stage_hp_granted_wave = 0
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
    close_link_pack()
    link_notice_open = false
    link_pack_open = false
    pending_link_notice.clear()
    _hinted_complete_links.clear()
    _pending_departure_discovery = false
    _run_bootstrapping = true
    hero.scale = Vector2.ONE * (3.0 if animation_demo else 1.0)
    hero.phase = 0.0
    hero.amplitude = 0.0
    hero.position = player_position
    if world_camera != null:
        world_camera.position = player_position
        world_camera.force_update_scroll()
    if map_view != null:
        map_view.set_view(player_position, wave)
    effects.hero_anchor = player_position
    effects._has_hero_anchor = true
    apply_character_view()
    if trial:
        var trial_ids: Array = Catalog.EXPANDED_IDS+["sling","totem"] if trial_preset=="expanded" else (Catalog.NEW_IDS + ["club","staff"] if trial_preset == "new" else Catalog.TRIAL_IDS)
        for key in trial_ids:
            grant_weapon(key)
    else:
        grant_weapon(starting_weapon)
    _run_bootstrapping = false
    set_loadout_visible(true)
    sync_idle_loadout()
    hud.hide_menu()
    update_hud()
    queue_redraw()
    record_character_wave(wave)
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
    refresh_weapon_enchant_tint()

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
        if not Catalog.can_start_character(character_id, settings.get("character_best_wave", {})):
            if hud.has_method("clear_launch_commit"):
                hud.clear_launch_commit()
            return
        starting_weapon = str(Catalog.character(character_id).get("starting_weapon", starting_weapon))
    var previous: Texture2D = hud.snapshot_departure_previous() if hud.has_method("snapshot_departure_previous") else hud.snapshot_ui()
    start_run(trial)
    if not running:
        if hud.has_method("restore_front_chrome"):
            hud.restore_front_chrome()
        return
    departure_left = 2.4
    hud.show_departure(departure_left)
    hud.page_turn(previous, "burn")

func begin_continue() -> void:
    if departure_left > 0.0:
        return
    var previous: Texture2D = hud.snapshot_departure_previous() if hud.has_method("snapshot_departure_previous") else hud.snapshot_ui()
    if not continue_game():
        if hud.has_method("restore_front_chrome"):
            hud.restore_front_chrome()
        return
    if not shop_open:
        departure_left = 2.4
        hud.show_departure(departure_left)
    hud.page_turn(previous, "burn")


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
    if settings.get("autosave",true) and not restoring and running and not trial_mode and not training_mode and not demo and not animation_demo:
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
        if effects != null:
            effects.hero_anchor = player_position
            effects._has_hero_anchor = true
        for enemy in enemies:
            enemy["position"] = map_view.move_body(enemy["position"],enemy["position"],enemy["radius"])
            enemy["view"].position = enemy["position"]
        update_hud()
        recover_elite_budget()
        record_character_wave(wave)
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
    close_training_panel()
    if running and settings.get("autosave",true) and not trial_mode and not training_mode and not demo and not save_game():
        return
    training_mode = false
    if hud != null and hud.has_method("set_training_mode"):
        hud.set_training_mode(false)
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
    close_link_pack()
    clear_run_for_title()
    audio.stop_all()
    hud.suppress_next_transition = false
    hud.show_menu("start",kills)
    update_hud()
    refresh_save_status()

func set_run_world_visible(value: bool) -> void:
    if actors != null:
        actors.visible = value
    if hero != null:
        hero.visible = value
    if map_view != null:
        map_view.visible = value
    if ground_marks_layer != null:
        ground_marks_layer.visible = value
    if pickup_renderer != null:
        pickup_renderer.visible = value
    if effects != null:
        effects.visible = value
    if weapons_layer != null:
        weapons_layer.visible = value
    if armory != null:
        armory.visible = value
    if companions != null:
        companions.visible = value
    if value:
        set_loadout_visible(not shop_open)
    else:
        set_loadout_visible(false)

func clear_run_for_title() -> void:
    clear_enemies()
    pickups.clear()
    chest_marks.clear()
    projectiles.clear()
    burning_fields.clear()
    expire_combat_fx()
    if companions != null:
        companions.reset()
    if armory != null:
        armory.reset()
    if pickup_renderer != null:
        pickup_renderer.sync([], Rect2(), 0.0)
    set_run_world_visible(false)
    position = Vector2.ZERO
    if world_camera != null:
        world_camera.offset = Vector2.ZERO
    if ground_marks_layer != null:
        ground_marks_layer.queue_redraw()
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        if running and settings.get("autosave",true) and not trial_mode and not demo and not save_game():
            return
        get_tree().quit()

func set_start_weapon(key: String) -> void:
    if Catalog.is_starter_weapon(key):
        starting_weapon = key

func sync_character_progress() -> void:
    if hud != null:
        hud.character_best_wave = Catalog.normalized_best_waves(settings.get("character_best_wave", {}))

func record_character_wave(reached: int = -1) -> void:
    if trial_mode or demo or animation_demo or save_store == null:
        return
    if not Catalog.CHARACTERS.has(character_id):
        return
    var wave_reached: int = wave if reached < 0 else reached
    if wave_reached <= 0:
        return
    var progress: Dictionary = Catalog.normalized_best_waves(settings.get("character_best_wave", {}))
    if wave_reached <= int(progress.get(character_id, 0)):
        sync_character_progress()
        return
    var backup: Dictionary = settings.duplicate(true)
    progress[character_id] = wave_reached
    settings["character_best_wave"] = progress
    var result: Dictionary = save_store.write_settings(settings)
    if not result.get("ok", false):
        settings = backup
    sync_character_progress()

func refresh_stats() -> Dictionary:
    stats = Growth.stats(buff_levels, stage_hp_bonus)
    if not trial_mode:
        Catalog.apply_character_modifiers(stats, character_id)
    _armory_options_dirty = true
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
    if upgrade_pending or shop_open or animation_demo or link_pack_open or link_notice_open:
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
    if trial_mode and running and not paused and not upgrade_pending and not shop_open and not link_pack_open and not link_notice_open:
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
    if not result.get("upgraded", false):
        queue_link_discovery(key)
    rebuild_groups()
    return true

func bind_weapon_view(key: String) -> void:
    if not Catalog.WEAPONS.has(key):
        return
    _armory_options_dirty = true
    if not weapon_views.has(key):
        var view: Sprite2D = library.make_weapon(key, Catalog.WEAPONS[key]["size"] * (1.24 if key == "sling" else 1.12))
        view.set_meta("base_scale", view.scale)
        weapons_layer.add_child(view)
        weapon_views[key] = view
        weapon_runtime[key] = {"position": player_position, "cooldown": 0.03, "hit_times": {}, "initialized": false, "recoil": 0.0, "chain_state": "rest", "chain_position": player_position, "chain_direction": Vector2.RIGHT, "chain_distance": 0.0, "chain_hit_ids": [], "chain_damage": 0.0, "blend_left": 0.0, "blend_start": player_position, "trail_next": 0.0, "orbit_phase": 0.0}
    var visual: Sprite2D = weapon_views[key]
    visual.texture = library.weapon_texture(key, weapon_level(key))
    var extent: float = float(visual.texture.get_meta("display_extent", maxf(visual.texture.get_width(), visual.texture.get_height())))
    visual.scale = Vector2.ONE * Catalog.WEAPONS[key].size * (1.24 if key == "sling" else 1.12) / extent
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

func owned_weapon_ids() -> Array:
    var ids: Array = []
    for item in inventory:
        var key: String = str(item.get("id", ""))
        if not key.is_empty() and not ids.has(key):
            ids.append(key)
    return ids

func active_link_ids() -> Array:
    return Rules.link_ids_of(active_links)

func has_active_link(link_id: String) -> bool:
    return Rules.has_link_id(active_links, link_id)

func has_link_kind(kind: String) -> bool:
    return Rules.has_link_kind(active_links, kind)

func current_chain_link() -> Dictionary:
    return Rules.chain_profile(active_links)

func is_weapon_suppressed(weapon_id: String) -> bool:
    return Rules.suppressed_weapon_ids(active_links).has(weapon_id)

func weapon_reload_penalty(weapon_id: String) -> float:
    return Rules.weapon_cooldown_multiplier(weapon_id, active_links)

func link_hud_view() -> Dictionary:
    return Rules.combined_link_view(active_links)

func _chain_blocks_link_change(desired_ids: Array) -> bool:
    var current: Dictionary = current_chain_link()
    if current.is_empty():
        return false
    var key: String = str(current.get("weapons", ["", ""])[1]) if current.get("weapons", []).size() > 1 else ""
    if key.is_empty() or not weapon_runtime.has(key):
        return false
    if str(weapon_runtime[key].get("chain_state", "rest")) == "rest":
        return false
    var current_id: String = str(current.get("id", ""))
    if not desired_ids.has(current_id):
        return true
    return false

func _queue_pending_links(desired_ids: Array) -> void:
    pending_link_ids = desired_ids.duplicate()
    pending_link = "none" if desired_ids.is_empty() else str(desired_ids.back())
    combo_message = "先收回锁链武器，再切换"
    combo_message_time = 1.2
    var current: Dictionary = current_chain_link()
    if current.is_empty():
        return
    var key: String = str(current.get("weapons", ["", ""])[1]) if current.get("weapons", []).size() > 1 else ""
    if key.is_empty() or not weapon_runtime.has(key):
        return
    var runtime: Dictionary = weapon_runtime[key]
    if runtime["chain_state"] == "out":
        runtime["chain_state"] = "back"
        runtime["chain_hit_ids"] = []
        audio.play("chain_in", -1.0)

func rebuild_groups() -> void:
    var ids: Array = owned_weapon_ids()
    available_links = Rules.link_options(ids)
    apply_links(Rules.normalize_link_ids(active_link_ids(), ids), false)
    announce_link_ready()

func select_link(link_id: String) -> void:
    var ids: Array = owned_weapon_ids()
    var resolution: Dictionary = Rules.add_link_ids(active_link_ids(), link_id, ids)
    if bool(resolution.get("invalid", false)):
        return
    var desired: Array = resolution.get("ids", [])
    if _chain_blocks_link_change(desired):
        _queue_pending_links(desired)
        update_hud()
        return
    apply_links(desired)

func apply_link(profile: Dictionary) -> void:
    var ids: Array = owned_weapon_ids()
    var link_id: String = str(profile.get("id", "none"))
    var desired: Array = [] if link_id == "none" else Rules.normalize_link_ids([link_id], ids)
    set_links(desired)

func set_links(link_ids: Array) -> void:
    var desired: Array = Rules.normalize_link_ids(link_ids, owned_weapon_ids())
    if _chain_blocks_link_change(desired):
        _queue_pending_links(desired)
        update_hud()
        return
    apply_links(desired)

func apply_links(link_ids: Array, refresh: bool = true) -> void:
    var ids: Array = owned_weapon_ids()
    var desired: Array = Rules.normalize_link_ids(link_ids, ids)
    var previous_chain: Dictionary = current_chain_link()
    var profiles: Array = Rules.profiles_for_ids(desired, ids)
    var next_chain: Dictionary = Rules.chain_profile(profiles)
    if not previous_chain.is_empty():
        var key: String = str(previous_chain.get("weapons", ["", ""])[1]) if previous_chain.get("weapons", []).size() > 1 else ""
        var same_chain: bool = not next_chain.is_empty() and str(next_chain.get("id", "")) == str(previous_chain.get("id", ""))
        if not same_chain and not key.is_empty() and weapon_runtime.has(key) and weapon_views.has(key):
            weapon_runtime[key]["blend_left"] = 0.2
            weapon_runtime[key]["blend_start"] = weapon_views[key].position
    active_links = profiles
    _armory_options_dirty = true
    active_link = Catalog.LINKS["none"].duplicate(true) if profiles.is_empty() else profiles.back().duplicate(true)
    pending_link = ""
    pending_link_ids = []
    groups = profiles.duplicate()
    combo_mode = "none" if profiles.is_empty() else (str(profiles[0].get("id", "none")) if profiles.size() == 1 else "multi")
    if refresh:
        update_hud()

func switch_formation() -> void:
    if upgrade_pending or wave_closing or shop_open or player_frozen:
        return
    collapsed = not collapsed
    update_hud()

func announce_link_ready() -> void:
    if link_notice_open or available_links.size() <= 1:
        return
    var names: PackedStringArray = PackedStringArray()
    for recipe in available_links:
        var link_id: String = str(recipe.get("id", "none"))
        if link_id == "none" or _hinted_complete_links.has(link_id):
            continue
        _hinted_complete_links[link_id] = true
        names.append(str(recipe.get("name", "")))
    if names.is_empty():
        return
    combo_message = "可联动「%s」· 按 %s 拖拽启用" % [" / ".join(names), KeyBindings.caption_for("link")]
    combo_message_time = 3.2

func _seen_link_ids() -> Array:
    var seen: Array = []
    var raw: Variant = settings.get("seen_link_recipes", [])
    if typeof(raw) == TYPE_ARRAY:
        for entry in raw:
            var link_id: String = str(entry)
            if Catalog.LINKS.has(link_id) and link_id != "none" and not seen.has(link_id):
                seen.append(link_id)
    return seen

const LINK_DISCOVERY_BATCH: int = 3

func queue_link_discovery(weapon_id: String) -> void:
    if weapon_id.is_empty() or not Catalog.WEAPONS.has(weapon_id):
        return
    var seen: Array = _seen_link_ids()
    var owned: Array = Catalog.inventory_ids(inventory)
    for recipe in Catalog.recipes_for_weapon(weapon_id):
        # Only announce recipes whose partner is already in the pack.
        if not Catalog.recipe_complete(recipe, owned):
            continue
        var link_id: String = str(recipe.get("id", ""))
        if link_id.is_empty() or seen.has(link_id):
            continue
        var already: bool = false
        for pending in pending_link_notice:
            if str(pending.get("id", "")) == link_id:
                already = true
                break
        if already:
            continue
        pending_link_notice.append(recipe)

func try_present_link_discovery(force: bool = false) -> bool:
    if link_notice_open or pending_link_notice.is_empty() or not running:
        return false
    if not force and (_run_bootstrapping or departure_left > 0.0 or demo or animation_demo or trial_mode or restoring):
        return false
    if hud == null or not hud.has_method("show_link_discovery"):
        return false
    if upgrade_pending and replace_pending.is_empty():
        return false
    var recipes: Array = pending_link_notice.duplicate(true)
    if recipes.size() > LINK_DISCOVERY_BATCH:
        recipes = recipes.slice(0, LINK_DISCOVERY_BATCH)
    var owned: Array = Catalog.inventory_ids(inventory)
    _link_notice_return = "shop" if shop_open else str(hud.screen)
    link_notice_open = true
    player_frozen = true
    if not shop_open and not upgrade_pending and audio != null and not paused:
        audio.set_paused(true)
    hud.show_link_discovery(recipes, owned)
    pending_link_notice = pending_link_notice.slice(recipes.size())
    update_hud()
    return true

func _mark_link_recipes_seen(recipes: Array) -> void:
    var previous: Array = _seen_link_ids()
    var seen: Array = previous.duplicate()
    var changed: bool = false
    for recipe in recipes:
        var link_id: String = str(recipe) if typeof(recipe) == TYPE_STRING else str(recipe.get("id", ""))
        if not Catalog.LINKS.has(link_id) or link_id == "none" or seen.has(link_id):
            continue
        seen.append(link_id)
        changed = true
    if not changed:
        return
    settings["seen_link_recipes"] = seen
    var result: Dictionary = save_store.write_settings(settings)
    if not result.get("ok", false):
        settings["seen_link_recipes"] = previous

func _close_link_discovery_ui() -> void:
    var reopen_shop: bool = shop_open
    link_notice_open = false
    if not shop_open and not upgrade_pending and not paused and audio != null:
        audio.set_paused(false)
    if player_hp > 0.0 and running and not wave_closing:
        player_frozen = false
    if hud != null and hud.has_method("hide_link_discovery"):
        hud.hide_link_discovery(reopen_shop)
        if reopen_shop:
            show_current_shop(false)
        elif hud.screen != "combat" and not upgrade_pending and not shop_open:
            hud.hide_menu()
    update_hud()

func _on_link_discovery_enable(link_id: String) -> void:
    if not link_notice_open:
        return
    if hud != null:
        _mark_link_recipes_seen(hud.link_discovery_recipes() if hud.has_method("link_discovery_recipes") else pending_link_notice)
    select_link(link_id)
    _close_link_discovery_ui()

func _on_link_discovery_closed() -> void:
    if not link_notice_open:
        return
    if hud != null:
        _mark_link_recipes_seen(hud.link_discovery_recipes() if hud.has_method("link_discovery_recipes") else [])
    _close_link_discovery_ui()

func toggle_hud_hidden() -> void:
    if hud == null or not running or shop_open or upgrade_pending or not hud.has_method("toggle_hud_hidden"):
        return
    if paused or stats_open:
        return
    hud.toggle_hud_hidden()

func switch_combo_mode() -> void:
    toggle_link_pack()

func _can_open_link_pack() -> bool:
    if not running or inventory.is_empty() or player_hp <= 0.0:
        return false
    if upgrade_pending or wave_closing or link_notice_open or departure_left > 0.0 or animation_demo or paused or stats_open:
        return false
    if not replace_pending.is_empty():
        return false
    if hud == null:
        return true
    return hud.screen in ["combat", "link_pack", "shop", ""]

func toggle_link_pack() -> void:
    if link_pack_open:
        close_link_pack()
        return
    open_link_pack()

func open_link_pack() -> bool:
    if link_pack_open:
        if hud != null and hud.has_method("refresh_link_pack"):
            hud.refresh_link_pack()
        return true
    if not _can_open_link_pack():
        return false
    _link_pack_return = "shop" if shop_open else (str(hud.screen) if hud != null else "")
    link_pack_open = true
    player_frozen = true
    if audio != null and not paused and not shop_open:
        audio.set_paused(true)
    if hud != null and hud.has_method("show_link_pack"):
        hud.show_link_pack(self)
    update_hud()
    return true

func close_link_pack() -> void:
    if not link_pack_open and (hud == null or hud.link_pack == null):
        link_pack_open = false
        return
    var reopen_shop: bool = shop_open
    link_pack_open = false
    _link_pack_return = ""
    if hud != null and hud.has_method("hide_link_pack"):
        hud.hide_link_pack(reopen_shop)
    if reopen_shop and running and player_hp > 0.0:
        show_current_shop(false)
    elif not shop_open and not upgrade_pending and not link_notice_open and not paused and running and player_hp > 0.0 and not wave_closing:
        player_frozen = false
        if audio != null:
            audio.set_paused(false)
    update_hud()

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
    if not running or upgrade_pending or shop_open or animation_demo or link_notice_open or link_pack_open:
        return
    paused = not paused
    audio.set_paused(paused)
    if paused:
        hud.show_menu("pause", kills)
    else:
        hud.hide_menu()
    update_hud()

func finish_run(won: bool) -> void:
    if training_mode and not won:
        # Training Camp death never enters normal Game Over: revive full HP & return directly to Training Camp!
        player_hp = float(stats.get("max_hp", 20.0))
        invulnerable = 1.2
        projectiles = projectiles.filter(func(p): return str(p.get("kind", "")) != "hostile")
        for enemy in enemies:
            var away: Vector2 = Vector2(enemy["position"]) - player_position
            if away.length() < 160.0:
                enemy["position"] = player_position + (away.normalized() if away.length() > 1.0 else Vector2.RIGHT) * 180.0
        if audio != null:
            audio.play("ui_open", -6.0)
        open_training_panel()
        if training_panel != null and training_panel.has_method("set_notice"):
            training_panel.set_notice("在训练营中已倒下，已自动满血复活！可开启「玩家无敌」或调整配装后继续测试")
        update_hud()
        return
    running = false
    paused = false
    upgrade_pending = false
    stats_open = false
    shop_open = false
    wave_closing = false
    wave_buffer = 0.0
    player_frozen = false
    close_link_pack()
    link_notice_open = false
    link_pack_open = false
    pending_link_notice.clear()
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
    close_link_pack()
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
    if try_present_link_discovery():
        return
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
    var vp_size: Vector2 = Vector2(1280.0, 800.0)
    if is_inside_tree():
        var raw_size: Vector2 = get_viewport_rect().size
        if raw_size.x > 10.0 and raw_size.y > 10.0:
            vp_size = raw_size
    return Rect2(player_position - vp_size * 0.5, vp_size)

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
    hud.update_state(player_hp, elapsed, kills, xp, xp_needed, inventory, collapsed, link_hud_view(), prefer_elite, trial_mode)
    var boss: Dictionary = {}
    for enemy in enemies:
        if enemy["kind"] == "boss" and enemy["hp"] > 0.0:
            boss = enemy
            break
    var hud_is_boss: bool = boss_round and not boss_defeated
    var hud_stage_time: float = (WAVE_SECONDS - boss_clear_left) if (boss_round and boss_defeated) else wave_elapsed
    var hud_wave_num: int = -1 if training_mode else wave
    hud.update_round(hud_wave_num,hud_stage_time,hud_is_boss,coins,boss.get("hp",0.0),boss.get("max_hp",0.0), BiomeEncounters.boss_name(str(boss["form"])) if boss.has("form") else "")
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
    if code == KEY_T and training_mode and running:
        toggle_training_panel()
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
        toggle_link_pack()
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
        if training_panel_open:
            close_training_panel()
            return
        if hud != null and hud.screen == "replace_confirm" and hud.has_method("cancel_replace_confirm"):
            hud.cancel_replace_confirm()
        elif not replace_pending.is_empty():
            cancel_replace()
        elif hud != null and hud.screen == "restart_confirm" and hud.has_method("cancel_restart"):
            hud.cancel_restart()
        elif hud != null and hud.screen == "help_confirm" and hud.has_method("cancel_help_trial"):
            hud.cancel_help_trial()
        elif link_notice_open and hud != null and hud.has_method("cancel_link_discovery"):
            hud.cancel_link_discovery()
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
                "link_discover":
                    if hud.has_method("confirm_link_discovery"):
                        hud.confirm_link_discovery()
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
    if not running or player_hp <= 0.0 or paused or shop_open or upgrade_pending or stats_open or player_frozen or link_notice_open or link_pack_open or wave_closing or departure_left > 0.0 or animation_demo:
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
    if _pending_departure_discovery and departure_left <= 0.0:
        _pending_departure_discovery = false
        try_present_link_discovery()

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
            _pending_departure_discovery = true
        return
    if animation_demo:
        animate_showcase(delta)
        return
    if not running or paused or upgrade_pending or shop_open or link_notice_open or link_pack_open or training_panel_open:
        return
    if player_frozen:
        movement = Vector2.ZERO
    if wave_closing:
        var still_absorbing: bool = absorb_round_resources(delta)
        wave_buffer=maxf(0,wave_buffer-delta)
        closing_absorb_left=maxf(0.0, closing_absorb_left - delta)
        effects.advance(delta)
        if wave_buffer<=0.000001 and (not still_absorbing or closing_absorb_left <= 0.000001): _finish_wave_closing()
        queue_redraw()
        return
    elapsed += delta
    wave_elapsed += delta
    if boss_round and not boss_defeated and wave_elapsed >= BOSS_WAVE_LIMIT_SECONDS:
        finish_run(false)
        update_hud()
        queue_redraw()
        return
    if boss_round and boss_defeated:
        boss_clear_left = maxf(0.0, boss_clear_left - delta)
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
    if world_camera != null:
        world_camera.position = player_position
        world_camera.force_update_scroll()
    if map_view != null:
        map_view.set_view(player_position, wave)
    effects.hero_anchor = player_position
    effects._has_hero_anchor = true
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
    _ground_marks_accum += delta
    _pickup_sync_accum += delta
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
    if not training_mode and ((boss_round and boss_defeated and boss_clear_left <= 0.000001) or (not boss_round and wave_elapsed >= WAVE_SECONDS - 0.000001)):
        start_wave_closing()
        apply_weapon_glows(delta)
        update_hud()
        queue_redraw()
        _simulating = false
        return
    if training_mode:
        apply_weapon_glows(delta)
        _hud_accum += delta
        if _hud_accum >= 0.10:
            _hud_accum = 0.0
            update_hud()
        queue_redraw()
        _simulating = false
        return
    spawn_clock -= delta
    # A Boss stage is a normal stage plus one Boss: same cadence, cap, and
    # regular minion pool, including after the Boss falls. The 30 s cleanup
    # window stays live and keeps the same normal-stage pipeline.
    var alive_cap: int = enemy_limit()
    if spawn_clock <= 0.0 and enemies.size() < alive_cap:
        var spawn_interval: float = Rules.spawn_interval_for(wave, boss_round, boss_defeated, enemies.size())
        spawn_clock = spawn_interval
        if boss_pending:
            spawn_enemy("boss",offscreen_point(1)+Vector2(48,0),false,"enter")
            var boss: Dictionary=enemies.back()
            var formula_hp: float = float(boss.max_hp)
            var capped_hp: float = Progression.cap_boss_hp(formula_hp, Progression.estimate_power(inventory,buff_levels,active_links))
            boss.hp=capped_hp
            boss.max_hp=capped_hp
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
    _hud_accum += delta
    if _hud_accum >= 0.10 or DisplayServer.get_name() == "headless":
        _hud_accum = 0.0
        update_hud()
    queue_redraw()
    _simulating = false

func advance_wave(next_wave: int) -> void:
    var old_wave: int = wave
    wave = next_wave
    record_character_wave(wave)
    var milestone: bool = wave / 5 > old_wave / 5
    if milestone:
        enemy_adaptation = Progression.adaptation(wave, Progression.estimate_power(inventory, buff_levels, active_links), enemy_adaptation)
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
    if not pending_link.is_empty() or not pending_link_ids.is_empty():
        var desired: Array = pending_link_ids.duplicate()
        if desired.is_empty() and pending_link != "none":
            desired = [pending_link]
        apply_links(desired)
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
    if link_notice_open:
        _on_link_discovery_closed()
    close_link_pack()
    link_notice_open = false
    link_pack_open = false
    player_frozen = false
    boss_round = wave % 5 == 0
    boss_defeated = false
    boss_clear_left = 0.0
    spawn_clock = 0.55
    ward_ready.clear()
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
    # Uncollected gems, blood packs, and ground chests are not vacuumed in at wave end.
    pickups.clear()
    chest_marks.clear()

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

func grant_stage_clear_hp() -> void:
    if stage_hp_granted_wave >= wave:
        return
    stage_hp_granted_wave = wave
    stage_hp_bonus += 1
    refresh_stats()
    player_hp = minf(float(stats["max_hp"]), player_hp + Growth.STAGE_CLEAR_HP)
    if hud != null:
        update_hud()

func start_wave_closing() -> void:
    if wave_closing or shop_open or not running:
        return
    grant_stage_clear_hp()
    close_link_pack()
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
    var magnet_r2: float = pickup_magnet_radius() * pickup_magnet_radius()
    var has_in_range: bool = false
    for stone in pickups:
        if Vector2(stone["position"]).distance_squared_to(player_position) <= magnet_r2:
            stone["closing_pull"] = true
            has_in_range = true
    closing_absorb_left = 1.6 if has_in_range else 0.0
    audio.stop_all()
    audio.set_paused(true)
    auto_save()

func _finish_wave_closing() -> void:
    wave_buffer = 0.0
    closing_absorb_left = 0.0
    player_frozen = true
    discard_remaining_drops()
    if demo:
        begin_round(wave + 1)
    else:
        continue_round_rewards()

func absorb_round_resources(delta: float) -> bool:
    # Only pickups ALREADY inside pickup magnet range when the wave ended finish flying into the player.
    var remaining: int = 0
    var pulling_count: int = 0
    for index in range(pickups.size()):
        var stone: Dictionary = pickups[index]
        if bool(stone.get("closing_pull", false)):
            stone["position"] = Vector2(stone["position"]).move_toward(player_position, 460.0 * maxf(0.0, delta))
            if Vector2(stone["position"]).distance_squared_to(player_position) < 484.0:
                var kind: String = str(stone.get("kind", "xp"))
                if kind == "coin":
                    coins += int(stone["value"])
                elif kind == "blood":
                    var healed: float = minf(stats["max_hp"] - player_hp, float(stone.get("value", LootRules.BLOOD_PACK_HEAL)))
                    player_hp += maxf(0.0, healed)
                else:
                    xp += LootDrops.experience_value(stone) * stats["xp_multiplier"]
                continue
            pulling_count += 1
        pickups[remaining] = stone
        remaining += 1
    pickups.resize(remaining)
    update_hud()
    return pulling_count > 0

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
    grant_stage_clear_hp()
    wave_closing = true
    wave_buffer = 0.0
    player_frozen = true
    dismiss_remaining_enemies()
    discard_remaining_drops()
    continue_round_rewards()

func open_round_shop() -> void:
    close_link_pack()
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
        var current: String = str(link_hud_view().get("name", "不联动"))
        return "按 %s 打开背包拖拽联动（当前：%s）· 同武器限一种附魔" % [KeyBindings.caption_for("link"), current]
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
        return "联动将成：已有%s，还差%s → %s（集齐后按 %s 打开背包拖拽启用）" % [Catalog.WEAPONS[held]["name"], Catalog.WEAPONS[missing]["name"], Catalog.LINKS[link_id]["name"], KeyBindings.caption_for("link")]
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
    try_present_link_discovery()
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
    queue_link_discovery(new_id)
    rebuild_groups()
    coins += refund
    if source == "shop":
        coins -= price_paid
        shop_stock[shop_index]["sold"] = true
        replace_pending.clear()
        show_current_shop(false, shop_index)
        update_hud()
        auto_save()
        try_present_link_discovery()
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
    return float(stats["pickup_radius"]) + Rules.magnet_wave_bonus(wave)

func update_pickups(delta: float) -> void:
    var remaining: int = 0
    var bursts: int = 0
    var radius_squared: float = pickup_magnet_radius() * pickup_magnet_radius()
    for index in range(pickups.size()):
        var stone: Dictionary = pickups[index]
        var kind: String = str(stone.get("kind", "xp"))
        # Only coins and XP gems respond to pickup magnet; blood packs and chests must be walked onto directly.
        if kind != "blood" and stone["position"].distance_squared_to(player_position) <= radius_squared:
            stone["position"] = stone["position"].move_toward(player_position, 330.0 * delta)
        if stone["position"].distance_squared_to(player_position) < 484.0:
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
            if bursts < 6:
                var burst_color := Color("#e2b85d") if kind == "coin" else (Color("#e07a7a") if kind == "blood" else Color("#87d5ae"))
                var burst_size: float = 4.5 if kind == "coin" else 6.0
                effects.burst(player_position + Vector2(0, 12), burst_color, burst_size)
                bursts += 1
        else:
            pickups[remaining] = stone
            remaining += 1
    pickups.resize(remaining)
    if pickups.size() > 140:
        var keep: Array = []
        var far_buckets: Dictionary = {}
        var far_sq: float = 380.0 * 380.0
        for item in pickups:
            var ikind: String = str(item.get("kind", "xp"))
            if ikind == "blood" or item["position"].distance_squared_to(player_position) <= far_sq:
                keep.append(item)
            elif not far_buckets.has(ikind):
                if ikind == "xp" and item.has("legacy_fraction"):
                    item["value"] = LootDrops.experience_value(item)
                    item.erase("legacy_fraction")
                far_buckets[ikind] = item
                keep.append(item)
            else:
                var bucket: Dictionary = far_buckets[ikind]
                if ikind == "coin":
                    bucket["value"] = int(bucket.get("value", 1)) + int(item.get("value", 1))
                else:
                    bucket["value"] = float(bucket.get("value", 1.0)) + LootDrops.experience_value(item)
        pickups = keep

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
    # Boss stages use the same elite budget as a normal stage of this wave.
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
    elite_budget = maxi(0, 2 - existing)

func take_wave_elite() -> bool:
    if elite_budget <= 0:
        return false
    var interval: float = maxf(0.40, 0.62 - float(wave - 1) * 0.10)
    var remaining_time: float = maxf(interval, WAVE_SECONDS - wave_elapsed)
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

func enemy_limit() -> int:
    return Rules.enemy_limit_for(wave, boss_round)

func spawn_enemy(kind: String, point: Vector2 = Vector2(INF, INF), wave_spawn: bool = false, arrival: String = "") -> void:
    map_view.set_view(player_position,wave)
    var data: Dictionary = Catalog.DINOS.get(kind, BiomeEncounters.MOBS.get(kind, {}))
    var form: String = BiomeEncounters.boss_form(wave) if kind == "boss" else kind
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
    view.setup(library, kind if Catalog.DINOS.has(kind) else "hunter", data["size"] * (1.1 if elite else 1.0), elite)
    var encounter_art: String = BiomeEncounters.art_form(kind, form, wave)
    if not encounter_art.is_empty():
        view.set_encounter_art(encounter_art)
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
    enemies.append({"id": enemy_serial, "kind": kind, "position": point, "hp": hp, "max_hp": hp, "elite": elite, "view": view, "radius": data["radius"], "state": start_state, "timer": start_timer, "direction": Vector2.RIGHT, "knock": Vector2.ZERO, "velocity": Vector2.ZERO, "attack_cycle":0, "form":form, "arrival": mode})
    for key in ["damage", "dodge", "speed_multiplier", "bullet_multiplier"]:
        enemies.back()[key] = profile[key]

func update_enemies(delta: float) -> void:
    recycle_distant_enemies()
    _sep_parity += 1
    var compute_sep: bool = (_sep_parity % 2) == 1
    # Frame snapshots + spatial hash grid for the separation pass (refreshed on alternate frames for high FPS).
    var sep_positions := PackedVector2Array()
    var sep_grid: Dictionary = {}
    if compute_sep:
        sep_positions.resize(enemies.size())
        for sep_index in range(enemies.size()):
            var pos: Vector2 = enemies[sep_index]["position"]
            sep_positions[sep_index] = pos
            if float(enemies[sep_index]["hp"]) > 0.0:
                var cell := Vector2i(floori(pos.x / 48.0), floori(pos.y / 48.0))
                if sep_grid.has(cell):
                    sep_grid[cell].append(sep_index)
                else:
                    sep_grid[cell] = [sep_index]
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
        if _hold_paralyzed_enemy(enemy, delta, view_rect):
            continue
        var difference: Vector2 = player_position - enemy["position"]
        var distance: float = difference.length()
        var direction: Vector2 = difference.normalized() if distance > 0.001 else Vector2.RIGHT
        if enemy.get("state", "walk") == "enter":
            var enter_speed: float = Catalog.DINOS.get(enemy["kind"], BiomeEncounters.MOBS.get(enemy["kind"], {}))["speed"] * float(enemy.get("speed_multiplier", 1.0))
            var enter_velocity: Vector2 = direction * enter_speed
            enemy["timer"] -= delta
            enemy["knock"] = enemy["knock"].move_toward(Vector2.ZERO, delta * 270.0)
            enter_velocity += enemy["knock"]
            enter_velocity = _ward_velocity(enemy, enter_velocity, delta)
            enemy["velocity"] = enter_velocity
            var enter_origin: Vector2 = enemy["position"]
            enemy["position"] = _move_warded_enemy(enemy, enter_velocity, delta)
            var enter_view = enemy.get("view")
            if is_instance_valid(enter_view):
                enter_view.position = enemy["position"]
                enter_view.health_fraction = enemy["hp"] / enemy["max_hp"]
                if view_rect.has_point(enemy["position"]):
                    enter_view.animate(enter_velocity, delta, "walk", enter_origin.distance_to(enemy["position"]))
            if visible_world_rect().grow(-12.0).has_point(enemy["position"]):
                enemy["state"] = "walk"
                enemy["timer"] = rng.randf_range(0.35, 1.0)
            continue
        var velocity: Vector2 = direction * Catalog.DINOS.get(enemy["kind"], BiomeEncounters.MOBS.get(enemy["kind"], {}))["speed"]
        enemy["timer"] -= delta
        var encounter: bool = BiomeEncounters.active(enemy)
        var behavior: Dictionary = BiomeEncounters.advance(self, enemy, delta) if encounter else EnemyRoster.advance(self, enemy, delta)
        if not running: break
        if behavior.handled:
            velocity=behavior.velocity
        elif enemy["kind"] == "charger":
            match enemy["state"]:
                "walk":
                    if distance < 245.0 and enemy["timer"] <= 0.0:
                        enemy["attack_cycle"] += 1
                        enemy["state"] = "windup"
                        enemy["timer"] = 0.65
                        enemy["direction"] = direction
                        velocity = Vector2.ZERO
                "windup":
                    velocity = Vector2.ZERO
                    if enemy["timer"] <= 0.0:
                        enemy["state"] = "dash"
                        enemy["timer"] = CHARGE_DURATION
                "dash":
                    velocity = enemy["direction"] * CHARGE_SPEED
                    if enemy["timer"] <= 0.0:
                        enemy["state"] = "recover"
                        enemy["timer"] = 0.6
                        velocity = Vector2.ZERO
                "recover":
                    velocity = Vector2.ZERO
                    if enemy["timer"] <= 0.0:
                        enemy["state"] = "walk"
                        enemy["timer"] = 1.4
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
            if compute_sep:
                var separation: Vector2 = Vector2.ZERO
                var self_position: Vector2 = enemy["position"]
                var cx: int = floori(self_position.x / 48.0)
                var cy: int = floori(self_position.y / 48.0)
                for dy in range(-1, 2):
                    for dx in range(-1, 2):
                        var bucket = sep_grid.get(Vector2i(cx + dx, cy + dy))
                        if bucket == null:
                            continue
                        for other_index in bucket:
                            if other_index == enemy_index:
                                continue
                            var offset: Vector2 = self_position - sep_positions[other_index]
                            var offset_length_squared: float = offset.length_squared()
                            if offset_length_squared < 1500.0 and offset_length_squared > 0.01:
                                separation += offset * (28.0 / sqrt(offset_length_squared))
                enemy["_sep"] = separation.limit_length(48)
            velocity += Vector2(enemy.get("_sep", Vector2.ZERO))
        if not encounter or enemy["state"] == "walk":
            velocity += enemy["knock"]
        velocity = _ward_velocity(enemy, velocity, delta)
        var before_move: Vector2 = enemy["position"]
        enemy["velocity"] = velocity
        enemy["knock"] = enemy["knock"].move_toward(Vector2.ZERO, delta * 270.0)
        # A stationary enemy whose position was already resolved by move_body
        # cannot become embedded (stones never move), so re-solving it every
        # frame is pure cost; spitters/throwers/chargers stand still a lot.
        if velocity.is_zero_approx() and bool(enemy.get("settled", false)):
            pass
        else:
            enemy["position"] = _move_warded_enemy(enemy, velocity, delta)
            enemy["settled"] = true
        enemy["view"].position = enemy["position"]
        enemy["view"].health_fraction = enemy["hp"] / enemy["max_hp"]
        # Off-screen enemies skip the walk-cycle update and redraw; their view
        # position and health stay current, and animation resumes (with the
        # 160px margin) before they can walk into view.
        if view_rect.has_point(enemy["position"]):
            if encounter and enemy["state"] != "walk":
                enemy["view"].face_attack(enemy["direction"])
            enemy["view"].animate(velocity, delta, behavior.get("pose",enemy["state"]), before_move.distance_to(enemy["position"]))
        if encounter:
            BiomeEncounters.strike_travel(self, enemy, before_move)
            if not running:
                break
        var contact_r: float = float(enemy["radius"]) + 18.0
        if (not encounter or enemy["state"] == "walk") and enemy["position"].distance_squared_to(player_position) < contact_r * contact_r:
            hurt_player((player_position - enemy["position"]).normalized(), enemy["damage"], enemy["kind"] == "boss")
            if not running:
                break

func _ward_velocity(enemy: Dictionary, velocity: Vector2, delta: float) -> Vector2:
    if str(enemy.get("ward_kind", "")) == "paralyze" or bool(enemy.get("paralyzed", false)):
        var left: float = float(enemy.get("ward_left", 0.0))
        if left <= 0.0:
            enemy["paralyzed"] = false
            enemy["ward_kind"] = ""
            enemy["ward_moving"] = false
            return velocity
        enemy["ward_left"] = left - minf(left, maxf(delta, 0.000001))
        enemy["ward_moving"] = false
        enemy["knock"] = Vector2.ZERO
        return Vector2.ZERO
    var slow_left: float = float(enemy.get("slow_left", 0.0))
    if slow_left > 0.0:
        enemy["slow_left"] = maxf(0.0, slow_left - delta)
        velocity *= 0.70
    var left: float = float(enemy.get("ward_left", 0.0))
    if left <= 0.0:
        enemy["ward_moving"] = false
        return velocity
    var step: float = minf(left, maxf(delta, 0.000001))
    enemy["ward_left"] = left - step
    enemy["ward_moving"] = true
    var direction: Vector2 = enemy.get("ward_dir", Vector2.RIGHT)
    if direction.length_squared() < 0.0001:
        direction = Vector2.RIGHT
    return direction.normalized() * float(enemy.get("ward_speed", 0.0))

func _move_warded_enemy(enemy: Dictionary, velocity: Vector2, delta: float) -> Vector2:
    var next: Vector2 = enemy["position"] + velocity * delta
    if bool(enemy.get("ward_moving", false)):
        next = arrive_inside(next)
    return map_view.move_body(enemy["position"], next, enemy["radius"])

func try_apply_ward(enemy: Dictionary, source: String, origin: Vector2 = Vector2.INF) -> bool:
    if enemy.is_empty() or float(enemy.get("hp", 0.0)) <= 0.0:
        return false
    var level: int = weapon_level("totem") if source == "thunder" else weapon_level("staff")
    var profile: Dictionary = Rules.ward_profile(source, level)
    if str(profile.get("kind", "none")) != "paralyze":
        return false
    var duration: float = float(profile.get("duration", 0.0))
    if duration <= 0.001:
        return false
    if str(enemy.get("kind", "")) == "boss":
        return false
    if bool(enemy.get("paralyzed_once", false)) or bool(enemy.get("cc_once", false)):
        return false
    if str(enemy.get("kind", "")) in ["tank", "charger", "cindertusk", "magmashell", "stonehorn"] or bool(enemy.get("elite", false)):
        # Heavy / bruiser / charger / elite monsters resist paralysis: brief 30% slow only (once per life)!
        enemy["cc_once"] = true
        enemy["paralyzed_once"] = true
        enemy["slow_left"] = 0.65
        return false
    if elapsed < float(ward_ready.get(source, -1000.0)):
        return false
    enemy["cc_once"] = true
    enemy["paralyzed_once"] = true
    ward_ready[source] = elapsed + float(profile.get("interval", Rules.PARALYZE_INTERVAL))
    enemy["ward_kind"] = "paralyze"
    enemy["ward_left"] = duration
    enemy["paralyzed"] = true
    enemy["ward_moving"] = false
    enemy["ward_dir"] = Vector2.ZERO
    enemy["ward_speed"] = 0.0
    enemy["knock"] = Vector2.ZERO
    enemy["velocity"] = Vector2.ZERO
    if effects != null:
        effects.puff(enemy["position"], Color("#d8f7ff"), 9.0)
    return true

func _hold_paralyzed_enemy(enemy: Dictionary, delta: float, view_rect: Rect2) -> bool:
    if str(enemy.get("ward_kind", "")) != "paralyze" and not bool(enemy.get("paralyzed", false)):
        return false
    var left: float = float(enemy.get("ward_left", 0.0))
    if left <= 0.0:
        enemy["ward_left"] = 0.0
        enemy["paralyzed"] = false
        enemy["ward_kind"] = ""
        enemy["ward_moving"] = false
        return false
    enemy["ward_left"] = left - delta
    if enemy["ward_left"] <= 0.0:
        enemy["ward_left"] = 0.0
        enemy["paralyzed"] = false
        enemy["ward_kind"] = ""
        enemy["ward_moving"] = false
        return false
    enemy["paralyzed"] = true
    enemy["ward_moving"] = false
    enemy["knock"] = Vector2.ZERO
    enemy["velocity"] = Vector2.ZERO
    var view = enemy.get("view")
    if is_instance_valid(view):
        view.position = enemy["position"]
        view.health_fraction = enemy["hp"] / enemy["max_hp"]
        if view_rect.has_point(enemy["position"]):
            view.animate(Vector2.ZERO, delta, "walk")
    return true

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

func enchant_damage_multiplier(weapon_id: String) -> float:
    return Rules.enchant_damage_bonus(active_links, weapon_id, Evolution.tier(weapon_level("firepot")), Evolution.tier(weapon_level("staff")), Evolution.tier(weapon_level("totem")))

func update_armory(delta: float) -> void:
    if _armory_options_dirty or _armory_options_cache.is_empty():
        _armory_options_cache = stats.duplicate()
        _armory_options_cache["link_kind"] = active_link.get("kind", "none") if active_links.size() <= 1 else "multi"
        var lk: Array = []
        for recipe in active_links:
            var rkind: String = str(recipe.get("kind", "none"))
            if not rkind.is_empty() and not lk.has(rkind):
                lk.append(rkind)
        _armory_options_cache["link_kinds"] = lk
        _armory_options_cache["suppressed_weapons"] = Rules.suppressed_weapon_ids(active_links)
        _armory_options_cache["reload_weapon"] = str(active_link.get("reload_weapon", ""))
        _armory_options_cache["reload_multiplier"] = float(active_link.get("cooldown_multiplier", 1.0))
        _armory_options_cache["reload_multipliers"] = Rules.reload_multipliers(active_links)
        _armory_options_cache["staff_tier"] = Evolution.tier(weapon_level("staff"))
        _armory_options_cache["firepot_tier"] = Evolution.tier(weapon_level("firepot"))
        _armory_options_cache["totem_tier"] = Evolution.tier(weapon_level("totem"))
        _armory_options_cache["totem_level"] = weapon_level("totem")
        _armory_options_cache["hammer_thunder"] = Rules.host_is_thunder_enchanted(active_links, "hammer")
        _armory_options_cache["enchant_mults"] = {
            "spear": enchant_damage_multiplier("spear"),
            "hammer": enchant_damage_multiplier("hammer"),
            "boomerang": enchant_damage_multiplier("boomerang"),
            "bonebow": enchant_damage_multiplier("bonebow")
        }
        _armory_options_dirty = false
    var options: Dictionary = _armory_options_cache
    options["totem_next_red"] = _peek_thunder_red("totem")
    options["bonebow_next_red"] = _peek_thunder_red("bonebow") if Rules.host_is_thunder_enchanted(active_links, "bonebow") else false
    for command in armory.advance(delta,player_position,combat_targets(),inventory,options,prefer_elite,weapon_views,current_weapon_mounts()):
        match command.get("type",""):
            "motion":
                var mwid: String = str(command["weapon_id"])
                var mtint: Color = _weapon_charge_color(mwid) if _host_is_enchanted(mwid) else Color.TRANSPARENT
                effects.weapon_motion(command["position"], command["direction"], mwid, mtint)
            "flash":
                var fwid: String = str(command.get("weapon_id", ""))
                flash_weapon(fwid)
                if fwid == "totem" or (fwid == "bonebow" and Rules.host_is_thunder_enchanted(active_links, "bonebow")):
                    _consume_thunder_red(fwid)
            "hit":
                var before_hp: float=float(command.enemy.hp)
                var was_living_monster: bool = Rules.is_living_monster(command.enemy)
                var cmd_wid: String = str(command.get("weapon_id", ""))
                var cmd_force_red: int = -1
                if bool(command.get("thunder_enchanted", false)):
                    cmd_force_red = 1 if bool(command.get("thunder_red", false)) else 0
                elif cmd_wid in ["spear", "boomerang"] and Rules.host_is_thunder_enchanted(active_links, cmd_wid):
                    cmd_force_red = 1 if _consume_thunder_red(cmd_wid) else 0
                hurt_enemy(command["enemy"],command["damage"],command["weapon_id"],false,command["direction"],cmd_force_red)
                apply_weapon_link_hit(command.enemy.position, cmd_wid, str(command.enemy.get("id", "")), float(command.get("damage", 0.0)), cmd_force_red)
                flash_weapon(command["weapon_id"])
            "area":
                var area_weapon: String = str(command.get("weapon_id", ""))
                var is_primary: bool = bool(command.get("primary", float(command.get("radius", 0.0)) <= 86.0))
                if area_weapon == "hammer" and bool(options["hammer_thunder"]):
                    # ONE massive sky lightning bolt hitting the whole AoE pack + ground Lichtenberg electric vein pattern (synced with pre-fire glow!)
                    var totem_lvl: int = weapon_level("totem")
                    var is_red: bool = _consume_thunder_red("hammer")
                    var red_mult: float = Rules.red_lightning_multiplier(totem_lvl) if is_red else 1.0
                    var bolt_color: Color = Color("#ff3a2e") if is_red else BattleVisuals.thunder_tint(int(options["totem_tier"]))
                    var strike_pt: Vector2 = Vector2(command["position"])
                    var strike_r: float = minf(maxf(116.0, float(command["radius"]) * 1.12) * stats["area_multiplier"], 205.0)
                    effects.sky_lightning(strike_pt + Vector2(rng.randf_range(-24.0, 24.0), -380.0), strike_pt, bolt_color, false, 1.55 if is_red else 1.48, is_red)
                    trigger_lava_lightning_splash(strike_pt, 1.15)
                    # Wrap up to 4 struck monsters BEFORE damage_area so even one-shot enemies visibly crackle!
                    var wrapped: int = 0
                    for enemy in combat_targets():
                        if wrapped >= 4:
                            break
                        if float(enemy.get("hp", 0.0)) > 0.0 and Rules.is_living_monster(enemy):
                            var reach_e: float = strike_r + float(enemy.get("radius", 0.0))
                            if Vector2(enemy["position"]).distance_squared_to(strike_pt) <= reach_e * reach_e:
                                effects.shock_wrap(enemy["position"], float(enemy.get("radius", 24.0)) + 8.0, bolt_color, is_red)
                                wrapped += 1
                    damage_area(strike_pt, strike_r, float(command["damage"]) * red_mult, "hammer", true, bolt_color, "thunder_blast", 1 if is_red else 0)
                    # Ground electric Lichtenberg crack-vein pattern (capped radius so high area buff never floods screen)
                    var has_recent_mark: bool = false
                    for f in burning_fields:
                        if str(f.get("residual", "")) == "thunder_mark" and float(f.get("age", 1.0)) < 0.30 and Vector2(f.get("position", Vector2.ZERO)).distance_squared_to(strike_pt) < 625.0:
                            has_recent_mark = true
                            break
                    if not has_recent_mark:
                        burning_fields.append({"position": strike_pt, "age": 0.0, "life": 1.85, "tick": 1.0, "radius": minf(strike_r * 0.72, 138.0), "damage": 0.0, "weapon_id": "totem", "from_link": true, "residual": "thunder_mark", "heavy": true, "crater": false, "red": is_red})
                        if burning_fields.size() > 6:
                            burning_fields.pop_front()
                    audio.play("magic_hit", 0.0, 0.66 if is_red else 0.72)
                    flash_weapon("hammer")
                    if is_primary:
                        apply_weapon_link_hit(strike_pt, "hammer", "", -1.0, 1 if is_red else 0)
                else:
                    var has_elem_crater: bool = area_weapon == "hammer" and (Rules.host_is_fire_enchanted(active_links, "hammer") or Rules.host_is_rune_enchanted(active_links, "hammer"))
                    # Enchanted hammer uses its own elemental burst (skip beige ring/quake!); secondary shockwave uses ring.
                    var area_burst: String = "" if has_elem_crater else ("quake" if is_primary else "ring")
                    damage_area(command["position"], command["radius"] * stats["area_multiplier"], command["damage"], area_weapon, true, Color("#e8c783"), area_burst)
                    audio.play("stone_hit", 0.0, 0.72)
                    flash_weapon(command.get("weapon_id", "hammer"))
                    if area_weapon == "hammer" and is_primary:
                        apply_weapon_link_hit(command["position"], "hammer")
            "beam":
                effects.lightning(command["start"],command["end"],command["color"])
                audio.play("magic_hit", -2.0, 1.08)
                flash_weapon("totem")
                if has_link_kind("thunder_crystal") and armory.states.has("crystal"):
                    for mine in armory.states.crystal.mines:
                        if Vector2(mine.position).distance_to(command["end"])<=120.0:
                            mine["charged"]=true
            "fan_fire":
                effects.burst(command.position, BattleVisuals.fire_tint(int(options["firepot_tier"])), command.radius * 0.85, "fire_blast")
            "sky_lightning":
                var is_red_sky: bool = bool(command.get("red", false))
                var bolt_color: Color = command.get("color", Color("#ff3a2e") if is_red_sky else BattleVisuals.thunder_tint(2))
                effects.sky_lightning(command["start"], command["end"], bolt_color, true, 1.25 if is_red_sky else 1.0, is_red_sky)
                trigger_lava_lightning_splash(command["end"], 1.05)
                damage_area(command["position"], float(command["radius"]) * stats["area_multiplier"], float(command["damage"]), "totem", true, bolt_color, "thunder_blast", 1 if is_red_sky else 0)
                audio.play("magic_hit", 0.0, 0.66 if is_red_sky else 0.72)
                flash_weapon("totem")
            "fire_pillar":
                var pillar_tier: int = int(command.get("tier", 2))
                var pillar_color: Color = BattleVisuals.fire_tint(pillar_tier)
                damage_area(command["position"], float(command["radius"]) * stats["area_multiplier"], float(command["damage"]), "firepot", true, pillar_color, "fire_blast")
                burning_fields.append({"position": command["position"], "age": 0.0, "life": 1.15, "tick": 0.18, "radius": float(command["radius"]) * stats["area_multiplier"], "damage": float(command["damage"]) * 0.28 * Rules.BURN_TICK_SCALE, "weapon_id": "firepot", "from_link": false, "residual": "fire", "heavy": true, "crater": false})
                audio.play("powder", -1.0, 0.82)
                flash_weapon("firepot")
    refresh_weapon_enchant_tint()

func update_rune_nova(delta: float, allow_attacks: bool) -> void:
    if not weapon_runtime.has("staff"):
        return
    var runtime: Dictionary = weapon_runtime["staff"]
    var haste: float = maxf(0.0, float(stats.get("attack_speed", 1.0)))
    runtime["nova_cooldown"] = maxf(0.0, float(runtime.get("nova_cooldown", 0.0)) - delta * haste)
    if not allow_attacks or is_weapon_suppressed("staff"):
        return
    var level: int = weapon_level("staff")
    var profile: Dictionary = Evolution.rune_nova_profile(level)
    if not bool(profile.get("unlocked", false)) or runtime["nova_cooldown"] > 0.0:
        return
    var radius: float = float(profile["radius"]) * float(stats.get("area_multiplier", 1.0))
    var any := false
    for enemy in combat_targets():
        if float(enemy.get("hp", 0.0)) <= 0.0:
            continue
        if player_position.distance_to(enemy["position"]) <= radius + float(enemy.get("radius", 0.0)):
            any = true
            break
    if not any:
        return
    var damage: float = Catalog.WEAPONS["staff"]["damage"] * Evolution.damage_multiplier("staff", level) * float(profile["damage_multiplier"])
    var tint: Color = BattleVisuals.staff_tint(Evolution.tier(level))
    damage_area(player_position, radius, damage, "staff", true, tint, "ring")
    effects.burst(player_position, tint, radius * 0.85, "ring")
    audio.play("magic", -1.0, 0.85)
    flash_weapon("staff")
    runtime["nova_cooldown"] = float(profile["cooldown"])

func update_weapons(delta: float,allow_attacks: bool=true) -> void:
    advance_formation(delta)
    update_rune_nova(delta, allow_attacks)
    var mounts: Dictionary = current_weapon_mounts()
    var targets: Array=combat_targets() if allow_attacks else []
    var melee_items: Array = []
    var ranged_items: Array = []
    var chain_recipe: Dictionary = current_chain_link()
    var chain_key: String = str(chain_recipe["weapons"][1]) if not chain_recipe.is_empty() and chain_recipe.get("weapons", []).size() > 1 else ""
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
            var tail_arc: float = -data["orbit_speed"] * (0.085 if key == "blade" else (0.065 if key == "axe" else 0.05))
            var tail: Vector2 = player_position + (point - player_position).rotated(tail_arc)
            var trail_tier: int = Evolution.tier(int(item["level"]))
            var trail_enchant: String = ""
            var trail_enchant_tier: int = 0
            if Rules.host_is_fire_enchanted(active_links, key):
                trail_enchant = "fire"
                trail_enchant_tier = Evolution.tier(weapon_level("firepot"))
            elif Rules.host_is_rune_enchanted(active_links, key):
                trail_enchant = "rune"
                trail_enchant_tier = Evolution.tier(weapon_level("staff"))
            elif Rules.host_is_thunder_enchanted(active_links, key):
                trail_enchant = "thunder"
                trail_enchant_tier = Evolution.tier(weapon_level("totem"))
            effects.swing_trail(tail, point, player_position, key, trail_tier, trail_enchant, trail_enchant_tier)
            runtime["trail_next"] = elapsed + 0.035
        var orbit_reach: float = Rules.orbit_radius_for(key, collapsed) + 13.0
        var seg_min_x: float = minf(previous.x, point.x) - 13.0
        var seg_max_x: float = maxf(previous.x, point.x) + 13.0
        var seg_min_y: float = minf(previous.y, point.y) - 13.0
        var seg_max_y: float = maxf(previous.y, point.y) + 13.0
        var near_checked: bool = false
        var near_has_monster: bool = false
        var near_has_egg: bool = false
        var hit_times: Dictionary = runtime["hit_times"]
        for enemy in targets:
            if enemy["hp"] <= 0.0:
                continue
            var epos: Vector2 = enemy["position"]
            var eradius: float = float(enemy["radius"])
            if epos.x + eradius < seg_min_x or epos.x - eradius > seg_max_x or epos.y + eradius < seg_min_y or epos.y - eradius > seg_max_y:
                continue
            if float(hit_times.get(enemy["id"], -INF)) > elapsed:
                continue
            var closest: Vector2 = Geometry2D.get_closest_point_to_segment(epos, previous, point)
            var hit_dist: float = eradius + 13.0
            if closest.distance_squared_to(epos) > hit_dist * hit_dist:
                continue
            var is_egg_target: bool = Rules.is_egg(enemy)
            var is_stone_target: bool = Rules.is_stone(enemy)
            if is_egg_target or is_stone_target:
                if not near_checked:
                    near_checked = true
                    for candidate in targets:
                        if float(candidate.get("hp", 0.0)) <= 0.0:
                            continue
                        var reach: float = orbit_reach + float(candidate.get("radius", 0.0))
                        if player_position.distance_squared_to(candidate["position"]) <= reach * reach:
                            if Rules.is_living_monster(candidate):
                                near_has_monster = true
                                break
                            elif Rules.is_egg(candidate):
                                near_has_egg = true
                if (is_egg_target and near_has_monster) or (is_stone_target and (near_has_monster or near_has_egg)):
                    continue
            var melee_damage: float = data["damage"] * Evolution.damage_multiplier(key, int(item["level"])) * enchant_damage_multiplier(key)
            hit_times[enemy["id"]] = elapsed + data["cooldown"] * weapon_reload_penalty(key) / Rules.effective_attack_speed(key, stats["attack_speed"])
            hurt_enemy(enemy, melee_damage, key, false, (epos - player_position).normalized())
            apply_weapon_link_hit(epos, key, str(enemy.get("id", "")), melee_damage)
            hero.recoil((point - player_position).normalized())
            audio.play("swing", -3.0 if key == "blade" else -1.0, 1.28 if key == "blade" else 0.88)
            flash_weapon(key)
    for item in ranged_items:
        var key: String = item["id"]
        var runtime: Dictionary = weapon_runtime[key]
        var data: Dictionary = Catalog.WEAPONS[key]
        var point: Vector2 = mounts.get(key, player_position + Rules.ranged_mount(key))
        runtime["position"] = point
        runtime["cooldown"] -= delta * Rules.effective_attack_speed(key, stats["attack_speed"])
        runtime["recoil"] = maxf(0.0, runtime["recoil"] - delta)
        var attack_range: float = Rules.scaled_range(data, stats)
        if key == "staff":
            attack_range = (365.0 if collapsed else 265.0) * float(stats.get("range_multiplier", 1.0))
        if key == "powder":
            attack_range = float(Rules.powder_attack_range(active_links)) * float(stats.get("range_multiplier", 1.0))
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
        view.modulate = Color(0.86, 0.98, 0.86) if is_weapon_suppressed(key) else Color.WHITE
        if is_weapon_suppressed(key) or target.is_empty() or runtime["cooldown"] > 0.0:
            continue
        if key == "powder" and not chain_recipe.is_empty():
            var linked: String = chain_key
            if weapon_runtime[linked]["chain_state"] != "rest" or not pending_link.is_empty():
                continue
            launch_chain(linked, target["position"])
        else:
            var damage: float = data["damage"] * Evolution.damage_multiplier(key, int(item["level"])) * enchant_damage_multiplier(key)
            # Shells always leave the visual muzzle, and while a target is
            # tracked the barrel is posed along the shot (see above), so the
            # shell's origin and heading both sit on the barrel line.
            if key == "staff":
                var count: int=Evolution.shot_count(key,item.level)
                var staff_bonus: Dictionary = Catalog.exclusive_bonus(character_id, key)
                var shot_damage: float = damage*(1.0 if count==3 else 0.85)
                if not staff_bonus.is_empty():
                    count = maxi(count, int(staff_bonus.get("shot_count", count)))
                    shot_damage = damage * float(staff_bonus.get("damage_multiplier", 1.25))
                for index in range(count):
                    var offset: float=index-(count-1)*0.5
                    var shot_aim: Vector2 = direction.rotated(offset * (0.055 if collapsed else 0.24))
                    fire_projectile(muzzle, shot_aim, key, shot_damage, attack_range, false, false, float(staff_bonus.get("homing", 0.0)))
                audio.play("magic", -2.0, 1.0)
                flash_weapon(key)
            else:
                var count: int=Evolution.shot_count(key,item.level) if key=="sling" else 1
                for index in range(count):
                    var offset: float=(index-(count-1)*0.5)*0.13
                    var shot_aim: Vector2 = direction.rotated(offset)
                    var enchanted_shot: bool = Rules.host_is_rune_enchanted(active_links, key)
                    fire_projectile(muzzle, shot_aim, key, damage*(1.0 if count==1 else (0.70 if count==2 else 0.61)), attack_range, false, enchanted_shot)
                    if not projectiles.is_empty() and Rules.host_is_fire_enchanted(active_links, key):
                        projectiles.back()["fire_enchanted"] = true
                audio.play("powder" if key == "powder" else "sling", 0.0 if key == "powder" else -2.0, 0.86 if key == "powder" else 1.0)
                flash_weapon(key)
                if key == "powder" and Rules.host_is_rune_enchanted(active_links, "powder"):
                    effects.rune_ignition(mounts.get("staff", player_position + Rules.ranged_mount("staff")), muzzle, Evolution.tier(weapon_level("staff")))
                    audio.play("magic", -2.0)
        var penalty: float = weapon_reload_penalty(key)
        runtime["cooldown"] = data["cooldown"] * penalty / (1.0 + (item["level"] - 1) * 0.12)
        runtime["recoil"] = 0.12
        hero.recoil(direction)
    if chain_key != "" and weapon_runtime.has(chain_key) and str(weapon_runtime[chain_key].get("chain_state", "rest")) == "rest":
        attach_chain_weapon(chain_key)
    refresh_weapon_draw_order()
    refresh_weapon_enchant_tint()


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
    refresh_weapon_enchant_tint()
    for key in weapon_views.keys():
        var view: Sprite2D = weapon_views[key]
        if not is_instance_valid(view):
            continue
        if not view.has_meta("base_scale"):
            view.set_meta("base_scale", view.scale)
        var glow: float = 0.0
        var charge_scale: float = 0.0
        if weapon_runtime.has(key):
            weapon_runtime[key]["glow"] = maxf(0.0, float(weapon_runtime[key].get("glow", 0.0)) - delta)
            glow = float(weapon_runtime[key]["glow"])
            if not is_weapon_suppressed(key) and key in ["powder", "sling", "staff"] and not enemies.is_empty():
                var cd_left: float = float(weapon_runtime[key].get("cooldown", 1.0))
                var win: float = 0.44 if key == "powder" else (0.30 if key == "staff" else 0.22)
                if cd_left > 0.0 and cd_left < win:
                    charge_scale = (1.0 - cd_left / win) * (0.09 if key == "powder" else 0.05)
        var t: float = clampf(glow / 0.2, 0.0, 1.0)
        var color: Color = _weapon_charge_color(key)
        var lit: Color = Color(minf(1.0, color.r * 1.45 + 0.28), minf(1.0, color.g * 1.3 + 0.22), minf(1.0, color.b * 1.15 + 0.18), 1.0)
        var suppressed: bool = is_weapon_suppressed(key)
        var rest: Color = Color(0.86, 0.98, 0.86) if suppressed else Color.WHITE
        view.modulate = rest.lerp(lit, t)
        view.scale = view.get_meta("base_scale") * (1.0 + 0.10 * t + charge_scale)

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
    runtime["chain_damage"] = Catalog.WEAPONS[key]["damage"] * Evolution.damage_multiplier(key, weapon_level(key)) + 1.6 * Evolution.damage_multiplier("powder", weapon_level("powder"))
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
    var chain_recipe: Dictionary = current_chain_link()
    var chain_range: float = float(chain_recipe.get("range", 210.0))
    var priority_targets: Array = chain_targets.filter(func(candidate):
        var reach: float = chain_range + float(candidate.get("radius", 0.0)) + 12.0
        return not runtime["chain_hit_ids"].has(candidate["id"]) and chain_anchor().distance_squared_to(candidate["position"]) <= reach * reach)
    for enemy in chain_targets:
        if enemy["hp"] <= 0.0 or runtime["chain_hit_ids"].has(enemy["id"]):
            continue
        if Rules.should_defer_target(enemy, priority_targets):
            continue
        if Geometry2D.get_closest_point_to_segment(enemy["position"], previous, point).distance_to(enemy["position"]) <= enemy["radius"] + 12.0:
            runtime["chain_hit_ids"].append(enemy["id"])
            var chain_damage: float = runtime["chain_damage"] * (0.6 if returning else 1.0)
            hurt_enemy(enemy, chain_damage, key, true, (point - previous).normalized())
            apply_weapon_link_hit(enemy["position"], key, str(enemy.get("id", "")), chain_damage)
            if not _host_is_enchanted(key):
                effects.burst(point, Color("#e2ceb0"), 17)
            hit_target = true
    if not returning and (hit_target or runtime["chain_distance"] >= chain_range):
        runtime["chain_state"] = "back"
        runtime["chain_hit_ids"] = []
        audio.play("chain_in", -1.0)
    elif returning and point.distance_to(chain_anchor()) < 7.0:
        runtime["chain_state"] = "rest"
        runtime["chain_position"] = chain_anchor()
        runtime["chain_hit_ids"] = []
        view.position = chain_anchor()
        weapon_runtime["powder"]["cooldown"] = maxf(0.35, weapon_runtime["powder"]["cooldown"])
        if not pending_link.is_empty() or not pending_link_ids.is_empty():
            var desired: Array = pending_link_ids.duplicate()
            if desired.is_empty() and pending_link != "none":
                desired = [pending_link]
            apply_links(desired)

func projectile_vfx_tier(key: String, enchanted: bool = false) -> int:
    if enchanted or Rules.host_is_rune_enchanted(active_links, key):
        return Evolution.tier(weapon_level("staff"))
    return Evolution.tier(weapon_level(key))

func projectile_fire_tier(key: String) -> int:
    if Rules.host_is_fire_enchanted(active_links, key):
        return Evolution.tier(weapon_level("firepot"))
    return 0

func projectile_thunder_tier(key: String) -> int:
    if Rules.host_is_thunder_enchanted(active_links, key):
        return Evolution.tier(weapon_level("totem"))
    return 0

func refresh_weapon_enchant_tint() -> void:
    for key in weapon_views.keys():
        var view: Sprite2D = weapon_views[key]
        if view == null or not is_instance_valid(view):
            continue
        if is_weapon_suppressed(key):
            view.modulate = Color(0.86, 0.98, 0.86)
            continue
        if Rules.host_is_fire_enchanted(active_links, key):
            view.modulate = BattleVisuals.weapon_enchant_modulate("fire", Evolution.tier(weapon_level("firepot")))
        elif key == "staff" or Rules.host_is_rune_enchanted(active_links, key):
            var rune_tier: int = Evolution.tier(weapon_level("staff"))
            if key == "staff" and rune_tier <= 0 and not Rules.host_is_rune_enchanted(active_links, key):
                view.modulate = Color.WHITE
            else:
                view.modulate = BattleVisuals.weapon_enchant_modulate("rune", rune_tier) if rune_tier >= 1 or Rules.host_is_rune_enchanted(active_links, key) else Color.WHITE
        elif key == "totem" or Rules.host_is_thunder_enchanted(active_links, key):
            var thunder_tier: int = Evolution.tier(weapon_level("totem"))
            if Rules.host_is_thunder_enchanted(active_links, key) or (key == "totem" and thunder_tier >= 1):
                view.modulate = BattleVisuals.weapon_enchant_modulate("thunder", thunder_tier)
            else:
                view.modulate = Color.WHITE
        else:
            view.modulate = Color.WHITE

func fire_projectile(point: Vector2, direction: Vector2, key: String, damage: float, attack_range: float, from_combo: bool = false, enchanted: bool = false, homing: float = 0.0) -> void:
    var speed: float = Catalog.WEAPONS[key]["speed"] * stats["bullet_speed"]
    var aim: Vector2 = direction.normalized() if direction.length() > 0.001 else Vector2.RIGHT
    var vfx_tier: int = projectile_vfx_tier(key, enchanted)
    var fire_tier: int = projectile_fire_tier(key)
    var thunder_tier: int = projectile_thunder_tier(key)
    var is_fire_ench: bool = fire_tier > 0 or Rules.host_is_fire_enchanted(active_links, key)
    var is_thunder_ench: bool = thunder_tier > 0 or Rules.host_is_thunder_enchanted(active_links, key)
    var is_thunder_red: bool = false
    if is_thunder_ench:
        if not from_combo:
            is_thunder_red = _consume_thunder_red(key)
        else:
            is_thunder_red = rng.randf() < Rules.red_lightning_chance(weapon_level("totem"))
    projectiles.append({"position": point, "velocity": aim * speed, "damage": damage, "kind": key, "weapon_id": key, "life": attack_range / speed, "radius": (9.0 if key == "powder" else 5.5) + stats["hit_radius"], "from_combo": from_combo, "enchanted": enchanted, "hit_ids": [], "pierce_left": 0 if key == "powder" else stats["pierce"], "bounces_left": 0 if key == "powder" else stats["ricochet"], "homing": homing, "vfx_tier": vfx_tier, "fire_tier": fire_tier, "thunder_tier": thunder_tier, "fire_enchanted": is_fire_ench, "thunder_enchanted": is_thunder_ench, "thunder_red": is_thunder_red})
    if projectiles.size() > 48:
        for evict_i in range(projectiles.size() - 1):
            if str(projectiles[evict_i].get("kind", "")) != "hostile":
                projectiles.remove_at(evict_i)
                break
    if not from_combo and weapon_level(key)>=5:
        if key=="sling": projectiles.back().bounces_left+=1
        if key=="staff": projectiles.back().pierce_left+=1
    effects.muzzle(point,aim,key,enchanted,vfx_tier,fire_tier,thunder_tier,is_fire_ench,is_thunder_ench,is_thunder_red)

func _find_nearest_unhit_target(origin: Vector2, max_range: float, targets: Array, hit_ids: Array) -> Dictionary:
    var max_sq: float = max_range * max_range
    var best_tier: int = -1
    var best_elite: bool = false
    var best_sq: float = INF
    var best: Dictionary = {}
    var has_hits: bool = not hit_ids.is_empty()
    for enemy in targets:
        if float(enemy.get("hp", 0.0)) <= 0.0:
            continue
        if has_hits and hit_ids.has(enemy["id"]):
            continue
        var d_sq: float = origin.distance_squared_to(enemy["position"])
        if d_sq > max_sq:
            continue
        var tier: int = 3 if str(enemy.get("kind", "")) == "boss" else (2 if Rules.is_living_monster(enemy) else (1 if Rules.is_egg(enemy) else 0))
        if tier < best_tier:
            continue
        var is_elite: bool = prefer_elite and bool(enemy.get("elite", false))
        if tier > best_tier or (is_elite and not best_elite) or (is_elite == best_elite and d_sq < best_sq):
            best_tier = tier
            best_elite = is_elite
            best_sq = d_sq
            best = enemy
    return best

func update_projectiles(delta: float) -> void:
    var remaining: Array = []
    var targets: Array = combat_targets()
    var proj_count: int = projectiles.size()
    var allow_trails: bool = current_vfx_mode() == "full" and enemies.size() <= 40
    var trail_interval: float = 0.045 if proj_count <= 16 else (0.095 if proj_count <= 32 else 0.16)
    for projectile in projectiles:
        var hit_ids: Array = projectile.get("hit_ids", [])
        var is_hostile: bool = projectile["kind"] == "hostile"
        var homing: float = float(stats.get("homing", 0.0)) + float(projectile.get("homing", 0.0))
        if not is_hostile and homing > 0.0:
            var target: Dictionary = _find_nearest_unhit_target(projectile["position"], 220.0, targets, hit_ids)
            if not target.is_empty():
                var speed: float = projectile["velocity"].length()
                var desired: Vector2 = (target["position"] - projectile["position"]).normalized()
                projectile["velocity"] = projectile["velocity"].normalized().lerp(desired, clampf(delta * homing, 0.0, 1.0)).normalized() * speed
        var previous: Vector2 = projectile["position"]
        var life_before: float = float(projectile["life"])
        var next_pos: Vector2 = previous + projectile["velocity"] * delta
        projectile["position"] = next_pos
        projectile["life"] = life_before - delta
        if allow_trails and projectile["kind"] in ["staff", "powder", "sling"] and absf(next_pos.x - player_position.x) <= 780.0 and absf(next_pos.y - player_position.y) <= 540.0:
            projectile["trail_clock"] = float(projectile.get("trail_clock", 0.0)) - delta
            if projectile["trail_clock"] <= 0.0:
                effects.flight_trail(previous, next_pos, projectile["kind"] == "staff" or projectile.get("enchanted", false), projectile["kind"], int(projectile.get("vfx_tier", 0)), bool(projectile.get("fire_enchanted", false)), int(projectile.get("fire_tier", 0)), bool(projectile.get("thunder_enchanted", false)), int(projectile.get("thunder_tier", 0)), bool(projectile.get("thunder_red", false)))
                projectile["trail_clock"] = trail_interval
        var consumed: bool = false
        var pradius: float = float(projectile["radius"])
        if is_hostile:
            var hr: float = pradius + 19.0
            if Geometry2D.get_closest_point_to_segment(player_position, previous, next_pos).distance_squared_to(player_position) < hr * hr:
                hurt_player(projectile["velocity"].normalized(), projectile["damage"], bool(projectile.get("boss", false)))
                consumed = true
        else:
            var seg_min_x: float = minf(previous.x, next_pos.x) - pradius
            var seg_max_x: float = maxf(previous.x, next_pos.x) + pradius
            var seg_min_y: float = minf(previous.y, next_pos.y) - pradius
            var seg_max_y: float = maxf(previous.y, next_pos.y) + pradius
            var priority_checked: bool = false
            var has_priority_monster: bool = false
            var has_priority_egg: bool = false
            for enemy in targets:
                if enemy["hp"] <= 0.0:
                    continue
                var epos: Vector2 = enemy["position"]
                var eradius: float = float(enemy["radius"])
                if epos.x + eradius < seg_min_x or epos.x - eradius > seg_max_x or epos.y + eradius < seg_min_y or epos.y - eradius > seg_max_y:
                    continue
                if not hit_ids.is_empty() and hit_ids.has(enemy["id"]):
                    continue
                var hit_dist: float = eradius + pradius
                if Geometry2D.get_closest_point_to_segment(epos, previous, next_pos).distance_squared_to(epos) > hit_dist * hit_dist:
                    continue
                var is_egg_target: bool = Rules.is_egg(enemy)
                var is_stone_target: bool = Rules.is_stone(enemy)
                if is_egg_target or is_stone_target:
                    if not priority_checked:
                        priority_checked = true
                        var remaining_reach: float = projectile["velocity"].length() * maxf(0.0, life_before) + pradius
                        for candidate in targets:
                            if float(candidate.get("hp", 0.0)) <= 0.0:
                                continue
                            if not hit_ids.is_empty() and hit_ids.has(candidate["id"]):
                                continue
                            var reach: float = remaining_reach + float(candidate.get("radius", 0.0))
                            if previous.distance_squared_to(candidate["position"]) <= reach * reach:
                                if Rules.is_living_monster(candidate):
                                    has_priority_monster = true
                                    break
                                elif Rules.is_egg(candidate):
                                    has_priority_egg = true
                    if (is_egg_target and has_priority_monster) or (is_stone_target and (has_priority_monster or has_priority_egg)):
                        continue
                if projectile["kind"] == "powder":
                    explode_powder(projectile)
                else:
                    if not projectile.has("hit_ids"):
                        projectile["hit_ids"] = []
                        hit_ids = projectile["hit_ids"]
                    hit_ids.append(enemy["id"])
                    var proj_force_red: int = (1 if bool(projectile.get("thunder_red", false)) else 0) if bool(projectile.get("thunder_enchanted", false)) else -1
                    hurt_enemy(enemy, projectile["damage"], projectile["weapon_id"], projectile["from_combo"], projectile["velocity"].normalized(), proj_force_red)
                    if not projectile.get("from_combo", false):
                        apply_weapon_link_hit(epos, str(projectile.get("weapon_id", projectile["kind"])), str(enemy.get("id", "")), float(projectile.get("damage", 0.0)), proj_force_red)
                    if projectile["kind"] == "staff":
                        audio.play("magic_hit", -5.0)
                    if int(projectile.get("bounces_left", 0)) > 0:
                        var next_target: Dictionary = _find_nearest_unhit_target(epos, 230.0, targets, hit_ids)
                        if not next_target.is_empty():
                            projectile["bounces_left"] -= 1
                            projectile["damage"] = float(projectile["damage"]) * Rules.SECONDARY_HIT_DECAY
                            projectile["velocity"] = (next_target["position"] - projectile["position"]).normalized() * projectile["velocity"].length()
                            projectile["life"] = maxf(projectile["life"], 0.55)
                            if allow_trails and proj_count <= 30:
                                effects.flight_trail(epos, epos + projectile["velocity"].normalized() * 34.0, projectile["kind"] == "staff" or bool(projectile.get("enchanted", false)), projectile["kind"], int(projectile.get("vfx_tier", 0)), bool(projectile.get("fire_enchanted", false)), int(projectile.get("fire_tier", 0)), bool(projectile.get("thunder_enchanted", false)), int(projectile.get("thunder_tier", 0)), bool(projectile.get("thunder_red", false)))
                            break
                    if int(projectile.get("pierce_left", 0)) > 0:
                        projectile["pierce_left"] -= 1
                        projectile["damage"] = float(projectile["damage"]) * Rules.SECONDARY_HIT_DECAY
                        if allow_trails and proj_count <= 26:
                            effects.pierce_cue(epos, projectile["velocity"].normalized())
                        continue
                consumed = true
                break
        if not consumed and projectile["life"] <= 0.0 and projectile["kind"] == "powder":
            explode_powder(projectile)
        if not consumed and projectile["life"] > 0.0:
            remaining.append(projectile)
    projectiles = remaining


func _host_is_enchanted(weapon_id: String) -> bool:
    return Rules.host_is_rune_enchanted(active_links, weapon_id) or Rules.host_is_fire_enchanted(active_links, weapon_id) or Rules.host_is_thunder_enchanted(active_links, weapon_id)

func apply_weapon_link_hit(point: Vector2, weapon_id: String, except_id: String = "", source_damage: float = -1.0, force_red: int = -1) -> void:
    if weapon_id.is_empty():
        return
    var kinds: Array = Rules.host_enchant_kinds(active_links, weapon_id)
    if kinds.has("fire_enchant"):
        _spawn_attachment_fire(point, weapon_id)
    if kinds.has("rune_enchant") or kinds.has("rune"):
        _apply_rune_burst(point, weapon_id == "hammer")
    if kinds.has("thunder_enchant"):
        _apply_thunder_jump(point, except_id, source_damage, 3 if weapon_id == "hammer" else 1, force_red)

func _spawn_attachment_fire(point: Vector2, host_id: String) -> void:
    for field in burning_fields:
        if bool(field.get("from_link", false)) and float(field.get("age", 1.0)) <= 0.04 and Vector2(field.get("position", point)).distance_squared_to(point) <= 36.0:
            return
    var pot_bonus: Dictionary = Catalog.exclusive_bonus(character_id, "firepot")
    var fire_lvl: int = weapon_level("firepot")
    var is_heavy: bool = host_id in ["hammer", "powder", "firepot"]
    var is_crater: bool = host_id == "hammer"
    var base_r: float = 80.0 if host_id == "hammer" else (58.0 if host_id == "powder" else 24.0)
    var base_life: float = 1.45 if host_id == "hammer" else (0.95 if host_id == "powder" else 0.58)
    var base_dmg_mult: float = 1.35 if host_id == "hammer" else 1.0
    var radius: float = minf(base_r * float(stats.get("area_multiplier", 1.0)) * float(pot_bonus.get("area_multiplier", 1.0)), 138.0)
    var life: float = base_life * float(pot_bonus.get("life_multiplier", 1.0))
    var damage: float = 1.65 * base_dmg_mult * Evolution.damage_multiplier("firepot", fire_lvl) * float(pot_bonus.get("damage_multiplier", 1.0)) * Rules.BURN_TICK_SCALE
    burning_fields.append({"position": point, "age": 0.0, "life": life, "tick": 0.35, "radius": radius, "damage": damage, "weapon_id": "firepot", "from_link": true, "residual": "fire", "heavy": is_heavy, "crater": is_crater, "green_fire": Evolution.tier(fire_lvl) >= 2})
    if burning_fields.size() > 6:
        burning_fields.pop_front()
    if is_heavy:
        effects.burst(point, BattleVisuals.fire_tint(Evolution.tier(fire_lvl)), radius * 0.62, "fire_blast")
    else:
        effects.burst(point, BattleVisuals.fire_tint(Evolution.tier(fire_lvl)), 26.0, "fire_splash")

func _apply_rune_burst(point: Vector2, heavy: bool = false) -> void:
    var staff_bonus: Dictionary = Catalog.exclusive_bonus(character_id, "staff")
    var staff_lvl: int = weapon_level("staff")
    var purple_mult: float = 1.25 if Evolution.tier(staff_lvl) >= 2 else 1.0
    var damage: float = 2.2 * (1.6 if heavy else 1.0) * Evolution.damage_multiplier("staff", staff_lvl) * purple_mult * float(staff_bonus.get("damage_multiplier", 1.0))
    var radius: float = (72.0 if heavy else 34.0) * float(stats.get("area_multiplier", 1.0))
    var burst_color: Color = BattleVisuals.staff_tint(Evolution.tier(staff_lvl))
    var burst_kind: String = "rune_blast" if heavy else "rune_spark"
    damage_area(point, radius, damage, "staff", true, burst_color, burst_kind)
    if heavy:
        var rune_damage: float = 1.85 * Evolution.damage_multiplier("staff", staff_lvl) * float(staff_bonus.get("damage_multiplier", 1.0)) * Rules.BURN_TICK_SCALE
        burning_fields.append({"position": point, "age": 0.0, "life": 1.35, "tick": 0.35, "radius": minf(radius * 0.96, 138.0), "damage": rune_damage, "weapon_id": "staff", "from_link": true, "residual": "rune", "heavy": true, "crater": true})
        if burning_fields.size() > 6:
            burning_fields.pop_front()

func _apply_thunder_jump(point: Vector2, except_id: String = "", source_damage: float = -1.0, max_bolts: int = 1, force_red: int = -1) -> void:
    var used_ids: Array = []
    if not except_id.is_empty():
        used_ids.append(except_id)
    var totem_lvl: int = weapon_level("totem")
    var totem_bonus: Dictionary = Catalog.exclusive_bonus(character_id, "totem")
    var is_red: bool = (force_red == 1) if force_red >= 0 else (rng.randf() < Rules.red_lightning_chance(totem_lvl))
    var red_mult: float = Rules.red_lightning_multiplier(totem_lvl) if is_red else 1.0
    var damage: float = source_damage * 0.58 if source_damage > 0.0 else Catalog.WEAPONS["totem"]["damage"] * Evolution.damage_multiplier("totem", totem_lvl) * 0.58
    damage *= float(totem_bonus.get("damage_multiplier", 1.0)) * red_mult
    var reach: float = 190.0 if max_bolts > 1 else 130.0
    var reach_sq: float = reach * reach
    for _bolt in range(max_bolts):
        var neighbor: Dictionary = {}
        var best_is_boss: bool = false
        var best_sq: float = INF
        for enemy in enemies:
            if not Rules.is_living_monster(enemy):
                continue
            var eid: String = str(enemy.get("id", ""))
            if used_ids.has(eid):
                continue
            var d_sq: float = point.distance_squared_to(enemy["position"])
            if d_sq <= reach_sq:
                var is_boss: bool = str(enemy.get("kind", "")) == "boss"
                if (is_boss and not best_is_boss) or (is_boss == best_is_boss and d_sq < best_sq):
                    best_is_boss = is_boss
                    best_sq = d_sq
                    neighbor = enemy
        if neighbor.is_empty():
            break
        used_ids.append(str(neighbor.get("id", "")))
        effects.beam(point, neighbor["position"], Color("#ff3a2e") if is_red else Color("#eef6ff"))
        if elapsed >= float(neighbor.get("_vfx_cd", -1.0)):
            neighbor["_vfx_cd"] = elapsed + 0.16
            effects.shock_wrap(neighbor["position"], float(neighbor.get("radius", 24.0)) + 2.0, Color("#ff3a2e") if is_red else Color("#eef6ff"), is_red)
        hurt_enemy(neighbor, damage, "totem", true, (neighbor["position"] - point).normalized(), 1 if is_red else 0)
        if has_link_kind("thunder_crystal") and armory.states.has("crystal"):
            for mine in armory.states.crystal.mines:
                if Vector2(mine.position).distance_squared_to(neighbor["position"]) <= 14400.0:
                    mine["charged"] = true

func explode_powder(projectile: Dictionary) -> void:
    var enchanted: bool = bool(projectile.get("enchanted", false)) and Rules.host_is_rune_enchanted(active_links, "powder")
    var fire_cannon: bool = Rules.host_is_fire_enchanted(active_links, "powder") or bool(projectile.get("fire_enchanted", false))
    var thunder_cannon: bool = Rules.host_is_thunder_enchanted(active_links, "powder") or bool(projectile.get("thunder_enchanted", false))
    var thunder_is_red: bool = thunder_cannon and bool(projectile.get("thunder_red", false))
    var point: Vector2 = projectile["position"]
    var staff_lvl: int = weapon_level("staff")
    var fire_lvl: int = weapon_level("firepot")
    var burst_kind: String = "rune_blast" if enchanted else ("fire_blast" if fire_cannon else ("thunder_blast" if thunder_cannon else "blast"))
    var burst_color: Color = BattleVisuals.staff_tint(Evolution.tier(staff_lvl)) if enchanted else (BattleVisuals.fire_tint(Evolution.tier(fire_lvl)) if fire_cannon else ((Color("#ff3a2e") if thunder_is_red else Color("#eef6ff")) if thunder_cannon else Color("#ffad40")))
    var dmg_mult: float = (1.30 if Evolution.tier(staff_lvl) >= 2 else 1.15) if enchanted else (Rules.red_lightning_multiplier(weapon_level("totem")) if thunder_is_red else 1.0)
    damage_area(point, (85.0 if enchanted else 63.0) * stats["area_multiplier"], projectile["damage"] * dmg_mult, "powder", true, burst_color, burst_kind, 1 if thunder_is_red else (-1 if not thunder_cannon else 0))
    audio.play("blast", 0.0, 0.88)
    var stage: int=Evolution.tier(weapon_level("powder"))
    if (stage>=1 and not enchanted and not fire_cannon and not thunder_cannon) or fire_cannon:
        var field_damage: float = projectile.damage*0.36*Rules.BURN_TICK_SCALE
        var field_radius: float = 56.0*stats.area_multiplier
        var field_life: float = 0.95
        var residual: String = "fire" if fire_cannon else "smoke"
        if fire_cannon:
            var pot_bonus: Dictionary = Catalog.exclusive_bonus(character_id, "firepot")
            field_damage *= float(pot_bonus.get("damage_multiplier", 1.0))
            field_radius *= float(pot_bonus.get("area_multiplier", 1.0))
            field_life *= float(pot_bonus.get("life_multiplier", 1.0))
        burning_fields.append({"position":point,"age":0.0,"life":field_life,"tick":0.35,"radius":field_radius,"damage":field_damage,"weapon_id":"powder" if not fire_cannon else "firepot","from_link":fire_cannon,"residual":residual,"green_fire":fire_cannon and Evolution.tier(fire_lvl) >= 2})
    elif not enchanted and not fire_cannon and not thunder_cannon:
        burning_fields.append({"position":point,"age":0.0,"life":0.78,"tick":1.0,"radius":48.0*stats.area_multiplier,"damage":0.0,"weapon_id":"powder","from_link":false,"residual":"smoke"})
        effects.puff(point + Vector2(-10, -4), Color("#c2b39c"), 30.0, 0)
        effects.puff(point + Vector2(12, -8), Color("#d6c7ad"), 26.0, 1)
        effects.puff(point + Vector2(0, -14), Color("#e6dbc5"), 22.0, 2)
    if stage>=2:
        for shard in range(4):
            fire_projectile(point,Vector2.from_angle(TAU*shard/4.0),"sling",projectile.damage*0.25,190.0,true,enchanted)
            var sp: Dictionary = projectiles.back()
            sp["weapon_id"] = "powder"
            if fire_cannon:
                sp["fire_enchanted"] = true
                sp["fire_tier"] = Evolution.tier(fire_lvl)
            if thunder_cannon:
                sp["thunder_enchanted"] = true
                sp["thunder_tier"] = Evolution.tier(weapon_level("totem"))
                sp["thunder_red"] = thunder_is_red
    if burning_fields.size() > 6:
        burning_fields.pop_front()
    if enchanted:
        var staff_bonus: Dictionary = Catalog.exclusive_bonus(character_id, "staff")
        var rune_damage: float = 1.75 * Evolution.damage_multiplier("staff", staff_lvl) * float(staff_bonus.get("damage_multiplier", 1.0)) * Rules.BURN_TICK_SCALE
        burning_fields.append({"position": point, "age": 0.0, "life": 1.50, "tick": 0.35, "radius": minf(70.0 * stats["area_multiplier"], 120.0), "damage": rune_damage, "weapon_id": "staff", "from_link": true, "residual": "rune", "heavy": true, "crater": false})
        if burning_fields.size() > 6:
            burning_fields.pop_front()
        audio.play("magic_hit", -5.0)
    if thunder_cannon:
        trigger_lava_lightning_splash(point, 1.0)
        burning_fields.append({"position": point, "age": 0.0, "life": 1.65, "tick": 1.0, "radius": minf(68.0 * stats["area_multiplier"], 112.0), "damage": 0.0, "weapon_id": "totem", "from_link": true, "residual": "thunder_mark", "red": thunder_is_red})
        if burning_fields.size() > 6:
            burning_fields.pop_front()
        _apply_thunder_jump(point, "", float(projectile.get("damage", 0.0)), 1, 1 if thunder_is_red else 0)

func update_burning_fields(delta: float) -> void:
    var remaining: Array = []
    for field in burning_fields:
        field["age"] += delta
        field["tick"] -= delta
        if field["tick"] <= 0.0:
            field["tick"] = 0.42
            var tick_dmg: float = float(field.get("damage", 0.0))
            if tick_dmg > 0.0:
                var fpos: Vector2 = field["position"]
                var frad: float = float(field["radius"])
                var fwid: String = str(field.get("weapon_id", "staff"))
                for enemy in combat_targets():
                    if float(enemy["hp"]) > 0.0:
                        var reach: float = frad + float(enemy["radius"])
                        if Vector2(enemy["position"]).distance_squared_to(fpos) <= reach * reach:
                            hurt_enemy(enemy, tick_dmg, fwid, true, Vector2.ZERO)
        if field["age"] < field["life"]:
            remaining.append(field)
    burning_fields = remaining

func combat_targets() -> Array:
    if _simulating and _combat_targets_ready:
        return _combat_targets_cache
    var cur_biome: String = map_view.biome if map_view != null else ""
    if _stones_dirty or _cached_stone_biome != cur_biome or player_position.distance_squared_to(_cached_stone_pos) > 1024.0:
        _cached_stone_targets = map_view.stone_targets(visible_world_rect().grow(80))
        _cached_stone_pos = player_position
        _cached_stone_biome = cur_biome
        _stones_dirty = false
    _combat_targets_cache = enemies + _cached_stone_targets
    _combat_targets_ready = _simulating
    return _combat_targets_cache

const PICKUP_TOP_HUD_PAD: float = 150.0

func pickup_visible_point(point: Vector2) -> Vector2:
    return point

func reveal_recent_pickups(_start_index: int) -> void:
    pass

func spawn_loot(reward: Dictionary, at: Vector2) -> void:
    LootDrops.append_reward(pickups, reward, at)

func trigger_lava_lightning_splash(strike_pt: Vector2, scale: float = 1.0) -> void:
    if map_view == null or effects == null or not map_view.is_in_lava(strike_pt, 12.0):
        return
    effects.burst(strike_pt, Color("#ff6a22"), 90.0 * scale, "fire_blast")
    effects.burst(strike_pt + Vector2(0.0, -10.0), Color("#ff9836"), 58.0 * scale, "fire_splash")
    effects.puff(strike_pt, Color("#ff7e30"), 26.0 * scale, 0)
    if audio != null:
        audio.play("powder", -2.0, 0.78)

func hurt_stone(target: Dictionary,damage: float) -> void:
    var result: Dictionary=map_view.damage_stone(target,damage*stats.damage_multiplier)
    if not result.hit: return
    _stones_dirty = true
    effects.puff(target.position,Color("#bda78a"),20 if result.destroyed else 12,0)
    audio.play("stone_hit",-8.0,1.2)
    if result.destroyed:
        effects.burst(target.position,Color("#e3c995"),28,"hit")
        spawn_loot(LootRules.rock_reward(rng),target.position)

func hurt_enemy(enemy: Dictionary, damage: float, weapon_id: String, from_combo: bool, direction: Vector2, force_red: int = -1) -> void:
    if enemy.get("stone",false):
        hurt_stone(enemy,damage)
        return
    if enemy["hp"] <= 0.0:
        return
    var smashed_egg: bool = str(enemy.get("state", "")) == "egg"
    var neutral: bool = weapon_id == "terrain_lava"
    if not neutral and BiomeEncounters.blocks(enemy, player_position):
        damage *= 0.40
    var unavoidable: bool = neutral or weapon_id in ["powder","hammer"] or (weapon_id == "staff" and from_combo)
    var evade_chance: float = maxf(0.0, float(enemy.get("dodge", 0.0)) - stats["dodge_ignore"])
    if not unavoidable and evade_chance > 0.0 and rng.randf() < evade_chance:
        effects.floating_text(enemy["position"], "敌闪避", Color("#f4a8d3"), 23)
        return
    var critical: bool = not neutral and (force_red == 1 or rng.randf() < stats["crit_chance"])
    var amount: float = damage if neutral else damage * stats["damage_multiplier"] * (stats["crit_multiplier"] if critical else 1.0)
    var close_r: float = float(stats.get("close_damage_range", 140.0))
    var slammed: bool = not neutral and float(stats.get("close_damage_bonus", 0.0)) > 0.0 and player_position.distance_squared_to(enemy["position"]) <= close_r * close_r
    if slammed:
        amount *= 1.0 + float(stats["close_damage_bonus"])
    if not neutral:
        amount *= Progression.outgoing_damage_scale(wave)
    var min_enemy_hp: float = 1.0 if (training_mode and training_enemy_immortal and not smashed_egg) else 0.0
    enemy["hp"] = maxf(min_enemy_hp, enemy["hp"] - amount)
    var is_thunder_hammer_hit: bool = weapon_id == "hammer" and Rules.host_is_thunder_enchanted(active_links, "hammer")
    var push: float = 95.0 if weapon_id in ["hammer", "club"] else (65.0 if weapon_id == "axe" else (30.0 if weapon_id == "blade" else 16.0))
    if neutral or weapon_id == "staff" or is_thunder_hammer_hit or str(enemy.get("kind", "")) == "boss":
        push = 0.0
    elif bool(enemy.get("cc_once", false)):
        push = 0.0
    elif str(enemy.get("kind", "")) in ["tank", "charger", "cindertusk", "magmashell", "stonehorn"] or bool(enemy.get("elite", false)):
        push *= 0.20
    if push > 0.0:
        enemy["knock"] += direction * push
        enemy["cc_once"] = true
    if not neutral:
        if Rules.host_is_thunder_enchanted(active_links, weapon_id) or (weapon_id == "totem" and weapon_level("totem") >= 3):
            if rng.randf() < 0.35:
                try_apply_ward(enemy, "thunder", enemy["position"] - direction)
    var feedback: bool = not neutral or elapsed >= float(enemy.get("lava_feedback_next",-INF)) or enemy["hp"]<=0
    if neutral: enemy["lava_feedback_sum"] = float(enemy.get("lava_feedback_sum",0.0)) + amount
    if feedback:
        enemy["view"].hit()
        var allow_hit_vfx: bool = elapsed >= float(enemy.get("_vfx_cd", -1.0))
        if allow_hit_vfx:
            enemy["_vfx_cd"] = elapsed + (0.24 if enemies.size() > 26 else 0.18)
            var ench_kinds: Array = [] if neutral else Rules.host_enchant_kinds(active_links, weapon_id)
            if ench_kinds.is_empty():
                if not (from_combo and weapon_id == "staff"):
                    var impact_tier: int = Evolution.tier(weapon_level("staff" if weapon_id in ["staff", "drone"] else weapon_id))
                    effects.impact(enemy["position"], direction, weapon_id, impact_tier)
            else:
                # Enchanted weapons replace (do not stack over) the original unenchanted weapon hit splash.
                if ench_kinds.has("rune_enchant") or ench_kinds.has("rune"):
                    if from_combo and weapon_id != "powder":
                        effects.burst(enemy["position"], BattleVisuals.staff_tint(Evolution.tier(weapon_level("staff"))), 16.0, "rune_spark")
                elif ench_kinds.has("fire_enchant"):
                    if weapon_id not in ["powder", "hammer"]:
                        effects.burst(enemy["position"], BattleVisuals.fire_tint(Evolution.tier(weapon_level("firepot"))), 17.0, "fire_splash")
                elif ench_kinds.has("thunder_enchant"):
                    if weapon_id != "powder":
                        var is_red_hit: bool = (force_red == 1) if force_red >= 0 else (rng.randf() < Rules.red_lightning_chance(weapon_level("totem")))
                        effects.shock_wrap(enemy["position"], float(enemy.get("radius", 24.0)), Color("#ff3a2e") if is_red_hit else BattleVisuals.thunder_tint(Evolution.tier(weapon_level("totem"))), is_red_hit)
        if slammed:
            effects.slam_cue(enemy["position"], direction)
        if bool(settings.get("damage_numbers", true)):
            effects.damage_number(enemy["position"],float(enemy.get("lava_feedback_sum",amount)) if neutral else amount,critical,Color("#ffbc65") if neutral else Color("#fffdf4"))
        if neutral:
            enemy["lava_feedback_sum"] = 0.0
            enemy["lava_feedback_next"] = elapsed+0.35
    enemy["view"].health_fraction = enemy["hp"] / enemy["max_hp"]
    if weapon_id == "club":
        audio.play("wood_hit", 0.0, 0.9)
    elif weapon_id == "axe":
        audio.play("stone_hit", 0.0, 0.96)
    elif weapon_id == "hammer":
        audio.play("stone_hit", 1.0, 0.72)
    elif weapon_id == "blade":
        audio.play("swing", -2.5, 1.35)
    elif weapon_id == "spear":
        audio.play("stone_hit", -1.0, 1.18)
    elif weapon_id == "sling":
        audio.play("sling", -3.0, 1.22)
    elif weapon_id == "boomerang":
        audio.play("swing", -3.0, 1.15)
    if critical:
        audio.play("magic_hit", -5.0, 1.42)
    if enemy["hp"] <= 0.0:
        kills += 1
        var boss: bool = enemy["kind"] == "boss"
        if boss:
            boss_defeated = true
            boss_clear_left = BOSS_CLEAR_SECONDS
        spawn_loot(LootRules.enemy_reward(enemy.kind,wave,enemy.elite,enemy.view.display_width,rng),enemy.position)
        if not boss and not smashed_egg and LootRules.should_drop_blood_pack(str(enemy.kind), bool(enemy.get("elite", false)), rng):
            var blood_index: int = pickups.size()
            LootDrops.append_blood_pack(pickups, enemy.position, LootRules.BLOOD_PACK_HEAL)
            reveal_recent_pickups(blood_index)
        if smashed_egg:
            effects.egg_smash(enemy["position"], enemy["view"].display_width)
        else:
            effects.defeat(enemy["position"], direction, enemy["view"].display_width, enemy["view"].sprite.texture, enemy["view"].body_dimensions)
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
    var evo_enchant: String = ""
    var evo_enchant_tier: int = 0
    var evo_color: Color = Color("#e5c28a") if key == "club" else (Color("#e5b87d") if key == "axe" else Color("#e4d4ad"))
    if Rules.host_is_fire_enchanted(active_links, key):
        evo_enchant = "fire"
        evo_enchant_tier = Evolution.tier(weapon_level("firepot"))
        evo_color = BattleVisuals.fire_tint(evo_enchant_tier)
    elif Rules.host_is_rune_enchanted(active_links, key):
        evo_enchant = "rune"
        evo_enchant_tier = Evolution.tier(weapon_level("staff"))
        evo_color = BattleVisuals.staff_tint(evo_enchant_tier)
    elif Rules.host_is_thunder_enchanted(active_links, key):
        evo_enchant = "thunder"
        evo_enchant_tier = Evolution.tier(weapon_level("totem"))
        evo_color = BattleVisuals.thunder_tint(evo_enchant_tier)
    if key=="club" and count%(2 if stage>=2 else 3)==0:
        damage_area(enemy.position,84.0 if stage>=2 else 64.0,damage*0.45,key,true,evo_color,"ring")
    elif key=="axe" and (enemy.hp<=0 or (stage>=2 and count%3==0)):
        damage_area(enemy.position,96.0 if stage>=2 else 70.0,damage*0.40,key,true,evo_color,"ring" if not evo_enchant.is_empty() else "cleave")
    elif key=="blade" and count%(3 if stage>=2 else 4)==0:
        if stage>=2:
            damage_area(enemy.position,60.0,damage*0.35,key,true,evo_color,"ring" if not evo_enchant.is_empty() else "cleave")
        elif enemy.hp>0:
            hurt_enemy(enemy,damage*0.35,key,true,direction)
        effects.swing_trail(enemy.position-Vector2(18,18),enemy.position+Vector2(18,18),enemy.position,key,stage,evo_enchant,evo_enchant_tier)

func damage_area(point: Vector2, radius: float, damage: float, weapon_id: String, from_combo: bool, color: Color, burst_kind: String = "blast", force_red: int = -1) -> void:
    if not burst_kind.is_empty():
        effects.burst(point, color, radius, burst_kind)
    if audio != null:
        if burst_kind == "rune_blast":
            audio.play("magic_hit", -3.0, 0.95)
        elif burst_kind == "rune_spark":
            audio.play("magic_hit", -7.0, 1.18)
        elif burst_kind == "thunder_blast":
            audio.play("magic_hit", -2.0, 1.28)
        elif burst_kind == "fire_blast":
            audio.play("blast", -2.5, 1.02)
        elif weapon_id == "hammer" or burst_kind == "quake":
            audio.play("blast", -2.0, 0.76)
        elif burst_kind == "cleave":
            audio.play("stone_hit", -1.0, 0.88)
        else:
            audio.play("blast", -2.0, 0.95)
    for enemy in combat_targets():
        if enemy["hp"] > 0.0:
            var reach: float = radius + float(enemy["radius"])
            if enemy["position"].distance_squared_to(point) < reach * reach:
                hurt_enemy(enemy, damage, weapon_id, from_combo, (enemy["position"] - point).normalized(), force_red)



# Environmental DPS is the same for both teams: no armor, random dodge,
# weapon bonuses or criticals. Timed hero immunity still protects a short dodge.
func update_terrain_damage(delta: float, player_exposure: float = -1.0) -> void:
    if delta <= 0.0 or not running or paused or shop_open or upgrade_pending or stats_open or player_frozen or link_notice_open or link_pack_open or wave_closing or departure_left > 0.0 or animation_demo:
        return
    var exposure: float = (delta if invulnerable <= 0.0 else 0.0) if player_exposure < 0.0 else player_exposure
    if training_mode and training_godmode:
        exposure = 0.0
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
    if not running or invulnerable > 0.0 or demo or animation_demo or (training_mode and training_godmode):
        return
    if rng.randf() < stats["dodge"]:
        invulnerable = 0.25
        effects.floating_text(player_position, "闪避", Color("#9ce7f0"), 22)
        return
    var amount: float = damage * (1.0 - stats["reduction"])
    # Cap every combat hit (contact, projectiles, quakes, elites, Boss).
    # Terrain DoT stays on update_terrain_damage and is intentionally uncapped.
    amount = minf(amount, Progression.HIT_CAP_RATIO * float(stats["max_hp"]))
    player_hp = maxf(1.0 if (training_mode and training_godmode) else 0.0, player_hp - amount)
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
    if world_camera != null:
        world_camera.position = player_position
        world_camera.force_update_scroll()
    if map_view != null:
        map_view.set_view(player_position, wave)
    effects.hero_anchor = player_position
    effects._has_hero_anchor = true
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
    if not running and not animation_demo:
        return
    var has_fields: bool = not burning_fields.is_empty()
    if ground_marks_layer != null:
        if (has_fields and _ground_marks_accum >= 0.05) or (not has_fields and _had_burning_fields):
            _ground_marks_accum = 0.0
            ground_marks_layer.queue_redraw()
    _had_burning_fields = has_fields
    if animation_demo:
        draw_string(demo_font, Vector2(64, 67), "原始人 · 动作预览", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#543b2c"))
        draw_string(demo_font, Vector2(360, 185), demo_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#64513a"))
        draw_string(demo_font, Vector2(325, 715), "同一角色的身体、双手、双脚独立运动", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#766449"))
    draw_link_shapes()
    if pickup_renderer != null and (_pickup_sync_accum >= 0.05 or pickups.size() != _last_pickup_count):
        _pickup_sync_accum = 0.0
        _last_pickup_count = pickups.size()
        pickup_renderer.sync(pickups, visible_world_rect().grow(40.0), elapsed)
    for chest in chest_marks:
        chest["age"] = float(chest.get("age", 0.0))
        draw_chest(chest["position"], chest["age"])
    for enemy in enemies:
        if enemy["hp"] <= 0.0:
            continue
        if BiomeEncounters.draw_attack(self, enemy) or EnemyRoster.draw_warning(self,enemy): continue
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
        elif enemy["state"] == "spit":
            draw_arc(enemy["position"] + (player_position - enemy["position"]).normalized() * 28.0, 12.0, 0.0, TAU, 24, Color("#b82f83"), 3.0, true)
    var vfx_full: bool = current_vfx_mode() == "full"
    var draw_proj_count: int = projectiles.size()
    var proj_idx: int = 0
    for projectile in projectiles:
        proj_idx += 1
        var ppos: Vector2 = projectile["position"]
        if absf(ppos.x - player_position.x) > 760.0 or absf(ppos.y - player_position.y) > 520.0:
            continue
        BattleVisuals.draw_projectile(self, projectile, elapsed)
        if not vfx_full or enemies.size() >= 20 or draw_proj_count > 10:
            continue
        var allow_wrap: bool = (proj_idx % 2 == 0)
        if not allow_wrap:
            continue
        if bool(projectile.get("fire_enchanted", false)):
            var vel: Vector2 = projectile.get("velocity", Vector2.RIGHT)
            var aim: Vector2 = vel.normalized() if vel.length_squared() > 0.01 else Vector2.RIGHT
            BattleVisuals.draw_fire_wrap(self, ppos, aim, 22.0, elapsed, int(projectile.get("fire_tier", 0)))
        if bool(projectile.get("thunder_enchanted", false)):
            BattleVisuals.draw_thunder_wrap(self, ppos, 16.0, elapsed, int(projectile.get("thunder_tier", 0)), bool(projectile.get("thunder_red", false)))
    # Clean permanent elemental particles hugging enchanted weapons (ALWAYS visible when VFX is full, never hidden by enemy count!)
    if vfx_full:
        _draw_enchanted_weapon_auras()
    # Sync pre-attack progressive fill charge directly to each weapon sprite's shader
    _sync_weapon_charge_cues()
    # No rotating wrap/aura rings on parked or orbiting weapons.
    # Attack-shot tints and projectile wraps stay on the projectiles themselves.

func _draw_enchanted_weapon_auras() -> void:
    if active_links.is_empty():
        return
    var glow: Texture2D = Effects.soft_glow_texture()
    for item in inventory:
        var key: String = str(item.get("id", ""))
        if not weapon_views.has(key) or not is_instance_valid(weapon_views[key]) or not weapon_views[key].visible:
            continue
        var is_fire: bool = Rules.host_is_fire_enchanted(active_links, key)
        var is_rune: bool = Rules.host_is_rune_enchanted(active_links, key)
        var is_thunder: bool = Rules.host_is_thunder_enchanted(active_links, key)
        if not is_fire and not is_rune and not is_thunder:
            continue
        var pos: Vector2 = weapon_views[key].position
        var r_aura: float = float(Catalog.WEAPONS[key].get("size", 40.0)) * 0.56
        var seed_k: float = float(key.hash() % 97) * 0.13
        if is_fire:
            # 常驻火焰附魔：柔和暖光 + 7 颗错落升腾飘散的炽热火星
            var ft: int = Evolution.tier(weapon_level("firepot"))
            var f_tint: Color = BattleVisuals.fire_tint(ft)
            var f_core: Color = BattleVisuals.fire_core(ft)
            draw_texture_rect(glow, Rect2(pos - Vector2.ONE * (r_aura * 1.15), Vector2.ONE * (r_aura * 2.3)), false, Color(f_tint.r, f_tint.g * 0.65, f_tint.b * 0.25, 0.26))
            for i in range(7):
                var cyc: float = fmod(elapsed * (1.25 + float(i % 3) * 0.22) + float(i) * 0.143 + seed_k, 1.0)
                var drift_x: float = sin(elapsed * 4.4 + float(i) * 2.1 + seed_k) * r_aura * (0.45 + float(i % 2) * 0.28)
                var p: Vector2 = pos + Vector2(drift_x, r_aura * 0.26 - cyc * (r_aura * 1.48))
                var a: float = clampf(cyc / 0.16, 0.0, 1.0) * clampf((1.0 - cyc) / 0.34, 0.0, 1.0)
                draw_circle(p, lerpf(2.8, 0.85, cyc), Color(f_tint.r, f_tint.g, f_tint.b, 0.90 * a))
                draw_circle(p, lerpf(1.4, 0.4, cyc), Color(f_core.r, f_core.g, f_core.b, 0.96 * a))
        elif is_rune:
            # 常驻魔法附魔：柔光 + 8 颗轻盈向上飘升的奥术星尘粒子（夹杂 2 颗微星点缀，1-4级青 / 5级紫）
            var staff_tier: int = Evolution.tier(weapon_level("staff"))
            var r_col: Color = BattleVisuals.staff_tint(staff_tier)
            var r_hi: Color = BattleVisuals.staff_highlight(staff_tier)
            draw_texture_rect(glow, Rect2(pos - Vector2.ONE * (r_aura * 1.20), Vector2.ONE * (r_aura * 2.40)), false, Color(r_col.r, r_col.g, r_col.b, 0.28))
            for i in range(8):
                var cyc: float = fmod(elapsed * (0.95 + float(i % 3) * 0.18) + float(i) * 0.125 + seed_k, 1.0)
                var sway_x: float = sin(elapsed * 3.4 + float(i) * 1.9 + seed_k) * r_aura * (0.48 + float(i % 2) * 0.28)
                var p: Vector2 = pos + Vector2(sway_x, r_aura * 0.28 - cyc * (r_aura * 1.55))
                var a: float = clampf(cyc / 0.18, 0.0, 1.0) * clampf((1.0 - cyc) / 0.36, 0.0, 1.0)
                var pr: float = lerpf(2.5, 0.95, cyc)
                draw_circle(p, pr * 1.8, Color(r_col.r, r_col.g, r_col.b, 0.42 * a))
                if i % 4 == 0:
                    var sz: float = pr * 1.35
                    draw_colored_polygon(PackedVector2Array([
                        p + Vector2(0, -sz), p + Vector2(sz * 0.35, -sz * 0.35),
                        p + Vector2(sz, 0), p + Vector2(sz * 0.35, sz * 0.35),
                        p + Vector2(0, sz), p + Vector2(-sz * 0.35, sz * 0.35),
                        p + Vector2(-sz, 0), p + Vector2(-sz * 0.35, -sz * 0.35)
                    ]), Color(r_hi.r, r_hi.g, r_hi.b, 0.95 * a))
                else:
                    draw_circle(p, pr, Color(r_col.r, r_col.g, r_col.b, 0.88 * a))
                    draw_circle(p, pr * 0.52, Color(r_hi.r, r_hi.g, r_hi.b, 0.96 * a))
        elif is_thunder:
            # 常驻雷电附魔：贴身跳跃的细巧多段电弧 + 微电火花（同步赤雷概率）
            var t_lvl: int = weapon_level("totem")
            var t_tint: Color = BattleVisuals.thunder_tint(Evolution.tier(t_lvl))
            var tick: int = int(floor(elapsed * 16.0))
            var tr := _draw_rng
            tr.seed = key.hash() + tick * 37
            var show_red: bool = _peek_thunder_red(key)
            var glow_c: Color = Color(1.0, 0.24, 0.16, 0.26) if show_red else Color(t_tint.r, t_tint.g, t_tint.b, 0.24)
            var arc_out: Color = Color(1.0, 0.32, 0.22, 0.90) if show_red else Color(0.84, 0.93, 1.0, 0.88)
            var arc_in: Color = Color(1.0, 0.94, 0.88, 0.98) if show_red else Color(1.0, 1.0, 0.99, 0.98)
            draw_texture_rect(glow, Rect2(pos - Vector2.ONE * (r_aura * 1.1), Vector2.ONE * (r_aura * 2.2)), false, glow_c)
            for _i in range(3):
                var a0: float = tr.randf_range(0.0, TAU)
                var a1: float = a0 + tr.randf_range(0.65, 1.35)
                var p0: Vector2 = pos + Vector2.from_angle(a0) * (r_aura * tr.randf_range(0.45, 0.92))
                var p2: Vector2 = pos + Vector2.from_angle(a1) * (r_aura * tr.randf_range(0.50, 0.98))
                var mid: Vector2 = p0.lerp(p2, 0.5) + Vector2(tr.randf_range(-6.0, 6.0), tr.randf_range(-6.0, 6.0))
                var pts := PackedVector2Array([p0, mid, p2])
                draw_polyline(pts, arc_out, 2.2, true)
                draw_polyline(pts, arc_in, 1.0, true)
            for _s in range(2):
                var sp: Vector2 = pos + Vector2.from_angle(tr.randf_range(0.0, TAU)) * (r_aura * tr.randf_range(0.70, 1.05))
                draw_circle(sp, tr.randf_range(1.1, 1.9), arc_in)

func _weapon_elem_style(key: String) -> int:
    if Rules.host_is_fire_enchanted(active_links, key) or key == "firepot":
        return 2
    if Rules.host_is_rune_enchanted(active_links, key) or key == "staff":
        return 1
    if Rules.host_is_thunder_enchanted(active_links, key) or key == "totem":
        return 3
    return 0

func _peek_thunder_red(key: String) -> bool:
    var totem_lvl: int = weapon_level("totem")
    var chance: float = Rules.red_lightning_chance(totem_lvl)
    if chance <= 0.0:
        if weapon_runtime.has(key):
            weapon_runtime[key]["next_thunder_red"] = false
        return false
    if weapon_runtime.has(key):
        if not weapon_runtime[key].has("next_thunder_red"):
            weapon_runtime[key]["next_thunder_red"] = rng.randf() < chance
        return bool(weapon_runtime[key]["next_thunder_red"])
    return false

func _consume_thunder_red(key: String) -> bool:
    var totem_lvl: int = weapon_level("totem")
    var chance: float = Rules.red_lightning_chance(totem_lvl)
    if chance <= 0.0:
        if weapon_runtime.has(key):
            weapon_runtime[key]["next_thunder_red"] = false
        return false
    if weapon_runtime.has(key):
        var current: bool = bool(weapon_runtime[key].get("next_thunder_red", rng.randf() < chance))
        weapon_runtime[key]["next_thunder_red"] = rng.randf() < chance
        return current
    return rng.randf() < chance

func _weapon_charge_color(key: String) -> Color:
    if Rules.host_is_fire_enchanted(active_links, key) or key == "firepot":
        return BattleVisuals.fire_tint(Evolution.tier(weapon_level("firepot")))
    if Rules.host_is_rune_enchanted(active_links, key) or key == "staff":
        return BattleVisuals.staff_tint(Evolution.tier(weapon_level("staff")))
    if Rules.host_is_thunder_enchanted(active_links, key) or key == "totem":
        if _peek_thunder_red(key):
            return Color("#ff3a2e")
        return BattleVisuals.thunder_tint(Evolution.tier(weapon_level("totem")))
    if key == "powder":
        return Color("#ffae42")
    if key == "crystal":
        return Color("#c2a8f0")
    return Color(Catalog.WEAPONS.get(key, {}).get("color", Color("#f2d488")))

func _sync_weapon_charge_cues() -> void:
    var cues: Array = []
    var allow_charge: bool = current_vfx_mode() == "full" and not enemies.is_empty()
    var has_living: bool = false
    if allow_charge:
        for e in enemies:
            if float(e.get("hp", 0.0)) > 0.0:
                has_living = true
                break
    for key in weapon_views.keys():
        var view: Sprite2D = weapon_views[key]
        if view == null or not is_instance_valid(view):
            continue
        var mat: ShaderMaterial = view.material as ShaderMaterial
        if mat == null:
            continue
        if is_weapon_suppressed(key) or not view.visible or current_vfx_mode() != "full":
            mat.set_shader_parameter("charge_progress", 0.0)
            continue
        var charge_t: float = 0.0
        if has_living and key not in ["club", "axe", "blade"]:
            if key in ["powder", "sling", "staff"]:
                if weapon_runtime.has(key):
                    var cd: float = float(weapon_runtime[key].get("cooldown", 1.0))
                    var win: float = 0.62 if key == "powder" else (0.36 if key == "staff" else 0.24)
                    if cd > 0.0 and cd < win:
                        charge_t = clampf(1.0 - cd / win, 0.0, 1.0)
            elif armory != null and armory.states.has(key):
                var st: Dictionary = armory.states[key]
                var phase: String = str(st.get("phase", "rest"))
                if key == "hammer":
                    if phase == "windup":
                        charge_t = clampf(float(st.get("age", 0.0)) / 0.22, 0.28, 1.0)
                    elif phase == "rest":
                        var cd_h: float = float(st.get("cooldown", 1.0))
                        if cd_h > 0.0 and cd_h < 0.45:
                            charge_t = clampf((1.0 - cd_h / 0.45) * 0.72, 0.0, 0.72)
                elif phase == "rest":
                    var cd2: float = float(st.get("cooldown", 1.0))
                    var win2: float = 0.38 if key in ["totem", "firepot", "crystal", "wardrum"] else 0.28
                    if cd2 > 0.0 and cd2 < win2:
                        charge_t = clampf(1.0 - cd2 / win2, 0.0, 1.0)
        var elem_s: int = _weapon_elem_style(key)
        if elem_s == 0:
            mat.set_shader_parameter("charge_progress", 0.0)
            mat.set_shader_parameter("elem_style", 0)
            if key == "powder" and charge_t > 0.25 and effects != null:
                var next_steam: float = float(weapon_runtime["powder"].get("_steam_next", 0.0))
                if elapsed >= next_steam:
                    weapon_runtime["powder"]["_steam_next"] = elapsed + 0.16
                    var steam_pt: Vector2 = weapon_muzzle_point("powder") + Vector2(rng.randf_range(-4.0, 4.0), -6.0)
                    effects.puff(steam_pt, Color("#f2ebdc"), 9.0 + charge_t * 5.0, int(elapsed * 10.0))
            continue
        mat.set_shader_parameter("charge_progress", charge_t)
        if charge_t > 0.02:
            var col_c: Color = _weapon_charge_color(key)
            mat.set_shader_parameter("charge_color", col_c)
            mat.set_shader_parameter("flow_horizontal", 1.0 if key == "powder" else 0.0)
            mat.set_shader_parameter("elem_style", elem_s)
            if key in ["powder", "sling", "staff", "bonebow", "totem", "hammer"]:
                var fwd: Vector2 = Vector2.from_angle(view.rotation if key == "powder" else view.rotation - PI * 0.5)
                var shape_kind: String = "hammer" if key == "hammer" else "muzzle"
                var p_end: Vector2
                var p_start: Vector2
                if key == "hammer":
                    p_end = view.position + fwd * 14.0
                    p_start = view.position - fwd * 16.0
                elif key in ["powder", "sling", "staff"]:
                    p_end = weapon_muzzle_point(key, fwd)
                    p_start = p_end - fwd * (34.0 if key == "powder" else 24.0)
                else:
                    p_end = view.position + fwd * 16.0
                    p_start = view.position - fwd * 14.0
                cues.append({
                    "start": p_start,
                    "end": p_end,
                    "color": col_c,
                    "t": charge_t,
                    "elem": elem_s,
                    "shape": shape_kind,
                    "heavy": key in ["powder", "hammer"],
                    "clock": elapsed
                })
    if effects != null:
        effects.set_charge_cues(cues)

func draw_magic_shell(point: Vector2, direction: Vector2) -> void:
    var normal: Vector2 = direction.orthogonal()
    draw_colored_polygon(PackedVector2Array([point + direction * 9, point + normal * 7 - direction * 3, point - direction * 18, point - normal * 7 - direction * 3]), Color("#df9853"))
    draw_colored_polygon(PackedVector2Array([point - direction * 7 + normal * 4, point - direction * 25 + normal * 2, point - direction * 15 - normal * 3]), Color("#edc277"))
    draw_circle(point, 7.5, Color("#4f9ab4"))
    draw_circle(point, 4.7, Color("#a3fcff"))
    draw_arc(point, 8.0, 0.0, TAU, 20, Color("#edda9a"), 1.8, true)

func residual_kind_of(field: Dictionary) -> String:
    var tagged: String = str(field.get("residual", ""))
    if not tagged.is_empty():
        return tagged
    var weapon_id: String = str(field.get("weapon_id", ""))
    if weapon_id == "staff":
        return "rune"
    if weapon_id == "firepot" or bool(field.get("from_link", false)) and weapon_id in ["firepot", "powder"]:
        return "fire"
    if weapon_id == "powder":
        return "smoke"
    return "fire" if weapon_id == "firepot" else "smoke"

func _organic_ground_patch(center: Vector2, radius: float, seed_val: float, squash_y: float = 0.78, steps: int = 18) -> PackedVector2Array:
    var pts := PackedVector2Array()
    for i in range(steps):
        var angle: float = TAU * float(i) / float(steps)
        var rough: float = 1.0 + sin(angle * 3.0 + seed_val * 1.7) * 0.13 + cos(angle * 5.0 - seed_val * 2.3) * 0.08
        pts.append(center + Vector2(cos(angle), sin(angle) * squash_y) * radius * rough)
    return pts

func _soft_flame_blob(base: Vector2, w: float, h: float, sway: float) -> PackedVector2Array:
    # Rounded, chubby hand-drawn flame silhouette (no sharp polygonal triangles).
    return PackedVector2Array([
        base + Vector2(-w * 0.68, 2.0),
        base + Vector2(-w * 0.92, -h * 0.26),
        base + Vector2(-w * 0.56 + sway * 0.45, -h * 0.68),
        base + Vector2(sway, -h),
        base + Vector2(w * 0.56 + sway * 0.45, -h * 0.68),
        base + Vector2(w * 0.92, -h * 0.26),
        base + Vector2(w * 0.68, 2.0),
        base + Vector2(0.0, 4.2)
    ])

func _clip_point_before_lava(from_pt: Vector2, to_pt: Vector2, pad: float = 4.0) -> Dictionary:
    if map_view == null or not map_view.is_in_lava(to_pt, pad):
        return {"hit": false, "point": to_pt}
    var low: float = 0.0
    var high: float = 1.0
    for _step in range(5):
        var mid: float = (low + high) * 0.5
        if map_view.is_in_lava(from_pt.lerp(to_pt, mid), pad):
            high = mid
        else:
            low = mid
    return {"hit": true, "point": from_pt.lerp(to_pt, low)}

func draw_burning_fields(canvas: Node2D) -> void:
    var vfx_m: String = current_vfx_mode()
    if vfx_m == "off":
        return
    var glow: Texture2D = Effects.soft_glow_texture()
    var view_cull: Rect2 = visible_world_rect().grow(180.0)
    var light_detail: bool = vfx_m == "minimal" or burning_fields.size() >= 7 or enemies.size() >= 32
    for field in burning_fields:
        var center: Vector2 = field["position"]
        if not view_cull.has_point(center):
            continue
        var age: float = float(field["age"])
        var life: float = maxf(0.001, float(field["life"]))
        var alpha: float = clampf(1.0 - pow(age / life, 1.4), 0.0, 1.0)
        var kind: String = residual_kind_of(field)
        var radius: float = float(field["radius"])
        var seed_val: float = fmod(absf(center.x * 0.037 + center.y * 0.061), 100.0)
        # Unified hammer slam crater cracks helper (drawn ON TOP of ground washes for both fire & rune so they match 100%!)
        if kind == "rune":
            # Aligned arcane crystal-cyan ground magic residue + rising magic motes (concentrated along cracks when crater!)
            var pulse: float = 0.93 + 0.07 * sin(age * 4.5 + seed_val)
            var is_crater: bool = bool(field.get("crater", false))
            if is_crater and not field.has("_crater_cracks"):
                var cseed: int = int(absf(center.x * 71.0 + center.y * 149.0)) + 29
                field["_crater_cracks"] = Effects.make_radial_cracks(center, radius * 1.18, cseed, 3, 6, 0.74, false)
            if not field.has("_rune_specks"):
                var rseed: int = int(absf(center.x * 97.0 + center.y * 193.0)) + int(roundi(radius * 13.0))
                var rr := RandomNumberGenerator.new()
                rr.seed = rseed
                var spine_pts: Array = []
                if is_crater:
                    for ck in field["_crater_cracks"]:
                        var sp_arr: Array = ck.get("spine", [])
                        for s_i in range(maxi(0, sp_arr.size() - 1)):
                            var pa: Vector2 = sp_arr[s_i]
                            var pb: Vector2 = sp_arr[s_i + 1]
                            spine_pts.append(pa)
                            spine_pts.append(pa.lerp(pb, 0.5))
                var particle_r: float = radius * (0.82 if is_crater else 0.72)
                var flecks: Array = []
                for _f in range(3):
                    var fpos: Vector2
                    if is_crater and not spine_pts.is_empty() and rr.randf() < 0.75:
                        fpos = Vector2(spine_pts[rr.randi_range(0, spine_pts.size() - 1)]) + Vector2(rr.randf_range(-5.0, 5.0), rr.randf_range(-4.0, 4.0))
                    else:
                        var fa: float = rr.randf_range(0.0, TAU)
                        var fd: float = particle_r * sqrt(rr.randf()) * 0.75
                        fpos = center + Vector2(cos(fa) * fd, sin(fa) * fd * 0.74)
                    flecks.append({
                        "pos": fpos,
                        "r": rr.randf_range(3.0, 5.0),
                        "phase": rr.randf_range(0.0, TAU)
                    })
                var specks: Array = []
                for _i in range(6 if is_crater else 5):
                    var spos: Vector2
                    if is_crater and not spine_pts.is_empty() and rr.randf() < 0.78:
                        spos = Vector2(spine_pts[rr.randi_range(0, spine_pts.size() - 1)]) + Vector2(rr.randf_range(-6.0, 6.0), rr.randf_range(-5.0, 5.0))
                    else:
                        var a: float = rr.randf_range(0.0, TAU)
                        var d: float = particle_r * sqrt(rr.randf()) * 0.88
                        spos = center + Vector2(cos(a) * d, sin(a) * d * 0.74)
                    specks.append({
                        "pos": spos,
                        "r": rr.randf_range(1.7, 3.2),
                        "phase": rr.randf_range(0.0, TAU),
                        "speed": rr.randf_range(4.5, 9.5),
                        "star": rr.randf() < 0.58
                    })
                var risers: Array = []
                for _m in range(7 if is_crater else 6):
                    var rbase: Vector2
                    if is_crater and not spine_pts.is_empty() and rr.randf() < 0.82:
                        rbase = Vector2(spine_pts[rr.randi_range(0, spine_pts.size() - 1)]) + Vector2(rr.randf_range(-4.0, 4.0), rr.randf_range(-3.0, 3.0))
                    else:
                        var ma: float = rr.randf_range(0.0, TAU)
                        var md: float = particle_r * sqrt(rr.randf()) * 0.84
                        rbase = center + Vector2(cos(ma) * md, sin(ma) * md * 0.74)
                    risers.append({
                        "base": rbase,
                        "r": rr.randf_range(1.5, 3.0),
                        "phase": rr.randf_range(0.0, 1.0),
                        "speed": rr.randf_range(0.55, 1.15),
                        "height": rr.randf_range(26.0, 52.0),
                        "sway": rr.randf_range(1.8, 3.8),
                        "star": rr.randf() < 0.38
                    })
                field["_rune_flecks"] = flecks
                field["_rune_specks"] = specks
                field["_rune_risers"] = risers
            # 1) Centered ground magic wash — dynamically tracks staff tier (cyan-blue Lv.1-4, awakened violet-purple Lv.5+!)
            var rune_tier: int = Evolution.tier(weapon_level("staff"))
            var is_purple: bool = rune_tier >= 2
            var wash_outer: Color = Color(0.44, 0.20, 0.74, (0.58 if is_crater else 0.68) * alpha) if is_purple else Color(0.16, 0.56, 0.78, (0.56 if is_crater else 0.68) * alpha)
            var wash_inner: Color = Color(0.76, 0.44, 0.98, (0.50 if is_crater else 0.62) * alpha) if is_purple else Color(0.36, 0.88, 1.0, (0.48 if is_crater else 0.60) * alpha)
            var mote_halo: Color = Color(0.74, 0.42, 0.98, 0.54) if is_purple else Color(0.34, 0.86, 0.98, 0.52)
            var mote_core: Color = Color(0.96, 0.88, 1.0, 1.0) if is_purple else Color(0.90, 0.99, 1.0, 1.0)
            var outer_wr: float = radius * (1.16 if is_crater else 1.14) * pulse
            canvas.draw_texture_rect(glow, Rect2(center - Vector2(outer_wr, outer_wr * 0.74), Vector2(outer_wr * 2.0, outer_wr * 1.48)), false, wash_outer)
            var core_r: float = radius * (0.76 if is_crater else 0.78) * pulse
            canvas.draw_texture_rect(glow, Rect2(center - Vector2(core_r, core_r * 0.74), Vector2(core_r * 2.0, core_r * 1.48)), false, wash_inner)
            if not is_crater:
                # Soft breathing arcane core bloom (no 4 border arcs!)
                var bloom_r: float = radius * 0.42 * (0.92 + 0.10 * sin(age * 6.5 + seed_val))
                canvas.draw_texture_rect(glow, Rect2(center - Vector2(bloom_r, bloom_r * 0.74), Vector2(bloom_r * 2.0, bloom_r * 1.48)), false, Color(mote_core.r, mote_core.g, mote_core.b, 0.44 * alpha))
            # 2) If hammer magic crater: draw unified 3-layer ground cracks ON TOP of the wash
            if is_crater:
                if not field.has("_crater_cracks"):
                    var cseed: int = int(absf(center.x * 71.0 + center.y * 149.0)) + 29
                    field["_crater_cracks"] = Effects.make_radial_cracks(center, radius * 1.18, cseed, 3, 6, 0.74, false)
                var glow_pulse: float = 0.85 + 0.15 * sin(age * 9.0 + seed_val)
                var crack_glow: Color = Color(0.84, 0.54, 1.0, 0.94 * alpha * glow_pulse) if is_purple else Color(0.52, 0.94, 1.0, 0.90 * alpha * glow_pulse)
                Effects.draw_elemental_cracks(
                    canvas, field["_crater_cracks"],
                    Color(0.26, 0.19, 0.13, 0.88 * alpha),
                    Color(0.14, 0.10, 0.08, 0.90 * alpha),
                    crack_glow
                )
            # 3) Luminous ground residue traces / flecks (trimmed in crowded/minimal scenes for smooth FPS)
            if not light_detail:
                for fl in field["_rune_flecks"]:
                    var fp: Vector2 = fl["pos"]
                    var fr: float = float(fl["r"]) * (0.90 + 0.12 * sin(age * 5.0 + float(fl["phase"])))
                    canvas.draw_texture_rect(glow, Rect2(fp - Vector2(fr * 1.8, fr * 1.3), Vector2(fr * 3.6, fr * 2.6)), false, Color(mote_halo.r, mote_halo.g, mote_halo.b, 0.52 * alpha))
                    canvas.draw_circle(fp, fr * 0.44, Color(mote_core.r, mote_core.g, mote_core.b, 0.70 * alpha))
            # 4) Twinkling ground magic starlight specks
            for sp in field["_rune_specks"]:
                var tw: float = 0.45 + 0.55 * sin(age * float(sp["speed"]) + float(sp["phase"]))
                var p: Vector2 = sp["pos"]
                var r_sz: float = float(sp["r"]) * (0.78 + 0.34 * tw)
                var sa: float = alpha * (0.52 + 0.48 * tw)
                if not light_detail:
                    canvas.draw_texture_rect(glow, Rect2(p - Vector2.ONE * (r_sz * 2.5), Vector2.ONE * (r_sz * 5.0)), false, Color(mote_halo.r, mote_halo.g, mote_halo.b, 0.54 * sa))
                if bool(sp["star"]):
                    canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r_sz * 1.45), p + Vector2(r_sz * 0.82, 0), p + Vector2(0, r_sz * 1.45), p + Vector2(-r_sz * 0.82, 0)]), Color(mote_core.r, mote_core.g, mote_core.b, 0.95 * sa))
                else:
                    canvas.draw_circle(p, r_sz * 0.85, Color(mote_core.r, mote_core.g, mote_core.b, 0.92 * sa))
            # 5) Continuously rising upward-floating magic motes
            for mr in field["_rune_risers"]:
                var cyc: float = fmod(age * float(mr["speed"]) + float(mr["phase"]), 1.0)
                var fade_in: float = clampf(cyc / 0.18, 0.0, 1.0)
                var fade_out: float = clampf((1.0 - cyc) / 0.35, 0.0, 1.0)
                var ma: float = alpha * fade_in * fade_out
                if ma <= 0.02:
                    continue
                var mp: Vector2 = Vector2(mr["base"]) + Vector2(sin(cyc * TAU + float(mr["phase"]) * 6.28) * float(mr["sway"]), -cyc * float(mr["height"]))
                var m_sz: float = float(mr["r"]) * lerpf(1.05, 0.48, cyc)
                canvas.draw_texture_rect(glow, Rect2(mp - Vector2.ONE * (m_sz * 2.6), Vector2.ONE * (m_sz * 5.2)), false, Color(mote_halo.r, mote_halo.g, mote_halo.b, 0.56 * ma))
                if bool(mr["star"]):
                    canvas.draw_colored_polygon(PackedVector2Array([mp + Vector2(0, -m_sz * 1.4), mp + Vector2(m_sz * 0.78, 0), mp + Vector2(0, m_sz * 1.4), mp + Vector2(-m_sz * 0.78, 0)]), Color(mote_core.r, mote_core.g, mote_core.b, 0.96 * ma))
                else:
                    canvas.draw_circle(mp, m_sz * 0.88, Color(mote_core.r, mote_core.g, mote_core.b, 0.94 * ma))
        elif kind == "fire":
            var is_green_fire: bool = bool(field.get("green_fire", false)) or Evolution.tier(weapon_level("firepot")) >= 2
            var gf_outer: Color = Color(0.14, 0.72, 0.36, 0.86 * alpha) if is_green_fire else Color(0.90, 0.34, 0.09, 0.86 * alpha)
            var gf_inner: Color = Color(0.76, 1.0, 0.56, 0.90 * alpha) if is_green_fire else Color(1.0, 0.78, 0.26, 0.90 * alpha)
            var gf_spark: Color = Color(0.72, 1.0, 0.54, 0.92 * alpha) if is_green_fire else Color(1.0, 0.70, 0.20, 0.90 * alpha)
            if not bool(field.get("heavy", true)):
                # Light weapon fire enchant (sling / bonebow / melee): small on-target flame & rising sparks (NO heavy ground pit!)
                var sway: float = sin(age * 16.0 + seed_val) * 2.4
                canvas.draw_texture_rect(glow, Rect2(center - Vector2(18.0, 14.0), Vector2(36.0, 28.0)), false, Color(0.16, 0.82, 0.44, 0.34 * alpha) if is_green_fire else Color(0.95, 0.42, 0.12, 0.34 * alpha))
                var tongues: Array = [
                    [Vector2(-5.0, 2.0), 5.5, 13.0, sway * 0.8],
                    [Vector2(0.0, 3.0), 7.0, 17.0, sway],
                    [Vector2(5.5, 2.5), 5.0, 11.5, -sway * 0.7]
                ]
                for tg in tongues:
                    var base: Vector2 = center + Vector2(tg[0])
                    var tw_w: float = float(tg[1]) * (0.85 + 0.18 * sin(age * 14.0 + float(tg[1])))
                    var tw_h: float = float(tg[2]) * (0.88 + 0.16 * cos(age * 12.0 + seed_val))
                    canvas.draw_colored_polygon(_soft_flame_blob(base, tw_w, tw_h, float(tg[3])), gf_outer)
                    canvas.draw_colored_polygon(_soft_flame_blob(base + Vector2(0, -1.0), tw_w * 0.56, tw_h * 0.60, float(tg[3]) * 0.7), gf_inner)
                for s_i in range(4):
                    var cyc: float = fmod(age * 1.45 + float(s_i) * 0.25 + seed_val * 0.1, 1.0)
                    var sp: Vector2 = center + Vector2(sin(cyc * 5.0 + float(s_i) * 2.1) * 7.5, -4.0 - cyc * 22.0)
                    canvas.draw_circle(sp, lerpf(2.2, 0.8, cyc), Color(gf_spark.r, gf_spark.g, gf_spark.b, (1.0 - cyc) * 0.90 * alpha))
            elif not bool(field.get("crater", false)):
                # Heavy cannon / firepot molten magma residue (NO cracks, NO red ring — denser near center without stacking, strictly inside the scorch wash!)
                var flicker: float = 0.90 + 0.10 * sin(age * 10.0 + seed_val)
                if not field.has("_cannon_fire"):
                    var cf_rng := RandomNumberGenerator.new()
                    cf_rng.seed = int(absf(center.x * 83.0 + center.y * 167.0)) + 19
                    var visual_r: float = radius * 0.68
                    var placed: Array = []
                    var pools: Array = []
                    for i in range(3):
                        var p: Vector2 = center
                        var sz: float = (6.5 if i == 0 else cf_rng.randf_range(3.8, 5.2)) * clampf(radius / 58.0, 0.78, 1.15)
                        for _try in range(24):
                            var norm_d: float = cf_rng.randf_range(0.0, 0.14) if i == 0 else cf_rng.randf_range(0.26, 0.52)
                            var a: float = cf_rng.randf_range(0.0, TAU)
                            var cand: Vector2 = center + Vector2(cos(a) * visual_r * norm_d, sin(a) * visual_r * norm_d * 0.74)
                            var ok: bool = true
                            for prev in placed:
                                if cand.distance_to(prev["pos"]) < sz + float(prev["r"]) + 2.8:
                                    ok = false
                                    break
                            if ok:
                                p = cand
                                break
                        placed.append({"pos": p, "r": sz})
                        var poly := PackedVector2Array()
                        for s in range(8):
                            var sa: float = TAU * float(s) / 8.0 + cf_rng.randf_range(-0.2, 0.2)
                            var sr: float = sz * cf_rng.randf_range(0.78, 1.14)
                            poly.append(p + Vector2(cos(sa) * sr, sin(sa) * sr * 0.72))
                        pools.append({"poly": poly, "center": p, "r": sz})
                    var dots: Array = []
                    for _s in range(10):
                        var nd: float = pow(cf_rng.randf(), 1.25) * 0.94
                        var dr: float = lerpf(3.0, 1.4, nd) * cf_rng.randf_range(0.85, 1.12)
                        var p: Vector2 = center
                        var found: bool = false
                        for _try in range(24):
                            var cand_nd: float = pow(cf_rng.randf(), 1.25) * 0.94
                            var a: float = cf_rng.randf_range(0.0, TAU)
                            var cand: Vector2 = center + Vector2(cos(a) * visual_r * cand_nd, sin(a) * visual_r * cand_nd * 0.74)
                            var ok: bool = true
                            for prev in placed:
                                if cand.distance_to(prev["pos"]) < dr + float(prev["r"]) + 2.6:
                                    ok = false
                                    break
                            if ok:
                                p = cand
                                nd = cand_nd
                                found = true
                                break
                        if not found:
                            continue
                        placed.append({"pos": p, "r": dr})
                        dots.append({"pos": p, "r": dr, "phase": cf_rng.randf_range(0.0, TAU), "hot": nd < 0.72 and cf_rng.randf() < 0.65})
                    var embers: Array = []
                    for _e in range(4):
                        var ea: float = cf_rng.randf_range(0.0, TAU)
                        var ed: float = visual_r * cf_rng.randf_range(0.10, 0.72)
                        embers.append({
                            "base": center + Vector2(cos(ea) * ed, sin(ea) * ed * 0.74),
                            "phase": cf_rng.randf_range(0.0, 1.0),
                            "speed": cf_rng.randf_range(0.85, 1.45),
                            "height": cf_rng.randf_range(14.0, 28.0),
                            "r": cf_rng.randf_range(1.2, 2.2)
                        })
                    field["_cannon_fire"] = {"pools": pools, "dots": dots, "embers": embers}
                var cf: Dictionary = field["_cannon_fire"]
                # Soft warm ground scorch wash wide enough to enclose all magma blobs & sparks
                var wash_r: float = radius * 1.12
                canvas.draw_texture_rect(glow, Rect2(center - Vector2(wash_r, wash_r * 0.74), Vector2(wash_r * 2.0, wash_r * 1.48)), false, Color(0.12, 0.56, 0.28, 0.42 * alpha) if is_green_fire else Color(0.58, 0.21, 0.08, 0.42 * alpha))
                var inner_wash_r: float = radius * 0.72
                canvas.draw_texture_rect(glow, Rect2(center - Vector2(inner_wash_r, inner_wash_r * 0.74), Vector2(inner_wash_r * 2.0, inner_wash_r * 1.48)), false, Color(0.18, 0.72, 0.36, 0.34 * alpha) if is_green_fire else Color(0.72, 0.25, 0.07, 0.34 * alpha))
                # Center-dense non-stacked volcanic molten magma blobs & dots, strictly inside the scorch wash
                var pool_dark := Color(0.08, 0.42, 0.20, 0.88 * alpha) if is_green_fire else Color(0.62, 0.16, 0.06, 0.88 * alpha)
                var pool_mid := Color(0.22, 0.86, 0.46, 0.86 * alpha * flicker) if is_green_fire else Color(0.92, 0.38, 0.09, 0.86 * alpha * flicker)
                var pool_core := Color(0.78, 1.0, 0.62, 0.86 * alpha * flicker) if is_green_fire else Color(1.0, 0.74, 0.24, 0.86 * alpha * flicker)
                for pool in cf["pools"]:
                    canvas.draw_colored_polygon(pool["poly"], pool_dark)
                    var cr: float = float(pool["r"]) * 0.56
                    canvas.draw_circle(pool["center"], cr, pool_mid)
                    canvas.draw_circle(pool["center"], cr * 0.44, pool_core)
                for dt in cf["dots"]:
                    var tw: float = 0.55 + 0.45 * sin(age * 8.5 + float(dt["phase"]))
                    var p: Vector2 = dt["pos"]
                    var dr: float = float(dt["r"])
                    canvas.draw_circle(p, dr, Color(0.10, 0.48, 0.24, 0.86 * alpha) if is_green_fire else Color(0.68, 0.19, 0.07, 0.86 * alpha))
                    if bool(dt["hot"]):
                        canvas.draw_circle(p, dr * 0.50, Color(0.78, 1.0, 0.62, 0.90 * alpha * tw) if is_green_fire else Color(1.0, 0.66, 0.18, 0.90 * alpha * tw))
                # Rising embers
                for em in cf["embers"]:
                    var cyc: float = fmod(age * float(em["speed"]) + float(em["phase"]), 1.0)
                    var ea_fade: float = alpha * clampf(cyc / 0.15, 0.0, 1.0) * clampf((1.0 - cyc) / 0.35, 0.0, 1.0)
                    var ep: Vector2 = Vector2(em["base"]) + Vector2(sin(cyc * 5.0 + float(em["phase"]) * 6.0) * 3.0, -cyc * float(em["height"]))
                    canvas.draw_circle(ep, float(em["r"]) * lerpf(1.0, 0.45, cyc), Color(0.74, 1.0, 0.56, 0.90 * ea_fade * flicker) if is_green_fire else Color(1.0, 0.68, 0.18, 0.90 * ea_fade * flicker))
            else:
                # Hammer Fire Crater: unified 3-layer ground cracks + well-distributed non-clumped magma & rising embers around the cracks!
                var flicker: float = 0.90 + 0.10 * sin(age * 9.5 + seed_val)
                if not field.has("_crater_cracks"):
                    var cseed: int = int(absf(center.x * 71.0 + center.y * 149.0)) + 29
                    field["_crater_cracks"] = Effects.make_radial_cracks(center, radius * 1.18, cseed, 3, 6, 0.74, false)
                if not field.has("_fire_magma"):
                    var fseed: int = int(absf(center.x * 89.0 + center.y * 173.0)) + int(roundi(radius * 17.0))
                    var fr := RandomNumberGenerator.new()
                    fr.seed = fseed
                    var visual_r: float = radius * 0.88
                    var placed: Array = []
                    var pools: Array = []
                    # Place 4 well-separated magma spots distributed around the cracks (NO clumping/piling in the center!)
                    for i in range(4):
                        var sz: float = fr.randf_range(4.2, 6.4) * clampf(radius / 58.0, 0.78, 1.15)
                        var p: Vector2 = center
                        var found: bool = false
                        for _try in range(24):
                            var nd: float = fr.randf_range(0.24, 0.76)
                            var a: float = fr.randf_range(0.0, TAU)
                            var cand: Vector2 = center + Vector2(cos(a) * visual_r * nd, sin(a) * visual_r * nd * 0.74)
                            var ok: bool = true
                            for prev in placed:
                                if cand.distance_to(prev["pos"]) < sz + float(prev["r"]) + 8.0:
                                    ok = false
                                    break
                            if ok:
                                p = cand
                                found = true
                                break
                        if not found:
                            continue
                        placed.append({"pos": p, "r": sz})
                        var poly := PackedVector2Array()
                        for s in range(8):
                            var sa: float = TAU * float(s) / 8.0 + fr.randf_range(-0.2, 0.2)
                            var sr: float = sz * fr.randf_range(0.76, 1.14)
                            poly.append(p + Vector2(cos(sa) * sr, sin(sa) * sr * 0.72))
                        pools.append({"poly": poly, "center": p, "r": sz})
                    # Well-spaced glowing magma dots scattered across the cracked zone (non-overlapping!)
                    var dots: Array = []
                    for _i in range(14):
                        var dr: float = fr.randf_range(1.6, 3.2)
                        var p: Vector2 = center
                        var nd: float = 0.5
                        var found: bool = false
                        for _try in range(20):
                            nd = sqrt(fr.randf()) * 0.94
                            var a: float = fr.randf_range(0.0, TAU)
                            var cand: Vector2 = center + Vector2(cos(a) * visual_r * nd, sin(a) * visual_r * nd * 0.74)
                            var ok: bool = true
                            for prev in placed:
                                if cand.distance_to(prev["pos"]) < dr + float(prev["r"]) + 4.5:
                                    ok = false
                                    break
                            if ok:
                                p = cand
                                found = true
                                break
                        if not found:
                            continue
                        placed.append({"pos": p, "r": dr})
                        dots.append({"pos": p, "r": dr, "phase": fr.randf_range(0.0, TAU), "hot": nd < 0.75 and fr.randf() < 0.65})
                    var embers: Array = []
                    var f_spines: Array = []
                    for ck in field["_crater_cracks"]:
                        var sp_arr: Array = ck.get("spine", [])
                        for s_i in range(maxi(0, sp_arr.size() - 1)):
                            f_spines.append(Vector2(sp_arr[s_i]).lerp(Vector2(sp_arr[s_i + 1]), 0.35))
                    for _e in range(9):
                        var ebase: Vector2
                        if not f_spines.is_empty() and fr.randf() < 0.85:
                            ebase = Vector2(f_spines[fr.randi_range(0, f_spines.size() - 1)]) + Vector2(fr.randf_range(-4.0, 4.0), fr.randf_range(-3.0, 3.0))
                        else:
                            var ea: float = fr.randf_range(0.0, TAU)
                            var ed: float = visual_r * fr.randf_range(0.18, 0.72)
                            ebase = center + Vector2(cos(ea) * ed, sin(ea) * ed * 0.74)
                        embers.append({
                            "base": ebase,
                            "phase": fr.randf_range(0.0, 1.0),
                            "speed": fr.randf_range(0.80, 1.35),
                            "height": fr.randf_range(18.0, 38.0),
                            "r": fr.randf_range(1.4, 2.6)
                        })
                    field["_fire_magma"] = {"pools": pools, "dots": dots, "embers": embers}
                var fm: Dictionary = field["_fire_magma"]
                # 1) Soft warm volcanic-amber/emerald pit wash
                var pit_r: float = radius * 1.14
                canvas.draw_texture_rect(glow, Rect2(center - Vector2(pit_r, pit_r * 0.74), Vector2(pit_r * 2.0, pit_r * 1.48)), false, Color(0.12, 0.56, 0.28, 0.44 * alpha) if is_green_fire else Color(0.62, 0.22, 0.08, 0.44 * alpha))
                var inner_r: float = radius * 0.72
                canvas.draw_texture_rect(glow, Rect2(center - Vector2(inner_r, inner_r * 0.74), Vector2(inner_r * 2.0, inner_r * 1.48)), false, Color(0.20, 0.78, 0.42, 0.40 * alpha * flicker) if is_green_fire else Color(0.84, 0.30, 0.08, 0.40 * alpha * flicker))
                # 2) Unified 3-layer ground cracks ON TOP of the wash
                Effects.draw_elemental_cracks(
                    canvas, field["_crater_cracks"],
                    Color(0.26, 0.19, 0.13, 0.88 * alpha),
                    Color(0.14, 0.10, 0.08, 0.90 * alpha),
                    Color(0.32, 0.96, 0.56, 0.94 * alpha * flicker) if is_green_fire else Color(0.98, 0.48, 0.14, 0.94 * alpha * flicker)
                )
                # 3) Well-spaced magma spots around the cracks (NOT piled in the middle!)
                var fm_dark := Color(0.08, 0.42, 0.20, 0.86 * alpha) if is_green_fire else Color(0.62, 0.16, 0.06, 0.86 * alpha)
                var fm_mid := Color(0.22, 0.86, 0.46, 0.86 * alpha * flicker) if is_green_fire else Color(0.92, 0.38, 0.09, 0.86 * alpha * flicker)
                var fm_core := Color(0.78, 1.0, 0.62, 0.86 * alpha * flicker) if is_green_fire else Color(1.0, 0.74, 0.24, 0.86 * alpha * flicker)
                for pool in fm["pools"]:
                    canvas.draw_colored_polygon(pool["poly"], fm_dark)
                    var cr: float = float(pool["r"]) * 0.56
                    canvas.draw_circle(pool["center"], cr, fm_mid)
                    canvas.draw_circle(pool["center"], cr * 0.44, fm_core)
                # 4) Evenly-distributed glowing magma dots + rising hot embers
                for dt in fm["dots"]:
                    var tw: float = 0.55 + 0.45 * sin(age * 8.0 + float(dt["phase"]))
                    var p: Vector2 = dt["pos"]
                    var dr: float = float(dt["r"])
                    canvas.draw_circle(p, dr, Color(0.10, 0.48, 0.24, 0.86 * alpha) if is_green_fire else Color(0.68, 0.19, 0.07, 0.86 * alpha))
                    if bool(dt["hot"]):
                        canvas.draw_circle(p, dr * 0.52, Color(0.78, 1.0, 0.62, 0.90 * alpha * tw) if is_green_fire else Color(1.0, 0.68, 0.18, 0.90 * alpha * tw))
                for em in fm["embers"]:
                    var cyc: float = fmod(age * float(em["speed"]) + float(em["phase"]), 1.0)
                    var ea_fade: float = alpha * clampf(cyc / 0.15, 0.0, 1.0) * clampf((1.0 - cyc) / 0.35, 0.0, 1.0)
                    var ep: Vector2 = Vector2(em["base"]) + Vector2(sin(cyc * 5.0 + float(em["phase"]) * 6.0) * 3.5, -cyc * float(em["height"]))
                    canvas.draw_circle(ep, float(em["r"]) * lerpf(1.0, 0.45, cyc), Color(0.76, 1.0, 0.58, 0.92 * ea_fade * flicker) if is_green_fire else Color(1.0, 0.70, 0.20, 0.92 * ea_fade * flicker))
        elif kind == "thunder_mark":
            # Fine, continuous Lichtenberg electric ground veins radiating seamlessly FROM center (stopping cleanly at lava rims!)
            if not field.has("_thunder_polys"):
                if map_view != null and map_view.is_in_lava(center, 4.0):
                    field["_thunder_polys"] = []
                    field["_in_lava"] = true
                else:
                    field["_in_lava"] = false
                    var tr := RandomNumberGenerator.new()
                    tr.seed = int(absf(center.x * 79.0 + center.y * 151.0)) + 41
                    var polys: Array = []
                    var v_count: int = tr.randi_range(6, 8)
                    var base_a: float = tr.randf_range(0.0, TAU)
                    var step_a: float = TAU / float(v_count)
                    for i in range(v_count):
                        var a: float = base_a + float(i) * step_a + tr.randf_range(-step_a * 0.32, step_a * 0.32)
                        var cur: Vector2 = center
                        var spine: Array = [cur]
                        var segs: int = tr.randi_range(4, 5)
                        var seg_len: float = (radius * tr.randf_range(0.72, 1.06)) / float(segs)
                        var zig: float = 1.0 if tr.randf() < 0.5 else -1.0
                        for _s in range(segs):
                            var sa: float = a + zig * tr.randf_range(0.10, 0.24)
                            zig = -zig
                            var next_pt: Vector2 = cur + Vector2(cos(sa), sin(sa) * 0.74) * seg_len * tr.randf_range(0.82, 1.18)
                            var clip: Dictionary = _clip_point_before_lava(cur, next_pt, 4.0)
                            if bool(clip["hit"]):
                                var rim_pt: Vector2 = clip["point"]
                                if rim_pt.distance_squared_to(cur) > 4.0:
                                    spine.append(rim_pt)
                                break
                            cur = next_pt
                            spine.append(cur)
                        if spine.size() >= 2:
                            polys.append(Effects._build_tapered_crack(spine, radius * tr.randf_range(0.018, 0.026)))
                        # Fine branching sub-veins along the main vein
                        for b_try in range(2):
                            if spine.size() >= 4 and tr.randf() < 0.70:
                                var fidx: int = clampi(1 + b_try, 1, spine.size() - 2)
                                var fcur: Vector2 = spine[fidx]
                                var fspine: Array = [fcur]
                                var fa: float = a + (1.0 if b_try == 0 else -1.0) * tr.randf_range(0.32, 0.62)
                                for _fs in range(2):
                                    var fsa: float = fa + (1.0 if _fs % 2 == 0 else -1.0) * tr.randf_range(0.06, 0.16)
                                    var fnext: Vector2 = fcur + Vector2(cos(fsa), sin(fsa) * 0.74) * (radius * tr.randf_range(0.12, 0.22))
                                    var fclip: Dictionary = _clip_point_before_lava(fcur, fnext, 4.0)
                                    if bool(fclip["hit"]):
                                        var frim: Vector2 = fclip["point"]
                                        if frim.distance_squared_to(fcur) > 4.0:
                                            fspine.append(frim)
                                        break
                                    fcur = fnext
                                    fspine.append(fcur)
                                if fspine.size() >= 2:
                                    polys.append(Effects._build_tapered_crack(fspine, radius * 0.012))
                    field["_thunder_polys"] = polys
            if bool(field.get("_in_lava", false)):
                continue
            # Unified scorched strike core + fine silver-white (or crimson Red Lightning) tapered electric veins
            var mark_alpha: float = clampf((1.0 - age / life) / 0.35, 0.0, 1.0)
            var is_red_mark: bool = bool(field.get("red", false))
            var glow_r: float = radius * 1.05
            canvas.draw_texture_rect(glow, Rect2(center - Vector2(glow_r, glow_r * 0.74), Vector2(glow_r * 2.0, glow_r * 1.48)), false, Color(0.86, 0.20, 0.14, 0.38 * mark_alpha) if is_red_mark else Color(0.76, 0.86, 0.96, 0.38 * mark_alpha))
            var pulse: float = 0.82 + 0.18 * sin(age * 14.0 + seed_val)
            var rim_col: Color = Color(0.32, 0.09, 0.09, 0.86 * mark_alpha) if is_red_mark else Color(0.22, 0.27, 0.36, 0.82 * mark_alpha)
            var inner_col: Color = Color(1.0, 0.34, 0.20, 0.96 * mark_alpha * pulse) if is_red_mark else Color(0.96, 0.99, 1.0, 0.98 * mark_alpha * pulse)
            # 2-pass layered draw: ALL dark rims first, then ALL bright glowing cores on top
            # so center hub and every branch junction merge seamlessly with ZERO dark cutoffs!
            canvas.draw_circle(center, 5.2 * mark_alpha, rim_col)
            for ck in field["_thunder_polys"]:
                canvas.draw_colored_polygon(ck["outer"], rim_col)
            canvas.draw_circle(center, 3.4 * mark_alpha, inner_col)
            for ck in field["_thunder_polys"]:
                canvas.draw_colored_polygon(ck["inner"], inner_col)
        elif kind == "thunder":
            # Persistent crackling thunder crater residue (e.g. thunder_hammer slam pit)
            var t_pulse: float = 0.88 + 0.12 * sin(age * 16.0 + seed_val)
            var tr_out: float = radius * 0.98
            canvas.draw_texture_rect(glow, Rect2(center - Vector2(tr_out, tr_out * 0.74), Vector2(tr_out * 2.0, tr_out * 1.48)), false, Color(0.32, 0.68, 0.84, 0.34 * alpha))
            var tr_in: float = radius * 0.54 * t_pulse
            canvas.draw_texture_rect(glow, Rect2(center - Vector2(tr_in, tr_in * 0.74), Vector2(tr_in * 2.0, tr_in * 1.48)), false, Color(0.86, 0.94, 0.62, 0.36 * alpha))
            var arc_step: int = int(floor(age * 11.0))
            var tr_rng := _draw_rng
            tr_rng.seed = int(absf(center.x * 53.0 + center.y * 113.0)) + arc_step * 17
            for _a in range(3):
                var ang: float = tr_rng.randf_range(0.0, TAU)
                var cur: Vector2 = center + Vector2(cos(ang), sin(ang) * 0.74) * tr_rng.randf_range(4.0, radius * 0.18)
                var pts := PackedVector2Array([cur])
                for _s in range(3):
                    ang += tr_rng.randf_range(-0.65, 0.65)
                    cur += Vector2(cos(ang), sin(ang) * 0.74) * tr_rng.randf_range(radius * 0.16, radius * 0.28)
                    pts.append(cur)
                canvas.draw_polyline(pts, Color(0.36, 0.82, 0.94, 0.82 * alpha), 3.0, true)
                canvas.draw_polyline(pts, Color(1.0, 0.97, 0.78, 0.92 * alpha), 1.3, true)
            for sp_i in range(10):
                var cyc: float = fmod(age * 1.15 + float(sp_i) * 0.1 + seed_val * 0.07, 1.0)
                var ang2: float = float(sp_i) * 2.399 + seed_val
                var d2: float = radius * (0.20 + 0.55 * fmod(float(sp_i) * 0.37, 1.0))
                var sp: Vector2 = center + Vector2(cos(ang2) * d2, sin(ang2) * d2 * 0.74 - cyc * 34.0)
                var sa: float = alpha * clampf(cyc / 0.15, 0.0, 1.0) * clampf((1.0 - cyc) / 0.35, 0.0, 1.0)
                canvas.draw_circle(sp, lerpf(2.5, 1.0, cyc), Color(0.96, 0.98, 0.70, 0.94 * sa))
        else:
            # Lightweight translucent parchment dust puffs (airy dust, NOT meteorite cloud or opaque sticker)
            if not field.has("_smoke_puffs"):
                var sr := RandomNumberGenerator.new()
                sr.seed = int(absf(center.x * 61.0 + center.y * 131.0)) + 7
                var spuffs: Array = []
                for _sp in range(3):
                    spuffs.append({"off": Vector2(sr.randf_range(-radius * 0.42, radius * 0.42), sr.randf_range(-radius * 0.24, radius * 0.24)), "r": radius * sr.randf_range(0.30, 0.46), "drift": Vector2(sr.randf_range(-10.0, 10.0), sr.randf_range(-20.0, -10.0)), "seed": sr.randf_range(0.0, 10.0)})
                field["_smoke_puffs"] = spuffs
            for sp in field["_smoke_puffs"]:
                var sp_pos: Vector2 = center + Vector2(sp["off"]) + Vector2(sp["drift"]) * age
                var sp_r: float = float(sp["r"]) * (0.82 + age * 0.42)
                Effects.draw_dust_puff(canvas, sp_pos, sp_r, alpha, float(sp["seed"]))

func draw_link_shapes() -> void:
    if ground_marks_layer == null:
        draw_burning_fields(self)
    var chain_recipe: Dictionary = current_chain_link()
    if chain_recipe.is_empty():
        return
    var key: String = str(chain_recipe["weapons"][1])
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

func current_vfx_mode() -> String:
    var raw: String = str(settings.get("vfx_mode", ""))
    if raw in ["full", "minimal", "off"]:
        return raw
    return "full" if bool(settings.get("vfx_enabled", true)) else "minimal"

func set_damage_numbers(enabled: bool) -> void:
    var previous: bool = bool(settings.get("damage_numbers", true))
    settings["damage_numbers"] = enabled
    var result: Dictionary = save_store.write_settings(settings)
    if not result.get("ok", false):
        settings["damage_numbers"] = previous
        hud.configure_display(previous, bool(settings.get("fullscreen", false)), current_vfx_mode())
        hud.save_note = "显示设置未保存：" + str(result.get("error", ""))
        if is_instance_valid(hud.save_note_label): hud.save_note_label.text = hud.save_note
        return
    hud.configure_display(enabled, bool(settings.get("fullscreen", false)), current_vfx_mode())

func set_vfx_mode(mode: String) -> void:
    var target_mode: String = mode if mode in ["full", "minimal", "off"] else "full"
    var previous: String = current_vfx_mode()
    settings["vfx_mode"] = target_mode
    settings["vfx_enabled"] = target_mode == "full"
    effects.set_vfx_mode(target_mode)
    var result: Dictionary = save_store.write_settings(settings)
    if not result.get("ok", false):
        settings["vfx_mode"] = previous
        settings["vfx_enabled"] = previous == "full"
        effects.set_vfx_mode(previous)
        hud.configure_display(bool(settings.get("damage_numbers", true)), bool(settings.get("fullscreen", false)), previous)
        hud.save_note = "特效设置未保存：" + str(result.get("error", ""))
        if is_instance_valid(hud.save_note_label): hud.save_note_label.text = hud.save_note
        return
    hud.configure_display(bool(settings.get("damage_numbers", true)), bool(settings.get("fullscreen", false)), target_mode)

func apply_display_mode(fullscreen: bool) -> void:
    if DisplayServer.get_name() == "headless":
        return
    if not OS.has_feature("android"):
        if fullscreen:
            DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
        else:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
            _fit_playable_window()
            call_deferred("_fit_playable_window")
    _apply_content_scale()

func _apply_content_scale() -> void:
    if DisplayServer.get_name() == "headless" or not is_inside_tree():
        return
    var win := get_tree().root
    win.content_scale_size = Vector2i(1280, 800)
    win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if OS.has_feature("android") else Window.CONTENT_SCALE_ASPECT_KEEP

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

func start_training_camp() -> void:
    # Protect any active normal run via autosave before entering training camp.
    if running and not trial_mode and not training_mode and not demo and not animation_demo and settings.get("autosave", true):
        save_game()
    start_run(false)
    training_mode = true
    training_godmode = true
    training_enemy_wave = 10
    training_enemy_immortal = false
    wave = 10
    paused = false
    clear_enemies()
    projectiles.clear()
    burning_fields.clear()
    pickups.clear()
    coins = 99999
    if hud != null:
        if hud.has_method("set_training_mode"):
            hud.set_training_mode(true)
        if hud.has_method("hide_overlay"):
            hud.hide_overlay()
    update_hud()
    open_training_panel()

func toggle_training_panel() -> void:
    if not training_mode or not running:
        return
    if training_panel_open:
        close_training_panel()
    else:
        open_training_panel()

func open_training_panel() -> void:
    if not training_mode or hud == null:
        return
    close_link_pack()
    if training_panel == null or not is_instance_valid(training_panel):
        training_panel = TrainingPanelScript.new()
        training_panel.name = "TrainingCampPanel"
        training_panel.z_index = 90
        training_panel.closed.connect(close_training_panel)
        training_panel.exit_training_requested.connect(exit_training_camp)
        training_panel.open_links_requested.connect(func():
            close_training_panel()
            paused = false
            if hud != null and hud.screen not in ["combat", "link_pack", "shop", ""]:
                hud.hide_menu()
            open_link_pack()
        )
        hud.root.add_child(training_panel)
        training_panel.setup(self)
    else:
        training_panel.visible = true
        training_panel.refresh()
    training_panel_open = true
    audio.set_paused(true)

func close_training_panel() -> void:
    training_panel_open = false
    if training_panel != null and is_instance_valid(training_panel):
        training_panel.visible = false
    if running and not paused and not shop_open and not link_pack_open:
        audio.set_paused(false)

func exit_training_camp() -> void:
    close_training_panel()
    training_mode = false
    if hud != null and hud.has_method("set_training_mode"):
        hud.set_training_mode(false)
    go_home()

func training_set_weapon_level(weapon_id: String, target_level: int) -> void:
    if not Catalog.WEAPONS.has(weapon_id):
        return
    var clamped: int = clampi(target_level, 1, Growth.MAX_WEAPON_LEVEL)
    var existing_idx: int = -1
    for i in range(inventory.size()):
        if str(inventory[i].get("id", "")) == weapon_id:
            existing_idx = i
            break
    if existing_idx >= 0:
        inventory[existing_idx]["level"] = clamped
        bind_weapon_view(weapon_id)
    else:
        if inventory.size() >= 6:
            return
        grant_weapon(weapon_id, clamped)
    available_links = Rules.link_options(Catalog.inventory_ids(inventory))
    refresh_stats()
    update_hud()

func training_remove_weapon(weapon_id: String) -> void:
    for i in range(inventory.size() - 1, -1, -1):
        if str(inventory[i].get("id", "")) == weapon_id:
            inventory.remove_at(i)
            break
    if weapon_views.has(weapon_id):
        if is_instance_valid(weapon_views[weapon_id]):
            weapon_views[weapon_id].queue_free()
        weapon_views.erase(weapon_id)
    weapon_runtime.erase(weapon_id)
    if armory != null:
        armory.states.erase(weapon_id)
    var keep_links: Array = []
    for recipe in active_links:
        if not recipe.get("weapons", []).has(weapon_id):
            keep_links.append(str(recipe.get("id", "")))
    apply_links(keep_links)
    available_links = Rules.link_options(Catalog.inventory_ids(inventory))
    refresh_stats()
    update_hud()

func training_set_buff(buff_id: String, target_level: int) -> void:
    if not Growth.BUFFS.has(buff_id):
        return
    buff_levels[buff_id] = maxi(0, target_level)
    refresh_stats()
    if buff_id == "vitality":
        player_hp = float(stats["max_hp"])
    update_hud()

func training_set_enemy_wave(target_wave: int) -> void:
    training_enemy_wave = target_wave
    wave = target_wave if target_wave > 0 else 10
    update_hud()

func training_spawn(pack_kind: String, count: int) -> void:
    var n: int = maxi(1, count)
    wave = training_enemy_wave if training_enemy_wave > 0 else 10
    var spawned: Array = []
    if pack_kind == "boss":
        var pos: Vector2 = player_position + Vector2(260.0, 0.0)
        spawn_enemy("boss", pos, false, "instant")
        if not enemies.is_empty():
            spawned.append(enemies.back())
    elif pack_kind == "elite":
        var pos: Vector2 = player_position + Vector2(220.0, -30.0)
        spawn_enemy("tank", pos, true, "instant")
        if not enemies.is_empty():
            spawned.append(enemies.back())
    else:
        var pool: Array = ["hunter", "raptor", "charger", "spitter"] if pack_kind == "mixed" else ["tank", "charger", "spitter", "reedspitter", "cindertusk"]
        for i in range(n):
            var a: float = TAU * float(i) / float(n) + rng.randf_range(-0.2, 0.2)
            var d: float = rng.randf_range(210.0, 310.0)
            var kind: String = str(pool[i % pool.size()])
            spawn_enemy(kind, player_position + Vector2(cos(a) * d, sin(a) * d * 0.78), false, "instant")
            if not enemies.is_empty():
                spawned.append(enemies.back())
    if training_enemy_wave == 0:
        for e in spawned:
            e["hp"] = 100000.0
            e["max_hp"] = 100000.0
            if is_instance_valid(e.get("view", null)):
                e["view"].health_fraction = 1.0
