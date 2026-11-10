extends SceneTree
var failures: Array[String] = []
func _init() -> void : call_deferred("_run")
func _expect(ok: bool, message: String) -> void :
	if not ok: failures.append(message)
func _run() -> void :
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	game.start_game()
	game.diagnostic_mode = "camera_test"
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	game.player.set_physics_process(false)
	game.combat_feedback.set_process(false)
	var motion: RefCounted = game.combat_feedback._camera_motion
	var camera: Camera2D = game.player.get_node("Camera2D")
	var origin: Vector2 = camera.position
	var zoom: Vector2 = camera.zoom
	game.player.velocity = Vector2(100, 0)
	game.player.position += Vector2(100,0) / 60
	motion.tick(1.0 / 60, false, 1)
	_expect(motion.drag.x < 0 and motion.drag.x > -2, "movement adds gradual position lag")
	for _frame in 120:
		game.player.position += Vector2(100,0) / 60
		motion.tick(1.0 / 60, false, 1)
	_expect(motion.drag.x < -7 and motion.drag.x > -11 and absf(motion.drag.y) < 0.001, "steady movement has a short single-layer lag")
	game.player.velocity = Vector2(-100, 0)
	for _frame in 120:
		game.player.position += Vector2(-100,0) / 60
		motion.tick(1.0 / 60, false, 1)
	_expect(motion.drag.x > 7 and motion.drag.x < 11, "direction reversal settles at a short bounded lag")

	var frozen: Vector2 = camera.position
	motion.tick(1.0 / 60, true, 1)
	_expect(camera.position == frozen, "reward pauses freeze follow inertia")
	game.player.dashing = true
	game.player.velocity = Vector2(700, -700)
	for _frame in 120:
		game.player.position += Vector2(700,-700) / 30
		motion.tick(1.0 / 30, false, 1)
	_expect(motion.drag.length() <= motion.MAX_DRAG + 0.001 and not camera.position_smoothing_enabled, "dash lag stays bounded without a second smoothing layer")
	game.player.dashing = false
	game.player.velocity = Vector2.ZERO
	for _frame in 180: motion.tick(1.0 / 60, false, 1)
	_expect(motion.drag.length() < 0.01, "stopping/dash recovery returns smoothly to the hero")
	game.player.velocity = Vector2(100, 0)
	for _frame in 30: motion.tick(1.0 / 60, false, 1)
	_expect(motion.drag.length() < 0.01, "pushing a wall cannot create lag from intended velocity alone")
	game.player.position += Vector2(1000,0)
	motion.tick(1.0/60, false, 1)
	_expect(motion.drag == Vector2.ZERO, "teleports reset follow rather than sweeping the world")
	motion.tick(1.0 / 60, false, 0)
	_expect(camera.position == origin and motion.drag == Vector2.ZERO, "zero comfort intensity disables additional motion immediately")
	var actor_position: Vector2 = game.player.position
	motion.tick(0.02, false, 1)
	_expect(game.player.position == actor_position and camera.zoom == zoom and camera.rotation == 0, "camera feedback cannot move a collider or change FOV/rotation")
	game.end_game()
	_expect(camera.position == origin and camera.offset == Vector2.ZERO and motion.drag == Vector2.ZERO, "run end clears all camera displacement")
	if failures.is_empty(): print("CAMERA MOTION OK: actual-position lag/stop/reversal, wall/teleport, pause, single-layer bounded dash catch-up, zero setting, unchanged collider/FOV and teardown")
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
