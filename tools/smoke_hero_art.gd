extends SceneTree

const ROSTER := preload("res://script/hero_roster.gd")
var errors: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value: errors.append(message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
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
		var g: Node = main.game
		check(not paused and not picker.is_visible_in_tree(),"confirmed run")
		check(g.player.animated_sprite_2d.sprite_frames == ROSTER.FRAMES[index],"selected player in combat")
		check(g.equipment_panel.get_level(ROSTER.START_CARDS[index]) == 1,"starter applied once")
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
			check(main.game.player.animated_sprite_2d.sprite_frames == ROSTER.FRAMES[index] and main.game.equipment_panel.get_level("rune_bolt") == 1,"Retry retains choice exactly once")
		await main._on_game_end_ui_main_menu_pressed()

	var game: Node = main.game
	for id in game.equipment_panel.EQUIP_DEFS:
		var path: String = game.equipment_panel.EQUIP_DEFS[id].icon
		check(path.contains("/rogge_art/icons/") and load(path).get_size() == Vector2(32,32), "new icon " + id)
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
	if errors.is_empty(): print("HERO ART OK: four selection paths, retry, icons, directional actions, eight boss walk/idle skins")
	else:
		for error in errors: push_error(error)
	quit(0 if errors.is_empty() else 1)
