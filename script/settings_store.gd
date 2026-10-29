extends Node
## Saved preferences in user://rogge_settings.cfg.
## Difficulty is stored only. It does not change combat yet.

const PATH := "user://rogge_settings.cfg"
const DIFF_EASY := 0
const DIFF_MEDIUM := 1
const DIFF_HARD := 2

var master_linear: float = 1.0
var control_scale: float = 1.0
var control_opacity: float = 0.85
var stick_norm: Vector2 = Vector2(-1, -1)
var dash_norm: Vector2 = Vector2(-1, -1)
var difficulty: int = DIFF_MEDIUM

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_from_disk()

func load_from_disk() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	master_linear = clampf(float(file.get_value("audio", "master", master_linear)), 0.0, 1.0)
	control_scale = clampf(float(file.get_value("controls", "scale", control_scale)), 0.7, 1.6)
	control_opacity = clampf(float(file.get_value("controls", "opacity", control_opacity)), 0.25, 1.0)
	stick_norm = Vector2(
		float(file.get_value("controls", "stick_x", -1.0)),
		float(file.get_value("controls", "stick_y", -1.0))
	)
	dash_norm = Vector2(
		float(file.get_value("controls", "dash_x", -1.0)),
		float(file.get_value("controls", "dash_y", -1.0))
	)
	difficulty = clampi(int(file.get_value("play", "difficulty", DIFF_MEDIUM)), DIFF_EASY, DIFF_HARD)

func save_to_disk() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "master", master_linear)
	file.set_value("controls", "scale", control_scale)
	file.set_value("controls", "opacity", control_opacity)
	file.set_value("controls", "stick_x", stick_norm.x)
	file.set_value("controls", "stick_y", stick_norm.y)
	file.set_value("controls", "dash_x", dash_norm.x)
	file.set_value("controls", "dash_y", dash_norm.y)
	file.set_value("play", "difficulty", difficulty)
	file.save(PATH)
	_sync_web_filesystem()

func _sync_web_filesystem() -> void:
	# HTML5 user:// lives in IndexedDB. Flush so a refresh keeps the layout.
	if not OS.has_feature("web"):
		return
	var js = Engine.get_singleton("JavaScriptBridge")
	if js != null and js.has_method("eval"):
		js.eval(
			"(function(){try{if(typeof FS!=='undefined'&&FS.syncfs){FS.syncfs(false,function(){});}}catch(e){}})();",
			true
		)

func apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	if master_linear <= 0.001:
		AudioServer.set_bus_mute(bus, true)
		return
	AudioServer.set_bus_mute(bus, false)
	AudioServer.set_bus_volume_db(bus, linear_to_db(master_linear))

func set_master_linear(value: float) -> void:
	master_linear = clampf(value, 0.0, 1.0)
	apply_audio()
	save_to_disk()

func set_control_scale(value: float) -> void:
	control_scale = clampf(value, 0.7, 1.6)
	save_to_disk()

func set_control_opacity(value: float) -> void:
	control_opacity = clampf(value, 0.25, 1.0)
	save_to_disk()

func set_difficulty(index: int) -> void:
	difficulty = clampi(index, DIFF_EASY, DIFF_HARD)
	save_to_disk()

func set_stick_norm(value: Vector2) -> void:
	stick_norm = value
	save_to_disk()

func set_dash_norm(value: Vector2) -> void:
	dash_norm = value
	save_to_disk()

func has_custom_stick() -> bool:
	return stick_norm.x >= 0.0 and stick_norm.y >= 0.0

func has_custom_dash() -> bool:
	return dash_norm.x >= 0.0 and dash_norm.y >= 0.0
