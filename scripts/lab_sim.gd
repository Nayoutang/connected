extends RefCounted
## Discrete, conservative reservoir network. One snapshot -> proposals ->
## donor/receiver limits -> simultaneous update. Display positions are not heights.

const EPS := 0.00001
var nodes: Array = []
var edges: Array = []
var floats: Array = []
var inventory: Dictionary = {}
var rules: Dictionary = {}
var tick := 0
var started := false
var won := false
var failed := false
var stable_ticks := 0
var operations := 0
var automatic_actions := 0
var initial_water := 0.0
var drained := 0.0
var wasted := 0.0
var initial_source := 0.0
var last_error := ""

func load_level(level: Dictionary) -> void:
	nodes = level["nodes"].duplicate(true)
	edges = level["edges"].duplicate(true)
	floats.clear()
	inventory = level["inventory"].duplicate(true)
	rules = level.duplicate(true)
	tick = 0
	started = false
	won = false
	failed = false
	stable_ticks = 0
	operations = 0
	automatic_actions = 0
	drained = 0.0
	wasted = 0.0
	initial_water = 0.0
	initial_source = 0.0
	last_error = ""
	for n in nodes:
		n["volume"] = float(n.get("volume", 0.0))
		n["installed"] = n.get("kind", "tank") != "socket"
		n["route"] = 0
		n["area"] = float(n.get("area", 1.0))
		initial_water += n["volume"]
		if n["kind"] == "source":
			initial_source += n["volume"]
	for e in edges:
		e["open"] = e.get("open", true)
		e["check"] = 0
		e["flow"] = 0.0

func node(id: String) -> Dictionary:
	for n in nodes:
		if n["id"] == id:
			return n
	return {}

func edge(id: String) -> Dictionary:
	for e in edges:
		if e["id"] == id:
			return e
	return {}

func _error(message: String) -> bool:
	last_error = message
	return false

func place_tank(id: String) -> bool:
	var n := node(id)
	if started or n.is_empty() or n["kind"] != "socket":
		return _error("只可在准备阶段的水箱底座安装或拆除。")
	if n["installed"]:
		remove_float(id)
		n["installed"] = false
		inventory["tank"] += 1
	elif inventory.get("tank", 0) > 0:
		n["installed"] = true
		inventory["tank"] -= 1
	else:
		return _error("水箱已用完；可先拆除其他底座上的水箱。")
	return true

func cycle_check(id: String) -> bool:
	var e := edge(id)
	if started or e.is_empty():
		return _error("单向阀只能在准备阶段调整。")
	if e["check"] == 0:
		if inventory.get("check", 0) <= 0:
			return _error("单向阀已用完；可拆下其他管道上的单向阀。")
		inventory["check"] -= 1
		e["check"] = 1
	elif e["check"] == 1:
		e["check"] = -1
	else:
		e["check"] = 0
		inventory["check"] += 1
	return true

func is_controlled(target: String) -> bool:
	for f in floats:
		if f["target"] == target:
			return true
	return false

func actuate(target: String) -> bool:
	if won or failed:
		return _error("本轮已结束，请重置后尝试新方案。")
	if started and is_controlled(target):
		return _error("这个装置由浮子接管；重置后可更改控制连接。")
	var n := node(target)
	var e := edge(target)
	if not n.is_empty() and n["kind"] == "router":
		n["route"] = 1 - int(n["route"])
	elif not e.is_empty() and e["kind"] == "valve":
		e["open"] = not e["open"]
	else:
		return _error("请选择可开关阀门或三通换向阀。")
	operations += 1
	return true

func remove_float(id: String) -> bool:
	if started:
		return _error("浮子连接只能在准备阶段调整。")
	for i in range(floats.size() - 1, -1, -1):
		if floats[i]["sensor"] == id:
			floats.remove_at(i)
			inventory["float"] += 1
	return true

func link_float(sensor: String, target: String, low: float, high: float, inverted: bool = false) -> bool:
	var n := node(sensor)
	var target_node := node(target)
	var target_edge := edge(target)
	if started or n.is_empty() or not n["installed"]:
		return _error("请选择已安装的容器，在准备阶段连接浮子。")
	if low < 0 or high <= low or high > float(n["capacity"]):
		return _error("阈值需满足：0 ≤ 下限 < 上限 ≤ 容量。")
	if not ((not target_node.is_empty() and target_node["kind"] == "router") or (not target_edge.is_empty() and target_edge["kind"] == "valve")):
		return _error("浮子目标必须是换向阀或可开关阀门。")
	var replacing := false
	for f in floats:
		if f["sensor"] == sensor:
			replacing = true
		elif f["target"] == target:
			return _error("一个装置只能由一个浮子控制，避免指令冲突。")
	if not replacing and inventory.get("float", 0) <= 0:
		return _error("没有剩余浮子。")
	remove_float(sensor)
	inventory["float"] -= 1
	floats.append({"sensor": sensor, "target": target, "low": low, "high": high, "inverted": inverted, "active": false})
	return true

