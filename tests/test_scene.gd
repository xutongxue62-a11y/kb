extends SceneTree
const Rules = preload("res://src/rules.gd")

var failures: int = 0
var checks: int = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func visible_labels(node: Node) -> Array:
    var result: Array = []
    if node is Label:
        result.append(node.text)
    for child in node.get_children():
        result.append_array(visible_labels(child))
    return result

func _initialize() -> void:
    if not FileAccess.file_exists("res://src/main.gd"):
        expect(false, "playable battle scene with independent limb motion is not implemented")
        print("SCENE RESULT: %d checks, %d failures" % [checks, failures])
        quit(1)
        return
    call_deferred("run_checks")

func run_checks() -> void:
    var script = load("res://src/main.gd")
    if script == null or not script.can_instantiate():
        expect(false, "battle scene script loads")
        quit(1)
        return
    var world = script.new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/scene_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.start_run(false)
    expect(world.inventory.size() == 1 and world.inventory[0]["id"] == "sling", "normal start has exactly one ranged sling")
    expect(world.hero.parts.size() == 5, "hero has body and four independent limb sprites")
    var before: Vector2 = world.player_position
    var foot_before: Vector2 = world.hero.parts["left_foot"].position
    var hand_before: Vector2 = world.hero.parts["left_hand"].position
    world.simulate(0.1, Vector2.RIGHT)
    expect(world.player_position.x > before.x, "movement input changes actual player position")
    expect(world.hero.parts["left_foot"].position != foot_before and world.hero.parts["left_hand"].position != hand_before, "actual foot and hand transforms both change during walking")
    var left_offset: Vector2 = world.hero.parts["left_foot"].position - world.hero.rest["left_foot"]
    var right_offset: Vector2 = world.hero.parts["right_foot"].position - world.hero.rest["right_foot"]
    expect(left_offset.dot(right_offset) < 0.0, "actual left and right feet move in opposite phases")
    world.toggle_pause()
    var elapsed_before: float = world.elapsed
    before = world.player_position
    world.simulate(0.5, Vector2.RIGHT)
    expect(is_equal_approx(world.elapsed, elapsed_before) and world.player_position == before, "pause freezes battle time and movement")
    world.toggle_pause()
    expect(not world.paused, "pause can resume")
    world.present_upgrade()
    elapsed_before = world.elapsed
    world.simulate(0.5, Vector2.LEFT)
    expect(world.upgrade_pending and is_equal_approx(world.elapsed, elapsed_before), "upgrade choice also freezes battle simulation")
    var offered: String = world.upgrade_choices[0]
    world.on_choice(offered)
    expect(not world.upgrade_pending, "choosing an offered weapon resumes combat")
    world.start_run(true)
    expect(world.inventory.size() == 6 and world.weapon_views.size() == 6, "six-weapon trial has six actual visible weapon nodes")
    world.collapsed = true
    world.elapsed = 8.49
    world.simulate(0.01, Vector2.ZERO)
    var near: bool = true
    for key in ["powder", "staff", "sling"]:
        if world.weapon_views[key].position.distance_to(world.player_position) > Rules.PARKED_MAX_ANCHOR:
            near = false
    expect(near, "ranged weapons stay near the avatar")
    expect(world.active_link["id"] == "none", "trial starts without forcing a link")
    world.switch_combo_mode()
    expect(world.active_link["id"] == "rune_shell" and world.inventory.size() == 6, "selecting a pair preserves original weapon slots")
    world.grant_weapon("club")
    expect(world.inventory.size() == 6 and world.inventory[0]["level"] == 2, "full-slot duplicate upgrades in the real scene")
    world.projectiles.append({"old_fixture": true})
    world.start_run(false)
    expect(world.projectiles.is_empty() and world.kills == 0 and is_zero_approx(world.elapsed), "restart clears projectiles, score and battle time")
    expect(world.inventory.size() == 1 and world.player_hp == 8, "restart restores normal starting loadout and health")
    world.player_hp = 1
    world.invulnerable = 0.0
    world.hurt_player(Vector2.RIGHT)
    expect(not world.running and world.hud.overlay.visible, "zero health ends the run and shows restart controls")
    world.start_run(false)
    expect(world.running and not world.hud.overlay.visible, "game can start again after death")
    world.elapsed = 89.99
    world.player_hp = 1
    world.invulnerable = 0.0
    world.projectiles.append({"position": world.player_position, "velocity": Vector2.ZERO, "damage": 1.0, "kind": "hostile", "life": 1.0, "radius": 6.5, "weapon_id": "", "from_combo": false})
    world.simulate(1.0 / 60.0, Vector2.ZERO)
    var ending_labels: Array = visible_labels(world.hud.overlay)
    expect(ending_labels.has("再来一局") and not ending_labels.has("生存成功"), "a fatal projectile on the deadline frame must preserve defeat")
    world.queue_free()
    print("SCENE RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)
