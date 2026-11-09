extends SceneTree

var checks := 0
var failures: Array[String] = []
var main: Node
var game: Node

func _init() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _tooltip_font(control: Control) -> void:
	var font := control.get_theme_font("font", "TooltipLabel")
	var missing := ""
	for index in control.tooltip_text.length():
		var code := control.tooltip_text.unicode_at(index)
		if code > 32 and not font.has_char(code): missing += String.chr(code)
	_expect(not control.tooltip_text.is_empty() and missing.is_empty(), "packaged tooltip font covers real text: " + missing)
	_expect(font is FontVariation and font.fallbacks.size() == 2, "actual control inherits bundled tooltip theme, independent of system fonts")

func _minion() -> Node:
	var actor: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
	actor.set_player_ref(game.player)
	actor.health = 321
	actor.add_to_group("EnemyGroup")
	actor.death_signal.connect(game.spawner.on_enemy_killed.bind(actor))
	game.add_child(actor)
	actor.global_position = game.player.global_position + Vector2(-100, 80)
	actor.set_physics_process(false)
	return actor

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	for stage in range(3, 7):
		await main._launch_run(&"")
		game = main.game
		game.level_manager.signal_level_up.disconnect(game.on_level_up)
		game.player.set_physics_process(false)
		game.weather.stop()
		game.meteors.set_process(false)
		game.variety.set_process(false)
		for path in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
			game.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
		game.spawner.timer.stop()
		game.spawner.get_node("Elite").stop()
		game.spawner.set_process(false)
		game.spawner.stage = stage
		var actor := _minion()
		var at: Vector2 = actor.global_position
		var kills: int = game.spawner.enemy_killed_num
		var shot: Node = load("res://scenes/enemy_projectile.tscn").instantiate()
		game.effect_container.add_child(shot)
		shot.launch(at + Vector2(-50, 0), Vector2.RIGHT, 100, 5, Color.WHITE)
		shot.set_physics_process(false)
		game.spawner.spawn_boss()
		for boss in game.spawner._active_bosses: boss.set_physics_process(false)
		await process_frame
		_expect(is_instance_valid(actor) and not actor.is_queued_for_deletion(), "stage %d entry preserves living minions" % stage)
		if is_instance_valid(actor):
			_expect(actor.health == 321 and actor.global_position == at, "stage %d entry does not damage or teleport retained minions" % stage)
		_expect(is_instance_valid(shot) and shot.live, "stage %d entry preserves existing hostile projectiles" % stage)
		_expect(game.spawner._active_bosses.size() == (2 if stage == 5 else 1), "stage %d retains correct guardian count" % stage)
		game.spawner._on_timer_timeout()
		game.spawner._on_elite_timeout()
		_expect(get_nodes_in_group("EnemyGroup").size() == 1 + game.spawner._active_bosses.size(), "guardian entry pauses new waves without erasing the old wave")
		_expect(game.spawner.enemy_killed_num == kills, "retained wave grants no fake kills")
		# Defeat/transition cleanup still removes minions and their projectiles.
		game.spawner._clear_minions()
		await process_frame
		_expect(not is_instance_valid(actor) and not is_instance_valid(shot), "stage %d explicit transition cleanup still works" % stage)

	for index in 4:
		game.beast_powers.unlock(index)
		_tooltip_font(game.beast_powers._buttons[index])
	for id in game.equipment_panel.EQUIP_DEFS:
		if game.equipment_panel.get_level(id) == 0: game.equipment_panel.apply_upgrade(id)
		_tooltip_font(game.equipment_panel._slots[id].icon_wrap)
	_tooltip_font(game.equipment_panel._arsenal_label)
	_tooltip_font(game.equipment_panel._growth_label)
	if failures.is_empty(): print("ENCOUNTER READABILITY OK: %d checks; four guardian entries retain minions/projectiles and stop new waves, cleanup, bundled CJK tooltips for all equipment and blessings" % checks)
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
