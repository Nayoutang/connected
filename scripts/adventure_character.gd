extends Node3D
## The imported walk is driven by the existing exploration movement controller.
const MODEL := preload("res://assets/characters/action+figure+3d+model.glb")
const WALK := &"角色走动"
const HEIGHT := preload("res://scripts/world_dimensions.gd").HERO_HEIGHT
const IDLE := &"idle"
const WAVE := &"wave_goodbye_02"
const SAVED_WALK := preload("res://assets/characters/animations/walk.tres")
var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var moving := false
var model: Node3D

func _ready() -> void:
	model = MODEL.instantiate() as Node3D
	model.name = "Visual"
	add_child(model)
	# Source is approximately 0.995 units high, with its feet at Y=0.
	model.scale = Vector3.ONE * (HEIGHT / 0.9946286082)
	for node in model.find_children("*", "", true, false):
		if node is AnimationPlayer:
			animation_player = node
		elif node is Skeleton3D:
			skeleton = node
	if animation_player == null:
		push_error("Adventure character is missing AnimationPlayer")
		return
	# Duplicate the imported resource: navigation owns horizontal displacement.
	var walk := SAVED_WALK.duplicate() as Animation
	walk.loop_mode = Animation.LOOP_LINEAR
	for track in walk.get_track_count():
		if walk.track_get_type(track) == Animation.TYPE_POSITION_3D and String(walk.track_get_path(track)).ends_with(":mixamorig_Hips"):
			var first: Vector3 = walk.track_get_key_value(track, 0)
			for key in walk.track_get_key_count(track):
				var value: Vector3 = walk.track_get_key_value(track, key)
				value.x = first.x
				value.z = first.z
				walk.track_set_key_value(track, key, value)
	var library := animation_player.get_animation_library("")
	if library.has_animation(WALK):
		library.remove_animation(WALK)
	library.add_animation(WALK, walk)
	if animation_player.has_animation(IDLE):
		var idle := animation_player.get_animation(IDLE).duplicate() as Animation
		idle.loop_mode = Animation.LOOP_LINEAR
		library.remove_animation(IDLE)
		library.add_animation(IDLE, idle)
	animation_player.animation_finished.connect(_on_animation_finished)
	_play_idle()

func set_locomotion(is_moving: bool, is_running: bool) -> void:
	if animation_player == null:
		return
	animation_player.speed_scale = 1.78 if is_moving and is_running else 1.0
	if is_moving != moving:
		moving = is_moving
		if moving:
			animation_player.play(WALK, 0.15)
		else:
			_play_idle()

func _play_idle() -> void:
	animation_player.speed_scale = 1.0
	if animation_player.has_animation(IDLE):
		animation_player.play(IDLE, 0.15)
	else:
		animation_player.play(WALK)
		animation_player.seek(0.0, true)
		animation_player.pause()

func play_wave() -> void:
	if animation_player != null and not moving and animation_player.has_animation(WAVE):
		animation_player.speed_scale = 1.0
		animation_player.play(WAVE, 0.15)

func _on_animation_finished(name: StringName) -> void:
	if name == WAVE and not moving:
		_play_idle()
