extends Control

const WORK := preload("res://assest/sounds/forge_work.ogg")
const UPGRADE := preload("res://assest/sounds/forge_upgrade.ogg")
const HOLD := preload("res://assest/sounds/forge_hold.ogg")
const DOWNGRADE := preload("res://assest/sounds/forge_downgrade.ogg")
const FLASH_SECONDS := 0.8
const GOLD := Color("#ffc750")
const AMBER := Color("#ef8738")
const IVORY := Color("#fff4c4")

var _voice := AudioStreamPlayer.new()
var _target := Rect2()
var _elapsed := FLASH_SECONDS

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	AudioManager.configure_sfx(_voice)
	_voice.volume_db = -6.5
	add_child(_voice)
	set_process(false)

func start_work() -> void:
	cancel_fx()
	_play(WORK)

func reveal(outcome: String, target: Rect2) -> void:
	cancel_fx()
	match outcome:
		"up":
			_play(UPGRADE)
			_target = target
			_elapsed = 0.0
			set_process(true)
			queue_redraw()
		"down":
			_play(DOWNGRADE)
		"stay":
			_play(HOLD)

func move_target(target: Rect2) -> void:
	_target = target

func _play(stream: AudioStream) -> void:
	_voice.stream = stream
	_voice.play()

func cancel_fx() -> void:
	_voice.stop()
	_elapsed = FLASH_SECONDS
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed = minf(_elapsed + delta, FLASH_SECONDS)
	queue_redraw()
	if _elapsed >= FLASH_SECONDS:
		set_process(false)

func _draw() -> void:
	if _elapsed >= FLASH_SECONDS or not _target.has_area():
		return

	var t := _elapsed / FLASH_SECONDS
	var center := _target.get_center().round()
	var radius := minf(_target.size.x, _target.size.y) * 0.5
	var fade := 1.0 - smoothstep(0.19, 0.97, t)
	var ignition := 1.0 - smoothstep(0.0, 0.42, t)
	var burst := ease(minf(1.0, t / 0.56), 0.32)

	# One gilded edge and one diagonal glint, restricted to this card.
	draw_rect(_target.grow(3), Color(AMBER, 0.60 * fade), false, 2)
	draw_rect(_target.grow(1), Color(IVORY, 0.93 * fade), false, 2)
	draw_rect(_target, Color(GOLD, 0.37 * ignition))
	var sweep := lerpf(-0.35, 1.55, t / 0.62)
	for y in range(0, ceili(_target.size.y), 3):
		var left := _target.size.x * sweep - y * 0.43
		var start := clampf(left - radius * 0.24, 0, _target.size.x)
		var stop := clampf(left + radius * 0.24, 0, _target.size.x)
		if stop > start:
			draw_rect(Rect2(_target.position + Vector2(start,y), Vector2(stop-start, minf(3, _target.size.y-y))), Color(IVORY, 0.76 * fade))

	# A single white-hot star blooms above the icon, then contracts into the gold edge.
	var glimmer := sin(PI * clampf(t / 0.63, 0, 1))
	if glimmer > 0.02:
		var star := (center + Vector2(radius * 0.31, -radius * 0.38)).round()
		var tall := radius * 1.15 * glimmer
		var wide := radius * 0.65 * glimmer
		var core := maxf(1.0, radius * 0.13 * glimmer)
		var points := PackedVector2Array([
			star + Vector2(0, -tall), star + Vector2(core, -core),
			star + Vector2(wide, 0), star + Vector2(core, core),
			star + Vector2(0, tall * 0.72), star + Vector2(-core, core),
			star + Vector2(-wide, 0), star + Vector2(-core, -core)
		])
		draw_colored_polygon(points, Color(GOLD, glimmer))
		draw_rect(Rect2(star - Vector2.ONE * core, Vector2.ONE * core * 2.0), Color(IVORY, glimmer))

	# Individually bounded rays keep the card readable and never touch the whole screen.
	for i in 10:
		var angle := TAU * i / 10.0 - PI * 0.5
		var dir := Vector2.from_angle(angle)
		var across := dir.orthogonal()
		var rim := radius / maxf(absf(dir.x), absf(dir.y))
		var root := center + dir * (rim + 1.0)
		var reach := radius * (0.64 if i % 3 == 0 else 0.37)
		var tip := root + dir * reach * (0.26 + 0.74 * burst)
		var heel := root.lerp(tip, smoothstep(0.36, 1.0, t))
		var half_width := (2.8 if i % 3 == 0 else 1.9) * fade
		if half_width > 0.65 and heel.distance_squared_to(tip) > 2.0:
			draw_colored_polygon(PackedVector2Array([heel-across*half_width, tip, heel+across*half_width]), Color(GOLD if i%2 else IVORY, fade))
		if t > 0.13:
			var spark := (tip + dir * (2.0 + radius * 0.34 * t)).round()
			var pixels := 3 if i%3 == 0 else 2
			draw_rect(Rect2(spark, Vector2(pixels,pixels)), Color(IVORY if i%2 else GOLD, fade))
