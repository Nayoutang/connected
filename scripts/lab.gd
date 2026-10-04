extends Node2D
## Interactive construction, generic controller wiring and measurable outcomes.

const Sim = preload("res://scripts/lab_sim.gd")
const Levels = preload("res://scripts/lab_levels.gd")
const Art = preload("res://scripts/game_art.gd")
const STEP := 0.35
const AQUA := Color("53d5f2")
const GOLD := Color("ffd277")
const DIM := Color("99b1c4")
var sim = Sim.new()
var levels: Array = Levels.get_levels()
var index := 0
var font: Font
var ui: Control
var selected := ""
var selected_edge := false
var paused := false
var accumulator := 0.0
var animation_time := 0.0
var result_shown := false
var title: Label
var hint: Label
var status: Label
var notice: Label
var details: Label
var stock: Label
var play_button: Button
var tank_button: Button
var action_button: Button
var check_button: Button
var link_button: Button
var remove_button: Button
var target_picker: OptionButton
var low: SpinBox
var high: SpinBox
var invert: CheckBox
var result_panel: PanelContainer
var result_label: Label
var story: CanvasLayer
var backdrop: Node2D
var sidebar_style: StyleBoxFlat
const StoryData = preload("res://scripts/story_data.gd")

func _ready() -> void:
	var window := get_window()
	window.content_scale_size = Vector2i(1280, 720)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	font = sf
	_build_ui()
	sidebar_style = _style(Color("112130"))
	backdrop = preload("res://scripts/story_backdrop.gd").new()
	add_child(backdrop)
	story = preload("res://scripts/story_dialogue.gd").new()
	add_child(story)
	_load(0)

func _style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(10)
	box.content_margin_left = 12
	box.content_margin_right = 12
	return box

