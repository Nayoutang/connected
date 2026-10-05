extends RefCounted
## 开源美术素材的绘制层。来源与许可见 assets/THIRD_PARTY.md。
## 所有绘制由 Main._draw() 调用，不改动模拟图；水的颜色/流动动画仍由 main.gd 负责，
## 这里负责管壳（Kenney 管道贴图，沿折线重复）、节点图标和终点的花草树外框。

const PIPE_DRY = preload("res://assets/kenney/pipeGrey_26.png")
const PIPE_WET = preload("res://assets/kenney/pipeGrey_32.png")
const DROP = preload("res://assets/icons/water-drop.svg")
const VALVE = preload("res://assets/icons/valve.svg")
const TANK = preload("res://assets/icons/water-tank.svg")
const SOURCE = preload("res://assets/icons/water-fountain.svg")

const AQUA := Color("53d5f2")
const METAL := Color("a8bfce")
const PANEL := Color("152736")
const CLOSED := Color("ff7c79")
const OPEN := Color("78e0ae")
const GOLD := Color("ffd277")
const PIPE_WIDTH := 30.0
const SOURCE_NAMES := {0: "水源", 1: "红水", 2: "蓝水", 4: "黄水"}
const WANT_NAMES := {1: "红花", 2: "蓝花", 3: "紫花", 4: "黄花", 5: "橙花", 6: "绿花", 7: "褐花"}


## 管壳：每一小段折线用管道贴图重复铺开。没装上的虹吸管画成半透明。
func edge(game: Node2D, e: int) -> void:
	var pts: PackedVector2Array = game._epath(e)
	var ghost: bool = game.sim.edge_kind[e] == "siphon" and not game.sim.edge_open[e]
	var tint := Color("718b9e")
	if ghost:
		tint.a = 0.30
	for k in range(pts.size() - 1):
		_strip(game, pts[k], pts[k + 1], tint)
	if not ghost:
		for k in range(1, pts.size() - 1):
			game.draw_circle(pts[k], PIPE_WIDTH * 0.5, METAL.darkened(0.25))


func _strip(game: Node2D, a: Vector2, b: Vector2, tint: Color) -> void:
	var length := a.distance_to(b)
	if length <= 0.0:
		return
	game.draw_set_transform(a, (b - a).angle())
	var count := maxi(1, ceili(length / 72.0))
	var span := length / count
	for segment in count:
		game.draw_texture_rect(PIPE_DRY, Rect2(segment * span, -PIPE_WIDTH / 2.0, span, PIPE_WIDTH), false, tint)
	game.draw_set_transform(Vector2.ZERO)


func _icon(game: Node2D, texture: Texture2D, p: Vector2, size: float, color: Color) -> void:
	game.draw_texture_rect(texture, Rect2(p - Vector2.ONE * size / 2.0, Vector2.ONE * size), false, color)


func plate(game: Node2D, p: Vector2, radius: float, color: Color) -> void:
	game.draw_circle(p + Vector2(0, 3), radius + 3.0, Color(0, 0, 0, 0.28))
	game.draw_circle(p, radius, PANEL)
	game.draw_arc(p, radius, 0, TAU, 48, color, 2.0, true)


var caption_style: StyleBoxFlat


func _caption_style() -> StyleBoxFlat:
	if caption_style == null:
		caption_style = StyleBoxFlat.new()
		caption_style.bg_color = Color("10202e")
		caption_style.set_corner_radius_all(6)
	return caption_style


func caption(game: Node2D, text: String, p: Vector2, color: Color) -> void:
	var width: float = game.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 14
	game.draw_style_box(_caption_style(), Rect2(p - Vector2(width / 2, 11), Vector2(width, 22)))
	game._txt(text, p, 14, color)


