extends RefCounted
## Small, bounded ink flipbooks. Each visible impact becomes one GPU quad.
const FRAMES:=6
const FAMILIES=["wood","axe","blade","stone","powder","rune","spear","hammer","bonebow","fire","drum","crystal","lightning","pet","smoke"]
static var cache: Dictionary={}
const DEFS='<defs><linearGradient id="bone" x2="0.3" y2="1"><stop stop-color="#fff4d9"/><stop offset="1" stop-color="#bba078"/></linearGradient><linearGradient id="wood" x2="0.4" y2="1"><stop stop-color="#e2bc78"/><stop offset="1" stop-color="#9e683f"/></linearGradient><linearGradient id="fire" x2="0.2" y2="1"><stop stop-color="#ffdf89"/><stop offset="0.45" stop-color="#eea651"/><stop offset="1" stop-color="#b05c35"/></linearGradient><linearGradient id="rune" x2="0.4" y2="1"><stop stop-color="#e9ffe3"/><stop offset="1" stop-color="#68b9ba"/></linearGradient><linearGradient id="crystal" x2="0.4" y2="1"><stop stop-color="#e6d8f6"/><stop offset="1" stop-color="#8879b1"/></linearGradient><linearGradient id="dust" x2="0.2" y2="1"><stop stop-color="#e4cfac"/><stop offset="1" stop-color="#aa8e69"/></linearGradient></defs>'

static func shard(at: Vector2,angle: float,length: float,width: float,material: String) -> String:
    return '<g transform="translate(%.2f %.2f) rotate(%.2f)"><path d="M%.2f 0L0 %.2fL%.2f 0L0 %.2fZ" fill="url(#%s)"/><path d="M%.2f 0L0 %.2fL0 0Z" fill="#fff1cd" opacity="0.7" stroke="none"/></g>' % [at.x,at.y,rad_to_deg(angle),length,width,-length*0.45,-width,material,length,-width]

