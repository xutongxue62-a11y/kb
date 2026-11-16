extends SceneTree

const Main = preload("res://src/main.gd")
const Store = preload("res://src/save_store.gd")
const Session = preload("res://src/session_state.gd")
const Catalog = preload("res://src/catalog.gd")
var checks := 0
var failures := 0

class PickupCanvas:
    extends RefCounted
    var texts: Array = []
    var textures: Array = []
    func draw_colored_polygon(_points, _color): pass
    func draw_circle(_point, _radius, _color): pass
    func draw_arc(_point, _radius, _start, _end, _count, _color, _width, _aa): pass
    func draw_line(_a, _b, _color, _width, _aa): pass
    func draw_string_outline(_font, _point, text, _align, _width, _size, _outline, _color): texts.append(text)
    func draw_string(_font, _point, text, _align, _width, _size, _color): texts.append(text)
    func draw_texture_rect(texture, rect, _tile): textures.append({"texture":texture,"rect":rect})

func expect(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + message)

func _initialize() -> void:
    call_deferred("run_checks")

func totals(drops: Array) -> Vector2:
    var result := Vector2.ZERO
    for drop in drops:
        if drop.kind == "coin": result.x += float(drop.value)
        else: result.y += float(drop.value) * float(drop.get("legacy_fraction", 1.0))
    return result

func units(drops: Array) -> bool:
    return drops.all(func(d): return d.value == 1)

func reset(world) -> void:
    world.clear_enemies()
    world.pickups.clear()
    world.coins = 0
    world.xp = 0.0
    world.stats.xp_multiplier = 1.0
    world.spawn_clock = 999
    world.invulnerable = 999

