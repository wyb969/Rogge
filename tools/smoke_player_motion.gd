extends SceneTree

var failures: Array[String] = []
var checks := 0
var main: Node
var game: Node
var player: Node
var saved_fps: int
var mobile: Node

func _init() -> void: call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func steps(count: int) -> void:
	for _i in count: await physics_frame
func release_input() -> void:
	for action in ["left", "right", "up", "down", "roll"]: Input.action_release(action)
	mobile.clear_move()
	mobile.clear_dash()
func fresh() -> void:
	release_input()
	await main._launch_run(&"")
	game = main.game
	player = game.player
	mobile.controls_enabled = false
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.spawner.set_process(false)
	game.weather.stop()
	game.meteors.set_process(false)
	game.variety.set_process(false)
	game.combat_feedback.set_process(false)
	for path in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	await steps(2)

func _run() -> void:
	mobile = root.get_node("MobileInput")
	saved_fps = Engine.physics_ticks_per_second
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var travel: Array[float] = []
	for fps in [30, 60]:
		Engine.physics_ticks_per_second = fps
		await fresh()
		var origin: Vector2 = player.global_position
		Input.action_press("right")
		await steps(fps)
		travel.append(player.global_position.x - origin.x)
		expect(is_equal_approx(player.velocity.length(), 100), "real input retains base speed at %d Hz" % fps)
		expect(player.animated_sprite_2d.animation == &"right", "right travel uses side animation")
		expect(not player.cpu_particles_2d.emitting and not player.cpu_particles_2d.visible, "walking never starts the old rotating quad emitter")
		expect(game.combat_feedback.ghosts.is_empty(), "walking creates no dash ghosts")
		var before: Vector2 = player.global_position
		var phase: float = player._walk_phase
		await steps(fps / 10)
		var distance: float = player.global_position.distance_to(before)
		var advance: float = fposmod(player._walk_phase - phase, 1)
		expect(absf(advance - distance / player.WALK_CYCLE_DISTANCE) < 0.002, "walk cycle follows real displacement at %d Hz" % fps)
		release_input()
		await steps(fps / 3)
		expect(player.velocity.is_zero_approx() and player.animated_sprite_2d.frame == 0 and not player.animated_sprite_2d.is_playing(), "friction settles to a stopped neutral pose")
		var mouse := InputEventMouseMotion.new()
		mouse.position = Vector2(-1000, -1000)
		Input.parse_input_event(mouse)
		await steps(2)
		expect(player.animated_sprite_2d.animation == &"right", "mouse movement cannot turn an idle hero")
	expect(absf(travel[0] - travel[1]) < 2.5, "30/60 Hz movement keeps the same travel within discrete acceleration error")
	Engine.physics_ticks_per_second = 60
	await fresh()
	Input.action_press("left")
	await steps(16)
	expect(player.animated_sprite_2d.animation == &"left", "left movement changes side without mouse aiming")
	release_input()
	await steps(15)
	Input.action_press("up")
	await steps(20)
	expect(player.animated_sprite_2d.animation == &"left", "vertical movement preserves horizontal facing")
	release_input()
	await steps(15)
	game._on_upgrade_selected("speed_up")
	Input.action_press("right")
	await steps(20)
	var start: Vector2 = player.global_position
	var phase: float = player._walk_phase
	await steps(6)
	var moved: float = player.global_position.distance_to(start)
	expect(is_equal_approx(player.velocity.length(), 120), "speed card still grants fixed20")
	expect(absf(fposmod(player._walk_phase - phase, 1) - moved / player.WALK_CYCLE_DISTANCE) < 0.002, "speed card automatically accelerates the distance-driven gait")
	release_input()
	await steps(15)
	var wall := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20, 400)
	collider.shape = rectangle
	wall.add_child(collider)
	game.add_child(wall)
	wall.global_position = player.global_position + Vector2(player.pickup_range + 12, 0)
	Input.action_press("right")
	await steps(30)
	expect(player.locomotion_speed <= player.WALK_STOP_SPEED and player.animated_sprite_2d.frame == 0, "actual wall collision stops gait even while movement is held")
	release_input()
	wall.queue_free()
	await steps(2)
	player.last_move_direction = Vector2.UP
	player.velocity = Vector2.ZERO
	player._start_dash(Vector2.ZERO)
	await steps(2)
	expect(player.dash_direction == Vector2.UP, "idle keyboard dash follows last movement rather than mouse")
	expect(player.animated_sprite_2d.animation in [&"left", &"right"] and player.animated_sprite_2d.frame == 1, "dash keeps a side launch pose without hyper-fast running frames")
	player.set_movement_locked(true)
	var locked: Vector2 = player.global_position
	Input.action_press("right")
	await steps(12)
	expect(player.global_position == locked and player.animated_sprite_2d.frame == 0 and player.locomotion_speed == 0, "trial movement lock clears locomotion and cannot drift")
	player.set_movement_locked(false)
	release_input()
	player.set_physics_process(false)
	var physics_scale: Vector2 = player.scale
	player._update_locomotion(Vector2(1000, 0) / 60, 1.0 / 60)
	expect(player._walk_phase < 0.33, "very fast builds cap visual cadence instead of flickering")
	player._tick_visuals(0.5)
	expect(player.animated_sprite_2d.rotation == 0 and player.scale == physics_scale, "walking stays axis-aligned and cosmetic pose never scales the collider")
	for direction in [&"left", &"right"]:
		for index in 3:
			var texture := player.animated_sprite_2d.sprite_frames.get_frame_texture(direction, index) as AtlasTexture
			expect(texture != null and texture.filter_clip, "side atlas frames explicitly clip neighbor pixels")
	player.reset_dash()
	expect(player.locomotion_speed == 0 and player.animated_sprite_2d.frame == 0, "run reset clears presentation")
	main.show_main_menu()
	release_input()
	Engine.physics_ticks_per_second = saved_fps
	if failures.is_empty(): print("PLAYER MOTION OK: %d checks; real30/60Hz input, travel/acceleration, actual-distance gait, speed card, stop/wall/vertical/mouse, last-direction dash, lock/reset, no walking particles, clipped frames and stable collider" % checks)
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
