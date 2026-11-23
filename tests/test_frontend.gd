extends SceneTree

const Catalog = preload("res://src/catalog.gd")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + message)

func find(node: Node, key: String) -> Node:
    if str(node.name) == key:
        return node
    for child in node.get_children():
        var match_node: Node = find(child, key)
        if match_node != null:
            return match_node
    return null

func copy(node: Node) -> String:
    var value: String = node.text + "\n" if node is Label else ""
    for child in node.get_children():
        value += copy(child)
    return value

func visible_copy(node: Node) -> String:
    if node is CanvasItem and not (node as CanvasItem).visible:
        return ""
    var value: String = node.text + "\n" if node is Label else ""
    for child in node.get_children():
        value += visible_copy(child)
    return value

func press(node: Node, key: String) -> void:
    var button = find(node, key)
    expect(button is BaseButton, "visible UI exposes " + key)
    if button is BaseButton and not button.disabled:
        button.pressed.emit()
    await process_frame
    await process_frame

func _initialize() -> void:
    call_deferred("run_checks")

func run_checks() -> void:
    root.size = Vector2i(1280, 800)
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/frontend_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    var hud = world.hud
    expect(hud.screen == "title", "home is the initial screen")
    await press(hud.overlay, "EnterCamp")
    expect(hud.screen == "cast", "Enter Camp goes directly to character selection")
    hud.show_cast()
    for key in ["PrevCharacter", "NextCharacter"]:
        var arrow = find(hud.overlay, key)
        expect(arrow is BaseButton, "character selection keeps a future navigation arrow: " + key)
        if arrow is BaseButton:
            expect(arrow.visible and not arrow.disabled, "multiple hunters keep class arrows available")
    var roster_size: int = Catalog.CHARACTER_ORDER.size()
    var page := func(index: int) -> String: return "%d / %d" % [index, roster_size]
    expect(find(hud.overlay, "StartSling") is BaseButton and find(hud.overlay, "StartClub") is BaseButton and find(hud.overlay, "StartSpear") is BaseButton, "original class confirm buttons are present")
    for confirm_key in ["StartBonebow", "StartStaff", "StartFirepot", "StartTotem"]:
        expect(find(hud.overlay, confirm_key) is BaseButton, "new class confirm button is present: " + confirm_key)
    expect(copy(hud.overlay).contains(page.call(1)) and copy(hud.overlay).contains("原始人") and copy(hud.overlay).contains("弹弓"), "the arrow page shows the default hunter and the page count")
    await press(hud.overlay, "NextCharacter")
    expect(hud.preview_character == "chief" and hud.selected_character == "caveman" and copy(hud.overlay).contains("酋长") and copy(hud.overlay).contains("骨矛") and copy(hud.overlay).contains(page.call(2)), "arrows switch to the chieftain page")
    await press(hud.overlay, "NextCharacter")
    expect(hud.preview_character == "barbarian" and hud.selected_character == "caveman" and copy(hud.overlay).contains("野蛮人") and copy(hud.overlay).contains("木棒") and copy(hud.overlay).contains(page.call(3)), "arrows switch to the barbarian page")
    var turns: int = 0
    while hud.preview_character != "caveman" and turns < roster_size:
        await press(hud.overlay, "NextCharacter")
        turns += 1
    expect(hud.preview_character == "caveman" and hud.selected_character == "caveman" and copy(hud.overlay).contains(page.call(1)), "arrows wrap back to the default hunter")
    await press(hud.overlay, "Settings")
    expect(hud.screen == "settings", "settings open from character select")
    await press(hud.overlay, "Back")
    expect(hud.screen == "cast", "closing settings restores character selection")
    await press(hud.overlay, "Back")
    expect(hud.screen in ["title", "start"], "selection back returns to the home page")

    expect(world.has_method("begin_departure"), "UI start has a separate ready buffer entry point")
    if world.has_method("begin_departure"):
        world.begin_departure(false)
        expect(world.running and world.departure_left >= 2.0, "a confirmed start initializes a protected countdown")
        var before_time: float = world.elapsed
        var before_pos: Vector2 = world.player_position
        var before_hp: float = world.player_hp
        var before_spawn: float = world.spawn_clock
        var before_projectiles: int = world.projectiles.size()
        world.simulate(0.5, Vector2.RIGHT)
        expect(world.elapsed == before_time and world.player_position == before_pos, "countdown freezes the battle timer and movement")
        expect(world.player_hp == before_hp and world.spawn_clock == before_spawn and world.projectiles.size() == before_projectiles, "countdown freezes incoming damage, spawning and attacks")
        var remaining: float = world.departure_left
        world.begin_departure(false)
        expect(is_equal_approx(world.departure_left, remaining), "repeated confirm does not reset or start another departure")
        world.simulate(3.0, Vector2.RIGHT)
        expect(is_zero_approx(world.departure_left) and world.elapsed == before_time, "finishing the countdown does not consume combat time")
        world.simulate(0.1, Vector2.RIGHT)
        expect(world.elapsed > before_time and world.player_position.x > before_pos.x, "battle simulation resumes after readiness")

    world.start_run(false)
    world.wave = 3
    world.coins = 28
    world.player_hp = 6.0
    world.player_level = 4
    expect(world.save_game(), "fixture saves a real isolated journey")
    world.go_home()
    await press(hud.overlay, "ContinueSave")
    expect(hud.screen == "continue" and not world.running, "opening continue previews the save without restoring or starting a run")
    var summary: String = copy(hud.overlay)
    expect(summary.contains("28") and summary.contains("6") and summary.contains("3"), "continue summary reads the real saved wallet, health and stage")
    expect(find(hud.overlay, "ConfirmContinue") is BaseButton, "restoration requires the explicit continue action")
    if find(hud.overlay, "ConfirmContinue") != null:
        await press(hud.overlay, "ConfirmContinue")
        expect(world.running and world.wave == 3 and world.coins == 28, "continue restores the saved journey instead of creating a new one")
        expect(world.departure_left > 0.0, "continued journeys also receive a readiness buffer")

    world.go_home()
    await press(hud.overlay, "ContinueSave")
    world.save_store.write_run(load("res://src/session_state.gd").capture(world, true))
    await press(hud.overlay, "ConfirmContinue")
    expect(not world.running and hud.screen == "continue", "an expired save leaves the preview open without starting a fresh run")
    expect(copy(hud.overlay).contains("没有有效的未结束存档"), "a failed continue explains the stale save visibly")
    var confirm = find(hud.overlay, "ConfirmContinue")
    expect(confirm != null and confirm.disabled, "an expired save disables its stale continue confirmation")

    hud.show_cast()
    await press(hud.overlay, "StartSling")
    expect(hud.screen == "new_save" and not world.running, "character confirmation opens the slot picker before starting the run")
    await press(hud.overlay, "ConfirmNewSave")
    world.simulate(3.0, Vector2.ZERO)
    world.finish_run(false)
    await press(hud.overlay, "StartSling")
    await press(hud.overlay, "ConfirmNewSave")
    expect(world.running and world.departure_left > 0, "a finished UI-started run can start again from defeat")
    world.go_home()

    var choices: Array = []
    var purchases: Array = []
    hud.choice_selected.connect(func(key: String): choices.append(key))
    hud.buy_requested.connect(func(index: int): purchases.append(index))
    hud.show_choices(["club", "power", "pet"], [], {}, "xp", 1)
    hud.input_lock_until = Time.get_ticks_msec() + 1000
    for node in hud.overlay.find_children("*", "Button", true, false):
        if node.text.is_empty():
            node.pressed.emit()
            break
    hud.choose_index(0)
    expect(choices.is_empty(), "growth mouse and number input cannot consume a choice during the paper roll")
    hud.input_lock_until = 0
    hud.choose_index(0)
    expect(choices == ["club"], "growth choice applies immediately after the paper finishes, with no confirm step")
    hud.show_shop([{"id":"sling","price":1,"sold":false}], 10, 1, [], {}, 8, 8)
    hud.input_lock_until = Time.get_ticks_msec() + 1000
    await press(hud.overlay, "ShopOffer0")
    expect(purchases.is_empty(), "shop cards cannot purchase during the paper roll")
    hud.input_lock_until = 0
    await press(hud.overlay, "ShopOffer0")
    expect(purchases == [0], "shop purchase applies immediately after its roll, with no confirm step")

    world.queue_free()
    await process_frame

    var home = load("res://src/main.gd").new()
    home.save_store = load("res://src/save_store.gd").new("res://runtime/tests/frontend_home_" + str(Time.get_ticks_usec()))
    root.add_child(home)
    home.set_physics_process(false)
    var home_hud = home.hud
    home.start_run(false)
    home.spawn_enemy("hunter", home.player_position + Vector2(120, 40))
    home.pickups.append({"kind": "coin", "position": home.player_position + Vector2(40, 40), "value": 1})
    home.chest_marks.append({"position": home.player_position + Vector2(-80, 30), "age": 0.5})
    home.hud.show_shop([{"id":"sling","price":1,"sold":false}], 10, 1, home.inventory, {}, home.player_hp, home.stats["max_hp"], false)
    home.shop_open = true
    expect(home.running and home.hero.visible and home.enemies.size() > 0, "a shop-return fixture starts with a live hunter and leftovers")
    expect(home_hud.screen == "shop", "the fixture is on the shop screen")
    var saved_settings: Dictionary = home.settings.duplicate(true)
    home.go_home()
    await process_frame
    expect(not home.running and not home.shop_open, "returning home leaves the run")
    expect(home_hud.screen in ["title", "start"], "returning home opens the title")
    expect(home_hud.overlay.find_child("HomeStage", true, false) != null, "the title decorative stage is kept")
    expect(find(home_hud.overlay, "EnterCamp") != null, "title actions are present after returning home")
    expect(find(home_hud.overlay, "ShopOffer0") == null, "the shop scroll is not left on the title")
    expect(home.enemies.is_empty() and home.pickups.is_empty() and home.chest_marks.is_empty(), "wave leftovers are cleared before the title")
    expect(home.hero != null and not home.hero.is_visible_in_tree(), "the live hunter is hidden on the title")
    expect(home.actors == null or not home.actors.visible, "combat actors are hidden on the title")
    expect(home.weapons_layer == null or not home.weapons_layer.visible, "equipped weapons are hidden on the title")
    expect(home.map_view == null or not home.map_view.visible, "the combat map is hidden under the title")
    var marker: Node = home.hero.get_node_or_null("PlayerMarker") if home.hero != null else null
    expect(marker == null or not (marker as CanvasItem).is_visible_in_tree(), "the live player marker is not visible on the title")
    expect(home.settings.get("autosave", true) == saved_settings.get("autosave", true), "going home does not wipe settings")

    home_hud.show_cast()
    await process_frame
    expect(copy(home_hud.overlay).contains("选择角色"), "character select still has its title chrome before the snapshot")
    expect(find(home_hud.overlay, "Back") != null and find(home_hud.overlay, "Back").visible, "the back button is visible before the departure snapshot")
    expect(find(home_hud.overlay, "Settings") != null and find(home_hud.overlay, "Settings").visible, "settings stays visible before the departure snapshot")
    var paper_sheet: Node = find(home_hud.overlay, "HanddrawnPaper")
    expect(home_hud.has_method("snapshot_departure_previous"), "departure snapshots go through a chrome-hiding helper")
    var previous: Texture2D = home_hud.snapshot_departure_previous()
    var shown: String = visible_copy(home_hud.overlay)
    var back: Node = find(home_hud.overlay, "Back")
    var settings: Node = find(home_hud.overlay, "Settings")
    var cast_title: Node = find(home_hud.overlay, "CastTitle")
    expect(not shown.contains("选择角色"), "torn-paper snapshot hides the character-select title")
    expect(back != null and not back.visible, "the back button is hidden for the departure snapshot")
    expect(settings != null and not settings.visible, "settings is hidden for the departure snapshot")
    expect(cast_title == null or not (cast_title as CanvasItem).visible, "the cast title label is hidden for the departure snapshot")
    expect(paper_sheet != null and paper_sheet is CanvasItem and (paper_sheet as CanvasItem).visible, "the parchment itself stays in the departure snapshot")
    expect(copy(home_hud.overlay).contains("原始人"), "character details remain in the overlay tree after hiding chrome")
    if home_hud.has_method("restore_front_chrome"):
        home_hud.restore_front_chrome()
        expect(find(home_hud.overlay, "Back").visible and find(home_hud.overlay, "Settings").visible, "chrome can be restored if a start does not begin")
    home.queue_free()
    await process_frame
    var paper = load("res://src/ui_paper.gd").new()
    paper.size = Vector2(772, 620)
    root.add_child(paper)
    expect(paper.has_method("outline"), "paper exposes the same valid outline used for rendering")
    if paper.has_method("outline"):
        for amount in [0.02, 0.15, 0.5, 1.0]:
            paper.reveal = amount
            expect(not Geometry2D.triangulate_polygon(paper.outline()).is_empty(), "unrolling paper has no self-intersecting corner at " + str(amount))
    paper.queue_free()
    await process_frame
    print("FRONTEND RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
