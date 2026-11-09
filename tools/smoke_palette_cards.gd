extends SceneTree

var PREVIEW: Script
var failures: Array[String] = []
var checks := 0
var main: Node
var game: Node

func _init() -> void: call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func settle() -> void:
	await process_frame
	await process_frame
	await process_frame
func fresh() -> void:
	paused = false
	await main._launch_run(&"")
	game = main.game
	game.level_manager.signal_level_up.disconnect(game.on_level_up)
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.player.set_physics_process(false)
	game.weather.stop()
	game.meteors.set_process(false)
	game.variety.set_process(false)
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]:
		game.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED

func observed(id: String) -> Dictionary:
	var p: Node = game.player
	var level: int = game.equipment_panel.get_level(id)
	match id:
		"speed_up": return {"移速":p.effective_move_speed()}
		"pickup_up": return {"拾取半径":p.pickup_range}
		"axe_up": return {"基础伤害":game.hand_weapon.weapon_demage,"飞行速度":game.hand_weapon.max_speed}
		"circle_up": return {"每本伤害":game.circle_weapon.get_child(0).weapon_demage,"书本数量":game.circle_weapon.num_weapons,"环绕速度":game.circle_weapon.rotation_speed}
		"gun_up": return {"单弹下限":game.gun_weapon.damage+5,"单弹上限":game.gun_weapon.damage+15,"射击间隔":game.gun_weapon.fire_interval,"穿透":game.gun_weapon.pierce}
		"drone_up": return {"激光伤害":game.drone_controller.get_damage(),"射击间隔":game.drone_controller.get_fire_cd(),"无人机数":game.drone_controller.get_drone_count(),"存活时间":game.drone_controller.get_lifetime()}
		"molotov_up": return {"每层秒伤":game.molotov_controller.get_burn_dps(),"燃烧层数":game.molotov_controller.get_burn_stacks(),"投掷间隔":game.molotov_controller.get_throw_interval(),"爆炸半径":game.molotov_controller.get_explode_radius()}
		"freeze_up": return {"冰冻几率":game.freeze_controller.get_on_hit_chance()*100,"持续时间":game.freeze_controller.get_freeze_duration(),"减速幅度":(1-game.freeze_controller.get_slow_factor())*100,"冻伤增伤":game.freeze_controller.get_frozen_bonus()*100}
		"regen_up": return {"每次回复":p.effective_heal_amount(p.regen_amount()),"回复间隔":p.regen_interval()}
		"monster_necklace": return {"每球回复":p.effective_heal_amount(p.monster_necklace_heal_for(level))}
		"lifesteal_up": return {"命中回复比例":p.lifesteal_percent_for(level)*p.total_healing_multiplier()*100,"固定回复":p.LIFESTEAL_FLAT*p.total_healing_multiplier(),"每次回复上限":p.effective_heal_amount(p.lifesteal_cap_for(level))}
		"shield_up": return {"每杀护盾":p.shield_gain_for(level),"衰减等待":p.shield_idle_for(level),"每秒衰减":p.shield_decay_for(level)}
		"critical_glasses": return {"暴击率":p.CRITICAL_GLASSES.chance_for(level)*100,"暴击伤害":p.CRITICAL_GLASSES.damage_multiplier_for(level)*100}
		"left_fist", "right_fist": return {"左侧伤害":p.get_side_damage_multiplier(p.global_position+Vector2.LEFT)*100,"右侧伤害":p.get_side_damage_multiplier(p.global_position+Vector2.RIGHT)*100}
		_:
			var stats: Dictionary
			if id == "wind_emblem": stats = game.variety.wind_stats(game.variety.wind_level)
			elif id == "echo_ember": stats = game.variety.echo_stats(game.variety.echo_level)
			else:
				var actor: Node = {"bomb":game.bomb_controller,"banana_fan":game.banana_fan,"black_hole":game.black_hole,"poison_trail":game.poison_trail,"lightning_ring":game.lightning_ring}[id]
				stats = actor._stats if id != "lightning_ring" else actor.stats_for(actor.level)
			var result := {}
			for key in stats:
				var label: String = {"damage":"基础伤害","dps":"每秒伤害","radius":"作用半径","range":"作用距离","interval":"触发间隔","bolts":"闪电目标","kills":"所需击杀"}.get(key,"")
				if not label.is_empty(): result[label] = stats[key]
			return result

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await settle()
	PREVIEW = load("res://script/card_preview.gd")
	var ids: Array = main.game.equipment_panel.EQUIP_DEFS.keys()
	for id in ids:
		await fresh()
		# Real character progression must be included in axe/book previews.
		game.current_level = 7
		for _step in 3:
			var before_speed: float = game.player.SPEED
			var data: Dictionary = PREVIEW.build(game,id)
			expect(not data.rows.is_empty() and data.desc.contains("→"), id+" has a numeric comparison")
			var state: int = game.player._critical_rng.state
			PREVIEW.build(game,id)
			expect(state == game.player._critical_rng.state and game.player.SPEED == before_speed, "preview is read-only and consumes no combat RNG")
			game._on_upgrade_selected(id)
			var actual := observed(id)
			for row in data.rows:
				expect(actual.has(row.label) and is_equal_approx(float(actual.get(row.label,-999)),float(row.after)), "%s %s preview=%s actual=%s" % [id,row.label,row.after,actual.get(row.label)])
			if id == "speed_up": expect(game.player.SPEED == before_speed+20,"speed balance remains fixed +20")

	await fresh()
	game.player.healing_multiplier = 1.5
	for id in ["pickup_up","speed_up"]: game._on_upgrade_selected(id)
	var regen: Dictionary = PREVIEW.build(game,"regen_up")
	game._on_upgrade_selected("regen_up")
	for row in regen.rows: expect(is_equal_approx(float(observed("regen_up")[row.label]),float(row.after)),"first growth combo and easy healing are reflected immediately")
	game._on_upgrade_selected("left_fist")
	var fist: Dictionary = PREVIEW.build(game,"right_fist")
	game._on_upgrade_selected("right_fist")
	for row in fist.rows: expect(is_equal_approx(float(observed("right_fist")[row.label]),float(row.after)),"dual fists remove the real opposite-side penalty")
	var menu: Node = game.pause_menu
	var chosen: Array = []
	for entry in menu.upgrade_pool:
		if entry.id in ["drone_up","bomb","freeze_up"]: chosen.append(entry)
	menu.upgrade_pool = chosen
	for dimensions in [Vector2i(900,600),Vector2i(390,844),Vector2i(844,390)]:
		root.size = dimensions
		await settle()
		menu.show_upgrade_options()
		await settle()
		menu._fit_cards()
		await settle()
		var screen := Rect2(Vector2.ZERO,root.get_visible_rect().size)
		expect(screen.encloses(menu.reroll_button.get_global_rect()),"reroll fits "+str(dimensions))
		for card in menu.h_box_container.get_children():
			expect(screen.encloses(card.get_global_rect()),"card fits "+str(dimensions))
			expect(card.get_global_rect().encloses(card.desc_label.get_global_rect()),"comparison text stays inside card "+str(dimensions))
			expect(card.desc_label.get_content_height() <= card.desc_label.size.y+1,"all rich text visible "+str(dimensions))
		menu.hide()
		paused = false

	root.size = Vector2i(900,600)
	var controls: Node = main.mobile_controls
	var settings: Node = root.get_node("SettingsStore")
	settings.set_control_scale(1.15)
	settings.set_control_opacity(0.62)
	settings.set_stick_norm(Vector2(0.2,0.72))
	settings.set_dash_norm(Vector2(0.8,0.73))
	controls.begin_layout_edit()
	await settle()
	expect(controls.stick_base.size.is_equal_approx(Vector2.ONE*112*1.15) and is_equal_approx(controls.stick_base.modulate.a,0.62),"custom control scale/opacity preserved")
	expect(settings.stick_norm == Vector2(0.2,0.72) and settings.dash_norm == Vector2(0.8,0.73),"custom positions preserved")
	var style: StyleBoxFlat = controls.stick_base.get_theme_stylebox("panel")
	expect(style.bg_color.is_equal_approx(GamePalette.alpha(GamePalette.UI_GREY_BASE,0.45)),"actual stick uses neutral semantic style")
	controls.dash_button.set_pressed_visual(true)
	controls.dash_button.set_cooldown(0.5,false,false)
	expect(not controls.dash_button.available and controls.dash_button.progress == 0.5,"cooldown presentation does not change gameplay state")
	controls.end_layout_edit()
	main.show_main_menu()
	if failures.is_empty(): print("PALETTE CARDS OK: %d checks; all22 real upgrades/current character level, shared formulas, read-only preview, combo/heal/fist interactions, three layouts and saved controls" % checks)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
