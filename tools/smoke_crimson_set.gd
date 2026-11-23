extends SceneTree

var errors: Array[String] = []

func check(ok: bool, msg: String) -> void:
	if not ok: errors.append(msg)

func _init() -> void: call_deferred("_run")

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main._on_crimson_practice()
	var machine: Node = main.starter_lottery
	check(machine.loadout.cards.size() == 4 and machine.loadout.group == "crimson", "debug opens the genuine set roll")
	machine._on_button()
	machine._process(3)
	check(machine._reel_panels[3].visible and machine._panel.material.get_shader_parameter("crimson"), "four prizes and red foil")
	machine._on_button()
	await process_frame
	await process_frame
	var g: Node = main.game
	g.spawner.stop_run()
	g.weather.stop()
	var panel: Node = g.equipment_panel
	check(panel.crimson_active and panel._active_combo_borders.size() == 4, "four red equipment borders after claim")
	check(panel.get_level(machine.loadout.perk) > 0, "hero perk retained")
	var forge: RefCounted = g.forge
	var members: Array = machine.COMBOS.CRIMSON_MEMBERS
	var skills := [g.ice_wave,g.draw_slash,g.ghost_dash,g.blood_vortex]
	for skill in skills: skill.set_physics_process(false)
	var origin: Vector2 = g.player.global_position
	g._spawn_control_targets([Vector2(50,0)])
	await physics_frame
	await physics_frame
	g.ice_wave.clear_combat_effects()
	check(g.ice_wave.cast(), "ice wave starts")
	check(is_equal_approx(g.ice_wave._damage,g.ice_wave._stats.damage*1.3) and is_equal_approx(g.ice_wave._radius,27.3) and is_equal_approx(g.ice_wave._reach,234) and is_equal_approx(g.ice_wave._cooldown,1.26), "ice damage, hit width, reach and cooldown")
	g.draw_slash._cooldown = 0.0
	g.draw_slash._physics_process(0)
	check(is_equal_approx(g.draw_slash._damage,g.draw_slash._stats.damage*1.3) and is_equal_approx(g.draw_slash._shape.radius,117) and is_equal_approx(g.draw_slash._cooldown,1.68), "slash damage, hit radius and cooldown")
	g.ghost_dash.begin_pass()
	check(is_equal_approx(g.ghost_dash._damage,g.ghost_dash._stats.damage*1.3) and is_equal_approx(g.ghost_dash.pass_distance,171.6) and is_equal_approx(g.ghost_dash._shape.radius,15.6) and is_equal_approx(g.player.dash_base_cooldown(),1.89), "phantom damage, path geometry and cooldown")
	g.blood_vortex.clear_combat_effects()
	check(g.blood_vortex.cast(), "vortex starts")
	check(is_equal_approx(g.blood_vortex._damage,g.blood_vortex._stats.damage*1.3) and is_equal_approx(g.blood_vortex._fx._length,351) and is_equal_approx(g.blood_vortex._fx._radius,91) and g.blood_vortex._query.shape == g.blood_vortex._large_funnel and is_equal_approx(g.blood_vortex._interval,0.5) and g.blood_vortex._beats == 6 and is_equal_approx(g.blood_vortex._recovery,3.15), "vortex geometry, recovery and unchanged beat timing")
	var extra: int = forge.add_card("ice_wave",0)
	forge.wallet = 1000
	forge.seal_stage()
	var main_uid: int = forge.cards.filter(func(c): return c.id == "draw_slash")[0].uid
	var ghost_uid: int = forge.cards.filter(func(c): return c.id == "ghost_dash")[0].uid
	var warning := L10n.text("绯刃四式将失效")
	check(panel.get_level("ice_wave") == 2 and warning in forge.preview(main_uid,[extra]).warnings, "the second draw raises the same skill and sacrificing it breaks the set")
	check(warning in forge.preview(main_uid,[ghost_uid]).warnings, "last-copy sacrifice warns")
	check(forge.attempt(main_uid,[ghost_uid]).ok and not panel.crimson_active, "sacrifice disables bonus")
	g.blood_vortex.clear_combat_effects()
	check(g.blood_vortex.cast() and g.blood_vortex._query.shape == g.blood_vortex._normal_funnel and is_equal_approx(g.blood_vortex._damage,g.blood_vortex._stats.damage), "next cast uses normal reach and damage")
	forge.add_card("ghost_dash",1)
	check(panel.crimson_active, "recollecting the missing skill restores the set")
	for id in members: check(panel.get_level(id) > 0, "complete inventory")
	for e in errors: push_error(e)
	if errors.is_empty(): print("CRIMSON SET OK: four live casts, red reveal, skill ranks and whole-skill sacrifice, reactivation")
	quit(0 if errors.is_empty() else 1)
