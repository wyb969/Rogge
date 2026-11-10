extends Node2D

const ARC := preload("res://script/arc_motion.gd")
const MAX_ATTACKS := 12
const CAPS := {&"cleave":3,&"boomerang":4,&"mortar":3}
const SLASH_RADIUS := 84.0
const SLASH_HALF_ANGLE := 0.72
const MORTAR_RADIUS := 44.0
const BLADE_SPEED := 145.0
const BLADE_RADIUS := 12.0
const DANGER := GamePalette.ENEMY_RED
const EDGE := GamePalette.TELEGRAPH_EDGE
const INK := GamePalette.INK
class Slot:
	extends RefCounted
	var active := false
	var source: WeakRef
	var source_id := 0
	var kind: StringName
	var origin := Vector2.ZERO
	var target := Vector2.ZERO
	var heading := Vector2.RIGHT
	var age := 0.0
	var previous_age := 0.0
	var windup := 0.75
	var duration := 1.0
	var leg := 1.2
	var damage := 0.0
	var hit := false
	var released := false
var slots: Array[Slot] = []
var casts := 0
var cancelled := 0
var attempted_hits := 0
var _running := false
var _generation := 0
var _sector := PackedVector2Array()
var _border := PackedVector2Array()
var _blade := PackedVector2Array([Vector2(-9,-7),Vector2(1,-4),Vector2(10,-8),Vector2(6,2),Vector2(-1,7),Vector2(-4,0)])
var _warn_audio: AudioStreamPlayer
var _impact_audio: AudioStreamPlayer
var _last_warning := -1000
@onready var game: Node = get_parent()

func _ready() -> void:
	z_index = 7
	for _i in MAX_ATTACKS: slots.append(Slot.new())
	_sector.append(Vector2.ZERO)
	for i in 19: _sector.append(Vector2.from_angle(lerpf(-SLASH_HALF_ANGLE,SLASH_HALF_ANGLE,float(i)/18.0))*SLASH_RADIUS)
	_border = _sector.duplicate()
	_border.append(Vector2.ZERO)
	_warn_audio = AudioStreamPlayer.new()
	_warn_audio.stream = preload("res://assest/sounds/trial_lock.wav")
	_warn_audio.volume_db = -24
	AudioManager.configure_sfx(_warn_audio)
	add_child(_warn_audio)
	_impact_audio = AudioStreamPlayer.new()
	_impact_audio.stream = preload("res://assest/sounds/bomb_burst.wav")
	_impact_audio.volume_db = -24
	AudioManager.configure_sfx(_impact_audio)
	add_child(_impact_audio)
	reset()

func reset() -> void:
	_running = false
	casts = 0
	cancelled = 0
	attempted_hits = 0
	clear_combat_effects()

func begin_run() -> void:
	reset()
	_running = true

func clear_combat_effects() -> void:
	_generation += 1
	for slot in slots:
		slot.active = false
		slot.source = null
	if _warn_audio!=null: _warn_audio.stop()
	if _impact_audio!=null: _impact_audio.stop()
	set_physics_process(false)
	set_process(false)
	queue_redraw()

func cast(actor: Node2D, kind: StringName) -> Slot:
	if not _running or not CAPS.has(kind) or not game.variety._battle_active() or not _source_ready(actor): return null
	var used := 0
	var free: Slot
	for slot in slots:
		if slot.active and slot.source_id==actor.get_instance_id(): return null
		if slot.active and slot.kind==kind: used += 1
		if not slot.active and free==null: free = slot
	if free==null or used>=int(CAPS[kind]): return null
	var direction: Vector2 = game.player.global_position-actor.global_position
	if direction.is_zero_approx(): direction = Vector2.RIGHT
	free.active = true
	free.source = weakref(actor)
	free.source_id = actor.get_instance_id()
	free.kind = kind
	free.origin = actor.global_position
	free.heading = direction.normalized()
	free.target = game.player.global_position
	if kind==&"boomerang": free.target = free.origin+free.heading*clampf(direction.length()+45.0,140.0,210.0)
	free.leg = free.origin.distance_to(free.target)/BLADE_SPEED
	free.windup = 1.1 if kind==&"mortar" else 0.75
	free.duration = free.windup+(free.leg*2 if kind==&"boomerang" else 0.18)
	free.age = 0
	free.previous_age = 0
	free.damage = actor.projectile_damage
	free.hit = false
	free.released = false
	casts += 1
	var now := Time.get_ticks_msec()
	if now-_last_warning>160:
		_last_warning = now
		_warn_audio.play()
	set_physics_process(true)
	set_process(true)
	queue_redraw()
	return free

func _source_ready(actor: Node2D) -> bool:
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and not actor._death_started and not actor.is_frozen() and actor._airflow_left<=0 and actor._blast_left<=0

func cancel(slot: Slot, owner_actor: Node2D) -> void:
	if slot.active and slot.source_id==owner_actor.get_instance_id():
		slot.active = false
		slot.source = null
		cancelled += 1
		queue_redraw()

static func blade_position(slot: Slot, age: float) -> Vector2:
	var t := clampf((age-slot.windup)/maxf(slot.leg,0.001),0,2)
	return slot.origin.lerp(slot.target,t if t<=1 else 2-t)

static func _near_segment(point: Vector2, a: Vector2, b: Vector2) -> bool:
	return point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point,a,b))<=BLADE_RADIUS*BLADE_RADIUS

