extends RefCounted

static var cache: Dictionary = {}
static func material_svg(content: String) -> String:
    var materials: Dictionary={
        "bone":["#fff0cc","#c4ad84"],"wood":["#c68f5d","#966342"],
        "stone":["#d6ccb4","#958e7c"],"teal":["#a6d9d0","#5a9c9b"],
        "amethyst":["#d9c5ed","#9886bd"],"gold":["#eed59b","#ba914f"],
        "copper":["#ebc582","#b17b46"],"amber":["#f3b46a","#c47c3e"]
    }
    var colors: Dictionary={
        "#f0dfb3":"bone","#e7d6a8":"bone","#ead9ae":"bone","#e9cb8d":"bone",
        "#a36f46":"wood","#9b6848":"wood","#a97550":"wood","#a2734e":"wood","#a76c45":"wood",
        "#ada38d":"stone","#79bfc1":"teal","#c2afe5":"amethyst","#b29bdf":"amethyst",
        "#c89850":"copper","#ebd59a":"gold","#ee9d48":"amber"
    }
    var definitions: String="<defs>"
    for id in materials:
        definitions+='<linearGradient id="'+id+'" x1="0" y1="0" x2="0.35" y2="1"><stop offset="0" stop-color="'+materials[id][0]+'"/><stop offset="1" stop-color="'+materials[id][1]+'"/></linearGradient>'
    definitions+="</defs>"
    for color in colors:
        content=content.replace('fill="'+color+'"','fill="url(#'+colors[color]+')"')
    return definitions+content
const SHAPES = {
    "spear": '<path d="M60 43 L70 43 L68 119 L59 119Z" fill="#a36f46"/><path d="M64 5 L81 37 L66 54 L48 38Z" fill="#f0dfb3"/><path d="M64 12 L66 45 M54 61 L73 65 M54 69 L72 73" fill="none" stroke="#b18c59" stroke-width="4"/>',
    "hammer": '<path d="M58 44 L74 44 L68 119 L56 116Z" fill="#9b6848"/><path d="M25 18 Q63 7 103 20 L105 55 Q65 67 23 54Z" fill="#ada38d"/><path d="M38 22 L42 54 M86 21 L82 57" fill="none" stroke="#ddd0ad" stroke-width="7"/><path d="M54 73 L72 77 M54 83 L71 87" fill="none" stroke="#e5c88e" stroke-width="4"/>',
    "boomerang": '<path d="M9 91 Q29 41 63 8 Q90 46 119 88 L100 100 Q76 77 63 52 Q43 77 27 106Z" fill="#e7d6a8"/><path d="M42 50 L60 63 M50 40 L68 53 M63 36 L80 51" fill="none" stroke="#a7744d" stroke-width="6"/>',
    "totem": '<path d="M47 36 L79 36 L84 113 Q62 124 42 112Z" fill="#a97550"/><path d="M35 43 L64 14 L94 43 L80 73 L48 73Z" fill="#79bfc1"/><path d="M70 24 L53 48 L66 48 L57 65 L78 41 L65 41Z" fill="#f6e8ac" stroke-width="2"/><path d="M44 88 L82 88 M44 99 L81 99" fill="none" stroke="#dfc58d" stroke-width="5"/>',
    "bonebow": '<path d="M57 48 L72 48 L76 114 L56 119 L59 89 L50 84 L56 72Z" fill="#a2734e"/><path d="M9 48 Q32 20 62 35 Q88 22 117 49 L109 63 Q84 44 64 51 Q37 45 19 65Z" fill="#ead9ae"/><path d="M15 59 L64 87 L113 58" fill="none" stroke="#775c3c" stroke-width="3"/><path d="M64 15 L64 78" fill="none" stroke="#f5e6c3" stroke-width="6"/><path d="M64 5 L73 20 L55 20Z" fill="#e4dbc2"/><path d="M55 97 L74 101 M55 105 L74 109" fill="none" stroke="#d9ba7b" stroke-width="4"/><path d="M29 42 L25 54 M96 41 L100 54" fill="none" stroke="#bda477" stroke-width="4"/>',
    "firepot": '<path d="M37 52 Q18 62 25 91 Q31 116 65 119 Q103 115 107 87 Q111 65 90 53 L89 40 L39 40Z" fill="#bd7047"/><path d="M37 38 Q62 30 91 38 L89 54 Q64 62 38 53Z" fill="#e0ae6b"/><path d="M96 60 Q121 47 120 73 Q119 93 104 90" fill="none" stroke="#bd8952" stroke-width="9"/><path d="M33 78 Q65 67 100 79 M36 95 Q64 104 96 94" fill="none" stroke="#edc07c" stroke-width="6"/><path d="M61 39 Q52 20 65 19" fill="none" stroke="#5f4733" stroke-width="5"/><path d="M64 28 Q49 17 62 4 Q76 13 73 23 L79 17 Q87 34 72 38Z" fill="#f2a747"/><path d="M68 31 Q60 24 68 17 Q76 27 68 31Z" fill="#ffde7b" stroke-width="2"/>',
    "wardrum": '<path d="M22 49 L107 49 L101 105 Q66 123 27 104Z" fill="#a76c45"/><ellipse cx="64" cy="47" rx="44" ry="20" fill="#e9cb8d"/><path d="M23 58 L103 58 M27 102 Q65 115 101 103" fill="none" stroke="#dec58c" stroke-width="7"/><path d="M29 65 L43 103 L57 65 L72 106 L87 64 L99 100" fill="none" stroke="#e2b674" stroke-width="4"/><path d="M49 43 L84 9 M69 45 L37 12" fill="none" stroke="#976440" stroke-width="8"/><ellipse cx="86" cy="9" rx="8" ry="5" transform="rotate(-42 86 9)" fill="#dfd3ac"/><ellipse cx="35" cy="10" rx="8" ry="5" transform="rotate(42 35 10)" fill="#dfd3ac"/><path d="M51 44 Q64 35 78 45" fill="none" stroke="#b39059" stroke-width="3"/>',
    "crystal": '<path d="M19 97 L34 85 L92 86 L110 101 L92 119 L35 117Z" fill="#8b795e"/><path d="M31 99 L20 56 L35 32 L57 81 L52 106Z" fill="#9e91bd"/><path d="M53 104 L43 41 L65 5 L84 37 L77 105Z" fill="#c2afe5"/><path d="M76 105 L82 61 L104 38 L111 76 L92 108Z" fill="#8c86bb"/><path d="M65 13 L64 94 M26 57 L45 99 M103 47 L89 99" fill="none" stroke="#e2d8f3" stroke-width="4"/><path d="M45 44 L64 54 L81 39 M84 64 L97 74" fill="none" stroke="#70618f" stroke-width="3"/><path d="M39 111 L57 114 M79 114 L95 109" fill="none" stroke="#baa17a" stroke-width="3"/>'
}

