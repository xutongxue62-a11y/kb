extends Node2D

const Catalog = preload("res://src/catalog.gd")
const Rules = preload("res://src/rules.gd")
const Evolution = preload("res://src/weapon_evolution.gd")
const ExpandedWeapons = preload("res://src/expanded_weapons.gd")
var states: Dictionary = {}

func reset() -> void:
    states.clear()
    queue_redraw()

func hit(enemy: Dictionary, damage: float, key: String, direction: Vector2) -> Dictionary:
    return {"type":"hit","enemy":enemy,"damage":damage,"weapon_id":key,"direction":direction}

func advance(delta: float, hero: Vector2, enemies: Array, inventory: Array, stats: Dictionary, prefer_elite: bool, views: Dictionary, mounts: Dictionary = {}) -> Array:
    var events: Array = []
    var haste: float = float(stats.get("attack_speed",1.0))
    var owned: Array = []
    for item in inventory:
        var key: String = item["id"]
        if (not Catalog.NEW_IDS.has(key) and not Catalog.EXPANDED_IDS.has(key)) or not views.has(key):
            continue
        owned.append(key)
        if stats.get("suppressed_weapons",[]).has(key):
            views[key].position=mounts.get(key,hero+Vector2(-38,14))
            views[key].modulate=Color(0.86,0.98,0.86)
            Rules.apply_parked_hold(views[key],key,hero,Vector2.LEFT)
            states.erase(key)
            continue
        views[key].modulate=Color.WHITE
        if Catalog.EXPANDED_IDS.has(key):
            if not states.has(key):
                states[key] = ExpandedWeapons.create_state(key, hero)
            var expanded_mount: Vector2 = mounts[key] if mounts.has(key) else Vector2(INF, INF)
            events.append_array(ExpandedWeapons.advance(key, delta, hero, enemies, item, stats, prefer_elite, views[key], states[key], expanded_mount))
            continue
        var data: Dictionary = Catalog.WEAPONS[key]
        var stage: int=Evolution.tier(item.level)
        var reach: float = Rules.scaled_range(data, stats)
        var mount: Vector2 = mounts[key] if mounts.has(key) else hero + Vector2(32 if key in ["spear","boomerang"] else -38,14)
        if not states.has(key):
            states[key] = {"phase":"rest","cooldown":0.0,"age":0.0,"position":mount,"direction":Vector2.RIGHT,"hit_ids":[],"travel":0.0,"dealt":false,"impact":mount,"distance":180.0}
        var state: Dictionary = states[key]
        var view: Sprite2D = views[key]
        state["evolution"]=stage
        state["cooldown"] = maxf(0.0,state["cooldown"]-delta*haste)
        state["age"] += delta * haste
        var target: Dictionary = Rules.choose_target(hero,reach,enemies,prefer_elite)
        var damage: float = data["damage"] * (1.0+(item["level"]-1)*0.35)
        if key == "totem":
            events.append_array(try_sky_lightning(state, item, hero, enemies, damage, delta * haste))
        if state["phase"] == "rest" and state["cooldown"] <= 0 and not target.is_empty():
            state["direction"] = (target["position"]-hero).normalized()
            state["age"] = 0.0
            state["dealt"] = false
            state["echo_done"] = false
            state["volleys_left"] = stage
            state["hit_ids"] = []
            var reload_map: Dictionary = stats.get("reload_multipliers", {})
            var reload_penalty: float = float(reload_map.get(key, 1.0)) if typeof(reload_map) == TYPE_DICTIONARY else 1.0
            if is_equal_approx(reload_penalty, 1.0) and key==stats.get("reload_weapon",""):
                reload_penalty = float(stats.get("reload_multiplier",1.0))
            state["cooldown"] = data["cooldown"]*reload_penalty
            events.append({"type":"flash","weapon_id":key})
            if key == "totem":
                var previous: Vector2 = mount
                var used: Array = []
                var current: Dictionary = target
                var mastery: Dictionary = Catalog.exclusive_bonus(str(stats.get("character_id", "")), key)
                var jumps: int = 4 if stage>=1 else 3
                var decay: float = 0.75
                if mastery.has("chain_count"):
                    jumps = maxi(jumps, int(mastery["chain_count"]))
                if mastery.has("decay"):
                    decay = float(mastery["decay"])
                for jump in range(jumps):
                    if current.is_empty():
                        break
                    used.append(current["id"])
                    events.append({"type":"beam","start":previous,"end":current["position"],"color":Color("#83e2ee")})
                    events.append(hit(current,damage*pow(decay,jump),key,(current["position"]-previous).normalized()))
                    previous = current["position"]
                    if stage>=2:
                        var branch_candidates: Array=enemies.filter(func(e):return not used.has(e.id))
                        var branch: Dictionary=Rules.choose_target(previous,170.0,branch_candidates,false)
                        if not branch.is_empty():
                            used.append(branch.id)
                            events.append({"type":"beam","start":previous,"end":branch.position,"color":Color("#f0dbaa")})
                            events.append(hit(branch,damage*0.35*pow(decay,jump),key,(branch.position-previous).normalized()))
                    var candidates: Array = enemies.filter(func(enemy):return not used.has(enemy["id"]))
                    current = Rules.choose_target(previous,170.0,candidates,false)
            elif key == "boomerang":
                state["phase"] = "out"
                state["position"] = mount
                state["travel"] = 0.0
                state["distance"] = clampf(hero.distance_to(target["position"])+60,140,reach)
            elif key == "hammer":
                state["phase"] = "windup"
                state["impact"] = hero + (target["position"]-hero).limit_length(100)
            else:
                state["phase"] = "thrust"
        if key == "spear":
            var extension: float = absf(sin(clampf(state["age"]/0.28,0,1)*PI*(2.0 if stage>=2 else 1.0))) if state["phase"] == "thrust" else 0.0
            if state["phase"] == "thrust":
                view.position = hero + state["direction"]*(34+extension*115)
                view.offset = Vector2.ZERO
            else:
                view.position = mount
            view.rotation = state["direction"].angle()+PI/2
            if state["phase"] == "thrust" and state["age"]>=0.08 and not state["dealt"]:
                state["dealt"] = true
                events.append_array(spear_strike(hero,state.direction,reach,enemies,damage,stage>=1))
            if state.phase=="thrust" and stage>=2 and state.age>=0.20 and not state.get("echo_done",false):
                state["echo_done"]=true
                events.append_array(spear_strike(hero,state.direction,reach,enemies,damage*0.55,true))
            if state["age"]>=0.28:
                state["phase"] = "rest"
        elif key == "hammer":
            view.position = mount + Vector2(0,-sin(clampf(state["age"]/0.4,0,1)*PI)*34) if state["phase"] == "windup" else mount
            view.rotation = -0.45 + sin(minf(1.0,state["age"]/0.28)*PI)*0.9
            if state["phase"] == "windup" and state["age"]>=0.22 and not state["dealt"]:
                state["dealt"] = true
                events.append({"type":"area","position":state["impact"],"radius":78.0,"damage":damage,"weapon_id":key})
                if stage>=1: events.append({"type":"area","position":state.impact,"radius":118.0,"damage":damage*0.35,"weapon_id":key})
            if state.phase=="windup" and stage>=2 and state.age>=0.34 and not state.get("echo_done",false):
                state["echo_done"]=true
                events.append({"type":"area","position":state.impact,"radius":104.0,"damage":damage*0.45,"weapon_id":key})
            if state["age"]>=0.4:
                state["phase"] = "rest"
        elif key == "boomerang":
            if state["phase"] in ["out","back"]:
                var before: Vector2 = state["position"]
                if state["phase"] == "out":
                    state["position"] += state["direction"]*data["speed"]*delta
                    state["travel"] += data["speed"]*delta
                else:
                    state["position"] = before.move_toward(mount,data["speed"]*delta)
                for enemy in enemies:
                    if enemy["hp"]<=0 or state["hit_ids"].has(enemy["id"]):
                        continue
                    if Geometry2D.get_closest_point_to_segment(enemy["position"],before,state["position"]).distance_to(enemy["position"])<=enemy["radius"]+12:
                        state["hit_ids"].append(enemy["id"])
                        events.append(hit(enemy,damage,key,(state["position"]-before).normalized()))
                if state["phase"] == "out" and state["travel"]>=state["distance"]:
                    state["phase"] = "back"
                    state["hit_ids"] = []
                elif state["phase"] == "back" and state["position"].distance_to(mount)<5:
                    if int(state.get("volleys_left",0))>0 and not target.is_empty():
                        state["volleys_left"]-=1
                        state["phase"]="out"
                        state["position"]=mount
                        state["travel"]=0.0
                        state["hit_ids"]=[]
                        state["direction"]=(target.position-mount).normalized().rotated(0.13 if int(state.volleys_left)%2==0 else -0.13)
                    else:
                        state["phase"] = "rest"
                view.position = state["position"]
                view.rotation += delta*22
            else:
                view.position = mount
        else:
            view.position = mount
            view.rotation = 0
        var in_flight: bool = (key == "boomerang" and state["phase"] != "rest") or (key == "spear" and state["phase"] == "thrust")
        if is_instance_valid(view):
            if in_flight:
                view.offset = Vector2.ZERO
            else:
                var hold_aim: Vector2 = state["direction"] if Vector2(state["direction"]).length() > 0.01 else (view.position - hero)
                Rules.apply_parked_hold(view, key, hero, hold_aim)
        if key in ["spear", "hammer", "boomerang"] and state["phase"] != "rest":
            state["trail_clock"] = float(state.get("trail_clock", 0.0)) - delta
            if state["trail_clock"] <= 0.0:
                events.append({"type":"motion", "position":view.position, "direction":state["direction"], "weapon_id":key})
                state["trail_clock"] = 0.05
        state["position"] = view.position
    var link_kinds: Array = stats.get("link_kinds", [])
    var fire_drum_active: bool = stats.get("link_kind","")=="fire_drum" or (typeof(link_kinds)==TYPE_ARRAY and link_kinds.has("fire_drum"))
    if fire_drum_active and states.has("wardrum") and states.has("firepot"):
        for wave in states.wardrum.waves:
            for fire in states.firepot.fires:
                if not fire.get("fanned",false) and Vector2(fire.position).distance_to(wave.position)<=wave.radius+fire.radius:
                    fire["fanned"]=true
                    fire.radius*=1.35
                    fire["life"]=float(fire.get("life",1.85))+0.35
                    events.append({"type":"fan_fire","position":fire.position,"radius":fire.radius})
    for key in states.keys():
        if not owned.has(key):
            states.erase(key)
    queue_redraw()
    return events

