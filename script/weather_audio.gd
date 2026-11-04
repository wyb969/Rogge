extends Node


const BEDS: = [preload("res://assest/sounds/weather/clear_air.ogg"), preload("res://assest/sounds/weather/overcast_wind.ogg"), preload("res://assest/sounds/weather/rain.ogg"), preload("res://assest/sounds/weather/snow.ogg")]
const BIRDS: = [preload("res://assest/sounds/weather/birds_1.ogg"), preload("res://assest/sounds/weather/birds_2.ogg")]
const OWL: = preload("res://assest/sounds/weather/night_owl.ogg")
const THUNDER: = [preload("res://assest/sounds/weather/thunder_1.ogg"), preload("res://assest/sounds/weather/thunder_2.ogg")]
const FADE_SECONDS: = 2.5
const BED_DB: = [-24.0, -23.0, -22.0, -24.0]
var active: = false
var kind: = -1
var daylight: = 1.0
var _owner: WeakRef
var _players: Array[AudioStreamPlayer] = []
var _event: AudioStreamPlayer
var _rng: = RandomNumberGenerator.new()
var _playback_allowed: = not OS.has_feature("web")
var _gains: = PackedFloat32Array([0, 0])
var _starts: = PackedFloat32Array([0, 0])
var _targets: = PackedFloat32Array([0, 0])
var _fade_elapsed: = 0.0
var _current: = -1
var _night: = false
var _next_event: = 0.0
var _event_fade: = 0.0
var _event_db: = -9.0
var _event_count: = 0
var _last_event: = ""
var _context_gain: = 1.0
var _last_tick: = 0
var _applied_db: = PackedFloat32Array([-999, -999])
var mix_writes: = 0

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	var bus: = AudioServer.get_bus_index("Ambience")
	if bus < 0:
		bus = AudioServer.get_bus_count()
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus, "Ambience")
		AudioServer.set_bus_send(bus, "Master")
	SettingsStore.apply_ambience_audio()
	for _i in 2:
		var player: = _make_player()
		_players.append(player)
	_event = _make_player()
	for stream in BEDS: stream.loop = true
	set_process(false)

func _make_player() -> AudioStreamPlayer:
	var player: = AudioStreamPlayer.new()
	player.bus = "Ambience"
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	player.max_polyphony = 1
	player.volume_db = -80
	add_child(player)
	return player

func bind_environment(owner: Node, weather: int, light: float) -> void :
	stop()
	_owner = weakref(owner)
	active = true
	_last_tick = Time.get_ticks_msec()
	_context_gain = 1.0
	_event_count = 0
	_last_event = ""
	set_process(true)
	sync(owner, weather, light)

func sync(owner: Node, weather: int, light: float) -> void :
	if not active or _owner == null or _owner.get_ref() != owner: return
	daylight = clampf(light, 0, 1)
	var night: = daylight < 0.18
	if kind == weather and _night == night: return
	var changed: = kind != weather
	kind = clampi(weather, 0, 3)
	_night = night

	if _event.playing: _event_fade = 0.25
	_next_event = _interval(true)
	if changed: _switch_bed()

func detach(owner: Node) -> void :
	if _owner != null and _owner.get_ref() == owner: stop()

func stop() -> void :
	active = false
	_owner = null
	kind = -1
	_current = -1
	_next_event = 0
	_event_fade = 0
	_gains.fill(0)
	_targets.fill(0)
	for player in _players: player.stop()
	if _event != null: _event.stop()
	set_process(false)

func unlock() -> void :
	if _playback_allowed: return
	_playback_allowed = true
	if active and _current >= 0:
		_gains.fill(0)
		_starts.fill(0)
		_fade_elapsed = 0
		_players[_current].volume_db = -80
		_applied_db[_current] = -80
		_players[_current].play()
		_last_tick = Time.get_ticks_msec()

