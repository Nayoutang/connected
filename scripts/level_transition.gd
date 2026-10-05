extends CanvasLayer
## Shared arrival brief. The timing is presentation only, never loading progress.
var active := false
var surface: Control
var motion: Tween
var completion: Callable
const INK := Color("101a21")
const PAPER := Color("eef0e7")
const GOLD := Color("f1cc70")
const REGIONS := {"gate": "归城水口", "old_street": "旧街管网", "reservoir": "蓄水高台", "clocktower": "钟楼水道", "greenhouse": "屋顶温室", "nursery": "无人苗圃", "households": "两户灯火"}

func _ready() -> void:
	layer = 40
	hide()

func _block(pos: Vector2, dimensions: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = dimensions
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(rect)
	return rect

func _text(value: String, pos: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = value
	label.position = pos
	label.size = dimensions
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(label)
	label.size = dimensions
	return label

func present(host: Node, done: Callable) -> void:
	cancel()
	if host.get_meta("skip_transition", false) or get_tree().root.get_meta("skip_transition", false):
		done.call()
		return
	completion = done
	active = true
	surface = Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.theme = Theme.new()
	surface.theme.default_font = host.font
	add_child(surface)
	_block(Vector2.ZERO, Vector2(1280, 720), INK)
	var photo := TextureRect.new()
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.texture = host.backdrop.current_texture
	photo.position = Vector2(0, 90)
	photo.size = Vector2(730, 550)
	photo.clip_contents = true
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(photo)
	_block(Vector2(0, 90), Vector2(730, 550), Color(0.03, 0.08, 0.10, 0.25))
	var divider := Polygon2D.new()
	divider.polygon = PackedVector2Array([Vector2(690, 90), Vector2(754, 90), Vector2(754, 640), Vector2(610, 640)])
	divider.color = INK
	surface.add_child(divider)
	_block(Vector2(40, 35), Vector2(5, 24), GOLD)
	_text("百阶城  /  水路修复档案", Vector2(60, 31), Vector2(500, 38), 22, PAPER)
	_text("FIELD RECORD     /     %02d — 13" % (host.lv_index + 1), Vector2(900, 37), Vector2(350, 28), 16, Color("9aafb6"))
	_text("目的地", Vector2(40, 540), Vector2(160, 30), 16, GOLD)
	_text(REGIONS.get(host.backdrop.region, "百阶城"), Vector2(40, 573), Vector2(500, 55), 34, PAPER)
	_text("修复任务  /  %02d" % (host.lv_index + 1), Vector2(776, 118), Vector2(430, 34), 20, GOLD)
	var heading := _text((host.lbl_title.text if host.lv_index < 10 else host.title.text).get_slice("·", 1).strip_edges(), Vector2(774, 165), Vector2(450, 116), 44, PAPER)
	_block(Vector2(778, 298), Vector2(442, 1), Color("42525a"))
	_text("现场提示", Vector2(778, 323), Vector2(420, 28), 17, GOLD)
	_text((host.lbl_hint.text if host.lv_index < 10 else host.hint.text), Vector2(778, 368), Vector2(428, 190), 23, PAPER)
	_text("勘察水路   →   配置装置   →   放水验证", Vector2(778, 584), Vector2(450, 40), 18, Color("9aafb6"))
	_block(Vector2(40, 662), Vector2(1180, 1), Color("42525a"))
	_text("连通  /  退潮之后", Vector2(40, 680), Vector2(400, 26), 16, Color("9aafb6"))
	_text("即将抵达    ·    点击 / 空格 / ESC 跳过", Vector2(844, 680), Vector2(400, 28), 16, PAPER)
	surface.modulate.a = 0.0
	heading.position.x += 28
	show()
	motion = create_tween()
	motion.tween_property(surface, "modulate:a", 1.0, 0.18)
	motion.parallel().tween_property(heading, "position:x", 774.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_interval(1.5)
	motion.tween_property(surface, "modulate:a", 0.0, 0.22)
	motion.tween_callback(finish)

func cancel() -> void:
	if motion != null:
		motion.kill()
	active = false
	completion = Callable()
	hide()
	if is_instance_valid(surface):
		remove_child(surface)
		surface.queue_free()
		surface = null

func finish() -> void:
	if not active:
		return
	var done := completion
	cancel()
	if done.is_valid():
		done.call()

func _input(event: InputEvent) -> void:
	if not active:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		finish()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
		finish()
