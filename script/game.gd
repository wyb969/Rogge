extends Node2D
@onready var player: CharacterBody2D = $Player
@onready var level_manager: Node2D = $LevelManager
@onready var hand_weapon: Node2D = $HandWeapon
@onready var circle_weapon: Node2D = $CircleWeapon
@onready var pause_menu: CanvasLayer = $Node2D
@onready var gun_weapon: Node2D = $Weapon
@onready var level_ui = $LevelManager / UI
@onready var spawner_ui = $Spawner / UI
@onready var spawner: Node2D = $Spawner
@onready var pickup_container: Node2D = $PickupContainer
@onready var effect_container: Node2D = $EffectContainer
@onready var hud_layer: CanvasLayer = $HudLayer
@onready var equipment_panel: Control = $HudLayer / EquipmentPanel
@onready var drone_controller: Node2D = $DroneController
@onready var molotov_controller: Node2D = $MolotovController
@onready var freeze_controller: Node2D = $FreezeController

const TRIALS: = preload("res://script/trials.gd")
const RUN_DIFFICULTY: = preload("res://script/run_difficulty.gd")
var run_difficulty: RefCounted = RUN_DIFFICULTY.new()
const SPEED_TRIAL_ENABLED: = true
var trials: Node
var _trial_pending: = ""
const DAMAGE_FLASH: = preload("res://script/damage_flash.gd")
var damage_flash: CanvasLayer
const COMBAT_FEEDBACK: = preload("res://script/combat_feedback.gd")
var combat_feedback: Node2D
const COMBAT_LIGHTING: = preload("res://script/combat_lighting.gd")
var combat_lighting: Node2D
var burn_spread: Node
const ENVIRONMENT_WEATHER: = preload("res://script/environment_weather.gd")
var weather: Node
const RUN_VARIETY: = preload("res://script/run_variety.gd")
var variety: Node2D
const METEOR_SHOWER: = preload("res://script/meteor_shower.gd")
var meteors: Node2D
const POISON_TRAIL: = preload("res://script/poison_trail.gd")
var poison_trail: Node2D
const BANANA_FAN := preload("res://script/banana_fan.gd")
const BLACK_HOLE := preload("res://script/black_hole.gd")
var banana_fan: Node2D
var black_hole: Node2D
const BEAST_POWERS: = preload("res://script/beast_powers.gd")
const LIGHTNING_FX: = preload("res://script/lightning_strike.gd")
const LIGHTNING_RING: = preload("res://script/lightning_ring.gd")
var lightning_ring: Node2D
var beast_powers: Node2D
var _blessing_pending: = -1

var current_level: int = 1
var diagnostic_mode: = "normal"


const DEATH_SLOWMO_SCALE: = 0.08
const DEATH_SLOWMO_SEC: = 0.45
var _death_presented: bool = false
const HEALING_ORB_SCENE: = preload("res://scenes/healing_orb.tscn")
const XP_COIN_SCENE: = preload("res://scenes/coin.tscn")
const XP_COIN_SCRIPT: = preload("res://script/coin.gd")
const HEALING_ORB_SCRIPT: = preload("res://script/healing_orb.gd")
const CHAIN_SCENE: = preload("res://scenes/chain_lightning_effect.tscn")
const MAX_IDLE_CHAINS: = 32
var _xp_actors: Array[Node2D] = []
var _healing_actors: Array[Node2D] = []
var _idle_chains: Array[Node2D] = []
var chains_created: = 0
var chains_reused: = 0
const MAX_XP_COINS: = 256
const MAX_HEALING_ORBS: = 96
const REST_HUB_SCENE: = preload("res://scenes/rest_hub.tscn")
const TREASURE_LOTTERY: = preload("res://script/treasure_lottery.gd")
var treasure_lottery: CanvasLayer
var _lottery_pending: = false
var _rest_pending: = false
var _level_reward_queue: Array[int] = []
var rest_hub: CanvasLayer
signal game_over(stats: Dictionary)

