extends Node2D
const GameFonts=preload("res://src/game_fonts.gd")
const CombatArt=preload("res://src/combat_art.gd")
const BattleVisuals=preload("res://src/battle_visuals.gd")

var particles: Array = []
var number_serial: int = 0
var bolt_serial: int = 0
var _impact_weapon: String=""
var _impact_tier: int=0
var font: SystemFont = GameFonts.create_system(PackedStringArray(["Microsoft YaHei", "SimSun", "Arial"]))
var ink: Color = Color("#2a221c")
var paper: Color = Color("#f4ead6")

const HEAVY_IDS = ["powder", "hammer", "club", "axe"]
const LIGHT_IDS = ["blade", "sling", "boomerang", "staff", "drone"]

func _init() -> void:
    font.font_names = PackedStringArray(["Microsoft YaHei", "SimSun", "Arial"])

func add_particle(particle: Dictionary) -> void:
    if not _impact_weapon.is_empty() and not particle.has("weapon_id"):
        particle["weapon_id"]=_impact_weapon
    particles.append(particle)
    if particles.size() > 200:
        particles.pop_front()
    queue_redraw()

func puff(at: Vector2, color: Color, size: float, index: int = 0) -> void:
    var step: int = absi(index) % 4
    var angle: float = float(step) * 2.15 + at.x * 0.01
    var drift: Vector2 = Vector2.from_angle(angle) * (14.0 + size * 0.16) + Vector2(0, -20.0 - size * 0.12)
    var smoke: Color = color.lerp(Color("#d9c6a3"), 0.55)
    add_particle({"at": at + Vector2.from_angle(angle) * (6.0 + size * 0.08), "drift": drift, "color": smoke, "size": size * 0.88, "kind": "smoke", "age": 0.0, "life": 0.28 + float(step) * 0.04, "seed": step})

func comic_word(at: Vector2, text: String, color: Color, size: int = 42, tilt: float = -14.0) -> void:
    var count:=0
    for particle in particles:
        if particle.kind!="word": continue
        count+=1
        if particle.text==text and particle.age<0.18 and particle.at.distance_squared_to(at)<16900: return
    if count>=6: return
    add_particle({"at": at + Vector2(0, -18), "color": color, "size": maxi(20,roundi(size*0.68)), "kind": "word", "age": 0.0, "life": 0.24, "text": text, "tilt": tilt})

func burst(at: Vector2, color: Color, size: float = 16.0, kind: String = "hit") -> void:
    var scaled: float = size * (1.45 if size < 70.0 else 1.08)
    var heavy: bool = kind in ["blast", "cannon", "rune_blast", "quake"]
    var life: float = 0.38 if heavy else (0.34 if kind == "ring" else 0.24)
    add_particle({"at": at, "color": color, "size": scaled, "kind": kind, "age": 0.0, "life": life})
    if heavy:
        var puffs: int = 3 if kind in ["blast", "cannon"] else 2
        for index in range(puffs):
            puff(at, color.lerp(Color("#6b5340"), 0.25), scaled * (0.28 + float(index) * 0.06), index)
        var word: String = "轰"
        var word_color: Color = Color("#fff2c8") if kind != "rune_blast" else Color("#d7fbff")
        comic_word(at + Vector2(10, -8), word, word_color, 42 if kind != "quake" else 40, -16.0)
    elif kind == "muzzle":
        puff(at, color, scaled * 0.34, 0)

func dodge_streak(at: Vector2, direction: Vector2) -> void:
    add_particle({"at": at + Vector2(0, 18), "direction": direction, "color": Color("#c4f4f1"), "size": 28.0, "kind": "dodge", "age": 0.0, "life": 0.15})

func rune_ignition(staff: Vector2, muzzle: Vector2, vfx_tier: int = 0) -> void:
    var tint: Color = BattleVisuals.staff_tint(vfx_tier)
    add_particle({"at": staff, "end": muzzle, "color": tint, "size": 20.0, "kind": "rune_ignition", "age": 0.0, "life": 0.28, "vfx_tier": vfx_tier})
    burst(muzzle, BattleVisuals.staff_highlight(vfx_tier) if vfx_tier >= 1 else Color("#b891ff"), 24.0 if vfx_tier >= 1 else 20.0, "rune_hit")

func weapon_aura(at: Vector2, color: Color, size: float = 28.0) -> void:
    add_particle({"at": at, "color": color, "size": size, "kind": "aura", "age": 0.0, "life": 0.14})
    burst(at, color, maxf(10.0, size * 0.45), "muzzle")

func beam(start: Vector2, end: Vector2, color: Color) -> void:
    add_particle({"at": start, "end": end, "color": color, "size": 6.5, "kind": "beam", "age": 0.0, "life": 0.20})

func muzzle(at: Vector2, direction: Vector2, key: String, enchanted: bool = false, vfx_tier: int = 0, fire_tier: int = 0, thunder_tier: int = 0) -> void:
    if key not in ["sling", "powder", "staff"]:
        return
    var axis: Vector2 = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
    var kind: String = {"sling": "sling_release", "powder": "powder_muzzle", "staff": "staff_muzzle"}[key]
    var color: Color = {"sling": Color("#ead3a0"), "powder": Color("#ffbc54"), "staff": Color("#70f2fa")}[key]
    if key == "staff" or enchanted:
        color = BattleVisuals.staff_tint(vfx_tier)
    elif fire_tier > 0:
        color = BattleVisuals.fire_tint(fire_tier)
    elif thunder_tier > 0:
        color = BattleVisuals.thunder_tint(thunder_tier)
    add_particle({"at": at, "direction": axis, "weapon_id": key, "enchanted": enchanted, "color": color, "size": 23.0 if key == "powder" else (16.0 if key == "staff" and vfx_tier >= 1 else 14.0), "kind": kind, "age": 0.0, "life": 0.11 if key == "powder" else (0.14 if key == "sling" else 0.18), "vfx_tier": vfx_tier})
    if key == "powder":
        puff(at - axis * 3, Color("#aa967c"), 10.0, 1)

func sky_lightning(start: Vector2, end: Vector2, color: Color) -> void:
    lightning(start, end, color)
    lightning(start + Vector2(8.0, 0.0), end + Vector2(2.0, 0.0), color.lightened(0.2))
    burst(end, color, 62.0, "ring")
    puff(end, color, 16.0, 4)

func lightning(start: Vector2, end: Vector2, color: Color) -> void:
    var length: float = start.distance_to(end)
    if length < 0.5:
        return
    bolt_serial += 1
    var axis: Vector2 = (end - start) / length
    var side: Vector2 = axis.orthogonal()
    var steps: int = clampi(ceili(length / 30.0), 5, 16)
    var jag: float = minf(17.0, length * 0.11)
    var points := PackedVector2Array([start])
    for index in range(1, steps):
        var t: float = float(index) / float(steps)
        var kick: float = jag * (0.6 + absf(sin(float(bolt_serial * 7 + index * 13))) * 0.4) * sin(t * PI)
        points.append(start.lerp(end, t) + side * kick * (-1.0 if index % 2 == 0 else 1.0))
    points.append(end)
    var branches: Array = []
    for index in [maxi(1, steps / 3), mini(steps - 1, steps * 2 / 3)]:
        var origin: Vector2 = points[index]
        var sign: float = -1.0 if branches.is_empty() else 1.0
        var reach: float = minf(21.0, length * 0.09)
        var branch := PackedVector2Array([origin, origin + axis * reach * 0.40 + side * sign * reach * 0.45, origin + axis * reach * 0.20 + side * sign * reach * 0.80, origin + axis * reach * 0.55 + side * sign * reach])
        branches.append(branch)
    add_particle({"at": start, "end": end, "points": points, "branches": branches, "color": color, "size": 5.4, "kind": "arc_lightning", "age": 0.0, "life": 0.18})

