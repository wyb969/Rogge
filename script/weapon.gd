extends Node2D
@export var player:Node2D
@export var relative_pos:Vector2

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var cool_down_timer: Timer = $CoolDownTimer
@onready var fire_point: Node2D = $Sprite2D/FirePoint
@export var bullet:PackedScene
@onready var muzzle_flash: CPUParticles2D = $Sprite2D/MuzzleFlash
@onready var bullet_shell: CPUParticles2D = $Sprite2D/BulletShell
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var line_2d: Line2D = $Line2D
@onready var auto_attack_timer: Timer = $AutoAttackTimer

var aim_tween: Tween
var recoil_tween: Tween

var gun_base_position: Vector2

@export var aim_duration := 0.20
@export var recoil_distance := 6.0
@export var recoil_back_time := 0.04
@export var recoil_return_time := 0.08

var level :=0
var base_fire_interval = 0.5
var fire_interval := 0.5
var damage:int = 15
const BULLET_SPEED = 10
var bullet_count := 1
var pierce := 0
var bullet_scale := 0.4

var cool_down:bool = true
var line_count = 10

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	line_2d.clear_points()
	if player:
		global_position = player.global_position + relative_pos
		gun_base_position = sprite_2d.position
	visible = false
	set_process(false)
	set_physics_process(false)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player:
		global_position = player.global_position + relative_pos
	line_2d.add_point(fire_point.global_position)
	if (line_2d.get_point_count()>40):
		line_2d.remove_point(0)

func shoot()->void:
	AudioManager.play_shoot()
	if(!cool_down):
		return
	cool_down = false
	cool_down_timer.start()
	#animation_player.play("shoot")
	var main = get_tree().current_scene
	var instance = bullet.instantiate()
	main.add_child(instance)
	instance.global_position = fire_point.global_position
	var v = Vector2.RIGHT.rotated(sprite_2d.global_rotation) * BULLET_SPEED
	instance.setVelocity(v)
	instance.setBulletDemage(damage + randi_range(5,15))
	instance.pierce = pierce
	instance.scale =  Vector2.ONE * bullet_scale
	var rotation_rad = v.angle()
	muzzle_flash.angle_min = rad_to_deg(-rotation_rad)
	muzzle_flash.angle_max = rad_to_deg(-rotation_rad)
	bullet_shell.emitting = true
	muzzle_flash.emitting = true

func get_texture() -> Texture2D:
	var t = sprite_2d.texture
	return t

func _on_cool_down_timer_timeout() -> void:
	cool_down = true


func get_nearest_alive_enemy(from_pos: Vector2) -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_dist_sq := INF

	var enemies = get_tree().get_nodes_in_group("EnemyGroup")

	for enemy in enemies:
		if enemy == null:
			continue

		if not is_instance_valid(enemy):
			continue

		if not enemy is Node2D:
			continue

		# 如果你的 Enemy 有 is_dead 变量
		if "is_dead" in enemy and enemy.is_dead:
			continue

		# 如果你的 Enemy 有 health 变量
		if "health" in enemy and enemy.health <= 0:
			continue

		var dist_sq := from_pos.distance_squared_to(enemy.global_position)

		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest_enemy = enemy

	return nearest_enemy


func _on_auto_attack_timer_timeout() -> void:
	var target = get_nearest_alive_enemy(sprite_2d.global_position)
	if target == null:
		return
	var target_pos = target.global_position
	var sprite_pos = sprite_2d.global_position
	var dir_vector = (target_pos - sprite_pos).normalized()
	tween_look_at(target_pos)
	shoot()
	play_recoil(target_pos)

func tween_look_at(target_pos: Vector2) -> void:
	var dir := target_pos - sprite_2d.global_position

	if dir.length_squared() <= 0.01:
		return

	var target_angle := dir.angle()

	# 避免从 179° 转到 -179° 时绕一大圈
	var current_angle := sprite_2d.rotation
	target_angle = current_angle + wrapf(
		target_angle - current_angle,
		-PI,
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
	# 如果你的枪图默认朝右，敌人在左边时需要翻转
	sprite_2d.flip_v = dir.x < 0

func play_recoil(dir: Vector2) -> void:
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

func upgrade()->void:
	level += 1
	damage = damage + 10 * level
	# 可选：等级越高，射速越快，但不要无限快
	fire_interval = max(0.05, base_fire_interval - 0.08 * (level - 1))
	if level == 1:
		visible = true
		set_process(true)
		set_physics_process(true)
		auto_attack_timer.wait_time = base_fire_interval
		auto_attack_timer.start()
		pierce = 3

	if level >= 2:
		pierce = level*1 + 3

	bullet_scale = (level-1)*0.01 + 0.4

	# 如果你用 Timer 控制自动攻击，需要同步 wait_time
	if auto_attack_timer != null:
		auto_attack_timer.wait_time = fire_interval
