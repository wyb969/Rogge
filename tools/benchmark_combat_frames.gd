extends SceneTree

# Run against either revision with --headless --fixed-fps 60 --script <absolute path>.
# Fixed simulation steps remove vsync and display pacing from the CPU comparison.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	seed(47)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for tick in 4:
		await process_frame
	var start := Time.get_ticks_usec()
	await main._launch_run(&"")
	print("ENTRY ", Time.get_ticks_usec() - start)
	var game: Node = main.game
	var times: Array[int] = []
	for i in 12:
		start = Time.get_ticks_usec()
		game._on_stage_advanced(2 + i % 5)
		times.append(Time.get_ticks_usec() - start)
	times.sort()
	print("STAGE ", times[6], " ", times[11])

	seed(47)
	game.spawner.enemy_array.assign([preload("res://resource/Enemy_1.tres")])
	game.spawner._pattern_stage = -1
	game.weather._select(0, true)
	game.weather.set_hazard(0)
	start = Time.get_ticks_usec()
	game.spawner.amount_spawn(5)
	print("WAVE ", Time.get_ticks_usec() - start)
	game.spawner.max_enmey_count = 96
	for i in range(5, 96):
		game.spawner.spawn(Vector2.ZERO, false)
	var actors := get_nodes_in_group("EnemyGroup")
	assert(actors.size() == 96)
	for i in actors.size():
		var actor: Node2D = actors[i]
		actor.health = 100000
		actor.global_position = Vector2(150 + (i % 12) * 26, -90 + floori(i / 12.0) * 26)
		actor.reset_physics_interpolation()
	game.player.player_health = 100000
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	times.clear()
	for tick in 120:
		start = Time.get_ticks_usec()
		await process_frame
		times.append(Time.get_ticks_usec() - start)
	assert(not paused and get_node_count_in_group("EnemyGroup") == 96)
	times.sort()
	print("COMBAT ", times[60], " ", times[114])
	quit()
