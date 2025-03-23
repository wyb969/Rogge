extends State
class_name dino_chase_state
@export var dino:CharacterBody2D
var player:CharacterBody2D

var speed = 50
var direction:Vector2
func enter()->void:
	player = get_tree().get_first_node_in_group("player")
	
func exit()->void:
	pass
	
func Physics_process(delta: float) -> void:
	var length = (player.global_position - dino.global_position).length()
	if(length > 200):
		print("trans to  idle")
		transition.emit(self, "dino_idle_state")
	if(length<15):
		dino.velocity = Vector2()
		return
	direction = player.global_position - dino.global_position
	dino.velocity =   direction.normalized() * speed
	
func Update(delta: float) -> void:
	pass
	
