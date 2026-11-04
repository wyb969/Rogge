extends CanvasLayer

const PEAK_ALPHA: = 0.34
const DURATION: = 0.26
const MIN_INTERVAL_MSEC: = 300
var _rect: ColorRect
var _tween: Tween
var _last_flash_msec: = - MIN_INTERVAL_MSEC

func _ready() -> void :
	layer = 88
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0.95, 0.025, 0.055, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.hide()

func flash(amount: float) -> void :
	if amount <= 0:
		return
	var now: = Time.get_ticks_msec()
	if now - _last_flash_msec < MIN_INTERVAL_MSEC:
		return
	_last_flash_msec = now
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_rect.color.a = PEAK_ALPHA
	_rect.show()

	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_interval(0.05)
	_tween.tween_property(_rect, "color:a", 0.0, DURATION - 0.05)
	_tween.tween_callback(_rect.hide)

func reset() -> void :
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_rect.color.a = 0
	_rect.hide()
	_last_flash_msec = - MIN_INTERVAL_MSEC