func _ready() -> void :
	pickup_container.child_entered_tree.connect(_pickup_entered)
	pickup_container.child_exiting_tree.connect(_pickup_exited)
	_capture_difficulty()
	weather = ENVIRONMENT_WEATHER.new()
	weather.name = "EnvironmentWeather"
	add_child(weather)
	combat_feedback = COMBAT_FEEDBACK.new()
	combat_feedback.name = "CombatFeedback"
	add_child(combat_feedback)
	set_meta(&"rogge_feedback", weakref(combat_feedback))
	combat_lighting = COMBAT_LIGHTING.new()
	combat_lighting.name = "CombatLighting"
	add_child(combat_lighting)
	burn_spread = preload("res://script/burn_spread.gd").new()
	burn_spread.name = "BurnSpread"
	add_child(burn_spread)
	damage_flash = DAMAGE_FLASH.new()
	damage_flash.name = "DamageFlash"
	add_child(damage_flash)
	player.health_damaged.connect(damage_flash.flash)
	beast_powers = BEAST_POWERS.new()
	beast_powers.name = "BeastPowers"
	add_child(beast_powers)
	beast_powers.blessing_claimed.connect(_on_blessing_claimed)
	trials = TRIALS.new()
	trials.name = "Trials"
	add_child(trials)
	trials.completed.connect(_on_trial_completed)
	lightning_ring = LIGHTNING_RING.new()
	lightning_ring.name = "LightningRing"
	add_child(lightning_ring)
	variety = RUN_VARIETY.new()
	variety.name = "RunVariety"
	add_child(variety)
	player.dash_completed.connect(variety.on_dash_completed)
	meteors = METEOR_SHOWER.new()
	meteors.name = "MeteorShower"
	add_child(meteors)
	poison_trail = POISON_TRAIL.new()
	poison_trail.name = "PoisonTrail"
	add_child(poison_trail)
	banana_fan = BANANA_FAN.new()
	banana_fan.name = "BananaFan"
	add_child(banana_fan)
	black_hole = BLACK_HOLE.new()
	black_hole.name = "BlackHole"
	add_child(black_hole)
	spawner.beast_defeated.connect(_on_beast_defeated)
	level_manager.signal_level_up.connect(on_level_up)
	pause_menu.upgrade_selected.connect(_on_upgrade_selected)
	pause_menu.upgrade_selected.connect( func(_id: String): call_deferred("_show_next_reward"))
	spawner.treasure_earned.connect(_on_treasure_earned)
	player.player_died.connect(on_player_died)
	spawner.boss_defeated.connect(on_boss_defeated)
	if spawner.has_signal("stage_advanced"):
		spawner.stage_advanced.connect(_on_stage_advanced)
	if spawner.has_signal("rest_requested"):
		spawner.rest_requested.connect(_on_rest_requested)
	if equipment_panel and equipment_panel.has_method("reset_equipment"):
		equipment_panel.reset_equipment()
	_reset_skill_controllers()

func prepare_game() -> void :
	player.reset_dash()
	weather.stop()
	combat_feedback.reset()
	RunDiagnostics.finish("return_to_menu")
	trials.reset()
	damage_flash.reset()
	spawner.stop_run()
	beast_powers.set_hud_visible(false)
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if level_ui:
		level_ui.hide()
	else:
		print(" level ui null")
	if spawner_ui:
		spawner_ui.hide()
	if hud_layer:
		hud_layer.hide()
	_reset_skill_controllers()

func start_game() -> void :
	combat_feedback.start()
	_capture_difficulty()
	spawner.start_run()
	beast_powers.set_hud_visible(true)
	$InfiniteBackground.begin_run()
	weather.begin_run()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if level_ui:
		level_ui.show()
	if spawner_ui:
		spawner_ui.show()
	if hud_layer:
		hud_layer.show()
	if equipment_panel and equipment_panel.has_method("reset_equipment"):
		equipment_panel.reset_equipment()
	_reset_skill_controllers()
	RunDiagnostics.begin(self, diagnostic_mode)
	variety.begin_run()
	combat_lighting.begin_run()
	meteors.begin_run()
	pause_menu.reset_draft()

func end_game() -> void :
	player.reset_dash()
	weather.stop()
	combat_feedback.reset()
	RunDiagnostics.finish("game_ended")
	_trial_pending = ""
	trials.reset()
	damage_flash.reset()
	spawner.stop_run()
	beast_powers.reset_effects()
	_lottery_pending = false
	_rest_pending = false
	_level_reward_queue.clear()
	if is_instance_valid(treasure_lottery):
		treasure_lottery.hide()
	clear_run_objects()
	_reset_skill_controllers()
	if rest_hub and rest_hub.has_method("close_hub"):
		rest_hub.close_hub()
	process_mode = Node.PROCESS_MODE_DISABLED
	if level_ui:
		level_ui.hide()
	if spawner_ui:
		spawner_ui.hide()
	if hud_layer:
		hud_layer.hide()
	clear_enemies()
	hide()

