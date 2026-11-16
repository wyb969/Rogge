extends Node
var main: Node
var g: Node
var actor: Node
func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await main._launch_run(&"minefield")
	g = main.game
	g.spawner.timer.stop()
	g.spawner.get_node("Elite").stop()
	g.spawner.set_process(false)
	g.weather.set_process(false)
	g.variety.set_process(false)
	g.meteors.set_process(false)
	g.weather._preview.hide()
	g.variety._notice.hide()
	g.variety._notice_left = 0
	g.combat_feedback.set_process(false)
	g.player.set_physics_process(false)
	g.player.set_process(false)
	for path in ["HandWeapon","CircleWeapon","Weapon","DroneController","MolotovController","FreezeController"]: g.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	var field: Node = g.weather.minefield
	field.set_physics_process(false)
	field._physics_process(0.01)
	field._clock = 2
	var at: Vector2 = field.mines[4].at
	g.player.global_position = at-field.FOOT+Vector2(-20,0)
	actor = load("res://scenes/enemy_shell.tscn").instantiate()
	actor.set_enemy_data(load("res://resource/Enemy_3.tres"))
	actor.set_player_ref(g.player)
	actor.add_to_group("EnemyGroup")
	g.add_child(actor)
	actor.health = 1000
	actor.global_position = at-field.FOOT+Vector2(20,0)
	actor.set_physics_process(false)
	actor.set_process(false)
	var camera: Camera2D = g.player.get_node("Camera2D")
	camera.global_position = at+Vector2(0,-15)
	camera.force_update_scroll()
	for size in [Vector2i(900,600),Vector2i(390,844)]: await capture("ground",size)
	field._snapshot()
	var selected: Array[int] = [4]
	field._blast_batch(selected)
	actor.set_process(false)
	g.player._physics_process(0.14)
	actor._physics_process(0.14)
	g.player._tick_visuals(0.22)
	actor._process(0.22)
	actor.set_process(false)
	field._clock += 0.22
	camera.global_position = at+Vector2(0,-15)
	camera.force_update_scroll()
	for size in [Vector2i(900,600),Vector2i(390,844)]: await capture("apex",size)
	g.player._tick_visuals(0.28)
	actor._process(0.28)
	actor.set_process(false)
	field._clock += 0.28
	await capture("landing",Vector2i(900,600))
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
func capture(label: String,size: Vector2i) -> void:
	get_window().size = size
	for i in 12: await get_tree().process_frame
	g.player.player_ring.queue_redraw()
	g.weather.minefield.queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("ROGGE_CAPTURE_DIR")+"/airborne-"+label+"-%dx%d.png"%[size.x,size.y])
