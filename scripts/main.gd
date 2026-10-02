extends Node2D
## 连通 —— 主场景：绘制 + 输入 + UI（全部用代码构建，没有额外场景文件）

const Chapter1 = preload("res://scripts/chapter1.gd")
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
const C_GOLD := Color(1.0, 0.82, 0.30)
const C_TEXT := Color(0.88, 0.91, 0.96)
const C_DIM := Color(0.55, 0.60, 0.70)
const C_WATER_LIGHT := Color(0.55, 0.80, 1.0)
const C_HILL := Color(0.13, 0.16, 0.20)
const C_GRASS := Color(0.38, 0.80, 0.42)
const C_GRASS_DARK := Color(0.22, 0.58, 0.32)
const C_SIPHON := Color(0.35, 0.85, 0.80)
const MASK_COLORS := {
	0: Color(0.10, 0.42, 0.95), 1: Color(0.93, 0.28, 0.32), 2: Color(0.22, 0.50, 1.0),
	3: Color(0.66, 0.32, 0.90), 4: Color(1.0, 0.85, 0.25), 5: Color(1.0, 0.55, 0.18),
	6: Color(0.30, 0.78, 0.38), 7: Color(0.55, 0.40, 0.32),
}
const ROUND_NAMES := {"grass": "一丛草", "flower": "一丛花", "tree": "一棵树"}

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
var drops: Array = []        # 水花粒子（只影响视觉）
var wet_prev := {}           # 上一帧哪些节点已被水浸到
var t_now := 0.0
var hover_kind := ""
var hover_id := -1
var lit_time := {}           # 终点第一次亮起的时间（花草长出来用）
var mode := "play"           # play / reveal / garden
var reveal_t := 0.0
var reveal_entries: Array = []
var reveal_rect := Rect2()
var reveal_key := ""
var reveal_gap := 1.4
var reveal_ground := 640.0

var lbl_title: Label
var lbl_hint: Label
var lbl_status: Label
var lbl_msg: Label
var btn_start: Button
var btn_reset: Button
var btn_next: Button
var btn_prev: Button


func _ready() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Noto Sans SC", "WenQuanYi Micro Hei", "Source Han Sans SC", "sans-serif"])
	font = sf
	levels = Chapter1.get_levels()
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

	btn_prev = _make_button(root, "上一关", Vector2(720, 656))
	btn_prev.pressed.connect(_on_prev)
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


func _on_prev() -> void:
	if mode == "play" and lv_index > 0:
		_load_level(lv_index - 1)


func _on_next() -> void:
	if mode == "play":
		var lv: Dictionary = levels[lv_index]
		if lv["caption"] != "":
			_start_reveal(lv["round"])
		elif lv_index + 1 < levels.size():
			_load_level(lv_index + 1)
	elif mode == "reveal":
		if lv_index + 1 < levels.size():
			_load_level(lv_index + 1)
		else:
			_start_reveal("")
	else:
		_load_level(0)


# ───────────────────────── 关卡流程 ─────────────────────────
func _load_level(i: int) -> void:
	lv_index = i
	mode = "play"
	_set_play_ui(true)
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
	drops.clear()
	wet_prev.clear()
	lit_time.clear()
	lbl_title.text = "第 %d 关 · %s" % [i + 1, lv["title"]]
	lbl_hint.text = lv["hint"]
	lbl_msg.text = ""
	btn_start.disabled = false
	btn_next.disabled = true
	btn_next.text = "下一关"
	btn_prev.disabled = (i == 0)
	_update_status()
	queue_redraw()


func _set_play_ui(on: bool) -> void:
	btn_start.visible = on
	btn_reset.visible = on
	btn_prev.visible = on
	lbl_status.visible = on


func _update_status() -> void:
	var lv: Dictionary = levels[lv_index]
	var parts: Array = []
	if lv["valves"] > 0:
		parts.append("阀门剩余 %d" % sim.valves_left)
	if lv["tanks"] > 0:
		parts.append("水箱剩余 %d" % sim.tanks_left)
	if lv["siphons"] > 0:
		parts.append("虹吸管剩余 %d" % sim.siphons_left)
	parts.append("终点 %d/%d" % [sim.goals_lit(), sim.goals_total()])
	lbl_status.text = "    ".join(parts)


