extends Area2D

signal coin_collected

var start_pick: bool = false
var player_body:Node2D
var max_speed:int=300
var max_distance:int=5
var tween:Tween
var fly_duration:float = 0.5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !start_pick: return
	
	var dist = global_position.distance_to(player_body.global_position)
	if dist > max_distance:
		global_position = global_position.move_toward(player_body.global_position, max_speed * delta)
	else:
		coin_collected.emit()
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	player_body = body
	start_pick = true
 
