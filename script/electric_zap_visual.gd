extends RefCounted
# Cached skeleton geometry per zap; one reused ring buffer, no particle/light nodes.
var _ring := PackedVector2Array()
func _init() -> void: _ring.resize(25)

func profile(actor: Node2D) -> Dictionary:
	var kind: StringName = &"person"
	var size := Vector2(20,28)
	var sprite: Node2D = actor.get("sprite_2d") if "sprite_2d" in actor else actor.get("animated_sprite_2d")
	var boss := "boss_current_health" in actor
	if boss:
		if "element" in actor: kind = [&"elephant",&"lion",&"bird",&"turtle"][actor.element]
		elif "attack_state" in actor: kind = &"knight"
		else: kind = &"dinosaur"
		if sprite != null:
			size = sprite.get_rect().size*sprite.global_scale.abs()*0.75
			size = size.clamp(Vector2(60,65),Vector2(160,160))
	elif "archetype" in actor:
		kind = [&"small",&"runner",&"tank",&"eye"][actor.archetype]
		size = Vector2(20,22)*clampf(actor.body_scale,0.4,3.0)
	var bones := PackedVector2Array()
	var skull := Vector2(0,-0.3)
	var skull_size := Vector2(0.18,0.16)
	match kind:
		&"dinosaur":
			skull = Vector2(0.23,-0.25)
			skull_size = Vector2(0.22,0.15)
			_chain(bones,[Vector2(0.1,-0.15),Vector2(-0.06,0.08),Vector2(-0.3,0.16),Vector2(-0.48,0.04)])
			_chain(bones,[Vector2(0.05,0.08),Vector2(0.22,0.24),Vector2(0.12,0.42),Vector2(0.3,0.42)])
			_chain(bones,[Vector2(-0.1,0.1),Vector2(-0.22,0.3),Vector2(-0.12,0.42)])
			_chain(bones,[Vector2(0.08,-0.12),Vector2(0.25,0),Vector2(0.34,-0.05)])
			for i in 4:
				var y := -0.1+i*0.06
				_chain(bones,[Vector2(-0.12,y),Vector2(0.08,y+0.03),Vector2(0.16,y)])
		&"bird":
			skull_size = Vector2(0.13,0.13)
			_chain(bones,[Vector2(0,-0.17),Vector2(0,0.32)])
			for side in [-1,1]:
				_chain(bones,[Vector2(0,-0.08),Vector2(side*0.22,-0.25),Vector2(side*0.48,-0.16)])
				for i in 4:
					_chain(bones,[Vector2(side*(0.18+i*0.08),-0.23+i*0.02),Vector2(side*(0.12+i*0.11),0.14+i*0.025)])
				_chain(bones,[Vector2(0,0.18),Vector2(side*0.1,0.33),Vector2(side*0.2,0.36)])
			_chain(bones,[Vector2(0.08,-0.3),Vector2(0.23,-0.26),Vector2(0.08,-0.23)])
		&"turtle":
			skull = Vector2(0,-0.37)
			skull_size = Vector2(0.13,0.11)
			_chain(bones,[Vector2(0,-0.26),Vector2(0,0.35)])
			for side in [-1,1]:
				_chain(bones,[Vector2(0,-0.22),Vector2(side*0.3,-0.13),Vector2(side*0.34,0.14),Vector2(0,0.32)])
				for y in [-0.1,0.04,0.18]: _chain(bones,[Vector2(0,y),Vector2(side*0.3,y-0.02)])
				for y in [-0.12,0.22]: _chain(bones,[Vector2(side*0.27,y),Vector2(side*0.44,y+0.06),Vector2(side*0.4,y+0.15)])
		&"elephant", &"lion":
			skull_size = Vector2(0.22,0.18) if kind==&"elephant" else Vector2(0.19,0.16)
			_chain(bones,[Vector2(0,-0.14),Vector2(0,0.28)])
			for side in [-1,1]:
				for y in [-0.08,0.02,0.12]: _chain(bones,[Vector2(0,y),Vector2(side*0.25,y-0.02),Vector2(side*0.2,y+0.04)])
				for x in [0.16,0.3]: _chain(bones,[Vector2(side*x,0.1),Vector2(side*(x+0.02),0.27),Vector2(side*(x+0.07),0.4)])
				if kind==&"elephant": _chain(bones,[Vector2(side*0.15,-0.22),Vector2(side*0.29,-0.1),Vector2(side*0.33,-0.23)])
			if kind==&"elephant": _chain(bones,[Vector2(0,-0.22),Vector2(0.02,-0.08),Vector2(-0.06,0.06),Vector2(-0.13,0.02)])
			else: _chain(bones,[Vector2(0.17,0.2),Vector2(0.38,0.14),Vector2(0.46,-0.05),Vector2(0.4,-0.14)])
		&"eye":
			skull = Vector2(0,-0.1)
			skull_size = Vector2(0.3,0.26)
			for side in [-1,0,1]: _chain(bones,[Vector2(side*0.12,0.15),Vector2(side*0.22,0.29),Vector2(side*0.3+0.05,0.4)])
		_:
			var chest := 0.32 if kind==&"tank" else (0.25 if kind==&"knight" else 0.18)
			if kind==&"small": skull_size = Vector2(0.24,0.2)
			if kind==&"runner": skull_size = Vector2(0.16,0.14)
			_chain(bones,[Vector2(0,-0.15),Vector2(0,0.22)])
			for side in [-1,1]:
				for y in [-0.08,0.02,0.12]: _chain(bones,[Vector2(0,y),Vector2(side*chest,y-0.02),Vector2(side*chest*0.8,y+0.04)])
				_chain(bones,[Vector2(side*chest,-0.1),Vector2(side*(chest+0.12),0.07),Vector2(side*(chest+0.08),0.22)])
				_chain(bones,[Vector2(0,0.2),Vector2(side*0.18,0.3),Vector2(side*(0.26 if kind==&"runner" else 0.15),0.47)])
				if kind==&"knight": _chain(bones,[Vector2(side*0.15,-0.35),Vector2(side*0.22,-0.45),Vector2(side*0.09,-0.4)])
	for i in bones.size(): bones[i] *= size
	return {"kind":kind,"size":size,"bones":bones,"skull":skull*size,"skull_size":skull_size*size,"boss":boss,"seed":float(actor.get_instance_id()%1009),"sprite":weakref(sprite) if sprite!=null else null}

