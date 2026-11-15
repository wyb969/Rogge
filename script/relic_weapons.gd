extends Node2D
# One bounded draw layer and one candidate query per physics tick for all three weapons.
const IDS := ["silver_knife", "cross_blade", "holy_water"]
const MAX_LEVEL := 5
const MAX_SHOTS := 32
const MAX_POOLS := 8
const TICK := 0.5
var levels := {"silver_knife":0, "cross_blade":0, "holy_water":0}
var cooldowns := {"silver_knife":0.0, "cross_blade":0.0, "holy_water":0.0}
var shots: Array[Dictionary] = []
var pools: Array[Dictionary] = []
var candidates: Array[Node2D] = []
var casts := 0
var hits := 0
var _water_tick := 0.0
var _generation := 0
var _audio: AudioStreamPlayer
@onready var game: Node = get_parent()

static func stats_for(id: String, rank: int) -> Dictionary:
	var step := clampi(rank, 1, MAX_LEVEL) - 1
	match id:
		"silver_knife": return {"damage":16.0+6.0*step,"count":1+floori(float(step)/2.0),"range":300.0+30.0*step,"interval":1.15-0.1*step}
		"cross_blade": return {"damage":24.0+8.0*step,"count":1,"range":180.0+25.0*step,"interval":2.8-0.25*step}
		_: return {"dps":10.0+5.0*step,"radius":48.0+8.0*step,"duration":3.0,"interval":4.5-0.4*step}

func _ready() -> void:
	z_index = 9
	for i in MAX_SHOTS:
		shots.append({"active":false,"kind":"","at":Vector2.ZERO,"previous":Vector2.ZERO,"origin":Vector2.ZERO,"direction":Vector2.RIGHT,"age":0.0,"life":1.0,"range":0.0,"damage":0.0,"returning":false,"hit_ids":{},"angle":0.0})
	for i in MAX_POOLS:
		pools.append({"active":false,"at":Vector2.ZERO,"age":0.0,"radius":0.0,"dps":0.0,"duration":3.0})
	_audio = AudioStreamPlayer.new()
	AudioManager.configure_sfx(_audio)
	_audio.stream = preload("res://assest/sounds/banana_fan.wav")
	_audio.volume_db = -24
	_audio.max_polyphony = 1
	add_child(_audio)
	reset()

func upgrade(id: String) -> void:
	if not levels.has(id): return
	levels[id] = mini(int(levels[id])+1,MAX_LEVEL)
	cooldowns[id] = minf(float(cooldowns[id]),0.3)
	set_physics_process(true)

func clear_combat_effects() -> void:
	_generation += 1
	for shot in shots:
		shot.active = false
		shot.hit_ids.clear()
	for pool in pools: pool.active = false
	candidates.clear()
	_water_tick = 0.0
	for id in IDS: cooldowns[id] = 0.3
	if _audio: _audio.stop()
	set_process(false)
	queue_redraw()

func reset() -> void:
	clear_combat_effects()
	for id in IDS: levels[id] = 0
	casts = 0
	hits = 0
	set_physics_process(false)

func _active() -> bool:
	return game.variety._battle_active()

func cast(id: String) -> bool:
	if not levels.has(id) or levels[id] <= 0 or not _active(): return false
	var stats := stats_for(id,levels[id])
	var origin: Vector2 = game.player.global_position
	var target: Node2D = CombatTargets.nearest(origin,380.0*380.0)
	if target == null or not game.is_ancestor_of(target): return false
	if id == "holy_water":
		for pool in pools:
			if pool.active: continue
			pool.active = true
			pool.at = origin + (target.global_position-origin).limit_length(260.0)
			pool.age = 0.0
			pool.radius = stats.radius
			pool.dps = stats.dps
			pool.duration = stats.duration
			_finish_cast(id,stats.interval)
			return true
		return false
	var direction: Vector2 = game.player.last_move_direction.normalized() if id == "silver_knife" else origin.direction_to(target.global_position)
	if direction.is_zero_approx(): direction = Vector2.RIGHT
	var count: int = int(stats.count)
	var spawned := 0
	for shot in shots:
		if shot.active: continue
		var spread := (float(spawned)-float(count-1)*0.5)*0.14
		shot.active = true
		shot.kind = id
		shot.origin = origin
		shot.at = origin
		shot.previous = origin
		shot.direction = direction.rotated(spread)
		shot.age = 0.0
		shot.life = float(stats.range)/430.0 if id == "silver_knife" else 1.4
		shot.range = stats.range
		shot.damage = stats.damage
		shot.returning = false
		shot.hit_ids.clear()
		spawned += 1
		if spawned >= count: break
	if spawned == 0: return false
	_finish_cast(id,stats.interval)
	return true

func _finish_cast(id: String, interval: float) -> void:
	cooldowns[id] = interval
	casts += 1
	set_process(true)
	if not _audio.playing:
		_audio.pitch_scale = 1.5 if id == "silver_knife" else (0.8 if id == "holy_water" else 1.1)
		_audio.play()

func _live(actor: Node2D) -> bool:
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.has_method("apply_hit") and (not actor.has_method("vulnerable") or actor.vulnerable()) and (not "health" in actor or actor.health > 0) and (not "boss_current_health" in actor or actor.boss_current_health > 0)

