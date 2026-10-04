extends Node2D
## 连通 —— 主场景：绘制 + 输入 + UI（全部用代码构建，没有额外场景文件）

const Levels = preload("res://scripts/levels.gd")
const WaterSim = preload("res://scripts/sim.gd")

const CELL := 90.0
const TICK := 0.35
const VIEW_W := 1280.0
const DESIGN_SIZE := Vector2i(1280, 720)

const C_BG := Color(0.07, 0.08, 0.11)
const C_WALL := Color(0.30, 0.33, 0.40)
const C_BORE := Color(0.09, 0.10, 0.13)
const C_WATER_LOW := Color(0.62, 0.86, 1.0)
const C_WATER_HIGH := Color(0.10, 0.42, 0.95)
const C_VALVE_CLOSED := Color(0.86, 0.28, 0.28)
const C_VALVE_OPEN := Color(0.30, 0.80, 0.45)
const C_SPRING := Color(0.98, 0.62, 0.18)
const C_GOLD := Color(1.0, 0.82, 0.30)
const C_TEXT := Color(0.88, 0.91, 0.96)
const C_DIM := Color(0.55, 0.60, 0.70)

var art = preload("res://scripts/game_art.gd").new()

var font: Font
var levels: Array = []
var lv_index := 0
var sim
var origin := Vector2(140, 130)

var running := false
var acc := 0.0
var frac := 0.0
var win_timer := -1.0
var won := false
var settled_msg := false
var flashes: Array = []
var hover_kind := ""
var hover_id := -1

var lbl_title: Label
var lbl_hint: Label
var lbl_status: Label
var lbl_msg: Label
var btn_start: Button
var btn_reset: Button
var btn_next: Button
var navigation: Control
var ui_paused := false
var story: CanvasLayer
var backdrop: Node2D
const StoryData = preload("res://scripts/story_data.gd")


func _ready() -> void:
	_configure_display()
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Noto Sans SC", "WenQuanYi Micro Hei", "Source Han Sans SC", "sans-serif"])
	font = sf
	levels = Levels.get_levels()
	_build_ui()
	_load_level(0)
	navigation = preload("res://scripts/game_ui.gd").new()
	get_child(0).add_child(navigation)
	navigation.setup(self, font)
	backdrop = preload("res://scripts/story_backdrop.gd").new()
	add_child(backdrop)
	backdrop.set_region(false, lv_index)
	story = preload("res://scripts/story_dialogue.gd").new()
	add_child(story)


func _configure_display() -> void:
	# Keep drawing and input in design coordinates. Godot scales the scene and
	# every CanvasLayer together whenever the host window / web canvas resizes.
	var window := get_window()
	window.unresizable = false
	window.content_scale_size = DESIGN_SIZE
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL


# ───────────────────────── UI ─────────────────────────
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 20
	root.theme = th
	layer.add_child(root)

	lbl_title = Label.new()
	lbl_title.position = Vector2(28, 14)
	lbl_title.add_theme_font_size_override("font_size", 32)
	lbl_title.add_theme_color_override("font_color", C_GOLD)
	root.add_child(lbl_title)

	lbl_hint = Label.new()
	lbl_hint.position = Vector2(28, 62)
	lbl_hint.custom_minimum_size = Vector2(1224, 0)
	lbl_hint.size = Vector2(1224, 56)
	lbl_hint.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	lbl_hint.add_theme_font_size_override("font_size", 20)
	lbl_hint.add_theme_color_override("font_color", C_TEXT)
	root.add_child(lbl_hint)

	lbl_status = Label.new()
	lbl_status.position = Vector2(28, 668)
	lbl_status.add_theme_font_size_override("font_size", 20)
	lbl_status.add_theme_color_override("font_color", C_DIM)
	root.add_child(lbl_status)

	lbl_msg = Label.new()
	lbl_msg.position = Vector2(28, 626)
	lbl_msg.custom_minimum_size = Vector2(1224, 0)
	lbl_msg.add_theme_font_size_override("font_size", 22)
	lbl_msg.add_theme_color_override("font_color", C_GOLD)
	root.add_child(lbl_msg)

	btn_start = _make_button(root, "放水", Vector2(850, 656))
	btn_start.pressed.connect(_on_start)
	btn_reset = _make_button(root, "重置", Vector2(980, 656))
	btn_reset.pressed.connect(_on_reset)
	btn_next = _make_button(root, "下一关", Vector2(1110, 656))
	btn_next.pressed.connect(_on_next)


