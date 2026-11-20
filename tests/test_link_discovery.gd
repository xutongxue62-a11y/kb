extends SceneTree

const Catalog = preload("res://src/catalog.gd")

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
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/link_discovery_%s_%s" % [suffix, str(Time.get_ticks_usec())])
    root.add_child(world)
    world.set_physics_process(false)
    world.demo = false
    world.animation_demo = false
    return world

func _initialize() -> void:
    call_deferred("run_checks")

func run_checks() -> void:
    root.size = Vector2i(1280, 800)
    check_catalog_helpers()
    await check_discovery_flow()
    await check_old_settings()
    print("LINK DISCOVERY RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures > 0 else 0)

func check_catalog_helpers() -> void:
    expect(Catalog.LINKS["rune_shell"]["name"] == "魔法炮", "rune_shell display name is 魔法炮")
    expect(Catalog.LINKS["fire_cannon"]["weapons"] == ["firepot", "powder"], "flame cannon is firepot plus powder")
    expect(Catalog.LINKS["rune_arrow"]["weapons"] == ["staff", "bonebow"], "rune arrow is staff plus bonebow")
    expect(Catalog.LINKS["fire_axe"]["name"] == "焚石斧" and Catalog.LINKS["fire_blade"]["name"] == "燃骨刃", "missing fire recipes on axe and blade are named")
    expect(Catalog.LINKS["rune_hammer"]["name"] == "符能重砸" and Catalog.LINKS["rune_axe"]["name"] == "符能石斧", "staff hammer and axe recipes are named")
    expect(Catalog.LINKS["thunder_shell"]["name"] == "导雷火炮" and Catalog.LINKS["thunder_sling"]["name"] == "导雷石弹", "totem cannon and sling recipes are named")
    expect(Catalog.LINKS["thunder_hammer"]["name"] == "引雷重砸" and Catalog.LINKS["thunder_axe"]["name"] == "引雷石斧" and Catalog.LINKS["thunder_blade"]["name"] == "引雷骨刃", "totem hammer, axe, and blade recipes are named")
    for key in Catalog.LINK_ORDER:
        var recipe: Dictionary = Catalog.LINKS[key]
        expect(recipe["weapons"].size() == 0 or recipe["weapons"].size() == 2, "every catalog recipe stays pairwise: " + key)
        expect(str(recipe.get("benefit", "")) != "" and str(recipe.get("cost", "")) != "", "every recipe publishes benefit and cost: " + key)
        if key != "none":
            expect(str(recipe.get("benefit", "")).length() >= 8 and str(recipe.get("cost", "")).length() >= 8, "benefit and cost stay uncut official sentences: " + key)
    var sling_recipes: Array = Catalog.recipes_for_weapon("sling")
    var sling_names: Array = []
    for recipe in sling_recipes:
        sling_names.append(recipe["id"])
    expect(sling_names.has("fire_sling") and sling_names.has("rune_sling") and sling_names.has("thunder_sling"), "sling lists fire, rune, and thunder attachments")
    var offer: String = Catalog.offer_link_text("firepot", ["powder"])
    expect(offer.contains("可联动：") and offer.contains("烈焰火炮") and offer.contains("优点") and offer.contains("缺点"), "shop text marks a completing pair with benefit and cost")
    var waiting: String = Catalog.offer_link_text("firepot", [])
    expect(waiting.contains("可与") and (waiting.contains("木质火药筒") or waiting.contains("火药筒") or waiting.contains("弹弓")), "incomplete offers name the missing partner")
    expect(Catalog.offer_link_text("firepot", ["firepot"]).is_empty(), "upgrading an already-owned weapon is not treated as completing a pair")
    var details: String = Catalog.link_details_text("staff")
    expect(details.contains("魔法炮") and details.contains("符能石斧") and details.contains("优点") and details.contains("缺点"), "weapon details list partners with benefit and cost")
    var fire_details: String = Catalog.link_details_text("firepot")
    expect(fire_details.contains("焚石斧") and fire_details.contains("燃骨刃") and fire_details.contains("烈焰火炮"), "firepot details include the completed host list")
    var totem_details: String = Catalog.link_details_text("totem")
    expect(totem_details.contains("导雷火炮") and totem_details.contains("引雷石斧") and totem_details.contains("导雷骨箭"), "totem details include old and new thunder recipes")

func check_discovery_flow() -> void:
    var world = make_world("starter")
    world.start_run(false)
    expect(world.active_link["id"] == "none", "a new run still defaults to no link")
    expect(Catalog.inventory_ids(world.inventory).has(world.starting_weapon), "the starter weapon is in the inventory")
    expect(world.pending_link_notice.is_empty(), "starting weapon does not queue recipes whose partners are missing")
    expect(not world.try_present_link_discovery() and not world.link_notice_open, "no discovery parchment appears for incomplete starter recipes")
    world.queue_link_discovery(world.starting_weapon)
    expect(world.pending_link_notice.is_empty(), "re-queuing the starter still ignores incomplete recipes")
    world.queue_free()
    await process_frame

    world = make_world("complete")
    world.start_run(false)
    expect(world.grant_weapon("firepot"), "firepot can be granted to complete a sling recipe")
    expect(world.pending_link_notice.size() == 1 and str(world.pending_link_notice[0].get("id", "")) == "fire_sling", "only the completing sling recipe is queued")
    var shown: bool = world.try_present_link_discovery()
    expect(shown and world.link_notice_open, "first acquire of a partnering weapon shows the parchment")
    await process_frame
    await process_frame
    var body: String = overlay_text(world.hud.overlay)
    expect(body.contains("燃石弹") and body.contains("优点") and body.contains("缺点") and body.contains("现在可启用"), "completing a pair lists the link with benefit, cost, and an enable status")
    expect(body.contains("启用") and body.contains("先不用"), "a complete pair offers enable and decline")
    expect(not body.contains("还差"), "the notice does not list recipes whose partners are still missing")
    expect(world.active_link["id"] == "none", "completing a pair does not auto-enable")
    world.hud.cancel_link_discovery()
    expect(not world.link_notice_open and world.active_link["id"] == "none", "declining leaves the link at 不联动")
    var seen: Array = world.settings.get("seen_link_recipes", [])
    expect(seen.has("fire_sling"), "dismissing marks the shown completing recipe as seen")
    world.pending_link_notice.clear()
    world.queue_link_discovery("firepot")
    expect(world.pending_link_notice.is_empty() and not world.try_present_link_discovery(), "seen flag prevents the same completing recipe from showing again")
    world.queue_free()
    await process_frame

    world = make_world("enable")
    world.start_run(false)
    expect(world.grant_weapon("staff"), "staff can be granted to complete a rune sling recipe")
    shown = world.try_present_link_discovery()
    expect(shown and world.link_notice_open, "a completed rune recipe is offered once")
    await process_frame
    await process_frame
    body = overlay_text(world.hud.overlay)
    expect(body.contains("符能弹") and body.contains("启用"), "the enable option names the completed rune recipe")
    world.hud.confirm_link_discovery()
    expect(not world.link_notice_open and world.active_link["id"] == "rune_sling", "enabling selects the completed link")
    world.queue_free()
    await process_frame

    world = make_world("batch")
    world.start_run(false)
    for key in ["club", "axe", "blade", "spear"]:
        expect(world.grant_weapon(key), "batch fixture can add " + key)
    world.pending_link_notice.clear()
    expect(world.grant_weapon("staff"), "staff completes several recipes at once")
    var queued_ids: Array = []
    for recipe in world.pending_link_notice:
        queued_ids.append(str(recipe.get("id", "")))
    expect(queued_ids.size() >= 4, "staff plus several owned hosts queues more than three completing recipes")
    expect(not queued_ids.any(func(link_id): return not Catalog.recipe_complete(Catalog.LINKS[link_id], Catalog.inventory_ids(world.inventory))), "queued recipes all have both partners in the pack")
    shown = world.try_present_link_discovery()
    expect(shown and world.link_notice_open, "a large completing batch still opens one parchment")
    await process_frame
    await process_frame
    expect(world.hud.link_discovery_recipes().size() == 3, "one parchment shows at most three recipes")
    expect(world.pending_link_notice.size() == queued_ids.size() - 3, "recipes beyond the first three stay queued")
    body = overlay_text(world.hud.overlay)
    expect(not body.contains("还差"), "the capped parchment still omits incomplete recipes")
    world.hud.cancel_link_discovery()
    world.queue_free()
    await process_frame

    world = make_world("shop")
    world.start_run(false)
    expect(world.grant_weapon("firepot"), "shop fixture owns firepot")
    world.hud.show_shop([{"id": "powder", "price": 10, "level": 1}], 100, 2, world.inventory, {}, world.player_hp, world.stats["max_hp"], false)
    await process_frame
    await process_frame
    var shop_copy: String = overlay_text(world.hud.overlay)
    var shop_mark: String = Catalog.offer_link_text("powder", Catalog.inventory_ids(world.inventory))
    expect(shop_mark.contains("可联动：") and shop_copy.contains("可联动：") and shop_copy.contains("烈焰火炮"), "shop offer text marks a completing pair")
    expect(shop_copy.contains("优点") and shop_copy.contains("缺点"), "shop completing badge includes short benefit and cost")
    world.queue_free()
    await process_frame

func check_old_settings() -> void:
    var store = load("res://src/save_store.gd").new("res://runtime/tests/link_discovery_old_%s" % str(Time.get_ticks_usec()))
    expect(store.write_settings({"autosave": true, "music_enabled": true, "seen_link_guide": false}).get("ok", false), "old settings without seen_link_recipes are valid")
    var loaded: Dictionary = store.read_settings()
    expect(not loaded.has("seen_link_recipes"), "old settings do not invent a seen_link_recipes list")
    var world = make_world("old")
    world.settings = loaded
    world.start_run(false)
    expect(world.pending_link_notice.is_empty(), "a lone starter still has no complete recipe to announce")
    expect(world.grant_weapon("firepot"), "a partner can be granted under old settings")
    expect(world.pending_link_notice.size() > 0, "missing seen_link_recipes still treats a newly completed recipe as eligible once")
    world.queue_free()
    await process_frame
