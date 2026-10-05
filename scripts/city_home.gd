extends Control
## The title and city hub are navigation surfaces, never playable levels.
var navigation: Control
var map_mode := false
var display_font: SystemFont

func _ready() -> void:
	display_font = SystemFont.new()
	display_font.font_names = PackedStringArray(["SimSun", "Noto Serif CJK SC", "serif"])
	queue_redraw()

func _draw() -> void:
	var muted := Color(0.86, 0.75, 0.52, 0.38)
	draw_line(Vector2(48, 76), Vector2(1232, 76), muted, 1)
	draw_line(Vector2(48, 650), Vector2(1232, 650), muted, 1)
	for x in [48.0, 1232.0]:
		draw_circle(Vector2(x, 76), 2.5, GOLD)
		draw_circle(Vector2(x, 650), 2.5, GOLD)
	if map_mode:
		return
	# Offset ink planes separate the title from the detailed city scenery.
	draw_colored_polygon(PackedVector2Array([Vector2(24, 323), Vector2(501, 292), Vector2(475, 508), Vector2(29, 536)]), Color(0.018, 0.062, 0.075, 0.86))
	draw_colored_polygon(PackedVector2Array([Vector2(29, 323), Vector2(44, 322), Vector2(30, 536), Vector2(15, 538)]), GOLD)
	draw_polyline(PackedVector2Array([Vector2(15, 365), Vector2(19, 315), Vector2(234, 301), Vector2(510, 283)]), Color(0.93, 0.84, 0.64, 0.75), 1.8, true)
	draw_polyline(PackedVector2Array([Vector2(491, 431), Vector2(480, 516), Vector2(300, 529), Vector2(61, 543)]), Color(0.93, 0.84, 0.64, 0.65), 1.3, true)
	_draw_water_mark(Vector2(437, 390))

func _draw_water_mark(center: Vector2) -> void:
	# A stepped aqueduct meets a drop: a small original city-water emblem.
	draw_colored_polygon(PackedVector2Array([center + Vector2(-37, -46), center + Vector2(39, -51), center + Vector2(32, 49), center + Vector2(-41, 54)]), Color("d8bd80"))
	var ink := Color("173a43")
	draw_polyline(PackedVector2Array([center + Vector2(-24, 12), center + Vector2(-24, -9), center + Vector2(-9, -9), center + Vector2(-9, -25), center + Vector2(7, -25)]), ink, 4, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(15, -21), center + Vector2(3, 0), center + Vector2(7, 10), center + Vector2(19, 10), center + Vector2(25, 0)]), ink)
	for y in [24.0, 33.0]:
		draw_polyline(PackedVector2Array([center + Vector2(-25, y), center + Vector2(-12, y - 3), center + Vector2(0, y), center + Vector2(13, y - 3), center + Vector2(25, y)]), ink, 2, true)
	draw_polyline(PackedVector2Array([center + Vector2(-44, -30), center + Vector2(-42, -54), center + Vector2(45, -58), center + Vector2(43, -13)]), PAPER, 1.5, true)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.065, 0.075, 0.84)
	style.set_border_width_all(1)
	style.border_color = Color(0.86, 0.75, 0.52, 0.42)
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 12
	return style
const PAPER := Color("f0eee4")
const GOLD := Color("edce86")

func label_at(text: String, pos: Vector2, dimensions: Vector2, font_size: int, color := PAPER) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.size = dimensions
	return label

func action(text: String, pos: Vector2, dimensions: Vector2, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = dimensions
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 24 if primary else 20)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("d8bd80") if primary else Color(0.055, 0.10, 0.13, 0.93)
		if state == "hover" or state == "pressed":
			style.bg_color = style.bg_color.lightened(0.15)
		style.content_margin_left = 24
		style.set_border_width_all(1)
		style.border_width_left = 3
		style.border_color = Color("aa9365")
		if state == "focus":
			style.set_border_width_all(2)
		button.add_theme_stylebox_override(state, style)
		button.add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), Color("14242a") if primary else PAPER)
	button.pressed.connect(callback)
	add_child(button)
	button.mouse_entered.connect(func(): _hover(button, pos, true))
	button.mouse_exited.connect(func(): _hover(button, pos, false))
	return button

