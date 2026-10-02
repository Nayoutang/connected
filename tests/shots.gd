extends SceneTree
## 截图脚本（需要显示环境，如 xvfb）：每关截 "放水前" 和 "运行中" 两张。
var main
var frame := 0
var level := 0
var stage := 0
var wait := 0
const Levels = preload("res://scripts/levels.gd")

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _shot(name: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("/home/claude/shots/%s.png" % name)

func _process(delta: float) -> bool:
	frame += 1
	if wait > 0:
		wait -= 1
		return false
	var lv = Levels.get_levels()[level]
	match stage:
		0:
			var sol = lv["solution"]
			for pair in sol["valves"]:
				main.sim.open_valve(main.sim.find_edge(pair[0], pair[1]))
			for t in sol["tanks"]:
				main.sim.toggle_tank(main.sim.find_node(t))
			wait = 4
			stage = 1
		1:
			_shot("L%d_a_before" % (level + 1))
			main._on_start()
			wait = 70
			stage = 2
		2:
			_shot("L%d_b_running" % (level + 1))
			stage = 3
		3:
			if main.won:
				wait = 5
				stage = 4
		4:
			_shot("L%d_c_won" % (level + 1))
			if level + 1 < Levels.get_levels().size():
				main._on_next()
				level += 1
				stage = 0
				wait = 3
			else:
				quit(0)
	return false