func _physics_process(delta: float) -> void:
	if not _active():
		clear_combat_effects()
		return
	for id in IDS:
		if levels[id] <= 0: continue
		cooldowns[id] -= delta
		if cooldowns[id] <= 0 and not cast(id): cooldowns[id] = 0.2
	var bounds := Rect2(game.player.global_position,Vector2.ZERO)
	var active := false
	for shot in shots:
		if shot.active:
			bounds = bounds.expand(shot.origin).expand(shot.at)
			active = true
	for pool in pools:
		if pool.active:
			bounds = bounds.expand(pool.at)
			active = true
	if not active:
		set_process(false)
		queue_redraw()
		return
	candidates.clear()
	CombatTargets.fill_in_bounds(bounds.grow(450.0),game,candidates)
	var generation := _generation
	for shot in shots:
		if not shot.active: continue
		shot.previous = shot.at
		shot.age = minf(shot.age+delta,shot.life)
		shot.at = _position_at(shot,shot.age)
		# Split a low-FPS step at the turn so outbound/return can each hit once.
		if shot.kind == "cross_blade" and not shot.returning and shot.age >= shot.life*0.5:
			var tip := _position_at(shot,shot.life*0.5)
			_sweep(shot,shot.previous,tip)
			if generation != _generation: return
			shot.hit_ids.clear()
			shot.returning = true
			_sweep(shot,tip,shot.at)
		else: _sweep(shot,shot.previous,shot.at)
		if generation != _generation: return
		shot.angle = shot.direction.angle() if shot.kind == "silver_knife" else shot.age*14.0
		if shot.age >= shot.life: shot.active = false
	_water_tick += delta
	if _water_tick >= TICK:
		# No catch-up burst after a hitch, and overlapping pools use only the strongest DPS.
		_water_tick = fmod(_water_tick,TICK)
		for actor in candidates:
			if not _live(actor): continue
			var dps := 0.0
			for pool in pools:
				if pool.active and pool.age < pool.duration and actor.global_position.distance_squared_to(pool.at) <= pool.radius*pool.radius:
					dps = maxf(dps,pool.dps)
			if dps > 0:
				actor.apply_hit({"damage":dps*TICK,"direction":Vector2.ZERO,"source":self,"from_status":true,"visual_effect":&"holy_water"})
				hits += 1
				if generation != _generation: return
	for pool in pools:
		if not pool.active: continue
		pool.age += delta
		if pool.age >= pool.duration: pool.active = false

func _position_at(shot: Dictionary, age: float) -> Vector2:
	var t: float = clampf(age/shot.life,0.0,1.0)
	var distance: float = shot.range * (t if shot.kind == "silver_knife" else sin(PI*t))
	return shot.origin+shot.direction*distance

func _sweep(shot: Dictionary, from: Vector2, to: Vector2) -> void:
	var generation := _generation
	for actor in candidates:
		if not _live(actor): continue
		var id := actor.get_instance_id()
		if shot.hit_ids.has(id): continue
		var nearest := Geometry2D.get_closest_point_to_segment(actor.global_position,from,to)
		if nearest.distance_squared_to(actor.global_position) > 26.0*26.0: continue
		shot.hit_ids[id] = true
		actor.apply_hit({"damage":shot.damage,"direction":shot.direction * (-1 if shot.returning else 1),"source":self})
		hits += 1
		if generation != _generation: return

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var cyan: Color = GamePalette.PLAYER_CYAN
	for pool in pools:
		if not pool.active: continue
		var fade: float = minf(pool.age*5.0,1.0)*minf((pool.duration-pool.age)*3.0,1.0)
		var at: Vector2 = to_local(pool.at)
		draw_circle(at,pool.radius,Color(cyan,0.16*fade))
		draw_arc(at,pool.radius,0,TAU,32,Color(cyan,0.65*fade),2.0)
		for i in 3:
			var wave: float = fmod(pool.age*0.65+float(i)/3.0,1.0)
			draw_arc(at,pool.radius*wave,0,TAU,24,Color(cyan,(1.0-wave)*0.3*fade),1.5)
		draw_line(at+Vector2(-5,0),at+Vector2(5,0),Color.WHITE,2)
		draw_line(at+Vector2(0,-5),at+Vector2(0,5),Color.WHITE,2)
	for shot in shots:
		if not shot.active: continue
		var pos: Vector2 = shot.previous.lerp(shot.at,Engine.get_physics_interpolation_fraction())
		draw_set_transform(to_local(pos),shot.angle)
		if shot.kind == "silver_knife":
			draw_line(Vector2(-22,0),Vector2.ZERO,Color(cyan,0.3),5)
			draw_colored_polygon(PackedVector2Array([Vector2(13,0),Vector2(-5,-4),Vector2(-2,0),Vector2(-5,4)]),Color.WHITE)
			draw_line(Vector2(-6,-4),Vector2(-6,4),cyan,3)
		else:
			draw_circle(Vector2.ZERO,18,Color(cyan,0.12))
			for i in 4:
				var a := Vector2.RIGHT.rotated(i*PI*0.5)
				draw_line(a*4,a*16,cyan,5)
				draw_line(a*8,a*17,Color.WHITE,2)
		draw_set_transform(Vector2.ZERO)
