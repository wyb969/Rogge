extends Node

@onready var healing_pickup_audio_player: AudioStreamPlayer = $HealingPickupAudioPlayer
@onready var pick_coin_audio_player: AudioStreamPlayer = $PickCoinAudioPlayer
@onready var upgrade_audio_player: AudioStreamPlayer = $UpgradeAudioPlayer
@onready var hurt_audio_player: AudioStreamPlayer = $HurtAudioPlayer
@onready var shoot_audio_player: AudioStreamPlayer = $ShootAudioPlayer
@onready var boss_audio_player: AudioStreamPlayer = $BossAudioPlayer
@onready var game_audio_player: AudioStreamPlayer = $GameAudioPlayer
@onready var menu_audio_player: AudioStreamPlayer = $MenuAudioPlayer
@onready var enemy_hurt_audio_player: AudioStreamPlayer = $EnemyHurtAudioPlayer
@onready var victory_audio_player: AudioStreamPlayer = $VictoryAudioPlayer
@onready var game_over_audio_player: AudioStreamPlayer = $GameOverAudioPlayer
@onready var boss_warning_audio_player: AudioStreamPlayer = $BossWarningAudioPlayer
@onready var boss_alarm_audio_player: AudioStreamPlayer = $BossAlarmAudioPlayer
@onready var drone_spawn_audio_player: AudioStreamPlayer = $DroneSpawnAudioPlayer
@onready var drone_attack_audio_player: AudioStreamPlayer = $DroneAttackAudioPlayer
@onready var drone_despawn_audio_player: AudioStreamPlayer = $DroneDespawnAudioPlayer

enum BgmKind{NONE, MENU, GAME, BOSS}
signal game_track_changed(title: String)
signal pickup_tone_played(pitch: float)
const ADVENTURE_MUSIC: = preload("res://script/adventure_music.gd")
var adventure_music: Node
const WEATHER_AUDIO: = preload("res://script/weather_audio.gd")
var weather_audio: Node

const BEAST_MUSIC: = [preload("res://assest/sounds/beast_tide_8bit.wav"), preload("res://assest/sounds/beast_thunder_8bit.wav"), preload("res://assest/sounds/beast_gale_8bit.wav"), preload("res://assest/sounds/beast_aegis_8bit.wav")]
const FIRST_BOSS_MUSIC: = preload("res://assest/sounds/boss_bgm.mp3")
const KNIGHT_BOSS_MUSIC: = preload("res://assest/sounds/knight_boss_8bit.wav")