func node(game: Node2D, i: int) -> void:
	var p: Vector2 = game._npos(i)
	var wet: bool = game._node_wet_vis(i)
	var sim = game.sim
	match sim.node_kind[i]:
		"source":
			var c: Color = game._mask_col(sim.node_mask[i]) if sim.node_mask[i] != 0 else AQUA
			plate(game, p, 30, c)
			_icon(game, SOURCE, p, 43, c)
			caption(game, SOURCE_NAMES.get(sim.node_mask[i], "水源"), p + Vector2(0, 40), c)
		"pipe":
			game.draw_circle(p, 12, METAL)
			game.draw_circle(p, 9, game._mask_col(sim.node_mask[i]) if wet else PANEL)
			game.draw_arc(p, 12, PI, TAU, 16, Color("e0ecf2"), 2, true)
		"goal":
			goal(game, i, p, wet)
		"slot":
			slot(game, i, p, wet)


## 终点：外框 + 里面长出来的草/花/叶。花的颜色 = 浇它的水的颜色。
func goal(game: Node2D, i: int, p: Vector2, wet: bool) -> void:
	var sim = game.sim
	var flora: String = game.levels[game.lv_index]["flora"]
	var want: int = sim.node_want[i]
	var m: int = sim.node_mask[i]
	var ok: bool = wet and sim.goal_ok(i)
	var wrong: bool = wet and not ok
	var ring := METAL
	if want != 0:
		ring = game._mask_col(want)
	if ok:
		ring = game._mask_col(m) if want != 0 else GOLD
		game.draw_circle(p, 42.0, Color(ring, 0.20))
	elif wrong:
		ring = CLOSED
	plate(game, p, 29, ring)
	var cap := "终点"
	if wet:
		var grow: float = clampf((game.t_now - float(game.lit_time.get(i, game.t_now))) * 1.6, 0.0, 1.0)
		var fc: Color = game._mask_col(m) if flora == "flower" else game.C_GRASS
		game._draw_flora(flora, p + Vector2(0, 2), 22.0, fc, grow)
		cap = "颜色不对" if wrong else "已连通"
	else:
		game.draw_circle(p + Vector2(0, 4), 6.0, Color(0.42, 0.34, 0.26))
		if want != 0:
			game.draw_circle(p + Vector2(0, 4), 3.0, game._mask_col(want))
			cap = WANT_NAMES.get(want, "终点")
	caption(game, cap, p + Vector2(0, 40), ring if (wet or want != 0) else METAL)


func slot(game: Node2D, i: int, p: Vector2, wet: bool) -> void:
	var sim = game.sim
	var placed: bool = sim.has_tank[i]
	var hovered: bool = game.hover_kind == "slot" and game.hover_id == i
	var tank_col: Color = game._mask_col(sim.tank_mask) if sim.tank_mask != 0 else AQUA
	var color := tank_col if placed else Color("6f879b")
	plate(game, p, 29, Color.WHITE if hovered else color)
	_icon(game, TANK, p, 44, color if placed else Color(color, 0.55))
	if not placed:
		game.draw_circle(p + Vector2(23, -21), 10, PANEL)
		game._txt("+" if not sim.started else "·", p + Vector2(23, -21), 20, game._mask_col(sim.node_mask[i]) if wet else METAL)
	var cap := "满水箱" if placed else ("空槽" if sim.started else "放水箱")
	caption(game, cap, p + Vector2(0, 40), color)


func valve(game: Node2D, e: int) -> void:
	var p: Vector2 = game._emid(e)
	var opened: bool = game.sim.edge_open[e]
	var color := OPEN if opened else CLOSED
	plate(game, p, 28, color)
	_icon(game, VALVE, p - Vector2(0, 1), 45, color)
	var cap := "已开启" if opened else ("次数已用完" if game.sim.valves_left == 0 else "点击开阀")
	caption(game, cap, p + Vector2(0, 38), color)
	if game.hover_kind == "valve" and game.hover_id == e:
		game.draw_arc(p, 33, 0, TAU, 48, Color.WHITE, 2, true)
	elif not opened and game.sim.valves_left > 0:
		var alpha := 0.22 + 0.12 * sin(Time.get_ticks_msec() / 280.0)
		game.draw_arc(p, 33, 0, TAU, 48, Color(color, alpha), 2, true)
