extends SceneTree
var failures := 0
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func click(lab, p: Vector2) -> void:
 var e := InputEventMouseButton.new()
 e.position = lab.get_global_transform_with_canvas() * p
 e.button_index = MOUSE_BUTTON_LEFT
 e.pressed = true
 root.push_input(e, true)
 var up := InputEventMouseButton.new()
 up.position = e.position
 up.button_index = MOUSE_BUTTON_LEFT
 root.push_input(up, true)
func shot(name: String) -> void:
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../lab-previews/" + name + ".png")
func solve(lab) -> void:
 lab.sim.start()
 for i in 100:
  lab.sim.step()
 lab._after_step()
 check(lab.sim.won, "Direct manipulation solution failed")
func run() -> void:
 change_scene_to_file("res://main.tscn")
 await create_timer(0.6).timeout
 current_scene.mode = "garden"
 current_scene._on_next()
 await create_timer(0.4).timeout
 var lab = current_scene
 lab.set_meta("skip_story", true)
 lab.story.close()
 check(lab.lv_index == 10, "Campaign must enter 11")
 check(lab.title.get_theme_color("font_color") == Color(1.0, 0.82, 0.30), "Title must match chapter one")
 click(lab, lab.sim.node("T")["pos"])
 check(lab.sim.node("T")["installed"], "Click tank slot must install")
 await shot("unified-11")
 solve(lab)
 lab._on_next()
 await create_timer(0.3).timeout
 check(lab.index == 1, "Continue to 12")
 click(lab, lab._mid(lab.sim.edge("AB")))
 check(lab.sim.edge("AB")["check"] == -1, "First click retains upper pool")
 click(lab, lab._float_position(lab.sim.node("A")))
 check(lab.sim.floats.size() == 1 and lab.sim.floats[0]["target"] == "R", "Float click must connect diverter")
 # Reversal/removal and reinstall must refund inventory and remain usable.
 click(lab, lab._mid(lab.sim.edge("AB")))
 check(lab.sim.edge("AB")["check"] == 1, "Second click reverses check valve")
 click(lab, lab._mid(lab.sim.edge("AB")))
 check(lab.sim.edge("AB")["check"] == 0 and lab.sim.inventory["check"] == 1, "Third click removes and refunds")
 click(lab, lab._mid(lab.sim.edge("AB")))
 click(lab, lab._float_position(lab.sim.node("A")))
 check(lab.sim.floats.is_empty() and lab.sim.inventory["float"] == 1, "Float removal refunds inventory")
 click(lab, lab._float_position(lab.sim.node("A")))
 await shot("unified-12")
 solve(lab)
 lab._on_next()
 await create_timer(0.3).timeout
 click(lab, lab.sim.node("T")["pos"])
 click(lab, lab._float_position(lab.sim.node("T")))
 check(lab.sim.floats.size() == 1 and lab.sim.floats[0]["target"] == "IN", "Float must connect inlet")
 lab._open_control_choices(lab.sim.node("T"))
 check(lab.control_targets.has("IN") and lab.control_targets.has("OUT"), "Alternative control targets remain available")
 lab.control_menu.hide()
 lab._on_start()
 lab._hover(lab._mid(lab.sim.edge("IN")))
 lab._activate_hover()
 check(lab.notice.text.contains("浮子控制"), "Automatic valve explains why manual operation is blocked")
 lab.navigation.show_screen("pause")
 var before: int = lab.sim.tick
 await create_timer(0.6).timeout
 check(lab.sim.tick == before, "Shared pause must stop simulation")
 lab.navigation.hide_screen()
 await create_timer(0.3).timeout
 await shot("unified-13")
 solve(lab)
 lab._on_next()
 await create_timer(0.6).timeout
 check(current_scene.navigation.screen == "menu", "Final level must return to menu")
 current_scene.enter_level(11)
 await create_timer(0.4).timeout
 lab = current_scene
 check(lab.index == 1, "Direct selection index")
 lab.story.close()
 lab.set_meta("skip_story", true)
 lab._load(0)
 await create_timer(0.3).timeout
 root.size = Vector2i(960, 540)
 await process_frame
 click(lab, lab.sim.node("T")["pos"])
 check(lab.sim.node("T")["installed"], "Scaled window input must match device")
 await shot("unified-small")
 lab._on_prev()
 await create_timer(0.5).timeout
 check(current_scene.lv_index == 9, "Previous from 11 returns to 10")
 print("UNIFIED CAMPAIGN: %d failures" % failures)
 quit(failures)
