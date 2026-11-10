extends MultiMeshInstance2D

const MAX_STAINS := 128
const MAX_PER_FRAME := 20
const HOLD_SECONDS := 2.0
const FADE_SECONDS := 0.5
const LIFETIME := HOLD_SECONDS + FADE_SECONDS
const TILE_SIZE := 32
const VARIANTS := 48
const ATLAS_COLUMNS := 8
const ATLAS_ROWS := 7
const DROP_VARIANTS := 8
const PARTS_PER_STAIN := 8
const AIR_SECONDS := 0.42
const SIZE_MULTIPLIER := 2.0
# Stable species pigments, independent of hit flashes, status and killing weapon.
const PALETTE := {
	&"chaser": Color("ff52ce"),
	&"chaser_brute": Color("a47cff"),
	&"dasher": Color("ff9b52"),
	&"tank": Color("5e8fff"),
	&"ranged": Color("40e6ee"),
	&"blade_mantis": Color("8cffbc"),
	&"boomerang_imp": Color("ff6de0"),
	&"spore_bomber": Color("779dff"),
	&"loot_courier": Color("f68cf0"),
	&"treasure_guardian": Color("d6f25b"),
	&"charger_boss": Color("ff70a6"),
	&"knight": Color("a0a4ff"),
	&"tide": Color("55cfff"),
	&"thunder": Color("e1a0ff"),
	&"gale": Color("69f0c8"),
	&"gale_ranged": Color("63f0b0"),
	&"gale_melee": Color("b5ed74"),
	&"aegis": Color("ffb47d"),
	&"power_trial": Color("e6f582"),
	&"speed_trial": Color("cc64ff"),
}
static var _atlas: Texture2D
static var _material: ShaderMaterial

class Drop:
	extends RefCounted
	var goal := Vector2.ZERO
	var flight := 0.25
	var delay := 0.0
	var lift := 5.0
	var rotation := 0.0
	var size := Vector2.ONE
	var variant := 0

class Stamp:
	extends RefCounted
	var at := Vector2.ZERO
	var tint := Color.WHITE
	var rotation := 0.0
	var size := Vector2.ONE
	var age := LIFETIME
	var variant := 0
	var pool_offset := Vector2.ZERO
	var drops: Array[Drop] = []
	func _init() -> void:
		for _i in PARTS_PER_STAIN - 1: drops.append(Drop.new())

var stamps: Array[Stamp] = []
var emitted := 0
var suppressed := 0
var active_count := 0
var _next := 0
var _frame := -1
var _in_frame := 0
var _redraw_left := 0.0
var _rng := RandomNumberGenerator.new()

static func color_for(kind: StringName) -> Color:
	return PALETTE.get(kind, PALETTE[&"chaser"])

static func _ellipse(picture: Image, center: Vector2, radius: Vector2, tint: Color) -> void:
	for y in range(maxi(0,int(center.y-radius.y)),mini(picture.get_height(),int(ceil(center.y+radius.y+1)))):
		for x in range(maxi(0,int(center.x-radius.x)),mini(picture.get_width(),int(ceil(center.x+radius.x+1)))):
			if ((Vector2(x+0.5,y+0.5)-center)/radius).length_squared()<=1.0:
				picture.set_pixel(x,y,tint)

static func _shared_atlas() -> Texture2D:
	if _atlas != null: return _atlas
	var picture := Image.create(TILE_SIZE*ATLAS_COLUMNS,TILE_SIZE*ATLAS_ROWS,false,Image.FORMAT_RGBA8)
	picture.fill(Color.TRANSPARENT)
	var random := RandomNumberGenerator.new()
	random.seed = 969073
	for i in VARIANTS:
		var origin := Vector2((i%ATLAS_COLUMNS)*TILE_SIZE, int(i/ATLAS_COLUMNS)*TILE_SIZE)
		var center := origin+Vector2(16,16)
		_ellipse(picture,center,Vector2(random.randf_range(4.2,7.5),random.randf_range(2.4,4.6)),Color(1,1,1,0.9))
		for _blob in random.randi_range(6,12):
			var angle := random.randf_range(0,TAU)
			var offset := Vector2(cos(angle)*random.randf_range(2,7),sin(angle)*random.randf_range(1,5))
			_ellipse(picture,center+offset,Vector2(random.randf_range(1,3.4),random.randf_range(0.8,2.7)),Color(1,1,1,random.randf_range(0.65,0.9)))
		_ellipse(picture,center+Vector2(random.randf_range(-2,2),random.randf_range(-1,1)),Vector2(random.randf_range(1.5,3.5),random.randf_range(1,2)),Color(0.65,0.65,0.65,0.95))
	for i in DROP_VARIANTS:
		var tile := VARIANTS+i
		var center := Vector2((tile%ATLAS_COLUMNS)*TILE_SIZE+16,int(tile/ATLAS_COLUMNS)*TILE_SIZE+16)
		_ellipse(picture,center,Vector2(random.randf_range(4,7.5),random.randf_range(1.6,3.3)),Color(1,1,1,0.9))
		_ellipse(picture,center+Vector2(-4,0),Vector2(5,random.randf_range(0.7,1.4)),Color(1,1,1,0.7))
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
	multimesh.instance_count = MAX_STAINS*PARTS_PER_STAIN
	for _i in MAX_STAINS: stamps.append(Stamp.new())
	_rng.randomize()
	reset()

