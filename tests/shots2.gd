extends SceneTree
## 截图：godot --path . --script res://tests/shots2.gd -- 输出目录
var main
var Chapter = load("res://scripts/chapter1.gd")
var levels: Array
var plan := []   # [kind, level, frames]
var step := 0
var wait := 0
var out := "/tmp"

func _initialize() -> void:
	levels = Chapter.get_levels()
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		plan.append(["pre", i, 20])
		plan.append(["win", i, 220])
	plan.append(["reveal", 2, 330])
	plan.append(["reveal", 5, 330])
	plan.append(["reveal", 9, 480])
	plan.append(["garden", 9, 700])

func _process(delta: float) -> bool:
	if wait > 0:
		wait -= 1
		return false
	if step > 0 and step <= plan.size():
		var p = plan[step - 1]
		var img = root.get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%02d.png" % [out, p[0], p[1] + 1])
	if step >= plan.size():
		quit(0)
		return false
	var p = plan[step]
	step += 1
	wait = p[2]
	match p[0]:
		"pre":
			main._load_level(p[1])
		"win":
			var lv = levels[p[1]]
			var sol = lv["solution"]
			for pair in sol["valves"]:
				main.sim.open_valve(main.sim.find_edge(pair[0], pair[1]))
			for t in sol["tanks"]:
				main.sim.toggle_tank(main.sim.find_node(t))
			for pair in sol.get("siphons", []):
				main.sim.toggle_siphon(main.sim.find_edge(pair[0], pair[1]))
			main._on_start()
		"reveal":
			main._load_level(p[1])
			main._start_reveal(levels[p[1]]["round"])
		"garden":
			main._start_reveal("")
	return false
