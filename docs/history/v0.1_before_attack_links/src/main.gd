extends Node2D

const Rules = preload("res://src/rules.gd")
const Catalog = preload("res://src/catalog.gd")
const AssetLibrary = preload("res://src/asset_library.gd")
const ActorView = preload("res://src/actor_view.gd")
const DinoView = preload("res://src/dino_view.gd")
const Effects = preload("res://src/effects.gd")
const Hud = preload("res://src/hud.gd")
const FIELD: Rect2 = Rect2(42, 147, 1196, 514)

var library
var actors: Node2D
var weapons_layer: Node2D
var hero
var effects
var hud
var inventory: Array = []
var weapon_views: Dictionary = {}
var weapon_runtime: Dictionary = {}
var enemies: Array = []
var projectiles: Array = []
var groups: Array = []
var counters: Dictionary = {}
var combo_cooldowns: Dictionary = {}
var upgrade_choices: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var player_position: Vector2 = Vector2(640, 401)
var player_hp: int = 8
var invulnerable: float = 0.0
var elapsed: float = 0.0
var kills: int = 0
var xp: int = 0
var xp_needed: int = 4
var player_level: int = 1
var enemy_serial: int = 0
var spawn_clock: float = 0.0
var running: bool = false
var paused: bool = false
var upgrade_pending: bool = false
var collapsed: bool = false
var combo_mode: String = "triple"
var prefer_elite: bool = false
var trial_mode: bool = false
var demo: bool = false
var animation_demo: bool = false
var combo_message: String = ""
var combo_message_time: float = 0.0
var demo_caption: String = ""
var demo_font: SystemFont
var demo_weapon: Sprite2D

func _ready() -> void:
    rng.seed = 2180411
    library = AssetLibrary.new()
    actors = Node2D.new()
    actors.y_sort_enabled = true
    add_child(actors)
    hero = ActorView.new()
    hero.setup(library)
    actors.add_child(hero)
    hero.position = player_position
    weapons_layer = Node2D.new()
    weapons_layer.z_index = 25
    add_child(weapons_layer)
    effects = Effects.new()
    effects.z_index = 35
    add_child(effects)
    hud = Hud.new()
    add_child(hud)
    hud.setup(library)
    hud.start_requested.connect(start_run)
    hud.formation_requested.connect(switch_formation)
    hud.combo_requested.connect(switch_combo_mode)
    hud.elite_requested.connect(switch_elite)
    hud.trial_requested.connect(func(): start_run(true))
    hud.pause_requested.connect(toggle_pause)
    hud.restart_requested.connect(func(): start_run(false))
    hud.choice_selected.connect(on_choice)
    demo_font = SystemFont.new()
    demo_font.font_names = PackedStringArray(["Microsoft YaHei", "Arial"])
    var arguments: PackedStringArray = OS.get_cmdline_user_args()
    demo = arguments.has("--demo")
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
        DisplayServer.window_set_title("原始人大作战 · 六武器演示")
        start_run(true)
    update_hud()
    queue_redraw()

func start_run(trial: bool = false) -> void:
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
    player_position = Vector2(640, 401)
    player_hp = 8
    invulnerable = 1.0
    elapsed = 0.0
    kills = 0
    xp = 0
    xp_needed = 4
    player_level = 1
    spawn_clock = 0.8
    enemy_serial = 0
    paused = false
    upgrade_pending = false
    collapsed = false
    combo_mode = "triple"
    trial_mode = trial
    running = true
    combo_message_time = 0.0
    hero.scale = Vector2.ONE * (3.0 if animation_demo else 1.0)
    hero.phase = 0.0
    hero.amplitude = 0.0
    hero.position = player_position
    if trial:
        for key in Catalog.IDS:
            grant_weapon(key)
    else:
        grant_weapon("club")
    hud.hide_menu()
    if not animation_demo:
        spawn_enemy("hunter", Vector2(352, 258))
        spawn_enemy("hunter", Vector2(942, 525))
        if trial:
            spawn_enemy("charger", Vector2(1010, 274))
            spawn_enemy("spitter", Vector2(310, 560))
            spawn_enemy("tank", Vector2(1090, 530))
    update_hud()
    queue_redraw()

