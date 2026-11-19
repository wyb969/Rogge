extends Control

const LIFT := preload("res://assest/sounds/forge_lift.ogg")
const SEAT := preload("res://assest/sounds/forge_seat.ogg")
const TAP := preload("res://assest/sounds/forge_tap.ogg")
const WORK := preload("res://assest/sounds/forge_work.ogg")
const UPGRADE := preload("res://assest/sounds/forge_upgrade.ogg")
const PINK_CHIME := preload("res://assest/sounds/forge_pink.ogg")
const ORANGE_CHIME := preload("res://assest/sounds/forge_orange.ogg")
const HOLD := preload("res://assest/sounds/forge_hold.ogg")
const DOWNGRADE := preload("res://assest/sounds/forge_downgrade.ogg")
const GOLD := Color("#ffc750")
const AMBER := Color("#ff8538")
const MOLTEN := Color("#ff5628")
const IVORY := Color("#fff5cb")
const ROSE := Color("#ff82c6")
const ORCHID := Color("#c089ed")
const PEARL := Color("#fff0fd")

var _card_voice := AudioStreamPlayer.new()
var _voice := AudioStreamPlayer.new()
var _frame := Control.new()
var _ink := Control.new()
var _tier := 1
var _elapsed := 0.0
var _duration := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	AudioManager.configure_sfx(_voice)
	_voice.volume_db = -6.5
	add_child(_voice)
	AudioManager.configure_sfx(_card_voice)
	_card_voice.volume_db = -11.0
	add_child(_card_voice)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.clip_contents = true
	add_child(_frame)
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_ink)
	_ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ink.draw.connect(_paint)
	_frame.hide()
	set_process(false)

func reveal_seconds(tier: int) -> float:
	return _success_chime(tier).get_length()

func _success_chime(tier: int) -> AudioStream:
	if tier >= 3: return ORANGE_CHIME
	return PINK_CHIME if tier == 2 else UPGRADE

func card_cue(stream: AudioStream) -> void:
	_card_voice.stream = stream
	_card_voice.play()

func start_work() -> void:
	cancel_fx()
	_play(WORK)

func reveal(outcome: String, target: Rect2, tier := 1) -> void:
	cancel_fx()
	match outcome:
		"up":
			_tier = tier
			_duration = reveal_seconds(tier)
			_elapsed = 0.0
			_play(_success_chime(tier))
			move_target(target)
			_frame.show()
			set_process(true)
			_ink.queue_redraw()
		"down":
			_play(DOWNGRADE)
		"stay":
			_play(HOLD)

func move_target(target: Rect2) -> void:
	# Clip to the art aperture even on the narrowest layout. Labels lie outside it.
	_frame.position = target.position - Vector2(2,2)
	_frame.size = target.size + Vector2(4,4)

func _play(stream: AudioStream) -> void:
	AudioManager.focus_sfx(stream.get_length())
	_voice.stream = stream
	_voice.play()

func cancel_fx() -> void:
	_card_voice.stop()
	_voice.stop()
	_elapsed = _duration
	_frame.hide()
	set_process(false)

func _process(_delta: float) -> void:
	_elapsed = _voice.get_playback_position() if _voice.playing else _duration
	if _elapsed >= _duration:
		_frame.hide()
		set_process(false)
	else:
		_ink.queue_redraw()

func _paint() -> void:
	if _duration <= 0 or _elapsed >= _duration or _frame.size.x <= 0 or _frame.size.y <= 0: return
	# Design in a common 100-unit aperture, resolving to the card's own physical pixels.
	_ink.draw_set_transform(Vector2.ZERO, 0, _frame.size / 100.0)
	var t := clampf(_elapsed / _duration, 0, 1)
	var rim := ROSE if _tier == 2 else GOLD
	var white := PEARL if _tier == 2 else IVORY
	var flash := 1.0 - smoothstep(0.015, 0.32, t)
	var fade := 1.0 - smoothstep(0.43, 1.0, t)
	_ink.draw_rect(Rect2(1,1,98,98), Color(rim, 0.23 * flash))
	_ink.draw_rect(Rect2(1,1,98,98), Color(rim, fade * 0.86), false, 3)
	_ink.draw_rect(Rect2(4,4,92,92), Color(white, flash * 0.86), false, 2)
	if _tier >= 3:
		_molten_reveal(t, fade)
	elif _tier == 2:
		_crystal_reveal(t, fade)
	else:
		_strike_rays(t, fade)
	_sweep(t, white, fade)
	# A second glint answers the cadence; the last rim fades with the ringing chord.
	var coda := smoothstep(0.48, 0.67, t) * (1.0 - smoothstep(0.7, 1.0, t))
	var glint := Vector2(lerpf(18.0, 81.0, smoothstep(0.5, 0.91, t)), 22)
	_star(glint, 11 * coda, 18 * coda, white, coda)
	_ink.draw_rect(Rect2(2,2,96,96), Color(rim, 0.6 * coda), false, 2)

func _sweep(t: float, color: Color, fade: float) -> void:
	var head := lerpf(-18,160,t / 0.54)
	for y in range(0,100,4):
		var x := head - float(y) * 0.45
		_ink.draw_rect(Rect2(x-9,y,14,4), Color(color, fade * 0.38))
		_ink.draw_rect(Rect2(x+5,y,3,4), Color(color, fade * 0.85))

