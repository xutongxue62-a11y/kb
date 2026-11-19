extends RefCounted

const VERSION: int = 1
const Catalog = preload("res://src/catalog.gd")
const BiomeEncounters = preload("res://src/biome_encounters.gd")
const MAX_SAFE_INTEGER: int = 9007199254740991
const MAX_PROGRESS: int = 1000000000
const MAX_FILE_BYTES: int = 8 * 1024 * 1024
const MAX_DEPTH: int = 32
const MAX_COLLECTION_SIZE: int = 10000
const MAX_PICKUPS: int = 50000
const WEAPON_IDS: Array = Catalog.IDS
const Growth = preload("res://src/growth.gd")
# Build validation from the public catalog so UI/runtime/save caps cannot diverge.
static var BUFF_MAX_LEVELS: Dictionary = _buff_max_levels()

static func _buff_max_levels() -> Dictionary:
    var result: Dictionary = {}
    for key in Growth.BUFFS:
        # Accept historical caps so older runs still load; gameplay clamps to max_level.
        result[key] = int(Growth.BUFFS[key].get("save_max_level", Growth.BUFFS[key]["max_level"]))
    return result

const REQUIRED_RUN_FIELDS: Array = ["version", "wave", "inventory", "buff_levels", "player_hp", "coins", "xp", "player_level", "finished"]

var _storage_dir: String

func _init(storage_dir: String = "user://saves") -> void:
    _storage_dir = storage_dir

func write_run(state: Variant) -> Dictionary:
    var validation_error: String = _validate_run(state)
    if not validation_error.is_empty():
        return _failure(validation_error)
    return _write_document("run.json", state)

func read_run() -> Dictionary:
    var result: Dictionary = _read_document("run.json", "run")
    if result["ok"]:
        return {"ok": true, "state": result["data"], "error": "", "recovered": false}
    var backup: Dictionary = _read_document("run.backup.json", "run")
    if backup["ok"]:
        return {"ok": true, "state": backup["data"], "error": "", "recovered": true}
    return {"ok": false, "state": {}, "error": result["error"] + "；" + backup["error"], "recovered": false}

func has_run() -> bool:
    var result: Dictionary = read_run()
    return result["ok"] and not result["state"].get("finished", true)

func read_settings() -> Dictionary:
    var result: Dictionary = _read_document("settings.json", "settings")
    if not result["ok"]:
        result = _read_document("settings.backup.json", "settings")
    if result["ok"]:
        var settings: Dictionary = result["data"]
        if not settings.has("autosave"):
            settings["autosave"] = true
        if not settings.has("music_enabled"):
            settings["music_enabled"] = true
        return settings
    return {"autosave": true, "music_enabled": true}

func write_settings(settings: Variant) -> Dictionary:
    var validation_error: String = _validate_settings(settings)
    if not validation_error.is_empty():
        return _failure(validation_error)
    var payload: Dictionary = settings.duplicate(true)
    if not payload.has("autosave"):
        payload["autosave"] = true
    if not payload.has("music_enabled"):
        payload["music_enabled"] = true
    return _write_document("settings.json", payload)

func _validate_run(state: Variant) -> String:
    if typeof(state) != TYPE_DICTIONARY:
        return "存档必须是 JSON 对象"
    var json_error: String = _validate_json(state)
    if not json_error.is_empty():
        return json_error
    for key in REQUIRED_RUN_FIELDS:
        if not state.has(key):
            return "存档缺少字段：" + key
    if not _integer_in_range(state["version"], VERSION, VERSION):
        return "不支持的存档版本"
    for key in ["wave", "player_level"]:
        if not _integer_in_range(state[key], 1, MAX_PROGRESS):
            return "存档数值无效：" + key
    if not _integer_in_range(state["coins"], 0, MAX_SAFE_INTEGER):
        return "存档金币无效"
    for key in ["xp", "player_hp"]:
        if not _number_in_range(state[key], 0.0, float(MAX_SAFE_INTEGER)):
            return "存档数值无效：" + key
    if typeof(state["finished"]) != TYPE_BOOL:
        return "存档结束标记无效"
    if not state["finished"] and state["player_hp"] <= 0:
        return "未结束的存档必须有剩余生命"
    var inventory: Variant = state["inventory"]
    if typeof(inventory) != TYPE_ARRAY or inventory.is_empty() or inventory.size() > 6:
        return "存档武器数量无效"
    var seen: Dictionary = {}
    for item in inventory:
        if typeof(item) != TYPE_DICTIONARY or not item.has("id") or not item.has("level"):
            return "存档武器格式无效"
        if typeof(item["id"]) != TYPE_STRING or not WEAPON_IDS.has(item["id"]) or seen.has(item["id"]):
            return "存档含未知或重复武器"
        if not _integer_in_range(item["level"], 1, Growth.MAX_WEAPON_LEVEL):
            return "存档武器等级无效"
        seen[item["id"]] = true
    var levels: Variant = state["buff_levels"]
    if typeof(levels) != TYPE_DICTIONARY:
        return "存档 Buff 格式无效"
    for key in levels:
        if not BUFF_MAX_LEVELS.has(key) or not _integer_in_range(levels[key], 0, BUFF_MAX_LEVELS[key]):
            return "存档 Buff 等级无效：" + str(key)
    return _validate_optional_run_fields(state)

