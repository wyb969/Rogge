extends SceneTree
## Headless check: archetypes move differently, and boss death opens stage 2.

var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	var spawner: Node = game.get_node("Spawner")
	var player: Node = game.get_node("Player")
	spawner.timer.stop()
	var elite: Timer = spawner.get_node("Elite")
	elite.stop()
	for node_name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		var node := game.get_node_or_null(node_name)
		if node:
			node.process_mode = Node.PROCESS_MODE_DISABLED
	player.player_health = 100000.0

	_check_resources()
	_check_roster(spawner)

	var chaser := _spawn(spawner, load("res://resource/Enemy_1.tres"), Vector2(220, 40))
	var dasher := _spawn(spawner, load("res://resource/Enemy_5.tres"), Vector2(-180, 30))
	var tank := _spawn(spawner, load("res://resource/Enemy_3.tres"), Vector2(40, 160))
	var ranged := _spawn(spawner, load("res://resource/Enemy_4.tres"), Vector2(-30, -180))

	_expect(chaser.archetype == EnemyData.Archetype.CHASER, "chaser archetype")
	_expect(dasher.archetype == EnemyData.Archetype.DASHER, "dasher archetype")
	_expect(tank.archetype == EnemyData.Archetype.TANK, "tank archetype")
	_expect(ranged.archetype == EnemyData.Archetype.RANGED, "ranged archetype")
	_expect(dasher.body_scale < 0.9, "dasher is small, scale=%s" % dasher.body_scale)
	_expect(tank.body_scale > 1.6, "tank is large, scale=%s" % tank.body_scale)
	_expect(dasher.deals_own_contact(), "dasher owns contact so player hurtbox does not double-hit")
	_expect(_has_no_nameplate(dasher) and _has_no_nameplate(tank) and _has_no_nameplate(ranged) and _has_no_nameplate(chaser), "enemies have no floating name tags")
	_expect(dasher.base_modulate.r > dasher.base_modulate.b, "dasher tint is warm")
	_expect(tank.base_modulate.b > tank.base_modulate.r, "tank tint is cool")

	var tank_hp_before: float = tank.health
	tank.take_damage(100.0)
	var tank_lost: float = tank_hp_before - tank.health
	_expect(tank_lost < 70.0 and tank_lost > 40.0, "tank defense reduced 100 dmg to %s" % tank_lost)
	_expect(is_instance_valid(tank), "tank survived the mitigated hit")

	var chaser_dummy := _spawn(spawner, load("res://resource/Enemy_1.tres"), Vector2(400, 400))
	var chaser_hp_before: float = chaser_dummy.health
	chaser_dummy.take_damage(100.0)
	var chaser_lost: float = chaser_hp_before - chaser_dummy.health
	_expect(chaser_lost >= 99.0, "chaser took full damage, lost %s" % chaser_lost)

	var max_speed := {
		"chaser": 0.0,
		"dasher": 0.0,
		"tank": 0.0,
		"ranged": 0.0,
	}
	var dasher_lunged := false
	var tank_slammed := false
	var frames := 0
	while frames < 180:
		await physics_frame
		frames += 1
		if not is_instance_valid(dasher) or not is_instance_valid(tank) or not is_instance_valid(ranged) or not is_instance_valid(chaser):
			_fail("an archetype died during the movement sample d=%s t=%s r=%s c=%s" % [
				is_instance_valid(dasher), is_instance_valid(tank), is_instance_valid(ranged), is_instance_valid(chaser)
			])
			break
		max_speed["chaser"] = maxf(max_speed["chaser"], chaser.velocity.length())
		max_speed["dasher"] = maxf(max_speed["dasher"], dasher.velocity.length())
		max_speed["tank"] = maxf(max_speed["tank"], tank.velocity.length())
		max_speed["ranged"] = maxf(max_speed["ranged"], ranged.velocity.length())
		if dasher.is_dashing:
			dasher_lunged = true
		if tank.slam_time_left > 0.0 or tank.slam_windup > 0.0:
			tank_slammed = true

	var shots := 0
	if is_instance_valid(ranged):
		shots = int(ranged.shots_fired)
	for node in get_nodes_in_group("enemy_projectile"):
		if is_instance_valid(node):
			shots += 1
	print("SMOKE speeds chaser=%.1f dasher=%.1f tank=%.1f ranged=%.1f shots=%d lunged=%s slammed=%s" % [
		max_speed["chaser"], max_speed["dasher"], max_speed["tank"], max_speed["ranged"], shots, dasher_lunged, tank_slammed
	])
	_expect(dasher_lunged and max_speed["dasher"] > 250.0, "dasher lunges fast (max %s)" % max_speed["dasher"])
	_expect(max_speed["tank"] < 180.0, "tank stays slower than a dash (max %s)" % max_speed["tank"])
	_expect(tank_slammed, "tank winds up a heavy slam")
	_expect(shots > 0, "ranged fired a projectile")
	_expect(max_speed["chaser"] < 90.0, "chaser stays at walk speed (max %s)" % max_speed["chaser"])
	_expect(max_speed["dasher"] > max_speed["chaser"] + 80.0, "dasher is clearly faster than chaser")

	var victory := {"hit": false}
	spawner.boss_defeated.connect(func() -> void: victory["hit"] = true)
	var advanced := {"stage": 0}
	spawner.stage_advanced.connect(func(next_stage: int) -> void: advanced["stage"] = next_stage)

	game.pause_menu.visible = true
	game._on_rest_requested()
	_expect(game.rest_hub == null or not game.rest_hub.visible, "rest waits while the level-up menu is open")
	game._open_rest_after_level_up("speed_up")
	await process_frame
	_expect(game.rest_hub != null and game.rest_hub.visible, "rest opens after the level-up card")
	game.rest_hub.close_hub()
	paused = false
	game.pause_menu.visible = false

	player.player_health = 40.0
	spawner._on_boss_defeated()
	await process_frame
	_expect(spawner.stage == 1, "first boss opens rest instead of stage 2, stage=%s" % spawner.stage)
	_expect(spawner.timer.is_stopped(), "rest stops the spawn timer")
	_expect(victory["hit"] == false, "first boss does not end the run")
	_expect(game.rest_hub != null and game.rest_hub.visible, "rest hub is open")
	_expect(is_equal_approx(player.player_health, player.max_player_health), "rest fully heals")
	_expect(game.rest_hub.next_button.disabled, "next stage starts locked")
	var hp_before: float = player.max_player_health
	game.rest_hub._on_reward_pressed("max_hp")
	_expect(player.max_player_health > hp_before + 100.0, "max hp reward applied")
	_expect(is_equal_approx(player.player_health, player.max_player_health), "max hp reward refills")
	_expect(not game.rest_hub.next_button.disabled, "next stage unlocks after one reward")
	var def_before: float = player.damage_reduction
	game.rest_hub._on_reward_pressed("defense")
	_expect(is_equal_approx(player.damage_reduction, def_before), "second reward is ignored")
	game.rest_hub._on_next_pressed()
	await create_timer(0.2).timeout
	_expect(spawner.stage == 2, "next stage button starts stage 2, got %s" % spawner.stage)
	_expect(advanced["stage"] == 2, "stage_advanced emitted 2")
	_expect(game.rest_hub == null or not game.rest_hub.visible, "rest hub closes")
	_expect(not paused, "combat pause lifts for stage 2")
	_expect(spawner._stage_label != null and spawner._stage_label.text == "STAGE 2", "HUD reads STAGE 2")
	var bg := game.get_node("InfiniteBackground")
	_expect(bg.tint.r > 0.4 and bg.tint.b < 0.35, "stage 2 tints the ground, tint=%s" % bg.tint)

	await create_timer(1.3).timeout
	_expect(spawner.stage_boss_countdown > 20.0, "stage 2 boss is scheduled, countdown=%s" % spawner.stage_boss_countdown)
	_expect(not spawner.timer.is_stopped(), "stage 2 resumes spawns")
	_expect(spawner.timer.wait_time < 1.0, "stage 2 spawn timer is faster (%s)" % spawner.timer.wait_time)

	var speed_before: float = player.SPEED
	player.apply_rest_move_speed(35.0)
	_expect(is_equal_approx(player.SPEED, speed_before + 35.0), "move speed reward")
	var cd_scale: float = player.apply_rest_cooldown(0.8)
	_expect(is_equal_approx(player.can_dasing_timer.wait_time, 2.4), "dash cooldown scaled, wait=%s" % player.can_dasing_timer.wait_time)
	var gun: Node = game.get_node("Weapon")
	gun.apply_cooldown_scale(cd_scale)
	_expect(gun.fire_interval < 0.5, "gun fire interval scaled, interval=%s" % gun.fire_interval)
	player.hurt_lock = 0.0
	player.player_health = 200.0
	player.apply_rest_defense(0.15)
	player.receive_attack(100.0, null)
	_expect(player.player_health > 110.0 and player.player_health < 120.0, "defense reduced 100 damage, hp=%s" % player.player_health)
	player.full_heal()

	var missing_before: float = player.max_player_health
	player.player_health = missing_before - 10.0
	player._process(3.0)
	_expect(is_equal_approx(player.player_health, missing_before - 10.0), "no regen before the card")
	player.add_regen_level()
	_expect(is_equal_approx(player.regen_amount(), 1.0), "first regen is +1")
	_expect(is_equal_approx(player.regen_interval(), 3.0), "first regen is every 3s")
	player._process(3.0)
	_expect(is_equal_approx(player.player_health, missing_before - 9.0), "regen healed 1")
	player.add_regen_level()
	_expect(player.regen_amount() > 1.0 and player.regen_interval() < 3.0, "later regen cards get stronger")
	player.player_health = 100.0
	player.notify_damage_dealt(40.0)
	_expect(is_equal_approx(player.player_health, 100.0), "no lifesteal before the card")
	player.add_lifesteal_level()
	player.notify_damage_dealt(5.0)
	_expect(is_equal_approx(player.player_health, 100.0), "chip hits do not lifesteal")
	player.notify_damage_dealt(40.0)
	_expect(player.player_health > 100.0 and player.player_health <= 102.0, "lifesteal is small, hp=%s" % player.player_health)
	var pool_ids := {}
	for entry in game.pause_menu.upgrade_pool:
		pool_ids[str(entry["id"])] = true
	_expect(pool_ids.has("regen_up") and pool_ids.has("lifesteal_up"), "level-up pool has both cards")
	var rest_ids := {}
	for btn in game.rest_hub._buttons:
		rest_ids[str(btn.get_meta("reward_id"))] = true
	_expect(rest_ids.has("regen_up") and rest_ids.has("lifesteal_up"), "rest hub offers regen and lifesteal")
	_expect(pool_ids.has("shield_up") and rest_ids.has("shield_up"), "shield card is in level-up and rest")
	player.hurt_lock = 0.0
	player.player_health = 100.0
	player.notify_enemy_killed()
	_expect(is_equal_approx(player.shield, 0.0), "no shield before the card")
	player.add_shield_level()
	_expect(is_equal_approx(player.shield_gain_for(1), 2.0), "first shield gain is +2")
	player.notify_enemy_killed()
	player.notify_enemy_killed()
	_expect(is_equal_approx(player.shield, 4.0), "kills stack shield with no cap, shield=%s" % player.shield)
	player._process(player.shield_idle_for(1) - 0.05)
	_expect(is_equal_approx(player.shield, 4.0), "shield holds while the idle timer is fresh")
	player.notify_enemy_killed()
	_expect(is_equal_approx(player.shield, 6.0), "a new kill refreshes the shield")
	player._process(player.shield_idle_for(1) + 0.5)
	_expect(player.shield < 6.0 and player.shield > 0.0, "shield decays after kills stop, shield=%s" % player.shield)
	player.shield = 5.0
	player._sync_shield_visuals()
	player.damage_reduction = 0.0
	player.hurt_lock = 0.0
	player.player_health = 100.0
	player.receive_attack(3.0, null)
	_expect(is_equal_approx(player.player_health, 100.0) and is_equal_approx(player.shield, 2.0), "shield absorbs before hp")
	player.hurt_lock = 0.0
	player.receive_attack(10.0, null)
	_expect(is_equal_approx(player.shield, 0.0) and player.player_health < 100.0, "overflow damage reaches hp, hp=%s" % player.player_health)
	var fill: Node = player.health_bar.get_node_or_null("ShieldFill")
	player.shield = 8.0
	player._sync_shield_visuals()
	_expect(fill != null and fill.visible and fill.size.x > 1.0, "health bar shows a yellow shield segment")
	_expect(player.shield_gem != null and player.shield_gem.visible, "diamond shield is visible")
	player.add_shield_level()
	_expect(player.shield_gain_for(2) > 2.0 and player.shield_decay_for(2) < player.shield_decay_for(1), "later shield cards gain more and decay slower")
	player.shield = 0.0
	player._sync_shield_visuals()

	spawner._on_boss_defeated()
	_expect(victory["hit"] == true, "second boss clears the run")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "victory does not add slow-mo")

	var defeats := {"n": 0}
	game.game_over.connect(func(stats: Dictionary) -> void:
		if not stats.get("victory", false):
			defeats["n"] += 1
	)
	player.player_health = 1.0
	player.hurt_lock = 0.0
	player.receive_attack(80.0, null)
	_expect(Engine.time_scale > 0.0 and Engine.time_scale < 0.2, "death enters slow-mo, scale=%s" % Engine.time_scale)
	_expect(game.get_node_or_null("DeathSlowmoVeil") != null, "death veil is visible during slow-mo")
	_expect(defeats["n"] == 0, "defeat UI waits until the slow-mo beat ends")
	await create_timer(0.8).timeout
	_expect(is_equal_approx(Engine.time_scale, 1.0), "death slow-mo restores time, scale=%s" % Engine.time_scale)
	_expect(defeats["n"] == 1, "defeat result follows the slow-mo")

	if _failures.is_empty():
		print("SMOKE OK")
		quit(0)
		return
	for failure in _failures:
		print("SMOKE FAIL: ", failure)
	quit(1)

