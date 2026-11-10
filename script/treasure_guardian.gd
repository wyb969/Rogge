extends "res://script/enemy_shell.gd"

const SLAM_RADIUS: = 70.0
var max_health: = 300.0
var slam_damage: = 60.0
var attack_left: = 2.0
var warning_left: = 0.0
var impact_left: = 0.0

func configure_guardian(hp: float, attack_damage: float) -> void :
	death_stain_color = DEATH_STAINS.color_for(&"treasure_guardian")
	max_health = hp
	health = hp
	body_scale = 1.85
	speed = 42.0
	defense = 0.08
	contact_radius = 32.0
	contact_damage = attack_damage * 0.65
	contact_cooldown = 1.0
	slam_damage = attack_damage
	base_modulate = Color.WHITE
	_semantic_kind = &"treasure_guardian"
	var body := get_node_or_null("Sprite2D") as Sprite2D
	if body != null: body.material = GamePalette.ramp_material(&"enemy:treasure_guardian")
	marker_color = GamePalette.ENEMY_TELEGRAPH_EDGE

func _physics_process(delta: float) -> void :
	if _death_started:
		return
	if not is_frozen():
		impact_left = maxf(0.0, impact_left - delta)
		if warning_left > 0.0:
			warning_left = maxf(0.0, warning_left - delta)
			if warning_left <= 0.0:
				impact_left = 0.22
				attack_left = 3.0
				if is_instance_valid(player_reference) and global_position.distance_to(player_reference.global_position) <= SLAM_RADIUS:
					player_reference.receive_attack(slam_damage, self)
		else:
			attack_left -= delta
			if attack_left <= 0.0 and is_instance_valid(player_reference) and global_position.distance_to(player_reference.global_position) < 130.0:
				warning_left = 0.85
	super._physics_process(delta)
	queue_redraw()

func _steer_chaser(dir: Vector2, move_speed: float) -> void :
	velocity = Vector2.ZERO if warning_left > 0.0 or impact_left > 0.0 else dir * move_speed

func _try_contact(dist: float) -> void :
	if warning_left <= 0.0 and impact_left <= 0.0:
		super._try_contact(dist)

func _draw() -> void :
	var radius: = SLAM_RADIUS / body_scale
	if warning_left > 0.0 or impact_left > 0.0:
		var active: = impact_left > 0.0
		draw_circle(Vector2.ZERO, radius, GamePalette.alpha(GamePalette.ENEMY_TELEGRAPH_FILL,0.4 if active else 0.3))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, GamePalette.BLACK, 3.0, true)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, GamePalette.ENEMY_TELEGRAPH_EDGE, 1.5, true)
		draw_arc(Vector2.ZERO, radius * (1.0 - warning_left / 0.85), 0, TAU, 64, GamePalette.alpha(GamePalette.ENEMY_TELEGRAPH_INNER,0.7), 1.0, true)

	draw_arc(Vector2.ZERO, 15.0, 0, TAU, 48, GamePalette.alpha(GamePalette.ENEMY_ORANGE,0.8), 1.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -17), Vector2(-9, -24), Vector2(-4, -21), Vector2(0, -27), Vector2(4, -21), Vector2(9, -24), Vector2(8, -17)]), GamePalette.ENEMY_RUST)
	draw_rect(Rect2(-22, -34, 44, 5), GamePalette.UI_PANEL)
	draw_rect(Rect2(-21, -33, 42.0 * clampf(health / max_health, 0, 1), 3), GamePalette.ENEMY_ORANGE)
