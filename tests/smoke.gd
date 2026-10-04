extends SceneTree
## 冒烟测试：加载主场景，逐关按方案操作，驱动真实的 _process / _draw。
## godot --headless --path . --script res://tests/smoke.gd

var main
var frame := 0
var level := 0
var stage := 0
var wait := 0
var results := []

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.set_meta("skip_story", true)
	root.add_child(main)

func _process(delta: float) -> bool:
	frame += 1
	if wait > 0:
		wait -= 1
		return false
	var Levels = load("res://scripts/levels.gd")
	var lv = Levels.get_levels()[level]
	match stage:
		0:
			var sol = lv["solution"]
			for pair in sol["valves"]:
				main.sim.open_valve(main.sim.find_edge(pair[0], pair[1]))
			for t in sol["tanks"]:
				main.sim.toggle_tank(main.sim.find_node(t))
			main._on_start()
			stage = 1
			wait = 0
		1:
			if main.won:
				print("level %d won, msg=%s" % [level + 1, main.lbl_msg.text])
				if level + 1 < Levels.get_levels().size():
					main._on_next()
					level += 1
					stage = 0
				else:
					print("SMOKE OK, frames=", frame)
					quit(0)
			elif frame > 4000:
				print("SMOKE TIMEOUT at level ", level + 1)
				quit(1)
	return false
