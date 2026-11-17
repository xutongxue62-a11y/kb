extends SceneTree

var checks: int = 0
var failures: int = 0
var save_store_script
var test_root: String = ""

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func _initialize() -> void:
    if not FileAccess.file_exists("res://src/save_store.gd"):
        expect(false, "isolated run persistence and settings are not implemented")
        finish()
        return
    save_store_script = load("res://src/save_store.gd")
    if save_store_script == null or not save_store_script.can_instantiate():
        expect(false, "SaveStore must load as an instantiable RefCounted script")
        finish()
        return
    test_root = "res://runtime/tests/save_store/%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    check_missing_files()
    var api = make_store("interface")
    expect(api.has_method("write_run"), "SaveStore exposes run writes")
    expect(api.has_method("write_settings"), "SaveStore exposes settings writes")
    if not api.has_method("write_run") or not api.has_method("write_settings"):
        finish()
        return
    check_round_trip()
    check_finished_run()
    check_invalid_writes()
    check_settings()
    check_music_settings()
    check_backups()
    check_corrupt_reads()
    check_key_bindings()
    check_settings_recovery()
    check_write_failures()
    check_json_limits()
    check_optional_corruption()
    finish()

func make_store(case_name: String):
    return save_store_script.new(test_root.path_join(case_name))

func check_missing_files() -> void:
    var store = make_store("missing")
    var result: Dictionary = store.read_run()
    expect(not result.get("ok", true) and not str(result.get("error", "")).is_empty(), "missing saves report a readable failure")
    expect(result.get("state", {}) == {} and not store.has_run(), "a missing save cannot become a continuable run")
    expect(store.read_settings() == {"autosave": true, "music_enabled": true}, "autosave defaults to enabled before any settings file exists")
    expect(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(test_root)), "reading missing saves and defaults does not create files or directories")

func sample_state() -> Dictionary:
    return {
        "version": 1, "wave": 5, "inventory": [{"id": "sling", "level": 2}, {"id": "hammer", "level": 1}],
        "buff_levels": {"vitality": 1, "pierce": 2}, "player_hp": 7.25,
        "coins": 17, "xp": 7.5, "player_level": 4, "finished": false,
        "elapsed": 121.5, "wave_elapsed": 1.5, "player_position": [640.0, 401.0],
        "shop_open": true, "boss_round": true, "boss_defeated": false, "collapsed": false, "prefer_elite": true,
        "enemy_adaptation": 1.25, "rng_state": "-9223372036854775808", "xp_needed": 14,
        "shop_stock": [{"id": "axe", "price": 8, "sold": true}, {"id": "power", "price": 10, "sold": false}, {"id": "heal", "price": 5, "sold": false}],
        "enemies": [{"id": 1, "kind": "hunter", "hp": 3.25, "max_hp": 5.0, "position": [520.0, 300.0], "elite": false, "attack_cycle": 0}],
        "pickups": [{"kind": "xp", "position": [100.0, 200.0], "value": 1.15}, {"kind": "coin", "position": [300.0, 400.0], "value": 3}],
        "shop": {"open": true, "offers": [{"id": "axe", "sold": true}]},
        "future_field": {"nested": [null, true, "保留额外信息", 0.125]}
    }

