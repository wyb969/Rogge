extends Node2D

@export var player: CharacterBody2D
@export var enemy: PackedScene
@export var enemy_array: Array[EnemyData]
@export var boss_warning_scene: PackedScene
@onready var timer: Timer = $Timer
@export var boss: PackedScene
const MINI_BOSS: = preload("res://scenes/treasure_guardian.tscn")
const MINI_BOSS_DATA: = preload("res://resource/Enemy2.tres")
const FINAL_STAGE: = 6
const STAGE3_MINI_DELAY: = 24.0
const FINAL_BOSS_AT: = 210.0
const WIND_BOSS: = preload("res://scenes/wind_boss.tscn")
var _active_bosses: Array[Node2D] = []
var _wind_attacker: Node2D
var _wind_turn: = 0
var _run_closed: = false
var _spawn_generation: = 0
const BEAST_BOSS: = preload("res://scenes/beast_boss.tscn")
const BEAST_DELAYS: = [55.0, 60.0, 65.0]
var _bosses_cleared: Dictionary = {}
var _endless_trial: = false
const KNIGHT_BOSS: = preload("res://scenes/knight_boss.tscn")

signal boss_defeated
signal stage_advanced(stage: int)
signal rest_requested
signal treasure_earned
signal beast_defeated(stage: int)

var distance: float = 560
var max_enmey_count: int = 40
var max_distance: float = 820
var current_level: int = 0
var enemy_killed_num: int = 0
const boss_level: int = 4

const MAX_WAVE_SIZE: int = 5
const MAX_WAVE_SIZE_STAGE2: int = 7
const STAGE2_BOSS_DELAY: float = 42.0







const LEVEL_LINEAR: = 0.08
const LEVEL_QUAD: = 0.008
const TIME_PER_MIN: = 0.06
const CARD_STEP: = 0.07
const DAMAGE_PER_LEVEL: = 0.04
const DAMAGE_PER_MINUTE: = 0.035
const DAMAGE_PER_CARD: = 0.015
const DAMAGE_MULTIPLIER_CAP: = 2.4
const STAGE_HP: Array[float] = [1.0, 1.38]
const STAGE_DMG: Array[float] = [1.0, 1.18]
const SPAWN_INTERVAL: Array[float] = [1.05, 0.82]
const SPAWN_INTERVAL_MIN: Array[float] = [0.7, 0.55]
const SPAWN_INTERVAL_PER_MIN: = 0.045
const ALIVE_CAP: Array[int] = [32, 44]
const ALIVE_PER_MIN: = 2
const WAVE_PER_MIN: = 0.5
const WAVE_PER_LEVEL: = 0.22

var stage: int = 1
var stage_boss_countdown: float = -1.0
var _boss_fight_active: bool = false
var _stage1_boss_cleared: bool = false
var _rest_open: bool = false
var _transitioning: bool = false
const THEME_ROSTER_SIZE: = 20
const PRIMARY_ROSTER_SLOTS: = 15
var primary_enemy_data: EnemyData
var _stage_themes: Dictionary = {}
var _pattern: Array[EnemyData] = []
var _pattern_i: int = 0
var _pattern_stage: int = -1
var _pattern_level: int = -1
var _stage_label: Label
var _stage_seconds: float = 0.0
var _offense_cards: int = 0
var _mini_spawned: = false
var _mini_cleared: = false
var _mini_countdown: = -1.0
var _mini_reward_claimed: = false
var run_seconds: = 0.0

var minute: int:
	set(value):
		minute = value
		%Mintue.text = str(minute).lpad(2, "0")

var second: int:
	set(value):
		second = value
		if second >= 60:
			second -= 60
			minute += 1
		%Second.text = str(second).lpad(2, "0")


func _ready() -> void :
	_ensure_stage_theme()
	_ensure_stage_label()
	_apply_spawn_pressure()