func run_checks() -> void:
    var world = Main.new()
    world.save_store = Store.new("res://runtime/tests/character_loot_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.demo = true
    world.start_run(false)
    reset(world)
    var canvas := PickupCanvas.new()
    for kind in ["xp", "coin"]:
        Main.BattleVisuals.draw_pickup(canvas,{"kind":kind,"position":Vector2.ZERO,"value":25},0.0)
    expect(canvas.texts.is_empty(), "ground resources never draw a multiplier label, even for legacy input")
    var batch := PickupCanvas.new()
    var mixed := [{"kind":"coin","position":Vector2(10,10),"value":1},{"kind":"xp","position":Vector2(40,10),"value":1},{"kind":"coin","position":Vector2(70,10),"value":1},{"kind":"xp","position":Vector2(9000,10),"value":1}]
    var renderer = Main.BattleVisuals.new()
    if renderer.has_method("draw_pickups"):
        renderer.call("draw_pickups",batch,mixed,Rect2(0,0,200,200),0.0)
        expect(batch.textures.size()==3 and mixed.size()==4 and units(mixed), "drawing culls only offscreen pixels, never entities")
        expect(batch.textures.size()==3 and batch.textures[1].texture==batch.textures[2].texture, "visible units share texture batches without sharing resource amounts")
    else:
        expect(false,"unit renderer supports cached texture batches without collapsing entities")
    var far: Vector2 = world.player_position + Vector2(350, 180)
    var rng_before: int = world.rng.state
    world.spawn_loot({"xp":5,"coin":3}, far)
    expect(world.pickups.size() == 8 and units(world.pickups), "5 XP / 3 coins are eight separate value=1 units")
    expect(totals(world.pickups) == Vector2(3,5), "new drop totals equal the reward exactly")
    expect(world.rng.state == rng_before, "scatter does not change subsequent random rewards or encounters")
    var positions: Dictionary = {}
    for drop in world.pickups: positions[drop.position] = true
    expect(positions.size() == 8, "units have eight distinct scatter positions")
    world.pickups[0].position = world.player_position
    world.pickups[-1].position = world.player_position
    world.stats.xp_multiplier = 1.5
    world.update_pickups(0.0)
    expect(world.pickups.size() == 6 and world.coins == 1 and is_equal_approx(world.xp,1.5), "only the touched XP and coin units collect; XP bonus applies at collection")
    var partial: Dictionary = Session.capture(world)
    expect(world.save_store.write_run(partial).ok, "partial unit collection saves through real storage")
    expect(world.continue_game(), "partial unit collection resumes through normal continue flow")
    expect(world.pickups.size() == 6 and totals(world.pickups) == Vector2(2,4) and world.coins == 1 and is_equal_approx(world.xp,1.5), "continue preserves six remaining units and earned totals")
    var before_positions: Array = world.pickups.map(func(d): return d.position)
    expect(world.save_store.write_run(Session.capture(world)).ok and world.continue_game(), "a second save/continue succeeds")
    expect(world.pickups.map(func(d): return d.position) == before_positions, "already-unit positions do not scatter again on every load")
    world.stats.xp_multiplier = 1.5
    world.collect_all_drops()
    expect(world.coins == 3 and is_equal_approx(world.xp,7.5), "all eight resources are credited exactly once with the original XP rule")
    reset(world)
    world.spawn_loot({"xp":0,"coin":0}, far)
    expect(world.pickups.is_empty(), "zero rewards create no phantom collectibles")
    world.spawn_loot({"xp":300,"coin":300}, far + Vector2(3000,3000))
    expect(world.pickups.size() == 600 and units(world.pickups) and world.coins == 0 and world.xp == 0.0, "crossing 240 never silently collects or repacks any of 600 units")
    world.update_pickups(1.0/60.0)
    expect(world.pickups.size() == 600 and world.coins == 0 and world.xp == 0.0, "distant units remain physical and uncredited")
    expect(world.save_store.write_run(Session.capture(world)).ok and world.continue_game(), "more than 256 unit drops save and resume")
    expect(world.pickups.size() == 600 and totals(world.pickups) == Vector2(300,300), "high-count continue loses and duplicates no units")
    reset(world)
    var legacy: Dictionary = Session.capture(world)
    legacy.pickups = [{"kind":"xp","position":[1000,700],"value":5},{"kind":"coin","position":[1100,700],"value":3}]
    var legacy_rng: String = legacy.rng_state
    expect(world.save_store.write_run(legacy).ok and world.continue_game(), "old bundled save remains readable")
    expect(world.pickups.size() == 8 and units(world.pickups) and totals(world.pickups) == Vector2(3,5), "old 5/3 bundles migrate to eight equal unit objects")
    expect(str(world.rng.state) == legacy_rng and world.coins == 0 and world.xp == 0.0, "legacy migration neither consumes RNG nor credits uncollected resources")
    expect(world.save_store.write_run(Session.capture(world)).ok and world.continue_game(), "migrated units persist normally")
    expect(world.pickups.size() == 8 and totals(world.pickups) == Vector2(3,5), "migration is idempotent after another continue")
    legacy.pickups = [{"kind":"xp","position":[1000,700],"value":2.5}]
    expect(world.save_store.write_run(legacy).ok and world.continue_game(), "historically valid fractional XP is still readable")
    expect(units(world.pickups) and is_equal_approx(totals(world.pickups).y,2.5), "fractional legacy entitlement is retained without a multi-unit value")
    expect(world.save_store.write_run(Session.capture(world)).ok and world.continue_game(), "fractional entitlement survives another save/load")
    world.stats.xp_multiplier = 2.0
    world.collect_all_drops()
    expect(is_equal_approx(world.xp,5.0), "fractional legacy XP is credited exactly once, with the collection multiplier")
    check_reward_sources(world)
    check_art(world)
    world.queue_free()
    await process_frame
    print("CHARACTER LOOT RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)

func check_reward_sources(world) -> void:
    for fixture in [["hunter",false],["tank",true],["boss",false]]:
        reset(world)
        world.spawn_enemy(fixture[0], world.player_position + Vector2(300,0), fixture[1], "idle")
        var enemy: Dictionary = world.enemies.back()
        enemy.dodge = 0.0
        world.hurt_enemy(enemy,100000.0,"sling",true,Vector2.RIGHT)
        var count: int = world.pickups.size()
        var reward: Vector2 = totals(world.pickups)
        world.hurt_enemy(enemy,100000.0,"sling",true,Vector2.RIGHT)
        expect(count > 1 and units(world.pickups) and world.pickups.size() == count, "%s defeat creates only units and rewards once" % fixture[0])
        world.collect_all_drops()
        expect(Vector2(world.coins,world.xp) == reward, "%s rewards collect to the exact physical total" % fixture[0])
    reset(world)
    world.map_view.chunks.clear()
    for x in range(-3,4):
        for y in range(-3,4): world.map_view.chunks[Vector2i(x,y)] = []
    var at: Vector2 = world.player_position + Vector2(300,0)
    var prop := {"kind":"stone","id":"unit_rock","point":at,"scale":1.0,"angle":0.0,"size":43.0,"color":Color.WHITE}
    world.map_view.chunks[Vector2i(1,0)] = [prop]
    var rocks: Array = world.map_view.stone_targets(Rect2(at-Vector2(50,50),Vector2(100,100)))
    expect(rocks.size() == 1, "stone fixture is a real destructible target")
    if not rocks.is_empty():
        world.hurt_stone(rocks[0],100000.0)
        var count: int = world.pickups.size()
        world.hurt_stone(rocks[0],100000.0)
        expect(count >= 2 and count <= 4 and units(world.pickups) and world.pickups.size() == count, "a stone produces 2-4 real units once, including repeated same-frame damage")

func check_art(world) -> void:
    var silhouettes: Array[Image] = []
    for id in Catalog.CHARACTER_ORDER:
        var profile: Dictionary = Catalog.character(id)
        world.character_id = id
        world.start_run(false)
        expect(not str(profile.body).is_empty() and world.hero.body_resource_path() == profile.body, "selected and resumed %s uses its configured redesigned body" % id)
        expect(str(profile.portrait).contains("/characters/v") and ResourceLoader.exists(profile.portrait), "%s selection uses its versioned actor portrait" % id)
        var portrait: Image = load(profile.portrait).get_image()
        var portrait_bounds: Rect2i = portrait.get_used_rect()
        expect(portrait_bounds.position.x>0 and portrait_bounds.end.x<portrait.get_width() and portrait_bounds.position.y>0 and portrait_bounds.end.y<portrait.get_height(), "%s portrait contains every outlined limb within transparent edges" % id)
        var body: Sprite2D = world.hero.parts.body
        expect(absf(body.texture.get_image().get_used_rect().size.y*body.scale.y-66.0) < 0.1, "%s visible body fits existing gameplay height and limb rig" % id)
        var image: Image = body.texture.get_image()
        image.resize(40,48,Image.INTERPOLATE_LANCZOS)
        silhouettes.append(image)
    for i in range(silhouettes.size()):
        for j in range(i+1,silhouettes.size()):
            var different := 0
            for y in range(48):
                for x in range(40):
                    if (silhouettes[i].get_pixel(x,y).a > 0.5) != (silhouettes[j].get_pixel(x,y).a > 0.5): different += 1
            expect(different > 90, "normal-size silhouettes of %s / %s differ beyond a palette swap" % [Catalog.CHARACTER_ORDER[i], Catalog.CHARACTER_ORDER[j]])
    for key in ["left_hand","right_hand","left_foot","right_foot"]:
        var limb: Sprite2D = world.hero.parts[key]
        var image: Image = limb.texture.get_image()
        var used: Rect2i = image.get_used_rect()
        var margin: int = mini(mini(used.position.x,used.position.y),mini(image.get_width()-used.end.x,image.get_height()-used.end.y))
        expect(margin>=24 and limb.material==null, "transparent %s edges retain the original ink without a cyan outline" % key)
