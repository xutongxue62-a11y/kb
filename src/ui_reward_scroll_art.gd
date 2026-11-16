extends RefCounted
## Reward-only scroll illustration. Native flat paint, no generated replacement art.
const Edge=preload("res://src/ui_paper_edge.gd")
const Pattern=preload("res://src/ui_paper_pattern.gd")
const PAPER:=Color("#e7d4b0")
const OUTLINE:=Color("#796246")

static func outline(area: Rect2) -> PackedVector2Array:
    var w: float=area.size.x
    var h: float=area.size.y
    if w<30 or h<30:
        return PackedVector2Array([area.position,area.position+Vector2(w,0),area.end,area.position+Vector2(0,h)])
    var shape:=PackedVector2Array([
        Vector2(5,10),Vector2(w*0.18,12),Vector2(w*0.39,7),Vector2(w*0.64,11),
        Vector2(w*0.84,8),Vector2(w-5,12),Vector2(w-6,h-12),
        Vector2(w*0.81,h-7),Vector2(w*0.60,h-11),Vector2(w*0.39,h-6),
        Vector2(w*0.18,h-10),Vector2(5,h-7)])
    var result: PackedVector2Array=Edge.fray(shape,3.1,43)
    for i in range(result.size()): result[i]+=area.position
    return result

static func draw_body(canvas: CanvasItem,area: Rect2,points: PackedVector2Array) -> void:
    var shadow:=PackedVector2Array()
    for point in points: shadow.append(point+Vector2(3,6))
    canvas.draw_colored_polygon(shadow,Color(0.20,0.12,0.055,0.23))
    canvas.draw_colored_polygon(points,PAPER)
    var w: float=area.size.x
    var h: float=area.size.y
    # Small, fixed strokes sit in the paper rather than making a vignette or gradient.
    for i in range(58):
        var x: float=35+fposmod(i*137.71,maxf(1,w-84))
        var y: float=24+fposmod(i*73.37,maxf(1,h-52))
        var length: float=9+fposmod(i*7.43,29)
        if x+length>w-29: continue
        var at:=area.position+Vector2(x,y)
        canvas.draw_polyline(PackedVector2Array([at,at+Vector2(length*0.56,-0.7),at+Vector2(length,0.4)]),Color(1.0,0.96,0.78,0.14),1.4,true)
    # Flat rim strokes give a painted thickness without a rectangular inset frame.
    for i in range(1,points.size()-1):
        var a: Vector2=points[i]
        var b: Vector2=points[i+1]
        if a.y>area.end.y-19 and b.y>area.end.y-19:
            canvas.draw_line(a+Vector2(0,-2),b+Vector2(0,-2),Color("#c8af85"),2.1,true)
        elif a.y<area.position.y+18 and b.y<area.position.y+18:
            canvas.draw_line(a+Vector2(0,2),b+Vector2(0,2),Color("#f5e8cd"),2.0,true)
    var border: PackedVector2Array=points.duplicate();border.append(points[0])
    Pattern.draw_scroll(canvas,area)
    canvas.draw_polyline(border,Color("#a48a64"),1.6,true)
    Edge.fibres(canvas,points,43,0.7)

static func ellipse(center: Vector2,radius: Vector2) -> PackedVector2Array:
    var result:=PackedVector2Array()
    for i in range(41):
        var angle: float=TAU*i/40.0
        result.append(center+Vector2(cos(angle)*radius.x,sin(angle)*radius.y))
    return result

static func draw_roller(canvas: CanvasItem,x: float,h: float) -> void:
    # A broad roll with three flat paint planes, a loose lip and substantial end caps.
    var skin:=PackedVector2Array([
        Vector2(x-18,12),Vector2(x-17,h*0.29),Vector2(x-19,h*0.63),Vector2(x-17,h-12),
        Vector2(x+16,h-12),Vector2(x+18,h*0.66),Vector2(x+17,h*0.34),Vector2(x+18,12)])
    canvas.draw_colored_polygon(skin,Color("#cdb58f"))
    canvas.draw_colored_polygon(PackedVector2Array([Vector2(x-16,13),Vector2(x-8,13),Vector2(x-7,h-13),Vector2(x-16,h-13)]),Color("#e8d8b7"))
    canvas.draw_colored_polygon(PackedVector2Array([Vector2(x+9,13),Vector2(x+17,13),Vector2(x+16,h-13),Vector2(x+8,h-13)]),Color("#ac916c"))
    var rim: PackedVector2Array=skin.duplicate();rim.append(skin[0])
    canvas.draw_polyline(rim,OUTLINE,2.1,true)
    canvas.draw_polyline(PackedVector2Array([Vector2(x-6,24),Vector2(x-5,h*0.47),Vector2(x-6,h-26)]),Color("#f3e5c9"),1.6,true)
    for i in range(8):
        var y: float=34+float(i)*(h-68)/8.0
        canvas.draw_line(Vector2(x-13,y),Vector2(x-8,y+1),Color(0.46,0.29,0.12,0.17),1.0,true)
    for y in [12.0,h-12.0]:
        var cap: PackedVector2Array=ellipse(Vector2(x,y),Vector2(20,7.5))
        canvas.draw_colored_polygon(cap,Color("#e9d9b9"))
        canvas.draw_polyline(cap,OUTLINE,2.1,true)
        var spiral:=PackedVector2Array()
        for i in range(39):
            var a: float=TAU*1.45*i/38.0
            var r: float=14.5*(1-i/43.0)
            spiral.append(Vector2(x+cos(a)*r,y+sin(a)*r*0.32))
        canvas.draw_polyline(spiral,Color("#a58a64"),1.35,true)

static func draw_rollers(canvas: CanvasItem,area: Rect2) -> void:
    draw_roller(canvas,17,area.size.y)
    draw_roller(canvas,area.size.x-17,area.size.y)
