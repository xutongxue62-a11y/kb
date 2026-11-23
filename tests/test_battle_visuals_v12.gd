extends SceneTree

const Effects = preload("res://src/effects.gd")
const ActorView = preload("res://src/actor_view.gd")
const AssetLibrary = preload("res://src/asset_library.gd")

var checks: int = 0
var failures: int = 0

# CanvasItem drawing is only legal inside _draw. Record that boundary so these
# checks exercise the production geometry without requiring a visible window.
class CanvasRecorder extends RefCounted:
    var commands: Array = []

    func draw_texture_rect(texture: Texture2D, rect: Rect2, _tile: bool) -> void:
        commands.append({"shape":"texture","texture":texture,"rect":rect,"color":Color.WHITE})

    func draw_colored_polygon(points: PackedVector2Array, color: Color) -> void:
        commands.append({"shape": "polygon", "points": points, "color": color})

    func draw_polyline(points: PackedVector2Array, color: Color, width: float = -1.0, _antialiased: bool = false) -> void:
        commands.append({"shape": "polyline", "points": points, "color": color, "width": width})

    func draw_circle(point: Vector2, radius: float, color: Color, _filled: bool = true, width: float = -1.0, _antialiased: bool = false) -> void:
        commands.append({"shape": "circle", "point": point, "radius": radius, "color": color, "width": width})

    func draw_line(start: Vector2, end: Vector2, color: Color, width: float = -1.0, _antialiased: bool = false) -> void:
        commands.append({"shape": "line", "points": PackedVector2Array([start, end]), "color": color, "width": width})

    func draw_arc(point: Vector2, radius: float, _start: float, _end: float, _count: int, color: Color, width: float = -1.0, _antialiased: bool = false) -> void:
        commands.append({"shape": "arc", "point": point, "radius": radius, "color": color, "width": width})

    func draw_string(_font: Font, point: Vector2, text: String, _alignment: int = 0, _width: float = -1.0, _font_size: int = 16, color: Color = Color.WHITE) -> void:
        commands.append({"shape": "text", "point": point, "text": text, "color": color})

    func draw_string_outline(_font: Font, point: Vector2, text: String, _alignment: int = 0, _width: float = -1.0, _font_size: int = 16, width: int = 1, color: Color = Color.WHITE) -> void:
        commands.append({"shape": "text_outline", "point": point, "text": text, "color": color, "width": width})

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func points_bounds(points: PackedVector2Array) -> Rect2:
    var bounds := Rect2(points[0], Vector2.ZERO)
    for point in points:
        bounds = bounds.expand(point)
    return bounds

func check_ground_shadow() -> void:
    var hero = ActorView.new()
    hero.setup(AssetLibrary.new())
    root.add_child(hero)
    var available: bool = hero.has_method("ground_shadow_anchor") and hero.has_method("_draw_ground_shadow")
    expect(available, "hero owns a fixed ground-shadow anchor and filled soft-shadow renderer")
    if available:
        var anchor: Vector2 = hero.ground_shadow_anchor()
        var body_before: Vector2 = hero.parts["body"].position
        for index in range(24):
            hero.animate(Vector2(180, 70), 7.0, 1.0 / 30.0)
            expect(hero.ground_shadow_anchor().is_equal_approx(anchor), "walking bob cannot move the ground shadow: frame " + str(index))
        expect(hero.parts["body"].position != body_before, "shadow test includes a genuinely animated body")
        expect(anchor.y > hero.rest["left_foot"].y and anchor.y > hero.rest["right_foot"].y, "projection sits under the resting soles")
        var canvas := CanvasRecorder.new()
        hero._draw_ground_shadow(canvas)
        var shadows: Array = canvas.commands.filter(func(c): return c.shape == "polygon")
        var rings: Array = canvas.commands.filter(func(c): return c.shape == "polyline")
        expect(shadows.size() >= 3, "hero keeps the layered filled soft shadow")
        expect(not rings.is_empty(), "the requested player marker adds a ground ring over the shadow")
        for command in canvas.commands:
            var bounds: Rect2 = points_bounds(command.points)
            expect(bounds.size.x > bounds.size.y * 2.5 and bounds.get_center().is_equal_approx(anchor), "soft projection remains flat and centered on the ground")
            if command.shape == "polygon":
                expect(command.color.a > 0.0 and command.color.a <= 0.15 and command.color.r < 0.2, "ground shadow is dark and translucent")
            elif command.shape == "polyline":
                expect(command.color.g > command.color.r and command.color.a > 0.1, "the player marker has a visible teal stroke")
    hero.queue_free()

