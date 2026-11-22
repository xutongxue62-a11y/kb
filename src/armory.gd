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
            var exp_stats: Dictionary = stats.duplicate()
            exp_stats["attack_speed"] = Rules.effective_attack_speed(key, haste)
            events.append_array(ExpandedWeapons.advance(key, delta, hero, enemies, item, exp_stats, prefer_elite, views[key], states[key], expanded_mount))
            continue
        var data: Dictionary = Catalog.WEAPONS[key]
        var stage: int=Evolution.tier(item.level)
        var reach: float = Rules.scaled_range(data, stats)
        var mount: Vector2 = mounts[key] if mounts.has(key) else hero + Vector2(32 if key in ["spear","boomerang"] else -38,14)
        if not states.has(key):
            states[key] = {"phase":"rest","cooldown":0.0,"age":0.0,"position":mount,"direction":Vector2.RIGHT,"hit_ids":[],"travel":0.0,"dealt":false,"impact":mount,"distance":180.0}
        var state: Dictionary = states[key]
        var view: Sprite2D = views[key]
        var weapon_haste: float = Rules.effective_attack_speed(key, haste)
        state["evolution"]=stage
        state["cooldown"] = maxf(0.0,state["cooldown"]-delta*weapon_haste)
        state["age"] += delta * weapon_haste
        var target: Dictionary = Rules.choose_target(hero,reach,enemies,prefer_elite)
        var damage: float = data["damage"] * Evolution.damage_multiplier(key, int(item.get("level", 1))) * float(stats.get("enchant_mults", {}).get(key, 1.0))
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
                var totem_lvl: int = int(item.get("level", 1))
                var is_red: bool = bool(stats["totem_next_red"]) if stats.has("totem_next_red") else (randf() < Rules.red_lightning_chance(totem_lvl))
                var red_mult: float = Rules.red_lightning_multiplier(totem_lvl) if is_red else 1.0
                var bolt_col: Color = Color("#ff3a2e") if is_red else Color("#eef6ff")
                var branch_col: Color = Color("#ff6e4a") if is_red else Color("#dcecff")
                for jump in range(jumps):
                    if current.is_empty():
                        break
                    used.append(current["id"])
                    events.append({"type":"beam","start":previous,"end":current["position"],"color":bolt_col,"red":is_red})
                    var beam_hit: Dictionary = hit(current,damage*red_mult*pow(decay,jump),key,(current["position"]-previous).normalized())
                    beam_hit["red"] = 1 if is_red else 0
                    events.append(beam_hit)
                    previous = current["position"]
                    if stage>=2:
                        var branch: Dictionary = _nearest_unused(previous, 170.0, enemies, used)
                        if not branch.is_empty():
                            used.append(branch.id)
                            events.append({"type":"beam","start":previous,"end":branch.position,"color":branch_col,"red":is_red})
                            events.append(hit(branch,damage*red_mult*0.35*pow(decay,jump),key,(branch.position-previous).normalized()))
                    current = _nearest_unused(previous, 170.0, enemies, used)
            elif key == "boomerang":
                state["phase"] = "out"
                state["position"] = mount
                state["travel"] = 0.0
                state["distance"] = clampf(hero.distance_to(target["position"])+60,140,reach)
            elif key == "hammer":
                state["phase"] = "windup"
                state["start"] = mount
                state["target_id"] = target.get("id", null)
                state["bounce_target_id"] = null
                var lead: Vector2 = target.get("velocity", Vector2.ZERO) * 0.08
                state["impact"] = hero + (target["position"] + lead - hero).limit_length(reach)
                state["bounce_impact"] = state["impact"]
                state["bounce_started"] = false
                state["flight_dir"] = 1.0 if (state["impact"].x - mount.x) >= 0.0 else -1.0
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
            var is_thunder_hammer: bool = bool(stats.get("hammer_thunder", false))
            state["thunder_mode"] = is_thunder_hammer
            if state["phase"] == "windup":
                var start_pt: Vector2 = state.get("start", mount)
                var dir_sign: float = float(state.get("flight_dir", 1.0))
                var slam_time: float = 0.22
                var bounce_time: float = 0.44
                var total_time: float = 0.66 if stage >= 2 else 0.48
                if state["age"] < slam_time:
                    # Track locked target smoothly during early windup so fast enemies don't dodge out from under the strike.
                    if state["age"] < 0.15 and state.get("target_id", null) != null:
                        var tracked_id: String = str(state["target_id"])
                        for candidate in enemies:
                            if str(candidate.get("id", "")) == tracked_id and float(candidate.get("hp", 0.0)) > 0.0:
                                var lead: Vector2 = candidate.get("velocity", Vector2.ZERO) * 0.06
                                var desired: Vector2 = hero + (candidate["position"] + lead - hero).limit_length(reach + 30.0)
                                state["impact"] = Vector2(state["impact"]).lerp(desired, clampf(delta * 18.0, 0.0, 1.0))
                                break
                    var impact_pt: Vector2 = state["impact"]
                    var t: float = clampf(state["age"] / slam_time, 0.0, 1.0)
                    var ease_t: float = t * t * (3.0 - 2.0 * t)
                    if is_thunder_hammer:
                        # Raise hammer skyward to summon lightning instead of smashing the ground!
                        view.position = mount + Vector2(0.0, -sin(t * PI * 0.5) * 34.0)
                        view.rotation = dir_sign * lerpf(-0.15, -0.55, ease_t)
                    else:
                        var arc_h: float = sin(t * PI) * 82.0
                        view.position = start_pt.lerp(impact_pt, ease_t) + Vector2(0.0, -arc_h)
                        view.rotation = dir_sign * lerpf(-0.9, 1.45, ease_t)
                else:
                    var impact_pt: Vector2 = state["impact"]
                    if not state["dealt"]:
                        state["dealt"] = true
                        events.append({"type":"area","position":impact_pt,"radius":102.0,"damage":damage,"weapon_id":key,"primary":true})
                        if stage >= 1 and not is_thunder_hammer:
                            events.append({"type":"area","position":impact_pt,"radius":122.0,"damage":damage*0.28,"weapon_id":key,"primary":false})
                        if stage >= 2 and not bool(state.get("bounce_started", false)):
                            state["bounce_started"] = true
                            var next_target: Dictionary = {}
                            var best_d2: float = 220.0 * 220.0
                            for candidate in enemies:
                                if float(candidate.get("hp", 0.0)) <= 0.0 or Rules.is_stone(candidate):
                                    continue
                                var d2: float = impact_pt.distance_squared_to(candidate["position"])
                                if d2 > 625.0 and d2 < best_d2:
                                    best_d2 = d2
                                    next_target = candidate
                            state["bounce_target_id"] = next_target.get("id", null) if not next_target.is_empty() else null
                            state["bounce_impact"] = next_target["position"] if not next_target.is_empty() else impact_pt
                    if stage >= 2 and state["age"] < bounce_time:
                        if state["age"] < slam_time + 0.14 and state.get("bounce_target_id", null) != null:
                            var b_id: String = str(state["bounce_target_id"])
                            for candidate in enemies:
                                if str(candidate.get("id", "")) == b_id and float(candidate.get("hp", 0.0)) > 0.0:
                                    state["bounce_impact"] = Vector2(state["bounce_impact"]).lerp(candidate["position"], clampf(delta * 18.0, 0.0, 1.0))
                                    break
                        var bt: float = clampf((state["age"] - slam_time) / (bounce_time - slam_time), 0.0, 1.0)
                        var b_ease: float = bt * bt * (3.0 - 2.0 * bt)
                        var bounce_pt: Vector2 = state.get("bounce_impact", impact_pt)
                        if is_thunder_hammer:
                            view.position = mount + Vector2(0.0, -34.0 - sin(bt * PI) * 14.0)
                            view.rotation = dir_sign * lerpf(-0.55, -0.35, b_ease)
                        else:
                            view.position = impact_pt.lerp(bounce_pt, b_ease) + Vector2(0.0, -sin(bt * PI) * 56.0)
                            view.rotation = dir_sign * lerpf(-0.6, 1.55, b_ease)
                    else:
                        if stage >= 2 and not state.get("echo_done", false):
                            state["echo_done"] = true
                            var bounce_pt: Vector2 = state.get("bounce_impact", impact_pt)
                            events.append({"type":"area","position":bounce_pt,"radius":128.0,"damage":damage*0.60,"weapon_id":key,"primary":true})
                        var ret_start_time: float = bounce_time if stage >= 2 else slam_time
                        var ret_from: Vector2 = state.get("bounce_impact", impact_pt) if stage >= 2 else impact_pt
                        var rt: float = clampf((state["age"] - ret_start_time) / maxf(0.01, total_time - ret_start_time), 0.0, 1.0)
                        if is_thunder_hammer:
                            view.position = (mount + Vector2(0.0, -34.0)).lerp(mount, rt)
                            view.rotation = dir_sign * lerpf(-0.45, 0.0, rt)
                        else:
                            view.position = ret_from.lerp(mount, rt) + Vector2(0.0, -sin(rt * PI) * 32.0)
                            view.rotation = dir_sign * lerpf(1.2, 0.0, rt)
                if state["age"] >= total_time:
                    state["phase"] = "rest"
                    view.position = mount
                    view.rotation = 0.0
            else:
                view.position = mount
                view.rotation = 0.0
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
        var in_flight: bool = (key == "boomerang" and state["phase"] != "rest") or (key == "spear" and state["phase"] == "thrust") or (key == "hammer" and state["phase"] != "rest")
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
        var crossed: Array = []
        for enemy in enemies:
            if enemy.hp<=0 or used.has(enemy.id): continue
            if Geometry2D.get_closest_point_to_segment(enemy.position,hero,hero+aim*reach).distance_to(enemy.position)<=enemy.radius+9:
                crossed.append(enemy)
        crossed.sort_custom(func(a, b): return hero.distance_squared_to(a["position"]) < hero.distance_squared_to(b["position"]))
        var hit_damage: float = damage
        for enemy in crossed:
            used.append(enemy.id)
            events.append(hit(enemy,hit_damage,"spear",aim))
            hit_damage *= Rules.SECONDARY_HIT_DECAY
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
        elif key == "hammer" and state["phase"] == "windup" and not bool(state.get("thunder_mode", false)):
            var glow: Texture2D = preload("res://src/effects.gd").soft_glow_texture()
            if not state["dealt"]:
                var point: Vector2 = state["impact"]
                var t: float = clampf(state["age"] / 0.22, 0.0, 1.0)
                var shadow_r: float = lerpf(26.0, 52.0, t)
                var area_r: float = lerpf(118.0, 96.0, t)
                draw_texture_rect(glow, Rect2(point - Vector2(area_r, area_r * 0.78), Vector2(area_r * 2.0, area_r * 1.56)), false, Color(0.76, 0.54, 0.28, 0.22 + 0.18 * t))
                draw_texture_rect(glow, Rect2(point - Vector2(shadow_r, shadow_r * 0.72), Vector2(shadow_r * 2.0, shadow_r * 1.44)), false, Color(0.28, 0.19, 0.12, 0.24 + 0.26 * t))
            elif int(state.get("evolution", 0)) >= 2 and not state.get("echo_done", false):
                var bpoint: Vector2 = state.get("bounce_impact", state["impact"])
                var bt: float = clampf((state["age"] - 0.22) / 0.22, 0.0, 1.0)
                var bshadow_r: float = lerpf(30.0, 58.0, bt)
                var barea_r: float = lerpf(138.0, 118.0, bt)
                draw_texture_rect(glow, Rect2(bpoint - Vector2(barea_r, barea_r * 0.78), Vector2(barea_r * 2.0, barea_r * 1.56)), false, Color(0.84, 0.60, 0.30, 0.24 + 0.20 * bt))
                draw_texture_rect(glow, Rect2(bpoint - Vector2(bshadow_r, bshadow_r * 0.72), Vector2(bshadow_r * 2.0, bshadow_r * 1.44)), false, Color(0.28, 0.19, 0.12, 0.26 + 0.26 * bt))
        elif key == "boomerang" and state["phase"] != "rest":
            draw_arc(state["position"],19,-1.6+state["age"]*20,1.3+state["age"]*20,16,Color(0.96,0.84,0.52,0.65),3.0,true)

