extends Node2D

var player: Node2D
var damage: float = 8.0
var fire_cd: float = 0.7
var orbit_radius: float = 48.0
var orbit_angle: float = 0.0
var orbit_speed: float = 2.2
var life_left: float = 8.0
var fire_timer: float = 0.0
var bullet_speed: float = 420.0

@onready var sprite: Sprite2D = $Sprite2D

func setup(p: Node2D, dmg: float, cd: float, lifetime: float, angle: float) -> void:
	player = p
	damage = dmg
	fire_cd = cd
	life_left = lifetime
	orbit_angle = angle
	fire_timer = randf_range(0.0, cd * 0.4)

func _process(delta: float) -> void:
	life_left -= delta
	if life_left <= 0.0:
		_fade_and_free()
		return

	orbit_angle += orbit_speed * delta
	if is_instance_valid(player):
		global_position = player.global_position + Vector2.RIGHT.rotated(orbit_angle) * orbit_radius

	if life_left < 1.2 and sprite:
		sprite.modulate.a = 0.45 + 0.55 * absf(sin(life_left * 14.0))

	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = fire_cd
		_shoot()

func _shoot() -> void:
	var target := _nearest_enemy()
	if target == null:
		return
	var dir := (target.global_position - global_position).normalized()
	var bullet := Area2D.new()
	bullet.set_script(preload("res://script/drone_bullet.gd"))
	bullet.collision_layer = 4
	bullet.collision_mask = 8

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	bullet.add_child(shape)

	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([
		Vector2(8, 0), Vector2(-5, -3.5), Vector2(-5, 3.5)
	])
	vis.color = Color(0.55, 0.9, 1.0, 1.0)
	bullet.add_child(vis)

	var container := get_tree().get_first_node_in_group("effect_container")
	if container:
		container.add_child(bullet)
	else:
		get_tree().current_scene.add_child(bullet)

	bullet.global_position = global_position
	bullet.velocity = dir * bullet_speed
	bullet.damage = damage

func _nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var best := INF
	for enemy in get_tree().get_nodes_in_group("EnemyGroup"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if "health" in enemy and float(enemy.health) <= 0.0:
			continue
		var d := global_position.distance_squared_to(enemy.global_position)
		if d < best:
			best = d
			nearest = enemy
	return nearest

func _fade_and_free() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)
