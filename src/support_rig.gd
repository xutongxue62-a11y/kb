extends RefCounted
## Original ink art in separable pieces. Simulation positions remain ground anchors.
static var cache: Dictionary={}
const DEFS='<defs><linearGradient id="skin" x2="0.2" y2="1"><stop stop-color="#a4bd9b"/><stop offset="1" stop-color="#668d83"/></linearGradient><linearGradient id="ivory" x2="0.4" y2="1"><stop stop-color="#fff0cc"/><stop offset="1" stop-color="#d9bd8d"/></linearGradient><linearGradient id="ochre" x2="0.2" y2="1"><stop stop-color="#e3aa65"/><stop offset="1" stop-color="#bc7e49"/></linearGradient><linearGradient id="wing" x2="0.5" y2="1"><stop stop-color="#b4c8ae"/><stop offset="1" stop-color="#6d9991"/></linearGradient></defs>'
const PARTS={
    "pet_tail":'<path d="M4 -9Q-14 -16 -35 -5L-41 0Q-21 -2 -5 14L7 10Z" fill="url(#skin)"/><path d="M-33 0Q-17 2 -4 12" fill="none" stroke="#e2d3a2" stroke-width="3"/><path d="M-18 -9L-14 -17L-7 -10" fill="url(#ivory)"/>',
    "pet_leg":'<path d="M-6 -3Q-14 5 -10 12L-13 20Q-5 24 8 21L9 17L0 13L5 3Z" fill="url(#skin)"/><path d="M-9 19L-5 20M0 18L3 20" fill="none" stroke="#f4dfad" stroke-width="1.8"/><path d="M-5 3L-7 10" fill="none" stroke="#aec2a1" stroke-width="2"/>',
    "pet_body":'<path d="M-29 5Q-33 -11 -19 -19Q0 -30 17 -21L29 -6L20 16Q-7 32 -26 17Z" fill="url(#skin)"/><path d="M-10 18Q10 24 22 -1L16 -12Q10 4 -10 10Z" fill="url(#ivory)" stroke-width="1.5"/><path d="M-23 -18L-21 -28L-13 -22M-7 -24L-1 -33L6 -23" fill="url(#ivory)"/><path d="M-23 -5L-17 -3M-21 3L-15 6M-13 -11L-7 -8" fill="none" stroke="#4c796e" stroke-width="3"/><path d="M12 -5Q20 -4 17 5L23 8L21 13Q14 15 9 8" fill="url(#skin)"/><path d="M-10 -17Q-2 -22 7 -18" fill="none" stroke="#c6d2b3" stroke-width="2.5"/>',
    "pet_head":'<path d="M-10 13Q-13 0 -11 -17Q-8 -32 7 -34L20 -29Q34 -28 38 -13Q38 0 27 4L10 4L2 21Z" fill="url(#skin)"/><path d="M1 9Q6 -7 19 -6L36 -8Q37 2 26 4L11 4L4 19Z" fill="url(#ivory)" stroke-width="1.5"/><path d="M-9 -18L-18 -23L-11 -29M-3 -32L-5 -42L6 -35" fill="url(#ivory)"/><path d="M18 -8Q24 -6 29 -9Q27 1 23 0Z" fill="#8f4f39" stroke-width="1.5"/><ellipse cx="12" cy="-20" rx="4.8" ry="6.5" fill="#463429" stroke-width="1.5"/><ellipse cx="13" cy="-22" rx="1.5" ry="2" fill="#fff4d5" stroke="none"/><path d="M7 -29Q12 -32 17 -28M29 -18L31 -17" fill="none" stroke-width="2"/><path d="M-5 11Q6 18 15 7" fill="none" stroke="#b87c41" stroke-width="5"/><path d="M0 17L6 12L12 18L6 25Z" fill="url(#ivory)"/><path d="M4 17L7 14L10 18L7 21Z" fill="#70bab0" stroke-width="1.3"/>',
    "drone_body":'<path d="M-19 8L-35 23L-26 25L-32 34L-12 20Z" fill="url(#ivory)"/><path d="M-24 20Q-16 24 -11 20" fill="none" stroke="#b77849" stroke-width="4"/><path d="M-17 13Q-20 -2 -9 -12L4 -22L14 -18L24 -9L35 -6L38 0L20 3L8 16Q-4 24 -17 13Z" fill="url(#ochre)"/><path d="M-4 13L10 -9L24 -3L32 -2Q12 6 6 16Z" fill="url(#ivory)" stroke-width="1.5"/><path d="M3 -23L-3 -38Q11 -39 19 -20" fill="url(#ochre)"/><path d="M-11 0L4 -8L14 2L7 15L-5 16Z" fill="#6d9991"/><path d="M-7 1L0 -4L8 0L6 8L0 10L-3 5L1 2L4 4" fill="none" stroke="#c8f1cf" stroke-width="2"/><path d="M-16 8L-9 12M8 -3L14 -8" fill="none" stroke="#8c593a" stroke-width="4"/><ellipse cx="18" cy="-13" rx="3.4" ry="4.4" fill="#463429" stroke-width="1.3"/><circle cx="19" cy="-14" r="1.1" fill="#fff4d5" stroke="none"/><path d="M26 -3L33 -2M31 -10L32 -9" fill="none" stroke-width="1.7"/>',
    "drone_wing":'<path d="M0 4L13 -16Q30 -40 53 -33L48 -18L49 -4L39 -9L35 13L23 2L15 21L6 11Z" fill="url(#wing)"/><path d="M0 4L14 -16L30 -28L51 -33M14 -16L20 2L15 20M29 -27L34 -2L35 12M44 -31L39 -9" fill="none" stroke="#4b3b2c" stroke-width="4.5"/><path d="M0 3L13 -16L29 -28L51 -33M14 -16L19 2L15 18M29 -26L34 -2L35 10M43 -30L39 -10" fill="none" stroke="#f0dfb7" stroke-width="2.4"/><path d="M10 -8L15 -11M28 -22L32 -25" fill="none" stroke="#b57b48" stroke-width="4"/><path d="M27 -7L30 -12L33 -8L31 -3Z" fill="#e7d8b0" stroke-width="1"/><path d="M9 2L10 6M41 -18L43 -16" fill="none" stroke="#c0d0b3" stroke-width="1.5"/>',
    "shadow":'<ellipse cx="0" cy="0" rx="26" ry="7" fill="#49392a" opacity="0.08" stroke="none"/><ellipse cx="0" cy="0" rx="20" ry="4.5" fill="#49392a" opacity="0.12" stroke="none"/>'
}

