extends RefCounted
## Real reusable mesh models, constructed from the generated reference silhouettes.
const WALL = Color("d0c3a5")
const STONE = Color("bcb6a0")
const TEAL = Color("344d53")
const WOOD = Color("74604b")
const GOLD = Color("dfb15f")
var root: Node3D
var palette := {}

func material(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if palette.has(key):
		return palette[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.82
	if c.a < 1:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	palette[key] = m
	return m

func part(mesh: Mesh, p: Vector3, c: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = p
	n.material_override = material(c)
	root.add_child(n)
	n.owner = root
	return n

func box(p: Vector3, s: Vector3, c: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = s
	return part(m, p, c)

func cyl(p: Vector3, r: float, h: float, c: Color, top := -1.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = r
	m.top_radius = r if top < 0 else top
	m.height = h
	m.radial_segments = 20
	return part(m, p, c)

func ball(p: Vector3, r: float, c: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2
	m.radial_segments = 12
	m.rings = 6
	return part(m, p, c)

func beam(a: Vector3, b: Vector3, thickness: float, c: Color) -> void:
	var n := cyl((a + b) / 2, thickness, a.distance_to(b), c)
	n.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func roof(w: float, d: float, y: float) -> void:
	# Overlapping rows of individual curved roof tiles, with lifted outer eaves.
	for side in [-1, 1]:
		var panel := box(Vector3(0, y + 0.39, side * d / 4), Vector3(w + 0.5, 0.13, d * 0.58), TEAL)
		panel.rotation.x = side * 0.40
		for row in 5:
			var z: float = side * (0.13 + row * (d / 2 + 0.28) / 5)
			var yy: float = y + 0.8 - absf(z) * 0.42 + (0.10 if row == 4 else 0)
			for i in range(int((w + 0.5) / 0.28)):
				var tile := cyl(Vector3(-w / 2 - 0.1 + i * 0.28, yy, z), 0.14, d / 10 + 0.18, TEAL.lightened(0.06 if i % 3 == 0 else 0))
				tile.rotation.x = PI / 2 + side * 0.40
	beam(Vector3(-w / 2 - 0.2, y + 0.88, 0), Vector3(w / 2 + 0.2, y + 0.88, 0), 0.12, GOLD)
	for side in [-1, 1]:
		ball(Vector3(side * (w / 2 + 0.3), y + 1.03, 0), 0.13, GOLD)

func window(p: Vector3, w := 0.7, h := 0.85) -> void:
	box(p, Vector3(w, h, 0.08), WOOD)
	box(p + Vector3(0, 0, 0.05), Vector3(w - 0.12, h - 0.12, 0.04), GOLD.darkened(0.15))
	for i in 4:
		box(p + Vector3(-w * 0.35 + i * w * 0.23, 0, 0.08), Vector3(0.035, h - 0.08, 0.04), WOOD)
	for yy in [-0.25, 0.0, 0.25]:
		box(p + Vector3(0, yy * h, 0.09), Vector3(w, 0.035, 0.04), WOOD)

func building(kind: String) -> void:
	var tall := kind == "house"
	var w := 3.7
	var h := 3.8 if tall else 2.6
	box(Vector3(0, 0.15, 0), Vector3(w + 0.12, 0.3, 3.3), STONE)
	box(Vector3(0, h / 2 + 0.3, 0), Vector3(w, h, 3.2), WALL)
	for x in [-1.78, 0.0, 1.78]:
		box(Vector3(x, h / 2 + 0.3, 1.64), Vector3(0.13, h, 0.13), WOOD)
	for y in [0.55, 2.4, h + 0.2]:
		box(Vector3(0, y, 1.66), Vector3(w, 0.12, 0.12), WOOD)
	box(Vector3(0, 1.18, 1.66), Vector3(0.85, 1.8, 0.09), WOOD)
	for x in [-0.22, 0.22]:
		ball(Vector3(x, 1.18, 1.75), 0.05, GOLD)
	for x in [-1.17, 1.17]:
		window(Vector3(x, 1.65, 1.7))
		if tall:
			window(Vector3(x, 3.35, 1.7), 0.85, 0.95)
	for x in [-1.78, 1.78]:
		for z in [-1.4, 0, 1.4]:
			box(Vector3(x, h / 2 + 0.3, z), Vector3(0.16, h, 0.16), WOOD)
	roof(w, 3.2, h + 0.18)
	for i in 3:
		box(Vector3(0, 0.05 + i * 0.09, 2.03 - i * 0.16), Vector3(1.4, 0.1, 0.5), STONE)
	if tall:
		box(Vector3(0, 2.68, 1.95), Vector3(3.1, 0.13, 0.68), WOOD)
		rail(Vector3(-1.5, 2.7, 2.25), Vector3(1.5, 2.7, 2.25), 0.55)
	if kind == "shop":
		var awning := box(Vector3(0, 2.2, 2.05), Vector3(3.7, 0.10, 1.0), Color("af795d"))
		awning.rotation.x = 0.18
		box(Vector3(0, 2.0, 2.53), Vector3(3.7, 0.22, 0.06), Color("af795d"))
		box(Vector3(0, 2.85, 1.72), Vector3(1.3, 0.38, 0.12), WOOD)
	if kind == "shed":
		beam(Vector3(1.9, 0.25, 0.5), Vector3(1.9, 0.9, 0.5), 0.05, TEAL)
		beam(Vector3(1.9, 0.9, 0.5), Vector3(2.13, 0.9, 0.5), 0.06, GOLD)

func rail(a: Vector3, b: Vector3, h := 0.85) -> void:
	for i in 9:
		var p := a.lerp(b, i / 8.0)
		beam(p, p + Vector3.UP * h, 0.035, TEAL)
		if i % 4 == 0:
			ball(p + Vector3.UP * (h + 0.05), 0.09, GOLD)
	beam(a + Vector3.UP * h, b + Vector3.UP * h, 0.065, TEAL)
	beam(a + Vector3.UP * h * 0.3, b + Vector3.UP * h * 0.3, 0.045, TEAL)

func stairs() -> void:
	for i in 10:
		var y := (i + 1) * 0.15
		box(Vector3(0, y / 2, 1.75 - i * 0.35), Vector3(3.3, y, 0.355), STONE)
		box(Vector3(0, y - 0.025, 1.79 - i * 0.35), Vector3(3.32, 0.05, 0.36), WALL)
	for x in [-1.7, 1.7]:
		for i in 10:
			box(Vector3(x, (i + 1) * 0.075, 1.75 - i * 0.35), Vector3(0.2, (i + 1) * 0.15, 0.36), STONE)
		rail(Vector3(x, 0.15, 1.75), Vector3(x, 1.5, -1.4))
		for z in [1.75, -1.4]:
			var y := 0.15 if z > 0 else 1.5
			box(Vector3(x, y + 0.45, z), Vector3(0.3, 0.9, 0.3), WALL)
			ball(Vector3(x, y + 0.98, z), 0.1, GOLD)

func reservoir() -> void:
	box(Vector3(0, 0.15, 0), Vector3(2.1, 0.3, 2.1), STONE)
	for x in [-0.7, 0.7]:
		for z in [-0.7, 0.7]:
			box(Vector3(x, 0.5, z), Vector3(0.27, 0.7, 0.27), STONE)
	cyl(Vector3(0, 1.8, 0), 0.95, 2.2, Color("648a88"))
	var lid := ball(Vector3(0, 2.9, 0), 0.96, TEAL)
	lid.scale.y = 0.30
	for y in [0.8, 1.3, 2.5, 2.85]:
		cyl(Vector3(0, y, 0), 0.98, 0.08, GOLD)
	for i in 16:
		var a := i * TAU / 16
		for y in [0.8, 2.5]:
			ball(Vector3(sin(a) * 0.99, y, cos(a) * 0.99), 0.04, GOLD)
	box(Vector3(0, 1.8, 0.99), Vector3(0.22, 1.55, 0.08), GOLD)
	box(Vector3(0, 1.8, 1.04), Vector3(0.12, 1.4, 0.04), Color("80bdc6"))
	for x in [0.42, 0.73]:
		beam(Vector3(x, 0.2, 0.99), Vector3(x, 3.0, 0.99), 0.03, TEAL)
	for i in 11:
		beam(Vector3(0.42, 0.3 + i * 0.25, 1.0), Vector3(0.73, 0.3 + i * 0.25, 1.0), 0.025, GOLD)
	beam(Vector3(-0.9, 1.0, 0), Vector3(-1.3, 1.0, 0), 0.12, TEAL)

func clocktower() -> void:
	box(Vector3(0, 0.2, 0), Vector3(2.9, 0.4, 2.9), STONE)
	box(Vector3(0, 2.2, 0), Vector3(2.7, 4, 2.7), WALL)
	for y in range(1, 9):
		box(Vector3(0, y * 0.45, 1.36), Vector3(2.7, 0.025, 0.025), STONE.darkened(0.16))
	box(Vector3(0, 0.95, 1.39), Vector3(0.65, 1.45, 0.10), WOOD)
	for x in [-1.18, 1.18]:
		for z in [-1.18, 1.18]:
			box(Vector3(x, 4.6, z), Vector3(0.18, 1.3, 0.18), WOOD)
	cyl(Vector3(0, 4.63, 0), 0.43, 0.48, GOLD, 0.22)
	ball(Vector3(0, 4.29, 0), 0.08, GOLD)
	roof(2.8, 2.8, 5.25)
	for side in 2:
		var face := cyl(Vector3(0, 3.25, 1.4) if side == 0 else Vector3(1.4, 3.25, 0), 0.75, 0.10, GOLD)
		face.rotation.x = PI / 2
		if side == 1:
			face.rotation = Vector3(0, 0, PI / 2)
		var disk := cyl(Vector3(0, 3.25, 1.47) if side == 0 else Vector3(1.47, 3.25, 0), 0.66, 0.04, Color("f2e4c5"))
		disk.rotation = face.rotation
	for i in 12:
		var a := i * TAU / 12
		box(Vector3(sin(a) * 0.55, 3.25 + cos(a) * 0.55, 1.51), Vector3(0.05, 0.07, 0.03), TEAL)
	box(Vector3(0, 3.43, 1.54), Vector3(0.045, 0.4, 0.04), TEAL)
	box(Vector3(0.14, 3.25, 1.54), Vector3(0.32, 0.045, 0.04), TEAL)

func greenhouse() -> void:
	box(Vector3(0, 0.3, 0), Vector3(5.4, 0.6, 3.4), STONE)
	var glass := Color(0.55, 0.76, 0.77, 0.30)
	for z in [-1.7, 1.7]:
		box(Vector3(0, 1.8, z), Vector3(5.3, 2.4, 0.035), glass)
		for x in [-2.7, -1.35, 0, 1.35, 2.7]:
			box(Vector3(x, 1.8, z), Vector3(0.09, 2.5, 0.09), TEAL)
		for y in [0.6, 1.8, 3.0]:
			box(Vector3(0, y, z), Vector3(5.5, 0.09, 0.09), TEAL)
	for x in [-2.7, 2.7]:
		box(Vector3(x, 1.8, 0), Vector3(0.035, 2.4, 3.4), glass)
	for side in [-1, 1]:
		var panel := box(Vector3(0, 3.45, side * 0.85), Vector3(5.4, 0.035, 1.92), glass)
		panel.rotation.x = side * 0.487
		for x in [-2.7, -1.35, 0, 1.35, 2.7]:
			beam(Vector3(x, 3, side * 1.7), Vector3(x, 3.9, 0), 0.05, TEAL)
	beam(Vector3(-2.7, 3.9, 0), Vector3(2.7, 3.9, 0), 0.06, GOLD)
	window(Vector3(0, 1.5, 1.77), 1.0, 1.8)
	for x in [-1.8, 1.8]:
		for z in [-0.8, 0.6]:
			box(Vector3(x, 0.7, z), Vector3(0.65, 0.35, 0.65), WOOD)
			ball(Vector3(x, 1.1, z), 0.38, Color("739478"))

func gate() -> void:
	for x in [-2.8, 2.8]:
		box(Vector3(x, 0.2, 0), Vector3(1, 0.4, 1), STONE)
		box(Vector3(x, 1.9, 0), Vector3(0.7, 3.4, 0.7), WALL)
		box(Vector3(x, 3.2, 0), Vector3(0.9, 0.4, 0.9), WOOD)
	box(Vector3(0, 3.5, 0), Vector3(6.3, 0.5, 1.0), WOOD)
	box(Vector3(0, 3.5, 0.52), Vector3(4.7, 0.32, 0.08), STONE)
	roof(6.3, 1.5, 3.8)
	var crest := ball(Vector3(0, 4.9, 0.25), 0.25, GOLD)
	crest.scale.y = 1.5

func bench() -> void:
	for i in 4:
		box(Vector3(0, 0.53, -0.25 + i * 0.17), Vector3(2, 0.09, 0.13), WOOD)
	for i in 3:
		box(Vector3(0, 0.82 + i * 0.18, -0.36), Vector3(2, 0.13, 0.08), WOOD)
	for x in [-0.8, 0.8]:
		for z in [-0.28, 0.28]:
			beam(Vector3(x, 0.04, z), Vector3(x, 0.6, z * 0.6), 0.055, TEAL)
		beam(Vector3(x, 0.82, -0.35), Vector3(x, 0.82, 0.33), 0.055, TEAL)
		beam(Vector3(x, 0.5, 0.3), Vector3(x, 0.82, 0.3), 0.045, TEAL)

func planter() -> void:
	box(Vector3(0, 0.3, 0), Vector3(1.45, 0.6, 1.1), STONE)
	box(Vector3(0, 0.61, 0), Vector3(1.2, 0.04, 0.86), Color("524e40"))
	for z in [-0.5, 0.5]:
		box(Vector3(0, 0.65, z), Vector3(1.5, 0.10, 0.12), WALL)
	for x in [-0.68, 0.68]:
		box(Vector3(x, 0.65, 0), Vector3(0.12, 0.10, 1.1), WALL)
	for i in 5:
		var x := -0.48 + i * 0.24
		var y := 0.95 + (i % 2) * 0.15
		beam(Vector3(x, 0.65, 0), Vector3(x, y, 0), 0.025, Color("6c8c62"))
		for side in [-1, 1]:
			var leaf := ball(Vector3(x + side * 0.09, y - 0.15, 0), 0.14, Color("739478"))
			leaf.scale = Vector3(1, 0.4, 0.65)
		for petal in 5:
			var a := petal * TAU / 5
			ball(Vector3(x + sin(a) * 0.07, y, cos(a) * 0.07), 0.075, Color("dda5a3"))
		ball(Vector3(x, y + 0.035, 0), 0.045, GOLD)

func lamp() -> void:
	cyl(Vector3(0, 0.12, 0), 0.25, 0.24, TEAL)
	cyl(Vector3(0, 1.6, 0), 0.07, 3.2, TEAL)
	beam(Vector3(0, 3.2, 0), Vector3(0.65, 3.2, 0), 0.06, TEAL)
	beam(Vector3(0.65, 3.2, 0), Vector3(0.65, 2.95, 0), 0.035, GOLD)
	box(Vector3(0.65, 2.64, 0), Vector3(0.44, 0.55, 0.44), GOLD)
	for x in [-0.22, 0.22]:
		for z in [-0.22, 0.22]:
			box(Vector3(0.65 + x, 2.64, z), Vector3(0.04, 0.6, 0.04), TEAL)
	cyl(Vector3(0.65, 3.0, 0), 0.43, 0.25, TEAL, 0.09)
	ball(Vector3(0.65, 3.16, 0), 0.07, GOLD)

func bridge() -> void:
	# Flat walking surface matches the game's river height; the arch is below the deck.
	box(Vector3(0, 0.02, 0), Vector3(3.7, 0.16, 4.4), STONE)
	for x in [-1.8, 1.8]:
		for i in 12:
			var z := -2.02 + i * 0.367
			var drop := 0.15 + 0.55 * pow(absf(z) / 2.2, 2)
			box(Vector3(x, -drop / 2, z), Vector3(0.26, drop, 0.36), WALL)
		rail(Vector3(x, 0.1, -2.15), Vector3(x, 0.1, 2.15), 1.0)
		for z in [-2.15, 2.15]:
			box(Vector3(x, 0.55, z), Vector3(0.33, 1.1, 0.33), STONE)
			ball(Vector3(x, 1.18, z), 0.11, GOLD)

func create(kind: String) -> Node3D:
	root = Node3D.new()
	root.name = kind.to_pascal_case()
	root.set_meta("reference_image", "res://assets/generated-town/%s.png" % kind)
	match kind:
		"house", "shop", "shed": building(kind)
		"clocktower": clocktower()
		"reservoir": reservoir()
		"greenhouse": greenhouse()
		"gate": gate()
		"stairs": stairs()
		"bridge": bridge()
		"bench": bench()
		"planter": planter()
		"lamp": lamp()
	return root
