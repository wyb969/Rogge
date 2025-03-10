extends State
class_name dino_idle_state

var wander_time:float = 4.0
var wander_direction:Vector2 
var SPEED = 20.0

@export var dino_player:CharacterBody2D

func enter()->void:
	print("enter idle")
	wander_direction = Vector2(randf_range(-1,1),randf_range(-1,1))
	pass
	
func exit()->void:
	pass
	
func _physics_process(delta: float) -> void:
	if wander_time<=0:
		wander_time = 4.0
		wander_direction = Vector2(randf_range(-1,1),randf_range(-1,1))
	wander_time -= delta
	
	if dino_player:
		dino_player.velocity = wander_direction*SPEED
	
func update(delta: float) -> void:
	pass
	
