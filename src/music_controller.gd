class_name MusicController
extends Node

## Four distinct original scores. Main owns preference persistence.
const TRACKS: Dictionary = {"title": "res://assets/music/v11/title.wav", "battle": "res://assets/music/v11/battle.wav", "grove": "res://assets/music/v11/grove.wav", "volcano": "res://assets/music/v11/volcano.wav"}
const LOOP_PATH: String = "res://assets/music/v11/title.wav"
const FADE_SECONDS: float = 0.35
const CONTEXT_GAIN_DB: Dictionary = {"title": -10.0, "battle": -12.0, "grove": -11.0, "volcano": -11.0, "pause": -18.0}
var _enabled := true
var _volume: float = 1.0
var _context := "title"
var _track_context := "title"
var _playing_context := ""
var _players: Array[AudioStreamPlayer] = []
var _mix_gain_db: Array[float] = [-60.0, -60.0]
var _active := 0
var _fade: Tween = null
# Compatibility/debug references; both remain null in headless mode.
var _player: AudioStreamPlayer = null
var _stream: AudioStreamWAV = null

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    if _enabled and DisplayServer.get_name() != "headless": _start()

func is_enabled() -> bool:
    return _enabled

func set_volume(value: float) -> void:
    _volume = clampf(value, 0.0, 1.0)
    if DisplayServer.get_name() == "headless" or _players.is_empty():
        return
    for index in range(_players.size()):
        _set_mix_gain(_mix_gain_db[index], index)

func _context_db(context: String) -> float:
    return float(CONTEXT_GAIN_DB.get(context, -12.0))

# Scene fades change only the mix. User volume is applied at every fade step,
# so an in-flight crossfade cannot restore an old slider value or undo mute.
func _set_mix_gain(gain_db: float, index: int) -> void:
    _mix_gain_db[index] = gain_db
    _players[index].volume_db = -80.0 if _volume <= 0.0001 else gain_db + linear_to_db(_volume)

func set_enabled(enabled: bool) -> void:
    _enabled = enabled
    if DisplayServer.get_name() == "headless" or not is_node_ready(): return
    if enabled:
        _start()
    else:
        _kill_fade()
        for player in _players: player.stop()
        _playing_context = ""

func set_context(context: String) -> void:
    if not CONTEXT_GAIN_DB.has(context) or context == _context: return
    _context = context
    # Pause ducks the currently playing biome. It never selects a new stream.
    if context != "pause": _track_context = context
    if _enabled and is_node_ready() and DisplayServer.get_name() != "headless": _start()

func _kill_fade() -> void:
    if _fade != null and _fade.is_valid(): _fade.kill()

func _start() -> void:
    if _players.is_empty():
        for index in 2:
            var player := AudioStreamPlayer.new()
            player.name = "SceneMusic%d" % index
            player.process_mode = Node.PROCESS_MODE_ALWAYS
            player.bus = &"Master"
            add_child(player)
            _players.append(player)
    if _playing_context == _track_context and _players[_active].playing:
        _kill_fade()
        # Finish retiring the other slot even if a previous crossfade was interrupted.
        _players[1 - _active].stop()
        _fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _fade.tween_method(_set_mix_gain.bind(_active), _mix_gain_db[_active], _context_db(_context), FADE_SECONDS)
        return
    var stream := load(TRACKS[_track_context]) as AudioStreamWAV
    if stream == null:
        push_warning("Missing scene score: " + str(TRACKS[_track_context]))
        return
    _kill_fade()
    stream = stream.duplicate() as AudioStreamWAV
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = stream.data.size() / (4 if stream.stereo else 2)
    var retiring := _active
    _active = 1 - _active
    _player = _players[_active]
    _player.stop()
    _stream = stream
    _player.stream = stream
    _set_mix_gain(-60.0, _active)
    _player.play()
    _playing_context = _track_context
    _fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _fade.set_parallel(true)
    _fade.tween_method(_set_mix_gain.bind(_active), _mix_gain_db[_active], _context_db(_context), FADE_SECONDS)
    _fade.tween_method(_set_mix_gain.bind(retiring), _mix_gain_db[retiring], -60.0, FADE_SECONDS)
    _fade.chain().tween_callback(_players[retiring].stop)
