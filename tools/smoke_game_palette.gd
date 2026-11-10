extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(GamePalette.HEAL.g > GamePalette.HEAL.r and GamePalette.HEAL.g > GamePalette.HEAL.b, "healing stays green")
	_expect(GamePalette.XP_GREEN.g > GamePalette.XP_GREEN.r, "XP green stays green")
	_expect(GamePalette.PLAYER_CYAN.b > GamePalette.PLAYER_CYAN.r and GamePalette.PLAYER_CYAN.g > GamePalette.PLAYER_CYAN.r, "player is cyan")
	_expect(GamePalette.ENEMY_RED.r > GamePalette.ENEMY_RED.g + 0.35 and GamePalette.ENEMY_RED.r > GamePalette.ENEMY_RED.b + 0.35, "enemies are red")
	_expect(GamePalette.TELEGRAPH_EDGE.r > GamePalette.TELEGRAPH_EDGE.b and GamePalette.TELEGRAPH_EDGE.g > GamePalette.TELEGRAPH_EDGE.b, "telegraph edge is red-orange")
	_expect(GamePalette.POISON.b > GamePalette.POISON.r and GamePalette.POISON.r > GamePalette.POISON.g, "poison clouds are purple")
	_expect(GamePalette.POISON_BODY.r > GamePalette.POISON_BODY.g and GamePalette.POISON_BODY.b > GamePalette.POISON_BODY.g, "poison tint stays off burn-orange and freeze-blue")
	_expect(GamePalette.UI_GREY.g <= GamePalette.UI_GREY.r + 0.08 and GamePalette.UI_GREY.b <= GamePalette.UI_GREY.r + 0.12, "UI grey is neutral")
	_expect(GamePalette.SKILL_GALE.b > GamePalette.SKILL_GALE.g or GamePalette.SKILL_GALE.r > GamePalette.SKILL_GALE.g, "gale skill is not green")
	_expect(GamePalette.stage_index(1) == 0 and GamePalette.stage_vignette(0) > GamePalette.stage_vignette(1), "stage 1 is the vignette moss index")
	for stage_num in range(2, 7):
		_expect(GamePalette.stage_index(stage_num) != 0 and GamePalette.stage_tint(stage_num) != GamePalette.stage_tint(1), "stage %d is distinct" % stage_num)
	_expect(GamePalette.HEAL_TEXT == Color(0.4, 1, 0.55), "healing numbers keep their existing green")

	var controls: CanvasLayer = load("res://scenes/mobile_controls.tscn").instantiate()
	root.add_child(controls)
	var stick: StyleBoxFlat = controls.get_node("Root/JoystickBase").get_theme_stylebox("panel")
	var knob: StyleBoxFlat = controls.get_node("Root/JoystickBase/Knob").get_theme_stylebox("panel")
	_expect(stick.border_color.g < stick.border_color.r + 0.2, "joystick border is not green")
	_expect(knob.bg_color.g < knob.bg_color.r + 0.2, "joystick knob is not green")
	var dash_label: Label = controls.get_node("Root/DashButton/Label")
	_expect(dash_label.get_theme_color("font_color").g < dash_label.get_theme_color("font_color").r + 0.15, "DASH label is not green")

	var page: Node = load("res://script/settings_page.gd").new()
	root.add_child(page)
	await process_frame
	for field in ["volume_slider", "music_slider", "sfx_slider", "ambience_slider", "size_slider", "opacity_slider", "shake_slider", "weather_slider", "difficulty_button", "difficulty_list", "back_button"]:
		_expect(page.get(field) != null, "settings keeps %s" % field)
	_expect(page.difficulty_list.get_child_count() == 3, "settings keeps the three difficulties")

	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game()
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	var bg: Node = game.get_node("InfiniteBackground")
	_expect(bg.palette_id == 0 and bg.tint == GamePalette.stage_tint(1), "a run opens on teal moss")
	_expect(float(bg._shader_mat.get_shader_parameter("vignette")) > 0.5, "stage 1 ground has a vignette")
	bg.apply_stage(2)
	_expect(bg.palette_id != 0 and bg.tint != GamePalette.stage_tint(1), "stage 2 ground changes")
	_expect(float(bg._shader_mat.get_shader_parameter("vignette")) < 0.5, "later stages use a lighter vignette")
	bg.apply_stage(1)
	_expect(game.player.modulate == Color.WHITE, "weather still owns the player root modulate")
	_expect(game.player.animated_sprite_2d.material == GamePalette.body_material(&"player"), "player body uses the cyan palette material")
	var data: EnemyData = load("res://resource/Enemy_4.tres")
	var enemy: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	game.add_child(enemy)
	enemy.set_enemy_data(data)
	_expect(enemy.base_modulate == data.tint, "enemy identity tint is unchanged")
	_expect(enemy.sprite_2d.modulate == Color.WHITE and enemy.sprite_2d.material == GamePalette.body_material(&"enemy"), "enemy art is recolored without replacing the status modulate channel")
	game._spawn_xp_coin_now(Vector2(80, 40), 2)
	var coin: Node = game.get_tree().get_first_node_in_group("xp_coin")
	_expect(coin != null and coin.modulate == Color.WHITE and coin.get_node("AnimatedSprite2D").material == null, "coins keep the original gold sprite")
	game.player.player_health = game.player.max_player_health - 40
	var before: float = game.player.player_health
	var orb: Node = game.spawn_healing_orb(Vector2(120, 40), 5.0)
	_expect(orb != null and is_equal_approx(orb.collect(), 5.0) and is_equal_approx(game.player.player_health, before + 5.0), "green heal pickup still heals the same amount")

	if failures.is_empty():
		print("GAME PALETTE OK")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
