extends SceneTree
var failures: Array[String] = []
func _init() -> void :
	call_deferred("_run")
func _run() -> void :
	for symbol in "↑↓←→↖↗↘↙":
		_expect(UiFonts.symbols().has_char(symbol.unicode_at(0)), "bundled font contains arrow " + symbol)
	_expect(FileAccess.file_exists("res://script/web_diagnostics.js"), "browser recorder is included in the exported resource pack")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	main._on_debug_button_pressed()
	main.get_node("mainUI/Control/DebugCenter/VBoxContainer/DebugStabilityButton").pressed.emit()
	await process_frame
	await process_frame
	var game: Node = main.game
	var test: Node = game.get_node("StabilityTest")
	test.duration = 1.0
	_expect(game.spawner.stage == 6 and game.spawner._active_bosses[0].phase == 2, "real Debug button enters the final beast's second phase")
	_expect(game.circle_weapon.get_child_count() == 12 and game.circle_weapon.card_level == 17, "stress fixture includes capped high-rank books")
	var diag: Node = root.get_node("RunDiagnostics")
	for i in range(180):
		diag.mark("bounded_fixture", {"index": i})
		diag._sample(16)
	push_warning("controlled diagnostics logger probe")
	await process_frame
	_expect(diag.report.events.any( func(event): return event.kind == "engine_error" and str(event.details).contains("controlled diagnostics logger probe")), "Godot's logger captures internally handled script/engine errors")
	_expect(diag.report.events.size() <= 96 and diag.report.samples.size() <= 60, "recorder history is bounded during a long run")
	await create_timer(1.3, true, false, true).timeout
	_expect(paused and diag.report.state == "ended" and diag.report.end_reason == "stress_complete", "timed stress run ends with a checkpoint and usable controls")
	var status: String = diag.export_report()
	_expect(status.contains("已导出") and FileAccess.file_exists(diag.last_export_path), "actual diagnostic export writes a reviewable JSON report")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(diag.last_export_path))
	_expect(saved is Dictionary and saved.build == str(ProjectSettings.get_setting("application/config/version")) and saved.peaks.books == 12, "report includes build, peak objects and reproduction loadout")
	test.stop()
	await process_frame
	await process_frame
	_expect(main.menu_page.visible and not main.debug_page.visible and paused, "Stop returns to the original home page")
	_expect(game.effect_container.get_child_count() == 0 and get_nodes_in_group("player_projectile").is_empty(), "returning home clears all run-owned projectiles/effects")
	var reader: Node = load("res://script/run_diagnostics.gd").new()
	root.add_child(reader)
	_expect(reader.previous.get("build") == saved.build, "a fresh recorder loads the preceding session checkpoint")
	reader.queue_free()
	if failures.is_empty():
		print("DIAGNOSTICS OK: bundled arrows, real final-boss stress entry, bounded reports, JSON export/reload, stop/back and run-owned cleanup")
	else:
		for failure in failures:
			push_error(failure)
	paused = false
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void :
	if not ok:
		failures.append(message)
