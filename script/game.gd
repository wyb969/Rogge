extends Node2D
@onready var player: CharacterBody2D = $Player
@onready var level_manager: Node2D = $LevelManager

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	pass


func on_coin_collected():
	level_manager.add_coin(1)
