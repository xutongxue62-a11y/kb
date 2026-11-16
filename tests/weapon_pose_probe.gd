extends RefCounted
static var samples: Dictionary={}
static var body_images: Dictionary={}

static func visible_center(sprite: Sprite2D) -> Vector2:
    return sprite.to_global(sprite.offset)

static func torso_overlap_area(body: Sprite2D,weapon: Sprite2D) -> float:
    var id: int=weapon.texture.get_instance_id()
    if not samples.has(id):
        var image: Image=weapon.texture.get_image()
        var stride: int=maxi(1,ceili(maxf(image.get_width(),image.get_height())/80.0))
        var points: Array=[]
        for y in range(stride/2,image.get_height(),stride):
            for x in range(stride/2,image.get_width(),stride):
                if image.get_pixel(x,y).a>=0.85:
                    points.append(Vector2(x+0.5,y+0.5)-weapon.texture.get_size()*0.5)
        samples[id]={"points":points,"area":float(stride*stride)}
    var body_id: int=body.texture.get_instance_id()
    if not body_images.has(body_id): body_images[body_id]=body.texture.get_image()
    var body_image: Image=body_images[body_id]
    var inverse: Transform2D=body.global_transform.affine_inverse()
    var extent: Vector2=body.texture.get_size()*0.5
    var overlap: float=0.0
    for point in samples[id].points:
        var at: Vector2=inverse*(weapon.to_global(point+weapon.offset))+extent-body.offset
        var pixel:=Vector2i(at)
        if pixel.x>=0 and pixel.y>=0 and pixel.x<body_image.get_width() and pixel.y<body_image.get_height() and body_image.get_pixelv(pixel).a>=0.85:
            overlap+=float(samples[id].area)*absf(weapon.global_transform.determinant())
    return overlap

static func minimum_extra_hold(body: Sprite2D,weapon: Sprite2D) -> float:
    var original: Vector2=weapon.offset
    var direction: Vector2=(weapon.to_global(original)-weapon.global_position).normalized()
    var local_step: Vector2=weapon.global_transform.basis_xform_inv(direction)
    var lower:=0.0
    var upper:=24.0
    for i in range(9):
        var candidate: float=(lower+upper)*0.5
        weapon.offset=original+local_step*candidate
        if torso_overlap_area(body,weapon)<=2.0: upper=candidate
        else: lower=candidate
    weapon.offset=original
    return upper
