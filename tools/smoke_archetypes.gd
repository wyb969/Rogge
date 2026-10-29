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
	spawner._on_boss_defeated()
	await create_timer(0.2).timeout
	_expect(spawner.stage == 2, "boss death sets stage 2, got %s" % spawner.stage)
	_expect(advanced["stage"] == 2, "stage_advanced emitted 2")
	_expect(victory["hit"] == false, "first boss does not end the run")
	_expect(spawner._stage_label != null and spawner._stage_label.text == "STAGE 2", "HUD reads STAGE 2")
	var bg := game.get_node("InfiniteBackground")
	_expect(bg.tint.r > 0.4 and bg.tint.b < 0.35, "stage 2 tints the ground, tint=%s" % bg.tint)

	await create_timer(1.3).timeout
	_expect(spawner.stage_boss_countdown > 20.0, "stage 2 boss is scheduled, countdown=%s" % spawner.stage_boss_countdown)
	_expect(not spawner.timer.is_stopped(), "stage 2 resumes spawns")
	_expect(spawner.timer.wait_time < 1.0, "stage 2 spawn timer is faster (%s)" % spawner.timer.wait_time)

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
