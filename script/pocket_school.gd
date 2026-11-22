extends "res://script/theme_skill_school.gd"
const BLUE := Color("#009fe3")
const CREAM := Color("#fff4a8")
var small_actors := {}
var rollers: Array[Dictionary] = []
var ray_at := Vector2.ZERO
var ray_dir := Vector2.RIGHT
var ray_left := 0.0
var ray_width := 0.0
var air_at := Vector2.ZERO
var air_dir := Vector2.RIGHT
var air_left := 0.0
var strike_left := 0.0
var strike_at := Vector2.ZERO
var enlarge_from := Vector2.ZERO
var enlarge_to := Vector2.ZERO
var enlarge_left := 0.0

func cast(id: String) -> bool:
	var at: Vector2=game.player.global_position
	var target:=closest(at,158 if id=="air_cannon" else 250,id=="air_cannon" and game.equipment_panel.pocket_active)
	if not live(target): return false
	var dir:=at.direction_to(target.global_position)
	if dir.is_zero_approx(): dir=Vector2.RIGHT
	var s: Dictionary=profiles[id]
	var generation:=epoch
	match id:
		"small_light":
			ray_at=at
			ray_dir=dir
			ray_left=0.27
			ray_width=s.radius
			for key in small_actors.keys():
				var actor=small_actors[key].get_ref()
				if not is_instance_valid(actor) or actor.pocket_small_left<=0: small_actors.erase(key)
			for actor in swept(at,at+dir*250,s.radius):
				var offset:=actor.global_position-at
				var along:=offset.dot(dir)
				if along<0 or along>250 or absf(offset.cross(dir))>ray_width*along/250+3: continue
				if actor.has_method("pocket_shrink") and actor.pocket_shrink(s.duration):
					small_actors[actor.get_instance_id()]=weakref(actor)
				hit(actor,s.damage,dir)
				if generation!=epoch: break
		"air_cannon":
			play_cue(preload("res://rogge_art/combat-fx/toon/pop.wav"))
			air_at=at
			air_dir=dir
			air_left=0.32
			var small: bool=target.get("pocket_small_left")!=null and target.pocket_small_left>0
			var big: bool=small and game.equipment_panel.pocket_active
			if target.has_method("pocket_launch") and target.pocket_launch(big):
				var sprite: Sprite2D=target.sprite_2d
				var frame_size:=sprite.texture.get_size()/Vector2(sprite.hframes,sprite.vframes)
				var ball:=_roller("body",target.global_position,dir,24 if big else 11,s.damage,s.range*(1.45 if big else (1.18 if small else 1)),maxi(6,s.count) if big else int(s.count))
				ball.actor=target
				ball.texture=sprite.texture
				ball.frame=Rect2(Vector2(sprite.frame_coords)*frame_size,frame_size)
				ball.super_ball=big
				if big: _enlarge(at,ball.at)
				ball.seen[target.get_instance_id()]=true
				rollers.append(ball)
			hit(target,s.damage,dir)
		"big_light":
			var coin: Node2D
			var best:=155.0*155
			for item in game._xp_actors:
				if not is_instance_valid(item) or item.is_queued_for_deletion() or item.is_collecting or item.start_pick: continue
				var dist:=at.distance_squared_to(item.global_position)
				if dist<best:
					best=dist
					coin=item
			var from:=coin.global_position if coin else at
			var aim:=from.direction_to(target.global_position)
			var ball:=_roller("marble",from,aim if not aim.is_zero_approx() else dir,s.radius,s.damage,258,12)
			_enlarge(at,from if coin else at+dir*15)
			ball.coin=coin
			ball.gold=is_instance_valid(coin)
			rollers.append(ball)
	return true

func _enlarge(from: Vector2, to: Vector2) -> void:
	enlarge_from=from
	enlarge_to=to
	enlarge_left=0.3

func _roller(kind: String, at: Vector2, dir: Vector2, radius: float, damage: float, distance: float, count: int) -> Dictionary:
	return {"kind":kind,"at":at,"dir":dir,"radius":radius,"damage":damage,"left":distance,"count":count,"seen":{},"hits":0,"angle":0.0,"actor":null,"coin":null,"gold":false,"super_ball":false}

func _release(ball: Dictionary) -> void:
	if is_instance_valid(ball.actor): ball.actor.pocket_land()

func _strike(ball: Dictionary) -> void:
	play_cue(preload("res://rogge_art/combat-fx/toon/strike.wav"))
	strike_at=ball.at
	strike_left=0.65
	var generation:=epoch
	for actor in CombatTargets.in_radius(strike_at,62*62,game):
		hit(actor,ball.damage,strike_at.direction_to(actor.global_position))
		if epoch!=generation: return

