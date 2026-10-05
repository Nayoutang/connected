extends "res://scripts/city_home.gd"
## Selecting a destination previews its real scene; entering is a separate action.
var selected := 0
var preview: TextureRect
var heading: Label
var description: Label
var district: Label
var entries: Array[Button] = []
var levels := preload("res://scripts/chapter1.gd").get_levels()
const Backdrop = preload("res://scripts/story_backdrop.gd")
const Campaign = preload("res://scripts/campaign.gd")
const RegionNames = preload("res://scripts/level_transition.gd").REGIONS

func setup_map(nav: Control) -> void:
	navigation = nav
	map_mode = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label_at("百阶城   /   水路地图", Vector2(48, 32), Vector2(650, 35), 22, GOLD)
	label_at("DESTINATIONS   /   01 — 13", Vector2(948, 38), Vector2(290, 30), 14, Color("b7c6c4"))
	var title := label_at("循水而行", Vector2(48, 99), Vector2(650, 66), 40)
	title.add_theme_font_override("font", display_font)
	label_at("选择修复地点，查看现场后再出发。", Vector2(50, 172), Vector2(650, 35), 18, Color("b7c6c4"))
	for i in 13:
		var index := i
		var name: String = levels[i]["title"] if i < 10 else Campaign.EXTRA_TITLES[i - 10]
		var button := action("%02d   %s" % [i + 1, name], Vector2(48 + (i % 2) * 326, 230 + (i / 2) * 52), Vector2(310, 42), func(): select_level(index))
		button.toggle_mode = true
		var chosen := StyleBoxFlat.new()
		chosen.bg_color = Color("395651")
		chosen.set_border_width_all(1)
		chosen.border_color = GOLD
		chosen.content_margin_left = 24
		button.add_theme_stylebox_override("pressed", chosen)
		entries.append(button)
	preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.position = Vector2(758, 114)
	preview.size = Vector2(474, 250)
	preview.clip_contents = true
	add_child(preview)
	district = label_at("", Vector2(758, 382), Vector2(474, 28), 17, GOLD)
	heading = label_at("", Vector2(758, 421), Vector2(474, 51), 29)
	description = label_at("", Vector2(758, 485), Vector2(474, 110), 18, Color("c7d4d0"))
	action("出发修复    →", Vector2(758, 586), Vector2(474, 47), func(): navigation.game.enter_level(selected), true)
	action("返回主界面", Vector2(48, 669), Vector2(180, 36), func(): nav.show_screen("hub"))
	action("返回大地图", Vector2(242, 669), Vector2(180, 36), nav.open_city_map)
	label_at("先存后送、双池供水、自动补水已并入修复旅程。", Vector2(706, 678), Vector2(540, 24), 14, Color("b7c6c4"))
	select_level(clampi(nav.game.lv_index, 0, 12))
	queue_redraw()

func select_level(index: int) -> void:
	selected = index
	for i in entries.size():
		entries[i].set_pressed_no_signal(i == index)
	var region: String = Backdrop.LESSON_REGIONS[index] if index < 10 else Backdrop.LAB_REGIONS[index - 10]
	preview.texture = load("res://assets/story/regions/%s.png" % region)
	district.text = "现场 / " + RegionNames[region]
	heading.text = "%02d  ·  %s" % [index + 1, levels[index]["title"] if index < 10 else Campaign.EXTRA_TITLES[index - 10]]
	description.text = levels[index]["hint"] if index < 10 else ["只有 8 升水。选择合适的水箱位置，让目标池存够 4 升水。", "让两个水池各存够 6 升水。使用单向阀留住水，手动或自动分流。", "让浮子控制进水，使灌溉池持续有水，同时避免水箱溢出。"][index - 10]
	description.size = Vector2(474, 110)
