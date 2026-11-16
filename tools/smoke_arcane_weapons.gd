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
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]: game.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
func enemy(game: Node, offset: Vector2) -> Node2D:
	var actor: Node2D = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_player_ref(game.player)
	actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
	actor.health = 10000
	actor.defense = 0
	actor.add_to_group("EnemyGroup")
	game.add_child(actor)
	actor.global_position = game.player.global_position+offset
	actor.set_physics_process(false)
	return actor
func hold(w: Node) -> void:
	w.set_physics_process(false)
	for id in w.IDS: w.cooldowns[id] = 999
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await main._launch_run(&"")
	var game: Node = main.game
	isolate(game)
	var w: Node = game.arcane_weapons
	var ids: Array = []
	for entry in game.pause_menu.available_upgrades(): ids.append(entry.id)
	for id in w.IDS:
		check(ids.has(id),"card is draftable and lottery eligible")
		check(not w.cast(id),"unowned cannot cast")
		check(load("res://assest/sprites/"+id+".svg")!=null,"icon imports")
		game._on_upgrade_selected(id)
		check(w.levels[id]==1 and game.equipment_panel.get_level(id)==1,"actual card dispatch/HUD")
	hold(w)
	var front := enemy(game,Vector2(50,0))
	var back := enemy(game,Vector2(-60,0))
	var far := enemy(game,Vector2(150,0))
	check(w.cast("thorn_whip"),"whip finds nearest enemy")
	check(front.health==9972 and back.health==10000 and far.health==10000,"whip hits only forward cone within radius")
	check(w.cast("pulse_aura"),"aura casts")
	check(front.health==9964 and back.health==9992 and far.health==10000,"aura hits both sides only within radius")
	check(w.cast("rune_bolt"),"rune casts")
	hold(w)
	var rune: Dictionary = w.runes[0]
	rune.direction = Vector2.RIGHT
	w._physics_process(0.8)
	check(front.health==9946 and far.health==9982,"rune sweeps through multiple targets and reflects on wall")
	check(rune.direction.x<0 and absf(rune.at.x-rune.center.x)<=rune.range,"reflection stays within fixed casting region")
	var hp: float = far.health
	w._sweep(rune,far.global_position-Vector2(1,0),far.global_position+Vector2(1,0))
	check(far.health==hp,"same rune cannot immediately repeat hit")
	w._physics_process(0.5)
	check(front.health<9946,"reflected pass can hit after local cooldown")
	w.clear_combat_effects()
	check(w.runes.all(func(x):return not x.active) and w.flashes.all(func(x):return x.left==0),"transition clears projectiles and flash pool")
	paused = true
	check(not w.cast("thorn_whip"),"pause blocks casts")
	paused = false
	for id in w.IDS:
		game._on_treasure_claimed(id,3)
		check(w.levels[id]==4 and game.equipment_panel.get_level(id)==4,"real lottery applies3 levels")
		game._on_treasure_claimed(id,3)
		check(w.levels[id]==5 and game.equipment_panel.get_level(id)==5,"lottery clamps remaining rank")
	check(game.spawner._offense_cards==15,"capped rewards cannot add phantom offense pressure")
	ids.clear()
	for entry in game.pause_menu.available_upgrades(): ids.append(entry.id)
	for id in w.IDS: check(not ids.has(id),"max rank excluded from draft and lottery")
	for i in 100: w.cast("rune_bolt")
	for i in 100: w.cast("thorn_whip")
	check(w.runes.size()==8 and w.flashes.size()==12,"casting cannot grow the pools")
	var before: int = w.hits
	w._process(0.05)
	check(w.hits==before,"render process never deals damage")
	game.end_game()
	check(w.runes.all(func(x):return not x.active),"end_game clears runes")
	await main._launch_run(&"arcane_weapons")
	check(main.game.arcane_weapons.levels.values()==[1,1,1],"Debug equips three new cards")
	check(main.game.relic_weapons.levels.silver_knife==1 and main.game.relic_weapons.levels.holy_water==1,"Debug also exposes fixed knife/water")
	await main._launch_run(&"")
	check(main.game.arcane_weapons.levels.values()==[0,0,0],"new normal run clears Debug loadout")
	if failures.is_empty():print("ARCANE WEAPONS OK: %d checks; cone/radius/ricochet, per-target cooldown, actual lottery caps, bounded effects, pause/end/new-run" % checks)
	for message in failures:push_error(message)
	quit(0 if failures.is_empty() else 1)
