extends RefCounted
## Original flat-color, ink-outline SVG art; no atlas or image-generation input.
## body_size is the original body canvas. Padding enlarges only the draw quad.

const PADDING: int = 64
const BODY_SIZES = {"raptor": Vector2(288, 256), "thrower": Vector2(244, 270), "armored": Vector2(322, 236)}
static var cache: Dictionary = {}
static var surface_shader: Shader

const SURFACES={
    "hunter":'<path d="M35 55L42 58L39 68L34 63Z M46 52L52 56L48 65L44 61Z M55 50L61 52L59 59L54 57Z" fill="#5e7b66" opacity="0.7"/><path d="M67 19Q77 11 85 20M43 47Q51 43 58 43" fill="none" stroke="#ccd3a8" stroke-width="1.4"/><path d="M68 26L72 28L75 24M74 35L79 37" fill="none" stroke="#647857" stroke-width="1.1"/>',
    "charger":'<path d="M56 25L61 20L63 30L60 37Z M68 17L72 15L74 26L71 31Z M79 23L84 25L82 34L78 32Z" fill="#ad6d50" opacity="0.65"/><path d="M35 64L42 60L48 67L43 72Z M49 73L53 68L58 73L54 78Z" fill="#a96646" opacity="0.65"/><path d="M55 19L58 15M67 13L70 11M79 18L82 18M20 69L28 72M35 58L43 57" fill="none" stroke="#f3c28b" stroke-width="1.6"/>',
    "spitter":'<path d="M39 59L45 55L51 60L47 67L42 66Z M50 67L56 64L61 70L57 76Z" fill="#86915c"/><path d="M44 23Q52 17 64 22M48 29Q55 24 62 27M64 42L69 44L72 39" fill="none" stroke="#ecd79a" stroke-width="1.5"/><path d="M71 32L74 36L72 41M76 30L79 33L78 37" fill="none" stroke="#947d44" stroke-width="1.3"/>',
    "tank":'<path d="M40 49L47 45L53 50L50 58L43 59Z M55 60L61 56L67 62L63 69L57 68Z M72 48L78 45L83 51L78 57L73 55Z" fill="#816a70" opacity="0.6"/><path d="M38 21L42 13L45 27Z M57 17L62 10L65 25Z M76 24L80 19L84 33Z" fill="#e9d7b3" opacity="0.8"/><path d="M19 56L23 58M48 43L54 43M63 49L68 50M75 65L79 67" fill="none" stroke="#dfc3a3" stroke-width="1.5"/>',
    "boss":'<path d="M40 49L47 45L53 50L50 58L43 59Z M55 60L61 56L67 62L63 69L57 68Z M72 48L78 45L83 51L78 57L73 55Z" fill="#81606c" opacity="0.7"/><path d="M37 24L43 12L47 27M58 21L63 10L67 25M76 29L81 19L85 33" fill="#e5cb9d"/><path d="M27 46L31 55L27 62M32 44L36 54L33 62M41 68L46 72L52 68" fill="none" stroke="#a24e4d" stroke-width="2.1"/>',
    "raptor":'<path d="M48 49L51 52L48 59M52 45L55 49L53 55M64 30L68 29M73 34L77 36" fill="none" stroke="#f2c885" stroke-width="1.3"/><path d="M49 61L52 59L54 62L51 65Z M56 55L59 53L61 56L58 59Z" fill="#ad6845"/>',
    "thrower":'<path d="M40 58L46 55L50 61L45 66Z M57 48L60 44L64 48L61 52Z" fill="#7b8b64"/><path d="M39 28L45 25M47 30L52 28M65 36L68 39M76 52L81 55" fill="none" stroke="#e2d7aa" stroke-width="1.3"/>',
    "armored":'<path d="M31 49L34 45L38 49M47 43L51 39L55 43M66 44L69 41L72 45M39 67L42 69M62 68L66 70" fill="none" stroke="#d6c59c" stroke-width="1.3"/><path d="M34 58L38 56L40 60L36 63Z M59 56L63 54L66 58L62 62Z" fill="#4f6252" opacity="0.75"/>'
}