func _check_resources() -> void:
	var dasher = load("res://resource/Enemy_5.tres")
	var tank = load("res://resource/Enemy_3.tres")
	var ranged = load("res://resource/Enemy_4.tres")
	var chaser = load("res://resource/Enemy_1.tres")
	_expect(dasher.archetype == EnemyData.Archetype.DASHER, "Enemy_5 resource is dasher")
	_expect(tank.archetype == EnemyData.Archetype.TANK, "Enemy_3 resource is tank")
	_expect(ranged.archetype == EnemyData.Archetype.RANGED, "Enemy_4 resource is ranged")
	_expect(chaser.archetype == EnemyData.Archetype.CHASER, "Enemy_1 resource is chaser")
	_expect(tank.defense >= 0.4 and tank.health >= 100.0, "tank resource is bulky")
	_expect(dasher.health <= 20.0 and dasher.move_speed >= 100.0, "dasher resource is fragile and fast")
	_expect(ranged.projectile_damage > 20.0, "ranged resource has a projectile")

func _check_roster(spawner: Node) -> void:
	var seen := {}
	for _i in 8:
		var data: EnemyData = spawner._next_enemy_data()
		seen[int(data.archetype)] = true
	_expect(seen.has(EnemyData.Archetype.CHASER), "roster includes chaser")
	_expect(seen.has(EnemyData.Archetype.DASHER), "roster includes dasher")
	_expect(seen.has(EnemyData.Archetype.TANK), "roster includes tank")
	_expect(seen.has(EnemyData.Archetype.RANGED), "roster includes ranged")

func _spawn(spawner: Node, data: EnemyData, offset: Vector2) -> Node:
	var enemy = spawner.enemy.instantiate()
	enemy.set_player_ref(spawner.player)
	enemy.set_enemy_data(data)
	enemy.add_to_group("EnemyGroup")
	spawner.add_child(enemy)
	enemy.global_position = spawner.player.global_position + offset
	return enemy

func _has_no_nameplate(enemy: Node) -> bool:
	if enemy.get_node_or_null("ArchetypeTag") != null:
		return false
	for child in enemy.get_children():
		if child is Label:
			return false
	return true

func _expect(ok: bool, message: String) -> void:
	if not ok:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