func _process(delta: float) -> void :


	if _run_closed or get_tree().paused or _rest_open or _transitioning:
		return
	run_seconds += delta
	_sync_run_clock()
	remove_far_enemy()
	if not _boss_fight_active:
		_stage_seconds += delta
	if stage == 3 and not _mini_spawned and _mini_countdown > 0.0:
		_mini_countdown -= delta
		if _mini_countdown <= 0.0:
			spawn_treasure_guardian()
	if _boss_fight_active or _endless_trial:
		return
	if stage == 3:
		stage_boss_countdown = maxf(FINAL_BOSS_AT - run_seconds, 0.0)
		if run_seconds >= FINAL_BOSS_AT and _mini_cleared and _mini_reward_claimed:
			boss_show_up()
	elif stage >= 2 and stage_boss_countdown > 0.0:
		stage_boss_countdown -= delta
		if stage_boss_countdown <= 0.0:
			boss_show_up()

func _sync_run_clock() -> void :
	var total: = int(run_seconds)
	var minutes: = int(total / 60)
	var seconds: = total % 60
	if minute != minutes:
		minute = minutes
	if second != seconds:
		second = seconds

func spawn(pos: Vector2, elite: bool):
	if _run_closed:
		return
	if get_tree().get_nodes_in_group("EnemyGroup").size() >= max_enmey_count:
		return
	if enemy == null or enemy_array.is_empty():
		return
	var data: = _next_enemy_data()
	if data == null:
		return
	var enemy_instance = enemy.instantiate()
	enemy_instance.set_player_ref(player)
	enemy_instance.set_enemy_data(data)
	enemy_instance.add_to_group("EnemyGroup")
	var hp_mul: = threat_hp_multiplier()
	var dmg_mul: = threat_damage_multiplier()
	enemy_instance.setHealth(enemy_instance.health * hp_mul)
	if enemy_instance.has_method("scale_offense"):
		enemy_instance.scale_offense(dmg_mul)
	else:
		enemy_instance.setDamage(enemy_instance.damage * dmg_mul)
	enemy_instance.death_signal.connect(on_enemy_killed.bind(enemy_instance))
	if elite:
		enemy_instance.set_elite_status()

	enemy_instance.health *= get_parent().run_difficulty.health_scale
	_world_root().add_child(enemy_instance)
	enemy_instance.global_position = pos

func note_offense_card() -> void :
	_offense_cards += 1

func threat_hp_multiplier() -> float:
	return threat_hp_multiplier_for(current_level, _stage_seconds, _offense_cards, stage)

func threat_damage_multiplier() -> float:
	return threat_damage_multiplier_for(current_level, _stage_seconds, _offense_cards, stage)

func threat_hp_multiplier_for(level: int, stage_seconds: float, cards: int, stage_num: int) -> float:
	return _pressure(level, stage_seconds, cards) * _stage_row(STAGE_HP, stage_num)

func threat_damage_multiplier_for(level: int, stage_seconds: float, cards: int, stage_num: int) -> float:
	var growth: = 1.0 + DAMAGE_PER_LEVEL * maxi(level, 0) + DAMAGE_PER_MINUTE * maxf(stage_seconds, 0.0) / 60.0 + DAMAGE_PER_CARD * maxi(cards, 0)
	return minf(growth * _stage_row(STAGE_DMG, stage_num), DAMAGE_MULTIPLIER_CAP)

func _pressure(level: int, stage_seconds: float, cards: int) -> float:
	var lv: = float(maxi(level, 0))
	var mins: = maxf(stage_seconds, 0.0) / 60.0
	var from_level: = 1.0 + LEVEL_LINEAR * lv + LEVEL_QUAD * lv * lv
	var from_time: = 1.0 + TIME_PER_MIN * mins
	var from_cards: = 1.0 + CARD_STEP * float(maxi(cards, 0))
	return from_level * from_time * from_cards

func _stage_row(row: Array[float], stage_num: int) -> float:
	var idx: = clampi(stage_num, 1, row.size()) - 1
	return row[idx]

func _apply_spawn_pressure() -> void :
	var idx: = clampi(stage, 1, SPAWN_INTERVAL.size()) - 1
	var mins: = _stage_seconds / 60.0
	var interval: = maxf(SPAWN_INTERVAL[idx] - SPAWN_INTERVAL_PER_MIN * mins, SPAWN_INTERVAL_MIN[idx])
	if timer:
		timer.wait_time = interval
	max_enmey_count = ALIVE_CAP[idx] + int(mins * float(ALIVE_PER_MIN))
	var elite: = get_node_or_null("Elite")
	if elite is Timer:
		elite.wait_time = 14.0 if stage <= 1 else 10.0

