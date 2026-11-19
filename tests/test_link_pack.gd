extends SceneTree

const Catalog = preload("res://src/catalog.gd")
const KeyBindings = preload("res://src/key_bindings.gd")

var checks: int = 0
var failures: int = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func overlay_text(node: Node) -> String:
    var value: String = ""
    if node is Label or node is Button or node is LinkButton:
        value += str(node.text) + "\n"
    if node is RichTextLabel:
        value += str(node.get_parsed_text()) + "\n"
    for child in node.get_children():
        value += overlay_text(child)
    return value

func make_world(suffix: String):
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/link_pack_%s_%s" % [suffix, str(Time.get_ticks_usec())])
    root.add_child(world)
    world.set_physics_process(false)
    world.demo = false
    world.animation_demo = false
    return world

func press_key(world, code: int) -> void:
    var event := InputEventKey.new()
    event.pressed = true
    event.echo = false
    event.physical_keycode = code
    event.keycode = code
    world._unhandled_key_input(event)

func pack(world):
    return world.hud.link_pack if world.hud != null else null

func _initialize() -> void:
    call_deferred("run_checks")

func run_checks() -> void:
    root.size = Vector2i(1280, 800)
    await check_open_close_and_no_cycle()
    await check_drop_unlink_error_and_swap()
    await check_attributes_and_freeze()
    await check_discovery_still_works()
    await check_help_and_hints()
    await check_blocked_screens()
    print("LINK PACK RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)

func check_open_close_and_no_cycle() -> void:
    var world = make_world("toggle")
    world.start_run(true)
    expect(world.active_link["id"] == "none", "trial still starts without a forced link")
    expect(not world.link_pack_open, "pack starts closed")
    var first_id: String = str(world.active_link["id"])
    press_key(world, KeyBindings.code_of("link"))
    expect(world.link_pack_open and world.hud.screen == "link_pack", "Q / link opens the weapon pack")
    expect(world.active_link["id"] == first_id, "opening the pack does not cycle recipes")
    expect(pack(world) != null and pack(world).is_open(), "pack UI is present after Q")
    press_key(world, KeyBindings.code_of("link"))
    expect(not world.link_pack_open and world.hud.screen == "combat", "Q closes the pack")
    expect(world.active_link["id"] == first_id, "closing the pack still does not cycle recipes")
    expect(world.open_link_pack(), "open_link_pack can open again")
    press_key(world, KeyBindings.code_of("cancel"))
    expect(not world.link_pack_open and not world.paused, "Esc closes the pack and does not pause")
    world.open_link_pack()
    expect(world.hud.overlay.find_child("CloseLinkPack", true, false) != null, "pack has a close button")
    world.hud.request_close_link_pack()
    expect(not world.link_pack_open, "the close button path dismisses the pack")
    world.switch_combo_mode()
    expect(world.link_pack_open and world.active_link["id"] == "none", "old cycle entry now toggles the pack instead")
    world.close_link_pack()
    world.queue_free()
    await process_frame

func check_drop_unlink_error_and_swap() -> void:
    var world = make_world("drop")
    world.start_run(true)
    expect(world.open_link_pack(), "pack opens over a six-weapon trial")
    var ui = pack(world)
    var ids: Array = ui.weapon_ids()
    expect(ids.has("powder") and ids.has("staff") and ids.has("axe") and ids.has("club"), "pack lists owned weapons as nodes")
    var before: String = str(world.active_link["id"])
    var bad: Dictionary = ui.try_drop("club", "staff")
    expect(not bad.get("ok", true) and str(bad.get("error", "")).contains("这两件武器不能联动"), "incompatible drop returns a clear error")
    expect(ui.error_text().contains("这两件武器不能联动"), "incompatible drop is shown in the pack")
    expect(world.active_link["id"] == before, "incompatible drop leaves the current link unchanged")
    var good: Dictionary = ui.try_drop("powder", "staff")
    expect(good.get("ok", false) and str(good.get("link_id", "")) == "rune_shell", "compatible drop enables the catalog recipe")
    expect(world.active_link["id"] == "rune_shell", "select_link applied 魔法炮")
    var copy: String = ui.displayed_text()
    expect(copy.contains("魔法炮") and copy.contains("优点") and copy.contains("缺点"), "linked cluster shows the recipe name with benefit and cost")
    expect(copy.contains(Catalog.benefit_text(Catalog.LINKS["rune_shell"])) and copy.contains(Catalog.cost_text(Catalog.LINKS["rune_shell"])), "pack shows the official benefit and cost copy")
    var still_bad: Dictionary = ui.try_drop("club", "rune_shell")
    expect(not still_bad.get("ok", true) and world.active_link["id"] == "rune_shell", "dropping a nonsense id does not break an existing link")
    var invalid_on_linked: Dictionary = ui.try_drop("sling", "powder")
    expect(not invalid_on_linked.get("ok", true) and world.active_link["id"] == "rune_shell", "incompatible drop onto a linked weapon keeps the old link")
    expect(ui.error_text().contains("这两件武器不能联动"), "invalid drop onto a linked card still reports the error")
    var swapped: Dictionary = ui.try_drop("powder", "axe")
    expect(swapped.get("ok", false) and world.active_link["id"] == "chain_axe", "dragging a linked weapon onto another compatible partner swaps the link")
    expect(str(swapped.get("toast", "")).contains("魔法炮") and str(swapped.get("toast", "")).contains("锁链石斧"), "swap toast names the old and new recipes")
    var unlinked: Dictionary = ui.try_unlink("axe")
    expect(unlinked.get("ok", false) and world.active_link["id"] == "none", "drag-apart / try_unlink returns to 不联动")
    expect(str(unlinked.get("toast", "")).contains("断开") or ui.toast_text().contains("断开"), "unlinking explains that the pair was disconnected")
    var again: Dictionary = ui.try_drop("staff", "powder")
    expect(again.get("ok", false) and world.active_link["id"] == "rune_shell", "pair order does not matter when forming a recipe")
    world.close_link_pack()
    world.queue_free()
    await process_frame

func check_attributes_and_freeze() -> void:
    var world = make_world("attrs")
    world.start_run(true)
    var started: float = world.elapsed
    var origin: Vector2 = world.player_position
    world.simulate(0.25, Vector2.RIGHT)
    expect(world.elapsed > started and world.player_position.x > origin.x, "combat still advances when the pack is closed")
    expect(world.open_link_pack(), "pack can open during combat")
    expect(world.player_frozen and world.link_pack_open, "opening the pack freezes the run")
    var frozen_time: float = world.elapsed
    var frozen_pos: Vector2 = world.player_position
    world.simulate(0.5, Vector2.LEFT)
    expect(is_equal_approx(world.elapsed, frozen_time) and world.player_position == frozen_pos, "the pack freezes battle time and movement")
    expect(not world.request_dodge(Vector2.RIGHT), "dodge is blocked while the pack is open")
    var ui = pack(world)
    var info: Dictionary = ui.node_info("powder")
    expect(str(info.get("name", "")).contains("火药") or str(info.get("name", "")).contains("筒"), "each node shows the weapon name")
    expect(str(info.get("stats", "")).contains("伤害") and str(info.get("stats", "")).contains("间隔"), "each node shows key combat stats")
    var text: String = ui.displayed_text()
    expect(text.contains("武器背包") and text.contains("拖"), "pack chrome explains drag-to-link")
    expect(ui.valid_drop_targets("powder").has("staff") and not ui.valid_drop_targets("powder").has("sling"), "only catalog-compatible weapons are valid drop targets")
    world.close_link_pack()
    expect(not world.link_pack_open and not world.player_frozen, "closing the pack unfreezes combat")
    var resumed: float = world.elapsed
    world.simulate(0.2, Vector2.ZERO)
    expect(world.elapsed > resumed, "combat resumes after the pack closes")
    world.queue_free()
    await process_frame

func check_discovery_still_works() -> void:
    var world = make_world("discover")
    world.start_run(false)
    expect(world.active_link["id"] == "none", "a normal run still defaults to 不联动")
    expect(world.pending_link_notice.size() > 0, "starter weapon still queues unseen recipes")
    expect(world.open_link_pack() and world.link_pack_open, "the pack can open in combat before a discovery parchment")
    world.close_link_pack()
    expect(not world.link_pack_open, "the pack closes before the discovery parchment is shown")
    var shown: bool = world.try_present_link_discovery()
    expect(shown and world.link_notice_open and world.hud.screen == "link_discover", "first-acquire parchment still appears")
    expect(world.active_link["id"] == "none", "discovery still does not auto-enable a link")
    expect(not world.open_link_pack() and not world.link_pack_open, "Q does not open the pack over the discovery parchment")
    var body: String = overlay_text(world.hud.overlay)
    expect(body.contains("优点") and body.contains("缺点"), "discovery still lists benefit and cost")
    world.hud.cancel_link_discovery()
    expect(not world.link_notice_open and world.active_link["id"] == "none", "declining discovery still leaves 不联动")
    world.queue_free()
    await process_frame

func check_help_and_hints() -> void:
    var world = make_world("help")
    world.start_run(true)
    var hint: String = world.link_hint_text()
    expect(hint.contains("背包") and hint.contains("拖"), "bottom hint teaches the backpack drag")
    expect(not hint.contains("按 Q 切换") and not hint.contains("按 %s 切换" % KeyBindings.caption_for("link")) and not hint.contains("切换（当前"), "bottom hint no longer talks about Q cycling")
    world.hud.show_help("gameplay", true)
    var gameplay: String = overlay_text(world.hud.overlay)
    expect(gameplay.contains("武器背包") and gameplay.contains("拖到一起"), "gameplay help opens the pack and explains dragging")
    expect(not gameplay.contains("切换联动"), "gameplay help no longer says Q cycles recipes")
    world.hud.show_help("keys", true)
    var keys: String = overlay_text(world.hud.overlay)
    expect(keys.contains("打开武器背包"), "keys help says the link key opens the pack")
    expect(not keys.contains("切换武器联动"), "keys help no longer says the link key cycles recipes")
    world.hud.show_help("links", true)
    var links: String = overlay_text(world.hud.overlay)
    expect(links.contains("火药筒") and links.contains("炮口") and links.contains("武器背包"), "link help still teaches cannon-muzzle chains and now the pack")
    expect(links.contains("拖到一起") and links.contains("拖开") and links.contains("这两件武器不能联动"), "link help explains drag-to-link, drag-apart, and the error")
    expect(not links.contains("在「不联动」和联动之间切换") and not links.contains("可用 %s 切换或关闭" % KeyBindings.caption_for("link")), "link help no longer describes Q cycling")
    world.hud.hide_menu()
    world.close_link_pack()
    world.queue_free()
    await process_frame

func check_blocked_screens() -> void:
    var world = make_world("blocked")
    expect(not world.open_link_pack() and not world.link_pack_open, "the pack does not open on the title screen")
    world.start_run(true)
    world.toggle_pause()
    expect(world.paused and world.hud.screen == "pause", "pause menu is available")
    expect(not world.open_link_pack() and not world.link_pack_open, "the pack does not open over the pause menu")
    world.toggle_pause()
    world.shop_open = true
    world.player_frozen = true
    world.hud.show_shop([{"id": "heal", "price": 1, "level": 1}], 10, 1, world.inventory, {}, world.player_hp, world.stats["max_hp"], false)
    expect(not world.open_link_pack() and world.hud.screen == "shop", "the pack does not open over the shop")
    world.shop_open = false
    world.hud.hide_menu()
    world.player_frozen = false
    expect(world.open_link_pack(), "pack opens again in combat")
    world.open_round_shop()
    expect(not world.link_pack_open and world.shop_open, "opening the shop dismisses the pack first")
    world.queue_free()
    await process_frame