func check_round_trip() -> void:
    var store = make_store("round_trip")
    var state: Dictionary = sample_state()
    var result: Dictionary = store.write_run(state)
    expect(result.get("ok", false) and result.get("error", "missing") == "", "a valid live run is saved successfully")
    var loaded: Dictionary = make_store("round_trip").read_run()
    expect(loaded.get("ok", false) and not loaded.get("recovered", false), "a fresh store reads the primary save without recovery")
    if not loaded.get("ok", false):
        return
    # JSON numbers are floats after parsing; compare their values at the API boundary.
    var restored: Dictionary = loaded["state"]
    expect(restored["version"] == 1 and restored["wave"] == 5 and restored["player_level"] == 4 and restored["coins"] == 17 and restored["xp"] == 7.5 and restored["player_hp"] == 7.25, "core counters and fractional XP/HP round-trip without loss")
    expect(restored["inventory"].size() == 2 and restored["inventory"][0]["id"] == "sling" and restored["inventory"][0]["level"] == 2 and restored["inventory"][1]["id"] == "hammer" and restored["buff_levels"]["pierce"] == 2, "original/new weapons and Buff levels round-trip")
    expect(restored["enemies"][0]["hp"] == 3.25 and restored["enemies"][0]["position"] == [520.0, 300.0] and restored["elapsed"] == 121.5 and restored["player_position"] == [640.0, 401.0], "encoded positions, encounter HP and time are preserved")
    expect(restored["shop"] == {"open": true, "offers": [{"id": "axe", "sold": true}]} and restored["future_field"] == {"nested": [null, true, "保留额外信息", 0.125]}, "shop sold state and unknown nested JSON fields are preserved")
    expect(store.has_run(), "an unfinished valid save can be continued")
    expect(state == sample_state(), "writing does not mutate the caller's nested state")
    var json: JSON = JSON.new()
    expect(json.parse(read_text("round_trip", "run.json")) == OK and typeof(json.data) == TYPE_DICTIONARY, "run storage is ordinary versioned JSON")
    expect(not FileAccess.file_exists(test_root.path_join("round_trip/run.json.tmp")), "successful replacement consumes the temporary run file")
    state["coins"] = 19
    expect(store.write_run(state).get("ok", false) and store.read_run().get("state", {}).get("coins", -1) == 19, "saving again replaces the primary with the current run")

func check_finished_run() -> void:
    var store = make_store("finished")
    var state: Dictionary = sample_state()
    state["finished"] = true
    state["player_hp"] = 0.0
    expect(store.write_run(state).get("ok", false), "death can record a finished run without deleting it")
    expect(store.read_run().get("ok", false) and not store.has_run(), "finished saves remain readable while Continue stays disabled")
    expect(FileAccess.file_exists(test_root.path_join("finished/run.json")), "a finished run is retained on disk")

func check_invalid_writes() -> void:
    var store = make_store("invalid_writes")
    expect(store.write_run(sample_state()).get("ok", false), "invalid-write fixture starts from a valid save")
    var original_text: String = read_text("invalid_writes", "run.json")
    var cases: Array = [
        ["version", 2], ["version", "1"], ["wave", 0], ["wave", 1.25], ["wave", true],
        ["player_level", 0], ["player_level", "4"], ["coins", -1], ["coins", 2.5], ["coins", "17"],
        ["coins", NAN], ["coins", 9007199254740992], ["xp", -0.1], ["xp", INF],
        ["player_hp", -1.0], ["player_hp", NAN], ["player_hp", 0.0], ["finished", 1],
        ["inventory", {}], ["inventory", []], ["inventory", ["sling"]],
        ["inventory", [{"id": "club", "level": 0}]], ["inventory", [{"id": "club", "level": 8}]],
        ["inventory", [{"id": "club", "level": 1.5}]], ["inventory", [{"id": "unknown", "level": 1}]],
        ["inventory", [{"id": "club"}]], ["inventory", [{"level": 1}]],
        ["inventory", [{"id": "club", "level": 1}, {"id": "club", "level": 2}]],
        ["inventory", [{"id": "club", "level": 1}, {"id": "axe", "level": 1}, {"id": "blade", "level": 1}, {"id": "sling", "level": 1}, {"id": "powder", "level": 1}, {"id": "staff", "level": 1}, {"id": "spear", "level": 1}]],
        ["buff_levels", []], ["buff_levels", {"power": 1000}], ["buff_levels", {"pierce": 1000}],
        ["buff_levels", {"vitality": -1}], ["buff_levels", {"power": 1.5}], ["buff_levels", {"unknown": 1}],
        ["future_field", Vector2(1, 2)], ["future_field", {"deep": [INF]}], ["future_field", {1: "non-string key"}]
    ]
    for index in range(cases.size()):
        var state: Dictionary = sample_state()
        state[cases[index][0]] = cases[index][1]
        var result: Dictionary = store.write_run(state)
        expect(not result.get("ok", true) and not str(result.get("error", "")).is_empty(), "unsafe state is rejected with a reason: %s case %d" % [cases[index][0], index])
    for key in ["version", "wave", "inventory", "buff_levels", "player_hp", "coins", "xp", "player_level", "finished"]:
        var state: Dictionary = sample_state()
        state.erase(key)
        expect(not store.write_run(state).get("ok", true), "required run field cannot be omitted: " + key)
    expect(not store.write_run([]).get("ok", true), "a non-dictionary API payload fails gracefully")
    expect(read_text("invalid_writes", "run.json") == original_text, "invalid write attempts never alter the last valid save")

