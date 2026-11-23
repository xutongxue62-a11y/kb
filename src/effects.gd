extends Node2D
const GameFonts=preload("res://src/game_fonts.gd")
const CombatArt=preload("res://src/combat_art.gd")
const BattleVisuals=preload("res://src/battle_visuals.gd")

var particles: Array = []
var charge_cues: Array = []
var vfx_mode: String = "full" # "full", "minimal", "off"
var vfx_enabled: bool = true
var hero_anchor: Vector2 = Vector2.ZERO
var _has_hero_anchor: bool = false
var number_serial: int = 0
var bolt_serial: int = 0
var _impact_weapon: String=""
var _impact_tier: int=0
var font: SystemFont = GameFonts.create_system(PackedStringArray(["Microsoft YaHei", "SimSun", "Arial"]))
var ink: Color = Color("#2a221c")
var paper: Color = Color("#f4ead6")
var _draw_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var ground_layer: Node2D
var number_layer: Node2D
var _had_ground_particles: bool = false
var _had_particles: bool = false
var _had_numbers: bool = false

const NUMBER_LIFE := 0.76
const DAMAGE_NUMBER_MERGE_TIME := 0.055
const DAMAGE_NUMBER_LIMIT := 8
const STATUS_NUMBER_LIMIT := 2

class GroundLayer:
    extends Node2D
    var owner_fx
    func _draw() -> void:
        if owner_fx != null:
            owner_fx._draw_ground_particles(self)

class NumberLayer:
    extends Node2D
    var owner_fx
    func _draw() -> void:
        owner_fx._draw_numbers(self)

func _ready() -> void:
    ground_layer = GroundLayer.new()
    ground_layer.owner_fx = self
    ground_layer.z_as_relative = false
    ground_layer.z_index = -20
    add_child(ground_layer)
    number_layer = NumberLayer.new()
    number_layer.owner_fx = self
    number_layer.z_index = 1
    add_child(number_layer)

const HEAVY_IDS = ["powder", "hammer", "club", "axe"]
const LIGHT_IDS = ["blade", "sling", "boomerang", "staff", "drone"]
const DECORATIVE_KINDS = ["smoke", "flight", "sling_release", "powder_muzzle", "staff_muzzle", "shock_wrap", "aura", "weapon_motion", "swing_trail", "rune_ignition", "dodge", "word", "fleck", "hit", "impact", "spark", "rune_spark", "rune_hit", "fire_splash"]
const PRIORITY_KINDS = ["sky_bolt", "rune_blast", "fire_blast", "thunder_blast", "quake", "arc_lightning"]

func set_vfx_mode(mode: String) -> void:
    vfx_mode = mode if mode in ["full", "minimal", "off"] else "full"
    vfx_enabled = vfx_mode == "full"
    if vfx_mode != "full":
        charge_cues.clear()
    if vfx_mode == "off":
        particles = particles.filter(func(p): return str(p.get("kind", "")) == "number")
    queue_redraw()
    if ground_layer != null:
        ground_layer.queue_redraw()

func _init() -> void:
    font.font_names = PackedStringArray(["Microsoft YaHei", "SimSun", "Arial"])

const DEDUP_HIT_KINDS = ["rune_spark", "fire_splash", "shock_wrap", "pierce_cue", "hit", "impact"]

func add_particle(particle: Dictionary) -> void:
    var kind: String = str(particle.get("kind", ""))
    if vfx_mode == "off":
        return
    if vfx_mode == "minimal" and kind in DECORATIVE_KINDS:
        return
    if kind in DEDUP_HIT_KINDS and particle.has("at"):
        var at_pos: Vector2 = particle["at"]
        for existing in particles:
            if str(existing.get("kind", "")) == kind and float(existing.get("age", 1.0)) < 0.07 and Vector2(existing["at"]).distance_squared_to(at_pos) < 1444.0:
                return
    if not _impact_weapon.is_empty() and not particle.has("weapon_id"):
        particle["weapon_id"]=_impact_weapon
    particles.append(particle)
    var cap: int = 30 if vfx_mode == "minimal" else 36
    if particles.size() > cap:
        var effect_count: int = 1
        var first_effect: int = -1
        var first_decorative: int = -1
        for idx in range(particles.size() - 1):
            var existing_kind: String = str(particles[idx].get("kind", ""))
            if existing_kind == "number":
                continue
            effect_count += 1
            if first_effect < 0:
                first_effect = idx
            if first_decorative < 0 and existing_kind not in PRIORITY_KINDS:
                first_decorative = idx
        if effect_count > cap:
            particles.remove_at(first_decorative if first_decorative >= 0 else first_effect)
    queue_redraw()
    if ground_layer != null and kind in ["quake", "thunder_blast"]:
        ground_layer.queue_redraw()

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
    var scaled: float = size * (0.95 if kind in ["rune_spark", "fire_splash"] else (1.45 if size < 70.0 else 1.08))
    var heavy: bool = kind in ["blast", "cannon", "quake"]
    var life: float = 0.38 if heavy else (0.36 if kind in ["ring", "rune_blast", "fire_blast", "thunder_blast"] else (0.28 if kind == "fire_splash" else (0.24 if kind == "rune_spark" else 0.24)))
    add_particle({"at": at, "color": color, "size": scaled, "kind": kind, "age": 0.0, "life": life})
    if heavy:
        var puffs: int = 1
        for index in range(puffs):
            puff(at, color.lerp(Color("#6b5340"), 0.25), scaled * 0.24, index)
        var word: String = "轰"
        var word_color: Color = Color("#fff2c8")
        comic_word(at + Vector2(10, -8), word, word_color, 36 if kind != "quake" else 34, -16.0)
    elif kind == "muzzle":
        puff(at, color, scaled * 0.26, 0)

func dodge_streak(at: Vector2, direction: Vector2) -> void:
    add_particle({"at": at + Vector2(0, 18), "direction": direction, "color": Color("#c4f4f1"), "size": 28.0, "kind": "dodge", "age": 0.0, "life": 0.15})

func rune_ignition(staff: Vector2, muzzle: Vector2, vfx_tier: int = 0) -> void:
    var tint: Color = BattleVisuals.staff_tint(vfx_tier)
    add_particle({"at": staff, "end": muzzle, "color": tint, "size": 20.0, "kind": "rune_ignition", "age": 0.0, "life": 0.28, "vfx_tier": vfx_tier})
    burst(muzzle, tint, 22.0 if vfx_tier >= 1 else 18.0, "rune_spark")

func weapon_aura(at: Vector2, color: Color, size: float = 28.0) -> void:
    add_particle({"at": at, "color": color, "size": size, "kind": "aura", "age": 0.0, "life": 0.14})
    burst(at, color, maxf(10.0, size * 0.45), "muzzle")

func beam(start: Vector2, end: Vector2, color: Color) -> void:
    add_particle({"at": start, "end": end, "color": color, "size": 6.5, "kind": "beam", "age": 0.0, "life": 0.20})

func muzzle(at: Vector2, direction: Vector2, key: String, enchanted: bool = false, vfx_tier: int = 0, fire_tier: int = 0, thunder_tier: int = 0, fire_enchanted: bool = false, thunder_enchanted: bool = false, thunder_red: bool = false) -> void:
    if key not in ["sling", "powder", "staff"]:
        return
    var axis: Vector2 = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
    var kind: String = {"sling": "sling_release", "powder": "powder_muzzle", "staff": "staff_muzzle"}[key]
    var color: Color = {"sling": Color("#ead3a0"), "powder": Color("#ffbc54"), "staff": Color("#70f2fa")}[key]
    var is_fire: bool = fire_enchanted or fire_tier > 0
    var is_thunder: bool = thunder_enchanted or thunder_tier > 0
    var any_enchant: bool = enchanted or is_fire or is_thunder
    if key == "staff" or enchanted:
        color = BattleVisuals.staff_tint(vfx_tier)
    elif is_fire:
        color = BattleVisuals.fire_tint(fire_tier)
    elif is_thunder:
        color = Color("#ff3a2e") if thunder_red else BattleVisuals.thunder_tint(thunder_tier)
    add_particle({"at": at, "direction": axis, "weapon_id": key, "enchanted": any_enchant, "color": color, "size": 23.0 if key == "powder" else (16.0 if key == "staff" and vfx_tier >= 1 else 14.0), "kind": kind, "age": 0.0, "life": 0.11 if key == "powder" else (0.14 if key == "sling" else 0.18), "vfx_tier": vfx_tier})
    if key == "powder" and not any_enchant:
        puff(at - axis * 3, Color("#aa967c"), 10.0, 1)

func sky_lightning(start: Vector2, end: Vector2, color: Color, with_wrap: bool = true, thickness_scale: float = 1.0, is_red: bool = false) -> void:
    bolt_serial += 1
    var rng := RandomNumberGenerator.new()
    rng.seed = bolt_serial * 131 + int(absf(end.x * 17.0 + end.y * 31.0))
    var delta_vec: Vector2 = end - start
    var length: float = maxf(1.0, delta_vec.length())
    var axis: Vector2 = delta_vec / length
    var side: Vector2 = axis.orthogonal()
    # Asymmetric sharp lightning leaps (uneven segment lengths, dramatic zags, never a uniform sine-stick!)
    var pts := PackedVector2Array([start])
    var t_cur: float = 0.0
    var side_off: float = 0.0
    var dir_sign: float = 1.0 if rng.randf() < 0.5 else -1.0
    while t_cur < 0.88:
        t_cur += rng.randf_range(0.08, 0.17)
        if t_cur >= 0.92:
            break
        dir_sign = -dir_sign if rng.randf() < 0.72 else dir_sign
        var env: float = sin(t_cur * PI)
        side_off = clampf(side_off * 0.45 + dir_sign * rng.randf_range(10.0, 26.0) * env, -34.0, 34.0)
        pts.append(start.lerp(end, t_cur) + side * side_off)
    pts.append(end)
    # Acute downward-cascading jagged lightning forks (18-38 deg downward, multi-segment & tapering)
    var branches: Array = []
    var fork_count: int = rng.randi_range(2, 3)
    for b_i in range(fork_count):
        if pts.size() < 4:
            break
        var idx: int = clampi(int(roundi(float(pts.size() - 1) * rng.randf_range(0.18, 0.72))), 1, pts.size() - 2)
        var cur: Vector2 = pts[idx]
        var bpts := PackedVector2Array([cur])
        var sgn: float = -1.0 if (b_i % 2 == 0) else 1.0
        var fork_ang: float = axis.angle() + sgn * rng.randf_range(0.28, 0.56)
        var segs: int = rng.randi_range(3, 4)
        var seg_len: float = rng.randf_range(14.0, 24.0) * maxf(1.0, thickness_scale * 0.9)
        for _s in range(segs):
            var step_a: float = fork_ang + rng.randf_range(-0.36, 0.36)
            cur += Vector2.from_angle(step_a) * seg_len
            seg_len *= 0.82
            bpts.append(cur)
        branches.append(bpts)
    var bolt_col: Color = Color("#ff3a2e") if is_red else color
    add_particle({"at": end, "start": start, "end": end, "points": pts, "branches": branches, "color": bolt_col, "size": 9.0 * thickness_scale, "scale": thickness_scale, "red": is_red, "kind": "sky_bolt", "age": 0.0, "life": 0.36})
    if with_wrap:
        shock_wrap(end, 34.0, bolt_col, is_red)

