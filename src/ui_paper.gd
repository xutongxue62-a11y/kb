extends Control
const Edge=preload("res://src/ui_paper_edge.gd")
const RewardArt=preload("res://src/ui_reward_scroll_art.gd")

var content: Control
var content_clip: Control
var roll_foreground: Control
var reward_style: bool=false:
    set(value):
        reward_style=value
        queue_redraw()
        if roll_foreground!=null: roll_foreground.queue_redraw()

class RollerForeground:
    extends Control
    var sheet
    func _draw() -> void:
        sheet.draw_rollers(self)

var paper := Color("#f1e6cd")
var ink := Color("#192639")
var paper_texture: Texture2D = preload("res://assets/ui/paper_grain_v01.png")
var opening_mode: String = "scroll":
    set(value):
        opening_mode = value
        _resize_content()
        queue_redraw()
var reveal: float = 1.0:
    set(value):
        reveal = clampf(value, 0.0, 1.0)
        _resize_content()
        queue_redraw()
        if roll_foreground != null: roll_foreground.queue_redraw()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    content_clip = Control.new()
    content_clip.name = "PaperClip"
    content_clip.clip_contents = true
    content_clip.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(content_clip)
    content = Control.new()
    content.name = "PaperContent"
    content.mouse_filter = Control.MOUSE_FILTER_PASS
    content_clip.add_child(content)
    roll_foreground = RollerForeground.new()
    roll_foreground.sheet = self
    roll_foreground.name = "RollerForeground"
    roll_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(roll_foreground)
    roll_foreground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _resize_content()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _resize_content()
        queue_redraw()

func _paper_rect() -> Rect2:
    if opening_mode == "scroll":
        return Rect2(0, 0, maxf(44, size.x * reveal), size.y)
    if opening_mode == "fold":
        return Rect2(0, size.y * (1 - reveal) * 0.5, size.x, size.y * reveal)
    return Rect2(Vector2.ZERO, size)

func visible_content_rect() -> Rect2:
    var area: Rect2 = _paper_rect()
    if opening_mode == "scroll":
        area.position += Vector2(38,22)
        area.size = Vector2(maxf(0,area.size.x-76),maxf(0,area.size.y-44))
    return area

func _resize_content() -> void:
    if content == null or content_clip == null:
        return
    if roll_foreground != null: roll_foreground.queue_redraw()
    var area := visible_content_rect()
    content_clip.position = area.position
    content_clip.size = area.size
    content.position = -area.position
    content.size = size

func outline() -> PackedVector2Array:
    var area := _paper_rect()
    if reward_style: return RewardArt.outline(area)
    var w: float = area.size.x
    var h: float = area.size.y
    if w < 19 or h < 19:
        return PackedVector2Array([area.position, area.position + Vector2(w, 0), area.end, area.position + Vector2(0, h)])
    var pts:=Edge.fray(PackedVector2Array([Vector2(4,4),Vector2(w-4,4),Vector2(w-4,h-4),Vector2(4,h-4)]),minf(8.5,minf(w,h)*0.09),37)
    for i in range(pts.size()): pts[i] += area.position
    return pts

func _roller(x: float, target: CanvasItem) -> void:
    var h: float = size.y
    var skin:=Edge.fray(PackedVector2Array([Vector2(x-14,9),Vector2(x+14,9),Vector2(x+14,h-9),Vector2(x-14,h-9)]),1.7,19)
    target.draw_colored_polygon(skin,Color("#c6a982"))
    target.draw_rect(Rect2(x - 8, 9, 11, h - 18), Color("#f7ecd3"))
    target.draw_line(Vector2(x + 12, 12), Vector2(x + 12, h - 12), Color("#725b40"), 1.4, true)
    for y in [11.0, h - 11]:
        var rim := PackedVector2Array()
        for i in range(33):
            var a: float = TAU * i / 32
            rim.append(Vector2(x + cos(a) * 14, y + sin(a) * 6))
        target.draw_colored_polygon(rim, paper.darkened(0.10))
        target.draw_polyline(rim, Color(ink, 0.65), 1.3, true)
        var spiral := PackedVector2Array()
        for i in range(31):
            var a: float = TAU * 1.7 * i / 30
            var r: float = 10 * (1 - i / 34.0)
            spiral.append(Vector2(x + cos(a) * r, y + sin(a) * r * 0.38))
        target.draw_polyline(spiral, Color("#8d7250"), 1, true)
    for i in range(4):
        var y: float = 32 + fmod(i * 103.0 + reveal * 76, maxf(1, h - 62))
        target.draw_line(Vector2(x - 5, y), Vector2(x + 3, y + 9), Color(0.35, 0.27, 0.18, 0.15), 1, true)

func draw_rollers(target: CanvasItem) -> void:
    if opening_mode != "scroll": return
    var area := _paper_rect()
    if reward_style:
        RewardArt.draw_rollers(target,area)
        return
    _roller(17,target)
    _roller(area.size.x-17,target)

func _draw() -> void:
    var area := _paper_rect()
    if area.size.x < 3 or area.size.y < 3:
        return
    var pts := outline()
    if reward_style:
        RewardArt.draw_body(self,area,pts)
        return
    var shadow := PackedVector2Array()
    var uv := PackedVector2Array()
    for point in pts:
        shadow.append(point + Vector2(4, 6))
        uv.append(point / size)
    draw_colored_polygon(shadow, Color(0.02, 0.05, 0.1, 0.24))
    draw_colored_polygon(pts, Color.WHITE, uv, paper_texture)
    Edge.fibres(self,pts,37,1.4)
    pts.append(pts[0])
    draw_polyline(pts, Color(ink, 0.36), 1.1, true)
    if opening_mode == "fold" and reveal < 0.98:
        var crease := Color(ink, (1 - reveal) * 0.30)
        draw_line(Vector2(10, area.position.y + 3), Vector2(size.x - 10, area.position.y + 3), crease, 2, true)
        draw_line(Vector2(10, area.end.y - 3), Vector2(size.x - 10, area.end.y - 3), crease, 2, true)
        draw_line(Vector2(10, size.y * 0.5), Vector2(size.x - 10, size.y * 0.5), Color(ink, (1 - reveal) * 0.12), 1, true)