func _reset_skill_controllers() -> void :

	for entry in CombatTargets._entries:
		var actor: Node = entry.actor
		if is_instance_valid(actor) and is_ancestor_of(actor) and actor.has_method("suspend_feedback"):
			actor.suspend_feedback()
	var playground: = get_node_or_null("FeedbackPlayground")
	if playground != null: playground.stop()
	AudioManager.stop_gun_audio()
	if burn_spread: burn_spread.reset()
	if combat_lighting: combat_lighting.reset()
	if level_manager: level_manager.reset_feedback()
	if meteors: meteors.reset()
	if poison_trail: poison_trail.reset()
	if banana_fan: banana_fan.reset()
	if black_hole: black_hole.reset()
	if variety: variety.reset()
	if lightning_ring:
		lightning_ring.reset()
	if drone_controller and drone_controller.has_method("reset"):
		drone_controller.reset()
	if molotov_controller and molotov_controller.has_method("reset"):
		molotov_controller.reset()
	if freeze_controller and freeze_controller.has_method("reset"):
		freeze_controller.reset()

func _capture_difficulty() -> void :
	run_difficulty = RUN_DIFFICULTY.new(SettingsStore.difficulty)
	player.healing_multiplier = run_difficulty.healing_scale

func clear_enemies() -> void :
	if burn_spread: burn_spread.reset()
	for enemy in get_tree().get_nodes_in_group("EnemyGroup"):
		if is_instance_valid(enemy):
			enemy.queue_free()

func show_lightning_strikes(targets: Array[Vector2], color: Color) -> Node2D:
	var effect: = LIGHTNING_FX.new()
	effect.setup(targets, color)
	effect_container.add_child(effect)
	return effect

func _process(_delta: float) -> void :
	pass

func on_level_up(level: int) -> void :
	current_level = level
	player.apply_level_growth(level)
	RunDiagnostics.mark("level_up", {"level": level}, true)
	spawner.handle_level_up(current_level)
	_level_reward_queue.append(level)
	_show_next_reward()

func _on_timer_timeout() -> void :
	pass

func _on_upgrade_selected(upgrade_id: String):
	if equipment_panel.EQUIP_DEFS.has(upgrade_id):
		var max_rank: int = equipment_panel.EQUIP_DEFS[upgrade_id].get("max_level", 2147483647)
		if equipment_panel.get_level(upgrade_id) >= max_rank: return
	RunDiagnostics.mark("before_card", {"id": upgrade_id}, true)
	match upgrade_id:
		"axe_up":
			hand_weapon.handle_level_up(current_level)
		"circle_up":
			circle_weapon.handle_level_up(current_level)
		"speed_up":
			player.speed_up(20)
		"gun_up":
			gun_weapon.upgrade()
		"pickup_up":
			player.pick_up_upgrade(1.2)
		"left_fist":
			player.upgrade_left_fist()
		"right_fist":
			player.upgrade_right_fist()
		"drone_up":
			drone_controller.upgrade()
		"molotov_up":
			molotov_controller.upgrade()
		"freeze_up":
			freeze_controller.upgrade()
		"regen_up":
			player.add_regen_level()
		"lifesteal_up":
			player.add_lifesteal_level()
		"shield_up":
			player.add_shield_level()
		"monster_necklace":
			player.add_monster_necklace_level()
		"lightning_ring":
			lightning_ring.upgrade()
		"wind_emblem", "echo_ember":
			variety.upgrade(upgrade_id)
		"poison_trail":
			poison_trail.upgrade()
		"banana_fan":
			banana_fan.upgrade()
		"black_hole":
			black_hole.upgrade()

	if spawner and spawner.has_method("note_offense_card") and upgrade_id in [
		"axe_up", "circle_up", "gun_up", "left_fist", "right_fist", 
		"drone_up", "molotov_up", "freeze_up", "lightning_ring", 
		"wind_emblem", "echo_ember", 
		"poison_trail", 
		"banana_fan", "black_hole",
	]:
		spawner.note_offense_card()

	if equipment_panel and equipment_panel.has_method("apply_upgrade"):
		equipment_panel.apply_upgrade(upgrade_id)
	combat_feedback.reward(player.global_position)
	RunDiagnostics.mark("after_card", {"id": upgrade_id}, true)