func reset() -> void:
	for i in MAX_STAINS:
		stamps[i].age = LIFETIME
		_hide_stamp(i)
	multimesh.visible_instance_count = 0
	emitted = 0
	suppressed = 0
	active_count = 0
	_next = 0
	_frame = -1
	_in_frame = 0
	_redraw_left = 0
	set_process(false)

func splat(at: Vector2, tint: Color, direction: Vector2 = Vector2.ZERO, body_size: float = 1.0) -> bool:
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
	stamp.tint = tint
	stamp.tint.a = _rng.randf_range(0.68,0.85)
	var directed := not direction.is_zero_approx()
	var heading := direction.angle() if directed else _rng.randf_range(-PI,PI)
	stamp.rotation = heading+_rng.randf_range(-0.12,0.12) if directed else heading
	stamp.size = Vector2(_rng.randf_range(0.8,1.25),_rng.randf_range(0.65,1.0))*clampf(body_size,0.65,1.8)*SIZE_MULTIPLIER
	stamp.pool_offset = Vector2.from_angle(heading)*_rng.randf_range(1,4)*clampf(body_size,0.65,1.8) if directed else Vector2.ZERO
	stamp.age = 0
	stamp.variant = _rng.randi_range(0,VARIANTS-1)
	_set_tile(_next*PARTS_PER_STAIN,stamp.variant)
	for i in stamp.drops.size():
		var drop := stamp.drops[i]
		var angle := heading+_rng.randf_range(-0.4,0.4) if directed and i<5 else (heading+_rng.randf_range(-1.2,1.2) if directed else _rng.randf_range(-PI,PI))
		var reach := _rng.randf_range(15,38) if i<5 else _rng.randf_range(7,20)
		drop.goal = Vector2.from_angle(angle)*reach*clampf(body_size,0.65,1.8)
		drop.flight = _rng.randf_range(0.19,0.35)
		drop.delay = _rng.randf_range(0,0.045)
		drop.lift = _rng.randf_range(4,13)*clampf(body_size,0.65,1.8)
		drop.rotation = angle
		drop.size = Vector2(_rng.randf_range(0.18,0.36),_rng.randf_range(0.13,0.24))*clampf(body_size,0.65,1.8)*SIZE_MULTIPLIER
		drop.variant = VARIANTS+_rng.randi_range(0,DROP_VARIANTS-1)
		_set_tile(_next*PARTS_PER_STAIN+i+1,drop.variant)
	_sync_stamp(_next)
	_next = (_next+1)%MAX_STAINS
	emitted += 1
	multimesh.visible_instance_count = MAX_STAINS*PARTS_PER_STAIN
	set_process(true)
	return true

static func opacity_at(age: float) -> float:
	return clampf((LIFETIME-age)/FADE_SECONDS,0,1)

func _sync_stamp(index: int) -> void:
	var stamp := stamps[index]
	var progress := clampf(stamp.age/0.12,0,1)
	var spread := lerpf(0.72,1.0,1.0-pow(1.0-progress,3))
	var base := index*PARTS_PER_STAIN
	multimesh.set_instance_transform_2d(base,Transform2D(stamp.rotation,stamp.size*spread,0,stamp.at+stamp.pool_offset*spread))
	var tint := stamp.tint
	tint.a *= opacity_at(stamp.age)
	multimesh.set_instance_color(base,tint)
	for i in stamp.drops.size():
		var drop := stamp.drops[i]
		var t := clampf((stamp.age-drop.delay)/drop.flight,0,1)
		var at := stamp.at+drop.goal*(t*(2-t))+Vector2.UP*sin(t*PI)*drop.lift
		var shape := drop.size*Vector2(lerpf(0.65,1.0,t),lerpf(0.7,1.0,t))
		multimesh.set_instance_transform_2d(base+i+1,Transform2D(drop.rotation,shape,0,at))
		var ink := tint
		ink.a *= 0.0 if stamp.age<drop.delay else 0.84
		multimesh.set_instance_color(base+i+1,ink)

func _set_tile(index: int, tile: int) -> void:
	multimesh.set_instance_custom_data(index,Color(float(tile)/float(VARIANTS+DROP_VARIANTS-1),0,0,0))

func _hide_stamp(index: int) -> void:
	for part in PARTS_PER_STAIN:
		multimesh.set_instance_color(index*PARTS_PER_STAIN+part,Color.TRANSPARENT)

# Only the dash mechanic calls this bounded sweep; stationary movement cannot harvest ink.
func consume_along_segment(from: Vector2, to: Vector2, limit: int) -> int:
	if limit<=0 or get_tree().paused: return 0
	var collected := 0
	var a := to_local(from)
	var b := to_local(to)
	for i in MAX_STAINS:
		var stamp := stamps[i]
		if stamp.age<AIR_SECONDS or stamp.age>HOLD_SECONDS: continue
		var closest := Geometry2D.get_closest_point_to_segment(stamp.at,a,b)
		if stamp.at.distance_squared_to(closest)>24.0*24.0: continue
		stamp.age = LIFETIME
		_hide_stamp(i)
		active_count -= 1
		collected += 1
		if collected>=limit: break
	if active_count==0:
		multimesh.visible_instance_count = 0
		set_process(false)
	return collected

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
			_hide_stamp(i)
		elif update and (previous<AIR_SECONDS or stamp.age>HOLD_SECONDS):
			_sync_stamp(i)
	if active_count == 0:
		multimesh.visible_instance_count = 0
		set_process(false)
