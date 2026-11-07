extends MultiMeshInstance2D

const MAX_STAINS := 128
const MAX_PER_FRAME := 20
const HOLD_SECONDS := 2.0
const FADE_SECONDS := 0.5
const LIFETIME := HOLD_SECONDS + FADE_SECONDS
const TILE_SIZE := 32
const VARIANTS := 12
const TEXTURE_CACHE_LIMIT := 32
const BURN := Color(0.56, 0.16, 0.085)
const POISON := Color(0.48, 0.17, 0.43)
const FROST := Color(0.17, 0.43, 0.54)
const SHOCK := Color(0.34, 0.25, 0.49)
const CHAR := Color(0.43, 0.16, 0.07)
const VOID := Color(0.26, 0.16, 0.34)
static var _atlas: Texture2D
static var _material: ShaderMaterial
static var _texture_colors: Dictionary = {}
static var textures_sampled := 0

class Stamp:
	extends RefCounted
	var at := Vector2.ZERO
	var tint := Color.WHITE
	var rotation := 0.0
	var size := Vector2.ONE
	var age := LIFETIME
	var variant := 0

var stamps: Array[Stamp] = []
var emitted := 0
var suppressed := 0
var active_count := 0
var _next := 0
var _frame := -1
var _in_frame := 0
var _redraw_left := 0.0
var _rng := RandomNumberGenerator.new()

static func texture_color(source: Texture2D) -> Color:
	if source == null: return Color(0.64, 0.28, 0.42)
	var key := source.resource_path
	if key.is_empty(): return Color(0.64, 0.28, 0.42)
	if _texture_colors.has(key): return _texture_colors[key]
	if _texture_colors.size() >= TEXTURE_CACHE_LIMIT: return Color(0.64, 0.28, 0.42)
	var picture := source.get_image()
	var sum := Vector3.ZERO
	var weight := 0.0
	if picture != null and not picture.is_empty():
		if picture.is_compressed(): picture.decompress()
		for y in 16:
			for x in 16:
				var color := picture.get_pixel(mini(picture.get_width()-1, int((x+0.5)*picture.get_width()/16.0)), mini(picture.get_height()-1, int((y+0.5)*picture.get_height()/16.0)))
				var amount := color.a * color.s * color.s * color.v
				sum += Vector3(color.r,color.g,color.b) * amount
				weight += amount
	var result := Color(0.64,0.28,0.42) if weight < 0.01 else Color(sum.x/weight,sum.y/weight,sum.z/weight)
	_texture_colors[key] = result
	textures_sampled += 1
	return result

static func color_for(body: Color, effect: StringName = &"") -> Color:
	match effect:
		&"burn": return BURN
		&"poison_trail": return POISON
		&"freeze": return FROST
		&"shock", &"lightning": return SHOCK
		&"bomb": return CHAR
		&"black_hole": return VOID
	var bounded := body.clamp(Color.BLACK,Color.WHITE)
	# Dark body pigment, not the transient white hit flash or a neon pickup color.
	bounded = bounded.lerp(Color(bounded.get_luminance(),bounded.get_luminance(),bounded.get_luminance()),0.14)
	return bounded.darkened(0.26)

static func _ellipse(picture: Image, center: Vector2, radius: Vector2, tint: Color) -> void:
	for y in range(maxi(0,int(center.y-radius.y)),mini(picture.get_height(),int(ceil(center.y+radius.y+1)))):
		for x in range(maxi(0,int(center.x-radius.x)),mini(picture.get_width(),int(ceil(center.x+radius.x+1)))):
			if ((Vector2(x+0.5,y+0.5)-center)/radius).length_squared()<=1.0:
				picture.set_pixel(x,y,tint)

static func _shared_atlas() -> Texture2D:
	if _atlas != null: return _atlas
	var picture := Image.create(TILE_SIZE*4,TILE_SIZE*3,false,Image.FORMAT_RGBA8)
	picture.fill(Color.TRANSPARENT)
	var random := RandomNumberGenerator.new()
	random.seed = 969073
	for i in VARIANTS:
		var origin := Vector2((i%4)*TILE_SIZE, int(i/4)*TILE_SIZE)
		var center := origin+Vector2(15,17)
		_ellipse(picture,center,Vector2(random.randf_range(5.5,7),random.randf_range(3.5,5)),Color(1,1,1,0.9))
		for _blob in 5:
			_ellipse(picture,center+Vector2(random.randf_range(-5,5),random.randf_range(-3,3)),Vector2(random.randf_range(2,4.5),random.randf_range(1.5,3)),Color(1,1,1,0.76))
		for _drop in 8:
			var angle := random.randf_range(-1.2,1.2)
			var point := center+Vector2.from_angle(angle)*random.randf_range(7.5,13)
			_ellipse(picture,point,Vector2(random.randf_range(0.65,1.8),random.randf_range(0.65,1.4)),Color(1,1,1,random.randf_range(0.45,0.85)))
		_ellipse(picture,center+Vector2(-1,0),Vector2(3.2,2.2),Color(0.7,0.7,0.7,0.95))
	_atlas = ImageTexture.create_from_image(picture)
	return _atlas

