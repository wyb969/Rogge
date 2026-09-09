extends Node2D
@onready var pick_coin_audio_player: AudioStreamPlayer2D = $PickCoinAudioPlayer
@onready var upgrade_audio_player: AudioStreamPlayer2D = $UpgradeAudioPlayer
@onready var hurt_audio_player: AudioStreamPlayer2D = $HurtAudioPlayer
@onready var shoot_audio_player: AudioStreamPlayer2D = $ShootAudioPlayer
@onready var boss_audio_player: AudioStreamPlayer2D = $BossAudioPlayer
@onready var game_audio_player: AudioStreamPlayer2D = $GameAudioPlayer
@onready var menu_audio_player: AudioStreamPlayer2D = $MenuAudioPlayer
@onready var enemy_hurt_audio_player: AudioStreamPlayer2D = $EnemyHurtAudioPlayer

func play_shoot() -> void:
	shoot_audio_player.pitch_scale = randf_range(0.96, 1.04)
	shoot_audio_player.play()

func play_hit() -> void:
	hurt_audio_player.pitch_scale = randf_range(0.96, 1.04)
	hurt_audio_player.play()

func play_pickup() -> void:
	pick_coin_audio_player.pitch_scale = randf_range(0.95, 1.08)
	pick_coin_audio_player.play()

func play_enemy_hurt()->void:
	enemy_hurt_audio_player.pitch_scale = randf_range(0.95, 1.08)
	enemy_hurt_audio_player.play()

func play_upgrade() -> void:
	upgrade_audio_player.pitch_scale = 1.0
	upgrade_audio_player.play()

func play_menu_bgm() -> void:
	game_audio_player.stop()
	boss_audio_player.stop()
	if not menu_audio_player.playing:
		print("menu player play")
		menu_audio_player.play()

func play_game_bgm() -> void:
	menu_audio_player.stop()
	boss_audio_player.stop()
	if not game_audio_player.playing:
		game_audio_player.play()

func play_boss_bgm()->void:
	menu_audio_player.stop()
	game_audio_player.stop()
	if not boss_audio_player.playing:
		boss_audio_player.play()


func stop_bgm() -> void:
	menu_audio_player.stop()
	game_audio_player.stop()
