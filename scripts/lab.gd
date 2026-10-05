extends Node2D
## Campaign water-volume levels use the same navigation and art primitives as chapter one.
const Campaign = preload("res://scripts/campaign.gd")
const Sim = preload("res://scripts/lab_sim.gd")
const Levels = preload("res://scripts/lab_levels.gd")
const Art = preload("res://scripts/game_art.gd")
const StoryData = preload("res://scripts/story_data.gd")
const STEP := 0.35
const AQUA := Color("53d5f2")
const GOLD := Color("ffd277")
const DIM := Color("8c99b3")
const POSITIONS = [
 {"S": Vector2(190, 170), "T": Vector2(550, 260), "U": Vector2(550, 530), "G": Vector2(1090, 440)},
 {"S": Vector2(190, 170), "R": Vector2(550, 260), "A": Vector2(1000, 350), "B": Vector2(1000, 530), "T": Vector2(550, 530)},
 {"S": Vector2(280, 170), "T": Vector2(640, 350), "G": Vector2(1000, 530)}
]
var art = Art.new()
var sim = Sim.new()
var levels: Array = Levels.get_levels()
var index := 0
var lv_index := 10
var font: Font
var ui: Control
var transition: CanvasLayer
var story: CanvasLayer
var backdrop: Node2D
var navigation: Control
var ui_paused := false
var paused := false
var accumulator := 0.0
var animation_time := 0.0
var result_shown := false
var title: Label
var hint: Label
var status: Label
var notice: Label
var btn_start: Button
var btn_reset: Button
var btn_next: Button
var btn_prev: Button
var hover_id := ""
var hover_type := ""
var control_menu: PopupMenu
var sensor_id := ""
var control_targets: Array[String] = []

func _ready() -> void:
 var window := get_window()
 window.content_scale_size = Vector2i(1280, 720)
 window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
 var sf := SystemFont.new()
 sf.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
 font = sf
 _build_ui()
 backdrop = preload("res://scripts/story_backdrop.gd").new()
 add_child(backdrop)
 story = preload("res://scripts/story_dialogue.gd").new()
 add_child(story)
 transition = preload("res://scripts/level_transition.gd").new()
 add_child(transition)
 navigation = preload("res://scripts/game_ui.gd").new()
 ui.get_parent().add_child(navigation)
 navigation.setup(self, font)
 _load(clampi(Campaign.take_level(get_tree(), 10) - 10, 0, 2))

func _label(text: String, pos: Vector2, dimensions: Vector2, size: int, color: Color) -> Label:
 var label := Label.new()
 label.text = text
 label.position = pos
 label.size = dimensions
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size", size)
 label.add_theme_color_override("font_color", color)
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 ui.add_child(label)
 return label

func _button(text: String, x: float, action: Callable) -> Button:
 var button := Button.new()
 button.text = text
 button.position = Vector2(x, 664)
 button.size = Vector2(120, 44)
 button.pressed.connect(action)
 ui.add_child(button)
 return button

func _build_ui() -> void:
 var layer := CanvasLayer.new()
 add_child(layer)
 ui = Control.new()
 ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
 ui.theme = Theme.new()
 ui.theme.default_font = font
 ui.theme.default_font_size = 20
 layer.add_child(ui)
 title = _label("", Vector2(28, 14), Vector2(1000, 44), 32, Color(1.0, 0.82, 0.30))
 hint = _label("", Vector2(28, 62), Vector2(1224, 56), 20, Color("e0e8f5"))
 status = _label("", Vector2(28, 668), Vector2(675, 38), 20, DIM)
 notice = _label("", Vector2(28, 625), Vector2(1224, 32), 20, GOLD)
 btn_prev = _button("上一关", 720, _on_prev)
 btn_start = _button("放水", 850, _on_start)
 btn_reset = _button("重置", 980, _on_reset)
 btn_next = _button("下一关", 1110, _on_next)
 control_menu = PopupMenu.new()
 control_menu.add_theme_font_override("font", font)
 control_menu.id_pressed.connect(_choose_control)
 ui.add_child(control_menu)

