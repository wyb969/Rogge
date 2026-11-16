extends Node2D
# Stateless world-grid generation + one batched target query, never one query per patch.
const CELL := 96.0
const RADIUS := 22.0
const MAX_PATCHES := 128
const MAX_ACTORS := 512
const CONTACT_INTERVAL := 1.0
const ARM_SECONDS := 0.8
const FOOT_OFFSET := Vector2(0,12)
var _seed := 0
var _rng := RandomNumberGenerator.new()
var _cells: Dictionary = {}
var _points := PackedVector2Array()
var _variants := PackedInt32Array()
var _bounds := Rect2i()
var _origins: Dictionary = {}
var _stage := -1
var _running := false
var _clock := 0.0
var _armed_at := 0.0
var _player_at := Vector2.ZERO
var _player_ready := 0.0
var _scan_left := 0.0
var _targets: Array[Node2D] = []
var _contacts: Dictionary = {}
var _seen: Dictionary = {}
var _flashes := PackedFloat32Array()
var _teeth: Array[Dictionary] = []
@onready var weather: Node = get_parent()
@onready var game: Node = weather.get_parent()

func _ready() -> void:
	z_index = -7 # Terrain above decorations; below actors, warnings and pickups.
	for variant in 4:
		for tooth in 3:
			var base := Vector2((tooth-1)*13,4+(variant+tooth)%3*3)
			var tip := base+Vector2(float((variant+tooth)%3-1)*3,-17.0-float((variant+tooth*3)%4)*3.0)
			_teeth.append({"body":PackedVector2Array([base+Vector2(-7,0),tip,base+Vector2(7,0)]),"shade":PackedVector2Array([base,tip,base+Vector2(7,0)]),"tip":tip})
	_rng.randomize()
	_points.resize(MAX_PATCHES)
	_variants.resize(MAX_PATCHES)
	_flashes.resize(MAX_PATCHES)
	reset_run()

func reset_run() -> void:
	_seed = _rng.randi_range(1,0x7fffffff)
	_origins.clear()
	_stage = -1
	_clock = 0
	stop()

func stop() -> void:
	_running = false
	_cells.clear()
	_contacts.clear()
	_targets.clear()
	_seen.clear()
	_bounds = Rect2i()
	_player_ready = 0
	_scan_left = 0
	hide()
	queue_redraw()

func _hash(cell: Vector2i) -> int:
	var value: int = (cell.x*73856093 ^ cell.y*19349663 ^ weather.stage*83492791 ^ _seed) & 0x7fffffff
	value = ((value ^ (value >> 16))*0x45d9f3b) & 0x7fffffff
	return (value ^ (value >> 16)) & 0x7fffffff

func point_for(cell: Vector2i) -> Vector2:
	var h := _hash(cell)
	return (Vector2(cell)+Vector2(0.5,0.5))*CELL+Vector2((h>>8)%25-12,(h>>16)%25-12)

func occupied(cell: Vector2i) -> bool:
	if _hash(cell)%100 >= 10: return false
	var origin: Vector2 = _origins.get(weather.stage,Vector2.ZERO)
	return point_for(cell).distance_squared_to(origin) > 112.0*112.0

func player_damage() -> float:
	return 12.0+2.0*maxi(0,weather.stage-1)

func enemy_damage() -> float:
	return player_damage()*3.0

func _refresh() -> void:
	var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse()*get_viewport().get_visible_rect()
	view = view.grow(CELL*2)
	# Include the controlled actor even while the camera catches up after a fast dash.
	view = view.expand(game.player.global_position-Vector2.ONE*CELL)
	view = view.expand(game.player.global_position+Vector2.ONE*CELL)
	var next := Rect2i(Vector2i((view.position/CELL).floor()),Vector2i((view.size/CELL).ceil())+Vector2i.ONE)
	next.size.x = mini(next.size.x,24)
	next.size.y = mini(next.size.y,24)
	if next == _bounds: return
	_bounds = next
	_cells.clear()
	_flashes.fill(0)
	for y in range(next.position.y,next.end.y):
		for x in range(next.position.x,next.end.x):
			var cell := Vector2i(x,y)
			if not occupied(cell) or _cells.size() >= MAX_PATCHES: continue
			var index := _cells.size()
			_cells[cell] = index
			_points[index] = point_for(cell)
			_variants[index] = _hash(cell)%4
	queue_redraw()