func check_ranged_effects() -> void:
    var fx = Effects.new()
    root.add_child(fx)
    expect(fx.has_method("muzzle"), "ranged weapons expose actual-origin muzzle feedback")
    if fx.has_method("muzzle"):
        var origins: Array = []
        var kinds: Array = []
        var signatures: Array = []
        for key in ["sling", "powder", "staff"]:
            fx.particles.clear()
            var origin := Vector2(180, 90)
            fx.muzzle(origin, Vector2(4, 0), key)
            expect(not fx.particles.is_empty(), key + " muzzle creates short-lived feedback")
            var primary: Dictionary = fx.particles[0]
            origins.append(primary.at)
            kinds.append(primary.kind)
            expect(primary.at == origin and primary.direction.is_equal_approx(Vector2.RIGHT), key + " muzzle stays at the supplied firing source and normalizes direction")
            expect(float(primary.life) <= 0.2, key + " muzzle clears quickly to keep the hunter visible")
            var canvas := CanvasRecorder.new()
            fx._draw_ranged_muzzle(canvas, primary, primary.color, 0.25)
            signatures.append(var_to_str(canvas.commands))
        expect(kinds[0] != kinds[1] and kinds[1] != kinds[2] and kinds[0] != kinds[2], "sling snap, powder flash and staff glyph have distinct effect states")
        expect(signatures[0] != signatures[1] and signatures[1] != signatures[2], "ranged feedback renders different geometry instead of a color swap")
        fx.particles.clear()
        fx.muzzle(Vector2.ZERO, Vector2.ZERO, "powder", true)
        expect(fx.particles[0].get("enchanted", false) and fx.particles[0].direction == Vector2.RIGHT, "enchanted powder keeps its own state with a safe zero-direction fallback")
        fx.particles.clear()
        var trail_signatures: Array = []
        for key in ["sling", "powder", "staff"]:
            fx.call("flight_trail", Vector2(10, 20), Vector2(30, 20), key == "staff", key)
            var particle: Dictionary = fx.particles.back()
            expect(particle.get("weapon_id", "") == key, key + " flight retains its weapon identity")
            var canvas := CanvasRecorder.new()
            fx._draw_flight(canvas, particle, particle.color, 0.2)
            trail_signatures.append(var_to_str(canvas.commands))
        expect(trail_signatures[0] != trail_signatures[1] and trail_signatures[1] != trail_signatures[2], "stone wake, powder fire and rune trail retain different geometry")
        fx.flight_trail(Vector2.ZERO, Vector2.RIGHT, false)
        expect(fx.particles.back().get("weapon_id", "") == "powder", "legacy three-argument nonmagic trail remains powder-compatible")
        fx.flight_trail(Vector2.ZERO, Vector2.RIGHT, true)
        expect(fx.particles.back().get("weapon_id", "") == "staff", "legacy three-argument magic trail remains staff-compatible")
    var impacts: Array = []
    for key in ["sling", "powder", "staff"]:
        fx.particles.clear()
        fx.impact(Vector2.ZERO, Vector2.RIGHT, key)
        impacts.append(fx.particles[0].kind)
    expect(impacts[0] != impacts[1] and impacts[1] != impacts[2], "stone chips, powder hit and rune impact remain distinguishable")
    fx.queue_free()