static func surface_texture(key: String,body: Vector2) -> Texture2D:
    var id: String="surface:"+key
    if cache.has(id): return cache[id]
    var width: int=int(body.x)+PADDING*2
    var height: int=int(body.y)+PADDING*2
    var svg: String='<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><g transform="translate(%d %d) scale(%.4f %.4f)" stroke-linejoin="round" stroke-linecap="round">%s</g></svg>' % [width,height,PADDING,PADDING,body.x/100.0,body.y/100.0,SURFACES.get(key,"")]
    var image:=Image.new()
    if image.load_svg_from_string(svg)!=OK: return null
    cache[id]=ImageTexture.create_from_image(image)
    return cache[id]

static func surface_material(mask: Texture2D) -> ShaderMaterial:
    if surface_shader==null:
        surface_shader=Shader.new()
        surface_shader.code='shader_type canvas_item; render_mode unshaded; uniform sampler2D body_mask; varying vec4 tint; void vertex(){tint=COLOR;} void fragment(){ vec4 paint=texture(TEXTURE,UV); paint.a*=texture(body_mask,UV).a; COLOR=paint*tint; }'
    var material:=ShaderMaterial.new()
    material.shader=surface_shader
    material.set_shader_parameter("body_mask",mask)
    return material

static func material_svg(content: String) -> String:
    var palettes: Dictionary={"#dc9559":["#e8ae73","#bc794c"],"#d88a50":["#e5a66b","#bc7547"],"#87917a":["#a6ad8d","#71806c"],"#b5a17a":["#d5bf8f","#9e8b69"],"#d2bd8b":["#ead5a5","#b49c70"],"#a5a66d":["#c3c18b","#858f5d"]}
    var defs: String="<defs>"
    var index:=0
    for color in palettes:
        var id: String="surface_material_"+str(index)
        defs+='<linearGradient id="'+id+'" x2="0.3" y2="1"><stop stop-color="'+palettes[color][0]+'"/><stop offset="1" stop-color="'+palettes[color][1]+'"/></linearGradient>'
        content=content.replace('fill="'+color+'"','fill="url(#'+id+')"')
        index+=1
    return defs+"</defs>"+content