func try_sky_lightning(state: Dictionary, item: Dictionary, hero: Vector2, enemies: Array, damage: float, dt: float) -> Array:
    var level: int = clampi(int(item.get("level", 1)), 1, 10)
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
    var is_red: bool = randf() < Rules.red_lightning_chance(level)
    var bolt_damage: float = damage * float(profile["damage_multiplier"]) * (Rules.red_lightning_multiplier(level) if is_red else 1.0)
    state["sky_cooldown"] = float(profile["cooldown"])
    return [{
        "type": "sky_lightning",
        "start": point + Vector2(0.0, -float(profile["height"])),
        "end": point,
        "position": point,
        "radius": float(profile["radius"]),
        "damage": bolt_damage,
        "weapon_id": "totem",
        "color": Color("#ff3a2e") if is_red else Color("#e8fbff"),
        "red": is_red
    }]

func _nearest_unused(origin: Vector2, max_range: float, enemies: Array, used: Array) -> Dictionary:
    var max_sq: float = max_range * max_range
    var best_tier: int = -1
    var best_sq: float = INF
    var best: Dictionary = {}
    for enemy in enemies:
        if float(enemy.get("hp", 0.0)) <= 0.0:
            continue
        if used.has(enemy["id"]):
            continue
        var d_sq: float = origin.distance_squared_to(enemy["position"])
        if d_sq > max_sq:
            continue
        var tier: int = 3 if str(enemy.get("kind", "")) == "boss" else (2 if Rules.is_living_monster(enemy) else (1 if Rules.is_egg(enemy) else 0))
        if tier > best_tier or (tier == best_tier and d_sq < best_sq):
            best_tier = tier
            best_sq = d_sq
            best = enemy
    return best
