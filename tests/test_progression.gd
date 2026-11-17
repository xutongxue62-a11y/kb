extends SceneTree

var checks: int = 0
var failures: int = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func clear_enemies(world: Node) -> void:
    for enemy in world.enemies:
        enemy["view"].queue_free()
    world.enemies.clear()
    world.projectiles.clear()

func _initialize() -> void:
    if not FileAccess.file_exists("res://src/progression.gd"):
        expect(false, "endless enemy growth, evasion and bounded build adaptation are not implemented")
        finish()
        return
    call_deferred("run_checks")

func run_checks() -> void:
    var progression = load("res://src/progression.gd")
    var first: Dictionary = progression.enemy_profile(1, "hunter")
    expect(is_equal_approx(first["hp"], 5.0) and is_equal_approx(first["damage"], 1.0) and is_zero_approx(first["dodge"]), "opening preserves weak ordinary enemies and zero random evasion")
    var fourth: Dictionary = progression.enemy_profile(4, "hunter")
    var fifth: Dictionary = progression.enemy_profile(5, "hunter")
    expect(fifth["hp"] > fourth["hp"] * 1.35 and fifth["damage"] > fourth["damage"] * 1.1, "fifth wave is a real HP and damage milestone")
    var tenth: Dictionary = progression.enemy_profile(10, "hunter")
    expect(tenth["hp"] > fifth["hp"] and tenth["damage"] > fifth["damage"] and tenth["dodge"] > fifth["dodge"], "later enemies grow in HP, damage and evasion independently")
    var elite: Dictionary = progression.enemy_profile(10, "hunter", 1.0, true)
    expect(elite["hp"] > tenth["hp"] and elite["damage"] > tenth["damage"], "elites have both durability and damage premiums")
    expect(progression.enemy_profile(10, "tank")["dodge"] < tenth["dodge"], "heavy enemies do not inherit agile enemies' full evasion")
    var late: Dictionary = progression.enemy_profile(10000, "hunter", 1.65, true)
    expect(is_finite(late["hp"]) and is_finite(late["damage"]) and late["dodge"] <= 0.30 and late["speed_multiplier"] <= 1.35, "arbitrarily late wave values stay finite and evasion/speed bounded")
    var weak: float = progression.estimate_power([{"id":"sling", "level":1}], {})
    var strong: float = progression.estimate_power([{"id":"sling", "level":5}, {"id":"club", "level":5}], {"power":3,"haste":3,"crit_chance":3,"crit_power":3,"pet":3})
    expect(strong > weak * 3.0, "build estimate includes weapon levels, passive stats and followers")
    var scaling: float = progression.adaptation(5, strong, 1.0)
    expect(scaling > 1.0 and scaling <= 1.65, "strong builds influence milestones without one-for-one damage cancellation")
    expect(progression.adaptation(10, weak, scaling) >= scaling, "a later milestone does not lower an already established monster baseline")
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/progression_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.demo = true
    world.start_run(false)
    clear_enemies(world)
    world.spawn_clock = 999.0
    world.elapsed = 89.99
    world.wave = 3
    world.wave_elapsed = 29.99
    world.simulate(0.02, Vector2.ZERO)
    world.simulate(world.WAVE_BUFFER+0.01,Vector2.ZERO)
    expect(world.running and world.wave == 4 and world.hud.timer_label.text.contains("4"), "crossing ninety seconds continues into wave four instead of ending")
    world.start_run(true)
    clear_enemies(world)
    world.wave = 4
    world.elapsed = 119.99
    world.spawn_clock = 999.0
    world.spawn_enemy("hunter", world.player_position + Vector2(520, 0))
    world.enemies[0]["hp"] = world.enemies[0]["max_hp"] * 0.5
    world.advance_wave(5)
    expect(world.wave == 5 and world.enemy_adaptation > 1.0, "real fifth wave samples the six-weapon build and strengthens enemies")
    expect(is_equal_approx(world.enemies[0]["hp"] / world.enemies[0]["max_hp"], 0.5), "wave strengthening preserves existing enemies' remaining HP fraction")
    world.start_run(false)
    clear_enemies(world)
    world.spawn_enemy("tank", world.player_position + Vector2(100, 0))
    world.enemies[0]["hp"] = 100.0
    world.enemies[0]["max_hp"] = 100.0
    world.enemies[0]["dodge"] = 1.0
    world.stats["crit_chance"] = 0.0
    world.hurt_enemy(world.enemies[0], 10.0, "sling", false, Vector2.RIGHT)
    expect(is_equal_approx(world.enemies[0]["hp"], 100.0) and world.effects.particles.any(func(item): return item.get("text", "") == "敌闪避"), "actual enemy evasion prevents damage and produces an explicit enemy-miss label")
    world.apply_buff("accuracy")
    world.apply_buff("accuracy")
    world.apply_buff("accuracy")
    world.stats["crit_chance"] = 0.0
    world.enemies[0]["dodge"] = 0.12
    world.hurt_enemy(world.enemies[0], 10.0, "sling", false, Vector2.RIGHT)
    expect(is_equal_approx(world.enemies[0]["hp"], 90.0), "three accuracy levels counter twelve percentage points of enemy evasion")
    world.enemies[0]["dodge"] = 1.0
    world.damage_area(world.enemies[0]["position"], 63.0, 5.0, "powder", true, Color.ORANGE)
    expect(is_equal_approx(world.enemies[0]["hp"], 85.0), "area explosions cannot randomly miss an enemy standing inside them")
    world.start_run(false)
    clear_enemies(world)
    world.demo = false
    world.wave = 10
    world.spawn_enemy("spitter", world.player_position + Vector2(200, 0))
    var damage: float = world.enemies[0]["damage"]
    world.invulnerable = 0.0
    world.hurt_player(Vector2.ZERO, damage)
    expect(damage > 1.0 and is_equal_approx(world.player_hp, 8.0 - damage), "later enemy profile damage reaches the real player health calculation")
    world.start_run(false)
    world.demo = false
    world.stats["dodge"] = 0.0
    world.stats["reduction"] = 0.0
    world.invulnerable = 0.0
    var cap: float = progression.HIT_CAP_RATIO * float(world.stats["max_hp"])
    world.player_hp = world.stats["max_hp"]
    world.hurt_player(Vector2.ZERO, 100.0, false)
    expect(is_equal_approx(world.player_hp, world.stats["max_hp"] - cap) and world.running, "regular combat hits are capped at 70% of max HP")
    world.invulnerable = 0.0
    world.player_hp = world.stats["max_hp"]
    world.hurt_player(Vector2.ZERO, 100.0, true)
    expect(is_equal_approx(world.player_hp, world.stats["max_hp"] - cap) and world.running, "Boss hits share the same 70% max-HP combat cap")
    world.map_view.chunks.clear()
    for x in range(-2, 5):
        for y in range(-2, 5):
            world.map_view.chunks[Vector2i(x, y)] = []
    var lava_at: Vector2 = world.player_position
    world.map_view.chunks[Vector2i(1, 0)] = [{"kind": "lava", "point": lava_at, "radius": 100.0, "seed": 0}]
    world.player_hp = world.stats["max_hp"]
    world.invulnerable = 0.0
    world.paused = false
    world.shop_open = false
    world.upgrade_pending = false
    world.stats_open = false
    world.player_frozen = false
    world.wave_closing = false
    world.departure_left = 0.0
    var before_lava: float = world.player_hp
    world.update_terrain_damage(3.0)
    var lava_taken: float = before_lava - world.player_hp
    expect(lava_taken > cap or is_equal_approx(world.player_hp, 0.0), "lava DoT ticks are not limited by the combat hit cap")
    world.start_run(false)
    clear_enemies(world)
    world.demo = true
    world.wave = 100
    world.spawn_enemy("charger", Vector2(300, 350))
    var charger: Dictionary = world.enemies[0]
    charger["state"] = "windup"
    charger["direction"] = Vector2.RIGHT
    charger["timer"] = 0.65
    expect(world.has_method("charge_path"), "scaled charger warning-path calculation is not implemented")
    if world.has_method("charge_path"):
        var warning: Vector2 = world.charge_path(charger)
        expect(is_equal_approx(warning.length(), 302.4), "maximum-speed charger warns of its full 302.4-pixel travel")
        var origin: Vector2 = charger["position"]
        charger["state"] = "dash"
        charger["timer"] = 0.4
        world.update_enemies(0.1)
        expect(is_equal_approx(origin.distance_to(charger["position"]) + world.charge_path(charger).length(), 302.4), "actual travelled distance plus remaining warning matches the complete scaled charge")
    world.queue_free()
    await process_frame
    finish()

func finish() -> void:
    print("PROGRESSION RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)
