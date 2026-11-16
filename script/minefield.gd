extends Node2D
# One fixed nine-slot array, shared actor snapshot; no proximity Areas or particle nodes.
const COUNT := 9
const GAP := 96.0
const TOUCH := 16.0
const RADIUS := 44.0
const FUSE := 0.16
const RESPAWN := 3.0
const ARM := 1.0
const FOOT := Vector2(0,12)
const MAX_ACTORS := 512
var mines: Array[Dictionary] = []
var _clock := 0.0
var _stage := -1
var _running := false
var _scan_left := 0.0
var _player_at := Vector2.ZERO
var _previous: Dictionary = {}
var _targets: Array[Node2D] = []
var _positions := PackedVector2Array()
var _pushed: Dictionary = {}
var _audio: AudioStreamPlayer
var detonations := 0
var hits := 0
var _bounds := Rect2()
@onready var weather: Node = get_parent()
@onready var game: Node = weather.get_parent()

func _ready() -> void:
	z_index = -6
	_audio = AudioStreamPlayer.new()
	AudioManager.configure_sfx(_audio)
	_audio.stream = preload("res://assest/sounds/bomb_burst.wav")
	_audio.volume_db = -18
	_audio.max_polyphony = 1
	add_child(_audio)
	stop()

func reset_run() -> void:
	stop()
	mines.clear()
	_stage = -1
	detonations = 0
	hits = 0

func stop() -> void:
	for reference in _pushed.values():
		var actor = reference.get_ref()
		if is_instance_valid(actor): actor.terrain_impulse.clear()
	_pushed.clear()
	_running = false
	_clock = 0
	_previous.clear()
	_targets.clear()
	_positions.clear()
	_scan_left = 0
	for mine in mines:
		mine.fuse = -1.0
		mine.ready = ARM
		mine.blast = -1.0
	if _audio!=null: _audio.stop()
	hide()
	queue_redraw()

func player_damage() -> float: return 24.0+3.0*maxi(0,weather.stage-1)
func enemy_damage() -> float: return player_damage()*3.0

func _layout() -> void:
	var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse()*get_viewport().get_visible_rect()
	var center := view.get_center()
	# The array remains central, but the opening position sits between rows/columns.
	var p: Vector2 = game.player.global_position+FOOT
	for y in range(-1,2):
		for x in range(-1,2):
			if (center+Vector2(x,y)*GAP).distance_to(p)<TOUCH+20:
				center += Vector2(GAP*0.5,GAP*0.5)
	mines.clear()
	for y in range(-1,2):
		for x in range(-1,2):
			mines.append({"at":center+Vector2(x,y)*GAP,"ready":_clock+ARM,"fuse":-1.0,"blast":-1.0})
	_bounds = Rect2(center-Vector2.ONE*(GAP+80),Vector2.ONE*(GAP+80)*2)
	_previous.clear()

func _touch(before: Vector2, after: Vector2, point: Vector2) -> bool:
	if before.distance_squared_to(after)>300*300: before = after
	return Geometry2D.get_closest_point_to_segment(point,before,after).distance_squared_to(point)<=TOUCH*TOUCH

func _trigger(index: int) -> void:
	var mine := mines[index]
	if _clock<float(mine.ready) or float(mine.fuse)>=0: return
	mine.fuse = _clock+FUSE
	mine.ready = _clock+RESPAWN # Measured from trigger, not from end of the blast animation.

func _snapshot() -> void:
	_targets.clear()
	_positions.clear()
	CombatTargets.fill_in_bounds(_bounds,game,_targets)
	if _targets.size()>MAX_ACTORS: _targets.resize(MAX_ACTORS)
	for actor in _targets: _positions.append(actor.global_position+FOOT)

func _trigger_contacts() -> void:
	var next: Dictionary = {}
	for i in _targets.size():
		var id := _targets[i].get_instance_id()
		var at := _positions[i]
		var before: Vector2 = _previous.get(id,at)
		next[id] = at
		for index in mines.size():
			if _touch(before,at,mines[index].at): _trigger(index)
	_previous = next

func _blast_batch(indices: Array[int]) -> void:
	# Freeze every hit target before any death/reward callbacks; no explosion-to-mine chain.
	var batch: Array[Dictionary] = []
	for index in indices:
		mines[index].fuse = -1.0
		mines[index].blast = _clock+0.36
		detonations += 1
	for i in _targets.size():
		for index in indices:
			var offset: Vector2 = _positions[i]-mines[index].at
			if offset.length_squared()>RADIUS*RADIUS: continue
			batch.append({"actor":_targets[i],"direction":offset.normalized() if not offset.is_zero_approx() else Vector2.UP})
			break # At most one hit/impulse for simultaneous overlapping blasts.
	_audio.play()
	var p: Node = game.player
	if p.player_health>0 and not p.movement_locked and not p.is_dash_invulnerable() and not p.arsenal_shield_active and p.hurt_lock<=0:
		for index in indices:
			var offset: Vector2 = p.global_position+FOOT-mines[index].at
			if offset.length_squared()>RADIUS*RADIUS: continue
			p.receive_attack(player_damage())
			if p.player_health>0:
				p.apply_terrain_impulse((offset.normalized() if not offset.is_zero_approx() else Vector2.UP)*260)
				_pushed[p.get_instance_id()] = weakref(p)
			break
	for hit in batch:
		if not weather.surface.active(): return
		var actor: Node2D = hit.actor
		if not is_instance_valid(actor) or actor.is_queued_for_deletion(): continue
		actor.apply_hit({"damage":enemy_damage(),"direction":hit.direction,"effect":"landmine","from_status":true,"damage_is_final":true,"source":self})
		hits += 1
		if not weather.surface.active(): return
		if is_instance_valid(actor) and actor.has_method("apply_terrain_impulse"):
			actor.apply_terrain_impulse(hit.direction*360)
			_pushed[actor.get_instance_id()] = weakref(actor)

