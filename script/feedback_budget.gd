extends RefCounted

const MAX_ACTIVE: = 64
const MAX_PER_FRAME: = 4
const PER_SECOND: = 36.0
static var suppressed: = 0
static var _tokens: = PER_SECOND
static var _stamp: = 0
static var _frame: = -1
static var _in_frame: = 0

static func allow_popup(tree: SceneTree) -> bool:
	var now: = Time.get_ticks_msec()
	_tokens = minf(PER_SECOND, _tokens + maxf(0, now - _stamp) * PER_SECOND / 1000.0)
	_stamp = now
	var frame: = Engine.get_process_frames()
	if _frame != frame:
		_frame = frame
		_in_frame = 0
	if _tokens < 1.0 or _in_frame >= MAX_PER_FRAME or tree.get_nodes_in_group("damage_popup").size() >= MAX_ACTIVE:
		suppressed += 1
		return false
	_tokens -= 1.0
	_in_frame += 1
	return true
