extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
    call_deferred("run_checks")

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func run_checks() -> void:
    var path := "res://src/biome_encounters.gd"
    expect(ResourceLoader.exists(path), "biome encounter controller is installed")
    if not ResourceLoader.exists(path):
        finish()
        return
    var encounters = load(path)
    var roster = load("res://src/enemy_roster.gd")
    var ids: Array = []
    for wave in [5, 10, 15, 20, 25, 30]:
        ids.append(encounters.boss_form(wave))
    expect(ids == ["fernmask", "cinderback", "drumjaw", "fernmask_dark", "cinderback_dark", "drumjaw_dark"], "first three milestones have separate bosses and later ones return as corrupted forms")
    expect(roster.spawn_pool(6, 16.0, false, false).has("sporeback"), "grove introduces sporeback")
    expect(roster.spawn_pool(9, 16.0, false, false).has("embersnout"), "volcano changes the standard lineup")
    expect(not roster.spawn_pool(9, 16.0, false, false).has("sporeback"), "old biome does not dominate the new one")
    var area: Dictionary = {"shape":"fan", "origin":Vector2.ZERO, "direction":Vector2.RIGHT, "reach":100.0, "width":0.7}
    expect(encounters.contains(area, Vector2(80, 0)), "fan hits inside the painted sector")
    expect(not encounters.contains(area, Vector2(0, 80)), "fan does not hit beside the painted sector")
    expect(not encounters.contains(area, Vector2(110, 0)), "fan does not hit outside the drawn range")
    var ink = load("res://src/encounter_ink.gd")
    var lane := {"mode":"", "shape":"lane"}
    expect(ink.family(lane, {"kind":"embersnout"}) == "fire", "fire is separate from the charge lane")
    expect(ink.family(lane, {"kind":"boss","form":"cinderback"}) == "fissure", "cinderback cracks use their own effect")
    expect(ink.family({"mode":"echo", "shape":"lane"}, {"kind":"boss","form":"fernmask_dark"}) == "echo", "corrupted afterstrike has its own brushes")

    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("user://tests/biome_encounters")
    root.add_child(world)
    world.set_physics_process(false)
    world.start_run(true, "base")
    check_frames()
    check_boss_pressure(world)
    world.clear_enemies()
    world.projectiles.clear()
    world.wave = 20
    world.spawn_enemy("boss", world.player_position + Vector2(168, 0))
    var boss: Dictionary = world.enemies.back()
    expect(boss.get("form") == "fernmask_dark", "normal scene spawn selects the late Boss form")
    boss.timer = 0.0
    world.update_enemies(0.016)
    expect(boss.state == "encounter_aim", "Boss announces the first attack before damage")
    if boss.state == "encounter_aim":
        var locked: Dictionary = boss.attack.duplicate()
        world.player_position += Vector2(0, 140)
        world.update_enemies(0.05)
        expect(boss.attack.origin == locked.origin and boss.attack.direction == locked.direction, "warning does not snap toward a moving player")
        boss.timer = 0.0
        world.update_enemies(0.016)
        expect(boss.state == "encounter_strike", "warning commits to an animated strike")
        expect(not boss.combo.is_empty(), "corrupted hunter retains its follow-up")
        for index in range(20):
            world.update_enemies(0.016)
        expect(boss.state == "encounter_aim" and boss.attack.mode == "echo", "pounce chains to a delayed shadow warning")
        expect(boss.attack.origin == locked.origin and boss.attack.direction == locked.direction, "shadow uses the original attack lane")
    world.spawn_enemy("ashhound", world.player_position + Vector2(150, 40))
    var hound: Dictionary = world.enemies.back()
    var view = hound.view
    view.animate(Vector2(180, 0), 0.1, "walk", 0.0)
    var stopped_phase: float = view.foot_phase
    expect(is_zero_approx(stopped_phase) and is_zero_approx(view.gait_amount), "blocked feet do not cycle under commanded movement")
    view.animate(Vector2(180, 0), 0.1, "walk", 5.0)
    var first_step: float = view.foot_phase
    view.animate(Vector2(180, 0), 0.1, "walk", 10.0)
    expect(is_equal_approx(view.foot_phase - first_step, first_step * 2.0), "gait measures actual travel distance")
    var saved: Dictionary = world.SessionState.capture(world)
    expect(world.save_store.write_run(saved).ok, "saved encounters accept new enemy kinds")
    world.hurt_enemy(hound, 100000.0, "powder", true, Vector2.RIGHT)
    expect(hound.hp <= 0.0, "new creatures can die and create defeat effects")
    expect(world.continue_game() and world.enemies.any(func(enemy): return enemy.kind == "ashhound"), "saved encounters restore new enemy kinds")
    world.queue_free()
    await process_frame
    finish()

