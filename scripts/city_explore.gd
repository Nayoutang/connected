extends "res://scripts/city_home.gd"
## Oblique 3D gardens in the existing 2D navigation layer.
const World := preload("res://scripts/garden_world.gd")
const REGIONS := ["gate", "old_street", "reservoir", "clocktower", "greenhouse", "nursery", "households"]
const NAMES := World.NAMES
const TASKS := [[0], [1, 6], [2, 8], [3], [4, 10], [5, 9, 12], [7, 11]]
const NOTES := ["水口的水位标尺仍然清楚。接通旧管，让幼苗喝到第一股水。", "旧街闸门已经关了很久。有限的开阀次数，要留给真正需要的支路。", "雨水从高台送向街区。出口高度比路线的长短更重要。", "钟楼高墙挡住了管道。虹吸出口必须比供水水位低。", "温室里的花等待不同颜色的水。红水和蓝水要在管道中汇合。", "苗圃的枝梢都在等水。用浮子控制补水，让它自己运转。", "高处住户和公共厨房共用一座水塔。让两边都留住水。"]
const JOURNEY := preload("res://assets/exploration/journey.png")
const DIALOGUE_ART := preload("res://assets/exploration/dialogue.png")
const STAR := preload("res://assets/exploration/star.png")
const VOYAGE := preload("res://assets/exploration/voyage.png")
const MAP_POS := [Vector2(236, 536), Vector2(548, 536), Vector2(860, 536), Vector2(236, 373), Vector2(548, 373), Vector2(860, 373), Vector2(548, 242)]
var location := -1
var map_open := false
var visited: Array = []
var examined: Array = []
var collected: Array = []
var completed: Array = []
var talked: Array = []
var position_2d := Vector2(-13, 12)
var city_return := Vector2(-13, 12)
var hover_id := -1
var nearest_id := -1
var path := PackedVector2Array()
var path_index := 0
var pending_id := -1
var walking := false
var running := false
var walk_phase := 0.0
var time := 0.0
var transition_busy := false
var view: SubViewport
var garden: Node3D
var world: Node3D
var camera: Camera3D
var actor: Node3D
var camera_target := Vector3.ZERO
var first_person := true
var view_yaw := 0.0
var view_pitch := 0.0
var looking := false
const Dimensions := preload("res://scripts/world_dimensions.gd")
const EYE_HEIGHT := Dimensions.EYE_HEIGHT
const LOOK_SENSITIVITY := 0.003

var astar := AStarGrid2D.new()
var grid_origin := Vector2.ZERO
const GRID_STEP := 0.65
var focus_fx: Control
var ui: Control
var dialogue: Panel
var mission_panel: Panel
var objective_label: Label
var prompt_label: Label
var viewport_container: SubViewportContainer
var markers: Control
var task_levels := preload("res://scripts/chapter1.gd").get_levels()
const Campaign := preload("res://scripts/campaign.gd")

func setup_explore(nav: Control) -> void:
	navigation = nav
	map_mode = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var state: Dictionary = get_tree().root.get_meta("garden_state", {})
	visited = state.get("visited", []).duplicate()
	examined = state.get("examined", []).duplicate()
	collected = state.get("collected", []).duplicate()
	talked = state.get("talked", []).duplicate()
	completed = get_tree().root.get_meta("city_completed", []).duplicate()
	city_return = state.get("city_return", Vector2(-13, 12))
	var start_region: int = int(get_tree().root.get_meta("garden_return_region", state.get("location", -1)))
	get_tree().root.remove_meta("garden_return_region")
	position_2d = state.get("point", city_return) if start_region == state.get("location", -1) else (city_return if start_region < 0 else Vector2(0, 6.8))
	viewport_container = SubViewportContainer.new()
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport_container)
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_2X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.handle_input_locally = false
	viewport_container.add_child(view)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	markers = Control.new()
	markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	markers.draw.connect(draw_markers)
	add_child(markers)
	focus_fx = preload("res://scripts/explore_focus.gd").new()
	add_child(focus_fx)
	load_garden(start_region, position_2d)
	if get_tree().root.get_meta("garden_open_map", false):
		get_tree().root.remove_meta("garden_open_map")
		toggle_map()

func make_label(value: String, pos: Vector2, dimensions: Vector2, font_size: int, color := PAPER, parent: Control = null) -> Label:
	var label := title_label(value, pos, dimensions, font_size, color)
	remove_child(label)
	(ui if parent == null else parent).add_child(label)
	return label

