extends "res://script/theme_skill_school.gd"

const ORANGE := Color("#ff8332")
const GOLD := Color("#ffdc60")
const KI := Color("#62d9ff")
var window := 0.0
var flash := 0.0
var flash_at := Vector2.ZERO
var flash_radius := 0.0
var blind_actors := {}
var mark: Node2D
var delayed := -1.0
var echo_at := Vector2.ZERO
var echo_left := 0.0
var echo_texture: Texture2D
var echo_size := Vector2.ZERO
var charge := 0.0
var charge_aim := Vector2.RIGHT
var discs: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var combo_stamp := 0
var combo_hits := {}
var impact_at := Vector2.ZERO
var impact := 0.0

func _ready() -> void:
	super()
	game.player.dash_started.connect(_dash)

func _direction(a: Vector2,b: Vector2) -> Vector2:
	return Vector2.RIGHT if a.is_equal_approx(b) else a.direction_to(b)

func _crowd_direction(origin: Vector2, nearest: Node2D) -> Vector2:
	var counts := PackedInt32Array()
	counts.resize(12)
	var dirs: Array[Vector2] = []
	dirs.resize(12)
	dirs.fill(Vector2.ZERO)
	for actor in CombatTargets.in_radius(origin,330*330,game):
		if not live(actor): continue
		var dir := _direction(origin,actor.global_position)
		var bin := posmod(roundi(dir.angle()*12/TAU),12)
		counts[bin] += 1
		dirs[bin] += dir
	var best := 0
	for i in 12:
		if counts[i]>counts[best]: best=i
	return dirs[best].normalized() if counts[best] else _direction(origin,nearest.global_position)

func cast(id: String) -> bool:
	var s: Dictionary = profiles[id]
	var at: Vector2 = game.player.global_position
	var target := closest(at,s.get("radius",88) if id=="solar_flare" else 320)
	if target == null: return false
	var generation := epoch
	match id:
		"solar_flare":
			for key in blind_actors.keys():
				var old = blind_actors[key].get_ref()
				if not is_instance_valid(old) or old.solar_blind_left<=0: blind_actors.erase(key)
			flash_at = at
			flash_radius = s.radius
			flash = 0.28
			mark = target
			if game.equipment_panel.dragon_active: window = 1.65
			for actor in CombatTargets.in_radius(at,s.radius*s.radius,game):
				if not live(actor): continue
				if actor.has_method("solar_blind") and actor.solar_blind(s.duration):
					blind_actors[actor.get_instance_id()] = weakref(actor)
				hit(actor,s.damage,_direction(at,actor.global_position))
				if epoch != generation: break
		"kienzan": _disc(at,_direction(at,target.global_position),s,0)
		"kamehameha":
			play_cue(preload("res://rogge_art/combat-fx/toon/qi.wav"))
			charge_aim = _crowd_direction(at,target)
			charge = 0.36
	return true

func _dash(at: Vector2) -> void:
	if window<=0 or not game.equipment_panel.dragon_active or not game.variety._battle_active(): return
	window=0
	delayed=0.22
	echo_at=at
	echo_left=0.86
	var sprite: AnimatedSprite2D = game.player.animated_sprite_2d
	echo_texture=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
	echo_size=echo_texture.get_size()*sprite.global_scale.abs()
	if sprite.flip_h: echo_size.x *= -1

func _disc(at: Vector2, dir: Vector2, s: Dictionary, stamp: int) -> void:
	discs.append({"at":at,"dir":dir,"radius":s.radius,"damage":s.damage,"remaining":int(s.count),"life":0.68,"seen":{},"stamp":stamp})

func _beam(at: Vector2, dir: Vector2, s: Dictionary, stamp: int) -> void:
	beams.append({"at":at,"dir":dir,"radius":s.radius,"damage":s.damage,"left":s.duration,"tick":0.0,"stamp":stamp})

func _tag(actor: Node2D, stamp: int, part: int, damage: float) -> void:
	if stamp == 0 or stamp != combo_stamp or not live(actor): return
	var key := actor.get_instance_id()
	var old := int(combo_hits.get(key,0))
	combo_hits[key]=old|part
	if old!=3 and (old|part)==3:
		impact_at=actor.global_position
		impact=0.24
		hit(actor,damage,Vector2.ZERO)