func _validate_optional_run_fields(state: Dictionary) -> String:
    if state.has("chest_queue") and not _integer_in_range(state["chest_queue"], 0, MAX_PROGRESS):
        return "存档宝箱奖励数量无效"
    if state.has("chest_marks"):
        if typeof(state["chest_marks"]) != TYPE_ARRAY or state["chest_marks"].size() > MAX_COLLECTION_SIZE:
            return "存档地面宝箱数量无效"
        for chest in state["chest_marks"]:
            if typeof(chest) != TYPE_DICTIONARY or not chest.has("position") or not _valid_point(chest["position"]):
                return "存档地面宝箱位置无效"
            if chest.has("age") and not _number_in_range(chest["age"], 0.0, float(MAX_SAFE_INTEGER)):
                return "存档地面宝箱计时无效"
    if state.has("player_position") and not _valid_point(state["player_position"]):
        return "存档玩家位置无效"
    for key in ["elapsed", "wave_elapsed"]:
        if state.has(key) and not _number_in_range(state[key], 0.0, float(MAX_SAFE_INTEGER)):
            return "存档计时无效：" + key
    if state.has("boss_clear_left") and not _number_in_range(state["boss_clear_left"], 0.0, 30.0):
        return "存档 Boss 清场计时无效"
    for key in ["shop_open", "boss_round", "boss_defeated", "collapsed", "prefer_elite","wave_closing","boss_pending"]:
        if state.has(key) and typeof(state[key]) != TYPE_BOOL:
            return "存档开关格式无效：" + key
    if state.has("enemy_adaptation") and not _number_in_range(state["enemy_adaptation"], 1.0, 1.75):
        return "存档敌人强化倍率无效"
    if state.has("xp_needed") and not _integer_in_range(state["xp_needed"], 1, MAX_SAFE_INTEGER):
        return "存档升级所需经验无效"
    for key in ["kills","enemy_serial"]:
        if state.has(key) and not _integer_in_range(state[key],0,MAX_SAFE_INTEGER):
            return "存档计数无效："+key
    if state.has("starting_weapon") and (typeof(state["starting_weapon"]) != TYPE_STRING or not Catalog.STARTER_WEAPONS.has(state["starting_weapon"])):
        return "存档初始武器无效"
    if state.has("character_id") and (typeof(state["character_id"]) != TYPE_STRING or not Catalog.CHARACTERS.has(state["character_id"])):
        return "存档角色无效"
    if state.has("link_id") and (typeof(state["link_id"]) != TYPE_STRING or not Catalog.LINKS.has(state["link_id"])):
        return "存档联动选项无效"
    if state.has("rng_state") and not _valid_rng_state(state["rng_state"]):
        return "存档随机状态无效"
    if state.has("shop_stock"):
        var stock_error: String = _validate_stock(state["shop_stock"])
        if not stock_error.is_empty():
            return stock_error
    if state.has("enemies"):
        var enemy_error: String = _validate_enemies(state["enemies"])
        if not enemy_error.is_empty():
            return enemy_error
    if state.has("pickups"):
        var pickup_error: String = _validate_pickups(state["pickups"])
        if not pickup_error.is_empty():
            return pickup_error
    if state.has("wave_buffer") and not _number_in_range(state.wave_buffer,0.0,2.0):
        return "存档结算停顿无效"
    if state.has("terrain_state"):
        if typeof(state.terrain_state)!=TYPE_DICTIONARY or typeof(state.terrain_state.get("stone_health",{}))!=TYPE_DICTIONARY:
            return "存档地形无效"
        var stones: Dictionary=state.terrain_state.get("stone_health",{})
        if stones.size()>MAX_COLLECTION_SIZE: return "存档石头数量无效"
        for id in stones:
            if typeof(id)!=TYPE_STRING or id.is_empty() or id.length()>160 or not _number_in_range(stones[id],0.0,1000.0):
                return "存档石头状态无效"
    return ""

