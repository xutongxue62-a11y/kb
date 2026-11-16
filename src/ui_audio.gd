class_name UIAudio
extends Node

## Short, bright semantic pluck/tick UI cues. Gameplay sound remains in audio_pool.gd.
## Requests during headless tests never create players or load audio resources.
const VOICE_LIMIT: int = 4
const CUES: Dictionary = {
    "button_hover": {"file":"res://assets/sfx/ui_v09/button_press.wav","gain_db":-6.0,"pitch":1.35,"min_gap_ms":90,"duration_ms":60},
    "button_press": {"file": "res://assets/sfx/ui_v09/button_press.wav", "gain_db": -3.0, "min_gap_ms": 90, "duration_ms": 60},
    "paper_popup": {"file": "res://assets/sfx/ui_v09/paper_popup.wav", "gain_db": -2.0, "min_gap_ms": 170, "duration_ms": 130},
    "page_turn": {"file": "res://assets/sfx/ui_v09/page_turn.wav", "gain_db": -3.0, "min_gap_ms": 240, "duration_ms": 200},
    "scroll_unroll": {"file": "res://assets/sfx/ui_v09/scroll_unroll.wav", "gain_db": -4.0, "min_gap_ms": 400, "duration_ms": 300},
    "paper_close": {"file": "res://assets/sfx/ui_v09/paper_close.wav", "gain_db": -2.0, "min_gap_ms": 140, "duration_ms": 95},
    "parchment_burn": {"file": "res://assets/sfx/ui_v09/parchment_burn.wav", "gain_db": -5.0, "min_gap_ms": 800, "duration_ms": 460},
    "choice_confirm": {"file": "res://assets/sfx/ui_v09/choice_confirm.wav", "gain_db": -1.0, "min_gap_ms": 150, "duration_ms": 150},
}

var _voices: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _voice_until_ms: Array[int] = [0, 0, 0, 0]
var _last_play_ms: Dictionary = {}
var volume: float = 1.0

func set_volume(value: float) -> void:
    volume = clampf(value, 0.0, 1.0)
    for voice in _voices:
        if volume <= 0.0001:
            voice.stop()
        else:
            voice.volume_db = float(voice.get_meta("base_gain_db", 0.0)) + linear_to_db(volume)

static func spec(key: String) -> Dictionary:
    # Explicit semantic cues only; unknown and legacy raw keys remain silent.
    return CUES.get(key, {}).duplicate(true)

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    if DisplayServer.get_name() == "headless":
        return
    for key in CUES:
        var file: String = CUES[key].file
        if ResourceLoader.exists(file):
            _streams[key] = load(file)
    for index in VOICE_LIMIT:
        var voice := AudioStreamPlayer.new()
        voice.process_mode = Node.PROCESS_MODE_ALWAYS
        voice.bus = &"Master"
        add_child(voice)
        _voices.append(voice)

func play(key: String) -> void:
    # Check before looking up/loading a stream, reserving a slot, or touching AudioServer.
    if volume <= 0.0001 or DisplayServer.get_name() == "headless" or not is_inside_tree():
        return
    if not _streams.has(key) or _streams[key] == null or _voices.is_empty():
        return
    var slot: int = _reserve_voice_at(key, Time.get_ticks_msec())
    if slot < 0:
        return
    var voice: AudioStreamPlayer = _voices[slot]
    voice.stream = _streams[key]
    voice.set_meta("base_gain_db", float(CUES[key].gain_db))
    voice.volume_db = float(CUES[key].gain_db) + linear_to_db(volume)
    voice.pitch_scale = float(CUES[key].get("pitch",1.0))
    voice.play()

func _reserve_voice_at(key: String, now_ms: int) -> int:
    # Keep finished tails intact: a full four-voice pool drops the new request.
    # Using the clip length also makes this scheduler deterministic without a sound device.
    if not CUES.has(key):
        return -1
    var cue: Dictionary = CUES[key]
    if key=="button_hover":
        var free:=0
        for slot in VOICE_LIMIT:
            if _voice_until_ms[slot]<=now_ms and (_voices.is_empty() or not _voices[slot].playing): free+=1
        if free<2: return -1 # Leave a voice for a click or page cue.
    if _last_play_ms.has(key) and now_ms - int(_last_play_ms[key]) < int(cue.min_gap_ms):
        return -1
    for slot in VOICE_LIMIT:
        if _voice_until_ms[slot] > now_ms:
            continue
        if not _voices.is_empty() and _voices[slot].playing:
            continue
        _voice_until_ms[slot] = now_ms + int(cue.duration_ms) + 16
        _last_play_ms[key] = now_ms
        return slot
    return -1
