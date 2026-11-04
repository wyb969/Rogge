extends SceneTree
var failures: Array[String] = []
func _init() -> void :
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._on_start_button_pressed()
	var game: Node = main.game
	var player: Node = game.player
	var flash: Node = game.damage_flash
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	player.set_physics_process(false)
	_expect( not flash._rect.visible, "fresh run begins without a red veil")
	player.receive_attack(50)
	_expect(player.player_health == 450 and flash._rect.visible and is_equal_approx(flash._rect.color.a, flash.PEAK_ALPHA), "real HP damage immediately produces a visible red flash")
	_expect(flash._rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "flash does not intercept movement/skill UI")

	paused = true
	Engine.time_scale = 0.1
	await _wait_for_real_fade(flash)
	_expect( not flash._rect.visible and is_zero_approx(flash._rect.color.a), "flash finishes in real time through pause and slow motion")
	Engine.time_scale = 1
	paused = false
	player.hurt_lock = 0
	player.dashing = true
	player.receive_attack(50)
	_expect( not flash._rect.visible, "invulnerable dash does not produce a false damage flash")
	player.dashing = false
	player.shield = 100
	player.hurt_lock = 0
	player.receive_attack(50)
	_expect(player.player_health == 450 and not flash._rect.visible, "fully absorbed shield damage does not flash red")
	player.hurt_lock = 0
	player.receive_attack(100)
	_expect(player.player_health == 400 and flash._rect.visible, "shield overflow that removes HP does flash (HP=%s visible=%s elapsed=%s ms)" % [player.player_health, flash._rect.visible, Time.get_ticks_msec() - flash._last_flash_msec])
	var first_stamp: int = flash._last_flash_msec
	player.hurt_lock = 0
	player.receive_attack(10)
	_expect(flash._last_flash_msec == first_stamp, "rapid accepted hits do not stack or endlessly refresh the veil")
	await _wait_for_real_fade(flash)
	_expect( not flash._rect.visible, "repeated-hit flash clears fully")
	player.hurt_lock = 0
	player.receive_attack(10)
	_expect(flash._rect.visible and flash._last_flash_msec > first_stamp, "later damage starts a fresh pulse")
	for size in [Vector2i(390, 844), Vector2i(900, 500)]:
		root.size = size
		await process_frame
		await process_frame
		_expect(flash._rect.get_global_rect().encloses(Rect2(Vector2.ZERO, root.get_visible_rect().size)), "red overlay covers the whole resized viewport")
	main.on_game_over({"victory": false})
	_expect( not flash._rect.visible, "ending the run immediately clears the flash")
	await main._on_game_end_ui_retry_pressed()
	_expect( not main.game.damage_flash._rect.visible, "Retry has no stale red flash")
	if failures.is_empty(): print("DAMAGE FLASH OK: real damage, shields/dash, bounded repeated hits, wall-clock fade, viewport coverage and run reset")
	else:
		for failure in failures: push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)

func _wait_for_real_fade(flash: Node) -> void :


	var deadline: = Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < deadline and (flash._rect.visible or Time.get_ticks_msec() - flash._last_flash_msec < 350):
		await process_frame
