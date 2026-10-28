extends Node2D
var level: int = 0
var coin_number: int = 0
var level_need_coin_number: int = 6
@onready var progress_bar: ProgressBar = $UI/HBoxContainer/ProgressBar
@onready var label: Label = $UI/HBoxContainer/Label
signal signal_level_up(level)

func add_coin(value: int) -> void:
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
	progress_bar.modulate = Color.from_hsv(float(level) / 4.0, float(level) / 0.8, float(level) / 0.5)
	signal_level_up.emit(level)

func get_need_exp(level: int) -> int:
	# Slightly gentler curve so fewer, denser-value kills still pace upgrades.
	return int(6 + level * 3.5 + level * level * 0.5)

func check_level_up() -> bool:
	return coin_number >= level_need_coin_number

func _process(_delta: float) -> void:
	progress_bar.value = float(coin_number) / float(level_need_coin_number) * 100.0
