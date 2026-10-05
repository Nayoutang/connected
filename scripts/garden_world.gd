extends Node3D
## Small shared mesh vocabulary builds a connected city and seven walkable gardens.
const Dimensions := preload("res://scripts/world_dimensions.gd")
const CENTERS := [Vector2(-13, 9), Vector2(0, 9), Vector2(13, 9), Vector2(-13, -7), Vector2(0, -7), Vector2(13, -7), Vector2(0, -22)]
const NAMES := ["归城水口", "旧街管网", "蓄水高台", "钟楼水道", "屋顶温室", "无人苗圃", "两户灯火"]
var solids: Array[Rect2] = []
var hotspots: Array[Dictionary] = []
var region := -1
var materials := {}
var water_meshes: Array[MeshInstance3D] = []
var clock_hand: Node3D
var paving_material: ShaderMaterial
var occluders: Array[MeshInstance3D] = []
const STONE := Color("bcb6a0")
const WALL := Color("d0c3a5")
const ROOF := Color("344d53")
const WOOD := Color("74604b")
const GOLD := Color("dfb15f")
const WATER := Color("508e98")

func mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if materials.has(key):
		return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	materials[key] = material
	return material

func mesh_at(mesh: Mesh, pos: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat(color)
	node.position = pos
	parent.add_child(node)
	if parent == self and pos.y > 1.3 and (mesh is BoxMesh or mesh is CylinderMesh or mesh is SphereMesh):
		occluders.append(node)
		node.set_meta("opaque_material", node.material_override)
		var faded := (node.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		faded.albedo_color.a = 0.22
		node.set_meta("faded_material", faded)
	return node

func box(pos: Vector3, dimensions: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return mesh_at(mesh, pos, color, parent)

func cylinder(pos: Vector3, radius: float, height: float, color: Color, parent: Node3D = self, top_radius := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return mesh_at(mesh, pos, color, parent)

func sphere(pos: Vector3, radius: float, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh_at(mesh, pos, color, parent)

func model_at(kind: String, point: Vector2, height: float, size := 1.0) -> Node3D:
	var packed := load("res://assets/models/town/%s.tscn" % kind) as PackedScene
	var model := packed.instantiate() as Node3D
	add_child(model)
	var source := Dimensions.mesh_bounds(model)
	var factor := Dimensions.uniform_scale(kind, source) * size
	model.scale = Vector3.ONE * factor
	model.position = Vector3(point.x, height, point.y)
	model.set_meta("component_kind", kind)
	model.set_meta("designed_size", source.size * factor)
	if kind in Dimensions.SOLID_MODELS:
		block(Rect2(point + Vector2(source.position.x, source.position.z) * factor, Vector2(source.size.x, source.size.z) * factor))
	# Register every model part for the existing player occlusion fade.
	for child in model.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			var material := child.get_active_material(0) as StandardMaterial3D
			if material != null and material.albedo_color.a >= 0.99:
				occluders.append(child)
				child.set_meta("opaque_material", material)
				var faded := material.duplicate() as StandardMaterial3D
				faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				faded.albedo_color.a = 0.22
				child.set_meta("faded_material", faded)
	return model

func block(rect: Rect2) -> void:
	solids.append(rect.grow(Dimensions.PLAYER_RADIUS))

func add_hotspot(kind: String, label: String, point: Vector2, index := -1, height := 0.0) -> void:
	hotspots.append({"kind": kind, "label": label, "point": point, "region": index, "height": height})

func build(index: int) -> void:
	region = index
	if index < 0:
		build_city()
	else:
		build_garden(index)

func paving(center: Vector2, dimensions: Vector2, height := 0.0) -> void:
	if paving_material == null:
		paving_material = ShaderMaterial.new()
		paving_material.shader = preload("res://assets/materials/stone_floor.gdshader")
	var floor_node := box(Vector3(center.x, height - 0.12, center.y), Vector3(dimensions.x, 0.24, dimensions.y), STONE)
	floor_node.name = "StonePaving"
	floor_node.material_override = paving_material

func water(center: Vector2, dimensions: Vector2, height := -0.16) -> void:
	var node := box(Vector3(center.x, height, center.y), Vector3(dimensions.x, 0.08, dimensions.y), WATER)
	water_meshes.append(node)
	for i in 3:
		box(Vector3(center.x - dimensions.x * 0.27 + i * dimensions.x * 0.27, height + 0.045, center.y), Vector3(dimensions.x * 0.11, 0.02, dimensions.y * 0.6), Color("7ab9bd"))

func railing(center: Vector2, width: float, height := 0.0) -> void:
	for i in range(int(width / 1.5) + 1):
		box(Vector3(center.x - width / 2 + i * 1.5, height + 0.5, center.y), Vector3(0.1, 1, 0.1), ROOF)
	box(Vector3(center.x, height + 0.94, center.y), Vector3(width, 0.1, 0.1), ROOF)
	box(Vector3(center.x, height + 0.34, center.y), Vector3(width, 0.07, 0.07), ROOF)

func tree(point: Vector2, height := 0.0, autumn := false) -> void:
	var original_children := get_children()
	cylinder(Vector3(point.x, height + 1, point.y), 0.15, 2, WOOD)
	var leaf := Color("b89b57") if autumn else Color("739478")
	for offset in [Vector3(-0.62, 2.7, 0), Vector3(0.6, 2.9, 0.25), Vector3(0, 3.35, -0.15)]:
		var canopy := sphere(Vector3(point.x, height, point.y) + offset, 1.0, leaf)
		canopy.scale.y = 0.8
	var group := Node3D.new()
	group.name = "Tree"
	add_child(group)
	group.position = Vector3(point.x, height, point.y)
	for child in get_children():
		if child != group and child not in original_children and child is Node3D:
			child.reparent(group, true)
	group.scale = Vector3.ONE * (5.5 / 4.15)
	block(Rect2(point - Vector2(0.3, 0.3), Vector2(0.6, 0.6)))

func planter(point: Vector2, height := 0.0, _flower := false) -> void:
	model_at("planter", point, height)

func lamp(point: Vector2, height := 0.0) -> void:
	model_at("lamp", point, height)

func house(point: Vector2, height := 0.0) -> void:
	model_at("house", point, height)

func bench(point: Vector2, height := 0.0) -> void:
	model_at("bench", point, height)

func tank(point: Vector2, height := 0.0, large := false) -> void:
	model_at("reservoir", point, height, 4.8 / 3.3 if large else 1.0)

func landmark(index: int, center: Vector2, height := 0.0) -> void:
	match index:
		0:
			var gate := model_at("gate", center, height)
			var gate_scale := gate.scale.x
			water(center + Vector2(0, -2), Vector2(3.5, 1.2), height + 0.2)
			block(Rect2(center + Vector2(-3.3, -0.5) * gate_scale, Vector2.ONE * gate_scale))
			block(Rect2(center + Vector2(2.3, -0.5) * gate_scale, Vector2.ONE * gate_scale))
		1:
			var offsets := [Vector2.ZERO] if region < 0 else [Vector2(-4.8, 0), Vector2(4.8, 0)]
			for offset in offsets:
				model_at("shop", center + offset, height)
		2:
			tank(center, height, true)
			tank(center + Vector2(3.4, 0.4), height)
		3:
			model_at("clocktower", center, height)
		4:
			model_at("greenhouse", center, height)
		5:
			model_at("shed", center + Vector2(0, -1.2), height)
			for x in [-2.8, 0, 2.8]:
				planter(center + Vector2(x, 1.8), height, true)
		6:
			var offsets := [Vector2.ZERO] if region < 0 else [Vector2(-4.8, 0), Vector2(4.8, 0)]
			for offset in offsets:
				house(center + offset, height)

func build_city() -> void:
	box(Vector3(0, -0.55, -7), Vector3(47, 1.0, 51), Color("84917b"))
	water(Vector2(0, 0.2), Vector2(47, 4), 0.015)
	# Water blocks movement except at three broad bridges.
	for rect in [Rect2(-23.5, -1.8, 8.5, 4), Rect2(-11, -1.8, 9, 4), Rect2(2, -1.8, 9, 4), Rect2(15, -1.8, 8.5, 4)]:
		block(rect)
	for z in [9.0, -7.0, -22.0]:
		paving(Vector2(0, z), Vector2(39 if z > -20 else 16, Dimensions.STREET_WIDTH))
	for x in [-13.0, 0.0, 13.0]:
		paving(Vector2(x, 1), Vector2(Dimensions.STREET_WIDTH, 18))
		paving(Vector2(x, 0.2), Vector2(4.1, 4.4), 0.10)
		rail_along_bridge(x)
	paving(Vector2(0, -15), Vector2(Dimensions.STREET_WIDTH, 17))
	for i in 7:
		var c: Vector2 = CENTERS[i]
		paving(c + Vector2(0, -1.0), Vector2(12, 12))
		landmark(i, c + Vector2(0, -4.5))
		add_hotspot("region", NAMES[i], c + Vector2(0, 1), i)
		tree(c + Vector2(-4.8, -3.4), 0, i % 2 == 0)
		lamp(c + Vector2(4.5, 2.1))
		planter(c + Vector2(-4.4, 2.4), 0, i in [4, 5])
		bench(c + Vector2(4.0, -1.1))
	# Town silhouette on the rim, never blocking the main promenade.
	for x in [-20.0, -6.5, 6.5, 20.0]:
		house(Vector2(x, -18.5))
		tree(Vector2(x, 14.6), 0, true)
	add_hotspot("home", "修复事务所", Vector2(-18, 12), -1)
	house(Vector2(-19.5, 9))

func rail_along_bridge(x: float) -> void:
	model_at("bridge", Vector2(x, 0.2), 0.0)

func build_garden(index: int) -> void:
	box(Vector3(0, -0.55, -3), Vector3(32, 1.0, 27), Color("7c8c77"))
	paving(Vector2(0, 1.4), Vector2(30, 17))
	# A raised back garden is accessible only through the central stairs.
	box(Vector3(0, 0.67, -8.25), Vector3(30, 1.35, 13.5), Color("9b977f"))
	paving(Vector2(0, -8.25), Vector2(30, 13.5), Dimensions.TERRACE_HEIGHT)
	model_at("stairs", Vector2(0, 0.25), 0.0)
	block(Rect2(-15, -1.65, 13.1, 0.8))
	block(Rect2(1.9, -1.65, 13.1, 0.8))
	railing(Vector2(-8.45, -1.35), 13.1, 1.5)
	railing(Vector2(8.45, -1.35), 13.1, 1.5)
	landmark(index, Vector2(0, -8.5), Dimensions.TERRACE_HEIGHT)
	for side in [-1, 1]:
		tree(Vector2(side * 12.3, -9.8), 1.5, index in [1, 3, 6])
		tree(Vector2(side * 12.4, 5.6), 0, index in [1, 6])
		planter(Vector2(side * 4.5, 0.4), 0, true)
		lamp(Vector2(side * 7.1, -2.6), 1.5)
	bench(Vector2(-7, 2.5))
	water(Vector2(7.5, 3.2), Vector2(3.2, 2.6), 0.10)
	block(Rect2(5.9, 1.9, 3.2, 2.6))
	block(Rect2(-4.55, 2.65, 0.7, 0.7))
	add_hotspot("npc", "岑伯", Vector2(-4.2, 3.0), index)
	add_hotspot("device", "水路检修台", Vector2(3.6, 3.0), index)
	add_hotspot("chest", "旅途物资箱", Vector2(-7.0, -3.7), index, 1.5)
	add_hotspot("exit", "返回百阶城大地图", Vector2(0, 9.1), -1)
	var neighbors: Array = [[1, 3], [0, 2, 4], [1, 5], [0, 4], [1, 3, 5, 6], [2, 4, 6], [4, 5]][index]
	for i in neighbors.size():
		var target: int = neighbors[i]
		add_hotspot("region", "前往" + NAMES[target], Vector2(-9.8 if i % 2 == 0 else 9.8, 7.3 - (i / 2) * 2.5), target)
		box(Vector3(-10.9 if i % 2 == 0 else 10.9, 0.65, 7.3 - (i / 2) * 2.5), Vector3(0.16, 1.3, 0.16), WOOD)
		box(Vector3(-10.9 if i % 2 == 0 else 10.9, 1.5, 7.3 - (i / 2) * 2.5), Vector3(1.7, 0.7, 0.15), GOLD)
	block(Rect2(2.8, 2.45, 1.6, 1.1))
	block(Rect2(-7.525, -4.1, 1.05, 0.8))
	box(Vector3(3.6, 0.6, 3.0), Vector3(1.6, 1.2, 1.1), WOOD)
	box(Vector3(3.6, 1.28, 3.0), Vector3(1.85, 0.15, 1.3), GOLD)
	tank(Vector2(5.1, 5.4))
	box(Vector3(-7, 1.85, -3.7), Vector3(1.05, 0.7, 0.8), GOLD)
	box(Vector3(-7, 2.24, -3.7), Vector3(1.12, 0.12, 0.88), WOOD)

func floor_height(point: Vector2) -> float:
	if region < 0:
		return 0.10 if absf(point.y - 0.2) < 2.2 and minf(absf(point.x), minf(absf(point.x - 13), absf(point.x + 13))) < 2.05 else 0.0
	if point.y <= -1.5:
		return 1.5
	if point.y < 2 and absf(point.x) < 1.8:
		return clampf((2 - point.y) / 3.5, 0, 1) * 1.5
	return 0

func walkable(point: Vector2) -> bool:
	var bounds := Dimensions.CITY_BOUNDS if region < 0 else Dimensions.GARDEN_BOUNDS
	if not bounds.has_point(point):
		return false
	for rect in solids:
		if rect.has_point(point):
			return false
	return true

func make_actor(point: Vector2, elder := false) -> Node3D:
	if not elder:
		var hero := preload("res://scenes/characters/adventure_character.tscn").instantiate() as Node3D
		add_child(hero)
		hero.position = Vector3(point.x, floor_height(point), point.y)
		return hero
	var actor := Node3D.new()
	add_child(actor)
	actor.position = Vector3(point.x, floor_height(point), point.y)
	actor.scale = Vector3.ONE * (Dimensions.NPC_HEIGHT / 2.2898)
	var skin := Color("f2ceb1")
	var hair := Color("c5c6b5") if elder else Color("283e49")
	var coat := Color("76886e") if elder else Color("375365")
	cylinder(Vector3(0, 0.85, 0), 0.33, 0.8, coat, actor, 0.27)
	var head := sphere(Vector3(0, 1.66, 0), 0.51, skin, actor)
	head.scale = Vector3(1, 1.04, 0.92)
	var cap := sphere(Vector3(0, 1.94, -0.065), 0.53, hair, actor)
	cap.scale = Vector3(1, 0.66, 1)
	for side in [-1, 1]:
		sphere(Vector3(side * 0.19, 1.67, 0.44), 0.063, Color("28313a"), actor)
		sphere(Vector3(side * 0.20, 1.70, 0.48), 0.019, Color("fff1d2"), actor)
		var leg := box(Vector3(side * 0.16, 0.25, 0), Vector3(0.20, 0.5, 0.23), Color("2b3a43"), actor)
		leg.name = "LegLeft" if side < 0 else "LegRight"
		box(Vector3(side * 0.16, 0.09, 0.13), Vector3(0.24, 0.18, 0.38), WOOD, actor)
		var arm := cylinder(Vector3(side * 0.37, 0.93, 0), 0.09, 0.57, coat, actor)
		arm.rotation.z = side * 0.13
		arm.name = "ArmLeft" if side < 0 else "ArmRight"
		sphere(Vector3(side * 0.41, 0.64, 0), 0.10, skin, actor)
	if elder:
		var beard := sphere(Vector3(0, 1.40, 0.36), 0.25, hair, actor)
		beard.scale.y = 0.5
		for side in [-1, 1]:
			var glasses := cylinder(Vector3(side * 0.19, 1.69, 0.50), 0.13, 0.04, GOLD, actor)
			glasses.rotation_degrees.x = 90
	else:
		cylinder(Vector3(0, 1.27, 0), 0.37, 0.16, GOLD, actor)
		box(Vector3(0.24, 1.08, 0.35), Vector3(0.20, 0.45, 0.1), GOLD, actor)
		for side in [-1, 1]:
			var goggles := cylinder(Vector3(side * 0.20, 2.08, 0.30), 0.16, 0.09, GOLD, actor)
			goggles.rotation_degrees.x = 65
			var glass := cylinder(Vector3(side * 0.20, 2.12, 0.34), 0.115, 0.08, Color("92b9c0"), actor)
			glass.rotation_degrees.x = 65
		box(Vector3(0, 0.85, -0.35), Vector3(0.55, 0.55, 0.22), WOOD, actor)
	return actor

func fade_occluders(player: Vector3, viewpoint: Vector3) -> void:
	for node in occluders:
		var inverse := node.global_transform.affine_inverse()
		var intersection: Variant = node.get_aabb().intersects_segment(inverse * player, inverse * viewpoint)
		var hidden := intersection != null
		node.material_override = node.get_meta("faded_material" if hidden else "opaque_material")
