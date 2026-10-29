extends Node2D

@export var player: CharacterBody2D

var level: int = 0
var throw_timer: float = 0.0

func upgrade() -> void:
	level += 1
	if level == 1:
		throw_timer = 0.4

func reset() -> void:
	level = 0
	throw_timer = 0.0

func _process(delta: float) -> void:
	if level <= 0 or not is_instance_valid(player):
		return
	throw_timer -= delta
	if throw_timer <= 0.0:
		_throw_bottle()
		throw_timer = get_throw_interval()

func _throw_bottle() -> void:
	var target := _pick_target()
	var dir := Vector2.RIGHT.rotated(randf() * TAU)
	if target:
		dir = (target.global_position - player.global_position).normalized()

	var bottle := Area2D.new()
	bottle.set_script(preload("res://script/molotov_bottle.gd"))

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	bottle.add_child(shape)

	var spr := Sprite2D.new()
	spr.texture = load("res://assest/sprites/molotov.svg")
	spr.scale = Vector2(0.35, 0.35)
	bottle.add_child(spr)

	var container := get_tree().get_first_node_in_group("effect_container")
	if container:
		container.add_child(bottle)
	else:
		get_tree().current_scene.add_child(bottle)

	bottle.global_position = player.global_position + dir * 18.0
	bottle.velocity = dir * get_throw_speed()
	bottle.burn_stacks = get_burn_stacks()
	bottle.burn_dps = get_burn_dps()
	bottle.explode_radius = get_explode_radius()
	bottle.life = 0.85 + float(level) * 0.05

func _pick_target() -> Node2D:
	var nearest: Node2D = null
	var best := INF
	for enemy in get_tree().get_nodes_in_group("EnemyGroup"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var d := player.global_position.distance_squared_to(enemy.global_position)
		if d < best:
			best = d
			nearest = enemy
	return nearest

func get_throw_interval() -> float:
	return maxf(1.6, 4.2 - float(level) * 0.35)

func get_throw_speed() -> float:
	return 220.0 + float(level) * 18.0

func get_burn_stacks() -> int:
	return 2 + int((level - 1) / 2)

func get_burn_dps() -> float:
	return 2.5 + float(level) * 1.8

func get_explode_radius() -> float:
	return 62.0 + float(level) * 8.0

## Passive for weapon-hit burn chance / stacks.
func get_on_hit_chance() -> float:
	return minf(0.18 + float(level) * 0.07, 0.65)

func get_on_hit_stacks() -> int:
	return 1 + int((level - 1) / 3)
