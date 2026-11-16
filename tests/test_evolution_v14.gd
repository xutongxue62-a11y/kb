extends SceneTree
const Main = preload("res://src/main.gd")
var checks := 0
var failures := 0
func expect(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + message)
func _initialize() -> void: call_deferred("run_checks")
func equip(world, id: String, level: int) -> void:
    world.clear_weapons()
    for i in range(level): world.grant_weapon(id)
    world.projectiles.clear()
    world.clear_enemies()
    world.spawn_enemy("tank",world.player_position+Vector2(220,0),false,"idle")
    world.enemies.back().hp=10000.0
    world.enemies.back().max_hp=10000.0
    world.enemies.back().dodge=0.0
    world.sync_idle_loadout()
func run_checks() -> void:
    var world = Main.new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/evolution_v14_"+str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.demo=true
    world.start_run(true)
    for fixture in [["sling",1,1],["sling",2,1],["sling",3,2],["sling",5,3],["staff",1,3],["staff",3,4],["staff",5,5]]:
        equip(world,fixture[0],fixture[1])
        world.weapon_runtime[fixture[0]].cooldown=0
        world.update_weapons(0.01)
        expect(world.projectiles.size()==fixture[2],"%s Lv%d fires %d real projectiles" % fixture)
        if fixture[0]=="sling" and fixture[1]==5:
            expect(world.projectiles.all(func(p):return p.bounces_left>=1),"awakened sling shots can ricochet")
    for id in world.Catalog.IDS:
        equip(world,id,1)
        var first: Image = world.weapon_views[id].texture.get_image()
        world.grant_weapon(id)
        world.grant_weapon(id)
        var third: Image = world.weapon_views[id].texture.get_image()
        world.grant_weapon(id)
        world.grant_weapon(id)
        var fifth: Image = world.weapon_views[id].texture.get_image()
        expect(first.get_data()!=third.get_data() and third.get_data()!=fifth.get_data(),"%s has distinct actual level 1 / 3 / 5 weapon textures" % id)
    for fixture in [["bonebow",1,1],["bonebow",3,2],["bonebow",5,3],["firepot",1,1],["firepot",3,2],["firepot",5,3]]:
        equip(world,fixture[0],fixture[1])
        world.update_armory(0.01)
        var key: String="arrows" if fixture[0]=="bonebow" else "pots"
        expect(world.armory.states[fixture[0]][key].size()==fixture[2],"%s Lv%d launches %d physical attacks" % fixture)
    equip(world,"wardrum",5)
    var beats: int=0
    for i in range(120):
        world.update_armory(0.01)
        beats=maxi(beats,int(world.armory.states.wardrum.beat_count))
    expect(beats==5,"awakened drum performs a real five-beat sequence")
    for fixture in [["fire_drum",["firepot","wardrum"]],["thunder_crystal",["totem","crystal"]],["storm_arrow",["bonebow","totem"]]]:
        var profile: Dictionary=world.Rules.link_profile(fixture[0],fixture[1])
        expect(profile.id==fixture[0],"coherent pair is selectable: "+fixture[0])
        expect(world.Rules.link_profile(fixture[0],[fixture[1][0]]).id=="none","one missing partner cannot create "+fixture[0])
    expect(world.Rules.link_options(["club","crystal"]).size()==1,"unrelated weapons get no forced recipe")
    check_specials(world)
    check_synergies(world)
    equip(world,"bonebow",5)
    for i in range(3): world.grant_weapon("totem")
    world.select_link("storm_arrow")
    var state: Dictionary=world.SessionState.capture(world)
    expect(world.save_store.write_run(state).ok and world.continue_game(),"new recipe and milestone equipment save through the existing schema")
    expect(world.weapon_level("bonebow")==5 and world.weapon_level("totem")==3 and world.active_link.id=="storm_arrow","resume retains both milestone levels and the selected two-weapon recipe")
    expect(world.weapon_views.bonebow.texture.get_image().get_data()==world.library.weapon_texture("bonebow",5).get_image().get_data(),"resumed battle weapon uses the awakened appearance")
    world.queue_free()
    await process_frame
    print("EVOLUTION V14 RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)

func check_specials(world) -> void:
    for fixture in [[1,3],[3,4],[5,8]]:
        equip(world,"totem",fixture[0])
        world.clear_enemies()
        for i in range(8):
            world.spawn_enemy("hunter",world.player_position+Vector2(180,i*30),false,"idle")
        var events: Array=world.armory.advance(0.01,world.player_position,world.enemies,world.inventory,world.stats,false,world.weapon_views,world.current_weapon_mounts())
        expect(events.filter(func(e):return e.type=="hit").size()==fixture[1],"totem Lv%d creates %d distinct lightning hits" % fixture)
    for fixture in [[1,1],[3,2],[5,3]]:
        equip(world,"hammer",fixture[0])
        world.enemies[0].position=world.player_position+Vector2(100,0)
        var areas: int=0
        for i in range(38):
            var events: Array=world.armory.advance(0.01,world.player_position,world.enemies,world.inventory,world.stats,false,world.weapon_views,world.current_weapon_mounts())
            areas+=events.filter(func(e):return e.type=="area").size()
        expect(areas==fixture[1],"hammer Lv%d produces %d real shock/impact events" % fixture)
    for fixture in [[1,1],[3,3],[5,6]]:
        equip(world,"spear",fixture[0])
        world.clear_enemies()
        for y in [-34,0,34]:
            world.spawn_enemy("hunter",world.player_position+Vector2(150,y),false,"idle")
            world.enemies.back().radius=8.0
        var hits: int=0
        for i in range(25):
            var events: Array=world.armory.advance(0.01,world.player_position,world.enemies,world.inventory,world.stats,false,world.weapon_views,world.current_weapon_mounts())
            hits+=events.filter(func(e):return e.type=="hit").size()
        expect(hits==fixture[1],"spear Lv%d actually strikes %d targets across fan/echo thrusts" % fixture)
    for level in [1,3,5]:
        equip(world,"club",level)
        var primary: Dictionary=world.enemies[0]
        world.spawn_enemy("hunter",primary.position+Vector2(30,0),false,"idle")
        var other: Dictionary=world.enemies.back()
        other.hp=1000.0
        world.stats.crit_chance=0.0
        for i in range(3): world.hurt_enemy(primary,1.0,"club",false,Vector2.RIGHT)
        expect((other.hp<1000.0)==(level>=3),"club milestone creates actual nearby quake damage only after unlock")

func check_synergies(world) -> void:
    equip(world,"firepot",1)
    world.grant_weapon("wardrum")
    world.select_link("fire_drum")
    world.spawn_enemy("hunter",world.player_position+Vector2(110,0),false,"idle")
    world.update_armory(0.01)
    world.armory.states.firepot.fires=[{"position":world.player_position+Vector2(80,0),"age":0.0,"next_tick":0.0,"damage":1.0,"radius":56.0}]
    for i in range(24): world.update_armory(0.01)
    expect(world.armory.states.firepot.fires[0].radius>56.0,"selected drum/fire recipe fans an existing flame field")
    equip(world,"totem",1)
    world.grant_weapon("crystal")
    world.select_link("thunder_crystal")
    world.update_armory(0.01)
    var mine:={"from":world.player_position,"position":world.enemies[0].position+Vector2(90,0),"age":0.65,"damage":1.0,"speed":420.0,"trigger":54.0}
    world.armory.states.crystal.mines=[mine]
    world.armory.states.totem.cooldown=0.0
    world.update_armory(0.01)
    expect(bool(mine.get("charged",false)),"selected lightning/crystal recipe charges a nearby mine through a real beam")
    world.update_armory(0.01)
    expect(world.armory.states.crystal.shards.size()==10,"charged crystal emits a ten-shard discharge")
    equip(world,"bonebow",1)
    world.grant_weapon("totem")
    world.select_link("storm_arrow")
    var target: Dictionary=world.enemies[0]
    world.spawn_enemy("hunter",target.position+Vector2(0,85),false,"idle")
    var neighbor: Dictionary=world.enemies.back()
    neighbor.hp=1000.0
    neighbor.max_hp=1000.0
    neighbor.dodge=0.0
    world.update_armory(0.01)
    expect(is_equal_approx(neighbor.hp,1000.0),"conductive-arrow recipe suppresses autonomous totem fire")
    for i in range(50): world.update_armory(0.01)
    expect(neighbor.hp<1000.0,"a landed conductive arrow actually arcs to a neighbor outside its flight line")
    target.dodge=1.0
    neighbor.hp=1000.0
    world.armory.states.bonebow.arrows.clear()
    world.armory.states.bonebow.cooldown=0.0
    for i in range(50): world.update_armory(0.01)
    expect(is_equal_approx(neighbor.hp,1000.0),"a dodged conductive arrow does not grant free lightning damage")
    equip(world,"bonebow",3)
    world.grant_weapon("totem")
    world.select_link("storm_arrow")
    target=world.enemies[0]
    target.hp=0.5
    target.dodge=0.0
    world.spawn_enemy("hunter",target.position+Vector2(0,85),false,"idle")
    neighbor=world.enemies.back()
    neighbor.hp=1000.0
    neighbor.max_hp=1000.0
    neighbor.dodge=0.0
    world.update_armory(0.4)
    expect(is_equal_approx(neighbor.hp,996.787),"same-frame twin arrows killing one target grant only the one landed-hit lightning arc")