func shock_wrap(at: Vector2, radius: float = 30.0, color: Color = Color("#eef6ff"), is_red: bool = false) -> void:
    bolt_serial += 1
    add_particle({"at": at, "color": Color("#ff3a2e") if is_red else color, "size": maxf(20.0, radius), "red": is_red, "kind": "shock_wrap", "age": 0.0, "life": 0.36, "seed": bolt_serial})

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
    # Collect simultaneous hits before displaying the total. Once visible,
    # the label keeps its value, position lane and lifetime.
    var nearby := 0
    var count := 0
    for particle in particles:
        if particle.kind != "number" or not particle.has("damage_origin"): continue
        count += 1
        var distance_squared: float = Vector2(particle.damage_origin).distance_squared_to(at)
        if distance_squared > 76.0 * 76.0: continue
        nearby += 1
        if distance_squared <= 34.0 * 34.0 and particle.age < DAMAGE_NUMBER_MERGE_TIME and bool(particle.critical) == critical:
            particle.value += amount
            particle.text = format_amount(particle.value) + ("!" if critical else "")
            return
    if nearby >= 2 or count >= DAMAGE_NUMBER_LIMIT:
        return
    var text: String = format_amount(amount)
    if critical:
        text += "!"
        color = Color("#ffd653")
    _add_number(at, text, color, 25 if critical else 20, amount, critical)
    particles.back()["damage_origin"] = at

func floating_text(at: Vector2, text: String, color: Color, size: int = 20, value: float = 0.0, critical: bool = false) -> void:
    var count := 0
    for particle in particles:
        if particle.kind == "number" and not particle.has("damage_origin"):
            count += 1
            if count >= STATUS_NUMBER_LIMIT:
                return
    _add_number(at, text, color, size, value, critical)

func _add_number(at: Vector2, text: String, color: Color, size: int, value: float, critical: bool) -> void:
    number_serial += 1
    var offset := Vector2((number_serial % 5 - 2) * 10, -44 - (number_serial % 3) * 7)
    particles.append({"at": at + offset, "color": color, "size": size, "kind": "number", "age": 0.0, "life": NUMBER_LIFE, "text": text, "value": value, "critical": critical})
    if number_layer != null:
        number_layer.queue_redraw()

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
            burst(at, BattleVisuals.staff_tint(staff_tier), 28.0 + float(staff_tier) * 4.0, "rune_spark")
        "spear":
            add_particle({"at": at, "color": Color("#fff1c0"), "size": 66.0, "kind": "thrust", "age": 0.0, "life": 0.22, "direction": facing})
            add_particle({"at": at + facing * 18.0, "color": Color("#ffe7a0"), "size": 22.0, "kind": "fleck", "age": 0.0, "life": 0.14, "direction": facing})
            comic_word(at + Vector2(facing.x * 18.0, -20.0), "戳", Color("#fff7de"), 34, -6.0)
        "totem":
            shock_wrap(at, 30.0, Color("#eef6ff"))
            comic_word(at + Vector2(8, -20), "雷", Color("#f2f7ff"), 30, 12.0)
        _:
            add_particle({"at": at, "color": Color("#fff2c4"), "size": 38.0, "kind": "impact", "age": 0.0, "life": 0.18, "direction": facing})

    _impact_weapon=""
    _impact_tier=0

func swing_trail(start: Vector2, end: Vector2, center: Vector2, weapon_id: String, tier: int = 0, enchant: String = "", enchant_tier: int = 0) -> void:
    if particles.size() >= 75 or start.distance_squared_to(end) < 0.01:
        return
    var color: Color
    var accent: Color
    if enchant == "fire":
        color = BattleVisuals.fire_tint(enchant_tier)
        accent = Color("#ffe59e")
    elif enchant == "rune":
        color = BattleVisuals.staff_tint(enchant_tier)
        accent = BattleVisuals.staff_highlight(enchant_tier)
    elif enchant == "thunder":
        color = BattleVisuals.thunder_tint(enchant_tier)
        accent = Color("#fff7c2")
    elif tier <= 0:
        # Lv.1-2 unenchanted: subtle, desaturated wind/material trail matching the weapon itself.
        if weapon_id == "club":
            color = Color(0.76, 0.71, 0.64, 0.45)
            accent = Color(0.88, 0.84, 0.78, 0.55)
        elif weapon_id == "axe":
            color = Color(0.77, 0.78, 0.75, 0.48)
            accent = Color(0.92, 0.92, 0.89, 0.60)
        else:
            color = Color(0.87, 0.86, 0.81, 0.46)
            accent = Color(0.96, 0.96, 0.92, 0.65)
    elif tier == 1:
        # Lv.3-4 evolved: natural weapon material hue emerges.
        if weapon_id == "club":
            color = Color("#c98f4d")
            accent = Color("#f2d29b")
        elif weapon_id == "axe":
            color = Color("#b4bfb9")
            accent = Color("#eef2ec")
        else:
            color = Color("#b8e4e8")
            accent = Color("#f2fdff")
    else:
        # Lv.5 awakened: vivid signature weapon aura.
        if weapon_id == "club":
            color = Color("#e8ad52")
            accent = Color("#fff0be")
        elif weapon_id == "axe":
            color = Color("#dfe8e0")
            accent = Color("#ffffff")
        else:
            color = Color("#86effa")
            accent = Color("#e8ffff")
    var base_size: float = 26.0 if weapon_id == "axe" else (9.0 if weapon_id == "blade" else 20.0)
    if tier >= 1:
        base_size *= 1.0 + float(tier) * 0.12
    add_particle({"at": start, "end": end, "center": center, "rel_start": start - center, "rel_end": end - center, "follow_hero": true, "color": color, "accent": accent, "size": base_size, "kind": "swing_trail", "weapon_id": weapon_id, "tier": tier, "enchant": enchant, "age": 0.0, "life": 0.11 if weapon_id == "blade" else 0.13})

func weapon_motion(at: Vector2, direction: Vector2, weapon_id: String, tint_override: Color = Color.TRANSPARENT) -> void:
    if particles.size() >= 46:
        return
    var color: Color = tint_override if tint_override.a > 0.01 else (Color("#f4d28d") if weapon_id == "boomerang" else (Color("#fff4c4") if weapon_id == "spear" else Color("#d5b793")))
    add_particle({"at": at, "direction": direction, "weapon_id": weapon_id, "color": color, "size": 22.0 if weapon_id == "spear" else 18.0, "kind": "weapon_motion", "age": 0.0, "life": 0.14})

func flight_trail(start: Vector2, end: Vector2, magic: bool, key: String = "", vfx_tier: int = 0, fire_enchanted: bool = false, fire_tier: int = 0, thunder_enchanted: bool = false, thunder_tier: int = 0, thunder_red: bool = false) -> void:
    if particles.size() >= 46 or start.distance_squared_to(end) < 0.01:
        return
    var weapon_id: String = key if not key.is_empty() else ("staff" if magic else "powder")
    var axis: Vector2 = (end - start).normalized()
    var tail: Vector2 = end - axis * minf(start.distance_to(end), 62.0 if weapon_id in ["sling", "spear"] else 46.0)
    var color: Color = Color("#ffe7b0") if weapon_id == "sling" else (Color("#fff1c0") if weapon_id == "spear" else Color("#ffb558"))
    var any_enchant: bool = magic or fire_enchanted or thunder_enchanted
    if magic or weapon_id == "staff":
        color = BattleVisuals.staff_tint(vfx_tier)
    elif fire_enchanted:
        color = BattleVisuals.fire_tint(fire_tier)
    elif thunder_enchanted:
        color = Color("#ff3a2e") if thunder_red else BattleVisuals.thunder_tint(thunder_tier)
    var trail_life: float = 0.13 if weapon_id == "sling" else (0.16 if weapon_id == "spear" else 0.14)
    add_particle({"at": tail, "end": end, "weapon_id": weapon_id, "enchanted": any_enchant, "color": color, "size": 13.0 if weapon_id == "sling" else (14.0 if weapon_id == "spear" else 10.0), "kind": "flight", "age": 0.0, "life": trail_life, "vfx_tier": vfx_tier})


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
    var has_ground: bool = false
    var has_numbers: bool = false
    var has_particles: bool = false
    for index in range(particles.size()):
        var particle: Dictionary = particles[index]
        particle["age"] += delta
        if particle["age"] < particle["life"]:
            var pkind: String = str(particle.get("kind", ""))
            if pkind == "number":
                has_numbers = true
            else:
                has_particles = true
            if pkind == "quake" or pkind == "thunder_blast":
                has_ground = true
            if write != index:
                particles[write] = particle
            write += 1
    if write != particles.size():
        particles.resize(write)
    if has_particles or _had_particles or not charge_cues.is_empty():
        queue_redraw()
    _had_particles = has_particles
    if ground_layer != null and (has_ground or _had_ground_particles):
        ground_layer.queue_redraw()
    _had_ground_particles = has_ground
    if number_layer != null and (has_numbers or _had_numbers):
        number_layer.queue_redraw()
    _had_numbers = has_numbers

func expire_all() -> void:
    particles.clear()
    charge_cues.clear()
    queue_redraw()
    if ground_layer != null:
        ground_layer.queue_redraw()
    if number_layer != null:
        number_layer.queue_redraw()

