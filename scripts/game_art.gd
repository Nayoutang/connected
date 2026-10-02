extends RefCounted
## Downloaded open assets. See assets/THIRD_PARTY.md for authors and licenses.
## All draw calls are made from Main._draw(), preserving the simulation graph.

const PIPE_DRY = preload("res://assets/kenney/pipeGrey_26.png")
const PIPE_WET = preload("res://assets/kenney/pipeGrey_32.png")
const VALVE = preload("res://assets/icons/valve.svg")
const SPRING = preload("res://assets/icons/spring.svg")
const TANK = preload("res://assets/icons/water-tank.svg")
const SOURCE = preload("res://assets/icons/water-fountain.svg")
const DROP = preload("res://assets/icons/water-drop.svg")

const AQUA := Color("53d5f2")
const METAL := Color("a8bfce")
const PANEL := Color("152736")
const CLOSED := Color("ff7c79")
const OPEN := Color("78e0ae")
const GOLD := Color("ffd277")
const PIPE_WIDTH := 30.0

func edge(game: Node2D, e: int) -> void:
	var a: Vector2 = game._npos(game.sim.edge_a[e])
	var b: Vector2 = game._npos(game.sim.edge_b[e])
	var length := a.distance_to(b)
	if length <= 0.0:
		return
	game.draw_set_transform(a, (b - a).angle())
	var count := maxi(1, ceili(length / 72.0))
	var span := length / count
	var wet_start := 0.0
	var wet_end := 0.0
	if game.sim.edge_from[e] >= 0:
		var progress: float = game._edge_progress(e)
		if game.sim.edge_from[e] == game.sim.edge_a[e]:
			wet_end = length * progress
		else:
			wet_start = length * (1.0 - progress)
			wet_end = length
	for segment in count:
		var x := segment * span
		var rect := Rect2(x, -PIPE_WIDTH / 2.0, span, PIPE_WIDTH)
		game.draw_texture_rect(PIPE_DRY, rect, false, Color("718b9e"))
		if wet_end > wet_start:
			_fill(game, x, span, wet_start, wet_end)
		elif game.sim.edge_kind[e] != "pipe" and not game.sim.edge_open[e]:
			# Closed valves still allow water to accumulate on either side.
			if game._node_wet_vis(game.sim.edge_a[e]):
				_fill(game, x, span, 0.0, length * 0.5)
			if game._node_wet_vis(game.sim.edge_b[e]):
				_fill(game, x, span, length * 0.5, length)
	game.draw_set_transform(Vector2.ZERO)

func _fill(game: Node2D, x: float, span: float, start: float, end: float) -> void:
	var left := maxf(x, start)
	var right := minf(x + span, end)
	if right <= left:
		return
	var size: Vector2 = PIPE_WET.get_size()
	var region := Rect2((left - x) / span * size.x, 0, (right - left) / span * size.x, size.y)
	game.draw_texture_rect_region(PIPE_WET, Rect2(left, -PIPE_WIDTH / 2.0, right - left, PIPE_WIDTH), region)

func _icon(game: Node2D, texture: Texture2D, p: Vector2, size: float, color: Color) -> void:
	game.draw_texture_rect(texture, Rect2(p - Vector2.ONE * size / 2.0, Vector2.ONE * size), false, color)

func _plate(game: Node2D, p: Vector2, radius: float, color: Color) -> void:
	game.draw_circle(p + Vector2(0, 3), radius + 3.0, Color(0, 0, 0, 0.28))
	game.draw_circle(p, radius, PANEL)
	game.draw_arc(p, radius, 0, TAU, 48, color, 2.0, true)

func _caption(game: Node2D, text: String, p: Vector2, color: Color) -> void:
	var width: float = game.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 14
	game.draw_style_box(_caption_style(), Rect2(p - Vector2(width / 2, 11), Vector2(width, 22)))
	game._txt(text, p, 14, color)

var caption_style: StyleBoxFlat

func _caption_style() -> StyleBoxFlat:
	if caption_style == null:
		caption_style = StyleBoxFlat.new()
		caption_style.bg_color = Color("10202e")
		caption_style.set_corner_radius_all(6)
	return caption_style

func node(game: Node2D, i: int) -> void:
	var p: Vector2 = game._npos(i)
	var wet: bool = game._node_wet_vis(i)
	match game.sim.node_kind[i]:
		"source":
			_plate(game, p, 30, AQUA)
			_icon(game, SOURCE, p, 43, AQUA)
			_caption(game, "水源", p + Vector2(0, 40), AQUA)
		"pipe":
			# Compact couplings join arbitrary-angle pipe segments.
			game.draw_circle(p, 12, METAL)
			game.draw_circle(p, 9, AQUA if wet else PANEL)
			game.draw_arc(p, 12, PI, TAU, 16, Color("e0ecf2"), 2, true)
		"goal":
			var color := GOLD if wet else METAL
			if wet:
				game.draw_circle(p, 36, Color(GOLD, 0.12))
			_plate(game, p, 27, color)
			_icon(game, DROP, p, 35, color)
			_caption(game, "已连通" if wet else "终点", p + Vector2(0, 37), color)
		"slot":
			slot(game, i, p, wet)

func slot(game: Node2D, i: int, p: Vector2, wet: bool) -> void:
	var placed: bool = game.sim.has_tank[i]
	var hovered: bool = game.hover_kind == "slot" and game.hover_id == i
	var color := AQUA if placed else Color("6f879b")
	_plate(game, p, 29, Color.WHITE if hovered else color)
	_icon(game, TANK, p, 44, color if placed else Color(color, 0.55))
	if not placed:
		game.draw_circle(p + Vector2(23, -21), 10, PANEL)
		game._txt("+" if not game.sim.started else "·", p + Vector2(23, -21), 20, AQUA if wet else METAL)
	var caption := "满水箱" if placed else ("空槽" if game.sim.started else "放水箱")
	_caption(game, caption, p + Vector2(0, 40), color)

func valve(game: Node2D, e: int) -> void:
	var p: Vector2 = game._emid(e)
	var opened: bool = game.sim.edge_open[e]
	var color := OPEN if opened else CLOSED
	_plate(game, p, 28, color)
	_icon(game, VALVE, p - Vector2(0, 1), 45, color)
	var caption := "已开启" if opened else ("次数已用完" if game.sim.valves_left == 0 else "点击开阀")
	_caption(game, caption, p + Vector2(0, 38), color)
	if game.hover_kind == "valve" and game.hover_id == e:
		game.draw_arc(p, 33, 0, TAU, 48, Color.WHITE, 2, true)
	elif not opened and game.sim.valves_left > 0:
		var alpha := 0.22 + 0.12 * sin(Time.get_ticks_msec() / 280.0)
		game.draw_arc(p, 33, 0, TAU, 48, Color(color, alpha), 2, true)

func spring(game: Node2D, e: int) -> void:
	var p: Vector2 = game._emid(e)
	var opened: bool = game.sim.edge_open[e]
	var color := OPEN if opened else GOLD
	var threshold: int = game.sim.edge_thr[e]
	var count: int = mini(game.sim.flow[game.sim.edge_a[e]], threshold)
	_plate(game, p, 28, color)
	_icon(game, SPRING, p, 36, color)
	var progress := 1.0 if opened else float(count) / maxf(1, threshold)
	if progress > 0:
		game.draw_arc(p, 33, -PI / 2, -PI / 2 + TAU * progress, 48, color, 3, true)
	_caption(game, "已弹开" if opened else "蓄水 %d/%d" % [count, threshold], p + Vector2(0, 41), color)
