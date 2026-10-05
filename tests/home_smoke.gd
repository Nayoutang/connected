extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func press_text(node: Node, prefix: String) -> void:
	for button in node.find_children("*", "Button", true, false):
		if button.text.begins_with(prefix):
			button.pressed.emit()
			return
	check(false, "Missing button " + prefix)
func run() -> void:
	change_scene_to_file("res://main.tscn")
	await create_timer(0.7).timeout
	var game = current_scene
	var nav = game.navigation
	check(nav.screen == "menu", "Title missing")
	press_text(nav.home, "开始游戏")
	await create_timer(0.6).timeout
	check(nav.screen == "hub" and game.ui_paused and not game.story.active and not game.transition.active, "Start must enter hub, not level")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../lab-previews/ggac-home.png")
	press_text(nav.home, "水路地图")
	await create_timer(0.6).timeout
	check(nav.screen == "explore", "Map must enter city exploration")
	press_text(nav.home, "关卡目录")
	await create_timer(0.6).timeout
	check(nav.screen == "levels", "Catalogue must show levels")
	press_text(nav.home, "13")
	check(nav.home.selected == 12 and not game.transition.active, "Selection must preview without entering")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../lab-previews/ggac-map.png")
	press_text(nav.home, "01")
	press_text(nav.home, "出发修复")
	await create_timer(0.4).timeout
	check(game.transition.active, "Level selection should enter brief")
	game.transition.finish()
	game.story.close()
	nav.show_screen("pause")
	await create_timer(0.6).timeout
	press_text(nav.card, "返回主界面")
	await create_timer(0.6).timeout
	check(nav.screen == "hub", "Return must enter hub")
	root.size = Vector2i(960, 540)
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../lab-previews/ggac-home-small.png")
	print("HOME: %d failures" % failures)
	quit(failures)