func set_charge_cues(cues: Array) -> void:
    charge_cues = cues
    if not cues.is_empty():
        queue_redraw()

func _draw_charge_cues() -> void:
    if vfx_mode != "full" or charge_cues.is_empty():
        return
    var glow: Texture2D = soft_glow_texture()
    for cue in charge_cues:
        var p_start: Vector2 = cue["start"]
        var p_end: Vector2 = cue["end"]
        var col: Color = cue["color"]
        var charge_t: float = clampf(float(cue["t"]), 0.0, 1.0)
        var elem: int = int(cue.get("elem", 0))
        var shape: String = str(cue.get("shape", "muzzle"))
        var is_heavy: bool = bool(cue.get("heavy", false))
        var clock: float = float(cue.get("clock", 0.0))
        var core_col: Color = col.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.65)
        var sc: float = 1.25 if is_heavy else 0.82
        if shape == "hammer":
            # 石槌专属形态适配：围绕大锤头展现三系截然不同的举锤蓄势！
            var head_pt: Vector2 = p_end
            var alpha_h: float = clampf(charge_t * 1.35, 0.0, 1.0)
            if elem == 1:
                # 魔法大锤：2 道宽柔旋转奥术光弧环绕锤头收束 + 5 颗星尘螺旋汇入石槌（1-4级亮青 / 5级亮紫）
                var eased_h: float = 1.0 - pow(1.0 - charge_t, 1.7)
                var hr: float = lerpf(32.0, 18.0, eased_h)
                var rot_h: float = clock * 3.4 + charge_t * 2.4
                draw_texture_rect(glow, Rect2(head_pt - Vector2.ONE * (hr * 1.15), Vector2.ONE * (hr * 2.3)), false, Color(col.r, col.g, col.b, 0.44 * alpha_h))
                draw_arc(head_pt, hr, rot_h, rot_h + 2.0, 16, Color(col.r, col.g, col.b, 0.88 * alpha_h), 2.4, true)
                draw_arc(head_pt, hr * 0.82, -rot_h, -rot_h + 1.8, 16, Color(core_col.r, core_col.g, core_col.b, 0.86 * alpha_h), 1.6, true)
                for mi in range(5):
                    var ma: float = rot_h + float(mi) * TAU / 5.0 + (1.0 - eased_h) * 1.6
                    var md: float = lerpf(34.0, 5.0, eased_h)
                    var mp: Vector2 = head_pt + Vector2.from_angle(ma) * md
                    draw_circle(mp, lerpf(1.8, 3.2, charge_t), Color(core_col.r, core_col.g, core_col.b, 0.92 * alpha_h))
            elif elem == 2:
                # 火焰大锤：锤头炽热红金热浪膨胀 + 6 颗滚烫熔岩火星随举锤急速向上喷涌卷起
                var fr: float = lerpf(18.0, 30.0, charge_t)
                draw_texture_rect(glow, Rect2(head_pt - Vector2.ONE * fr, Vector2.ONE * (fr * 2.0)), false, Color(1.0, 0.38, 0.06, 0.52 * alpha_h))
                draw_texture_rect(glow, Rect2(head_pt - Vector2.ONE * (fr * 0.55), Vector2.ONE * (fr * 1.1)), false, Color(1.0, 0.86, 0.36, 0.58 * alpha_h))
                for fi in range(6):
                    var cyc: float = fmod(charge_t * 1.8 + float(fi) / 6.0, 1.0)
                    var sp: Vector2 = head_pt + Vector2(sin(clock * 11.0 + float(fi) * 2.2) * 14.0, 6.0 - cyc * 34.0)
                    var fa: float = sin(cyc * PI) * alpha_h
                    if fa > 0.04:
                        draw_circle(sp, lerpf(3.6, 1.1, cyc), Color(1.0, 0.42, 0.08, 0.94 * fa))
                        draw_circle(sp, lerpf(1.7, 0.5, cyc), Color(1.0, 0.95, 0.58, 0.98 * fa))
            elif elem == 3:
                # 雷电大锤：举锤引雷——电弧沿锤柄蹿上锤头并向上空伸出 2 道引雷电尖！
                var tick_h: int = int(floor(clock * 22.0))
                var trh := _draw_rng
                trh.seed = int(absf(head_pt.x * 19.0 + head_pt.y * 37.0)) + tick_h * 23
                var is_red_h: bool = col.r > 0.85 and col.g < 0.48
                var rim_h: Color = Color(0.58, 0.08, 0.08, 0.82 * alpha_h) if is_red_h else Color(0.28, 0.36, 0.48, 0.72 * alpha_h)
                var body_h: Color = Color(col.r, col.g, col.b, 0.96 * alpha_h)
                var core_h: Color = Color(1.0, 0.94, 0.88, alpha_h) if is_red_h else Color(1.0, 1.0, 0.99, alpha_h)
                # 2 arcs surging up handle into hammerhead
                for _bi in range(2):
                    var b0: Vector2 = p_start.lerp(head_pt, trh.randf_range(0.0, 0.4)) + Vector2(trh.randf_range(-7.0, 7.0), trh.randf_range(-5.0, 5.0))
                    var b1: Vector2 = b0.lerp(head_pt, 0.5) + Vector2(trh.randf_range(-9.0, 9.0), trh.randf_range(-8.0, 8.0))
                    var pts_h := PackedVector2Array([b0, b1, head_pt])
                    draw_polyline(pts_h, rim_h, 3.4, true)
                    draw_polyline(pts_h, body_h, 2.0, true)
                    draw_polyline(pts_h, core_h, 1.0, true)
                # 2 sky-calling lightning spires reaching upward from the raised hammerhead!
                for si in range(2):
                    var reach_up: float = lerpf(16.0, 44.0, charge_t)
                    var sky_tip: Vector2 = head_pt + Vector2((1.0 if si == 0 else -1.0) * trh.randf_range(6.0, 16.0), -reach_up)
                    var sm1: Vector2 = head_pt.lerp(sky_tip, 0.45) + Vector2(trh.randf_range(-7.0, 7.0), 0.0)
                    var sm2: Vector2 = head_pt.lerp(sky_tip, 0.78) + Vector2(trh.randf_range(-6.0, 6.0), 0.0)
                    var spts := PackedVector2Array([head_pt, sm1, sm2, sky_tip])
                    draw_polyline(spts, rim_h, 3.6, true)
                    draw_polyline(spts, body_h, 2.2, true)
                    draw_polyline(spts, core_h, 1.1, true)
            continue
        if elem == 1:
            # 魔法专属动态反馈：旋转奥术细环由大收缩聚焦至发射端 + 4 颗星尘沿螺旋轨迹旋入聚能！
            var eased: float = 1.0 - pow(1.0 - charge_t, 1.8)
            var ring_r: float = lerpf(24.0 * sc, 5.5 * sc, eased)
            var rot: float = clock * 3.8 + charge_t * 2.6
            var alpha_m: float = clampf(charge_t * 1.4, 0.0, 1.0)
            draw_texture_rect(glow, Rect2(p_end - Vector2.ONE * (ring_r * 1.4), Vector2.ONE * (ring_r * 2.8)), false, Color(col.r, col.g, col.b, 0.36 * alpha_m))
            # Two opposing delicate rotating arcane arcs shrinking inward (NOT a solid blocky ring!)
            draw_arc(p_end, ring_r, rot, rot + 1.9, 16, Color(col.r, col.g, col.b, 0.85 * alpha_m), 1.8, true)
            draw_arc(p_end, ring_r, rot + PI, rot + PI + 1.9, 16, Color(core_col.r, core_col.g, core_col.b, 0.85 * alpha_m), 1.4, true)
            for mi in range(4):
                var sa: float = rot + float(mi) * PI * 0.5 + (1.0 - eased) * 1.4
                var sd: float = lerpf(28.0 * sc, 3.0, eased)
                var mp: Vector2 = p_end + Vector2.from_angle(sa) * sd
                draw_circle(mp, lerpf(1.6, 2.8 * sc, charge_t), Color(core_col.r, core_col.g, core_col.b, 0.90 * alpha_m))
            if charge_t > 0.65:
                var pop: float = (charge_t - 0.65) / 0.35
                draw_circle(p_end, 4.5 * sc * pop, Color(core_col.r, core_col.g, core_col.b, 0.92 * pop))
        elif elem == 2:
            # 火焰专属动态反馈：熔炉鼓风蓄压——炽热红金热浪膨胀 + 滚烫火星从炮身/尖端急速向上喷涌！
            var heat_r: float = (18.0 * sc) * (0.75 + 0.45 * charge_t)
            var mid_pt: Vector2 = p_start.lerp(p_end, 0.65)
            draw_texture_rect(glow, Rect2(mid_pt - Vector2.ONE * heat_r, Vector2.ONE * (heat_r * 2.0)), false, Color(1.0, 0.42, 0.08, 0.46 * charge_t))
            var count_f: int = 5 if is_heavy else 3
            for fi in range(count_f):
                var cyc: float = fmod(charge_t * 1.6 + float(fi) / float(count_f), 1.0)
                var base_f: Vector2 = p_start.lerp(p_end, 0.35 + 0.60 * float(fi) / float(count_f))
                var curl_x: float = sin(clock * 12.0 + float(fi) * 2.5) * (6.0 * sc)
                var sp: Vector2 = base_f + Vector2(curl_x, -cyc * (24.0 * sc))
                var fa: float = sin(cyc * PI) * charge_t
                if fa > 0.04:
                    draw_circle(sp, lerpf(3.2, 1.1, cyc) * sc, Color(1.0, 0.45, 0.10, 0.92 * fa))
                    draw_circle(sp, lerpf(1.6, 0.5, cyc) * sc, Color(1.0, 0.94, 0.55, 0.96 * fa))
        elif elem == 3:
            # 雷电专属动态反馈：高压线圈拉满——2-3 道折线电弧从机身跃出并收束击向炮口/锤头 + 尖端锐利电闪！
            var tick: int = int(floor(clock * (18.0 + 14.0 * charge_t)))
            var tr := _draw_rng
            tr.seed = int(absf(p_end.x * 17.0 + p_end.y * 31.0)) + tick * 29
            var is_red_t: bool = col.r > 0.85 and col.g < 0.48
            var rim_c: Color = Color(0.58, 0.08, 0.08, 0.82 * charge_t) if is_red_t else Color(0.28, 0.36, 0.48, 0.72 * charge_t)
            var body_c: Color = Color(col.r, col.g, col.b, 0.95 * charge_t)
            var core_c: Color = Color(1.0, 0.94, 0.88, charge_t) if is_red_t else Color(1.0, 1.0, 0.99, charge_t)
            var bolts: int = 3 if is_heavy else 2
            var axis: Vector2 = (p_end - p_start).normalized() if p_end.distance_squared_to(p_start) > 1.0 else Vector2.RIGHT
            var side: Vector2 = axis.orthogonal()
            for bi in range(bolts):
                var s_off: float = (1.0 if bi % 2 == 0 else -1.0) * (10.0 * sc) * (1.2 - 0.5 * charge_t)
                var b0: Vector2 = p_start.lerp(p_end, tr.randf_range(0.05, 0.45)) + side * s_off
                var b1: Vector2 = b0.lerp(p_end, 0.45) + side * (s_off * tr.randf_range(0.4, 1.25)) + axis * tr.randf_range(-4.0, 4.0)
                var b2: Vector2 = b0.lerp(p_end, 0.78) + side * tr.randf_range(-4.5, 4.5)
                var pts := PackedVector2Array([b0, b1, b2, p_end])
                draw_polyline(pts, rim_c, 3.6, true)
                draw_polyline(pts, body_c, 2.2, true)
                draw_polyline(pts, core_c, 1.0, true)
            if charge_t > 0.55:
                var snap_f: float = (charge_t - 0.55) / 0.45
                var sl: float = (9.5 * sc) * snap_f
                draw_line(p_end - Vector2(sl, 0.0), p_end + Vector2(sl, 0.0), core_c, 2.0, true)
                draw_line(p_end - Vector2(0.0, sl), p_end + Vector2(0.0, sl), core_c, 2.0, true)