func on_coin_collected(amount: int = 2) -> void :
	level_manager.add_coin(run_difficulty.experience_for(amount))

func spawn_xp_coin(at: Vector2, raw_xp: int) -> void :


	call_deferred("_spawn_xp_coin_now", at, raw_xp)

func _spawn_xp_coin_now(at: Vector2, raw_xp: int) -> void :
	if not is_inside_tree() or is_queued_for_deletion() or process_mode == Node.PROCESS_MODE_DISABLED:
		return
	var prepared: int = run_difficulty.experience_for(raw_xp)
	var nearest: Node2D
	if _xp_actors.size() >= MAX_XP_COINS:
		var candidate: = _nearest_pickup(_xp_actors, at)
		if _xp_actors.size() >= MAX_XP_COINS: nearest = candidate
	if nearest != null:
		if nearest.prepared_xp < 0:
			nearest.prepared_xp = run_difficulty.experience_for(nearest.xp_value)
		nearest.xp_value += raw_xp
		nearest.prepared_xp += prepared
		return
	var coin: = XP_COIN_SCENE.instantiate()
	coin.xp_value = raw_xp
	coin.prepared_xp = prepared
	coin.coin_collected.connect(_on_prepared_coin_collected.bind(coin))
	pickup_container.add_child(coin)
	coin.global_position = at

func _on_prepared_coin_collected(_raw: int, coin: Node) -> void :
	level_manager.add_coin(coin.prepared_xp)

func on_player_died() -> void :
	if trials.active_fight():
		trials.fail("生命耗尽：这次试炼未通过。")
		return
	if _death_presented:
		return
	_death_presented = true



	get_tree().set_meta("player_death_slowmo", true)
	Engine.time_scale = DEATH_SLOWMO_SCALE
	var veil: = _show_death_veil()
	await _hold_death_beat()
	if is_instance_valid(veil):
		veil.queue_free()
	if get_tree().has_meta("player_death_slowmo"):
		get_tree().remove_meta("player_death_slowmo")
	Engine.time_scale = 1.0
	if not is_inside_tree():
		return
	var stats: = _build_run_stats(false)
	game_over.emit(stats)

func _hold_death_beat() -> void :


	var started: = Time.get_ticks_msec()
	var limit: = int(DEATH_SLOWMO_SEC * 1000.0)
	while Time.get_ticks_msec() - started < limit:
		Engine.time_scale = DEATH_SLOWMO_SCALE
		await get_tree().process_frame

func _show_death_veil() -> CanvasLayer:
	var layer: = CanvasLayer.new()
	layer.name = "DeathSlowmoVeil"
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var rect: = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0.7, 0.05, 0.04, 0.34)
	layer.add_child(rect)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	return layer

func on_boss_defeated() -> void :
	Engine.time_scale = 1.0
	clear_enemies()
	var stats: = _build_run_stats(true)
	game_over.emit(stats)

func _on_rest_requested() -> void :
	Engine.time_scale = 1.0
	_rest_pending = true
	call_deferred("_show_next_reward")

func _open_rest_hub() -> void :
	variety.clear_combat_effects()
	if player and player.has_method("full_heal"):
		player.full_heal()
	if rest_hub == null or not is_instance_valid(rest_hub):
		rest_hub = REST_HUB_SCENE.instantiate()
		rest_hub.reward_picked.connect(_on_rest_reward)
		rest_hub.next_stage_pressed.connect(_on_rest_next_stage)
		add_child(rest_hub)
	rest_hub.open_hub()
	get_tree().paused = true

func _on_rest_reward(reward_id: String) -> void :
	if player == null or rest_hub == null:
		return
	match reward_id:
		"max_hp":
			player.apply_rest_max_hp(rest_hub.MAX_HP_BONUS)
		"defense":
			player.apply_rest_defense(rest_hub.DEFENSE_BONUS)
		"move_speed":
			player.apply_rest_move_speed(rest_hub.MOVE_SPEED_BONUS)
		"cooldown":
			var scale: float = player.apply_rest_cooldown(rest_hub.COOLDOWN_SCALE)
			if gun_weapon and gun_weapon.has_method("apply_cooldown_scale"):
				gun_weapon.apply_cooldown_scale(scale)
		"regen_up":
			player.add_regen_level()
		"lifesteal_up":
			player.add_lifesteal_level()
		"shield_up":
			player.add_shield_level()
		"monster_necklace":
			player.add_monster_necklace_level()
			if equipment_panel:
				equipment_panel.apply_upgrade(reward_id)

