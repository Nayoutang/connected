extends SceneTree
## Run headless for UI actions, or with -- --preview-dir=<absolute directory> to capture.

var lab
var failures := 0
var preview_dir := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preview-dir="):
			preview_dir = argument.trim_prefix("--preview-dir=")
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func shot(name: String) -> void:
	if preview_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preview_dir.path_join(name + ".png"))

func run() -> void:
	lab = load("res://lab.tscn").instantiate()
	lab.set_meta("skip_story", true)
	root.add_child(lab)
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(440, 230)
	root.push_input(click, true)
	check(lab.selected == "T" and not lab.selected_edge, "Canvas click selects tank socket")
	check(not lab.tank_button.disabled, "Tank socket can be configured")
	lab.tank_button.pressed.emit()
	check(lab.sim.node("T").installed, "Install tank through UI")
	await shot("lab-tank")
	lab.play_button.pressed.emit()
	check(lab.sim.started, "Play button starts simulation")
	lab.play_button.pressed.emit()
	var before: int = lab.sim.tick
	await create_timer(0.5).timeout
	check(lab.sim.tick == before, "Pause freezes simulation")
	lab._single_step()
	check(lab.sim.tick == before + 1 and lab.paused, "Single step stays paused")
	lab._load(1)
	click.position = Vector2(780, 375)
	root.push_input(click, true)
	check(lab.selected == "AB" and lab.selected_edge, "Canvas click selects connecting pipe")
	lab.check_button.pressed.emit()
	lab.check_button.pressed.emit()
	check(lab.sim.edge("AB").check == -1, "One-way valve reversed through UI")
	lab._select("A", false)
	lab.target_picker.select(0)
	lab.low.value = 2
	lab.high.value = 6
	lab.link_button.pressed.emit()
	check(lab.sim.floats.size() == 1, "Generic float link created through UI")
	await shot("lab-dual-prepared")
	for i in 14:
		lab._single_step()
	await shot("lab-dual-flowing")
	for i in 80:
		lab._single_step()
	check(lab.sim.won and lab.result_panel.visible, "Automatic dual pool solution shows result")
	await create_timer(0.3).timeout
	await shot("lab-dual-result")
	lab._load(2)
	lab._select("T", false)
	lab.tank_button.pressed.emit()
	lab.target_picker.select(0)
	lab.link_button.pressed.emit()
	for i in 12:
		lab._single_step()
	await shot("lab-feedback")
	for i in 100:
		lab._single_step()
	check(lab.sim.won, "Irrigation succeeds from UI-configured controller")
	lab._load(0)
	check(not lab.sim.started and lab.sim.floats.is_empty() and not lab.result_panel.visible, "Reset clears prior run")
	print("LAB UI SMOKE: ", failures, " failure(s)")
	quit(1 if failures else 0)
