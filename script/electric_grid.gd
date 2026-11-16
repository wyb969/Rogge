extends Node2D
# Four world-fixed zones; recycle only distant offscreen slots while exploring.
const PERIOD := 0.5
const WARNING := 0.75
const LIVE := 0.32
const CHAIN_RADIUS := 42.0
const MAX_ACTORS := 512
const MAX_ZAPS := 64
const MAX_LINKS := 128
const FOOT := Vector2(0,12)
const ZONE_COUNT := 4
const ESCAPE_GRACE := 0.5
const STUN_SECONDS := 1.0
const ZAP_VISUAL := preload("res://script/electric_zap_visual.gd")
var zones: Array[Dictionary] = []
var _explore_at := Vector2.ZERO
var _zap_visual := ZAP_VISUAL.new()
var _rng := RandomNumberGenerator.new()
var _stage := -1
var _running := false
var _clock := 0.0
var _cycle := -1
var _scan_left := 0.0
var _player_ready := 0.0
var _player_hit := false
var _player_at := Vector2.ZERO
var _hit_ids: Dictionary = {}
var _previous: Dictionary = {}
var _ready_ids: Dictionary = {}
var _stunned: Dictionary = {}
var _targets: Array[Node2D] = []
var _zaps: Array[Dictionary] = []
var _links: Array[Dictionary] = []
var _overlay: ZapOverlay
var _arc := PackedVector2Array()
var _audio: AudioStreamPlayer
var _audio_ready := 0.0
var audio_events := 0
var scans := 0
var last_batch := 0
@onready var weather: Node = get_parent()
@onready var game: Node = weather.get_parent()

class ZapOverlay extends Node2D:
	var grid: Node2D
	func _draw() -> void: grid.draw_zaps(self)

func _ready() -> void:
	z_index = -7
	_audio = AudioStreamPlayer.new()
	AudioManager.configure_sfx(_audio)
	_audio.stream = preload("res://assest/sounds/terrain_electric.wav")
	_audio.volume_db = -12
	_audio.max_polyphony = 1
	add_child(_audio)
	_rng.randomize()
	_arc.resize(13)
	_overlay = ZapOverlay.new()
	_overlay.grid = self
	_overlay.z_index = 25
	add_child(_overlay)
	stop()

func reset_run() -> void:
	stop()
	zones.clear()
	_stage = -1

func stop() -> void:
	for reference in _stunned.values():
		var actor = reference.get_ref()
		if is_instance_valid(actor): actor.electric_stun_left = 0
	_stunned.clear()
	_running = false
	_clock = 0
	_cycle = -1
	_scan_left = 0
	_player_ready = 0
	_player_hit = false
	_hit_ids.clear()
	_ready_ids.clear()
	_previous.clear()
	_targets.clear()
	for zap in _zaps: _restore_zap(zap)
	_zaps.clear()
	_audio_ready = 0
	if _audio!=null: _audio.stop()
	_links.clear()
	hide()
	queue_redraw()
	if _overlay != null: _overlay.queue_redraw()

func make_zone(bounds: Rect2, circle: bool, armed_at: float = 0) -> Dictionary:
	return {"bounds":bounds,"circle":circle,"armed_at":armed_at}

func _new_zone(origin: Vector2, index: int, heading: Vector2 = Vector2.ZERO) -> Dictionary:
	var circle := _rng.randf()<0.5
	var width := _rng.randf_range(76,108)
	var size := Vector2(width,width if circle else _rng.randf_range(70,108))
	var angle := TAU*float(index)/ZONE_COUNT+_rng.randf_range(-0.28,0.28)
	if not heading.is_zero_approx(): angle = heading.angle()+_rng.randf_range(-1.3,1.3)
	var direction := Vector2.from_angle(angle)
	var center := origin+direction*_rng.randf_range(150,220)
	var rect := Rect2(center-size*0.5,size)
	for attempt in 24:
		var blocked := rect.grow(65).has_point(origin)
		for j in zones.size():
			if j!=index and rect.grow(16).intersects(zones[j].bounds): blocked = true
		if not blocked: return make_zone(rect,circle,_clock+WARNING)
		direction = direction.rotated(0.65)
		center = origin+direction*(170+float(attempt/8)*55)
		rect.position = center-size*0.5
	# Keep the original offscreen slot if no safe placement is available.
	return zones[index] if index<zones.size() else make_zone(Rect2(origin+Vector2(350+index*150,0),size),circle,_clock+WARNING)

