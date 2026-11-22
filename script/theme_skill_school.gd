extends Node2D

const DRAGON := ["solar_flare","kienzan","kamehameha"]
const POCKET := ["small_light","air_cannon","big_light"]
const LABELS := {"damage":"单次伤害","radius":"作用半径","range":"攻击距离","interval":"触发间隔","duration":"持续时间","count":"穿透数"}
@onready var game: Node = get_parent()
var profiles := {}
var cooldowns := {}
var cue := AudioStreamPlayer.new()
var epoch := 0
var in_battle := false
var clock := 0.0

static func stats_for(id: String, rank: int) -> Dictionary:
	var s := clampi(rank-1,0,4)
	match id:
		"solar_flare": return {"damage":8.0+2*s,"radius":88+9*s,"interval":4.5-0.33*s,"duration":0.85+0.1*s}
		"kienzan": return {"damage":20.0+5*s,"radius":15+2*s,"count":3+s,"interval":2.9-0.17*s}
		"kamehameha": return {"damage":12.0+3*s,"radius":10+2*s,"duration":0.42+0.07*s,"interval":4.8-0.25*s}
		"small_light": return {"damage":7.0+2*s,"radius":24+5*s,"duration":2.4+0.35*s,"interval":3.9-0.2*s}
		"air_cannon": return {"damage":17.0+5*s,"range":150+25*s,"count":2+s,"interval":3.1-0.18*s}
		"big_light": return {"damage":22.0+5*s,"radius":17+3*s,"interval":4.4-0.23*s}
	return {}

func _ready() -> void:
	AudioManager.configure_sfx(cue)
	cue.volume_db = -17
	add_child(cue)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 13
	set_physics_process(false)

func set_forged_stats(id: String, count: int, stats: Dictionary) -> void:
	if count > 0:
		if not profiles.has(id): cooldowns[id] = 0.25
		profiles[id] = stats
	else:
		profiles.erase(id)
		cooldowns.erase(id)
		removed(id)
	if profiles.is_empty(): clear_combat_effects()
	set_physics_process(not profiles.is_empty())

func reset() -> void:
	profiles.clear()
	cooldowns.clear()
	clear_combat_effects()
	set_physics_process(false)

func clear_combat_effects() -> void:
	epoch += 1
	cue.stop()
	in_battle = false
	for id in cooldowns: cooldowns[id] = 0.25
	clear_fx()
	queue_redraw()

func _physics_process(dt: float) -> void:
	if not game.variety._battle_active():
		if in_battle: clear_combat_effects()
		return
	in_battle = true
	clock = fmod(clock+dt,60)
	var start := epoch
	for id in profiles.keys():
		cooldowns[id] -= dt
		if cooldowns[id] > 0: continue
		var interval: float = profiles[id].interval
		var fired := cast(id)
		if start != epoch: return
		cooldowns[id] = interval if fired else 0.18
	advance(dt)
	queue_redraw()

func live(actor) -> bool:
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.is_in_group("EnemyGroup") and (not actor.has_method("vulnerable") or actor.vulnerable())

func closest(origin: Vector2, reach: float, prefer_small := false) -> Node2D:
	var best: Node2D
	var score := INF
	for actor in CombatTargets.in_radius(origin,reach*reach,game):
		if not live(actor): continue
		var distance := origin.distance_squared_to(actor.global_position)
		if prefer_small and actor.get("pocket_small_left") != null and actor.pocket_small_left > 0: distance -= reach*reach
		if distance < score:
			score = distance
			best = actor
	return best

func swept(a: Vector2, b: Vector2, radius: float) -> Array[Node2D]:
	var hits: Array[Node2D] = []
	CombatTargets.fill_in_bounds(Rect2(a,b-a).abs().grow(radius+1),game,hits)
	var result: Array[Node2D] = []
	for actor in hits:
		if not live(actor): continue
		var point := a if a.is_equal_approx(b) else Geometry2D.get_closest_point_to_segment(actor.global_position,a,b)
		if point.distance_squared_to(actor.global_position) <= radius*radius: result.append(actor)
	return result

func hit(actor, damage: float, direction: Vector2) -> void:
	if live(actor): actor.apply_hit({"damage":damage,"direction":direction,"source":self})

func play_cue(stream: AudioStream, pitch := 1.0) -> void:
	cue.stream = stream
	cue.pitch_scale = pitch
	cue.play()

func cast(_id: String) -> bool: return false
func advance(_dt: float) -> void: pass
func removed(_id: String) -> void: pass
func clear_fx() -> void: pass
