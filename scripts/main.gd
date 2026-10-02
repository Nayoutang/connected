extends Node2D
## 连通 —— 主场景：绘制 + 输入 + UI（全部用代码构建，没有额外场景文件）

const Levels = preload("res://scripts/levels.gd")
const WaterSim = preload("res://scripts/sim.gd")

const CELL := 90.0
const TICK := 0.35
const VIEW_W := 1280.0

const C_BG := Color(0.07, 0.08, 0.11)
const C_GUIDE := Color(1, 1, 1, 0.05)
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


func _ready() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Noto Sans SC", "WenQuanYi Micro Hei", "Source Han Sans SC", "sans-serif"])
	font = sf
	levels = Levels.get_levels()
	_build_ui()
	_load_level(0)


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
		_load_level(lv_index + 1)


# ───────────────────────── 关卡流程 ─────────────────────────
func _load_level(i: int) -> void:
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


func _update_status() -> void:
	var s := "阀门剩余 %d    水箱剩余 %d    终点 %d/%d" % [sim.valves_left, sim.tanks_left, sim.goals_lit(), sim.goals_total()]
	lbl_status.text = s


func _process(delta: float) -> void:
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
		if sim.edge_kind[e] == "valve" and not sim.edge_open[e] and _emid(e).distance_to(m) < 26.0:
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
	draw_rect(Rect2(0, 0, VIEW_W, 720), C_BG)

	# 高度参考线 + 左侧"高/低"标尺
	for r in range(0, 6):
		var y := origin.y + r * CELL
		draw_line(Vector2(60, y), Vector2(VIEW_W - 40, y), C_GUIDE, 1.0)
	draw_line(Vector2(34, origin.y), Vector2(34, origin.y + 5 * CELL), C_DIM, 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(34, origin.y + 5 * CELL + 12), Vector2(26, origin.y + 5 * CELL), Vector2(42, origin.y + 5 * CELL)]), C_DIM)
	_txt("高", Vector2(34, origin.y - 18), 18, C_DIM)
	_txt("低", Vector2(34, origin.y + 5 * CELL + 30), 18, C_DIM)

	# 管道：外壁 → 内腔 → 水
	for e in sim.edge_a.size():
		draw_line(_npos(sim.edge_a[e]), _npos(sim.edge_b[e]), C_WALL, 22.0, true)
	for e in sim.edge_a.size():
		draw_line(_npos(sim.edge_a[e]), _npos(sim.edge_b[e]), C_BORE, 14.0, true)
	for e in sim.edge_a.size():
		var f: int = sim.edge_from[e]
		if f >= 0:
			var p0 := _npos(f)
			var other: int = sim.edge_b[e] if sim.edge_a[e] == f else sim.edge_a[e]
			var p1 := _npos(other)
			var p := _edge_progress(e)
			draw_line(p0, p0.lerp(p1, p), _water_col(other), 10.0, true)
		elif sim.edge_kind[e] != "pipe" and not sim.edge_open[e]:
			# 关着的阀门：两侧有水就各自灌到阀门处（连通器，水会顶到阀门）
			var pa := _npos(sim.edge_a[e])
			var pb := _npos(sim.edge_b[e])
			var mid := pa.lerp(pb, 0.5)
			if _node_wet_vis(sim.edge_a[e]):
				draw_line(pa, mid, C_WATER_HIGH, 10.0, true)
			if _node_wet_vis(sim.edge_b[e]):
				draw_line(pb, mid, C_WATER_HIGH, 10.0, true)

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
	var p := _npos(i)
	var kind: String = sim.node_kind[i]
	var wet_vis := _node_wet_vis(i)
	match kind:
		"source":
			draw_rect(Rect2(p - Vector2(34, 28), Vector2(68, 56)), C_WALL)
			draw_rect(Rect2(p - Vector2(28, 22), Vector2(56, 44)), C_WATER_HIGH if sim.started else Color(0.18, 0.28, 0.5))
			_txt("水源", p, 20, Color.WHITE)
		"pipe":
			draw_circle(p, 13.0, C_WALL)
			draw_circle(p, 8.0, _water_col(i) if wet_vis else C_BORE)
		"goal":
			var col: Color = C_GOLD if wet_vis else C_WALL
			if wet_vis:
				draw_circle(p, 40.0, Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.18))
			draw_circle(p, 28.0, C_BG)
			draw_arc(p, 28.0, 0.0, TAU, 48, col, 5.0, true)
			if wet_vis:
				draw_circle(p, 22.0, C_GOLD)
			_txt("终点", p, 18, Color(0.1, 0.1, 0.1) if wet_vis else C_DIM)
		"slot":
			_draw_slot(i, p, wet_vis)


