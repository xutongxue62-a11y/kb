extends RefCounted
const WeaponArt = preload("res://src/weapon_art.gd")
const EnemyArt = preload("res://src/enemy_art.gd")
const Catalog = preload("res://src/catalog.gd")
const Evolution = preload("res://src/weapon_evolution.gd")
# Transparent geometry for the silhouette outline, independent of atlas neighbors.
const DINO_PADDING: int = 64
const DINO_FRINGE: int = 8
const DINO_ALPHA_NOISE: float = 8.0 / 255.0

var regions: Dictionary
var atlases: Dictionary = {}
var cache: Dictionary = {}
var weapon_material: ShaderMaterial
var team_shader: Shader
var team_materials: Dictionary = {}

func _init() -> void:
    regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/regions.json"))
    for category in ["hero", "dinosaurs", "weapons"]:
        atlases[category] = load("res://assets/%s.png" % category)
    var shader: Shader = Shader.new()
    shader.code = """shader_type canvas_item;
render_mode unshaded;
uniform float charge_progress = 0.0;
uniform vec4 charge_color : source_color = vec4(1.0, 0.72, 0.32, 1.0);
uniform float flow_horizontal = 0.0;
uniform int elem_style = 0; // 0=neutral, 1=rune, 2=fire, 3=thunder
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
    vec4 sample_color = texture(TEXTURE, UV);
    float coverage = smoothstep(0.72, 0.97, sample_color.a);
    vec3 rgb = sample_color.rgb;
    if (charge_progress > 0.01 && elem_style > 0 && coverage > 0.05) {
        vec2 px = TEXTURE_PIXEL_SIZE * 2.0;
        vec4 s_u = texture(TEXTURE, UV + vec2(0.0, -px.y));
        vec4 s_d = texture(TEXTURE, UV + vec2(0.0, px.y));
        vec4 s_l = texture(TEXTURE, UV + vec2(-px.x, 0.0));
        vec4 s_r = texture(TEXTURE, UV + vec2(px.x, 0.0));
        float interior = smoothstep(0.62, 0.95, min(min(s_u.a, s_d.a), min(s_l.a, s_r.a)));
        float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
        float avg_luma = dot((s_u.rgb + s_d.rgb + s_l.rgb + s_r.rgb) * 0.25, vec3(0.299, 0.587, 0.114));
        float seam = clamp((avg_luma - luma) * 5.8 + smoothstep(0.36, 0.14, luma) * 0.52, 0.0, 1.0) * interior;
        float axis_t = mix(1.0 - UV.y, UV.x, flow_horizontal);
        float ramp = smoothstep(0.02, 0.25, charge_progress);
        vec3 col = charge_color.rgb;
        if (elem_style == 1) {
            // 魔法本体：柔和奥术内光随聚焦渐亮
            float glow_m = clamp((seam * 0.65 + interior * 0.28) * charge_progress * ramp, 0.0, 1.0);
            rgb = mix(rgb, col, glow_m * 0.62);
            rgb += mix(col, vec3(1.0), 0.5) * (seam * charge_progress * ramp * 0.25);
        } else if (elem_style == 2) {
            // 火焰本体：熔炉鼓风式由内向外烧红至炽金白热
            float core_dist = length((UV - vec2(0.5, 0.5)) * vec2(1.4, 1.4));
            float forge = clamp((1.0 - smoothstep(0.05, 0.85, core_dist - charge_progress * 0.45)) * interior * charge_progress, 0.0, 1.0);
            float heat = clamp(forge * (0.72 + 0.28 * sin(TIME * 22.0)) + seam * charge_progress * 0.55, 0.0, 1.0);
            vec3 ember = mix(vec3(0.82, 0.16, 0.02), vec3(1.0, 0.68, 0.14), smoothstep(0.18, 0.82, heat));
            vec3 white_hot = vec3(1.0, 0.94, 0.56);
            rgb = mix(rgb, ember, heat * 0.82);
            rgb += white_hot * (smoothstep(0.62, 1.0, heat) * 0.45);
        } else if (elem_style == 3) {
            // 雷电本体：高压电纹沿缝隙随充能加快劈闪
            float t_step = floor(TIME * (14.0 + 16.0 * charge_progress));
            float h = fract(sin(dot(vec2(floor(axis_t * 14.0), t_step), vec2(12.9898, 78.233))) * 43758.5453);
            float bolt = clamp(seam * step(0.42 - 0.22 * charge_progress, h) * ramp * (0.65 + 0.55 * charge_progress), 0.0, 1.0);
            rgb = mix(rgb, col, bolt * 0.88);
            rgb += mix(col, vec3(1.0), 0.65) * (bolt * 0.48);
        }
    }
    COLOR = vec4(rgb, coverage) * tint;
}
"""
    weapon_material = ShaderMaterial.new()
    weapon_material.shader = shader
    team_shader = Shader.new()
    team_shader.code = """shader_type canvas_item;
render_mode unshaded;
uniform vec4 team_color : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform vec4 region_bounds = vec4(0.0, 0.0, 1.0, 1.0);
uniform float outline_width = 3.0;
varying vec4 item_tint;
void vertex() { item_tint = COLOR; }
void fragment() {
    vec4 base = texture(TEXTURE, UV);
    float edge = base.a;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 sample_uv = UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * outline_width;
            if (sample_uv.x >= region_bounds.x && sample_uv.y >= region_bounds.y && sample_uv.x <= region_bounds.z && sample_uv.y <= region_bounds.w) {
                edge = max(edge, texture(TEXTURE, sample_uv).a);
            }
        }
    }
    COLOR = vec4(mix(team_color.rgb, base.rgb, base.a), max(base.a, edge * team_color.a)) * item_tint;
}
"""