static func hits_point(slot: Slot, point: Vector2, before: float, after: float) -> bool:
	if after<slot.windup or before>slot.duration: return false
	if slot.kind==&"cleave":
		var offset := point-slot.origin
		var d := offset.length()
		return d<=SLASH_RADIUS and (d<0.001 or offset.dot(slot.heading)>=d*cos(SLASH_HALF_ANGLE))
	if slot.kind==&"mortar": return point.distance_squared_to(slot.target)<=MORTAR_RADIUS*MORTAR_RADIUS
	var a := blade_position(slot,before)
	var b := blade_position(slot,after)
	if before<slot.windup+slot.leg and after>=slot.windup+slot.leg:
		return _near_segment(point,a,slot.target) or _near_segment(point,slot.target,b)
	return _near_segment(point,a,b)

func _physics_process(delta: float) -> void:
	if get_tree().paused or not _running or not game.variety._battle_active(): return
	var active := false
	var generation := _generation
	for slot in slots:
		if not slot.active: continue
		var actor: Node2D = slot.source.get_ref() if slot.source!=null else null
		if not _source_ready(actor) or actor.global_position.distance_squared_to(slot.origin)>18.0*18.0:
			slot.active = false
			slot.source = null
			cancelled += 1
			continue
		var before := slot.age
		slot.previous_age = before
		slot.age = minf(slot.duration,slot.age+maxf(delta,0))
		if slot.age>=slot.windup and not slot.released:
			slot.released = true
			if slot.kind==&"mortar": _impact_audio.play()
			else: AudioManager.play_juice("dash")
		if not slot.hit and hits_point(slot,game.player.global_position,before,slot.age):
			slot.hit = true
			attempted_hits += 1
			game.player.receive_attack(slot.damage,actor)
			if generation!=_generation: return
		if slot.age>=slot.duration:
			slot.active = false
			slot.source = null
		else: active = true
	queue_redraw()
	if not active:
		set_physics_process(false)
		set_process(false)

func _process(_delta: float) -> void:
	if not get_tree().paused: queue_redraw()

func _draw() -> void:
	for slot in slots:
		if not slot.active: continue
		var age := ARC.render_age(slot.previous_age,slot.age)
		var warning := slot.age<slot.windup
		var progress := clampf(age/slot.windup,0,1)
		if slot.kind==&"cleave":
			draw_set_transform(to_local(slot.origin),slot.heading.angle())
			var fill_alpha := 0.36+0.14*progress if warning else 0.52
			draw_colored_polygon(_sector,Color(GamePalette.TELEGRAPH_FILL,fill_alpha))
			draw_polyline(_border,INK,4.0,false)
			draw_arc(Vector2.ZERO,SLASH_RADIUS,-SLASH_HALF_ANGLE,SLASH_HALF_ANGLE,18,Color(EDGE,0.35),7.0,false)
			draw_polyline(_border,EDGE,2.4,false)
			if warning: draw_arc(Vector2.ZERO,SLASH_RADIUS*progress,-SLASH_HALF_ANGLE,SLASH_HALF_ANGLE,18,Color(EDGE,0.9),2.2,false)
			else:
				var swing := (maxf(age,slot.windup)-slot.windup)/0.18
				draw_arc(Vector2.ZERO,SLASH_RADIUS*0.85,-SLASH_HALF_ANGLE+1.15*swing-0.35,-SLASH_HALF_ANGLE+1.15*swing+0.4,12,Color(EDGE,0.95),5,false)
			draw_set_transform(Vector2.ZERO)
		elif slot.kind==&"boomerang":
			if warning:
				draw_line(to_local(slot.origin),to_local(slot.target),INK,5,false)
				draw_line(to_local(slot.origin),to_local(slot.target),Color(EDGE,0.55+0.4*progress),2.4,false)
				draw_circle(to_local(slot.target),5,DANGER,false,1.5,false)
			else:
				var at := to_local(blade_position(slot,maxf(age,slot.windup)))
				draw_set_transform(at,(maxf(age,slot.windup)-slot.windup)*14)
				draw_colored_polygon(_blade,INK)
				draw_set_transform(at,(maxf(age,slot.windup)-slot.windup)*14,Vector2.ONE*0.72)
				draw_colored_polygon(_blade,DANGER)
				draw_line(Vector2(-3,-2),Vector2(4,1),Color(EDGE,0.95),2,false)
				draw_set_transform(Vector2.ZERO)
		else:
			var at := to_local(slot.target)
			draw_circle(at,MORTAR_RADIUS,Color(GamePalette.TELEGRAPH_FILL,0.28+0.16*progress if warning else 0.46))
			draw_arc(at,MORTAR_RADIUS,0,TAU,32,Color(EDGE,0.28),6,false)
			draw_arc(at,MORTAR_RADIUS,0,TAU,32,INK,3,false)
			draw_arc(at,MORTAR_RADIUS,0,TAU,32,EDGE,1.8,false)
			if warning:
				draw_arc(at,MORTAR_RADIUS*progress,0,TAU,24,Color(EDGE,0.85),1.6,false)
				var seed_at := to_local(ARC.position_at(slot.origin,slot.target,age-0.25,0.85,45.0))
				draw_circle(seed_at,6,INK)
				draw_circle(seed_at,4,EDGE)
			else:
				var burst := (maxf(age,slot.windup)-slot.windup)/0.18
				draw_arc(at,MORTAR_RADIUS*(0.3+0.7*burst),0,TAU,24,Color(EDGE,1-burst),4,false)
				for i in 6:
					var dir := Vector2.from_angle(i*TAU/6)
					draw_line(at+dir*10,at+dir*(15+20*burst),Color(DANGER,1-burst),2,false)
