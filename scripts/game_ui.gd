extends Control
## 基础导航界面；Tween 只作用于 UI，模拟逻辑仍由主场景管理。

var game: Node
var overlay: ColorRect
var card: VBoxContainer
var motion: Tween
var screen := ""
var switching := false

func setup(host: Node, ui_font: Font) -> void:
	game = host
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme_data := Theme.new()
	theme_data.default_font = ui_font
	theme_data.default_font_size = 22
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("18334b") if state == "normal" else Color("245d79")
		if state == "disabled":
			style.bg_color = Color("17212e")
		style.set_corner_radius_all(12)
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2)
			style.border_color = Color("6cdef2")
		theme_data.set_stylebox(state, "Button", style)
	theme = theme_data
	# 同时统一原有操作栏的样式。
	game.btn_start.theme = theme_data
	game.btn_reset.theme = theme_data
	game.btn_next.theme = theme_data
	game.btn_prev.theme = theme_data
	var pause := Button.new()
	pause.text = "暂停 / ESC"
	pause.position = Vector2(1070, 16)
	pause.size = Vector2(180, 44)
	pause.pressed.connect(func(): show_screen("pause"))
	add_child(pause)
	overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.045, 0.08, 0.70)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	card = VBoxContainer.new()
	card.custom_minimum_size = Vector2(560, 0)
	card.add_theme_constant_override("separation", 14)
	center.add_child(card)
	show_screen("menu")

func _label(text: String, font_size: int, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	card.add_child(label)

func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 38 if screen == "levels" else 48
	button.pressed.connect(action)
	card.add_child(button)

func show_screen(next: String) -> void:
	if switching:
		return
	switching = true
	game.ui_paused = true
	if motion:
		motion.kill()
	motion = create_tween()
	motion.tween_property(card, "modulate:a", 0.0, 0.12)
	motion.tween_callback(func():
		screen = next
		card.add_theme_constant_override("separation", 3 if next == "levels" else 14)
		for child in card.get_children():
			card.remove_child(child)
			child.queue_free()
		_build_screen(next)
		overlay.show()
		overlay.modulate.a = 0.0
		card.modulate.a = 0.0
		overlay.position = Vector2(0, 24)
	)
	motion.tween_property(overlay, "modulate:a", 1.0, 0.22)
	motion.parallel().tween_property(card, "modulate:a", 1.0, 0.22)
	motion.parallel().tween_property(overlay, "position", Vector2.ZERO, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_callback(func():
		switching = false
		for child in card.get_children():
			if child is Button:
				child.grab_focus()
				break
	)

func _build_screen(next: String) -> void:
	match next:
		"menu":
			_label("连 通", 64, Color("6cdef2"))
			_label("退潮之后 · 百阶城", 24)
			_label("第一章 · 重力篇 · 十个实验：草 / 花 / 树", 18, Color("95aabd"))
			_button("归城 · 开始修复", func(): game.enter_level(0))
			_button("涌现实验室 · 搭建自动水路", func(): get_tree().change_scene_to_file("res://lab.tscn"))
			_button("选择关卡", func(): show_screen("levels"))
			_button("玩法说明", func(): show_screen("help"))
			_button("素材署名", func(): show_screen("credits"))
			_button("退出游戏", func(): game.get_tree().quit())
		"levels":
			_label("选择实验", 36, Color("6cdef2"))
			for i in game.levels.size():
				var index: int = i
				_button("%02d  ·  %s" % [i + 1, game.levels[i]["title"]], func(): game.enter_level(index))
			_button("返回主菜单", func(): show_screen("menu"))
		"pause":
			_label("实验暂停", 40, Color("6cdef2"))
			_button("继续实验", hide_screen)
			_button("重新开始本关", game._on_reset)
			_button("选择关卡", func(): show_screen("levels"))
			_button("返回主菜单", func(): show_screen("menu"))
		"help":
			_label("玩法说明", 36, Color("6cdef2"))
			_label("① 放水前：点水箱空位放/收水箱；点弧形管上的圆钮装/拆虹吸管\n② 点击红色阀门打开通路，注意剩余次数\n③ 点击「放水」，让水到达所有终点\n④ 水不能超过水源/水箱的高度；虹吸管能翻过山头，但出口必须比水位低\n⑤ 不同颜色的水汇合会混色，花开出的颜色就是水的颜色\n\n快捷键：ESC 暂停 · [ ] 切关 · V 看本轮揭晓 · G 看花园", 20)
			_button("返回主菜单", func(): show_screen("menu"))
		"credits":
			_label("素材署名", 36, Color("6cdef2"))
			_label("城市 / 人物：AI 生成像素美术", 18)
			_label("水管：Kenney · Puzzle Pack 2 · CC0", 20)
			_label("阀门 / 水箱 / 喷泉：Delapouite · CC BY 3.0", 20)
			_label("水滴：sbed · Game-icons.net · CC BY 3.0", 20)
			_label("图标以原始 SVG 使用，游戏内缩放及着色。", 18, Color("95aabd"))
			_button("Kenney 素材与许可", func(): OS.shell_open("https://kenney.nl/assets/puzzle-pack-2"))
			_button("Game-icons 素材与许可", func(): OS.shell_open("https://game-icons.net/faq.html"))
			_button("返回主菜单", func(): show_screen("menu"))
		"win":
			_label("全部实验完成！" if game.lv_index == game.levels.size() - 1 else "连通成功！", 40, Color("ffcf70"))
			_label(game.levels[game.lv_index]["win"], 20)
			if game.lv_index + 1 < game.levels.size():
				_button("进入下一关", game._on_next)
			_button("再试一次", game._on_reset)
			_button("返回主菜单", func(): show_screen("menu"))

func hide_screen() -> void:
	if motion:
		motion.kill()
	switching = true
	screen = ""
	motion = create_tween()
	motion.tween_property(overlay, "modulate:a", 0.0, 0.22)
	motion.tween_callback(func():
		overlay.hide()
		game.ui_paused = false
		switching = false
	)

func reveal_level() -> void:
	# 在遮罩之下立即加载关卡，然后淡出；阻止动画期间的点击穿透。
	overlay.show()
	overlay.position = Vector2.ZERO
	overlay.modulate.a = 1.0
	card.hide()
	hide_screen()
	motion.tween_callback(func(): card.show())

func _input(event: InputEvent) -> void:
	if game.story != null and game.story.active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if switching:
			return
		if screen == "pause":
			hide_screen()
		elif screen == "":
			show_screen("pause")
		else:
			show_screen("menu")
		get_viewport().set_input_as_handled()
