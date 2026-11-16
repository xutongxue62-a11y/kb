extends Node2D
const Rules = preload("res://src/rules.gd")
const SupportArt = preload("res://src/support_art.gd")
const SupportRig = preload("res://src/support_rig.gd")
const PET_LEASH := 320.0
const PET_RANGE := 370.0
const PET_BITE := 39.0
const PET_SPEED := 225.0
const PET_ACCELERATION := 820.0
const MIN_COOLDOWN := 0.14
var terrain: Node = null
var states: Dictionary = {}
var clock := 0.0

func reset() -> void:
    states.clear()
    clock = 0.0
    queue_redraw()

func advance(delta: float, hero: Vector2, enemies: Array, levels: Dictionary, stats: Dictionary, prefer_elite: bool = false) -> Array:
    clock += delta
    var attacks: Array = []
    var haste := clampf(float(stats.get("attack_speed", 1.0)), 0.25, 4.6)
    for key in ["pet", "drone"]:
        var level := clampi(int(levels.get(key, 0)), 0, 6)
        if level == 0:
            states.erase(key)
            continue
        var offset := Vector2(-48, 34) if key == "pet" else Vector2(-62, -48)
        if not states.has(key):
            states[key] = {"position": hero + offset, "velocity":Vector2.ZERO, "stride":0.0, "regroup":false, "cooldown": 0.0, "attack": 0.0, "facing": 1.0, "level": level, "moving": false, "aim": Vector2.RIGHT}
        var state: Dictionary = states[key]
        state["level"] = level
        var gap: float=Vector2(state.position).distance_to(hero)
        if gap>350.0: state["regroup"]=true
        elif gap<130.0: state["regroup"]=false
        # Cooldowns are real seconds. Haste shortens interval once, with a hard floor.
        state["cooldown"] = maxf(0.0, state["cooldown"] - delta)
        state["attack"] = maxf(0.0, state["attack"] - delta)
        var candidates: Array = enemies
        if key == "pet":
            candidates = enemies.filter(func(enemy): return hero.distance_to(enemy["position"]) <= minf(PET_RANGE, PET_LEASH + float(enemy["radius"]) + PET_BITE))
        else:
            candidates=enemies.filter(func(enemy):return hero.distance_squared_to(enemy.position)<=420.0*420.0)
        var target: Dictionary=Rules.choose_target(hero if key=="pet" else state.position,PET_RANGE if key=="pet" else 420.0,candidates,prefer_elite)
        if state.regroup: target={}
        var destination := hero + offset
        if key == "pet" and not target.is_empty():
            var approach: Vector2=(target.position-state.position).normalized()
            var contact: Vector2=target.position-approach*maxf(0.0,float(target.radius)+PET_BITE-8.0)
            destination=hero+(contact-hero).limit_length(PET_LEASH)
        var previous: Vector2 = state["position"]
        var difference: Vector2=destination-previous
        var distance: float=difference.length()
        var max_speed: float=PET_SPEED if key=="pet" else 250.0
        var player_speed: float=maxf(0.0,float(stats.get("speed",210.0)))
        if target.is_empty(): max_speed=maxf(max_speed,player_speed*(1.06 if key=="pet" else 1.10))
        if state.regroup: max_speed=maxf(max_speed,player_speed+65.0)
        max_speed=minf(max_speed,360.0 if key=="pet" else 380.0)
        var acceleration: float=PET_ACCELERATION if key=="pet" else 650.0
        var desired: Vector2=difference.normalized()*minf(max_speed,sqrt(2.0*acceleration*distance)) if distance>0.2 else Vector2.ZERO
        var velocity: Vector2=Vector2(state.get("velocity",Vector2.ZERO)).move_toward(desired,maxf(delta,0.0)*acceleration)
        var next: Vector2=previous+velocity*maxf(delta,0.0)
        if distance<0.2 or (next-previous).length()>distance: next=destination
        if key == "pet" and terrain != null and terrain.has_method("move_body"):
            next = terrain.move_body(previous, next, 18.0)
        state["position"] = next
        state["velocity"]=(next-previous)/delta if delta>0.000001 else Vector2.ZERO
        state["stride"]=float(state.get("stride",0.0))+next.distance_to(previous)*TAU/32.0
        state["moving"] = next.distance_squared_to(previous) > 0.1
        var facing_point: Vector2 = target["position"] if not target.is_empty() else destination
        if absf(facing_point.x - previous.x) > 1.0: state["facing"] = signf(facing_point.x - previous.x)
        if target.is_empty() or state["cooldown"] > 0.0: continue
        if key == "pet" and next.distance_to(target["position"]) > float(target["radius"]) + PET_BITE: continue
        state["attack"] = 0.20
        state["aim"] = (target["position"] - next).normalized()
        state["cooldown"] = maxf(MIN_COOLDOWN, (0.65 if key == "pet" else 0.8) / ((1.0 + (level - 1) * 0.14) * haste))
        attacks.append({"kind": key, "enemy": target, "position": next, "damage": (7.0 if key == "pet" else 5.0) * (1.0 + (level - 1) * 0.42)})
    queue_redraw()
    return attacks

func _draw() -> void:
    for key in states:
        SupportRig.draw(self,key,states[key],clock)
