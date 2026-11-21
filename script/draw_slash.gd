extends Node2D

const FX := preload("res://script/draw_slash_fx.gd")
const SWISH := preload("res://rogge_art/combat-fx/draw-slash/draw.ogg")
const PAGE_SIZE := 64

var level := 0
var _stats := stats_for(1)
var _cooldown := 0.0
var _windup := -1.0
var _damage := 0.0
var _shape := CircleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()
var _fx := FX.new()
var _sound := AudioStreamPlayer.new()
@onready var game: Node = get_parent()

static func stats_for(rank: int) -> Dictionary:
	var step := clampi(rank, 1, 5) - 1
	return {"damage": 32.0 + 8.0 * step, "radius": 90.0 + 14.0 * step, "interval": 2.4 - 0.25 * step}

func _ready() -> void:
	add_child(_fx)
	add_child(_sound)
	AudioManager.configure_sfx(_sound)
	_sound.stream = SWISH
	_sound.volume_db = -10.0
	_query.shape = _shape
	_query.collision_mask = 8
	reset()

func upgrade() -> void:
	level = mini(5, level + 1)
	_stats = stats_for(level)
	_cooldown = minf(_cooldown, _stats.interval)
	set_physics_process(true)

func clear_combat_effects() -> void:
	_windup = -1.0
	_fx.clear()
	_sound.stop()

func reset() -> void:
	clear_combat_effects()
	level = 0
	_cooldown = 0.18
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not game.variety._battle_active():
		if _windup >= 0.0 or _fx.visible or _sound.playing: clear_combat_effects()
		return
	var center: Vector2 = game.player.global_position
	_cooldown -= delta
	if _windup >= 0.0:
		_fx.global_position = center
		_windup -= delta
		if _windup <= 0.0:
			_windup = -1.0
			_sound.play()
			_strike(center)
	elif _cooldown <= 0.0:
		_shape.radius = _stats.radius
		_query.transform = Transform2D(0, center)
		if get_world_2d().direct_space_state.intersect_shape(_query, 1).is_empty():
			_cooldown = 0.15
			return
		_damage = _stats.damage
		_windup = FX.IMPACT_TIME
		_cooldown = _stats.interval
		_fx.play(center, _shape.radius, -1.0 if game.player._facing_left else 1.0)

func _strike(center: Vector2) -> void:
	_query.transform = Transform2D(0, center)
	# Snapshot at impact. Killing a boss can disable combat during damage dispatch.
	var targets := {}
	var excluded: Array[RID] = []
	var world := get_world_2d().direct_space_state
	while true:
		_query.exclude = excluded
		var hits := world.intersect_shape(_query, PAGE_SIZE)
		for hit in hits:
			excluded.append(hit.rid)
			var actor: Node2D = hit.collider
			if actor.is_in_group("EnemyGroup") and game.is_ancestor_of(actor) and actor.has_method("apply_hit"):
				targets[actor.get_instance_id()] = actor
		if hits.size() < PAGE_SIZE: break
	_query.exclude = []
	for id in targets:
		if not game.variety._battle_active(): break
		var actor: Node2D = targets[id]
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_in_group("EnemyGroup"): continue
		if actor.has_method("vulnerable") and not actor.vulnerable(): continue
		actor.apply_hit({"damage": _damage, "direction": center.direction_to(actor.global_position), "source": self})