func make_button(value: String, pos: Vector2, dimensions: Vector2, callback: Callable, parent: Control = null) -> Button:
	var button := action(value, pos, dimensions, callback)
	remove_child(button)
	(ui if parent == null else parent).add_child(button)
	button.mouse_entered.connect(func(): focus_fx.active = true; focus_fx.target = pos + dimensions * 0.5)
	button.mouse_exited.connect(func(): focus_fx.active = false)
	return button

func picture(texture: Texture2D, pos: Vector2, dimensions: Vector2, parent: Control = null) -> void:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.position = pos
	rect.size = dimensions
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(ui if parent == null else parent).add_child(rect)

func dark_panel(pos: Vector2, dimensions: Vector2, parent: Control = null) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style())
	(ui if parent == null else parent).add_child(panel)
	return panel

func build_ui() -> void:
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	focus_fx.active = false
	picture(JOURNEY, Vector2(109, 31), Vector2(204, 39))
	make_label("百阶城 · 归城小记" if location < 0 else NAMES[location], Vector2(112, 70), Vector2(620, 40), 29, GOLD)
	make_label("沿着水声，走过每一条街。" if location < 0 else "散步 / 交谈 / 调查 / 修复", Vector2(113, 111), Vector2(590, 30), 17)
	make_button("‹  返回", Vector2(24, 24), Vector2(80, 52), back)
	make_label("ESC", Vector2(43, 77), Vector2(70, 24), 13)
	make_button("大地图  M", Vector2(1060, 28), Vector2(184, 46), toggle_map)
	make_button("关卡目录", Vector2(1060, 86), Vector2(184, 42), func(): save_state(); navigation.show_screen("levels"))
	var journal := dark_panel(Vector2(28, 177), Vector2(255, 182))
	picture(VOYAGE, Vector2(16, 9), Vector2(149, 31), journal)
	make_label("循水归城", Vector2(20, 42), Vector2(220, 28), 23, GOLD, journal)
	objective_label = make_label("", Vector2(20, 80), Vector2(218, 92), 17, PAPER, journal)
	dark_panel(Vector2(895, 487), Vector2(350, 141))
	prompt_label = make_label("", Vector2(902, 556), Vector2(335, 71), 23, GOLD)
	picture(DIALOGUE_ART, Vector2(1088, 480), Vector2(119, 67))
	make_label("WASD 移动 · Shift 快走 · 按住右键转头\nF 交互 · M 大地图 · V 切换视角", Vector2(34, 650), Vector2(880, 58), 17)
	update_objective()
	if map_open:
		build_map()

func update_objective() -> void:
	if objective_label == null:
		return
	objective_label.text = "到访街区  %d / 7\n调查水路  %d / 7\n收集物资  %d / 7\n修复委托  %d / 13" % [visited.size(), examined.size(), collected.size(), completed.size()]
	if location >= 0:
		objective_label.text = "与岑伯交谈  %s\n调查检修台  %s\n寻找物资箱  %s" % ["✓" if location in talked else "○", "✓" if location in examined else "○", "✓" if location in collected else "○"]

func load_garden(index: int, spawn: Vector2) -> void:
	location = index
	if is_instance_valid(garden):
		view.remove_child(garden)
		garden.queue_free()
	garden = Node3D.new()
	view.add_child(garden)
	world = World.new()
	garden.add_child(world)
	world.build(index)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("a7bdba")
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("6496bb")
	sky_material.sky_horizon_color = Color("c5d7cf")
	sky_material.ground_horizon_color = Color("c5d7cf")
	sky_material.ground_bottom_color = Color("7c8c77")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.environment.sky = sky
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d8e3df")
	environment.environment.ambient_light_energy = 0.42
	garden.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_color = Color("ffe5b9")
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70
	garden.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE if first_person else Camera3D.PROJECTION_ORTHOGONAL
	camera.fov = 75
	camera.near = 0.05
	camera.size = 20 if index < 0 else 18
	camera.far = 130
	garden.add_child(camera)
	build_navigation()
	position_2d = nearest_walkable(spawn)
	actor = world.make_actor(position_2d)
	actor.visible = not first_person
	view_yaw = 0.0
	view_pitch = -0.06
	if index >= 0:
		world.make_actor(Vector2(-4.2, 3.0), true)
		if index not in visited:
			visited.append(index)
	camera_target = Vector3(position_2d.x, world.floor_height(position_2d), position_2d.y)
	update_camera(1.0, true)
	path.clear()
	pending_id = -1
	nearest_id = -1
	hover_id = -1
	map_open = false
	close_panels()
	build_ui()
	save_state()

