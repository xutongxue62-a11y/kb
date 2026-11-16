extends SceneTree
var checks:=0
var failures:=0
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var support=load("res://src/companions.gd").new()
    root.add_child(support)
    var target: Dictionary={"position":Vector2(300,0),"hp":10000.0,"radius":16.0,"elite":false}
    support.advance(0.0,Vector2.ZERO,[target],{"pet":1},{"attack_speed":1.0})
    var previous: Vector2=support.states.pet.position
    var hits: int=0
    for i in range(180):
        for hit in support.advance(1.0/60.0,Vector2.ZERO,[target],{"pet":1},{"attack_speed":1.0}):
            hits+=1
            expect(hit.position.distance_to(target.position)<=55.01,"slower pet still bites only on contact")
        var current: Vector2=support.states.pet.position
        var speed: float=current.distance_to(previous)*60.0
        expect(speed<=225.1,"ground chase never uses the previous 460px/s slide")
        if i==0: expect(speed<=16.0,"pet accelerates from rest rather than instantly jumping to full speed")
        previous=current
    expect(hits>=2,"slower pet reaches a 300px target and continues attacking")
    support.reset()
    var edge: Dictionary={"position":Vector2(365,0),"hp":10000.0,"radius":16.0,"elite":true}
    var near: Dictionary={"position":Vector2(85,0),"hp":10000.0,"radius":16.0,"elite":false}
    var edge_hits:=0
    for i in range(240):
        for hit in support.advance(1.0/60.0,Vector2.ZERO,[near,edge],{"pet":1},{"attack_speed":1.0},true):
            if hit.enemy==edge: edge_hits+=1
    expect(edge_hits>0,"reachable elite at the leash edge is not starved by an overly distant stop point")
    expect(support.states.pet.has("stride") and support.states.pet.has("velocity"),"movement carries actual travelled gait phase and velocity")
    if support.states.pet.has("stride"):
        var phase: float=support.states.pet.stride
        for i in range(60): support.advance(1.0/60.0,Vector2.ZERO,[near,edge],{"pet":1},{"attack_speed":1.0},true)
        expect(is_equal_approx(phase,float(support.states.pet.stride)),"feet stop stepping when the pet has stopped")
    support.reset()
    var hero:=Vector2.ZERO
    var max_gap:=0.0
    for i in range(1800):
        hero.x+=286.0/60.0
        support.advance(1.0/60.0,hero,[],{"pet":1,"drone":1},{"attack_speed":1.0,"speed":286.0})
        for key in ["pet","drone"]: max_gap=maxf(max_gap,hero.distance_to(support.states[key].position))
    expect(max_gap<390.0,"followers remain on screen through thirty seconds of maximum-speed player travel")
    var far_target: Dictionary={"position":hero+Vector2(1100,0),"hp":10000.0,"radius":16.0,"elite":false}
    var distant: Array=support.advance(1.0/60.0,hero+Vector2(1000,0),[far_target],{"pet":1,"drone":1},{"attack_speed":1.0,"speed":286.0})
    expect(distant.is_empty(),"offscreen followers regroup instead of firing a world-length beam")
    var rig_path: String="res://src/support_rig.gd"
    expect(ResourceLoader.exists(rig_path),"supports have articulated ink art instead of one rigid bitmap")
    if ResourceLoader.exists(rig_path):
        var rig=load(rig_path)
        var state: Dictionary={"stride":1.0,"moving":true,"attack":0.0,"aim":Vector2.RIGHT,"facing":1.0,"position":Vector2.ZERO}
        var p: Dictionary=rig.pose("pet",state,0.0)
        state.stride=2.4
        var q: Dictionary=rig.pose("pet",state,0.0)
        expect(p.front_foot!=q.front_foot and p.back_foot!=q.back_foot,"travel phase independently moves both ground feet")
        var a: Dictionary=rig.pose("drone",state,0.0)
        var b: Dictionary=rig.pose("drone",state,0.12)
        expect(absf(a.wing-b.wing)>0.15,"flyer changes wing hinge angle independently of the body")
        for id in ["pet_body","pet_head","pet_tail","pet_leg","drone_body","drone_wing"]:
            var texture: Texture2D=rig.texture(id)
            expect(texture!=null and texture==rig.texture(id),"articulated part is cached: "+id)
    support.queue_free()
    print("COMPANIONS V16 RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)
