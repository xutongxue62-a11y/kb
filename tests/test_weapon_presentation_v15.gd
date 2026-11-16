extends SceneTree
const Main=preload("res://src/main.gd")
const Probe=preload("res://tests/weapon_pose_probe.gd")
var checks:=0
var failures:=0
var clearance: Dictionary={}
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        print("FAIL: "+label)
func _initialize() -> void: call_deferred("run_checks")
func equip(world,ids: Array,level: int) -> void:
    world.clear_weapons()
    for id in ids:
        for i in range(level): world.grant_weapon(id)
    world.sync_idle_loadout()
func run_checks() -> void:
    var world=Main.new()
    world.save_store=load("res://src/save_store.gd").new("res://runtime/tests/weapon_presentation_v15_"+str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.settings.autosave=false
    world.start_run(false)
    world.clear_enemies()
    for compact in [false,true]:
        world.collapsed=compact
        equip(world,["bonebow","powder","staff","totem","firepot","crystal"],3)
        var nearest:=INF
        var ids: Array=world.weapon_views.keys()
        for first in range(ids.size()):
            for second in range(first+1,ids.size()):
                nearest=minf(nearest,Probe.visible_center(world.weapon_views[ids[first]]).distance_to(Probe.visible_center(world.weapon_views[ids[second]])))
        expect(nearest>=26.0,"six idle carried weapons retain readable row separation (compact=%s min=%.1f)" % [compact,nearest])
    for level in [1,3,5]:
        for id in Main.Catalog.IDS:
            equip(world,[id],level)
            for compact in [false,true]:
                world.collapsed=compact
                world.formation_phase=0
                world.sync_idle_loadout()
                var view: Sprite2D=world.weapon_views[id]
                var distance: float=Probe.visible_center(view).distance_to(world.player_position)
                expect(distance<=70.0 if Main.Rules.is_parked_weapon(id) else distance<=102.0,"visible %s Lv%d stays near the hero (compact=%s distance=%.1f)" % [id,level,compact,distance])
    for id in Main.Catalog.CHARACTER_ORDER:
        world.hero.set_character(id)
        for level in [1,5]:
            check_loadout(world,["bonebow","powder","staff","spear","totem","crystal"],level,id)
            check_loadout(world,["hammer","boomerang","firepot","wardrum","sling","totem"],level,id)
    for ids in [["bonebow"],["bonebow","powder","staff","totem","firepot","crystal"]]:
        for level in [1,5]:
            equip(world,ids,level)
            world.clear_enemies()
            world.spawn_enemy("tank",world.player_position+Vector2(-230 if ids.size()==1 else 230,0),false,"idle")
            world.enemies.back().hp=10000.0
            world.enemies.back().dodge=0.0
            world.update_armory(0.01)
            var arrows: Array=world.armory.states.bonebow.arrows
            var forward: Vector2=Vector2.UP.rotated(world.weapon_views.bonebow.rotation)
            expect(not arrows.is_empty() and forward.dot(arrows[0].direction)>0.999,"firing bow points along its real arrow outside the idle cone, slots%d Lv%d" % [ids.size(),level])
    world.queue_free()
    await process_frame
    print("WEAPON PRESENTATION V15 RESULT: %d checks, %d failures" % [checks,failures])
    if not clearance.is_empty(): print("EXTRA HOLD PIXELS: ",clearance)
    quit(1 if failures else 0)

func check_loadout(world,ids: Array,level: int,id: String) -> void:
    equip(world,ids,level)
    for compact in [false,true]:
        world.collapsed=compact
        for direction in range(8):
            var aim:=Vector2.from_angle(direction*TAU/8.0)
            for key in ["powder","staff","sling"]:
                if world.weapon_runtime.has(key):
                    world.weapon_runtime[key].aim=aim
                    world.weapon_runtime[key].recoil=0.12
            for key in world.armory.states:
                world.armory.states[key].direction=aim
            world.sync_idle_loadout()
            for key in world.weapon_runtime: world.weapon_runtime[key].glow=0.2
            world.apply_weapon_glows(0.0)
            for key in world.weapon_views:
                var area: float=Probe.torso_overlap_area(world.hero.parts.body,world.weapon_views[key])
                if area>2.0 and OS.get_cmdline_user_args().has("--measure-clearance"):
                    clearance[key]=maxf(float(clearance.get(key,0.0)),Probe.minimum_extra_hold(world.hero.parts.body,world.weapon_views[key]))
                expect(area<=2.0,"opaque %s clears %s torso at Lv%d / aim%d / compact%s (%.2fpx2)" % [key,id,level,direction,compact,area])
