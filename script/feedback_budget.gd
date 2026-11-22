extends RefCounted

const CROWD_SIZE := 12
const MAX_ACTIVE: = 64
const MAX_PER_FRAME: = 4
const PER_SECOND: = 36.0
static var suppressed: = 0
static var _tokens: = PER_SECOND
static var _stamp: = 0
static var _frame: = -1
static var _in_frame: = 0

# Shared across simultaneous automatic attacks and physics catch-up steps.
static var _impact_frame := -1
static var _impact_count := 0

static func allow_skill_impact() -> bool:
	var frame := Engine.get_process_frames()
	if frame != _impact_frame:
		_impact_frame = frame
		_impact_count = 0
	if _impact_count >= MAX_PER_FRAME: return false
	_impact_count += 1
	return true

static func allow_popup(tree: SceneTree) -> bool:
	var now: = Time.get_ticks_msec()
	_tokens = minf(PER_SECOND, _tokens + maxf(0, now - _stamp) * PER_SECOND / 1000.0)
	_stamp = now
	var frame: = Engine.get_process_frames()
	if _frame != frame:
		_frame = frame
		_in_frame = 0
	if _tokens < 1.0 or _in_frame >= MAX_PER_FRAME or tree.get_node_count_in_group("damage_popup") >= MAX_ACTIVE:
		suppressed += 1
		return false
	_tokens -= 1.0
	_in_frame += 1
	return true
