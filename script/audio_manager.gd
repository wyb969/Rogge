extends Node

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

enum BgmKind { NONE, MENU, GAME, BOSS }

var _desired_bgm: BgmKind = BgmKind.NONE
var _web_audio_unlocked: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Saved master volume. SettingsStore loads before this autoload.
	SettingsStore.apply_audio()
	# Web browsers block audio until a real user gesture.
	set_process_input(OS.has_feature("web"))

func _input(event: InputEvent) -> void:
	if _web_audio_unlocked:
		return
	if event is InputEventMouseButton and event.pressed:
		unlock_web_audio()
	elif event is InputEventScreenTouch and event.pressed:
		unlock_web_audio()
	elif event is InputEventKey and event.pressed:
		unlock_web_audio()

func unlock_web_audio() -> void:
	if _web_audio_unlocked:
		_resume_desired_bgm(false)
		return
	_web_audio_unlocked = true
	_resume_browser_audio_context()
	_resume_desired_bgm(true)

func play_shoot() -> void:
	_ensure_web_ready()
	shoot_audio_player.pitch_scale = randf_range(0.96, 1.04)
	shoot_audio_player.play()

func play_hit() -> void:
	_ensure_web_ready()
	hurt_audio_player.pitch_scale = randf_range(0.96, 1.04)
	hurt_audio_player.play()

func play_pickup() -> void:
	_ensure_web_ready()
	pick_coin_audio_player.pitch_scale = randf_range(0.95, 1.08)
	pick_coin_audio_player.play()

func play_enemy_hurt() -> void:
	_ensure_web_ready()
	enemy_hurt_audio_player.pitch_scale = randf_range(0.95, 1.08)
	enemy_hurt_audio_player.play()

func play_upgrade() -> void:
	_ensure_web_ready()
	upgrade_audio_player.pitch_scale = 1.0
	upgrade_audio_player.play()

func play_drone_spawn() -> void:
	_ensure_web_ready()
	if drone_spawn_audio_player == null:
		return
	drone_spawn_audio_player.pitch_scale = randf_range(0.94, 1.08)
	drone_spawn_audio_player.volume_db = -2.0
	drone_spawn_audio_player.play()

func play_drone_attack() -> void:
	_ensure_web_ready()
	if drone_attack_audio_player == null:
		return
	drone_attack_audio_player.pitch_scale = randf_range(0.97, 1.06)
	drone_attack_audio_player.volume_db = -4.0
	drone_attack_audio_player.play()

func play_drone_despawn() -> void:
	_ensure_web_ready()
	if drone_despawn_audio_player == null:
		return
	drone_despawn_audio_player.pitch_scale = randf_range(0.9, 1.05)
	drone_despawn_audio_player.volume_db = -3.0
	drone_despawn_audio_player.play()

func play_menu_bgm() -> void:
	_desired_bgm = BgmKind.MENU
	_stop_result_sfx()
	game_audio_player.stop()
	boss_audio_player.stop()
	_play_bgm_player(menu_audio_player)

func play_game_bgm() -> void:
	_desired_bgm = BgmKind.GAME
	_ensure_web_ready()
	_stop_result_sfx()
	menu_audio_player.stop()
	boss_audio_player.stop()
	_play_bgm_player(game_audio_player)

func play_boss_bgm() -> void:
	_desired_bgm = BgmKind.BOSS
	_ensure_web_ready()
	_stop_result_sfx()
	menu_audio_player.stop()
	game_audio_player.stop()
	_play_bgm_player(boss_audio_player)

func play_boss_warning() -> void:
	## Alarm stinger before the boss appears: boom + rising beeps.
	_ensure_web_ready()
	if boss_warning_audio_player:
		boss_warning_audio_player.pitch_scale = 0.85
		boss_warning_audio_player.volume_db = 2.0
		boss_warning_audio_player.play()
	_play_boss_alarm_pattern()

func _play_boss_alarm_pattern() -> void:
	if boss_alarm_audio_player == null:
		return
	# Three urgent beeps using the existing tap/power-up style SFX.
	for i in 3:
		var t := get_tree().create_timer(0.12 + float(i) * 0.22)
		var pitch := 0.9 + float(i) * 0.18
		t.timeout.connect(func():
			if not is_instance_valid(boss_alarm_audio_player):
				return
			boss_alarm_audio_player.pitch_scale = pitch
			boss_alarm_audio_player.volume_db = 1.5
			boss_alarm_audio_player.play()
		)

func play_victory() -> void:
	_desired_bgm = BgmKind.NONE
	_ensure_web_ready()
	stop_bgm()
	if not victory_audio_player.playing:
		victory_audio_player.play()

func play_game_over() -> void:
	_desired_bgm = BgmKind.NONE
	_ensure_web_ready()
	stop_bgm()
	if not game_over_audio_player.playing:
		game_over_audio_player.play()

func stop_bgm() -> void:
	menu_audio_player.stop()
	game_audio_player.stop()
	boss_audio_player.stop()

func _stop_result_sfx() -> void:
	victory_audio_player.stop()
	game_over_audio_player.stop()

func _ensure_web_ready() -> void:
	if OS.has_feature("web") and not _web_audio_unlocked:
		unlock_web_audio()

func _play_bgm_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if OS.has_feature("web") and not _web_audio_unlocked:
		# Wait for first tap/click; unlock_web_audio will resume.
		return
	if not player.playing:
		player.play()

func _resume_desired_bgm(force: bool = false) -> void:
	match _desired_bgm:
		BgmKind.MENU:
			if force or not menu_audio_player.playing:
				menu_audio_player.play()
		BgmKind.GAME:
			if force or not game_audio_player.playing:
				game_audio_player.play()
		BgmKind.BOSS:
			if force or not boss_audio_player.playing:
				boss_audio_player.play()
		_:
			pass

func _resume_browser_audio_context() -> void:
	if not OS.has_feature("web"):
		return
	# Avoid hard JavaScriptBridge dependency (missing on desktop builds).
	# Godot web runtime resumes AudioContext on the next play() after a gesture.
	var js = Engine.get_singleton("JavaScriptBridge")
	if js != null and js.has_method("eval"):
		js.eval(
			"(function(){try{if(typeof GodotAudio!=='undefined'&&GodotAudio.ctx){GodotAudio.ctx.resume();}if(window.Godot&&window.Godot.audioContext){window.Godot.audioContext.resume();}}catch(e){}})();",
			true
		)
