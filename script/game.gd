extends Node2D
@onready var enemy: CharacterBody2D = $Enemy
@onready var player: CharacterBody2D = $Player
var enemy_fx = preload("res://scenes/enemy.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	enemy.set_player(player)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	spawn_enemy()


func spawn_enemy():
	var e = enemy_fx.instantiate()
	var pos = player.global_position
	if randf() < 0.5:
		pos.x -= randf_range(100.0, 200.0)
	else:
		pos.x += randf_range(100.0, 200.0)
	pos.y += randf_range(-150,150)
	e.global_position = pos
	e.set_player(player)
	add_child(e)
