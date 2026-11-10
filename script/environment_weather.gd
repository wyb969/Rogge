extends Node


enum Weather{CLEAR, OVERCAST, RAIN, SNOW}
const NAMES: Array[String] = ["晴天", "阴天", "雨天", "雪天"]
const CYCLE_SECONDS: = 240.0
const TRANSITION_SECONDS: = 2.5
const MAX_RAIN: = 96
const MAX_SNOW: = 64
static var _last_opening: = -1
var running: = false
var current_weather: = Weather.CLEAR
var stage: = 1
var elapsed: = 0.0
var solar_phase: = 0.0
var daylight: = 1.0
var ambient: = Color.WHITE
var sun_strength: = 0.0
var cloud_strength: = 0.0
var rain_count: = 0
var snow_count: = 0
var _start_phase: = 0.0
var _weights: = PackedFloat32Array([1, 0, 0, 0])
var _transition_start: = PackedFloat32Array([1, 0, 0, 0])
var _transition_left: = 0.0
var _stage_profiles: = {}
var _bag: Array[int] = []
var _rng: = RandomNumberGenerator.new()
var _rain: = PackedVector4Array()
var _snow: = PackedVector4Array()
var _snow_stars: = PackedVector3Array()
var _snow_positions: = PackedVector2Array()
var _snow_elapsed: = 0.0
var _snow_seeded: = false
var _background: Node
var _field: WeatherField
var _snow_field: WeatherField
var _ui: CanvasLayer
var _caption: Label
var _redraw_left: = 0.0
var _lighting_left: = 0.0
var _caption_stamp: = -1
var _wind_offset: = Vector2.ZERO
var _previous_camera: = Vector2.ZERO
var _preview: CanvasLayer
var _buttons: HBoxContainer

class WeatherField:
	extends Node2D
	var weather: Node
	var world_snow: = false
	func _draw() -> void :
		if world_snow: weather.draw_snow(self)
		else: weather.draw_weather(self)

func _ready() -> void :
	_rng.randomize()
	_background = get_parent().get_node("InfiniteBackground")
	for i in MAX_RAIN:
		_rain.append(Vector4(_rng.randf(), _rng.randf(), _rng.randf(), _rng.randf()))
	for i in MAX_SNOW:
		_snow.append(Vector4(_rng.randf(), _rng.randf(), _rng.randf(), _rng.randf()))
	_snow_stars.resize(MAX_SNOW / 4)
	_snow_positions.resize(MAX_SNOW)
	_field = WeatherField.new()
	_field.name = "WeatherField"
	_field.weather = self
	_field.top_level = true
	_field.z_index = -5
	add_child(_field)
	_snow_field = WeatherField.new()
	_snow_field.name = "WorldSnowField"
	_snow_field.weather = self
	_snow_field.world_snow = true
	_snow_field.top_level = true
	_snow_field.z_index = -5
	add_child(_snow_field)
	_snow_field.global_transform = Transform2D.IDENTITY
	_ui = CanvasLayer.new()
	_ui.layer = 50
	add_child(_ui)
	_caption = Label.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_color_override("font_color", GamePalette.UI_BORDER)
	_caption.add_theme_color_override("font_outline_color", GamePalette.BLACK)
	_caption.add_theme_constant_override("outline_size", 3)
	_ui.add_child(_caption)
	get_viewport().size_changed.connect(_fit)
	_fit()
	stop()

func begin_run() -> void :
	_stage_profiles.clear()
	_bag.clear()
	elapsed = 0
	_snow_elapsed = 0
	_snow_seeded = false
	_start_phase = _rng.randf()
	_wind_offset = Vector2.ZERO
	_previous_camera = _camera_center()
	running = true
	set_process(true)
	_field.show()
	_snow_field.show()
	_caption.show()
	apply_stage(1, true)
	AudioManager.weather_audio.bind_environment(self, current_weather, daylight)

func apply_stage(value: int, immediate: bool = false) -> void :
	if not running: return
	stage = maxi(1, value)
	if not _stage_profiles.has(stage):
		var previous: int = _last_opening if stage == 1 else current_weather
		if _bag.is_empty():
			_bag.assign([0, 1, 2, 3])
			for i in range(_bag.size() - 1, 0, -1):
				var other: = _rng.randi_range(0, i)
				var temp: = _bag[i]
				_bag[i] = _bag[other]
				_bag[other] = temp
		if _bag.size() > 1 and _bag.back() == previous:
			var temp: = _bag[0]
			_bag[0] = _bag.back()
			_bag[_bag.size() - 1] = temp
		_stage_profiles[stage] = _bag.pop_back()
		if stage == 1: _last_opening = int(_stage_profiles[stage])
	var selected: int = _stage_profiles[stage]
	if current_weather == selected and not immediate: return
	_select(selected, immediate)

func _select(kind: int, immediate: bool) -> void :
	current_weather = kind as Weather
	_transition_start = _weights.duplicate()
	_transition_left = 0.0 if immediate else TRANSITION_SECONDS
	if immediate:
		_weights.fill(0)
		_weights[kind] = 1
	_update_environment()
	_advance_snow()
	_field.queue_redraw()
	_snow_field.queue_redraw()