func _process(delta: float) -> void:
	if mode != "play":
		_process_reveal(delta)
		return
	if running and not won:
		if sim.settled:
			acc = TICK
			if not sim.all_lit() and win_timer < 0.0 and not settled_msg:
				settled_msg = true
				if sim.goals_wrong() > 0:
					lbl_msg.text = "有花开错了颜色。水混得不对——点【重置】换一种方案。"
				else:
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
		if win_timer < 0.0 and not sim.settled:
			win_timer = 0.0  # 终点都亮了，但水还没流完，等整幅图填满再宣布通关
		elif win_timer < 0.0:
			won = true
			lbl_msg.text = "通关！" + levels[lv_index]["win"]
			btn_next.text = "揭晓" if levels[lv_index]["caption"] != "" else "下一关"
			btn_next.disabled = false
	for f in flashes:
		f["t"] += delta
	flashes = flashes.filter(func(f): return f["t"] < 0.7)
	_update_water_fx(delta)
	_update_hover()
	queue_redraw()


func _collect_events() -> void:
	for ev in sim.events:
		if ev[0] == "tank":
			flashes.append({"pos": _npos(ev[1]), "t": 0.0, "col": C_WATER_HIGH})


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
		for e in sim.edge_a.size():
			if sim.edge_kind[e] == "siphon" and _badge(e).distance_to(m) < 26.0:
				hover_kind = "siphon"
				hover_id = e
				return
		for i in sim.node_id.size():
			if sim.node_kind[i] == "slot" and _npos(i).distance_to(m) < 34.0:
				hover_kind = "slot"
				hover_id = i
				return


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# 调试/试玩用的快捷键：[ ] 切关，V 看本轮揭晓，G 看花园
		if event.keycode == KEY_BRACKETRIGHT and lv_index + 1 < levels.size():
			_load_level(lv_index + 1)
		elif event.keycode == KEY_BRACKETLEFT and lv_index > 0:
			_load_level(lv_index - 1)
		elif event.keycode == KEY_V and mode == "play":
			_start_reveal(levels[lv_index]["round"])
		elif event.keycode == KEY_G and mode == "play":
			_start_reveal("")
		return
	if mode != "play":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if hover_kind == "valve":
			if sim.open_valve(hover_id):
				flashes.append({"pos": _emid(hover_id), "t": 0.0, "col": C_VALVE_OPEN})
				lbl_msg.text = ""
				settled_msg = false
			else:
				lbl_msg.text = "阀门次数用完了。"
		elif hover_kind == "siphon":
			if sim.toggle_siphon(hover_id):
				lbl_msg.text = ""
			else:
				lbl_msg.text = "虹吸管用完了，再点已装的可以拆下。"
		elif hover_kind == "slot":
			if not sim.toggle_tank(hover_id):
				lbl_msg.text = "水箱用完了，再点已放的水箱可以收回。"
			else:
				lbl_msg.text = ""
		_update_status()


# ───────────────────────── 几何 ─────────────────────────
func _mask_col(m: int) -> Color:
	return MASK_COLORS.get(m, MASK_COLORS[0])


func _mask_light(m: int) -> Color:
	return _mask_col(m).lerp(Color.WHITE, 0.45)


func _npos_g(s, i: int, org: Vector2, cell: float) -> Vector2:
	return org + Vector2(s.node_col[i], s.node_row[i]) * cell


func _npos(i: int) -> Vector2:
	return _npos_g(sim, i, origin, CELL)


## 管道的折线：普通管 = 两点直线；虹吸管 = 竖直升到最高点、横过山头、再竖直落下
func _epath_g(s, e: int, org: Vector2, cell: float) -> PackedVector2Array:
	var pa := _npos_g(s, s.edge_a[e], org, cell)
	var pb := _npos_g(s, s.edge_b[e], org, cell)
	if s.edge_kind[e] == "siphon":
		var ay: float = org.y + float(s.edge_apex_row[e]) * cell
		return PackedVector2Array([pa, Vector2(pa.x, ay), Vector2(pb.x, ay), pb])
	return PackedVector2Array([pa, pb])


func _epath(e: int) -> PackedVector2Array:
	return _epath_g(sim, e, origin, CELL)


func _emid(e: int) -> Vector2:
	return (_npos(sim.edge_a[e]) + _npos(sim.edge_b[e])) * 0.5


## 虹吸管顶部中点（装/拆的圆钮就在这儿）
func _badge(e: int) -> Vector2:
	var pts := _epath(e)
	return (pts[1] + pts[2]) * 0.5