func _draw_numbers(canvas) -> void:
    for particle in particles:
        if particle.kind != "number":
            continue
        var delay: float = DAMAGE_NUMBER_MERGE_TIME if particle.has("damage_origin") else 0.0
        if particle.age < delay:
            continue
        var progress: float = (particle.age - delay) / (particle.life - delay)
        var point: Vector2 = particle.at + Vector2(0.0, -42.0 * progress)
        if _has_hero_anchor and (absf(point.x - hero_anchor.x) > 780.0 or absf(point.y - hero_anchor.y) > 540.0):
            continue
        var text: String = particle.text
        var size: int = particle.size
        point.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
        var color: Color = particle.color
        color.a *= 1.0 - smoothstep(0.62, 1.0, progress)
        canvas.draw_string_outline(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0.16, 0.1, 0.08, color.a))
        canvas.draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
    _draw_charge_cues()
    for particle in particles:
        if particle.kind == "number":
            continue
        var progress: float = particle["age"] / particle["life"]
        var color: Color = particle["color"]
        if particle["kind"] == "word":
            color.a *= clampf((1.0 - progress) / 0.22, 0.0, 1.0)
        else:
            color.a *= 0.90 * (1.0 - progress * 0.96)
        var point: Vector2 = particle["at"]
        if particle.has("drift"):
            point += particle["drift"] * progress
        var kind_id: String = str(particle.get("kind", ""))
        if _has_hero_anchor and kind_id not in ["sky_bolt", "arc_lightning", "beam"]:
            if absf(point.x - hero_anchor.x) > 780.0 or absf(point.y - hero_anchor.y) > 540.0:
                continue
        var size: float = particle["size"]
        var family: String=CombatArt.particle_family(particle)
        if not family.is_empty() and str(particle.get("kind", "")) not in ["quake", "rune_blast", "rune_spark", "fire_blast", "fire_splash", "thunder_blast"] and not (str(particle.get("kind", "")) == "cleave" and bool(particle.get("enchanted", false))):
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
                draw_arc(particle["end"], size * (0.7 + progress), progress * 2.0, TAU + progress * 2.0, 24, Color(color.r, color.g, color.b, color.a), 2.0, true)
            "smoke":
                draw_dust_puff(self, point, size * (0.55 + progress * 0.50), clampf((1.0 - progress) * 1.1, 0.0, 0.90), float(particle.get("seed", 0)))
            "word":
                _draw_word(point, particle["text"], int(size), color, float(particle.get("tilt", -12.0)), progress)
            "swing_trail":
                var center: Vector2 = hero_anchor if (bool(particle.get("follow_hero", false)) and _has_hero_anchor) else particle["center"]
                var start: Vector2 = particle.get("rel_start", point - particle["center"])
                var end: Vector2 = particle.get("rel_end", particle["end"] - particle["center"])
                var turn: float = start.angle_to(end)
                var w_id: String = str(particle.get("weapon_id", "club"))
                var tier: int = int(particle.get("tier", 0))
                var enchant: String = str(particle.get("enchant", ""))
                var accent: Color = particle.get("accent", Color(1.0, 1.0, 0.95, color.a))
                var fade: float = 1.0 - progress * 0.72
                var segs: int = 8 if w_id == "blade" else 7
                if w_id == "club":
                    # Blunt heavy wind-pressure arc with rounded head & transverse shock bars.
                    for index in range(segs):
                        var t0: float = float(index) / float(segs)
                        var t1: float = float(index + 1) / float(segs)
                        var dir0: Vector2 = Vector2.from_angle(start.angle() + turn * t0)
                        var dir1: Vector2 = Vector2.from_angle(start.angle() + turn * t1)
                        var r0: float = lerpf(start.length(), end.length(), t0)
                        var r1: float = lerpf(start.length(), end.length(), t1)
                        var bell0: float = sin(t0 * PI * 0.72 + 0.28)
                        var bell1: float = sin(t1 * PI * 0.72 + 0.28)
                        var half0: float = size * 0.55 * bell0 * fade
                        var half1: float = size * 0.55 * bell1 * fade
                        var strip := PackedVector2Array([center + dir0 * (r0 - half0), center + dir0 * (r0 + half0 * 0.65), center + dir1 * (r1 + half1 * 0.65), center + dir1 * (r1 - half1)])
                        draw_colored_polygon(strip, Color(color.r, color.g, color.b, color.a * (0.24 + t1 * 0.48)))
                        if index % 2 == 1:
                            draw_line(center + dir1 * (r1 - half1 * 0.75), center + dir1 * (r1 + half1 * 0.55), Color(accent.r, accent.g, accent.b, color.a * t1 * 0.75), 2.2, true)
                    var head_r: float = size * 0.34 * fade
                    draw_circle(center + end, head_r, Color(accent.r, accent.g, accent.b, color.a * 0.55))
                elif w_id == "axe":
                    # Smooth broad heavy-axe sweeping arc (follows weapon cleanly, NOT a triangular scythe!).
                    for index in range(segs):
                        var t0: float = float(index) / float(segs)
                        var t1: float = float(index + 1) / float(segs)
                        var dir0: Vector2 = Vector2.from_angle(start.angle() + turn * t0)
                        var dir1: Vector2 = Vector2.from_angle(start.angle() + turn * t1)
                        var r0: float = lerpf(start.length(), end.length(), t0)
                        var r1: float = lerpf(start.length(), end.length(), t1)
                        var w0: float = size * (0.28 + sin(t0 * PI * 0.85) * 0.58) * fade
                        var w1: float = size * (0.28 + sin(t1 * PI * 0.85) * 0.58) * fade
                        var outer0: Vector2 = center + dir0 * (r0 + 5.0)
                        var outer1: Vector2 = center + dir1 * (r1 + 5.0)
                        var inner0: Vector2 = center + dir0 * (r0 - w0)
                        var inner1: Vector2 = center + dir1 * (r1 - w1)
                        draw_colored_polygon(PackedVector2Array([inner0, outer0, outer1, inner1]), Color(color.r, color.g, color.b, color.a * (0.22 + t1 * 0.58)))
                        draw_line(outer0, outer1, Color(accent.r, accent.g, accent.b, color.a * (0.45 + t1 * 0.55)), 3.2 if tier >= 1 or not enchant.is_empty() else 2.2, true)
                        draw_line(inner0, inner1, Color(color.r * 0.75, color.g * 0.70, color.b * 0.66, color.a * t1 * 0.45), 1.5, true)
                else:
                    # Blade: razor-thin, fast dual-streak pointed slash.
                    var outer_pts := PackedVector2Array()
                    var inner_pts := PackedVector2Array()
                    for index in range(segs + 1):
                        var t: float = float(index) / float(segs)
                        var dir: Vector2 = Vector2.from_angle(start.angle() + turn * t)
                        var r: float = lerpf(start.length(), end.length(), t)
                        var pinch: float = sin(t * PI)
                        outer_pts.append(center + dir * (r + 3.0 + pinch * 3.5))
                        inner_pts.append(center + dir * (r - size * (0.35 + pinch * 0.75) * fade))
                    for index in range(segs):
                        var t1: float = float(index + 1) / float(segs)
                        draw_colored_polygon(PackedVector2Array([inner_pts[index], outer_pts[index], outer_pts[index + 1], inner_pts[index + 1]]), Color(color.r, color.g, color.b, color.a * (0.22 + t1 * 0.58)))
                    draw_polyline(outer_pts, Color(accent.r, accent.g, accent.b, color.a * 0.92), 2.0 if tier >= 1 or not enchant.is_empty() else 1.5, true)
                    if tier >= 1 or not enchant.is_empty():
                        draw_polyline(inner_pts, Color(color.r, color.g, color.b, color.a * 0.62), 1.2, true)
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
            "sky_bolt":
                _draw_sky_bolt(particle, progress)
            "shock_wrap":
                _draw_shock_wrap(point, size, progress, int(particle.get("seed", 1)), bool(particle.get("red", false)))
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
            "blast", "cannon":
                _draw_explosion(point, size, color, progress, false)
            "rune_blast":
                _draw_rune_blast(point, size, color, progress)
            "rune_spark":
                _draw_rune_spark(point, size, color, progress)
            "fire_blast":
                _draw_fire_blast(point, size, color, progress)
            "fire_splash":
                _draw_fire_splash(point, size, color, progress)
            "thunder_blast":
                if ground_layer == null:
                    _draw_thunder_blast(self, point, size, color, progress)
            "quake":
                if ground_layer == null:
                    _draw_quake(self, particle, point, size, color, progress)
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
                # Procedural jagged lightning bolt that strictly respects particle["color"] (silver-white or crimson Red Lightning — NEVER hardcoded blue SVG!).
                var end_pt: Vector2 = Vector2(particle["end"])
                var chord: Vector2 = end_pt - point
                var dist: float = chord.length()
                if dist > 1.0:
                    var axis: Vector2 = chord / dist
                    var side: Vector2 = axis.orthogonal()
                    var steps: int = clampi(int(ceil(dist / 26.0)), 4, 12)
                    var is_red_beam: bool = color.r > 0.85 and color.g < 0.48
                    var rim_c: Color = Color(0.58, 0.10, 0.08, color.a * 0.85) if is_red_beam else Color(0.28, 0.36, 0.48, color.a * 0.78)
                    var body_c: Color = Color(color.r, color.g, color.b, color.a * 0.96)
                    var core_c: Color = Color(1.0, 0.94, 0.88, color.a) if is_red_beam else Color(1.0, 1.0, 0.99, color.a)
                    var bpts := PackedVector2Array([point])
                    var bseed: int = int(absf(point.x * 13.0 + end_pt.y * 29.0)) + int(floor(progress * 10.0)) * 7
                    for bi in range(1, steps):
                        var t: float = float(bi) / float(steps)
                        var env: float = sin(t * PI)
                        var sgn: float = -1.0 if ((bi + bseed) % 2 == 0) else 1.0
                        var jag: float = minf(13.0, dist * 0.09) * (0.45 + 0.55 * absf(sin(float(bseed + bi * 17)))) * env
                        bpts.append(point.lerp(end_pt, t) + side * sgn * jag)
                    bpts.append(end_pt)
                    var fade_b: float = clampf(1.0 - progress * 0.55, 0.2, 1.0)
                    _stroke_bolt(bpts, rim_c, 6.2 * fade_b, 1.8 * fade_b)
                    _stroke_bolt(bpts, body_c, 3.6 * fade_b, 1.0 * fade_b)
                    _stroke_bolt(bpts, core_c, 1.7 * fade_b, 0.5 * fade_b)
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
            var streak_col: Color = color.lerp(Color(1.0, 1.0, 1.0, color.a), 0.35) if bool(particle.get("enchanted", false)) else white
            canvas.draw_polyline(band, outline, 4.0, true)
            canvas.draw_polyline(band, color, 2.2, true)
            for sign in [-1.0, 1.0]:
                var start: Vector2 = point + axis * 10 + side * sign * 4
                var end: Vector2 = start + axis * 7 + side * sign * 2
                canvas.draw_line(start, end, outline, 3.1, true)
                canvas.draw_line(start, end, streak_col, 1.5, true)
        "powder":
            var shrink: float = 1.0 - progress * 0.45
            var flash := _oriented_points(point, axis, [Vector2(-1, 0), Vector2(7, -8) * shrink, Vector2(11, -3) * shrink, Vector2(26, -4) * shrink, Vector2(18, 1) * shrink, Vector2(23, 7) * shrink, Vector2(10, 4) * shrink, Vector2(6, 9) * shrink])
            canvas.draw_colored_polygon(flash, color)
            var border: PackedVector2Array = flash.duplicate()
            border.append(flash[0])
            canvas.draw_polyline(border, outline, 2.6, true)
            canvas.draw_colored_polygon(_oriented_points(point, axis, [Vector2(0, 0), Vector2(13, -3) * shrink, Vector2(19, 0) * shrink, Vector2(10, 4) * shrink]), color.lerp(Color(1.0, 1.0, 1.0, color.a), 0.55) if bool(particle.get("enchanted", false)) else white)
            if particle.get("enchanted", false):
                canvas.draw_arc(point + axis * 5, 10.0 * shrink, axis.angle() - 1.4, axis.angle() + 1.4, 12, outline, 3.6, true)
                canvas.draw_arc(point + axis * 5, 10.0 * shrink, axis.angle() - 1.4, axis.angle() + 1.4, 12, color.lerp(Color(1.0, 1.0, 1.0, color.a), 0.45), 2.0, true)
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
            var is_ench_sling: bool = bool(particle.get("enchanted", false))
            var tip_col: Color = color.lerp(Color(1.0, 1.0, 1.0, color.a), 0.45) if is_ench_sling else Color(1.0, 0.97, 0.82, color.a)
            canvas.draw_line(start, end, outline, (6.0 if is_ench_sling else 5.2) * (1.0 - progress) + 0.9, true)
            canvas.draw_line(start, end, Color(color.r, color.g, color.b, color.a * 0.95), 3.0 if is_ench_sling else 2.3, true)
            canvas.draw_circle(end, (4.0 if is_ench_sling else 3.2) * (1.0 - progress), tip_col)
            canvas.draw_circle(start - side * 2, 2.6 * (1.0 - progress), Color(color.r, color.g, color.b, color.a * 0.78))
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

