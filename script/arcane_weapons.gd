extends Node2D
const IDS := ["thorn_whip", "rune_bolt", "pulse_aura"]
const MAX_LEVEL := 5
const MAX_RUNES := 8
const MAX_FLASHES := 12
var levels := {"thorn_whip":0,"rune_bolt":0,"pulse_aura":0}
var cooldowns := {"thorn_whip":0.0,"rune_bolt":0.0,"pulse_aura":0.0}
var runes: Array[Dictionary] = []
var flashes: Array[Dictionary] = []
var _targets: Array[Node2D] = []
var _flash_slot := 0
var _generation := 0
var _audio: AudioStreamPlayer
var hits := 0
var casts := 0
@onready var game: Node = get_parent()

static func stats_for(id: String, rank: int) -> Dictionary:
	var step := clampi(rank,1,5)-1
	match id:
		"thorn_whip": return {"damage":28.0+8.0*step,"range":110.0+14.0*step,"interval":1.5-0.12*step}
		"rune_bolt": return {"damage":18.0+5.0*step,"count":1+(1 if step>=3 else 0),"range":180.0+15.0*step,"duration":3.0,"interval":3.2-0.2*step}
		_: return {"damage":8.0+4.0*step,"radius":65.0+8.0*step,"interval":1.25-0.1*step}

func _ready() -> void:
	z_index = 10
	for i in MAX_RUNES:
		runes.append({"active":false,"at":Vector2.ZERO,"previous":Vector2.ZERO,"center":Vector2.ZERO,"direction":Vector2.RIGHT,"range":180.0,"age":0.0,"duration":3.0,"damage":0.0,"hit_times":{}})
	for i in MAX_FLASHES:
		flashes.append({"left":0.0,"at":Vector2.ZERO,"angle":0.0,"radius":0.0,"kind":""})
	_audio = AudioStreamPlayer.new()
	AudioManager.configure_sfx(_audio)
	_audio.stream = preload("res://assest/sounds/banana_fan.wav")
	_audio.volume_db = -26
	_audio.max_polyphony = 1
	add_child(_audio)
	reset()

func upgrade(id: String) -> void:
	if not levels.has(id): return
	levels[id] = mini(5,int(levels[id])+1)
	cooldowns[id] = minf(float(cooldowns[id]),0.3)
	set_physics_process(true)

func reset() -> void:
	clear_combat_effects()
	for id in IDS: levels[id] = 0
	hits = 0
	casts = 0
	set_physics_process(false)

func clear_combat_effects() -> void:
	_generation += 1
	for rune in runes:
		rune.active = false
		rune.hit_times.clear()
	for flash in flashes: flash.left = 0.0
	for id in IDS: cooldowns[id] = 0.3
	_targets.clear()
	if _audio: _audio.stop()
	set_process(false)
	queue_redraw()

func _live(actor: Node2D) -> bool:
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.has_method("apply_hit") and (not actor.has_method("vulnerable") or actor.vulnerable()) and (not "health" in actor or actor.health>0) and (not "boss_current_health" in actor or actor.boss_current_health>0)

func _flash(kind: String, at: Vector2, radius: float, angle: float = 0.0) -> void:
	var flash := flashes[_flash_slot]
	_flash_slot = (_flash_slot+1)%MAX_FLASHES
	flash.left = 0.26
	flash.kind = kind
	flash.at = at
	flash.radius = radius
	flash.angle = angle
	set_process(true)

func cast(id: String) -> bool:
	if not levels.has(id) or levels[id]<=0 or not game.variety._battle_active(): return false
	var stats := stats_for(id,levels[id])
	var origin: Vector2 = game.player.global_position
	_targets.clear()
	var radius: float = stats.get("range",stats.get("radius",0.0))
	CombatTargets.fill_in_radius(origin,radius*radius,game,_targets)
	var nearest: Node2D
	var distance := INF
	for actor in _targets:
		if not _live(actor): continue
		var d := origin.distance_squared_to(actor.global_position)
		if d<distance:
			distance = d
			nearest = actor
	if nearest == null: return false
	var direction: Vector2 = origin.direction_to(nearest.global_position)
	if direction.is_zero_approx(): direction = Vector2.RIGHT
	var generation := _generation
	if id == "rune_bolt":
		var count := 0
		for rune in runes:
			if rune.active: continue
			rune.active = true
			rune.at = origin
			rune.previous = origin
			rune.center = origin
			rune.direction = direction.rotated(-0.22 if count==0 else 0.22)
			rune.range = radius
			rune.age = 0.0
			rune.duration = stats.duration
			rune.damage = stats.damage
			rune.hit_times.clear()
			count += 1
			if count>=int(stats.count): break
		if count==0: return false
		set_process(true)
	else:
		_flash(id,origin,radius,direction.angle())
		for actor in _targets:
			if not _live(actor): continue
			if id=="thorn_whip" and origin.direction_to(actor.global_position).dot(direction)<cos(deg_to_rad(60.0)): continue
			actor.apply_hit({"damage":stats.damage,"direction":origin.direction_to(actor.global_position),"source":self,"from_status":id=="pulse_aura","visual_effect":&"pulse_aura"})
			hits += 1
			if generation!=_generation: return true
	cooldowns[id] = stats.interval
	casts += 1
	if not _audio.playing:
		_audio.pitch_scale = 0.65 if id=="pulse_aura" else 1.25
		_audio.play()
	return true

