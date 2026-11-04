extends Logger

var recorder: WeakRef
var _mutex: = Mutex.new()
var _window: = 0
var _count: = 0

func _log_error(function_name: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void :
	_mutex.lock()
	var now: = Time.get_ticks_msec()
	if now - _window >= 1000:
		_window = now
		_count = 0
	_count += 1
	var accept: = _count <= 12
	_mutex.unlock()
	if not accept:
		return
	var target: Node = recorder.get_ref() if recorder != null else null
	if is_instance_valid(target):
		var traces: Array[String] = []
		for trace in script_backtraces.slice(0, 3):
			traces.append(trace.format().left(2400))
		target.call_deferred("capture_engine_error", {"function": function_name, "file": file.left(240), "line": line, "code": code.left(1400), "message": rationale.left(1400), "type": error_type, "script_backtraces": traces})
