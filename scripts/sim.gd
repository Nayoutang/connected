extends RefCounted
## 水管模拟核心（纯逻辑，不含任何绘制）。
##
## 规则一句话版：
##  1. 重力：每个节点有高度(elev)。水带着"水头"(head)流动，只能到达 高度 <= 水头 的节点。
##  2. 连通器：水位不衰减，中间先下后上也能过去，只要不高于水位。
##  3. 阀门：手动阀门默认关闭，玩家可打开（次数有限）。
##  4. 水箱：装满水的蓄水箱，放在空位上就成为一个新水源，水位 = 所在高度（纯重力，没有任何抬升）。
##  5. 虹吸管：架在山脊上的弧形管，装上后水能翻过比水位还高的山头（最多高出 3 格），
##     但出口必须严格低于进水端的水位——和水位一样高都不行。
##  6. 颜色：水源可以带色（R红 B蓝 Y黄）。同高或高处流下来的水汇进来时会混色（红+蓝=紫…）；
##     往上流时只是水位找平，不混色。终点可以要求特定颜色（花的颜色 = 水的颜色）。

const FRICTION := 0.0   # 不再有损耗：水位只由水源/水塔决定
const SRC_BONUS := 0.0  # 水源水位 = 水源所在高度
const TANK_BONUS := 0.0 # 水箱是装满水的蓄水箱：水位 = 它所在的高度
const TANK_CAP := 3
const SIPHON_LIFT := 3.0   # 虹吸最多能把水抬到比水位高 3 格
const EPS := 0.0001

var rows := 6
var node_id: Array = []
var node_kind: Array = []   # source / pipe / goal / slot
var node_col: Array = []
var node_row: Array = []
var elev: Array = []
var node_mask: Array = []   # 水的颜色（位掩码，0 = 清水）
var node_want: Array = []   # 终点要求的颜色（0 = 不限）

var edge_a: Array = []
var edge_b: Array = []
var edge_kind: Array = []   # pipe / valve
var edge_len: Array = []
var edge_apex: Array = []      # 虹吸管最高点的高度（非虹吸 = -1）
var edge_apex_row: Array = []  # 虹吸管最高点所在行（画图用）
var edge_open: Array = []
var edge_from: Array = []   # 水最先从哪个节点流入这条边（-1 = 还没水）
var edge_t0: Array = []     # 水开始流入这条边的 tick

var wet: Array = []
var head: Array = []
var has_tank: Array = []
var tank_fill: Array = []
var tank_full: Array = []

var tick := 0
var started := false
var settled := false
var valves_left := 0
var tanks_left := 0
var siphons_left := 0
var tank_mask := 0
var events: Array = []
var _index := {}


const COLORS := {"R": 1, "B": 2, "Y": 4}


static func mask_of(letters: String) -> int:
	var m := 0
	for ch in letters:
		m |= int(COLORS.get(ch, 0))
	return m


func load_level(lv: Dictionary) -> void:
	rows = lv["rows"]
	valves_left = lv["valves"]
	tanks_left = lv["tanks"]
	siphons_left = int(lv.get("siphons", 0))
	tank_mask = mask_of(str(lv.get("tank_color", "")))
	var i := 0
	for nd in lv["nodes"]:
		_index[nd[0]] = i
		node_id.append(nd[0])
		node_kind.append(nd[1])
		node_col.append(nd[2])
		node_row.append(nd[3])
		elev.append(float(rows - int(nd[3])))
		var cm: int = mask_of(str(nd[4])) if nd.size() > 4 else 0
		node_mask.append(cm if nd[1] == "source" else 0)
		node_want.append(cm if nd[1] == "goal" else 0)
		wet.append(false)
		head.append(0.0)
		has_tank.append(false)
		tank_fill.append(0)
		tank_full.append(false)
		i += 1
	for ed in lv["edges"]:
		var a: int = _index[ed[0]]
		var b: int = _index[ed[1]]
		var kind: String = ed[2] if ed.size() > 2 else "pipe"
		edge_a.append(a)
		edge_b.append(b)
		edge_kind.append(kind)
		edge_len.append(float(abs(node_col[a] - node_col[b]) + abs(node_row[a] - node_row[b])))
		edge_open.append(kind == "pipe")
		if kind == "siphon":
			edge_apex_row.append(int(ed[3]))
			edge_apex.append(float(rows - int(ed[3])))
		else:
			edge_apex_row.append(-1)
			edge_apex.append(-1.0)
		edge_from.append(-1)
		edge_t0.append(0)


func find_node(id: String) -> int:
	return _index[id]


