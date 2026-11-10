extends SceneTree
var failures: Array[String] = []

func _init() -> void :
	call_deferred("_run")

func _run() -> void :
	seed(96910)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	game.add_to_group("game")
	root.add_child(game)
	current_scene = game
	game.start_game()
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	var bg: Node = game.get_node("InfiniteBackground")
	var spawner: Node = game.spawner
	var palette_script = load("res://script/infinite_background.gd")
	var seen_colors: = {}
	var last_opening: = -1
	for _run_id in 64:
		var sample: Node = palette_script.new()
		sample.begin_run()
		var opening: int = sample.palette_id
		seen_colors[opening] = true
		_expect(opening != last_opening, "consecutive opening rolls avoid the previous palette")
		for _repeat in 4:
			sample.apply_stage(1)
			_expect(sample.palette_id == opening, "same-stage palette stays fixed")
		sample.apply_stage(2)
		var second: int = sample.palette_id
		_expect(second != opening, "adjacent stages have distinct colors")
		sample.apply_stage(1)
		sample.apply_stage(2)
		_expect(sample.palette_id == second, "reapplying stages restores their cached colors")
		last_opening = opening
		sample.free()
	_expect(seen_colors.size() == 4, "opening selection reaches all four teal moss variants")
	for color in bg.PALETTE_TINTS:
		var values: Vector2 = bg._shader_mat.get_shader_parameter("ground_values")
		var floor_color: Color = color * (values.x + values.y)
		for highlight in [GamePalette.UI_TEXT, GamePalette.PICKUP_GREEN]:
			var contrast: = (_luminance(highlight) + 0.05) / (_luminance(floor_color) + 0.05)
			_expect(contrast >= 4.5, "white projectile cores and green experience pickups contrast with every floor palette")

	var seen_themes: = {}
	for _run_id in 64:
		spawner._stage_themes.clear()
		spawner.stage = 1
		spawner.current_level = 0
		spawner._rebuild_pattern()
		var primary: EnemyData = spawner.primary_enemy_data
		seen_themes[primary.resource_path] = true
		_expect(primary.archetype == EnemyData.Archetype.CHASER or primary.archetype == EnemyData.Archetype.DASHER, "primary themes are light melee enemies")
		var counts: = {}
		var ranged_count: = 0
		for _draw in 80:
			var data: EnemyData = spawner._next_enemy_data()
			counts[data] = int(counts.get(data, 0)) + 1
			if data.archetype == EnemyData.Archetype.RANGED:
				ranged_count += 1
		_expect(counts.get(primary, 0) == 60, "actual spawn draws contain 75 percent of one specific enemy variant")
		_expect(ranged_count == 4, "opening ranged share stays at five percent")
		spawner.current_level = 8
		spawner._rebuild_pattern()
		_expect(spawner.primary_enemy_data == primary, "level changes do not reroll the theme")
		spawner.stage = 2
		spawner._rebuild_pattern()
		_expect(spawner.primary_enemy_data != primary, "next stage chooses a different main enemy")
		var ranged_slots: = 0
		for data in spawner._pattern:
			if data.archetype == EnemyData.Archetype.RANGED:
				ranged_slots += 1
		_expect(ranged_slots == 2, "later stages gradually introduce more ranged support")
	_expect(seen_themes.size() == 3, "all three primary variants are reachable")


	for primary in [load("res://resource/Enemy_1.tres"), load("res://resource/Enemy2.tres"), load("res://resource/Enemy_5.tres")]:
		for stage_num in [1, 2]:
			spawner.stage = stage_num
			spawner.current_level = 8
			spawner._stage_themes[stage_num] = primary
			spawner._rebuild_pattern()
			for i in 100:
				spawner.spawn(Vector2(4000 + i * 50, 4000), i % 3 == 0)
			_expect(spawner._ranged_alive_count() <= spawner.ranged_alive_limit(), "mixed and elite waves respect ranged caps")
			for enemy in get_nodes_in_group("EnemyGroup"):
				enemy.free()

	spawner.stage = 1
	spawner._stage_themes.clear()
	spawner._ensure_stage_theme()
	var first_theme: EnemyData = spawner.primary_enemy_data
	var first_palette: int = bg.palette_id
	spawner._rest_open = true
	spawner.begin_next_stage()
	_expect(spawner.primary_enemy_data != first_theme and bg.palette_id != first_palette, "real stage transition changes both theme and background")
	await create_timer(1.2, true, false, true).timeout
	spawner.timer.stop()
	spawner.get_node("Elite").stop()
	if failures.is_empty():
		print("STAGE VARIATION OK: 12 safe colors in three stage families, stable/repeat-free teal opening rolls, 3 primary themes, 75% share, stage transition and ranged caps")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _luminance(color: Color) -> float:
	var linear: = color.srgb_to_linear()
	return linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722

func _expect(ok: bool, message: String) -> void :
	if not ok:
		failures.append(message)
