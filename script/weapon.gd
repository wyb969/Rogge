extends Node2D
@export var player: Node2D
@export var relative_pos: Vector2

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var cool_down_timer: Timer = $CoolDownTimer
@onready var fire_point: Node2D = $Sprite2D / FirePoint
@export var bullet: PackedScene
@onready var muzzle_flash: CPUParticles2D = $Sprite2D / MuzzleFlash
@onready var bullet_shell: CPUParticles2D = $Sprite2D / BulletShell
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var line_2d: Line2D = $Line2D
@onready var auto_attack_timer: Timer = $AutoAttackTimer

var aim_tween: Tween
var recoil_tween: Tween

var gun_base_position: Vector2

@export var aim_duration: = 0.2
@export var recoil_distance: = 6.0
@export var recoil_back_time: = 0.04
@export var recoil_return_time: = 0.08

var level: = 0
var base_fire_interval = 0.5
var fire_interval: = 0.5
var damage: int = 15
const BULLET_SPEED = 10
var bullet_count: = 1
var pierce: = 0
var bullet_scale: = 0.4

var cool_down: bool = true
var line_count = 10
var cooldown_scale: float = 1.0
var _base_shot_lock: float = 0.064


func _ready() -> void :
	sprite_2d.material = GamePalette.ramp_material(&"friendly")
	muzzle_flash.color_ramp = GamePalette.weapon_gradient()
	bullet_shell.color = GamePalette.FRIENDLY_LIGHT
	line_2d.clear_points()
	if player:
		global_position = player.global_position + relative_pos
		gun_base_position = sprite_2d.position
	if cool_down_timer:
		_base_shot_lock = cool_down_timer.wait_time
	visible = false
	set_process(false)
	set_physics_process(false)


func _process(delta: float) -> void :
	if player:
		global_position = player.global_position + relative_pos
	line_2d.add_point(fire_point.global_position)
	if (line_2d.get_point_count() > 40):
		line_2d.remove_point(0)

func shoot() -> void :
	if ( !cool_down):
		return
	cool_down = false
	cool_down_timer.start()

	var instance = bullet.instantiate()
	var container: = get_parent().get_node_or_null("EffectContainer")
	if container == null:
		container = self
	container.add_child(instance)
	AudioManager.play_shoot()
	instance.global_position = fire_point.global_position
	var v = Vector2.RIGHT.rotated(sprite_2d.global_rotation) * BULLET_SPEED
	var lights: = preload("res://script/combat_lighting.gd").find(self)
	if lights != null: lights.muzzle(fire_point.global_position, v.normalized(), fire_point)
	instance.setVelocity(v)
	instance.setBulletDemage(damage + randi_range(5, 15))
	instance.pierce = pierce
	instance.scale = Vector2.ONE * bullet_scale
	var rotation_rad = v.angle()
	muzzle_flash.angle_min = rad_to_deg( - rotation_rad)
	muzzle_flash.angle_max = rad_to_deg( - rotation_rad)
	bullet_shell.emitting = true
	muzzle_flash.emitting = true

func get_texture() -> Texture2D:
	var t = sprite_2d.texture
	return t

func _on_cool_down_timer_timeout() -> void :
	cool_down = true


func get_nearest_alive_enemy(from_pos: Vector2) -> Node2D:
	return CombatTargets.nearest(from_pos)


func _on_auto_attack_timer_timeout() -> void :
	var target = get_nearest_alive_enemy(sprite_2d.global_position)
	if target == null:
		return
	var target_pos = target.global_position
	var sprite_pos = sprite_2d.global_position
	var dir_vector = (target_pos - sprite_pos).normalized()
	tween_look_at(target_pos)
	shoot()
	play_recoil(target_pos)

func tween_look_at(target_pos: Vector2) -> void :
	var dir: = target_pos - sprite_2d.global_position

	if dir.length_squared() <= 0.01:
		return

	var target_angle: = dir.angle()


	var current_angle: = sprite_2d.rotation
	target_angle = current_angle + wrapf(
		target_angle - current_angle, 
		- PI, 
		PI
	)

	if aim_tween != null and aim_tween.is_valid():
		aim_tween.kill()

	aim_tween = create_tween()
	aim_tween.set_trans(Tween.TRANS_BACK)
	aim_tween.set_ease(Tween.EASE_OUT)
	aim_tween.tween_property(
		sprite_2d, 
		"rotation", 
		target_angle, 
		aim_duration
	)

	sprite_2d.flip_v = dir.x < 0

func play_recoil(dir: Vector2) -> void :
	if dir.length_squared() <= 0.01:
		return

	dir = dir.normalized()

	if recoil_tween != null and recoil_tween.is_valid():
		recoil_tween.kill()

	sprite_2d.position = gun_base_position

	recoil_tween = create_tween()
	recoil_tween.set_trans(Tween.TRANS_QUAD)
	recoil_tween.set_ease(Tween.EASE_OUT)

	recoil_tween.tween_property(
		sprite_2d, 
		"position", 
		gun_base_position - dir * recoil_distance, 
		recoil_back_time
	)

	recoil_tween.tween_property(
		sprite_2d, 
		"position", 
		gun_base_position, 
		recoil_return_time
	)

func upgrade() -> void :
	level += 1
	damage = damage_for_upgrade(level)
	if level == 1:
		visible = true
		set_process(true)
		set_physics_process(true)
		auto_attack_timer.start()
		pierce = 3

	if level >= 2:
		pierce = level * 1 + 3

	bullet_scale = (level - 1) * 0.01 + 0.4
	_sync_cooldown_timers()

func apply_cooldown_scale(scale: float) -> void :
	cooldown_scale = clampf(scale, 0.45, 1.0)
	_sync_cooldown_timers()

func _sync_cooldown_timers() -> void :
	fire_interval = interval_for(level)
	if auto_attack_timer != null:
		auto_attack_timer.wait_time = fire_interval
	if cool_down_timer != null:
		cool_down_timer.wait_time = maxf(0.02, _base_shot_lock * cooldown_scale)

func damage_for_upgrade(rank: int) -> int:
	return damage + 10 * rank

func interval_for(rank: int) -> float:
	return maxf(0.05, (base_fire_interval - 0.08 * float(maxi(rank - 1, 0))) * cooldown_scale)
