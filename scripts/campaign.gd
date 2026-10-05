extends RefCounted
## Shared campaign routing; presentation scenes keep their distinct simulations.
const FIRST_CHAPTER_COUNT := 10
const TOTAL := 13
const EXTRA_TITLES := ["先存后送", "双池供水", "自动补水"]

static func open_level(tree: SceneTree, index: int) -> void:
 tree.root.set_meta("campaign_level", clampi(index, 0, TOTAL - 1))
 tree.change_scene_to_file("res://lab.tscn" if index >= FIRST_CHAPTER_COUNT else "res://main.tscn")

static func take_level(tree: SceneTree, fallback: int) -> int:
 var index := int(tree.root.get_meta("campaign_level", fallback))
 tree.root.remove_meta("campaign_level")
 return index