func _draw_sky_bolt(particle: Dictionary, progress: float) -> void:
    # Dramatic comic sky-to-ground lightning bolt (supports crimson Red Lightning for high-level totem / thunder enchants!)
    var fade: float = clampf(1.0 - pow(progress, 1.3), 0.0, 1.0)
    var sc: float = float(particle.get("scale", 1.0))
    var is_red: bool = bool(particle.get("red", false))
    var pts: PackedVector2Array = particle["points"]
    var end_pt: Vector2 = particle["end"]
    var glow: Texture2D = soft_glow_texture()
    var flash_r: float = 48.0 * sc * (0.72 + progress * 0.38)
    var aura_col: Color = Color(1.0, 0.22, 0.16, 0.42 * fade) if is_red else Color(0.84, 0.92, 1.0, 0.40 * fade)
    var rim_col: Color = Color(0.56, 0.08, 0.08, 0.90 * fade) if is_red else Color(0.28, 0.36, 0.48, 0.86 * fade)
    var body_col: Color = Color(1.0, 0.34, 0.22, 0.98 * fade) if is_red else Color(0.90, 0.96, 1.0, 0.98 * fade)
    var core_col: Color = Color(1.0, 0.94, 0.88, 0.99 * fade) if is_red else Color(1.0, 1.0, 0.98, 1.0 * fade)
    draw_texture_rect(glow, Rect2(end_pt - Vector2(flash_r, flash_r * 0.76), Vector2(flash_r * 2.0, flash_r * 1.52)), false, Color(aura_col.r, aura_col.g, aura_col.b, 0.56 * fade))
    draw_texture_rect(glow, Rect2(end_pt - Vector2.ONE * (flash_r * 0.42), Vector2.ONE * (flash_r * 0.84)), false, Color(core_col.r, core_col.g, core_col.b, 0.72 * fade))
    _stroke_bolt(pts, aura_col, 24.0 * sc * fade, 7.0 * sc * fade)
    _stroke_bolt(pts, rim_col, 10.5 * sc * fade, 3.0 * sc * fade)
    _stroke_bolt(pts, body_col, 6.8 * sc * fade, 1.8 * sc * fade)
    _stroke_bolt(pts, core_col, 3.2 * sc * fade, 0.9 * sc * fade)
    for br in particle["branches"]:
        _stroke_bolt(br, Color(aura_col.r, aura_col.g, aura_col.b, 0.26 * fade), 9.0 * sc * fade, 1.2 * sc * fade)
        _stroke_bolt(br, Color(rim_col.r, rim_col.g, rim_col.b, 0.80 * fade), 4.0 * sc * fade, 0.6 * sc * fade)
        _stroke_bolt(br, Color(body_col.r, body_col.g, body_col.b, 0.94 * fade), 2.4 * sc * fade, 0.4 * sc * fade)
        _stroke_bolt(br, Color(core_col.r, core_col.g, core_col.b, 0.96 * fade), 1.1 * sc * fade, 0.25 * sc * fade)

func _draw_shock_wrap(point: Vector2, radius: float, progress: float, seed_int: int, is_red: bool = false) -> void:
    # Compact, wispy micro-lightning strands tightly hugging the monster's body (lightweight draw budget).
    var fade: float = clampf(1.0 - pow(progress, 1.35), 0.0, 1.0)
    var r_wrap: float = radius * 0.78
    var step_tick: int = int(floor(progress * 11.0))
    var r := _draw_rng
    r.seed = seed_int * 37 + step_tick * 23
    var glow: Texture2D = soft_glow_texture()
    var outer_col: Color = Color(1.0, 0.26, 0.18, 0.76 * fade) if is_red else Color(0.74, 0.86, 0.98, 0.76 * fade)
    var inner_col: Color = Color(1.0, 0.92, 0.86, 0.95 * fade) if is_red else Color(1.0, 1.0, 0.98, 0.96 * fade)
    draw_texture_rect(glow, Rect2(point - Vector2.ONE * (r_wrap * 0.88), Vector2.ONE * (r_wrap * 1.76)), false, Color(outer_col.r, outer_col.g, outer_col.b, 0.20 * fade))
    for _i in range(3):
        var a0: float = r.randf_range(0.0, TAU)
        var span: float = r.randf_range(0.55, 1.25) * (1.0 if r.randf() < 0.5 else -1.0)
        var rr0: float = r_wrap * r.randf_range(0.45, 0.92)
        var pts := PackedVector2Array()
        var segs: int = 3
        for s in range(segs + 1):
            var t: float = float(s) / float(segs)
            var ang: float = a0 + span * t
            var rad: float = rr0 * r.randf_range(0.88, 1.12)
            var jitter := Vector2(r.randf_range(-3.0, 3.0), r.randf_range(-3.0, 3.0))
            pts.append(point + Vector2(cos(ang) * rad, sin(ang) * rad * 0.80) + jitter)
        draw_polyline(pts, outer_col, 1.8, true)
        draw_polyline(pts, inner_col, 0.9, true)
    for _s in range(2):
        var sa: float = r.randf_range(0.0, TAU)
        var sd: float = r_wrap * r.randf_range(0.45, 1.02)
        var sp: Vector2 = point + Vector2(cos(sa) * sd, sin(sa) * sd * 0.80)
        draw_circle(sp, r.randf_range(0.8, 1.5) * fade, inner_col)

