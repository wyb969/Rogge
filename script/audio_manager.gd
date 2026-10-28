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

enum BgmKind { NONE, MENU, GAME, BOSS }

var _desired_bgm: BgmKind = BgmKind.NONE
var _web_audio_unlocked: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, false)
		AudioServer.set_bus_volume_db(master_idx, 0.0)
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