func _label(text: String, pos: Vector2, size: Vector2, font_size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(label)
	return label

func _button(text: String, pos: Vector2, size: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size
	button.pressed.connect(callback)
	ui.add_child(button)
	return button

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var theme_data := Theme.new()
	theme_data.default_font = font
	theme_data.default_font_size = 18
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			theme_data.set_stylebox(state, type, _style(Color("24556b") if state in ["hover", "focus"] else Color("193248")))
	ui.theme = theme_data
	title = _label("", Vector2(28, 16), Vector2(900, 42), 30)
	title.add_theme_color_override("font_color", AQUA)
	hint = _label("", Vector2(28, 64), Vector2(1220, 64), 19)
	_button("返回主菜单", Vector2(1090, 16), Vector2(160, 40), func(): get_tree().change_scene_to_file("res://main.tscn"))
	_label("水路图 / 点击装置配置 · 交叉处不连通 · h 表示实际高度", Vector2(28, 135), Vector2(880, 30), 18)
	_label("装置面板", Vector2(944, 137), Vector2(300, 30), 22)
	stock = _label("", Vector2(944, 175), Vector2(300, 50), 17)
	details = _label("", Vector2(944, 228), Vector2(302, 102), 17)
	tank_button = _button("安装 / 拆除水箱", Vector2(944, 335), Vector2(300, 36), _tank)
	action_button = _button("切换装置", Vector2(944, 379), Vector2(300, 36), _actuate)
	check_button = _button("安装 / 反向 / 拆除单向阀", Vector2(944, 423), Vector2(300, 36), _check)
	_label("浮子控制目标（选择容器后配置）", Vector2(944, 469), Vector2(300, 25), 16)
	target_picker = OptionButton.new()
	target_picker.position = Vector2(944, 498)
	target_picker.size = Vector2(300, 34)
	ui.add_child(target_picker)
	_label("下限", Vector2(944, 542), Vector2(44, 25), 16)
	_label("上限", Vector2(1099, 542), Vector2(44, 25), 16)
	low = SpinBox.new()
	low.position = Vector2(987, 537)
	low.size = Vector2(106, 34)
	low.min_value = 0
	low.max_value = 32
	low.step = 0.5
	low.value = 2
	ui.add_child(low)
	high = SpinBox.new()
	high.position = Vector2(1142, 537)
	high.size = Vector2(102, 34)
	high.min_value = 0.5
	high.max_value = 32
	high.step = 0.5
	high.value = 6
	ui.add_child(high)
	invert = CheckBox.new()
	invert.text = "反转高 / 低水位动作"
	invert.position = Vector2(944, 577)
	ui.add_child(invert)
	link_button = _button("连接 / 更新浮子", Vector2(944, 615), Vector2(183, 36), _link)
	remove_button = _button("拆浮子", Vector2(1135, 615), Vector2(109, 36), _remove_float)
	_label("默认：高水位关阀 / 切 B，低水位开阀 / 切 A", Vector2(944, 659), Vector2(310, 40), 14)
	status = _label("", Vector2(28, 598), Vector2(876, 28), 17)
	notice = _label("", Vector2(28, 630), Vector2(876, 26), 16)
	notice.add_theme_color_override("font_color", GOLD)
	play_button = _button("开始放水", Vector2(28, 668), Vector2(150, 38), _play)
	_button("单步", Vector2(190, 668), Vector2(92, 38), _single_step)
	_button("重温剧情", Vector2(408, 668), Vector2(126, 38), func(): story.play(StoryData.chapter(true, index)))
	_button("重置", Vector2(294, 668), Vector2(92, 38), func(): _load(index))
	_button("上一关", Vector2(642, 668), Vector2(112, 38), func(): _load(posmod(index - 1, levels.size())))
	_button("下一关", Vector2(766, 668), Vector2(112, 38), func(): _load((index + 1) % levels.size()))
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(280, 195)
	result_panel.size = Vector2(720, 325)
	var result_style := _style(Color("142a3e"))
	result_style.set_border_width_all(2)
	result_style.border_color = AQUA
	result_style.content_margin_top = 24
	result_style.content_margin_bottom = 24
	result_panel.add_theme_stylebox_override("panel", result_style)
	ui.add_child(result_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	result_panel.add_child(stack)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 24)
	stack.add_child(result_label)
	var inspect := Button.new()
	inspect.text = "查看水路与结果"
	inspect.pressed.connect(func(): result_panel.hide())
	stack.add_child(inspect)
	var retry := Button.new()
	retry.text = "重新搭建，尝试另一种解法"
	retry.pressed.connect(func(): _load(index))
	stack.add_child(retry)
	result_panel.hide()

func _load(level_index: int) -> void:
	backdrop.set_region(true, level_index)
	index = level_index
	sim.load_level(levels[index])
	paused = false
	accumulator = 0
	selected = ""
	selected_edge = false
	result_shown = false
	result_panel.hide()
	title.text = "涌现实验室 · " + levels[index]["title"]
	hint.text = levels[index]["hint"]
	notice.text = "准备阶段可自由配置；运行时仍可手动切换阀门。空水箱不会凭空产生水。"
	target_picker.clear()
	for n in sim.nodes:
		if n["kind"] == "router":
			target_picker.add_item(n["name"] + "  A ↔ B")
			target_picker.set_item_metadata(target_picker.item_count - 1, n["id"])
	for e in sim.edges:
		if e["kind"] == "valve":
			target_picker.add_item(e["id"] + "  开 ↔ 关")
			target_picker.set_item_metadata(target_picker.item_count - 1, e["id"])
	low.value = 2
	high.value = 6
	invert.button_pressed = false
	_refresh()
	queue_redraw()
	if not get_meta("skip_story", false):
		story.play(StoryData.chapter(true, index))

func _feedback(ok: bool, message: String) -> void:
	notice.text = message if ok else sim.last_error
	_refresh()
	queue_redraw()

func _tank() -> void:
	_feedback(sim.place_tank(selected), "水箱配置已更新；高水位容器可以向低处送水。")

func _actuate() -> void:
	_feedback(sim.actuate(selected), "已切换；蓝色箭头显示当前流动方向。")

func _check() -> void:
	_feedback(sim.cycle_check(selected), "单向阀已更新；箭头表示允许的方向，再点可反向或拆除。")

func _link() -> void:
	if target_picker.selected < 0:
		return
	var target: String = target_picker.get_item_metadata(target_picker.selected)
	_feedback(sim.link_float(selected, target, low.value, high.value, invert.button_pressed), "浮子已连接；虚线是控制线，在上下限之间保持原状态。")

func _remove_float() -> void:
	_feedback(sim.remove_float(selected), "浮子已拆除，装置恢复手动控制。")

func _play() -> void:
	if sim.won or sim.failed:
		return
	if not sim.started:
		sim.start()
		paused = false
	else:
		paused = not paused
	_refresh()

func _single_step() -> void:
	if sim.won or sim.failed:
		return
	sim.start()
	paused = true
	accumulator = 0
	sim.step()
	_after_step()

func _process(delta: float) -> void:
	if story.active:
		return
	if sim.started and not paused and not sim.won and not sim.failed:
		animation_time += delta
		accumulator += delta
		while accumulator >= STEP and not sim.won and not sim.failed:
			accumulator -= STEP
			sim.step()
			_after_step()
	queue_redraw()

func _after_step() -> void:
	_refresh()
	if (sim.won or sim.failed) and not result_shown:
		result_shown = true
		result_label.text = ("系统运转成功！" if sim.won else "实验未达标") + "\n\n" + sim.score_text()
		if sim.failed:
			notice.text = sim.last_error
		if sim.won:
			backdrop.celebrate()
		if sim.won and not get_meta("skip_story", false):
			story.play(StoryData.chapter(true, index, true))
			story.finished.connect(_show_result, CONNECT_ONE_SHOT)
		else:
			_show_result()

func _show_result() -> void:
	result_panel.show()
	result_panel.modulate.a = 0
	create_tween().tween_property(result_panel, "modulate:a", 1.0, 0.25)

func _refresh() -> void:
	stock.text = "剩余：水箱 %d · 单向阀 %d · 浮子 %d" % [sim.inventory["tank"], sim.inventory["check"], sim.inventory["float"]]
	status.text = "水源 %.1f L  /  存水 %.1f L  /  已用 %.1f L  ·  保持 %d/%d 拍  ·  手动 %d 次" % [sim.source_water(), sim.total_water(), sim.drained, sim.stable_ticks, sim.rules["hold_ticks"], sim.operations]
	play_button.text = "已结束" if sim.won or sim.failed else ("开始放水" if not sim.started else ("继续" if paused else "暂停"))
	play_button.disabled = sim.won or sim.failed
	var n: Dictionary = sim.node(selected) if not selected_edge else {}
	var e: Dictionary = sim.edge(selected) if selected_edge else {}
	details.text = "点击左侧水箱底座安装水箱；\n点击管道配置单向阀；\n点击容器，为它连接浮子。"
	if not n.is_empty():
		details.text = "%s  [%s]\n水量 %.1f / %.1f L · 高度 h=%.1f\n水面 %.1f%s" % [n["name"], n["id"], n["volume"], n["capacity"], n["height"], sim.head(n), " · 未安装" if not n["installed"] else ""]
	elif not e.is_empty():
		var direction: String = "双向" if e["check"] == 0 else (e["a"] + " → " + e["b"] if e["check"] == 1 else e["b"] + " → " + e["a"])
		details.text = "管道 %s：%s ↔ %s\n上限 %.1f L/拍 · %s\n当前 %.2f L/拍%s" % [e["id"], e["a"], e["b"], e["rate"], direction, absf(e["flow"]), " · 已关闭" if not e["open"] else ""]
	tank_button.disabled = sim.started or n.is_empty() or n.get("kind") != "socket"
	check_button.disabled = sim.started or e.is_empty()
	action_button.disabled = sim.won or sim.failed or not ((not n.is_empty() and n.get("kind") == "router") or (not e.is_empty() and e.get("kind") == "valve"))
	action_button.text = "切换出口 A / B" if n.get("kind") == "router" else "打开 / 关闭阀门"
	var sensor_ok: bool = not sim.started and not n.is_empty() and n.get("installed", false) and n.get("kind") != "router"
	link_button.disabled = not sensor_ok
	remove_button.disabled = not sensor_ok
	target_picker.disabled = not sensor_ok
	low.editable = sensor_ok
	high.editable = sensor_ok
	invert.disabled = not sensor_ok

func _unhandled_input(event: InputEvent) -> void:
	if story.active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if result_panel.visible:
			result_panel.hide()
		elif sim.started:
			paused = not paused
			_refresh()
		return
	if result_panel.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if p.x >= 915 or p.y < 180 or p.y >= 595:
			return
		for n in sim.nodes:
			if p.distance_to(n["pos"]) < 46:
				_select(n["id"], false)
				return
		var nearest := 24.0
		var candidate := ""
		for e in sim.edges:
			var a: Vector2 = sim.node(e["a"])["pos"]
			var b: Vector2 = sim.node(e["b"])["pos"]
			var distance := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
			if distance < nearest:
				nearest = distance
				candidate = e["id"]
		if not candidate.is_empty():
			_select(candidate, true)

func _select(id: String, is_edge: bool) -> void:
	selected = id
	selected_edge = is_edge
	for f in sim.floats:
		if f["sensor"] == id and not is_edge:
			low.value = f["low"]
			high.value = f["high"]
			invert.button_pressed = f["inverted"]
			for i in target_picker.item_count:
				if target_picker.get_item_metadata(i) == f["target"]:
					target_picker.select(i)
	_refresh()

func _text(text: String, p: Vector2, size: int, color: Color = Color.WHITE, width: float = 190) -> void:
	draw_string(font, p - Vector2(width / 2, -size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)

func _icon(texture: Texture2D, p: Vector2, size: float, color: Color) -> void:
	draw_texture_rect(texture, Rect2(p - Vector2.ONE * size / 2, Vector2.ONE * size), false, color)

func _arrow(p: Vector2, direction: Vector2, color: Color, size: float = 9) -> void:
	var forward := direction.normalized()
	var side := forward.orthogonal()
	draw_colored_polygon(PackedVector2Array([p + forward * size, p - forward * size + side * size * 0.65, p - forward * size - side * size * 0.65]), color)

func _draw() -> void:
	if font == null:
		return
	draw_rect(Rect2(12, 8, 1256, 704), Color(0.025, 0.055, 0.09, 0.55))
	draw_style_box(sidebar_style, Rect2(925, 128, 335, 577))
	for e in sim.edges:
		_draw_edge(e)
	for f in sim.floats:
		var target_node: Dictionary = sim.node(f["target"])
		var dest: Vector2
		if target_node.is_empty():
			var e: Dictionary = sim.edge(f["target"])
			dest = (sim.node(e["a"])["pos"] + sim.node(e["b"])["pos"]) * 0.5
		else:
			dest = target_node["pos"]
		var origin: Vector2 = sim.node(f["sensor"])["pos"]
		draw_dashed_line(origin + Vector2(0, -32), dest + Vector2(0, -32), GOLD, 2, 8)
		_text("浮子 → " + f["target"], origin + Vector2(0, -76), 14, GOLD)
	for n in sim.nodes:
		_draw_node(n)

func _draw_edge(e: Dictionary) -> void:
	var a: Vector2 = sim.node(e["a"])["pos"]
	var b: Vector2 = sim.node(e["b"])["pos"]
	var mid := (a + b) * 0.5
	var color := AQUA if absf(e["flow"]) > Sim.EPS else DIM
	if selected_edge and selected == e["id"]:
		draw_line(a, b, Color("43728e"), 27, true)
	draw_set_transform(a, (b - a).angle())
	var length := a.distance_to(b)
	var segments := maxi(1, ceili(length / 70))
	for i in segments:
		draw_texture_rect(Art.PIPE_WET if absf(e["flow"]) > Sim.EPS else Art.PIPE_DRY, Rect2(i * length / segments, -8, length / segments, 16), false, Color.WHITE if absf(e["flow"]) > Sim.EPS else Color("557080"))
	draw_set_transform(Vector2.ZERO)
	if absf(e["flow"]) > Sim.EPS:
		var phase := fmod(animation_time * 0.8, 1.0)
		_arrow(a.lerp(b, phase if e["flow"] > 0 else 1.0 - phase), (b - a) * signf(e["flow"]), Color.WHITE, 6)
	if e["kind"] == "valve":
		draw_circle(mid, 21, Color("112130"))
		_icon(Art.VALVE, mid, 33, Color("78e0ae") if e["open"] else Color("ff7c79"))
	if e["check"] != 0:
		var badge := mid + Vector2(0, -26) if e["kind"] == "valve" else mid
		draw_circle(badge, 15, Color("112130"))
		_arrow(badge, (b - a) * int(e["check"]), GOLD)
	var caption: String = e["id"]
	if e.has("port"):
		caption += " / 出口 " + ("A" if e["port"] == 0 else "B")
	var label_offset := Vector2(-45, 0) if e["kind"] == "valve" and absf(a.x - b.x) < 30 else Vector2(0, 26)
	_text(caption, mid + label_offset, 14, color)

func _draw_node(n: Dictionary) -> void:
	var p: Vector2 = n["pos"]
	var color := AQUA if n["installed"] else DIM
	if n.has("target") and float(n["volume"]) + Sim.EPS >= float(n["target"]):
		color = GOLD
	draw_circle(p, 34, Color("152b3e"))
	draw_arc(p, 34, 0, TAU, 48, color, 2, true)
	if selected == n["id"] and not selected_edge:
		draw_arc(p, 41, 0, TAU, 48, Color.WHITE, 2, true)
	if n["kind"] == "router":
		_icon(Art.VALVE, p - Vector2(0, 5), 33, AQUA)
		_text("→ A" if n["route"] == 0 else "→ B", p + Vector2(0, 21), 14, GOLD)
	else:
		var texture: Texture2D = Art.SOURCE if n["kind"] == "source" else (Art.DROP if n["kind"] == "goal" else Art.TANK)
		_icon(texture, p, 44, color if n["installed"] else Color(color, 0.45))
		if not n["installed"]:
			_text("+", p + Vector2(27, -26), 23, AQUA)
	_text(n["name"] + " · h" + str(n["height"]), p + Vector2(0, -50), 16, color)
	var bar := Rect2(p + Vector2(-37, 40), Vector2(74, 5))
	draw_rect(bar, Color("263d50"))
	draw_rect(Rect2(bar.position, Vector2(74 * float(n["volume"]) / float(n["capacity"]), 5)), color)
	if n.has("target"):
		var x := p.x - 37 + 74 * float(n["target"]) / float(n["capacity"])
		draw_line(Vector2(x, p.y + 38), Vector2(x, p.y + 47), GOLD, 2)
	if n.has("spill_at"):
		var x := p.x - 37 + 74 * float(n["spill_at"]) / float(n["capacity"])
		draw_line(Vector2(x, p.y + 36), Vector2(x, p.y + 48), Color("ff7c79"), 3)
	var caption := "%.1f/%.0f L" % [n["volume"], n["capacity"]]
	if n.has("target"):
		caption += " 目标≥%.0f" % n["target"]
	if n.has("spill_at"):
		caption += " 限%.1f" % n["spill_at"]
	_text(caption, p + Vector2(0, 57), 14, color)
