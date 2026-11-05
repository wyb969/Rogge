extends SceneTree

var failures: Array[String] = []
var checks := 0
var main: Node
var game: Node

func _init() -> void: call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _isolate() -> void:
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.player.set_physics_process(false)
	game.player.global_position = Vector2.ZERO
	game.weather.stop()
	game.variety._courier_left = 99999
	game.bomb_controller.set_physics_process(false)
	for node_name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(node_name).process_mode = Node.PROCESS_MODE_DISABLED

func _enemy(at: Vector2, hp: float = 1000.0) -> Node:
	var actor: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_player_ref(game.player)
	actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
	actor.health = hp
	actor.defense = 0.0
	actor.add_to_group("EnemyGroup")
	actor.death_signal.connect(game.spawner.on_enemy_killed.bind(actor))
	game.add_child(actor)
	actor.global_position = at
	actor.set_physics_process(false)
	return actor

func _active_bomb() -> Dictionary:
	for bomb in game.bomb_controller._bombs:
		if bomb.active: return bomb
	return {}

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	game = main.game
	_isolate()
	var controller: Node = game.bomb_controller
	var bomb_rules: Script = load("res://script/bomb_controller.gd")
	controller._physics_process(20)
	_expect(controller.level == 0 and controller.casts == 0, "an unowned bomb card cannot attack")
	var entry: Dictionary = {}
	for option in game.pause_menu.upgrade_pool:
		if option.id == "bomb": entry = option
	_expect(not entry.is_empty() and entry.max_level == 5 and game.equipment_panel.EQUIP_DEFS.bomb.max_level == 5, "ordinary draft, lottery source and equipment share the bomb rank cap")
	_expect(load(entry.icon) is Texture2D, "bomb has a real imported icon")
	var pool: Array = game.pause_menu.upgrade_pool.duplicate()
	game.pause_menu.upgrade_pool = [entry]
	game.pause_menu.show_upgrade_options()
	game.pause_menu.on_card_selected("bomb")
	_expect(controller.level == 1 and game.equipment_panel.get_level("bomb") == 1 and not paused, "a real draft selection equips the bomb and resumes combat")
	_isolate()
	game.pause_menu.upgrade_pool = pool
	var description: String = game.pause_menu._build_card_data(entry).desc
	_expect(description.contains("65") and description.contains("82") and description.contains("4.08") and description.contains("无人机"), "next-rank preview uses controller stats and explains the three-card combo")
	var near: Node = _enemy(Vector2(100, 0))
	var neighbor: Node = _enemy(Vector2(122, 14))
	var outside: Node = _enemy(Vector2(190, 80))
	var registry: Node = root.get_node("CombatTargets")
	var before_queries: int = registry.queries
	_expect(controller.cast(), "bomb automatically picks a nearby enemy")
	var record := _active_bomb()
	_expect(record.at == Vector2(100, 0), "throw snapshots a fixed ground position")
	controller._physics_process(0.66)
	_expect(near.health == 1000 and controller.detonations == 0, "arc and fuse precede damage")
	controller._physics_process(0.03)
	_expect(near.health == 950 and neighbor.health == 950 and outside.health == 1000 and controller.hits == 2, "a blast damages each in-radius enemy once and respects its boundary")
	_expect(registry.queries - before_queries == 2, "one throw and one detonation use only two registry queries")
	controller._detonate(record)
	_expect(near.health == 950 and controller.detonations == 1, "a consumed bomb cannot detonate twice")
	_expect(near.burn_stacks == 0 and neighbor.burn_stacks == 0 and near.freeze_time == 0, "plain bombs do not introduce default burn, freeze or chained explosions")
	near._apply_crowd_motion(0.15)
	near._apply_move_juice(0)
	_expect(near.velocity.length() > 0 and near.blast_jump_height() > 5 and near.sprite_2d.position.y < -5, "blast creates real body impulse and composes a separate visual hop")
	game.player.hurt_lock = 0
	near.contact_timer = 0
	var hp: float = game.player.player_health
	near._try_contact(0)
	_expect(game.player.player_health == hp, "airborne enemies cannot deal contact damage")
	var light: Node = _enemy(Vector2(400, 0))
	var heavy: Node = _enemy(Vector2(450, 0))
	heavy.body_scale = 2.0
	heavy.is_elite = true
	light.apply_blast_impulse(Vector2(400, 0), 0.3)
	heavy.apply_blast_impulse(Vector2(400, 0), 0.3)
	_expect(heavy._blast_velocity.length() < light._blast_velocity.length(), "large and elite bodies resist blast displacement")
	var dasher: Node = _enemy(Vector2(500, 0))
	dasher.archetype = EnemyData.Archetype.DASHER
	dasher.is_dashing = true
	dasher.dash_time_left = 0.15
	dasher.apply_blast_impulse(Vector2(400, 0), 0.3)
	_expect(not dasher.is_dashing and dasher.dash_timer >= 0.75 and dasher._blast_left > 0.0, "a real blast interrupts a charging agile enemy before launching it")
	var distance_30 := 0.0
	var distance_120 := 0.0
	for dt in [1.0 / 30, 1.0 / 120]:
		light.clear_blast_impulse()
		light.apply_blast_impulse(Vector2(400, 0), 0.3)
		var distance := 0.0
		for _i in roundi(0.3 / dt):
			light.velocity = Vector2.ZERO
			light._apply_crowd_motion(dt)
			distance += light.velocity.x * dt
		if dt > 0.02: distance_30 = distance
		else: distance_120 = distance
	_expect(absf(distance_30 - distance_120) < 0.05, "blast displacement is stable across 30 and 120 physics steps")
	game.variety.clear_combat_effects()
	_expect(controller.level == 1 and controller._bombs.all(func(b: Dictionary): return not b.active) and near._blast_left == 0 and light._blast_left == 0, "stage cleanup clears projectiles, lift and force while retaining bomb rank")
	game.clear_enemies()
	await process_frame
	var critical: Node = _enemy(Vector2(100, 0))
	for _i in 5: game._on_upgrade_selected("critical_glasses")
	controller.cast()
	controller._physics_process(0.7)
	_expect(critical.health == 900, "direct bomb damage applies a full-rank critical exactly once")
	game.player.reset_critical_glasses()
	game.variety.clear_combat_effects()
	critical.health = 1
	game._on_upgrade_selected("monster_necklace")
	var kills: int = game.spawner.enemy_killed_num
	controller.cast()
	controller._physics_process(0.7)
	_expect(critical._death_started and game.spawner.enemy_killed_num == kills + 1 and get_nodes_in_group("healing_orb").size() == 1, "bomb kills grant normal kill and monster-necklace rewards once")
	await process_frame
	game.variety.clear_combat_effects()
	for i in 120: _enemy(Vector2(100 + i % 8, i % 5))
	controller.cast()
	controller._physics_process(0.7)
	_expect(controller._bombs.size() == bomb_rules.MAX_BOMBS and controller._blasts.size() == bomb_rules.MAX_BLASTS and game.combat_feedback.shards.size() <= 128, "dense crowds retain fixed bomb/blast pools and shared bounded particles")
	game.variety.clear_combat_effects()
	for _i in bomb_rules.MAX_BOMBS: _expect(controller.cast(), "fixed projectile slots can be filled without creating nodes")
	_expect(not controller.cast(), "a saturated projectile pool refuses an extra bomb")
	var age: float = controller._bombs[0].age
	paused = true
	controller._physics_process(10)
	_expect(controller._bombs[0].age == age, "pause freezes the fuse and cannot detonate into a reward page")
	paused = false
	game.variety.clear_combat_effects()
	for _i in 8: game._on_upgrade_selected("bomb")
	_expect(controller.level == 5 and game.equipment_panel.get_level("bomb") == 5, "repeated bonus rewards cannot exceed rank five")
	for option in game.pause_menu.available_upgrades(): _expect(option.id != "bomb", "max-rank bomb leaves ordinary and lottery eligibility")
	_expect(is_equal_approx(bomb_rules.stats_for(5).damage, 110) and is_equal_approx(bomb_rules.stats_for(5).radius, 118) and is_equal_approx(bomb_rules.stats_for(5).interval, 2.50563), "rank-five damage, range and cooldown match the published progression")
	game.clear_enemies()
	await process_frame
	game.spawner.debug_start_beast(3)
	var boss: Node = game.spawner._active_bosses[0]
	boss.set_physics_process(false)
	boss.last_hitstop_msec = Time.get_ticks_msec() + 100000
	game.player.global_position = boss.global_position - Vector2(100, 0)
	var boss_hp: float = boss.boss_current_health
	var boss_at: Vector2 = boss.global_position
	controller.cast()
	controller._physics_process(0.7)
	_expect(boss.boss_current_health < boss_hp and boss.global_position == boss_at and not boss.has_method("apply_blast_impulse"), "Boss takes bomb damage while retaining telegraph position and displacement immunity")
	game.variety.clear_combat_effects()
	game.clear_enemies()
	await process_frame
	game.spawner._active_bosses.clear()
	game.spawner._boss_fight_active = false
	game.trials.begin("speed")
	game.trials.start_attempt()
	var wizard: Node = game.trials.enemy
	wizard.set_physics_process(false)
	game.player.global_position = wizard.global_position - Vector2(100, 0)
	var protected_hp: float = wizard.boss_current_health
	_expect(not controller.cast(), "automatic targeting skips an invulnerable speed-trial enemy")
	wizard.trial_state = wizard.TrialState.RECOVER
	wizard._exposed = true
	_expect(controller.cast(), "an exposed trial enemy can be targeted")
	wizard._exposed = false
	wizard.trial_state = wizard.TrialState.LOCK
	controller._physics_process(0.7)
	_expect(wizard.boss_current_health == protected_hp, "a fuse cannot bypass a trial shield that closed after the throw")
	game.trials.reset()
	main.show_main_menu()
	_expect(controller.level == 0 and not game.player.arsenal_shield_active, "return to menu clears bomb ownership and transient invulnerability")
	await main._launch_run(&"bomb5")
	game = main.game
	_expect(game.bomb_controller.level == 5 and game.equipment_panel.get_level("bomb") == 5 and not game.arsenal_combo.unlocked, "rank-five Debug starts equipped without granting an incomplete combo")
	await main._on_game_end_ui_retry_pressed()
	game = main.game
	_expect(game.bomb_controller.level == 5, "Debug retry rebuilds the selected bomb mode")
	await main._launch_run(&"")
	game = main.game
	_expect(game.bomb_controller.level == 0 and game.equipment_panel.get_level("bomb") == 0, "a normal run does not inherit Debug cards")
	main.show_main_menu()
	if failures.is_empty(): print("BOMB CARD OK: %d checks; real draft/upgrade/caps, area/fuse/unique hit, blast hop/force, rewards/crit, trial/Boss rules, fixed pools, pause/cleanup and Debug lifecycle" % checks)
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
