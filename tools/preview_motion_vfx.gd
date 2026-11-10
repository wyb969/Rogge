extends Node

# QA-only scene. Exercise actual menu/preset controls; the normal entry never loads this.
const ARC := preload("res://script/arc_motion.gd")
var main: Node
var held := {}
func _ready() -> void: call_deferred("_run")
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().process_frame.connect(_tick)
	if OS.has_feature("web"): JavaScriptBridge.eval("window.__vfxReady=true;window.__arcSamples=[]",true)
func _pressed(key: Key) -> bool:
	var down := Input.is_physical_key_pressed(key)
	var result: bool = down and not held.get(key,false)
	held[key] = down
	return result
func _rect(control: Control) -> Array:
	var tr := get_viewport().get_final_transform()
	var center := tr * control.get_global_rect().get_center()
	var size := tr.get_scale() * control.size
	return [center.x,center.y,size.x,size.y]
func _tick() -> void:
	if not OS.has_feature("web") or not is_instance_valid(main.game): return
	var game: Node = main.game
	var sandbox: Node = game.get_node_or_null("MotionVfxDebug")
	var command: Variant = JavaScriptBridge.eval("(function(){var c=window.__vfxCommand;window.__vfxCommand=null;return c;})()",true)
	if command == "physics30": Engine.physics_ticks_per_second = 30
	if command == "physics60": Engine.physics_ticks_per_second = 60
	if command == "pause": get_tree().paused = true
	if command == "resume": get_tree().paused = false
	if _pressed(KEY_F2) and sandbox != null: sandbox.replay()
	if _pressed(KEY_F3): get_tree().paused = not get_tree().paused
	if _pressed(KEY_F4): Engine.physics_ticks_per_second = 30 if Engine.physics_ticks_per_second == 60 else 60
	if _pressed(KEY_F6): game.player.reset_dash()
	var player: Node = game.player
	var hud: Node2D = player.get_node("InkFootHud")
	var tr := get_viewport().get_final_transform()
	var arc_samples: Array = []
	for bomb in game.bomb_controller._bombs:
		if not bomb.active: continue
		var age := ARC.render_age(bomb.previous_age,bomb.age)
		var at := ARC.position_at(bomb.from,bomb.at,age,game.bomb_controller.THROW_SECONDS,44)
		arc_samples.append({"kind":"player","age":bomb.age,"visual_age":age,"x":at.x,"y":at.y})
	for slot in game.enemy_attacks.slots:
		if not slot.active or slot.kind != &"mortar": continue
		var age := ARC.render_age(slot.previous_age,slot.age)
		var at := ARC.position_at(slot.origin,slot.target,age-0.25,0.85,45)
		arc_samples.append({"kind":"enemy","age":slot.age,"visual_age":age,"x":at.x,"y":at.y})
	var offset: Vector2 = game.ink_surf._caption.global_position-player.global_position
	var stick: Control = main.mobile_controls.stick_base
	var data := {
		"mode":str(main._test_mode),"debug_page":main.debug_page.visible,"menu":main.menu_page.visible,
		"menu_debug":_rect(main.get_node("mainUI/Control/MenuCenter/VBoxContainer/DebugButton")),
		"preset":_rect(main.debug_page.get_node("VBoxContainer/DebugMotionVfxButton")),
		"home":_rect(main.fullscreen_toggle.home_button),
		"position":[player.global_position.x,player.global_position.y],
		"hud_offset":[offset.x,offset.y],"hud_visible":hud.visible,"caption":game.ink_surf._caption.text,
		"dashing":player.dashing,"direction":[player.dash_direction.x,player.dash_direction.y],
		"ghosts":game.combat_feedback.ghosts.size(),"bomb_rank":game.bomb_controller.level,
		"canvas":[get_tree().root.size.x,get_tree().root.size.y],"physics_hz":Engine.physics_ticks_per_second,
		"stick":_rect(stick),"stick_radius":main.mobile_controls.stick_radius*tr.get_scale().x,
		"dash":_rect(main.mobile_controls.dash_button),"paused":get_tree().paused,
		"screen_player":[player.get_global_transform_with_canvas().origin.x,player.get_global_transform_with_canvas().origin.y],
		"arcs":arc_samples,"frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),
	}
	if sandbox != null:
		data.replay = _rect(sandbox.replay_button)
		data.reset_dash = _rect(sandbox.dash_button)
	JavaScriptBridge.eval("window.__vfx="+JSON.stringify(data)+";if(window.__vfx.arcs.length){window.__arcSamples.push(window.__vfx);if(window.__arcSamples.length>400)window.__arcSamples.shift();}",true)
