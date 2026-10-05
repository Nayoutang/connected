extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var hero = load("res://scenes/characters/adventure_character.tscn").instantiate()
	stage.add_child(hero)
	await process_frame
	check(hero.skeleton != null and hero.skeleton.get_bone_count() == 66, "Expected 66-bone imported rig")
	check(hero.animation_player != null, "Expected imported AnimationPlayer")
	check(hero.animation_player.current_animation == "idle", "Stationary character must play imported idle")
	var leg: int = hero.skeleton.find_bone("mixamorig_LeftUpLeg")
	var before: Quaternion = hero.skeleton.get_bone_pose_rotation(leg)
	hero.set_locomotion(true, false)
	await create_timer(0.45).timeout
	check(hero.animation_player.is_playing(), "Movement must play walk")
	check(not before.is_equal_approx(hero.skeleton.get_bone_pose_rotation(leg)), "Walk must animate skeleton")
	check(hero.position.is_equal_approx(Vector3.ZERO), "Animation must not displace navigation root")
	hero.set_locomotion(true, true)
	check(is_equal_approx(hero.animation_player.speed_scale, 1.78), "Run must speed up available walk")
	hero.set_locomotion(false, false)
	check(hero.animation_player.current_animation == "idle", "Stop must return to idle")
	hero.play_wave()
	check(hero.animation_player.current_animation == "wave_goodbye_02", "Interaction must play wave")
	hero.animation_player.advance(6.1)
	check(hero.animation_player.current_animation == "idle", "Wave must return to idle")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(850, 1000)
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.position = Vector3(2.7, 1.65, 4.5)
		camera.look_at(Vector3(0, 1.2, 0))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 3.15
		var light := DirectionalLight3D.new()
		stage.add_child(light)
		light.rotation_degrees = Vector3(-35, -25, 0)
		light.light_energy = 1.1
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("52666c")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color("ffffff")
		environment.environment.ambient_light_energy = 0.6
		stage.add_child(environment)
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://imported-character-preview.png")
	stage.queue_free()
	await process_frame
	print("CHARACTER: %d failures" % failures)
	quit(failures)