func grant_weapon(key: String) -> bool:
    var result: Dictionary = Rules.equip(inventory, key)
    if not result.get("accepted", false):
        return false
    if not weapon_views.has(key):
        var view: Sprite2D = library.make_weapon(key, Catalog.WEAPONS[key]["size"])
        weapons_layer.add_child(view)
        weapon_views[key] = view
        weapon_runtime[key] = {"position": player_position, "cooldown": 0.15, "hit_times": {}, "initialized": false, "recoil": 0.0}
    rebuild_groups()
    return true

func rebuild_groups() -> void:
    var ids: Array = []
    for item in inventory:
        ids.append(item["id"])
    groups = Rules.combo_groups(ids, combo_mode)
    counters.clear()

func switch_formation() -> void:
    if upgrade_pending:
        return
    collapsed = not collapsed
    update_hud()

func switch_combo_mode() -> void:
    if upgrade_pending:
        return
    combo_mode = "pair" if combo_mode == "triple" else "triple"
    rebuild_groups()
    update_hud()

func switch_elite() -> void:
    prefer_elite = not prefer_elite
    update_hud()

func toggle_pause() -> void:
    if not running or upgrade_pending or animation_demo:
        return
    paused = not paused
    if paused:
        hud.show_menu("pause", kills)
    else:
        hud.hide_menu()

func finish_run(won: bool) -> void:
    running = false
    paused = false
    upgrade_pending = false
    hud.show_menu("win" if won else "lose", kills)
    update_hud()

func present_upgrade() -> void:
    if upgrade_pending or not running:
        return
    var pool: Array = []
    for key in Catalog.IDS:
        var level: int = 0
        for item in inventory:
            if item["id"] == key:
                level = item["level"]
        if level < 5:
            pool.append(key)
    if pool.is_empty():
        xp = 0
        player_hp = mini(8, player_hp + 2)
        return
    pool.shuffle()
    upgrade_choices = pool.slice(0, mini(3, pool.size()))
    upgrade_pending = true
    hud.show_choices(upgrade_choices, inventory)

func on_choice(key: String) -> void:
    if not upgrade_pending or not upgrade_choices.has(key):
        return
    if not grant_weapon(key):
        return
    xp = maxi(0, xp - xp_needed)
    player_level += 1
    xp_needed = 4 + player_level * 2
    player_hp = mini(8, player_hp + 1)
    upgrade_pending = false
    upgrade_choices.clear()
    hud.hide_menu()
    update_hud()

func update_hud() -> void:
    if hud == null:
        return
    hud.update_state(player_hp, elapsed, kills, xp, xp_needed, inventory, collapsed, combo_mode, prefer_elite, groups, trial_mode)
    if combo_message_time > 0.0:
        hud.notice_label.text = combo_message

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    match event.physical_keycode:
        KEY_F2:
            start_run(true)
        KEY_SPACE:
            switch_formation()
        KEY_Q:
            switch_combo_mode()
        KEY_E:
            switch_elite()
        KEY_R:
            start_run(trial_mode)
        KEY_ESCAPE:
            toggle_pause()
        KEY_1:
            hud.choose_index(0)
        KEY_2:
            hud.choose_index(1)
        KEY_3:
            hud.choose_index(2)

func _physics_process(delta: float) -> void:
    var movement: Vector2 = Vector2.ZERO
    if demo:
        var desired: Vector2 = Vector2(640 + sin(elapsed * 0.65) * 188, 403 + sin(elapsed * 1.15) * 100)
        if player_position.distance_to(desired) > 6:
            movement = (desired - player_position).normalized()
        collapsed = fmod(elapsed, 12.0) > 6.0
        var wanted_mode: String = "pair" if fmod(elapsed, 20.0) > 10.0 else "triple"
        if combo_mode != wanted_mode:
            combo_mode = wanted_mode
            rebuild_groups()
    else:
        movement.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
        movement.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
    simulate(delta, movement)

