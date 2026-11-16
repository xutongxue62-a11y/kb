extends SceneTree

class SoundSpy:
    extends "res://src/hud.gd"
    var sound_requests: Array[String] = []
    func can_animate() -> bool:
        return true
    func snapshot_ui() -> Texture2D:
        return null
    func play_ui(key: String) -> void:
        sound_requests.append(key)

var checks := 0
var failures := 0
func expect(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("FAIL: " + message)
func _initialize() -> void:
    call_deferred("run_checks")
func run_checks() -> void:
    var transition = load("res://src/ui_transition.gd").new()
    transition.size = Vector2(1280, 800)
    root.add_child(transition)
    expect(transition.has_method("burn_boundary"), "departure uses an expanding two-dimensional burn boundary")
    if transition.has_method("burn_boundary"):
        var early: PackedVector2Array = transition.burn_boundary(0.25)
        var late: PackedVector2Array = transition.burn_boundary(0.65)
        expect(early.size() >= 32 and early.size() == late.size(), "burn has a closed detailed contour")
        var first := Rect2(early[0], Vector2.ZERO)
        var second := Rect2(late[0], Vector2.ZERO)
        for p in early: first = first.expand(p)
        for p in late: second = second.expand(p)
        expect(first.size.x > 90 and first.size.y > 90, "fire spreads in both screen axes instead of a vertical wipe line")
        expect(second.get_area() > first.get_area() * 1.5, "the burned opening grows across time")
    transition.play(null, "burn")
    expect(transition.duration >= 0.75, "burn remains visible rather than flashing past")
    transition.finish()
    expect(transition.has_method("page_strip_points"), "return uses a curved paper surface instead of compressing the whole frame to a line")
    if transition.has_method("page_strip_points"):
        for step in range(12):
            for u in [0.0, 0.4, 0.95]:
                var patch: PackedVector2Array = transition.page_strip_points(u, u + 0.05, step / 12.0)
                expect(not Geometry2D.triangulate_polygon(patch).is_empty(), "return paper strip remains drawable across its bend")
    expect(transition.has_method("flame_polygon"), "the burn exposes the actual hand-drawn flame geometry")
    if transition.has_method("flame_polygon"):
        for i in range(24):
            var direction := Vector2.from_angle(TAU * i / 24)
            var flame: PackedVector2Array = transition.flame_polygon(Vector2(300, 240), direction, 19.0, sin(i * 2.7) * 6)
            expect(not Geometry2D.triangulate_polygon(flame).is_empty(), "a short flame remains drawable at angle " + str(i))

    var paper = load("res://src/ui_paper.gd").new()
    paper.size = Vector2(800, 480)
    root.add_child(paper)
    expect(paper.has_method("visible_content_rect"), "paper animation uses a real clipping rectangle")
    if paper.has_method("visible_content_rect"):
        paper.opening_mode = "scroll"
        paper.reveal = 0.3
        var scroll: Rect2 = paper.visible_content_rect()
        paper.opening_mode = "fold"
        var fold: Rect2 = paper.visible_content_rect()
        expect(scroll.size.x < 400 and scroll.size.y == 436, "Buff scroll reveals horizontally with full-height rollers")
        expect(fold.size.x == 800 and fold.size.y < 240 and fold.position.y > 0, "ordinary dialog unfolds vertically from its center")
        expect(paper.content.get_parent().clip_contents, "unrevealed paper controls stay under the animated clip")

    var hud = load("res://src/hud.gd").new()
    root.add_child(hud)
    hud.setup(load("res://src/asset_library.gd").new())
    hud.show_cast()
    var left: BaseButton = hud.overlay.find_child("PrevCharacter", true, false)
    var right: BaseButton = hud.overlay.find_child("NextCharacter", true, false)
    expect(left != null and right != null, "selection retains previous and next controls")
    if left != null and right != null:
        expect(left.get_theme_stylebox("normal") is StyleBoxEmpty and right.get_theme_stylebox("normal") is StyleBoxEmpty, "selector chevrons have no bulky default button boxes")
        expect(left.position.y >= 380 and right.position.y >= 380, "selector arrows sit alongside the count below the character")
    var sheet = hud.overlay.find_child("HanddrawnPaper", true, false)
    expect(sheet != null and sheet.get("opening_mode") == "compose", "character page uses staged composition rather than the Buff roll")
    hud.show_settings(false)
    sheet = hud.overlay.find_child("HanddrawnPaper", true, false)
    expect(sheet != null and sheet.get("opening_mode") == "fold", "settings choose their own fold animation")
    hud.show_choices(["club", "power", "pet"], [], {})
    sheet = hud.overlay.find_child("HanddrawnPaper", true, false)
    expect(sheet != null and sheet.get("opening_mode") == "scroll", "growth retains the physical scroll animation")

    var audited := SoundSpy.new()
    root.add_child(audited)
    audited.setup(load("res://src/asset_library.gd").new())
    audited.show_menu("pause", 0)
    audited.input_lock_until = 0
    audited.veil.finish()
    audited.stats_requested.connect(func(): audited.show_stats({}, load("res://src/growth.gd").stats({})))
    audited.sound_requests.clear()
    var stats_button: Button = audited.overlay.find_child("Stats", true, false)
    stats_button.pressed.emit()
    expect(audited.screen == "stats", "pause attribute button enters the actual attribute page")
    expect(audited.sound_requests == ["paper_popup"], "opening attributes requests one page cue without a layered button sound")
    audited.queue_free()
    hud.queue_free()
    paper.queue_free()
    transition.queue_free()
    await process_frame
    print("UI MOTION RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
