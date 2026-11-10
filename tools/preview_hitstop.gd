extends "res://tools/preview_motion_vfx.gd"

# QA-only observation of the real Debug buttons. Normal game never loads this.
var _captured_flash := 0
var _frame_bounds: Array = []

func _ready() -> void:
	super._ready()
	RenderingServer.frame_post_draw.connect(_capture_impact_frame)

func _capture_impact_frame() -> void:
	if not OS.has_feature("web") or not is_instance_valid(main) or not is_instance_valid(main.game): return
	if main._test_mode != &"hitstop": return
	var fx: Node = main.game.combat_feedback.impact_feedback
	if fx.flashes <= _captured_flash: return
	# GPU submission/readback can finish after the flash deadline in software GL;
	# retain the bounds sampled for this rendered frame, not a later wall clock.
	if _frame_bounds.is_empty(): return
	# Capture the completed real render before the short flash expires. Browser
	# screenshot round-trips can otherwise miss it; no gameplay clock is frozen.
	var png := get_viewport().get_texture().get_image().save_png_to_buffer()
	_captured_flash = fx.flashes
	var metadata := {"flashes":fx.flashes,"bounds":_frame_bounds,"scale":Engine.time_scale}
	JavaScriptBridge.eval("window.__hitCapture="+JSON.stringify(metadata)+";window.__hitCapture.image='"+Marshalls.raw_to_base64(png)+"';",true)

func _tick() -> void:
	super._tick()
	if not OS.has_feature("web") or not is_instance_valid(main) or not is_instance_valid(main.game): return
	var fx: Node = main.game.combat_feedback.impact_feedback
	var now := Time.get_ticks_usec()
	var visible_flashes: Array = []
	var transform: Transform2D = get_viewport().get_final_transform()*fx.get_global_transform_with_canvas()
	for record in fx.records:
		if now>=int(record.end) or record.texture==null: continue
		var rect: Rect2 = transform*record.transform*record.rect
		visible_flashes.append({"player":record.player,"remaining_ms":(record.end-now)/1000.0,
			"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	var data := {"preset":_rect(main.debug_page.get_node("VBoxContainer/DebugHitstopButton")),
		"mode":str(main._test_mode),"scale":Engine.time_scale,"owns":fx._owns_scale,
		"flashes":fx.flashes,"stops":fx.stops,"active":visible_flashes,
		"health":main.game.player.player_health,"paused":get_tree().paused}
	_frame_bounds = visible_flashes
	JavaScriptBridge.eval("window.__hit="+JSON.stringify(data)+";window.__hitSamples=window.__hitSamples||[];window.__hitSamples.push(window.__hit);if(window.__hitSamples.length>500)window.__hitSamples.shift();",true)
