extends Control
## 基础导航界面；Tween 只作用于 UI，模拟逻辑仍由主场景管理。

var game: Node
var overlay: ColorRect
var card: VBoxContainer
var motion: Tween
var screen := ""
var switching := false
var home: Control
var home_background: TextureRect
var home_shade: ColorRect
var city_jump: Button

func setup(host: Node, ui_font: Font) -> void:
	game = host
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme_data := Theme.new()
	theme_data.default_font = ui_font
	theme_data.default_font_size = 22
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("162e32") if state == "normal" else Color("31524f")
		if state == "disabled":
			style.bg_color = Color("17212e")
		style.set_corner_radius_all(2)
		style.set_border_width_all(1)
		style.border_color = Color("6b725f")
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2)
			style.border_color = Color("edce86")
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
	city_jump = Button.new()
	city_jump.text = "大地图 / M"
	city_jump.position = Vector2(888, 16)
	city_jump.size = Vector2(170, 44)
	city_jump.visible = false
	city_jump.pressed.connect(open_city_map)
	add_child(city_jump)
	overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.045, 0.08, 0.70)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	home_background = TextureRect.new()
	home_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	home_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	home_background.texture = load("res://assets/story/city-home.png")
	home_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	home_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(home_background)
	home_shade = ColorRect.new()
	home_shade.color = Color(0.025, 0.05, 0.07, 0.4)
	home_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	home_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(home_shade)
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

func _button(text: String, action: Callable, parent: Node = null) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 38 if screen == "levels" else 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	(parent if parent != null else card).add_child(button)

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
		city_jump.visible = false
		card.add_theme_constant_override("separation", 3 if next == "levels" else 14)
		for child in card.get_children():
			card.remove_child(child)
			child.queue_free()
		if is_instance_valid(home):
			overlay.remove_child(home)
			home.queue_free()
			home = null
		var at_home := next in ["menu", "hub", "levels", "explore"]
		home_background.visible = next != "pause" and next != "win"
		home_shade.visible = home_background.visible
		home_shade.color.a = 0.22 if next in ["menu", "hub"] else 0.86
		card.get_parent().visible = not at_home
		if at_home:
			if next == "explore":
				home = preload("res://scripts/city_explore.gd").new()
			else:
				home = preload("res://scripts/city_map.gd").new() if next == "levels" else preload("res://scripts/city_home.gd").new()
			overlay.add_child(home)
			if next == "explore":
				home.setup_explore(self)
			elif next == "levels":
				home.setup_map(self)
			else:
				home.setup(self, next == "menu")
		else:
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
		for child in (home if is_instance_valid(home) else card).find_children("*", "Button", true, false):
			child.grab_focus()
			break
	)

func _build_screen(next: String) -> void:
	match next:
		"pause":
			_label("修复暂停", 40, Color("edce86"))
			_button("继续修复", hide_screen)
			_button("重新开始本关", game._on_reset)
			_button("返回大地图", open_city_map)
			_button("返回街区探索", return_to_city)
			_button("选择关卡", func(): show_screen("levels"))
			_button("返回主界面", func(): show_screen("hub"))
		"help":
			_label("玩法说明", 36, Color("edce86"))
			_label("① 放水前：点水箱空位放/收水箱；点弧形管上的圆钮装/拆虹吸管\n② 点击红色阀门打开通路，注意剩余次数\n③ 点击「放水」，让水到达所有终点\n④ 水不能超过水源/水箱的高度；虹吸管能翻过山头，但出口必须比水位低\n⑤ 不同颜色的水汇合会混色，花开出的颜色就是水的颜色\n⑥ 第11关起直接点击装置操作；点容器旁的「浮」连接浮子，右键可选控制目标\n\n快捷键：ESC 暂停 · [ ] 切关 · V 查看阶段报告 · G 查看阶段总览", 20)
			_button("返回主界面", func(): show_screen("hub"))
		"credits":
			_label("素材署名", 36, Color("edce86"))
			_label("城市 / 人物：AI 生成像素美术", 18)
			_label("水管：Kenney · Puzzle Pack 2 · CC0", 20)
			_label("阀门 / 水箱 / 喷泉：Delapouite · CC BY 3.0", 20)
			_label("水滴：sbed · Game-icons.net · CC BY 3.0", 20)
			_label("图标以原始 SVG 使用，游戏内缩放及着色。", 18, Color("95aabd"))
			_button("Kenney 素材与许可", func(): OS.shell_open("https://kenney.nl/assets/puzzle-pack-2"))
			_button("Game-icons 素材与许可", func(): OS.shell_open("https://game-icons.net/faq.html"))
			_button("返回主界面", func(): show_screen("hub"))
		"win":
			_label("全城修复完成！" if game.lv_index == 12 else "连通成功！", 40, Color("ffcf70"))
			_label(game.completion_text() if game.has_method("completion_text") else game.levels[game.lv_index]["win"], 20)
			_button("返回大地图", open_city_map)
			_button("返回街区探索", return_to_city)
			if game.lv_index < 12:
				_button("进入下一关", game._on_next)
			_button("再试一次", game._on_reset)
			_button("返回主界面", func(): show_screen("hub"))

func open_city_map() -> void:
	if switching or (game.transition != null and game.transition.active) or (game.story != null and game.story.active):
		return
	get_tree().root.set_meta("garden_return_region", -1)
	get_tree().root.set_meta("garden_open_map", true)
	show_screen("explore")

func return_to_city() -> void:
	var region_for_level := [0, 1, 2, 3, 4, 5, 1, 6, 2, 5, 4, 6, 5]
	get_tree().root.set_meta("garden_return_region", region_for_level[clampi(game.lv_index, 0, 12)])
	show_screen("explore")

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
		city_jump.visible = true
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
	if game.transition != null and game.transition.active:
		return
	if game.story != null and game.story.active:
		return
	if screen == "" and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		open_city_map()
		get_viewport().set_input_as_handled()
		return
	if screen == "explore" and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_M, KEY_E, KEY_F, KEY_ESCAPE, KEY_V]:
		if is_instance_valid(home):
			home.handle_key(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if switching:
			return
		if screen == "pause":
			hide_screen()
		elif screen == "":
			show_screen("pause")
		else:
			show_screen("menu" if screen == "hub" else "hub")
		get_viewport().set_input_as_handled()