func _ensure_stage_theme() -> void :
	if not _stage_themes.has(stage) or not enemy_array.has(_stage_themes[stage]):
		var choices: Array[EnemyData] = []
		for data in enemy_array:
			if data.archetype == EnemyData.Archetype.CHASER or data.archetype == EnemyData.Archetype.DASHER:
				choices.append(data)

		if choices.is_empty():
			for data in enemy_array:
				if data.archetype != EnemyData.Archetype.RANGED:
					choices.append(data)
		if choices.is_empty():
			choices.assign(enemy_array)
		var previous: EnemyData = _stage_themes.get(stage - 1, null)
		if choices.size() > 1 and choices.has(previous):
			choices.erase(previous)
		if choices.is_empty():
			primary_enemy_data = null
			return
		_stage_themes[stage] = choices[randi() % choices.size()]
	primary_enemy_data = _stage_themes[stage]

func _rebuild_pattern() -> void :
	_ensure_stage_theme()
	_pattern_stage = stage
	_pattern_level = current_level
	_pattern_i = 0
	_pattern.clear()
	if primary_enemy_data == null:
		return
	var support: Array[EnemyData] = []
	var ranged: Array[EnemyData] = []
	for data in enemy_array:
		if data.archetype == EnemyData.Archetype.RANGED:
			ranged.append(data)
		elif data != primary_enemy_data:
			support.append(data)
	var ranged_slots: = 0 if ranged.is_empty() else (2 if stage >= 2 and current_level >= 5 else 1)
	for _i in PRIMARY_ROSTER_SLOTS:
		_pattern.append(primary_enemy_data)
	for i in ranged_slots:
		_pattern.append(ranged[i % ranged.size()])
	support.shuffle()
	while _pattern.size() < THEME_ROSTER_SIZE:
		var idx: = _pattern.size() - PRIMARY_ROSTER_SLOTS - ranged_slots
		_pattern.append(support[idx % support.size()] if not support.is_empty() else primary_enemy_data)
	_pattern.shuffle()

func ranged_alive_limit() -> int:
	if stage <= 1:
		return 1 if current_level < 2 else 2
	return mini(2 * stage, stage + int(maxi(current_level, 0) / 4))

func _ranged_alive_count() -> int:
	var count: = 0
	for node in get_tree().get_nodes_in_group("EnemyGroup"):
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node.get("archetype") == EnemyData.Archetype.RANGED:
			count += 1
	return count

func _next_enemy_data() -> EnemyData:
	if _pattern.is_empty() or _pattern_stage != stage or _pattern_level != current_level:
		_rebuild_pattern()
	for _attempt in _pattern.size():
		if _pattern_i >= _pattern.size():
			_pattern.shuffle()
			_pattern_i = 0
		var data: = _pattern[_pattern_i]
		_pattern_i += 1
		if data.archetype == EnemyData.Archetype.RANGED and _ranged_alive_count() >= ranged_alive_limit():
			continue
		return data

	return null

func get_random_position(angle: float = -1.0) -> Vector2:
	var spawn_angle: = angle
	if spawn_angle < 0.0:
		spawn_angle = randf_range(0.0, TAU)
	var spawn_distance: = distance + randf_range(-40.0, 80.0)
	return player.global_position + spawn_distance * Vector2.RIGHT.rotated(spawn_angle)

func amount_spawn(num: int = 1):
	var count: = clampi(num, 0, MAX_WAVE_SIZE_STAGE2 if stage >= 2 else MAX_WAVE_SIZE)
	if count <= 0 or player == null:
		return

	var base_angle: = randf_range(0.0, TAU)
	for i in range(count):
		var angle: = base_angle + (TAU * float(i) / float(count)) + randf_range(-0.15, 0.15)
		spawn(get_random_position(angle), false)

func _calc_wave_size() -> int:

	var cap: = MAX_WAVE_SIZE_STAGE2 if stage >= 2 else MAX_WAVE_SIZE
	var mins: = _stage_seconds / 60.0
	var size: = 1 + int(mins * WAVE_PER_MIN) + int(float(current_level) * WAVE_PER_LEVEL)
	if stage >= 2:
		size += 1
	return clampi(size, 1, cap)