func check_settings() -> void:
    var store = make_store("settings")
    var settings: Dictionary = {"autosave": false, "music_enabled": true, "audio": {"volume": 0.4}, "future": null}
    expect(store.write_settings(settings).get("ok", false), "autosave can be disabled and persisted")
    expect(make_store("settings").read_settings() == settings, "settings retain unknown safe JSON fields across instances")
    var original_text: String = read_text("settings", "settings.json")
    expect(not store.write_settings({"autosave": "false"}).get("ok", true), "a string cannot silently disable or enable autosave")
    expect(not store.write_settings({"autosave": false, "unsafe": Vector2.ONE}).get("ok", true), "unsafe nested setting values are rejected")
    expect(not store.write_settings([]).get("ok", true), "a non-dictionary settings payload fails gracefully")
    expect(read_text("settings", "settings.json") == original_text, "failed settings validation preserves the prior file")
    expect(make_store("settings_default").write_settings({"future": 2}).get("ok", false), "a settings payload without autosave uses its default")
    var defaults: Dictionary = make_store("settings_default").read_settings()
    expect(defaults.get("autosave", false) and defaults.get("future", -1) == 2, "default autosave merges into saved settings without losing extras")

func check_backups() -> void:
    var store = make_store("backup")
    var state: Dictionary = sample_state()
    state["coins"] = 11
    expect(store.write_run(state).get("ok", false), "backup fixture writes its first run")
    state["coins"] = 22
    expect(store.write_run(state).get("ok", false), "second valid save succeeds")
    state["coins"] = 33
    expect(store.write_run(state).get("ok", false), "third valid save succeeds")
    var backup_text: String = read_text("backup", "run.backup.json")
    var backup_json: JSON = JSON.new()
    var backup_parse_error: Error = backup_json.parse(backup_text)
    var backup_data: Variant = backup_json.data if backup_parse_error == OK else null
    expect(typeof(backup_data) == TYPE_DICTIONARY and backup_data.get("coins", -1) == 22, "backup tracks the immediately preceding valid run")
    write_raw("backup", "run.json", "{truncated primary")
    var recovered: Dictionary = store.read_run()
    expect(recovered.get("ok", false) and recovered.get("recovered", false) and recovered.get("state", {}).get("coins", -1) == 22, "corrupt primary falls back to the last valid backup")
    expect(store.has_run(), "a valid unfinished backup remains continuable")
    expect(read_text("backup", "run.json") == "{truncated primary" and read_text("backup", "run.backup.json") == backup_text, "reading and checking Continue never overwrite corrupt primary or backup evidence")
    state["coins"] = 44
    expect(store.write_run(state).get("ok", false), "an explicit save can replace a corrupt primary")
    expect(read_text("backup", "run.backup.json") == backup_text, "a corrupt primary is never rotated over a valid backup")
    expect(store.read_run().get("state", {}).get("coins", -1) == 44 and not store.read_run().get("recovered", true), "a subsequent explicit save becomes the normal primary")
    var finished_store = make_store("finished_backup")
    expect(finished_store.write_run(sample_state()).get("ok", false), "finished-backup fixture starts from a live save")
    state = sample_state()
    state["finished"] = true
    state["player_hp"] = 0.0
    expect(finished_store.write_run(state).get("ok", false) and not finished_store.has_run(), "valid death record takes precedence over an unfinished backup")
    var orphan = make_store("backup_only")
    write_raw("backup_only", "run.backup.json", JSON.stringify(sample_state()))
    expect(orphan.read_run().get("ok", false) and orphan.read_run().get("recovered", false), "backup can recover a missing primary")
    expect(not FileAccess.file_exists(test_root.path_join("backup_only/run.json")), "backup-only reads do not recreate a primary")