func check_lightning() -> void:
    var fx = Effects.new()
    root.add_child(fx)
    expect(fx.has_method("lightning"), "chain lightning has a dedicated branched bolt API")
    if fx.has_method("lightning"):
        var start := Vector2(70, 125)
        var end := Vector2(530, 285)
        fx.lightning(start, end, Color("#79f4ff"))
        expect(fx.particles.size() == 1, "a complete branching bolt occupies one particle-budget slot")
        var bolt: Dictionary = fx.particles[0]
        var points: PackedVector2Array = bolt.get("points", PackedVector2Array())
        expect(points.size() >= 6 and points.size() <= 19 and points[0] == start and points[-1] == end, "lightning bends between exact hit endpoints with bounded segment count")
        var bent: bool = false
        var bounded: bool = true
        for point in points:
            var offset: float = point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, end))
            bent = bent or offset > 3.0
            bounded = bounded and offset <= 20.0
        expect(bent and bounded, "lightning is a jagged path constrained to its narrow hit corridor")
        var branches: Array = bolt.get("branches", [])
        expect(branches.size() >= 1 and branches.size() <= 3, "lightning has a small bounded set of branches")
        for branch in branches:
            expect(points.has(branch[0]) and branch.size() >= 3 and branch.size() <= 5, "branch starts on the real main bolt and has a limited path")
            for point in branch:
                expect(point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, end)) <= 40.0, "branch cannot expand into a screen-covering fan")
        var canvas := CanvasRecorder.new()
        fx._draw_arc_lightning(canvas, bolt, bolt.color, 0.1)
        var dark: Array = canvas.commands.filter(func(c): return c.get("width", 0) >= 4.0 and c.color.r < 0.3)
        var bright: Array = canvas.commands.filter(func(c): return c.get("width", 100) <= 2.5 and c.color.r > 0.7 and c.color.g > 0.85)
        expect(not dark.is_empty() and not bright.is_empty(), "bolt renders a bright core inside a dark outline on light and dark terrain")
        var original: PackedVector2Array = points.duplicate()
        fx.advance(0.06)
        expect(fx.particles[0].points == original, "lightning geometry does not jump while it fades")
        var count: int = fx.particles.size()
        fx.lightning(start, start, Color.WHITE)
        expect(fx.particles.size() == count, "zero-length hit does not create a malformed bolt")
        for index in range(230):
            fx.lightning(start, end, Color.WHITE)
            fx.muzzle(start, Vector2.RIGHT, "staff", false)
        expect(fx.particles.size() <= 200, "rapid combined ranged feedback respects the existing particle cap")
        fx.advance(0.6)
        expect(fx.particles.is_empty(), "all new ranged particles expire within a short combat beat")
    fx.damage_number(Vector2.ZERO, 400.0)
    fx.damage_number(Vector2(1, 0), 600.0)
    expect(fx.particles.filter(func(p): return p.kind == "number").size() == 1 and is_equal_approx(fx.particles.back().value, 1000.0), "visual additions preserve damage-number coalescing")
    for index in range(64):
        fx.burst(Vector2(index * 40, 40), Color.WHITE, 24.0, "smoke")
    fx.set_vfx_mode("off")
    fx.advance(0.10)
    expect(fx.particles.size() == 1 and fx.particles[0].value == 1000.0, "a busy effects budget and VFX changes leave the active number intact")
    fx.damage_number(Vector2.ZERO, 500.0)
    expect(fx.particles[0].value == 1000.0, "later hits do not rewrite an already visible number")
    if fx.has_method("_draw_numbers") and fx.particles.size() == 2:
        var number_canvas := CanvasRecorder.new()
        fx._draw_numbers(number_canvas)
        var early: Dictionary = number_canvas.commands[1]
        fx.advance(0.57)
        number_canvas.commands.clear()
        fx._draw_numbers(number_canvas)
        var late: Dictionary = number_canvas.commands[1]
        expect(late.point.y < early.point.y and is_equal_approx(late.point.x, early.point.x) and late.color.a < early.color.a, "the existing number rises and fades without moving sideways")
        fx.advance(1.0)
        number_canvas.commands.clear()
        fx._draw_numbers(number_canvas)
        expect(number_canvas.commands.is_empty(), "all numbers disappear naturally at the end of their lifetimes")
    fx.queue_free()

