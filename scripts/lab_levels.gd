extends RefCounted

static func vessel(id: String, name: String, kind: String, pos: Vector2, height: float, capacity: float, volume: float = 0.0, area: float = 1.0) -> Dictionary:
	return {"id": id, "name": name, "kind": kind, "pos": pos, "height": height, "capacity": capacity, "volume": volume, "area": area}

static func pipe(id: String, a: String, b: String, kind: String = "pipe", rate: float = 1.0, opened: bool = true) -> Dictionary:
	return {"id": id, "a": a, "b": b, "kind": kind, "rate": rate, "open": opened}

static func get_levels() -> Array:
	var goal1 := vessel("G", "目标池", "goal", Vector2(780, 370), 1, 6)
	goal1["target"] = 4.0
	var first := {
		"title": "01 / 先存后送", "hint": "点击高、低底座之一安装水箱，再放水。只有 8 L 水；目标池需保持 ≥4 L。高度 h 决定水能否送达。",
		"inventory": {"tank": 1, "check": 1, "float": 1}, "hold_ticks": 3,
		"nodes": [vessel("S", "有限水源", "source", Vector2(130, 350), 9, 8, 8, 2), vessel("T", "高处底座", "socket", Vector2(440, 230), 4, 8, 0, 2), vessel("U", "低处底座", "socket", Vector2(440, 500), 0, 8, 0, 2), goal1],
		"edges": [pipe("ST", "S", "T"), pipe("SU", "S", "U"), pipe("TG", "T", "G", "valve"), pipe("UG", "U", "G", "valve")]
	}
	var a := vessel("A", "上池 A", "goal", Vector2(780, 240), 2, 8)
	a["target"] = 6.0
	var b := vessel("B", "下池 B", "goal", Vector2(780, 510), 0, 8)
	b["target"] = 6.0
	var ra := pipe("RA", "R", "A")
	ra.merge({"router": "R", "port": 0})
	var rb := pipe("RB", "R", "B")
	rb.merge({"router": "R", "port": 1})
	var second := {
		"title": "02 / 双池供水", "hint": "两池同时 ≥6 L，保持 3 拍。点 A—B 管装单向阀阻止倒灌；可手动换向，也可给 A 配置浮子控制 R（下限 2，上限 6）。",
		"inventory": {"tank": 1, "check": 1, "float": 1}, "hold_ticks": 3,
		"nodes": [vessel("S", "有限水源", "source", Vector2(120, 350), 12, 13, 13, 2), vessel("R", "换向阀 R", "router", Vector2(430, 350), 10, 1), a, b, vessel("T", "备用水箱", "socket", Vector2(440, 510), 8, 4, 0, 2)],
		"edges": [pipe("SR", "S", "R", "pipe", 1.5), ra, rb, pipe("AB", "A", "B", "pipe", 0.6), pipe("RT", "R", "T", "valve", 1, false), pipe("TA", "T", "A", "valve", 1, false)]
	}
	var garden := vessel("G", "灌溉池", "goal", Vector2(780, 370), 0, 5)
	garden.merge({"target": 3.0, "drain": 0.25})
	var regulator := vessel("T", "调节水箱", "socket", Vector2(440, 370), 3, 8, 0, 2)
	regulator["spill_at"] = 6.9
	var third := {
		"title": "03 / 自动补水", "hint": "水箱超过 6.9 L 会溢流失败！可用浮子控制 IN（下限 2，上限 6）。灌溉池每拍用 0.25 L，需连续 24 拍保持 ≥3 L。",
		"inventory": {"tank": 1, "check": 1, "float": 1}, "hold_ticks": 24, "max_waste": 0.0,
		"nodes": [vessel("S", "有限水源", "source", Vector2(130, 370), 12, 32, 32, 2), regulator, garden],
		"edges": [pipe("IN", "S", "T", "valve", 1.5), pipe("OUT", "T", "G", "valve", 0.8)]
	}
	return [first, second, third]
