extends SceneTree

const Catalog = preload("res://src/catalog.gd")
const Library = preload("res://src/asset_library.gd")
const Actor = preload("res://src/actor_view.gd")

func _initialize() -> void:
    call_deferred("render_portraits")

func render_portraits() -> void:
    var library = Library.new()
    var manifest := {"method":"Native ActorView render; same body and limb rig as battle", "characters":{}}
    for id in Catalog.CHARACTER_ORDER:
        var viewport := SubViewport.new()
        viewport.size = Vector2i(560,560)
        viewport.transparent_bg = true
        viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        root.add_child(viewport)
        var actor = Actor.new()
        actor.setup(library,id)
        actor.position = Vector2(280,215)
        actor.scale = Vector2.ONE * 6.0
        actor.get_node("PlayerMarker").hide()
        viewport.add_child(actor)
        await process_frame
        await RenderingServer.frame_post_draw
        var path: String = Catalog.character(id).portrait
        var error: Error = viewport.get_texture().get_image().save_png(path)
        if error != OK:
            push_error("Portrait export failed: " + path)
            quit(1)
            return
        manifest.characters[id] = {"body":Catalog.character(id).body,"body_sha256":FileAccess.get_sha256(Catalog.character(id).body),"portrait":path,"portrait_sha256":FileAccess.get_sha256(path)}
        print("EXPORTED: " + path)
        viewport.queue_free()
        await process_frame
    var file := FileAccess.open("res://assets/characters/v14/portrait_manifest.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(manifest,"  ") + "\n")
    file.close()
    quit(0)
