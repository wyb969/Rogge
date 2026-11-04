extends SceneTree

var failures: Array[String] = []
var game: Node

func _init() -> void :
	call_deferred("_run")

func _new_game() -> Node:
	var instance: Node = load("res://scenes/game.tscn").instantiate()
	instance.add_to_group("game")
	root.add_child(instance)
	instance.spawner.timer.stop()
	instance.spawner.get_node("Elite").stop()
	instance.player.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		instance.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	return instance

func _run() -> void :
	game = _new_game()
	var player: Node = game.player
	player.player_health = 300.0
	player.health_bar.set_health(300.0)
	player.shield = 40.0
	game.level_manager.add_coin(6)
	_expect(game.level_manager.level == 1 and player.max_player_health == 525 and player.player_health == 325, "real first XP level adds 25 maximum/current health before card selection")
	_expect(paused and game.pause_menu.visible, "normal upgrade selection still pauses combat")
	var bundle: = 0
	for level in range(1, 5):
		bundle += game.level_manager.get_need_exp(level)
	game.level_manager.add_coin(bundle)
	_expect(game.level_manager.level == 5 and player.growth_level == 5 and player.max_player_health == 625 and player.player_health == 425, "multi-level XP grants each level once while preserving missing health")
	_expect(player.health_bar.max_value == 625 and player.health_bar.health == 425 and player.shield == 40, "HP bar maximum/current and existing shield stay synchronized")
	player.apply_level_growth(5)
	player.apply_level_growth(3)
	game._on_upgrade_selected("axe_up")
	game._on_upgrade_selected("axe_up")
	_expect(player.max_player_health == 625 and player.player_health == 425, "duplicates, older notifications and bonus card stacks do not grant extra growth")
	player.apply_rest_max_hp(150)
	player.apply_level_growth(6)
	_expect(player.max_player_health == 800 and player.player_health == 800, "rest health stacks with later XP growth")
	player.healing_multiplier = 1.5
	player.apply_level_growth(7)
	_expect(player.max_player_health == 825 and player.player_health == 825, "difficulty healing multiplier cannot double-scale a stat increase")
	player.player_health = 0
	player.apply_level_growth(8)
	_expect(player.player_health == 0 and player.max_player_health == 825, "growth cannot revive a dead player")
	game._level_reward_queue.clear()
	paused = false
	game.queue_free()
	await process_frame
	game = _new_game()
	player = game.player
	_expect(player.growth_level == 0 and player.max_player_health == 500, "fresh runs clear all XP health growth")
	var spawner: Node = game.spawner
	_expect(is_equal_approx(spawner.threat_damage_multiplier_for(0, 0, 0, 1), 1.0), "opening enemy attack baseline is unchanged")
	_expect(spawner.threat_damage_multiplier_for(12, 60, 12, 3) < 2.1, "stage-three damage does not inherit quadratic HP scaling")
	_expect(spawner.threat_damage_multiplier_for(100, 3600, 100, 6) <= 2.4, "late pressure has a finite attack multiplier cap")
	_expect(spawner.threat_hp_multiplier_for(20, 120, 20, 3) > spawner.threat_hp_multiplier_for(12, 60, 12, 3), "enemy HP still grows independently")
	for level in [12, 30]:
		player.apply_level_growth(level)
		spawner.stage = 3
		spawner.current_level = level
		spawner._stage_seconds = 60.0 if level == 12 else 900.0
		spawner._offense_cards = level
		for data_path in ["Enemy_1", "Enemy2", "Enemy_3", "Enemy_4", "Enemy_5"]:
			var data: EnemyData = load("res://resource/%s.tres" % data_path)
			spawner.enemy_array.clear()
			spawner.enemy_array.append(data)
			spawner._pattern.clear()
			spawner._stage_themes.clear()
			spawner.spawn(Vector2(500, 0), true)
			var actor: Node = get_nodes_in_group("EnemyGroup").back()
			actor.set_physics_process(false)
			player.full_heal()
			player.shield = 0
			var hp: float = player.player_health
			if actor.archetype == EnemyData.Archetype.RANGED:
				actor._fire_projectile(Vector2.RIGHT)
				var bullet: Node = get_nodes_in_group("enemy_projectile").back()
				bullet.set_physics_process(false)
				bullet.global_position = player.global_position
				bullet._physics_process(0)
			else:
				actor.is_dashing = actor.archetype == EnemyData.Archetype.DASHER
				actor.slam_time_left = 0.1 if actor.archetype == EnemyData.Archetype.TANK else 0.0
				actor.contact_timer = 0
				actor._try_contact(0)
			var loss: float = hp - player.player_health
			_expect(loss > 0 and loss < 300 and player.player_health > 0, "real stage-three elite %s at level %d cannot one-shot a grown player (damage %.1f)" % [data_path, level, loss])
			var after_first: float = player.player_health
			player._physics_process(0.2)
			player.receive_attack(100, actor)
			_expect(player.player_health == after_first, "another enemy within 0.2 seconds cannot stack a second hit")
			player._physics_process(0.26)
			player.receive_attack(40, actor)
			_expect(is_equal_approx(player.player_health, after_first - 40), "damage resumes after the 0.45-second escape window")
			actor.queue_free()
			await process_frame

	var corpse: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	corpse.set_enemy_data(load("res://resource/Enemy_5.tres"))
	corpse.set_player_ref(player)
	game.add_child(corpse)
	corpse.set_physics_process(false)
	corpse._death_started = true
	corpse.contact_timer = 0
	player.hurt_lock = 0
	var hp_before: float = player.player_health
	corpse._try_contact(0)
	_expect(player.player_health == hp_before, "dead actors cannot deal a final phantom contact hit")
	corpse._death_started = false
	corpse.health = 0.1
	corpse.burn_stacks = 1
	corpse.burn_tick = 0.44
	corpse.global_position = player.global_position
	corpse._physics_process(0.02)
	_expect(corpse._death_started and player.player_health == hp_before, "a burn kill during status update cancels this frame's movement and contact")
	if failures.is_empty():
		print("SURVIVAL GROWTH OK: real XP/multi-level growth, HP HUD/shields, rest stacking, no duplicate/card/revive growth, fresh runs, bounded stage-three elite hits and multi-source escape window")
	else:
		for failure in failures:
			push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void :
	if not ok:
		failures.append(message)
