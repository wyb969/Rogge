extends State
class_name dino_idle_state

var wander_time:float = 4.0
var wander_direction:Vector2 
var SPEED = 20.0

@export var dino_player:CharacterBody2D
var player:CharacterBody2D

func enter()->void:
	player = get_tree().get_first_node_in_group("player")
	wander_direction = Vector2(randf_range(-1,1),randf_range(-1,1))
	pass
	
func exit()->void:
	pass
	
func Physics_process(delta: float) -> void:
	if wander_time<=0:
		wander_time = 4.0
		wander_direction = Vector2(randf_range(-1,1),randf_range(-1,1))
	wander_time -= delta
	
	if dino_player:
		dino_player.velocity = wander_direction*SPEED
		
	var length = (player.global_position - dino_player.global_position).length()
	if length<100:
		transition.emit(self, "dino_chase_state")
	
func Update(delta: float) -> void:
	pass
	