func _validate_stock(stock: Variant) -> String:
    if typeof(stock) != TYPE_ARRAY or stock.size() > 8:
        return "存档商店库存无效"
    for offer in stock:
        if typeof(offer) != TYPE_DICTIONARY or not offer.has_all(["id", "price", "sold"]):
            return "存档商品格式无效"
        if typeof(offer["id"]) != TYPE_STRING or not (WEAPON_IDS.has(offer["id"]) or BUFF_MAX_LEVELS.has(offer["id"]) or offer["id"] == "heal"):
            return "存档包含未知商品"
        if not _integer_in_range(offer["price"], 1, MAX_PROGRESS) or typeof(offer["sold"]) != TYPE_BOOL:
            return "存档商品价格或售罄标记无效"
        if offer.has("probability") and not _number_in_range(offer["probability"], 0.0, 1.0):
            return "存档商品首抽率无效"
        if offer.has("level") and not _integer_in_range(offer["level"], 1, Growth.MAX_WEAPON_LEVEL):
            return "存档商品等级无效"
    return ""

func _validate_enemies(enemies: Variant) -> String:
    if typeof(enemies) != TYPE_ARRAY or enemies.size() > 128:
        return "存档敌人数量无效"
    var seen: Dictionary = {}
    for enemy in enemies:
        if typeof(enemy) != TYPE_DICTIONARY or not enemy.has_all(["id", "kind", "position", "hp", "max_hp", "elite"]):
            return "存档敌人格式无效"
        if not _integer_in_range(enemy["id"], 1, MAX_SAFE_INTEGER):
            return "存档敌人编号无效"
        var enemy_id: int = int(enemy["id"])
        if seen.has(enemy_id):
            return "存档敌人编号重复"
        seen[enemy_id] = true
        if typeof(enemy["kind"]) != TYPE_STRING or (not Catalog.DINOS.has(enemy["kind"]) and not BiomeEncounters.MOBS.has(enemy["kind"])):
            return "存档敌人种类无效"
        if not _valid_point(enemy["position"]) or typeof(enemy["elite"]) != TYPE_BOOL:
            return "存档敌人位置或精英标记无效"
        if not _number_in_range(enemy["hp"], 0.0, float(MAX_SAFE_INTEGER)) or not _number_in_range(enemy["max_hp"], 0.0, float(MAX_SAFE_INTEGER)):
            return "存档敌人生命无效"
        if enemy["max_hp"] <= 0.0 or enemy["hp"] > enemy["max_hp"]:
            return "存档敌人生命超出上限"
        if enemy.has("attack_cycle") and not _integer_in_range(enemy["attack_cycle"], 0, MAX_SAFE_INTEGER):
            return "存档敌人攻击轮次无效"
        if enemy.has("summoner_id") and not _integer_in_range(enemy["summoner_id"], 1, MAX_SAFE_INTEGER):
            return "存档召唤者编号无效"
        if enemy.has("next_summon") and not _number_in_range(enemy["next_summon"], 0.0, float(MAX_SAFE_INTEGER)):
            return "存档召唤计时无效"
    return ""

func _validate_pickups(pickups: Variant) -> String:
    if typeof(pickups) != TYPE_ARRAY or pickups.size() > MAX_PICKUPS:
        return "存档掉落数量无效"
    var unit_count: float = 0.0
    for pickup in pickups:
        if typeof(pickup) != TYPE_DICTIONARY or not pickup.has_all(["kind", "position", "value"]):
            return "存档掉落格式无效"
        if typeof(pickup["kind"]) != TYPE_STRING or not ["xp", "coin", "blood"].has(pickup["kind"]):
            return "存档掉落种类无效"
        if not _valid_point(pickup["position"]) or not _number_in_range(pickup["value"], 0.0, float(MAX_SAFE_INTEGER)):
            return "存档掉落位置或数量无效"
        if pickup["kind"] == "coin" and not _integer_in_range(pickup["value"], 0, MAX_SAFE_INTEGER):
            return "存档掉落金币必须是整数"
        if pickup.has("legacy_fraction") and (pickup["kind"] != "xp" or pickup["value"] != 1 or not _number_in_range(pickup["legacy_fraction"], 0.0, 1.0) or pickup["legacy_fraction"] <= 0.0):
            return "旧版经验余量无效"
        unit_count += ceilf(float(pickup["value"]))
        if unit_count > MAX_PICKUPS:
            return "存档独立掉落数量过大"
    return ""

