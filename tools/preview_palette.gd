extends Node

# Isolated visual fixture. Use tools/preview_palette.tscn as a QA entry; normal game scenes never invoke it.
var main: Node
var game: Node
var backgrounds := [0,4,9]
var background_index := 0
var held := {}
var card_group := 0
var fixture_ready := false

func _ready() -> void: call_deferred("_run")
func _enemy(at: Vector2, data_path: String = "res://resource/Enemy_1.tres") -> Node:
	var actor: Node = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_enemy_data(load(data_path))
	actor.set_player_ref(game.player)
	actor.health = 20000
	actor.add_to_group("EnemyGroup")
	game.add_child(actor)
	actor.global_position = at
	actor.set_physics_process(false)
	return actor
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await get_tree().process_frame
	await get_tree().process_frame
	await main._launch_run(&"")
	game = main.game
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.player.set_physics_process(false)
	game.player.global_position = Vector2.ZERO
	game.player.get_node("Camera2D").position_smoothing_enabled = false
	game.player.get_node("Camera2D").reset_smoothing()
	game.weather.set_preview(0,0)
	game.weather.set_process(false)
	game.meteors.set_process(false)
	game.variety.set_process(false)
	game.variety._notice.hide()
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]:
		game.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	for _i in 3: game._on_upgrade_selected("poison_trail")
	game.poison_trail.set_process(false)
	game.poison_trail._clock = 0.4
	_enemy(Vector2(-25,40))
	var slasher := _enemy(Vector2(105,-35))
	_enemy(Vector2(-115,-45),"res://resource/Enemy_4.tres")
	_enemy(Vector2(85,60),"res://resource/BladeMantis.tres")
	var elite := _enemy(Vector2(-90,80),"res://resource/Enemy2.tres")
	elite.set_elite_status()
	for i in 5:
		game.poison_trail._clouds[i].at = Vector2(-85+i*27,40)
		game.poison_trail._clouds[i].left = 4
	game.poison_trail._scan(0)
	game.poison_trail.queue_redraw()
	game.poison_trail._markers.queue_redraw()
	var slash: RefCounted = game.enemy_attacks.cast(slasher,&"cleave")
	if slash != null: slash.age = slash.windup*0.7
	game.enemy_attacks.set_physics_process(false)
	game.enemy_attacks.queue_redraw()
	for i in 8:
		game._spawn_xp_coin_now(Vector2(-60+i*20,85),2)
	for at in [Vector2(-95,20),Vector2(80,35)]:
		var orb: Node = game.spawn_healing_orb(at,5)
		orb.set_physics_process(false)
	for actor in game._xp_actors: actor.set_process(false)
	for at in [Vector2(55,-65),Vector2(85,-55)]:
		var shot: Node = load("res://scenes/enemy_projectile.tscn").instantiate()
		game.effect_container.add_child(shot)
		shot.launch(at,Vector2.LEFT,100,5,GamePalette.DANGER_RED)
		shot.set_physics_process(false)
	for i in 4: game.beast_powers.unlock(i)
	game.player.shield = 60
	game.player._sync_shield_visuals()
	main.mobile_controls.set_process(false)
	main.mobile_controls.dash_button.set_cooldown(1,true,false)
	game.get_node("InfiniteBackground")._apply_palette(backgrounds[background_index])
	get_tree().process_frame.connect(_tick)
	fixture_ready = true
	if OS.has_feature("web"): JavaScriptBridge.eval("window.__paletteReady=true",true)
	print("PALETTE PREVIEW READY")

func _pressed(key: Key) -> bool:
	var down := Input.is_physical_key_pressed(key)
	var changed: bool = down and not held.get(key,false)
	held[key] = down
	return changed
func _cards() -> void:
	var groups := [["gun_up","drone_up","poison_trail"],["left_fist","critical_glasses","regen_up"]]
	var entries: Array = []
	for entry in game.pause_menu.upgrade_pool:
		if entry.id in groups[card_group]: entries.append(entry)
	# Restore the complete pool when switching groups.
	if not game.pause_menu.has_meta("full_pool"): game.pause_menu.set_meta("full_pool",game.pause_menu.upgrade_pool.duplicate(true))
	entries.clear()
	for entry in game.pause_menu.get_meta("full_pool"):
		if entry.id in groups[card_group]: entries.append(entry)
	game.pause_menu.upgrade_pool = entries
	game.pause_menu.show_upgrade_options()
func _tick() -> void:
	if not fixture_ready: return
	if _pressed(KEY_B):
		background_index = (background_index+1)%backgrounds.size()
		game.get_node("InfiniteBackground")._apply_palette(backgrounds[background_index])
	if _pressed(KEY_C):
		if game.pause_menu.visible:
			game.pause_menu.hide()
			get_tree().paused = false
		else: _cards()
	if _pressed(KEY_N):
		card_group = 1-card_group
		_cards()
	var button: Control = main.mobile_controls.dash_button
	if _pressed(KEY_1):
		button.reset_feedback()
		button.set_cooldown(1,true,false)
	if _pressed(KEY_2): button.set_pressed_visual(true)
	if _pressed(KEY_3):
		button.set_pressed_visual(false)
		button.set_cooldown(0.45,false,false)
	if _pressed(KEY_4):
		button.set_cooldown(1,true,false)
		button.visual_scale = 1.08
		button.ready_glow = 1
	_publish_state()

func _publish_state() -> void:
	if not OS.has_feature("web"): return
	var dash: Control = main.mobile_controls.dash_button
	JavaScriptBridge.eval("window.__paletteState="+JSON.stringify({"background":background_index,"cards":game.pause_menu.visible,"group":card_group,"pressed":dash._pressed,"available":dash.available,"progress":dash.progress,"ready_glow":dash.ready_glow}),true)
