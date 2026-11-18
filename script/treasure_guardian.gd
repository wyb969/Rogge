extends "res://script/enemy_shell.gd"

const BODY_SCALE := 1.85
const SLAM_RADIUS: = 70.0 * Dimensions.BOSS

func model_multiplier() -> float:
	return Dimensions.BOSS
var max_health: = 300.0
var slam_damage: = 60.0
var attack_left: = 2.0
var warning_left: = 0.0
var impact_left: = 0.0

var poses := preload("res://script/boss_pose.gd").new()

func _ready() -> void:
	super._ready()
	Dimensions.add_warning_layer(self, _draw_warning)
	poses.setup(self, sprite_2d, "guardian", 10)
	_sprite_base_scale = sprite_2d.scale
	death_signal.connect(_show_open_lid)

func pose_action() -> StringName:
	if electric_stun_left > 0 or terrain_impulse.left > 0: return &"stun"
	if warning_left > 0: return &"slam_warn"
	if impact_left > 0: return &"slam"
	return &"approach"

func play_hit_tween(direction: Vector2):
	super.play_hit_tween(direction)
	poses.hurt_left = 0.18

func _show_open_lid() -> void:
	var chest := AnimatedSprite2D.new()
	chest.sprite_frames = poses.clips
	chest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chest.flip_h = sprite_2d.flip_h
	chest.offset = sprite_2d.offset
	get_parent().add_child(chest)
	chest.global_transform = sprite_2d.global_transform
	chest.z_index = sprite_2d.z_index
	chest.animation_finished.connect(chest.queue_free)
	chest.play(&"open_lid")

func configure_guardian(hp: float, attack_damage: float) -> void :
	death_stain_color = DEATH_STAINS.color_for(&"treasure_guardian")
	max_health = hp
	health = hp
	body_scale = BODY_SCALE
	speed = 42.0
	defense = 0.08
	contact_radius = 32.0
	contact_damage = attack_damage * 0.65
	contact_cooldown = 1.0
	slam_damage = attack_damage
	base_modulate = Color(1.15, 0.9, 0.48)
	marker_color = Color(1.0, 0.82, 0.3)

func _physics_process(delta: float) -> void :
	if _death_started:
		return
	if electric_stun_left>0 or terrain_impulse.left>0:
		_update_statuses(delta)
		if not _death_started: _tick_environment_control(delta)
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
			if attack_left <= 0.0 and is_instance_valid(player_reference) and global_position.distance_to(player_reference.global_position) < 130.0 + added_body_reach():
				warning_left = 0.85
	super._physics_process(delta)
	queue_redraw()

func _steer_chaser(dir: Vector2, move_speed: float) -> void :
	velocity = Vector2.ZERO if warning_left > 0.0 or impact_left > 0.0 else dir * move_speed

func _try_contact(dist: float) -> void :
	if warning_left <= 0.0 and impact_left <= 0.0:
		super._try_contact(dist)

func _draw_warning(canvas: Node2D) -> void:
	var radius: = SLAM_RADIUS / body_scale
	if warning_left > 0.0 or impact_left > 0.0:
		var active: = impact_left > 0.0
		canvas.draw_circle(Vector2.ZERO, radius, Color(1.0, 0.12, 0.08, 0.4 if active else 0.2))
		canvas.draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.02, 0.015, 0.02), 3.0, true)
		canvas.draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(1.0, 0.3, 0.18), 1.5, true)
		canvas.draw_arc(Vector2.ZERO, radius * (1.0 - warning_left / 0.85), 0, TAU, 64, Color(1.0, 0.8, 0.6, 0.7), 1.0, true)

	canvas.draw_arc(Vector2.ZERO, 15.0, 0, TAU, 48, Color(1.0, 0.78, 0.2, 0.8), 1.0, true)
	canvas.draw_rect(Rect2(-22, -54, 44, 5), Color(0.03, 0.025, 0.035))
	canvas.draw_rect(Rect2(-21, -53, 42.0 * clampf(health / max_health, 0, 1), 3), Color(1.0, 0.76, 0.18))

func _cancel_controlled_attack() -> void:
	super._cancel_controlled_attack()
	warning_left = 0
	impact_left = 0
	attack_left = maxf(attack_left,0.8)