func _valid_point(point: Variant) -> bool:
    return typeof(point) == TYPE_ARRAY and point.size() == 2 and _number_in_range(point[0], -float(MAX_SAFE_INTEGER), float(MAX_SAFE_INTEGER)) and _number_in_range(point[1], -float(MAX_SAFE_INTEGER), float(MAX_SAFE_INTEGER))

func _valid_rng_state(value: Variant) -> bool:
    if typeof(value) != TYPE_STRING or value.is_empty():
        return false
    var digits: String = value
    var negative: bool = digits.begins_with("-")
    if negative or digits.begins_with("+"):
        digits = digits.substr(1)
    if digits.is_empty():
        return false
    for index in range(digits.length()):
        var code: int = digits.unicode_at(index)
        if code < 48 or code > 57:
            return false
    digits = digits.lstrip("0")
    # RNG state is encoded as text to retain every bit of a signed 64-bit integer.
    if digits.length() > 19:
        return false
    if digits.length() == 19:
        return digits <= ("9223372036854775808" if negative else "9223372036854775807")
    return true

func _validate_settings(settings: Variant) -> String:
    if typeof(settings) != TYPE_DICTIONARY:
        return "设置必须是 JSON 对象"
    var json_error: String = _validate_json(settings)
    if not json_error.is_empty():
        return json_error
    if settings.has("autosave") and typeof(settings["autosave"]) != TYPE_BOOL:
        return "自动存档设置必须是布尔值"
    if settings.has("music_enabled") and typeof(settings["music_enabled"]) != TYPE_BOOL:
        return "背景音乐设置必须是布尔值"
    if settings.has("damage_numbers") and typeof(settings["damage_numbers"]) != TYPE_BOOL:
        return "伤害数字设置必须是布尔值"
    if settings.has("fullscreen") and typeof(settings["fullscreen"]) != TYPE_BOOL:
        return "全屏设置必须是布尔值"
    if settings.has("seen_link_guide") and typeof(settings["seen_link_guide"]) != TYPE_BOOL:
        return "联动引导记录必须是布尔值"
    if settings.has("key_bindings"):
        if typeof(settings["key_bindings"]) != TYPE_DICTIONARY:
            return "按键设置必须是对象"
        for action in settings["key_bindings"]:
            if typeof(action) != TYPE_STRING:
                return "按键设置的功能名必须是字符串"
            var bind: Variant = settings["key_bindings"][action]
            if typeof(bind) != TYPE_INT and typeof(bind) != TYPE_FLOAT:
                return "按键设置必须是数值键码"
            if float(bind) != float(int(bind)) or int(bind) <= 0:
                return "按键设置必须是正整数键码"
    for key in ["music_volume", "sfx_volume"]:
        if settings.has(key) and not _number_in_range(settings[key], 0.0, 1.0):
            return "音量设置必须是 0 到 1 的数值"
    if settings.has("character_best_wave"):
        var progress: Variant = settings["character_best_wave"]
        if typeof(progress) != TYPE_DICTIONARY or progress.size() > MAX_COLLECTION_SIZE:
            return "角色关卡进度格式无效"
        for key in progress:
            if typeof(key) != TYPE_STRING or not Catalog.CHARACTERS.has(key):
                return "角色关卡进度包含未知角色"
            if not _integer_in_range(progress[key], 0, MAX_PROGRESS):
                return "角色最高关卡无效：" + str(key)
    return ""