func _on_rest_next_stage() -> void :
	if rest_hub and rest_hub.has_method("close_hub"):
		rest_hub.close_hub()
	get_tree().paused = false
	Engine.time_scale = 1.0
	if spawner and spawner.has_method("begin_next_stage"):
		spawner.begin_next_stage()

func _on_stage_advanced(next_stage: int) -> void :
	variety.clear_combat_effects()
	Engine.time_scale = 1.0
	var bg: = get_node_or_null("InfiniteBackground")
	if bg != null and bg.has_method("apply_stage"):
		bg.apply_stage(next_stage)
	weather.apply_stage(next_stage)
	RunDiagnostics.mark("stage_enter", {"stage": next_stage}, true)
	if AudioManager.has_method("play_game_bgm"):
		AudioManager.play_game_bgm(next_stage)

func _build_run_stats(victory: bool) -> Dictionary:
	var stage_num: = 1
	if spawner != null and "stage" in spawner:
		stage_num = int(spawner.stage)
	return {
		"minutes": spawner.minute, 
		"seconds": spawner.second, 
		"kills": spawner.enemy_killed_num, 
		"level": current_level, 
		"stage": stage_num, 
		"victory": victory, 
		"difficulty": run_difficulty.index, 
		"trials": trials.results.duplicate(true)
	}

func clear_container(container: Node) -> void :
	for child in container.get_children():
		child.queue_free()

func clear_run_objects() -> void :
	_idle_chains.clear()
	clear_container(pickup_container)
	clear_container(effect_container)

func _pickup_entered(node: Node) -> void :

	if node is XP_COIN_SCRIPT: _xp_actors.append(node)
	elif node is HEALING_ORB_SCRIPT: _healing_actors.append(node)

func _pickup_exited(node: Node) -> void :
	if node is XP_COIN_SCRIPT: _xp_actors.erase(node)
	elif node is HEALING_ORB_SCRIPT: _healing_actors.erase(node)

func _nearest_pickup(actors: Array[Node2D], at: Vector2, healing: bool = false) -> Node2D:
	var nearest: Node2D
	var distance: = INF
	var i: = actors.size() - 1
	while i >= 0:
		var actor: = actors[i]


		if actor.is_queued_for_deletion() or (healing and actor.collected):
			actors.remove_at(i)
			i -= 1
			continue
		var next: = actor.global_position.distance_squared_to(at)
		if next < distance:
			distance = next
			nearest = actor
		i -= 1
	return nearest

func acquire_chain_lightning() -> Node2D:
	if not is_inside_tree() or process_mode == Node.PROCESS_MODE_DISABLED: return null
	while not _idle_chains.is_empty():
		var cached: = _idle_chains.pop_back() as Node2D
		if is_instance_valid(cached) and not cached.is_queued_for_deletion():
			chains_reused += 1
			return cached
	var chain: = CHAIN_SCENE.instantiate() as Node2D
	chain.pool_owner = weakref(self)
	effect_container.add_child(chain)
	chains_created += 1
	return chain

func recycle_chain_lightning(chain: Node2D) -> void :
	if process_mode == Node.PROCESS_MODE_DISABLED or _idle_chains.size() >= MAX_IDLE_CHAINS:
		chain.queue_free()
	else:
		_idle_chains.append(chain)


func prepare_lighting_debug() -> void :
	prepare_blessing_debug()
	level_manager.level_need_coin_number = 240
	level_manager.coin_number = 80
	for _rank in 3:
		_on_upgrade_selected("gun_up")
		_on_upgrade_selected("drone_up")
	for i in 8:
		spawn_healing_orb(player.global_position + Vector2(-100 + i * 28, 95), 5)
	variety.upgrade("wind_emblem")
	variety.upgrade("echo_ember")
	for i in 24:
		_spawn_xp_coin_now(player.global_position + Vector2(-190 + i * 12, -95 + float(i % 3) * 12), 2)
	variety.notify("光影测试：观察光束、枪火与回血球；连续拾币会点亮经验条")

