extends SceneTree
var checks := 0
var failures := 0
class BlockedTerrain extends Node:
    var calls := 0
    func move_body(from: Vector2, _to: Vector2, _radius: float) -> Vector2:
        calls += 1
        return from
func expect(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + label)
func _initialize() -> void:
    call_deferred("run")
func enemy(at: Vector2, elite := false) -> Dictionary:
    return {"position": at, "radius": 16.0, "hp": 10000.0, "elite": elite}
func run() -> void:
    var support = load("res://src/companions.gd").new()
    root.add_child(support)
    var target = enemy(Vector2(290, 0))
    var events := 0
    var damage := 0.0
    for i in 150:
        for hit in support.advance(1.0 / 60.0, Vector2.ZERO, [target], {"pet": 1}, {"attack_speed": 1.0}):
            events += 1
            damage += hit.damage
            expect(hit.position.distance_to(target.position) <= 55.01, "pet bites only in contact")
    expect(events >= 2 and damage >= 14, "grounded pet reaches 290 and repeats its contact bite within two and a half seconds")
    support.reset()
    var near = enemy(Vector2(85, 0))
    var far = enemy(Vector2(420, 0), true)
    var near_hits := 0
    for i in 90:
        for hit in support.advance(1.0 / 60.0, Vector2.ZERO, [near, far], {"pet": 1}, {"attack_speed": 1.0}, true):
            near_hits += int(hit.enemy == near)
    expect(near_hits > 0, "unreachable elite cannot starve reachable normal target")
    support.reset()
    expect(support.advance(1, Vector2.ZERO, [enemy(Vector2(900, 0))], {"pet": 6, "drone": 6}, {"attack_speed": 4.6}).is_empty(), "supports never freely kill across world")
    support.reset()
    var baseline := 0.0
    var upgraded := 0.0
    for level in [1, 6]:
        support.reset()
        for i in 600:
            for hit in support.advance(1.0 / 60.0, Vector2.ZERO, [near], {"pet": level, "drone": level}, {"attack_speed": 1.0 if level == 1 else 4.6}):
                if level == 1: baseline += hit.damage
                else: upgraded += hit.damage
    expect(upgraded > baseline * 4, "growth materially increases support damage")
    expect(upgraded < baseline * 50, "minimum cooldown bounds high-haste event rate")
    var terrain := BlockedTerrain.new()
    root.add_child(terrain)
    support.terrain = terrain
    support.reset()
    var blocked_hits := 0
    for i in 90:
        blocked_hits += support.advance(1.0/60.0, Vector2.ZERO, [target], {"pet": 1}, {"attack_speed": 1.0}).size()
    expect(terrain.calls == 90 and blocked_hits == 0, "ground pet uses terrain and cannot bite through blockage")
    support.reset()
    expect(support.advance(.1, Vector2.ZERO, [target], {"drone": 1}, {"attack_speed": 1.0}).size() == 1, "drone flies over terrain and shoots within range")
    expect(terrain.calls == 90, "drone never uses ground resolver")
    support.terrain = null
    terrain.free()
    var art = load("res://src/support_art.gd")
    for key in ["pet", "drone"]:
        var texture: Texture2D = art.texture(key)
        expect(texture != null, "generated support art loads: " + key)
        if texture != null:
            var image: Image = texture.get_image()
            image.save_png("res://runtime/v11_" + key + "_alpha_preview.png")
            var used: Rect2i = image.get_used_rect()
            expect(used.position.x >= 12 and used.position.y >= 12, "clean transparent sprite padding " + key)
            expect(used.end.x <= image.get_width()-12 and used.end.y <= image.get_height()-12, "symmetric sprite margins " + key)
    print("SUPPORT DAMAGE comparison 10s: base=%.1f upgraded=%.1f" % [baseline, upgraded])
    support.free()
    print("SUPPORTS V11 RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
