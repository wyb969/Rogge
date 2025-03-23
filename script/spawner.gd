extends Node2D

@export var player:CharacterBody2D
@export var enemy:PackedScene

var distance: float = 200

var minute: int:
	set(value):
		minute = value
		%Mintue.text = str(minute)
		

var second: int:
	set(value):
		second = value
		if second>=10:
			second -=10
			minute +=1
		%Second.text = str(second).lpad(2,'0')

func spawn(pos:Vector2):
	var enemy_instance = enemy.instantiate()
	enemy_instance.position = pos
	enemy_instance.set_player(player)
	
	get_tree().current_scene.add_child(enemy_instance)
	
	
func get_random_position()->Vector2:
	return player.position + distance * Vector2.RIGHT.rotated(randf_range(0,2*PI))
	
func amount_spawn(num:int=1):
	for i in range(num):
		spawn(get_random_position())
		


func _on_timer_timeout() -> void:
	second+=1
	amount_spawn(second%10)