static func svg(content: String,extent: int=128) -> String:
    return '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="%d %d %d %d">%s<g stroke="#49392b" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [-extent/2,-extent/2,extent,extent,DEFS,content]

static func texture(id: String) -> Texture2D:
    if cache.has(id): return cache[id]
    if not PARTS.has(id): return null
    var image:=Image.new()
    if image.load_svg_from_string(svg(PARTS[id]))!=OK: return null
    cache[id]=ImageTexture.create_from_image(image)
    return cache[id]

static func portrait(key: String) -> Texture2D:
    var id: String="portrait:"+key
    if cache.has(id): return cache[id]
    var content: String=""
    if key=="pet":
        for part in [["pet_tail",-27,6],["pet_leg",-9,25],["pet_body",0,8],["pet_leg",12,24],["pet_head",20,-8]]:
            content+='<g transform="translate(%s %s)">%s</g>' % [part[1],part[2],PARTS[part[0]]]
    elif key=="drone":
        content='<g transform="translate(-9 0) scale(-1 1)">'+PARTS.drone_wing+'</g><g transform="translate(10 0)">'+PARTS.drone_wing+'</g>'+PARTS.drone_body
    else: return null
    var image:=Image.new()
    if image.load_svg_from_string(svg(content,160))!=OK: return null
    cache[id]=ImageTexture.create_from_image(image)
    return cache[id]