func _path_len(pts: PackedVector2Array) -> float:
	var t := 0.0
	for k in range(pts.size() - 1):
		t += pts[k].distance_to(pts[k + 1])
	return t


func _path_rev(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(pts.size() - 1, -1, -1):
		out.append(pts[k])
	return out


func _path_at(pts: PackedVector2Array, d: float) -> Vector2:
	var rest := d
	for k in range(pts.size() - 1):
		var l := pts[k].distance_to(pts[k + 1])
		if rest <= l or k == pts.size() - 2:
			return pts[k].lerp(pts[k + 1], clampf(rest / maxf(l, 0.001), 0.0, 1.0))
		rest -= l
	return pts[pts.size() - 1]


func _path_dir(pts: PackedVector2Array, d: float) -> Vector2:
	var rest := d
	for k in range(pts.size() - 1):
		var l := pts[k].distance_to(pts[k + 1])
		if rest <= l or k == pts.size() - 2:
			return (pts[k + 1] - pts[k]).normalized()
		rest -= l
	return Vector2.RIGHT


func _path_cut(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	var rest := d
	for k in range(pts.size() - 1):
		var l := pts[k].distance_to(pts[k + 1])
		if rest <= l:
			out.append(pts[k].lerp(pts[k + 1], rest / maxf(l, 0.001)))
			return out
		out.append(pts[k + 1])
		rest -= l
	return out


func _edge_progress(e: int) -> float:
	if sim.edge_from[e] < 0:
		return 0.0
	return clampf(float(sim.tick - 1 - sim.edge_t0[e]) + frac, 0.0, 1.0)


func _node_wet_vis(i: int) -> bool:
	if sim.node_kind[i] == "source":
		return true
	if sim.has_tank[i]:
		return true
	for e in sim.edge_a.size():
		var f: int = sim.edge_from[e]
		if f >= 0 and f != i and (sim.edge_a[e] == i or sim.edge_b[e] == i):
			if _edge_progress(e) >= 1.0:
				return true
	return false


## 视觉用的水流进度：往下流越流越快，往上流越流越慢，平着流匀速
func _edge_flow(e: int, from_n: int, to_n: int) -> float:
	var p := _edge_progress(e)
	if p <= 0.0 or p >= 1.0 or sim.edge_kind[e] == "siphon":
		return p
	var dz: float = sim.elev[to_n] - sim.elev[from_n]
	if dz < -0.01:
		return pow(p, 1.6)
	elif dz > 0.01:
		return 1.0 - pow(1.0 - p, 1.6)
	return p


func _flow_path(e: int, f: int) -> PackedVector2Array:
	var pts := _epath(e)
	if sim.edge_a[e] != f:
		pts = _path_rev(pts)
	return pts


# ───────────────────────── 水的视觉效果 ─────────────────────────
func _add_drop(pos: Vector2, vel: Vector2, life: float, col: Color) -> void:
	if drops.size() < 400:
		drops.append({"p": pos, "v": vel, "t": life, "t0": life, "c": col})


func _update_water_fx(delta: float) -> void:
	t_now += delta
	if running:
		# 水流前端甩出的水珠
		for e in sim.edge_a.size():
			var f: int = sim.edge_from[e]
			if f < 0:
				continue
			var other: int = sim.edge_b[e] if sim.edge_a[e] == f else sim.edge_a[e]
			var s := _edge_flow(e, f, other)
			if s <= 0.0 or s >= 1.0:
				continue
			if randf() < delta * 28.0:
				var pts := _flow_path(e, f)
				var dist := _path_len(pts) * s
				var dir := _path_dir(pts, dist)
				var nrm := Vector2(-dir.y, dir.x)
				var vel := dir * randf_range(20.0, 60.0) + nrm * randf_range(-35.0, 35.0) + Vector2(0.0, -randf_range(15.0, 55.0))
				_add_drop(_path_at(pts, dist), vel, 0.55, _mask_light(sim.node_mask[f]))
		# 新被水浸到的节点：溅起水花（终点更大、带金色）
		for i in sim.node_id.size():
			var wv: bool = _node_wet_vis(i)
			if wv and not wet_prev.get(i, false) and sim.node_kind[i] != "source":
				var is_goal: bool = sim.node_kind[i] == "goal"
				if is_goal:
					lit_time[i] = t_now
				var cnt := 22 if is_goal else 9
				for k in cnt:
					var ang := randf_range(PI * 1.1, PI * 1.9)
					var sp := randf_range(60.0, 190.0 if is_goal else 120.0)
					var col: Color = C_GOLD if (is_goal and k % 2 == 0) else _mask_light(sim.node_mask[i])
					_add_drop(_npos(i), Vector2(cos(ang), sin(ang)) * sp, randf_range(0.5, 0.9), col)
				flashes.append({"pos": _npos(i), "t": 0.0, "col": _mask_light(sim.node_mask[i])})
			wet_prev[i] = wv
	for d in drops:
		var v: Vector2 = d["v"]
		v.y += 420.0 * delta
		d["v"] = v
		d["p"] = (d["p"] as Vector2) + v * delta
		d["t"] = (d["t"] as float) - delta
	drops = drops.filter(func(d): return d["t"] > 0.0)


## 沿折线画一段水：带波动的高光沿流向移动，前端是圆润的水头
func _draw_water_path(pts: PackedVector2Array, s: float, m: int, width := 10.0) -> void:
	if s <= 0.0:
		return
	var total := _path_len(pts)
	if total < 1.0:
		return
	var col := _mask_col(m)
	var light := _mask_light(m)
	var dist := total * s
	var cut := _path_cut(pts, dist)
	draw_polyline(cut, col, width, true)
	for k in range(1, cut.size() - 1):
		draw_circle(cut[k], width * 0.5, col)
	var n := maxi(2, int(dist / 10.0))
	var hp := PackedVector2Array()
	for k in range(n + 1):
		var u := dist * float(k) / float(n)
		var dir := _path_dir(pts, u)
		var nrm := Vector2(-dir.y, dir.x)
		var wob := sin(u * 0.09 - t_now * 5.0) * 1.3
		hp.append(_path_at(pts, u) + nrm * (wob - 2.0) * width / 10.0)
	draw_polyline(hp, Color(light.r, light.g, light.b, 0.55), maxf(1.0, width * 0.2), true)
	if s < 0.999:
		var tip := cut[cut.size() - 1]
		draw_circle(tip, width * 0.6, col)
		draw_circle(tip + Vector2(0, -width * 0.15), width * 0.22, Color(light.r, light.g, light.b, 0.7))


func _draw_dashed_path(pts: PackedVector2Array, col: Color, width: float) -> void:
	var total := _path_len(pts)
	var d := 0.0
	while d < total:
		var a := _path_at(pts, d)
		var b := _path_at(pts, minf(d + 12.0, total))
		draw_line(a, b, col, width)
		d += 22.0


func _draw_dashed_hline(y: float, x0: float, x1: float, col: Color) -> void:
	var x := x0
	while x < x1:
		draw_line(Vector2(x, y), Vector2(minf(x + 10.0, x1), y), col, 2.0)
		x += 20.0


func _txt(text: String, center: Vector2, size: int, col: Color) -> void:
	var w := 160.0
	draw_string(font, Vector2(center.x - w / 2.0, center.y + size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)


# ───────────────────────── 花草树 ─────────────────────────
func _leaf(base: Vector2, ang: float, length: float, col: Color) -> void:
	if length < 3.0:
		return
	var dir := Vector2(cos(ang), sin(ang))
	var nrm := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	for k in range(0, 9):
		var u := float(k) / 8.0
		pts.append(base + dir * length * u + nrm * sin(u * PI) * length * 0.32)
	for k in range(7, 0, -1):
		var u := float(k) / 8.0
		pts.append(base + dir * length * u - nrm * sin(u * PI) * length * 0.32)
	draw_colored_polygon(pts, col)


## kind: grass / flower / leaf。size = 大致半径(像素)，grow = 0..1 长出来的程度
func _draw_flora(kind: String, p: Vector2, size: float, col: Color, grow: float) -> void:
	if grow <= 0.0:
		return
	var g := clampf(grow, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - g, 3.0)   # 先快后慢，像破土而出
	match kind:
		"grass":
			for k in range(-2, 3):
				var h := size * (1.15 - 0.2 * absf(float(k))) * e
				var bx := p.x + float(k) * size * 0.28
				var lean := float(k) * size * 0.16 * e
				var c := C_GRASS if k % 2 == 0 else C_GRASS_DARK
				if h < 2.0:
					continue
				draw_colored_polygon(PackedVector2Array([
					Vector2(bx - size * 0.1, p.y + size * 0.55), Vector2(bx + size * 0.1, p.y + size * 0.55),
					Vector2(bx + lean, p.y + size * 0.55 - h)]), c)
		"leaf":
			var c1 := C_GRASS
			draw_line(p + Vector2(0, size * 0.6), p + Vector2(0, size * 0.6 - size * 0.8 * e), C_GRASS_DARK, maxf(1.5, size * 0.08))
			for k in 3:
				var ang := deg_to_rad(-90.0 + (float(k) - 1.0) * 52.0)
				_leaf(p + Vector2(0, size * 0.55), ang, size * 1.25 * e, c1 if k != 1 else C_GRASS_DARK)
		"flower":
			var top := p + Vector2(0, -size * 0.1)
			draw_line(p + Vector2(0, size * 0.75), top, C_GRASS_DARK, maxf(1.5, size * 0.1))
			for k in 6:
				var ang := TAU * float(k) / 6.0
				draw_circle(top + Vector2(cos(ang), sin(ang)) * size * 0.46 * e, size * 0.3 * e, col)
			draw_circle(top, size * 0.28 * e, Color(1.0, 0.93, 0.55))


# ───────────────────────── 绘制 ─────────────────────────
func _draw() -> void:
	if sim == null:
		return
	draw_rect(Rect2(0, 0, VIEW_W, 720), C_BG)
	if mode != "play":
		_draw_reveal()
		return

	# 高度参考线 + 左侧"高/低"标尺
	for r in range(0, 6):
		var y := origin.y + r * CELL
		draw_line(Vector2(60, y), Vector2(VIEW_W - 40, y), C_GUIDE, 1.0)
	draw_line(Vector2(34, origin.y), Vector2(34, origin.y + 5 * CELL), C_DIM, 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(34, origin.y + 5 * CELL + 12), Vector2(26, origin.y + 5 * CELL), Vector2(42, origin.y + 5 * CELL)]), C_DIM)
	_txt("高", Vector2(34, origin.y - 18), 18, C_DIM)
	_txt("低", Vector2(34, origin.y + 5 * CELL + 30), 18, C_DIM)

	# 水位线：每个水源、每个已放的水箱，水最多涨到它的高度
	for i in sim.node_id.size():
		if sim.node_kind[i] == "source" or sim.has_tank[i]:
			var wy: float = origin.y + float(sim.node_row[i]) * CELL
			var wc := _mask_col(sim.node_mask[i])
			_draw_dashed_hline(wy, 60.0, VIEW_W - 40.0, Color(wc.r, wc.g, wc.b, 0.28))

	# 山头（虹吸管翻过的地方）
	for e in sim.edge_a.size():
		if sim.edge_kind[e] == "siphon":
			var pts := _epath(e)
			var x0 := minf(pts[0].x, pts[3].x)
			var x1 := maxf(pts[0].x, pts[3].x)
			var top := pts[1].y + CELL * 0.55
			draw_colored_polygon(PackedVector2Array([
				Vector2(x0 + CELL * 0.3, top + CELL * 0.9), Vector2(x0 + CELL * 0.7, top),
				Vector2(x1 - CELL * 0.7, top), Vector2(x1 - CELL * 0.3, top + CELL * 0.9)]), C_HILL)

	# 管道：外壁 → 内腔 → 水
	for e in sim.edge_a.size():
		var pts := _epath(e)
		if sim.edge_kind[e] == "siphon" and not sim.edge_open[e]:
			_draw_dashed_path(pts, Color(C_WALL.r, C_WALL.g, C_WALL.b, 0.55), 14.0)
			continue
		draw_polyline(pts, C_WALL, 22.0, true)
		for k in range(1, pts.size() - 1):
			draw_circle(pts[k], 11.0, C_WALL)
	for e in sim.edge_a.size():
		var pts := _epath(e)
		if sim.edge_kind[e] == "siphon" and not sim.edge_open[e]:
			continue
		draw_polyline(pts, C_BORE, 14.0, true)
		for k in range(1, pts.size() - 1):
			draw_circle(pts[k], 7.0, C_BORE)
	for e in sim.edge_a.size():
		var f: int = sim.edge_from[e]
		if f >= 0:
			var other: int = sim.edge_b[e] if sim.edge_a[e] == f else sim.edge_a[e]
			_draw_water_path(_flow_path(e, f), _edge_flow(e, f, other), sim.node_mask[f])
		elif sim.edge_kind[e] == "valve" and not sim.edge_open[e]:
			# 关着的阀门：两侧有水就各自灌到阀门处（连通器，水会顶到阀门）
			var pa := _npos(sim.edge_a[e])
			var pb := _npos(sim.edge_b[e])
			var mid := pa.lerp(pb, 0.5)
			if _node_wet_vis(sim.edge_a[e]):
				draw_line(pa, mid, _mask_col(sim.node_mask[sim.edge_a[e]]), 10.0, true)
			if _node_wet_vis(sim.edge_b[e]):
				draw_line(pb, mid, _mask_col(sim.node_mask[sim.edge_b[e]]), 10.0, true)

	for i in sim.node_id.size():
		_draw_node(i)
	for e in sim.edge_a.size():
		if sim.edge_kind[e] == "valve":
			_draw_valve(e)
		elif sim.edge_kind[e] == "siphon":
			_draw_siphon_badge(e)

	for d in drops:
		var dc: Color = d["c"]
		dc.a = clampf((d["t"] as float) / (d["t0"] as float), 0.0, 1.0)
		draw_circle(d["p"], 2.6, dc)
	for f in flashes:
		var t: float = f["t"] / 0.7
		var c: Color = f["col"]
		c.a = 1.0 - t
		draw_arc(f["pos"], 18.0 + 60.0 * t, 0.0, TAU, 40, c, 4.0 * (1.0 - t) + 1.0, true)


func _draw_node(i: int) -> void:
	var p := _npos(i)
	var kind: String = sim.node_kind[i]
	var wet_vis := _node_wet_vis(i)
	var wc := _mask_col(sim.node_mask[i])
	match kind:
		"source":
			draw_rect(Rect2(p - Vector2(34, 28), Vector2(68, 56)), C_WALL)
			var inner: Color = wc if sim.started else wc.darkened(0.55)
			draw_rect(Rect2(p - Vector2(28, 22), Vector2(56, 44)), inner)
			_txt("水源", p, 20, Color.WHITE)
		"pipe":
			draw_circle(p, 13.0, C_WALL)
			draw_circle(p, 8.0, wc if wet_vis else C_BORE)
		"goal":
			_draw_goal(i, p, wet_vis)
		"slot":
			_draw_slot(i, p, wet_vis)


func _draw_goal(i: int, p: Vector2, wet_vis: bool) -> void:
	var flora: String = levels[lv_index]["flora"]
	var want: int = sim.node_want[i]
	var m: int = sim.node_mask[i]
	var ok: bool = wet_vis and sim.goal_ok(i)
	var wrong: bool = wet_vis and not ok
	var ring: Color = C_WALL
	if want != 0:
		ring = _mask_col(want)
	if ok:
		var gc: Color = _mask_col(m) if want != 0 else C_GOLD
		draw_circle(p, 42.0, Color(gc.r, gc.g, gc.b, 0.20))
		ring = gc
	elif wrong:
		ring = C_VALVE_CLOSED
	draw_circle(p, 29.0, C_BG)
	draw_arc(p, 29.0, 0.0, TAU, 48, ring, 5.0, true)
	if wet_vis:
		var grow: float = clampf((t_now - float(lit_time.get(i, t_now))) * 1.6, 0.0, 1.0)
		var fc: Color = _mask_col(m) if (flora == "flower") else C_GRASS
		_draw_flora(flora, p + Vector2(0, 2), 22.0, fc, grow)
		if wrong:
			_txt("颜色不对", p + Vector2(0, 46), 16, C_VALVE_CLOSED)
	else:
		# 还没浇到水：一个小小的种子
		draw_circle(p + Vector2(0, 4), 6.0, Color(0.42, 0.34, 0.26))
		if want != 0:
			draw_circle(p + Vector2(0, 4), 3.0, _mask_col(want))
		_txt("终点", p + Vector2(0, 46), 16, C_DIM)


func _draw_slot(i: int, p: Vector2, wet_vis: bool) -> void:
	var rect := Rect2(p - Vector2(26, 30), Vector2(52, 60))
	if sim.has_tank[i]:
		var tc := _mask_col(sim.tank_mask)
		draw_rect(rect, C_WALL)
		var inner := Rect2(rect.position + Vector2(5, 5), rect.size - Vector2(10, 10))
		draw_rect(inner, C_BORE)
		var h := inner.size.y
		draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y - h, inner.size.x, h), tc)
		var top_y: float = inner.position.y + inner.size.y - h
		var wave := PackedVector2Array()
		for k in 9:
			var wx: float = inner.position.x + inner.size.x * float(k) / 8.0
			wave.append(Vector2(wx, top_y + 1.5 + sin(t_now * 3.0 + float(k) * 0.9) * 1.6))
		draw_polyline(wave, _mask_light(sim.tank_mask), 2.0, true)
		_txt("水箱", p + Vector2(0, 46), 16, C_DIM)
	else:
		draw_circle(p, 13.0, C_WALL)
		draw_circle(p, 8.0, _mask_col(sim.node_mask[i]) if wet_vis else C_BORE)
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