func on_enemy_killed(dead_enemy: Node2D = null) -> void :
	enemy_killed_num += 1
	_grant_kill_shield()
	_drop_necklace_orb(dead_enemy)
	get_parent().variety.note_kill(dead_enemy)

func _on_timer_timeout() -> void :
	if _run_closed:
		return
	if _boss_fight_active:
		return
	_apply_spawn_pressure()
	if stage <= 1 and not _stage1_boss_cleared and current_level >= boss_level:
		boss_show_up()
		return

	amount_spawn(_calc_wave_size())

func _on_elite_timeout() -> void :
	if _run_closed:
		return
	if _boss_fight_active:
		return
	if stage <= 1 and current_level >= boss_level:
		return
	if get_tree().get_nodes_in_group("EnemyGroup").size() >= max_enmey_count:
		return
	spawn(get_random_position(), true)

func boss_show_up() -> void :
	if _run_closed or _boss_fight_active:
		return
	_boss_fight_active = true
	stage_boss_countdown = -1.0
	RunDiagnostics.mark("boss_warning", {"stage": stage}, true)
	if timer:
		timer.stop()
	var warning = boss_warning_scene.instantiate()
	_world_root().add_child(warning)

	var generation: = _spawn_generation
	await get_tree().create_timer(2.2).timeout
	if not is_inside_tree() or _run_closed or generation != _spawn_generation or not _boss_fight_active:
		return
	spawn_boss()

func remove_far_enemy() -> void :
	if player == null:
		return
	for enemy_node in get_tree().get_nodes_in_group("EnemyGroup"):
		if enemy_node is Timer:
			continue
		if not is_instance_valid(enemy_node):
			continue
		var dis = player.global_position.distance_to(enemy_node.global_position)
		if dis >= max_distance and not enemy_node.is_in_group("treasure_guardian") and not enemy_node.has_signal("boss_defeated"):
			enemy_node.queue_free()

func handle_level_up(level: int):
	current_level = level

func spawn_boss() -> void :
	if _run_closed or _rest_open:
		return

	_active_bosses = _active_bosses.filter( func(node): return is_instance_valid(node) and not node.is_queued_for_deletion())
	if not _active_bosses.is_empty() or _bosses_cleared.has(stage):
		return
	_boss_fight_active = true
	stage_boss_countdown = -1.0
	timer.stop()
	get_node("Elite").stop()
	AudioManager.play_boss_bgm(stage)
	if stage >= 3:
		_clear_minions()
	_wind_attacker = null
	_wind_turn = 0
	var count: = 2 if stage == 5 else 1
	for role in count:
		var scene: PackedScene = WIND_BOSS if stage == 5 else (BEAST_BOSS if stage >= 3 else (KNIGHT_BOSS if stage == 2 else boss))
		var boss_instance: Node2D = scene.instantiate()
		if boss_instance.has_method("configure_stage"):
			boss_instance.configure_stage(stage)
		if stage == 5:
			boss_instance.configure_wind_role(role, self)
		boss_instance.set_player(player)
		boss_instance.add_to_group("EnemyGroup")
		_active_bosses.append(boss_instance)
		boss_instance.boss_defeated.connect(_on_boss_defeated.bind(boss_instance))
		_world_root().add_child(boss_instance)
		boss_instance.apply_difficulty_health(get_parent().run_difficulty.health_scale)
		var offset: = 220.0 * Vector2.RIGHT.rotated(randf_range(0, TAU))
		if stage >= 2:
			var camera: = get_viewport().get_camera_2d()
			var zoom_x: = camera.zoom.x if camera != null else 1.0
			var half_width: = get_viewport().get_visible_rect().size.x / maxf(zoom_x, 0.01) * 0.5
			var side_distance: = clampf(half_width - 64.0, 48.0, 145.0)
			if stage == 5:
				offset = Vector2(side_distance * (-1.0 if role == 0 else 1.0), -45.0 if role == 0 else 45.0)
			else:
				offset = Vector2(side_distance * (-1.0 if randf() < 0.5 else 1.0), randf_range(-20.0, 20.0))
		boss_instance.global_position = player.global_position + offset
		boss_instance.reset_physics_interpolation()
		RunDiagnostics.mark("boss_spawn", {"stage": stage, "role": role}, true)

