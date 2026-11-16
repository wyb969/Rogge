extends Node2D
# Two world-fixed strips, one snapshot query and iterative spatial flood fill per scan.
const PERIOD := 4.5
const WARNING := 0.75
const LIVE := 1.2
const CHAIN_RADIUS := 42.0
const MAX_ACTORS := 512
const MAX_ZAPS := 64
const MAX_LINKS := 128
const FOOT := Vector2(0,12)
var strips: Array[Rect2] = []
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
var _stunned: Dictionary = {}
var _targets: Array[Node2D] = []
var _zaps: Array[Dictionary] = []
var _links: Array[Dictionary] = []
var _overlay: ZapOverlay
var _arc := PackedVector2Array()
var scans := 0
var last_batch := 0
@onready var weather: Node = get_parent()
@onready var game: Node = weather.get_parent()

class ZapOverlay extends Node2D:
	var grid: Node2D
	func _draw() -> void: grid.draw_zaps(self)

func _ready() -> void:
	z_index = -7
	_rng.randomize()
	_arc.resize(13)
	_overlay = ZapOverlay.new()
	_overlay.grid = self
	_overlay.z_index = 25
	add_child(_overlay)
	stop()

func reset_run() -> void:
	stop()
	strips.clear()
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
	_previous.clear()
	_targets.clear()
	_zaps.clear()
	_links.clear()
	hide()
	queue_redraw()
	if _overlay != null: _overlay.queue_redraw()

func _layout(origin: Vector2) -> void:
	strips.clear()
	for i in 2:
		var horizontal := _rng.randf()<0.5
		var size := Vector2(_rng.randf_range(200,280),42)
		if not horizontal: size = Vector2(size.y,size.x)
		var side := -1.0 if i==0 else 1.0
		var offset := Vector2(_rng.randf_range(-40,40),side*_rng.randf_range(120,175)) if horizontal else Vector2(side*_rng.randf_range(120,175),_rng.randf_range(-40,40))
		var rect := Rect2(origin+offset-size*0.5,size)
		# A second strip must not intersect the first, or the safe starting disk.
		for attempt in 8:
			if (i==0 or not rect.grow(25).intersects(strips[0])) and not rect.grow(65).has_point(origin): break
			rect.position += offset.normalized()*45
		strips.append(rect)

func player_damage() -> float: return 18.0+3.0*maxi(0,weather.stage-1)
func enemy_damage() -> float: return player_damage()*3.0
func phase() -> float: return fposmod(_clock,PERIOD)
func energized() -> bool: return phase()>=WARNING and phase()<WARNING+LIVE

func _crosses(before: Vector2, after: Vector2) -> bool:
	if before.distance_squared_to(after)>300.0*300.0: before = after
	for rect in strips:
		var bounds := rect.grow(5)
		if bounds.has_point(before) or bounds.has_point(after): return true
		var a := bounds.position
		var b := Vector2(bounds.end.x,bounds.position.y)
		var c := bounds.end
		var d := Vector2(bounds.position.x,bounds.end.y)
		if Geometry2D.segment_intersects_segment(before,after,a,b)!=null or Geometry2D.segment_intersects_segment(before,after,b,c)!=null or Geometry2D.segment_intersects_segment(before,after,c,d)!=null or Geometry2D.segment_intersects_segment(before,after,d,a)!=null: return true
	return false

func _zap(actor: Node2D) -> void:
	if actor.has_method("apply_electric_stun"):
		actor.apply_electric_stun(1.0)
		_stunned[actor.get_instance_id()] = weakref(actor)
	if _zaps.size()<MAX_ZAPS:
		_zaps.append({"actor":weakref(actor),"until":_clock+1.0})

