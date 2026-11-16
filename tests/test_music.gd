extends SceneTree
var checks := 0
var failures := 0
func expect(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: " + label)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var music = load("res://src/music_controller.gd").new()
    music.set_enabled(false)
    root.add_child(music)
    music.set_context("grove")
    expect(music._context == "grove", "grove selects its own composition")
    music.set_context("pause")
    expect(music._track_context == "grove", "pause preserves selected grove score")
    music.set_context("grove")
    expect(music._context == "grove", "resume retains biome")
    var fingerprints: Array = []
    for ctx in ["title", "battle", "grove", "volcano"]:
        var path = "res://assets/music/v11/" + ctx + ".wav"
        expect(FileAccess.file_exists(path), "independent PCM composition " + ctx)
        var bytes = FileAccess.get_file_as_bytes(path)
        var digest := HashingContext.new()
        digest.start(HashingContext.HASH_SHA256)
        digest.update(bytes)
        var hash: String = digest.finish().hex_encode()
        expect(not fingerprints.has(hash), "scene is a distinct PCM score " + ctx)
        fingerprints.append(hash)
        if bytes.size() > 44:
            expect(bytes.slice(0, 4).get_string_from_ascii() == "RIFF", "WAV header " + ctx)
            expect(bytes.decode_u32(24) == 44100 and bytes.decode_u16(22) == 2, "stereo 44.1k " + ctx)
            var duration = float(bytes.size() - 44) / 176400.0
            expect(duration >= 24 and duration <= 32, "complete phrase " + ctx)
    for i in 20:
        music.set_enabled(true)
        music.set_context("volcano")
        music.set_context("pause")
        music.set_enabled(false)
    expect(music.get_child_count() == 0, "headless never allocates AudioStreamPlayers")
    expect(music._stream == null and music._player == null, "headless never loads streams")
    expect(not music.is_enabled(), "disabled state persists through contexts")
    music.free()
    var world = load("res://src/main.gd").new()
    world.save_store = load("res://src/save_store.gd").new("res://runtime/tests/music_navigation_" + str(Time.get_ticks_usec()))
    root.add_child(world)
    world.set_physics_process(false)
    world.start_run(true,"base")
    world.wave = 6
    world.update_hud()
    expect(world.music._context == "grove", "world selects the grove composition")
    world.toggle_pause()
    expect(world.music._context == "pause", "opening pause immediately ducks the active score")
    world.toggle_pause()
    expect(world.music._context == "grove", "closing pause immediately restores the biome score")
    world.toggle_stats()
    expect(world.music._context == "pause", "battle stats immediately duck the active score")
    world.toggle_stats()
    expect(world.music._context == "grove", "closing battle stats restores the biome score")
    world.present_upgrade("xp")
    expect(world.music._context == "pause", "growth selection immediately ducks the active score")
    world.go_home()
    expect(world.music._context == "title", "returning home immediately selects the title score")
    world.queue_free()
    await process_frame
    print("MUSIC RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
