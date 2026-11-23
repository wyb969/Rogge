extends SceneTree

# Run with an isolated Godot user directory to exercise the real permanent-reward store.
var main: Node
var game: Node
var failures: Array[String] = []
var checks := 0
var profile_bytes: PackedByteArray
var had_profile := false
var profile_path: String

func _init() -> void:
	call_deferred("_run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func frames(n := 3) -> void:
	for i in n: await process_frame

func normal_start() -> void:
	main._on_start_button_pressed()
	await frames()
	main.hero_picker.cards[0].pressed.emit()
	await frames()
	var slots: Node = main.starter_lottery
	slots.loadout = {"cards": ["axe_up","speed_up","shield_up"], "group": "", "perk": "pickup_up", "backup": "", "tiers": {"axe_up":0,"speed_up":0,"shield_up":0}}
	slots._button.pressed.emit()
	slots._process(3.0)
	slots._button.pressed.emit()
	await frames()
	game = main.game
	game.spawner.timer.stop()
	game.spawner.get_node("Elite").stop()
	expect(game.forge.enabled and not paused, "confirmed normal loadout starts the live forge economy")

func find_card(id: String, tier := -1) -> Dictionary:
	for card: Dictionary in game.forge.cards:
		if card.id == id and (tier < 0 or card.tier == tier):
			return card
	return {}

func card_by_uid(uid: int) -> Dictionary:
	for card: Dictionary in game.forge.cards:
		if card.uid == uid: return card
	return {}

func defeat_stage_boss() -> void:
	game.spawner.spawn_boss()
	var bosses: Array = game.spawner._active_bosses.duplicate()
	expect(not bosses.is_empty(), "stage boss actually spawned")
	for boss: Node in bosses:
		boss.apply_hit({"damage": 9999999})
		if bosses.size() == 2 and boss == bosses[0]:
			expect(not game.spawner._bosses_cleared.has(5), "the first wind boss cannot settle the pair")
	var deadline := Time.get_ticks_msec() + 3000
	while not game.pause_menu.visible and Time.get_ticks_msec() < deadline:
		await process_frame

func pick_draft() -> void:
	var options: Node = game.pause_menu.h_box_container
	var card := options.get_child(0)
	# Preserve the starter weapon so the last-attack guard is exercised.
	for candidate in options.get_children():
		if candidate.upgrade_id not in main.starter_lottery.WEAPONS and candidate.upgrade_id not in game.forge.OTHER_ATTACKS:
			card = candidate
			break
	card.selected.emit(card.upgrade_id)
	await frames()

func finish_forge() -> void:
	game.forge_screen.quit_button.pressed.emit()
	await frames()

func verify_crafting() -> void:
	var forge = game.forge
	var speed: Dictionary = find_card("speed_up")
	var axe: Dictionary = find_card("axe_up")
	expect(not speed.is_empty() and not axe.is_empty(), "actual starting inventory includes distinct instances")
	if speed.is_empty() or axe.is_empty(): return
	var costless: int = forge.wallet
	forge.wallet = 9999999
	expect(not forge.preview(speed.uid,[speed.uid]).valid, "main instance cannot be its own sacrifice")
	var weapons: Array = []
	for card: Dictionary in forge.cards:
		if card.id in main.starter_lottery.WEAPONS or card.id in forge.OTHER_ATTACKS: weapons.append(card.uid)
	expect(weapons.size() <= 2 and forge.preview(speed.uid,weapons).valid and not forge.preview(speed.uid,weapons).warnings.is_empty(), "last attack can be sacrificed with an explicit warning")
	forge.add_card("drone_up",0)
	forge.add_card("gun_up",0)
	forge.add_card("bomb",0)
	expect(game.arsenal_combo.unlocked, "three actual different weapons activate arsenal")
	var victim_id := "drone_up"
	for candidate in ["drone_up","gun_up","bomb"]:
		if game.equipment_panel.get_level(candidate) == 1:
			victim_id = candidate
			break
	var victim: Dictionary = find_card(victim_id)
	var second: Dictionary = find_card("gun_up" if victim_id != "gun_up" else "bomb")
	var third: Dictionary = find_card("axe_up")
	var zero: Dictionary = forge.preview(speed.uid,[])
	var one: Dictionary = forge.preview(speed.uid,[victim.uid])
	var two: Dictionary = forge.preview(speed.uid,[victim.uid,second.uid])
	expect(zero.valid and one.valid and two.valid, "zero, one and two heterogeneous sacrifices are legal")
	expect(zero.cost > one.cost and one.cost > two.cost, "each extra ingredient reduces coin cost")
	expect(zero.down == 0 and is_equal_approx(one.up,two.up) and is_equal_approx(one.down,30.0) and is_equal_approx(one.stay,40.0), "solo never drops and transfer rolls use 30/40/30")
	expect(not forge.preview(speed.uid,[victim.uid,victim.uid]).valid, "same instance cannot fill both slots")
	expect(not forge.preview(speed.uid,[victim.uid,second.uid,third.uid]).valid, "three material cards rejected")
	var count: int = forge.cards.size()
	forge.wallet = 0
	expect(not forge.attempt(speed.uid,[victim.uid]).ok and forge.cards.size() == count and not card_by_uid(victim.uid).is_empty(), "unaffordable attempts are atomic")
	forge.wallet = 9999999
	var balance: int = forge.wallet
	var resolved: Dictionary = forge.attempt(speed.uid,[victim.uid])
	expect(resolved.ok and forge.wallet == balance - one.cost, "one attempt consumes exactly the quoted coins")
	expect(forge.cards.size() == count-1 and card_by_uid(victim.uid).is_empty() and not card_by_uid(speed.uid).is_empty(), "only the sacrifice is removed")
	expect(not game.arsenal_combo.unlocked and game.equipment_panel.get_level(victim_id)==0, "sacrificing a unique weapon removes its rank and shield set")
	expect(not forge.attempt(speed.uid,[victim.uid]).ok and forge.wallet == balance-one.cost, "a repeated submission cannot reuse a spent card")
	seed(969)
	var seen := {}
	for i in 60:
		var sub: int = forge.add_card("bomb")
		var rank: int = speed.level
		var plan: Dictionary = forge.preview(speed.uid,[sub])
		var trial: Dictionary = forge.attempt(speed.uid,[sub])
		expect(trial.ok and speed.level == plan.levels[trial.outcome] and speed.level >= rank, "whole level transfer matches quote")
		seen[trial.outcome] = true
		if seen.size() == 3 and rank >= 12: break
	expect(seen.size() == 3 and speed.level >= 12 and game.player.awakened.has("speed_up"), "all outcomes, orange awakening and levels beyond nine")
	var solo_rank: int = speed.level
	var solo: Dictionary = forge.attempt(speed.uid,[])
	expect(solo.ok and speed.level in [solo_rank,solo_rank+1], "solo result holds or adds one")
	# Spend the actual last weapon and carry the resulting build through the next stage.
	var remaining: Array = []
	for card in forge.cards:
		if card.id in main.starter_lottery.WEAPONS or card.id in forge.OTHER_ATTACKS:
			remaining.append(card.uid)
	while remaining.size() > 2:
		expect(forge.attempt(speed.uid,[remaining.pop_back()]).ok, "remove another weapon")
	var last_plan: Dictionary = forge.preview(speed.uid,remaining)
	expect(last_plan.valid and last_plan.warnings[0] == L10n.text("将失去最后一种攻击技能，仍可利用地形击杀敌人。"), "terrain warning has priority before committing")
	expect(forge.attempt(speed.uid,remaining).ok, "last attacking skill sacrifice completes")
	for card in forge.cards:
		expect(card.id not in main.starter_lottery.WEAPONS and card.id not in forge.OTHER_ATTACKS, "all independent attack skills were removed")
	forge.wallet = costless

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await frames()
	await normal_start()
	var forge = game.forge
	profile_path = forge.PROFILE
	had_profile = FileAccess.file_exists(profile_path)
	if had_profile: profile_bytes = FileAccess.get_file_as_bytes(profile_path)
	var materials_before: int = forge.materials
	var coins_before: int = forge.wallet
	var level_before: int = game.current_level
	var count_before: int = forge._score(forge.cards)
	expect(find_card("pickup_up").tier == 0 and game.player.SPEED == 120, "innate perk is cyan and level one speed card grants 20")
	game.player.player_health = game.player.max_player_health * 0.5
	var damaged_health: float = game.player.player_health
	game.spawn_healing_orb(game.player.global_position+Vector2(-1600,0),5)
	game._spawn_xp_coin_now(game.player.global_position+Vector2(2200,0),2)
	await defeat_stage_boss()
	expect(game.pause_menu.visible and game.current_level == level_before+1, "subthreshold boss cleanup grants exactly one real level and one draft")
	expect(forge.wallet > coins_before and game.get_tree().get_nodes_in_group("xp_coin").is_empty(), "a distant drop is paid on boss death")
	expect(get_nodes_in_group("healing_orb").is_empty() and game.player.player_health > damaged_health, "distant healing orbs are collected before the draft")
	expect(forge._score(forge.cards) == count_before, "a pending draft cannot silently add an extra card")
	if not game.pause_menu.visible:
		_finish()
		return
	await pick_draft()
	expect(forge._score(forge.cards) == count_before+10 and game.forge_screen.visible and paused, "draft resolves into one forge visit")
	if not game.forge_screen.visible:
		_finish()
		return
	var audio := root.get_node("AudioManager")
	expect(audio._desired_bgm == audio.BgmKind.FORGE and audio.boss_audio_player.playing and audio.boss_audio_player.stream == audio.FORGE_MUSIC, "normal paused forge plays its own score")
	expect(audio.FORGE_MUSIC.loop and audio.boss_audio_player.bus == &"Music" and not audio.adventure_music.active, "loop uses the music slider and replaces the adventure voices")
	await verify_crafting()
	var reward: Dictionary = forge.reward_preview()
	expect(reward.total > 0 and reward.score >= reward.speed, "gear makes the largest stage award and fast time is secondary")
	var normal_wallet: int = forge.wallet
	var owned: int = forge.cards.size()
	forge.refill_practice()
	expect(not is_instance_valid(game.forge_screen.supply_button) and normal_wallet == forge.wallet and owned == forge.cards.size(), "normal stage forge cannot grant practice supplies")
	await finish_forge()
	expect(forge.materials > materials_before and game.rest_hub.visible, "skipping or closing the forge banks this stage and continues to rest")
	expect(audio._desired_bgm == audio.BgmKind.GAME and not audio.boss_audio_player.playing, "rest resumes stage music after the forge")
	var earned: int = forge.materials
	forge.settle_stage()
	expect(forge.materials == earned, "repeated settlement cannot pay twice")
	game.rest_hub._on_reward_pressed("max_hp")
	game.rest_hub.next_button.pressed.emit()
	await create_timer(1.25).timeout
	expect(game.spawner.stage == 2 and not paused, "real rest choice continues the run")
	var previous_level: int = game.current_level
	var threshold: int = game.level_manager.level_need_coin_number - game.level_manager.coin_number
	var xp: int = threshold + game.level_manager.get_need_exp(previous_level+1)
	# Use prepared XP to avoid difficulty and growth changing the diagnostic boundary.
	game._spawn_xp_coin_now(game.player.global_position + Vector2(1200,0),xp)
	var pending = get_first_node_in_group("xp_coin")
	pending.prepared_xp = xp
	await defeat_stage_boss()
	expect(game.current_level == previous_level+2 and game.pause_menu.visible, "mass pickup can earn two actual draft levels")
	for i in 2:
		if game.pause_menu.visible: await pick_draft()
	expect(game.forge_screen.visible, "complete both choice dialogs before opening the forge")
	await finish_forge()
	var after_second: int = forge.materials
	expect(after_second > earned, "second stage banks its own material reward")
	await main.on_game_over({"victory":false})
	await main._on_game_end_ui_main_menu_pressed()
	await normal_start()
	expect(game.forge.materials == after_second and game.forge.wallet == 0, "restart retains banked materials and discards the run wallet")
	var original_furnace: int = game.forge.furnace_level
	var price: int = game.forge.furnace_cost()
	if game.forge.materials < price:
		expect(not game.forge.upgrade_furnace(), "unfunded furnace purchase is refused")
	game.forge.materials += price
	var funded: int = game.forge.materials
	expect(game.forge.upgrade_furnace() and game.forge.materials == funded-price and game.forge.furnace_level == original_furnace+1,"furnace level purchase debits the exact permanent cost")
	var stored := ConfigFile.new()
	expect(stored.load(profile_path) == OK and stored.get_value("forge","level",0) == original_furnace+1 and stored.get_value("forge","materials",-1) == funded-price, "level and material debit were committed together")
	var reloaded = game.forge.get_script().new()
	reloaded.begin(game)
	expect(reloaded.materials == funded-price and reloaded.furnace_level == original_furnace+1, "fresh inventory reads the permanent furnace from disk")
	var practice = game.forge.get_script().new()
	practice.begin(game,true)
	practice.seal_stage()
	practice.settle_stage()
	stored.load(profile_path)
	expect(stored.get_value("forge","materials",-1) == funded-price, "practice rewards leave the actual player's materials alone")
	await verify_final_clear()
	_finish()

func verify_final_clear() -> void:
	var forge = game.forge
	game.spawner.stage = 5
	game.spawner.stage_advanced.emit(5)
	await defeat_stage_boss()
	await complete_stage_modals()
	game.spawner.stage = 6
	game.spawner._rest_open = false
	game.spawner.stage_advanced.emit(6)
	game.trials.results.speed = {"passed":true}
	await defeat_stage_boss()
	await complete_stage_modals()
	var previous: int = forge.materials
	game.on_boss_defeated()
	await frames()
	expect(forge.materials > previous and main.game_end_ui.visible, "true victory banks an extra clear reward")
	var after: int = forge.materials
	forge.award_victory()
	expect(forge.materials == after, "repeated victory payout is idempotent")

func complete_stage_modals() -> void:
	for cycle in 8:
		if game.pause_menu.visible:
			await pick_draft()
		elif is_instance_valid(game.forge_screen) and game.forge_screen.visible:
			await finish_forge()
		elif game.beast_powers._pending_reward >= 0:
			game.beast_powers.reward_claim.pressed.emit()
			await frames()
		elif is_instance_valid(game.rest_hub) and game.rest_hub.visible:
			game.rest_hub._on_reward_pressed("max_hp")
			game.rest_hub.next_button.pressed.emit()
			await create_timer(1.25).timeout
			return
		else:
			await frames()

func _finish() -> void:
	if not profile_path.is_empty():
		if had_profile:
			var out := FileAccess.open(profile_path,FileAccess.WRITE)
			out.store_buffer(profile_bytes)
		elif FileAccess.file_exists(profile_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))
	if failures.is_empty(): print("FORGE OK: %d checks; normal starting slots, world drops, draft queue, costs, safeguards, stage and clear settlement, restart" % checks)
	paused = false
	quit(0 if failures.is_empty() else 1)