var _desired_bgm: BgmKind = BgmKind.NONE
var _web_audio_unlocked: bool = false
var _last_enemy_hurt_msec: = -10000
var _sfx_rng: = RandomNumberGenerator.new()
var _pickup_stamp: = -1000
var _pickup_note: = 0
const PICKUP_SCALE: = [0, 2, 4, 7, 9, 12]
var _juice_players: = {}
var _juice_stamps: = {}
var _beast_players: Array[AudioStreamPlayer] = []
var _beast_stamps: Array[int] = [-1000, -1000, -1000, -1000]
var beast_cues_played: Array[int] = [0, 0, 0, 0]
var _last_shot_msec: = -1000
const GUN_CUES: = [preload("res://assest/sounds/juice_shot_0.wav"), preload("res://assest/sounds/juice_shot_1.wav"), preload("res://assest/sounds/juice_shot_2.wav")]
const GUN_MIN_GAP: = 94
const GUN_PITCH: = [1.0, 1.025, 0.98, 1.01, 0.97, 1.015]
var gun_cues_played: = 0
var _gun_variant: = 0
var _gun_chain: = 0
var _focus_until_msec: = 0
var _music_duck: = 1.0
var _mix_tick: = 0
var _applied_music_gain: = -1.0
var _applied_mix_generation: = -1
var mix_writes: = 0
const JUICE_SOUNDS: = {"dash": preload("res://assest/sounds/juice_dash.wav"), "kill": preload("res://assest/sounds/juice_kill.wav"), "ready": preload("res://assest/sounds/juice_ready.wav"), "boss_lock": preload("res://assest/sounds/juice_boss_lock.wav"), "boss_rush": preload("res://assest/sounds/juice_boss_rush.wav")}
const BEAST_SOUNDS: = [preload("res://assest/sounds/beast_power_tide.wav"), preload("res://assest/sounds/beast_power_thunder.wav"), preload("res://assest/sounds/beast_power_gale.wav"), preload("res://assest/sounds/beast_power_aegis.wav")]

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_rng.randomize()
	_mix_tick = Time.get_ticks_msec()
	for bus_name in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) >= 0: continue
		var bus: = AudioServer.get_bus_count()
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus, bus_name)
		AudioServer.set_bus_send(bus, "Master")
	var music_players: = [game_audio_player, boss_audio_player, menu_audio_player, victory_audio_player, game_over_audio_player]
	for child in get_children():
		if not child is AudioStreamPlayer: continue
		child.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		child.bus = "Music" if child in music_players else "SFX"
	shoot_audio_player.stream = GUN_CUES[0]
	shoot_audio_player.max_polyphony = 1
	for key in JUICE_SOUNDS:
		var player: = AudioStreamPlayer.new()
		player.stream = JUICE_SOUNDS[key]
		player.volume_db = {"kill": -10.0, "dash": -8.0, "ready": -11.0, "boss_lock": -10.0, "boss_rush": -11.0}[key]
		player.max_polyphony = 1
		configure_sfx(player)
		add_child(player)
		_juice_players[key] = player
	for sound in BEAST_SOUNDS:
		var player: = AudioStreamPlayer.new()
		player.stream = sound
		player.volume_db = -7
		player.max_polyphony = 1
		configure_sfx(player)
		add_child(player)
		_beast_players.append(player)

	SettingsStore.apply_audio()
	SettingsStore.apply_mix()
	adventure_music = ADVENTURE_MUSIC.new()
	adventure_music.name = "AdventureMusic"
	adventure_music.configure(game_audio_player)
	add_child(adventure_music)
	adventure_music.track_changed.connect( func(_index: int, title: String): game_track_changed.emit(title))
	weather_audio = WEATHER_AUDIO.new()
	weather_audio.name = "WeatherAudio"
	add_child(weather_audio)

	set_process_input(OS.has_feature("web"))

func configure_sfx(player: AudioStreamPlayer) -> void :


	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	player.bus = "SFX"

func focus_sfx(seconds: float = 0.2) -> void :
	_focus_until_msec = maxi(_focus_until_msec, Time.get_ticks_msec() + int(seconds * 1000))

func _process(_delta: float) -> void :
	var now: = Time.get_ticks_msec()
	var dt: = clampf(float(now - _mix_tick) / 1000.0, 0, 0.1)
	_mix_tick = now
	var target: = 0.55 if now < _focus_until_msec else 1.0
	_music_duck = lerpf(_music_duck, target, 1 - exp( - dt * (35 if target < _music_duck else 5)))
	if absf(_music_duck - target) < 0.001: _music_duck = target
	var gain: float = SettingsStore.music_linear * _music_duck
	if absf(gain - _applied_music_gain) > 0.0001 or _applied_mix_generation != SettingsStore.mix_generation:
		var bus: = AudioServer.get_bus_index("Music")
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.0001, gain)))
			mix_writes += 1
		_applied_music_gain = gain
		_applied_mix_generation = SettingsStore.mix_generation

func _input(event: InputEvent) -> void :
	if _web_audio_unlocked:
		return
	if event is InputEventMouseButton and event.pressed:
		unlock_web_audio()
	elif event is InputEventScreenTouch and event.pressed:
		unlock_web_audio()
	elif event is InputEventKey and event.pressed:
		unlock_web_audio()

func unlock_web_audio() -> void :
	weather_audio.unlock()
	if _web_audio_unlocked:
		_resume_desired_bgm(false)
		return
	_web_audio_unlocked = true
	_resume_browser_audio_context()
	_resume_desired_bgm(true)

func play_shoot() -> void :
	var now: = Time.get_ticks_msec()
	var gap: = now - _last_shot_msec
	if gap < GUN_MIN_GAP: return
	_gun_chain = mini(_gun_chain + 1, 8) if gap < 220 else 0
	_last_shot_msec = now
	_ensure_web_ready()
	shoot_audio_player.stream = GUN_CUES[_gun_variant % GUN_CUES.size()]
	shoot_audio_player.pitch_scale = GUN_PITCH[_gun_variant % GUN_PITCH.size()]
	var pickup_focus: = now - _pickup_stamp < 180 and _pickup_note >= 2
	shoot_audio_player.volume_db = -13.0 - float(_gun_chain) * 0.5 - (3.0 if pickup_focus else 0.0)
	shoot_audio_player.play()
	_gun_variant = (_gun_variant + 1) % 6
	gun_cues_played += 1