func simulate(delta: float, movement: Vector2) -> void:
    if animation_demo:
        animate_showcase(delta)
        return
    if not running or paused or upgrade_pending:
        return
    elapsed += delta
    invulnerable = maxf(0.0, invulnerable - delta)
    combo_message_time = maxf(0.0, combo_message_time - delta)
    var old_position: Vector2 = player_position
    var velocity: Vector2 = movement.limit_length(1.0) * 220.0
    player_position += velocity * delta
    player_position.x = clampf(player_position.x, FIELD.position.x + 40, FIELD.end.x - 40)
    player_position.y = clampf(player_position.y, FIELD.position.y + 40, FIELD.end.y - 52)
    hero.position = player_position
    hero.animate(velocity, old_position.distance_to(player_position), delta)
    effects.advance(delta)
    update_enemies(delta)
    if not running:
        update_hud()
        queue_redraw()
        return
    update_weapons(delta)
    update_projectiles(delta)
    if not running:
        update_hud()
        queue_redraw()
        return
    var living: Array = []
    for enemy in enemies:
        if enemy["hp"] > 0.0:
            living.append(enemy)
        else:
            enemy["view"].queue_free()
    enemies = living
    spawn_clock -= delta
    if spawn_clock <= 0.0 and enemies.size() < 42:
        spawn_clock = maxf(0.45, 1.0 - elapsed * 0.007)
        var kinds: Array = ["hunter", "hunter", "charger", "spitter", "tank"]
        var available_count: int = 2 if elapsed < 8.0 and not trial_mode else kinds.size()
        spawn_enemy(kinds[rng.randi_range(0, available_count - 1)])
    if elapsed >= 60.0:
        finish_run(true)
    elif xp >= xp_needed and not trial_mode and not demo:
        present_upgrade()
    update_hud()
    queue_redraw()

func spawn_enemy(kind: String, point: Vector2 = Vector2(-10000, -10000)) -> void:
    var data: Dictionary = Catalog.DINOS[kind]
    if point.x < -9999:
        match rng.randi_range(0, 3):
            0: point = Vector2(FIELD.position.x + 18, rng.randf_range(FIELD.position.y + 30, FIELD.end.y - 25))
            1: point = Vector2(FIELD.end.x - 18, rng.randf_range(FIELD.position.y + 30, FIELD.end.y - 25))
            2: point = Vector2(rng.randf_range(FIELD.position.x + 25, FIELD.end.x - 25), FIELD.position.y + 18)
            _: point = Vector2(rng.randf_range(FIELD.position.x + 25, FIELD.end.x - 25), FIELD.end.y - 18)
    enemy_serial += 1
    var elite: bool = enemy_serial % 9 == 0
    var hp: float = data["hp"] * (1.8 if elite else 1.0)
    var view = DinoView.new()
    view.setup(library, kind, data["size"] * (1.1 if elite else 1.0), elite)
    view.position = point
    actors.add_child(view)
    enemies.append({"id": enemy_serial, "kind": kind, "position": point, "hp": hp, "max_hp": hp, "elite": elite, "view": view, "radius": data["radius"], "state": "walk", "timer": rng.randf_range(1.0, 2.0), "direction": Vector2.RIGHT, "knock": Vector2.ZERO})

func update_enemies(delta: float) -> void:
    for enemy in enemies:
        if enemy["hp"] <= 0.0:
            continue
        var difference: Vector2 = player_position - enemy["position"]
        var distance: float = difference.length()
        var direction: Vector2 = difference.normalized()
        var velocity: Vector2 = direction * Catalog.DINOS[enemy["kind"]]["speed"]
        enemy["timer"] -= delta
        if enemy["kind"] == "charger":
            match enemy["state"]:
                "walk":
                    if distance < 245.0 and enemy["timer"] <= 0.0:
                        enemy["state"] = "windup"
                        enemy["timer"] = 0.65
                        enemy["direction"] = direction
                        velocity = Vector2.ZERO
                "windup":
                    velocity = Vector2.ZERO
                    if enemy["timer"] <= 0.0:
                        enemy["state"] = "dash"
                        enemy["timer"] = 0.4
                "dash":
                    velocity = enemy["direction"] * 560.0
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
                    projectiles.append({"position": enemy["position"] + direction * 25, "velocity": direction * 190, "damage": 1.0, "kind": "hostile", "life": 4.5, "radius": 6.5, "weapon_id": "", "from_combo": false})
                    enemy["state"] = "walk"
                    enemy["timer"] = 2.1
            elif distance < 395 and enemy["timer"] <= 0.0:
                enemy["state"] = "spit"
                enemy["timer"] = 0.4
        if enemy["state"] == "walk":
            var separation: Vector2 = Vector2.ZERO
            for other in enemies:
                if other["id"] == enemy["id"] or other["hp"] <= 0.0:
                    continue
                var offset: Vector2 = enemy["position"] - other["position"]
                if offset.length_squared() < 1500.0 and offset.length_squared() > 0.01:
                    separation += offset.normalized() * 28.0
            velocity += separation.limit_length(48)
        velocity += enemy["knock"]
        enemy["knock"] = enemy["knock"].move_toward(Vector2.ZERO, delta * 270.0)
        enemy["position"] += velocity * delta
        enemy["position"].x = clampf(enemy["position"].x, FIELD.position.x + 8, FIELD.end.x - 8)
        enemy["position"].y = clampf(enemy["position"].y, FIELD.position.y + 10, FIELD.end.y - 10)
        enemy["view"].position = enemy["position"]
        enemy["view"].health_fraction = enemy["hp"] / enemy["max_hp"]
        enemy["view"].animate(velocity, delta, enemy["state"])
        if enemy["position"].distance_to(player_position) < enemy["radius"] + 18.0:
            hurt_player((player_position - enemy["position"]).normalized())
            if not running:
                break

