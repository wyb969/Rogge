extends Node2D
@export var player: Node2D
@export var relative_pos: Vector2
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D

const BASE_FLIGHT_SPEED: = 200.0
const MAX_FLIGHT_SPEED: = 600
const HIT_RADIUS: = 14.0
var level: = 1
var weapon_demage: float = 10.0
var max_speed: int = 200
var max_distance: int = 200
var rotate_speed: float = 4.0
var flying_out: = false
var returning: = false
var start_pos: Vector2
var fly_dir: = Vector2.RIGHT
var _outbound_distance: = 0.0
var _hit_ids: = {}
var _sweep_shape: = CapsuleShape2D.new()
var _sweep_query: = PhysicsShapeQueryParameters2D.new()

func _ready() -> void :
	_sweep_query.shape = _sweep_shape

	area_2d.monitoring = false
	if is_instance_valid(player):
		global_position = player.global_position + relative_pos

func _physics_process(delta: float) -> void :
	if not is_instance_valid(player):
		return
	var hand: = player.global_position + relative_pos
	if not flying_out and not returning:
		global_position = hand
		return
	rotation += rotate_speed * delta
	if flying_out:
		var step: = minf(float(max_speed) * delta, maxf(0.0, max_distance - _outbound_distance))
		_move_with_hits(global_position + fly_dir * step)
		_outbound_distance += step
		if _outbound_distance >= max_distance:
			flying_out = false
			returning = true
			_hit_ids.clear()
	else:

		_move_with_hits(global_position.move_toward(hand, float(max_speed) * delta))
		if global_position.is_equal_approx(hand):
			returning = false
			rotation = 0.0

func _move_with_hits(destination: Vector2) -> void :
	var before: = global_position
	global_position = destination
	var motion: = destination - before
	var radius: = HIT_RADIUS * maxf(absf(global_scale.x), absf(global_scale.y))
	_sweep_shape.radius = radius
	_sweep_shape.height = motion.length() + radius * 2.0
	_sweep_query.transform = Transform2D(motion.angle() - PI * 0.5, (before + destination) * 0.5)
	_sweep_query.collision_mask = area_2d.collision_mask
	for result in get_world_2d().direct_space_state.intersect_shape(_sweep_query, 128):
		var body: Node = result.collider
		if not _live_target(body) or _hit_ids.has(body.get_instance_id()):
			continue
		_hit_ids[body.get_instance_id()] = true
		body.apply_hit({
			"damage": weapon_demage, 
			"direction": (body.global_position - before).normalized(), 
			"source": self, 
		})

func _live_target(body: Node) -> bool:
	if not is_instance_valid(body) or body.is_queued_for_deletion() or not body is Node2D or not body.has_method("apply_hit"):
		return false
	for flag in ["is_dying", "is_dead", "_death_started"]:
		if flag in body and body.get(flag):
			return false
	for hp in ["health", "boss_current_health"]:
		if hp in body and float(body.get(hp)) <= 0.0:
			return false
	return true

func _on_attack_timer_timeout() -> void :
	start_attack()

func get_nearest_enemy() -> Node2D:
	return CombatTargets.nearest(global_position)

func start_attack() -> void :
	if flying_out or returning or not is_instance_valid(player):
		return
	global_position = player.global_position + relative_pos
	var target_enemy: = get_nearest_enemy()
	if target_enemy == null:
		return
	start_pos = global_position
	fly_dir = (target_enemy.global_position - start_pos).normalized()
	if fly_dir.is_zero_approx():
		fly_dir = Vector2.RIGHT
	_outbound_distance = 0.0
	_hit_ids.clear()
	flying_out = true
	returning = false

func handle_level_up(character_level: int) -> void :
	var next := upgrade_preview(character_level)
	level += 1
	weapon_demage = next.damage
	max_speed = next.speed

func upgrade_preview(character_level: int) -> Dictionary:
	var upgrades := float(level)
	return {"damage": weapon_demage * (1.0 + 0.12 * character_level + 0.015 * character_level * character_level),
		"speed": mini(MAX_FLIGHT_SPEED, roundi(BASE_FLIGHT_SPEED * (1.0 + 0.12 * upgrades + 0.015 * upgrades * upgrades)))}
