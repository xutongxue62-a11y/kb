extends SceneTree

var checks: int = 0
var failures: int = 0
var roster
var art

# This harness implements only the world boundary consumed by EnemyRoster. The
# main scene remains responsible for collision, invulnerability and movement.
class CombatWorld:
    extends RefCounted
    var player_position: Vector2 = Vector2(170, 0)
    var projectiles: Array = []
    var effects = null
    var audio = null
    var hp: float = 8.0
    var hits: Array = []
    func hurt_player(direction: Vector2, damage: float = 1.0) -> void:
        hp -= damage
        hits.append({"direction": direction, "damage": damage})

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func _initialize() -> void:
    seed(121511)
    for path in ["res://src/enemy_roster.gd", "res://src/enemy_art.gd"]:
        expect(FileAccess.file_exists(path), "v0.12 enemy module exists: " + path)
    if failures > 0:
        finish()
        return
    roster = load("res://src/enemy_roster.gd")
    art = load("res://src/enemy_art.gd")
    call_deferred("run_checks")

func make_enemy(kind: String, point: Vector2 = Vector2.ZERO) -> Dictionary:
    return {"id": 17, "kind": kind, "position": point, "state": "walk", "timer": 0.0,
        "direction": Vector2.RIGHT, "attack_cycle": 0, "slam_at": point,
        "knock": Vector2(18, -3), "velocity": Vector2.ZERO, "hp": 100.0,
        "radius": float(roster.NEW_DATA[kind]["radius"]), "damage": roster.base_damage(kind),
        "speed_multiplier": 1.0, "bullet_multiplier": 1.0}

func tick(world, enemy: Dictionary, delta: float, move: bool = true) -> Dictionary:
    enemy["timer"] -= delta
    var result: Dictionary = roster.advance(world, enemy, delta)
    if move and result.get("handled", false):
        enemy["position"] += result["velocity"] * float(enemy["speed_multiplier"]) * delta
    return result

func until_state(world, enemy: Dictionary, state: String, maximum: float = 3.0) -> float:
    var spent: float = 0.0
    while enemy["state"] != state and spent < maximum:
        tick(world, enemy, 0.01)
        spent += 0.01
    expect(enemy["state"] == state, enemy["kind"] + " reaches " + state + " within its attack cycle")
    return spent

func run_checks() -> void:
    check_pools_and_growth()
    check_delegation_and_timing()
    check_raptor()
    check_thrower()
    check_armored()
    check_art()
    finish()