static func format_amount(amount: float) -> String:
    var magnitude: float = absf(amount)
    for pair in [[1000000000000.0, "T"], [1000000000.0, "B"], [1000000.0, "M"], [10000.0, "K"]]:
        if magnitude >= pair[0]:
            return "%.1f%s" % [amount / (1000.0 if pair[1] == "K" else pair[0]), pair[1]]
    return str(roundi(amount)) if is_equal_approx(amount, roundf(amount)) else "%.1f" % amount

func damage_number(at: Vector2, amount: float, critical: bool = false, color: Color = Color("#fffdf4")) -> void:
    # Coalesce bursts arriving at the same contact point; combat damage is already
    # resolved by Main. Keep a few recent totals rather than covering the weapons.
    var nearby := 0
    var oldest := -1
    var oldest_age := -1.0
    for index in range(particles.size()):
        var particle: Dictionary = particles[index]
        if particle.kind != "number" or not particle.has("damage_origin"): continue
        if particle.damage_origin.distance_to(at) > 76: continue
        nearby += 1
        if float(particle.age) > oldest_age:
            oldest = index
            oldest_age = particle.age
        if particle.damage_origin.distance_to(at) <= 22 and particle.age < 0.10 and bool(particle.critical) == critical:
            particle.value += amount
            particle.text = format_amount(particle.value) + ("!" if critical else "")
            queue_redraw()
            return
    var total_numbers := 0
    var oldest_any := -1
    var oldest_any_age := -1.0
    for index in range(particles.size()):
        var particle: Dictionary = particles[index]
        if particle.kind != "number":
            continue
        total_numbers += 1
        if float(particle.age) > oldest_any_age:
            oldest_any = index
            oldest_any_age = float(particle.age)
    if nearby >= 3 and oldest >= 0:
        particles.remove_at(oldest)
        if oldest_any > oldest:
            oldest_any -= 1
        total_numbers -= 1
    elif total_numbers >= 10 and oldest_any >= 0:
        particles.remove_at(oldest_any)
    var text: String = format_amount(amount)
    if critical:
        text += "!"
        color = Color("#ffd653")
    floating_text(at, text, color, 25 if critical else 20, amount, critical)
    particles.back()["damage_origin"] = at
    particles.back()["life"] = 0.46

func floating_text(at: Vector2, text: String, color: Color, size: int = 20, value: float = 0.0, critical: bool = false) -> void:
    var total_numbers := 0
    var oldest := -1
    var oldest_age := -1.0
    for index in range(particles.size()):
        var particle: Dictionary = particles[index]
        if particle.kind != "number":
            continue
        total_numbers += 1
        if float(particle.age) > oldest_age:
            oldest = index
            oldest_age = float(particle.age)
    if total_numbers >= 10 and oldest >= 0:
        particles.remove_at(oldest)
    number_serial += 1
    add_particle({"at": at + Vector2((number_serial % 5 - 2) * 12, -36 - (number_serial % 3) * 10), "color": color, "size": size, "kind": "number", "age": 0.0, "life": 0.58, "text": text, "value": value, "critical": critical})

func impact(at: Vector2, direction: Vector2, weapon_id: String, vfx_tier: int = 0) -> void:
    _impact_weapon=weapon_id
    _impact_tier=vfx_tier
    var facing: Vector2 = direction if direction.length_squared() > 0.01 else Vector2.RIGHT
    match weapon_id:
        "powder":
            add_particle({"at": at, "color": Color("#ffb44c"), "size": 48.0, "kind": "impact", "age": 0.0, "life": 0.20, "direction": facing})
            for index in range(2):
                puff(at, Color("#c9a37a"), 24.0 + float(index) * 6.0, index + 1)
            add_particle({"at": at, "color": Color("#ff7a3a"), "size": 18.0, "kind": "fleck", "age": 0.0, "life": 0.16, "direction": facing})
        "hammer":
            add_particle({"at": at, "color": Color("#fff2c4"), "size": 68.0, "kind": "smash", "age": 0.0, "life": 0.22, "direction": facing, "cracks": true})
            puff(at, Color("#cbb089"), 24.0, 1)
            puff(at + Vector2(-22, 10), Color("#cbb089"), 18.0, 2)
            puff(at + Vector2(22, 10), Color("#cbb089"), 18.0, 3)
            add_particle({"at": at, "color": Color("#efe0b0"), "size": 52.0, "kind": "ring", "age": 0.0, "life": 0.18})
        "club":
            add_particle({"at": at, "color": Color("#fff2c4"), "size": 86.0, "kind": "smash", "age": 0.0, "life": 0.24, "direction": facing, "cracks": true})
            for index in range(2):
                puff(at, Color("#d2b894"), 26.0 + float(index) * 5.0, index)
            add_particle({"at": at, "color": Color("#ffe08a"), "size": 58.0, "kind": "ring", "age": 0.0, "life": 0.18})
            comic_word(at + Vector2(facing.x * 16.0, -22.0), "嘭", Color("#fff7de"), 46, -12.0 if number_serial % 2 == 0 else 10.0)
        "axe":
            add_particle({"at": at, "color": Color("#f5a26e"), "size": 72.0, "kind": "chop", "age": 0.0, "life": 0.22, "direction": facing})
            puff(at, Color("#d8c4a2"), 22.0, 1)
            comic_word(at + Vector2(facing.x * 16.0, -22.0), "嘭", Color("#fff7de"), 42, 10.0)
        "blade":
            add_particle({"at": at, "color": Color("#c9a5ff"), "size": 62.0, "kind": "slash", "age": 0.0, "life": 0.18, "direction": facing, "thin": true})
            add_particle({"at": at + facing * 10.0, "color": Color("#fffaf0"), "size": 20.0, "kind": "hit", "age": 0.0, "life": 0.14})
            comic_word(at + Vector2(facing.x * 14.0, -20.0), "唰", Color("#fff7de"), 32, -16.0)
        "sling":
            add_particle({"at": at, "color": Color("#ffe7b0"), "size": 36.0, "kind": "fleck", "age": 0.0, "life": 0.18, "direction": facing})
            add_particle({"at": at, "color": Color("#fff2c4"), "size": 28.0, "kind": "hit", "age": 0.0, "life": 0.14})
            puff(at, Color("#e6d2a8"), 16.0, 0)
            comic_word(at + Vector2(8, -18), "啪", Color("#fff4d8"), 30, 8.0)
        "boomerang":
            add_particle({"at": at, "color": Color("#f3d48a"), "size": 40.0, "kind": "ribbon", "age": 0.0, "life": 0.18, "direction": facing})
        "staff", "drone":
            var staff_tier: int = int(_impact_tier)
            add_particle({"at": at, "color": BattleVisuals.staff_tint(staff_tier), "size": 52.0 + (8.0 if staff_tier >= 2 else (4.0 if staff_tier >= 1 else 0.0)), "kind": "rune_hit", "age": 0.0, "life": 0.22, "direction": facing, "vfx_tier": staff_tier})
            if staff_tier >= 1:
                add_particle({"at": at, "color": BattleVisuals.staff_highlight(staff_tier), "size": 28.0, "kind": "aura", "age": 0.0, "life": 0.16})
            comic_word(at + Vector2(facing.x * 12.0, -20.0), "闪", BattleVisuals.staff_highlight(staff_tier), 32, -8.0)
        "spear":
            add_particle({"at": at, "color": Color("#fff1c0"), "size": 66.0, "kind": "thrust", "age": 0.0, "life": 0.22, "direction": facing})
            add_particle({"at": at + facing * 18.0, "color": Color("#ffe7a0"), "size": 22.0, "kind": "fleck", "age": 0.0, "life": 0.14, "direction": facing})
            comic_word(at + Vector2(facing.x * 18.0, -20.0), "戳", Color("#fff7de"), 34, -6.0)
        "totem":
            add_particle({"at": at, "color": Color("#7cf0ff"), "size": 56.0, "kind": "lightning", "age": 0.0, "life": 0.20, "direction": facing})
            comic_word(at + Vector2(8, -20), "雷", Color("#d7fbff"), 32, 12.0)
        _:
            add_particle({"at": at, "color": Color("#fff2c4"), "size": 38.0, "kind": "impact", "age": 0.0, "life": 0.18, "direction": facing})

    _impact_weapon=""
    _impact_tier=0