func start() -> void:
	if not started:
		started = true

func head(n: Dictionary) -> float:
	return float(n["height"]) + float(n["volume"]) / float(n["area"])

func _controllers() -> void:
	for f in floats:
		var volume: float = node(f["sensor"])["volume"]
		if volume >= float(f["high"]) - EPS:
			f["active"] = true
		elif volume <= float(f["low"]) + EPS:
			f["active"] = false
		var active: bool = f["active"] != f["inverted"]
		var n := node(f["target"])
		if not n.is_empty():
			var route := 1 if active else 0
			if n["route"] != route:
				automatic_actions += 1
				n["route"] = route
		else:
			var e := edge(f["target"])
			if e["open"] != (not active):
				automatic_actions += 1
				e["open"] = not active

func step() -> void:
	if not started or won or failed:
		return
	_controllers()
	var outgoing := {}
	var incoming := {}
	var changes := {}
	var demands: Array = []
	for n in nodes:
		outgoing[n["id"]] = 0.0
		incoming[n["id"]] = 0.0
		changes[n["id"]] = 0.0
	for e in edges:
		e["flow"] = 0.0
		var a := node(e["a"])
		var b := node(e["b"])
		if not a["installed"] or not b["installed"] or not e["open"]:
			continue
		if e.has("router") and node(e["router"])["route"] != e["port"]:
			continue
		var difference := head(a) - head(b)
		if absf(difference) < EPS:
			continue
		var sign_flow := 1 if difference > 0 else -1
		if e["check"] != 0 and e["check"] != sign_flow:
			continue
		var source: Dictionary = a if sign_flow == 1 else b
		var destination: Dictionary = b if sign_flow == 1 else a
		# Limit by equalization volume as well as per-tick throughput.
		var amount := minf(float(e.get("rate", 1.0)), absf(difference) / (1.0 / float(a["area"]) + 1.0 / float(b["area"])))
		amount = minf(amount, float(source["volume"]))
		if amount <= EPS:
			continue
		demands.append({"edge": e, "src": source["id"], "dst": destination["id"], "amount": amount, "sign": sign_flow})
		outgoing[source["id"]] += amount
	for d in demands:
		var available: float = node(d["src"])["volume"]
		d["amount"] *= minf(1.0, available / float(outgoing[d["src"]]))
		incoming[d["dst"]] += d["amount"]
	for d in demands:
		var dest := node(d["dst"])
		var free := float(dest["capacity"]) - float(dest["volume"])
		var amount: float = d["amount"] * minf(1.0, maxf(0, free) / float(incoming[d["dst"]]))
		changes[d["src"]] -= amount
		changes[d["dst"]] += amount
		d["edge"]["flow"] = amount * int(d["sign"])
	for n in nodes:
		# Drains consume only snapshot water, so incoming water cannot teleport out.
		var consumed := minf(float(n.get("drain", 0.0)), maxf(0.0, float(n["volume"]) + minf(0.0, changes[n["id"]])))
		drained += consumed
		n["volume"] += changes[n["id"]] - consumed
		# Overflow is a visible, accounted loss rather than silently deleting water.
		var overflow := maxf(0.0, float(n["volume"]) - float(n.get("spill_at", n["capacity"])))
		n["volume"] -= overflow
		wasted += overflow
		drained += overflow
	tick += 1
	stable_ticks = stable_ticks + 1 if goals_met() else 0
	failed = wasted > float(rules.get("max_waste", 1000000.0)) + EPS
	if failed:
		last_error = "水箱超过安全水位，发生溢流。请调整控制阈值或及时关阀。"
	won = not failed and stable_ticks >= int(rules.get("hold_ticks", 3))
	if not won and tick >= int(rules.get("max_ticks", 240)):
		failed = true
		last_error = "本轮时间用尽，请调整装置或尝试另一条水路。"

func goals_met() -> bool:
	var count := 0
	for n in nodes:
		if n.has("target"):
			count += 1
			if float(n["volume"]) + EPS < float(n["target"]):
				return false
	return count > 0

func total_water() -> float:
	var total := 0.0
	for n in nodes:
		total += float(n["volume"])
	return total

func source_water() -> float:
	var total := 0.0
	for n in nodes:
		if n["kind"] == "source":
			total += float(n["volume"])
	return total

func device_count() -> int:
	var count := floats.size()
	for n in nodes:
		if n["kind"] == "router" or (n["kind"] == "socket" and n["installed"]):
			count += 1
	for e in edges:
		if e["kind"] == "valve":
			count += 1
		if e["check"] != 0:
			count += 1
	return count

func score_text() -> String:
	return "取水 %.1f L · 用水 %.1f L · 溢流 %.1f L · 手动 %d 次\n装置 %d 个 · 自动动作 %d 次 · 用时 %.1f 秒" % [initial_source - source_water(), drained - wasted, wasted, operations, device_count(), automatic_actions, tick * 0.35]