func enter_level(global_index: int) -> void:
 if global_index >= 10:
  _load(global_index - 10)
 else:
  Campaign.open_level(get_tree(), global_index)

func _load(i: int, brief := true) -> void:
 transition.cancel()
 index = clampi(i, 0, 2)
 lv_index = index + 10
 sim.load_level(levels[index])
 for n in sim.nodes:
  n["pos"] = POSITIONS[index][n["id"]]
 paused = false
 accumulator = 0
 animation_time = 0
 result_shown = false
 hover_id = ""
 hover_type = ""
 backdrop.set_region(true, index)
 title.text = "第 %d 关 · %s" % [lv_index + 1, Campaign.EXTRA_TITLES[index]]
 hint.text = [
  "点击空位放置水箱，再点【放水】。只有 8 升水，目标需要 4 升；水箱的位置决定水能否送达。",
  "两个水池都需要 6 升水。点击池间的箭头防止倒流；点击换向阀分水，或用上池的浮子自动切换。",
  "点击空位放水箱，再点旁边的【浮】接上自动补水。让灌溉池持续有水，同时避免水箱溢出。"
 ][index]
 notice.text = ""
 control_menu.hide()
 _refresh()
 navigation.reveal_level()
 if brief:
  var loaded_index := index
  transition.present(self, func():
   if not get_meta("skip_story", false):
    story.play(StoryData.chapter(true, loaded_index))
  )
 queue_redraw()

func _on_start() -> void:
 if transition.active or story.active or ui_paused or sim.won or sim.failed:
  return
 sim.start()
 paused = false
 notice.text = ""
 _refresh()

func _on_reset() -> void:
 _load(index, false)

func _on_prev() -> void:
 enter_level(lv_index - 1)

func _on_next() -> void:
 if not sim.won:
  return
 if index < 2:
  _load(index + 1)
 else:
  get_tree().change_scene_to_file("res://main.tscn")

func completion_text() -> String:
 return ["雨水已送到温室。下一处是两户共用的水路。", "两个水池都已存够水。接下来让苗圃自动补水。", "苗圃的供水已能自行调节。百阶城的这段修复工作完成了。"][index]

func _process(delta: float) -> void:
 if transition.active or story.active or ui_paused or paused:
  return
 animation_time += delta
 if sim.started and not sim.won and not sim.failed:
  accumulator += delta
  while accumulator >= STEP and not sim.won and not sim.failed:
   accumulator -= STEP
   sim.step()
   _after_step()
 _hover(get_local_mouse_position())
 queue_redraw()

func _after_step() -> void:
 _refresh()
 if (sim.won or sim.failed) and not result_shown:
  result_shown = true
  if sim.won:
   var city_completed: Array = get_tree().root.get_meta("city_completed", []).duplicate()
   if lv_index not in city_completed:
    city_completed.append(lv_index)
   get_tree().root.set_meta("city_completed", city_completed)
   backdrop.celebrate()
   notice.text = "通关！" + completion_text()
   if not get_meta("skip_story", false):
    story.play(StoryData.chapter(true, index, true))
   # Same in-place completion as the first ten levels, without a laboratory results panel.
  else:
   notice.text = "水箱溢出了。点【重置】，接上浮子后再试。" if sim.wasted > 0 else "水没有满足目标。点【重置】换一种方案。"

func _refresh() -> void:
 var lit := 0
 var total := 0
 for n in sim.nodes:
  if n.has("target"):
   total += 1
   if float(n["volume"]) + Sim.EPS >= float(n["target"]):
    lit += 1
 status.text = "水箱剩余 %d   浮子剩余 %d   终点 %d/%d" % [sim.inventory["tank"], sim.inventory["float"], lit, total]
 if index == 2 and sim.started:
  status.text += "   供水 %.1f/%.1f秒" % [sim.stable_ticks * STEP, sim.rules["hold_ticks"] * STEP]
 btn_start.disabled = sim.started
 btn_next.disabled = not sim.won
 btn_next.text = "完成" if index == 2 else "下一关"