func update_weapons(delta: float) -> void:
    var melee_items: Array = []
    var ranged_items: Array = []
    for item in inventory:
        if Catalog.WEAPONS[item["id"]]["kind"] == "melee":
            melee_items.append(item)
        else:
            ranged_items.append(item)
    var slot_order: Array = []
    for index in range(maxi(melee_items.size(), ranged_items.size())):
        if index < melee_items.size():
            slot_order.append(melee_items[index]["id"])
        if index < ranged_items.size():
            slot_order.append(ranged_items[index]["id"])
    for index in range(melee_items.size()):
        var item: Dictionary = melee_items[index]
        var key: String = item["id"]
        var runtime: Dictionary = weapon_runtime[key]
        var data: Dictionary = Catalog.WEAPONS[key]
        var point: Vector2 = player_position + Rules.orbit_position(slot_order.find(key), slot_order.size(), elapsed * 4.6, collapsed)
        var previous: Vector2 = runtime["position"] if runtime["initialized"] else point
        runtime["position"] = point
        runtime["initialized"] = true
        var view: Sprite2D = weapon_views[key]
        view.position = point
        var intrinsic: float = PI / 2.0 if key == "axe" else PI / 4.0
        view.rotation = (point - player_position).angle() + PI / 2.0 + intrinsic
        for enemy in enemies:
            if enemy["hp"] <= 0.0:
                continue
            var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy["position"], previous, point)
            if nearest.distance_to(enemy["position"]) > enemy["radius"] + 13.0:
                continue
            if float(runtime["hit_times"].get(enemy["id"], -INF)) > elapsed:
                continue
            runtime["hit_times"][enemy["id"]] = elapsed + data["cooldown"]
            var damage: float = data["damage"] * (1.0 + (item["level"] - 1) * 0.35)
            hurt_enemy(enemy, damage, key, false, (enemy["position"] - player_position).normalized())
            hero.recoil((point - player_position).normalized())
    for index in range(ranged_items.size()):
        var item: Dictionary = ranged_items[index]
        var key: String = item["id"]
        var runtime: Dictionary = weapon_runtime[key]
        var data: Dictionary = Catalog.WEAPONS[key]
        var angle: float = elapsed * 4.6 + float(slot_order.find(key)) * TAU / maxf(1.0, slot_order.size())
        var point: Vector2 = player_position + Vector2.from_angle(angle) * 93.0
        runtime["position"] = point
        runtime["cooldown"] -= delta
        runtime["recoil"] = maxf(0.0, runtime["recoil"] - delta)
        var attack_range: float = data["range"]
        if key == "staff":
            attack_range = 365.0 if collapsed else 265.0
        var target: Dictionary = Rules.choose_target(point, attack_range, enemies, prefer_elite)
        var direction: Vector2 = (target["position"] - point).normalized() if not target.is_empty() else Vector2.from_angle(angle)
        var view: Sprite2D = weapon_views[key]
        view.position = point - direction * runtime["recoil"] * 24.0
        view.rotation = direction.angle() + (0.0 if key == "powder" else PI / 2.0)
        if target.is_empty() or runtime["cooldown"] > 0.0:
            continue
        runtime["cooldown"] = data["cooldown"] / (1.0 + (item["level"] - 1) * 0.08)
        runtime["recoil"] = 0.12
        hero.recoil(direction)
        var damage: float = data["damage"] * (1.0 + (item["level"] - 1) * 0.35)
        if key == "staff":
            var spread: float = 0.055 if collapsed else 0.24
            for offset in [-1, 0, 1]:
                fire_projectile(point, direction.rotated(float(offset) * spread), key, damage, attack_range)
        else:
            fire_projectile(point, direction, key, damage, attack_range)

