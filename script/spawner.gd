extends Node2D

@export var player: CharacterBody2D
@export var enemy: PackedScene
@export var enemy_array: Array[EnemyData]
@export var boss_warning_scene: PackedScene
@onready var timer: Timer = $Timer
@export var boss: PackedScene

signal boss_defeated

var distance: float = 560
var max_enmey_count: int = 40
var max_distance: float = 820
var current_level: int = 0
var enemy_killed_num: int = 0
const boss_level: int = 4
## Soft cap for a single wave so packs stay readable.
const MAX_WAVE_SIZE: int = 5

var minute: int:
	set(value):
		minute = value
		%Mintue.text = str(minute)

var second: int:
	set(value):
		second = value
		if second >= 60:
			second -= 60
			minute += 1
		%Second.text = str(second).lpad(2, '0')


func _process(_delta: float) -> void:
	remove_far_enemy()

func spawn(pos: Vector2, elite: bool):
	if get_tree().get_nodes_in_group("EnemyGroup").size() >= max_enmey_count:
		return
	var enemy_instance = enemy.instantiate()
	enemy_instance.position = pos
	enemy_instance.set_player_ref(player)
	enemy_instance.set_enemy_data(enemy_array[min(minute % enemy_array.size(), enemy_array.size() - 1)])
	enemy_instance.add_to_group("EnemyGroup")
	enemy_instance.setHealth(enemy_instance.health * (1.0 + 0.12 * current_level + 0.015 * current_level * current_level))
	enemy_instance.setDamage(enemy_instance.damage * (1.0 + 0.12 * current_level + 0.015 * current_level * current_level))
	enemy_instance.death_signal.connect(on_enemy_killed)
	if elite:
		enemy_instance.set_elite_status()
	get_tree().current_scene.add_child(enemy_instance)

func get_random_position(angle: float = -1.0) -> Vector2:
	var spawn_angle := angle
	if spawn_angle < 0.0:
		spawn_angle = randf_range(0.0, TAU)
	var spawn_distance := distance + randf_range(-40.0, 80.0)
	return player.position + spawn_distance * Vector2.RIGHT.rotated(spawn_angle)

func amount_spawn(num: int = 1):
	var count := clampi(num, 0, MAX_WAVE_SIZE)
	if count <= 0:
		return
	# Spread around the player so they don't stack into one blob.
	var base_angle := randf_range(0.0, TAU)
	for i in range(count):
		var angle := base_angle + (TAU * float(i) / float(count)) + randf_range(-0.15, 0.15)
		spawn(get_random_position(angle), false)

func _calc_wave_size() -> int:
	# Slow ramp: early 1-2, mid ~3, late capped at 5.
	var size := 1 + int(minute / 2) + int(current_level / 3)
	return clampi(size, 1, MAX_WAVE_SIZE)

func on_enemy_killed() -> void:
	enemy_killed_num += 1

func _on_timer_timeout() -> void:
	second += 1
	if current_level >= boss_level:
		timer.stop()
		boss_show_up()
		return
	# Spawn a small wave every 1.2s (timer wait_time), not every frame.
	amount_spawn(_calc_wave_size())

func _on_elite_timeout() -> void:
	if current_level >= boss_level:
		return
	if get_tree().get_nodes_in_group("EnemyGroup").size() >= max_enmey_count:
		return
	spawn(get_random_position(), true)

func boss_show_up() -> void:
	var warning = boss_warning_scene.instantiate()
	get_tree().current_scene.add_child(warning)
	await get_tree().create_timer(2.0).timeout
	spawn_boss()

func remove_far_enemy() -> void:
	for enemy_node in get_tree().get_nodes_in_group("EnemyGroup"):
		if enemy_node is Timer:
			continue
		if not is_instance_valid(enemy_node):
			continue
		var dis = player.global_position.distance_to(enemy_node.global_position)
		if dis >= max_distance:
			enemy_node.queue_free()

func handle_level_up(level: int):
	current_level = level

func spawn_boss() -> void:
	AudioManager.play_boss_bgm()
	var boss_instance = boss.instantiate()
	boss_instance.position = player.position + 200 * Vector2.RIGHT.rotated(randf_range(0, TAU))
	boss_instance.set_player(player)
	boss_instance.add_to_group("EnemyGroup")
	if boss_instance.has_signal("boss_defeated"):
		boss_instance.boss_defeated.connect(_on_boss_defeated)
	get_tree().current_scene.add_child(boss_instance)

func _on_boss_defeated() -> void:
	enemy_killed_num += 1
	boss_defeated.emit()