func _switch_bed() -> void :

	var outgoing: = 0 if _gains[0] >= _gains[1] else 1
	var incoming: = 1 - outgoing
	var reuse: = false
	for i in 2:
		if _players[i].stream == BEDS[kind]:
			incoming = i
			reuse = _players[i].playing
	if not reuse:
		_players[incoming].stop()
		_players[incoming].stream = BEDS[kind]
		_players[incoming].volume_db = -80
		_applied_db[incoming] = -80
		_gains[incoming] = 0
	_starts = _gains.duplicate()
	_targets.fill(0)
	_targets[incoming] = 1
	_current = incoming
	_fade_elapsed = 0
	if _playback_allowed and not reuse: _players[incoming].play()

func _process(_delta: float) -> void :
	if not active: return
	var owner: Object = _owner.get_ref() if _owner != null else null
	if owner == null or not owner.running:
		stop()
		return

	var now: = Time.get_ticks_msec()
	var dt: = clampf(float(now - _last_tick) / 1000.0, 0, 0.2)
	_last_tick = now
	if not _playback_allowed: return
	_fade_elapsed = minf(FADE_SECONDS, _fade_elapsed + dt)
	var t: = smoothstep(0, 1, _fade_elapsed / FADE_SECONDS)
	var boss: bool = get_parent()._desired_bgm == get_parent().BgmKind.BOSS
	var context: = (0.48 if boss else 1.0) * (0.55 if get_tree().paused else 1.0)
	_context_gain = lerpf(_context_gain, context, 1.0 - exp( - dt * 4))
	var night_gain: = lerpf(0.52, 1, daylight) if kind == 0 else 1.0
	for i in 2:
		_gains[i] = sqrt(lerpf(_starts[i] * _starts[i], _targets[i], t))
		if not _players[i].playing: continue
		var bed_kind: = BEDS.find(_players[i].stream)
		var base: float = BED_DB[maxi(0, bed_kind)]
		var volume: = base + linear_to_db(maxf(0.0001, _gains[i] * _context_gain * night_gain))
		if absf(volume - _applied_db[i]) > 0.02:
			_players[i].volume_db = volume
			_applied_db[i] = volume
			mix_writes += 1
		if t >= 1 and _targets[i] == 0 and _players[i].playing: _players[i].stop()
	if _event_fade > 0:
		_event_fade = maxf(0, _event_fade - dt)
		if _event_fade == 0: _event.stop()
	if _event.playing:
		_event.volume_db = _event_db + linear_to_db(maxf(0.0001, _context_gain * (_event_fade / 0.25 if _event_fade > 0 else 1.0)))

	if get_tree().paused: return
	_next_event -= dt
	if _next_event <= 0 and not _event.playing:
		_play_event()
		_next_event = _interval(false)

func _interval(first: bool) -> float:
	if kind == 2: return _rng.randf_range(4, 7) if first else _rng.randf_range(16, 30)
	if kind == 0:
		if _night: return _rng.randf_range(2, 4) if first else _rng.randf_range(25, 45)
		return _rng.randf_range(0.6, 1.5) if first else _rng.randf_range(4, 9)
	return 30.0

func _play_event() -> void :
	if kind == 2:
		_event.stream = THUNDER[_rng.randi_range(0, THUNDER.size() - 1)]
		_event_db = -20
		_last_event = "thunder"
	elif kind == 0:
		_event.stream = OWL if _night else BIRDS[_rng.randi_range(0, BIRDS.size() - 1)]
		_event_db = -22 if _night else -16
		_last_event = "owl" if _night else "birds"
	else: return
	_event.pitch_scale = _rng.randf_range(0.97, 1.03)
	_event_fade = 0
	_event.volume_db = _event_db + linear_to_db(maxf(0.0001, _context_gain))
	_event.play()
	_event_count += 1

func describe() -> Dictionary:
	var voices: = 0
	for player in _players:
		if player.playing: voices += 1
	return {"active": active, "kind": kind, "bed_voices": voices, "event_voice": _event.playing, "events": _event_count, "last_event": _last_event, "duck": snappedf(_context_gain, 0.001), "volume": SettingsStore.ambience_linear}
