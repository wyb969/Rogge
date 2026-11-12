extends SceneTree
var failures: Array[String] = []
func _init() -> void :
	call_deferred("_run")
func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	var game: Node = main.game
	var fx: Node = game.combat_feedback
	var fixed_fx_children: int = fx.get_child_count()
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	game.player.set_physics_process(false)
	var audio: Node = root.get_node("AudioManager")
	var store: Node = root.get_node("SettingsStore")
	var saved_shake: float = store.camera_shake
	main._on_setting_button_pressed()
	main.settings_page.shake_slider.value = 0
	_expect(store.camera_shake == 0, "real settings slider controls camera shake")
	store.camera_shake = 1
	store.load_from_disk()
	_expect(store.camera_shake == 0, "camera comfort setting persists")
	main.settings_page.close_page()
	paused = false
	seed(969)
	var expected: = randi()
	seed(969)
	fx.hit(Vector2.ZERO, Vector2.RIGHT, true)
	fx.kill(Vector2.ZERO, Color.GREEN)
	audio.play_shoot()
	_expect(randi() == expected, "cosmetic particles and action audio preserve combat/loot RNG")
	var enemy: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	game.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.health = 1000
	enemy.global_position = Vector2(150, 0)
	var initial: Vector2 = enemy.global_position
	enemy.receive_hit(Vector2.RIGHT, 20)
	_expect(enemy.health == 980, "real hit damage remains exact")
	await create_timer(0.12, true, false, true).timeout
	_expect(enemy.global_position.is_equal_approx(initial), "drawing recoil cannot move the enemy collider")
	_expect(enemy.sprite_2d.self_modulate.is_equal_approx(Color.WHITE), "hit flash settles without erasing status/warning tint")
	var health: float = game.player.player_health
	game.player.receive_attack(20, enemy)
	_expect(game.player.player_health == health - 20 and fx._shake > 0, "actual player damage triggers directional feedback")
	var camera: Camera2D = game.player.get_node("Camera2D")
	await process_frame
	_expect(camera.offset.is_zero_approx(), "zero shake keeps a stable camera even during real hurt")
	store.set_camera_shake(1)
	fx.camera_impulse(100, Vector2.RIGHT * 100)
	await process_frame
	_expect(camera.offset.length() <= 6.01, "camera offset is bounded even for oversized stacked impulses")
	game.player.hurt_lock = 0
	game.player._start_dash(Vector2.UP)
	var root_before: = root.get_child_count()
	for _i in range(40): game.player._on_shadow_timer_timeout()
	_expect(fx.ghosts.size() <= 8 and fx.ghosts.size() > 0 and root.get_child_count() == root_before, "real dash uses bounded drawing ghosts without allocating root nodes")
	game.player._on_dashing_timer_timeout()
	for _frame in range(20):
		for _burst in range(100):
			fx.hit(Vector2.ZERO, Vector2.RIGHT, true)
			fx.kill(Vector2.ZERO, Color.WHITE, true)
			fx.pickup(Vector2.ZERO)
		_expect(fx.shards.size() <= 128 and fx.rings.size() <= 16 and fx.ghosts.size() <= 8, "hit/kill/pickup storms remain within fixed drawing budgets")
		await process_frame
	_expect(fx.suppressed > 0 and fx.get_child_count() == fixed_fx_children, "over-budget cosmetics allocate no particle nodes")
	var popup: Node = load("res://scenes/damage_text.tscn").instantiate()
	game.effect_container.add_child(popup)
	popup.show_damage("100", Vector2.ZERO, 0, 0)
	var label_start: Vector2 = popup.label.position
	await create_timer(0.15, true, false, true).timeout
	_expect(popup.label.position.y < label_start.y, "actual damage numbers rise away from the impact")
	await create_timer(0.4, true, false, true).timeout
	_expect( not is_instance_valid(popup), "damage numbers expire on schedule")
	audio._pickup_stamp = -1000
	audio.play_pickup()
	var first_pitch: float = audio.pick_coin_audio_player.pitch_scale
	audio._pickup_stamp = Time.get_ticks_msec() - 80
	audio.play_pickup()
	_expect(audio.pick_coin_audio_player.pitch_scale > first_pitch, "successive pickups climb a bounded musical scale")
	audio._pickup_stamp = Time.get_ticks_msec() - 500
	audio.play_pickup()
	_expect(is_equal_approx(audio.pick_coin_audio_player.pitch_scale, first_pitch), "pickup melody resets after a gap")
	game.end_game()
	_expect(fx.shards.is_empty() and fx.rings.is_empty() and fx.ghosts.is_empty() and camera.offset.is_zero_approx() and not fx.is_processing(), "ending a run clears all cosmetics and camera state")
	store.set_camera_shake(saved_shake)
	if failures.is_empty(): print("COMBAT FEEDBACK OK: real actions/settings/persistence, exact damage, independent RNG, stable colliders, bounded camera/batches/ghosts, rising pickups, floating text and teardown")
	else:
		for failure in failures: push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
