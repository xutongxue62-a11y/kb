extends RefCounted

var regions: Dictionary
var atlases: Dictionary = {}
var cache: Dictionary = {}
var weapon_material: ShaderMaterial

func _init() -> void:
    regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/regions.json"))
    for category in ["hero", "dinosaurs", "weapons"]:
        atlases[category] = load("res://assets/%s.png" % category)
    var shader: Shader = Shader.new()
    shader.code = """shader_type canvas_item;
render_mode unshaded;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
    vec4 sample_color = texture(TEXTURE, UV);
    float coverage = smoothstep(0.72, 0.97, sample_color.a);
    COLOR = vec4(sample_color.rgb, coverage) * tint;
}
"""
    weapon_material = ShaderMaterial.new()
    weapon_material.shader = shader

func region(category: String, key: String) -> Rect2:
    var r: Array = regions[category][key]
    return Rect2(r[0], r[1], r[2], r[3])

func texture(category: String, key: String) -> Texture2D:
    var cache_key: String = category + ":" + key
    if not cache.has(cache_key):
        var atlas: AtlasTexture = AtlasTexture.new()
        atlas.atlas = atlases[category]
        atlas.region = region(category, key)
        atlas.filter_clip = true
        cache[cache_key] = atlas
    return cache[cache_key]

func make_weapon(key: String, target_size: float) -> Sprite2D:
    var sprite: Sprite2D = Sprite2D.new()
    sprite.texture = texture("weapons", key)
    sprite.material = weapon_material
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    var dimensions: Vector2 = sprite.texture.get_size()
    sprite.scale = Vector2.ONE * target_size / maxf(dimensions.x, dimensions.y)
    return sprite