func _chain(points: PackedVector2Array, chain: Array) -> void:
	for i in range(1,chain.size()):
		points.append(chain[i-1])
		points.append(chain[i])

func ring_points(size: Vector2, clock: float, seed: float) -> PackedVector2Array:
	for i in 24:
		var angle := TAU*i/24.0
		var jitter := 1.0+0.12*sin(i*2.7+floor(clock*22)*2.3+seed)+0.07*cos(i*4.1+clock*17+seed)
		_ring[i] = Vector2.from_angle(angle)*(size*0.57+Vector2.ONE*6)*jitter
	_ring[24] = _ring[0]
	return _ring

func draw(canvas: Node2D, actor: Node2D, data: Dictionary, clock: float) -> void:
	var at := actor.global_position
	var facing := 1.0
	var sprite = data.sprite.get_ref() if data.sprite!=null else null
	if is_instance_valid(sprite):
		at = sprite.global_position
		if sprite.flip_h: facing = -1
	var color := GamePalette.HIT_FLASH_WHITE
	color.a = 0.9 if int(clock*18+data.seed)%2==0 else 0.55
	canvas.draw_set_transform(at,0,Vector2(facing,1))
	var ring := ring_points(data.size,clock,data.seed)
	canvas.draw_polyline(ring,Color(GamePalette.ENEMY_ORANGE,0.45),4.0 if data.boss else 3.0)
	canvas.draw_polyline(ring,Color(GamePalette.HIT_FLASH_WHITE,0.9),1.4 if data.boss else 0.9)
	var width := 2.2 if data.boss else 1.15
	canvas.draw_multiline(data.bones,Color(GamePalette.INK,0.9),width+2)
	canvas.draw_multiline(data.bones,color,width)
	var head: Vector2 = data.skull_size
	canvas.draw_set_transform(at+Vector2(facing*data.skull.x,data.skull.y),0,head)
	canvas.draw_circle(Vector2.ZERO,1,color)
	canvas.draw_set_transform(at,0,Vector2(facing,1))
	if data.kind==&"eye": canvas.draw_circle(data.skull,head.y*0.35,GamePalette.INK)
	else:
		for side in [-1,1]: canvas.draw_circle(data.skull+Vector2(side*head.x*0.4,-head.y*0.12),maxf(1,head.y*0.23),GamePalette.INK)
	canvas.draw_set_transform(Vector2.ZERO)
