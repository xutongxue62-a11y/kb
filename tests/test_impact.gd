extends SceneTree

const Rules = preload("res://src/rules.gd")

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

func single_weapon(world: Node, key: String) -> void:
    world.start_run(false)
    clear_enemies(world)
    # Damage benchmark uses an open lane; mining is covered in resources_v12.
    for x in range(-2,5):
        for y in range(-2,5): world.map_view.chunks[Vector2i(x,y)]=[]
    for view in world.weapon_views.values():
        view.queue_free()
    world.inventory.clear()
    world.weapon_views.clear()
    world.weapon_runtime.clear()
    world.grant_weapon(key)
    world.stats["crit_chance"] = 0.0

func check_close_ranged_targets(world: Node) -> void:
    for key in ["sling", "powder", "staff"]:
        for target_offset in [Vector2(42, 0), Vector2(-42, 0), Vector2(0, 42), Vector2(0, -42)]:
            single_weapon(world, key)
            world.spawn_enemy("hunter", world.player_position + target_offset)
            var enemy: Dictionary = world.enemies[0]
            enemy["hp"] = 1000.0
            enemy["max_hp"] = 1000.0
            enemy["dodge"] = 0.0
            world.weapon_runtime[key]["cooldown"] = 0.0
            world.update_weapons(0.0)
            var view: Sprite2D = world.weapon_views[key]
            var view_direction: Vector2 = Vector2.from_angle(view.rotation - (0.0 if key == "powder" else PI / 2.0))
            # Juniper (2026-11-17): the barrel itself must turn to the monster.
            # A shell that leaves toward the target while the barrel points
            # elsewhere reads as firing out of the weapon's back, so while a
            # target is tracked the displayed barrel follows the shot — and
            # the shell still leaves the displayed muzzle.
            var muzzle: Vector2 = world.weapon_muzzle_point(key, view_direction)
            var aligned: bool = world.projectiles.size() == (3 if key == "staff" else 1)
            if aligned:
                var center_shot: Dictionary = world.projectiles[world.projectiles.size() / 2]
                var heading: Vector2 = Vector2(center_shot["velocity"]).normalized()
                aligned = heading.dot((enemy["position"] - muzzle).normalized()) > 0.99
                # At point-blank on the weapon's own side the muzzle reach can
                # pass the target: the shell then hops back from the muzzle
                # into the target while the barrel points at it from its base.
                var overshot: bool = muzzle.distance_to(view.position) > enemy["position"].distance_to(view.position)
                if overshot:
                    aligned = aligned and view_direction.dot((enemy["position"] - view.position).normalized()) > 0.99
                else:
                    aligned = aligned and view_direction.dot(heading) > 0.999
                for projectile in world.projectiles:
                    aligned = aligned and projectile["position"].distance_to(muzzle) <= 1.5
            expect(aligned, "actual ranged muzzle and aim follow the displayed barrel for a close target: " + key + " " + str(target_offset))
            for index in range(60):
                world.update_projectiles(1.0 / 60.0)
            expect(enemy["hp"] < 1000.0, "actual ranged shot hits a hunter just outside body contact on every side: " + key + " " + str(target_offset))

func _initialize() -> void:
    call_deferred("run_checks")

