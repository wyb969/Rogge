extends Node

signal track_changed(index: int, title: String)
const BPM: = 160
const FADE_SECONDS: = 4.0 * 60.0 / BPM
const VOLUME_DB: = -4.0
const TRACKS: = [
	{"title": "江湖行", "stream": preload("res://assest/music/adventure/jianghu.ogg")}, 
	{"title": "古堡夜行", "stream": preload("res://assest/music/adventure/ruins.ogg")}, 
	{"title": "碧潮回响", "stream": preload("res://assest/music/adventure/tide.ogg")}, 
	{"title": "风雷疾驰", "stream": preload("res://assest/music/adventure/thunder.ogg")}, 
	{"title": "云上漫游", "stream": preload("res://assest/music/adventure/gale.ogg")}, 
	{"title": "熔火行军", "stream": preload("res://assest/music/adventure/ember.ogg")}, 
	{"title": "逐光冒险", "stream": preload("res://assest/music/adventure/daybreak.ogg")}, 
	{"title": "旌旗如风", "stream": preload("res://assest/music/adventure/banners.ogg")}, 
]
var active: = false
var preview_mode: = false
var stage: = 1
var track_index: = -1
var _last_track: = -1
var _preview_cursor: = -1
var _bag: Array[int] = []
var _players: Array[AudioStreamPlayer] = []
var _current: AudioStreamPlayer
var _fade: Tween
var _allow_play: = false
var _rng: = RandomNumberGenerator.new()

func configure(first: AudioStreamPlayer) -> void :
	_players.append(first)

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	var second: = AudioStreamPlayer.new()
	second.name = "GameAudioPlayerB"
	second.bus = _players[0].bus
	add_child(second)
	_players.append(second)
	for player in _players:


		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		player.finished.connect(_on_finished.bind(player))

func play_stage(value: int, new_run: bool, allow_play: bool) -> void :
	var next_stage: = clampi(value, 1, 6)
	var changed: = stage != next_stage or preview_mode or new_run
	_allow_play = allow_play
	if active and not changed:
		resume(false)
		return
	stage = next_stage
	preview_mode = false
	if changed:
		_bag.clear()
	active = true
	_switch_to(_take_next(changed and not new_run))

func preview_next(allow_play: bool) -> void :
	_allow_play = allow_play
	active = true
	preview_mode = true
	_preview_cursor = (_preview_cursor + 1) % TRACKS.size()
	_switch_to(_preview_cursor)

func _pool() -> Array[int]:
	return [stage - 1, 6, 7]

func _take_next(prefer_theme: bool = false) -> int:
	if _bag.is_empty():
		_bag.assign(_pool())
		for i in range(_bag.size() - 1, 0, -1):
			var other: = _rng.randi_range(0, i)
			var swap: = _bag[i]
			_bag[i] = _bag[other]
			_bag[other] = swap
	if prefer_theme and stage - 1 != _last_track:
		_bag.erase(stage - 1)
		return stage - 1
	if _bag.size() > 1 and _bag.back() == _last_track:
		var swap: = _bag[0]
		_bag[0] = _bag.back()
		_bag[_bag.size() - 1] = swap
	return _bag.pop_back()

func _next() -> void :
	if preview_mode:
		preview_next(_allow_play)
	else:
		_switch_to(_take_next())

func _switch_to(index: int) -> void :
	_cancel_fade()


	var previous: AudioStreamPlayer
	for player in _players:
		if player.playing and (previous == null or player.volume_db > previous.volume_db):
			previous = player
	var incoming: = _players[1] if previous == _players[0] else _players[0]
	incoming.stop()
	incoming.stream = TRACKS[index].stream
	incoming.pitch_scale = 1.0
	_current = incoming
	track_index = index
	_last_track = index
	track_changed.emit(index, TRACKS[index].title)
	if not _allow_play:
		if previous != null:
			previous.stop()
		incoming.volume_db = VOLUME_DB
		return
	incoming.volume_db = -80.0
	incoming.play()
	var previous_gain: = db_to_linear(previous.volume_db) if previous != null else 0.0
	_fade = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_method(_crossfade_gains.bind(previous, incoming, previous_gain), 0.0, 1.0, FADE_SECONDS)
	_fade.tween_callback(_finish_fade.bind(previous))

func _crossfade_gains(weight: float, previous: AudioStreamPlayer, incoming: AudioStreamPlayer, previous_gain: float) -> void :
	if previous != null:
		previous.volume_db = linear_to_db(maxf(0.0001, cos(weight * PI * 0.5) * previous_gain))
	incoming.volume_db = linear_to_db(maxf(0.0001, sin(weight * PI * 0.5) * db_to_linear(VOLUME_DB)))

func _finish_fade(previous: AudioStreamPlayer) -> void :
	if previous != null and previous != _current:
		previous.stop()
	_current.volume_db = VOLUME_DB
	_fade = null

func _cancel_fade() -> void :
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null

func _process(_delta: float) -> void :
	if not active or not _allow_play or _current == null or not _current.playing or _fade != null:
		return


	if _current.stream.get_length() - _current.get_playback_position() <= FADE_SECONDS:
		_next()

func _on_finished(player: AudioStreamPlayer) -> void :
	if active and player == _current and _allow_play and not player.playing:
		_next()

func resume(force: bool = false) -> void :
	if not active or _current == null:
		return
	if not _allow_play:
		return
	if force or not _current.playing:
		_current.play()

func unlock() -> void :
	_allow_play = true
	resume(false)

func stop() -> void :
	active = false
	_cancel_fade()
	for player in _players:
		player.stop()

func title() -> String:
	return TRACKS[track_index].title if track_index >= 0 else ""
