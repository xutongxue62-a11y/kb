extends SceneTree

const Library = preload("res://src/asset_library.gd")
const Dino = preload("res://src/dino_view.gd")
var checks: int = 0
var failures: int = 0

func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + message)

func _initialize() -> void:
    var library = Library.new()
    var source: Image = library.atlases["dinosaurs"].get_image()
    for kind in ["hunter", "charger", "spitter", "tank", "boss"]:
        var texture: Texture2D = library.texture("dinosaurs", kind)
        expect(not texture is AtlasTexture, kind + " isolates the dinosaur from sibling atlas sampling")
        var image: Image = texture.get_image()
        var bounds: Rect2i = image.get_used_rect()
        var original: Rect2i = Rect2i(library.region("dinosaurs", kind))
        var offset: Vector2i = (image.get_size() - original.size) / 2
        var min_margin: int = mini(mini(bounds.position.x, bounds.position.y), mini(image.get_width() - bounds.end.x, image.get_height() - bounds.end.y))
        expect(min_margin >= 24, kind + " has transparent quad margin around actual nonzero alpha")
        var preserved: bool = true
        var clean_noise: bool = true
        for y in range(original.size.y):
            for x in range(original.size.x):
                var before: Color = source.get_pixelv(original.position + Vector2i(x, y))
                var after: Color = image.get_pixelv(offset + Vector2i(x, y))
                if before.a > 8.0 / 255.0 and not before.is_equal_approx(after):
                    preserved = false
                if before.a <= 8.0 / 255.0 and after.a != 0.0:
                    clean_noise = false
        expect(preserved, kind + " preserves every meaningful body RGBA pixel")
        expect(clean_noise, kind + " suppresses near-transparent atlas background noise")
        # Every meaningful fringe pixel within eight pixels of the old cut is retained,
        # while the output beyond that isolated extraction stays completely transparent.
        var fringe_preserved: bool = true
        var isolated: bool = true
        for y in range(image.get_height()):
            for x in range(image.get_width()):
                var relative: Vector2i = Vector2i(x, y) - offset
                var after: Color = image.get_pixel(x, y)
                if Rect2i(Vector2i(-8, -8), original.size + Vector2i(16, 16)).has_point(relative):
                    var before: Color = source.get_pixelv(original.position + relative)
                    if before.a > 8.0 / 255.0 and not before.is_equal_approx(after):
                        fringe_preserved = false
                elif after.a != 0.0:
                    isolated = false
        expect(fringe_preserved, kind + " keeps antialiased fringe outside legacy crop")
        expect(isolated, kind + " cannot contain neighboring dinosaur pixels")
        for elite in [false, true]:
            var view = Dino.new()
            var size: float = {"hunter": 62.0, "charger": 78.0, "spitter": 68.0, "tank": 91.0, "boss": 158.0}[kind] * (1.1 if elite else 1.0)
            view.setup(library, kind, size, elite)
            var scale_before: Vector2 = view.base_scale
            expect(is_equal_approx(view.base_scale.x * maxf(original.size.x, original.size.y), size), kind + " retains original body display scale (elite=" + str(elite) + ")")
            var width: float = view.sprite.material.get_shader_parameter("outline_width")
            expect(min_margin > ceili(width) + 1, kind + " outline fits inside transparent quad (elite=" + str(elite) + ")")
            expect(view.sprite.material.get_shader_parameter("region_bounds") == Vector4(0, 0, 1, 1), kind + " shader uses isolated UV bounds")
            view.elite = not elite
            expect((view.sprite.material.get_shader_parameter("team_color") == Color("#e31b28")) == not elite, kind + " late elite change updates red silhouette")
            expect(view.base_scale == scale_before, kind + " late elite update keeps body scale")
            view.set_shell("egg")
            expect(not view.sprite.visible, kind + " egg silhouette hides textured body")
            view.free()
        print("EDGE METRIC: %s original=%s output=%s alpha_bounds=%s transparent_margin=%d" % [kind, original.size, image.get_size(), bounds, min_margin])
    var actor = load("res://src/actor_view.gd").new()
    actor.setup(library)
    expect(is_equal_approx(actor.parts.body.texture.get_image().get_used_rect().size.y * actor.body_scale.y, 66.0), "configured hero visible height and separated limb anchors remain compatible")
    expect(not actor.parts["left_hand"].texture is AtlasTexture and actor.parts["left_hand"].texture.get_image().get_used_rect().position.x >= 24, "hero limbs isolate the original atlas art with transparent outline margins")
    actor.free()
    expect(library.texture("weapons", "club") is AtlasTexture, "weapon atlas contract remains compatible")
    expect(FileAccess.get_sha256("res://assets/dinosaurs.png") == "83df73a22baf06aacb9fe94c0198cf963c0a28b80cfc165d8bc791e548834213", "original dinosaur art is unchanged")
    print("SPRITE EDGES RESULT: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)
