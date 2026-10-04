extends Node2D
## One shared backdrop; bounded procedural particles without per-frame nodes.
const CITY = preload("res://assets/story/baijie.png")
const LESSON_REGIONS = ["gate", "old_street", "reservoir", "clocktower", "greenhouse", "nursery", "old_street", "households", "reservoir", "nursery"]
const LAB_REGIONS = ["greenhouse", "households", "nursery"]
var current_texture: Texture2D = CITY
var region := "baijie"

func set_region(lab: bool, index: int) -> void:
	var regions: Array = LAB_REGIONS if lab else LESSON_REGIONS
	var next_region: String = regions[clampi(index, 0, regions.size() - 1)]
	if next_region == region:
		return
	region = next_region
	current_texture = load("res://assets/story/regions/%s.png" % region)
	pulse = 0.0
	queue_redraw()

var time := 0.0
var pulse := 0.0

func _ready() -> void:
	z_index = -10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func celebrate() -> void:
	pulse = 1.0

func _process(delta: float) -> void:
	time += delta
	pulse = maxf(0.0, pulse - delta * 0.32)
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(current_texture, Rect2(0, 0, 1280, 720), false)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.025, 0.055, 0.09, 0.35))
	for i in 28:
		var p := Vector2(fposmod(i * 173.0 + time * (3 + i % 4), 1280), fposmod(i * 79.0 - time * (5 + i % 3), 720))
		draw_rect(Rect2(p, Vector2(2, 2)), Color(0.8, 0.93, 0.75, 0.2 + 0.18 * sin(time + i)))
	if pulse > 0:
		for i in 3:
			draw_arc(Vector2(640, 380), (1.0 - pulse) * 650 + i * 45, 0, TAU, 96, Color(0.35, 0.9, 1.0, pulse * 0.5), 3)
