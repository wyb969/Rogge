extends Node2D

const HUD_LAYOUT := preload("res://script/boss_hud_layout.gd")
var level: int = 0
var coin_number: int = 0
var level_need_coin_number: int = 6
@onready var progress_bar: ProgressBar = $UI / HBoxContainer / ProgressBar
@onready var label: Label = $UI / HBoxContainer / Label
signal signal_level_up(level)
var pickup_glow: ColorRect

func _ready() -> void :
	label.text=L10n.text("等级 %d") % level
	progress_bar.modulate = Color.WHITE
	progress_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var back := preload("res://script/painted_ui.gd").MOSS
	var fill: = StyleBoxFlat.new()
	fill.bg_color = GamePalette.XP_BAR
	fill.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("background", back)
	progress_bar.add_theme_stylebox_override("fill", fill)
	progress_bar.add_theme_color_override("font_color", Color(0.9, 0.94, 0.9))
	pickup_glow = preload("res://script/xp_pickup_glow.gd").new()
	progress_bar.add_child(pickup_glow)
	pickup_glow.bind(progress_bar)
	AudioManager.pickup_tone_played.connect(_on_pickup_tone)
	get_viewport().size_changed.connect(_fit_hud)
	_fit_hud()

func _fit_hud() -> void:
	var ui: float=HUD_LAYOUT.display_scale(self)
	var row: HBoxContainer=$UI/HBoxContainer
	var top: float=HUD_LAYOUT.header_top(self)
	row.position=Vector2(HUD_LAYOUT.SIDE_MARGIN*ui,(top+40)*ui)
	row.size=Vector2(276*ui,30*ui)
	row.add_theme_constant_override("separation",int(8*ui))
	label.custom_minimum_size=Vector2(68*ui,30*ui)
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.clip_text=true
	label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	UiFonts.apply_to_label(label,int(16*ui))
	progress_bar.custom_minimum_size=Vector2(200*ui,30*ui)
	progress_bar.add_theme_font_size_override("font_size",int(16*ui))

func _on_pickup_tone(pitch: float) -> void :
	var game: = get_parent()
	if not game.visible or game.process_mode == Node.PROCESS_MODE_DISABLED: return
	pickup_glow.pulse(pitch)

func reset_feedback() -> void :
	if is_instance_valid(pickup_glow): pickup_glow.reset()
	AudioManager.reset_pickup_combo()

func add_coin(value: int) -> void :
	coin_number += value
	while check_level_up():
		level_up()
	progress_bar.value = float(coin_number) / float(level_need_coin_number) * 100.0

func level_up():
	AudioManager.play_upgrade()
	level += 1
	label.text = L10n.text("等级 %d") % level
	coin_number = max(0, coin_number - level_need_coin_number)
	level_need_coin_number = get_need_exp(level)
	progress_bar.value = float(coin_number) / float(level_need_coin_number) * 100.0
	signal_level_up.emit(level)

func get_need_exp(level: int) -> int:

	return int(6 + level * 3.5 + level * level * 0.5)

func check_level_up() -> bool:
	return coin_number >= level_need_coin_number

func _process(_delta: float) -> void :
	var value: = float(coin_number) / float(level_need_coin_number) * 100.0
	if not is_equal_approx(progress_bar.value, value): progress_bar.value = value
