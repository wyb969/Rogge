extends SceneTree

var failures: Array[String] = []
var player: Node
var controls: Node
var mobile: Node

func _init() -> void :
	call_deferred("_run")

func _run() -> void :
	root.size = Vector2i(900, 600)
	mobile = root.get_node("MobileInput")
	player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	controls = load("res://scenes/mobile_controls.tscn").instantiate()
	root.add_child(controls)
	await process_frame
	await physics_frame
	controls._layout_controls()

	for i in 8:
		var dir: = Vector2.RIGHT.rotated(float(i) * TAU / 8.0)
		for strength in [1.0, 0.16]:
			_reset()
			_stick(dir, strength)
			_touch(1, true, _dash_center())
			player._physics_process(1.0 / 60.0)
			_expect_direction(dir, "held stick %s strength %s" % [i, strength])


		_reset()
		_stick(dir, 1.0)
		player._physics_process(1.0 / 60.0)
		_touch(0, false, _stick_center())
		player.velocity = Vector2.ZERO
		_touch(1, true, _dash_center())
		player._physics_process(1.0 / 60.0)
		_expect_direction(dir, "released stick and stationary %s" % i)


		_reset()
		_stick(dir, 1.0)
		_touch(1, true, _dash_center())
		_touch(0, false, _stick_center())
		player._physics_process(1.0 / 60.0)
		_expect_direction(dir, "release in request frame %s" % i)

		_touch(1, false, _dash_center())
		player.dashing = false
		player.can_dash = true
		player.velocity = Vector2.ZERO
		_touch(1, true, _dash_center())
		player._physics_process(1.0 / 60.0)
		_expect_direction(dir, "repeat dash after snapshot %s" % i)

	_reset()
	_stick(Vector2.UP, 1.0)
	var emulated: = InputEventMouseButton.new()
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.position = _dash_center()
	emulated.pressed = true
	controls._input(emulated)
	emulated.pressed = false
	controls._input(emulated)
	_expect(mobile.move_vector.normalized().is_equal_approx(Vector2.UP), "emulated mouse does not release or redirect finger 0")
	_touch(1, true, _dash_center())
	var drag: = InputEventScreenDrag.new()
	drag.index = 1
	drag.position = _stick_center() + Vector2.RIGHT * 100.0
	controls._input(drag)
	player._physics_process(1.0 / 60.0)
	_expect_direction(Vector2.UP, "second finger does not redirect stick")


	_reset()
	_stick(Vector2.LEFT, 1.0)
	player._physics_process(1.0 / 60.0)
	controls._update_stick(_stick_center() + Vector2.RIGHT * controls.stick_radius * 0.05)
	player.velocity = Vector2.ZERO
	_touch(1, true, _dash_center())
	player._physics_process(1.0 / 60.0)
	_expect_direction(Vector2.LEFT, "deadzone jitter keeps previous heading")

	mobile.request_dash()
	controls.hide_controls()
	_expect( not mobile.dash_just_pressed and mobile.move_vector == Vector2.ZERO, "hiding controls clears pending input")
	_expect(controls._stick_touch_index == -1 and controls._dash_touch_index == -1, "hiding controls releases finger ownership")


	_reset()
	_stick(Vector2.LEFT, 1.0)
	var mouse: = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = _dash_center()
	mouse.pressed = true
	controls._input(mouse)
	mouse.pressed = false
	controls._input(mouse)
	_expect(controls._stick_touch_index == 0 and mobile.has_move_input(), "mouse fallback has a separate pointer identity")

	if failures.is_empty():
		print("DASH DIRECTION OK: 8 directions, light input, stopped/released stick, request snapshot, multi-touch and reset")
	else:
		for failure in failures:
			push_error(failure)
	controls.hide_controls()
	player.free()
	controls.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _reset() -> void :
	controls.hide_controls()
	controls.visible = true
	mobile.controls_enabled = true
	player.dashing = false
	player.can_dash = true
	player.velocity = Vector2.ZERO
	player.last_move_direction = Vector2.RIGHT
	player.dashing_timer.stop()
	player.can_dasing_timer.stop()
	player.shadow_timer.stop()

func _stick(dir: Vector2, strength: float) -> void :
	_touch(0, true, _stick_center() + dir * controls.stick_radius * strength)

func _touch(index: int, pressed: bool, pos: Vector2) -> void :
	var event: = InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = pos
	controls._input(event)

func _stick_center() -> Vector2:
	return controls.stick_base.global_position + controls.stick_base.size * 0.5

func _dash_center() -> Vector2:
	return controls.dash_button.global_position + controls.dash_button.size * 0.5

func _expect_direction(dir: Vector2, context: String) -> void :
	_expect(player.dashing and player.dash_direction.is_equal_approx(dir), context + ": wrong direction " + str(player.dash_direction))
	_expect(player.velocity.distance_to(dir * player.DASH_SPEED) < 0.01, context + ": wrong dash velocity " + str(player.velocity))

func _expect(ok: bool, message: String) -> void :
	if not ok:
		failures.append(message)