func _draw_arc_lightning(canvas, particle: Dictionary, color: Color, progress: float) -> void:
    var paths: Array = [particle["points"]]
    paths.append_array(particle["branches"])
    var fade: float = 1.0 - progress * 0.55
    var is_red_arc: bool = color.r > 0.85 and color.g < 0.48
    var core_col: Color = Color(1.0, 0.92, 0.86, color.a) if is_red_arc else Color(1.0, 1.0, 0.99, color.a)
    var flake_col: Color = Color(1.0, 0.72, 0.62, color.a * 0.62) if is_red_arc else Color(0.92, 0.96, 1.0, color.a * 0.58)
    for index in range(paths.size()):
        var branch: bool = index > 0
        var opacity: float = 0.85 if branch else 1.0
        canvas.draw_polyline(paths[index], Color(ink.r, ink.g, ink.b, color.a * opacity), (4.1 if branch else 6.5) * fade, true)
        canvas.draw_polyline(paths[index], Color(color.r, color.g, color.b, color.a * opacity), (2.4 if branch else 3.7) * fade, true)
        canvas.draw_polyline(paths[index], Color(core_col.r, core_col.g, core_col.b, color.a * opacity), (1.0 if branch else 1.7) * fade, true)
    canvas.draw_circle(particle["end"], 2.6 * fade, core_col)
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
            canvas.draw_line(mid - side * tick * 0.35, mid + side * tick * 0.2, Color(core_col.r, core_col.g, core_col.b, color.a * 0.8), 1.0, true)
        else:
            var flake: PackedVector2Array = PackedVector2Array([
                mid + tangent * 3.2,
                mid + side * 2.4,
                mid - tangent * 2.0,
                mid - side * 1.6
            ])
            canvas.draw_colored_polygon(flake, flake_col)

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

func _draw_tapered_star(point: Vector2, outer_r: float, inner_r: float, color: Color, canvas: CanvasItem = self) -> void:
    var pts := PackedVector2Array()
    for i in range(8):
        var a: float = float(i) * PI * 0.25
        var r: float = outer_r if i % 2 == 0 else inner_r
        pts.append(point + Vector2.from_angle(a) * r)
    canvas.draw_colored_polygon(pts, color)

func _draw_rune_blast(point: Vector2, size: float, color: Color, progress: float) -> void:
    # Organic parchment-watercolor arcane burst for heavy magic weapons (cannon, hammer) — no rigid circles or symmetric spokes.
    var ease_out: float = 1.0 - pow(1.0 - progress, 2.2)
    var fade: float = clampf(1.0 - progress * 0.92, 0.0, 1.0)
    var light: Color = color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.58)
    var deep: Color = color.darkened(0.16)
    var glow_tex: Texture2D = soft_glow_texture()
    var r := _draw_rng
    r.seed = int(absf(point.x * 37.0 + point.y * 91.0)) + 13
    # 1. Organic layered watercolor magic bloom (main aura + 2 soft off-center drifting clouds)
    var glow_r: float = size * (0.74 + ease_out * 0.44)
    draw_texture_rect(glow_tex, Rect2(point - Vector2(glow_r, glow_r), Vector2(glow_r * 2.0, glow_r * 2.0)), false, Color(deep.r, deep.g, deep.b, fade * 0.50))
    for lobe in range(2):
        var la: float = r.randf_range(0.0, TAU)
        var ld: float = size * (0.14 + ease_out * 0.24)
        var lr: float = size * (0.44 + ease_out * 0.28) * r.randf_range(0.82, 1.15)
        var lp: Vector2 = point + Vector2.from_angle(la) * ld
        draw_texture_rect(glow_tex, Rect2(lp - Vector2(lr, lr), Vector2(lr * 2.0, lr * 2.0)), false, Color(color.r, color.g, color.b, fade * 0.36))
    var core_r: float = size * (0.40 + ease_out * 0.20)
    draw_texture_rect(glow_tex, Rect2(point - Vector2(core_r, core_r), Vector2(core_r * 2.0, core_r * 2.0)), false, Color(light.r, light.g, light.b, fade * 0.62))
    # 2. Opening bright center arcane star-flash
    var pulse_fade: float = clampf(1.0 - progress * 1.85, 0.0, 1.0)
    if pulse_fade > 0.01:
        var star_r: float = size * 0.40 * (0.70 + pulse_fade * 0.38)
        _draw_tapered_star(point, star_r, star_r * 0.22, Color(light.r, light.g, light.b, pulse_fade * 0.74))
        _draw_tapered_star(point, star_r * 0.66, star_r * 0.14, Color(1.0, 1.0, 1.0, pulse_fade * 0.96))
    # 3. Irregular, natural scatter of glowing arcane diamonds & fine drifting dust motes (non-symmetric!)
    for _i in range(7):
        var ang: float = r.randf_range(0.0, TAU)
        var speed_m: float = r.randf_range(0.35, 0.96)
        var dist: float = size * (0.12 + ease_out * speed_m)
        var lift: float = -ease_out * r.randf_range(4.0, 16.0)
        var mote: Vector2 = point + Vector2.from_angle(ang) * dist + Vector2(0.0, lift)
        var mr: float = r.randf_range(2.6, 5.6) * (1.0 - progress * 0.52)
        var col_m: Color = Color(light.r, light.g, light.b, fade * r.randf_range(0.72, 0.96))
        draw_colored_polygon(PackedVector2Array([
            mote + Vector2(0.0, -mr), mote + Vector2(mr * 0.62, 0.0),
            mote + Vector2(0.0, mr), mote + Vector2(-mr * 0.62, 0.0)
        ]), col_m)
    for _d in range(6):
        var dang: float = r.randf_range(0.0, TAU)
        var ddist: float = size * (0.18 + ease_out * r.randf_range(0.42, 0.92))
        var dp: Vector2 = point + Vector2.from_angle(dang) * ddist + Vector2(0.0, -ease_out * r.randf_range(6.0, 20.0))
        draw_circle(dp, r.randf_range(1.2, 2.6) * (1.0 - progress * 0.55), Color(1.0, 1.0, 1.0, fade * r.randf_range(0.55, 0.88)))

func _draw_rune_spark(point: Vector2, size: float, color: Color, progress: float) -> void:
    # Compact, crisp magic hit pop on monsters (trimmed size & draw calls for high FPS).
    var ease_out: float = 1.0 - pow(1.0 - progress, 2.0)
    var fade: float = clampf(1.0 - progress * 0.92, 0.0, 1.0)
    var light: Color = color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.55)
    var glow_tex: Texture2D = soft_glow_texture()
    var glow_r: float = maxf(13.0, size * (0.48 + ease_out * 0.24))
    draw_texture_rect(glow_tex, Rect2(point - Vector2(glow_r, glow_r), Vector2(glow_r * 2.0, glow_r * 2.0)), false, Color(color.r, color.g, color.b, fade * 0.62))
    var flash: float = clampf(1.0 - progress * 1.5, 0.0, 1.0)
    if flash > 0.01:
        var sr: float = maxf(9.5, size * 0.32) * (0.72 + flash * 0.34)
        _draw_tapered_star(point, sr, sr * 0.26, Color(color.r, color.g, color.b, flash * 0.86))
        _draw_tapered_star(point, sr * 0.65, sr * 0.15, Color(1.0, 1.0, 1.0, flash * 0.96))
    for index in range(3):
        var angle: float = float(index) * TAU / 3.0 + 0.52
        var dir: Vector2 = Vector2.from_angle(angle)
        var side: Vector2 = dir.orthogonal()
        var d0: float = size * (0.10 + ease_out * 0.18)
        var d1: float = size * (0.28 + ease_out * 0.36)
        var w: float = maxf(1.5, 3.0 * (1.0 - progress * 0.65))
        var p_base: Vector2 = point + dir * d0
        var p_mid: Vector2 = point + dir * lerpf(d0, d1, 0.38)
        var p_tip: Vector2 = point + dir * d1
        draw_colored_polygon(PackedVector2Array([p_base, p_mid + side * w, p_tip, p_mid - side * w]), Color(light.r, light.g, light.b, fade * 0.88))

func _draw_lava_drop(pos: Vector2, vel_dir: Vector2, radius: float, color: Color, alpha: float) -> void:
    # Stretched liquid magma glob with dark crust rim, molten orange/emerald body, and bright hot core!
    var is_green: bool = color.g > color.r * 1.25 and color.g > 0.65
    var axis: Vector2 = vel_dir.normalized() if vel_dir.length_squared() > 0.01 else Vector2.DOWN
    var side: Vector2 = axis.orthogonal()
    var tail: Vector2 = pos - axis * (radius * 2.15)
    var nose: Vector2 = pos + axis * (radius * 1.15)
    var rim := Color(0.06, 0.34, 0.16, alpha * 0.92) if is_green else Color(0.42, 0.10, 0.03, alpha * 0.92)
    var body := Color(color.r * 0.85, color.g, color.b * 0.85, alpha * 0.96) if is_green else Color(color.r, color.g * 0.78, color.b * 0.35, alpha * 0.96)
    var core := Color(0.84, 1.0, 0.68, alpha * 0.94) if is_green else Color(1.0, 0.88, 0.36, alpha * 0.94)
    draw_colored_polygon(PackedVector2Array([tail, pos + side * (radius * 1.05), nose, pos - side * (radius * 1.05)]), rim)
    draw_circle(pos, radius * 1.05, rim)
    draw_colored_polygon(PackedVector2Array([pos - axis * (radius * 1.45), pos + side * (radius * 0.78), pos + axis * (radius * 0.85), pos - side * (radius * 0.78)]), body)
    draw_circle(pos, radius * 0.82, body)
    draw_circle(pos + axis * (radius * 0.18), radius * 0.42, core)

