extends Node2D
var level: int = 0
var coin_number: int = 0
var level_need_coin_number: int = 6
@onready var progress_bar: ProgressBar = $UI / HBoxContainer / ProgressBar
@onready var label: Label = $UI / HBoxContainer / Label
signal signal_level_up(level)
var pickup_glow: ColorRect

func _ready() -> void :
	progress_bar.modulate = Color.WHITE
	var back: = StyleBoxFlat.new()
	back.bg_color = GamePalette.alpha(GamePalette.UI_PANEL,0.95)
	back.border_color = GamePalette.PLAYER_PRIMARY.darkened(0.35)
	back.set_border_width_all(1)
	back.set_corner_radius_all(4)
	var fill: = StyleBoxFlat.new()
	fill.bg_color = GamePalette.PLAYER_PRIMARY
	fill.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("background", back)
	progress_bar.add_theme_stylebox_override("fill", fill)
	progress_bar.add_theme_color_override("font_color", GamePalette.UI_TEXT)
	pickup_glow = preload("res://script/xp_pickup_glow.gd").new()
	progress_bar.add_child(pickup_glow)
	pickup_glow.bind(progress_bar)
	AudioManager.pickup_tone_played.connect(_on_pickup_tone)

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
	label.text = "Level: " + str(level)
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
