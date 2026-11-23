extends RefCounted

const Catalog = preload("res://src/catalog.gd")
const Growth = preload("res://src/growth.gd")
const Economy = preload("res://src/economy.gd")
const Progression = preload("res://src/progression.gd")
const LootDrops = preload("res://src/loot_drops.gd")
const BiomeEncounters = preload("res://src/biome_encounters.gd")

static func point(value: Vector2) -> Array:
    return [value.x, value.y]

static func vector(value, fallback: Vector2 = Vector2.ZERO) -> Vector2:
    if value is Array and value.size() == 2 and (value[0] is float or value[0] is int) and (value[1] is float or value[1] is int):
        var result: Vector2 = Vector2(value[0], value[1])
        if is_finite(result.x) and is_finite(result.y):
            return result
    return fallback


static func _capture_result_positions(world: Node) -> Dictionary:
    var saved := {}
    var raw = world.pack_result_positions if "pack_result_positions" in world else {}
    if typeof(raw) != TYPE_DICTIONARY:
        return saved
    for link_id in raw:
        var value = raw[link_id]
        if value is Vector2:
            saved[str(link_id)] = point(value)
        elif value is Array and value.size() >= 2:
            saved[str(link_id)] = [float(value[0]), float(value[1])]
    return saved

static func _restore_result_positions(raw) -> Dictionary:
    var restored := {}
    if typeof(raw) != TYPE_DICTIONARY:
        return restored
    for link_id in raw:
        restored[str(link_id)] = vector(raw[link_id], Vector2.ZERO)
    return restored

static func capture(world: Node, finished: bool = false) -> Dictionary:
    var enemies: Array = []
    for enemy in world.enemies:
        if enemy["hp"] <= 0.0:
            continue
        var entry := {"id":enemy["id"], "kind":enemy["kind"], "position":point(enemy["position"]), "hp":enemy["hp"], "max_hp":enemy["max_hp"], "elite":enemy["elite"], "attack_cycle":enemy.get("attack_cycle",0)}
        if enemy.has("summoner_id"):
            entry["summoner_id"] = enemy["summoner_id"]
        if enemy.has("next_summon"):
            entry["next_summon"] = enemy["next_summon"]
        enemies.append(entry)
    var drops: Array = []
    for drop in world.pickups:
        var saved := {"kind":drop.get("kind","xp"), "position":point(drop["position"]), "value":drop["value"]}
        if drop.has("legacy_fraction"):
            saved["legacy_fraction"] = drop["legacy_fraction"]
        drops.append(saved)
    var chests: Array = []
    for chest in world.chest_marks:
        chests.append({"position":point(chest["position"]), "age":chest.get("age", 0.0)})
    # A visible, unchosen chest reward is still owed when saving mid-choice.
    var owed_chests: int = world.chest_queue + int(world.upgrade_pending and world.upgrade_reason == "chest")
    var talent_offers: Array = []
    if world.upgrade_pending and world.upgrade_reason == "talent":
        for key in world.upgrade_choices:
            var offer := {"id": key}
            if world.upgrade_offer_levels.has(key):
                offer["level"] = world.upgrade_offer_levels[key]
            talent_offers.append(offer)
    return {
        "chest_marks":chests, "chest_queue":owed_chests, "elite_chest_due":world.elite_chest_due, "talent_growth_offers":talent_offers,
        "terrain_state":world.map_view.capture_terrain(),
        "wave_closing":world.wave_closing,"wave_buffer":world.wave_buffer,"boss_pending":world.boss_pending,
        "version":1, "finished":finished, "wave":world.wave, "wave_elapsed":world.wave_elapsed, "elapsed":world.elapsed,
        "player_hp":world.player_hp, "player_position":point(world.player_position), "coins":world.coins,
        "xp":world.xp, "xp_needed":world.xp_needed, "player_level":world.player_level, "stage_hp_bonus":world.stage_hp_bonus, "stage_hp_granted_wave":world.stage_hp_granted_wave, "kills":world.kills,
        "inventory":world.inventory.duplicate(true), "buff_levels":world.buff_levels.duplicate(true), "starting_weapon":world.starting_weapon,
        "character_id":world.character_id,
        "collapsed":world.collapsed, "prefer_elite":world.prefer_elite, "link_id":world.active_link["id"] if world.active_link_ids().is_empty() else str(world.active_link_ids()[0]),
        "link_ids":world.active_link_ids(),
        "enemy_adaptation":world.enemy_adaptation, "enemy_serial":world.enemy_serial, "enemies":enemies, "pickups":drops,
        "boss_round":world.boss_round, "boss_defeated":world.boss_defeated, "boss_clear_left":world.boss_clear_left, "shop_open":world.shop_open,
        "shop_stock":world.shop_stock.duplicate(true), "shop_rerolls":world.shop_rerolls, "shop_refresh_progress":world.shop_refresh_progress,
        "regen_delay_left":clampf(world.regen_ready_at - world.elapsed, 0.0, Growth.REGEN_DAMAGE_DELAY), "rng_state":str(world.rng.state),
        "pack_result_positions":_capture_result_positions(world)
    }