func _star(at: Vector2, width: float, height: float, color: Color, alpha: float) -> void:
	if alpha <= 0.01 or width < 1.0 or height < 1.0: return
	var core := maxf(1.0, minf(width, height) * 0.20)
	var points := PackedVector2Array([
		at + Vector2(0,-height), at + Vector2(core,-core), at + Vector2(width,0),
		at + Vector2(core,core), at + Vector2(0,height), at + Vector2(-core,core),
		at + Vector2(-width,0), at + Vector2(-core,-core)
	])
	_ink.draw_colored_polygon(points, Color(color,alpha))
	_ink.draw_rect(Rect2(at-Vector2.ONE*core,Vector2.ONE*core*2.0), Color(Color.WHITE,alpha))

func _strike_rays(t: float, fade: float) -> void:
	var burst := ease(clampf(t / 0.40,0,1),0.27)
	for i in 8:
		var dir := Vector2.from_angle(PI * (i/4.0 + 0.125))
		var tip := Vector2(50,50) + dir * lerpf(24,64,burst)
		var heel := Vector2(50,50) + dir * lerpf(13,60,smoothstep(0.03,0.69,t))
		var edge := dir.orthogonal() * (3.0 * fade)
		if heel.distance_to(tip) > 2 and edge.length() > 0.45:
			_ink.draw_colored_polygon(PackedVector2Array([tip,heel-edge,heel+edge]), Color(GOLD, fade))
	var spark := sin(PI * clampf(t / 0.76,0,1))
	_star(Vector2(61,33), 17*spark, 32*spark, IVORY, spark)

func _crystal_reveal(t: float, fade: float) -> void:
	var lift := ease(clampf(t / 0.68,0,1),0.42)
	# Rose glass splits into six faceted shards. The central icon stays legible.
	for i in 6:
		var angle := TAU * i / 6.0 - 1.18
		var dir := Vector2.from_angle(angle)
		var at := Vector2(50,50) + dir * lerpf(26,43,lift)
		var axial := dir.rotated(-0.19) * (11.0 if i%2 else 14.0)
		var across := axial.orthogonal() * 0.34
		var tip := at + axial
		var heel := at - axial * 0.55
		_ink.draw_colored_polygon(PackedVector2Array([tip,at-across,heel]), Color(ORCHID,fade))
		_ink.draw_colored_polygon(PackedVector2Array([tip,heel,at+across]), Color(ROSE,fade))
		_ink.draw_line(tip,at+across,Color(PEARL,fade),1.8)
	for i in 3:
		var phase := clampf((t - i * 0.10) / 0.57,0,1)
		var glint := sin(PI * phase)
		var anchor := [Vector2(68,26),Vector2(20,69),Vector2(77,80)]
		_star(anchor[i],(14-i*2)*glint,(23-i*3)*glint,PEARL,glint)

func _molten_reveal(t: float, fade: float) -> void:
	# The column and its ground halo share one impact, followed by drifting embers.
	var swell := sin(PI * pow(clampf(t/0.72,0,1),0.60))
	var beam_width := 2.0 + 12.0 * swell
	var bottom := Vector2(50,80)
	var left := Vector2(47-beam_width,0)
	var right := Vector2(53+beam_width,0)
	_ink.draw_colored_polygon(PackedVector2Array([left,right,bottom+Vector2(4,0),bottom-Vector2(4,0)]),Color(GOLD,0.30*swell))
	_ink.draw_colored_polygon(PackedVector2Array([Vector2(49,0),Vector2(53,0),bottom]),Color(IVORY,0.82*swell))
	# Orange-edged flame tongues rise behind the halo, framing the weapon.
	for i in 6:
		var side := -1.0 if i%2 == 0 else 1.0
		var row := floori(i/2.0)
		var x := 50.0 + side*(23.0+7.0*row)
		var foot := Vector2(x,79.0-row*2.0)
		var lift := (23.0 + 10.0*row) * swell
		var tip := foot + Vector2(side*(7.0+row*2), -lift)
		if lift > 2.0:
			_ink.draw_colored_polygon(PackedVector2Array([foot-Vector2(3,0),tip,foot+Vector2(4,0)]),Color(MOLTEN,0.78*swell))
			_ink.draw_line(foot,tip,Color(AMBER,0.92*swell),1.7)
	var ring := ease(clampf(t/0.44,0,1),0.33)
	var span := Vector2(15+30*ring,4+5*ring)
	for i in 24:
		var a := TAU * i / 24.0
		var b := a + TAU * 0.86 / 24.0
		var p := bottom + Vector2(cos(a),sin(a))*span
		var q := bottom + Vector2(cos(b),sin(b))*span
		_ink.draw_line(p,q,Color(IVORY if i%4 == 0 else GOLD,fade),3)
	for i in 12:
		var start := 0.015 * (i%5)
		var travel := clampf((t-start) / (0.83+0.06*(i%3)),0,1)
		if travel <= 0 or travel >= 1: continue
		var x := 7.0 + float((i*37)%84)
		var y := 84.0 - travel*(48.0+(i*19)%37)
		x += sin(travel * PI * 1.2 + i) * 4.0
		var ember := sin(travel*PI)
		_ink.draw_rect(Rect2(roundf(x),roundf(y),2+i%2,3+i%5),Color(GOLD if i%3 else AMBER,ember))
	var glint := sin(PI*clampf(t/0.58,0,1))
	_star(Vector2(55,32),27*glint,37*glint,IVORY,glint)
	if _tier > 3:
		var echo := sin(PI*clampf((t-0.24)/0.65,0,1))
		_star(Vector2(26,62),8*echo,16*echo,GOLD,echo)
