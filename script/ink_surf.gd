extends Node2D

const REQUIRED := 3
const COOLDOWN := 6.0
const DAMAGE := 60.0
const RADIUS := 90.0
const PULSE_SECONDS := 0.34
const SURGE_COLORS := [GamePalette.FRIENDLY_CYAN,GamePalette.FRIENDLY_BLUE,GamePalette.FRIENDLY_LIGHT]
var charge := 0
var cooldown := 0.0
var absorbed := 0
var surges := 0
var hits := 0
var _running := false
var _tracking := false
var _last_at := Vector2.ZERO
var _pulse_at := Vector2.ZERO
var _pulse_left := 0.0
var _gain_left := 0.0
var _redraw_left := 0.0
var _generation := 0
var _targets: Array[Node2D] = []
var _caption: Label
var debug_training := false
var _debug_left := 0.0
@onready var game: Node = get_parent()

func _ready() -> void:
	z_index = 11
	_caption = Label.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_to_label(_caption,9,true)
	_caption.add_theme_color_override("font_color",GamePalette.FRIENDLY_LIGHT)
	_caption.add_theme_color_override("font_outline_color",Color("172536"))
	_caption.add_theme_constant_override("outline_size",2)
	add_child(_caption)
	game.player.dash_started.connect(_on_dash_started)
	game.player.dash_completed.connect(_on_dash_completed)
	reset()

func reset() -> void:
	_running = false
	absorbed = 0
	surges = 0
	hits = 0
	debug_training = false
	clear_combat_effects()
	set_process(false)
	set_physics_process(false)

func begin_run() -> void:
	reset()
	_running = true
	set_process(true)
	set_physics_process(true)
	if game.diagnostic_mode=="normal":
		game.variety.notify("彩墨冲浪：冲刺掠过3处新鲜溅痕\n在冲刺终点释放击退震波")

func clear_combat_effects() -> void:
	_generation += 1
	charge = 0
	cooldown = 0
	_tracking = false
	_pulse_left = 0
	_gain_left = 0
	_targets.clear()
	if _caption!=null: _caption.hide()
	queue_redraw()

func enable_debug_training() -> void:
	debug_training = true
	_debug_left = 0

func _refresh_debug_ink(delta: float) -> void:
	if not debug_training or cooldown>0: return
	_debug_left -= delta
	if _debug_left>0: return
	_debug_left = 1.2
	var heading: Vector2 = game.player.last_move_direction.normalized()
	if heading.is_zero_approx(): heading = Vector2.RIGHT
	for i in REQUIRED:
		game.combat_feedback.death_stains.splat(game.player.global_position+heading*(25+i*30),preload("res://script/death_stains.gd").color_for(&"chaser"),heading)

func _active() -> bool:
	return _running and not game.player.movement_locked and game.variety._battle_active()

func _on_dash_started(at: Vector2) -> void:
	_tracking = _active() and cooldown<=0
	_last_at = at

func _sweep(at: Vector2) -> void:
	if not _tracking or charge>=REQUIRED: return
	if at.distance_squared_to(_last_at)>220.0*220.0:
		_last_at = at
		return
	var count: int = game.combat_feedback.death_stains.consume_along_segment(_last_at,at,REQUIRED-charge)
	_last_at = at
	if count<=0: return
	charge += count
	absorbed += count
	_gain_left = 0.22
	AudioManager.play_juice("ready" if charge==REQUIRED else "dash")
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if not _active():
		_tracking = false
		return
	if _tracking and game.player.dashing: _sweep(game.player.global_position)

func _on_dash_completed(at: Vector2) -> void:
	if not _tracking or not _active(): return
	_sweep(at)
	_tracking = false
	if charge<REQUIRED or cooldown>0: return
	# Set the gate before damage. Kills create ink but cannot recursively fuel this surge.
	charge = 0
	cooldown = COOLDOWN
	surges += 1
	_pulse_at = at
	_pulse_left = PULSE_SECONDS
	_targets.clear()
	CombatTargets.fill_in_radius(at,RADIUS*RADIUS,game,_targets)
	var generation := _generation
	for actor in _targets:
		if not is_instance_valid(actor) or actor.is_queued_for_deletion(): continue
		if actor.has_method("vulnerable") and not actor.vulnerable(): continue
		var direction: Vector2 = (actor.global_position-at).normalized()
		actor.apply_hit({"damage":DAMAGE,"direction":direction,"effect":"ink_surf","from_status":true,"source":self})
		if generation!=_generation: return
		if is_instance_valid(actor) and actor.has_method("apply_blast_impulse"):
			actor.apply_blast_impulse(direction*200.0,0.18)
		hits += 1
	_targets.clear()
	game.combat_feedback.spray(at,Vector2.ZERO,GamePalette.FRIENDLY_CYAN,8,65)
	AudioManager.play_juice("kill")
	RunDiagnostics.mark("ink_surf",{"surges":surges,"absorbed":absorbed})
	queue_redraw()

func _process(delta: float) -> void:
	if not _running or get_tree().paused: return
	if not _active():
		_caption.hide()
		return
	_refresh_debug_ink(delta)
	cooldown = maxf(0,cooldown-delta)
	_pulse_left = maxf(0,_pulse_left-delta)
	_gain_left = maxf(0,_gain_left-delta)
	_redraw_left -= delta
	if _redraw_left<=0:
		_redraw_left = 1.0/30.0
		_caption.position = to_local(game.player.global_position)+Vector2(-50,32)
		_caption.size = Vector2(100,14)
		_caption.text = "彩墨冷却" if cooldown>0 else "彩墨 %d/3" % charge
		_caption.visible = charge>0 or _tracking or cooldown>0
		queue_redraw()

func _draw() -> void:
	if not is_node_ready() or not _active(): return
	var player_at := to_local(game.player.global_position)
	if charge>0 or _tracking or cooldown>0:
		for i in REQUIRED:
			var tint := GamePalette.FRIENDLY_CYAN if i<charge else Color("233845")
			var size := 2.8+_gain_left*5 if i<charge else 2.8
			var center := player_at+Vector2((i-1)*9,27)
			draw_rect(Rect2(center-Vector2.ONE*(size+1),Vector2.ONE*(size+1)*2),Color("111c29"))
			draw_rect(Rect2(center-Vector2.ONE*size,Vector2.ONE*size*2),tint)
		if cooldown>0:
			draw_line(player_at+Vector2(-14,48),player_at+Vector2(14,48),Color("162532"),2)
			draw_line(player_at+Vector2(-14,48),player_at+Vector2(-14+28*(1-cooldown/COOLDOWN),48),GamePalette.FRIENDLY_CYAN,2)
	if _pulse_left>0:
		var t := 1-_pulse_left/PULSE_SECONDS
		var at := to_local(_pulse_at)
		for i in 3:
			var tint: Color = SURGE_COLORS[i]
			tint.a = (1-t)*0.8
			draw_arc(at,RADIUS*(0.25+0.75*t),i*TAU/3.0,i*TAU/3.0+1.8,18,tint,2.5,false)
