extends SceneTree
class RefusingStore:
    extends "res://src/save_store.gd"
    func write_run(_state: Variant) -> Dictionary:
        return {"ok":false,"error":"isolated test refusal"}
var checks:=0
var failures:=0
func expect(ok: bool,message: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        print("FAIL: "+message)
func _initialize() -> void: call_deferred("run_checks")
func run_checks() -> void:
    var map=load("res://src/world_map.gd").new()
    expect(map.has_method("stone_targets") and map.has_method("damage_stone"),"rocks expose real health and weapon damage")
    expect(FileAccess.file_exists("res://src/loot_rules.gd"),"difficulty-based random loot rules exist")
    if failures:
        map.free()
        finish()
        return
    root.add_child(map)
    map.set_process(false)
    for x in range(-3,4):
        for y in range(-3,4): map.chunks[Vector2i(x,y)]=[]
    var at:=Vector2(640,401)
    var prop:={"kind":"stone","id":"ochre:1:0:0","point":at,"scale":1.0,"angle":0.0,"seed":3}
    map.chunks[Vector2i(1,0)]=[prop]
    var rocks: Array=map.stone_targets(Rect2(at-Vector2(100,100),Vector2(200,200)))
    expect(rocks.size()==1,"one actual stone produces one attack target")
    var rock: Dictionary=rocks[0]
    var result: Dictionary=map.damage_stone(rock,rock.max_hp-1)
    expect(result.hit and not result.destroyed,"a nonlethal stone hit leaves collision intact")
    expect(map.move_body(at-Vector2(100,0),at+Vector2(100,0),18).x<at.x,"damaged stone still blocks movement")
    result=map.damage_stone(rock,2)
    expect(result.destroyed,"lethal stone hit destroys once")
    expect(not map.damage_stone(rock,999).hit,"same-frame repeat damage cannot re-destroy a rock")
    expect(map.stone_targets(Rect2(at-Vector2(100,100),Vector2(200,200))).is_empty(),"broken rock cannot be targeted again")
    expect(map.move_body(at-Vector2(100,0),at+Vector2(100,0),18).distance_to(at+Vector2(100,0))<0.1,"broken rock releases its actual collision")
    var saved: Dictionary=map.capture_terrain()
    map.chunks.clear()
    map.restore_terrain(saved)
    map.chunks[Vector2i(1,0)]=[prop]
    expect(map.stone_targets(Rect2(at-Vector2(100,100),Vector2(200,200))).is_empty(),"stream cache eviction and restoration cannot respawn a broken stone")
    var loot=load("res://src/loot_rules.gd")
    var rng:=RandomNumberGenerator.new()
    rng.seed=1200
    var tiny_total:=0
    var heavy_total:=0
    var elite_total:=0
    var late_total:=0
    var outcomes: Dictionary={}
    for i in range(160):
        var small: Dictionary=loot.enemy_reward("hunter",1,false,62,rng)
        outcomes[str(small)]=true
        tiny_total+=small.coin+small.xp
        var heavy: Dictionary=loot.enemy_reward("tank",1,false,91,rng)
        heavy_total+=heavy.coin+heavy.xp
        var elite: Dictionary=loot.enemy_reward("tank",1,true,108,rng)
        elite_total+=elite.coin+elite.xp
        var late: Dictionary=loot.enemy_reward("tank",12,false,91,rng)
        late_total+=late.coin+late.xp
        var rock_loot: Dictionary=loot.rock_reward(rng)
        expect(rock_loot.coin>=1 and rock_loot.coin<=2 and rock_loot.xp>=1 and rock_loot.xp<=2,"rock drops remain a small resource reward")
    expect(outcomes.size()>1,"identical monsters have real random drop amounts")
    expect(heavy_total>tiny_total and elite_total>heavy_total and late_total>heavy_total,"large, elite and later enemies have stronger resource bands")
    map.queue_free()
    await process_frame
    var world=load("res://src/main.gd").new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/tests/resources_v12_"+str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.start_run(true,"base")
    world.clear_enemies()
    world.map_view.chunks.clear()
    for x in range(-3,4):
        for y in range(-3,4): world.map_view.chunks[Vector2i(x,y)]=[]
    world.map_view.chunks[Vector2i(1,0)]=[prop]
    var target: Dictionary=world.map_view.stone_targets(Rect2(at-Vector2(100,100),Vector2(200,200)))[0]
    var kills: int=world.kills
    world.hurt_enemy(target,999,"sling",false,Vector2.RIGHT)
    var mined_count: int=world.pickups.size()
    world.hurt_enemy(target,999,"sling",false,Vector2.RIGHT)
    expect(mined_count>=2 and mined_count<=4 and world.pickups.size()==mined_count and world.pickups.all(func(d):return d.value==1) and world.kills==kills,"actual weapon mining drops unit resources exactly once without a fake monster kill")
    var state: Dictionary=world.SessionState.capture(world,false)
    expect(world.save_store.write_run(state).ok and world.continue_game(),"broken-rock state saves and reloads through real storage")
    expect(world.map_view.stone_health.get("ochre:1:0:0",-1)==0,"loaded game retains broken rocks")
    var invalid: Dictionary=state.duplicate(true)
    invalid.terrain_state.stone_health["bad"]=-1
    expect(not world.save_store.write_run(invalid).ok,"invalid negative stone health cannot overwrite a valid save")
    world.start_run(false)
    world.clear_enemies()
    world.spawn_clock=999
    world.invulnerable=999
    world.map_view.chunks.clear()
    for x in range(-3,4):
        for y in range(-3,4): world.map_view.chunks[Vector2i(x,y)]=[]
    var distant: Dictionary=prop.duplicate(true)
    distant.point=at+Vector2(240,0)
    world.map_view.chunks[Vector2i(1,0)]=[distant]
    for i in range(360): world.simulate(1.0/60.0,Vector2.ZERO)
    expect(world.map_view.stone_health.get(distant.id,-1)==0 and world.pickups.size()>=2 and world.pickups.size()<=4 and world.pickups.all(func(d):return d.value==1),"actual automatic sling projectiles break an idle rock and release individual loot")
    expect(world.save_game(),"broken idle rock is written before later isolated fixtures")
    var enemy:={"id":123,"hp":1.0,"position":at+Vector2(250,0),"elite":false}
    var nearer_rock:={"id":"stone:test","hp":22.0,"position":at+Vector2(40,0),"stone":true,"elite":false}
    expect(world.Rules.choose_target(at,360,[nearer_rock,enemy]).id==123,"nearby mining cannot steal automatic fire from a living enemy in range")
    world.settings["autosave"]=false
    world.start_run(false)
    world.clear_enemies()
    world.spawn_clock=999
    world.invulnerable=999
    world.map_view.chunks.clear()
    for x in range(-3,4):
        for y in range(-3,4): world.map_view.chunks[Vector2i(x,y)]=[]
    var close_rock:=prop.duplicate(true)
    close_rock.id="ochre:pref:0:0"
    close_rock.point=at+Vector2(70,0)
    world.map_view.chunks[Vector2i(1,0)]=[close_rock]
    world.spawn_enemy("hunter", at+Vector2(220,0))
    var foe: Dictionary=world.enemies.back()
    foe.hp=400.0
    foe.max_hp=400.0
    var foe_hp: float=foe.hp
    var rock_id: String=world.map_view.stone_id(close_rock)
    var rock_hp: float=world.map_view.stone_max_hp(close_rock)
    for i in range(90): world.simulate(1.0/60.0,Vector2.ZERO)
    expect(foe.hp<foe_hp and foe.hp>0.0 and world.map_view.stone_health.get(rock_id, rock_hp)==rock_hp,"a loaded sling prefers a living monster over a closer rock")
    world.clear_enemies()
    world.projectiles.clear()
    for i in range(240): world.simulate(1.0/60.0,Vector2.ZERO)
    expect(world.map_view.stone_health.get(rock_id, rock_hp)<rock_hp,"the same sling still mines a rock once no monster remains")
    world.set_start_weapon("club")
    world.start_run(false)
    world.clear_enemies()
    world.spawn_clock=999
    world.invulnerable=999
    world.map_view.chunks.clear()
    for x in range(-3,4):
        for y in range(-3,4): world.map_view.chunks[Vector2i(x,y)]=[]
    var orbit_rock:=prop.duplicate(true)
    orbit_rock.id="ochre:melee:0:0"
    orbit_rock.point=at+Vector2(60,0)
    world.map_view.chunks[Vector2i(1,0)]=[orbit_rock]
    world.spawn_enemy("hunter", at+Vector2(90,0))
    var brawler: Dictionary=world.enemies.back()
    brawler.hp=400.0
    brawler.max_hp=400.0
    var brawler_hp: float=brawler.hp
    var orbit_id: String=world.map_view.stone_id(orbit_rock)
    var orbit_hp: float=world.map_view.stone_max_hp(orbit_rock)
    for i in range(90): world.simulate(1.0/60.0,Vector2.ZERO)
    expect(brawler.hp<brawler_hp and brawler.hp>0.0 and world.map_view.stone_health.get(orbit_id, orbit_hp)==orbit_hp,"orbiting melee skips nearby rocks while a monster is in reach")
    world.start_run(true,"base")
    var protected: Dictionary=world.save_store.read_run()
    expect(protected.ok and protected.state.terrain_state.stone_health.get(distant.id,-1)==0,"entering trial preserves broken rocks in the protected normal save")
    world.settings["autosave"]=true
    world.start_run(false)
    world.map_view.stone_health[distant.id]=0.0
    world.save_store=RefusingStore.new("res://runtime/tests/refusing_v12_"+str(Time.get_ticks_usec()))
    world.start_run(true,"base")
    expect(not world.trial_mode and world.map_view.stone_health.get(distant.id,-1)==0,"failed protective save leaves the current normal map untouched")
    world.queue_free()
    await process_frame
    finish()
func finish() -> void:
    print("RESOURCES V12 RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