func _validate_json(value: Variant, depth: int = 0, collection_limit: int = MAX_COLLECTION_SIZE) -> String:
    if depth > MAX_DEPTH:
        return "存档数据嵌套过深或含循环引用"
    match typeof(value):
        TYPE_NIL, TYPE_BOOL, TYPE_STRING:
            return ""
        TYPE_INT, TYPE_FLOAT:
            if not _number_in_range(value, -float(MAX_SAFE_INTEGER), float(MAX_SAFE_INTEGER)):
                return "存档包含非有限或超出 JSON 精度的数值"
        TYPE_ARRAY, TYPE_DICTIONARY:
            if value.size() > collection_limit:
                return "存档数据集合过大"
            for key in value:
                if typeof(value) == TYPE_DICTIONARY and typeof(key) != TYPE_STRING:
                    return "JSON 对象的键必须是字符串"
                var child: Variant = value[key] if typeof(value) == TYPE_DICTIONARY else key
                var limit: int = MAX_PICKUPS if depth == 0 and typeof(value) == TYPE_DICTIONARY and key == "pickups" else MAX_COLLECTION_SIZE
                var child_error: String = _validate_json(child, depth + 1, limit)
                if not child_error.is_empty():
                    return child_error
        _:
            return "存档包含非 JSON 类型；请先编码坐标和引擎对象"
    return ""

func _integer_in_range(value: Variant, minimum: int, maximum: int) -> bool:
    return _number_in_range(value, float(minimum), float(maximum)) and float(value) == floor(float(value))

func _number_in_range(value: Variant, minimum: float, maximum: float) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    return is_finite(float(value)) and value >= minimum and value <= maximum

func _read_document(file_name: String, kind: String) -> Dictionary:
    if _storage_dir.strip_edges().is_empty():
        return _failure("存档目录为空")
    var path: String = _storage_dir.path_join(file_name)
    if not FileAccess.file_exists(path):
        return _failure("没有可用文件：" + file_name)
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return _failure("无法读取 %s：%s" % [file_name, error_string(FileAccess.get_open_error())])
    if file.get_length() > MAX_FILE_BYTES:
        file.close()
        return _failure("存档文件过大：" + file_name)
    var body: String = file.get_as_text()
    var read_error: Error = file.get_error()
    file.close()
    if read_error != OK and read_error != ERR_FILE_EOF:
        return _failure("读取 %s 失败：%s" % [file_name, error_string(read_error)])
    var json: JSON = JSON.new()
    if json.parse(body) != OK:
        return _failure("JSON 文件损坏：" + file_name)
    var validation_error: String = _validate_run(json.data) if kind == "run" else _validate_settings(json.data)
    if not validation_error.is_empty():
        return _failure("%s：%s" % [file_name, validation_error])
    return {"ok": true, "data": json.data, "text": body, "error": ""}

func _write_document(file_name: String, data: Dictionary) -> Dictionary:
    if _storage_dir.strip_edges().is_empty():
        return _failure("存档目录为空")
    var body: String = JSON.stringify(data, "\t", true, true)
    if body.to_utf8_buffer().size() > MAX_FILE_BYTES:
        return _failure("存档文件过大")
    var directory: String = ProjectSettings.globalize_path(_storage_dir)
    var directory_error: Error = DirAccess.make_dir_recursive_absolute(directory)
    if directory_error != OK:
        return _failure("无法创建存档目录：" + error_string(directory_error))
    var primary: String = directory.path_join(file_name)
    var temporary: String = primary + ".tmp"
    var result: Dictionary = _write_text(temporary, body)
    if not result["ok"]:
        return result
    # Keep the primary in place until both the new file and its backup are flushed.
    # Only a validated primary may replace the previous valid backup.
    var previous: Dictionary = _read_document(file_name, "run" if file_name == "run.json" else "settings")
    if previous["ok"]:
        var backup: String = directory.path_join(file_name.get_basename() + ".backup.json")
        var backup_temporary: String = backup + ".tmp"
        result = _write_text(backup_temporary, previous["text"])
        if not result["ok"]:
            return _failure("保留有效备份失败：" + result["error"])
        var backup_error: Error = DirAccess.rename_absolute(backup_temporary, backup)
        if backup_error != OK:
            return _failure("替换有效备份失败：" + error_string(backup_error))
    var replace_error: Error = DirAccess.rename_absolute(temporary, primary)
    if replace_error != OK:
        return _failure("替换 %s 失败：%s" % [file_name, error_string(replace_error)])
    return {"ok": true, "error": ""}

func _write_text(path: String, body: String) -> Dictionary:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return _failure("无法写入临时文件：" + error_string(FileAccess.get_open_error()))
    file.store_string(body)
    file.flush()
    var write_error: Error = file.get_error()
    file.close()
    if write_error != OK:
        return _failure("写入临时文件失败：" + error_string(write_error))
    return {"ok": true, "error": ""}

func _failure(message: String) -> Dictionary:
    return {"ok": false, "error": message}
