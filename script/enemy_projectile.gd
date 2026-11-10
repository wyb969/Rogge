extends Node2D



var velocity: Vector2 = Vector2.ZERO
var damage: float = 30.0
var life: float = 2.7
var color: Color = Color(1.0, 0.62, 0.78, 1)
var live: bool = false

func _ready() -> void :
	add_to_group("enemy_projectile")
	z_index = 8
	queue_redraw()

func launch(origin: Vector2, dir: Vector2, speed: float, dmg: float, tint: Color) -> void :
	var aim: = dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	velocity = aim * speed
	damage = dmg
	rotation = aim.angle()
	color = tint


	global_position = origin
	live = true
	queue_redraw()

func _draw() -> void :

	draw_line(Vector2(-17, 0), Vector2(-8, 0), Color(GamePalette.ENEMY_ORANGE, 0.75), 3.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -7), Vector2(4, -7), Vector2(12, 0), 
		Vector2(4, 7), Vector2(-10, 7), Vector2(-6, 0), 
	]), Color(0.025, 0.015, 0.04))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -4), Vector2(3, -4), Vector2(8, 0), 
		Vector2(3, 4), Vector2(-6, 4), Vector2(-3, 0), 
	]), GamePalette.ENEMY_RED)
	draw_line(Vector2(-3, 0), Vector2(4, 0), Color(GamePalette.TELEGRAPH_EDGE, 0.95), 2.0, true)

func _physics_process(delta: float) -> void :
	if not live:
		return
	global_position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var player: = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) > 18.0:
		return
	if player.has_method("receive_attack"):
		player.receive_attack(damage, self)
	queue_free()