static func apply(world: Node, state: Dictionary) -> bool:
    if state.get("finished", false) or int(state.get("version",0)) != 1:
        return false
    world.start_run(false)
    world.clear_enemies()
    world.clear_weapons()
    world.wave = maxi(1,int(state.get("wave",1)))
    world.map_view.restore_terrain(state.get("terrain_state",{}))
    world.wave_elapsed = maxf(0.0,float(state.get("wave_elapsed",0.0)))
    world.elapsed = maxf(0.0,float(state.get("elapsed",0.0)))
    world.regen_ready_at = world.elapsed + clampf(float(state.get("regen_delay_left", 0.0)), 0.0, Growth.REGEN_DAMAGE_DELAY)
    world.enemy_adaptation = clampf(float(state.get("enemy_adaptation",1.0)),1.0,1.75)
    world.set_start_weapon(str(state.get("starting_weapon","sling")))
    world.character_id = Catalog.resolve_character_id(str(state.get("character_id","")), world.starting_weapon)
    if world.hero != null and world.hero.has_method("set_character"):
        world.hero.set_character(world.character_id)
    for item in state.get("inventory",[]):
        var key: String = str(item.get("id",""))
        if not Catalog.WEAPONS.has(key):
            return false
        for index in range(clampi(int(item.get("level",1)),1,Growth.MAX_WEAPON_LEVEL)):
            world.grant_weapon(key)
    world.buff_levels.clear()
    for key in state.get("buff_levels",{}):
        if Growth.BUFFS.has(key):
            world.buff_levels[key] = clampi(int(state["buff_levels"][key]),0,Growth.BUFFS[key]["max_level"])
    world.player_level = maxi(1,int(state.get("player_level",1)))
    world.stage_hp_bonus = maxi(0,int(state.get("stage_hp_bonus",0)))
    world.stage_hp_granted_wave = maxi(0,int(state.get("stage_hp_granted_wave",0)))
    if world.has_method("refresh_stats"):
        world.refresh_stats()
    else:
        world.stats = Growth.stats(world.buff_levels, world.stage_hp_bonus)
        Catalog.apply_character_modifiers(world.stats, world.character_id)
    world.player_hp = clampf(float(state.get("player_hp",8.0)),0.0,world.stats["max_hp"])
    world.player_position = vector(state.get("player_position"),Vector2(640,401))
    world.hero.position = world.player_position
    world.coins = maxi(0,int(state.get("coins",0)))
    world.xp = maxf(0.0,float(state.get("xp",0.0)))
    world.xp_needed = maxi(8,int(state.get("xp_needed",8)))
    world.kills = maxi(0,int(state.get("kills",0)))
    world.collapsed = bool(state.get("collapsed",false))
    world.prefer_elite = bool(state.get("prefer_elite",false))
    var restored_links: Array = []
    if state.has("link_ids"):
        var raw_links: Variant = state.get("link_ids", [])
        if typeof(raw_links) == TYPE_ARRAY:
            restored_links = raw_links
    elif str(state.get("link_id", "none")) != "none":
        restored_links = [str(state.get("link_id", "none"))]
    if restored_links.is_empty():
        world.apply_links([])
    else:
        world.apply_links(restored_links)
    for data in state.get("enemies",[]):
        var kind: String = str(data.get("kind",""))
        if not Catalog.DINOS.has(kind) and not BiomeEncounters.MOBS.has(kind):
            continue
        world.spawn_enemy(kind,vector(data.get("position"),Vector2(300,300)))
        var enemy: Dictionary = world.enemies.back()
        enemy["id"] = int(data.get("id",enemy["id"]))
        enemy["elite"] = bool(data.get("elite",false))
        enemy["view"].elite = enemy["elite"]
        var profile: Dictionary = Progression.enemy_profile(world.wave,kind,world.enemy_adaptation,enemy["elite"])
        for key in ["damage","dodge","speed_multiplier","bullet_multiplier"]:
            enemy[key] = profile[key]
        enemy["max_hp"] = maxf(0.1,float(data.get("max_hp",enemy["max_hp"])))
        enemy["hp"] = clampf(float(data.get("hp",enemy["hp"])),0.0,enemy["max_hp"])
        enemy["attack_cycle"] = int(data.get("attack_cycle",0))
        if data.has("summoner_id"):
            enemy["summoner_id"] = int(data["summoner_id"])
        if data.has("next_summon"):
            enemy["next_summon"] = float(data["next_summon"])
        enemy["timer"] = 1.0
        enemy["view"].health_fraction = enemy["hp"] / enemy["max_hp"]
    world.enemy_serial = maxi(world.enemy_serial,int(state.get("enemy_serial",world.enemy_serial)))
    world.pickups.clear()
    for drop in state.get("pickups",[]):
        LootDrops.restore(world.pickups, drop, vector(drop.get("position")))
    world.chest_marks.clear()
    for chest in state.get("chest_marks", []):
        world.chest_marks.append({"position":world.reachable_chest_position(vector(chest["position"])), "age":float(chest.get("age", 0.0))})
    world.chest_queue = int(state.get("chest_queue", 0))
    world.elite_chest_due = bool(state.get("elite_chest_due", false))
    world.boss_round = bool(state.get("boss_round",world.wave % 5 == 0))
    world.boss_defeated = bool(state.get("boss_defeated",false))
    world.boss_clear_left = clampf(float(state.get("boss_clear_left", 0.0)), 0.0, world.BOSS_CLEAR_SECONDS) if world.boss_defeated else 0.0
    world.boss_pending = bool(state.get("boss_pending",world.boss_round and not world.boss_defeated and state.get("enemies",[]).is_empty()))
    world.wave_closing = bool(state.get("wave_closing",false))
    world.wave_buffer = clampf(float(state.get("wave_buffer",0.0)),0.0,world.WAVE_BUFFER) if world.wave_closing else 0.0
    world.shop_open = bool(state.get("shop_open",false))
    world.shop_rerolls = int(state.get("shop_rerolls", 0))
    world.shop_refresh_progress = int(state.get("shop_refresh_progress", 0))
    world.shop_stock.clear()
    for offer in state.get("shop_stock",[]):
        var restored_offer := {"id":str(offer.get("id","")),"price":int(offer.get("price",0)),"sold":bool(offer.get("sold",false))}
        if offer.has("probability"): restored_offer["probability"] = float(offer["probability"])
        if offer.has("level"): restored_offer["level"] = clampi(int(offer["level"]), 1, Growth.MAX_WEAPON_LEVEL)
        if not restored_offer.sold and Catalog.WEAPONS.has(restored_offer.id):
            restored_offer["price"] = Economy.price_weapon_offer(restored_offer, world.inventory, world.wave)
        world.shop_stock.append(restored_offer)
    world.rng.state = str(state.get("rng_state",world.rng.state)).to_int()
    world.invulnerable = 1.0
    world.running = true
    world.paused = false
    world.upgrade_pending = false
    world.audio.set_paused(world.shop_open or world.wave_closing)
    world.player_frozen = world.shop_open or world.wave_closing
    if world.has_method("hatch_enemy"):
        for enemy in world.enemies:
            if str(enemy.get("state", "")) == "egg":
                world.hatch_enemy(enemy, false)
    if world.has_method("set_loadout_visible"):
        world.set_loadout_visible(not world.shop_open)
    if world.wave_closing:
        world.sync_idle_loadout()
    world.update_hud()
    if world.shop_open:
        world.show_current_shop()
        if world.has_method("set_loadout_visible"):
            world.set_loadout_visible(false)
    else:
        world.hud.hide_menu()
        world.restore_talent_growth(state.get("talent_growth_offers", []))
    if "pack_result_positions" in world:
        world.pack_result_positions = _restore_result_positions(state.get("pack_result_positions", {}))
    return true
