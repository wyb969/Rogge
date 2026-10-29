extends Node2D
## Small enemy shot. Damages the player by distance so the large pickup
## collider does not count as a hit.

var velocity: Vector2 = Vector2.ZERO
var damage: float = 30.0
var life: float = 2.7
var color: Color = Color(1.0, 0.86, 0.25, 1)
var live: bool = false

func _ready() -> void:
	add_to_group("enemy_projectile")
	z_index = 8
	queue_redraw()

func launch(origin: Vector2, dir: Vector2, speed: float, dmg: float, tint: Color) -> void:
	var aim := dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	velocity = aim * speed
	damage = dmg
	rotation = aim.angle()
	color = tint
	# Position must be set before the shot can register a hit. Entering the
	# tree can run physics once while the node is still on the parent origin.
	global_position = origin
	live = true
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color(color.r, color.g * 0.35, 0.08, 0.95))
	draw_circle(Vector2.ZERO, 3.0, color)

func _physics_process(delta: float) -> void:
	if not live:
		return
	global_position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) > 18.0:
		return
	if player.has_method("receive_attack"):
		player.receive_attack(damage, self)
	queue_free()
