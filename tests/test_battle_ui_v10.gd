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
    hud.hide_menu()
    expect(hud.hp_bar.get_global_rect().end.x < 350 and hud.hp_bar.get_global_rect().position.y < 100, "health is a compact top-left meter")
    expect(hud.xp_bar.get_global_rect().end.x < 350 and hud.xp_bar.get_global_rect().position.y < 140, "experience shares the top-left status paper")
    expect(hud.status_strip.has_method("paper_outline") and hud.status_strip.size.x < 350, "status no longer spans a hard rectangular row")
    expect(hud.root.find_child("DodgeStatus", true, false) != null, "Shift readiness is visible in battle")
    expect(hud.has_method("configure_music"), "settings expose a separate persisted music preference")
    hud.show_settings(true)
    expect(hud.overlay.find_child("MusicEnabled", true, false) is BaseButton, "music has an actual settings toggle")
    hud.queue_free()
    await process_frame
    print("BATTLE_UI_V10 RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
