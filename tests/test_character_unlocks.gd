extends SceneTree

const Catalog = preload("res://src/catalog.gd")
const Armory = preload("res://src/armory.gd")
const SaveStore = preload("res://src/save_store.gd")
const Main = preload("res://src/main.gd")

var checks: int = 0
var failures: int = 0
var preview_was: bool = true

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
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

func under_paper(node: Node) -> bool:
    var current: Node = node
    while current != null:
        if str(current.name) == "HanddrawnPaper":
            return true
        current = current.get_parent()
    return false

func readable_ink(node: Label) -> bool:
    if node == null:
        return false
    var color: Color = node.get_theme_color("font_color")
    if color.is_equal_approx(Color("#d7c7ad")) or color.is_equal_approx(Color("#f2e8d2")):
        return false
    return color.r * 0.3 + color.g * 0.59 + color.b * 0.11 < 0.55

func inside_paper(control: Control, sheet: Control) -> bool:
    return control != null and sheet != null and sheet.get_global_rect().grow(-24.0).encloses(control.get_global_rect())

func enemy(id: int, point: Vector2, radius: float = 8.0) -> Dictionary:
    return {"id": id, "position": point, "hp": 1000.0, "radius": radius}

func make_world(suffix: String = "") -> Node:
    var world = Main.new()
    world.save_store = SaveStore.new("res://runtime/tests/character_unlocks_" + suffix + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    return world

func _initialize() -> void:
    preview_was = Catalog.PREVIEW_CHARACTER_UNLOCK
    call_deferred("run_checks")

func run_checks() -> void:
    check_catalog()
    check_unlock_rules()
    check_exclusive_weapons()
    check_spear_interval()
    await check_staff_exclusive()
    await check_select_and_progress()
    Catalog.PREVIEW_CHARACTER_UNLOCK = preview_was
    print("CHARACTER UNLOCKS RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)

func check_catalog() -> void:
    expect(Catalog.CHARACTER_ORDER == ["caveman", "chief", "barbarian", "hunter", "shaman", "firekeeper", "priest"], "new hunters are appended after the original three")
    expect(Catalog.STARTER_WEAPONS.has("bonebow") and Catalog.STARTER_WEAPONS.has("staff") and Catalog.STARTER_WEAPONS.has("firepot") and Catalog.STARTER_WEAPONS.has("totem"), "exclusive starting weapons are valid starter IDs")
    expect(Catalog.PREVIEW_CHARACTER_UNLOCK, "the preview build unlocks later hunters by default")
    var expected := {
        "hunter": ["bonebow", "caveman", 5, "猎手"],
        "shaman": ["staff", "chief", 8, "巫师"],
        "firekeeper": ["firepot", "barbarian", 8, "掌火人"],
        "priest": ["totem", "shaman", 12, "祭祀"]
    }
    for id in expected:
        var profile: Dictionary = Catalog.character(id)
        var row: Array = expected[id]
        expect(str(profile.get("starting_weapon", "")) == row[0] and Catalog.exclusive_weapon_id(id) == row[0], "%s starts with its exclusive weapon" % id)
        expect(str(profile.get("name", "")) == row[3], "%s keeps its display name" % id)
        expect(profile.get("skills", []) is Array and profile["skills"].size() == 2, "%s has two skills" % id)
        var skill_text: String = str(profile["skills"][0].get("description", "")) + str(profile["skills"][1].get("description", ""))
        expect(skill_text.contains(str(Catalog.WEAPONS[row[0]]["name"])) or skill_text.contains("骨弩") or skill_text.contains("魔法杖") or skill_text.contains("火种壶") or skill_text.contains("图腾"), "%s skills mention the exclusive weapon" % id)
        expect(FileAccess.file_exists(str(profile.get("body", ""))), "%s body asset exists" % id)
        expect(FileAccess.file_exists(str(profile.get("portrait", ""))), "%s portrait asset exists" % id)
        var requirement: Dictionary = Catalog.CHARACTER_UNLOCKS[id]
        expect(str(requirement.get("required_character", "")) == row[1] and int(requirement.get("required_wave", 0)) == int(row[2]), "%s unlock requirement is stored" % id)
        expect(Catalog.unlock_requirement_text(id).contains(Catalog.character(row[1]).name) and Catalog.unlock_requirement_text(id).contains(str(row[2])), "%s unlock text names the required hunter and wave" % id)
    for id in Catalog.CHARACTER_ORDER:
        var stats: Dictionary = Catalog.apply_character_modifiers(Main.Growth.stats({}), id)
        expect(is_equal_approx(stats.damage_multiplier, 1.0) and is_zero_approx(stats.close_damage_bonus), id + " relies on talent triggers for bonus damage")
        expect(stats.attack_speed <= 1.04 and stats.reduction <= 0.061, id + " has only small unconditional combat bonuses")
    var heavy_armor: Dictionary = Catalog.apply_character_modifiers(Main.Growth.stats({"armor":100}), "barbarian")
    expect(heavy_armor.reduction <= 1.0, "a passive reduction bonus cannot make stacked armor heal from hits")
    expect(Catalog.exclusive_bonus("hunter", "staff").is_empty() and Catalog.exclusive_bonus("caveman", "bonebow").is_empty(), "mastery only applies to the matching hunter and weapon")

func check_unlock_rules() -> void:
    var empty := {}
    expect(Catalog.is_character_unlocked("caveman", empty) and Catalog.is_character_unlocked("chief", empty) and Catalog.is_character_unlocked("barbarian", empty), "the original three hunters start unlocked")
    expect(not Catalog.is_character_unlocked("hunter", empty) and not Catalog.is_character_unlocked("shaman", empty) and not Catalog.is_character_unlocked("firekeeper", empty) and not Catalog.is_character_unlocked("priest", empty), "later hunters stay locked without official progress")
    expect(not Catalog.is_character_unlocked("hunter", {"caveman": 4}), "dying short of wave 5 does not unlock the hunter")
    expect(Catalog.is_character_unlocked("hunter", {"caveman": 5}), "reaching wave 5 with the caveman unlocks the hunter")
    expect(not Catalog.is_character_unlocked("shaman", {"chief": 7, "caveman": 20}) and Catalog.is_character_unlocked("shaman", {"chief": 8}), "the shaman needs the chieftain to reach wave 8")
    expect(Catalog.is_character_unlocked("firekeeper", {"barbarian": 8}) and not Catalog.is_character_unlocked("firekeeper", {"caveman": 8}), "the firekeeper needs the barbarian, not another hunter")
    expect(not Catalog.is_character_unlocked("priest", {"shaman": 11}) and Catalog.is_character_unlocked("priest", {"shaman": 12}), "the priest unlocks only after the shaman reaches wave 12")
    Catalog.PREVIEW_CHARACTER_UNLOCK = true
    expect(Catalog.can_start_character("priest", empty) and Catalog.shows_preview_unlock("priest", empty), "preview mode can start a locked hunter and marks the early unlock")
    expect(not Catalog.shows_preview_unlock("caveman", empty), "starting hunters do not show a preview-unlock mark")
    Catalog.PREVIEW_CHARACTER_UNLOCK = false
    expect(not Catalog.can_start_character("hunter", empty) and Catalog.can_start_character("hunter", {"caveman": 5}), "official mode starts a later hunter only after its condition is met")
    expect(Catalog.can_start_character("caveman", empty), "official mode still allows the original hunters")
    Catalog.PREVIEW_CHARACTER_UNLOCK = preview_was

func simulate_weapon(armory: Node, views: Dictionary, key: String, seconds: float, targets: Array, stats: Dictionary, level: int = 1) -> Array:
    var events: Array = []
    var remaining: float = seconds
    while remaining > 0.00001:
        var delta: float = minf(1.0 / 120.0, remaining)
        events.append_array(armory.advance(delta, Vector2.ZERO, targets, [{"id": key, "level": level}], stats, false, views))
        remaining -= delta
    return events

func hits(events: Array, target_id: int = -1) -> Array:
    return events.filter(func(event): return event.get("type", "") == "hit" and (target_id == -1 or event["enemy"]["id"] == target_id))

func check_exclusive_weapons() -> void:
    var armory: Node2D = Armory.new()
    root.add_child(armory)
    var views: Dictionary = {}
    for key in ["bonebow", "firepot", "totem"]:
        var view := Sprite2D.new()
        armory.add_child(view)
        views[key] = view
    var line: Array = [enemy(1, Vector2(170, -34)), enemy(2, Vector2(250, -34)), enemy(3, Vector2(330, -34)), enemy(4, Vector2(410, -34)), enemy(5, Vector2(490, -34))]
    armory.reset()
    var base_bow: Array = simulate_weapon(armory, views, "bonebow", 0.6, line, {"attack_speed": 1.0, "character_id": "caveman"})
    expect(hits(base_bow, 1).size() == 1 and hits(base_bow, 2).size() == 1 and hits(base_bow, 3).size() == 1, "a non-hunter bonebow still pierces three enemies")
    expect(hits(base_bow, 4).is_empty() and hits(base_bow, 5).is_empty(), "a non-hunter bonebow does not gain the hunter pierce bonus")
    armory.reset()
    var hunter_bow: Array = simulate_weapon(armory, views, "bonebow", 0.6, line, {"attack_speed": 1.0, "character_id": "hunter"})
    expect(hits(hunter_bow, 4).size() == 1 and hits(hunter_bow, 5).size() == 1, "a hunter bonebow pierces five enemies along the same path")
    armory.reset()
    var far: Array = [enemy(20, Vector2(70.0 + 430.0 + 40.0, -34.0), 16.0)]
    var base_reach: Array = simulate_weapon(armory, views, "bonebow", 0.9, far, {"attack_speed": 1.0, "character_id": "chief"})
    expect(hits(base_reach, 20).is_empty(), "another hunter holding the bonebow keeps the default range")
    armory.reset()
    var hunter_reach: Array = simulate_weapon(armory, views, "bonebow", 0.9, far, {"attack_speed": 1.0, "character_id": "hunter"})
    expect(not hits(hunter_reach, 20).is_empty(), "the hunter bonebow still has a small exclusive reach increase")

    armory.reset()
    var pot_target: Array = [enemy(1, Vector2(150, 0))]
    simulate_weapon(armory, views, "firepot", 0.8, pot_target, {"attack_speed": 1.0, "character_id": "barbarian"})
    var base_fire: Dictionary = armory.states.get("firepot", {}).get("fires", [{}])[0] if not armory.states.get("firepot", {}).get("fires", []).is_empty() else {}
    expect(not base_fire.is_empty() and is_equal_approx(float(base_fire.get("radius", 0.0)), 56.0) and is_equal_approx(float(base_fire.get("life", 0.0)), 1.15), "a non-firekeeper pot keeps the default field")
    var base_damage: float = float(base_fire.get("damage", 0.0))
    armory.reset()
    simulate_weapon(armory, views, "firepot", 0.8, pot_target, {"attack_speed": 1.0, "character_id": "firekeeper"})
    var mastered: Dictionary = armory.states.get("firepot", {}).get("fires", [{}])[0] if not armory.states.get("firepot", {}).get("fires", []).is_empty() else {}
    expect(not mastered.is_empty(), "the firekeeper pot still lands a field")
    if not mastered.is_empty():
        expect(is_equal_approx(float(mastered.get("radius", 0.0)), 56.0 * 1.15), "the firekeeper field is slightly larger")
        expect(is_equal_approx(float(mastered.get("life", 0.0)), 1.15 * 1.35), "the firekeeper field lasts longer")
        expect(is_equal_approx(float(mastered.get("damage", 0.0)), base_damage * 1.03), "the firekeeper gets a small bonus on the ordinary firepot field")

    var chain: Array = [enemy(1, Vector2(90, 0), 20.0), enemy(2, Vector2(140, 0), 20.0), enemy(3, Vector2(190, 0), 20.0), enemy(4, Vector2(240, 0), 20.0), enemy(5, Vector2(290, 0), 20.0)]
    armory.reset()
    var base_totem: Array = armory.advance(0.02, Vector2.ZERO, chain, [{"id": "totem", "level": 1}], {"attack_speed": 1.0, "character_id": "chief"}, false, views)
    var base_hits: Array = hits(base_totem)
    expect(base_hits.size() == 3, "another hunter's totem still chains through three enemies")
    armory.reset()
    var priest_totem: Array = armory.advance(0.02, Vector2.ZERO, chain, [{"id": "totem", "level": 1}], {"attack_speed": 1.0, "character_id": "priest"}, false, views)
    var priest_hits: Array = hits(priest_totem)
    expect(priest_hits.size() == 5, "the priest totem chains through five enemies")
    if priest_hits.size() >= 2 and base_hits.size() >= 2:
        expect(is_equal_approx(priest_hits[1]["damage"] / priest_hits[0]["damage"], 0.80), "the priest keeps a modest chain decay advantage")
        expect(is_equal_approx(base_hits[1]["damage"] / base_hits[0]["damage"], 0.75), "non-priest chain decay stays at the default")
    armory.queue_free()

func check_spear_interval() -> void:
    var armory = load("res://src/armory.gd").new()
    root.add_child(armory)
    var view := Sprite2D.new()
    armory.add_child(view)
    var stats: Dictionary = Catalog.apply_character_modifiers(Main.Growth.stats({}), "chief")
    var casts: Array[float] = []
    for step in range(200):
        for event in armory.advance(1.0 / 240.0, Vector2.ZERO, [enemy(1, Vector2(90, 0))], [{"id":"spear","level":1}], stats, false, {"spear":view}):
            if event.type == "flash":
                casts.append(step / 240.0)
    expect(casts.size() == 2 and absf(casts[1] - casts[0] - 0.54 / 1.04) < 0.005, "an unbuffed chief's real spear casts are about 0.52 seconds apart")
    armory.queue_free()

func check_staff_exclusive() -> void:
    var shaman = make_world("staff_shaman_")
    shaman.demo = true
    shaman.character_id = "shaman"
    shaman.starting_weapon = "staff"
    shaman.start_run(false)
    shaman.spawn_enemy("tank", shaman.player_position + Vector2(180, 0), false, "idle")
    if shaman.weapon_runtime.has("staff"):
        shaman.weapon_runtime["staff"]["cooldown"] = 0.0
    shaman.simulate(0.05, Vector2.ZERO)
    var shaman_shots: Array = shaman.projectiles.filter(func(shot): return str(shot.get("kind", "")) == "staff")
    expect(shaman_shots.size() == 5, "a shaman staff volley launches five runes")
    if not shaman_shots.is_empty():
        expect(is_equal_approx(float(shaman_shots[0].get("damage", 0.0)), Catalog.WEAPONS["staff"]["damage"] * 0.92 * 1.03), "the shaman gets a small bonus to staff projectiles")
        expect(is_equal_approx(float(shaman_shots[0].get("homing", 0.0)), 1.6), "shaman staff runes carry slight tracking")
    shaman.queue_free()
    await process_frame

    var other = make_world("staff_chief_")
    other.demo = true
    other.character_id = "chief"
    other.starting_weapon = "spear"
    other.start_run(false)
    other.clear_weapons()
    other.grant_weapon("staff")
    if other.weapon_runtime.has("staff"):
        other.weapon_runtime["staff"]["cooldown"] = 0.0
    other.spawn_enemy("tank", other.player_position + Vector2(180, 0), false, "idle")
    other.simulate(0.05, Vector2.ZERO)
    var other_shots: Array = other.projectiles.filter(func(shot): return str(shot.get("kind", "")) == "staff")
    expect(other_shots.size() == 3, "a non-shaman staff still launches three runes")
    if not other_shots.is_empty():
        expect(is_equal_approx(float(other_shots[0].get("damage", 0.0)), Catalog.WEAPONS["staff"]["damage"] * 0.92), "a non-shaman staff keeps the default rune damage")
        expect(is_equal_approx(float(other_shots[0].get("homing", 0.0)), 0.0), "a non-shaman staff does not gain exclusive tracking")
    other.queue_free()
    await process_frame

func check_select_and_progress() -> void:
    var world = make_world("select_")
    if world.hud.start_requested.is_connected(world.show_departure_slot_picker):
        world.hud.start_requested.disconnect(world.show_departure_slot_picker)
    var hud = world.hud
    var events: Array = []
    hud.starter_selected.connect(func(key: String): events.append(["starter", key]))
    hud.start_requested.connect(func(trial: bool): events.append(["start", trial]))
    Catalog.PREVIEW_CHARACTER_UNLOCK = true
    hud.character_best_wave = {}
    hud.show_cast()
    await process_frame
    hud.change_character(1)
    hud.change_character(1)
    hud.change_character(1)
    await process_frame
    expect(hud.preview_character == "hunter", "arrows reach the hunter preview")
    var preview_text: String = copy(hud.overlay)
    expect(preview_text.contains("猎手") and preview_text.contains("骨弩") and preview_text.contains("试玩提前解锁"), "preview mode marks a formally locked hunter")
    var preview_note: Label = find(hud.overlay, "UnlockNote") as Label
    var preview_condition: Label = find(hud.overlay, "UnlockCondition") as Label
    expect(preview_note != null and preview_condition != null, "preview mode shows both the preview mark and the official condition")
    expect(under_paper(preview_note) and under_paper(preview_condition), "preview unlock labels sit inside the parchment, not on the tear")
    expect(readable_ink(preview_note) and readable_ink(preview_condition), "preview unlock labels use dark ink with contrast on the parchment")
    for character in ["hunter", "shaman", "firekeeper", "priest"]:
        hud.preview_character = character
        hud.show_cast("ui_open", true)
        await process_frame
        var sheet: Control = find(hud.overlay, "HanddrawnPaper") as Control
        var badge: Label = find(hud.overlay, "UnlockNote") as Label
        var requirement: Label = find(hud.overlay, "UnlockCondition") as Label
        expect(inside_paper(badge, sheet) and inside_paper(requirement, sheet) and badge.get_global_rect().position.y < sheet.get_global_rect().get_center().y, character + " keeps both preview labels inside the upper parchment margin")
    hud.preview_character = "hunter"
    hud.show_cast("ui_open", true)
    await process_frame
    expect(preview_text.contains("用原始人到达第 5 关解锁"), "preview mode still shows the official hunter condition")
    var confirm: BaseButton = find(hud.overlay, "StartBonebow")
    expect(confirm != null and confirm.visible and not confirm.disabled, "preview mode still allows confirming a formally locked hunter")
    events.clear()
    if confirm != null:
        confirm.pressed.emit()
        await process_frame
    expect(events == [["starter", "bonebow"], ["start", false]], "preview confirmation starts the hunter")

    Catalog.PREVIEW_CHARACTER_UNLOCK = false
    hud.launch_committed = false
    hud.character_best_wave = {}
    hud.selected_character = "caveman"
    hud.preview_character = "hunter"
    if world.has_method("go_home"):
        world.running = false
        world.departure_left = 0.0
    hud.show_cast("ui_open", true)
    await process_frame
    var locked_text: String = copy(hud.overlay)
    expect(locked_text.contains("用原始人到达第 5 关解锁") and not locked_text.contains("试玩提前解锁"), "official mode shows the hunter unlock condition")
    var locked_note: Label = find(hud.overlay, "UnlockNote") as Label
    expect(locked_note != null and under_paper(locked_note) and readable_ink(locked_note), "official unlock condition sits inside the parchment in dark ink")
    expect(find(hud.overlay, "UnlockCondition") == null, "official mode does not add a separate preview condition label")
    confirm = find(hud.overlay, "StartBonebow")
    expect(confirm != null and confirm.disabled, "official mode disables confirm for a locked hunter")
    events.clear()
    hud.confirm_cast("bonebow")
    await process_frame
    expect(events.is_empty() and not world.running, "locked confirmation cannot start a run")

    hud.character_best_wave = {"caveman": 5}
    hud.preview_character = "hunter"
    hud.show_cast("ui_open", true)
    await process_frame
    confirm = find(hud.overlay, "StartBonebow")
    expect(confirm != null and not confirm.disabled and not copy(hud.overlay).contains("试玩提前解锁"), "meeting the formal condition enables the hunter without a preview mark")

    world.demo = false
    world.trial_mode = false
    world.character_id = "caveman"
    world.starting_weapon = "sling"
    world.start_run(false)
    expect(int(world.settings.get("character_best_wave", {}).get("caveman", 0)) >= 1, "an official run records the starting wave")
    world.begin_round(5)
    expect(int(world.settings.get("character_best_wave", {}).get("caveman", 0)) == 5, "entering wave 5 records that progress for the current hunter")
    var official_store = world.save_store
    var saved: Dictionary = official_store.read_settings()
    expect(int(saved.get("character_best_wave", {}).get("caveman", 0)) == 5, "official wave progress is written to settings")
    world.queue_free()
    await process_frame

    var trial = make_world("trial_")
    trial.character_id = "caveman"
    trial.start_run(true)
    trial.begin_round(5)
    expect(trial.settings.get("character_best_wave", {}).is_empty() or int(trial.settings.get("character_best_wave", {}).get("caveman", 0)) == 0, "trial mode does not write hunter unlock progress")
    trial.queue_free()
    await process_frame

    var demo = make_world("demo_")
    demo.demo = true
    demo.character_id = "chief"
    demo.start_run(false)
    demo.begin_round(8)
    expect(int(demo.settings.get("character_best_wave", {}).get("chief", 0)) == 0, "demo mode does not write hunter unlock progress")
    demo.queue_free()
    await process_frame
    Catalog.PREVIEW_CHARACTER_UNLOCK = preview_was
