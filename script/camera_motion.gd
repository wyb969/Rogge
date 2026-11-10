extends RefCounted

# A single world-position spring owns follow lag. Camera2D's built-in smoothing
# stays off so dash recovery cannot accumulate two separate follow delays.
const MAX_DRAG := 16.0
const FOLLOW_RESPONSE := 20.0
const DASH_RESPONSE := 30.0
const TELEPORT_DISTANCE := 240.0
var camera: Camera2D
var player: CharacterBody2D
var _origin := Vector2.ZERO
var drag := Vector2.ZERO
var _velocity := Vector2.ZERO
var _focus := Vector2.ZERO
var _previous_target := Vector2.ZERO

func bind(view: Camera2D, target: CharacterBody2D) -> void:
	camera = view
	player = target
	_origin = camera.position
	camera.position_smoothing_enabled = false
	reset()

func reset() -> void:
	drag = Vector2.ZERO
	_velocity = Vector2.ZERO
	if is_instance_valid(camera) and is_instance_valid(player):
		_focus = player.global_position + _origin
		_previous_target = _focus
		camera.position = _origin
		camera.position_smoothing_enabled = false
		camera.reset_smoothing()

func tick(delta: float, paused: bool, comfort: float) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(player): return
	var target := player.global_position + _origin
	if comfort <= 0:
		reset()
		return
	if paused: return
	if target.distance_to(_previous_target) > TELEPORT_DISTANCE:
		reset()
		return
	_previous_target = target
	var dt := clampf(delta, 0, 0.05)
	var omega := DASH_RESPONSE if player.dashing else FOLLOW_RESPONSE
	var change := _focus - target
	var spring := _velocity + change * omega
	var decay := exp(-omega * dt)
	_focus = target + (change + spring * dt) * decay
	_velocity = (_velocity - spring * omega * dt) * decay
	drag = (_focus - target).limit_length(MAX_DRAG)
	_focus = target + drag
	camera.position = _origin + drag * clampf(comfort, 0, 1)
