extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	change_scene_to_file("res://main.tscn")
	await create_timer(0.6).timeout
	var game = current_scene
	game.enter_level(0)
	check(game.transition.active and not game.story.active, "Brief must precede dialogue")
	await create_timer(0.5).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../lab-previews/transition-arrival.png")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	root.push_input(key, true)
	check(not game.transition.active and game.story.active, "Skip should open story exactly once")
	game.story.close()
	game.enter_level(1)
	game.enter_level(2)
	await create_timer(2.2).timeout
	check(game.lv_index == 2 and game.story.active and not game.transition.active, "Latest brief must finish automatically")
	game.story.close()
	game.enter_level(10)
	await create_timer(0.5).timeout
	game = current_scene
	check(game.transition.active and game.lv_index == 10, "Cross-scene brief missing")
	game.sim.start()
	var ticks: int = game.sim.tick
	await create_timer(0.4).timeout
	check(game.sim.tick == ticks, "Simulation advanced behind brief")
	root.size = Vector2i(960, 540)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../lab-previews/transition-small.png")
	game.transition.finish()
	game.story.close()
	game._on_reset()
	check(not game.transition.active, "Reset should not replay arrival")
	print("TRANSITION: %d failures" % failures)
	quit(failures)
