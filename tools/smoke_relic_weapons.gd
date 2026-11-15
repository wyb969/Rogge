extends SceneTree
var failures: Array[String] = []
var checks := 0
var main: Node
func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func isolate(game: Node) -> void:
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.weather.stop()
	game.player.set_physics_process(false)
	game.variety._courier_left = 99999
	if game.level_manager.signal_level_up.is_connected(game.on_level_up): game.level_manager.signal_level_up.disconnect(game.on_level_up)
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]:
		game.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
func enemy(game: Node, offset: Vector2) -> Node2D:
	var actor: Node2D = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_player_ref(game.player)
	actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
	actor.health = 10000.0
	actor.defense = 0.0
	actor.add_to_group("EnemyGroup")
	game.add_child(actor)
	actor.global_position = game.player.global_position+offset
	actor.set_physics_process(false)
	return actor
func hold(w: Node) -> void:
	w.set_physics_process(false)
	for id in w.IDS: w.cooldowns[id] = 999.0
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await main._launch_run(&"")
	var game: Node = main.game
	isolate(game)
	var w: Node = game.relic_weapons
	var entry_ids: Array = []
	for entry in game.pause_menu.upgrade_pool: entry_ids.append(entry.id)
	for id in w.IDS:
		check(entry_ids.has(id) and game.equipment_panel.get_level(id)==0,"new card in draft/reward pool and not initially owned")
		check(not w.cast(id),"unowned weapon cannot cast")
		check(load("res://assest/sprites/"+id+".svg") != null,"original icon imports")
		game._on_upgrade_selected(id)
		check(w.levels[id]==1 and game.equipment_panel.get_level(id)==1,"real dispatch synchronizes weapon/HUD")
	check(game.spawner._offense_cards==3,"three real offense cards counted")
	hold(w)
	var front := enemy(game,Vector2(100,0))
	var far := enemy(game,Vector2(230,0))
	var side := enemy(game,Vector2(100,80))
	game.player.last_move_direction = Vector2.LEFT
	check(w.cast("silver_knife"),"owned knife casts with nearby target")
	hold(w)
	w._physics_process(1.0)
	check(is_equal_approx(front.health,9984) and is_equal_approx(far.health,9984),"moving away still auto-aims and swept knife hits every crossed target once")
	check(is_equal_approx(side.health,10000),"knife does not hit off-path targets")
	w._physics_process(0.1)
	check(is_equal_approx(front.health,9984),"expired knife cannot hit again")
	w.clear_combat_effects()
	check(w.cast("cross_blade"),"cross casts")
	hold(w)
	w._physics_process(1.5)
	check(is_equal_approx(front.health,9936),"cross splits long frame at turn: exactly two24 damage contacts")
	check(is_equal_approx(far.health,9984),"cross range cannot reach distant actor")
	w.clear_combat_effects()
	check(w.cast("holy_water") and w.cast("holy_water"),"two water areas can overlap")
	hold(w)
	w._physics_process(0.5)
	check(is_equal_approx(front.health,9931),"overlap applies only one5 damage tick")
	check(w.water_hits.any(func(hit): return hit.left>0) and w.pools[0].flash>0,"actual water damage produces burst and bright pulse")
	w._process(0.3)
	check(w.water_hits.all(func(hit): return hit.left==0),"water bursts fade in a fixed pool")
	paused = true
	var before: float = front.health
	check(not w.cast("holy_water"),"paused game cannot cast")
	paused = false
	game.variety.clear_combat_effects()
	hold(w)
	w._physics_process(0.5)
	check(front.health==before,"transition clear removes damage zones")
	for id in w.IDS:
		for i in 7: game._on_upgrade_selected(id)
		check(w.levels[id]==5 and game.equipment_panel.get_level(id)==5,"all sources capped at rank5")
		check(w.stats_for(id,5)==w.stats_for(id,99),"stat helper clamps invalid ranks")
	check(game.spawner._offense_cards==15,"over-cap cards add no phantom pressure")
	var available: Array = game.pause_menu.available_upgrades()
	for entry in available: check(not w.IDS.has(entry.id),"maxed weapons excluded from draft and lottery")
	for id in w.IDS:
		var a: Dictionary = w.stats_for(id,1)
		var b: Dictionary = w.stats_for(id,5)
		check(b.interval<a.interval,"upgrades improve frequency")
	for i in 100: w.cast("holy_water")
	for i in 100: w.cast("silver_knife")
	check(w.pools.size()==8 and w.shots.size()==32,"repeated casts cannot grow fixed pools")
	game.end_game()
	check(w.pools.all(func(x):return not x.active) and w.shots.all(func(x):return not x.active),"end game clears all pooled effects")
	await main._launch_run(&"relic_weapons")
	check(main.game.relic_weapons.levels.values()==[1,1,1],"Debug preset equips all three")
	await main._launch_run(&"")
	check(main.game.relic_weapons.levels.values()==[0,0,0],"ordinary new run does not inherit Debug ownership")
	if failures.is_empty(): print("RELIC WEAPONS OK: %d checks; draft/HUD/caps, swept long frames, return hits, overlap, pause/cleanup, bounded pools and Debug isolation" % checks)
	for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