func check_corrupt_reads() -> void:
    var negative: Dictionary = sample_state()
    negative["coins"] = -1
    var bad_inventory: Dictionary = sample_state()
    bad_inventory["inventory"] = [{"id": "club", "level": 100}]
    var wrong_version: Dictionary = sample_state()
    wrong_version["version"] = 999
    var corrupt_cases: Array = [
        "", "{broken", "[]", "null", "{\"version\":1}",
        JSON.stringify(negative), JSON.stringify(bad_inventory), JSON.stringify(wrong_version),
        JSON.stringify(sample_state()).replace("\"coins\":17", "\"coins\":1e309")
    ]
    for index in range(corrupt_cases.size()):
        var case_name: String = "corrupt_%d" % index
        write_raw(case_name, "run.json", corrupt_cases[index])
        var store = make_store(case_name)
        var result: Dictionary = store.read_run()
        expect(not result.get("ok", true) and result.get("state", {}) == {} and not str(result.get("error", "")).is_empty() and not store.has_run(), "corrupt or invalid on-disk JSON fails safely: case %d" % index)
        expect(read_text(case_name, "run.json") == corrupt_cases[index], "corrupt reads preserve the original bytes: case %d" % index)
    var fallback = make_store("schema_fallback")
    write_raw("schema_fallback", "run.json", JSON.stringify(negative))
    write_raw("schema_fallback", "run.backup.json", JSON.stringify(sample_state()))
    expect(fallback.read_run().get("ok", false) and fallback.read_run().get("recovered", false), "schema-invalid primary is eligible for backup recovery")
    write_raw("schema_fallback", "run.backup.json", "also corrupt")
    expect(not fallback.read_run().get("ok", true) and not fallback.has_run(), "two invalid files fail cleanly instead of returning partial state")

func check_settings_recovery() -> void:
    var store = make_store("settings_backup")
    expect(store.write_settings({"autosave": false, "audio": {"volume": 0.3}}).get("ok", false), "settings backup fixture writes the first preference")
    expect(store.write_settings({"autosave": true, "music_enabled": true}).get("ok", false), "valid settings can be replaced")
    var backup_text: String = read_text("settings_backup", "settings.backup.json")
    write_raw("settings_backup", "settings.json", "{\"autosave\":\"false\"}")
    expect(store.read_settings() == {"autosave": false, "music_enabled": true, "audio": {"volume": 0.3}}, "invalid settings recover the prior valid preference")
    expect(read_text("settings_backup", "settings.json") == "{\"autosave\":\"false\"}" and read_text("settings_backup", "settings.backup.json") == backup_text, "settings recovery is read-only")
    write_raw("settings_backup", "settings.backup.json", "{also bad")
    expect(store.read_settings() == {"autosave": true, "music_enabled": true}, "unrecoverable settings use the documented safe default")

func check_write_failures() -> void:
    var store = make_store("blocked_temp")
    expect(store.write_run(sample_state()).get("ok", false), "write-failure fixture starts from a valid primary")
    var before: String = read_text("blocked_temp", "run.json")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_root.path_join("blocked_temp/run.json.tmp")))
    var result: Dictionary = store.write_run(sample_state())
    expect(not result.get("ok", true) and not str(result.get("error", "")).is_empty(), "real temporary-file write failures are returned to the caller")
    expect(read_text("blocked_temp", "run.json") == before, "temporary-file failures retain the prior primary")
    var backup_store = make_store("blocked_backup")
    expect(backup_store.write_run(sample_state()).get("ok", false), "backup-failure fixture starts from a valid primary")
    var later: Dictionary = sample_state()
    later["coins"] = 99
    before = read_text("blocked_backup", "run.json")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_root.path_join("blocked_backup/run.backup.json.tmp")))
    result = backup_store.write_run(later)
    expect(not result.get("ok", true) and read_text("blocked_backup", "run.json") == before, "backup write failure prevents replacing the only prior valid primary")
    var replace_store = make_store("blocked_replace")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_root.path_join("blocked_replace/run.json")))
    result = replace_store.write_run(sample_state())
    expect(not result.get("ok", true) and not str(result.get("error", "")).is_empty(), "failed primary rename is not reported as a successful save")
    var empty_path_store = save_store_script.new("")
    expect(not empty_path_store.write_run(sample_state()).get("ok", true), "an empty destination cannot accidentally write into the project root")

