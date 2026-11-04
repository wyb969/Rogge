extends Node


const PATH: = "user://rogge_diagnostics.json"
const WEB_HELPER: = "res://script/web_diagnostics.js"
const FEEDBACK: = preload("res://script/feedback_budget.gd")
const MAX_SAMPLES: = 60
const MAX_EVENTS: = 96
var previous: Dictionary = {}
var report: Dictionary = {}
var last_export_path: = ""
var batching: = false
var _game: WeakRef
var _last_frame: = 0
var _last_sample: = 0
var _last_save: = 0
var _last_stall: = -10000
var _js: Object
var _logger: Logger

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	_logger = load("res://script/diagnostic_logger.gd").new()
	_logger.recorder = weakref(self)
	OS.add_logger(_logger)
	if FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			previous = parsed
	if OS.has_feature("web"):
		_js = Engine.get_singleton("JavaScriptBridge")
		if _js != null:
			_js.call("eval", FileAccess.get_file_as_string(WEB_HELPER), true)
			var parsed = JSON.parse_string(str(_js.call("eval", "JSON.stringify(globalThis.RoggeDiagnostics.previous)", true)))
			if parsed is Dictionary:
				previous = parsed

func begin(game: Node, mode: String) -> void :
	if report.get("state") == "active":
		finish("replaced_run")
	_game = weakref(game)
	var now: = Time.get_ticks_msec()
	_last_frame = now
	_last_sample = now
	_last_save = now
	report = {"schema": 1, "build": str(ProjectSettings.get_setting("application/config/version", "dev")), 
		"session_id": "%d-%d" % [Time.get_unix_time_from_system(), now], "mode": mode, 
		"state": "active", "started_unix": Time.get_unix_time_from_system(), 
		"runtime": {"os": OS.get_name(), "web": OS.has_feature("web"), "engine": Engine.get_version_info().string}, 
		"events": [], "samples": [], "peaks": {}, "loadout": {}}
	mark("run_start", {}, true)

func capture_engine_error(details: Dictionary) -> void :
	mark("engine_error", details, true)

func _exit_tree() -> void :
	if _logger != null:
		OS.remove_logger(_logger)

func mark(kind: String, details: Dictionary = {}, checkpoint: bool = false) -> void :
	if report.is_empty() or report.get("state") != "active":
		return
	var event: = {"kind": kind, "at_ms": Time.get_ticks_msec(), "details": details.duplicate(true)}
	report.events.append(event)
	if report.events.size() > MAX_EVENTS:
		report.events.pop_front()
	if checkpoint and not batching:
		_sample(0.0)
		_save()

func finish(reason: String) -> void :
	if report.get("state") != "active":
		return
	mark("run_end", {"reason": reason}, true)
	report.state = "ended"
	report.end_reason = reason
	_save()

func _process(_delta: float) -> void :
	var now: = Time.get_ticks_msec()
	var frame_ms: = float(now - _last_frame)
	_last_frame = now
	if report.get("state") != "active":
		return
	report.peaks["frame_ms"] = maxf(float(report.peaks.get("frame_ms", 0)), frame_ms)
	if now - _last_sample >= 1000:
		_sample(frame_ms)
		_last_sample = now
	if frame_ms >= 160 and now - _last_stall >= 2000 and not get_tree().paused:
		_last_stall = now
		mark("frame_stall", {"frame_ms": frame_ms}, true)
	if now - _last_save >= 5000:
		_save()

func _owned_count(group: StringName, game: Node) -> int:
	var count: = 0
	for node in get_tree().get_nodes_in_group(group):
		if is_instance_valid(node) and game.is_ancestor_of(node):
			count += 1
	return count

