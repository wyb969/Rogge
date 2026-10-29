extends Node2D
## Dramatic boss-incoming banner: readable web text, flash, shake, SFX.

@onready var canvas: CanvasLayer = $CanvasLayer
@onready var label: Label = $CanvasLayer/Label
@onready var flash: ColorRect = $CanvasLayer/Flash

const WARNING_TEXT := "BOSS IS COMING!!!"
const SHAKE_DURATION := 1.8
const SHAKE_STRENGTH := 14.0

var _shake_camera: Camera2D
var _shake_origin: Vector2 = Vector2.ZERO
var _shake_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if canvas:
		canvas.layer = 110

	_setup_label()
	_setup_flash()
	_bind_camera()

	if AudioManager and AudioManager.has_method("play_boss_warning"):
		AudioManager.play_boss_warning()

	_shake_time = SHAKE_DURATION
	set_process(true)
	await _play_banner_tween()
	queue_free()

func _setup_label() -> void:
	label.text = WARNING_TEXT
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# ASCII "!" — fullwidth Chinese ！ was tofu on web.
	UiFonts.apply_to_label(label, 40, true)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.55, 0.08, 0.05, 1.0))
	label.add_theme_constant_override("outline_size", 10)
	label.modulate.a = 0.0
	label.scale = Vector2(0.7, 0.7)
	label.anchors_preset = Control.PRESET_CENTER
	label.offset_left = -420.0
	label.offset_right = 420.0
	label.offset_top = -48.0
	label.offset_bottom = 48.0
	# Approximate center pivot for the fixed offsets above.
	label.pivot_offset = Vector2(420.0, 48.0)

func _setup_flash() -> void:
	if flash == null:
		return
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0.75, 0.05, 0.02, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)

func _bind_camera() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			cam = player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		_shake_camera = cam
		_shake_origin = cam.offset

func _process(delta: float) -> void:
	if _shake_time <= 0.0 or _shake_camera == null or not is_instance_valid(_shake_camera):
		return
	_shake_time -= delta
	var t := clampf(_shake_time / SHAKE_DURATION, 0.0, 1.0)
	var mag := SHAKE_STRENGTH * t * t
	_shake_camera.offset = _shake_origin + Vector2(
		randf_range(-mag, mag),
		randf_range(-mag, mag)
	)
	if _shake_time <= 0.0:
		_shake_camera.offset = _shake_origin

func _play_banner_tween() -> void:
	# Red flash pulses.
	if flash:
		var flash_tw := create_tween()
		flash_tw.tween_property(flash, "color:a", 0.45, 0.1)
		flash_tw.tween_property(flash, "color:a", 0.12, 0.16)
		flash_tw.tween_property(flash, "color:a", 0.4, 0.1)
		flash_tw.tween_property(flash, "color:a", 0.1, 0.2)
		flash_tw.tween_property(flash, "color:a", 0.32, 0.1)
		flash_tw.tween_property(flash, "color:a", 0.0, 0.55)

	# Text slam-in + urgency blink + fade.
	var text_tw := create_tween()
	text_tw.tween_property(label, "modulate:a", 1.0, 0.1)
	text_tw.parallel().tween_property(label, "scale", Vector2(1.18, 1.18), 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	text_tw.tween_property(label, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for _i in 4:
		text_tw.tween_property(label, "modulate", Color(1.25, 0.45, 0.25, 1.0), 0.07)
		text_tw.tween_property(label, "modulate", Color(1.0, 0.88, 0.3, 1.0), 0.11)
	text_tw.tween_interval(0.25)
	text_tw.tween_property(label, "modulate:a", 0.0, 0.4)
	await text_tw.finished

	if _shake_camera and is_instance_valid(_shake_camera):
		_shake_camera.offset = _shake_origin

func _exit_tree() -> void:
	if _shake_camera and is_instance_valid(_shake_camera):
		_shake_camera.offset = _shake_origin
