extends Node2D
## One portal pair, one courier and one bounded electrical discharge.
const IDS := ["portal_gun", "errand_box", "micro_cell"]
const GATE := preload("res://rogge_art/combat-fx/dimension/gate.png")
const HELPER := preload("res://rogge_art/combat-fx/dimension/assistant.png")
const CELL := preload("res://rogge_art/combat-fx/dimension/micro_cell.png")
const YELLOW := Color("#fff36a")
const AQUA := Color("#88e2fa")
@onready var game: Node = get_parent()
var profiles := {}
var gate_cd := 0.0
var box_cd := 0.0
var charge := 0.0
var last_position := Vector2.INF
var entry := Vector2.ZERO
var outlet := Vector2.ZERO
var heading := Vector2.RIGHT
var gate_left := 0.0
var scan_left := 0.0
var tickets := 0
var sent := {}
var flights: Array[Dictionary] = []
var worker: Node2D
var working := false
var powered := false
var elapsed := 0.0
var worker_at := Vector2.ZERO
var departure := Vector2.ZERO
var worker_exit := Vector2.ZERO
var landed := false
var beat := 0.0
var spark_left := 0.0
var arcs: Array[PackedVector2Array] = []
var cancellations := 0
var gate_sound := AudioStreamPlayer.new()
var receipt_sound := AudioStreamPlayer.new()

static func stats_for(id: String, rank: int) -> Dictionary:
	var step := clampi(rank,1,5)-1
	match id:
		"portal_gun": return {"damage":16.0+4*step,"interval":5.2-0.48*step,"count":1+floori(step/2.0)}
		"errand_box": return {"damage":22.0+6*step,"interval":4.2-0.43*step}
	return {"damage":18.0+5*step,"range":240.0-26*step,"count":1+floori(step/2.0)}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 4
	gate_sound.stream = preload("res://rogge_art/combat-fx/dimension/wormhole.wav")
	receipt_sound.stream = preload("res://rogge_art/combat-fx/dimension/receipt.wav")
	for sound in [gate_sound,receipt_sound]:
		AudioManager.configure_sfx(sound)
		sound.volume_db = -15
		add_child(sound)
	set_physics_process(false)

func set_forged_stats(id: String, count: int, stats: Dictionary) -> void:
	if count > 0:
		profiles[id] = stats
	else:
		profiles.erase(id)
		if id == "portal_gun":
			gate_left = 0
			flights.clear()
		if id == "errand_box" or powered: working = false
		if id == "micro_cell":
			charge = 0
			arcs.clear()
	if profiles.is_empty(): clear_combat_effects()
	set_physics_process(not profiles.is_empty())
	queue_redraw()

func reset() -> void:
	profiles.clear()
	clear_combat_effects()
	set_physics_process(false)

func clear_combat_effects() -> void:
	cancellations += 1
	gate_sound.stop()
	receipt_sound.stop()
	gate_cd = 0.25
	box_cd = 0.55
	gate_left = 0
	working = false
	worker = null
	powered = false
	flights.clear()
	sent.clear()
	tickets = 0
	arcs.clear()
	spark_left = 0
	charge = 0
	last_position = Vector2.INF
	queue_redraw()

func _live(actor) -> bool:
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.is_in_group("EnemyGroup") and actor.has_method("apply_hit") and (not actor.has_method("vulnerable") or actor.vulnerable())

func _nearest(at: Vector2, reach: float, excluded := {}) -> Node2D:
	var best: Node2D
	var best_distance := INF
	for actor in CombatTargets.in_radius(at,reach*reach,game):
		if excluded.has(actor) or not _live(actor): continue
		var distance := at.distance_squared_to(actor.global_position)
		if distance < best_distance:
			best = actor
			best_distance = distance
	return best

func _hit(actor, damage: float, direction: Vector2) -> void:
	if _live(actor):
		actor.apply_hit({"damage":damage,"direction":direction,"source":self})

func _open(origin: Vector2, nearest: Node2D) -> void:
	heading = origin.direction_to(nearest.global_position)
	if heading.is_zero_approx(): heading = Vector2.RIGHT
	entry = origin + heading * minf(40, origin.distance_to(nearest.global_position))
	var others := {nearest:true}
	var destination := _nearest(entry,290,others)
	var center := destination.global_position if destination else entry + heading * 88
	outlet = center - heading * 28
	if entry.distance_to(outlet) < 50: outlet = center + heading * 70
	heading = outlet.direction_to(center)
	if heading.is_zero_approx(): heading = Vector2.RIGHT
	tickets = int(profiles.portal_gun.count)
	sent.clear()
	gate_sound.play()
	gate_left = 1.8
	scan_left = 0

