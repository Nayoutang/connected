extends SceneTree
const Dimensions := preload("res://scripts/world_dimensions.gd")
var failures := 0
var measurements := {}
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
	for region in range(-1, 7):
		explore.load_garden(region, Vector2(-13, 12) if region < 0 else Vector2(0, 6.8))
		await process_frame
		var footprints: Array[Rect2] = []
		for model in explore.world.get_children():
			if not model.has_meta("component_kind"):
				continue
			var kind: String = model.get_meta("component_kind")
			var actual: AABB = Dimensions.mesh_bounds(model)
			check(is_equal_approx(model.scale.x, model.scale.y) and is_equal_approx(model.scale.y, model.scale.z), "Nonuniform model scale: " + kind)
			if kind in ["house", "shop"]:
				check(absf(actual.size.x - float(Dimensions.WIDTHS[kind])) < 0.01, "Incorrect building width: " + kind)
				check(actual.size.y > Dimensions.HERO_HEIGHT * 3.8, "Building too short beside hero: " + kind)
				var footprint := Rect2(actual.position.x, actual.position.z, actual.size.x, actual.size.z)
				for previous in footprints:
					check(not footprint.intersects(previous), "House/shop overlap in region %d" % region)
				footprints.append(footprint)
			measurements[kind] = {"width": actual.size.x, "height": actual.size.y, "depth": actual.size.z}
		for hotspot in explore.world.hotspots:
			explore.walk_to(hotspot["point"])
			check(not explore.path.is_empty(), "Unreachable hotspot region %d: %s" % [region, hotspot["label"]])
			if not explore.path.is_empty():
				check(explore.path[-1].distance_to(hotspot["point"]) < 2.9, "Hotspot approach blocked: " + hotspot["label"])
			explore.path.clear()
	explore.load_garden(1, Vector2(0, 3.8))
	explore.view_pitch = 0.08
	explore.update_camera(1.0, true)
	await create_timer(0.3).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://street-scale.png")
	var file := FileAccess.open("user://measured-dimensions.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements, "  "))
	print("SCALE: %d failures" % failures)
	quit(failures)