func spear_strike(hero: Vector2,direction: Vector2,reach: float,enemies: Array,damage: float,fan: bool) -> Array:
    var events: Array=[]
    var used: Array=[]
    for offset in ([-0.18,0.0,0.18] if fan else [0.0]):
        var aim: Vector2=direction.rotated(offset)
        for enemy in enemies:
            if enemy.hp<=0 or used.has(enemy.id): continue
            if Geometry2D.get_closest_point_to_segment(enemy.position,hero,hero+aim*reach).distance_to(enemy.position)<=enemy.radius+9:
                used.append(enemy.id)
                events.append(hit(enemy,damage,"spear",aim))
    return events

func _draw() -> void:
    for key in states:
        var state: Dictionary = states[key]
        if Catalog.EXPANDED_IDS.has(key):
            ExpandedWeapons.draw(self, key, state)
        elif key == "spear" and state["phase"] == "thrust":
            for offset in ([-0.18,0.0,0.18] if int(state.get("evolution",0))>=1 else [0.0]):
                var aim: Vector2=Vector2(state.direction).rotated(offset)
                draw_line(state.position-aim*65,state.position+aim*20,Color(0.95,0.87,0.62,0.7),4.0,true)
        elif key == "hammer" and state["phase"] == "windup" and not state["dealt"]:
            var point: Vector2 = state["impact"]
            var size: float = 16+state["age"]*50
            draw_line(point-Vector2(size,size),point+Vector2(size,size),Color(0.79,0.62,0.31,0.55),3.0,true)
            draw_line(point-Vector2(size,-size),point+Vector2(size,-size),Color(0.79,0.62,0.31,0.55),3.0,true)
        elif key == "boomerang" and state["phase"] != "rest":
            draw_arc(state["position"],19,-1.6+state["age"]*20,1.3+state["age"]*20,16,Color(0.96,0.84,0.52,0.65),3.0,true)

func try_sky_lightning(state: Dictionary, item: Dictionary, hero: Vector2, enemies: Array, damage: float, dt: float) -> Array:
    var level: int = clampi(int(item.get("level", 1)), 1, 5)
    var profile: Dictionary = Evolution.sky_lightning_profile(level)
    state["sky_cooldown"] = maxf(0.0, float(state.get("sky_cooldown", 0.0)) - maxf(0.0, dt))
    if not bool(profile.get("unlocked", false)) or state["sky_cooldown"] > 0.0:
        return []
    var reach: float = 460.0
    var target: Dictionary = Rules.choose_target(hero, reach, enemies, true)
    if target.is_empty():
        target = Rules.choose_target(hero, reach, enemies, false)
    if target.is_empty():
        return []
    var point: Vector2 = target["position"]
    var bolt_damage: float = damage * float(profile["damage_multiplier"])
    state["sky_cooldown"] = float(profile["cooldown"])
    return [{
        "type": "sky_lightning",
        "start": point + Vector2(0.0, -float(profile["height"])),
        "end": point,
        "position": point,
        "radius": float(profile["radius"]),
        "damage": bolt_damage,
        "weapon_id": "totem",
        "color": Color("#e8fbff")
    }]
