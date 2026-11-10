extends Node

# QA-only entry: real player physics, controls, camera and presentation in a quiet run.
# Normal game scenes never invoke this harness or expose its telemetry/test keys.
var main: Node
var game: Node
var ready_for_preview := false
var held := {}
var _boosted := false

func _ready() -> void: call_deferred("_run")
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
	game.weather.set_preview(0, 0)
	game.weather.set_process(false)
	game.meteors.set_process(false)
	game.variety.set_process(false)
	game.variety._notice.hide()
	for path in ["HandWeapon", "CircleWeapon", "Weapon", "DroneController", "MolotovController", "FreezeController"]:
		game.get_node(path).process_mode = Node.PROCESS_MODE_DISABLED
	game.get_node("InfiniteBackground")._apply_palette(0)
	get_tree().process_frame.connect(_tick)
	ready_for_preview = true
	if OS.has_feature("web"): JavaScriptBridge.eval("window.__motionReady=true", true)
	print("PLAYER MOTION PREVIEW READY")

func _pressed(key: Key) -> bool:
	var down := Input.is_physical_key_pressed(key)
	var changed: bool = down and not held.get(key, false)
	held[key] = down
	return changed

func _tick() -> void:
	if not ready_for_preview: return
	if _pressed(KEY_F2) and not _boosted:
		for _i in 3: game._on_upgrade_selected("speed_up")
		_boosted = true
	if _pressed(KEY_F3): get_tree().paused = not get_tree().paused
	if not OS.has_feature("web"): return
	var p: Node = game.player
	var sprite: AnimatedSprite2D = p.animated_sprite_2d
	var camera: Camera2D = p.get_node("Camera2D")
	var motion: RefCounted = game.combat_feedback._camera_motion
	var transform := get_viewport().get_final_transform()
	var stick: Control = main.mobile_controls.stick_base
	var dash: Control = main.mobile_controls.dash_button
	var data := {
		"position":[p.global_position.x,p.global_position.y],
		"speed":p.locomotion_speed, "base_speed":p.effective_move_speed(),
		"animation":sprite.animation, "frame":sprite.frame, "phase":p._walk_phase,
		"rotation":sprite.rotation, "scale":[sprite.scale.x,sprite.scale.y],
		"dashing":p.dashing, "dash_direction":[p.dash_direction.x,p.dash_direction.y],
		"particles":p.cpu_particles_2d.emitting, "particle_visible":p.cpu_particles_2d.visible,
		"ghosts":game.combat_feedback.ghosts.size(),
		"camera_drag":[motion.drag.x,motion.drag.y], "camera_smoothing":camera.position_smoothing_enabled,
		"paused":get_tree().paused,
		"canvas_size":[get_tree().root.size.x,get_tree().root.size.y],
		"stick":transform*(stick.global_position+stick.size*0.5),
		"stick_radius":main.mobile_controls.stick_radius*transform.get_scale().x,
		"dash":transform*(dash.global_position+dash.size*0.5),
		"screen_player":p.get_global_transform_with_canvas().origin,
	}
	# JSON vectors need numeric arrays, not their display strings.
	for key in ["stick", "dash", "screen_player"]:
		var point: Vector2 = data[key]
		data[key] = [point.x,point.y]
	JavaScriptBridge.eval("window.__motion="+JSON.stringify(data),true)
