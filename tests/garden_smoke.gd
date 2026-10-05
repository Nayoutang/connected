extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func press(node: Node, prefix: String) -> void:
	for button in node.find_children("*", "Button", true, false):
		if button.text.begins_with(prefix):
			button.pressed.emit()
			return
	check(false, "Missing button " + prefix)
func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func shot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../lab-previews/garden-%s.png" % name)
func hotspot(world: Node, kind: String) -> int:
	for i in world.world.hotspots.size():
		if world.world.hotspots[i]["kind"] == kind:
			return i
	return -1
func run() -> void:
	change_scene_to_file("res://main.tscn")
	await create_timer(0.7).timeout
	var game = current_scene
	var nav = game.navigation
	nav.show_screen("hub")
	await create_timer(0.6).timeout
	press(nav.home, "水路地图")
	await create_timer(0.9).timeout
	check(nav.screen == "explore" and game.ui_paused, "Explore must pause water simulation")
	var world = nav.home
	check(world.view.own_world_3d and world.world.hotspots.size() == 8, "Main map must have seven physical entrances plus home")
	var start: Vector2 = world.position_2d
	key(KEY_W, true)
	await create_timer(0.45).timeout
	key(KEY_W, false)
	check(world.position_2d.distance_to(start) > 0.4, "W must move character in depth")
	start = world.position_2d
	key(KEY_D, true)
	await create_timer(0.3).timeout
	key(KEY_D, false)
	check(world.position_2d.distance_to(start) > 0.3, "D must move character laterally")
	world.position_2d = Vector2(0, 11.5)
	world.update_camera(1, true)
	await create_timer(0.15).timeout
	await shot("city")
	world.walk_to(Vector2(0, -7))
	check(world.path.size() > 5, "River route should use a bridge")
	for point in world.path:
		check(world.world.walkable(point), "Every path waypoint must avoid obstacles")
	world.path.clear()
	world.toggle_map()
	check(world.map_open, "M opens map network")
	await shot("map")
	world.toggle_map()
	for region in 7:
		world.change_location(region)
		await create_timer(0.6).timeout
		check(world.location == region and region in world.visited, "Every region must be connected to the map")
		check(hotspot(world, "exit") >= 0 and hotspot(world, "region") >= 0, "Every scene needs a map return and neighbor exit")
		var id := hotspot(world, "npc")
		world.position_2d = Vector2(0, 6.8)
		world.interact(id)
		check(world.dialogue == null, "Remote NPC interaction must be blocked")
		world.position_2d = world.world.hotspots[id]["point"]
		world.interact(id)
		check(world.dialogue != null and region in world.talked, "Near NPC interaction should talk")
		world.close_panels()
		id = hotspot(world, "device")
		world.position_2d = world.world.hotspots[id]["point"] + Vector2(-0.5, 1)
		world.interact(id)
		check(world.mission_panel != null and region in world.examined, "Device should expose local repair tasks")
		world.close_panels()
		id = hotspot(world, "chest")
		world.walk_to(world.world.hotspots[id]["point"])
		check(world.path.size() > 0, "Raised terrace chest must be reachable by stairs")
		world.path.clear()
		world.position_2d = world.world.hotspots[id]["point"]
		world.interact(id)
		check(region in world.collected, "Chest records a collectible")
		world.close_panels()
		world.interact(id)
		check(world.dialogue == null, "Collected chest must not reopen")
		if world.dialogue != null:
			world.close_panels()
	world.position_2d = Vector2(0, 3.8)
	world.update_camera(1, true)
	await create_timer(0.15).timeout
	await shot("scene")
	world.walk_to(Vector2(-7, -3.7))
	check(world.path.size() > 5, "Raised destination should produce a stair route")
	await shot("route")
	world.set_process(false)
	for step in 1100:
		world._process(0.016)
	world.set_process(true)
	check(world.position_2d.distance_to(Vector2(-7, -3.7)) < 1.4, "Automatic movement must reach the terrace around obstacles")
	check(world.actor.position.y > 1.4, "Actor should climb to terrace height")
	world.position_2d = Vector2(0, 3.8)
	world.update_camera(1, true)
	world.path.clear()
	root.size = Vector2i(960, 540)
	await create_timer(0.15).timeout
	await shot("small")
	root.size = Vector2i(1280, 720)
	await create_timer(0.15).timeout
	world.change_location(-1)
	await create_timer(0.6).timeout
	check(world.location == -1, "Scene must return to full city")
	world.change_location(4)
	await create_timer(0.6).timeout
	var id := hotspot(world, "device")
	world.position_2d = world.world.hotspots[id]["point"]
	world.interact(id)
	await shot("missions")
	press(world.mission_panel, "11")
	await create_timer(1.4).timeout
	check(current_scene.get_script().resource_path.ends_with("lab.gd"), "Task 11 must enter real laboratory")
	var lab = current_scene
	lab.transition.cancel()
	lab.story.close()
	lab.navigation.return_to_city()
	await create_timer(0.9).timeout
	check(lab.navigation.home.location == 4, "Repair scene must return to its physical district")
	check(lab.navigation.home.collected.size() == 7, "Exploration records must survive campaign scene changes")
	lab.navigation.home.close_panels()
	lab.navigation.home.back()
	await create_timer(0.6).timeout
	check(lab.navigation.home.location == -1, "District back should return to main map")
	lab.navigation.show_screen("pause")
	await create_timer(0.6).timeout
	press(lab.navigation.card, "返回大地图")
	await create_timer(0.8).timeout
	check(lab.navigation.home.location == -1 and lab.navigation.home.map_open, "Any repair scene must open the main map directly")
	print("GARDEN: %d failures" % failures)
	quit(failures)