static func source(family: String,frame: int) -> String:
    var t: float=float(frame)/5.0
    var content: String=""
    match family:
        "wood":
            content='<path d="M-21 9L-13 -5L-8 6L1 -13L8 -2L23 -10L14 10L27 17L8 19L-2 30L-9 18L-27 22Z" fill="url(#dust)" opacity="0.6" stroke-width="1.2"/>'
            for i in range(7):
                var a: float=i*2.399+0.3
                content+=shard(Vector2.from_angle(a)*(14+t*27),a,9-t*3,2.8,"wood")
        "axe":
            content='<path d="M-47 27Q-8 -44 47 -29Q8 -22 -29 31L-37 16Z" fill="url(#bone)"/><path d="M-44 27Q-1 -35 42 -29Q-1 -11 -29 31Z" fill="#e6a36b" stroke="none" opacity="0.75"/><path d="M-35 19Q0 -21 32 -25" fill="none" stroke="#fff2cc" stroke-width="2.3"/>'
            for i in range(3): content+=shard(Vector2(18+i*9+t*4,7-i*9),-0.8,8,3,"bone")
        "blade":
            content='<path d="M-54 25Q-4 -28 53 -24Q2 -13 -39 25L-28 6Z" fill="url(#crystal)" stroke-width="1.5"/><path d="M-48 22Q-2 -22 48 -24Q2 -15 -39 24Z" fill="#f8efd8" stroke="none"/><path d="M-32 31Q4 -5 38 -8L8 8Z" fill="#bdabd8" opacity="0.65" stroke="none"/>'
            content+=shard(Vector2(43,-10-t*12),-0.8,7,2.2,"crystal")
        "stone":
            for i in range(8):
                var a: float=i*TAU/8.0+0.4
                content+=shard(Vector2.from_angle(a)*(9+t*34),a,6+(i%3),3.5,"bone")
            content+='<path d="M-9 2L-4 -8L6 -6L10 3L0 9Z" fill="#b7ab8f"/>'
        "powder":
            content='<path d="M-45 9Q-58 -10 -37 -17Q-39 -35 -17 -30Q-13 -49 5 -32Q23 -48 29 -25Q50 -32 46 -11Q59 0 43 15Q45 34 24 30Q13 47 -1 32Q-20 44 -25 27Q-48 32 -45 9Z" fill="url(#fire)" stroke-width="2.2"/><path d="M-29 7L-23 -11L-12 -6L-7 -26L4 -11L22 -24L22 -5L38 3L20 9L18 26L3 15L-10 29L-11 11Z" fill="#ffdf91" stroke="none"/><path d="M-15 2Q-3 -10 14 -2L5 13L-7 10Z" fill="#fff1c3" stroke="none"/>'
            for i in range(4): content+=shard(Vector2.from_angle(i*1.7)*(40+t*10),i*1.7,5,2,"wood")
        "rune":
            content='<path d="M-34 -10L-34 -24L-18 -28M14 -32L29 -28L34 -13M35 10L30 27L12 31M-15 33L-32 25L-35 11" fill="none" stroke="#5b9b9a" stroke-width="4"/><path d="M-31 -10L-31 -22L-18 -25M14 -29L27 -25L31 -13M32 10L27 24L12 28M-15 30L-29 23L-32 11" fill="none" stroke="#d6f3d0" stroke-width="1.5"/>'
            for i in range(4): content+=shard(Vector2.from_angle(i*PI/2+0.3)*(15+t*22),i*PI/2+0.3,9,5,"rune")
            content+=shard(Vector2.ZERO,0,13*(1-t*0.45),8,"rune")
        "spear":
            content='<path d="M-56 2L-21 -4L-13 -12L51 0L-12 12L-19 5Z" fill="url(#bone)" stroke-width="1.5"/><path d="M-42 1L-11 -2L38 0L-12 4Z" fill="#fff2c9" stroke="none"/><path d="M-25 -12L-8 -15L-16 -9M-26 14L-9 17L-18 9" fill="none" stroke="#a68e65" stroke-width="2"/>'
            content+=shard(Vector2(30+t*15,-12),-0.15,8,2.5,"bone")
        "hammer":
            content='<path d="M-52 16L-33 7L-24 10L-10 2L-24 -4L-42 -3L-31 -12L-12 -7L-3 -19L9 -12L20 -18L24 -7L47 -7L35 4L49 14L28 11L16 25L8 15L-5 28L-13 15L-31 24L-31 16Z" fill="url(#dust)" opacity="0.8"/><path d="M-37 11L-12 4L-2 7L10 1L29 8M-2 7L-6 21M10 1L19 -9" fill="none" stroke="#70543b" stroke-width="2.8"/>'
            for i in range(5): content+=shard(Vector2(-37+i*18,-6-absf(sin(i*2.3+t))*19),i*1.7,6,4,"bone")
        "bonebow":
            content='<path d="M-45 -2L-15 -4L-6 -10L13 0L-6 10L-15 4L-45 2Z" fill="url(#bone)"/><path d="M-35 -7L-24 -13L-18 -7M-35 8L-24 14L-18 8" fill="none" stroke="#c1a278" stroke-width="2.5"/>'
            for i in range(5):
                var a: float=-0.8+i*0.4
                content+=shard(Vector2(8,0)+Vector2.from_angle(a)*(16+t*27),a,7,2.7,"bone")
        "fire":
            content='<path d="M-49 16Q-39 3 -24 8Q-1 -2 17 7Q39 5 49 18Q22 33 -7 28Q-34 32 -49 16Z" fill="#79573b" opacity="0.28" stroke="none"/>'
            for i in range(5):
                var x: float=-34+i*17
                var h: float=22+sin(i*2.7+t*TAU)*8
                content+='<path d="M%.1f 18Q%.1f 0 %.1f %.1fQ%.1f -4 %.1f -10Q%.1f 10 %.1f 18Z" fill="url(#fire)" stroke-width="1.6"/>' % [x-7,x-13,x,-h,x+3,x+8,x+13,x+5]
                content+='<path d="M%.1f 16Q%.1f 7 %.1f -2Q%.1f 10 %.1f 17Z" fill="#ffe6a4" stroke="none"/>' % [x-3,x-4,x+1,x+7,x+3]
        "drum":
            for i in range(8):
                content+='<g transform="rotate(%.1f)"><path d="M35 -13Q48 -7 49 7L43 13L40 4L33 1L38 -3L31 -11Z" fill="url(#wood)" stroke-width="1.5"/><path d="M39 -9Q47 0 44 7" fill="none" stroke="#f7dfab" stroke-width="2"/><path d="M29 -7L32 -3L28 0" fill="none" stroke="#c3a16c" stroke-width="1.5"/></g>' % [i*45+t*6]
        "crystal":
            for i in range(7):
                var a: float=i*TAU/7+0.1
                content+=shard(Vector2.from_angle(a)*(9+t*29),a,12-(i%3)*2,5-(i%2),"crystal")
            content+=shard(Vector2.ZERO,-0.5,13*(1-t*0.6),8,"crystal")
        "lightning":
            var flicker: float=t*5.0
            content='<path d="M-46 -10L-8 -20L22 -4L50 2L18 14L-10 6L-42 8Z" fill="#8fe3e4" opacity="0.32" stroke="none"/>'
            content+='<path d="M-58 4L-36 -18L-22 -4L-8 -32L6 -10L18 -26L26 -2L42 -18L58 2L34 12L26 2L10 24L4 6L-10 20L-16 4L-30 12L-44 2Z" fill="#2f5c60"/>'
            content+='<path d="M-52 3L-34 -12L-20 -1L-6 -22L4 -6L18 -16L24 0L40 -10L52 1L34 7L24 0L10 14L6 1L-8 12L-12 1L-28 6Z" fill="#6ec8cc" stroke="none"/>'
            content+='<path d="M-44 2L-30 -6L-18 0L-4 -12L4 -2L16 -8L22 1L36 -5L46 1L32 4L18 0L8 7L2 0L-10 7L-18 0Z" fill="#f4ffe6" stroke="none"/>'
            content+='<path d="M-8 -8L-22 %.1fL-6 %.1fL-2 -16Z" fill="#4f8f93"/><path d="M-8 -8L-18 %.1fL-4 %.1f" fill="none" stroke="#f4ffe6" stroke-width="1.5"/>' % [-30-flicker,-42-flicker*0.4,-28-flicker,-38-flicker*0.3]
            content+='<path d="M20 1L32 %.1fL48 %.1fL28 14Z" fill="#7cced1"/><path d="M20 1L30 %.1fL44 %.1f" fill="none" stroke="#f4ffe6" stroke-width="1.4"/>' % [20+flicker*0.4,28+flicker*0.5,18+flicker*0.3,26+flicker*0.4]
            content+='<path d="M8 8L2 28L14 22Z" fill="#88c3c5" opacity="0.9"/>'
            for i in range(6):
                var a: float=-0.9+i*0.38
                content+=shard(Vector2(-28+i*12,-2+(i%2)*6),a,4.5,1.4,"rune")
        "pet":
            for i in range(3): content+='<path d="M%d -31Q%d -6 %d 23L%d 30Q%d 1 %d -31Z" fill="url(#bone)" stroke-width="1.1"/>' % [-20+i*15,-28+i*15,-17+i*15,-13+i*15,-20+i*15,-20+i*15]
        "smoke":
            # Large 厚涂 color chunks, not a single soft puff. They lift slightly over the flipbook.
            var lift: float=-t*7.0
            content='<g transform="translate(0 %.1f)">' % lift
            content+='<path d="M-52 30L-60 14L-48 -2L-28 6L-18 22L-30 36L-50 38Z" fill="#5a4434" opacity="0.86"/>'
            content+='<path d="M-30 24L-40 4L-22 -16L4 -8L20 10L8 30L-16 34Z" fill="url(#dust)" opacity="0.95"/>'
            content+='<path d="M-20 2L-28 -18L-10 -34L14 -22L18 -4L2 10Z" fill="#e6d3ae" opacity="0.88"/>'
            content+='<path d="M10 20L22 -2L44 -10L56 8L46 26L22 32Z" fill="#b38a5e" opacity="0.9"/>'
            content+='<path d="M-8 16L2 2L22 8L16 24L0 26Z" fill="#8a6a48" opacity="0.8"/>'
            content+='<path d="M-16 -4L-10 -20L8 -16L6 0L-6 6Z" fill="#fff4d9" opacity="0.72" stroke="none"/>'
            content+='<path d="M-34 12L-20 6M-6 18L10 10M16 2L30 -6M-18 -10L-6 -18M24 16L36 10" fill="none" stroke="#4a3728" stroke-width="1.7" opacity="0.4"/>'
            content+='</g>'
    return '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="-64 -64 128 128">'+DEFS+'<g stroke="#594330" stroke-width="2" stroke-linejoin="round" stroke-linecap="round">'+content+'</g></svg>'