func prepare_feedback_debug() -> void :
	prepare_lighting_debug()
	for _i in 5: _on_upgrade_selected("gun_up")
	for entry in CombatTargets._entries:
		if CombatTargets._live(entry, &"EnemyGroup") and is_ancestor_of(entry.actor) and "health" in entry.actor:
			entry.actor.health = 1000000000
	var fixture: = preload("res://script/feedback_playground.gd").new()
	fixture.name = "FeedbackPlayground"
	add_child(fixture)
	variety.notify("连拾金币点燃经验条；体验轻巧连射，点击下方可重播")

func prepare_first_boss_debug() -> void :
	player.apply_rest_max_hp(500)
	spawner.spawn_boss()
	if not spawner._active_bosses.is_empty():
		var boss: Node2D = spawner._active_bosses[0]
		boss.global_position = player.global_position
		boss.reset_physics_interpolation()
		boss.rush_timer.stop()
		boss.start_charge_attack()
	variety.notify("第一关 Boss 重合测试：Shift 冲刺脱离，观察下一轮冲刺")

func prepare_blessing_debug() -> void :
	player.apply_rest_max_hp(500)
	player.player_health = player.max_player_health - 300
	spawner.timer.stop()
	spawner.get_node("Elite").stop()
	for i in 4: beast_powers.unlock(i)
	_spawn_xp_coin_now(player.global_position + Vector2(1200, 0), 4)
	spawn_healing_orb(player.global_position + Vector2(-1400, 100), 5)
	for offset in [Vector2(-120, -40), Vector2(110, -35), Vector2(90, 75)]:
		var target: Node = load("res://scenes/enemy_shell.tscn").instantiate()
		target.set_player_ref(player)
		target.set_enemy_data(load("res://resource/Enemy_1.tres"))
		target.add_to_group("EnemyGroup")
		target.health = 2000
		target.death_signal.connect(spawner.on_enemy_killed.bind(target))
		add_child(target)
		target.global_position = player.global_position + offset
		target.set_physics_process(false)
	variety.notify("点击左侧四个图标：体验祝福特效、音效与全图拾取")

func prepare_knight_debug_fight() -> void :
	current_level = 5
	player.apply_level_growth(current_level)
	spawner.handle_level_up(current_level)
	level_manager.level = current_level
	level_manager.label.text = "Level: 5 (Boss test)"
	_on_upgrade_selected("axe_up")
	_on_upgrade_selected("gun_up")
	_on_upgrade_selected("gun_up")
	player.apply_rest_max_hp(100.0)
	player.apply_rest_move_speed(20.0)
	player.full_heal()
	spawner.debug_start_stage2_boss()

func prepare_meteor_debug() -> void :
	weather.set_preview(1, 0.5)
	beast_powers.unlock(2)
	player.player_health = player.max_player_health - 50
	for i in 6:
		_spawn_xp_coin_now(player.global_position + Vector2(600 + i * 90, 180), 2)
	spawn_healing_orb(player.global_position + Vector2(-950, -120), 5)
	var center: Vector2 = player.global_position + Vector2(90, -35)
	meteors.start_shower(center)
	for i in 3: spawner.spawn(center + Vector2(i * 18 - 18, 8), false)

func prepare_weather_debug() -> void :
	player.max_player_health = 50000
	player.player_health = 50000
	player.health_bar.set_max_health(50000, 50000)
	weather.enable_preview()

func spawn_necklace_orb(world_position: Vector2) -> Node2D:
	if player.monster_necklace_level <= 0 or player.player_health <= 0.0:
		return null
	return spawn_healing_orb(world_position + Vector2(0, -18), player.monster_necklace_heal_for(player.monster_necklace_level))

func spawn_healing_orb(world_position: Vector2, amount: float = 5.0) -> Node2D:
	if player.player_health <= 0 or amount <= 0 or process_mode == Node.PROCESS_MODE_DISABLED:
		return null
	var nearest: Node2D
	if _healing_actors.size() >= MAX_HEALING_ORBS:
		var candidate: = _nearest_pickup(_healing_actors, world_position, true)
		if _healing_actors.size() >= MAX_HEALING_ORBS: nearest = candidate
	if nearest != null:
		nearest.heal_amount += amount
		nearest.age = 0.0
		return nearest
	var orb: = HEALING_ORB_SCENE.instantiate() as Node2D

	orb.configure(amount, player)
	pickup_container.add_child(orb)
	orb.global_position = world_position
	return orb