func check_pools_and_growth() -> void:
    var first: Array = roster.spawn_pool(1, 0.0, false, false)
    expect(first.all(func(kind): return kind == "hunter"), "opening twelve seconds remain hunter-only")
    expect(not roster.spawn_pool(1, 18.0, false, false).has("raptor"), "ordinary first wave does not frontload the three new attacks")
    expect(roster.spawn_pool(2, 31.0, false, false).has("raptor"), "second wave introduces the lateral pouncer")
    expect(not roster.spawn_pool(2, 31.0, false, false).has("thrower"), "stone fans arrive after the pouncer has been introduced")
    expect(roster.spawn_pool(3, 61.0, false, false).has("thrower"), "third wave introduces fan-shaped ranged pressure")
    var all_regular: Array = roster.spawn_pool(4, 91.0, false, false)
    for kind in ["hunter", "charger", "spitter", "tank", "raptor", "thrower", "armored"]:
        expect(all_regular.has(kind), "ordinary spawn pool can actually select " + kind)
        expect(roster.spawn_pool(1, 0.0, true, false).has(kind), "trial mode makes " + kind + " available without waiting")
    expect(not all_regular.has("boss") and not roster.spawn_pool(10, 300.0, false, true).has("boss"), "boss remains an explicit round spawn, never a random ordinary pick")
    expect(not roster.spawn_pool(5, 120.0, false, true).has("armored"), "boss adds do not stack another heavy quake onto the boss")
    var progression = load("res://src/progression.gd")
    for kind in ["raptor", "thrower", "armored"]:
        var opening: Dictionary = progression.enemy_profile(1, kind)
        var later: Dictionary = progression.enemy_profile(20, kind, 1.65, true)
        expect(is_equal_approx(opening["hp"], float(roster.NEW_DATA[kind]["hp"])), kind + " can receive a real profile before Catalog integration")
        expect(is_equal_approx(opening["damage"], float(roster.base_damage(kind))), kind + " base damage is used by progression")
        expect(later["hp"] > opening["hp"] and later["damage"] > opening["damage"], kind + " participates in wave and elite growth")
        var endless: Dictionary = progression.enemy_profile(10000, kind, 1.65, true)
        expect(is_finite(endless["hp"]) and is_finite(endless["damage"]) and endless["speed_multiplier"] <= 1.35, kind + " endless growth remains finite and bounded in speed")
    expect(progression.enemy_profile(20, "armored")["dodge"] < progression.enemy_profile(20, "raptor")["dodge"], "heavy armor does not acquire the agile creature's full dodge")
    expect(is_equal_approx(progression.enemy_profile(1, "hunter")["hp"], 5.0), "existing hunter starting balance is preserved")
    expect(is_equal_approx(progression.estimate_power([{"id": "firepot", "level": 1}], {}), 7.268181818), "firepot build power accounts for all six fire ticks instead of a single impact")
    expect(is_equal_approx(progression.estimate_power([{"id": "wardrum", "level": 1}], {}), 6.677142857), "wardrum build power accounts for all three physical beats")

func check_delegation_and_timing() -> void:
    var world = CombatWorld.new()
    var original: Dictionary = {"kind": "charger", "state": "walk", "timer": 0.5}
    var before: Dictionary = original.duplicate(true)
    expect(not roster.advance(world, original, 0.1).get("handled", true) and original == before, "existing enemy kinds fall through without any mutation")
    var enemy: Dictionary = make_enemy("raptor")
    enemy["state"] = "raptor_aim"
    enemy["timer"] = 0.4
    enemy["direction"] = Vector2.RIGHT
    var point: Vector2 = enemy["position"]
    var knock: Vector2 = enemy["knock"]
    var result: Dictionary = roster.advance(world, enemy, 0.1)
    expect(result["handled"] and is_equal_approx(enemy["timer"], 0.4), "advance uses Main's already-decremented timer without stepping it twice")
    expect(enemy["position"] == point and enemy["knock"] == knock, "advance leaves all physical movement and knock decay to Main")
    expect(result["velocity"] == Vector2.ZERO and result.get("pose", "") == "windup", "pounce aiming exposes a readable stationary anticipation pose")

func check_raptor() -> void:
    var world = CombatWorld.new()
    var enemy: Dictionary = make_enemy("raptor")
    var result: Dictionary = tick(world, enemy, 0.01, false)
    expect(enemy["state"] == "raptor_step" and absf(result["velocity"].y) > 80 and absf(result["velocity"].x) < 0.01, "raptor begins by moving laterally rather than duplicating charger pursuit")
    until_state(world, enemy, "raptor_aim")
    var locked: Vector2 = enemy["direction"]
    var marker: Dictionary = roster.warning(enemy)
    expect(marker.get("kind", "") == "lane" and marker["end"].distance_to(marker["origin"]) > 125.0, "pounce anticipation announces its complete physical travel lane")
    world.player_position = Vector2(-400, 200)
    var aim_time: float = until_state(world, enemy, "raptor_lunge")
    expect(aim_time >= 0.56 and enemy["direction"].is_equal_approx(locked), "pounce has at least half a second of warning and does not retarget after locking")
    var from: Vector2 = enemy["position"]
    until_state(world, enemy, "recover")
    expect(is_equal_approx(from.distance_to(enemy["position"]), 129.6), "pounce travels exactly its advertised base distance with no terminal-frame overshoot")
    expect(world.hits.is_empty() and world.projectiles.is_empty(), "pouncer delegates body contact to Main and never invents ranged or area hits")
    enemy = make_enemy("raptor")
    enemy["state"] = "raptor_lunge"
    enemy["direction"] = Vector2.RIGHT
    enemy["timer"] = 0.36
    enemy["speed_multiplier"] = 1.35
    var full_warning: Dictionary = roster.warning(enemy)
    var advertised: float = full_warning["origin"].distance_to(full_warning["end"])
    tick(world, enemy, 0.1)
    var remaining: Dictionary = roster.warning(enemy)
    expect(is_equal_approx(enemy["position"].length() + remaining["origin"].distance_to(remaining["end"]), advertised), "scaled lunge travel and remaining marker share the same total distance")

