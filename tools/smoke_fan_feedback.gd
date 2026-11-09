extends SceneTree

const FX := preload("res://script/status_echo_feedback.gd")
var failures: Array[String] = []
var main: Node
var game: Node

func _init() -> void: call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _isolate() -> void:
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.player.set_physics_process(false)
	game.player.global_position = Vector2.ZERO
	game.player.last_move_direction = Vector2.RIGHT
	game.weather.stop()
	game.variety._courier_left = 99999
	game.poison_trail.set_process(false)
	game.banana_fan.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED

func _enemy(at: Vector2) -> Node:
	var actor: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_player_ref(game.player)
	actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
	actor.health = 1000
	actor.defense = 0
	actor.add_to_group("EnemyGroup")
	game.add_child(actor)
	actor.global_position = at
	actor.set_physics_process(false)
	return actor

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	game = main.game
	_isolate()
	game._on_upgrade_selected("banana_fan")
	game._on_upgrade_selected("poison_trail")
	_isolate()
	var fan: Node = game.banana_fan
	var feedback: Node = fan.status_feedback
	feedback.set_process(false)
	var burn: Node = _enemy(Vector2(80, -20))
	var poison: Node = _enemy(Vector2(95, 25))
	var both: Node = _enemy(Vector2(110, 0))
	var clean: Node = _enemy(Vector2(75, 42))
	burn.apply_burn({"burn_stacks": 3, "burn_dps": 4.0})
	both.apply_burn({"burn_stacks": 3, "burn_dps": 4.0})
	game.poison_trail._clouds[0].at = Vector2(110, 20)
	game.poison_trail._clouds[0].left = 4.0
	game.poison_trail._scan(0.0)
	var node_count: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var shared_material: int = feedback.material.get_instance_id()
	_expect(fan.cast(), "real fan cast targets the status samples")
	fan._physics_process(0.52)
	_expect(feedback._indices.size() == 3 and feedback.flashes == 3 and not feedback._indices.has(clean.get_instance_id()), "only successful status replays flash the actual affected bodies")
	for pair in [[burn, FX.BURN], [poison, FX.POISON], [both, FX.BURN | FX.POISON]]:
		var actor: Node = pair[0]
		var record: Dictionary = feedback._records[feedback._indices[actor.get_instance_id()]]
		_expect(record.kind == pair[1] and record.sprite == actor.sprite_2d and record.left == FX.FLASH_SECONDS, "flash uses the pre-hit status kind and the actual animated sprite")
	_expect(FX.color_for(FX.BURN, 0).is_equal_approx(GamePalette.FRIENDLY_BLUE), "friendly burn replay uses the cool combat palette")
	_expect(FX.color_for(FX.POISON, 0).is_equal_approx(GamePalette.POISON_PURPLE), "poison replay is a saturated purple distinct from freeze")
	_expect(FX.color_for(3, 0) == FX.BURN_COLOR and FX.color_for(3, 0.25).is_equal_approx(FX.POISON_COLOR), "dual status progresses from blue to purple")
	_expect(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - node_count <= 8 and feedback.material.get_instance_id() == shared_material, "replays share one drawing material without per-enemy effect nodes")
	var burn_tint: Color = burn.sprite_2d.modulate
	var poison_tint: Color = poison._poison_tint
	var collider_scale: Vector2 = burn.scale
	var health: float = burn.health
	feedback.flash(weakref(burn), FX.BURN)
	_expect(feedback._indices.size() == 3 and burn.sprite_2d.modulate == burn_tint and poison._poison_tint == poison_tint and burn.scale == collider_scale and burn.health == health, "refreshing a flash preserves combat state, original color channels and collision size")
	for _i in 5: fan._scan_gust()
	_expect(feedback.flashes == 4, "repeated gust scans cannot create more status flashes")
	var left: float = feedback._records[feedback._indices[burn.get_instance_id()]].left
	paused = true
	feedback._process(10)
	_expect(feedback._records[feedback._indices[burn.get_instance_id()]].left == left, "pause freezes color animation")
	paused = false
	feedback._process(0.35)
	_expect(feedback._indices.is_empty() and not feedback.is_processing(), "color overlays expire and stop processing without leaving a tint")
	_expect(burn.sprite_2d.modulate == burn_tint and poison._poison_tint == poison_tint, "fade-out does not overwrite burn or poison coloring")
	var targets: Array[Node] = []
	for i in 60: targets.append(_enemy(Vector2(500 + i * 4, 20)))
	for _i in 3:
		for target in targets: feedback.flash(weakref(target), FX.POISON)
	_expect(feedback._records.size() == FX.MAX_FLASHES and feedback._indices.size() == FX.MAX_FLASHES and feedback.material.get_instance_id() == shared_material, "large repeated crowds keep a fixed 48-slot pool and one material")
	for target in targets: target.queue_free()
	await process_frame
	feedback._process(0)
	_expect(feedback._indices.is_empty(), "deleted enemies leave no retained flash records or invalid sprite access")
	var molotov: Node = game.molotov_controller
	for rank in [1, 5, 8, 50]:
		molotov.level = rank
		var expected: float = {1: 2.8875, 5: 1.8375, 8: 1.2, 50: 1.2}[rank]
		_expect(is_equal_approx(molotov.get_throw_interval(), expected), "gasoline cooldown is 25 percent shorter, with a bounded 1.2 second minimum")
		molotov.throw_timer = 0
		molotov._process(0)
		var count: int = game.effect_container.get_child_count()
		var elapsed := 0.0
		while game.effect_container.get_child_count() == count and elapsed < 4:
			molotov._process(0.01)
			elapsed += 0.01
		_expect(absf(elapsed - expected) <= 0.011, "actual bottle creation follows the shorter interval")
	molotov.level = 1
	molotov.throw_timer = 3.5
	molotov.upgrade()
	_expect(is_equal_approx(molotov.throw_timer, 2.625), "upgrades shorten an already pending gasoline cooldown")
	var description: String = game.pause_menu._molotov_desc()
	_expect(description.contains("2.36s"), "card preview uses the controller's exact next-rank cooldown")
	molotov.reset()
	var count: int = game.effect_container.get_child_count()
	molotov._process(10)
	_expect(game.effect_container.get_child_count() == count, "unowned gasoline does not throw bottles")
	game.variety.clear_combat_effects()
	_expect(feedback._indices.is_empty() and not feedback.is_processing(), "stage cleanup removes all visual flash work")
	main.show_main_menu()
	if failures.is_empty(): print("FAN FEEDBACK OK: status-specific body colors, dual-status transition, shared bounded pool, exact fade/pause/delete/reset, unchanged combat channels, real gasoline cooldowns/upgrades and preview")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
