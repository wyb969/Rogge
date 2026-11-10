extends SceneTree
var failures: Array[String] = []
const BUDGET = preload("res://script/feedback_budget.gd")
const TEXT = preload("res://script/demage_text.gd")
func _init() -> void : call_deferred("_run")
func expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func admit() -> void :
	BUDGET._tokens = 36
	BUDGET._frame = -1
	BUDGET._stamp = Time.get_ticks_msec()
func _run() -> void :
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await main._launch_run(&"")
	var game: Node = main.game
	game.spawner.set_process(false)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	for name in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]: game.get_node(name).process_mode = Node.PROCESS_MODE_DISABLED
	var actor: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
	actor.set_player_ref(game.player)
	game.add_child(actor)
	actor.add_to_group("EnemyGroup")
	actor.health = 10000
	actor.set_physics_process(false)
	for effect in ["burn", "freeze", "poison_trail", ""]:
		actor.freeze_time = 0
		admit()
		var hp: float = actor.health
		actor.apply_hit({"damage": 10, "effect": effect, "from_status": effect == "poison_trail"})
		var popup: Node = game.effect_container.get_children().back()
		expect(actor.health == hp - 10 and popup._status == (effect != ""), "real burn/frost/poison and plain hits route to their intended text without damage changes")
		if effect != "": expect(popup.label.get_theme_color("font_color") == (GamePalette.POISON_TINT if effect == "poison_trail" else TEXT.STATUS_YELLOW), "poison remains purple; burn and frost follow Cursor yellow-to-red colors")
		else: expect(popup.label.get_theme_color("font_color") == Color(1, 0.96, 0.83), "plain damage stays cream")
	admit()
	actor._take_status_damage(5)
	var burn: Node = game.effect_container.get_children().back()
	expect(burn._status, "actual periodic burn damage uses abnormal text")
	admit()
	actor.freeze_time = 1
	game.freeze_controller.level = 1
	var hp: float = actor.health
	actor.apply_hit({"damage": 10})
	var frozen: Node = game.effect_container.get_children().back()
	expect(is_equal_approx(hp - actor.health, 13) and frozen._status, "frozen-target bonus hits retain the old bonus and get abnormal text")
	game.freeze_controller.level = 0
	var heal: Node = load("res://scenes/damage_text.tscn").instantiate()
	game.effect_container.add_child(heal)
	heal.show_heal("+5")
	expect( not heal._status and heal.label.get_theme_color("font_color") == Color(0.4, 1, 0.55), "healing text remains green")
	await create_timer(0.13, true, false, true).timeout
	expect(is_instance_valid(burn) and burn.label.get_theme_color("font_color").g < TEXT.STATUS_YELLOW.g and burn.label.get_theme_color("font_color").g > TEXT.STATUS_RED.g, "the real existing popup tween transitions through orange")
	await create_timer(0.13, true, false, true).timeout
	expect(is_instance_valid(burn) and burn.label.get_theme_color("font_color").is_equal_approx(TEXT.STATUS_RED), "abnormal numbers finish red before expiry")
	await create_timer(0.14, true, false, true).timeout
	expect( not is_instance_valid(burn), "gradient adds no extra popup lifetime")
	var boss: Node = load("res://scenes/boss.tscn").instantiate()
	boss.set_player(game.player)
	game.add_child(boss)
	boss.add_to_group("EnemyGroup")
	boss.rush_timer.stop()
	boss.set_physics_process(false)
	boss.last_hitstop_msec = Time.get_ticks_msec() + 100000
	admit()
	var boss_hp: float = boss.boss_current_health
	boss.apply_hit({"damage": 5, "effect": "poison_trail", "from_status": true})
	var popup: Node = game.effect_container.get_children().back()
	expect(boss.boss_current_health == boss_hp - 5 and popup._status, "real boss poison uses the same bounded yellow/red popup")
	main.show_main_menu()
	if failures.is_empty(): print("STATUS NUMBERS OK: real burn ticks/frost/poison and frozen bonus, plain/heal colors, yellow-orange-red tween/lifetime, bounded boss status routing and return")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
