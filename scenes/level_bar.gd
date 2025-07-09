extends Node2D
var level:int = 0
var coin_number:int = 0
var level_need_coin_number:int = 10
@onready var progress_bar: ProgressBar = $UI/HBoxContainer/ProgressBar
@onready var label: Label = $UI/HBoxContainer/Label

func add_coin(value:int)->void:
	coin_number += 1
	if check_level_up():
		level_up()
	else:
		progress_bar.value =  float(coin_number) / float(level_need_coin_number) * 100 
	
func level_up():
	level +=1
	label.text = "Level: "+ str(level)
	coin_number = 0
	progress_bar.value = 0
	level_need_coin_number = level_need_coin_number * level * 1.1#exp(level)
	progress_bar.modulate = Color.from_hsv(float(level)/ 4.0, float(level)/0.8, float(level)/0.5)
	
func check_level_up()->bool:
	return coin_number>=level_need_coin_number

func _process(delta: float) -> void:
	progress_bar.value = float(coin_number) / float(level_need_coin_number) * 100 
