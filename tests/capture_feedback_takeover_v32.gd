extends SceneTree

# Development-only native capture. The real player store is never opened.
const Catalog = preload("res://src/catalog.gd")
const SaveStore = preload("res://src/save_store.gd")
var folder := "D:/Codex/场景建模/独立游戏/原始人大作战_发行准备/feedback_v32_takeover_20261116/native"
var world
var checks := 0
var failures := 0
var marks: Array = []

func _initialize() -> void:
    call_deferred("record")

func expect(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + message)

func frames(count: int = 40) -> void:
    for _index in range(count):
        await process_frame

func button(key: String) -> Button:
    return world.hud.overlay.find_child(key, true, false) as Button

func click(node: Control) -> void:
    expect(node != null, "native click target exists")
    if node == null:
        return
    var waited := 0
    while world.hud.ui_busy() and waited < 120:
        await process_frame
        waited += 1
    expect(not world.hud.ui_busy(), "UI transition completes before native pointer input")
    root.gui_disable_input = false
    var at := node.get_global_rect().get_center()
    var motion := InputEventMouseMotion.new()
    motion.position = at
    motion.global_position = at
    root.push_input(motion, true)
    for pressed in [true, false]:
        var event := InputEventMouseButton.new()
        event.position = at
        event.global_position = at
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = pressed
        root.push_input(event, true)
    root.gui_disable_input = true
    await frames()

func shot(key: String, inspect_buttons: bool = true) -> void:
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    # Keep-aspect mode renders 1152x720 content inside a 1280x720 window,
    # with 64px margins on each side. The texture excludes those margins.
    expect(root.size == Vector2i(1280, 720) and image.get_size() == Vector2i(1152, 720), "720p window preserves the complete 1280x800 canvas: " + key)
    var button_count := 0
    if inspect_buttons:
        for node in world.hud.overlay.find_children("*", "BaseButton", true, false):
            if not node.is_visible_in_tree():
                continue
            var rect: Rect2 = root.get_final_transform() * (node.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, node.size))
            expect(Rect2(-0.5, -0.5, 1281, 721).encloses(rect), "whole 720p button stays on screen: " + key + "/" + node.name)
            button_count += 1
    expect(image.save_png(folder.path_join(key + ".png")) == OK, "saved native screenshot: " + key)
    marks.append({"name": key, "native_size": str(image.get_size()), "visible_buttons": button_count, "logical_viewport": str(root.get_visible_rect()), "final_transform": str(root.get_final_transform())})

func record() -> void:
    DirAccess.make_dir_recursive_absolute(folder)
    Engine.max_fps = 60
    root.gui_disable_input = true
    world = load("res://src/main.gd").new()
    world.save_store = SaveStore.new("res://runtime/tests/native_takeover_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.settings.autosave = false
    world.set_physics_process(false)
    world.music.set_enabled(false)
    root.size = Vector2i(1280, 720)
    await frames(55)
    await shot("home_720p")
    world.hud.show_settings(false)
    await frames()
    for key in ["MusicEnabled", "Autosave"]:
        var toggle: Button = button(key)
        var state: Label = toggle.find_child("SwitchState", false, false) as Label
        expect(state != null and toggle.get_global_rect().encloses(state.get_global_rect()), "switch status remains inside its control: " + key)
    await shot("settings_720p")
    world.hud.close_front_modal()
    world.hud.show_cast()
    await frames()
    var committed: String = world.hud.selected_character
    await click(button("NextCharacter"))
    expect(world.hud.selected_character == committed and world.hud.displayed_character() != committed, "native next click previews without changing the selected character")
    await shot("character_preview_720p")
    # A real pointer press on the original portrait commits just that preview.
    var previewed: String = world.hud.displayed_character()
    var picture: Control
    for node in world.hud.overlay.find_children("*", "Control", true, false):
        if node.tooltip_text == "点击画像确认选择该角色":
            picture = node
            break
    expect(picture != null, "the preview portrait is clickable")
    if picture != null:
        await click(picture)
        expect(world.hud.selected_character == previewed, "portrait input commits the preview")
    world.hud.show_title()
    await frames()
    var inventory: Array = []
    for pair in [["totem", 5], ["powder", 4], ["spear", 3], ["crystal", 2], ["axe", 5], ["staff", 3]]:
        inventory.append({"id": pair[0], "level": pair[1]})
    world.hud.save_summary = {"starting_weapon": "spear", "inventory": inventory, "player_hp": 6.5, "coins": 44, "wave": 3, "player_level": 7, "buff_levels": {}, "character_id": Catalog.CHARACTER_ORDER[1]}
    world.hud.save_available = true
    world.hud.show_continue()
    await frames()
    expect(world.hud.overlay.find_child("SaveHp", true, false).text.contains("6.5"), "save HP retains the decimal")
    await shot("saved_loadout_720p")
    world.hud.close_front_modal()
    world.hud.show_help("gameplay", false)
    await frames()
    await click(button("Stats"))
    expect(world.hud.screen == "stats" and not world.running and not world.trial_mode, "native help attributes click never starts a trial")
    await shot("help_attributes_720p")
    world.toggle_stats()
    expect(world.hud.screen == "help" and not world.running, "closing help attributes returns to help")
    world.start_run(false)
    world.set_physics_process(false)
    world.clear_enemies()
    world.clear_weapons()
    for item in inventory:
        world.grant_weapon(item.id, item.level)
    world.apply_buff("pet")
    world.player_hp = 6.5
    world.coins = 44
    world.wave = 7
    world.update_hud()
    world.update_companions(0.0)
    world.companions.states.pet.position = world.player_position + Vector2(-160, 54)
    world.companions.queue_redraw()
    world.pickups = [{"kind": "blood", "position": world.player_position + Vector2(85, 72), "value": 2.0}, {"kind": "coin", "position": world.player_position + Vector2(115, 85), "value": 1}, {"kind": "xp", "position": world.player_position + Vector2(143, 61), "value": 1}]
    world.spawn_enemy("hunter", world.player_position + Vector2(200, 0), false, "chase")
    world.update_weapons(0.0, false)
    world.queue_redraw()
    await frames(8)
    await shot("battle_feedback_720p", false)
    world.invulnerable = 0.0
    world.stats.dodge = 0.0
    world.hurt_player(Vector2.LEFT, 1.0)
    expect(world.player_hp < 6.5 and world.hurt_flash > 0.0, "the native hurt capture is driven by a real landed hit")
    world.update_hud()
    world.hero.animate(Vector2.ZERO, 0.0, 0.0)
    world.hud.set_hurt_flash(world.hurt_flash)
    world.effects.damage_number(world.player_position + Vector2(200, -80), 18.0, true)
    world.effects.floating_text(world.player_position + Vector2(85, 12), "+2 生命", Color("#b5e4aa"), 23)
    await frames(2)
    await shot("hurt_and_outlined_text_720p", false)
    var file := FileAccess.open(folder.path_join("report.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks": checks, "failures": failures, "screenshots": marks, "real_player_storage_used": false}, "  "))
    file.close()
    world.queue_free()
    await frames(2)
    print("NATIVE TAKEOVER V32 RESULT: %d checks, %d failures; %d screenshots" % [checks, failures, marks.size()])
    quit(1 if failures else 0)
