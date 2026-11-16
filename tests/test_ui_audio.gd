extends SceneTree

var checks: int = 0
var failures: int = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func _initialize() -> void:
    call_deferred("run_checks")

func run_checks() -> void:
    var script_path: String = "res://src/ui_audio.gd"
    expect(FileAccess.file_exists(script_path), "a dedicated semantic UI audio service exists")
    if not FileAccess.file_exists(script_path):
        finish()
        return
    var audio_script = load(script_path)
    var cues: Array[String] = ["button_press", "paper_popup", "page_turn", "scroll_unroll", "paper_close", "parchment_burn", "choice_confirm"]
    var unique_files: Dictionary = {}
    var unique_hashes: Dictionary = {}
    for key in cues:
        var cue: Dictionary = audio_script.spec(key)
        expect(cue.has("file") and cue.has("gain_db") and cue.has("min_gap_ms"), "semantic cue has a file, gain and debounce: " + key)
        if not cue.has("file"):
            continue
        expect(FileAccess.file_exists(cue.file), "semantic cue resolves to an existing WAV: " + key)
        unique_files[cue.file] = true
        expect(str(cue.file).contains("/ui_v09/"), "rejected v08 timbre is replaced: " + key)
        if FileAccess.file_exists(cue.file):
            unique_hashes[FileAccess.get_sha256(cue.file)] = true
            check_pcm(key, cue)
            var previous: String = "res://assets/sfx/ui_v08/" + key + ".wav"
            expect(FileAccess.get_sha256(cue.file) != FileAccess.get_sha256(previous), "cue is resynthesized rather than reused: " + key)
        expect(float(cue.gain_db) <= 0.0, "UI playback never boosts the quiet source: " + key)
    expect(unique_hashes.size() == 7, "all seven cues contain distinct PCM data")
    expect(unique_files.size() == 7, "each UI action has its own source recording")
    expect(audio_script.spec("hover").is_empty(), "hover has no audible mapping")
    expect(audio_script.spec("ui_open").is_empty(), "legacy generic UI sweeps cannot reappear through this service")
    expect(audio_script.spec("unknown").is_empty(), "unknown cues are silent")
    var changed_spec: Dictionary = audio_script.spec("page_turn")
    changed_spec["file"] = "res://does_not_exist.wav"
    expect(audio_script.spec("page_turn").file != changed_spec.file, "callers cannot corrupt the shared cue mapping")

    var audio = audio_script.new()
    root.add_child(audio)
    expect(audio.get_child_count() == 0 and audio._streams.is_empty(), "headless startup creates no audio players or loaded audio streams")
    for key in cues:
        audio.play(key)
    expect(audio.get_child_count() == 0 and audio._streams.is_empty(), "headless semantic requests remain silent without audio allocation")
    expect(audio._last_play_ms.is_empty(), "headless requests do not spend audible cooldowns")
    expect(audio._reserve_voice_at("unknown", 1000) == -1, "unknown requests cannot consume a voice")
    expect(audio._reserve_voice_at("button_press", 1000) == 0, "first tactile cue receives a voice")
    var gap: int = int(audio_script.spec("button_press").min_gap_ms)
    expect(audio._reserve_voice_at("button_press", 1000 + gap - 1) == -1, "repeated press is suppressed inside its semantic cooldown")
    expect(audio._reserve_voice_at("button_press", 1000 + gap) >= 0, "press becomes eligible exactly at its cooldown boundary")
    audio.queue_free()
    await process_frame

    audio = audio_script.new()
    root.add_child(audio)
    var overlapping: Array[String] = ["scroll_unroll", "parchment_burn", "page_turn", "paper_popup"]
    for index in overlapping.size():
        expect(audio._reserve_voice_at(overlapping[index], 2000) == index, "distinct overlapping cues occupy one bounded voice each")
    expect(audio._reserve_voice_at("choice_confirm", 2000) == -1, "fifth overlapping cue is dropped rather than stacked or interrupting a tail")
    expect(not audio._last_play_ms.has("choice_confirm"), "a full pool does not consume the dropped cue cooldown")
    expect(audio._reserve_voice_at("choice_confirm", 2146) == 3, "a finished short popup frees its voice for the next cue")
    audio.queue_free()
    await process_frame
    finish()

func check_pcm(key: String, cue: Dictionary) -> void:
    var data: PackedByteArray = FileAccess.get_file_as_bytes(cue.file)
    expect(data.size() >= 44 and data.slice(0, 4).get_string_from_ascii() == "RIFF", "PCM WAV header: " + key)
    if data.size() < 44:
        return
    expect(data.decode_u16(20) == 1 and data.decode_u16(22) == 1 and data.decode_u16(34) == 16, "mono 16-bit PCM: " + key)
    var rate: int = data.decode_u32(24)
    expect(rate == 44100, "44.1kHz source: " + key)
    var count: int = (data.size() - 44) / 2
    var duration: float = float(count) / rate
    var limit: float = 0.5 if key == "parchment_burn" else 0.33
    expect(duration <= limit, "crisp cues have short bounded tails: " + key)
    expect(absf(duration * 1000.0 - float(cue.duration_ms)) < 1.0, "scheduler covers actual clip duration: " + key)
    var peak: float = 0.0
    var total: float = 0.0
    for index in count:
        var sample: float = float(data.decode_s16(44 + index * 2)) / 32768.0
        peak = maxf(peak, absf(sample))
        total += sample
    var audible_peak_db: float = linear_to_db(peak) + float(cue.gain_db)
    if key == "parchment_burn":
        expect(audible_peak_db >= -23.0 and audible_peak_db <= -18.0, "burn stays softer: " + key)
    else:
        expect(audible_peak_db >= -16.1 and audible_peak_db <= -12.0, "short cue playback has restrained clear headroom: " + key)
    expect(absf(total / count) < 0.0001, "negligible PCM DC: " + key)
    expect(data.decode_s16(44) == 0 and data.decode_s16(data.size() - 2) == 0, "zero endpoints avoid hard cuts: " + key)

func finish() -> void:
    print("UI_AUDIO RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
