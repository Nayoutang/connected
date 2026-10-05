extends RefCounted
## Design dimensions in metres: one Godot world unit represents one metre.
const HERO_HEIGHT := 1.65
const EYE_HEIGHT := 1.52
const NPC_HEIGHT := 1.70
const PLAYER_RADIUS := 0.33
const HOUSE_WIDTH := 7.2
const SHOP_WIDTH := 6.4
const STREET_WIDTH := 4.0
const TERRACE_HEIGHT := 1.5
const STAIR_RISE := 0.15
const STAIR_TREAD := 0.35
const CITY_BOUNDS := Rect2(-23, -32, 46, 49)
const GARDEN_BOUNDS := Rect2(-14.65, -14.65, 29.3, 24.4)
const WIDTHS := {"house": HOUSE_WIDTH, "shop": SHOP_WIDTH, "bench": 1.6, "planter": 1.5}
const HEIGHTS := {"clocktower": 9.0, "greenhouse": 4.8, "shed": 4.4, "gate": 6.2, "lamp": 3.4, "reservoir": 3.3}
const SOLID_MODELS := ["house", "shop", "clocktower", "greenhouse", "shed", "reservoir", "bench", "planter", "lamp"]

static func mesh_bounds(node: Node, transform := Transform3D.IDENTITY) -> AABB:
	var result := AABB()
	if node is Node3D:
		transform = transform * node.transform
	if node is MeshInstance3D:
		result = transform * node.get_aabb()
	for child in node.get_children():
		var box := mesh_bounds(child, transform)
		if box.size != Vector3.ZERO:
			result = box if result.size == Vector3.ZERO else result.merge(box)
	return result

static func uniform_scale(kind: String, bounds: AABB) -> float:
	if WIDTHS.has(kind):
		return float(WIDTHS[kind]) / maxf(bounds.size.x, 0.001)
	if HEIGHTS.has(kind):
		return float(HEIGHTS[kind]) / maxf(bounds.size.y, 0.001)
	return 1.0 # Preserve the already calibrated stair and bridge geometry.