func _scan_gate() -> void:
	for actor in CombatTargets.in_radius(entry,32*32,game):
		if not _live(actor) or sent.has(actor.get_instance_id()): continue
		sent[actor.get_instance_id()] = true
		tickets -= 1
		var damage: float = profiles.portal_gun.damage
		if actor.has_method("travel_through_portal") and actor.travel_through_portal(outlet,heading):
			flights.append({"body":actor,"left":0.29,"damage":damage,"previous":actor.global_position})
		_hit(actor,damage,heading)
		if tickets <= 0 or not game.variety._battle_active(): break

func _tick_flights(dt: float) -> void:
	for i in range(flights.size()-1,-1,-1):
		var trip := flights[i]
		var actor: Node2D = trip.body if is_instance_valid(trip.body) else null
		if not _live(actor):
			flights.remove_at(i)
			continue
		trip.left -= dt
		var start: Vector2 = trip.previous
		var finish := actor.global_position
		trip.previous = finish
		var center := (start+finish)*0.5
		var radius := 21.0+start.distance_to(finish)*0.5
		for other in CombatTargets.in_radius(center,radius*radius,game):
			if other == actor or not _live(other): continue
			var closest := finish if start.is_equal_approx(finish) else Geometry2D.get_closest_point_to_segment(other.global_position,start,finish)
			if closest.distance_squared_to(other.global_position)>441: continue
			flights.remove_at(i)
			_hit(other,trip.damage,actor.global_position.direction_to(other.global_position))
			if not game.variety._battle_active() or flights.is_empty(): return
			break
		if i < flights.size() and is_same(trip,flights[i]) and trip.left <= 0: flights.remove_at(i)

func _dispatch(target: Node2D, express: bool) -> void:
	working = true
	landed = false
	powered = express
	elapsed = 0
	worker = target
	departure = game.player.global_position
	worker_at = departure
	if powered:
		if gate_left <= 0:
			_open(departure,target)
			gate_cd = profiles.portal_gun.interval
		gate_left = maxf(0.95,gate_left)
		worker_exit = outlet
		charge = 0
	box_cd = profiles.errand_box.interval

func _arc(from: Vector2, to: Vector2) -> void:
	var side := from.direction_to(to).orthogonal()*6
	arcs.append(PackedVector2Array([from,from.lerp(to,0.29)+side,from.lerp(to,0.57)-side,to]))
	spark_left = 0.24

func _zap(origin: Vector2, first: Node2D, burst: bool) -> void:
	var epoch := cancellations
	arcs.clear()
	var stats: Dictionary = profiles.micro_cell
	var used := {}
	var targets: Array[Node2D] = []
	if burst:
		targets = CombatTargets.in_radius(origin,98*98,game)
		targets.erase(first)
		targets.push_front(first)
	var target := first
	var at := origin
	for i in (mini(targets.size(),8) if burst else int(stats.count)):
		if burst: target = targets[i]
		if not _live(target): continue
		var pos := target.global_position
		_arc(origin + Vector2(0,-15) if burst else at,pos)
		used[target] = true
		_hit(target,stats.damage*(1.5 if burst else 1.0),at.direction_to(pos))
		if epoch != cancellations or not game.variety._battle_active(): return
		at = pos
		if not burst and i+1 < int(stats.count):
			target = _nearest(pos,105,used)
			if target == null: break

func _tick_worker(dt: float) -> void:
	elapsed += dt
	if landed:
		if elapsed > 1.18: working = false
		return
	if not _live(worker):
		worker = _nearest(worker_at,300)
		if worker == null:
			if powered and profiles.has("micro_cell"): charge = 1
			working = false
			return
	var dest := worker.global_position
	if powered:
		if elapsed < 0.25:
			worker_at = departure.lerp(entry,elapsed/0.25)
		else:
			worker_at = worker_exit.lerp(dest,clampf((elapsed-0.25)/0.5,0,1))
	else:
		worker_at = worker_at.move_toward(dest,dt*460)
	if (powered and elapsed >= 0.75) or (not powered and worker_at.distance_to(dest)<12):
		var epoch := cancellations
		worker_at = dest
		landed = true
		elapsed = 0.76
		receipt_sound.pitch_scale = 1.0 if powered else 1.2
		receipt_sound.play()
		if powered: _zap(dest,worker,true)
		if epoch == cancellations and game.variety._battle_active(): _hit(worker,profiles.errand_box.damage,departure.direction_to(dest))