func _touch_player() -> void:
	var p: Node = game.player
	var at: Vector2 = p.global_position+FOOT
	var before := _player_at
	_player_at = at
	if not energized() or _player_hit or _clock<_player_ready or p.movement_locked: return
	if p.is_dash_invulnerable() or p.hurt_lock>0 or p.arsenal_shield_active: return
	if not _crosses(before,at): return
	_player_hit = true
	_player_ready = _clock+3.5 # 1s paralysis + 2.5s electrical escape grace.
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
		if energized() and not _hit_ids.has(id) and _crosses(_previous.get(id,at),at):
			visited[i] = true
			queue.append(i)
	_previous = next_previous
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
		if _hit_ids.has(id): continue
		_hit_ids[id] = true
		batch.append(actor)
	last_batch = batch.size()
	for actor in batch:
		if not weather.surface.active(): break
		if not is_instance_valid(actor) or actor.is_queued_for_deletion(): continue
		actor.apply_hit({"damage":enemy_damage(),"direction":Vector2.ZERO,"effect":"electric_grid","from_status":true,"damage_is_final":true,"source":self})
		if weather.surface.active() and is_instance_valid(actor): _zap(actor)

func _physics_process(delta: float) -> void:
	# Pause freezes the cycle; lifecycle/other-weather changes cancel it cleanly.
	if get_tree().paused: return
	if not weather.surface.active() or weather.current_weather!=0 or weather._weights[0]<0.5:
		if _running: stop()
		return
	if not _running or _stage!=weather.stage:
		stop()
		if strips.is_empty() or _stage!=weather.stage: _layout(game.player.global_position)
		_stage = weather.stage
		_running = true
		_player_at = game.player.global_position+FOOT
		show()
	_clock += maxf(delta,0)
	var cycle := int(_clock/PERIOD)
	if cycle!=_cycle:
		_cycle = cycle
		_hit_ids.clear()
		_player_hit = false
	_touch_player()
	if not _running: return
	for i in range(_zaps.size()-1,-1,-1):
		if _zaps[i].until<=_clock or not is_instance_valid(_zaps[i].actor.get_ref()): _zaps.remove_at(i)
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
	var active := energized()
	var warning := phase()<WARNING
	var edge := GamePalette.ENEMY_ORANGE if active or warning else GamePalette.UI_GREY_BORDER
	for rect in strips:
		draw_rect(rect,Color(GamePalette.INK,0.65))
		if warning: draw_rect(rect,Color(GamePalette.ENEMY_RED,0.12+0.12*sin(phase()*20)))
		draw_rect(rect,Color(edge,0.95 if active else 0.5),false,2)
		# Electrode pairs and crossbars distinguish these strips from flat attack warnings.
		var horizontal := rect.size.x>rect.size.y
		var length := rect.size.x if horizontal else rect.size.y
		var width := rect.size.y if horizontal else rect.size.x
		for j in 7:
			var along := length*float(j)/6.0
			var a := rect.position+(Vector2(along,0) if horizontal else Vector2(0,along))
			var b := a+(Vector2(0,width) if horizontal else Vector2(width,0))
			draw_line(a,b,Color(edge,0.22),1)
			draw_circle(a,2,edge)
			draw_circle(b,2,edge)
		if not active: continue
		for lane in 3:
			for j in 13:
				var t := float(j)/12
				var offset := width*(lane+1)/4.0+sin(t*27+floor(_clock*24)*1.7+lane*4)*4
				_arc[j] = rect.position+(Vector2(length*t,offset) if horizontal else Vector2(offset,length*t))
			draw_polyline(_arc,Color(GamePalette.ENEMY_ORANGE,0.28),5)
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
		var at: Vector2 = actor.global_position
		var color := GamePalette.HIT_FLASH_WHITE
		color.a = 1.0 if int(_clock*18)%2==0 else 0.65
		canvas.draw_circle(at,14,Color(GamePalette.INK,0.75))
		canvas.draw_circle(at+Vector2(0,-8),5,color)
		canvas.draw_circle(at+Vector2(-2,-9),1.1,GamePalette.INK)
		canvas.draw_circle(at+Vector2(2,-9),1.1,GamePalette.INK)
		canvas.draw_line(at+Vector2(0,-3),at+Vector2(0,8),color,2)
		for y in [0,3,6]: canvas.draw_line(at+Vector2(-4,y),at+Vector2(4,y),color,1.5)
		for side in [-1,1]:
			canvas.draw_polyline(PackedVector2Array([at+Vector2(0,-1),at+Vector2(side*7,2),at+Vector2(side*9,-3)]),color,1.5)
			canvas.draw_line(at+Vector2(0,8),at+Vector2(side*5,13),color,2)