static func texture(key: String) -> Texture2D:
    if cache.has(key):
        return cache[key]
    if not SHAPES.has(key):
        return null
    var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">'+material_svg('<g stroke="#4b382a" stroke-width="4.6" stroke-linejoin="round" stroke-linecap="round">'+SHAPES[key]+'</g>')+'</svg>'
    var image: Image = Image.new()
    if image.load_svg_from_string(svg) != OK:
        return null
    cache[key] = ImageTexture.create_from_image(image)
    return cache[key]

static func evolved_texture(base: Texture2D,key: String,stage: int) -> Texture2D:
    if stage<=0: return base
    var cache_key: String="evolved:"+key+":"+str(stage)
    if cache.has(cache_key): return cache[cache_key]
    var source: Image=base.get_image()
    var scale: float=128.0/maxf(source.get_width(),source.get_height())
    source.resize(maxi(1,roundi(source.get_width()*scale)),maxi(1,roundi(source.get_height()*scale)),Image.INTERPOLATE_LANCZOS)
    var image:=Image.create(160,160,false,Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    image.blit_rect(source,Rect2i(Vector2i.ZERO,source.get_size()),(Vector2i(160,160)-source.get_size())/2)
    var magic: bool=key in ["staff","totem","crystal"]
    var accent: String="#b29bdf" if magic else ("#ee9d48" if key in ["powder","firepot"] else "#ebd59a")
    var wraps: Dictionary={
        "club":'<g transform="rotate(40 63 107)"><path d="M53 103H73V111H53Z" fill="#c89850"/></g>',
        "axe":'<g transform="rotate(12 75 107)"><path d="M67 100H83V107H67Z M67 116H82V122H67Z" fill="#c89850"/></g>',
        "blade":'<g transform="rotate(43 61 110)"><path d="M52 105H70V113H52Z" fill="#c89850"/></g>',
        "sling":'<path d="M41 54L50 51L55 66L46 69Z M110 51L119 54L114 69L105 66Z" fill="#c89850"/>',
        "powder":'<path d="M62 58L71 56L76 98L67 100Z M93 56L102 55L108 96L99 98Z" fill="#c89850"/>',
        "staff":'<path d="M72 92L87 94L86 101L71 99Z M70 113L84 114L83 121L69 120Z" fill="#c89850"/>',
        "spear":'<path d="M70 87H89V94H70Z M70 112H87V119H70Z" fill="#c89850"/>',
        "hammer":'<path d="M72 93H89V101H72Z M71 118H88V125H71Z" fill="#c89850"/>',
        "boomerang":'<g transform="rotate(35 51 87)"><path d="M40 83H62V90H40Z" fill="#c89850"/></g><g transform="rotate(-35 109 87)"><path d="M98 83H120V90H98Z" fill="#c89850"/></g>',
        "totem":'<path d="M61 105H98V112H61Z M60 123H99V130H60Z" fill="#c89850"/>',
        "bonebow":'<path d="M70 111H92V118H70Z M70 125H92V131H70Z" fill="#c89850"/>',
        "firepot":'<path d="M44 92Q80 83 116 92L115 99Q80 91 45 99Z" fill="#c89850"/>',
        "wardrum":'<path d="M42 91H119V99H43Z" fill="#c89850"/>',
        "crystal":'<path d="M44 126L78 132L119 125L113 135L79 142L48 135Z" fill="#c89850"/>'
    }
    var gems: Dictionary={"club":Vector2(93,59),"axe":Vector2(80,57),"blade":Vector2(90,69),"sling":Vector2(80,111),"powder":Vector2(83,79),"staff":Vector2(80,53),"spear":Vector2(80,56),"hammer":Vector2(80,51),"boomerang":Vector2(80,48),"totem":Vector2(80,68),"bonebow":Vector2(80,70),"firepot":Vector2(80,103),"wardrum":Vector2(80,104),"crystal":Vector2(80,86)}
    var center: Vector2=gems[key]
    var construction: Dictionary={
        "club":'<g transform="rotate(40 94 56)"><path d="M77 49H108V58H77Z" fill="#d4b77c"/><path d="M80 51L87 56L94 51L101 56L106 51" fill="none" stroke="#78533b" stroke-width="2"/></g><path d="M89 38L92 48L98 45L101 35" fill="#f0ddb2"/>',
        "axe":'<path d="M46 45L59 37L64 44L55 65L43 62Z M103 38L115 42L117 62L105 68L99 60Z" fill="#738982"/><path d="M47 47L53 45L49 58M108 43L112 47L111 59" fill="none" stroke="#e8d7aa" stroke-width="3"/>',
        "blade":'<path d="M81 81Q95 64 111 41L115 47Q104 70 89 86Z" fill="#867ca3"/><path d="M87 81L91 71L97 72L100 62L106 61" fill="none" stroke="#ebddbf" stroke-width="3"/><path d="M57 101L66 95L73 103L65 110Z" fill="#ceae71"/>',
        "sling":'<path d="M45 51L52 49L59 65L53 70Z M108 51L115 53L111 70L104 65Z" fill="#82968a"/><path d="M48 54L55 57M110 56L107 63" fill="none" stroke="#f2dfb6" stroke-width="3"/><path d="M66 103L93 103L91 111L68 111Z" fill="#c8ab72"/>',
        "powder":'<path d="M75 60L83 59L89 96L81 98Z M105 58L113 59L118 94L110 96Z" fill="#75887d"/><path d="M77 64L85 63M81 84L89 83M108 64L115 65M112 83L118 84" fill="none" stroke="#ead7a8" stroke-width="2.5"/><path d="M126 58L132 61L132 92L125 96Z" fill="#d1b079"/>',
        "staff":'<path d="M68 49L62 40L67 34L74 44L86 44L93 34L98 41L91 52L80 57Z" fill="#7d9588"/><path d="M74 30L80 23L87 30L85 41L77 43Z" fill="#c7b2df"/><path d="M78 29L81 36L85 30" fill="none" stroke="#f2e3bc" stroke-width="2"/>',
        "spear":'<path d="M68 45L75 52L73 62L64 57L60 43Z M88 51L95 43L98 56L88 63Z" fill="#77877d"/><path d="M73 36L80 28L86 39L80 46Z" fill="#d6be86"/><path d="M76 36L80 40L83 37" fill="none" stroke="#fff0c4" stroke-width="2"/>',
        "hammer":'<path d="M44 39L53 36L56 64L46 63Z M107 36L117 39L115 64L105 66Z" fill="#a88b5f"/><path d="M57 40H104V45H58Z" fill="#d1bc8c"/><path d="M49 41L51 57M111 41L110 58" fill="none" stroke="#f6e1b3" stroke-width="2.5"/>',
        "boomerang":'<path d="M39 77L47 65L65 52L71 56L55 69L46 83Z M89 54L97 51L117 75L112 83L102 69Z" fill="#bba06d"/><path d="M44 77L53 67L60 64M97 58L105 65L109 73" fill="none" stroke="#f7e6bd" stroke-width="3"/>',
        "totem":'<path d="M59 54L68 44L72 59L66 71Z M91 44L102 55L97 71L89 59Z" fill="#d8c18e"/><path d="M65 78L78 86L94 77L92 90L78 98L67 91Z" fill="#87978b"/><path d="M69 80L78 86L89 80" fill="none" stroke="#f1deb5" stroke-width="2.5"/>',
        "bonebow":'<path d="M35 60L45 55L60 59L57 67L43 65Z M101 58L117 55L127 61L120 66L105 66Z" fill="#829389"/><path d="M43 59L50 62L56 60M107 61L114 59L120 61" fill="none" stroke="#f7e4b9" stroke-width="2.5"/><path d="M74 84H86V99H74Z" fill="#cbb17d"/>',
        "firepot":'<path d="M51 85Q78 77 109 86L109 95Q79 87 51 95Z" fill="#b09664"/><path d="M56 89L65 85L74 90L83 85L93 91L103 87" fill="none" stroke="#edcf98" stroke-width="2.5"/><path d="M62 114L69 108L75 115L69 122Z M89 114L95 108L101 114L95 121Z" fill="#d8bd84"/>',
        "wardrum":'<path d="M45 75L51 77L57 112L50 110Z M107 76L113 75L108 111L101 113Z" fill="#d8be8a"/><path d="M58 85L65 91L71 84L78 91L85 84L92 91L99 84" fill="none" stroke="#f3deb0" stroke-width="3"/><path d="M48 72Q80 80 112 72" fill="none" stroke="#829185" stroke-width="4"/>',
        "crystal":'<path d="M69 49L80 31L84 57L77 80Z M93 76L104 63L100 91L91 106Z M49 77L56 70L67 96L62 104Z" fill="#e4d9ed" stroke="#8b78a4" stroke-width="1.5"/><path d="M74 50L78 72M98 77L95 95M54 80L60 96" fill="none" stroke="#fff0cf" stroke-width="2.5"/>'
    }
    var shape: String=wraps[key]+construction[key]
    if stage>=2:
        shape=shape.replace('#829389','#5d7d7d').replace('#82968a','#5d7d7d').replace('#cbb17d','#dec58d')
    shape+='<path d="M%d %dL%d %dL%d %dL%d %dZ" fill="%s"/>' % [center.x,center.y-9,center.x+8,center.y,center.x,center.y+9,center.x-8,center.y,accent]
    shape+='<path d="M%d %dL%d %dL%d %dZ" fill="#fff3d3" opacity="0.6" stroke="none"/>' % [center.x-5,center.y,center.x,center.y-6,center.x,center.y+4]
    if stage>=2:
        var tips: Dictionary={
            "club":'<path d="M84 40L88 23L97 35 M107 39L123 36L116 51 M109 67L122 75L104 79Z"/>',
            "axe":'<path d="M51 36L33 40L38 62L53 63 M107 34L125 38L123 61L107 62Z"/>',
            "blade":'<path d="M78 82L72 61L88 65 M98 53L99 34L110 39 M111 39L126 24L120 49Z"/>',
            "sling":'<path d="M43 44L36 27L51 36 M110 37L122 27L118 48Z"/>',
            "powder":'<path d="M125 57L143 50L137 69L145 81L127 83Z"/>',
            "staff":'<path d="M69 46L67 28L80 14L94 29L92 46L80 56Z"/>',
            "spear":'<path d="M67 58L54 35L72 44L80 24L89 44L106 34L93 58Z"/>',
            "hammer":'<path d="M43 34L29 30L31 69L43 71 M116 33L130 30L129 69L116 72Z"/>',
            "boomerang":'<path d="M36 86L15 89L24 111L42 119 M124 85L145 89L135 109L118 118Z"/>',
            "totem":'<path d="M53 53L44 31L64 42 M95 42L116 31L107 57Z"/>',
            "bonebow":'<path d="M32 61L19 43L45 50 M116 49L141 42L130 63Z"/>',
            "firepot":'<path d="M47 72L31 63L36 89L49 91 M113 72L129 63L123 89L111 91Z"/>',
            "wardrum":'<path d="M40 62L29 51L32 78L44 81 M118 62L132 51L128 79L117 81Z"/>',
            "crystal":'<path d="M51 119L37 91L43 66L63 111L66 126 M96 120L111 69L125 88L113 121L97 130Z"/>'
        }
        shape+='<g fill="'+accent+'">'+tips[key]+'</g>'
    var ornament:=Image.new()
    ornament.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="160" height="160">'+material_svg('<g stroke="#48372c" stroke-width="3.5" stroke-linejoin="round" stroke-linecap="round">'+shape+'</g>')+'</svg>')
    image.blend_rect(ornament,Rect2i(0,0,160,160),Vector2i.ZERO)
    image.fix_alpha_edges()
    var result:=ImageTexture.create_from_image(image)
    result.set_meta("display_extent",128.0)
    cache[cache_key]=result
    return result