func check_thrower() -> void:
    var world = CombatWorld.new()
    var enemy: Dictionary = make_enemy("thrower")
    enemy["timer"] = 9.0
    world.player_position = Vector2(90, 0)
    expect(roster.advance(world, enemy, 0.1)["velocity"].x < 0.0, "thrower retreats when a player closes into its space")
    world.player_position = Vector2(420, 0)
    expect(roster.advance(world, enemy, 0.1)["velocity"].x > 0.0, "thrower approaches when beyond throwing range")
    world.player_position = Vector2(260, 0)
    expect(roster.advance(world, enemy, 0.1)["velocity"] == Vector2.ZERO, "thrower holds its firing distance instead of overlapping the player")
    enemy["timer"] = 0.0
    enemy["bullet_multiplier"] = 1.2
    tick(world, enemy, 0.01, false)
    expect(enemy["state"] == "thrower_aim" and world.projectiles.is_empty(), "thrower enters anticipation before emitting any harmful stones")
    var marker: Dictionary = roster.warning(enemy)
    expect(marker.get("kind", "") == "fan" and marker["directions"].size() == 3, "stone fan warning announces all three projectile directions")
    var origin: Vector2 = marker["origin"]
    var directions: Array = marker["directions"].duplicate()
    world.player_position = Vector2(-260, 0)
    for _step in range(65):
        tick(world, enemy, 0.01, false)
    expect(world.projectiles.is_empty(), "stone fan cannot hit during the first 650 milliseconds of warning")
    until_state(world, enemy, "recover")
    expect(world.projectiles.size() == 3, "one completed throw creates exactly three stones")
    if world.projectiles.size() == 3:
        for index in range(3):
            var projectile: Dictionary = world.projectiles[index]
            expect(projectile["position"].is_equal_approx(origin) and projectile["velocity"].normalized().is_equal_approx(directions[index]), "stone %d launches from the warned origin along its locked direction" % index)
            expect(is_equal_approx(projectile["velocity"].length(), 206.4) and projectile["radius"] >= 8.0 and projectile["kind"] == "hostile", "stone %d carries scaled speed and a real hostile collision payload" % index)
        expect(world.projectiles[0]["velocity"].y * world.projectiles[2]["velocity"].y < 0.0, "outer stones fan to opposite sides of the center stone")
        expect(is_equal_approx(marker["range"], 619.2), "fan warning range agrees with scaled projectile speed and lifetime")
    tick(world, enemy, 0.05, false)
    expect(world.projectiles.size() == 3, "the expired warning does not emit duplicate fans during recovery")