func _layout(origin: Vector2) -> void:
	zones.clear()
	for i in ZONE_COUNT: zones.append(_new_zone(origin,i))
	_explore_at = origin

func _refresh_exploration() -> void:
	var at: Vector2 = game.player.global_position
	if at.distance_squared_to(_explore_at)<64.0*64.0: return
	var heading := (at-_explore_at).normalized()
	_explore_at = at
	var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse()*get_viewport().get_visible_rect()
	view = view.grow(90)
	for i in zones.size():
		var bounds: Rect2 = zones[i].bounds
		# Existing visible terrain never slides with the player or disappears under actors.
		if bounds.get_center().distance_squared_to(at)<420.0*420.0 or view.intersects(bounds): continue
		zones[i] = _new_zone(at,i,heading)

func zone_live(zone: Dictionary) -> bool:
	return energized() and _clock>=float(zone.armed_at)

func player_damage() -> float: return 18.0+3.0*maxi(0,weather.stage-1)
func enemy_damage() -> float: return player_damage()*3.0
func phase() -> float: return fposmod(maxf(0,_clock-WARNING),PERIOD)
func energized() -> bool: return _clock>=WARNING and phase()<LIVE

func _crosses(before: Vector2, after: Vector2, live_only: bool = true) -> bool:
	if before.distance_squared_to(after)>300.0*300.0: before = after
	for zone in zones:
		if live_only and not zone_live(zone): continue
		var rect: Rect2 = zone.bounds
		if zone.circle:
			var near := Geometry2D.get_closest_point_to_segment(rect.get_center(),before,after)
			if near.distance_squared_to(rect.get_center())<=pow(rect.size.x*0.5+5,2): return true
			continue
		var bounds := rect.grow(5)
		if bounds.has_point(before) or bounds.has_point(after): return true
		var a := bounds.position
		var b := Vector2(bounds.end.x,bounds.position.y)
		var c := bounds.end
		var d := Vector2(bounds.position.x,bounds.end.y)
		if Geometry2D.segment_intersects_segment(before,after,a,b)!=null or Geometry2D.segment_intersects_segment(before,after,b,c)!=null or Geometry2D.segment_intersects_segment(before,after,c,d)!=null or Geometry2D.segment_intersects_segment(before,after,d,a)!=null: return true
	return false

func _play_zap_sound() -> void:
	if _clock>=_audio_ready:
		_audio.play()
		audio_events += 1
		_audio_ready = _clock+0.15 # One voice per batch, never one voice per victim.

func _restore_zap(zap: Dictionary) -> void:
	for saved in zap.hidden:
		var item = saved.item.get_ref()
		if is_instance_valid(item): item.visible = saved.visible

func _zap(actor: Node2D) -> void:
	if actor.has_method("is_control_immune") and actor.is_control_immune(): return
	if ("_death_started" in actor and actor._death_started) or ("is_dying" in actor and actor.is_dying): return
	if actor.has_method("apply_electric_stun"):
		actor.apply_electric_stun(STUN_SECONDS)
		_stunned[actor.get_instance_id()] = weakref(actor)
	_play_zap_sound()
	for zap in _zaps:
		if zap.actor.get_ref()==actor:
			zap.until = _clock+STUN_SECONDS
			return
	if _zaps.size()<MAX_ZAPS:
		var profile: Dictionary = _zap_visual.profile(actor)
		var hidden: Array[Dictionary] = []
		var sprite = profile.sprite.get_ref() if profile.sprite!=null else null
		if is_instance_valid(sprite):
			hidden.append({"item":weakref(sprite),"visible":sprite.visible})
			sprite.hide()
		if "_sword" in actor and is_instance_valid(actor._sword):
			hidden.append({"item":weakref(actor._sword),"visible":actor._sword.visible})
			actor._sword.hide()
		_zaps.append({"actor":weakref(actor),"until":_clock+STUN_SECONDS,"profile":profile,"hidden":hidden})

