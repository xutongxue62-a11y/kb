extends SceneTree
var checks: int = 0
var failures: int = 0
func expect(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + message)
func clear_route(world) -> void:
    var home := Vector2i(floori(world.player_position.x/512.0),floori(world.player_position.y/512.0))
    for y in range(home.y-2,home.y+3):
        for x in range(home.x-2,home.x+3):
            world.map_view.chunks[Vector2i(x,y)] = []
func _initialize() -> void:
    call_deferred("run_checks")
func run_checks() -> void:
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/dodge_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    expect(world.has_method("request_dodge"), "combat exposes bounded dodge request")
    expect(world.effects.has_method("rune_ignition"), "rune ignition has explicit visual feedback")
    if failures > 0:
        world.queue_free()
        print("DODGE RESULT: %d checks, %d failures" % [checks,failures])
        quit(1)
        return
    world.start_run(true)
    world.clear_enemies()
    world.spawn_clock = 100.0
    world.invulnerable = 0.0
    var origin: Vector2 = world.player_position
    expect(world.request_dodge(Vector2.RIGHT), "can dodge during combat")
    expect(not world.request_dodge(Vector2.LEFT), "repeated dodge cannot refresh")
    expect(is_equal_approx(world.dodge_left, 0.2), "dash duration is 200ms")
    expect(world.invulnerable >= world.dodge_left, "dash grants brief invulnerability")
    for step in range(12):
        clear_route(world)
        world.simulate(1.0 / 60.0, Vector2.LEFT)
    expect(absf(world.player_position.x-origin.x-140.0)<0.1, "locked direction moves 140 pixels despite opposite input")
    expect(world.dodge_left < 0.001, "dash ends after 200ms")
    expect(world.dodge_cooldown>1.1, "cooldown outlasts dash")
    var cooldown: float = world.dodge_cooldown
    world.paused = true
    clear_route(world)
    world.simulate(0.5, Vector2.ZERO)
    expect(is_equal_approx(cooldown, world.dodge_cooldown), "pause freezes dodge cooldown")
    world.paused = false
    clear_route(world)
    world.simulate(1.3, Vector2.ZERO)
    expect(world.request_dodge(Vector2(1,1)), "dodge recharges")
    origin = world.player_position
    clear_route(world)
    world.simulate(0.3, Vector2.ZERO)
    expect(absf(world.player_position.distance_to(origin)-140.0)<0.1, "long frame caps dash distance; diagonal normalized")
    for blocker in ["paused","shop_open","upgrade_pending","stats_open","player_frozen","wave_closing"]:
        world.start_run(true)
        world.set(blocker, true)
        expect(not world.request_dodge(Vector2.RIGHT), "blocked dodge: " + blocker)
        expect(world.dodge_cooldown == 0.0, "blocked request consumes no cooldown: " + blocker)
        world.set(blocker, false)
    world.start_run(true)
    world.departure_left = 1.0
    expect(not world.request_dodge(), "departure blocks dodge")
    world.departure_left = 0.0
    world.player_hp = 0.0
    expect(not world.request_dodge(), "dead blocks dodge")
    world.start_run(true)
    world.running = false
    expect(not world.request_dodge(), "title blocks dodge")
    world.start_run(true)
    world.invulnerable = 1.0
    expect(world.request_dodge(Vector2.LEFT), "dodge during continue protection")
    expect(world.invulnerable == 1.0, "dodge does not shorten continue protection")
    world.start_run(true)
    expect(world.dodge_left == 0.0 and world.dodge_cooldown == 0.0, "new run clears transient dash")
    world.player_position = Vector2(1197,590)
    world.request_dodge(Vector2.ONE)
    clear_route(world)
    world.simulate(0.3, Vector2.ZERO)
    expect(world.player_position.x > 1198 and world.player_position.y > 609, "dash freely crosses former arena boundary")
    world.start_run(true)
    world.clear_enemies()
    world.spawn_clock = 100.0
    clear_route(world)
    world.simulate(0.01, Vector2.UP)
    origin = world.player_position
    var key := InputEventKey.new()
    key.pressed = true
    key.physical_keycode = KEY_SHIFT
    world._unhandled_key_input(key)
    clear_route(world)
    world.simulate(0.2, Vector2.ZERO)
    expect(world.player_position.y < origin.y-139.0, "native Shift executes last-facing dodge")
    world.start_run(true)
    world.request_dodge(Vector2.RIGHT)
    var health: float = world.player_hp
    world.hurt_player(Vector2.LEFT, 2.0)
    expect(world.player_hp == health, "actual incoming damage blocked during dash")
    var snapshot: Dictionary = load("res://src/session_state.gd").capture(world, false)
    expect(not snapshot.has("dodge_left") and not snapshot.has("dodge_direction"), "save snapshot excludes dash transient")
    world.start_run(false)
    var no_dash_origin: Vector2 = world.player_position
    clear_route(world)
    world.simulate(0.01, Vector2.ZERO)
    expect(world.player_position == no_dash_origin, "restart has no latent dash displacement")
    world.start_run(true)
    key.physical_keycode = KEY_Q
    world._unhandled_key_input(key)
    expect(world.active_link["id"] == "rune_shell", "native Q activates earned rune link")
    world.effects.particles.clear()
    world.effects.rune_ignition(Vector2(20,20),Vector2(80,20))
    expect(world.effects.particles.any(func(p):return p["kind"] == "rune_ignition"), "rune ignition produces dedicated particles")
    world.start_run(true, "new")
    world.clear_enemies()
    world.spawn_enemy("tank", world.player_position + Vector2(90,0))
    for frame in range(8):
        world.update_armory(0.04)
    for weapon in ["spear", "hammer", "boomerang"]:
        expect(world.effects.particles.any(func(p):return p["kind"] == "weapon_motion" and p.get("weapon_id", "") == weapon), "special weapon emits unique motion feedback: " + weapon)
    world.queue_free()
    print("DODGE RESULT: %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