func swing_trail(start: Vector2, end: Vector2, center: Vector2, weapon_id: String) -> void:
    if particles.size() >= 180 or start.distance_squared_to(end) < 0.01:
        return
    var color: Color = Color("#ffd56a") if weapon_id == "club" else (Color("#ed9564") if weapon_id == "axe" else Color("#b7a4fa"))
    add_particle({"at": start, "end": end, "center": center, "color": color, "size": 28.0 if weapon_id == "axe" else (11.0 if weapon_id == "blade" else 22.0), "kind": "swing_trail", "weapon_id": weapon_id, "age": 0.0, "life": 0.16})

func weapon_motion(at: Vector2, direction: Vector2, weapon_id: String) -> void:
    if particles.size() >= 180:
        return
    var color: Color = Color("#f4d28d") if weapon_id == "boomerang" else (Color("#fff4c4") if weapon_id == "spear" else Color("#d5b793"))
    add_particle({"at": at, "direction": direction, "weapon_id": weapon_id, "color": color, "size": 22.0 if weapon_id == "spear" else 18.0, "kind": "weapon_motion", "age": 0.0, "life": 0.14})

func flight_trail(start: Vector2, end: Vector2, magic: bool, key: String = "", vfx_tier: int = 0) -> void:
    if particles.size() >= 180 or start.distance_squared_to(end) < 0.01:
        return
    var weapon_id: String = key if not key.is_empty() else ("staff" if magic else "powder")
    var axis: Vector2 = (end - start).normalized()
    var tail: Vector2 = end - axis * minf(start.distance_to(end), 62.0 if weapon_id in ["sling", "spear"] else 46.0)
    var color: Color = Color("#75f5ff") if magic else (Color("#ffe7b0") if weapon_id == "sling" else (Color("#fff1c0") if weapon_id == "spear" else Color("#ffb558")))
    if magic or weapon_id == "staff":
        color = BattleVisuals.staff_tint(vfx_tier)
    var trail_life: float = 0.13 if weapon_id == "sling" else (0.16 if weapon_id == "spear" else 0.14)
    add_particle({"at": tail, "end": end, "weapon_id": weapon_id, "enchanted": magic and weapon_id == "powder", "color": color, "size": 13.0 if weapon_id == "sling" else (14.0 if weapon_id == "spear" else 10.0), "kind": "flight", "age": 0.0, "life": trail_life, "vfx_tier": vfx_tier})


func pierce_cue(at: Vector2, direction: Vector2) -> void:
    var axis: Vector2 = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
    comic_word(at + Vector2(axis.x * 12.0, -26.0), "穿", Color("#fff6c6"), 34, -8.0)
    beam(at - axis * 8.0, at + axis * 58.0, Color("#ffe7a3"))
    add_particle({"at": at, "color": Color("#fff1c0"), "size": 48.0, "kind": "thrust", "age": 0.0, "life": 0.16, "direction": axis})

func slam_cue(at: Vector2, direction: Vector2) -> void:
    var axis: Vector2 = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
    comic_word(at + Vector2(axis.x * 10.0, -30.0), "猛", Color("#ffe0a8"), 36, 8.0)
    add_particle({"at": at, "color": Color("#ffd27a"), "size": 64.0, "kind": "ring", "age": 0.0, "life": 0.20})
    add_particle({"at": at, "color": Color("#fff2c4"), "size": 54.0, "kind": "smash", "age": 0.0, "life": 0.18, "direction": axis, "cracks": true})

func egg_crack(at: Vector2, size: float = 36.0) -> void:
    if particles.size() >= 180:
        return
    add_particle({"at": at, "color": Color("#f7e6c4"), "size": size * 0.7, "kind": "ring", "age": 0.0, "life": 0.20})
    for step in range(4):
        if particles.size() >= 180:
            break
        var drift: Vector2 = Vector2.from_angle(TAU * float(step) / 4.0 + 0.35) * (size * 0.34)
        add_particle({"at": at, "drift": drift, "color": Color("#e8d0a0"), "size": size * 0.22, "kind": "fleck", "age": 0.0, "life": 0.18, "direction": drift.normalized() if drift.length() > 0.01 else Vector2.UP})

func egg_smash(at: Vector2, size: float = 36.0) -> void:
    burst(at, Color("#f3e2c4"), size * 0.9, "hit")
    puff(at, Color("#efe0c0"), size * 0.75, 0)
    puff(at, Color("#d7b17a"), size * 0.5, 1)
    add_particle({"at": at, "color": Color("#f7e6c4"), "size": size, "kind": "smash", "age": 0.0, "life": 0.22, "direction": Vector2.UP, "cracks": true})
    comic_word(at + Vector2(4, -6), "碎", Color("#fff4d0"), 34, -8.0)

func defeat(at: Vector2, direction: Vector2, size: float, texture: Texture2D = null, body_dimensions: Vector2 = Vector2.ZERO) -> void:
    add_particle({"at": at, "direction": direction, "color": Color("#e9c996"), "size": size * 0.52, "texture": texture, "body_dimensions":body_dimensions, "kind": "defeat", "age": 0.0, "life": 0.26})
    puff(at, Color("#e2cba8"), 20.0, 2)
    comic_word(at + Vector2(0, -28), "倒", Color("#fff1d0"), 28, 8.0)

func advance(delta: float) -> void:
    var write: int = 0
    for index in range(particles.size()):
        var particle: Dictionary = particles[index]
        particle["age"] += delta
        if particle["age"] < particle["life"]:
            if write != index:
                particles[write] = particle
            write += 1
    if write != particles.size():
        particles.resize(write)
    queue_redraw()

func expire_all() -> void:
    particles.clear()
    queue_redraw()