func check_boss_pressure(world) -> void:
    var encounters = load("res://src/biome_encounters.gd")
    var roster = load("res://src/enemy_roster.gd")
    expect(roster.spawn_pool(6,10.0,false,false).has("reedspitter"), "grove has its own long range skirmisher")
    expect(roster.spawn_pool(9,10.0,false,false).has("cindertusk"), "volcano has its own ranged artillery")
    for stage in [5, 10, 15]:
        world.clear_enemies()
        world.projectiles.clear()
        world.wave = stage
        world.boss_defeated = false
        world.demo = false
        world.invulnerable = 0.0
        world.player_hp = world.stats["max_hp"]
        world.stats["dodge"] = 0.0
        var hp_at_start: float = world.player_hp
        world.spawn_enemy("boss", world.player_position + Vector2(392,0))
        var boss: Dictionary = world.enemies.back()
        boss.timer = 0.0
        world.update_enemies(0.016)
        expect(boss.state == "encounter_aim", "wave %d Boss pressures a stationary player at range" % stage)
        var attack: Dictionary = boss.get("attack", {})
        expect(attack.get("mode") in ["volley","target"], "wave %d starts a real ranged move" % stage)
        if not attack.is_empty():
            boss.timer = 0.0
            world.update_enemies(0.016)
            if attack.mode == "volley":
                expect(not world.projectiles.is_empty() and world.projectiles[0].boss, "ranged tell launches hostile Boss shots")
                for _i in range(128):
                    world.update_projectiles(0.016)
            if attack.mode == "target":
                expect(encounters.contains(attack, attack.origin), "marked ranged rockfall covers the locked target")
        expect(world.player_hp < hp_at_start, "wave %d ranged attack damages a player who does not move" % stage)
        boss.state = "walk"
        boss.timer = 0.0
        boss.attack_cycle = 3
        world.update_enemies(0.016)
        expect(boss.get("attack", {}).get("mode") == "summon", "wave %d Boss has its own summon" % stage)
        boss.timer = 0.0
        world.update_enemies(0.016)
        var owned: Array = world.enemies.filter(func(enemy): return int(enemy.get("summoner_id",0)) == int(boss.id))
        expect(owned.size() >= 1 and owned.size() <= 2, "summons are marked and bounded")
        if not owned.is_empty():
            world.elapsed += 20.0
            boss.state = "walk"
            boss.timer = 0.0
            world.update_enemies(0.016)
            expect(boss.attack.mode != "summon", "living summons prevent another cast")
        var save: Dictionary = world.SessionState.capture(world)
        expect(world.save_store.write_run(save).ok and world.continue_game(), "Boss summon metadata round trips in existing save format")
        expect(world.enemies.any(func(enemy): return int(enemy.get("summoner_id",0)) == int(boss.id)), "loading retains the summon owner")

func check_frames() -> void:
    var script = load("res://src/creature_frames.gd")
    var view = script.new()
    for form in ["hunter", "charger", "spitter", "tank", "raptor", "thrower", "armored",
            "fernmask", "fernmask_dark", "cinderback", "drumjaw", "sidesnap", "stonecrest", "shieldback",
            "leafstalker", "sporeback", "bonecaller", "embersnout", "ashhound", "basaltroller",
            "cinderback_dark", "drumjaw_dark", "reedspitter", "cindertusk"]:
        view.configure(form, 100.0)
        expect(view.ready_to_draw and view.sample_rects.size() == 6, form + " has six whole-body sprites")
        if not view.ready_to_draw:
            continue
        var visited: Dictionary = {}
        for index in range(4):
            view.pose(TAU * (index + 0.2) / 4.0, true, "walk", 0.1, 1.0)
            visited[view.sample_rects[view.frame]] = true
        expect(visited.size() == 4 and view.scale == Vector2.ONE and is_zero_approx(view.rotation), form + " changes complete frames without deforming the sprite")
        view.pose(1.1, false, "walk", 1.0, -1.0)
        expect(view.frame == 0 and view.scale == Vector2(-1, 1), form + " stops walking and only mirrors to face left")
        view.pose(0.0, false, "windup", 0.2, 1.0)
        expect(view.frame == 4, form + " has a dedicated anticipation drawing")
        view.pose(0.0, false, "strike", 0.1, 1.0)
        expect(view.frame == 5, form + " has a dedicated strike drawing")
    view.configure("drumjaw", 158.0)
    view.pose(0.0,false,"bite_prep",0.3,1.0)
    expect(view.displayed_clip == "bite" and view.frame == 0, "drumjaw crouches before a separate bite sequence")
    view.pose(0.0,false,"pounce",0.06,1.0)
    expect(view.displayed_clip == "bite" and view.frame == 1, "the whole creature springs on its first bite frame")
    view.pose(0.0,false,"recover",0.1,1.0)
    expect(view.displayed_clip == "bite" and view.frame == 3, "recovery uses a separate landing pose")
    view.free()

func finish() -> void:
    print("BIOME ENCOUNTERS RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