func _draw_siphon_badge(e: int) -> void:
	var p := _badge(e)
	var on: bool = sim.edge_open[e]
	draw_circle(p, 19.0, C_BG)
	draw_circle(p, 16.0, C_SIPHON if on else C_BORE)
	draw_arc(p, 16.0, 0.0, TAU, 32, C_SIPHON, 2.5, true)
	_txt("拆" if on else "装", p, 17, C_BG if on else C_SIPHON)
	_txt("虹吸管", p + Vector2(0, 34), 14, C_DIM)
	if hover_kind == "siphon" and hover_id == e:
		draw_arc(p, 23.0, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 2.0, true)
	elif not on and not sim.started and sim.siphons_left > 0:
		var pulse := 0.25 + 0.2 * sin(Time.get_ticks_msec() / 280.0)
		draw_arc(p, 23.0, 0.0, TAU, 32, Color(1, 1, 1, pulse), 2.0, true)


# ───────────────────────── 揭晓 ─────────────────────────
func _solved_sim(lv: Dictionary):
	var s = WaterSim.new()
	s.load_level(lv)
	var sol: Dictionary = lv["solution"]
	for pair in sol["valves"]:
		s.open_valve(s.find_edge(pair[0], pair[1]))
	for t in sol["tanks"]:
		s.toggle_tank(s.find_node(t))
	for pair in sol.get("siphons", []):
		s.toggle_siphon(s.find_edge(pair[0], pair[1]))
	s.start()
	var n := 0
	while n < 400 and not s.settled:
		s.step()
		n += 1
	return s