func build_navigation() -> void:
	var bounds := Dimensions.CITY_BOUNDS if location < 0 else Dimensions.GARDEN_BOUNDS
	grid_origin = bounds.position + Vector2.ONE * GRID_STEP * 0.5
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, int(bounds.size.x / GRID_STEP), int(bounds.size.y / GRID_STEP))
	astar.cell_size = Vector2.ONE * GRID_STEP
	astar.offset = grid_origin
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for x in astar.region.size.x:
		for y in astar.region.size.y:
			astar.set_point_solid(Vector2i(x, y), not world.walkable(grid_origin + Vector2(x, y) * GRID_STEP))

func cell_of(point: Vector2) -> Vector2i:
	var id := Vector2i(((point - grid_origin) / GRID_STEP).round())
	id.x = clampi(id.x, 0, astar.region.size.x - 1)
	id.y = clampi(id.y, 0, astar.region.size.y - 1)
	return id

func nearest_cell(point: Vector2) -> Vector2i:
	var first := cell_of(point)
	var best := first
	var distance := INF
	for radius in range(9):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var id := first + Vector2i(x, y)
				if astar.region.has_point(id) and not astar.is_point_solid(id):
					var length := (grid_origin + Vector2(id) * GRID_STEP).distance_squared_to(point)
					if length < distance:
						distance = length
						best = id
		if distance < INF:
			return best
	return first

func nearest_walkable(point: Vector2) -> Vector2:
	return grid_origin + Vector2(nearest_cell(point)) * GRID_STEP

func walk_to(point: Vector2, hotspot := -1) -> void:
	path = astar.get_point_path(nearest_cell(position_2d), nearest_cell(point))
	path_index = 0
	pending_id = hotspot
	if path.is_empty():
		pending_id = -1
		prompt_label.text = "这里暂时无法到达"

func update_camera(delta: float, snap := false) -> void:
	if first_person:
		camera_target = Vector3(position_2d.x, world.floor_height(position_2d) + EYE_HEIGHT, position_2d.y)
		camera.position = camera_target
		camera.rotation = Vector3(view_pitch, view_yaw, 0)
	else:
		var desired := Vector3(position_2d.x, world.floor_height(position_2d) + 0.65, position_2d.y)
		camera_target = desired if snap else camera_target.lerp(desired, 1 - exp(-delta * 5))
		camera.position = camera_target + Vector3(12, 17, 18)
		camera.look_at(camera_target)

func toggle_perspective() -> void:
	first_person = not first_person
	_release_look()
	actor.visible = not first_person
	if first_person:
		for node in world.occluders:
			node.material_override = node.get_meta("opaque_material")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE if first_person else Camera3D.PROJECTION_ORTHOGONAL
	update_camera(1.0, true)

func _release_look() -> void:
	looking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _exit_tree() -> void:
	_release_look()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		_release_look()
	if not first_person or transition_busy or navigation.switching or map_open or dialogue != null or mission_panel != null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and is_scene_point(event.position):
		looking = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and looking:
		view_yaw -= event.relative.x * LOOK_SENSITIVITY
		view_pitch = clampf(view_pitch - event.relative.y * LOOK_SENSITIVITY, -1.2, 1.2)
		update_camera(0.0, true)
		get_viewport().set_input_as_handled()

func move_player(direction: Vector2, distance: float) -> void:
	var next := position_2d + direction * distance
	# Axis sliding lets keyboard walking skim a wall without crossing it.
	if world.walkable(next):
		position_2d = next
	elif world.walkable(Vector2(next.x, position_2d.y)):
		position_2d.x = next.x
	elif world.walkable(Vector2(position_2d.x, next.y)):
		position_2d.y = next.y
	else:
		return
	walking = true
	actor.rotation.y = lerp_angle(actor.rotation.y, atan2(direction.x, direction.y), 0.2)