func _sample(frame_ms: float) -> void :
	var game: Node = _game.get_ref() if _game != null else null
	if not is_instance_valid(game):
		return
	var memory: = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var sample: = {"at_ms": Time.get_ticks_msec(), "stage": game.spawner.stage, "level": game.current_level, "difficulty": game.run_difficulty.index, 
		"run_seconds": snappedf(game.spawner.run_seconds, 0.1), "paused": get_tree().paused, 
		"hp": game.player.player_health, "max_hp": game.player.max_player_health, 
		"dash": {"moving": game.player.dashing, "grace": snappedf(game.player.dash_grace_left, 0.001), "ready": game.player.can_dash, "cooldown": snappedf(game.player.dash_cooldown_progress(), 0.001)}, 
		"fps": int(Performance.get_monitor(Performance.TIME_FPS)), "frame_ms": frame_ms, 
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), 
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), 
		"memory_bytes": memory if memory > 0 else null, 
		"video_memory_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)), 
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), 
		"enemies": _owned_count(&"EnemyGroup", game), "books": game.circle_weapon.get_child_count(), 
		"player_shots": _owned_count(&"player_projectile", game), 
		"effects": game.effect_container.get_child_count(), "pickups": game.pickup_container.get_child_count(), 
		"damage_popups": _owned_count(&"damage_popup", game), "suppressed_popups": FEEDBACK.suppressed}
	var bosses: = []
	sample["runtime"] = {"render_mode": "viewport" if get_tree().root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT else "canvas_items", "window": str(get_tree().root.size), "logical_viewport": str(get_tree().root.get_visible_rect().size), "target_registry": CombatTargets.tracked_count(), "target_queries": CombatTargets.queries, "chains_created": game.chains_created, "chains_reused": game.chains_reused, "idle_chains": game._idle_chains.size(), "ground_rebuilds": game.get_node("InfiniteBackground").coverage_rebuilds, "decor_rebuilds": game.get_node("InfiniteBackground").decoration_rebuilds}
	sample["boss_visuals"] = _owned_count(&"elemental_attack_visual", game)
	sample["local_light"] = {"bullets": game.combat_lighting._bullets.size(), "drones": game.combat_lighting._drones.size(), "orb_groups": game.combat_lighting._orb_count, "shadows": game.combat_lighting.shadows_last, "quads": game.combat_lighting.light_quads_last, "beams": game.combat_lighting.beams_last, "rings": game.combat_lighting.rings_last, "xp_glow": game.level_manager.pickup_glow.energy, "pickup_pitch": AudioManager.pick_coin_audio_player.pitch_scale}
	sample["burn_spread"] = {"pending": game.burn_spread._count, "batches": game.burn_spread.batches, "examined": game.burn_spread.examined, "distance_checks": game.burn_spread.distance_checks, "applications": game.burn_spread.applied}
	sample["pickup_combo"] = {"count": game.level_manager.pickup_glow.combo, "tier": game.level_manager.pickup_glow.tier, "heat": game.level_manager.pickup_glow.heat}
	sample["gun_audio"] = {"played": AudioManager.gun_cues_played, "chain": AudioManager._gun_chain, "gain_db": AudioManager.shoot_audio_player.volume_db}
	sample["poison"] = {"level": game.poison_trail.level, "clouds": game.poison_trail.active_clouds(), "exposed": game.poison_trail._exposed.size(), "damage_ticks": game.poison_trail.damage_ticks, "emitted": game.poison_trail.clouds_emitted}
	sample["meteors"] = {"showers": game.meteors.showers_started, "active": game.meteors._count, "impacts": game.meteors.impacts, "kills": game.meteors.enemies_defeated, "drops": game.meteors.drops_spawned, "pending_drops": game.meteors._reward_left}
	sample["camera_motion"] = {"drag": str(game.combat_feedback._camera_motion.drag)}
	sample["variety"] = {"wind_level": game.variety.wind_level, "echo_level": game.variety.echo_level, "echo_charge": game.variety.echo_charge, "pulses": game.variety.pulses_cast, "couriers_defeated": game.variety.couriers_defeated, "rerolls": game.pause_menu.rerolls}
	var weather: Node = game.get("weather")
	if weather != null:
		sample["weather"] = weather.describe()
	sample["xp_coins"] = _owned_count(&"xp_coin", game)
	sample["healing_orbs"] = _owned_count(&"healing_orb", game)
	var feedback: Node = game.get("combat_feedback")
	if feedback != null:
		sample["juice_shards"] = feedback.shards.size()
		sample["juice_rings"] = feedback.rings.size()
		sample["juice_ghosts"] = feedback.ghosts.size()
		sample["juice_suppressed"] = feedback.suppressed
	for boss in game.spawner._active_bosses:
		if is_instance_valid(boss):
			var entry: = {"stage": boss.fight_stage, "phase": boss.get("phase"), "hp": boss.boss_current_health}
			var visual: Node = boss.get("attack_visual")
			if visual != null:
				entry["attack_state"] = boss.state
				entry["attack_pattern"] = boss.pattern_index
				entry["visual_active"] = visual.active
				entry["visual_shapes"] = visual.geometry.size()
				entry["visual_draw_calls"] = visual.draw_calls_last
			bosses.append(entry)
	sample["bosses"] = bosses
	for id in game.equipment_panel.EQUIP_DEFS:
		report.loadout[id] = game.equipment_panel.get_level(id)
	report.samples.append(sample)
	if report.samples.size() > MAX_SAMPLES:
		report.samples.pop_front()
	for key in ["nodes", "books", "enemies", "player_shots", "effects", "pickups", "xp_coins", "healing_orbs", "damage_popups", "frame_ms", "juice_shards", "juice_rings", "juice_ghosts", "boss_visuals"]:
		if not sample.has(key): continue
		report.peaks[key] = maxf(float(report.peaks.get(key, 0)), float(sample[key]))
	report.last_unix = Time.get_unix_time_from_system()

func _save() -> void :
	if report.is_empty():
		return
	_last_save = Time.get_ticks_msec()
	var data: = JSON.stringify(report)
	var file: = FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	if file != null:
		file.store_string(data)
		file.close()
		DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH + ".tmp"), ProjectSettings.globalize_path(PATH))
	if _js != null:
		_js.call("eval", "globalThis.RoggeDiagnostics.update(" + data + ")", true)

func latest() -> Dictionary:
	if _js != null:
		var browser = JSON.parse_string(str(_js.call("eval", "JSON.stringify(globalThis.RoggeDiagnostics.latest())", true)))
		if browser is Dictionary:
			return browser
	return report.duplicate(true) if not report.is_empty() else previous.duplicate(true)

func export_report() -> String:
	if report.get("state") == "active":
		_sample(0.0)
		_save()
	var data: = latest()
	if data.is_empty():
		return "暂无记录，请先游玩或运行压力测试"
	var name: = "rogge-diagnostics-%s-%d.json" % [data.get("build", "dev"), Time.get_unix_time_from_system()]
	var bytes: = JSON.stringify(data, "\t").to_utf8_buffer()
	if _js != null:
		_js.call("download_buffer", bytes, name, "application/json")
		last_export_path = name
	else:
		last_export_path = "user://" + name
		var file: = FileAccess.open(last_export_path, FileAccess.WRITE)
		if file == null:
			return "报告保存失败"
		file.store_buffer(bytes)
	return "诊断报告已导出，请保存 JSON 文件"
