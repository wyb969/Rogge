extends SceneTree

var directory := "/opt/cursor/artifacts/palette-v4"

func _init() -> void:
	call_deferred("_run")

func shot(label: String) -> void:
	print("SHOT ", label)
	for _i in 4:
		await process_frame
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	if image == null:
		push_error("missing viewport image")
		return
	image.save_png(directory + "/" + label + ".png")
	print("WROTE ", label, " ", image.get_width(), "x", image.get_height())

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			directory = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(directory)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	print("LAUNCH")
	await main._launch_run(&"")
	print("RUNNING")
	var game: Node = main.game
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.player.set_physics_process(false)
	if game.level_manager.signal_level_up.is_connected(game.on_level_up):
		game.level_manager.signal_level_up.disconnect(game.on_level_up)
	game.variety.set_process(false)
	for node_name in ["HandWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(node_name).process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera2D = game.player.get_node("Camera2D")
	camera.position_smoothing_enabled = false
	camera.offset = Vector2.ZERO
	game.combat_feedback.set_process(false)
	game.weather.set_preview(0, 0.15)
	game.weather.set_process(false)
	game.get_node("InfiniteBackground").apply_stage(1)
	game.level_manager.coin_number = 2
	game.level_manager.level_need_coin_number = 6
	game.level_manager.progress_bar.value = 34
	game.level_manager.label.text = "Level: 0"
	for index in 4:
		game.beast_powers.unlock(index)
	game._on_upgrade_selected("poison_trail")
	game._on_upgrade_selected("lightning_ring")
	game._on_upgrade_selected("shield_up")
	game.poison_trail.set_process(false)
	game.circle_weapon.set_process(false)
	for unit in game.circle_weapon.get_children():
		unit.set_process(false)
	var spots: Array[Vector2] = [Vector2(90, -20), Vector2(-70, 36), Vector2(40, 70)]
	var resources: Array[String] = ["res://resource/Enemy_1.tres", "res://resource/Enemy_5.tres", "res://resource/Enemy_4.tres"]
	var foes: Array[Node] = []
	for i in spots.size():
		var actor: Node = load("res://scenes/enemy_shell.tscn").instantiate()
		actor.set_player_ref(game.player)
		actor.set_enemy_data(load(resources[i]))
		actor.add_to_group("EnemyGroup")
		game.add_child(actor)
		actor.global_position = game.player.global_position + spots[i]
		actor.set_physics_process(false)
		foes.append(actor)
	var field: Node = game.enemy_attacks
	var slot = field.slots[0]
	slot.active = true
	slot.kind = &"cleave"
	slot.origin = foes[0].global_position
	slot.heading = (game.player.global_position - foes[0].global_position).normalized()
	slot.target = game.player.global_position
	slot.age = 0.42
	slot.windup = 0.75
	slot.duration = 1.2
	slot.source = weakref(foes[0])
	slot.source_id = foes[0].get_instance_id()
	field.set_physics_process(false)
	field.queue_redraw()
	game.poison_trail.level = 3
	game.poison_trail._stats = game.poison_trail.stats_for(3)
	for i in 3:
		game.poison_trail._clouds[i].at = game.player.global_position + Vector2(-36 + i * 22, 18)
		game.poison_trail._clouds[i].left = 3.5
		game.poison_trail._clouds[i].phase = float(i)
	game.poison_trail.queue_redraw()
	for i in 6:
		game._spawn_xp_coin_now(game.player.global_position + Vector2(-70 + i * 18, 78), 2)
	game.player.monster_necklace_level = 1
	for at in [Vector2(-80, 8), Vector2(110, 48)]:
		var orb: Node = game.spawn_necklace_orb(game.player.global_position + at)
		orb.set_physics_process(false)
	if game.combat_lighting:
		game.combat_lighting.begin_run()
	root.size = Vector2i(900, 600)
	await shot("landscape-stage1")
	root.size = Vector2i(390, 844)
	await shot("portrait-stage1")
	root.size = Vector2i(900, 600)
	game.get_node("InfiniteBackground").apply_stage(2)
	if game.spawner.get("_stage_label") != null:
		game.spawner._stage_label.text = "STAGE 2"
	await shot("landscape-stage2")
	print("PALETTE CAPTURE OK ", directory)
	quit()