func _draw_slot(i: int, p: Vector2, wet_vis: bool) -> void:
	var rect := Rect2(p - Vector2(26, 30), Vector2(52, 60))
	if sim.has_tank[i]:
		draw_rect(rect, C_WALL)
		var inner := Rect2(rect.position + Vector2(5, 5), rect.size - Vector2(10, 10))
		draw_rect(inner, C_BORE)
		var ratio := 1.0
		if ratio > 0.0:
			var h := inner.size.y * ratio
			draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y - h, inner.size.x, h), C_WATER_HIGH)
		_txt("水箱", p + Vector2(0, 46), 16, C_DIM)
	else:
		draw_circle(p, 13.0, C_WALL)
		draw_circle(p, 8.0, _water_col(i) if wet_vis else C_BORE)
		var col := Color(1, 1, 1, 0.55) if (hover_kind == "slot" and hover_id == i) else Color(1, 1, 1, 0.22)
		_draw_dashed_rect(rect, col)
		if not sim.started:
			_txt("空位", p + Vector2(0, 46), 16, C_DIM)
	if hover_kind == "slot" and hover_id == i:
		draw_rect(rect.grow(4), Color(1, 1, 1, 0.5), false, 2.0)


func _draw_dashed_rect(r: Rect2, col: Color) -> void:
	var pts := [r.position, r.position + Vector2(r.size.x, 0), r.position + r.size, r.position + Vector2(0, r.size.y), r.position]
	for k in 4:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var d := a.distance_to(b)
		var n := int(d / 10.0)
		for j in range(0, n, 2):
			draw_line(a.lerp(b, float(j) / n), a.lerp(b, float(j + 1) / n), col, 2.0)


func _draw_valve(e: int) -> void:
	var p := _emid(e)
	var open: bool = sim.edge_open[e]
	var col: Color = C_VALVE_OPEN if open else C_VALVE_CLOSED
	var r := Rect2(p - Vector2(17, 17), Vector2(34, 34))
	draw_rect(r.grow(3), C_BG)
	draw_rect(r, col)
	_txt("开" if open else "关", p, 18, Color.WHITE)
	if hover_kind == "valve" and hover_id == e:
		draw_rect(r.grow(5), Color(1, 1, 1, 0.8), false, 2.0)
	elif not open and sim.valves_left > 0:
		var pulse := 0.25 + 0.2 * sin(Time.get_ticks_msec() / 280.0)
		draw_rect(r.grow(5), Color(1, 1, 1, pulse), false, 2.0)


func _draw_spring(e: int) -> void:
	var p := _emid(e)
	var open: bool = sim.edge_open[e]
	var col: Color = C_VALVE_OPEN if open else C_SPRING
	var s := 20.0
	var poly := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)])
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s - 3), p + Vector2(s + 3, 0), p + Vector2(0, s + 3), p + Vector2(-s - 3, 0)]), C_BG)
	draw_colored_polygon(poly, col)
	var thr: int = sim.edge_thr[e]
	var cnt: int = mini(sim.flow[sim.edge_a[e]], thr)
	_txt("弹" if open else "%d/%d" % [cnt, thr], p, 15, Color(0.1, 0.1, 0.1))