func region(category: String, key: String) -> Rect2:
    if category=="dinosaurs" and EnemyArt.BODY_SIZES.has(key): return Rect2(Vector2.ZERO,EnemyArt.body_size(key))
    var r: Array = regions[category]["tank" if category == "dinosaurs" and key == "boss" else key]
    return Rect2(r[0], r[1], r[2], r[3])

func texture(category: String, key: String) -> Texture2D:
    if category=="dinosaurs" and EnemyArt.BODY_SIZES.has(key): return EnemyArt.texture(key)
    if category == "weapons" and WeaponArt.SHAPES.has(key):
        return WeaponArt.texture(key)
    var cache_key: String = category + ":" + key
    if not cache.has(cache_key):
        if category == "dinosaurs":
            # Boss and tank deliberately share the same art and GPU resource.
            var canonical: String = "tank" if key == "boss" else key
            var isolated_key: String = category + ":" + canonical
            if not cache.has(isolated_key):
                cache[isolated_key] = _dinosaur_texture(canonical)
            cache[cache_key] = cache[isolated_key]
            return cache[cache_key]
        var atlas: AtlasTexture = AtlasTexture.new()
        atlas.atlas = atlases[category]
        atlas.region = region(category, key)
        atlas.filter_clip = true
        cache[cache_key] = atlas
    return cache[cache_key]