## key = "grass"/"flower"/"tree" 揭晓一轮；key = "" 揭晓整座花园
func _start_reveal(key: String) -> void:
	reveal_key = key
	mode = "reveal" if key != "" else "garden"
	reveal_t = 0.0
	reveal_entries.clear()
	var min_c := 9999.0
	var min_r := 9999.0
	var max_c := -9999.0
	var max_r := -9999.0
	var last_i := lv_index
	for i in levels.size():
		var lv: Dictionary = levels[i]
		if key != "" and lv["round"] != key:
			continue
		var s = _solved_sim(lv)
		var ox: int = lv["reveal"][0]
		var oy: int = lv["reveal"][1]
		var mc := 0
		for c in s.node_col:
			mc = maxi(mc, c)
		min_c = minf(min_c, float(ox))
		min_r = minf(min_r, float(oy))
		max_c = maxf(max_c, float(ox + mc + 1))
		max_r = maxf(max_r, float(oy + lv["rows"]))
		reveal_entries.append({"sim": s, "lv": lv, "ox": ox, "oy": oy, "i": i})
		last_i = i
	lv_index = last_i
	var w := max_c - min_c
	var h := max_r - min_r
	var sc := minf(minf(1160.0 / (w * CELL), 440.0 / (h * CELL)), 0.55)
	var cell := CELL * sc
	var base := Vector2(640.0 - (min_c + w * 0.5) * cell, 340.0 - (min_r + h * 0.5) * cell)
	reveal_ground = base.y + max_r * cell
	reveal_rect = Rect2(base, Vector2(cell, sc))   # position = 画布原点, size.x = 每格像素, size.y = 缩放比
	reveal_gap = 0.7 if key == "" else 1.4
	_set_play_ui(false)
	lbl_title.text = "揭晓……"
	lbl_hint.text = "你一路解开的管道，拼在一起——"
	lbl_msg.text = ""
	btn_next.disabled = true
	btn_next.text = "继续"
	queue_redraw()


