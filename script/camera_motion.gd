extends RefCounted

const MAX_DRAG: = 22.0
var camera: Camera2D
var player: CharacterBody2D
var _origin: = Vector2.ZERO
var _base_speed: = 5.0
var drag: = Vector2.ZERO
var _velocity: = Vector2.ZERO

func bind(view: Camera2D, target: CharacterBody2D) -> void :
	camera = view
	player = target
	_origin = camera.position
	_base_speed = camera.position_smoothing_speed

func reset() -> void :
	drag = Vector2.ZERO
	_velocity = Vector2.ZERO
	if is_instance_valid(camera):
		camera.position = _origin
		camera.position_smoothing_speed = _base_speed
		camera.reset_smoothing()

func tick(delta: float, paused: bool, comfort: float) -> void :
	if not is_instance_valid(camera) or not is_instance_valid(player): return
	if comfort <= 0:
		drag = Vector2.ZERO
		_velocity = Vector2.ZERO
		camera.position = _origin
		camera.position_smoothing_speed = _base_speed
		return
	if paused: return
	var dt: = clampf(delta, 0, 0.05)
	var target: = ( - player.velocity * 0.075).limit_length(MAX_DRAG) if player.player_health > 0 else Vector2.ZERO
	var omega: = 15.0
	var change: = drag - target
	var spring: = _velocity + change * omega
	var decay: = exp( - omega * dt)
	drag = (target + (change + spring * dt) * decay).limit_length(MAX_DRAG)
	_velocity = (_velocity - spring * omega * dt) * decay
	camera.position = _origin + drag * comfort

	var speed: = 10.0 if player.dashing else 4.6
	camera.position_smoothing_speed = lerpf(_base_speed, speed, comfort)