func _physics_process(delta: float) -> void:
	if not game.variety._battle_active():
		clear_combat_effects()
		return
	for id in IDS:
		if levels[id]<=0: continue
		cooldowns[id] -= delta
		if cooldowns[id]<=0 and not cast(id): cooldowns[id] = 0.2
	var bounds := Rect2(game.player.global_position,Vector2.ZERO)
	var active := false
	for rune in runes:
		if rune.active:
			active = true
			bounds = bounds.expand(rune.center-Vector2.ONE*rune.range).expand(rune.center+Vector2.ONE*rune.range)
	if not active: return
	_targets.clear()
	CombatTargets.fill_in_bounds(bounds.grow(26),game,_targets)
	var generation := _generation
	for rune in runes:
		if not rune.active: continue
		rune.previous = rune.at
		var travel: float = minf(delta,maxf(0,rune.duration-rune.age))*270.0
		rune.age += delta
		# Reflected segments are swept separately. Never teleport through targets on a hitch.
		for bounce in 5:
			if travel<=0.001: break
			var offset: Vector2 = rune.at-rune.center
			var dir: Vector2 = rune.direction
			var tx: float = (signf(dir.x)*rune.range-offset.x)/dir.x if absf(dir.x)>0.0001 else INF
			var ty: float = (signf(dir.y)*rune.range-offset.y)/dir.y if absf(dir.y)>0.0001 else INF
			var distance: float = maxf(0.0,minf(tx,ty))
			var step := minf(travel,distance)
			var next: Vector2 = rune.at+dir*step
			_sweep(rune,rune.at,next)
			if generation!=_generation: return
			rune.at = next
			travel -= step
			if distance>step: break
			if tx<=ty+0.001: rune.direction.x *= -1.0
			if ty<=tx+0.001: rune.direction.y *= -1.0
			_flash("rune_bounce",rune.at,13)
		if rune.age>=rune.duration: rune.active = false

func _sweep(rune: Dictionary, from: Vector2, to: Vector2) -> void:
	var generation := _generation
	for actor in _targets:
		if not _live(actor): continue
		var id := actor.get_instance_id()
		if float(rune.hit_times.get(id,-10.0))+0.35>rune.age: continue
		if Geometry2D.get_closest_point_to_segment(actor.global_position,from,to).distance_squared_to(actor.global_position)>26*26: continue
		rune.hit_times[id] = rune.age
		actor.apply_hit({"damage":rune.damage,"direction":rune.direction,"source":self})
		hits += 1
		if generation!=_generation: return

func _process(delta: float) -> void:
	var active := false
	for flash in flashes:
		flash.left = maxf(0,float(flash.left)-delta)
		active = active or flash.left>0
	for rune in runes: active = active or rune.active
	queue_redraw()
	if not active: set_process(false)

func _draw() -> void:
	var cyan: Color = GamePalette.PLAYER_CYAN
	for rune in runes:
		if not rune.active: continue
		var at: Vector2 = to_local(rune.previous.lerp(rune.at,Engine.get_physics_interpolation_fraction()))
		draw_set_transform(at,rune.age*5.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0,-9),Vector2(7,0),Vector2(0,9),Vector2(-7,0)]),Color.WHITE)
		draw_arc(Vector2.ZERO,13,0,TAU,12,cyan,2)
		draw_set_transform(Vector2.ZERO)
	for flash in flashes:
		if flash.left<=0: continue
		var progress: float = 1.0-float(flash.left)/0.26
		var at: Vector2 = to_local(flash.at)
		var color := Color(cyan,1.0-progress)
		if flash.kind=="thorn_whip":
			var start: float = flash.angle-PI/3.0
			var end: float = flash.angle+PI/3.0
			draw_arc(at,flash.radius*(0.75+0.25*progress),start,end,24,color,5)
			draw_arc(at,flash.radius*0.75,start,end,24,Color(1,1,1,1.0-progress),2)
			for i in 7:
				var direction := Vector2.RIGHT.rotated(lerpf(start,end,float(i)/6.0))
				draw_line(at+direction*flash.radius*0.83,at+direction*flash.radius,color,2)
		else:
			draw_arc(at,flash.radius*(0.5+0.5*progress),0,TAU,32,color,3)
			if flash.kind=="pulse_aura":
				for i in 8:
					var direction := Vector2.RIGHT.rotated(TAU*i/8.0)
					draw_line(at+direction*(flash.radius-8),at+direction*flash.radius,Color(1,1,1,1.0-progress),2)