const SHAPES = {
    "raptor": '''
<path d="M119 150 Q78 169 39 157 L10 144 Q22 174 57 187 Q88 197 123 178Z" fill="#b66c46"/>
<path d="M44 167 Q73 183 106 174" fill="none" stroke="#e5b47b" stroke-width="8"/>
<path d="M124 167 L110 207 L88 226 L91 237 L133 236 L141 225 L134 212 L157 178Z" fill="#a65e40"/>
<path d="M92 236 L88 243 L103 239 M116 236 L118 244 L129 237" fill="#eee4c4" stroke-width="5"/>
<path d="M121 174 Q101 141 121 110 Q133 87 165 95 L191 126 L173 176 Q149 191 121 174Z" fill="#dc9559"/>
<path d="M151 113 Q136 139 147 174 Q166 169 174 148 L177 125Z" fill="#f3d9a0" stroke-width="4"/>
<path d="M137 174 L159 198 L154 225 L144 235 Q154 242 176 237 L189 227 L175 218 L181 189 L167 167Z" fill="#d88b50"/>
<path d="M160 234 L155 245 L173 238 M176 231 L179 241 L190 229" fill="#f4e8c8" stroke-width="5"/>
<path d="M154 106 L161 73 L181 53 L205 51 L225 65 L229 94 L205 122 L182 135Z" fill="#d88a50"/>
<path d="M175 61 L165 31 L187 45 L194 19 L209 46 L224 29 L231 59" fill="#5a8277"/>
<path d="M195 60 Q220 50 241 69 L252 79 L276 84 L279 106 L262 122 L224 121 L201 102Z" fill="#e1a464"/>
<path d="M231 106 L271 104 L265 118 L235 119Z" fill="#f3dbab" stroke-width="4"/>
<path d="M247 110 L251 118 L256 108" fill="#fff4d3" stroke-width="3"/>
<path d="M218 76 L239 75" fill="none" stroke-width="6"/>
<path d="M223 81 Q230 78 234 85 L228 92 L221 88Z" fill="#f1cf68" stroke-width="4"/>
<path d="M228 82 L228 89" fill="none" stroke-width="4"/>
<circle cx="267" cy="94" r="3" fill="#382b26" stroke="none"/>
<path d="M175 124 Q192 121 202 142 L220 153 L232 146 L233 157 L219 173 L196 165 L181 148" fill="#dd9658"/>
<path d="M221 167 Q244 171 256 153 Q259 174 244 185 Q229 190 216 179Z" fill="#f0e4bf" stroke-width="5"/>
<path d="M154 122 Q164 116 174 131 L180 153 L194 163 L190 174 L170 163 L160 143" fill="#e7aa6a"/>
<path d="M185 168 Q208 175 215 159 Q217 179 203 188 Q188 188 180 178Z" fill="#fff0c7" stroke-width="5"/>
<path d="M121 121 L135 129 M116 135 L129 143 M110 155 L123 161 M171 77 L181 83" fill="none" stroke="#a15d3e" stroke-width="6"/>
''',
    "thrower": '''
<path d="M169 194 Q199 186 219 202 L236 224 Q213 222 191 216 L166 211Z" fill="#9e6350"/>
<path d="M82 200 L77 236 L60 247 L62 259 L105 259 L118 245 L113 204Z" fill="#875744"/>
<path d="M133 203 L143 236 L136 249 L141 260 L184 259 L190 248 L168 234 L165 198Z" fill="#a36a51"/>
<path d="M69 252 L69 259 M82 251 L83 260 M150 251 L150 260 M164 251 L165 260" fill="none" stroke="#e5c49a" stroke-width="5"/>
<path d="M58 130 Q67 97 106 94 L153 107 Q182 121 182 168 L171 219 Q119 238 72 214Z" fill="#b97d5c"/>
<path d="M92 135 Q112 122 143 136 L150 208 Q119 223 91 203Z" fill="#e4bf8b" stroke-width="5"/>
<path d="M88 142 Q65 148 52 129 L38 99 L25 92 L17 78 L22 57 L42 50 L61 62 L62 80 L75 106 L96 111Z" fill="#b67b5c"/>
<path d="M24 72 L42 63 L55 70 M23 84 L43 79 L58 84" fill="none" stroke="#e2b486" stroke-width="5"/>
<path d="M26 49 L21 29 L35 9 L59 12 L72 29 L64 51 L44 58Z" fill="#afa68a"/>
<path d="M35 13 L40 31 L24 33 M42 32 L63 44 M41 32 L65 22" fill="none" stroke="#d9d0ad" stroke-width="4"/>
<path d="M154 129 Q176 105 192 124 L208 163 L230 174 L232 196 L217 209 L194 204 L177 181 L154 164Z" fill="#aa6c50"/>
<path d="M197 174 L213 174 L227 181 M199 186 L216 186 L229 191" fill="none" stroke="#dcb085" stroke-width="5"/>
<path d="M193 166 L185 144 L199 125 L222 129 L235 147 L230 168 L210 178Z" fill="#b5a98b"/>
<path d="M200 129 L204 146 L188 148 M204 146 L228 158 M205 147 L226 134" fill="none" stroke="#ddd1a9" stroke-width="4"/>
<path d="M87 110 L88 71 L102 45 L134 32 L160 44 L172 73 L160 115 L135 131 L107 126Z" fill="#bd8260"/>
<path d="M98 57 L99 33 L113 40 L122 21 L138 39 L156 31 L159 52" fill="#6c7861"/>
<path d="M117 73 Q141 59 164 70 L181 80 L180 103 L163 119 L132 117 L114 102Z" fill="#ca956d"/>
<path d="M128 102 L173 99 L163 116 L138 116Z" fill="#e6c591" stroke-width="4"/>
<path d="M130 103 L132 121 L141 108 M159 108 L165 122 L170 103" fill="#f8e8bb" stroke-width="4"/>
<path d="M112 72 L128 69 M140 67 L155 71" fill="none" stroke-width="6"/>
<path d="M119 77 L124 78 M145 77 L150 78" fill="none" stroke="#f5d075" stroke-width="7"/>
<path d="M122 76 L122 81 M147 76 L147 81" fill="none" stroke-width="3"/>
<circle cx="169" cy="86" r="3" fill="#382b26" stroke="none"/>
<path d="M84 170 L96 176 L88 189 M150 171 L161 181 L153 194" fill="none" stroke="#8d5a45" stroke-width="5"/>
<path d="M76 214 L105 219 L128 225 L152 220 L172 212" fill="none" stroke="#6c7861" stroke-width="10"/>
<path d="M116 211 L129 217 L122 231 L110 222Z" fill="#d5c296" stroke-width="4"/>
''',
    "armored": '''
<path d="M100 152 L59 159 L35 143 L24 149 L11 137 L15 116 L36 105 L55 119 L59 136 L100 128Z" fill="#887450"/>
<path d="M19 117 L34 125 L48 116 M34 125 L29 144 M34 125 L53 137" fill="none" stroke="#c0b08a" stroke-width="5"/>
<path d="M116 153 L108 195 L95 205 L99 221 L140 221 L153 207 L153 164Z" fill="#8e7655"/>
<path d="M209 152 L216 196 L204 209 L209 222 L253 222 L262 207 L241 193 L246 159Z" fill="#8e7655"/>
<path d="M105 212 L106 220 M120 211 L121 220 M216 212 L218 221 M234 212 L236 221" fill="none" stroke="#dfd1ab" stroke-width="5"/>
<path d="M74 143 Q72 88 128 63 Q187 35 240 72 Q263 87 270 136 L258 180 Q202 205 131 192 Q97 185 74 166Z" fill="#87917a"/>
<path d="M93 150 Q159 172 255 145 L248 175 Q174 200 112 178Z" fill="#c2aa78" stroke-width="5"/>
<path d="M103 116 L83 84 L114 91 L118 54 L141 73 L160 35 L180 65 L207 37 L219 75 L250 60 L251 99 L278 97 L264 126Z" fill="#d2bd8b"/>
<path d="M91 121 L102 90 L130 75 L148 99 L143 134 L113 150 L87 139Z" fill="#667560"/>
<path d="M136 91 L159 64 L190 65 L206 95 L187 130 L151 135Z" fill="#727e68"/>
<path d="M199 95 L218 77 L246 92 L257 123 L235 145 L202 131Z" fill="#62715f"/>
<path d="M108 97 L110 127 L131 135 M159 80 L160 110 L181 118 M220 91 L222 122 L241 128" fill="none" stroke="#94a087" stroke-width="5"/>
<path d="M122 174 L123 201 L115 213 L121 225 L162 225 L173 212 L153 197 L159 181Z" fill="#ab8f61"/>
<path d="M218 174 L225 200 L217 214 L223 225 L268 225 L276 212 L254 196 L249 174Z" fill="#b79c69"/>
<path d="M127 216 L127 225 M142 216 L144 225 M231 216 L232 225 M249 215 L250 225" fill="none" stroke="#eee0b9" stroke-width="5"/>
<path d="M248 124 Q268 101 287 117 L298 131 L313 135 L313 161 L298 177 L268 178 L248 163Z" fill="#b5a17a"/>
<path d="M267 121 L260 105 L280 112 L285 99 L295 123" fill="#d9c89d"/>
<path d="M280 156 L308 153 L300 172 L276 173Z" fill="#dfcc9f" stroke-width="4"/>
<path d="M266 135 L283 132" fill="none" stroke-width="7"/>
<path d="M273 140 L279 140" fill="none" stroke="#f1cf6d" stroke-width="7"/>
<path d="M277 137 L277 143" fill="none" stroke-width="3"/>
<circle cx="305" cy="145" r="3" fill="#382b26" stroke="none"/>
<path d="M90 154 L103 160 M180 153 L193 157 M270 164 L281 166" fill="none" stroke="#75694e" stroke-width="5"/>
'''
}

static func body_size(key: String) -> Vector2:
    return BODY_SIZES.get(key, Vector2.ZERO)

static func texture(key: String) -> Texture2D:
    if cache.has(key):
        return cache[key]
    if not SHAPES.has(key):
        return null
    var body: Vector2 = body_size(key)
    var width: int = int(body.x) + PADDING * 2
    var height: int = int(body.y) + PADDING * 2
    var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' % [width,height,width,height,material_svg('<g transform="translate(%d %d)" stroke="#382b26" stroke-width="7" stroke-linejoin="round" stroke-linecap="round">%s</g>' % [PADDING,PADDING,SHAPES[key]])]
    var image: Image = Image.new()
    if image.load_svg_from_string(svg) != OK:
        return null
    image.fix_alpha_edges()
    cache[key] = ImageTexture.create_from_image(image)
    return cache[key]
