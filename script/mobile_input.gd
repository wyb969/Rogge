extends Node


var move_vector: Vector2 = Vector2.ZERO
var dash_just_pressed: bool = false
var dash_move_vector: Vector2 = Vector2.ZERO
var controls_enabled: bool = false

func set_move_vector(v: Vector2) -> void :
	if v.length() > 1.0:
		v = v.normalized()
	move_vector = v

func clear_move() -> void :
	move_vector = Vector2.ZERO

func request_dash() -> void :
	dash_move_vector = move_vector
	dash_just_pressed = true

func clear_dash() -> void :
	dash_just_pressed = false
	dash_move_vector = Vector2.ZERO

func consume_dash() -> bool:
	if dash_just_pressed:
		dash_just_pressed = false
		return true
	return false

func has_move_input() -> bool:
	return not move_vector.is_zero_approx()