func prepare_necklace_debug_run() -> void :
	_on_upgrade_selected("monster_necklace")

	player.player_health = maxf(1.0, player.max_player_health - 50.0)
	player.health_bar.set_health(player.player_health)
	level_manager.label.text = "Level: 0 (Necklace test)"
	for offset in [Vector2(-90, -45), Vector2(90, -45), Vector2(0, 85)]:
		spawner.spawn(player.global_position + offset, false)

func prepare_lightning_debug_run() -> void :
	player.apply_level_growth(current_level)
	level_manager.level = current_level
	spawner.handle_level_up(current_level)
	_on_upgrade_selected("lightning_ring")
	beast_powers.unlock(1)
	level_manager.label.text = "Level: 1 (Lightning test)"
	for offset in [Vector2(-130, 35), Vector2(70, -45), Vector2(140, 70), Vector2(-65, 105)]:
		spawner.spawn(player.global_position + offset, false)

func prepare_variety_debug() -> void :
	_on_upgrade_selected("wind_emblem")
	_on_upgrade_selected("echo_ember")
	variety._courier_left = 999
	variety.spawn_courier()
	variety.notify("已装备踏风徽记 / 回响火种\n冲刺结束触发风压 · 击杀 8 个敌人触发回响")

func _on_treasure_earned() -> void :

	_lottery_pending = true

	call_deferred("_show_next_reward")

func prepare_poison_debug(rank: int) -> void :
	for _i in clampi(rank, 1, 5): _on_upgrade_selected("poison_trail")
	variety.notify("剧毒踪迹 %d 级 · 移动留下毒雾\n%s" % [poison_trail.level, "每秒 25 点伤害 · 移速降低 25%" if rank >= 5 else "每秒 5 点伤害 · 5 级解锁减速"])
	for at in [Vector2(-100, 0), Vector2(100, 0), Vector2(0, 110)]:
		var actor: Node2D = load("res://scenes/enemy_shell.tscn").instantiate()
		actor.set_player_ref(player)
		actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
		actor.health = 150 * run_difficulty.health_scale
		actor.add_to_group("EnemyGroup")
		actor.death_signal.connect(spawner.on_enemy_killed.bind(actor))
		add_child(actor)
		actor.global_position = player.global_position + at

func prepare_control_debug(mode: StringName) -> void:
	var rank := 5 if mode in [&"fan5", &"black_hole5", &"control_cards"] else 1
	var ids: Array[String] = []
	if mode in [&"fan", &"fan5", &"control_cards"]: ids.append("banana_fan")
	if mode in [&"black_hole", &"black_hole5", &"control_cards"]: ids.append("black_hole")
	for id in ids:
		for _i in rank: _on_upgrade_selected(id)
	variety.notify("控场卡片 %d 级\n芭蕉扇沿移动方向吹风 · 黑洞自动聚怪" % rank)
	for offset in [Vector2(95, -28), Vector2(125, 22), Vector2(165, 0), Vector2(-100, -45), Vector2(65, 105)]:
		var actor: Node2D = load("res://scenes/enemy_shell.tscn").instantiate()
		actor.set_player_ref(player)
		actor.set_enemy_data(load("res://resource/Enemy_1.tres"))
		actor.health = 240.0 * run_difficulty.health_scale
		actor.add_to_group("EnemyGroup")
		actor.death_signal.connect(spawner.on_enemy_killed.bind(actor))
		add_child(actor)
		actor.global_position = player.global_position + offset

func _show_next_reward() -> void :
	if _death_presented or player.player_health <= 0.0 or process_mode == Node.PROCESS_MODE_DISABLED:
		return
	if trials.blocks_rewards():
		return
	if beast_powers._pending_reward >= 0:
		return
	if pause_menu.visible or (is_instance_valid(treasure_lottery) and treasure_lottery.visible) or (is_instance_valid(rest_hub) and rest_hub.visible):
		return
	if _lottery_pending:
		_lottery_pending = false
		if not is_instance_valid(treasure_lottery):
			treasure_lottery = TREASURE_LOTTERY.new()
			treasure_lottery.reward_claimed.connect(_on_treasure_claimed)
			add_child(treasure_lottery)
		treasure_lottery.open_lottery(pause_menu.available_upgrades(), equipment_panel)
	elif _blessing_pending >= 0:
		var defeated_stage: = _blessing_pending
		_blessing_pending = -1
		beast_powers.open_reward(defeated_stage, defeated_stage == spawner.FINAL_STAGE and not SPEED_TRIAL_ENABLED)
	elif not _level_reward_queue.is_empty():
		_level_reward_queue.pop_front()
		pause_menu.show_upgrade_options()
	elif not _trial_pending.is_empty():
		var trial_kind: = _trial_pending
		_trial_pending = ""
		trials.begin(trial_kind)
	elif _rest_pending:
		_rest_pending = false
		_open_rest_hub()