func check_json_limits() -> void:
    var store = make_store("json_limits")
    var state: Dictionary = sample_state()
    var cycle: Dictionary = {}
    cycle["self"] = cycle
    state["future_field"] = cycle
    expect(not store.write_run(state).get("ok", true), "cyclic extras fail safely before JSON serialization")
    cycle.clear()
    state = sample_state()
    state["future_field"] = "x".repeat(8 * 1024 * 1024)
    expect(not store.write_run(state).get("ok", true), "oversized payloads are rejected before touching disk")
    expect(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(test_root.path_join("json_limits"))), "failed preflight checks do not create a storage directory")
    state = sample_state()
    state["coins"] = 9007199254740991
    expect(store.write_run(state).get("ok", false) and store.read_run().get("state", {}).get("coins", -1) == 9007199254740991, "largest precisely representable JSON coin count round-trips")

func check_optional_corruption() -> void:
    var cases: Array = [
        ["player_position", "wrong"], ["player_position", [1]], ["player_position", [1, 2, 3]], ["player_position", [true, 2]],
        ["elapsed", -0.1], ["elapsed", "1"], ["wave_elapsed", -1], ["wave_elapsed", true],
        ["shop_open", 1], ["boss_round", "false"], ["boss_defeated", null], ["collapsed", 0], ["prefer_elite", "true"],
        ["enemy_adaptation", 0.99], ["enemy_adaptation", 1.76], ["enemy_adaptation", "1.5"],
        ["xp_needed", 0], ["xp_needed", 1.25], ["xp_needed", false],
        ["kills", []], ["kills", false], ["kills", -1], ["kills", 1.5],
        ["enemy_serial", []], ["enemy_serial", false], ["enemy_serial", -1], ["enemy_serial", 1.5],
        ["starting_weapon", "staff"], ["starting_weapon", []], ["link_id", "unknown"], ["link_id", []],
        ["rng_state", 1], ["rng_state", ""], ["rng_state", "1.0"], ["rng_state", "1e4"], ["rng_state", "--1"], ["rng_state", " 12 "], ["rng_state", "9223372036854775808"],
        ["shop_stock", {}], ["shop_stock", [false]], ["shop_stock", [{}]],
        ["enemies", {}], ["enemies", [false]], ["enemies", [{}]],
        ["pickups", {}], ["pickups", [false]], ["pickups", [{}]]
    ]
    for mutation in [["id", "unknown"], ["price", 0], ["price", -1], ["price", 1.5], ["price", 1000000001], ["sold", 1]]:
        var offer: Dictionary = {"id": "club", "price": 10, "sold": false}
        offer[mutation[0]] = mutation[1]
        cases.append(["shop_stock", [offer]])
    for key in ["id", "price", "sold"]:
        var offer: Dictionary = {"id": "club", "price": 10, "sold": false}
        offer.erase(key)
        cases.append(["shop_stock", [offer]])
    var enemy_fixture: Dictionary = {"id": 1, "kind": "boss", "position": [500.0, 300.0], "hp": 4.0, "max_hp": 5.0, "elite": true}
    for mutation in [["id", 0], ["id", 1.5], ["id", "1"], ["kind", "unknown"], ["position", [1, "2"]], ["hp", -1], ["hp", 6], ["max_hp", 0], ["max_hp", "5"], ["elite", 1], ["attack_cycle", -1], ["attack_cycle", 1.25]]:
        var enemy: Dictionary = enemy_fixture.duplicate(true)
        enemy[mutation[0]] = mutation[1]
        cases.append(["enemies", [enemy]])
    for key in ["id", "kind", "position", "hp", "max_hp", "elite"]:
        var enemy: Dictionary = enemy_fixture.duplicate(true)
        enemy.erase(key)
        cases.append(["enemies", [enemy]])
    cases.append(["enemies", [enemy_fixture.duplicate(true), enemy_fixture.duplicate(true)]])
    for mutation in [["kind", "unknown"], ["position", [1]], ["value", -1], ["value", "1"], ["value", 1.5]]:
        var pickup: Dictionary = {"kind": "coin", "position": [100.0, 100.0], "value": 1}
        pickup[mutation[0]] = mutation[1]
        cases.append(["pickups", [pickup]])
    for key in ["kind", "position", "value"]:
        var pickup: Dictionary = {"kind": "xp", "position": [100.0, 100.0], "value": 0.5}
        pickup.erase(key)
        cases.append(["pickups", [pickup]])
    var many_enemies: Array = []
    for index in range(129):
        var enemy: Dictionary = enemy_fixture.duplicate(true)
        enemy["id"] = index + 1
        many_enemies.append(enemy)
    cases.append(["enemies", many_enemies])
    var many_offers: Array = []
    for index in range(9):
        many_offers.append({"id": "heal", "price": 1, "sold": false})
    cases.append(["shop_stock", many_offers])
    var many_pickups: Array = []
    for index in range(50001):
        many_pickups.append({"kind": "xp", "position": [0, 0], "value": 0})
    cases.append(["pickups", many_pickups])
    var reader = make_store("optional_corrupt_read")
    var writer = make_store("optional_corrupt_write")
    var backup_text: String = JSON.stringify(sample_state())
    write_raw("optional_corrupt_read", "run.backup.json", backup_text)
    for index in range(cases.size()):
        var state: Dictionary = sample_state()
        state[cases[index][0]] = cases[index][1]
        var label: String = "%s case %d" % [cases[index][0], index]
        var body: String = JSON.stringify(state)
        write_raw("optional_corrupt_read", "run.json", body)
        var result: Dictionary = reader.read_run()
        expect(result.get("ok", false) and result.get("recovered", false) and result.get("state", {}).get("coins", -1) == 17, "malformed known optional field recovers a valid backup: " + label)
        expect(not writer.write_run(state).get("ok", true), "malformed known optional field is rejected before writing: " + label)
        expect(read_text("optional_corrupt_read", "run.json") == body and read_text("optional_corrupt_read", "run.backup.json") == backup_text, "optional-field recovery preserves both files: " + label)
    var recovered: Dictionary = reader.read_run()
    expect(recovered.get("state", {}).get("future_field", {}) == {"nested": [null, true, "保留额外信息", 0.125]}, "unknown safe nested extras are retained after optional-field corruption recovery")
    var boundaries: Dictionary = sample_state()
    boundaries["enemy_adaptation"] = 1.65
    boundaries["wave_elapsed"] = 0.0
    boundaries["elapsed"] = 0.0
    boundaries["xp_needed"] = 1
    boundaries["rng_state"] = "9223372036854775807"
    many_enemies.pop_back()
    many_enemies[0]["hp"] = 0.0
    many_enemies[0]["attack_cycle"] = 0
    many_offers.pop_back()
    many_offers[0]["price"] = 1000000000
    many_pickups.pop_back()
    boundaries["enemies"] = many_enemies
    boundaries["shop_stock"] = many_offers
    boundaries["pickups"] = many_pickups
    var boundary_store = make_store("optional_boundaries")
    expect(boundary_store.write_run(boundaries).get("ok", false), "valid optional counts, numeric edges, zero HP enemy and signed RNG state are accepted")
    var loaded: Dictionary = boundary_store.read_run()
    expect(loaded.get("ok", false) and loaded.get("state", {}).get("enemies", []).size() == 128 and loaded.get("state", {}).get("pickups", []).size() == 50000, "valid maximum encounter sizes round-trip with independent unit drops")
    var core_only: Dictionary = sample_state()
    for key in ["player_position", "elapsed", "wave_elapsed", "shop_open", "boss_round", "boss_defeated", "collapsed", "prefer_elite", "enemy_adaptation", "shop_stock", "enemies", "pickups", "rng_state", "xp_needed"]:
        core_only.erase(key)
    expect(make_store("optional_absent").write_run(core_only).get("ok", false), "optional encounter fields may remain absent in a valid core save")