func _physics_process(dt: float) -> void:
	if not game.variety._battle_active():
		if last_position != Vector2.INF: clear_combat_effects()
		return
	var origin: Vector2 = game.player.global_position
	beat = fmod(beat+dt,60)
	if profiles.has("micro_cell") and last_position != Vector2.INF:
		charge = minf(1,charge+minf(last_position.distance_to(origin),1200*dt)/float(profiles.micro_cell.range))
	last_position = origin
	gate_cd -= dt
	box_cd -= dt
	gate_left = maxf(0,gate_left-dt)
	spark_left = maxf(0,spark_left-dt)
	if not flights.is_empty(): _tick_flights(dt)
	if not game.variety._battle_active(): return
	if profiles.has("portal_gun") and gate_cd <= 0 and not (working and powered and not landed):
		var near := _nearest(origin,230)
		gate_cd = profiles.portal_gun.interval if near else 0.22
		if near: _open(origin,near)
	if gate_left > 0 and tickets > 0:
		scan_left -= dt
		if scan_left <= 0:
			scan_left = 0.10
			_scan_gate()
	if not game.variety._battle_active(): return
	var express: bool = game.equipment_panel.dimension_active and charge >= 1
	if working: _tick_worker(dt)
	elif profiles.has("errand_box") and box_cd <= 0:
		var target := _nearest(origin,305)
		if target: _dispatch(target,express)
		else: box_cd = 0.22
	if charge >= 1 and not game.equipment_panel.dimension_active and profiles.has("micro_cell") and scan_zap_due(dt):
		var target := _nearest(origin,185)
		if target:
			charge = 0
			_zap(origin,target,false)
	queue_redraw()

var zap_scan := 0.0
func scan_zap_due(dt: float) -> bool:
	zap_scan -= dt
	if zap_scan > 0: return false
	zap_scan = 0.15
	return true

func _draw() -> void:
	if last_position == Vector2.INF: return
	if gate_left > 0:
		var frame := int(beat*12)%6
		var scale_y := minf(1,gate_left/0.2)
		for at in [entry,outlet]:
			var size := Vector2(31,47)*Vector2(1,scale_y)
			draw_texture_rect_region(GATE,Rect2(at-size*0.5,size),Rect2(frame*48,0,48,54))
	if profiles.has("micro_cell"):
		var pos := last_position + Vector2(15,-7)
		draw_texture_rect(CELL,Rect2(pos,Vector2(14,14)),false)
		draw_rect(Rect2(pos+Vector2(2,14),Vector2(11,3)),Color("#1c2637"))
		draw_rect(Rect2(pos+Vector2(3,15),Vector2(roundf(9*charge),1)),YELLOW)
	if working:
		if _live(worker) and not landed:
			var p := worker.global_position + Vector2(0,-32)
			draw_rect(Rect2(p-Vector2(2,5),Vector2(4,7)),YELLOW)
			draw_rect(Rect2(p+Vector2(-2,4),Vector2(4,2)),YELLOW)
		var frame := 3 if landed else (2 if powered else int(beat*9)%2)
		var hop := 0.0 if landed else absf(sin(elapsed*12))*6
		var feet := worker_at-Vector2(0,hop)
		draw_texture_rect_region(HELPER,Rect2(feet-Vector2(12,29),Vector2(26,31)),Rect2(frame*22,0,22,26))
		if powered and not landed: draw_texture_rect(CELL,Rect2(feet-Vector2(-2,17),Vector2(15,15)),false)
	if working and powered and landed:
		var t := clampf((elapsed-0.76)/0.42,0,1)
		draw_arc(worker_at,16+82*t,0,TAU,28,Color(YELLOW,0.68*(1-t)),2,false)
		draw_texture_rect(CELL,Rect2(worker_at-Vector2(9,16),Vector2(18,18)),false)
	if spark_left > 0:
		for arc in arcs:
			draw_polyline(arc,Color(AQUA,spark_left*2.4),5)
			draw_polyline(arc,Color(YELLOW,minf(1,spark_left*8)),2)