func _crossing(before: Vector2, after: Vector2) -> int:
	# Treat teleports as arrivals; ordinary dash/knockback paths are swept, not sampled points.
	if before.distance_squared_to(after)>300.0*300.0: before = after
	var low := Vector2i(((before.min(after)-Vector2.ONE*RADIUS)/CELL).floor())
	var high := Vector2i(((before.max(after)+Vector2.ONE*RADIUS)/CELL).floor())
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var index: int = _cells.get(Vector2i(x,y),-1)
			if index < 0: continue
			var near := Geometry2D.get_closest_point_to_segment(_points[index],before,after)
			if near.distance_squared_to(_points[index]) <= RADIUS*RADIUS: return index
	return -1

func _touch_player() -> void:
	var at: Vector2 = game.player.global_position+FOOT_OFFSET
	var previous := _player_at
	_player_at = at
	if _clock < _player_ready or _clock < _armed_at or game.player.movement_locked: return
	if game.player.is_dash_invulnerable() or game.player.hurt_lock>0 or game.player.arsenal_shield_active: return
	var index := _crossing(previous,at)
	if index < 0: return
	_player_ready = _clock+CONTACT_INTERVAL
	_flashes[index] = _clock+0.22
	game.player.receive_attack(player_damage())

func _scan_enemies() -> void:
	if not weather.surface.active(): return
	_targets.clear()
	_seen.clear()
	CombatTargets.fill_in_bounds(Rect2(Vector2(_bounds.position)*CELL,Vector2(_bounds.size)*CELL),game,_targets)
	for i in mini(_targets.size(),MAX_ACTORS):
		_seen[_targets[i].get_instance_id()] = true
	for id in _contacts.keys():
		if not _seen.has(id): _contacts.erase(id)
	for i in mini(_targets.size(),MAX_ACTORS):
		var actor := _targets[i]
		var id := actor.get_instance_id()
		var at: Vector2 = actor.global_position+FOOT_OFFSET
		var contact: Dictionary = _contacts[id] if _contacts.has(id) else {"at":at,"ready":0.0}
		var before: Vector2 = contact.at
		contact.at = at
		_contacts[id] = contact
		if _clock < _armed_at or _clock < float(contact.ready): continue
		var index := _crossing(before,at)
		if index < 0: continue
		contact.ready = _clock+CONTACT_INTERVAL
		_flashes[index] = _clock+0.22
		# Already computed environmental damage, independent of the player's crit/side/status bonuses.
		actor.apply_hit({"damage":enemy_damage(),"direction":Vector2.ZERO,"effect":"ice_spikes","from_status":true,"damage_is_final":true,"source":self})
		if not weather.surface.active(): return

func _physics_process(delta: float) -> void:
	var enabled: bool = weather.hazard_enabled(weather.Hazard.SPIKES)
	if not enabled:
		if _running: stop()
		return
	_clock += delta
	if not _running or _stage != weather.stage:
		stop()
		_running = true
		_stage = weather.stage
		if not _origins.has(_stage): _origins[_stage] = game.player.global_position
		_armed_at = _clock+ARM_SECONDS
		_player_at = game.player.global_position+FOOT_OFFSET
		show()
	_refresh()
	_touch_player()
	if not _running or not weather.surface.active(): return
	_scan_left -= delta
	if _scan_left <= 0:
		_scan_left = 0.1
		_scan_enemies()
		queue_redraw()

func _draw() -> void:
	if not _running: return
	var armed: float = clampf(1.0-(_armed_at-_clock)/ARM_SECONDS,0,1)
	for i in _cells.size():
		var at := _points[i]
		var flash := 1.0 if _flashes[i]>_clock else 0.0
		draw_circle(at,RADIUS,Color(GamePalette.SPIKE_BASE,0.72))
		draw_arc(at,RADIUS,0,TAU,20,Color(GamePalette.ENEMY_RED,0.45+armed*0.25),1.4)
		draw_set_transform(at)
		for tooth in 3:
			var shape: Dictionary = _teeth[_variants[i]*3+tooth]
			draw_colored_polygon(shape.body,GamePalette.ICE_REFLECTION.lerp(GamePalette.UI_TEXT,flash))
			draw_colored_polygon(shape.shade,GamePalette.SPIKE_SHADE)
			draw_line(shape.tip,shape.tip+Vector2(0,5),GamePalette.ENEMY_ORANGE,2)
		draw_set_transform(Vector2.ZERO)
