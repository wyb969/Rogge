extends SceneTree
var failures: Array[String] = []
var checks := 0
func _init() -> void: call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _settle() -> void:
	await process_frame
	await process_frame
func _home_ok(main: Node) -> void:
	_expect(main.menu_page.visible and main.main_ui.visible and not main.debug_page.visible and paused, "return restores the paused home page")
	_expect(not main.fullscreen_toggle.home_button.visible and main.fullscreen_toggle.home_button.disabled, "home action hides outside a run")
	_expect(main.game_root.get_child_count()==1 and main._test_mode==&"" and not main._returning_home, "return completes once and resets debug state")
	_expect(not main.game.player.movement_locked and not main.game.growth_combo_active and not main.game.arsenal_combo.unlocked, "fresh prepared game inherits no lock or combo gear")
	_expect(get_nodes_in_group("wooden_trial_enemy").is_empty() and get_nodes_in_group("EnemyGroup").is_empty(), "return leaves no prior enemies")
func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _settle()
	var toolbar: Node = main.fullscreen_toggle
	var prepared: Node = main.game
	_expect(toolbar.button.visible and not toolbar.home_button.visible, "home has fullscreen only")
	toolbar.home_button.pressed.emit()
	_expect(main.game==prepared and not main._returning_home, "hidden Home cannot start another transition")
	await main._launch_run(&"equipment_combos")
	_expect(toolbar.home_button.visible and not toolbar.home_button.disabled, "run shows the Home action next to fullscreen")
	for size in [Vector2i(390,844),Vector2i(320,568),Vector2i(844,390),Vector2i(900,600)]:
		root.size=size
		await _settle()
		var bounds:=Rect2(Vector2.ZERO,root.get_visible_rect().size)
		var home_rect: Rect2 = toolbar.home_button.get_global_rect()
		var full_rect: Rect2 = toolbar.button.get_global_rect()
		_expect(bounds.encloses(home_rect) and bounds.encloses(full_rect), "toolbar fits %s" % size)
		_expect(home_rect.end.x<full_rect.position.x and is_equal_approx(home_rect.position.y,full_rect.position.y) and is_equal_approx(home_rect.size.y,full_rect.size.y), "Home and fullscreen stay side by side")
		_expect(main.game.equipment_panel.scale.x<=1 and main.game.equipment_panel.slot_list.columns==2, "equipment keeps original scale in two columns")
	var mobile: Node = root.get_node("MobileInput")
	var original_dash: Vector2 = main.mobile_controls.dash_button.global_position
	main.mobile_controls.dash_button.global_position=toolbar.home_button.global_position
	var touch:=InputEventScreenTouch.new()
	touch.pressed=true
	touch.position=toolbar.home_button.get_global_rect().get_center()
	_expect(not main.mobile_controls._handle_touch(touch) and not mobile.dash_just_pressed, "toolbar takes priority over a customized overlapping DASH control")
	main.mobile_controls.dash_button.global_position=original_dash
	# Exercise the real GUI route, including the gameplay input layer yielding the click.
	var at: Vector2 = toolbar.home_button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new()
	motion.position=at
	motion.global_position=at
	root.push_input(motion,true)
	for pressed_value in [true,false]:
		var click:=InputEventMouseButton.new()
		click.position=at
		click.global_position=at
		click.button_index=MOUSE_BUTTON_LEFT
		click.pressed=pressed_value
		root.push_input(click,true)
	await _settle()
	_home_ok(main)
	_expect(main.game!=prepared, "GUI click returns to a fresh prepared game")
	for active in [false,true]:
		await main._launch_run(&"trial_wooden")
		var trials: Node = main.game.trials
		trials.set_process(false)
		if active:
			trials.start_button.pressed.emit()
			trials._process(0.5)
			_expect(main.game.player.movement_locked and trials.horde.alive_count()>0, "active survival really has a lock and crowd before returning")
		else:
			_expect(paused and toolbar.layer>trials._modal.layer, "toolbar remains above paused trial explanation")
		var old_player: Node = main.game.player
		toolbar.home_button.pressed.emit()
		toolbar.home_button.pressed.emit()
		_expect(not old_player.movement_locked and not trials.horde.active, "Home immediately releases the trial lock and stops its crowd")
		await _settle()
		_home_ok(main)
	await main._launch_run(&"")
	main.game.player.hurt_lock = 0
	main.game.player.receive_attack(1000000)
	_expect(has_meta("player_death_slowmo") and Engine.time_scale<1, "real lethal hit begins the death slow-motion interval")
	toolbar.home_button.pressed.emit()
	await _settle()
	_expect(not has_meta("player_death_slowmo") and is_equal_approx(Engine.time_scale,1), "return clears interrupted death state and restores normal time")
	await create_timer(0.6,true,false,true).timeout
	_home_ok(main)
	_expect(not main.game_end_ui.root_ui.visible, "an interrupted death cannot show a stale result over Home")
	await main._launch_run(&"")
	main.on_game_over({"victory":false})
	_expect(not toolbar.home_button.visible, "result page uses its own Back action")
	main.game_end_ui.main_menu_pressed.emit()
	main.game_end_ui.main_menu_pressed.emit()
	await _settle()
	_home_ok(main)
	if failures.is_empty(): print("SESSION TOOLBAR OK: %d checks; actual GUI click, compact equipment, adjacent buttons, touch ownership, paused/active trial teardown, double-tap and result navigation" % checks)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
