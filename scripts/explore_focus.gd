extends Control
## Mouse-only visual feedback; never intercepts a hotspot click.
var target := Vector2.ZERO
var active := false
var amount := 0.0
var flash := 0.0
var shutter := 0.0
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	elapsed += delta
	amount = move_toward(amount, 1.0 if active else 0.0, delta * 7)
	flash = maxf(0, flash - delta * 2.5)
	queue_redraw()

func _draw() -> void:
	if amount > 0.01:
		var radius := lerpf(58, 29, amount) + flash * 17
		var color := Color("f4d992")
		color.a = amount
		for i in 6:
			var angle := i * TAU / 6.0 + (1 - amount) * 0.5
			var a := Vector2.from_angle(angle)
			var b := Vector2.from_angle(angle + 0.42)
			draw_colored_polygon(PackedVector2Array([target + a * radius, target + a * (radius + 11), target + b * (radius + 8), target + b * (radius + 1)]), color)
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				var corner := target + Vector2(sx, sy) * (radius + 16)
				draw_polyline(PackedVector2Array([corner - Vector2(sx * 12, 0), corner, corner - Vector2(0, sy * 12)]), color, 2, true)
		draw_circle(target, 2.2, color)
		draw_arc(target, radius + 22, -PI / 2, -PI / 2 + amount * TAU, 48, Color(0.5, 0.87, 0.88, amount * 0.5), 1, true)
	if shutter > 0:
		# Two offset banks of shutter leaves close over the whole scene.
		for i in 8:
			var width := size.x / 8.0
			var depth := size.y * 0.54 * shutter
			draw_rect(Rect2(i * width, 0, width + 1, depth + (i % 2) * 18 * shutter), Color("0d242e"))
			draw_rect(Rect2(i * width, size.y - depth, width + 1, depth), Color("0d242e"))
