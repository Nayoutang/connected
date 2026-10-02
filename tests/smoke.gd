extends SceneTree
## 冒烟测试：加载主场景，逐关按标准解操作，驱动真实的 _process / _draw，并走一遍三轮揭晓和花园。
## godot --headless --path . --script res://tests/smoke.gd

var main
var frame := 0
var level := 0
var stage := 0
var wait := 0
var reveals := 0
var Chapter = load("res://scripts/chapter1.gd")
var levels: Array

func _initialize() -> void:
	levels = Chapter.get_levels()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _process(delta: float) -> bool:
	frame += 1
	if wait > 0:
		wait -= 1
		return false
	var lv = levels[level]
	match stage:
		0:
			var sol = lv["solution"]
			for pair in sol["valves"]:
				main.sim.open_valve(main.sim.find_edge(pair[0], pair[1]))
			for t in sol["tanks"]:
				main.sim.toggle_tank(main.sim.find_node(t))
			for pair in sol.get("siphons", []):
				main.sim.toggle_siphon(main.sim.find_edge(pair[0], pair[1]))
			main._on_start()
			stage = 1
		1:
			if main.won:
				print("level %d won, msg=%s" % [level + 1, main.lbl_msg.text])
				if lv["caption"] != "":
					main._on_next()   # 进入揭晓
					stage = 2
					wait = 1
				elif level + 1 < levels.size():
					main._on_next()
					level += 1
					stage = 0
			elif frame > 12000:
				print("SMOKE TIMEOUT at level ", level + 1)
				quit(1)
		2:
			# 揭晓画面：等它播完
			if main.btn_next.disabled == false:
				print("reveal ok: %s | %s" % [main.lbl_title.text, main.lbl_msg.text])
				reveals += 1
				main._on_next()
				if main.mode == "garden":
					stage = 3
				elif level + 1 < levels.size():
					level += 1
					stage = 0
		3:
			if main.btn_next.disabled == false:
				print("garden ok: %s" % main.lbl_msg.text)
				print("SMOKE OK, frames=", frame, " reveals=", reveals)
				quit(0)
	return false
