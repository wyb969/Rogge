extends Node2D
## Companion drone: orbits the player in world space (does not inherit player facing),
## and attacks with a short laser beam instead of projectiles.

var player: Node2D
var damage: float = 8.0
var fire_cd: float = 0.7
var orbit_radius: float = 52.0
var orbit_angle: float = 0.0
var orbit_speed: float = 1.6
var life_left: float = 8.0
var fire_timer: float = 0.0

## Laser beam
var laser_range: float = 260.0
var laser_duration: float = 0.28
var laser_tick: float = 0.09
var laser_time_left: float = 0.0
var laser_tick_left: float = 0.0
var laser_target: Node2D = null
var laser_width: float = 3.2
var _despawning: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var laser_line: Line2D = $LaserLine

func setup(p: Node2D, dmg: float, cd: float, lifetime: float, angle: float) -> void:
	player = p
	damage = dmg
	fire_cd = cd
	life_left = lifetime
	orbit_angle = angle
	fire_timer = randf_range(0.05, cd * 0.35)
	# Keep art upright in world space — never spin with the player.
	rotation = 0.0
	if sprite:
		sprite.rotation = 0.0
	_clear_laser()
	if AudioManager and AudioManager.has_method("play_drone_spawn"):
		AudioManager.play_drone_spawn()

func _ready() -> void:
	if laser_line == null:
		laser_line = Line2D.new()
		laser_line.name = "LaserLine"
		add_child(laser_line)
	laser_line.width = laser_width
	laser_line.default_color = Color(0.45, 0.95, 1.0, 0.95)
	laser_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	laser_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	laser_line.joint_mode = Line2D.LINE_JOINT_ROUND
	laser_line.z_index = 8
	laser_line.visible = false
	# World-space points so the beam is not warped by any local spin.
	laser_line.top_level = true

func _process(delta: float) -> void:
	if _despawning:
		return
	life_left -= delta
	if life_left <= 0.0:
		_clear_laser()
		_fade_and_free()
		return

	# World-space companion orbit — independent of player look / rotation.
	orbit_angle += orbit_speed * delta
	rotation = 0.0
	global_rotation = 0.0
	if sprite:
		sprite.rotation = 0.0

	if is_instance_valid(player):
		var desired := player.global_position + Vector2.from_angle(orbit_angle) * orbit_radius
		# Soft chase so it feels like escort flight, not a rigid stick.
		global_position = global_position.lerp(desired, clampf(10.0 * delta, 0.0, 1.0))

	if life_left < 1.2 and sprite:
		sprite.modulate.a = 0.45 + 0.55 * absf(sin(life_left * 14.0))

	if laser_time_left > 0.0:
		_update_laser(delta)
	else:
		fire_timer -= delta
		if fire_timer <= 0.0:
			fire_timer = fire_cd
			_start_laser()

func _start_laser() -> void:
	var target := _nearest_enemy_in_range()
	if target == null:
		return
	laser_target = target
	laser_time_left = laser_duration
	laser_tick_left = 0.0
	if AudioManager and AudioManager.has_method("play_drone_attack"):
		AudioManager.play_drone_attack()
	_apply_laser_hit()
	_draw_laser_to(target.global_position)

func _update_laser(delta: float) -> void:
	laser_time_left -= delta
	if laser_target == null or not is_instance_valid(laser_target):
		_clear_laser()
		return
	if "health" in laser_target and float(laser_target.health) <= 0.0:
		_clear_laser()
		return
	if global_position.distance_to(laser_target.global_position) > laser_range * 1.15:
		_clear_laser()
		return

	_draw_laser_to(laser_target.global_position)

	laser_tick_left -= delta
	if laser_tick_left <= 0.0:
		laser_tick_left = laser_tick
		_apply_laser_hit()

	if laser_time_left <= 0.0:
		_clear_laser()

func _apply_laser_hit() -> void:
	if laser_target == null or not is_instance_valid(laser_target):
		return
	if not laser_target.is_in_group("EnemyGroup"):
		return
	var dir := (laser_target.global_position - global_position).normalized()
	if laser_target.has_method("apply_hit"):
		laser_target.apply_hit({
			"damage": damage,
			"direction": dir,
			"effect": "drone_laser",
			"source": self
		})

func _draw_laser_to(target_pos: Vector2) -> void:
	if laser_line == null:
		return
	laser_line.visible = true
	laser_line.clear_points()
	laser_line.add_point(global_position)
	laser_line.add_point(target_pos)
	# Pulse width while firing.
	var pulse := 1.0 + 0.35 * absf(sin(Time.get_ticks_msec() * 0.04))
	laser_line.width = laser_width * pulse
	laser_line.default_color = Color(0.55, 0.95, 1.0, 0.55 + 0.4 * pulse)

func _clear_laser() -> void:
	laser_time_left = 0.0
	laser_tick_left = 0.0
	laser_target = null
	if laser_line:
		laser_line.visible = false
		laser_line.clear_points()

func _nearest_enemy_in_range() -> Node2D:
	var nearest: Node2D = null
	var best := laser_range * laser_range
	for enemy in get_tree().get_nodes_in_group("EnemyGroup"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if "health" in enemy and float(enemy.health) <= 0.0:
			continue
		var d := global_position.distance_squared_to(enemy.global_position)
		if d <= best:
			best = d
			nearest = enemy
	return nearest

func _fade_and_free() -> void:
	if _despawning:
		return
	_despawning = true
	_clear_laser()
	if AudioManager and AudioManager.has_method("play_drone_despawn"):
		AudioManager.play_drone_despawn()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)