func stop() -> void :
	AudioManager.weather_audio.detach(self)
	running = false
	rain_count = 0
	snow_count = 0
	set_process(false)
	if _field != null:
		_field.hide()
		_field.queue_redraw()
	if _snow_field != null:
		_snow_field.hide()
		_snow_field.queue_redraw()
	if _caption != null: _caption.hide()
	if _preview != null: _preview.hide()
	if _background != null:
		_background.set_environment_light(Color.WHITE, 0, Vector2(0.9, 0.35), 0, 0)

func _process(delta: float) -> void :
	if not running: return
	elapsed += delta
	_lighting_left -= delta
	if _transition_left > 0:
		_transition_left = maxf(0, _transition_left - delta)
		var blend: = smoothstep(0, 1, 1.0 - _transition_left / TRANSITION_SECONDS)
		for i in 4:
			_weights[i] = lerpf(_transition_start[i], 1.0 if i == current_weather else 0.0, blend)
	_field.global_transform = get_viewport().get_canvas_transform().affine_inverse()
	_redraw_left -= delta
	if _redraw_left > 0: return
	_redraw_left = 1.0 / 30.0
	var center: = _camera_center()
	var camera: = get_viewport().get_camera_2d()
	var zoom: = camera.zoom if camera != null else Vector2.ONE
	_wind_offset -= (center - _previous_camera) * zoom * 0.25
	_previous_camera = center
	var vp: = get_viewport().get_visible_rect().size
	_wind_offset = Vector2(fposmod(_wind_offset.x, vp.x + 64), fposmod(_wind_offset.y, vp.y + 64))
	_advance_snow()
	if _lighting_left <= 0:
		_lighting_left = 0.1
		_update_environment()
	_field.queue_redraw()
	_snow_field.queue_redraw()

func _snow_bounds() -> Rect2:


	var inverse: = get_viewport().get_canvas_transform().affine_inverse()
	return (inverse * get_viewport().get_visible_rect()).grow(48)

func _advance_snow() -> void :
	var dt: = elapsed - _snow_elapsed
	var previous: = _snow_elapsed
	_snow_elapsed = elapsed
	if snow_count <= 0: return
	var bounds: = _snow_bounds()
	var zoom: = get_viewport().get_canvas_transform().get_scale().abs()
	for i in MAX_SNOW:
		var seed: Vector4 = _snow[i]
		var point: = _snow_positions[i] if _snow_seeded else bounds.position + Vector2(seed.x, seed.y) * bounds.size

		point += Vector2((10 + seed.z * 12) * dt + (sin(elapsed * 0.7 + seed.w * TAU) - sin(previous * 0.7 + seed.w * TAU)) * 14, (32 + seed.z * 42) * dt) / zoom

		point = bounds.position + (point - bounds.position).posmodv(bounds.size)
		_snow_positions[i] = point
	_snow_seeded = true

func _camera_center() -> Vector2:
	var camera: = get_viewport().get_camera_2d()
	return camera.get_screen_center_position() if camera != null else Vector2.ZERO

func _update_environment() -> void :
	solar_phase = fposmod(_start_phase + elapsed / CYCLE_SECONDS, 1)
	daylight = smoothstep(0.18, 0.82, 0.5 + cos(solar_phase * TAU) * 0.5)
	ambient = GamePalette.WEATHER_NIGHT.lerp(GamePalette.WEATHER_DAY, daylight)
	var horizon: = pow(1.0 - absf(daylight * 2 - 1), 3) * 0.18
	ambient = ambient.lerp(GamePalette.WEATHER_HORIZON, horizon)
	var overcast: float = _weights[1] * 0.06 + _weights[2] * 0.1 + _weights[3] * 0.05
	ambient *= 1.0 - overcast
	var intensity: float = SettingsStore.weather_intensity
	sun_strength = daylight * (_weights[0] * 0.14 + _weights[1] * 0.02 + _weights[3] * 0.03) * intensity
	cloud_strength = (_weights[0] * 0.12 + _weights[1] * 0.45 + _weights[2] * 0.6 + _weights[3] * 0.35) * intensity
	var direction: = Vector2(0.9, 0.35).rotated(sin(solar_phase * TAU) * 0.35)
	_background.set_environment_light(ambient, sun_strength, direction, elapsed, cloud_strength)
	var boss_factor: = 0.72 if get_parent().spawner._boss_fight_active else 1.0
	rain_count = int(MAX_RAIN * _weights[Weather.RAIN] * intensity * boss_factor)
	snow_count = int(MAX_SNOW * _weights[Weather.SNOW] * intensity * boss_factor)
	var period: = 0 if daylight > 0.72 else (1 if daylight < 0.18 else (2 if solar_phase < 0.5 else 3))
	var stamp: = int(current_weather) * 4 + period
	if stamp != _caption_stamp:
		_caption_stamp = stamp
		_caption.text = NAMES[current_weather] + " · " + time_name()
	AudioManager.weather_audio.sync(self, current_weather, daylight)

