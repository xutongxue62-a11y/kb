extends Node2D

const Actor = preload("res://src/actor_view.gd")
var library
var hero
var weapons: Array[Sprite2D] = []
var critters: Array[Dictionary] = []
var clock := 0.0
var parallax := Vector2.ZERO
var center := Vector2(838, 397)
var last_beat := -1

func setup(assets) -> void:
    library = assets
    hero = Actor.new()
    add_child(hero)
    hero.setup(library)
    hero.get_node("PlayerMarker").hide()
    hero.scale = Vector2.ONE * 2.9
    for sprite in hero.parts.values(): sprite.material = library.weapon_material
    for key in ["club", "axe", "blade", "sling", "powder", "staff"]:
        var sprite: Sprite2D = library.make_weapon(key, 90 if key != "powder" else 102)
        sprite.name = "Orbit_" + key
        add_child(sprite)
        weapons.append(sprite)
    var placements := [
        ["hunter", Vector2(589, 182), 144.0, 0.3],
        ["charger", Vector2(1114, 172), 153.0, 2.2],
        ["spitter", Vector2(488, 447), 126.0, 1.1],
        ["tank", Vector2(592, 660), 168.0, 3.3],
        ["hunter", Vector2(1120, 631), 149.0, 4.2],
        ["hunter", Vector2(1173, 383), 117.0, 5.3]]
    for entry in placements:
        var sprite := Sprite2D.new()
        sprite.texture = library.texture("dinosaurs", entry[0])
        sprite.material = library.weapon_material
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        var scale_value: float = float(entry[2]) / maxf(library.region("dinosaurs", entry[0]).size.x, library.region("dinosaurs", entry[0]).size.y)
        sprite.scale = Vector2.ONE * scale_value
        sprite.flip_h = entry[1].x > center.x
        sprite.z_index = 3
        add_child(sprite)
        critters.append({"sprite":sprite,"rest":entry[1],"phase":entry[3],"scale":scale_value,"width":entry[2],"kind":entry[0]})
    advance_visual(0.0)
    if DisplayServer.get_name() == "headless": set_process(false)

func _process(delta: float) -> void:
    if library == null: return
    var target: Vector2 = (get_global_mouse_position() - Vector2(640, 400)) * 0.009
    target = target.limit_length(6)
    parallax = parallax.lerp(target, 1 - exp(-delta * 3))
    advance_visual(delta)

func orbit_point(angle: float) -> Vector2:
    return center + parallax + Vector2(cos(angle) * 205, sin(angle) * 193)

func advance_visual(delta: float) -> void:
    clock += delta
    hero.position = center + parallax + Vector2(0, sin(clock * 1.8) * 2)
    hero.animate(Vector2.ZERO, 0, delta)
    hero.rotation = sin(clock * 1.25) * 0.012
    for i in range(weapons.size()):
        var angle: float = TAU * i / 6.0 + clock * 0.49 + sin(clock * 0.8) * 0.10 - 0.7
        var sprite: Sprite2D = weapons[i]
        sprite.position = orbit_point(angle)
        sprite.rotation = sin(angle + 0.8) * 0.23 + sin(clock * 2 + i) * 0.055
        if i == posmod(floori(clock / 0.85),6):
            var phase: float = fmod(clock,0.85) / 0.85
            var attack: float = maxf(0,sin(clampf((phase-0.08)/0.65,0,1)*PI))
            sprite.position += Vector2.from_angle(angle) * attack * 16
            sprite.rotation += attack * (0.65 if i < 3 else -0.16)
        sprite.z_index = 14 if sin(angle) > 0.1 else 7
    var beat: int = floori(clock / 0.85)
    if beat != last_beat:
        last_beat = beat
        hero.recoil((weapons[posmod(beat,6)].position-center).normalized())
    for creature in critters:
        var sprite: Sprite2D = creature.sprite
        var phase_value: float = clock * 2.2 + float(creature.phase)
        var hop: float = pow(maxf(0, sin(phase_value)), 2) * (3 if creature.kind == "tank" else (5 if creature.kind == "charger" else 11))
        sprite.position = creature.rest + parallax * 0.45 + Vector2(sin(clock * 0.72 + float(creature.phase)) * 11, -hop)
        sprite.rotation = sin(phase_value) * 0.026
        sprite.scale = Vector2.ONE * float(creature.scale) * Vector2(1 + sin(phase_value) * 0.016, 1 - sin(phase_value) * 0.020)
        if creature.kind == "spitter":
            sprite.rotation += sin(clock*1.8)*0.055
            sprite.scale.y *= 1 + sin(clock*1.8)*0.025
        if creature.kind == "hunter":
            sprite.position.x += pow(maxf(0,sin(clock*1.3+creature.phase)),3)*10
    queue_redraw()

func shadow(at: Vector2, width: float, alpha: float) -> void:
    draw_set_transform(at, 0, Vector2(width, width * 0.16))
    draw_circle(Vector2.ZERO, 0.5, Color(0.25, 0.18, 0.13, alpha), true, -1, true)
    draw_set_transform(Vector2.ZERO)

func _draw() -> void:
    if library == null: return
    shadow(center + parallax + Vector2(0, 132), 173, 0.16)
    for creature in critters:
        shadow(creature.rest + parallax * 0.45 + Vector2(0, float(creature.width) * 0.28), float(creature.width) * 0.83, 0.17)
    for i in range(6):
        var angle: float = TAU * i / 6.0 + clock * 0.49 + sin(clock * 0.8) * 0.10 - 0.7
        var trail := PackedVector2Array()
        var inner := PackedVector2Array()
        for n in range(12):
            var a: float = angle - 0.32 + n * 0.022
            trail.append(orbit_point(a))
            inner.append(center + parallax + (orbit_point(a) - center - parallax) * 0.96)
        draw_polyline(trail, Color(1.0, 0.96, 0.80, 0.60), 3.2, true)
        draw_polyline(inner, Color(1.0, 0.96, 0.80, 0.30), 1.1, true)
    var attacking: int = posmod(floori(clock / 0.85),6)
    var phase: float = fmod(clock,0.85)/0.85
    var start: Vector2 = weapons[attacking].position
    if attacking >= 3 and phase > 0.2 and phase < 0.83:
        var end: Vector2 = critters[attacking].sprite.position
        var travel: float = clampf((phase-0.2)/0.6,0,1)
        var at: Vector2 = start.lerp(end,travel)
        var direction: Vector2 = (end-start).normalized()
        var tone := Color("#77b6b1") if attacking == 5 else Color("#bc8b51")
        draw_line(at-direction*22,at,tone,3.0,true)
        draw_circle(at,4.0,tone,true,-1,true)
    elif attacking < 3 and phase > 0.1 and phase < 0.65:
        var flash: float = sin((phase-0.1)/0.55*PI)
        draw_arc(start,25,-1.4+phase*3,0.6+phase*3,16,Color(1,0.97,0.84,flash*0.7),3.0,true)