func fire_projectile(point: Vector2, direction: Vector2, key: String, damage: float, attack_range: float, from_combo: bool = false) -> void:
    var speed: float = Catalog.WEAPONS[key]["speed"]
    projectiles.append({"position": point + direction * 19.0, "velocity": direction * speed, "damage": damage, "kind": key, "weapon_id": key, "life": attack_range / speed, "radius": 6.5 if key == "powder" else 4.5, "from_combo": from_combo})

func update_projectiles(delta: float) -> void:
    var remaining: Array = []
    for projectile in projectiles:
        var previous: Vector2 = projectile["position"]
        projectile["position"] += projectile["velocity"] * delta
        projectile["life"] -= delta
        var consumed: bool = false
        if projectile["kind"] == "hostile":
            var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(player_position, previous, projectile["position"])
            if nearest.distance_to(player_position) < projectile["radius"] + 19.0:
                hurt_player(projectile["velocity"].normalized())
                consumed = true
        else:
            for enemy in enemies:
                if enemy["hp"] <= 0.0:
                    continue
                var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy["position"], previous, projectile["position"])
                if nearest.distance_to(enemy["position"]) > enemy["radius"] + projectile["radius"]:
                    continue
                if projectile["kind"] == "powder":
                    damage_area(projectile["position"], 73.0, projectile["damage"], "powder", projectile["from_combo"], Color("#d2a15d"))
                else:
                    hurt_enemy(enemy, projectile["damage"], projectile["weapon_id"], projectile["from_combo"], projectile["velocity"].normalized())
                consumed = true
                break
        if not consumed and projectile["life"] <= 0.0 and projectile["kind"] == "powder":
            damage_area(projectile["position"], 73.0, projectile["damage"], "powder", projectile["from_combo"], Color("#d2a15d"))
        if not consumed and projectile["life"] > 0.0:
            remaining.append(projectile)
    projectiles = remaining

func hurt_enemy(enemy: Dictionary, damage: float, weapon_id: String, from_combo: bool, direction: Vector2) -> void:
    if enemy["hp"] <= 0.0:
        return
    enemy["hp"] = maxf(0.0, enemy["hp"] - damage)
    enemy["knock"] += direction * (95.0 if weapon_id == "club" else 42.0)
    enemy["view"].hit()
    effects.burst(enemy["position"], Color("#f8e9bd"), 9.0)
    if enemy["hp"] <= 0.0:
        kills += 1
        xp += 1
        effects.burst(enemy["position"], Color("#c4b47a"), 20.0, "ring")
    var triggered: Array = Rules.advance_combos(counters, {"weapon_id": weapon_id, "from_combo": from_combo}, groups)
    for group in triggered:
        trigger_combo(group, enemy["position"])

func damage_area(point: Vector2, radius: float, damage: float, weapon_id: String, from_combo: bool, color: Color) -> void:
    effects.burst(point, color, radius, "ring")
    for enemy in enemies:
        if enemy["hp"] > 0.0 and enemy["position"].distance_to(point) < radius + enemy["radius"]:
            hurt_enemy(enemy, damage, weapon_id, from_combo, (enemy["position"] - point).normalized())

func trigger_combo(group: Dictionary, hit_position: Vector2) -> void:
    if float(combo_cooldowns.get(group["id"], -INF)) > elapsed:
        return
    combo_cooldowns[group["id"]] = elapsed + 0.5
    combo_message = "联动 · " + group["name"]
    combo_message_time = 1.6
    match group["id"]:
        "break":
            damage_area(player_position, 126.0, 3.3, "club", true, group["color"])
        "quake":
            damage_area(player_position, 181.0, 5.5, "axe", true, group["color"])
        "hunt":
            var target: Dictionary = Rules.choose_target(hit_position, 235.0, enemies)
            if not target.is_empty():
                effects.beam(player_position, target["position"], group["color"])
                hurt_enemy(target, 5.0, "sling", true, (target["position"] - player_position).normalized())
        "rune":
            damage_area(hit_position, 98.0, 5.0, "staff", true, group["color"])
        "wildfire":
            damage_area(hit_position, 132.0, 7.5, "staff", true, group["color"])
            effects.beam(player_position, hit_position, group["color"])