func _float_position(n: Dictionary) -> Vector2:
 return n["pos"] + Vector2(62, -32)

func _has_float(id: String) -> bool:
 for f in sim.floats:
  if f["sensor"] == id:
   return true
 return false

func _controller(target: String) -> Dictionary:
 for f in sim.floats:
  if f["target"] == target:
   return f
 return {}

func _recommended(n: Dictionary) -> String:
 if n.has("target"):
  for other in sim.nodes:
   if other["kind"] == "router":
    return other["id"]
 for e in sim.edges:
  if e["kind"] == "valve" and e["b"] == n["id"]:
   return e["id"]
 for e in sim.edges:
  if e["kind"] == "valve":
   return e["id"]
 return ""

func _connect_float(n: Dictionary, target: String) -> void:
 var lower := float(n["capacity"]) * 0.25
 var upper := minf(float(n.get("target", float(n["capacity"]) * 0.75)), float(n.get("spill_at", n["capacity"])))
 var ok: bool = sim.link_float(n["id"], target, lower, upper, false)
 var name := "换向阀" if not sim.node(target).is_empty() else _valve_name(sim.edge(target))
 notice.text = ("浮子已连接%s：低于 %.0f 升恢复，达到 %.0f 升切换。" % [name, lower, upper]) if ok else sim.last_error
 _refresh()

func _open_control_choices(n: Dictionary) -> void:
 if sim.started:
  return
 sensor_id = n["id"]
 control_targets.clear()
 control_menu.clear()
 for other in sim.nodes:
  if other["kind"] == "router":
   control_targets.append(other["id"])
   control_menu.add_item("控制换向阀", control_targets.size() - 1)
 for e in sim.edges:
  if e["kind"] == "valve":
   control_targets.append(e["id"])
   control_menu.add_item("控制" + _valve_name(e), control_targets.size() - 1)
 control_menu.popup_centered(Vector2i(300, 0))

func _choose_control(id: int) -> void:
 if id < 0 or id >= control_targets.size() or sim.started or sim.node(sensor_id).is_empty():
  return
 _connect_float(sim.node(sensor_id), control_targets[id])

func _hover(p: Vector2) -> void:
 hover_id = ""
 hover_type = ""
 for n in sim.nodes:
  if n["installed"] and n["kind"] in ["socket", "goal"] and p.distance_to(_float_position(n)) < 22:
   hover_id = n["id"]
   hover_type = "float"
   return
  if p.distance_to(n["pos"]) < 34:
   hover_id = n["id"]
   hover_type = "node"
   return
 for e in sim.edges:
  if (e["kind"] == "valve" or e["id"] == "AB") and p.distance_to(_mid(e)) < 32:
   hover_id = e["id"]
   hover_type = "edge"
   return

func _unhandled_input(event: InputEvent) -> void:
 if transition.active or story.active or ui_paused:
  return
 if event is InputEventMouseButton and event.pressed:
  var p: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
  _hover(p)
  if event.button_index == MOUSE_BUTTON_LEFT:
   _activate_hover()
  elif event.button_index == MOUSE_BUTTON_RIGHT and hover_type in ["node", "float"]:
   var n: Dictionary = sim.node(hover_id)
   if n["installed"] and n["kind"] in ["socket", "goal"]:
    _open_control_choices(n)

