extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game = load("res://main.tscn").instantiate()
 game.set_meta("skip_story", true)
 root.add_child(game)
 await create_timer(0.6).timeout
 for pair in [["grass", 2], ["flower", 5], ["tree", 9]]:
  game._load_level(pair[1])
  await create_timer(0.3).timeout
  game._start_reveal(pair[0])
  assert(not game.btn_next.disabled)
  await create_timer(0.3).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../lab-previews/report-final-" + pair[0] + ".png")
 print("REPORTS: all three rendered; continue immediately available")
 quit()