func write_raw(case_name: String, file_name: String, body: String) -> void:
    var directory: String = test_root.path_join(case_name)
    var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
    if directory_error != OK:
        expect(false, "cannot create isolated test fixture directory")
        return
    var file: FileAccess = FileAccess.open(directory.path_join(file_name), FileAccess.WRITE)
    if file == null:
        expect(false, "cannot write isolated test fixture")
        return
    file.store_string(body)
    file.flush()
    file.close()

func read_text(case_name: String, file_name: String) -> String:
    var file: FileAccess = FileAccess.open(test_root.path_join(case_name).path_join(file_name), FileAccess.READ)
    if file == null:
        return ""
    return file.get_as_text()

func finish() -> void:
    print("SAVE STORE RESULT: %d checks, %d failures" % [checks, failures])
    if not test_root.is_empty():
        print("SAVE STORE TEST DATA: " + test_root)
    quit(1 if failures > 0 else 0)

func check_music_settings() -> void:
    var store = make_store("music_settings")
    write_raw("music_settings", "settings.json", "{\"autosave\":false,\"future\":7}")
    expect(store.read_settings() == {"autosave": false, "music_enabled": true, "future": 7.0}, "old autosave-only preferences migrate music to enabled without losing fields")
    var settings: Dictionary = store.read_settings()
    settings["music_enabled"] = false
    expect(store.write_settings(settings).get("ok", false), "music off persists while autosave remains disabled")
    expect(make_store("music_settings").read_settings() == {"autosave": false, "music_enabled": false, "future": 7.0}, "a new store restores independent music and autosave switches plus unknown settings")
    settings = store.read_settings()
    settings["autosave"] = true
    expect(store.write_settings(settings).get("ok", false) and not make_store("music_settings").read_settings()["music_enabled"], "enabling autosave does not re-enable music")
    settings["autosave"] = false
    expect(store.write_settings(settings).get("ok", false), "independent switches restore without touching run storage")
    var original_text: String = read_text("music_settings", "settings.json")
    for value in [0, 1, "false", null, [], {}]:
        expect(not store.write_settings({"music_enabled": value}).get("ok", true), "music accepts only a JSON boolean: " + str(value))
    expect(read_text("music_settings", "settings.json") == original_text, "invalid music writes preserve the last valid preferences")
    write_raw("music_settings", "settings.json", "{\"music_enabled\":\"false\"}")
    expect(typeof(store.read_settings().get("music_enabled")) == TYPE_BOOL and not store.read_settings()["music_enabled"], "invalid primary music value falls back to last valid music-off backup")

