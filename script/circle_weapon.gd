extends Node2D

@export var weapon_scene:PackedScene
@export var num_weapons: int = 3               # 武器数量
@export var radius: float = 40.0              # 环绕半径
@export var rotation_speed: float = 1.0       # 每秒旋转角度 (度/s)

@export var player:CharacterBody2D

var current_angle: float = 0.0                 # 当前旋转角度
var current_level:int =0
func _ready():
	spawn_weapons()

func spawn_weapons():
	# 清除旧的武器
	for child in get_children():
		child.queue_free()

	# 均匀分布 num_weapons 个武器
	for i in range(num_weapons):
		var angle = deg_to_rad(360.0 / num_weapons * i)
		var weapon = weapon_scene.instantiate()
		add_child(weapon)
		weapon.setLevel(current_level)
		weapon.global_position = Vector2(cos(angle), sin(angle)) * radius + global_position

func _process(delta):
	#current_angle += rotation_speed * delta
	rotation = rotation + rotation_speed * delta
	global_position = player.global_position
	for child in get_children():
		if child.has_method("setLevel"):
			child.setLevel(current_level)

func handle_level_up(level:int):
	rotation_speed = rotation_speed * (1.0 + 0.25 * log(1.0 + level))
	current_level = level
	if level >= 1:
		num_weapons += 1
		spawn_weapons()
	if level >= 7:
		num_weapons *= 2
		spawn_weapons()