func _activate_hover() -> void:
 if sim.won or sim.failed:
  return
 match hover_type:
  "node":
   var n: Dictionary = sim.node(hover_id)
   if n["kind"] == "socket" and not sim.started:
    if not sim.place_tank(hover_id):
     notice.text = sim.last_error
    else:
     notice.text = "水箱已放置。点【放水】开始，或再点水箱收回。" if n["installed"] else "水箱已收回，可以换一个位置。"
   elif n["kind"] == "router":
    if not sim.actuate(hover_id):
     notice.text = "换向阀正由浮子控制。重置后可拆下浮子，恢复手动操作。" if not _controller(hover_id).is_empty() else sim.last_error
    else:
     notice.text = "现在向上池供水。" if n["route"] == 0 else "现在向下池供水。"
  "edge":
   var e: Dictionary = sim.edge(hover_id)
   if e["kind"] == "valve":
    if not sim.actuate(hover_id):
     notice.text = "此阀正由浮子控制。重置后可拆下浮子，恢复手动操作。" if not _controller(hover_id).is_empty() else sim.last_error
    else:
     notice.text = _valve_name(e) + ("已开启。" if e["open"] else "已关闭。")
   elif not sim.started:
    # A first click installs the useful retaining direction; later clicks reverse/remove it.
    var desired := -1 if e["check"] == 0 else (1 if e["check"] == -1 else 0)
    for i in 2:
     if e["check"] != desired:
      sim.cycle_check(hover_id)
    notice.text = "箭头方向可以通水，反向会被挡住。再点可反向或拆除。"
  "float":
   if not sim.started:
    var n: Dictionary = sim.node(hover_id)
    if _has_float(hover_id):
     sim.remove_float(hover_id)
     notice.text = "浮子已拆下。"
    else:
     _connect_float(n, _recommended(n))
 _refresh()
 queue_redraw()