func _on_treasure_claimed(upgrade_id: String, levels: int) -> void :


	for _i in levels:
		_on_upgrade_selected(upgrade_id)
	spawner.complete_treasure_reward()
	get_tree().paused = false
	call_deferred("_show_next_reward")

func prepare_treasure_debug_run() -> void :
	current_level = 6
	player.apply_level_growth(current_level)
	spawner.handle_level_up(current_level)
	level_manager.level = current_level
	level_manager.label.text = "Level: 6 (Treasure test)"
	_on_upgrade_selected("axe_up")
	_on_upgrade_selected("gun_up")
	_on_upgrade_selected("gun_up")
	player.full_heal()
	spawner.debug_start_treasure_guardian()

func _on_beast_defeated(stage_num: int) -> void :
	variety.clear_combat_effects()
	_blessing_pending = stage_num
	call_deferred("_show_next_reward")

func _on_blessing_claimed(stage_num: int, settle: bool) -> void :
	get_tree().paused = false
	if stage_num == 4 and not trials.results.has("power"):
		_trial_pending = "power"
		call_deferred("_show_next_reward")
	elif stage_num == 6 and SPEED_TRIAL_ENABLED and not trials.results.has("speed"):
		_trial_pending = "speed"
		call_deferred("_show_next_reward")
	elif settle:
		on_boss_defeated()
	elif stage_num == spawner.FINAL_STAGE:
		spawner.begin_free_trial()
		beast_powers.finish_button.show()
		call_deferred("_show_next_reward")
	else:
		_rest_pending = true
		call_deferred("_show_next_reward")

func prepare_beast_debug(stage_num: int) -> void :
	current_level = 6 + (stage_num - 3) * 2
	player.apply_level_growth(current_level)
	spawner.handle_level_up(current_level)
	level_manager.level = current_level
	level_manager.label.text = "Level: %d (Guardian test)" % current_level
	_on_upgrade_selected("axe_up")
	for _i in 3 + (stage_num - 3):
		_on_upgrade_selected("gun_up")
	player.apply_rest_max_hp(100 + (stage_num - 3) * 80)
	player.full_heal()
	for i in stage_num - 3:
		beast_powers.unlock(i)
	spawner.debug_start_beast(stage_num)

func _on_trial_completed(kind: String, _passed: bool, settle: bool) -> void :
	if kind == "power":
		_rest_pending = true
		call_deferred("_show_next_reward")
	elif settle:
		on_boss_defeated()
	else:
		spawner.begin_free_trial()
		beast_powers.finish_button.show()
		call_deferred("_show_next_reward")

func prepare_trial_debug(kind: String) -> void :
	var stage_num: = 4 if kind == "power" else 6
	current_level = 8 if kind == "power" else 12
	player.apply_level_growth(current_level)
	level_manager.level = current_level
	spawner.handle_level_up(current_level)
	level_manager.label.text = "Level: %d (Trial test)" % current_level
	_on_upgrade_selected("axe_up")
	for _i in (4 if kind == "power" else 6):
		_on_upgrade_selected("gun_up")
	player.apply_rest_max_hp(180 if kind == "power" else 300)
	player.full_heal()
	for i in (2 if kind == "power" else 4):
		beast_powers.unlock(i)
	spawner._clear_minions()
	spawner.stage = stage_num
	spawner._ensure_stage_theme()
	spawner._bosses_cleared[stage_num] = true
	spawner._rest_open = true
	spawner.timer.stop()
	spawner.get_node("Elite").stop()
	spawner._refresh_stage_label()
	spawner.stage_advanced.emit(stage_num)
	_trial_pending = kind
	_show_next_reward()