func hurt_player(direction: Vector2) -> void:
    if not running or invulnerable > 0.0 or demo or animation_demo:
        return
    player_hp -= 1
    invulnerable = 0.7
    hero.hurt()
    effects.burst(player_position, Color("#bd7356"), 18.0, "ring")
    player_position += direction * 8.0
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
            effects.burst(player_position + Vector2(145, 0), Color("#d6b672"), 18.0)
    player_position += velocity * delta
    hero.position = player_position
    hero.animate(velocity, velocity.length() * delta, delta)
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
    draw_rect(Rect2(0, 0, 1280, 800), Color("#c3c59b"))
    var ground: StyleBoxFlat = StyleBoxFlat.new()
    ground.bg_color = Color("#e3ddba")
    ground.set_corner_radius_all(46)
    draw_style_box(ground, FIELD.grow(13))
    for index in range(7):
        var point: Vector2 = Vector2(115 + index * 162, 202 + fmod(index * 103.0, 370.0))
        draw_set_transform(point, 0.0, Vector2(1.7, 0.55))
        draw_circle(Vector2.ZERO, 24.0 + index % 3 * 5, Color(0.74, 0.67, 0.43, 0.15))
    draw_set_transform(Vector2.ZERO)
    for point in [Vector2(83, 190), Vector2(1210, 204), Vector2(72, 600), Vector2(1210, 613), Vector2(236, 648)]:
        draw_grass(point, 15.0)
    for point in [Vector2(116, 625), Vector2(1190, 170), Vector2(78, 165), Vector2(1168, 642)]:
        draw_set_transform(point, 0.0, Vector2(1.3, 0.8))
        draw_circle(Vector2.ZERO, 17.0, Color("#aaa08c"))
        draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 20, Color("#918570"), 2.0, true)
    draw_set_transform(Vector2.ZERO)
    if animation_demo:
        draw_string(demo_font, Vector2(64, 67), "原始人 · 动作预览", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#543b2c"))
        draw_string(demo_font, Vector2(360, 185), demo_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#64513a"))
        draw_string(demo_font, Vector2(325, 715), "同一角色的身体、双手、双脚独立运动", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#766449"))
    for enemy in enemies:
        if enemy["hp"] <= 0.0:
            continue
        if enemy["state"] == "windup" or enemy["state"] == "dash":
            var start: Vector2 = enemy["position"]
            var direction: Vector2 = enemy["direction"]
            var end: Vector2 = start + direction * (224.0 if enemy["state"] == "windup" else maxf(enemy["timer"], 0.0) * 560.0)
            var normal: Vector2 = direction.orthogonal() * 17.0
            var polygon: PackedVector2Array = PackedVector2Array([start - normal, end - normal, end - normal * 1.5, end + direction * 19.0, end + normal * 1.5, end + normal, start + normal])
            draw_colored_polygon(polygon, Color(0.78, 0.36, 0.25, 0.14))
            var outline: PackedVector2Array = polygon.duplicate()
            outline.append(polygon[0])
            draw_polyline(outline, Color(0.76, 0.36, 0.25, 0.62), 2.0, true)
        elif enemy["state"] == "spit":
            draw_arc(enemy["position"] + (player_position - enemy["position"]).normalized() * 28.0, 9.0, 0.0, TAU, 24, Color("#ca8a60"), 2.5, true)
    for projectile in projectiles:
        var point: Vector2 = projectile["position"]
        var direction: Vector2 = projectile["velocity"].normalized()
        match projectile["kind"]:
            "hostile":
                draw_circle(point, 6.5, Color("#c97c61"))
                draw_arc(point, 6.5, 0.0, TAU, 16, Color("#684334"), 1.7, true)
            "powder":
                draw_line(point - direction * 16, point, Color("#ddad68"), 3.0, true)
                draw_circle(point, 6.0, Color("#a56843"))
                draw_arc(point, 6.0, 0.0, TAU, 14, Color("#654833"), 1.5, true)
            "staff":
                var normal: Vector2 = direction.orthogonal()
                draw_colored_polygon(PackedVector2Array([point + direction * 8, point + normal * 4, point - direction * 6, point - normal * 4]), Color("#a6c2a4"))
                draw_line(point - direction * 13, point - direction * 4, Color("#d4ddbc"), 1.8, true)
            _:
                draw_line(point - direction * 10, point, Color("#f4e1b1"), 3.0, true)
                draw_circle(point, 4.5, Color("#eee0b8"))
                draw_arc(point, 4.5, 0.0, TAU, 12, Color("#806748"), 1.2, true)
