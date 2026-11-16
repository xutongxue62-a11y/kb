extends SceneTree

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
    root.size = Vector2i(1280, 800)
    var hud = load("res://src/hud.gd").new()
    root.add_child(hud)
    hud.setup(load("res://src/asset_library.gd").new())
    hud.show_title()
    for key in ["EnterCamp", "ContinueSave", "HelpGameplay", "Settings"]:
        var button: Button = hud.overlay.find_child(key, true, false)
        expect(button != null and button.get_meta("home_paper_action", false), "home uses a paper-shaped action: " + key)
        if button == null: continue
        expect(button.find_child("InkFeedback", false, false) == null, "home hover does not add old corner/underline chrome: " + key)
        expect(button.get_theme_stylebox("normal") is StyleBoxEmpty and button.get_theme_stylebox("focus") is StyleBoxEmpty, "native square button boxes are absent: " + key)
        if button.has_method("paper_outline"):
            var outline: PackedVector2Array = button.paper_outline()
            expect(not Geometry2D.triangulate_polygon(outline).is_empty(), "torn paper silhouette is drawable: " + key)
            expect(not button._has_point(Vector2(1, 1)) and button._has_point(button.size * 0.5), "hit area follows the slanted paper: " + key)
    var stage = hud.overlay.find_child("HomeStage", true, false)
    expect(stage != null and stage.has_method("advance_visual"), "home contains a live visual stage")
    if stage != null and stage.has_method("advance_visual"):
        expect(stage.weapons.size() == 6 and stage.critters.size() >= 4, "all six real weapons and surrounding monsters are present")
        var old_weapon: Vector2 = stage.weapons[0].position
        var old_monster: Vector2 = stage.critters[0].sprite.position
        stage.advance_visual(0.8)
        expect(stage.weapons[0].position.distance_to(old_weapon) > 30, "home weapons visibly orbit across time")
        expect(stage.critters[0].sprite.position.distance_to(old_monster) > 3, "home monsters move independently")
        expect(stage.hero.idle_time > 0.0, "home actor has actual breathing animation")
    var button: Button = hud.overlay.find_child("EnterCamp", true, false)
    button.pressed.emit()
    expect(hud.screen == "cast", "new paper action still opens character selection")
    expect(hud.overlay.find_child("HomeStage", true, false) == null, "the live stage is removed on leaving home")
    var cast_back: Button = hud.overlay.find_child("Back", true, false)
    expect(not cast_back.get_meta("home_paper_action", false), "other screen layouts are kept for the later UI pass")
    hud.queue_free()
    await process_frame
    print("HOME_V09 RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