func _process(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	time += delta
	walking = false
	running = Input.is_physical_key_pressed(KEY_SHIFT)
	if not navigation.switching and not transition_busy and not map_open and dialogue == null and mission_panel == null:
		var raw := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		var speed := 4.0 if running else 2.4
		if raw.length() > 0:
			path.clear()
			pending_id = -1
			var direction3 := camera.basis.x * raw.x + camera.basis.z * raw.y
			move_player(Vector2(direction3.x, direction3.z).normalized(), speed * minf(delta, 0.05))
		elif path_index < path.size():
			var difference := path[path_index] - position_2d
			if difference.length() < 0.10:
				path_index += 1
			else:
				move_player(difference.normalized(), minf(speed * minf(delta, 0.05), difference.length()))
		elif pending_id >= 0:
			var id := pending_id
			pending_id = -1
			if position_2d.distance_to(world.hotspots[id]["point"]) < 2.9:
				interact(id)
		update_camera(delta)
		update_nearest()
		update_hover(get_local_mouse_position())
	if walking:
		walk_phase += delta * (15 if running else 9)
	actor.position = Vector3(position_2d.x, world.floor_height(position_2d), position_2d.y)
	actor.set_locomotion(walking, running)
	if not first_person:
		world.fade_occluders(actor.global_position + Vector3(0, 1.05, 0), camera.global_position)
	if looking and (map_open or dialogue != null or mission_panel != null or transition_busy or navigation.switching):
		_release_look()
	markers.queue_redraw()
	queue_redraw()

func update_nearest() -> void:
	nearest_id = -1
	var closest := 2.9
	for i in world.hotspots.size():
		var hotspot: Dictionary = world.hotspots[i]
		if hotspot["kind"] == "chest" and location in collected:
			continue
		var distance := position_2d.distance_to(hotspot["point"])
		if distance < closest:
			closest = distance
			nearest_id = i
	prompt_label.text = "F  " + world.hotspots[nearest_id]["label"] if nearest_id >= 0 else "走近人物或物件\n即可交互"

func screen_point(hotspot: Dictionary) -> Vector2:
	var point: Vector2 = hotspot["point"]
	var pos := Vector3(point.x, world.floor_height(point) + (2.0 if hotspot["kind"] == "npc" else 1.65), point.y)
	if camera.is_position_behind(pos):
		return Vector2(-10000, -10000)
	return camera.unproject_position(pos) * size / Vector2(view.size)

func update_hover(point: Vector2) -> void:
	hover_id = -1
	if not is_scene_point(point):
		return
	for i in world.hotspots.size():
		if world.hotspots[i]["kind"] == "chest" and location in collected:
			continue
		var hotspot: Dictionary = world.hotspots[i]
		var ground: Vector2 = hotspot["point"]
		if camera.is_position_behind(Vector3(ground.x, world.floor_height(ground) + 1.0, ground.y)):
			continue
		var foot := camera.unproject_position(Vector3(ground.x, world.floor_height(ground), ground.y)) * size / Vector2(view.size)
		var body_hit: bool = hotspot["kind"] in ["npc", "device", "chest"] and Rect2(foot - Vector2(33, 90), Vector2(66, 100)).has_point(point)
		if screen_point(hotspot).distance_to(point) < 40 or body_hit:
			hover_id = i
			break
	focus_fx.active = hover_id >= 0
	focus_fx.target = screen_point(world.hotspots[hover_id]) if hover_id >= 0 else point
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover_id >= 0 else Control.CURSOR_ARROW

func is_scene_point(point: Vector2) -> bool:
	return point.y > 145 and point.y < 635 and not Rect2(28, 177, 255, 182).has_point(point) and not Rect2(900, 480, 344, 150).has_point(point)

func mouse_to_world(point: Vector2) -> Vector2:
	var vp_point := point * Vector2(view.size) / size
	var origin := camera.project_ray_origin(vp_point)
	var direction := camera.project_ray_normal(vp_point)
	var hit: Variant = Plane(Vector3.UP, 0).intersects_ray(origin, direction)
	if hit == null or (first_person and direction.y >= -0.02):
		return position_2d
	var ground: Vector3 = hit
	var height: float = world.floor_height(Vector2(ground.x, ground.z))
	if height > 0:
		hit = Plane(Vector3.UP, height).intersects_ray(origin, direction)
		if hit != null:
			ground = hit
	return Vector2(ground.x, ground.z)

func _gui_input(event: InputEvent) -> void:
	if transition_busy or navigation.switching or map_open or dialogue != null or mission_panel != null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and is_scene_point(event.position):
		update_hover(event.position)
		focus_fx.flash = 1
		if hover_id >= 0:
			if position_2d.distance_to(world.hotspots[hover_id]["point"]) < 2.9:
				interact(hover_id)
			else:
				walk_to(world.hotspots[hover_id]["point"], hover_id)
		else:
			walk_to(mouse_to_world(event.position))
		accept_event()

func handle_key(event: InputEventKey) -> void:
	if transition_busy or navigation.switching:
		return
	match event.keycode:
		KEY_V:
			toggle_perspective()
		KEY_M:
			toggle_map()
		KEY_ESCAPE:
			back()
		KEY_F, KEY_E:
			if dialogue != null or mission_panel != null:
				close_panels()
			elif not map_open and nearest_id >= 0:
				interact(nearest_id)

func interact(id: int) -> void:
	if transition_busy or id < 0 or id >= world.hotspots.size():
		return
	var hotspot: Dictionary = world.hotspots[id]
	if position_2d.distance_to(hotspot["point"]) > 2.9:
		return
	path.clear()
	pending_id = -1
	focus_fx.flash = 1
	match hotspot["kind"]:
		"region":
			change_location(hotspot["region"])
		"exit":
			change_location(-1)
		"home":
			save_state()
			navigation.show_screen("hub")
		"npc":
			actor.set_locomotion(false, false)
			actor.play_wave()
			if location not in talked:
				talked.append(location)
			show_dialogue("岑伯", NOTES[location] + "\n先看看检修台，有需要的工具再去高台物资箱找。")
		"device":
			if location not in examined:
				examined.append(location)
			show_missions()
		"chest":
			if location not in collected:
				collected.append(location)
				show_dialogue("旅途物资 / 已收录", "找到一份旧水路图纸和修复记录。\n这段街区的物资已经收录到归城小记，返回时不会重复领取。")
	update_objective()
	save_state()

func change_location(index: int) -> void:
	if transition_busy:
		return
	if location < 0:
		city_return = position_2d
	transition_busy = true
	close_panels()
	focus_fx.active = false
	var tween := create_tween()
	tween.tween_property(focus_fx, "shutter", 1.0, 0.16)
	tween.tween_callback(func(): load_garden(index, city_return if index < 0 else Vector2(0, 6.8)))
	tween.tween_property(focus_fx, "shutter", 0.0, 0.25)
	tween.tween_callback(func(): transition_busy = false)

func save_state() -> void:
	get_tree().root.set_meta("garden_state", {"location": location, "point": position_2d, "city_return": city_return, "visited": visited.duplicate(), "examined": examined.duplicate(), "talked": talked.duplicate(), "collected": collected.duplicate()})

func back() -> void:
	_release_look()
	if dialogue != null or mission_panel != null:
		close_panels()
	elif map_open:
		toggle_map()
	elif location >= 0:
		change_location(-1)
	else:
		save_state()
		navigation.show_screen("hub")

func toggle_map() -> void:
	_release_look()
	if transition_busy:
		return
	close_panels()
	path.clear()
	pending_id = -1
	map_open = not map_open
	build_ui()

func close_panels() -> void:
	_release_look()
	for panel in [dialogue, mission_panel]:
		if is_instance_valid(panel):
			remove_child(panel)
			panel.queue_free()
	dialogue = null
	mission_panel = null
	if is_instance_valid(focus_fx):
		focus_fx.active = false

func show_dialogue(speaker: String, value: String) -> void:
	close_panels()
	dialogue = dark_panel(Vector2(66, 449), Vector2(1148, 185), self)
	dialogue.mouse_filter = Control.MOUSE_FILTER_STOP
	picture(DIALOGUE_ART, Vector2(943, 6), Vector2(123, 48), dialogue)
	make_label(speaker, Vector2(29, 18), Vector2(780, 34), 25, GOLD, dialogue)
	make_label(value, Vector2(29, 60), Vector2(1070, 80), 22, PAPER, dialogue)
	make_button("继续 / F", Vector2(935, 138), Vector2(181, 36), close_panels, dialogue)

func show_missions() -> void:
	close_panels()
	mission_panel = dark_panel(Vector2(346, 154), Vector2(670, 418), self)
	mission_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	make_label(NAMES[location] + " / 水路检修台", Vector2(25, 23), Vector2(616, 45), 28, GOLD, mission_panel)
	make_label(NOTES[location], Vector2(25, 73), Vector2(615, 75), 19, PAPER, mission_panel)
	var row := 0
	for level in TASKS[location]:
		var index := int(level)
		var title: String = task_levels[index]["title"] if index < 10 else Campaign.EXTRA_TITLES[index - 10]
		make_button("%02d  %s   %s" % [index + 1, title, "✓ 已修复" if index in completed else "→ 开始修复"], Vector2(25, 160 + row * 66), Vector2(616, 55), func(): launch_task(index), mission_panel)
		row += 1
	make_button("继续探索 / F", Vector2(425, 360), Vector2(215, 38), close_panels, mission_panel)

func launch_task(index: int) -> void:
	save_state()
	get_tree().root.set_meta("garden_return_region", location)
	navigation.game.enter_level(index)

func build_map() -> void:
	var panel := dark_panel(Vector2(56, 137), Vector2(1168, 479))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.draw.connect(func():
		for edge in [[0, 1], [1, 2], [0, 3], [1, 4], [2, 5], [3, 4], [4, 5], [4, 6], [5, 6]]:
			panel.draw_line(MAP_POS[edge[0]] - panel.position, MAP_POS[edge[1]] - panel.position, Color("71a99b"), 5, true)
	)
	make_label("百阶城 · 全域水路图", Vector2(30, 15), Vector2(920, 45), 31, GOLD, panel)
	make_label("所有场景都能返回这里。选中街区，沿途出发。", Vector2(31, 62), Vector2(1010, 34), 18, PAPER, panel)
	# Buttons overlay the drawn network; no list of rectangular scene thumbnails.
	for i in 7:
		var index := i
		var pos: Vector2 = MAP_POS[i] - Vector2(56, 137)
		if i in visited:
			picture(STAR, pos + Vector2(108, -11), Vector2(28, 28), panel)
		make_button(NAMES[i] + ("  ✓" if i in visited else ""), pos + Vector2(-86, -17), Vector2(184, 43), func(): map_open = false; change_location(index), panel)
	make_button("返回大地图", Vector2(911, 406), Vector2(219, 45), func(): map_open = false; change_location(-1), panel)
	picture(VOYAGE, Vector2(910, 279), Vector2(201, 76), panel)

func draw_markers() -> void:
	if not is_instance_valid(camera) or map_open or dialogue != null or mission_panel != null:
		return
	var font := get_theme_font("font")
	for i in world.hotspots.size():
		var hotspot: Dictionary = world.hotspots[i]
		if hotspot["kind"] == "chest" and location in collected:
			continue
		var point := screen_point(hotspot)
		if point.x < 10 or point.x > size.x - 10 or point.y < 147 or point.y > 610 or Rect2(28, 177, 255, 182).has_point(point):
			continue
		point.y += sin(time * 2.7 + i) * 2
		var hot: bool = i == nearest_id or i == hover_id
		var radius := 20.0 if hot else 15.0
		markers.draw_circle(point, radius, Color(0.035, 0.10, 0.13, 0.90))
		markers.draw_arc(point, radius, 0, TAU, 28, GOLD if hot else Color("d9e7df"), 2, true)
		var symbol := "…" if hotspot["kind"] == "npc" else ("!" if hotspot["kind"] in ["device", "chest"] else "↗")
		markers.draw_string(font, point + Vector2(-8, 7), symbol, HORIZONTAL_ALIGNMENT_CENTER, 20, 20, GOLD if hot else PAPER)
		markers.draw_colored_polygon(PackedVector2Array([point + Vector2(-4, radius + 3), point + Vector2(4, radius + 3), point + Vector2(0, radius + 9)]), GOLD if hot else PAPER)
		markers.draw_string_outline(font, point + Vector2(-100, 42), hotspot["label"], HORIZONTAL_ALIGNMENT_CENTER, 200, 16, 4, Color("1b343a"))
		markers.draw_string(font, point + Vector2(-100, 42), hotspot["label"], HORIZONTAL_ALIGNMENT_CENTER, 200, 16, PAPER)
	if path_index < path.size():
		for i in range(path_index, path.size(), 2):
			var point: Vector2 = path[i]
			var pos := camera.unproject_position(Vector3(point.x, world.floor_height(point) + 0.04, point.y)) * size / Vector2(view.size)
			if is_scene_point(pos):
				markers.draw_circle(pos, 3.2, GOLD)

func _draw() -> void:
	pass