func _draw_fire_blast(point: Vector2, size: float, color: Color, progress: float) -> void:
    # Heavy molten lava / awakened emerald-flame splatter — irregular globs arcing outward & splashing down!
    var is_green: bool = color.g > color.r * 1.25 and color.g > 0.65
    var ease_out: float = 1.0 - pow(1.0 - progress, 2.0)
    var fade: float = clampf(1.0 - pow(progress, 1.8), 0.0, 1.0)
    var glow_tex: Texture2D = soft_glow_texture()
    var r := _draw_rng
    r.seed = int(absf(point.x * 43.0 + point.y * 89.0)) + 29
    # 1. Warm impact heat flash at center (quick punch, no symmetric flower!)
    var flash_a: float = clampf(1.0 - progress * 1.9, 0.0, 1.0)
    var glow_r: float = size * (0.68 + ease_out * 0.34)
    var wash_col := Color(0.16, 0.82, 0.44, fade * 0.52) if is_green else Color(color.r, color.g * 0.52, color.b * 0.22, fade * 0.52)
    draw_texture_rect(glow_tex, Rect2(point - Vector2(glow_r, glow_r * 0.76), Vector2(glow_r * 2.0, glow_r * 1.52)), false, wash_col)
    if flash_a > 0.01:
        var core_r: float = size * (0.34 + ease_out * 0.16)
        var core_col := Color(0.84, 1.0, 0.68, flash_a * 0.78) if is_green else Color(1.0, 0.86, 0.38, flash_a * 0.78)
        draw_texture_rect(glow_tex, Rect2(point - Vector2(core_r, core_r), Vector2(core_r * 2.0, core_r * 2.0)), false, core_col)
    # 2. 6 irregular ballistic molten globs splashing outward and curving down onto the ground!
    for _i in range(6):
        var vx: float = r.randf_range(-1.0, 1.0) * size * r.randf_range(0.55, 1.25)
        var vy_up: float = -r.randf_range(0.45, 1.15) * size * 0.82
        var grav: float = size * r.randf_range(1.25, 1.75)
        var p_now: Vector2 = point + Vector2(vx * progress, vy_up * progress + 0.5 * grav * progress * progress)
        var v_now: Vector2 = Vector2(vx, vy_up + grav * progress)
        var drop_r: float = r.randf_range(3.6, 7.2) * (1.0 - progress * 0.45)
        _draw_lava_drop(p_now, v_now, drop_r, color, fade)
        # Small ground splatter puddle dot when droplet nears the end of its arc
        if progress > 0.55:
            var land_a: float = clampf((progress - 0.55) / 0.25, 0.0, 1.0) * fade
            var puddle_col := Color(0.18, 0.84, 0.46, land_a * 0.42) if is_green else Color(0.92, 0.34, 0.08, land_a * 0.42)
            draw_circle(p_now + Vector2(0.0, 2.0), drop_r * 1.25, puddle_col)
    # 3. 4 tiny hot popping cinders
    var cinder_col := Color(0.76, 1.0, 0.62, fade * 0.92) if is_green else Color(1.0, 0.90, 0.46, fade * 0.92)
    for _s in range(4):
        var sx: float = r.randf_range(-1.0, 1.0) * size * 1.05
        var sy: float = -r.randf_range(0.4, 1.2) * size * 0.9
        var sp: Vector2 = point + Vector2(sx * ease_out, sy * ease_out + 18.0 * progress * progress)
        draw_circle(sp, r.randf_range(1.3, 2.5) * fade, cinder_col)

func _draw_fire_splash(point: Vector2, size: float, color: Color, progress: float) -> void:
    # Compact molten-droplet splatter on monsters (trimmed size & droplet count for high FPS).
    var is_green: bool = color.g > color.r * 1.25 and color.g > 0.65
    var ease_out: float = 1.0 - pow(1.0 - progress, 2.0)
    var fade: float = clampf(1.0 - pow(progress, 1.7), 0.0, 1.0)
    var glow_tex: Texture2D = soft_glow_texture()
    var r := _draw_rng
    r.seed = int(absf(point.x * 53.0 + point.y * 71.0)) + 7
    var glow_r: float = maxf(13.0, size * (0.42 + ease_out * 0.20))
    var glow_c := Color(0.18, 0.84, 0.46, fade * 0.54) if is_green else Color(color.r, color.g * 0.55, color.b * 0.2, fade * 0.54)
    draw_texture_rect(glow_tex, Rect2(point - Vector2(glow_r, glow_r), Vector2(glow_r * 2.0, glow_r * 2.0)), false, glow_c)
    for _i in range(2):
        var vx: float = r.randf_range(-1.0, 1.0) * maxf(18.0, size * 0.88)
        var vy_up: float = -r.randf_range(0.45, 1.0) * maxf(16.0, size * 0.72)
        var grav: float = maxf(36.0, size * 1.45)
        var p_now: Vector2 = point + Vector2(vx * progress, vy_up * progress + 0.5 * grav * progress * progress)
        var v_now: Vector2 = Vector2(vx, vy_up + grav * progress)
        var drop_r: float = r.randf_range(2.0, 3.6) * (1.0 - progress * 0.42)
        _draw_lava_drop(p_now, v_now, drop_r, color, fade)

func _draw_thunder_blast(canvas: Node2D, point: Vector2, size: float, color: Color, progress: float) -> void:
    # Clean silver-white (or crimson Red Lightning) electric AoE burst for Thunder Cannon — NO brown dust smoke!
    var ease_out: float = 1.0 - pow(1.0 - progress, 2.2)
    var fade: float = clampf(1.0 - progress * 0.90, 0.0, 1.0)
    var is_red: bool = color.r > 0.85 and color.g < 0.48
    var aura_c: Color = Color(1.0, 0.24, 0.16, fade * 0.52) if is_red else Color(0.84, 0.92, 1.0, fade * 0.50)
    var rim_c: Color = Color(0.58, 0.10, 0.08, fade * 0.84) if is_red else Color(0.28, 0.36, 0.48, fade * 0.78)
    var body_c: Color = Color(1.0, 0.36, 0.24, fade * 0.96) if is_red else Color(0.92, 0.97, 1.0, fade * 0.96)
    var core_c: Color = Color(1.0, 0.94, 0.88, fade) if is_red else Color(1.0, 1.0, 0.99, fade)
    var glow_tex: Texture2D = soft_glow_texture()
    var glow_r: float = size * (0.68 + ease_out * 0.40)
    canvas.draw_texture_rect(glow_tex, Rect2(point - Vector2(glow_r, glow_r), Vector2(glow_r * 2.0, glow_r * 2.0)), false, aura_c)
    var flash: float = clampf(1.0 - progress * 1.8, 0.0, 1.0)
    if flash > 0.01:
        var sr: float = size * 0.36 * (0.75 + flash * 0.35)
        _draw_tapered_star(point, sr, sr * 0.20, Color(core_c.r, core_c.g, core_c.b, flash * 0.95), canvas)
    # 6 sharp radiating jagged lightning forks tapering outward
    var r := _draw_rng
    r.seed = int(absf(point.x * 19.0 + point.y * 37.0)) + int(floor(progress * 8.0)) * 11
    for i in range(6):
        var a: float = float(i) * TAU / 6.0 + r.randf_range(-0.18, 0.18)
        var dir: Vector2 = Vector2.from_angle(a)
        var side: Vector2 = dir.orthogonal()
        var reach: float = size * (0.45 + ease_out * 0.55) * r.randf_range(0.85, 1.12)
        var pts := PackedVector2Array([point])
        for s in range(1, 5):
            var t: float = float(s) / 4.0
            var jag: float = r.randf_range(-9.0, 9.0) * sin(t * PI)
            pts.append(point + dir * (reach * t) + side * jag)
        _stroke_bolt(pts, rim_c, 5.2 * fade, 0.8 * fade, canvas)
        _stroke_bolt(pts, body_c, 3.0 * fade, 0.5 * fade, canvas)
        _stroke_bolt(pts, core_c, 1.4 * fade, 0.25 * fade, canvas)

static var _soft_glow_tex: Texture2D = null

static func soft_glow_texture() -> Texture2D:
    if _soft_glow_tex != null:
        return _soft_glow_tex
    var sz: int = 64
    var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
    var half: float = float(sz - 1) * 0.5
    for y in range(sz):
        for x in range(sz):
            var dx: float = (float(x) - half) / half
            var dy: float = (float(y) - half) / half
            var d: float = sqrt(dx * dx + dy * dy)
            if d >= 1.0:
                img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))
            else:
                # Smooth Ghibli-style watercolor radial falloff with subtle organic brush grain
                var angle: float = atan2(dy, dx)
                var grain: float = 0.92 + 0.08 * sin(angle * 3.0 + d * 5.0) * cos(angle * 2.0 - d * 3.0)
                var a: float = pow(cos(d * PI * 0.5), 1.85) * grain
                img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
    _soft_glow_tex = ImageTexture.create_from_image(img)
    return _soft_glow_tex

static func draw_dust_puff(canvas: Node2D, center: Vector2, radius: float, alpha: float, seed_val: float = 0.0) -> void:
    # Warm sandy-yellow ("土黄/沙黄") earth dust matching the parchment wilderness (zero blue or green tint).
    var a: float = clampf(alpha, 0.0, 1.0)
    var r_big: float = radius * 1.42
    var rot: float = fmod(seed_val * 1.9, TAU) * 0.25
    var lobes: Array = [
        [Vector2(0.0, 0.0), 0.62],
        [Vector2(-0.48, 0.16), 0.46],
        [Vector2(0.48, 0.12), 0.44],
        [Vector2(-0.20, -0.32), 0.40],
        [Vector2(0.24, -0.26), 0.38]
    ]
    for lobe in lobes:
        var p: Vector2 = center + Vector2(lobe[0]).rotated(rot) * r_big
        var r: float = float(lobe[1]) * r_big
        canvas.draw_circle(p + Vector2(0.0, 2.5), r * 1.05, Color(0.80, 0.60, 0.28, 0.42 * a))
        canvas.draw_circle(p, r, Color(0.95, 0.80, 0.44, 0.68 * a))
    # Soft sunlit sand highlight on upper billow
    canvas.draw_circle(center + Vector2(-r_big * 0.10, -r_big * 0.16), r_big * 0.44, Color(0.99, 0.90, 0.62, 0.40 * a))
    # Subtle warm ochre contour hints
    canvas.draw_arc(center + Vector2(-r_big * 0.14, -r_big * 0.12), r_big * 0.48, 3.2, 5.5, 12, Color(0.58, 0.42, 0.19, 0.34 * a), 1.6, true)
    canvas.draw_arc(center + Vector2(r_big * 0.22, r_big * 0.08), r_big * 0.36, -0.4, 1.6, 10, Color(0.58, 0.42, 0.19, 0.28 * a), 1.4, true)

