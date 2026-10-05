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
	await create_timer(0.7).timeout
	var nav = current_scene.navigation
	nav.show_screen("explore")
	await create_timer(0.8).timeout
	var explore = nav.home
	check(explore.first_person and explore.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Default must be first person")
	check(not explore.actor.visible, "Player mesh must not occlude eye camera")
	check(is_equal_approx(explore.camera.position.y - explore.world.floor_height(explore.position_2d), 1.52), "Eye height must follow floor")
	check(explore.world.find_children("StonePaving*", "MeshInstance3D", true, false).size() > 0, "Stone floor must be instantiated")
	check(explore.world.find_children("ImportedBuilding*", "Node3D", true, false).size() > 0, "Imported houses and shops must be in city")
	var start: Vector2 = explore.position_2d
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.physical_keycode = KEY_W
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(0.4).timeout
	event.pressed = false
	Input.parse_input_event(event)
	check(explore.position_2d.distance_to(start) > 0.5, "First-person W must move")
	var toggle := InputEventKey.new()
	toggle.keycode = KEY_V
	toggle.physical_keycode = KEY_V
	toggle.pressed = true
	Input.parse_input_event(toggle)
	await process_frame
	check(not explore.first_person and explore.actor.visible, "V must restore third-person player")
	toggle.pressed = false
	Input.parse_input_event(toggle)
	await process_frame
	toggle.pressed = true
	Input.parse_input_event(toggle)
	await process_frame
	check(explore.first_person and not explore.actor.visible, "V must return to first person")
	toggle.pressed = false
	Input.parse_input_event(toggle)
	explore.change_location(1)
	await create_timer(0.7).timeout
	explore.position_2d = Vector2(0, 3.8)
	explore.view_pitch = -0.10
	explore.update_camera(1.0, true)
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(30, 10)
	explore.looking = true
	var yaw: float = explore.view_yaw
	explore._input(mouse)
	check(explore.view_yaw < yaw, "Mouse look must change yaw")
	explore.toggle_map()
	check(not explore.looking and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Map must release cursor")
	explore.toggle_map()
	explore.view_yaw = 0.0
	explore.view_pitch = -0.08
	explore.update_camera(1.0, true)
	await create_timer(0.2).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://first-person-street.png")
	print("FIRST PERSON: %d failures" % failures)
	quit(failures)
