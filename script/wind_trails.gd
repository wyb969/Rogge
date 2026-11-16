extends Node2D
# Compatibility/Web equivalent of particle-history ribbons. No GPU trail feature needed.
const COUNT := 14
const POINTS := 64
const STEP := 1.0/60.0
const MAX_STEPS := 8
var _rng := RandomNumberGenerator.new()
var _trails: Array[Dictionary] = []
var _vortices: Array[Dictionary] = []
var _bounds := Rect2()
var _accumulator := 0.0
var _clock := 0.0
var _strength := 0.0
var _direction := Vector2.RIGHT
var _speed := 100.0
var live := false
var steps_last := 0
@onready var surface: Node = get_parent()

func _ready() -> void:
	z_index = 31 # Surface is -35: ribbons stay below actors and danger warnings at -4.
	_rng.randomize()
	var taper := Curve.new()
	for pair in [Vector2(0,0),Vector2(0.25,0.65),Vector2(0.75,1),Vector2(1,0)]: taper.add_point(pair)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0,0.35,0.85,1])
	gradient.colors = PackedColorArray([Color(GamePalette.WIND_TRAIL,0),Color(GamePalette.WIND_TRAIL,0.7),GamePalette.WIND_TRAIL,Color(GamePalette.WIND_TRAIL,0)])
	var cross_section := GradientTexture2D.new()
	cross_section.width = 4
	cross_section.height = 32
	cross_section.fill_from = Vector2(0.5,0)
	cross_section.fill_to = Vector2(0.5,1)
	cross_section.gradient = Gradient.new()
	cross_section.gradient.offsets = PackedFloat32Array([0,0.25,0.5,0.75,1])
	cross_section.gradient.colors = PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.3),Color.WHITE,Color(1,1,1,0.3),Color(1,1,1,0)])
	for i in COUNT:
		var line := Line2D.new()
		line.width = 2.2 if i%3 else 1.8
		line.texture = cross_section
		line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		line.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		line.width_curve = taper
		line.gradient = gradient
		line.antialiased = true
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.round_precision = 2
		add_child(line)
		var history := PackedVector2Array()
		history.resize(POINTS)
		var display := PackedVector2Array()
		display.resize(POINTS)
		_trails.append({"line":line,"history":history,"display":display,"at":Vector2.ZERO,"velocity":Vector2.ZERO,"cursor":0,"age":0.0,"life":1.0,"gain":1.0})
	stop()

func stop() -> void:
	live = false
	_accumulator = 0
	_clock = 0
	_strength = 0
	_vortices.clear()
	for trail in _trails:
		trail.line.hide()
		trail.line.clear_points()
	hide()
	set_process(false)

func sync(strength: float, velocity: Vector2) -> void:
	_strength = clampf(strength,0,1)
	if _strength<=0.001 or not surface.active():
		if live: stop()
		return
	_direction = velocity.normalized() if not velocity.is_zero_approx() else _direction
	_speed = 88+velocity.length()*3.0
	_bounds = get_viewport().get_canvas_transform().affine_inverse()*get_viewport().get_visible_rect()
	if not live:
		live = true
		for i in 3: _vortices.append(_new_vortex(i))
		for i in COUNT: _spawn(_trails[i],i,true)
		# Prewarm once with bounded work so entering wind weather is immediately readable.
		for i in POINTS: _step(STEP)
		_render()
	show()
	set_process(true)

func _new_vortex(index: int) -> Dictionary:
	var center := _bounds.position+_bounds.size*Vector2(_rng.randf_range(0.15,0.85),_rng.randf_range(0.15,0.85))
	return {"at":center,"radius":_rng.randf_range(85,145),"spin":(-1.0 if index%2 else 1.0),"phase":_rng.randf_range(0,TAU)}