func request_wind_attack(member: Node2D, role: int) -> bool:
	if not _active_bosses.has(member) or member.is_dying:
		return false
	if is_instance_valid(_wind_attacker) and not _wind_attacker.is_dying:
		return _wind_attacker == member
	var other_alive: = false
	for other in _active_bosses:
		if is_instance_valid(other) and other != member and not other.is_dying:
			other_alive = true
	if other_alive and role != _wind_turn:
		return false
	_wind_attacker = member
	return true

func release_wind_attack(member: Node2D, role: int) -> void :
	if _wind_attacker == member:
		_wind_attacker = null
		_wind_turn = 1 - role

func _on_boss_defeated(dead_boss: Node2D = null) -> void :
	if _rest_open or _bosses_cleared.has(stage):
		return
	if dead_boss != null:
		if not _active_bosses.has(dead_boss):
			return
		_active_bosses.erase(dead_boss)
	enemy_killed_num += 1
	_grant_kill_shield()
	_drop_necklace_orb(dead_boss)
	if stage == 5 and not _active_bosses.is_empty():
		return
	_bosses_cleared[stage] = true
	_boss_fight_active = false
	if stage >= 3:
		_rest_open = true
		stage_boss_countdown = -1.0
		timer.stop()
		get_node("Elite").stop()
		_clear_minions()
		beast_defeated.emit(stage)
		return
	if stage < FINAL_STAGE and not _rest_open:
		_open_rest_gate()
		return
	boss_defeated.emit()

func _open_rest_gate() -> void :
	_rest_open = true
	stage_boss_countdown = -1.0
	if timer:
		timer.stop()
	var elite: = get_node_or_null("Elite")
	if elite is Timer:
		elite.stop()
	_clear_minions()
	rest_requested.emit()

func begin_next_stage() -> void :
	if stage >= FINAL_STAGE or not _rest_open:
		return
	_rest_open = false
	_enter_stage(stage + 1)

func _enter_stage(next_stage: int) -> void :
	if _run_closed or _transitioning or stage >= next_stage:
		return
	_transitioning = true
	stage = next_stage
	_stage1_boss_cleared = true
	_clear_minions()
	_stage_seconds = 0.0
	max_distance = 980.0
	distance = 620.0
	_pattern_stage = -1
	_ensure_stage_theme()
	_apply_spawn_pressure()
	_refresh_stage_label()
	stage_advanced.emit(stage)
	_show_stage_banner(stage)
	if AudioManager.has_method("play_game_bgm"):
		AudioManager.play_game_bgm(stage)

	var transition_generation: = _spawn_generation
	await get_tree().create_timer(1.15).timeout
	if not is_inside_tree() or _run_closed or transition_generation != _spawn_generation:
		return
	_apply_spawn_pressure()
	if timer:
		timer.start()
	var elite: = get_node_or_null("Elite")
	if elite is Timer:
		elite.start()
	stage_boss_countdown = maxf(FINAL_BOSS_AT - run_seconds, 0.0) if stage == 3 else (BEAST_DELAYS[stage - 4] if stage >= 4 else STAGE2_BOSS_DELAY)
	_mini_countdown = STAGE3_MINI_DELAY if stage == 3 else -1.0
	_transitioning = false

func _grant_kill_shield() -> void :
	if player != null and player.has_method("notify_enemy_killed"):
		player.notify_enemy_killed()

func _clear_minions() -> void :
	for node in get_tree().get_nodes_in_group("EnemyGroup"):
		if not is_instance_valid(node):
			continue
		if node.has_signal("boss_defeated"):
			continue
		node.queue_free()
	for shot in get_tree().get_nodes_in_group("enemy_projectile"):
		if is_instance_valid(shot):
			shot.queue_free()

func _show_stage_banner(next_stage: int) -> void :
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

	var owner_game: = get_parent()
	if owner_game != null and owner_game.has_method("clear_enemies"):
		return owner_game
	var scene: = get_tree().current_scene
	if scene != null:
		return scene
	if get_parent() != null:
		return get_parent()
	return get_tree().root