static func make_radial_cracks(center: Vector2, radius: float, seed_int: int, count_min: int = 3, count_max: int = 6, squash_y: float = 0.76, allow_branches: bool = false) -> Array:
    # Unified crisp straight-segmented angular ground cracks: random 3-6 arms & random overall scale per slam!
    var r := RandomNumberGenerator.new()
    r.seed = seed_int
    var count: int = r.randi_range(count_min, count_max)
    var scale_jitter: float = r.randf_range(0.84, 1.20)
    var scaled_r: float = radius * scale_jitter
    var cracks: Array = []
    var base_a: float = r.randf_range(0.0, TAU)
    var sector: float = TAU / float(count)
    for i in range(count):
        var a: float = base_a + float(i) * sector + r.randf_range(-sector * 0.34, sector * 0.34)
        var is_major: bool = (i % 2 == 0)
        var segs: int = r.randi_range(3, 4) if is_major else r.randi_range(2, 3)
        var total_len: float = scaled_r * (r.randf_range(0.74, 1.10) if is_major else r.randf_range(0.38, 0.74))
        var step_len: float = total_len / float(segs)
        var root_w: float = scaled_r * (r.randf_range(0.080, 0.110) if is_major else r.randf_range(0.058, 0.084))
        var cur: Vector2 = center + Vector2(cos(a), sin(a) * squash_y) * r.randf_range(scaled_r * 0.02, scaled_r * 0.08)
        var spine: Array = [cur]
        var zig: float = 1.0 if r.randf() < 0.5 else -1.0
        for _s in range(segs):
            # Straight heading with crisp angular rock-fracture zigs (never curls!)
            var seg_a: float = a + zig * r.randf_range(0.10, 0.26)
            zig = -zig
            cur += Vector2(cos(seg_a), sin(seg_a) * squash_y) * step_len * r.randf_range(0.82, 1.18)
            spine.append(cur)
        cracks.append(_build_tapered_crack(spine, root_w))
        if allow_branches and is_major and spine.size() >= 3:
            var idx: int = r.randi_range(1, spine.size() - 2)
            var bcur: Vector2 = spine[idx]
            var bspine: Array = [bcur]
            var ba: float = a + (1.0 if r.randf() < 0.5 else -1.0) * r.randf_range(0.42, 0.78)
            for _bs in range(2):
                var bseg_a: float = ba + (1.0 if _bs % 2 == 0 else -1.0) * r.randf_range(0.04, 0.14)
                bcur += Vector2(cos(bseg_a), sin(bseg_a) * squash_y) * (radius * r.randf_range(0.14, 0.24))
                bspine.append(bcur)
            cracks.append(_build_tapered_crack(bspine, root_w * 0.50))
    return cracks

static func _build_tapered_crack(spine: Array, root_half_w: float) -> Dictionary:
    var n: int = spine.size()
    var left_pts: Array = []
    var right_pts: Array = []
    var core_left: Array = []
    var core_right: Array = []
    for i in range(n):
        var t: float = float(i) / maxf(1.0, float(n - 1)) # 0 at root -> 1 at vanishing tip
        var taper: float = pow(1.0 - t, 1.25) # thick at root, smoothly feathers to 0 at tip
        var p: Vector2 = spine[i]
        var tangent: Vector2 = (spine[mini(i + 1, n - 1)] - spine[maxi(i - 1, 0)]).normalized()
        if tangent.length_squared() < 0.001:
            tangent = Vector2.RIGHT
        var norm: Vector2 = tangent.orthogonal()
        var hw: float = root_half_w * taper
        left_pts.append(p + norm * hw)
        right_pts.append(p - norm * hw)
        core_left.append(p + norm * (hw * 0.52))
        core_right.append(p - norm * (hw * 0.52))
    var outer := PackedVector2Array()
    var inner := PackedVector2Array()
    for i in range(n):
        outer.append(left_pts[i])
        inner.append(core_left[i])
    for i in range(n - 2, -1, -1):
        outer.append(right_pts[i])
        inner.append(core_right[i])
    return {"outer": outer, "inner": inner, "spine": spine}

static func draw_tapered_cracks(canvas: Node2D, cracks: Array, rim_color: Color, core_color: Color) -> void:
    for ck in cracks:
        canvas.draw_colored_polygon(ck["outer"], rim_color)
    for ck in cracks:
        canvas.draw_colored_polygon(ck["inner"], core_color)

static func draw_elemental_cracks(canvas: Node2D, cracks: Array, rim_color: Color, bed_color: Color, glow_color: Color) -> void:
    # Layered 4-pass rendering so ALL crack junctions and the center hub merge seamlessly
    # with ZERO dark outline cutoffs across intersecting branches!
    var bevel_col := Color(0.96, 0.87, 0.68, 0.58 * rim_color.a)
    # Pass 1: Sunlit broken-crust bevel lip for all branches
    for ck in cracks:
        var outer: PackedVector2Array = ck["outer"]
        var bevel := PackedVector2Array()
        for pt in outer:
            bevel.append(pt + Vector2(1.2, 2.0))
        canvas.draw_colored_polygon(bevel, bevel_col)
    # Pass 2: Dark earth-wall rim for all branches
    for ck in cracks:
        canvas.draw_colored_polygon(ck["outer"], rim_color)
    # Pass 3: Deep recessed chasm interior for all branches (merges cleanly at every junction!)
    for ck in cracks:
        canvas.draw_colored_polygon(ck["inner"], bed_color)
    # Pass 4: Continuous elemental glow shining through ALL fissures on top of the dark walls
    if glow_color.a <= 0.01:
        return
    var bright_core: Color = glow_color.lerp(Color(1.0, 1.0, 1.0, glow_color.a), 0.58)
    for ck in cracks:
        var spine: Array = ck.get("spine", [])
        if spine.size() < 2:
            continue
        var glow_segs: int = maxi(1, int(ceil(float(spine.size() - 1) * 0.82)))
        for i in range(glow_segs):
            var t: float = 1.0 - float(i) / maxf(1.0, float(glow_segs))
            var bloom_col: Color = Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * (0.28 + 0.36 * t))
            var seg_col: Color = Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * (0.58 + 0.42 * t))
            canvas.draw_line(spine[i], spine[i + 1], bloom_col, 7.2 * t + 1.8, true)
            canvas.draw_line(spine[i], spine[i + 1], seg_col, 3.6 * t + 0.9, true)
            if t > 0.35:
                canvas.draw_line(spine[i], spine[i + 1], Color(bright_core.r, bright_core.g, bright_core.b, glow_color.a * t * 0.92), 1.6 * t + 0.4, true)

func _draw_ground_particles(canvas: Node2D) -> void:
    if vfx_mode == "off":
        return
    for particle in particles:
        var kind: String = str(particle.get("kind", ""))
        if kind != "quake" and kind != "thunder_blast":
            continue
        var point: Vector2 = particle["at"]
        if _has_hero_anchor and (absf(point.x - hero_anchor.x) > 780.0 or absf(point.y - hero_anchor.y) > 540.0):
            continue
        var progress: float = clampf(float(particle["age"]) / maxf(0.001, float(particle["life"])), 0.0, 1.0)
        if kind == "quake":
            _draw_quake(canvas, particle, point, float(particle["size"]), particle["color"], progress)
        else:
            _draw_thunder_blast(canvas, point, float(particle["size"]), particle["color"], progress)

func _draw_quake(canvas: Node2D, particle: Dictionary, point: Vector2, size: float, color: Color, progress: float) -> void:
    var glow: Texture2D = soft_glow_texture()
    var squash_y: float = 0.74
    var fade: float = clampf(1.0 - pow(progress, 1.45), 0.0, 1.0)
    var seed_int: int = int(absf(point.x * 73.0 + point.y * 137.0)) + 17
    var r := _draw_rng
    r.seed = seed_int
    # Soft recessed parchment pit (low saturation, blends into ground)
    var pit_r: float = size * (0.46 + minf(progress * 0.18, 0.10))
    canvas.draw_texture_rect(glow, Rect2(point - Vector2(pit_r * 1.4, pit_r * 1.4 * squash_y), Vector2(pit_r * 2.8, pit_r * 2.8 * squash_y)), false, Color(0.52, 0.39, 0.25, 0.36 * fade))
    # Unified 3-layer crisp ground cracks (cached per quake particle for high FPS!)
    if not particle.has("_quake_cracks"):
        particle["_quake_cracks"] = make_radial_cracks(point, size * 1.06, seed_int + 9, 3, 6, squash_y, false)
    draw_elemental_cracks(
        canvas, particle["_quake_cracks"],
        Color(0.26, 0.19, 0.13, 0.86 * fade),
        Color(0.14, 0.10, 0.08, 0.88 * fade),
        Color(0.14, 0.10, 0.08, 0.0)
    )
    # Translucent airy dust puffs & tiny pebbles
    if progress < 0.80:
        var p2: float = clampf(progress / 0.80, 0.0, 1.0)
        var dust_alpha: float = sin(p2 * PI) * 0.82
        var ring_r: float = size * (0.28 + p2 * 0.54)
        for i in range(5):
            var a: float = float(i) * TAU / 5.0 + r.randf_range(-0.25, 0.25)
            var puff_pos: Vector2 = point + Vector2(cos(a), sin(a) * squash_y) * ring_r + Vector2(0.0, -p2 * 9.0)
            draw_dust_puff(canvas, puff_pos, size * r.randf_range(0.16, 0.24) * (0.7 + p2 * 0.45), dust_alpha, float(i) + seed_int)
        for i in range(4):
            var pa: float = r.randf_range(0.0, TAU)
            var dist: float = size * (0.26 + p2 * 0.64)
            var hop: float = sin(p2 * PI) * r.randf_range(12.0, 20.0)
            var ppos: Vector2 = point + Vector2(cos(pa) * dist, sin(pa) * dist * squash_y - hop)
            canvas.draw_circle(ppos, r.randf_range(2.2, 3.6) * (1.0 - p2 * 0.35), Color(0.54, 0.42, 0.29, 0.75 * dust_alpha))

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

func _stroke_bolt(points: PackedVector2Array, color: Color, peak: float, tip: float, canvas: CanvasItem = self) -> void:
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
        canvas.draw_line(points[index], points[index + 1], color, maxf(0.6, width), true)

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