func find_edge(id_a: String, id_b: String) -> int:
	var a: int = _index[id_a]
	var b: int = _index[id_b]
	for e in edge_a.size():
		if (edge_a[e] == a and edge_b[e] == b) or (edge_a[e] == b and edge_b[e] == a):
			return e
	return -1


func start() -> void:
	started = true
	settled = false
	for i in node_id.size():
		if node_kind[i] == "source":
			wet[i] = true
			head[i] = elev[i] + SRC_BONUS
		elif has_tank[i]:
			wet[i] = true
			tank_full[i] = true
			head[i] = elev[i] + TANK_BONUS


func toggle_tank(i: int) -> bool:
	if started or node_kind[i] != "slot":
		return false
	if has_tank[i]:
		has_tank[i] = false
		tanks_left += 1
		return true
	if tanks_left > 0:
		has_tank[i] = true
		tanks_left -= 1
		return true
	return false


func toggle_siphon(e: int) -> bool:
	if started or e < 0 or edge_kind[e] != "siphon":
		return false
	if edge_open[e]:
		edge_open[e] = false
		siphons_left += 1
		return true
	if siphons_left > 0:
		edge_open[e] = true
		siphons_left -= 1
		return true
	return false


func open_valve(e: int) -> bool:
	if e < 0 or edge_kind[e] != "valve" or edge_open[e] or valves_left <= 0:
		return false
	edge_open[e] = true
	valves_left -= 1
	settled = false
	return true


func goals_total() -> int:
	var n := 0
	for i in node_id.size():
		if node_kind[i] == "goal":
			n += 1
	return n


func goal_ok(i: int) -> bool:
	return node_kind[i] == "goal" and wet[i] and (node_want[i] == 0 or node_mask[i] == node_want[i])


func goals_lit() -> int:
	var n := 0
	for i in node_id.size():
		if goal_ok(i):
			n += 1
	return n


## 浇到了水、但颜色不对的终点数
func goals_wrong() -> int:
	var n := 0
	for i in node_id.size():
		if node_kind[i] == "goal" and wet[i] and not goal_ok(i):
			n += 1
	return n


func all_lit() -> bool:
	return goals_lit() == goals_total()


## 推进一个 tick：水前沿每 tick 只前进一条边，方便看到"涌"的过程。
func step() -> void:
	events.clear()
	var changed := false
	var pw: Array = wet.duplicate()
	var ph: Array = head.duplicate()
	var pm: Array = node_mask.duplicate()

	# 1) 水箱蓄水
	for i in node_id.size():
		if has_tank[i] and pw[i] and not tank_full[i]:
			tank_fill[i] += 1
			changed = true
			if tank_fill[i] >= TANK_CAP:
				tank_full[i] = true
				head[i] = elev[i] + TANK_BONUS
				events.append(["tank", i])

	# 2) 水沿开着的边传播
	for e in edge_a.size():
		if not edge_open[e]:
			continue
		for dir in 2:
			var s: int = edge_a[e] if dir == 0 else edge_b[e]
			var d: int = edge_b[e] if dir == 0 else edge_a[e]
			if not pw[s]:
				continue
			if has_tank[s] and not tank_full[s]:
				continue  # 水箱没蓄满，不往外放
			if node_kind[d] == "source" or (has_tank[d] and tank_full[d]):
				continue
			var hs: float = head[s] if has_tank[s] else ph[s]
			var h2: float = hs - FRICTION * edge_len[e]
			if edge_kind[e] == "siphon":
				if h2 <= elev[d] + EPS:
					continue  # 虹吸：出口必须严格低于水位
				if edge_apex[e] > hs + SIPHON_LIFT + EPS:
					continue  # 山头太高，吸不上去
			elif h2 + EPS < elev[d]:
				continue  # 爬不上去
			var first: bool = not wet[d]
			if first or h2 > head[d] + EPS:
				wet[d] = true
				head[d] = h2
				changed = true
			if edge_from[e] < 0:
				edge_from[e] = s   # 水第一次流过这条管子（两头都早就有水的管子也要"流满"）
				edge_t0[e] = tick
				changed = true
			if first:
				node_mask[d] = pm[s]
				changed = true
			elif elev[s] >= elev[d] - EPS:
				var nm: int = node_mask[d] | pm[s]   # 平着或从高处流下来的水才会混色
				if nm != node_mask[d]:
					node_mask[d] = nm
					changed = true

	# 3) 是否仍在蓄水
	var pending := false
	for i in node_id.size():
		if has_tank[i] and wet[i] and not tank_full[i]:
			pending = true

	tick += 1
	settled = (not changed) and (not pending)
