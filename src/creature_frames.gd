extends Node2D
## One complete drawing per frame. The only transform is horizontal facing
## and uniform sizing, with a common registration point baked into the atlas.

const DATA_PATH := "res://assets/encounters/creature_frames.json"
const ATLAS_PATH := "res://assets/encounters/creature_frames.png"
const WALK_FRAMES := 4
const ANTICIPATION := 4
const ATTACK := 5
static var library: Dictionary = {}
static var atlas: Texture2D

var ready_to_draw := false
var frame := 0
var sample_rects: Array[Rect2] = []
var draw_rects: Array[Rect2] = []
var attacks: Dictionary = {}
var active_clip: String = ""
var displayed_clip: String = ""
var size_factor := 1.0

func configure(form: String, width: float) -> void:
    if atlas == null and ResourceLoader.exists(ATLAS_PATH) and FileAccess.file_exists(DATA_PATH):
        atlas = load(ATLAS_PATH)
        library = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    var key: String = "tank" if form == "boss" else form
    if not library.has(key):
        key = key.trim_suffix("_dark")
    sample_rects.clear()
    draw_rects.clear()
    attacks.clear()
    active_clip = ""
    displayed_clip = ""
    frame = 0
    ready_to_draw = library.has(key)
    if not ready_to_draw:
        return
    var data: Dictionary = library[key]
    size_factor = width / float(data.extent)
    for f in data.frames:
        var bounds := Rect2(f[0], f[1], f[2], f[3])
        sample_rects.append(bounds)
        draw_rects.append(Rect2(Vector2(f[4], f[5]) * size_factor, bounds.size * size_factor))
    var extra: String = str({"fernmask":"sweep","cinderback":"stomp","drumjaw":"bite"}.get(form, ""))
    if not extra.is_empty() and library.has(key + "_" + extra):
        var extra_data: Dictionary = library[key + "_" + extra]
        var extra_scale: float = width / float(extra_data.extent)
        var clips: Array[Array] = []
        var main_ground: float = (float(data.frames[0][5]) + float(data.frames[0][3])) * size_factor
        var extra_ground: float = (float(extra_data.frames[0][5]) + float(extra_data.frames[0][3])) * extra_scale
        for f in extra_data.frames:
            var bounds := Rect2(f[0], f[1], f[2], f[3])
            var offset: Vector2 = Vector2(f[4], f[5]) * extra_scale + Vector2(0.0,main_ground - extra_ground)
            clips.append([bounds, Rect2(offset, bounds.size * extra_scale)])
        attacks[extra] = clips
    queue_redraw()

func pose(phase: float, moving: bool, action: String, time: float, facing: float) -> void:
    if not ready_to_draw:
        return
    var pose_index: int = select_frame(phase, moving, action, time)
    var clip: String = action.trim_suffix("_prep")
    if action == "pounce" and attacks.has("bite"):
        clip = "bite"
    if action == "recover":
        clip = active_clip
    if attacks.has(clip):
        active_clip = clip
        if action.ends_with("_prep"):
            pose_index = 0 if clip == "bite" or time < 0.23 else 1
        elif action == "recover":
            pose_index = 3
        elif clip == "bite" and time < 0.11:
            pose_index = 1
        else:
            pose_index = 2 if time < 0.18 else 3
    else:
        active_clip = ""
        clip = ""
    if pose_index != frame or facing != scale.x or clip != displayed_clip:
        frame = pose_index
        displayed_clip = clip
        scale = Vector2(facing, 1.0)
        queue_redraw()

static func select_frame(phase: float, moving: bool, action: String, time: float) -> int:
    match action:
        "windup", "coil", "brace", "inhale", "spit", "slam", "throw", "armored_slam", "thrower_aim", "raptor_aim", "sweep_prep", "stomp_prep", "bite_prep":
            return ANTICIPATION
        "strike", "sweep", "roar", "pounce", "breath", "roll", "charge", "dash", "stomp":
            return ATTACK
        "recover":
            return ANTICIPATION if time < 0.08 else 0
    if moving:
        return mini(WALK_FRAMES - 1, int(fposmod(phase, TAU) / TAU * WALK_FRAMES))
    return 0

func set_elite_outline(shader: Shader) -> void:
    if shader == null:
        material = null
    elif material == null:
        var outline := ShaderMaterial.new()
        outline.shader = shader
        outline.set_shader_parameter("team_color", Color("#e31b28"))
        material = outline
    queue_redraw()

func _draw() -> void:
    if not ready_to_draw:
        return
    var pair: Array = [sample_rects[frame], draw_rects[frame]] if displayed_clip.is_empty() else attacks[displayed_clip][frame]
    var sample: Rect2 = pair[0]
    var bounds: Rect2 = pair[1]
    var outline: ShaderMaterial = material as ShaderMaterial
    if outline != null:
        var texture_size: Vector2 = atlas.get_size()
        var start: Vector2 = sample.position / texture_size
        var end: Vector2 = sample.end / texture_size
        var pixels_to_world: float = bounds.size.x / sample.size.x
        outline.set_shader_parameter("region_bounds", Vector4(start.x, start.y, end.x, end.y))
        outline.set_shader_parameter("outline_width", 2.0 / pixels_to_world)
        # Atlas cells have three transparent pixels on each side for the outline.
        sample = sample.grow(3.0)
        bounds = bounds.grow(3.0 * pixels_to_world)
    draw_texture_rect_region(atlas, bounds, sample)
