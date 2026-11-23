extends RefCounted

const Rules = preload("res://src/rules.gd")
const Catalog = preload("res://src/catalog.gd")
const BONE := Color("#edca83")
const THUNDER := Color("#98c5f6")
const RUNE := Color("#d2a5ec")

var chief_flag_at := Vector2.INF
var chief_flag_until := 0.0
var chief_flag_ready := 0.0
var chief_thrust_used := false
var rage_hits := 0
var rage_ready := 0.0
var guard_until := 0.0
var staff_casts := 0
var staff_sigil_at := Vector2.INF
var priest_hits := 0
var priest_altar_at := Vector2.INF
var priest_altar_until := 0.0
var priest_use_altar := false

func start_armory_attack(world, weapon: String) -> void:
    if weapon == "spear" and world.character_id == "chief":
        chief_thrust_used = false
    elif weapon == "totem" and world.character_id == "priest":
        if world.elapsed >= priest_altar_until:
            priest_altar_at = Vector2.INF
        priest_use_altar = priest_altar_at.is_finite()

func landed_armory_hit(world, enemy: Dictionary, weapon: String, raw_damage: float, direction: Vector2) -> void:
    if weapon == "spear" and world.character_id == "chief" and not chief_thrust_used:
        chief_thrust_used = true
        var point: Vector2 = enemy.position
        if world.elapsed < chief_flag_until:
            var aim: Vector2 = chief_flag_at.direction_to(point)
            var reach: float = Rules.scaled_range(Catalog.WEAPONS["spear"], world.stats)
            world.effects.beam(chief_flag_at, chief_flag_at + aim * reach, BONE)
            for strike in world.armory.spear_strike(chief_flag_at, aim, reach, world.combat_targets(), raw_damage * 0.60, false):
                world.hurt_enemy(strike.enemy, strike.damage, "spear", true, strike.direction)
        elif world.elapsed >= chief_flag_ready:
            chief_flag_at = point + direction * 72.0
            chief_flag_until = world.elapsed + 3.0
            chief_flag_ready = world.elapsed + 8.0
            world.effects.burst(chief_flag_at, BONE, 34.0, "ring")
    elif weapon == "totem" and world.character_id == "priest":
        if priest_use_altar and float(enemy.hp) > 0.0:
            priest_use_altar = false
            var point: Vector2 = enemy.position
            world.effects.lightning(priest_altar_at, point, THUNDER)
            priest_altar_at = Vector2.INF
            world.hurt_enemy(enemy, raw_damage * 0.65, "talent_altar", true, direction)
        elif not priest_altar_at.is_finite():
            priest_hits += 1
            if priest_hits == 6:
                priest_hits = 0
                priest_altar_at = world.player_position + Vector2(0.0, 42.0)
                priest_altar_until = world.elapsed + 8.0
                world.effects.burst(priest_altar_at, THUNDER, 45.0, "ring")

func hunter_multiplier(world, enemy: Dictionary, weapon: String, from_combo: bool) -> float:
    if world.character_id != "hunter" or weapon != "bonebow" or from_combo or world.elapsed < float(enemy.get("hunt_ready_at", 0.0)):
        return 1.0
    var hits: int = int(enemy.get("hunt_hits", 0)) + 1
    if hits == 4:
        enemy["hunt_hits"] = 0
        enemy["hunt_ready_at"] = world.elapsed + 4.0
        world.effects.burst(enemy.position, BONE, 35.0, "ring")
        return 1.80
    enemy["hunt_hits"] = hits
    return 1.0

func record_player_hit(world) -> void:
    if world.character_id == "barbarian" and world.elapsed >= rage_ready:
        rage_hits = mini(2, rage_hits + 1)
        if rage_hits == 2:
            world.effects.burst(world.player_position, BONE, 34.0, "ring")

func counter_melee(world, enemy: Dictionary, weapon: String, raw_damage: float, from_combo: bool) -> void:
    if world.character_id != "barbarian" or rage_hits < 2 or weapon not in ["club", "axe", "blade", "spear", "hammer"]:
        return
    if (from_combo and weapon != "hammer") or (weapon == "hammer" and Rules.host_is_thunder_enchanted(world.active_links, weapon)):
        return
    rage_hits = 0
    rage_ready = world.elapsed + 8.0
    guard_until = world.elapsed + 1.0
    world.damage_area(enemy.position, 112.0, raw_damage * 1.45, "talent_counter", true, BONE, "ring")

func staff_echo(world, muzzle: Vector2) -> Vector2:
    if world.character_id != "shaman":
        return Vector2.INF
    var echo: Vector2 = staff_sigil_at
    staff_sigil_at = Vector2.INF
    staff_casts = (staff_casts + 1) % 3
    if staff_casts == 0:
        staff_sigil_at = muzzle
        world.effects.burst(muzzle, RUNE, 29.0, "rune_spark")
    return echo

func draw_markers(canvas: CanvasItem, time: float) -> void:
    if chief_flag_at.is_finite() and time < chief_flag_until:
        var tip := chief_flag_at + Vector2(0, -35)
        canvas.draw_line(chief_flag_at, tip, Color("#483123"), 4.0, true)
        canvas.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(25, 6), tip + Vector2(0, 16)]), BONE)
    if staff_sigil_at.is_finite():
        canvas.draw_arc(staff_sigil_at, 18.0, 0.0, TAU, 24, RUNE, 2.0, true)
        canvas.draw_polyline(PackedVector2Array([staff_sigil_at + Vector2.UP * 14.0, staff_sigil_at + Vector2.RIGHT * 12.0, staff_sigil_at + Vector2.DOWN * 10.0, staff_sigil_at + Vector2.LEFT * 12.0, staff_sigil_at + Vector2.UP * 14.0]), RUNE, 2.0, true)
    if priest_altar_at.is_finite() and time < priest_altar_until:
        canvas.draw_arc(priest_altar_at, 21.0, 0.0, TAU, 24, THUNDER, 2.0, true)
        canvas.draw_colored_polygon(PackedVector2Array([priest_altar_at + Vector2(-10, 4), priest_altar_at + Vector2(0, -28), priest_altar_at + Vector2(10, 4)]), THUNDER)
