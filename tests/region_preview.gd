extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var paths := {}
 for lab_mode in [false, true]:
  var scene = load("res://lab.tscn" if lab_mode else "res://main.tscn").instantiate()
  scene.set_meta("skip_story", true)
  root.add_child(scene)
  await create_timer(0.6).timeout
  for i in (3 if lab_mode else 4):
   if lab_mode:
    scene._load(i)
   else:
    scene._load_level(i)
   await create_timer(0.3).timeout
   var texture: Texture2D = scene.backdrop.current_texture
   assert(texture != null)
   assert(not paths.has(texture.resource_path))
   paths[texture.resource_path] = true
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://../lab-previews/region-" + scene.backdrop.region + ".png")
  scene.queue_free()
  await process_frame
 print("REGIONS: 7 unique backgrounds loaded and rendered")
 quit()
