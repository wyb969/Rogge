extends Node2D

var hit_enemies = {}

@export var jump_delay := 0.08
@export var line_lifetime :=  0.14

func start_chain(first_enemy: Node2D, data: Dictionary) -> void:
	var damage: float = data.get("damage", 5.0)
	var chain_count: int = data.get("chain_count", 3)
	var chain_range: float = data.get("chain_range", 180.0)
	var enemy_group: String = data.get("enemy_group", "EnemyGroup")

	var current_enemy := first_enemy

	hit_enemies.clear()
	hit_enemies[current_enemy] = true

	for i in range(chain_count):
		if not is_instance_valid(current_enemy):
			break

		var next_enemy := find_nearest_enemy(
			current_enemy.global_position,
			chain_range,
			enemy_group
		)

		if next_enemy == null:
			break

		var from_pos := current_enemy.global_position
		var to_pos := next_enemy.global_position

		draw_line_between(from_pos, to_pos)

		if next_enemy.has_method("apply_hit"):
			next_enemy.apply_hit({
				"damage": damage,
				"direction": (to_pos - from_pos).normalized(),
				"effect": "lightning",
				"source": self
			})

		hit_enemies[next_enemy] = true
		current_enemy = next_enemy

		await get_tree().create_timer(jump_delay).timeout

	await get_tree().create_timer(line_lifetime).timeout
	queue_free()

func find_nearest_enemy(from_pos: Vector2, search_range: float, enemy_group: String) -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_dist_sq := search_range * search_range

	for enemy in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(enemy):
			continue

		if not enemy is Node2D:
			continue

		if hit_enemies.has(enemy):
			continue

		if "is_dead" in enemy and enemy.is_dead:
			continue

		if "health" in enemy and enemy.health <= 0:
			continue

		var dist_sq := from_pos.distance_squared_to(enemy.global_position)

		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest_enemy = enemy

	return nearest_enemy

func draw_line_between(start_pos: Vector2, end_pos: Vector2) -> void:
	var line := Line2D.new()
	var container := get_tree().get_first_node_in_group("effect_container")
	container.add_child(line)

	line.global_position = Vector2.ZERO
	line.z_index = 999
	line.width = 5.0
	line.default_color = Color(0.55, 0.9, 1.0, 1.0)

	line.points = make_lightning_points(start_pos, end_pos)

	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, line_lifetime)
	tween.finished.connect(line.queue_free)


func make_lightning_points(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments := 5

	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var p := start_pos.lerp(end_pos, t)

		if i != 0 and i != segments:
			p += Vector2(
				randf_range(-10, 10),
				randf_range(-10, 10)
			)

		points.append(p)

	return points