func _touch_player() -> void:
	var p: Node = game.player
	var at: Vector2 = p.global_position+FOOT
	var before := _player_at
	_player_at = at
	if not energized() or _player_hit or _clock<_player_ready or p.movement_locked: return
	if p.is_dash_invulnerable() or p.hurt_lock>0 or p.arsenal_shield_active: return
	if not _crosses(before,at): return
	_player_hit = true
	_player_ready = _clock+STUN_SECONDS+ESCAPE_GRACE # One second paralysis, then half a second escape grace.
	_play_zap_sound()
	p.receive_attack(player_damage())
	if p.player_health>0: _zap(p)

func _scan_enemies() -> void:
	scans += 1
	last_batch = 0
	_targets.clear()
	CombatTargets.fill_in_radius(Vector2.ZERO,INF,game,_targets)
	# Bound work and memory even in synthetic overload; rotate coverage after each cycle.
	var total := _targets.size()
	var count := mini(total,MAX_ACTORS)
	var actors: Array[Node2D] = []
	var positions := PackedVector2Array()
	var buckets: Dictionary = {}
	var next_previous: Dictionary = {}
	var next_ready: Dictionary = {}
	var queue: Array[int] = []
	var visited: Dictionary = {}
	var offset := (_cycle*MAX_ACTORS)%maxi(total,1) if total>MAX_ACTORS else 0
	for i in count:
		var actor := _targets[(i+offset)%total]
		var id := actor.get_instance_id()
		var at := actor.global_position+FOOT
		actors.append(actor)
		positions.append(at)
		var cell := Vector2i((at/CHAIN_RADIUS).floor())
		if not buckets.has(cell): buckets[cell] = []
		buckets[cell].append(i)
		next_previous[id] = at
		if _ready_ids.has(id): next_ready[id] = _ready_ids[id]
		if energized() and not _hit_ids.has(id) and _clock>=float(_ready_ids.get(id,0)) and _crosses(_previous.get(id,at),at):
			visited[i] = true
			queue.append(i)
	_previous = next_previous
	_ready_ids = next_ready
	if queue.is_empty(): return
	# Determine the complete connected snapshot BEFORE any hit/death callbacks can move it.
	var head := 0
	while head<queue.size():
		var index := queue[head]
		head += 1
		var cell := Vector2i((positions[index]/CHAIN_RADIUS).floor())
		for y in range(-1,2):
			for x in range(-1,2):
				var key := cell+Vector2i(x,y)
				if not buckets.has(key): continue
				var bucket: Array = buckets[key]
				for k in range(bucket.size()-1,-1,-1):
					var neighbor: int = bucket[k]
					if visited.has(neighbor):
						bucket.remove_at(k)
						continue
					if positions[index].distance_squared_to(positions[neighbor])>CHAIN_RADIUS*CHAIN_RADIUS: continue
					visited[neighbor] = true
					queue.append(neighbor)
					bucket.remove_at(k)
					if _links.size()<MAX_LINKS:
						_links.append({"a":positions[index]-FOOT,"b":positions[neighbor]-FOOT,"until":_clock+0.25})
	var batch: Array[Node2D] = []
	for index in queue:
		var actor := actors[index]
		var id := actor.get_instance_id()
		if _hit_ids.has(id) or _clock<float(_ready_ids.get(id,0)): continue
		_hit_ids[id] = true
		_ready_ids[id] = _clock+PERIOD
		batch.append(actor)
	last_batch = batch.size()
	if not batch.is_empty(): _play_zap_sound()
	for actor in batch:
		if not weather.surface.active(): break
		if not is_instance_valid(actor) or actor.is_queued_for_deletion(): continue
		actor.apply_hit({"damage":enemy_damage(),"direction":Vector2.ZERO,"effect":"electric_grid","from_status":true,"damage_is_final":true,"source":self})
		if weather.surface.active() and is_instance_valid(actor): _zap(actor)

