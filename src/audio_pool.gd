extends Node

const NAMES = ["wood_hit", "stone_hit", "swing", "sling", "powder", "blast", "magic", "magic_hit", "chain_out", "chain_in", "step", "hurt", "pickup_gold", "pickup_xp", "pickup_heal", "level_up", "enemy_death", "boss_appear", "boss_defeat", "win", "lose"]
const ALIASES := {"pickup_gold": "ui_click", "pickup_xp": "ui_hover", "pickup_heal": "magic", "level_up": "ui_open", "enemy_death": "stone_hit", "boss_appear": "blast", "boss_defeat": "blast", "win": "ui_open", "lose": "hurt"}
const BASE_DB: float = -24.0
const MIN_DB: float = -36.0
const MAX_DB: float = -12.0
var streams: Dictionary = {}
var voices: Array = []
var cooldowns: Dictionary = {}
var volume: float = 1.0

func _ready() -> void:
    if DisplayServer.get_name() == "headless":
        return
    for key in NAMES:
        var path: String = "res://assets/sfx/%s.wav" % key
        if ResourceLoader.exists(path):
            streams[key] = load(path)
        elif ALIASES.has(key) and ResourceLoader.exists("res://assets/sfx/%s.wav" % ALIASES[key]):
            streams[key] = load("res://assets/sfx/%s.wav" % ALIASES[key])
    for index in range(8):
        var voice: AudioStreamPlayer = AudioStreamPlayer.new()
        voice.volume_db = BASE_DB
        add_child(voice)
        voices.append(voice)

func advance(delta: float) -> void:
    for key in cooldowns.keys():
        cooldowns[key] = maxf(0.0, cooldowns[key] - delta)

func _cooldown_for(key: String) -> float:
    if key == "step":
        return 0.22
    if key == "hurt":
        return 0.18
    if key.begins_with("pickup_"):
        return 0.12
    if key in ["enemy_death", "level_up", "win", "lose", "boss_appear", "boss_defeat"]:
        return 0.28
    return 0.20

func set_volume(value: float) -> void:
    volume = clampf(value, 0.0, 1.0)
    for voice in voices:
        if volume <= 0.0001:
            voice.stop()
        else:
            voice.volume_db = float(voice.get_meta("base_gain_db", BASE_DB)) + linear_to_db(volume)

func play(key: String, gain: float = 0.0, pitch: float = 1.0) -> void:
    if volume <= 0.0001 or not streams.has(key) or float(cooldowns.get(key, 0.0)) > 0.0:
        return
    cooldowns[key] = _cooldown_for(key)
    var volume_db: float = linear_to_db(volume)
    for voice in voices:
        if not voice.playing:
            voice.stream = streams[key]
            var base_gain: float = clampf(BASE_DB + gain, MIN_DB, MAX_DB)
            voice.set_meta("base_gain_db", base_gain)
            voice.volume_db = base_gain + volume_db
            voice.pitch_scale = pitch
            voice.play()
            return

func set_paused(value: bool) -> void:
    for voice in voices:
        voice.stream_paused = value

func stop_all() -> void:
    for voice in voices:
        voice.stop()
        voice.stream = null
        voice.stream_paused = false
    cooldowns.clear()

func _exit_tree() -> void:
    stop_all()
    streams.clear()
