extends SceneTree
var checks:=0
var failures:=0
func expect(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures+=1;print("FAIL: "+label)
func _initialize() -> void:
    var library=load("res://src/asset_library.gd").new()
    for kind in library.Catalog.DINOS:
        var view=load("res://src/dino_view.gd").new()
        view.setup(library,kind,float(library.Catalog.DINOS[kind].size),false)
        var scale_before: Vector2=view.base_scale
        var surface: Sprite2D=view.find_child("SurfaceArt",true,false) as Sprite2D
        expect(surface!=null,kind+" has a dedicated scale/armor/skin detail layer")
        if surface!=null:
            expect(surface.texture!=null and surface.texture.get_size()==view.sprite.texture.get_size(),kind+" details share the original padded body canvas")
            expect(surface.material.get_shader_parameter("body_mask")==view.sprite.texture,kind+" material details are clipped to the original body silhouette")
            for velocity in [Vector2(-120,0),Vector2(120,0)]:
                view.animate(velocity,0.1)
                expect(surface.flip_h==view.sprite.flip_h,kind+" surface follows both facing directions")
            expect(view.base_scale==scale_before,kind+" surface does not change combat/body scale")
        view.free()
    check_boss_spines(library)
    check_later_bosses_have_no_procedural_crests()
    print("MONSTER SURFACE V16 RESULT: %d checks, %d failures" % [checks,failures])
    quit(1 if failures else 0)

func is_cream(c: Color) -> bool:
    return c.a > 0.6 and c.r > 0.78 and c.g > 0.68 and c.b > 0.52 and c.b < 0.85 and c.r > c.b + 0.08

func is_gold(c: Color) -> bool:
    return c.a > 0.25 and c.r > 0.70 and c.g > 0.55 and c.b > 0.35 and c.b < 0.82 and c.r > c.b + 0.08

func check_boss_spines(library) -> void:
    var view = load("res://src/dino_view.gd").new()
    view.setup(library, "boss", 158.0, false)
    var body: Image = view.sprite.texture.get_image()
    var surface_img: Image = view.surface.texture.get_image()
    expect(body != null and surface_img != null, "boss body and surface can be rasterized")
    if body == null or surface_img == null:
        view.free()
        return
    var horns := [
        {"name": "left", "rect": Rect2i(174, 116, 88, 64)},
        {"name": "middle", "rect": Rect2i(274, 75, 99, 70)},
        {"name": "right", "rect": Rect2i(385, 115, 89, 66)},
    ]
    var gold_outside := 0
    var gold_total := 0
    for y in range(body.get_height()):
        for x in range(body.get_width()):
            var paint: Color = surface_img.get_pixel(x, y)
            paint.a *= body.get_pixel(x, y).a
            if not is_gold(paint):
                continue
            gold_total += 1
            var inside := false
            for horn in horns:
                if (horn["rect"] as Rect2i).grow(10).has_point(Vector2i(x, y)):
                    inside = true
                    break
            if not inside:
                gold_outside += 1
    expect(gold_total >= 2000, "boss surface paints gold onto the back horns")
    expect(gold_outside * 20 <= gold_total, "gold horn paint stays on the back plates and does not hang down the sides")
    for horn in horns:
        var rect: Rect2i = horn["rect"]
        var cream := 0
        var covered := 0
        var tip_gold := 0
        var base_gold := 0
        var tip_y: int = rect.position.y + int(round(rect.size.y * 0.22))
        var base_y: int = rect.position.y + int(round(rect.size.y * 0.78))
        for y in range(rect.position.y, rect.end.y):
            for x in range(rect.position.x, rect.end.x):
                if not is_cream(body.get_pixel(x, y)):
                    continue
                cream += 1
                var paint: Color = surface_img.get_pixel(x, y)
                paint.a *= body.get_pixel(x, y).a
                if is_gold(paint):
                    covered += 1
                    if y <= tip_y:
                        tip_gold += 1
                    if y >= base_y:
                        base_gold += 1
        expect(cream >= 800, horn["name"] + " horn interior was measured")
        expect(covered * 2 >= cream, horn["name"] + " horn fill covers the interior instead of floating above it")
        expect(tip_gold >= 20, horn["name"] + " horn tip is painted")
        expect(base_gold >= 20, horn["name"] + " horn root sits on the back plate")
    view.free()

func check_later_bosses_have_no_procedural_crests() -> void:
    var source := FileAccess.get_file_as_string("res://src/dino_view.gd")
    expect(source.find("draw_colored_polygon(crest") == -1, "later bosses must not get a second pass of triangular crests in DinoView._draw")
    expect(source.find("Color(\"#7f4850\")") == -1, "procedural crest ink is gone")
    expect(source.find("Color(\"#c4a477\")") == -1, "procedural crest fill is gone")
