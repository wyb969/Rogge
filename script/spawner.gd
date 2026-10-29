extends Node2D

@export var player: CharacterBody2D
@export var enemy: PackedScene
@export var enemy_array: Array[EnemyData]
@export var boss_warning_scene: PackedScene
@onready var timer: Timer = $Timer
@export var boss: PackedScene

signal boss_defeated
signal stage_advanced(stage: int)

var distance: float = 560
var max_enmey_count: int = 40
var max_distance: float = 820
var current_level: int = 0
var enemy_killed_num: int = 0
const boss_level: int = 4
## Soft cap for a single wave so packs stay readable.
const MAX_WAVE_SIZE: int = 5
const MAX_WAVE_SIZE_STAGE2: int = 7
const STAGE2_BOSS_DELAY: float = 42.0

var stage: int = 1
var stage_boss_countdown: float = -1.0
var _boss_fight_active: bool = false
var _stage1_boss_cleared: bool = false
var _transitioning: bool = false
var _pattern: Array[int] = []
var _pattern_i: int = 0
var _pattern_stage: int = -1
var _buckets: Dictionary = {}
var _stage_label: Label

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


func _ready() -> void:
	_ensure_stage_label()

func _process(delta: float) -> void:
	remove_far_enemy()
	if stage >= 2 and stage_boss_countdown > 0.0 and not _boss_fight_active:
		stage_boss_countdown -= delta
		if stage_boss_countdown <= 0.0:
			stage_boss_countdown = -1.0
			boss_show_up()

func spawn(pos: Vector2, elite: bool):
	if get_tree().get_nodes_in_group("EnemyGroup").size() >= max_enmey_count:
		return
	if enemy == null or enemy_array.is_empty():
		return
	var data := _next_enemy_data()
	if data == null:
		return
	var enemy_instance = enemy.instantiate()
	enemy_instance.set_player_ref(player)
	enemy_instance.set_enemy_data(data)
	enemy_instance.add_to_group("EnemyGroup")
	var power := _power_scale()
	enemy_instance.setHealth(enemy_instance.health * power)
	if enemy_instance.has_method("scale_offense"):
		enemy_instance.scale_offense(power)
	else:
		enemy_instance.setDamage(enemy_instance.damage * power)
	enemy_instance.death_signal.connect(on_enemy_killed)
	if elite:
		enemy_instance.set_elite_status()
	_world_root().add_child(enemy_instance)
	enemy_instance.global_position = pos

func _power_scale() -> float:
	var scale := 1.0 + 0.12 * float(current_level) + 0.015 * float(current_level) * float(current_level)
	if stage >= 2:
		scale *= 1.25
	return scale

func _rebuild_pattern() -> void:
	_pattern_stage = stage
	_pattern_i = 0
	_buckets.clear()
	for data in enemy_array:
		var key := int(data.archetype)
		if not _buckets.has(key):
			_buckets[key] = []
		_buckets[key].append(data)
	# Stage 1 teaches all styles quickly. Stage 2 leans on the new archetypes.
	if stage <= 1:
		_pattern = [
			EnemyData.Archetype.CHASER,
			EnemyData.Archetype.DASHER,
			EnemyData.Archetype.RANGED,
			EnemyData.Archetype.CHASER,
			EnemyData.Archetype.TANK,
			EnemyData.Archetype.DASHER,
		]
	else:
		_pattern = [
			EnemyData.Archetype.DASHER,
			EnemyData.Archetype.TANK,
			EnemyData.Archetype.RANGED,
			EnemyData.Archetype.DASHER,
			EnemyData.Archetype.RANGED,
			EnemyData.Archetype.TANK,
			EnemyData.Archetype.CHASER,
		]

func _next_enemy_data() -> EnemyData:
	if _pattern.is_empty() or _pattern_stage != stage:
		_rebuild_pattern()
	if enemy_array.is_empty():
		return null
	if _pattern.is_empty():
		return enemy_array[0]
	for _attempt in _pattern.size():
		var kind: int = int(_pattern[_pattern_i % _pattern.size()])
		_pattern_i += 1
		var bucket: Array = _buckets.get(kind, [])
		if not bucket.is_empty():
			return bucket[randi() % bucket.size()]
	return enemy_array[0]

func get_random_position(angle: float = -1.0) -> Vector2:
	var spawn_angle := angle
	if spawn_angle < 0.0:
		spawn_angle = randf_range(0.0, TAU)
	var spawn_distance := distance + randf_range(-40.0, 80.0)
	return player.global_position + spawn_distance * Vector2.RIGHT.rotated(spawn_angle)

func amount_spawn(num: int = 1):
	var count := clampi(num, 0, MAX_WAVE_SIZE_STAGE2 if stage >= 2 else MAX_WAVE_SIZE)
	if count <= 0 or player == null:
		return
	# Spread around the player so they don't stack into one blob.
	var base_angle := randf_range(0.0, TAU)
	for i in range(count):
		var angle := base_angle + (TAU * float(i) / float(count)) + randf_range(-0.15, 0.15)
		spawn(get_random_position(angle), false)