func _physics_process(delta: float) -> void:
	# Pause freezes pulses; stage-hazard/lifecycle changes cancel owned effects.
	if get_tree().paused: return
	if not weather.hazard_enabled(weather.Hazard.ELECTRIC):
		if _running: stop()
		return
	if not _running or _stage!=weather.stage:
		stop()
		if zones.is_empty() or _stage!=weather.stage: _layout(game.player.global_position)
		else:
			for zone in zones: zone.armed_at = WARNING
			_explore_at = game.player.global_position
		_stage = weather.stage
		_running = true
		_player_at = game.player.global_position+FOOT
		show()
	_clock += maxf(delta,0)
	var cycle := int(maxf(0,_clock-WARNING)/PERIOD)
	if cycle!=_cycle:
		_cycle = cycle
		_hit_ids.clear()
		_player_hit = false
	_refresh_exploration()
	_touch_player()
	if not _running: return
	for i in range(_zaps.size()-1,-1,-1):
		var actor = _zaps[i].actor.get_ref()
		if _zaps[i].until<=_clock or not is_instance_valid(actor) or actor.electric_stun_left<=0 or ("_death_started" in actor and actor._death_started) or ("is_dying" in actor and actor.is_dying):
			_restore_zap(_zaps[i])
			_zaps.remove_at(i)
	for i in range(_links.size()-1,-1,-1):
		if _links[i].until<=_clock: _links.remove_at(i)
	for id in _stunned.keys():
		var actor = _stunned[id].get_ref()
		if not is_instance_valid(actor) or actor.electric_stun_left<=0: _stunned.erase(id)
	_scan_left -= delta
	if _scan_left<=0:
		_scan_left = 0.1
		if energized(): _scan_enemies()
		else: _previous.clear()
	queue_redraw()
	_overlay.queue_redraw()

func _draw() -> void:
	if not _running: return
	for zone in zones:
		var rect: Rect2 = zone.bounds
		var center := rect.get_center()
		var active := zone_live(zone)
		var warning := _clock<WARNING or _clock<float(zone.armed_at)
		var edge := GamePalette.ENEMY_ORANGE if active or warning else GamePalette.UI_GREY_BORDER
		var alpha := 0.95 if active else 0.5
		var fill := Color(GamePalette.ENEMY_RED,0.16+0.08*sin(_clock*20)) if warning else Color(GamePalette.INK,0.65)
		if zone.circle:
			var radius := rect.size.x*0.5
			draw_circle(center,radius,fill)
			draw_arc(center,radius,0,TAU,32,Color(edge,alpha),2)
			for j in 8: draw_circle(center+Vector2.from_angle(TAU*j/8)*radius,2,edge)
		else:
			draw_rect(rect,fill)
			draw_rect(rect,Color(edge,alpha),false,2)
			for j in 5:
				var a := rect.position+Vector2(rect.size.x*j/4,0)
				var b := a+Vector2(0,rect.size.y)
				draw_line(a,b,Color(edge,0.16),1)
				draw_circle(a,2,edge)
				draw_circle(b,2,edge)
		if not active: continue
		for lane in 4:
			var y := rect.size.y*(lane+1)/5.0
			var half_width := rect.size.x*0.5-2
			if zone.circle: half_width = sqrt(maxf(0,pow(rect.size.x*0.5-3,2)-pow(y-rect.size.y*0.5,2)))-3
			for j in 13:
				var t := float(j)/12
				var wave := sin(t*27+floor(_clock*24)*1.7+lane*4)*3*sin(t*PI)
				_arc[j] = Vector2(center.x+lerpf(-half_width,half_width,t),rect.position.y+y+wave)
			draw_polyline(_arc,Color(GamePalette.ENEMY_ORANGE,0.28),4)
			draw_polyline(_arc,GamePalette.HIT_FLASH_WHITE,1.1)

func draw_zaps(canvas: Node2D) -> void:
	for link in _links:
		var mid: Vector2 = (link.a+link.b)*0.5+Vector2(sin(_clock*80)*4,cos(_clock*65)*4)
		var points := PackedVector2Array([link.a,mid,link.b])
		canvas.draw_polyline(points,Color(GamePalette.ENEMY_ORANGE,0.75),4)
		canvas.draw_polyline(points,GamePalette.HIT_FLASH_WHITE,1.2)
	for zap in _zaps:
		var actor = zap.actor.get_ref()
		if not is_instance_valid(actor) or actor.electric_stun_left<=0: continue
		_zap_visual.draw(canvas,actor,zap.profile,_clock)
