extends SceneTree

var checks: int = 0
var failures: int = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func _initialize() -> void:
    if not FileAccess.file_exists("res://src/armory.gd"):
        expect(false,"four distinct new weapon attacks are not implemented")
        finish()
        return
    call_deferred("run_checks")

func run_checks() -> void:
    var armory = load("res://src/armory.gd").new()
    root.add_child(armory)
    var views: Dictionary = {}
    for key in ["spear","hammer","boomerang","totem"]:
        var view: Sprite2D = Sprite2D.new()
        armory.add_child(view)
        views[key] = view
    var enemies: Array = [{"id":1,"position":Vector2(90,0),"hp":100.0,"radius":20.0},{"id":2,"position":Vector2(140,0),"hp":100.0,"radius":20.0},{"id":3,"position":Vector2(190,0),"hp":100.0,"radius":20.0}]
    var stats: Dictionary = {"attack_speed":1.0}
    var events: Array = []
    for index in range(24):
        events.append_array(armory.advance(1.0/60.0,Vector2.ZERO,enemies,[{"id":"spear","level":1}],stats,false,views))
    expect(events.filter(func(event):return event["type"]=="hit").size() >= 2,"a real spear thrust pierces more than one enemy along its line")
    armory.reset()
    events.clear()
    for index in range(32):
        events.append_array(armory.advance(1.0/60.0,Vector2.ZERO,enemies,[{"id":"hammer","level":1}],stats,false,views))
    var areas: Array = events.filter(func(event):return event["type"]=="area")
    expect(areas.size()==1 and areas[0]["radius"]>=70 and is_equal_approx(areas[0]["damage"], 21.6 * 0.92),"hammer produces one delayed area smash with actual starting damage")
    var hammer_damage: Array[float] = []
    for thunder in [false, true]:
        armory.reset()
        events.clear()
        stats["hammer_thunder"] = thunder
        for index in range(32):
            events.append_array(armory.advance(1.0/60.0, Vector2.ZERO, enemies, [{"id":"hammer","level":10}], stats, false, views))
        areas = events.filter(func(event): return event["type"] == "area")
        hammer_damage.append(float(areas[0]["damage"]) if not areas.is_empty() else 0.0)
    expect(hammer_damage[1] > 0.0 and is_equal_approx(hammer_damage[0], hammer_damage[1] * 1.06), "only the ordinary hammer gets the new late weapon bonus")
    armory.reset()
    events.clear()
    # One cycle returns in ~0.56s; the new 0.76s interval would already start a
    # second throw by frame 48, so stop while the first boomerang is home.
    for index in range(42):
        events.append_array(armory.advance(1.0/60.0,Vector2.ZERO,enemies,[{"id":"boomerang","level":1}],stats,false,views))
    var first_hits: Array = events.filter(func(event):return event["type"]=="hit" and event["enemy"]["id"]==1)
    expect(first_hits.size()==2,"boomerang damages a crossed target once outbound and once returning")
    expect(armory.states["boomerang"]["phase"]=="rest" and views["boomerang"].position.length()<60,"boomerang physically returns to its owner")
    armory.reset()
    events = armory.advance(0.02,Vector2.ZERO,enemies,[{"id":"totem","level":1}],stats,false,views)
    var hits: Array = events.filter(func(event):return event["type"]=="hit")
    var unique: Dictionary = {}
    for hit in hits:
        unique[hit["enemy"]["id"]]=true
    expect(hits.size()==3 and unique.size()==3,"totem chains through three distinct real enemy dictionaries")
    expect(hits[0]["damage"]>hits[1]["damage"] and hits[1]["damage"]>hits[2]["damage"],"chain lightning loses damage at each jump")
    armory.reset()
    events = armory.advance(0.02,Vector2.ZERO,[],[{"id":"totem","level":1}],stats,false,views)
    expect(events.is_empty(),"no target produces no phantom attacks")
    for key in ["spear","hammer","boomerang","totem"]:
        var texture: Texture2D = load("res://src/weapon_art.gd").texture(key)
        expect(texture!=null and texture.get_size()==Vector2(128,128),"new weapon has its own rendered icon: "+key)
        var icon: Image = texture.get_image()
        expect(icon.get_pixel(0,0).a==0.0,"new icon background is transparent: "+key)
    armory.reset()
    expect(armory.states.is_empty(),"reset clears cooldowns and in-flight new weapons")
    armory.queue_free()
    await process_frame
    finish()

func finish() -> void:
    print("ARMORY RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures>0 else 0)