func _calc_wave_size() -> int:
	# Slow ramp: early 1-2, mid ~3, late capped. Stage 2 starts denser.
	var cap := MAX_WAVE_SIZE_STAGE2 if stage >= 2 else MAX_WAVE_SIZE
	var size := 1 + int(minute / 2) + int(current_level / 3)
	if stage >= 2:
		size += 2
	return clampi(size, 1, cap)

func on_enemy_killed() -> void:
	enemy_killed_num += 1

func _on_timer_timeout() -> void:
	second += 1
	if _boss_fight_active:
		return
	if stage <= 1 and not _stage1_boss_cleared and current_level >= boss_level:
		boss_show_up()
		return
	# Spawn a small wave every timer tick, not every frame.
	amount_spawn(_calc_wave_size())

func _on_elite_timeout() -> void:
	if _boss_fight_active:
		return
	if stage <= 1 and current_level >= boss_level:
		return
	if get_tree().get_nodes_in_group("EnemyGroup").size() >= max_enmey_count:
		return
	spawn(get_random_position(), true)

func boss_show_up() -> void:
	if _boss_fight_active:
		return
	_boss_fight_active = true
	stage_boss_countdown = -1.0
	if timer:
		timer.stop()
	var warning = boss_warning_scene.instantiate()
	_world_root().add_child(warning)
	# Give the banner / shake / alarm enough time before the boss drops in.
	await get_tree().create_timer(2.2).timeout
	if not is_inside_tree():
		return
	spawn_boss()

func remove_far_enemy() -> void:
	if player == null:
		return
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
	if boss_instance.has_method("configure_stage"):
		boss_instance.configure_stage(stage)
	boss_instance.set_player(player)
	boss_instance.add_to_group("EnemyGroup")
	if boss_instance.has_signal("boss_defeated"):
		boss_instance.boss_defeated.connect(_on_boss_defeated)
	_world_root().add_child(boss_instance)
	boss_instance.global_position = player.global_position + 220.0 * Vector2.RIGHT.rotated(randf_range(0, TAU))

func _on_boss_defeated() -> void:
	enemy_killed_num += 1
	_boss_fight_active = false
	if stage <= 1 and not _stage1_boss_cleared:
		_enter_stage(2)
		return
	boss_defeated.emit()

func _enter_stage(next_stage: int) -> void:
	if _transitioning or stage >= next_stage:
		return
	_transitioning = true
	stage = next_stage
	_stage1_boss_cleared = true
	_clear_minions()
	max_enmey_count = 56
	max_distance = 980.0
	distance = 620.0
	_pattern_stage = -1
	_refresh_stage_label()
	stage_advanced.emit(stage)
	_show_stage_banner(stage)
	if AudioManager.has_method("play_game_bgm"):
		AudioManager.play_game_bgm()
	# Short breather so the STAGE banner reads, then the harder mix starts.
	await get_tree().create_timer(1.15).timeout
	if not is_inside_tree():
		return
	if timer:
		timer.wait_time = 0.85
		timer.start()
	var elite := get_node_or_null("Elite")
	if elite is Timer:
		elite.wait_time = 9.0
		elite.start()
	stage_boss_countdown = STAGE2_BOSS_DELAY
	_transitioning = false

func _clear_minions() -> void:
	for node in get_tree().get_nodes_in_group("EnemyGroup"):
		if not is_instance_valid(node):
			continue
		if node.has_signal("boss_defeated"):
			continue
		node.queue_free()
	for shot in get_tree().get_nodes_in_group("enemy_projectile"):
		if is_instance_valid(shot):
			shot.queue_free()

func _show_stage_banner(next_stage: int) -> void:
	if boss_warning_scene == null:
		return
	var banner = boss_warning_scene.instantiate()
	banner.banner_text = "STAGE %d" % next_stage
	banner.banner_color = Color(0.55, 0.95, 1.0, 1.0)
	banner.flash_tint = Color(0.12, 0.34, 0.85, 1.0)
	banner.outline_color = Color(0.04, 0.1, 0.28, 1.0)
	banner.shake_strength = 7.0
	banner.shake_duration = 0.75
	banner.play_alarm = false
	_world_root().add_child(banner)

func _world_root() -> Node:
	var scene := get_tree().current_scene
	if scene != null:
		return scene
	if get_parent() != null:
		return get_parent()
	return get_tree().root

func _ensure_stage_label() -> void:
	var ui := get_node_or_null("UI")
	if ui == null:
		return
	var label := ui.get_node_or_null("StageLabel") as Label
	if label == null:
		label = Label.new()
		label.name = "StageLabel"
		ui.add_child(label)
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.offset_left = -170.0
	label.offset_top = 16.0
	label.offset_right = 170.0
	label.offset_bottom = 56.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiFonts.apply_to_label(label, 22, true)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 1))
	label.add_theme_constant_override("outline_size", 6)
	_stage_label = label
	_refresh_stage_label()

func _refresh_stage_label() -> void:
	if _stage_label == null or not is_instance_valid(_stage_label):
		return
	_stage_label.text = "STAGE %d" % stage
	if stage >= 2:
		_stage_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35, 1))
	else:
		_stage_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8, 1))