func _exit_tree() -> void :
	if is_instance_valid(AudioManager.weather_audio): AudioManager.weather_audio.detach(self)

func time_name() -> String:
	if daylight > 0.72: return "日间"
	if daylight < 0.18: return "夜间"
	return "黄昏" if solar_phase < 0.5 else "黎明"

func draw_weather(canvas: Node2D) -> void :
	if not running: return
	var vp: = get_viewport().get_visible_rect().size
	var hero: Vector2 = get_parent().player.get_global_transform_with_canvas().origin
	for i in rain_count:
		var seed: Vector4 = _rain[i]
		var x: = fposmod(seed.x * vp.x - elapsed * (55 + seed.z * 35) + _wind_offset.x, vp.x + 64) - 32
		var y: = fposmod(seed.y * vp.y + elapsed * (460 + seed.z * 300) + _wind_offset.y, vp.y + 64) - 32
		var point: = Vector2(x, y)
		var alpha: = (0.12 + seed.w * 0.1) * lerpf(0.25, 1, smoothstep(20, 85, point.distance_to(hero)))
		canvas.draw_line(point, point + Vector2(-2.0, 9.0 + seed.z * 9), GamePalette.alpha(GamePalette.WEATHER_RAIN,alpha), 0.8 + seed.w * 0.4, false)

func draw_snow(canvas: Node2D) -> void :
	if not running or not _snow_seeded: return
	var hero: Vector2 = get_parent().player.global_position
	var zoom: = get_viewport().get_canvas_transform().get_scale().abs()
	for i in snow_count:
		var seed: Vector4 = _snow[i]
		var point: = _snow_positions[i]
		var alpha: = (0.18 + seed.w * 0.16) * lerpf(0.25, 1, smoothstep(20, 85, ((point - hero) * zoom).length()))


		var size: = Vector2.ONE * (1.4 + seed.z * 2.0) / zoom
		canvas.draw_rect(Rect2(point - size * 0.5, size), GamePalette.alpha(GamePalette.WEATHER_SNOW,alpha))
		if i % 4 == 0:
			_snow_stars[i / 4] = Vector3(point.x, point.y, alpha)

	for i in (snow_count + 3) / 4:
		var star: Vector3 = _snow_stars[i]
		var point: = Vector2(star.x, star.y)
		canvas.draw_line(point - Vector2(2.8, 0) / zoom, point + Vector2(2.8, 0) / zoom, GamePalette.alpha(GamePalette.WEATHER_STAR,star.z * 0.8), 1.0 / zoom.x, false)
		canvas.draw_line(point - Vector2(0, 2.8) / zoom, point + Vector2(0, 2.8) / zoom, GamePalette.alpha(GamePalette.WEATHER_STAR,star.z * 0.8), 1.0 / zoom.y, false)

func describe() -> Dictionary:
	return {"running": running, "stage": stage, "weather": NAMES[current_weather], "solar_phase": snappedf(solar_phase, 0.001), "daylight": snappedf(daylight, 0.001), "rain": rain_count, "snow": snow_count, "intensity": SettingsStore.weather_intensity, "audio": AudioManager.weather_audio.describe()}

func set_preview(kind: int, phase: float = -1) -> void :
	if phase >= 0: _start_phase = fposmod(phase - elapsed / CYCLE_SECONDS, 1)
	_select(clampi(kind, 0, 3), true)

func enable_preview() -> void :
	if _preview != null: return
	add_to_group("diagnostic_ui")
	_preview = CanvasLayer.new()
	_preview.layer = 95
	_preview.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_preview)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	_preview.add_child(_buttons)
	for title in ["下个天气", "切换昼夜", "返回主页"]:
		var button: = Button.new()
		button.text = title
		_buttons.add_child(button)
	_buttons.get_child(0).pressed.connect( func(): set_preview((current_weather + 1) % 4))
	_buttons.get_child(1).pressed.connect( func(): set_preview(current_weather, 0.0 if daylight < 0.5 else 0.5))
	_buttons.get_child(2).pressed.connect( func():
		get_parent().end_game()
		get_tree().current_scene.show_main_menu())
	_fit()

func owns_pointer(point: Vector2) -> bool:
	if _preview == null or not _preview.visible: return false
	for button in _buttons.get_children():
		if button.get_global_rect().has_point(point): return true
	return false

func _fit() -> void :
	var vp: = get_viewport().get_visible_rect().size
	var scale: = 2.0 if vp.y > vp.x else 1.0
	UiFonts.apply_to_label(_caption, int(12 * scale))
	_caption.position = Vector2(vp.x * 0.3, 56 * scale)
	_caption.size = Vector2(vp.x * 0.4, 24 * scale)
	if _buttons == null: return
	var width: = minf(780, vp.x - 40)
	_buttons.position = Vector2((vp.x - width) * 0.5, vp.y - 76 * scale)
	for button in _buttons.get_children():
		button.custom_minimum_size = Vector2((width - 20) / 3, 56 * scale)
		UiFonts.apply_to_button(button, int(16 * scale))
	_buttons.set_deferred("size", Vector2(width, 56 * scale))