func _make_button(parent: Node, text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = Vector2(120, 44)
	b.size = Vector2(120, 44)
	b.add_theme_font_size_override("font_size", 22)
	parent.add_child(b)
	return b


func _on_start() -> void:
	if story != null and story.active:
		return
	if ui_paused or (story != null and story.active):
		navigation.hide_screen()
	if running:
		return
	running = true
	sim.start()
	acc = 0.0
	frac = 0.0
	btn_start.disabled = true
	lbl_msg.text = ""


func _on_reset() -> void:
	_load_level(lv_index)


func _on_next() -> void:
	if lv_index + 1 < levels.size():
		enter_level(lv_index + 1)


# ───────────────────────── 关卡流程 ─────────────────────────
func enter_level(i: int) -> void:
	_load_level(i)
	if not get_meta("skip_story", false):
		story.play(StoryData.chapter(false, i))

func _load_level(i: int) -> void:
	if backdrop != null:
		backdrop.set_region(false, i)
	lv_index = i
	var lv: Dictionary = levels[i]
	sim = WaterSim.new()
	sim.load_level(lv)
	var max_col := 0
	for c in sim.node_col:
		max_col = maxi(max_col, c)
	origin = Vector2((VIEW_W - max_col * CELL) / 2.0, 150.0)
	running = false
	acc = 0.0
	frac = 0.0
	win_timer = -1.0
	won = false
	settled_msg = false
	flashes.clear()
	lbl_title.text = "第 %d 关 · %s" % [i + 1, lv["title"]]
	lbl_hint.text = lv["hint"]
	lbl_msg.text = ""
	btn_start.disabled = false
	btn_next.disabled = true
	btn_next.visible = (i + 1 < levels.size())
	_update_status()
	queue_redraw()
	if navigation != null:
		navigation.reveal_level()


func _update_status() -> void:
	var s := "阀门剩余 %d    水箱剩余 %d    终点 %d/%d" % [sim.valves_left, sim.tanks_left, sim.goals_lit(), sim.goals_total()]
	lbl_status.text = s


func _process(delta: float) -> void:
	if ui_paused or (story != null and story.active):
		return
	if running and not won:
		if sim.settled:
			acc = TICK
			if not sim.all_lit() and win_timer < 0.0 and not settled_msg:
				settled_msg = true
				lbl_msg.text = "水停住了。点【重置】换一种方案。"
		else:
			acc += delta
			while acc >= TICK and not sim.settled:
				acc -= TICK
				sim.step()
				_collect_events()
				_update_status()
				if sim.all_lit() and win_timer < 0.0:
					win_timer = TICK * 2.5
		frac = clampf(acc / TICK, 0.0, 1.0)
	if win_timer >= 0.0 and not won:
		win_timer -= delta
		if win_timer < 0.0:
			won = true
			if lv_index + 1 < levels.size():
				lbl_msg.text = "通关！" + levels[lv_index]["win"]
				btn_next.disabled = false
			else:
				lbl_msg.text = "全部通关！" + levels[lv_index]["win"] + "（Demo 到此结束）"
			backdrop.celebrate()
			if not get_meta("skip_story", false):
				story.play(StoryData.chapter(false, lv_index, true))
				story.finished.connect(func(): navigation.show_screen("win"), CONNECT_ONE_SHOT)
			else:
				navigation.show_screen("win")
	for f in flashes:
		f["t"] += delta
	flashes = flashes.filter(func(f): return f["t"] < 0.7)
	_update_hover()
	queue_redraw()


func _collect_events() -> void:
	for ev in sim.events:
		if ev[0] == "tank":
			flashes.append({"pos": _npos(ev[1]), "t": 0.0, "col": C_WATER_HIGH})
		elif ev[0] == "pop":
			flashes.append({"pos": _emid(ev[1]), "t": 0.0, "col": C_SPRING})


# ───────────────────────── 输入 ─────────────────────────
func _update_hover() -> void:
	hover_kind = ""
	hover_id = -1
	var m := get_local_mouse_position()
	for e in sim.edge_a.size():
		if sim.edge_kind[e] == "valve" and not sim.edge_open[e] and _emid(e).distance_to(m) < 33.0:
			hover_kind = "valve"
			hover_id = e
			return
	if not sim.started:
		for i in sim.node_id.size():
			if sim.node_kind[i] == "slot" and _npos(i).distance_to(m) < 34.0:
				hover_kind = "slot"
				hover_id = i
				return


func _unhandled_input(event: InputEvent) -> void:
	if ui_paused or (story != null and story.active):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if hover_kind == "valve":
			if sim.open_valve(hover_id):
				flashes.append({"pos": _emid(hover_id), "t": 0.0, "col": C_VALVE_OPEN})
				lbl_msg.text = ""
				settled_msg = false
			else:
				lbl_msg.text = "阀门次数用完了。"
		elif hover_kind == "slot":
			if not sim.toggle_tank(hover_id):
				lbl_msg.text = "水箱用完了，再点已放的水箱可以收回。"
			else:
				lbl_msg.text = ""
		_update_status()


# ───────────────────────── 绘制 ─────────────────────────
func _npos(i: int) -> Vector2:
	return origin + Vector2(sim.node_col[i], sim.node_row[i]) * CELL


func _emid(e: int) -> Vector2:
	return (_npos(sim.edge_a[e]) + _npos(sim.edge_b[e])) * 0.5


func _edge_progress(e: int) -> float:
	if sim.edge_from[e] < 0:
		return 0.0
	return clampf(float(sim.tick - 1 - sim.edge_t0[e]) + frac, 0.0, 1.0)


func _node_wet_vis(i: int) -> bool:
	if sim.node_kind[i] == "source":
		return true
	for e in sim.edge_a.size():
		var f: int = sim.edge_from[e]
		if f >= 0 and f != i and (sim.edge_a[e] == i or sim.edge_b[e] == i):
			if _edge_progress(e) >= 1.0:
				return true
	return false


func _water_col(node: int) -> Color:
	return C_WATER_HIGH


func _txt(text: String, center: Vector2, size: int, col: Color) -> void:
	var w := 160.0
	draw_string(font, Vector2(center.x - w / 2.0, center.y + size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)


func _draw() -> void:
	if sim == null:
		return
	draw_rect(Rect2(12, 8, 1256, 704), Color(0.035, 0.065, 0.10, 0.55))

	# 左侧高低标尺保留；背景不再绘制网格。
	draw_line(Vector2(34, origin.y), Vector2(34, origin.y + 5 * CELL), C_DIM, 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(34, origin.y + 5 * CELL + 12), Vector2(26, origin.y + 5 * CELL), Vector2(42, origin.y + 5 * CELL)]), C_DIM)
	_txt("高", Vector2(34, origin.y - 18), 18, C_DIM)
	_txt("低", Vector2(34, origin.y + 5 * CELL + 30), 18, C_DIM)

	# Open-licensed pipe textures, with progressive water fill.
	for e in sim.edge_a.size():
		art.edge(self, e)

	for i in sim.node_id.size():
		_draw_node(i)
	for e in sim.edge_a.size():
		if sim.edge_kind[e] == "valve":
			_draw_valve(e)
		elif sim.edge_kind[e] == "spring":
			_draw_spring(e)

	for f in flashes:
		var t: float = f["t"] / 0.7
		var c: Color = f["col"]
		c.a = 1.0 - t
		draw_arc(f["pos"], 18.0 + 60.0 * t, 0.0, TAU, 40, c, 4.0 * (1.0 - t) + 1.0, true)


func _draw_node(i: int) -> void:
	art.node(self, i)


func _draw_valve(e: int) -> void:
	art.valve(self, e)


func _draw_spring(e: int) -> void:
	art.spring(self, e)