func _txt(text: String, p: Vector2, size: int, color: Color) -> void:
 draw_string(font, p - Vector2(110, -size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, 220, size, color)

func _mid(e: Dictionary) -> Vector2:
 return (sim.node(e["a"])["pos"] + sim.node(e["b"])["pos"]) * 0.5

func _valve_name(e: Dictionary) -> String:
 return {"IN": "进水阀", "OUT": "出水阀", "TG": "高位阀", "UG": "低位阀", "RT": "储水阀", "TA": "回水阀"}.get(e["id"], "阀门")

func _draw() -> void:
 if font == null:
  return
 draw_rect(Rect2(12, 8, 1256, 704), Color(0.035, 0.065, 0.10, 0.55))
 draw_line(Vector2(34, 124), Vector2(34, 574), DIM, 2)
 draw_colored_polygon(PackedVector2Array([Vector2(34, 586), Vector2(26, 574), Vector2(42, 574)]), DIM)
 _txt("高", Vector2(34, 106), 18, DIM)
 _txt("低", Vector2(34, 604), 18, DIM)
 for e in sim.edges:
  var a: Vector2 = sim.node(e["a"])["pos"]
  var b: Vector2 = sim.node(e["b"])["pos"]
  art._strip(self, a, b, Color("718b9e"))
  if absf(e["flow"]) > Sim.EPS:
   draw_line(a, b, Color("1a6bf2"), 14, true)
   var p := a.lerp(b, fposmod(animation_time * 0.7, 1.0) if e["flow"] > 0 else 1.0 - fposmod(animation_time * 0.7, 1.0))
   draw_circle(p, 5, Color("8ccfff"))
 for e in sim.edges:
  var mid := _mid(e)
  if e["kind"] == "valve":
   var c := Art.OPEN if e["open"] else Art.CLOSED
   art.plate(self, mid, 28, c)
   art._icon(self, Art.VALVE, mid, 45, c)
   var controlled := not _controller(e["id"]).is_empty()
   art.caption(self, _valve_name(e) + (" · 自动" if controlled else (" · 开" if e["open"] else " · 关")), mid + Vector2(0, 38), c)
  elif e["id"] == "AB":
   art.plate(self, mid, 22, Art.METAL if e["check"] == 0 else GOLD)
   _txt("↔" if e["check"] == 0 else ("↑" if e["check"] == -1 else "↓"), mid, 25, GOLD)
   art.caption(self, "单向阀", mid + Vector2(43, 0), Art.METAL)
  if hover_type == "edge" and hover_id == e["id"]:
   draw_arc(mid, 33, 0, TAU, 48, Color.WHITE, 2, true)
   var tip := "点此关闭" if e["open"] else "点此开启"
   if e["kind"] != "valve":
    tip = "点此安装" if e["check"] == 0 else ("点此反向" if e["check"] == -1 else "点此拆除")
   elif not _controller(e["id"]).is_empty():
    tip = "浮子自动控制"
   if not sim.won and not sim.failed:
    art.caption(self, tip, mid + Vector2(0, -44), GOLD)
 for n in sim.nodes:
  _draw_node(n)
 for f in sim.floats:
  var n: Dictionary = sim.node(f["sensor"])
  var target: Dictionary = sim.node(f["target"])
  var destination: Vector2 = target["pos"] if not target.is_empty() else _mid(sim.edge(f["target"]))
  draw_dashed_line(_float_position(n), destination + Vector2(0, -28), Color(GOLD, 0.6), 1.5, 7)

func _draw_node(n: Dictionary) -> void:
 var p: Vector2 = n["pos"]
 var c := AQUA if n["installed"] else Color("6f879b")
 var caption := "水源"
 if n["kind"] == "goal":
  var ok: bool = n["volume"] + Sim.EPS >= n["target"]
  c = GOLD if ok else Art.METAL
  art.plate(self, p, 29, c)
  draw_circle(p + Vector2(0, 4), 6, GOLD if ok else Color(0.42, 0.34, 0.26))
  caption = "已供足水" if ok else "终点"
 elif n["kind"] == "router":
  art.plate(self, p, 28, Art.OPEN)
  art._icon(self, Art.VALVE, p, 45, Art.OPEN)
  caption = "送往上池" if n["route"] == 0 else "送往下池"
  if not _controller(n["id"]).is_empty():
   caption += " · 自动"
 else:
  art.plate(self, p, 29, c)
  art._icon(self, Art.SOURCE if n["kind"] == "source" else Art.TANK, p, 44, c if n["installed"] else Color(c, 0.55))
  if n["kind"] == "socket":
   caption = "水箱" if n["installed"] else "放水箱"
   if not n["installed"]:
    _txt("+", p + Vector2(23, -21), 20, Art.METAL)
 art.caption(self, caption, p + Vector2(0, 40), c)
 if n["installed"] and n["kind"] != "router":
  var fill := clampf(float(n["volume"]) / float(n["capacity"]), 0.0, 1.0)
  if fill > 0:
   draw_arc(p, 25, -PI / 2, -PI / 2 + TAU * fill, 48, Color(AQUA, 0.65), 3, true)
  var water_text := "余水 %.1f 升" % n["volume"] if n["kind"] == "source" else "%.1f / %.0f 升" % [n["volume"], n.get("target", n["capacity"])]
  art.caption(self, water_text, p + Vector2(0, 64), Art.METAL)
 if n["installed"] and n["kind"] in ["socket", "goal"]:
  var fp := _float_position(n)
  var attached := _has_float(n["id"])
  art.plate(self, fp, 18, GOLD if attached else Art.METAL)
  _txt("浮", fp, 17, GOLD if attached else Art.METAL)
  if hover_id == n["id"] and hover_type == "float":
   var tip := "点击拆浮子" if attached else "点击接浮子 · 右键选目标"
   if sim.started:
    tip = "浮子运行中" if attached else "放水前可安装浮子"
   art.caption(self, tip, fp + Vector2(25, -29), GOLD)
 if hover_type == "node" and hover_id == n["id"]:
  draw_arc(p, 34, 0, TAU, 48, Color.WHITE, 2, true)
  if n["kind"] == "socket" and not sim.started:
   art.caption(self, "点击收回" if n["installed"] else "点击放水箱", p + Vector2(0, -45), GOLD)
  elif n["kind"] == "router" and not sim.won and not sim.failed:
   art.caption(self, "浮子自动控制" if not _controller(n["id"]).is_empty() else "点击切换出口", p + Vector2(0, -45), GOLD)
