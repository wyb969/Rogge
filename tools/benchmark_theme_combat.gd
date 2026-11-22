extends SceneTree

# Run the same external script against both exports with --headless --max-fps 60
# --main-pack <index.pck> --script <absolute path to this file> -- <group>.
const SETS := preload("res://script/equipment_combos.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var groups := {"none": [], "dragon": SETS.DRAGON_MEMBERS, "pocket": SETS.POCKET_MEMBERS,
		"dimension": SETS.DIMENSION_MEMBERS, "crimson": SETS.CRIMSON_MEMBERS,
		"mixed": SETS.DRAGON_MEMBERS + SETS.POCKET_MEMBERS + SETS.DIMENSION_MEMBERS + SETS.CRIMSON_MEMBERS,
		"classic": ["axe_up", "circle_up", "gun_up"]}
	var args := OS.get_cmdline_user_args()
	var group := args[0] if not args.is_empty() else "mixed"
	if not groups.has(group):
		push_error("Unknown equipment group " + group)
		quit(1)
		return
	seed(47)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 4: await process_frame
	await main._launch_run(&"", {"cards": groups[group]})
	var game: Node = main.game
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.weather._select(0, true)
	game.weather.set_hazard(0)
	game.player.hurt_lock = 9999
	game.spawner.max_enmey_count = 96
	game.spawner.enemy_array.assign([load("res://resource/Enemy_1.tres")])
	game.spawner._pattern_stage = -1
	var origin: Vector2 = game.player.global_position
	for i in 96:
		var offset := Vector2.from_angle(TAU * (i % 24) / 24.0) * (42 + 36 * floori(i / 24.0))
		game.spawner.spawn(origin + offset, false)
	for actor in get_nodes_in_group("EnemyGroup"): actor.health = 99999

	var samples: Array[int] = []
	var matches := 0
	for repeat in 9:
		var start := Time.get_ticks_usec()
		for j in 200:
			var a := origin + Vector2((j % 24) * 13 - 150, (j % 19) * 15 - 140)
			matches += game.turtle_school.swept(a, a + Vector2(12, -5), 18).size()
		samples.append(Time.get_ticks_usec() - start)
	samples.sort()
	print("SWEEPS ", group, " median_us=", samples[4], " matches=", matches)

	for i in 8: await process_frame
	var fx: Node = game.combat_feedback.impact_feedback
	var previous_stops: int = fx.stops
	var last := Time.get_ticks_usec()
	samples.clear()
	for tick in 360:
		if tick % 60 == 0:
			var direction := "right" if tick % 120 == 0 else "left"
			Input.action_release("left" if direction == "right" else "right")
			Input.action_press(direction)
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(now - last)
		last = now
	Input.action_release("left")
	Input.action_release("right")
	samples.sort()
	print("COMBAT ", group, " p50_us=", samples[180], " p95_us=", samples[342],
		" p99_us=", samples[356], " stops=", fx.stops - previous_stops,
		" enemies=", get_node_count_in_group("EnemyGroup"))
	await main._on_game_end_ui_main_menu_pressed()
	main.queue_free()
	for i in 3: await process_frame
	quit()