func _physics_process(delta: float) -> void:
	if get_tree().paused: return
	if not weather.surface.active():
		if _running: stop()
		return
	if not _running or _stage!=weather.stage:
		stop()
		_running = true
		if mines.is_empty() or _stage!=weather.stage: _layout()
		_stage = weather.stage
		_player_at = game.player.global_position+FOOT
		show()
	_clock += maxf(delta,0)
	var p: Vector2 = game.player.global_position+FOOT
	var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse()*get_viewport().get_visible_rect()
	if p.distance_to(_bounds.get_center())>650 and not view.grow(100).intersects(_bounds): _layout()
	var due: Array[int] = []
	for i in mines.size():
		if float(mines[i].fuse)>=0 and _clock>=float(mines[i].fuse): due.append(i)
		if _touch(_player_at,p,mines[i].at): _trigger(i)
	_player_at = p
	_scan_left -= delta
	if _scan_left<=0 or not due.is_empty():
		_scan_left = 0.1
		_snapshot()
		_trigger_contacts()
		if not due.is_empty(): _blast_batch(due)
	for id in _pushed.keys():
		var actor = _pushed[id].get_ref()
		if not is_instance_valid(actor) or actor.terrain_impulse.left<=0: _pushed.erase(id)
	queue_redraw()

func _draw() -> void:
	if not _running: return
	for i in mines.size():
		var mine := mines[i]
		var at: Vector2 = mine.at
		var armed := _clock>=float(mine.ready)
		var fuse := float(mine.fuse)>=0
		var reform := not armed and not fuse and float(mine.ready)-_clock<0.55
		var alpha := 1.0 if armed or fuse else (0.55 if reform else 0.18)
		draw_set_transform(at+Vector2(0,5),0,Vector2(1,0.45))
		draw_circle(Vector2.ZERO,17,GamePalette.shadow(0.45*alpha))
		draw_set_transform(at,0,Vector2(1,0.68))
		draw_circle(Vector2.ZERO,15,Color(GamePalette.INK,alpha))
		draw_circle(Vector2(0,-2),13,Color(GamePalette.UI_GREY_DARK,alpha))
		draw_arc(Vector2(0,-2),12,0,TAU,24,Color(GamePalette.UI_GREY_BORDER,alpha),1.8)
		var sheen := _clock*0.7+i*0.65
		draw_arc(Vector2(0,-2),10,sheen,sheen+1.4,9,Color(GamePalette.UI_GREY_ACTIVE,alpha*0.9),2.0)
		draw_line(Vector2(-8,-4),Vector2(6,-7),Color(GamePalette.UI_GREY_ACTIVE,alpha*0.4),1)
		for j in 4:
			var bolt := Vector2.from_angle(PI*0.25+j*PI*0.5)*9
			draw_circle(bolt,1.3,Color(GamePalette.UI_GREY_ACTIVE,alpha))
		draw_set_transform(Vector2.ZERO)
		if armed or fuse or reform:
			var blink := 0.45+0.55*(0.5+0.5*sin(_clock*(36 if fuse else 9)+i*0.4))
			draw_circle(at+Vector2(0,-3),5,Color(GamePalette.ENEMY_RED,blink*0.28))
			draw_circle(at+Vector2(0,-3),2.8,Color(GamePalette.ENEMY_RED,blink))
			draw_circle(at+Vector2(-0.7,-3.8),0.8,Color(GamePalette.HIT_FLASH_WHITE,blink*0.7))
		if fuse:
			draw_circle(at,RADIUS,Color(GamePalette.ENEMY_RED,0.1))
			draw_arc(at,RADIUS,0,TAU,32,Color(GamePalette.ENEMY_ORANGE,0.8),1.5)
		var left := float(mine.blast)-_clock
		if left>0:
			var progress := 1-left/0.36
			var radius := lerpf(8,RADIUS,1-pow(1-progress,3))
			if progress<0.25: draw_circle(at,radius*0.65,Color(GamePalette.HIT_FLASH_WHITE,left))
			draw_arc(at,radius,0,TAU,32,Color(GamePalette.ENEMY_ORANGE,left/0.36),2.5)
			for j in 8:
				var dir := Vector2.from_angle(j*TAU/8+i*0.3)
				draw_line(at+dir*radius*0.55,at+dir*radius,Color(GamePalette.HIT_FLASH_WHITE,left/0.36),1.5)