static func texture(family: String,progress: float=0.0) -> Texture2D:
    if family not in FAMILIES: return null
    var frame: int=clampi(floori(progress*FRAMES),0,FRAMES-1)
    var id: String=family+":"+str(frame)
    if cache.has(id): return cache[id]
    var image:=Image.new()
    if image.load_svg_from_string(source(family,frame))!=OK: return null
    cache[id]=ImageTexture.create_from_image(image)
    return cache[id]

static func warm() -> void:
    for family in FAMILIES:
        for frame in range(FRAMES): texture(family,float(frame)/FRAMES)

static func draw(canvas,family: String,at: Vector2,size: float,progress: float,direction: Vector2=Vector2.RIGHT,alpha: float=1.0) -> void:
    var art: Texture2D=texture(family,progress)
    if art==null: return
    var angle: float=direction.angle() if family in ["axe","blade","spear","bonebow","lightning","pet"] else 0.0
    var extent: float=maxf(1,size)*(0.74+minf(progress,1.0)*0.28)
    canvas.draw_set_transform(at,angle)
    canvas.draw_texture_rect(art,Rect2(Vector2.ONE*-extent,Vector2.ONE*extent*2),false,Color(1,1,1,clampf(alpha,0,1)))
    canvas.draw_set_transform(Vector2.ZERO)

static func particle_family(particle: Dictionary) -> String:
    var kind: String=particle.get("kind","")
    if kind in ["number","word","flight","arc_lightning","swing_trail","defeat","dodge","rune_ignition","beam","sling_release","powder_muzzle","staff_muzzle"]: return ""
    if kind=="smoke": return "smoke"
    if kind=="quake": return "hammer"
    if kind in ["blast","cannon"]: return "powder"
    if kind=="rune_blast": return "rune"
    var key: String=particle.get("weapon_id","")
    var families: Dictionary={"club":"wood","axe":"axe","blade":"blade","sling":"stone","powder":"powder","staff":"rune","spear":"spear","hammer":"hammer","boomerang":"bonebow","totem":"lightning","bonebow":"bonebow","firepot":"fire","wardrum":"drum","crystal":"crystal","drone":"rune","pet":"pet"}
    if families.has(key): return families[key]
    return {"chop":"axe","slash":"blade","smash":"hammer","rune_hit":"rune","ring":"drum","thrust":"spear","lightning":"lightning","ribbon":"bonebow","fleck":"stone","aura":"rune","muzzle":"stone","impact":"wood","hit":"stone"}.get(kind,"")