func run_checks() -> void:
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/impact_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.start_run(false)
    expect(world.enemies.is_empty(), "opening starts without any enemies already on the field")
    world.simulate(0.56,Vector2.ZERO)
    expect(world.enemies.size()==1 and world.enemies[0].state=="enter" and not world.visible_world_rect().has_point(world.enemies[0].position),"first hunter walks in from beyond the camera after the opening delay")
    world.spawn_enemy("hunter",Vector2(INF,INF),false,"egg")
    expect(world.enemies.back().state=="egg" and world.enemies.back().position.distance_to(world.player_position)>=200,"explicit egg arrival preserves its hatch warning and safe distance")
    expect(world.xp_needed == 15, "first growth is paced at fifteen collected ordinary stones")
    var output: Dictionary = {}
    for key in ["sling", "powder", "staff", "club", "axe", "blade"]:
        single_weapon(world, key)
        world.collapsed = true
        world.spawn_enemy("tank", world.player_position + Vector2(76, 0))
        world.enemies[0]["hp"] = 1000.0
        world.enemies[0]["max_hp"] = 1000.0
        for index in range(180):
            world.elapsed = float(index) / 60.0
            world.update_weapons(1.0 / 60.0)
            world.update_projectiles(1.0 / 60.0)
        output[key] = 1000.0 - world.enemies[0]["hp"]
    var ranged_best: float = maxf(output["sling"], maxf(output["powder"], output["staff"]))
    print("ACTUAL 3s DAMAGE: " + str(output))
    for key in ["club", "axe", "blade"]:
        expect(output[key] > ranged_best * 1.15, "actual " + key + " close-range output exceeds the strongest independent ranged by at least 15 percent")
        single_weapon(world, key)
        world.spawn_enemy("hunter", world.player_position + Vector2(Rules.MELEE_ORBIT, 0))
        for index in range(50):
            world.elapsed = float(index) / 60.0
            world.update_weapons(1.0 / 60.0)
        expect(world.enemies[0]["hp"] <= 0 and world.kills == 1, key + " kills an opening ordinary hunter on its first real orbit contact")
    single_weapon(world, "sling")
    world.spawn_enemy("tank", world.player_position + Vector2(170, 0))
    world.enemies[0]["hp"] = 1000.0
    for index in range(60):
        world.elapsed = float(index) / 60.0
        world.update_weapons(1.0 / 60.0)
    expect(world.projectiles.size() >= 3, "opening sling fires at least three actual shots in the first second")
    single_weapon(world, "club")
    for index in range(180):
        world.elapsed += 1.0 / 60.0
        world.update_weapons(1.0 / 60.0)
    var before_haste: Vector2 = world.weapon_views["club"].position
    world.spawn_enemy("tank", world.player_position)
    world.enemies[0]["hp"] = 100.0
    world.apply_buff("haste")
    world.elapsed += 1.0 / 60.0
    world.update_weapons(1.0 / 60.0)
    # One frame at the farther melee radius still has to be a small step, not a teleport across the ring.
    expect(world.weapon_views["club"].position.distance_to(before_haste) < 30.0, "haste preserves continuous melee phase instead of jumping across the orbit")
    expect(is_equal_approx(world.enemies[0]["hp"], 100.0), "haste cannot create a false swept hit through the center of the orbit")
    expect(world.hero.parts["body"].material == null and world.enemies[0]["view"].sprite.material != null, "hero retains original ink without a cyan outline; enemy team outlines stay enabled")
    var richer_effects: bool = world.effects.has_method("swing_trail") and world.effects.has_method("defeat")
    expect(richer_effects, "layered melee trails and enemy defeat effects are not implemented")
    if richer_effects:
        single_weapon(world, "club")
        world.spawn_enemy("hunter", world.player_position + Vector2(Rules.MELEE_ORBIT, 0))
        for index in range(12):
            world.elapsed = float(index) / 60.0
            world.update_weapons(1.0 / 60.0)
        expect(world.effects.particles.any(func(item): return item["kind"] == "swing_trail") and world.effects.particles.any(func(item): return item["kind"] == "defeat"), "real melee attacks generate ribbons and real kills generate defeat feedback")
        world.toggle_pause()
        var age: float = world.effects.particles[0]["age"]
        world.simulate(0.4, Vector2.RIGHT)
        expect(is_equal_approx(world.effects.particles[0]["age"], age), "pausing also freezes richer combat effects")
        world.start_run(false)
        expect(world.effects.particles.is_empty() and world.position.is_zero_approx(), "restart clears effects and resets visual shake offset")
        for index in range(220):
            world.effects.swing_trail(Vector2(76, 0), Vector2(72, 24), Vector2.ZERO, "club")
        expect(world.effects.particles.size() <= 200, "continuous melee trails respect the particle budget")
        world.effects.advance(1.0)
        expect(world.effects.particles.is_empty(), "short-lived attack trails expire instead of accumulating")
        world.effects.puff(Vector2.ZERO, Color("#e2cba8"), 24.0, 40)
        world.effects.defeat(Vector2(12, 0), Vector2(0, -1), 36.0)
        expect(world.effects.particles.size() > 0 and world.effects.particles[0]["life"] < 0.5, "puff life stays short even with a large smoke index")
        world.effects.expire_all()
        expect(world.effects.particles.is_empty(), "expire_all advances leftover combat effects to expiry")
    check_close_ranged_targets(world)
    world.queue_free()
    await process_frame
    print("IMPACT RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)