func stop_gun_audio() -> void :
	shoot_audio_player.stop()
	_last_shot_msec = -1000
	_gun_chain = 0
	_gun_variant = 0

func play_hit() -> void :
	focus_sfx(0.3)
	_ensure_web_ready()
	hurt_audio_player.pitch_scale = _sfx_rng.randf_range(0.96, 1.04)
	hurt_audio_player.play()

func play_pickup() -> void :
	var now: = Time.get_ticks_msec()
	if now - _pickup_stamp < 65: return
	_pickup_note = 0 if now - _pickup_stamp > 450 else mini(_pickup_note + 1, 5)
	_pickup_stamp = now
	_ensure_web_ready()
	pick_coin_audio_player.pitch_scale = pow(2.0, float(PICKUP_SCALE[_pickup_note]) / 12.0)
	pick_coin_audio_player.volume_db = -10
	pick_coin_audio_player.play()
	pickup_tone_played.emit(pick_coin_audio_player.pitch_scale)

func reset_pickup_combo() -> void :
	_pickup_stamp = -1000
	_pickup_note = 0
	pick_coin_audio_player.pitch_scale = 1

func play_juice(kind: String) -> void :
	if not _juice_players.has(kind): return
	var now: = Time.get_ticks_msec()
	if now - int(_juice_stamps.get(kind, -1000)) < (140 if kind == "kill" else 100): return
	_juice_stamps[kind] = now
	if kind != "ready": focus_sfx()
	_ensure_web_ready()
	var player: AudioStreamPlayer = _juice_players[kind]
	player.pitch_scale = _sfx_rng.randf_range(0.97, 1.03)
	player.play()

func play_healing_pickup() -> void :
	focus_sfx()
	_ensure_web_ready()
	healing_pickup_audio_player.pitch_scale = _sfx_rng.randf_range(0.97, 1.03)
	healing_pickup_audio_player.play()

func play_beast_power(index: int) -> void :
	if index < 0 or index >= _beast_players.size(): return
	var now: = Time.get_ticks_msec()
	if now - _beast_stamps[index] < 100: return
	_beast_stamps[index] = now
	focus_sfx(0.45)
	_ensure_web_ready()
	_beast_players[index].play()
	beast_cues_played[index] += 1

func stop_beast_power_audio() -> void :
	for i in _beast_players.size():
		_beast_players[i].stop()
		_beast_stamps[i] = -1000

func play_enemy_hurt() -> void :
	var now: = Time.get_ticks_msec()
	if now - _last_enemy_hurt_msec < 100:
		return
	_last_enemy_hurt_msec = now
	_ensure_web_ready()
	enemy_hurt_audio_player.pitch_scale = _sfx_rng.randf_range(0.95, 1.08)
	var rapid_gun: = _gun_chain >= 3 and now - _last_shot_msec < 220
	enemy_hurt_audio_player.volume_db = -14 if rapid_gun else -6
	enemy_hurt_audio_player.play()

func play_upgrade() -> void :
	focus_sfx(0.3)
	_ensure_web_ready()
	upgrade_audio_player.pitch_scale = 1.0
	upgrade_audio_player.play()

func play_drone_spawn() -> void :
	_ensure_web_ready()
	if drone_spawn_audio_player == null:
		return
	drone_spawn_audio_player.pitch_scale = _sfx_rng.randf_range(0.94, 1.08)
	drone_spawn_audio_player.volume_db = -2.0
	drone_spawn_audio_player.play()

func play_drone_attack() -> void :
	_ensure_web_ready()
	if drone_attack_audio_player == null:
		return
	drone_attack_audio_player.pitch_scale = _sfx_rng.randf_range(0.97, 1.06)
	drone_attack_audio_player.volume_db = -4.0
	drone_attack_audio_player.play()

func play_drone_despawn() -> void :
	_ensure_web_ready()
	if drone_despawn_audio_player == null:
		return
	drone_despawn_audio_player.pitch_scale = _sfx_rng.randf_range(0.9, 1.05)
	drone_despawn_audio_player.volume_db = -3.0
	drone_despawn_audio_player.play()

