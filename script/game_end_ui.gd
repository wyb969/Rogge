extends Node2D

signal retry_pressed
signal main_menu_pressed

@onready var root_ui: Control = $CanvasLayer/Control

@onready var time_label: Label = $CanvasLayer/Control/BoxContainer/TimeLabel
@onready var kill_label: Label = $CanvasLayer/Control/BoxContainer/KillLabel
@onready var level_label: Label = $CanvasLayer/Control/BoxContainer/LevelLabel
@onready var retry_button: Button = $CanvasLayer/Control/BoxContainer/RetryButton
@onready var main_menu_button: Button = $CanvasLayer/Control/BoxContainer/BackToMenu

func _ready() -> void:
	root_ui.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

	retry_button.pressed.connect(func(): retry_pressed.emit())
	main_menu_button.pressed.connect(func(): main_menu_pressed.emit())

func show_result(stats: Dictionary) -> void:
	root_ui.show()

	var minutes :int= stats.get("minutes",0)
	var seconds :int= stats.get("seconds",0)

	time_label.text = "Survived: %02d:%02d" % [minutes, seconds]
	kill_label.text = "Kills: %d" % stats.get("kills", 0)
	level_label.text = "Level: %d" % stats.get("level", 1)

func hide_result() -> void:
	root_ui.hide()