static func pose(key: String,state: Dictionary,clock: float) -> Dictionary:
    var stride: float=float(state.get("stride",0.0))
    var moving: bool=bool(state.get("moving",false))
    var travel: float=sin(stride)*5.0 if moving else 0.0
    var front: Vector2=Vector2(travel,-maxf(0.0,sin(stride))*5.0) if moving else Vector2.ZERO
    var back: Vector2=Vector2(-travel,-maxf(0.0,-sin(stride))*5.0) if moving else Vector2.ZERO
    # Quick downstroke, softer upstroke and a small glide pause, independent of travel.
    var wing: float=sin(clock*15.0)*0.55+sin(clock*30.0)*0.09 if key=="drone" else 0.0
    return {"front_foot":front,"back_foot":back,"tail":sin(stride*0.5)*0.09 if moving else sin(clock*2.0)*0.025,"body_lift":-absf(sin(stride))*1.2 if moving else sin(clock*2.0)*0.35,"wing":wing,"hover":sin(clock*7.5)*1.3}

static func draw_part(canvas: Node2D,id: String,at: Vector2,angle: float=0.0,scale_value: Vector2=Vector2.ONE,tint: Color=Color.WHITE) -> void:
    canvas.draw_set_transform(at,angle,scale_value)
    canvas.draw_texture_rect(texture(id),Rect2(-64,-64,128,128),false,tint)

static func draw(canvas: Node2D,key: String,state: Dictionary,clock: float) -> void:
    var point: Vector2=state.position
    var facing: float=state.facing
    var p: Dictionary=pose(key,state,clock)
    var attack: float=clampf(float(state.attack)/0.2,0.0,1.0)
    var bite: float=sin(attack*PI)
    draw_part(canvas,"shadow",point+Vector2(0,5),0.0,Vector2.ONE if key=="pet" else Vector2(0.85,0.7))
    var body: Vector2=point+Vector2(0,-30+p.body_lift) if key=="pet" else point+Vector2(0,-28+p.hover)
    var mirror: Vector2=Vector2(facing,1)
    if key=="pet":
        # Teal ally tint plus a red collar so the 幼龙 is not mistaken for an enemy 迅猛龙.
        var ally := Color("#7ec9c4")
        draw_part(canvas,"pet_tail",body+Vector2(-27*facing,-2),p.tail*facing,mirror,ally)
        draw_part(canvas,"pet_leg",body+Vector2(-12*facing,15)+Vector2(p.back_foot.x*facing,p.back_foot.y),-sin(float(state.get("stride",0)))*0.08 if state.moving else 0.0,mirror,Color("#8fb8aa"))
        draw_part(canvas,"pet_body",body,0.0,mirror,ally)
        draw_part(canvas,"pet_leg",body+Vector2(12*facing,15)+Vector2(p.front_foot.x*facing,p.front_foot.y),0.0,mirror,ally)
        draw_part(canvas,"pet_head",body+Vector2(20*facing+bite*3*facing,-13),-bite*0.12*facing,mirror,ally)
        canvas.draw_set_transform(Vector2.ZERO)
        var collar_at: Vector2 = body+Vector2(8*facing,-2)
        var collar_rot: float = 0.15*facing
        var collar := PackedVector2Array()
        for offset in [Vector2(-10,-6),Vector2(10,-5),Vector2(11,5),Vector2(-11,4)]:
            collar.append(collar_at + Vector2(offset.x*facing, offset.y).rotated(collar_rot))
        canvas.draw_colored_polygon(collar, Color("#c4453a"))
        var banner := PackedVector2Array()
        for offset in [Vector2(8,-2),Vector2(20,-14),Vector2(16,-2)]:
            banner.append(collar_at + Vector2(offset.x*facing, offset.y).rotated(collar_rot))
        canvas.draw_colored_polygon(banner, Color("#e8c15a"))
    else:
        draw_part(canvas,"drone_wing",body+Vector2(-9*facing,-3),(-0.10-p.wing)*facing,Vector2(-facing,0.85-absf(p.wing)*0.36),Color("#c5c8ae"))
        draw_part(canvas,"drone_wing",body+Vector2(9*facing,1),(0.12+p.wing)*facing,Vector2(facing,1.0-absf(p.wing)*0.20))
        draw_part(canvas,"drone_body",body-state.aim*bite*2,-p.wing*0.035*facing,mirror)
    canvas.draw_set_transform(Vector2.ZERO)
