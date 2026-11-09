extends ColorRect

const FADE_SECONDS: = 0.5
var energy: = 0.0
var peak: = 0.0
var tone: = 0.0
var pitch: = 1.0
var combo: = 0
var tier: = 0
var heat: = 0.0
var kick: = 0.0
var _last_cue: = -1000
var _combo_label: Label
var _age: = FADE_SECONDS
var _stamp: = 0
var _bar: ProgressBar
var _shader: ShaderMaterial

func bind(bar: ProgressBar) -> void :
	_bar = bar
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader = ShaderMaterial.new()
	_shader.shader = preload("res://shaders/xp_pickup_glow.gdshader")
	GamePalette.configure_xp_shader(_shader)
	material = _shader
	_combo_label = Label.new()
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_label.add_theme_constant_override("outline_size", 3)
	_combo_label.add_theme_color_override("font_outline_color", Color(0.035, 0.045, 0.06))
	add_child(_combo_label)
	bar.resized.connect(_fit)
	bar.value_changed.connect(_sync_fill)
	_fit()
	reset()

func _fit() -> void :
	position = Vector2(-10, -22)
	size = _bar.size + Vector2(20, 32)
	_shader.set_shader_parameter("bar_size", _bar.size)

	_combo_label.position = Vector2(10, 0)
	_combo_label.size = Vector2(170, _bar.size.y + 6)
	_combo_label.pivot_offset = Vector2(0, _bar.size.y * 0.5)
	UiFonts.apply_to_label(_combo_label, int(clampf(_bar.size.y * 0.55, 13, 22)), true)
	_sync_fill(_bar.value)

func _sync_fill(value: float) -> void :
	_shader.set_shader_parameter("fill_ratio", clampf((value - _bar.min_value) / maxf(1, _bar.max_value - _bar.min_value), 0, 1))

func pulse(actual_pitch: float) -> void :
	var now: = Time.get_ticks_msec()
	combo = mini(combo + 1, 999) if now - _last_cue <= 450 else 1
	_last_cue = now
	tier = 3 if combo >= 16 else (2 if combo >= 8 else (1 if combo >= 4 else 0))
	heat = clampf(float(combo - 1) / 15, 0, 1)
	kick = 1
	pitch = actual_pitch
	tone = clampf(actual_pitch - 1.0, 0, 1)
	peak = lerpf(0.18, 1.0, tone)
	energy = peak
	_age = 0
	_stamp = Time.get_ticks_msec()
	_shader.set_shader_parameter("energy", energy)
	_shader.set_shader_parameter("tone", tone)
	_shader.set_shader_parameter("heat", heat)
	_shader.set_shader_parameter("kick", kick)
	_combo_label.text = "%d COMBO%s" % [combo, "!" if tier >= 2 else ""]
	_combo_label.add_theme_color_override("font_color", [GamePalette.FRIENDLY_LIGHT,GamePalette.FRIENDLY_CYAN,GamePalette.FRIENDLY_BLUE,GamePalette.PLAYER_DAMAGE_WHITE][tier])
	_combo_label.visible = combo >= 2
	_combo_label.modulate = Color.WHITE
	_combo_label.scale = Vector2.ONE * (1.1 + 0.06 * float(tier) / 3)
	show()
	set_process(true)

func reset() -> void :
	energy = 0
	peak = 0
	tone = 0
	pitch = 1
	combo = 0
	tier = 0
	heat = 0
	kick = 0
	_last_cue = -1000
	_age = FADE_SECONDS
	if _shader != null: _shader.set_shader_parameter("energy", 0.0)
	if _combo_label != null:
		_combo_label.hide()
		_combo_label.scale = Vector2.ONE
	hide()
	set_process(false)

func _process(_delta: float) -> void :
	var now: = Time.get_ticks_msec()
	_age = minf(FADE_SECONDS, _age + float(now - _stamp) / 1000)
	_stamp = now
	energy = peak * pow(1 - _age / FADE_SECONDS, 2)
	kick = maxf(0, 1 - _age / 0.15)
	_shader.set_shader_parameter("energy", energy)
	_shader.set_shader_parameter("kick", kick)
	_combo_label.scale = Vector2.ONE * (1 + kick * (0.1 + 0.06 * float(tier) / 3))
	_combo_label.modulate.a = clampf(1 - _age / FADE_SECONDS, 0, 1)
	if _age >= FADE_SECONDS: reset()
