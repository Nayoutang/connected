extends Button
## Slanted bottom navigation with an intentionally loose ink contour.
var tint := Color("378e9d")
var index := 0
var hot := false

func _ready() -> void:
	mouse_entered.connect(_set_hot.bind(true))
	mouse_exited.connect(_set_hot.bind(false))
	focus_entered.connect(_set_hot.bind(true))
	focus_exited.connect(_set_hot.bind(false))
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
		add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), Color.TRANSPARENT)

func _set_hot(value: bool) -> void:
	hot = value or has_focus()
	queue_redraw()

func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, _shape())

func _shape() -> PackedVector2Array:
	var w := size.x
	var h := size.y
	return PackedVector2Array([Vector2(25, 13), Vector2(w - 8, 0), Vector2(w - 27, h - 13), Vector2(6, h)])

func _draw() -> void:
	var w := size.x
	var h := size.y
	var lift := Vector2(0, -4 if hot else 0)
	var shape := _shape()
	for i in shape.size():
		shape[i] += lift
	var shadow := PackedVector2Array()
	for point in shape:
		shadow.append(point + Vector2(6, 9))
	draw_colored_polygon(shadow, Color(0.015, 0.045, 0.055, 0.8))
	draw_colored_polygon(shape, tint.lightened(0.17) if hot else tint)
	# Unequal segments and open ends keep the outline from feeling mechanical.
	var ink := Color("eee4c9")
	ink.a = 0.95 if hot else 0.68
	draw_polyline(PackedVector2Array([Vector2(3, h + 6), Vector2(12, h * 0.63), Vector2(20, 5), Vector2(w * 0.49, -3), Vector2(w - 5, -7)]) , ink, 1.7, true)
	draw_polyline(PackedVector2Array([Vector2(w + 2, 8), Vector2(w - 8, h * 0.48), Vector2(w - 20, h - 5), Vector2(w * 0.56, h + 1), Vector2(28, h + 9)]), ink, 1.2, true)
	draw_polyline(PackedVector2Array([Vector2(16, 23), Vector2(25, 9), Vector2(w * 0.38, 2)]), Color(0.06, 0.14, 0.17, 0.6), 1.1, true)
	var font := get_theme_font("font")
	var fg := Color("102c35") if tint.get_luminance() > 0.4 else Color("fff5df")
	draw_string(font, Vector2(35, 49) + lift, text, HORIZONTAL_ALIGNMENT_LEFT, w - 68, 25, fg)
	draw_string(font, Vector2(37, 74) + lift, "%02d   /   %s" % [index + 1, "SELECT" if hot else "CITY ARCHIVE"], HORIZONTAL_ALIGNMENT_LEFT, w - 65, 11, fg)
	if hot:
		draw_line(Vector2(35, 56) + lift, Vector2(w - 48, 48) + lift, fg, 2, true)