func _hover(button: Button, origin: Vector2, entered: bool) -> void:
	var old: Tween = button.get_meta("hover_tween", null)
	if old != null:
		old.kill()
	var tween := button.create_tween()
	button.set_meta("hover_tween", tween)
	tween.tween_property(button, "position:x", origin.x - (4 if entered else 0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func bottom_action(text: String, slot: int, count: int, callback: Callable) -> Button:
	var button := preload("res://scripts/home_option.gd").new()
	var colors := [Color("d8bd80"), Color("458f9d"), Color("829d87"), Color("546f85")]
	button.text = text
	button.tint = colors[slot]
	button.index = slot
	var width := 366.0 if count == 3 else 279.0
	button.position = Vector2(48 + slot * (width + 13), 562 + [9, -8, 4, -13][slot])
	button.size = Vector2(width, 104)
	button.pressed.connect(callback)
	add_child(button)
	return button

func title_label(text: String, pos: Vector2, dimensions: Vector2, font_size: int, color := PAPER) -> Label:
	var label := label_at(text, pos, dimensions, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_outline_color", Color("102b34"))
	label.add_theme_constant_override("outline_size", 7 if font_size >= 60 else 3)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 5)
	return label

func build_title(is_title: bool) -> void:
	if display_font == null:
		display_font = SystemFont.new()
		display_font.font_names = PackedStringArray(["SimSun", "Noto Serif CJK SC", "serif"])
	var heading := title_label("欢迎归城" if is_title else "修复事务所", Vector2(56, 303), Vector2(300, 40), 25, GOLD)
	heading.rotation = -0.035
	var letters := ["连", "通"] if is_title else ["百", "阶", "城"]
	var positions := [Vector2(58, 341), Vector2(196, 357)] if is_title else [Vector2(55, 350), Vector2(164, 335), Vector2(294, 363)]
	var sizes := [108, 118] if is_title else [104, 120, 90]
	for i in letters.size():
		var glyph := title_label(letters[i], positions[i], Vector2(145, 150), sizes[i], GOLD if i == 1 else Color("fff7e6"))
		glyph.add_theme_font_override("font", display_font)
		glyph.rotation = [-0.055, 0.025, -0.045][i]
	title_label("LIAN / TONG" if is_title else "BAI / JIE / CHENG", Vector2(62, 458), Vector2(330, 28), 15, GOLD)
	title_label("退潮之后，循水归城。" if is_title else "循着水声，去往下一处人家。", Vector2(57, 490), Vector2(422, 34), 21)

func setup(nav: Control, is_title: bool) -> void:
	navigation = nav
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_label("连通   /   百阶城水务志", Vector2(48, 32), Vector2(530, 30), 19, GOLD)
	title_label("BAIJIE    /    RESTORATION ARCHIVE", Vector2(865, 37), Vector2(380, 25), 13, Color("b7c6c4"))
	build_title(is_title)
	label_at("山城水路修复记", Vector2(48, 686), Vector2(430, 24), 15, Color("bacac6"))
	label_at("重力  /  混色  /  自动水路", Vector2(989, 686), Vector2(265, 24), 14, GOLD)
	if is_title:
		bottom_action("开始游戏    →", 0, 3, func(): nav.show_screen("hub"))
		bottom_action("素材署名", 1, 3, func(): nav.show_screen("credits"))
		bottom_action("退出游戏", 2, 3, func(): get_tree().quit())
	else:
		bottom_action("水路地图", 0, 4, func(): nav.show_screen("explore"))
		bottom_action("修复手册", 1, 4, func(): nav.show_screen("help"))
		bottom_action("档案馆", 2, 4, func(): nav.show_screen("credits"))
		bottom_action("返回标题", 3, 4, func(): nav.show_screen("menu"))