func _ensure_stage_label() -> void :
	var ui: = get_node_or_null("UI")
	if ui == null:
		return
	var label: = ui.get_node_or_null("StageLabel") as Label
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

func _refresh_stage_label() -> void :
	if _stage_label == null or not is_instance_valid(_stage_label):
		return
	_stage_label.text = "STAGE %d" % stage
	if stage >= 2:
		_stage_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35, 1))
	else:
		_stage_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8, 1))


func debug_start_stage2_boss() -> void :
	_clear_minions()
	stage = 2
	_ensure_stage_theme()
	_stage1_boss_cleared = true
	_rest_open = false
	_transitioning = false
	_boss_fight_active = true
	stage_boss_countdown = -1.0
	timer.stop()
	var elite: = get_node_or_null("Elite") as Timer
	if elite:
		elite.stop()
	_refresh_stage_label()
	stage_advanced.emit(stage)
	spawn_boss()

func _drop_necklace_orb(dead_enemy: Node2D) -> void :
	if not is_instance_valid(dead_enemy) or not is_instance_valid(player):
		return
	var game: = player.get_parent()
	if game != null and game.has_method("spawn_necklace_orb"):
		game.spawn_necklace_orb(dead_enemy.global_position)


func spawn_treasure_guardian() -> Node2D:
	if _run_closed or _mini_spawned or stage != 3 or _rest_open or not is_instance_valid(player):
		return null
	_mini_spawned = true
	_mini_reward_claimed = false
	var guardian: = MINI_BOSS.instantiate() as Node2D
	guardian.set_enemy_data(MINI_BOSS_DATA)
	guardian.set_player_ref(player)
	guardian.configure_guardian(clampf(42.0 * threat_hp_multiplier() * 4.0, 240.0, 720.0) * get_parent().run_difficulty.health_scale, 
		clampf(48.0 * threat_damage_multiplier(), 48.0, 95.0))
	guardian.add_to_group("EnemyGroup")
	guardian.add_to_group("treasure_guardian")
	guardian.death_signal.connect(_on_guardian_defeated.bind(guardian))
	_world_root().add_child(guardian)
	guardian.global_position = player.global_position + Vector2(-110, -35)
	var banner = boss_warning_scene.instantiate()
	banner.banner_text = "TREASURE GUARDIAN"
	banner.banner_color = Color(1.0, 0.84, 0.3)
	banner.flash_tint = Color(0.28, 0.18, 0.04, 1.0)
	banner.play_alarm = false
	_world_root().add_child(banner)
	return guardian

func _on_guardian_defeated(guardian: Node2D) -> void :
	if _mini_cleared:
		return
	_mini_cleared = true
	on_enemy_killed(guardian)
	treasure_earned.emit()

func debug_start_treasure_guardian() -> void :
	_clear_minions()
	stage = 3
	_stage_seconds = STAGE3_MINI_DELAY
	_ensure_stage_theme()
	_refresh_stage_label()
	stage_advanced.emit(stage)
	stage_boss_countdown = maxf(FINAL_BOSS_AT - run_seconds, 0.0)
	spawn_treasure_guardian()

func complete_treasure_reward() -> void :


	if _mini_cleared:
		_mini_reward_claimed = true

func debug_start_beast(stage_num: int) -> void :
	_clear_minions()
	stage = stage_num
	_ensure_stage_theme()
	_stage1_boss_cleared = true
	_rest_open = false
	_transitioning = false
	_boss_fight_active = true
	stage_boss_countdown = -1
	timer.stop()
	get_node("Elite").stop()
	_refresh_stage_label()
	stage_advanced.emit(stage)
	spawn_boss()

func begin_free_trial() -> void :
	_rest_open = false
	_endless_trial = true
	_boss_fight_active = false
	stage_boss_countdown = -1
	timer.start()
	get_node("Elite").start()
	AudioManager.play_game_bgm(stage)

func stop_run() -> void :
	_run_closed = true
	_spawn_generation += 1
	_boss_fight_active = false
	timer.stop()
	get_node("Elite").stop()
	_wind_attacker = null
	_active_bosses.clear()

func start_run() -> void :
	_run_closed = false
	if not _boss_fight_active and not _rest_open:
		timer.start()
		get_node("Elite").start()