func check_key_bindings() -> void:
    var store = make_store("key_bindings")
    expect(store.write_settings({"autosave": true, "key_bindings": {"confirm": 75}}).get("ok", false), "optional key bindings can be stored")
    var loaded: Dictionary = make_store("key_bindings").read_settings()
    expect(int(loaded.get("key_bindings", {}).get("confirm", 0)) == 75, "key binding integers round-trip")
    expect(bool(loaded.get("autosave", false)), "autosave remains present beside optional bindings")
    expect(make_store("no_key_bindings").read_settings() == {"autosave": true, "music_enabled": true}, "missing key bindings stay absent and do not become required")
    var original_text: String = read_text("key_bindings", "settings.json")
    expect(not store.write_settings({"autosave": true, "key_bindings": "Enter"}).get("ok", true), "key bindings must be an object")
    expect(not store.write_settings({"autosave": true, "key_bindings": {"confirm": "Enter"}}).get("ok", true), "key binding values must be integer keycodes")
    expect(not store.write_settings({"autosave": true, "key_bindings": {"confirm": 0}}).get("ok", true), "key binding values must be positive")
    expect(read_text("key_bindings", "settings.json") == original_text, "invalid key binding writes preserve the last valid preferences")
    expect(store.write_settings({"autosave": true, "future": 3, "key_bindings": {"confirm": 75, "custom_future": 12}}).get("ok", false), "unknown nested binding keys are optional extras")
    var again: Dictionary = make_store("key_bindings").read_settings()
    expect(int(again.get("key_bindings", {}).get("custom_future", 0)) == 12 and again.get("future", 0) == 3, "unknown extras beside and inside key bindings are preserved")

