extends CanvasLayer
## Modal dialogue owns input, not the simulation's pause state.
signal finished
const ACHENG = preload("res://assets/story/acheng.png")
const CEN = preload("res://assets/story/cen.png")
var active := false
var lines: Array = []
var cursor := 0
var letters := 0.0
var surface: Control
var portrait: TextureRect
var body: Label
var speaker: Label
var place: Label
var advance_button: Button
var motion: Tween

func _ready() -> void:
	layer = 30
	surface = Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(surface)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	var theme_data := Theme.new()
	theme_data.default_font = font
	theme_data.default_font_size = 20
	surface.theme = theme_data
	var veil := ColorRect.new()
	veil.color = Color(0.015, 0.035, 0.06, 0.45)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(veil)
	var heading_band := ColorRect.new()
	heading_band.color = Color("102432")
	heading_band.size = Vector2(1280, 112)
	heading_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(heading_band)
	portrait = TextureRect.new()
	portrait.position = Vector2(30, 260)
	portrait.size = Vector2(320, 440)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(portrait)
	var panel := Panel.new()
	panel.position = Vector2(350, 490)
	panel.size = Vector2(900, 205)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102432")
	style.border_color = Color("c6a96c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(panel)
	place = _label(Vector2(36, 30), Vector2(1150, 50), 28)
	speaker = _label(Vector2(376, 505), Vector2(700, 32), 24)
	speaker.add_theme_color_override("font_color", Color("ffd277"))
	body = _label(Vector2(376, 548), Vector2(842, 88), 23)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	advance_button = _button("继续  /  空格", Vector2(1035, 645), advance)
	_button("跳过剧情 / Esc", Vector2(376, 645), close)
	surface.hide()
	set_process(false)

func _label(pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(label)
	return label

func _button(text: String, pos: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = Vector2(180, 36)
	button.pressed.connect(action)
	surface.add_child(button)
	return button

func play(content: Array) -> void:
	if content.is_empty():
		return
	lines = content
	cursor = 0
	active = true
	surface.show()
	set_process(true)
	_show_line()
	advance_button.grab_focus()

func _show_line() -> void:
	var line: Dictionary = lines[cursor]
	place.text = "退潮之后  /  " + line["place"]
	speaker.text = line["speaker"]
	body.text = line["text"]
	body.visible_characters = 0
	letters = 0
	portrait.texture = ACHENG if line["speaker"] == "阿澄" else CEN
	if motion:
		motion.kill()
	portrait.position.x = 10
	portrait.modulate.a = 0
	motion = create_tween().set_parallel(true)
	motion.tween_property(portrait, "position:x", 30.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(portrait, "modulate:a", 1.0, 0.25)

func _process(delta: float) -> void:
	letters += delta * 30
	body.visible_characters = mini(int(letters), body.text.length())

func advance() -> void:
	if not active:
		return
	if body.visible_characters < body.text.length():
		letters = body.text.length()
		body.visible_characters = body.text.length()
		return
	cursor += 1
	if cursor >= lines.size():
		close()
	else:
		_show_line()

func close() -> void:
	if not active:
		return
	active = false
	if motion:
		motion.kill()
	surface.hide()
	set_process(false)
	finished.emit()

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close()
		elif event.keycode in [KEY_SPACE, KEY_ENTER]:
			advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Buttons handle their own clicks. Clicking elsewhere advances once.
		var p := surface.get_local_mouse_position()
		if not Rect2(376, 645, 180, 36).has_point(p) and not Rect2(1035, 645, 180, 36).has_point(p):
			advance()
			get_viewport().set_input_as_handled()