func _dinosaur_texture(key: String) -> ImageTexture:
    var bounds: Rect2i = Rect2i(region("dinosaurs", key))
    var source: Image = atlases["dinosaurs"].get_image()
    # The legacy bounds were computed at alpha >= 180, clipping the AA fringe.
    # A small guard restores that fringe; it is far from all sibling silhouettes.
    var extraction: Rect2i = bounds.grow(DINO_FRINGE)
    var image: Image = Image.create(bounds.size.x + DINO_PADDING * 2, bounds.size.y + DINO_PADDING * 2, false, Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    for y in range(extraction.size.y):
        for x in range(extraction.size.x):
            var pixel: Color = source.get_pixelv(extraction.position + Vector2i(x, y))
            # Compression/export haze is not body coverage. Retain all meaningful
            # RGBA and antialias pixels exactly; never change the source PNG.
            if pixel.a > DINO_ALPHA_NOISE:
                image.set_pixel(x + DINO_PADDING - DINO_FRINGE, y + DINO_PADDING - DINO_FRINGE, pixel)
    image.fix_alpha_edges()
    return ImageTexture.create_from_image(image)

func weapon_texture(key: String,level: int=1) -> Texture2D:
    return WeaponArt.evolved_texture(texture("weapons",key),key,Evolution.tier(level))

func make_weapon(key: String, target_size: float,level: int=1) -> Sprite2D:
    var sprite: Sprite2D = Sprite2D.new()
    sprite.texture = weapon_texture(key,level)
    var mat: ShaderMaterial = weapon_material.duplicate() as ShaderMaterial
    mat.set_shader_parameter("flow_horizontal", 1.0 if key == "powder" else 0.0)
    mat.set_shader_parameter("charge_progress", 0.0)
    sprite.material = mat
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    var dimensions: Vector2 = sprite.texture.get_size()
    sprite.scale = Vector2.ONE * target_size / float(sprite.texture.get_meta("display_extent",maxf(dimensions.x,dimensions.y)))
    return sprite

func team_material(category: String, key: String, team: String, source_width: float = 16.0) -> ShaderMaterial:
    var cache_key: String = category + ":" + key + ":" + team + ":" + str(source_width)
    if not team_materials.has(cache_key):
        var material: ShaderMaterial = ShaderMaterial.new()
        material.shader = team_shader
        var bounds: Rect2 = region(category, key)
        var dimensions: Vector2 = atlases[category].get_size()
        material.set_shader_parameter("region_bounds", Vector4(0.0, 0.0, 1.0, 1.0) if category == "dinosaurs" else Vector4(bounds.position.x / dimensions.x, bounds.position.y / dimensions.y, bounds.end.x / dimensions.x, bounds.end.y / dimensions.y))
        material.set_shader_parameter("team_color", Color("#a2d7d5") if team == "hero" else (Color("#e31b28") if team == "elite" else Color("#874052")))
        material.set_shader_parameter("outline_width", source_width)
        team_materials[cache_key] = material
    return team_materials[cache_key]

func hero_body_path(character_id: String) -> String:
    var profile: Dictionary = Catalog.character(character_id)
    return str(profile.get("body", ""))

func hero_body_texture(character_id: String) -> Texture2D:
    var path: String = hero_body_path(character_id)
    if path.is_empty():
        return texture("hero", "body")
    var cache_key: String = "hero_body:" + path
    if not cache.has(cache_key):
        if ResourceLoader.exists(path):
            var source: Texture2D = load(path)
            var image: Image = source.get_image()
            cache[cache_key] = _padded_hero_texture(image, image.get_used_rect(), 48, path)
        else:
            cache[cache_key] = texture("hero", "body")
    return cache[cache_key]

func _padded_hero_texture(source: Image, bounds: Rect2i, padding: int, path: String = "") -> ImageTexture:
    var image := Image.create(bounds.size.x + padding * 2, bounds.size.y + padding * 2, false, Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    image.blit_rect(source, bounds, Vector2i(padding,padding))
    image.fix_alpha_edges()
    var result := ImageTexture.create_from_image(image)
    result.set_meta("content_size", Vector2(bounds.size))
    result.set_meta("source_path", path)
    return result

func hero_limb_texture(key: String) -> Texture2D:
    var cache_key: String = "hero_limb:" + key
    if not cache.has(cache_key):
        # Isolate the AA fringe, then leave room for the existing team outline.
        # The source atlas and original centers/limb attachment positions stay intact.
        var bounds: Rect2i = Rect2i(region("hero",key)).grow(4)
        cache[cache_key] = _padded_hero_texture(atlases.hero.get_image(),bounds,32)
    return cache[cache_key]

func hero_limb_material(key: String, source_width: float) -> ShaderMaterial:
    return _isolated_hero_material("hero_limb_mat:" + key,source_width)

func hero_body_material(character_id: String, source_width: float = 16.0) -> ShaderMaterial:
    var path: String = hero_body_path(character_id)
    if path.is_empty():
        return team_material("hero", "body", "hero", source_width)
    return _isolated_hero_material("hero_body_mat:" + path,source_width)

func _isolated_hero_material(key: String, source_width: float) -> ShaderMaterial:
    var cache_key: String = key + ":" + str(source_width)
    if not team_materials.has(cache_key):
        var material: ShaderMaterial = ShaderMaterial.new()
        material.shader = team_shader
        material.set_shader_parameter("region_bounds", Vector4(0.0, 0.0, 1.0, 1.0))
        material.set_shader_parameter("team_color", Color("#a2d7d5"))
        material.set_shader_parameter("outline_width", source_width)
        team_materials[cache_key] = material
    return team_materials[cache_key]