func _spawn(trail: Dictionary, index: int, initial: bool = false) -> void:
	var area := _bounds.grow(65)
	trail.at = area.position+Vector2(_rng.randf(),_rng.randf())*area.size
	# A few particles pass through rotating pockets; the rest show the dominant wind.
	if index%4==0 and not _vortices.is_empty():
		var vortex: Dictionary = _vortices[index%3]
		trail.at = vortex.at+_direction.orthogonal()*float(vortex.radius)*0.35
	trail.velocity = flow(trail.at)
	trail.age = _rng.randf_range(0.4,1.8) if initial else 0.0
	trail.life = _rng.randf_range(3.5,6.0)
	trail.gain = _rng.randf_range(0.32,0.58)
	trail.cursor = 0
	trail.history.fill(trail.at)
	trail.display.fill(trail.at)

func flow(at: Vector2) -> Vector2:
	var side := _direction.orthogonal()
	var along := at.dot(_direction)*0.009
	var across := at.dot(side)*0.012
	var sway := sin(along+_clock*0.65)*0.32+sin(across-_clock*0.48)*0.21
	var velocity := (_direction+side*sway)*_speed
	for vortex in _vortices:
		var offset: Vector2 = at-vortex.at
		var radius: float = vortex.radius
		var distance := offset.length()
		if distance>=radius or distance<0.1: continue
		var weight := 1.0-distance/radius
		# Suppress the through-flow at the core and add smooth tangential curl.
		velocity *= 1.0-0.72*weight
		velocity += offset.orthogonal()/distance*float(vortex.spin)*210*weight*(0.85+0.15*sin(_clock*0.6+float(vortex.phase)))
	return velocity.limit_length(210)

func _step(delta: float) -> void:
	_clock += delta
	for i in COUNT:
		var trail: Dictionary = _trails[i]
		trail.age += delta
		if trail.age>=trail.life or not _bounds.grow(220).has_point(trail.at): _spawn(trail,i)
		# Midpoint integration curves smoothly without frame-rate-dependent steering.
		var v := flow(trail.at)
		trail.velocity = flow(trail.at+v*delta*0.5)
		trail.at += trail.velocity*delta
		trail.cursor = (int(trail.cursor)+1)%POINTS
		trail.history[trail.cursor] = trail.at

func advance(delta: float) -> void:
	steps_last = 0
	if not live or get_tree().paused or not surface.active(): return
	_accumulator = minf(_accumulator+maxf(delta,0),STEP*MAX_STEPS)
	while _accumulator+0.0000001>=STEP and steps_last<MAX_STEPS:
		_step(STEP)
		_accumulator = maxf(0,_accumulator-STEP)
		steps_last += 1
	_render()

func _process(delta: float) -> void:
	if not surface.active():
		stop()
		return
	_bounds = get_viewport().get_canvas_transform().affine_inverse()*get_viewport().get_visible_rect()
	for i in _vortices.size():
		if not _bounds.grow(260).has_point(_vortices[i].at): _vortices[i] = _new_vortex(i)
	advance(delta)

func _render() -> void:
	var blend := _accumulator/STEP
	var pixels := maxf(0.2,(get_viewport().get_final_transform()*get_viewport().get_canvas_transform()).get_scale().x)
	var visible_count := clampi(int(ceil(COUNT*_strength)),1,COUNT)
	for i in COUNT:
		var trail: Dictionary = _trails[i]
		trail.line.visible = i<visible_count
		if i>=visible_count: continue
		for j in POINTS:
			var slot := (int(trail.cursor)+1+j)%POINTS
			var next := (slot+1)%POINTS
			var a: Vector2 = trail.history[slot]
			trail.display[j] = a.lerp(trail.history[next],blend) if j<POINTS-1 else a+trail.velocity*_accumulator
		var fade := smoothstep(0,0.65,float(trail.age))*(1-smoothstep(float(trail.life)-0.8,float(trail.life),float(trail.age)))
		trail.line.width = maxf(2.2 if i%3 else 1.8,1.8/pixels)
		trail.line.modulate.a = float(trail.gain)*fade*_strength
		trail.line.points = trail.display