func _draw() -> void:
    for particle in particles:
        var progress: float = particle["age"] / particle["life"]
        var color: Color = particle["color"]
        if particle["kind"] == "number" or particle["kind"] == "word":
            color.a *= clampf((1.0 - progress) / 0.22, 0.0, 1.0)
        else:
            color.a *= 0.90 * (1.0 - progress * 0.96)
        var point: Vector2 = particle["at"]
        if particle.has("drift"):
            point += particle["drift"] * progress
        var size: float = particle["size"]
        var family: String=CombatArt.particle_family(particle)
        if not family.is_empty():
            CombatArt.draw(self,family,point,size,progress,particle.get("direction",Vector2.RIGHT),color.a)
            continue
        match particle["kind"]:
            "dodge":
                var direction: Vector2 = particle["direction"]
                for offset in [-1, 1]:
                    var foot: Vector2 = point + direction.orthogonal() * offset * 13.0
                    draw_line(foot, foot - direction * size * (0.6 + progress), Color(color.r, color.g, color.b, color.a * 0.55), 2.5, true)
            "rune_ignition":
                # The connecting glyphs are hollow and fade quickly to leave the hero readable.
                draw_line(point, particle["end"], Color(color.r, color.g, color.b, color.a * 0.3), 2.0, true)
                for index in range(5):
                    var rune: Vector2 = point.lerp(particle["end"], float(index) / 4.0)
                    var radius: float = 5.0 + 3.0 * sin(progress * PI)
                    draw_polyline(PackedVector2Array([rune + Vector2(0,-radius), rune + Vector2(radius,0), rune + Vector2(0,radius), rune + Vector2(-radius,0), rune + Vector2(0,-radius)]), color, 2.0, true)
                draw_arc(particle["end"], size * (0.7 + progress), progress * 2.0, TAU + progress * 2.0, 24, Color(0.72,0.52,1.0,color.a), 2.0, true)
            "smoke":
                _draw_smoke(point, size * (0.7 + progress * 0.85), color, int(particle.get("seed", 0)), progress)
            "word":
                _draw_word(point, particle["text"], int(size), color, float(particle.get("tilt", -12.0)), progress)
            "swing_trail":
                var center: Vector2 = particle["center"]
                var start: Vector2 = point - center
                var end: Vector2 = particle["end"] - center
                var turn: float = start.angle_to(end)
                for index in range(7):
                    var t0: float = float(index) / 7.0
                    var t1: float = float(index + 1) / 7.0
                    var dir0: Vector2 = Vector2.from_angle(start.angle() + turn * t0)
                    var dir1: Vector2 = Vector2.from_angle(start.angle() + turn * t1)
                    var r0: float = lerpf(start.length(), end.length(), t0)
                    var r1: float = lerpf(start.length(), end.length(), t1)
                    var width0: float = size * (0.25 + t0 * 0.9) * (1.0 - progress * 0.65)
                    var width1: float = size * (0.25 + t1 * 0.9) * (1.0 - progress * 0.65)
                    var strip: PackedVector2Array = PackedVector2Array([center + dir0 * (r0 - width0), center + dir0 * (r0 + 4), center + dir1 * (r1 + 4), center + dir1 * (r1 - width1)])
                    draw_colored_polygon(strip, Color(color.r, color.g, color.b, color.a * (0.3 + t1 * 0.6)))
                    draw_line(center + dir0 * (r0 + 4), center + dir1 * (r1 + 4), Color(1.0, 1.0, 0.95, color.a * t1), 3.0, true)
                    if particle["weapon_id"] == "blade":
                        draw_line(center+dir0*(r0-13),center+dir1*(r1-13),Color(0.68,0.55,0.94,color.a*t1),1.4,true)
                        draw_line(center+dir0*(r0+10),center+dir1*(r1+10),Color(0.88,0.80,1,color.a*t1*0.55),1.0,true)
                    elif particle["weapon_id"] == "club" and index%2==0:
                        draw_line(center+dir1*(r1-4),center+dir1*(r1-12),Color(0.72,0.43,0.18,color.a*t1),2.5,true)
                    elif particle["weapon_id"] == "axe":
                        draw_line(center+dir0*(r0-width0),center+dir1*(r1-width1),Color(0.55,0.30,0.17,color.a*t1*0.6),1.6,true)
            "weapon_motion":
                var direction: Vector2 = particle["direction"]
                var normal: Vector2 = direction.orthogonal()
                if particle["weapon_id"] == "boomerang":
                    draw_arc(point, size, direction.angle()-1.4, direction.angle()+1.4, 12, color, 2.5, true)
                elif particle["weapon_id"] == "spear":
                    draw_line(point-direction*size, point, color, 2.0, true)
                    draw_line(point-normal*4.0-direction*7.0, point, color, 1.8, true)
                    draw_line(point+normal*4.0-direction*7.0, point, color, 1.8, true)
                else:
                    draw_arc(point, size, PI, TAU, 12, color, 2.0, true)
            "flight":
                _draw_flight(self, particle, color, progress)
            "sling_release", "powder_muzzle", "staff_muzzle":
                _draw_ranged_muzzle(self, particle, color, progress)
            "arc_lightning":
                _draw_arc_lightning(self, particle, color, progress)
            "defeat":
                if particle["texture"] != null:
                    var texture: Texture2D = particle["texture"]
                    var dimensions: Vector2 = texture.get_size()
                    var body_dimensions: Vector2 = particle.get("body_dimensions", Vector2.ZERO)
                    if body_dimensions == Vector2.ZERO: body_dimensions = dimensions
                    var extent: Vector2 = dimensions * size * 2.0 / maxf(body_dimensions.x, body_dimensions.y)
                    draw_set_transform(point + Vector2(0, -progress * 18), progress * particle["direction"].x * 0.28, Vector2.ONE * (1.0 - progress * 0.4))
                    draw_texture_rect(texture, Rect2(-extent * 0.5, extent), false, Color(1.35, 1.12, 0.91, (1.0 - progress) * 0.8))
                    draw_set_transform(Vector2.ZERO)
                for index in range(8):
                    var burst_dir: Vector2 = Vector2.from_angle(index * TAU / 8.0 + 0.24)
                    var center: Vector2 = point + burst_dir * size * (0.3 + progress * 1.25)
                    var normal: Vector2 = burst_dir.orthogonal() * (6.0 * (1.0 - progress))
                    draw_colored_polygon(PackedVector2Array([center + burst_dir * 9, center - burst_dir * 5 + normal, center - burst_dir * 5 - normal]), color)
            "number":
                var punch: float = 1.22 if progress < 0.09 else (1.08 if progress < 0.2 else 1.0)
                if particle.get("critical", false):
                    punch += 0.12 if progress < 0.2 else 0.04
                size *= punch
                var width: float = font.get_string_size(particle["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
                point += Vector2(-width * 0.5, -progress * 64.0)
                var outline: Color = Color(0.16, 0.1, 0.08, color.a)
                draw_string_outline(font, point, particle["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), 5, outline)
                draw_string(font, point, particle["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), color)
            "blast", "cannon":
                _draw_explosion(point, size, color, progress, false)
            "rune_blast":
                _draw_explosion(point, size, color, progress, true)
            "quake":
                _draw_quake(point, size, color, progress)
            "slash":
                var facing: float = particle["direction"].angle()
                var cut: Vector2 = Vector2.from_angle(facing - 0.65)
                var thick: float = 7.0 if particle.get("thin", false) else 14.0
                var inner: float = 3.6 if particle.get("thin", false) else 8.0
                draw_line(point - cut * size * 1.15, point + cut * size * 1.15, Color(ink.r, ink.g, ink.b, color.a * 0.85), thick * (1.0 - progress), true)
                draw_line(point - cut * size * 1.15, point + cut * size * 1.15, color, inner * (1.0 - progress) + 1.5, true)
                if not particle.get("thin", false):
                    draw_arc(point, size * (0.55 + progress * 0.75), facing - PI * 0.75, facing + PI * 0.25, 22, Color(1.0, 1.0, 0.94, color.a), 6.0 * (1.0 - progress) + 1.5, true)
            "chop":
                _draw_chop(point, size, color, particle["direction"], progress)
            "smash":
                _draw_star(point, size * (0.55 + progress * 0.2), 8, Color(1.0, 0.96, 0.72, color.a * (1.0 - progress * 0.4)))
                draw_circle(point, size * 0.28 * (1.0 - progress), Color(1.0, 1.0, 0.92, color.a))
                draw_arc(point, size * (0.3 + progress * 0.95), 0, TAU, 36, Color(ink.r, ink.g, ink.b, color.a), 6.0 * (1.0 - progress) + 2.0, true)
                draw_arc(point, size * (0.3 + progress * 0.95), 0, TAU, 36, color, 3.5 * (1.0 - progress) + 1.0, true)
                for index in range(8):
                    var shard: Vector2 = Vector2.from_angle(index * TAU / 8.0 + 0.4)
                    var normal: Vector2 = shard.orthogonal() * 4.0 * (1.0 - progress)
                    var center: Vector2 = point + shard * size * (0.35 + progress * 0.95)
                    draw_colored_polygon(PackedVector2Array([center + shard * 12, center - shard * 4 + normal, center - shard * 4 - normal]), color)
                if particle.get("cracks", false):
                    _draw_cracks(point, size * (0.7 + progress * 0.45), color, progress)
            "rune_hit":
                var radius: float = size * (0.5 + progress * 0.85)
                var diamond: PackedVector2Array = PackedVector2Array()
                for index in range(5):
                    diamond.append(point + Vector2.from_angle(index * PI / 2.0 + progress * 0.45) * radius)
                draw_polyline(diamond, Color(ink.r, ink.g, ink.b, color.a), 8.0 * (1.0 - progress) + 1.5, true)
                draw_polyline(diamond, color, 4.0 * (1.0 - progress) + 1.2, true)
                draw_circle(point, radius * 0.34 * (1.0 - progress), Color(0.88, 1.0, 1.0, color.a))
                draw_line(point - Vector2.RIGHT * radius * 1.2, point + Vector2.RIGHT * radius * 1.2, color, 3.0, true)
                draw_line(point - Vector2.DOWN * radius * 1.2, point + Vector2.DOWN * radius * 1.2, color, 3.0, true)
                for index in range(4):
                    var angle: float = float(index) * PI * 0.5 + 0.35
                    var inner: Vector2 = point + Vector2.from_angle(angle) * radius * 0.42
                    var outer: Vector2 = point + Vector2.from_angle(angle) * radius * 0.9
                    draw_line(inner, outer, color, 2.2 * (1.0 - progress) + 0.8, true)
                    var tick: Vector2 = Vector2.from_angle(angle + 0.65) * radius * 0.16
                    draw_line(outer - tick, outer + tick, Color(ink.r, ink.g, ink.b, color.a), 2.0, true)
            "thrust":
                _draw_thrust(point, size, color, particle["direction"], progress)
            "lightning":
                _draw_lightning(point, size, color, progress)
            "fleck":
                _draw_flecks(point, size, color, progress)
            "ribbon":
                _draw_ribbon(point, size, color, particle["direction"], progress)
            "aura":
                var glow: Color = Color(color.r, color.g, color.b, color.a * 0.38)
                draw_circle(point, size * (0.7 + progress * 0.15), glow)
                draw_arc(point, size * (0.72 + progress * 0.55), 0.0, TAU, 36, Color(ink.r, ink.g, ink.b, color.a), 5.5 * (1.0 - progress) + 1.6, true)
                draw_arc(point, size * (0.72 + progress * 0.55), 0.0, TAU, 36, color, 3.2 * (1.0 - progress) + 1.0, true)
            "muzzle":
                _draw_star(point, size * (0.55 - progress * 0.12), 6, color)
                for index in range(5):
                    var spark: Vector2 = Vector2.from_angle(float(index) * TAU / 5.0 + 0.2)
                    draw_line(point + spark * size * progress * 0.15, point + spark * size * (0.4 + progress * 0.5), color, 2.6 * (1.0 - progress) + 0.8, true)
            "impact":
                _draw_star(point, size * (0.7 - progress * 0.2), 7, Color(1.0, 0.97, 0.8, color.a))
                draw_circle(point, 14.0 * (1.0 - progress), Color(1.0, 1.0, 0.92, color.a))
                for index in range(8):
                    var ray: Vector2 = Vector2.from_angle(index * TAU / 8.0 + progress * 0.2)
                    draw_line(point + ray * size * progress * 0.25, point + ray * size * (0.45 + progress * 0.75), Color(ink.r, ink.g, ink.b, color.a * 0.8), 5.0 * (1.0 - progress) + 1.5, true)
                    draw_line(point + ray * size * progress * 0.25, point + ray * size * (0.45 + progress * 0.75), color, 3.2 * (1.0 - progress) + 1.0, true)
            "ring":
                draw_arc(point, size * (0.28 + progress * 0.85), 0.0, TAU, 48, Color(ink.r, ink.g, ink.b, color.a * 0.7), 6.0 * (1.0 - progress) + 1.5, true)
                draw_arc(point, size * (0.28 + progress * 0.85), 0.0, TAU, 48, color, 3.6 * (1.0 - progress) + 1.0, true)
            "beam":
                var chord: Vector2=Vector2(particle.end)-point
                draw_set_transform((point+Vector2(particle.end))*0.5,chord.angle())
                draw_texture_rect(CombatArt.texture("lightning",progress),Rect2(-chord.length()*0.59,-13,chord.length()*1.18,26),false,Color(1,1,1,color.a))
                draw_set_transform(Vector2.ZERO)
            "hit":
                _draw_star(point, size * (0.8 - progress * 0.15), 6, color)
                for index in range(6):
                    var ray: Vector2 = Vector2.from_angle(float(index) * TAU / 6.0 + 0.3)
                    draw_line(point + ray * size * progress * 0.2, point + ray * size * (0.5 + progress * 0.7), color, 3.4 * (1.0 - progress) + 1.0, true)
            _:
                for index in range(6):
                    var ray: Vector2 = Vector2.from_angle(float(index) * TAU / 6.0 + 0.35)
                    draw_line(point + ray * size * progress, point + ray * size * (0.45 + progress), color, 3.2, true)

func _oriented_points(center: Vector2, axis: Vector2, coordinates: Array) -> PackedVector2Array:
    var points := PackedVector2Array()
    var side: Vector2 = axis.orthogonal()
    for local in coordinates:
        points.append(center + axis * local.x + side * local.y)
    return points

func _draw_ranged_muzzle(canvas, particle: Dictionary, color: Color, progress: float) -> void:
    var point: Vector2 = particle["at"]
    var axis: Vector2 = particle["direction"]
    var side: Vector2 = axis.orthogonal()
    var outline := Color(ink.r, ink.g, ink.b, color.a)
    var white := Color(1.0, 0.98, 0.86, color.a)
    match particle["weapon_id"]:
        "sling":
            var snap: Vector2 = point + axis * (6.0 - progress * 7.0)
            var band := PackedVector2Array([point - side * 9 - axis * 5, snap, point + side * 9 - axis * 5])
            canvas.draw_polyline(band, outline, 4.0, true)
            canvas.draw_polyline(band, color, 1.9, true)
            for sign in [-1.0, 1.0]:
                var start: Vector2 = point + axis * 10 + side * sign * 4
                var end: Vector2 = start + axis * 7 + side * sign * 2
                canvas.draw_line(start, end, outline, 3.1, true)
                canvas.draw_line(start, end, white, 1.3, true)
        "powder":
            var shrink: float = 1.0 - progress * 0.45
            var flash := _oriented_points(point, axis, [Vector2(-1, 0), Vector2(7, -8) * shrink, Vector2(11, -3) * shrink, Vector2(26, -4) * shrink, Vector2(18, 1) * shrink, Vector2(23, 7) * shrink, Vector2(10, 4) * shrink, Vector2(6, 9) * shrink])
            canvas.draw_colored_polygon(flash, color)
            var border: PackedVector2Array = flash.duplicate()
            border.append(flash[0])
            canvas.draw_polyline(border, outline, 2.6, true)
            canvas.draw_colored_polygon(_oriented_points(point, axis, [Vector2(0, 0), Vector2(13, -3) * shrink, Vector2(19, 0) * shrink, Vector2(10, 4) * shrink]), white)
            if particle.get("enchanted", false):
                canvas.draw_arc(point + axis * 5, 10.0 * shrink, axis.angle() - 1.4, axis.angle() + 1.4, 12, outline, 4.0, true)
                canvas.draw_arc(point + axis * 5, 10.0 * shrink, axis.angle() - 1.4, axis.angle() + 1.4, 12, Color(0.45, 1.0, 1.0, color.a), 2.0, true)
        "staff":
            var radius: float = 10.0 + progress * 7.0
            var rune := _oriented_points(point, axis.rotated(progress * 0.45), [Vector2(radius, 0), Vector2(0, radius * 0.8), Vector2(-radius, 0), Vector2(0, -radius * 0.8), Vector2(radius, 0)])
            canvas.draw_polyline(rune, outline, 4.7, true)
            canvas.draw_polyline(rune, color, 2.2, true)
            canvas.draw_arc(point, radius * 0.58, axis.angle() - 2.4, axis.angle() + 1.0, 16, white, 1.7, true)
            canvas.draw_line(point + axis * 11, point + axis * 22, outline, 4.0, true)
            canvas.draw_line(point + axis * 11, point + axis * 22, white, 1.6, true)
            canvas.draw_circle(point, 3.0 * (1.0 - progress * 0.6), Color(0.86, 1.0, 1.0, color.a))

func _draw_flight(canvas, particle: Dictionary, color: Color, progress: float) -> void:
    var start: Vector2 = particle["at"]
    var end: Vector2 = particle["end"]
    var axis: Vector2 = (end - start).normalized()
    var side: Vector2 = axis.orthogonal()
    var outline := Color(ink.r, ink.g, ink.b, color.a * 0.65)
    match particle.get("weapon_id", "staff"):
        "sling":
            canvas.draw_line(start, end, outline, 5.2 * (1.0 - progress) + 0.9, true)
            canvas.draw_line(start, end, Color(color.r, color.g, color.b, color.a * 0.92), 2.3, true)
            canvas.draw_circle(end, 3.2 * (1.0 - progress), Color(1.0, 0.97, 0.82, color.a))
            canvas.draw_circle(start - side * 2, 2.4 * (1.0 - progress), Color(color.r, color.g, color.b, color.a * 0.75))
        "spear":
            canvas.draw_line(start, end, outline, 7.4 * (1.0 - progress) + 1.4, true)
            canvas.draw_line(start, end, Color(color.r, color.g, color.b, color.a), 3.6 * (1.0 - progress) + 1.1, true)
            canvas.draw_line(start.lerp(end, 0.12), end, Color(1.0, 0.98, 0.82, color.a * 0.95), 1.6, true)
            canvas.draw_circle(end, 4.0 * (1.0 - progress), Color(1.0, 0.96, 0.78, color.a))
        "powder":
            var width: float = 3.6 * (1.0 - progress) + 0.8
            canvas.draw_colored_polygon(PackedVector2Array([start - axis * 5, end + side * width, end - side * width]), outline)
            canvas.draw_colored_polygon(PackedVector2Array([start, end + side * width * 0.65, end - side * width * 0.65]), color)
            canvas.draw_line(start.lerp(end, 0.25), end, Color(1.0, 1.0, 0.86, color.a * 0.85), 1.5, true)
        _:
            canvas.draw_line(start, end, outline, 6.2 * (1.0 - progress) + 1.2, true)
            canvas.draw_line(start, end, color, 3.0 * (1.0 - progress) + 0.9, true)
            canvas.draw_line(start.lerp(end, 0.15), end, Color(0.90, 1.0, 1.0, color.a * 0.9), 1.1, true)
            var rune_at: Vector2 = start.lerp(end, 0.55)
            canvas.draw_line(rune_at - side * 4, rune_at + side * 4, color, 1.3, true)

func _draw_arc_lightning(canvas, particle: Dictionary, color: Color, progress: float) -> void:
    var paths: Array = [particle["points"]]
    paths.append_array(particle["branches"])
    var fade: float = 1.0 - progress * 0.55
    for index in range(paths.size()):
        var branch: bool = index > 0
        var opacity: float = 0.85 if branch else 1.0
        canvas.draw_polyline(paths[index], Color(ink.r, ink.g, ink.b, color.a * opacity), (4.1 if branch else 6.5) * fade, true)
        canvas.draw_polyline(paths[index], Color(color.r, color.g, color.b, color.a * opacity), (2.4 if branch else 3.7) * fade, true)
        canvas.draw_polyline(paths[index], Color(0.88, 1.0, 1.0, color.a * opacity), (1.0 if branch else 1.7) * fade, true)
    canvas.draw_circle(particle["end"], 2.6 * fade, Color(0.93, 1.0, 1.0, color.a))
    var main: PackedVector2Array = particle["points"]
    for index in range(1, main.size() - 1):
        var mid: Vector2 = main[index]
        var tangent: Vector2 = (main[mini(index + 1, main.size() - 1)] - main[maxi(index - 1, 0)])
        if tangent.length_squared() < 0.001:
            continue
        tangent = tangent.normalized()
        var side: Vector2 = tangent.orthogonal()
        var tick: float = (3.4 + float(index % 3) * 1.8) * fade
        if index % 2 == 0:
            canvas.draw_line(mid - side * tick, mid + side * tick * 0.5, Color(ink.r, ink.g, ink.b, color.a * 0.7), 1.6, true)
            canvas.draw_line(mid - side * tick * 0.35, mid + side * tick * 0.2, Color(0.9, 1.0, 0.95, color.a * 0.8), 1.0, true)
        else:
            var flake: PackedVector2Array = PackedVector2Array([
                mid + tangent * 3.2,
                mid + side * 2.4,
                mid - tangent * 2.0,
                mid - side * 1.6
            ])
            canvas.draw_colored_polygon(flake, Color(0.86, 1.0, 0.96, color.a * 0.55))

func _cloud_points(center: Vector2, radius: float, seed: int, count: int = 48) -> PackedVector2Array:
    var points: PackedVector2Array = PackedVector2Array()
    var lobes: float = 5.0 + float(absi(seed) % 3)
    var ripples: float = 9.0 + float(absi(seed * 3) % 5)
    var phase: float = float(seed) * 0.73
    for index in range(count):
        var theta: float = float(index) / float(count) * TAU
        var radius_at: float = radius * (0.75 + 0.25 * sin(lobes * theta + phase) + 0.12 * sin(ripples * theta + phase * 1.7))
        radius_at *= 1.0 + 0.04 * sin(float(seed + index) * 1.7)
        points.append(center + Vector2.from_angle(theta) * radius_at)
    return points

func _fill_cloud(points: PackedVector2Array, color: Color, ink_pad: float) -> void:
    if points.size() < 3:
        return
    var centroid: Vector2 = Vector2.ZERO
    for point in points:
        centroid += point
    centroid /= float(points.size())
    var ink_pts: PackedVector2Array = PackedVector2Array()
    for point in points:
        var offset: Vector2 = point - centroid
        var length: float = maxf(offset.length(), 1.0)
        ink_pts.append(centroid + offset * ((length + ink_pad) / length))
    var outline: Color = Color(ink.r, ink.g, ink.b, color.a * 0.95)
    var fill: Color = Color(color.r, color.g, color.b, color.a * 0.9)
    draw_colored_polygon(ink_pts, outline)
    draw_colored_polygon(points, fill)

func _draw_smoke(center: Vector2, radius: float, color: Color, seed: int, progress: float = 0.0) -> void:
    var body: PackedVector2Array = _cloud_points(center, radius, seed, 52)
    _fill_cloud(body, color, 4.5)
    var highlight: Color = Color(paper.r, paper.g, paper.b, color.a * 0.42)
    var shine: PackedVector2Array = _cloud_points(center + Vector2(-radius * 0.22, -radius * 0.28), radius * 0.36, seed + 3, 28)
    if shine.size() >= 3:
        draw_colored_polygon(shine, highlight)
    var wisps: int = 2 + absi(seed) % 2
    for index in range(wisps):
        var offset: Vector2 = Vector2(-10.0 + float(index) * 11.0, -radius * (0.58 + progress * 0.42) - float(index) * 8.0)
        var wisp_radius: float = radius * (0.28 - float(index) * 0.05) * (1.0 + progress * 0.28)
        var wisp: PackedVector2Array = _cloud_points(center + offset.rotated(float(seed) * 0.2), maxf(wisp_radius, 4.0), seed + 11 + index, 36)
        var wisp_color: Color = color
        wisp_color.a *= 0.62
        _fill_cloud(wisp, wisp_color, 3.0)
    for index in range(5):
        var angle: float = float(seed) * 0.9 + float(index) * 1.7
        var distance: float = radius * (0.18 + float(index % 3) * 0.22)
        var soot: Vector2 = center + Vector2.from_angle(angle) * distance + Vector2(0, progress * 10.0)
        draw_circle(soot, 1.5 + float(index % 3) * 0.7, Color(ink.r, ink.g, ink.b, color.a * 0.72))

func _draw_star(center: Vector2, radius: float, spikes: int, color: Color) -> void:
    var points: PackedVector2Array = PackedVector2Array()
    for index in range(spikes * 2):
        var length: float = radius if index % 2 == 0 else radius * 0.42
        points.append(center + Vector2.from_angle(float(index) * PI / float(spikes) - 0.2) * length)
    var outline: PackedVector2Array = points.duplicate()
    outline.append(points[0])
    draw_colored_polygon(points, color)
    draw_polyline(outline, Color(ink.r, ink.g, ink.b, color.a), 3.4, true)

func _draw_explosion(point: Vector2, size: float, color: Color, progress: float, rune: bool) -> void:
    var outer: float = size * (0.85 + progress * 0.45)
    var core: Color = Color(0.72, 1.0, 1.0, color.a * 0.9) if rune else Color(1.0, 0.93, 0.55, color.a * 0.9)
    _draw_star(point, outer, 9, Color(color.r, color.g, color.b, color.a * 0.95))
    _draw_star(point, outer * 0.58, 7, core)
    draw_circle(point, size * (0.18 + progress * 0.12), Color(1.0, 0.98, 0.86, color.a))
    for index in range(10):
        var ray: Vector2 = Vector2.from_angle(index * TAU / 10.0 + 0.3)
        draw_line(point + ray * size * progress * 0.55, point + ray * size * (0.4 + progress * 0.95), Color(ink.r, ink.g, ink.b, color.a), 5.0 * (1.0 - progress) + 1.2, true)
        draw_line(point + ray * size * progress * 0.55, point + ray * size * (0.4 + progress * 0.95), color, 3.0 * (1.0 - progress) + 0.8, true)
    for index in range(6):
        var shard_dir: Vector2 = Vector2.from_angle(index * TAU / 6.0 + 0.51)
        var shard: Vector2 = point + shard_dir * size * (0.35 + progress * 0.7)
        var normal: Vector2 = shard_dir.orthogonal() * (5.0 * (1.0 - progress))
        var debris: Color = Color("#5a4636") if not rune else Color("#2f6c73")
        debris.a = color.a
        draw_colored_polygon(PackedVector2Array([shard + shard_dir * 11, shard - shard_dir * 4 + normal, shard - shard_dir * 4 - normal]), debris)

func _draw_quake(point: Vector2, size: float, color: Color, progress: float) -> void:
    _draw_star(point, size * (0.42 + progress * 0.12), 8, Color(1.0, 0.96, 0.74, color.a))
    draw_arc(point, size * (0.22 + progress * 0.7), 0.0, TAU, 36, Color(ink.r, ink.g, ink.b, color.a), 7.0 * (1.0 - progress) + 2.0, true)
    draw_arc(point, size * (0.22 + progress * 0.7), 0.0, TAU, 36, color, 3.8 * (1.0 - progress) + 1.0, true)
    _draw_cracks(point, size * (0.75 + progress * 0.4), color, progress)

func _draw_cracks(point: Vector2, size: float, color: Color, progress: float) -> void:
    for index in range(6):
        var angle: float = float(index) * TAU / 6.0 + 0.18
        var tip: Vector2 = point + Vector2.from_angle(angle) * size * (0.55 + progress * 0.45)
        var mid: Vector2 = point.lerp(tip, 0.55) + Vector2.from_angle(angle + 0.7) * size * 0.12
        draw_line(point, mid, Color(ink.r, ink.g, ink.b, color.a), 5.0 * (1.0 - progress) + 1.6, true)
        draw_line(mid, tip, Color(ink.r, ink.g, ink.b, color.a), 3.2 * (1.0 - progress) + 1.0, true)
        draw_line(point, mid, color, 2.2 * (1.0 - progress) + 0.8, true)

func _draw_chop(point: Vector2, size: float, color: Color, direction: Vector2, progress: float) -> void:
    var facing: float = direction.angle()
    var cut: Vector2 = Vector2.from_angle(facing - 0.4)
    draw_line(point - cut * size * 1.05, point + cut * size * 1.05, Color(ink.r, ink.g, ink.b, color.a * 0.9), 12.0 * (1.0 - progress), true)
    draw_line(point - cut * size * 1.05, point + cut * size * 1.05, color, 6.5 * (1.0 - progress) + 1.4, true)
    for index in range(5):
        var chip_dir: Vector2 = Vector2.from_angle(facing + 0.8 + float(index) * 0.55)
        var chip: Vector2 = point + chip_dir * size * (0.25 + progress * 0.7 + float(index) * 0.04)
        var normal: Vector2 = chip_dir.orthogonal() * (4.0 * (1.0 - progress))
        var stone: Color = Color("#d8c6a0")
        stone.a = color.a
        draw_colored_polygon(PackedVector2Array([chip + chip_dir * 8, chip - chip_dir * 3 + normal, chip - chip_dir * 3 - normal]), stone)
        draw_polyline(PackedVector2Array([chip + chip_dir * 8, chip - chip_dir * 3 + normal, chip - chip_dir * 3 - normal, chip + chip_dir * 8]), Color(ink.r, ink.g, ink.b, color.a), 1.8, true)

func _draw_thrust(point: Vector2, size: float, color: Color, direction: Vector2, progress: float) -> void:
    var axis: Vector2 = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
    var tail: Vector2 = point - axis * size * 1.35
    var tip: Vector2 = point + axis * size * (1.05 + progress * 0.35)
    draw_line(tail, tip, Color(ink.r, ink.g, ink.b, color.a * 0.9), 6.5 * (1.0 - progress) + 1.5, true)
    draw_line(tail, tip, color, 3.2 * (1.0 - progress) + 1.0, true)
    var head: PackedVector2Array = PackedVector2Array([
        tip,
        tip - axis * size * 0.28 + axis.orthogonal() * size * 0.16,
        tip - axis * size * 0.28 - axis.orthogonal() * size * 0.16
    ])
    draw_colored_polygon(head, Color(ink.r, ink.g, ink.b, color.a))
    draw_colored_polygon(PackedVector2Array([
        tip,
        tip - axis * size * 0.22 + axis.orthogonal() * size * 0.1,
        tip - axis * size * 0.22 - axis.orthogonal() * size * 0.1
    ]), color)
    _draw_star(tip, size * 0.22 * (1.0 - progress * 0.35), 5, Color(1.0, 0.97, 0.85, color.a))
    for index in range(3):
        var spark: Vector2 = Vector2.from_angle(axis.angle() + 0.7 + float(index) * 0.5)
        draw_line(tip, tip + spark * size * (0.22 + progress * 0.2), color, 2.2, true)

func _draw_lightning(point: Vector2, size: float, color: Color, progress: float) -> void:
    var fade: float = 1.0 - progress * 0.75
    var core: Color = Color(0.85, 1.0, 1.0, color.a)
    var start: Vector2 = point + Vector2(-size * 0.18, -size * 1.05)
    var main: PackedVector2Array = _lightning_path(start, Vector2(0.12, 1.0), size * 1.9, 7, 11, size * 0.22)
    _stroke_bolt(main, Color(ink.r, ink.g, ink.b, color.a), 7.6 * fade, 1.4)
    _stroke_bolt(main, color, 4.4 * fade, 0.8)
    _stroke_bolt(main, core, 2.0 * fade, 0.5)
    if main.size() >= 5:
        var branch_a: PackedVector2Array = _lightning_path(main[2], Vector2(0.9, 0.55), size * 0.72, 4, 23, size * 0.16)
        var branch_b: PackedVector2Array = _lightning_path(main[4], Vector2(-0.8, 0.7), size * 0.55, 3, 41, size * 0.14)
        _stroke_bolt(branch_a, Color(ink.r, ink.g, ink.b, color.a * 0.85), 3.1 * fade, 0.8)
        _stroke_bolt(branch_a, color, 1.6 * fade, 0.5)
        _stroke_bolt(branch_b, Color(ink.r, ink.g, ink.b, color.a * 0.75), 2.3 * fade, 0.7)
        _stroke_bolt(branch_b, color, 1.15 * fade, 0.4)
    _draw_star(point, size * 0.22 * (1.0 - progress * 0.3), 4, core)

func _lightning_path(origin: Vector2, direction: Vector2, length: float, steps: int, seed: int, jag: float) -> PackedVector2Array:
    var axis: Vector2 = direction.normalized()
    var side: Vector2 = axis.orthogonal()
    var points: PackedVector2Array = PackedVector2Array()
    var cursor: Vector2 = origin
    points.append(cursor)
    var leftover: float = length
    for step in range(steps):
        var remain: int = steps - step
        var share: float = leftover * (0.12 + 0.28 * absf(sin(float(seed * 3 + step * 11))))
        if remain == 1:
            share = leftover
        share = maxf(share, length * 0.08)
        leftover = maxf(0.0, leftover - share)
        var kick: float = jag * (0.4 + 0.85 * absf(sin(float(seed + step * 7))))
        if step % 2 == 1:
            kick = -kick
        if step == steps - 1:
            kick *= 0.25
        cursor += axis * share + side * kick
        points.append(cursor)
    return points

func _stroke_bolt(points: PackedVector2Array, color: Color, peak: float, tip: float) -> void:
    if points.size() < 2:
        return
    var last: int = points.size() - 1
    for index in range(last):
        var t: float = float(index) / float(maxi(1, last - 1))
        var envelope: float = 1.0 - absf(t * 2.0 - 0.9) * 0.75
        envelope = clampf(envelope, 0.15, 1.0)
        if index == 0 or index == last - 1:
            envelope *= 0.45
        elif index % 2 == 0:
            envelope *= 1.25
        var width: float = lerpf(tip, peak, envelope)
        draw_line(points[index], points[index + 1], color, maxf(0.6, width), true)

func _draw_flecks(point: Vector2, size: float, color: Color, progress: float) -> void:
    _draw_star(point, size * (0.4 - progress * 0.1), 4, color)
    for index in range(5):
        var angle: float = float(index) * TAU / 5.0 + 0.4
        var fleck: Vector2 = point + Vector2.from_angle(angle) * size * (0.7 + progress * 0.8)
        var axis: Vector2 = Vector2.from_angle(angle + 0.7) * (3.6 * (1.0 - progress) + 1.2)
        var normal: Vector2 = axis.orthogonal() * 0.55
        draw_colored_polygon(PackedVector2Array([
            fleck + axis, fleck + normal, fleck - axis * 0.7, fleck - normal
        ]), Color(ink.r, ink.g, ink.b, color.a * 0.9))
        draw_colored_polygon(PackedVector2Array([
            fleck + axis * 0.7, fleck + normal * 0.6, fleck - axis * 0.5, fleck - normal * 0.6
        ]), color)

func _draw_ribbon(point: Vector2, size: float, color: Color, direction: Vector2, progress: float) -> void:
    var axis: Vector2 = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
    var points: PackedVector2Array = PackedVector2Array()
    for index in range(10):
        var t: float = float(index) / 9.0
        var along: Vector2 = axis * size * (-0.35 + t * 1.55)
        var wave: Vector2 = axis.orthogonal() * sin(t * PI * 1.6 + progress) * size * (0.42 - t * 0.12)
        points.append(point + along + wave)
    for index in range(points.size() - 1):
        var t: float = float(index) / float(points.size() - 1)
        var width: float = (5.8 if t < 0.55 else lerpf(5.8, 1.2, (t - 0.55) / 0.45)) * (1.0 - progress * 0.6)
        draw_line(points[index], points[index + 1], Color(ink.r, ink.g, ink.b, color.a), width + 2.4, true)
        draw_line(points[index], points[index + 1], color, maxf(1.0, width), true)
    _draw_star(point, size * 0.22 * (1.0 - progress * 0.4), 5, Color(1.0, 0.97, 0.85, color.a))

func _draw_word(point: Vector2, text: String, size: int, color: Color, tilt: float, progress: float) -> void:
    var punch: float = 1.45 if progress < 0.12 else (1.08 if progress < 0.25 else 1.0)
    var font_size: int = int(float(size) * punch)
    var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    var origin: Vector2 = point + Vector2(-width * 0.5, -progress * 36.0)
    draw_set_transform(origin, deg_to_rad(tilt * (1.0 - progress * 0.4)), Vector2.ONE)
    var outline: Color = Color(ink.r, ink.g, ink.b, color.a)
    draw_string_outline(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 12, outline)
    draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
    draw_set_transform(Vector2.ZERO)
