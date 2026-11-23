extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
    call_deferred("run")

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func run() -> void:
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/talents_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.settings.autosave = false
    expect("talents" in world, "the main combat scene owns character talent state")
    if "talents" in world:
        check_growth(world)
        check_hits(world)
        check_weapon_actions(world)
    world.queue_free()
    await process_frame
    print("CHARACTER TALENTS RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)

func prepare(world, character: String, weapon: String) -> void:
    world.character_id = character
    world.starting_weapon = weapon
    world.start_run(false)
    world.settings["seen_link_recipes"] = world.Catalog.LINK_ORDER.duplicate()
    world.stats["crit_chance"] = 0.0
    world.stats["dodge"] = 0.0
    world.clear_enemies()

func target(world) -> Dictionary:
    world.spawn_enemy("tank", world.player_position + Vector2(90, 0))
    var enemy: Dictionary = world.enemies.back()
    enemy.hp = 10000.0
    enemy.max_hp = 10000.0
    return enemy

func check_growth(world) -> void:
    prepare(world, "caveman", "sling")
    world.player_level = 2
    world.xp = world.xp_needed
    world.present_upgrade()
    var first: String = world.upgrade_choices[0]
    world.on_choice(first)
    expect(world.player_level == 3 and world.upgrade_pending and not world.upgrade_choices.has(first), "level three commits XP once and offers a distinct second reward")
    expect(world.upgrade_choices.all(func(key): return world.Catalog.WEAPONS.has(key) != world.Catalog.WEAPONS.has(first)), "the follow-up prefers the other reward category")
    expect(world.save_game() and world.continue_game() and world.upgrade_pending, "saving between the two picks restores the unspent reward")
    if world.upgrade_pending:
        world.on_choice(world.upgrade_choices[0])
    expect(world.player_level == 3 and not world.upgrade_pending, "the second pick cannot consume a second level")
    expect(is_equal_approx(world.Growth.stats({"power":6}).damage_multiplier, 1.90) and is_equal_approx(world.Growth.stats({"power":10}).damage_multiplier, 2.56), "only stacks seven through ten get larger gains")
    expect(is_equal_approx(world.Evolution.damage_multiplier("hammer", 10) / world.Evolution.damage_multiplier("hammer", 10, true), 1.06), "late hammer growth can be excluded specifically for thunder hammer")
    prepare(world, "caveman", "sling")
    world.grant_weapon("firepot", 10)
    world.select_link("fire_sling")
    expect(is_equal_approx(world.enchant_damage_multiplier("sling"), 1.46 * 1.04), "late affix growth uses the enchant catalyst level")

func check_hits(world) -> void:
    prepare(world, "hunter", "bonebow")
    var enemy := target(world)
    var damage: Array[float] = []
    for hit in range(5):
        var before: float = enemy.hp
        world.hurt_enemy(enemy, 10.0, "bonebow", false, Vector2.RIGHT)
        damage.append(before - float(enemy.hp))
    expect(is_equal_approx(damage[3], 18.0) and is_equal_approx(damage[4], 10.0), "the hunter's fourth hit on one target triggers a single weak-point bonus")
    prepare(world, "caveman", "sling")
    world.grant_weapon("bonebow")
    enemy = target(world)
    for hit in range(4):
        world.hurt_enemy(enemy, 10.0, "bonebow", false, Vector2.RIGHT)
    expect(is_equal_approx(enemy.hp, 9960.0) and not enemy.has("hunt_hits"), "using a hunter's weapon on another character does not grant the talent")
    prepare(world, "barbarian", "club")
    enemy = target(world)
    var neighbor := target(world)
    for hit in range(2):
        world.invulnerable = 0.0
        world.hurt_player(Vector2.ZERO, 1.0)
    var neighbor_hp: float = neighbor.hp
    world.hurt_enemy(enemy, 1.0, "club", false, Vector2.RIGHT)
    expect(neighbor.hp < neighbor_hp, "two landed attacks prime a barbarian area counter")
    world.invulnerable = 0.0
    var player_before: float = world.player_hp
    world.hurt_player(Vector2.ZERO, 2.0)
    expect(is_equal_approx(player_before - world.player_hp, 0.94), "the counter grants half damage for a second")

func check_weapon_actions(world) -> void:
    prepare(world, "shaman", "staff")
    target(world)
    for volley in range(4):
        world.weapon_runtime["staff"].cooldown = 0.0
        world.projectiles.clear()
        world.update_weapons(0.05)
    expect(world.projectiles.size() == 10 and world.projectiles.any(func(shot): return shot.from_combo), "the fourth shaman cast includes one reflected five-rune volley")
    prepare(world, "chief", "spear")
    var enemy := target(world)
    for frame in range(80):
        world.elapsed += 1.0 / 60.0
        world.update_armory(1.0 / 60.0)
    expect(world.talents.chief_flag_at.is_finite() and world.effects.particles.any(func(p): return p.kind == "beam"), "the chief plants a flag and it answers a later spear thrust")
    prepare(world, "priest", "totem")
    enemy = target(world)
    for shot in range(6):
        world.armory.states["totem"] = {"phase":"rest", "cooldown":0.0, "age":0.0}
        world.elapsed += 0.1
        world.update_armory(0.1)
    expect(world.talents.priest_altar_at.is_finite(), "a priest alone with one target can build an altar")
    var before_discharge: float = enemy.hp
    world.armory.states["totem"] = {"phase":"rest", "cooldown":0.0, "age":0.0}
    world.elapsed += 0.1
    world.update_armory(0.1)
    expect(not world.talents.priest_altar_at.is_finite() and is_equal_approx(before_discharge - float(enemy.hp), 3.4 * 0.92 * 1.65), "the next priest volley hits the same target again through the altar")
    prepare(world, "firekeeper", "firepot")
    enemy = target(world)
    world.update_armory(0.01)
    var state: Dictionary = world.armory.states["firepot"]
    state.pots.clear()
    for point in [world.player_position, world.player_position + Vector2(20, 0)]:
        state.fires.append({"position":point, "age":0.2, "life":1.4, "next_tick":0.48, "damage":2.0, "radius":56.0})
    world.update_armory(0.1)
    world.update_armory(0.1)
    expect(state.fires.size() == 1 and state.fires[0].get("living_fire", false) and state.fires[0].position.x > world.player_position.x + 10, "overlapping firekeeper flames merge and move toward the enemy")
    prepare(world, "firekeeper", "firepot")
    target(world)
    for frame in range(150):
        world.update_armory(1.0 / 60.0)
    var active_fires: Array = world.armory.states["firepot"].fires
    expect(active_fires.any(func(fire): return fire.get("living_fire", false)), "two ordinary level-one throws can activate live fire without a damage or haste buff")