func play_menu_bgm() -> void :
	stop_gun_audio()
	weather_audio.stop()
	_desired_bgm = BgmKind.MENU
	_stop_result_sfx()
	adventure_music.stop()
	boss_audio_player.stop()
	_play_bgm_player(menu_audio_player)

func play_game_bgm(stage: int = 1, new_run: bool = false) -> void :
	_desired_bgm = BgmKind.GAME
	_stop_result_sfx()
	menu_audio_player.stop()
	boss_audio_player.stop()
	adventure_music.play_stage(stage, new_run, not OS.has_feature("web") or _web_audio_unlocked)
	_ensure_web_ready()

func preview_game_bgm_next() -> void :
	_desired_bgm = BgmKind.GAME
	_stop_result_sfx()
	menu_audio_player.stop()
	boss_audio_player.stop()
	adventure_music.preview_next( not OS.has_feature("web") or _web_audio_unlocked)
	_ensure_web_ready()

func play_boss_bgm(stage: int = 1) -> void :
	_desired_bgm = BgmKind.BOSS
	_ensure_web_ready()
	_stop_result_sfx()
	menu_audio_player.stop()
	adventure_music.stop()
	var selected: AudioStream = BEAST_MUSIC[clampi(stage - 3, 0, 3)] if stage >= 3 else (KNIGHT_BOSS_MUSIC if stage == 2 else FIRST_BOSS_MUSIC)
	if boss_audio_player.stream != selected:
		boss_audio_player.stop()
		boss_audio_player.stream = selected
	boss_audio_player.volume_db = -4.0 if stage >= 2 else 0.0
	_play_bgm_player(boss_audio_player)

func play_boss_warning() -> void :

	_ensure_web_ready()
	if boss_warning_audio_player:
		boss_warning_audio_player.pitch_scale = 0.85
		boss_warning_audio_player.volume_db = 2.0
		boss_warning_audio_player.play()
	_play_boss_alarm_pattern()

func _play_boss_alarm_pattern() -> void :
	if boss_alarm_audio_player == null:
		return

	for i in 3:
		var t: = get_tree().create_timer(0.12 + float(i) * 0.22)
		var pitch: = 0.9 + float(i) * 0.18
		t.timeout.connect( func():
			if not is_instance_valid(boss_alarm_audio_player):
				return
			boss_alarm_audio_player.pitch_scale = pitch
			boss_alarm_audio_player.volume_db = 1.5
			boss_alarm_audio_player.play()
		)

func play_victory() -> void :
	_desired_bgm = BgmKind.NONE
	_ensure_web_ready()
	stop_bgm()
	if not victory_audio_player.playing:
		victory_audio_player.play()

func play_game_over() -> void :
	_desired_bgm = BgmKind.NONE
	_ensure_web_ready()
	stop_bgm()
	if not game_over_audio_player.playing:
		game_over_audio_player.play()

func stop_bgm() -> void :
	weather_audio.stop()
	_desired_bgm = BgmKind.NONE
	menu_audio_player.stop()
	adventure_music.stop()
	boss_audio_player.stop()

func _stop_result_sfx() -> void :
	victory_audio_player.stop()
	game_over_audio_player.stop()

func _ensure_web_ready() -> void :
	if OS.has_feature("web") and not _web_audio_unlocked:
		unlock_web_audio()

func _play_bgm_player(player: AudioStreamPlayer) -> void :
	if player == null:
		return
	if OS.has_feature("web") and not _web_audio_unlocked:

		return
	if not player.playing:
		player.play()

func _resume_desired_bgm(force: bool = false) -> void :
	match _desired_bgm:
		BgmKind.MENU:
			if force or not menu_audio_player.playing:
				menu_audio_player.play()
		BgmKind.GAME:
			adventure_music.unlock()
		BgmKind.BOSS:
			if force or not boss_audio_player.playing:
				boss_audio_player.play()
		_:
			pass

func _resume_browser_audio_context() -> void :
	if not OS.has_feature("web"):
		return


	var js = Engine.get_singleton("JavaScriptBridge")
	if js != null and js.has_method("eval"):
		js.eval(
			"(function(){try{if(typeof GodotAudio!=='undefined'&&GodotAudio.ctx){GodotAudio.ctx.resume();}if(window.Godot&&window.Godot.audioContext){window.Godot.audioContext.resume();}}catch(e){}})();", 
			true
		)
