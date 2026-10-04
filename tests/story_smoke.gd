extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func shot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../lab-previews/" + name + ".png")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.6).timeout
	game.enter_level(0)
	await create_timer(0.35).timeout
	check(game.story.active, "Opening story missing")
	check(game.story.body.visible_characters > 0, "Typewriter stalled")
	game.story.advance()
	check(game.story.body.visible_characters == game.story.body.text.length(), "First advance should reveal line")
	await shot("story-acheng")
	game.story.advance()
	check(game.story.speaker.text == "岑伯", "Speaker should switch")
	await create_timer(0.4).timeout
	game.story.advance()
	await shot("story-cen")
	game.story.close()
	check(not game.story.active, "Skip should dismiss story")
	for i in game.levels.size():
		game.enter_level(i)
		check(game.story.active, "Missing chapter introduction %d" % i)
		check(not game.story.body.text.is_empty(), "Empty chapter dialogue")
		game.story.close()
		await create_timer(0.25).timeout
		game.sim = game._solved_sim(game.levels[i])
		game.running = true
		game.win_timer = 0.1
		game._process(0.2)
		check(game.won and game.story.active, "Missing chapter ending %d" % i)
		game.story.close()
		game._on_next()
		if game.levels[i]["caption"] != "":
			check(game.mode == "reveal", "Story must preserve chapter reveal")
		if game.story.active:
			game.story.close()
	game.queue_free()
	await process_frame
	var lab = load("res://lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	lab.sim.start()
	await create_timer(0.5).timeout
	check(lab.sim.tick == 0, "Dialogue must pause simulation")
	lab.story.close()
	await create_timer(0.5).timeout
	check(lab.sim.tick > 0, "Simulation must resume after dialogue")
	lab.paused = true
	lab.story.play(load("res://scripts/story_data.gd").chapter(true, 0))
	lab.story.close()
	check(lab.paused, "Replay must preserve player's pause state")
	lab._load(1)
	lab.story.close()
	await shot("story-lab")
	root.size = Vector2i(960, 540)
	lab.story.play(load("res://scripts/story_data.gd").chapter(true, 1))
	await create_timer(0.3).timeout
	lab.story.advance()
	await shot("story-small-window")
	lab.queue_free()
	await process_frame
	print("STORY TESTS: %d failures" % failures)
	quit(failures)