func _ready() -> void:
	z_as_relative = false
	z_index = -3
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture = _shared_atlas()
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/death_stains.gdshader")
	material = _material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*TILE_SIZE
	multimesh.mesh = quad
	multimesh.instance_count = MAX_STAINS
	for _i in MAX_STAINS: stamps.append(Stamp.new())
	_rng.randomize()
	reset()

func reset() -> void:
	for i in MAX_STAINS:
		stamps[i].age = LIFETIME
		multimesh.set_instance_color(i,Color.TRANSPARENT)
		multimesh.set_instance_transform_2d(i,Transform2D(0,Vector2.ZERO,0,Vector2.ZERO))
	multimesh.visible_instance_count = 0
	emitted = 0
	suppressed = 0
	active_count = 0
	_next = 0
	_frame = -1
	_in_frame = 0
	_redraw_left = 0
	set_process(false)

func splat(at: Vector2, body: Color, effect: StringName = &"", direction: Vector2 = Vector2.ZERO, body_size: float = 1.0) -> bool:
	if get_tree().paused or not get_parent().is_processing(): return false
	var frame := Engine.get_process_frames()
	if frame != _frame:
		_frame = frame
		_in_frame = 0
	if _in_frame >= MAX_PER_FRAME:
		suppressed += 1
		return false
	_in_frame += 1
	var stamp := stamps[_next]
	if stamp.age >= LIFETIME: active_count += 1
	stamp.at = to_local(at)
	stamp.tint = color_for(body,effect)
	stamp.tint.a = _rng.randf_range(0.68,0.85)
	stamp.rotation = _rng.randf_range(-PI,PI) if direction.is_zero_approx() else direction.angle()+_rng.randf_range(-0.8,0.8)
	stamp.size = Vector2(_rng.randf_range(0.8,1.25),_rng.randf_range(0.65,1.0))*clampf(body_size,0.65,1.8)
	stamp.age = 0
	stamp.variant = _rng.randi_range(0,VARIANTS-1)
	multimesh.set_instance_custom_data(_next,Color(float(stamp.variant)/float(VARIANTS-1),0,0,0))
	_sync_stamp(_next)
	_next = (_next+1)%MAX_STAINS
	emitted += 1
	multimesh.visible_instance_count = MAX_STAINS
	set_process(true)
	return true

static func opacity_at(age: float) -> float:
	return clampf((LIFETIME-age)/FADE_SECONDS,0,1)

func _sync_stamp(index: int) -> void:
	var stamp := stamps[index]
	var progress := clampf(stamp.age/0.12,0,1)
	var spread := lerpf(0.72,1.0,1.0-pow(1.0-progress,3))
	multimesh.set_instance_transform_2d(index,Transform2D(stamp.rotation,stamp.size*spread,0,stamp.at))
	var tint := stamp.tint
	tint.a *= opacity_at(stamp.age)
	multimesh.set_instance_color(index,tint)

func _process(delta: float) -> void:
	if get_tree().paused: return
	var seconds := delta/maxf(Engine.time_scale,0.001)
	_redraw_left -= seconds
	var update := _redraw_left <= 0
	if update: _redraw_left = 1.0/30.0
	for i in MAX_STAINS:
		var stamp := stamps[i]
		if stamp.age >= LIFETIME: continue
		var previous := stamp.age
		stamp.age = minf(LIFETIME,stamp.age+seconds)
		if stamp.age >= LIFETIME:
			active_count -= 1
			multimesh.set_instance_color(i,Color.TRANSPARENT)
		elif update and (previous<0.12 or stamp.age>HOLD_SECONDS):
			_sync_stamp(i)
	if active_count == 0:
		multimesh.visible_instance_count = 0
		set_process(false)
