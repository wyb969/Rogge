extends Area2D

var velocity: Vector2 = Vector2.ZERO
var burn_stacks: int = 2
var burn_dps: float = 3.0
var explode_radius: float = 70.0
var life: float = 1.1

func _ready() -> void:
	collision_layer = 4
	collision_mask = 8
	monitoring = true
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	rotation += delta * 10.0
	life -= delta
	if life <= 0.0:
		_explode()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("EnemyGroup"):
		_explode()

func _explode() -> void:
	if not is_inside_tree():
		return
	_spawn_burst_fx()
	for enemy in get_tree().get_nodes_in_group("EnemyGroup"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if global_position.distance_to(enemy.global_position) > explode_radius:
			continue
		if enemy.has_method("apply_hit"):
			enemy.apply_hit({
				"damage": burn_dps * 1.5,
				"direction": (enemy.global_position - global_position).normalized(),
				"effect": "burn",
				"burn_stacks": burn_stacks,
				"burn_dps": burn_dps,
				"source": self
			})
		elif enemy.has_method("apply_burn"):
			enemy.apply_burn({
				"burn_stacks": burn_stacks,
				"burn_dps": burn_dps
			})
	queue_free()

func _spawn_burst_fx() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 18
	p.lifetime = 0.35
	p.emitting = false
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 140.0
	p.gravity = Vector2(0, 180)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(1.0, 0.45, 0.15, 1.0)
	p.z_index = 20
	var container := get_tree().get_first_node_in_group("effect_container")
	if container:
		container.add_child(p)
	else:
		get_tree().current_scene.add_child(p)
	p.global_position = global_position
	p.emitting = true
	p.finished.connect(p.queue_free)
