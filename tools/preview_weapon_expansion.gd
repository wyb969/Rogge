extends Node
# Native screenshot fixture only; normal main scene never loads this script.
func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await main._launch_run(&"arcane_weapons")
	var game: Node = main.game
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.weather.stop()
	game.variety._courier_left = 99999
	game.player.set_physics_process(false)
	game.player.last_move_direction = Vector2.RIGHT
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]: game.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	for offset in [Vector2(50,0),Vector2(130,10),Vector2(80,42),Vector2(-60,10)]:
		var actor = load("res://scenes/enemy_shell.tscn").instantiate()
		actor.set_player_ref(game.player)
		actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
		actor.health = 10000
		actor.add_to_group("EnemyGroup")
		game.add_child(actor)
		actor.global_position = game.player.global_position+offset
		actor.set_physics_process(false)
	var w: Node = game.relic_weapons
	w.set_physics_process(false)
	for id in w.IDS:
		for i in 2: game._on_upgrade_selected(id)
		w.cast(id)
		w.cooldowns[id] = 999.0
	w.set_physics_process(false)
	w._physics_process(0.5)
	var a: Node = game.arcane_weapons
	a.set_physics_process(false)
	for id in a.IDS:
		a.cast(id)
		a.cooldowns[id] = 999
	a._physics_process(0.12)
	for size in [Vector2i(900,600),Vector2i(390,844)]:
		get_window().size = size
		await get_tree().process_frame
		await get_tree().process_frame
		w._physics_process(0.5)
		a.cast("thorn_whip")
		a.cast("pulse_aura")
		await RenderingServer.frame_post_draw
		var directory := OS.get_environment("ROGGE_CAPTURE_DIR")
		get_viewport().get_texture().get_image().save_png(directory+"/expansion-%dx%d.png" % [size.x,size.y])
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