func advance(dt: float) -> void:
	enlarge_left=maxf(0,enlarge_left-dt)
	ray_left=maxf(0,ray_left-dt)
	air_left=maxf(0,air_left-dt)
	strike_left=maxf(0,strike_left-dt)
	var generation:=epoch
	for i in range(rollers.size()-1,-1,-1):
		var ball:=rollers[i]
		var from: Vector2=ball.at
		var step:=minf(ball.left,dt*(395 if ball.kind=="body" else 270))
		ball.left-=step
		ball.at=from+ball.dir*step
		if live(ball.actor):
			var obstacle = ball.actor.move_and_collide(ball.dir*step)
			ball.at=ball.actor.global_position
			if obstacle: ball.left=0
		if is_instance_valid(ball.coin) and not ball.coin.start_pick and not ball.coin.is_collecting: ball.coin.global_position=ball.at
		ball.angle+=step/ball.radius
		for actor in swept(from,ball.at,ball.radius):
			var key:=actor.get_instance_id()
			if ball.seen.has(key): continue
			ball.seen[key]=true
			ball.hits+=1
			hit(actor,ball.damage,ball.dir)
			if epoch!=generation: return
			if ball.super_ball and ball.hits==5:
				_strike(ball)
				if epoch!=generation: return
			if ball.hits>=ball.count: break
		if ball.left<=0 or ball.hits>=ball.count:
			_release(ball)
			rollers.remove_at(i)

func removed(id: String) -> void:
	if id=="small_light": _clear_small()
	for i in range(rollers.size()-1,-1,-1):
		if (id=="air_cannon" and rollers[i].kind=="body") or (id=="big_light" and rollers[i].kind=="marble"):
			_release(rollers[i])
			rollers.remove_at(i)

func _clear_small() -> void:
	for ref in small_actors.values():
		var actor=ref.get_ref()
		if is_instance_valid(actor): actor.pocket_restore()
	small_actors.clear()

func clear_fx() -> void:
	for ball in rollers: _release(ball)
	rollers.clear()
	_clear_small()
	ray_left=0
	air_left=0
	strike_left=0
	enlarge_left=0

func has_visible_fx() -> bool:
	return enlarge_left > 0 or ray_left > 0 or air_left > 0 or strike_left > 0 or not rollers.is_empty()

func _draw() -> void:
	if enlarge_left>0:
		var t:=1-enlarge_left/0.3
		var wing:=enlarge_from.direction_to(enlarge_to).orthogonal()*(6+10*t)
		if enlarge_from.distance_squared_to(enlarge_to)>1:
			draw_colored_polygon(PackedVector2Array([enlarge_from,enlarge_to-wing,enlarge_to+wing]),Color("#f4b7d2",enlarge_left))
		draw_arc(enlarge_to,6+20*t,0,TAU,24,Color("#ffecac",1-t),2)
	if ray_left>0:
		var end:=ray_at+ray_dir*250
		var side:=ray_dir.orthogonal()*ray_width
		draw_colored_polygon(PackedVector2Array([ray_at,end-side,end+side]),Color(CREAM,ray_left*0.7))
		draw_line(ray_at,end-side,Color(CREAM,ray_left*2),1)
		draw_line(ray_at,end+side,Color(CREAM,ray_left*2),1)
	if air_left>0:
		for i in 3:
			var t:=clampf(1-air_left/0.32-i*0.13,0,1)
			draw_set_transform(air_at+air_dir*(12+t*134),air_dir.angle(),Vector2(0.37,1))
			draw_arc(Vector2.ZERO,8+t*13,-2.6,2.6,18,Color("#d7fcff",1-t),3)
		draw_set_transform(Vector2.ZERO)
	for ball in rollers:
		var r:float=ball.radius
		draw_set_transform(ball.at,0,Vector2(1,0.34))
		draw_circle(Vector2(0,3),r*0.88,Color(0.05,0.09,0.14,0.4))
		var center:Vector2=ball.at+Vector2.UP*(r*0.48)
		draw_set_transform(center,ball.angle,Vector2.ONE)
		if ball.kind=="body":
			draw_texture_rect_region(ball.texture,Rect2(-Vector2.ONE*r,Vector2.ONE*2*r),ball.frame)
			if ball.super_ball:
				draw_arc(Vector2.ZERO,r,-1.6,0.6,16,BLUE,3)
				draw_arc(Vector2.ZERO,r,1.5,3.2,12,Color.WHITE,2)
		else:
			var fill:=Color("#edb54b") if ball.gold else Color("#88a6b4")
			draw_circle(Vector2.ZERO,r,Color("#263a51"))
			draw_circle(Vector2.ZERO,r-2,fill)
			draw_arc(Vector2.ZERO,r*0.64,0.1,2.8,14,BLUE,3)
			draw_circle(Vector2(-r*0.32,-r*0.38),3,Color.WHITE)
		draw_set_transform(Vector2.ZERO)
	if strike_left>0:
		var t:=1-strike_left/0.65
		for i in 8:
			var dir:=Vector2.from_angle(i*TAU/8)
			var pos:=strike_at+dir*(12+45*t)
			draw_line(pos-dir*5,pos+dir*5,CREAM,3)
			draw_line(pos-dir.orthogonal()*3,pos+dir.orthogonal()*3,Color.WHITE,2)
		draw_string(UiFonts.ui_bold(),strike_at+Vector2(-28,-18-12*t),L10n.text("全中！"),HORIZONTAL_ALIGNMENT_LEFT,-1,16,CREAM)
