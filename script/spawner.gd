extends Node2D

@export var player:CharacterBody2D
@export var enemy:PackedScene
@export var enemy_array:Array[EnemyData]
 

var distance: float = 200
var max_enmey_count:  int = 800
var max_distance: float = 300
var current_level: int = 0

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


func _process(delta: float) -> void:
	remove_far_enemy()	

func spawn(pos:Vector2, elite:bool):
	if get_tree().get_nodes_in_group("EnemyGroup").size() >= max_enmey_count:
		print("max enmey size")
		return
	var enemy_instance = enemy.instantiate()
	enemy_instance.position = pos
	enemy_instance.set_player_ref(player)
	enemy_instance.set_enemy_data(enemy_array[min(minute%enemy_array.size(),enemy_array.size()-1)])
	enemy_instance.add_to_group("EnemyGroup")
	enemy_instance.setHealth(enemy_instance.health * (1.0 + 0.12 * current_level + 0.015 * current_level * current_level))
	enemy_instance.setDemage(enemy_instance.demage * (1.0 + 0.12 * current_level + 0.015 * current_level * current_level))
	if elite:
		enemy_instance.set_elite_status()
	get_tree().current_scene.add_child(enemy_instance)
	
	
func get_random_position()->Vector2:
	return player.position + distance * Vector2.RIGHT.rotated(randf_range(0,2*PI))
	
func amount_spawn(num:int=1):
	for i in range(num):
		spawn(get_random_position(),false)
		


func _on_timer_timeout() -> void:
	second+=1
	amount_spawn(second%10)


func _on_elite_timeout() -> void:
	spawn(get_random_position(),true)


func remove_far_enemy()->void:
	for enemy in get_tree().get_nodes_in_group("EnemyGroup"):
		if enemy is Timer:
			continue
		var dis = player.global_position.distance_to(enemy.global_position)
		if dis >= max_distance:
			get_tree().current_scene.remove_child(enemy)
			enemy.queue_free()

func handle_level_up(level:int):
	current_level = level
