extends Area2D

var velocity: Vector2 = Vector2.RIGHT * 420.0
var damage: float = 8.0
var traveled: float = 0.0
var max_travel: float = 520.0
var hit_done: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 4
	collision_mask = 8
	monitoring = true

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	traveled += velocity.length() * delta
	rotation = velocity.angle()
	if traveled >= max_travel:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if hit_done:
		return
	if not body.is_in_group("EnemyGroup"):
		return
	hit_done = true
	if body.has_method("apply_hit"):
		body.apply_hit({
			"damage": damage,
			"direction": velocity.normalized(),
			"effect": "drone",
			"source": self
		})
	queue_free()
