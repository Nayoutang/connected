extends SceneTree
## 无头验证：godot --headless --path . --script res://tests/run_tests.gd

const Levels = preload("res://scripts/levels.gd")
const WaterSim = preload("res://scripts/sim.gd")


func _init() -> void:
	var ok := true
	var all: Array = Levels.get_levels()
	for i in all.size():
		var lv: Dictionary = all[i]
		var r: Array = _run(lv, lv["solution"])
		print("Level %d %s: solution -> %s (ticks=%d)" % [i + 1, lv["title"], "WIN" if r[0] else "FAIL", r[1]])
		if not r[0]:
			ok = false
		for alternative in lv.get("alternatives", []):
			var ra: Array = _run(lv, alternative)
			print("    alternative -> %s" % ("WIN" if ra[0] else "FAIL"))
			if not ra[0]:
				ok = false
		for bad in lv["bad"]:
			var rb: Array = _run(lv, bad)
			print("    attempt %s -> %s" % [str(bad), "WIN (unexpected!)" if rb[0] else "no win (expected)"])
			if rb[0]:
				ok = false
	print("ALL OK" if ok else "SOME FAILED")
	quit(0 if ok else 1)


func _run(lv: Dictionary, sol: Dictionary) -> Array:
	var sim = WaterSim.new()
	sim.load_level(lv)
	for pair in sol["valves"]:
		sim.open_valve(sim.find_edge(pair[0], pair[1]))
	for t in sol["tanks"]:
		sim.toggle_tank(sim.find_node(t))
	sim.start()
	var n := 0
	while n < 300:
		sim.step()
		n += 1
		if sim.all_lit():
			return [true, n]
		if sim.settled:
			break
	return [false, n]
