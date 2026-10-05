extends Control
## Readable, skippable stage recap using existing region artwork.
const DATA = {
 "grass": ["基础供水", "水位决定能到达的高度，阀门决定可用的通路。", ["gate", "old_street", "reservoir"], ["连通器", "阀门", "高处水箱"], ["水可以先下降再上升，\n但不会超过供水水位。", "打开需要的支路，\n让水到达目标。", "选择足够高的位置，\n为高处目标提供水位。"], 0, 3],
 "flower": ["越障与配色", "虹吸改变可走的路径，汇流决定最终的颜色。", ["clocktower", "greenhouse", "nursery"], ["虹吸越障", "颜色汇合", "分路配色"], ["出口低于供水水位，\n虹吸才能持续送水。", "红水与蓝水汇合，\n得到目标需要的紫色。", "把黄水分别送往两侧，\n配出橙色与绿色。"], 3, 6],
 "tree": ["分支供水", "先确定水位，再安排支路；同一个目标可以有不同解法。", ["old_street", "households", "reservoir"], ["分配装置", "比较路线", "下一站 · 屋顶温室"], ["有限的阀门和水箱，\n需要照顾多个终点。", "看出口高度与连通关系，\n不只比较路线长短。", "从第 11 关起，水会用完。\n你将学习储水与自动控制。"], 6, 10]
}
var content: Control
var motion: Tween

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE

func label_at(text: String, pos: Vector2, dimensions: Vector2, font_size: int, color: Color) -> void:
 var label := Label.new()
 label.text = text
 label.position = pos
 label.size = dimensions
 label.add_theme_font_size_override("font_size", font_size)
 label.add_theme_color_override("font_color", color)
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 content.add_child(label)

func present(key: String, completed: Dictionary, ui_font: Font) -> void:
 if motion:
  motion.kill()
 if content != null:
  remove_child(content)
  content.queue_free()
 content = Control.new()
 content.mouse_filter = Control.MOUSE_FILTER_IGNORE
 content.theme = Theme.new()
 content.theme.default_font = ui_font
 add_child(content)
 var info: Array = DATA.get(key, DATA["tree"])
 var aqua := Color("79d7da")
 var light := Color("e4edf0")
 var muted := Color("b3c4cf")
 label_at(info[0], Vector2(74, 112), Vector2(1100, 48), 36, light)
 label_at(info[1], Vector2(74, 165), Vector2(1100, 38), 20, muted)
 for i in 3:
  var x := 74.0 + i * 383.0
  var panel := Panel.new()
  panel.position = Vector2(x, 222)
  panel.size = Vector2(365, 350)
  panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
  var style := StyleBoxFlat.new()
  style.bg_color = Color("102735")
  style.border_color = Color("365362")
  style.set_border_width_all(1)
  style.set_corner_radius_all(8)
  panel.add_theme_stylebox_override("panel", style)
  content.add_child(panel)
  var picture := TextureRect.new()
  picture.position = Vector2(x + 10, 232)
  picture.clip_contents = true
  picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  picture.texture = load("res://assets/story/regions/%s.png" % info[2][i])
  picture.size = Vector2(345, 174)
  picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
  picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
  picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
  content.add_child(picture)
  label_at(info[3][i], Vector2(x + 20, 425), Vector2(325, 35), 25, aqua)
  label_at(info[4][i], Vector2(x + 20, 476), Vector2(325, 72), 20, light)
 var count := 0
 for i in range(info[5], info[6]):
  if completed.has(i):
   count += 1
 label_at("本次游玩记录  ·  本阶段完成 %d / %d 关" % [count, info[6] - info[5]], Vector2(74, 600), Vector2(1100, 35), 18, muted)
 show()
 content.modulate.a = 0
 motion = create_tween()
 motion.tween_property(content, "modulate:a", 1.0, 0.22)
