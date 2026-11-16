extends RefCounted
# Screen-space HUD, independent of card containers and world-camera zoom.
static func fit(panel: Control, bar: ProgressBar, title: Label, action: Label=null, slot: int=0) -> float:
	var viewport:=panel.get_viewport()
	var ui:=display_scale(panel)
	var vp:=viewport.get_visible_rect().size
	var width:=minf(420*ui,vp.x-32*ui)
	panel.size=Vector2(width,12*ui)
	panel.position=Vector2((vp.x-width)*0.5,(116+20*slot)*ui)
	title.position=Vector2.ZERO
	title.custom_minimum_size=Vector2.ZERO
	title.size=Vector2(width,18*ui)
	title.clip_text=true
	title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	UiFonts.apply_to_label(title,int(13*ui),true)
	bar.position=Vector2.ZERO
	bar.size=Vector2(width,12*ui)
	if action!=null:
		action.position=Vector2(0,36*ui)
		action.size=Vector2(width,16*ui)
		action.clip_text=true
		UiFonts.apply_to_label(action,int(10*ui),true)
	title.hide()
	if action!=null: action.hide()
	return ui

static func display_scale(owner: Node) -> float:
	var viewport:=owner.get_viewport()
	var transform:=viewport.get_final_transform()
	var ratio:=1.0
	if OS.has_feature("web"):
		var css: Variant=JavaScriptBridge.eval("document.getElementById('canvas').getBoundingClientRect().width",true)
		if (css is float or css is int) and float(css)>0: ratio=float(viewport.get_tree().root.size.x)/float(css)
	var ui:=ratio/maxf((transform*Vector2.RIGHT-transform*Vector2.ZERO).length(),0.1)
	# Tiny/minimized and headless windows must still fit the logical viewport.
	var vp:=viewport.get_visible_rect().size
	return minf(ui,minf(vp.x/320.0,vp.y/240.0))