func check_pickups_and_projectiles() -> void:
    var path := "res://src/battle_visuals.gd"
    expect(FileAccess.file_exists(path), "battle visuals provides reusable pickup and projectile drawing")
    if not FileAccess.file_exists(path):
        return
    var visuals = load(path)
    var coin := CanvasRecorder.new()
    var crystal := CanvasRecorder.new()
    var drop := {"position": Vector2(50, 80), "kind": "coin", "value": 1}
    visuals.draw_pickup(coin, drop, 0.0)
    drop.kind = "xp"
    visuals.draw_pickup(crystal, drop, 0.0)
    expect(coin.commands.size()==1 and coin.commands[0].shape=="texture" and coin.commands[0].rect.size==Vector2(32,36), "each coin uses one cached icon draw at its legible gameplay size")
    expect(crystal.commands.size()==1 and crystal.commands[0].shape=="texture" and crystal.commands[0].texture!=coin.commands[0].texture, "experience retains its own crystal icon")
    var coin_image: Image = coin.commands[0].texture.get_image()
    var crystal_image: Image = crystal.commands[0].texture.get_image()
    expect(coin_image.get_pixel(12,18).r>0.8 and coin_image.get_pixel(12,18).g>0.5 and coin_image.get_pixel(12,18).b<0.4,"cached coin has a clear gold body")
    expect(crystal_image.get_pixel(16,18).g>0.7 and crystal_image.get_pixel(16,18).r<0.7,"cached experience has a clear green body")
    for canvas in [coin, crystal]:
        var icon: Image = canvas.commands[0].texture.get_image()
        var shadow := false
        var ink := false
        for y in range(icon.get_height()):
            for x in range(icon.get_width()):
                var pixel: Color = icon.get_pixel(x,y)
                if y>=28 and pixel.a>0.1 and pixel.a<0.4: shadow=true
                if pixel.a>0.9 and pixel.r<0.2 and pixel.g<0.2 and pixel.b<0.2: ink=true
        expect(shadow and ink,"cached pickup keeps a small translucent ground projection and readable ink border")
    var bulk := CanvasRecorder.new()
    drop.kind = "coin"
    drop.value = 40
    visuals.draw_pickup(bulk, drop, 1.0)
    expect(bulk.commands.all(func(c): return c.shape!="text" and c.shape!="text_outline"), "ground resources omit quantity labels even for legacy input")
    var signatures: Array = []
    for key in ["sling", "powder", "staff", "hostile"]:
        var projectile := {"position": Vector2(120, 120), "velocity": Vector2(200, 0), "kind": key, "radius": 5.5}
        var original: Dictionary = projectile.duplicate(true)
        var canvas := CanvasRecorder.new()
        expect(visuals.draw_projectile(canvas, projectile, 0.5), key + " projectile is handled")
        expect(projectile == original, key + " visual drawing cannot change collision state")
        expect(canvas.commands.any(func(c): return c.color.r < 0.3 and c.color.a > 0.9), key + " projectile retains a dark silhouette")
        signatures.append(var_to_str(canvas.commands))
    expect(signatures[0] != signatures[1] and signatures[1] != signatures[2] and signatures[2] != signatures[3], "stone, burning shell, rune and hostile projectile have distinct rendered shapes")
    var magic := CanvasRecorder.new()
    visuals.draw_projectile(magic, {"position": Vector2(120, 120), "velocity": Vector2.ZERO, "kind": "powder", "enchanted": true}, 0.5)
    expect(var_to_str(magic.commands) != signatures[1] and magic.commands.any(func(c): return c.color.g > 0.8 and c.color.b > 0.8), "enchanted powder adds cyan rune energy while retaining shell geometry")
    var unknown := CanvasRecorder.new()
    expect(not visuals.draw_projectile(unknown, {"position": Vector2.ZERO, "velocity": Vector2.ZERO, "kind": "future_weapon"}, 0.0) and unknown.commands.is_empty(), "unknown projectile remains available to the legacy fallback")

func _initialize() -> void:
    call_deferred("run_checks")

func run_checks() -> void:
    check_ground_shadow()
    check_ranged_effects()
    check_lightning()
    check_pickups_and_projectiles()
    await process_frame
    print("BATTLE_VISUALS_V12 RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