func _process_reveal(delta: float) -> void:
	reveal_t += delta
	t_now += delta
	var total: float = float(reveal_entries.size()) * reveal_gap + 2.6
	if reveal_t >= total and btn_next.disabled:
		btn_next.disabled = false
		if mode == "garden":
			lbl_title.text = "第一章 · 重力篇 · 花园"
			lbl_hint.text = ""
			lbl_msg.text = "三轮，十关，一座花园。你只放了几个水箱、开了几个阀门、装了几根虹吸管——剩下的，是水自己长出来的。"
			btn_next.text = "再玩一遍"
		else:
			lbl_title.text = "揭晓：" + ROUND_NAMES.get(reveal_key, "")
			lbl_hint.text = ""
			lbl_msg.text = reveal_entries[reveal_entries.size() - 1]["lv"]["caption"]
	queue_redraw()


func _draw_reveal() -> void:
	var org: Vector2 = reveal_rect.position
	var cell: float = reveal_rect.size.x
	var sc: float = reveal_rect.size.y
	var n := float(reveal_entries.size())
	# 第二幕：管道淡去，终点长成真正的花草树
	var q: float = clampf((reveal_t - (n * reveal_gap + 0.3)) / 1.6, 0.0, 1.0)
	var a_mul := 1.0 - 0.72 * q
	draw_rect(Rect2(0, 640, VIEW_W, 80), Color(0.10, 0.16, 0.12))
	var goals := {"grass": [], "flower": [], "leaf": []}
	for k in reveal_entries.size():
		var en: Dictionary = reveal_entries[k]
		var g: float = clampf((reveal_t - float(k) * reveal_gap) / (reveal_gap * 0.9), 0.0, 1.0)
		if g <= 0.0:
			continue
		var s = en["sim"]
		var lorg: Vector2 = org + Vector2(float(en["ox"]), float(en["oy"])) * cell
		var wd := maxf(2.0, 22.0 * sc)
		var al := g * a_mul
		for e in s.edge_a.size():
			if s.edge_kind[e] == "siphon" and not s.edge_open[e]:
				continue
			if s.edge_kind[e] == "valve" and not s.edge_open[e]:
				continue
			var pts := _epath_g(s, e, lorg, cell)
			draw_polyline(pts, Color(C_WALL.r, C_WALL.g, C_WALL.b, al), wd, true)
			for qq in range(1, pts.size() - 1):
				draw_circle(pts[qq], wd * 0.5, Color(C_WALL.r, C_WALL.g, C_WALL.b, al))
		for e in s.edge_a.size():
			if s.edge_from[e] < 0:
				continue
			var pts2 := _epath_g(s, e, lorg, cell)
			var wc := _mask_col(s.node_mask[s.edge_from[e]])
			wc.a = al
			draw_polyline(pts2, wc, wd * 0.6, true)
			for qq in range(1, pts2.size() - 1):
				draw_circle(pts2[qq], wd * 0.3, wc)
		var flora: String = en["lv"]["flora"]
		for i in s.node_id.size():
			var p: Vector2 = _npos_g(s, i, lorg, cell)
			if s.node_kind[i] == "goal":
				var fc: Color = _mask_col(s.node_mask[i]) if flora == "flower" else C_GRASS
				goals[flora].append({"p": p, "c": fc, "g": g})
			elif s.node_kind[i] == "source":
				draw_circle(p, wd * 0.8, Color(_mask_col(s.node_mask[i]), al))
	var gy := reveal_ground
	# 花的茎、树干和树枝（在花叶后面）
	for it in goals["flower"]:
		var fp: Vector2 = it["p"]
		draw_line(fp, Vector2(fp.x, gy), Color(C_GRASS_DARK, q), maxf(2.0, 16.0 * sc * q), true)
	var leaves: Array = goals["leaf"]
	if leaves.size() > 0 and q > 0.0:
		var cx := 0.0
		var ay := 0.0
		for it in leaves:
			cx += (it["p"] as Vector2).x
			ay += (it["p"] as Vector2).y
		cx /= float(leaves.size())
		ay /= float(leaves.size())
		var top := Vector2(cx, lerpf(ay, gy, 0.3))
		var brown := Color(0.45, 0.30, 0.18, q)
		draw_line(Vector2(cx, gy), top, brown, maxf(4.0, 60.0 * sc * q), true)
		for it in leaves:
			draw_line(top, it["p"], brown, maxf(2.0, 24.0 * sc * q), true)
	# 花草树本体
	var base_sz := maxf(14.0, 70.0 * sc)
	var big := base_sz * (1.0 + 1.4 * q)
	for kind in ["grass", "flower", "leaf"]:
		for it in goals[kind]:
			var c: Color = it["c"]
			_draw_flora(kind, it["p"], big, c, it["g"])