func check_armored() -> void:
    var world = CombatWorld.new()
    world.player_position = Vector2(100, 0)
    var enemy: Dictionary = make_enemy("armored")
    var result: Dictionary = tick(world, enemy, 0.01, false)
    expect(enemy["state"] == "armored_slam" and result["velocity"] == Vector2.ZERO, "armored beast plants its feet before a heavy attack")
    var marker: Dictionary = roster.warning(enemy)
    expect(marker.get("kind", "") == "circle" and is_equal_approx(marker["radius"], 112.0), "quake anticipation marks the exact area used for impact")
    for _step in range(90):
        tick(world, enemy, 0.01, false)
    expect(world.hp == 8.0 and world.hits.is_empty(), "quake has a readable nine-tenths second before any area damage")
    until_state(world, enemy, "recover")
    expect(world.hits.size() == 1 and is_equal_approx(world.hp, 6.25), "quake deals one physical area hit using the monster damage profile")
    tick(world, enemy, 0.2, false)
    expect(world.hits.size() == 1, "quake cannot repeat its hit during recovery")
    world = CombatWorld.new()
    world.player_position = Vector2(131, 0)
    enemy = make_enemy("armored")
    tick(world, enemy, 0.01, false)
    until_state(world, enemy, "recover")
    expect(world.hits.is_empty(), "player outside quake radius plus body radius escapes the attack")
    world = CombatWorld.new()
    world.player_position = Vector2(129, 0)
    enemy = make_enemy("armored")
    tick(world, enemy, 0.01, false)
    until_state(world, enemy, "recover")
    expect(world.hits.size() == 1, "player body intersecting the quake edge receives the advertised hit")
    world = CombatWorld.new()
    world.player_position = Vector2(500, 0)
    enemy = make_enemy("armored")
    result = roster.advance(world, enemy, 0.1)
    expect(result["velocity"].length() <= 30.0 and enemy["state"] == "walk", "heavy beast approaches slowly and cannot quake a distant player")

func check_art() -> void:
    var masks: Array = []
    var contact: Image = Image.create_empty(720, 360, false, Image.FORMAT_RGBA8)
    contact.fill(Color("#eadfc7"))
    var slot: int = 0
    for kind in ["raptor", "thrower", "armored"]:
        var texture: Texture2D = art.texture(kind)
        expect(texture != null, kind + " has an independently generated texture")
        if texture == null:
            continue
        var image: Image = texture.get_image()
        expect(not image.is_empty(), kind + " generated art has real pixels")
        var body: Vector2i = Vector2i(art.body_size(kind))
        expect(image.get_size() == body + Vector2i(128, 128), kind + " publishes unpadded body size separately from its outline quad")
        var bounds: Rect2i = image.get_used_rect()
        var margin: int = mini(mini(bounds.position.x, bounds.position.y), mini(image.get_width() - bounds.end.x, image.get_height() - bounds.end.y))
        expect(bounds.has_area() and margin >= 64, kind + " leaves at least 64 transparent pixels on every side for tight elite outlines")
        var mask: PackedByteArray = PackedByteArray()
        var opaque: int = 0
        var ink: int = 0
        var normalized: Image = image.get_region(bounds)
        normalized.resize(80, 80, Image.INTERPOLATE_NEAREST)
        for y in range(80):
            for x in range(80):
                var pixel: Color = normalized.get_pixel(x, y)
                mask.append(1 if pixel.a > 0.5 else 0)
                if pixel.a > 0.9:
                    opaque += 1
                    if pixel.r < 0.32 and pixel.g < 0.28 and pixel.b < 0.25:
                        ink += 1
        expect(opaque > 1800 and ink > 180, kind + " reads as substantial flat-fill art with a coarse dark outline")
        for previous in masks:
            var changed: int = 0
            for index in range(mask.size()):
                if mask[index] != previous[index]:
                    changed += 1
            expect(changed > 650, kind + " has a different silhouette rather than a recolored old species")
        masks.append(mask)
        var scaled: Image = image.duplicate()
        scaled.resize(220, 220, Image.INTERPOLATE_LANCZOS)
        contact.blend_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), Vector2i(10 + slot * 240, 70))
        slot += 1
        print("ENEMY ART METRIC: %s body=%s image=%s used=%s margin=%d" % [kind, body, image.get_size(), bounds, margin])
    if OS.get_cmdline_user_args().has("--write-art"):
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://runtime/tests/enemies_v12"))
        contact.save_png("res://runtime/tests/enemies_v12/three_species.png")
    expect(art.texture("unknown") == null, "unknown art keys fail closed instead of borrowing an existing monster image")

func finish() -> void:
    print("ENEMIES V12 RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)
