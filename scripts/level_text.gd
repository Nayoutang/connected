extends RefCounted
## 关卡文本格式解析。一个 .txt 文件 = 一关，写法见 levels/README.txt。
## 解析结果与 levels.gd 里的字典完全同构，可直接交给 sim.gd / main.gd。


static func parse(text: String) -> Dictionary:
	var lv := {
		"title": "未命名", "rows": 6, "valves": 0, "tanks": 0, "siphons": 0,
		"hint": "", "win": "", "round": "", "flora": "grass", "tank_color": "", "caption": "",
		"reveal": [0, 0], "nodes": [], "edges": [],
		"solution": {"valves": [], "tanks": [], "siphons": []}, "alternatives": [], "bad": [],
	}
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var sp := line.find(" ")
		var key := line if sp < 0 else line.substr(0, sp)
		var rest := "" if sp < 0 else line.substr(sp + 1).strip_edges()
		var p := rest.split(" ", false)
		match key:
			"title", "hint", "win", "round", "flora", "tank_color", "caption":
				lv[key] = rest
			"rows", "valves", "tanks", "siphons":
				lv[key] = int(rest)
			"reveal":  # reveal 列 行（揭晓画面里这一关放的位置，单位 = 格）
				lv["reveal"] = [int(p[0]), int(p[1])]
			"node":    # node 编号 种类 列 行 [颜色]
				var nd: Array = [p[0], p[1], int(p[2]), int(p[3])]
				if p.size() > 4:
					nd.append(p[4])
				lv["nodes"].append(nd)
			"edge":    # edge a b [valve | siphon 最高点所在行]
				var e: Array = [p[0], p[1]]
				if p.size() > 2:
					e.append(p[2])
				if p.size() > 3:
					e.append(int(p[3]))
				lv["edges"].append(e)
			"solution":   # solution 阀门a-b 阀门c-d 水箱:x  （没有就空着）
				lv["solution"] = _plan(p)
			"alt":
				lv["alternatives"].append(_plan(p))
			"bad":
				lv["bad"].append(_plan(p))
	return lv


## "F-L" = 阀门 F↔L；"@s2" = 水箱放在 s2
static func _plan(tokens: PackedStringArray) -> Dictionary:
	var plan := {"valves": [], "tanks": [], "siphons": []}
	for t in tokens:
		if t.begins_with("@"):
			plan["tanks"].append(t.substr(1))
		elif t.begins_with("~"):
			var sp2 := t.substr(1).split("-")
			plan["siphons"].append([sp2[0], sp2[1]])
		elif t.find("-") > 0:
			var ab := t.split("-")
			plan["valves"].append([ab[0], ab[1]])
	return plan


static func load_dir(dir_path: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	var names: Array = []
	for f in d.get_files():
		if f.ends_with(".txt") and f != "README.txt":
			names.append(f)
	names.sort()
	for f in names:
		var fa := FileAccess.open(dir_path.path_join(f), FileAccess.READ)
		if fa == null:
			continue
		var lv := parse(fa.get_as_text())
		lv["_file"] = f
		out.append(lv)
	return out
