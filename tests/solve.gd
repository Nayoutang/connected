extends SceneTree
## 解的枚举器：godot --headless --path . --script res://tests/solve.gd
## 对每一关（levels.gd + levels/*.txt）穷举「开哪些阀门 × 水箱放哪些空位」，报告：
##  - 一共多少种能通关的摆法，其中「最简解」（去掉任何一步就不行）多少种
##  - 每个最简解：耗时(tick)、是否所有管子都被水流经（否 = 有死胡同）、用了哪些步骤
##  - 设计提示：无解 / 只有唯一解 / 解太多 / 有死胡同

const Levels = preload("res://scripts/chapter1.gd")
const LevelText = preload("res://scripts/level_text.gd")
const WaterSim = preload("res://scripts/sim.gd")


func _init() -> void:
	var all: Array = Levels.get_levels()
	all.append_array(LevelText.load_dir("res://levels"))
	for i in all.size():
		_report(i + 1, all[i])
	quit(0)


func _combos(items: Array, max_k: int) -> Array:
	var out: Array = [[]]
	for k in range(1, mini(max_k, items.size()) + 1):
		_choose(items, k, 0, [], out)
	return out


func _choose(items: Array, k: int, start: int, cur: Array, out: Array) -> void:
	if cur.size() == k:
		out.append(cur.duplicate())
		return
	for i in range(start, items.size()):
		cur.append(items[i])
		_choose(items, k, i + 1, cur, out)
		cur.pop_back()


func _run(lv: Dictionary, valves: Array, tanks: Array, siphons: Array = []) -> Dictionary:
	var sim = WaterSim.new()
	sim.load_level(lv)
	for v in valves:
		sim.open_valve(v)
	for t in tanks:
		sim.toggle_tank(t)
	for a in siphons:
		sim.toggle_siphon(a)
	sim.start()
	var n := 0
	while n < 400:
		sim.step()
		n += 1
		if sim.settled:
			break
	var dry := 0
	for e in sim.edge_a.size():
		if sim.edge_from[e] < 0 and sim.edge_open[e]:
			dry += 1   # 开着却从没进水的管子 = 死胡同
	return {"win": sim.all_lit(), "ticks": n, "dry": dry, "wrong": sim.goals_wrong()}


func _report(num: int, lv: Dictionary) -> void:
	var probe = WaterSim.new()
	probe.load_level(lv)
	var valve_edges: Array = []
	for e in probe.edge_a.size():
		if probe.edge_kind[e] == "valve":
			valve_edges.append(e)
	var arches: Array = []
	for e in probe.edge_a.size():
		if probe.edge_kind[e] == "siphon":
			arches.append(e)
	var slots: Array = []
	for i in probe.node_id.size():
		if probe.node_kind[i] == "slot":
			slots.append(i)
	var wins: Array = []
	for vs in _combos(valve_edges, lv["valves"]):
		for ts in _combos(slots, lv["tanks"]):
			for ss in _combos(arches, lv.get("siphons", 0)):
				var r := _run(lv, vs, ts, ss)
				if r["win"]:
					wins.append({"v": vs, "t": ts, "s": ss, "r": r})
	# 最简解：不存在真子集也能赢
	var minimal: Array = []
	for w in wins:
		var simple := true
		for o in wins:
			if o == w:
				continue
			if _subset(o["v"], w["v"]) and _subset(o["t"], w["t"]) and _subset(o["s"], w["s"]) and (o["v"].size() + o["t"].size() + o["s"].size() < w["v"].size() + w["t"].size() + w["s"].size()):
				simple = false
				break
		if simple:
			minimal.append(w)
	var total := 0
	total = _combos(valve_edges, lv["valves"]).size() * _combos(slots, lv["tanks"]).size() * _combos(arches, lv.get("siphons", 0)).size()
	var tag: String = lv.get("_file", "")
	print("═ 第%d关《%s》%s  阀门×%d 水箱×%d 虹吸×%d  节点%d 边%d" % [num, lv["title"], ("  [" + tag + "]") if tag != "" else "", lv["valves"], lv["tanks"], lv.get("siphons", 0), probe.node_id.size(), probe.edge_a.size()])
	print("   摆法共 %d 种，能通关 %d 种，最简解 %d 种" % [total, wins.size(), minimal.size()])
	for w in minimal:
		var steps: Array = []
		for e in w["v"]:
			steps.append("开阀%s-%s" % [probe.node_id[probe.edge_a[e]], probe.node_id[probe.edge_b[e]]])
		for i in w["t"]:
			steps.append("水箱@%s" % probe.node_id[i])
		for e in w["s"]:
			steps.append("虹吸%s-%s" % [probe.node_id[probe.edge_a[e]], probe.node_id[probe.edge_b[e]]])
		print("   · %s   耗时%d tick%s" % [" + ".join(steps) if steps.size() > 0 else "（什么都不用做）", w["r"]["ticks"], "" if w["r"]["dry"] == 0 else "  ⚠ %d 根管子没进水" % w["r"]["dry"]])
	var tips: Array = []
	if wins.size() == 0:
		tips.append("无解！")
	elif minimal.size() == 1:
		tips.append("唯一解（想做多解关就再加一条路）")
	if wins.size() > 8:
		tips.append("通关摆法偏多（%d），谜题可能太松" % wins.size())
	for w in minimal:
		if w["r"]["dry"] > 0:
			tips.append("有死胡同管子（设计原则：解法成立时每根管子都该有水）")
			break
	if lv["solution"] != null and lv["solution"].has("valves"):
		var sv: Array = []
		for pair in lv["solution"]["valves"]:
			sv.append(probe.find_edge(pair[0], pair[1]))
		var st: Array = []
		for t in lv["solution"]["tanks"]:
			st.append(probe.find_node(t))
		var sp: Array = []
		for pair in lv["solution"].get("siphons", []):
			sp.append(probe.find_edge(pair[0], pair[1]))
		if not _run(lv, sv, st, sp)["win"]:
			tips.append("你写的 solution 并不能通关")
	for t in tips:
		print("   ！" + t)


func _subset(a: Array, b: Array) -> bool:
	for x in a:
		if not b.has(x):
			return false
	return true
