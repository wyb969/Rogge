extends Node
## Autoload bridge between on-screen touch controls and player input.

var move_vector: Vector2 = Vector2.ZERO
var dash_just_pressed: bool = false
var controls_enabled: bool = false

func set_move_vector(v: Vector2) -> void:
	if v.length() > 1.0:
		v = v.normalized()
	move_vector = v

func clear_move() -> void:
	move_vector = Vector2.ZERO

func request_dash() -> void:
	dash_just_pressed = true

func consume_dash() -> bool:
	if dash_just_pressed:
		dash_just_pressed = false
		return true
	return false

func has_move_input() -> bool:
	return move_vector.length_squared() > 0.01
