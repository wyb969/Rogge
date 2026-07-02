extends Area2D

signal coin_collected

var start_pick: bool = false
var player_body:Node2D
var max_speed:int=300
var max_distance:int=5

var base_scale: Vector2
var pickup_tween: Tween
var is_collecting := false

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


var fly_time := 0.0
var fly_duration := 0.35

var bezier_start_pos: Vector2
var bezier_control_pos: Vector2
var is_bezier_started := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	base_scale = scale


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !start_pick:
		return

	if player_body == null or !is_instance_valid(player_body):
		return

	if !is_bezier_started:
		is_bezier_started = true
		fly_time = 0.0

		bezier_start_pos = global_position

		var target_pos := player_body.global_position
		var mid := (bezier_start_pos + target_pos) * 0.5
		var dir := (target_pos - bezier_start_pos).normalized()
		var normal := Vector2(-dir.y, dir.x)

		bezier_control_pos = mid + normal * randf_range(-50.0, 50.0)

	fly_time += delta

	var t = clamp(fly_time / fly_duration, 0.0, 1.0)

	# 平滑一下，前慢后快，更像被吸过去
	var eased_t = t * t * (3.0 - 2.0 * t)
	var size_boost = lerp(1.0, 1.10, eased_t)
	var glow = lerp(1.0, 1.18, eased_t)

	scale = base_scale * size_boost
	modulate = Color(glow, glow, glow, 1.0)
	var target_pos := player_body.global_position

	global_position = bezier2(
		bezier_start_pos,
		bezier_control_pos,
		target_pos,
		eased_t
	)

	var dist := global_position.distance_to(player_body.global_position)
	if dist <= max_distance or t >= 1.0:
		collect_coin()

func bezier2(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 := p0.lerp(p1, t)
	var q1 := p1.lerp(p2, t)
	return q0.lerp(q1, t)


func _on_body_entered(body: Node2D) -> void:
	player_body = body
	start_pickup()

func start_pickup() -> void:
	start_pick = true
	is_bezier_started = false
	if animated_sprite_2d:
		animated_sprite_2d.play("collect")
	if pickup_tween != null and pickup_tween.is_valid():
		pickup_tween.kill()

	scale = base_scale
	modulate = Color.WHITE

	pickup_tween = create_tween()
	pickup_tween.set_trans(Tween.TRANS_BACK)
	pickup_tween.set_ease(Tween.EASE_OUT)

	pickup_tween.tween_property(
		self,
		"scale",
		base_scale * 1.18,
		0.08
	)

func collect_coin() -> void:
	if is_collecting:
		return

	is_collecting = true
	start_pick = false

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)

	tween.parallel().tween_property(self, "scale", base_scale * 0.2, 0.08)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.08)

	await tween.finished

	coin_collected.emit()
	queue_free()