func advance(dt: float) -> void:
	var generation := epoch
	window=maxf(0,window-dt)
	flash=maxf(0,flash-dt)
	impact=maxf(0,impact-dt)
	echo_left=maxf(0,echo_left-dt)
	if charge>0:
		charge-=dt
		if charge<=0 and profiles.has("kamehameha"): _beam(game.player.global_position,charge_aim,profiles.kamehameha,0)
	if delayed>=0:
		delayed-=dt
		if delayed<0 and game.equipment_panel.dragon_active:
			var at: Vector2 = game.player.global_position
			if not live(mark): mark=closest(at,330)
			if live(mark):
				play_cue(preload("res://rogge_art/combat-fx/toon/qi.wav"),1.24)
				combo_stamp+=1
				combo_hits.clear()
				_disc(at,_direction(at,mark.global_position),profiles.kienzan,combo_stamp)
				_beam(echo_at,_direction(echo_at,mark.global_position),profiles.kamehameha,combo_stamp)
	for i in range(discs.size()-1,-1,-1):
		var disc:=discs[i]
		var from: Vector2=disc.at
		disc.at=from+disc.dir*540*dt
		disc.life-=dt
		for actor in swept(from,disc.at,disc.radius):
			var key:=actor.get_instance_id()
			if disc.seen.has(key): continue
			disc.seen[key]=true
			disc.remaining-=1
			hit(actor,disc.damage,disc.dir)
			if generation!=epoch:return
			_tag(actor,disc.stamp,1,disc.damage)
			if generation!=epoch:return
			if disc.remaining<=0: break
		if disc.life<=0 or disc.remaining<=0: discs.remove_at(i)
	for i in range(beams.size()-1,-1,-1):
		var beam:=beams[i]
		beam.left-=dt
		beam.tick-=dt
		if beam.tick<=0:
			beam.tick+=0.14
			for actor in swept(beam.at,beam.at+beam.dir*330,beam.radius):
				hit(actor,beam.damage,beam.dir)
				if generation!=epoch:return
				_tag(actor,beam.stamp,2,beam.damage)
				if generation!=epoch:return
		if beam.left<=0: beams.remove_at(i)

func removed(id: String) -> void:
	window=0
	delayed=-1
	combo_stamp+=1
	if id=="solar_flare": _release_blind()
	if id=="kienzan": discs.clear()
	if id=="kamehameha":
		charge=0
		beams.clear()

func _release_blind() -> void:
	for ref in blind_actors.values():
		var enemy = ref.get_ref()
		if is_instance_valid(enemy): enemy.solar_blind_left=0
	blind_actors.clear()

func clear_fx() -> void:
	_release_blind()
	mark=null
	charge=0
	window=0
	delayed=-1
	flash=0
	impact=0
	echo_left=0
	discs.clear()
	beams.clear()
	combo_hits.clear()

func _draw() -> void:
	if flash>0:
		var t:=1-flash/0.28
		for i in 14:
			var dir:=Vector2.from_angle(TAU*i/14)
			var side:=dir.orthogonal()*3*(1-t)
			var a:=flash_at+dir*(9+20*t)
			draw_colored_polygon(PackedVector2Array([a+side,flash_at+dir*(25+flash_radius*0.65*t)*(1 if i%2 else 0.78),a-side]),Color(GOLD,1-t))
	if window>0: draw_arc(game.player.global_position,19,-PI*0.5,-PI*0.5+TAU*window/1.65,22,ORANGE,2)
	if echo_left>0 and echo_texture:
		draw_set_transform(echo_at,0,Vector2(signf(echo_size.x),1))
		draw_texture_rect(echo_texture,Rect2(-echo_size.abs()*0.5,echo_size.abs()),false,Color(1,0.63,0.25,0.62*minf(1,echo_left*5)))
		draw_set_transform(Vector2.ZERO)
	if charge>0:
		var center: Vector2=game.player.global_position+charge_aim*14
		draw_circle(center,5+7*(1-charge/0.36),Color(KI,0.6))
		draw_circle(center,4,Color.WHITE)
	for beam in beams:
		var end: Vector2=beam.at+beam.dir*330
		var side: Vector2=beam.dir.orthogonal()
		var outer:=PackedVector2Array()
		for k in 10:
			var x:=k/9.0
			outer.append(beam.at.lerp(end,x)+side*beam.radius*(0.85+0.18*sin(x*24-clock*38)))
		for k in range(9,-1,-1):
			var x:=k/9.0
			outer.append(beam.at.lerp(end,x)-side*beam.radius*(0.85+0.18*cos(x*21-clock*31)))
		draw_colored_polygon(outer,Color(KI,0.52))
		draw_circle(beam.at,beam.radius*1.45,KI)
		draw_circle(beam.at,beam.radius*0.9,Color.WHITE)
		draw_line(beam.at,end,KI,beam.radius*1.4)
		draw_line(beam.at,end,Color("#efffff"),beam.radius*(0.55+0.13*sin(clock*45)))
		draw_circle(end,beam.radius,KI)
		for j in 4:
			var pos:Vector2=beam.at.lerp(end,fposmod(clock*1.7+j*0.25,1.0))
			draw_set_transform(pos,beam.dir.angle(),Vector2(0.3,1))
			draw_arc(Vector2.ZERO,beam.radius*1.2,-1.8,1.8,12,Color("#c3f6ff"),2)
		draw_set_transform(Vector2.ZERO)
	for disc in discs:
		var side:Vector2=disc.dir.orthogonal()
		for i in [-1,1]:
			var tip:Vector2=disc.at+side*(i*disc.radius*0.64)
			draw_line(tip-disc.dir*23,tip,Color(GOLD,0.55),2)
		draw_set_transform(disc.at,disc.dir.angle(),Vector2(0.4,1))
		draw_circle(Vector2.ZERO,disc.radius,GOLD)
		draw_arc(Vector2.ZERO,disc.radius-2,clock*18,clock*18+4.3,18,Color.WHITE,2)
		draw_set_transform(Vector2.ZERO)
	if impact>0:
		for i in 6:
			var dir:=Vector2.from_angle(i*TAU/6)
			draw_line(impact_at+dir*6,impact_at+dir*(9+22*impact/0.24),ORANGE,3)
