extends SceneTree

const ROSTER := preload("res://script/hero_roster.gd")
var errors: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value: errors.append(message)

func _init() -> void:
	call_deferred("_run")

func claim_start(main: Node, perk: String, group: String = "", rerolls: int = 0) -> Dictionary:
	var machine: Node = main.starter_lottery
	check(machine.rerolls_left == 3 and not machine._reroll.visible, "new opening has three unused rerolls")
	if group == "mixed":
		machine.loadout = machine.draw_loadout(perk, 99)
	elif group != "":
		# Exercise both real jackpot definitions regardless of the random seed.
		var members: Array = {"growth":machine.COMBOS.GROWTH_MEMBERS,"arsenal":machine.COMBOS.ARSENAL_MEMBERS,"crimson":machine.COMBOS.CRIMSON_MEMBERS}[group]
		var backup := "gun_up" if group == "growth" and perk not in machine.WEAPONS else ""
		machine.loadout = {"cards":members, "group":group, "backup":backup, "perk":perk}
	check(machine._panel.material == null, "every new spin starts without foil")
	check(machine.visible and paused, "selection pauses at the machine")
	check(root.get_visible_rect().encloses(machine._button.get_global_rect()), "spin is reachable")
	machine._button.pressed.emit()
	check(machine.spinning and machine._button.disabled, "single spin locked")
	machine._process(3.0)
	await process_frame
	await process_frame
	var left: Rect2 = machine._reroll.get_global_rect()
	var right: Rect2 = machine._button.get_global_rect()
	check(left.end.x <= right.position.x and is_equal_approx(left.position.y, right.position.y), "reroll left and confirm right")
	check(root.get_visible_rect().encloses(left) and root.get_visible_rect().encloses(right), "both actions fit")
	check(machine._reroll.visible and not machine._reroll.disabled and machine.rerolls_left == 3, "first spin is free")
	for i in rerolls:
		var old: Dictionary = machine.loadout
		for down in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = left.get_center()
			click.pressed = down
			root.push_input(click, true)
		check(machine.spinning and machine._reroll.disabled and machine._button.disabled, "clicking reroll locks both buttons")
		check(not is_same(machine.loadout, old) and machine.loadout.perk == perk, "reroll draws fresh gear for the same hero")
		check(machine._panel.material == null, "reroll clears previous jackpot foil")
		machine._on_reroll_pressed()
		machine._on_button()
		check(machine.visible and paused and not machine.claimed and machine.rerolls_left == 2-i, "extra inputs cannot spend or claim mid-spin")
		machine._process(3.0)
		check(machine._reroll.disabled == (i == 2) and not machine._button.disabled, "only an exhausted reroll stays disabled")
		if machine.rerolls_left == 0:
			var final_draw: Dictionary = machine.loadout
			machine._on_reroll_pressed()
			check(is_same(machine.loadout, final_draw) and machine.rerolls_left == 0, "fourth reroll rejected")
	for i in machine.loadout.cards.size():
		var id: String = machine.loadout.cards[i]
		check(machine._reels[i].texture.resource_path == machine.EQUIPMENT[id].icon, "reel matches item")
	check((machine._panel.material != null) == (machine.loadout.group != ""), "jackpot-only foil")
	check(machine._reel_panels[3].visible == (machine.loadout.group == "crimson"),"fourth card shown only on crimson reveal")
	if machine.loadout.group == "crimson": check(machine.foil.get_shader_parameter("crimson"),"crimson reveal uses red foil")
	var rolled: Dictionary = machine.loadout
	check(rolled.perk == perk, "chosen hero's perk retained")
	machine._button.pressed.emit()
	machine._on_button()
	await process_frame
	await process_frame
	return rolled

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var machine: Node = main.starter_lottery
	for perk: String in ROSTER.START_CARDS:
		var jackpots := 0
		for bucket in 100:
			var draw: Dictionary = machine.draw_loadout(perk, bucket)
			var items: Array = draw.cards.duplicate()
			items.append(perk)
			if draw.backup != "": items.append(draw.backup)
			var growth: bool = machine.COMBOS.GROWTH_MEMBERS.all(func(id): return id in items)
			var arsenal: bool = machine.COMBOS.ARSENAL_MEMBERS.all(func(id): return id in items)
			var crimson: bool = machine.COMBOS.CRIMSON_MEMBERS.all(func(id): return id in items)
			check((bucket < 30) == (growth or arsenal or crimson), "actual full set at the 30/70 boundary")
			check(machine.WEAPONS.any(func(id): return id in items), "every opening can attack")
			if growth or arsenal or crimson: jackpots += 1
		check(jackpots == 30, "exactly 30 jackpot buckets")
	var picker: Node = main.hero_picker
	for index in 4:
		root.size = Vector2i(390,844) if index % 2 == 0 else Vector2i(900,600)
		main._on_start_button_pressed()
		await process_frame
		await process_frame
		check(paused and picker.is_visible_in_tree(), "the world waits for selection")
		check(picker.grid.columns == (2 if index % 2 == 0 else 4), "mobile/desktop columns")
		for i in 4:
			check(root.get_visible_rect().encloses(picker.cards[i].get_global_rect()), "all four choices fit")
			check(picker.portraits[i].texture == ROSTER.FRAMES[i].get_frame_texture(&"idle_right",0), "matching portrait")
		if index == 0:
			picker.back.pressed.emit()
			check(main.menu_page.visible and paused and not picker.visible,"back returns safely")
			main._on_start_button_pressed()
		picker.cards[index].pressed.emit()
		await process_frame
		await process_frame
		var rolled := await claim_start(main, ROSTER.START_CARDS[index], ["growth", "mixed", "arsenal", "crimson"][index], [0, 3, 0, 0][index])
		var g: Node = main.game
		var expected: Array = rolled.cards.duplicate()
		expected.append(rolled.perk)
		if rolled.backup != "": expected.append(rolled.backup)
		for id in g.equipment_panel.EQUIP_DEFS:
			check(g.equipment_panel.get_level(id) == expected.count(id), "exact starting rank "+id)
		check(g.hand_weapon.visible == ("axe_up" in expected), "axe visibility")
		check((g.circle_weapon.get_child_count() > 0) == ("circle_up" in expected), "book colliders")
		check(g.growth_combo_active == (rolled.group == "growth"), "real growth bonus activated")
		check(g.arsenal_combo.unlocked == (rolled.group == "arsenal"), "real arsenal shield activated")
		for weapon_id in ["axe_up", "circle_up"]:
			if weapon_id in expected: continue
			var preview: Dictionary = load("res://script/card_preview.gd").build(g, weapon_id)
			check(not preview.rows.is_empty(), "unowned weapon shows first-rank preview")
			g._on_upgrade_selected(weapon_id)
			check(g.equipment_panel.get_level(weapon_id) == 1, "unowned weapon acquired at rank one")
		check(g.hand_weapon.visible and g.hand_weapon.is_physics_processing(), "axe can attack")
		check(g.circle_weapon.get_child_count() > 0 and g.circle_weapon.is_processing(), "books orbit after acquisition")
		check(not paused and not picker.is_visible_in_tree(),"confirmed run")
		check(g.player.animated_sprite_2d.sprite_frames == ROSTER.FRAMES[index],"selected player in combat")
		check(g.equipment_panel.get_level(ROSTER.START_CARDS[index]) == expected.count(rolled.perk),"starter applied once")
		g.player._update_locomotion(Vector2(-1,0), 1.0/60)
		check(g.player.animated_sprite_2d.animation == &"walk_left","left poses")
		g.player.cast_pose()
		check(g.player.animated_sprite_2d.animation == &"cast_left","cast follows last side")
		g.player.receive_attack(5)
		check(g.player.animated_sprite_2d.animation == &"hurt_left","real damage plays hurt")
		g.player._start_dash(Vector2.RIGHT)
		check(g.player.animated_sprite_2d.animation == &"dash_right","right dash")
		if index == 3:
			await main._on_game_end_ui_retry_pressed()
			await claim_start(main, ROSTER.START_CARDS[index], "", 2)
			check(main.game.player.animated_sprite_2d.sprite_frames == ROSTER.FRAMES[index] and main.game.equipment_panel.get_level("rune_bolt") == 1,"Retry retains choice exactly once")
		await main._on_game_end_ui_main_menu_pressed()

	var game: Node = main.game
	for id in game.equipment_panel.EQUIP_DEFS:
		var path: String = game.equipment_panel.EQUIP_DEFS[id].icon
		var combat_icon: bool = id in ["light_thorn", "ice_wave", "ghost_dash", "blood_vortex", "draw_slash"]
		var side := 40 if combat_icon else 32
		check(path.begins_with("res://rogge_art/") and load(path).get_size() == Vector2(side, side), "equipment icon " + id)
	for spec in [["boss","lizard",1],["knight_boss","knight",2],["beast_boss","tide",3],["beast_boss","thunder",4],["wind_boss","wind-ranged",5],["wind_boss","wind-melee",5],["beast_boss","aegis",6],["treasure_guardian","guardian",3]]:
		var actor: Node = load("res://scenes/%s.tscn" % spec[0]).instantiate()
		if spec[1]=="guardian":
			actor.set_enemy_data(load("res://resource/Enemy2.tres"))
			actor.configure_guardian(300,60)
			actor.set_player_ref(game.player)
		else:
			actor.configure_stage(spec[2])
			actor.set_player(game.player)
		if spec[0]=="wind_boss": actor.configure_wind_role(1 if spec[1]=="wind-melee" else 0, game.spawner)
		game.add_child(actor)
		var poses: Node = actor.poses
		check(poses.sprite.material == null and poses.sprite.modulate == Color.WHITE, "native palette " + spec[1])
		check(poses.sprite.texture.resource_path.ends_with("/%s/poses.png" % spec[1]),"boss skin "+spec[1])
		var neutral := poses.clips.get_frame_texture(&"idle", 0) as AtlasTexture
		check(neutral.region.size == Vector2(144, 144), "fine source frame " + spec[1])
		for action in poses.clips.get_animation_names():
			for frame in poses.clips.get_frame_count(action):
				var tile := poses.clips.get_frame_texture(action, frame) as AtlasTexture
				check(tile.region.size == neutral.region.size and Rect2(Vector2.ZERO, tile.atlas.get_size()).encloses(tile.region), "valid pose region " + spec[1])
		poses._physics_process(0.1)
		actor.position.x += 10
		poses._physics_process(0.1)
		check(poses.current == &"approach" and not poses.sprite.flip_h,"right moving "+spec[1])
		actor.position.x -= 10
		poses._physics_process(0.1)
		check(poses.sprite.flip_h,"left moving "+spec[1])
		poses._physics_process(0.2)
		check(poses.current == &"idle", "no motion returns to idle")
		actor.free()
	if errors.is_empty(): print("HERO ART OK: four heroes, 30/70 roll boundary, three rerolls, final-only equipment, both live sets, rank zero weapons, retry, icons, directional actions, eight boss walk/idle skins")
	else:
		for error in errors: push_error(error)
	quit(0 if errors.is_empty() else 1)
