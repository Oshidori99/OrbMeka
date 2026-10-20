extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event)

func _run() -> void:
	root.size = Vector2i(1280,720)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	# Réglages par défaut isolés : jamais ceux du joueur (user://settings.json).
	app.settings = load("res://scripts/user_settings.gd").new("res://.godot/test-default-settings.json")
	app.catalog = load("res://scripts/world_catalog.gd").new("res://.godot/history-unused.json")
	app.catalog.worlds.append({"id":"test", "name":"Historique", "seed":456})
	root.add_child(app)
	current_scene = app
	app.history_button.pressed.emit()
	check(app.page == "history" and app.history_text.text == FileAccess.get_file_as_string("res://docs/HISTORIQUE.txt"), "history displays current UTF-8 source file")
	var titles: Array = []
	for line in app.history_text.text.split("
"):
		if line.begins_with("0.0."):
			titles.append(line)
	check(titles.size() == 43 and titles[0].begins_with("0.0.3.19 ") and titles[-1].begins_with("0.0.1 "), "all forty-three versions shown latest to earliest")
	check(titles.find("0.0.2.5.1 — Rappels de commandes") < titles.find("0.0.2.5 — Raccourcis et sélection"), "five-part patch number sorted correctly")
	check(not is_instance_valid(app.active_world) and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "history does not launch game or capture pointer")
	await process_frame
	await process_frame
	var panel: Control = app.menu_panel
	check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= 720, "history panel fits 1280 by 720")
	check(app.history_scroll.get_v_scroll_bar().max_value > app.history_scroll.size.y, "long history scrolls")
	app.history_back_button.pressed.emit()
	check(app.page == "home", "Return exits history to home")
	app.history_text.text = "stale"
	app.open_history()
	check(app.history_text.text != "stale" and app.history_scroll.scroll_vertical == 0, "reopening reloads file and returns to top")
	escape()
	check(app.page == "home", "Escape exits history to home")
	check(ProjectSettings.get_setting("editor_plugins/enabled").has("res://addons/history_export/plugin.cfg"), "history export inclusion plugin enabled")
	app.open_world("test")
	var player: CharacterBody3D = app.active_world.player
	app.active_world.add_block(Vector3i(40,0,40),2)
	var count: int = app.active_world.blocks.size()
	for index in range(3):
		player.actions.set_place_pressed(true,true)
		player.actions.set_break_pressed(true,true)
		escape()
		check(app.page == "pause" and paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape opens pause and releases mouse in cycle %d" % index)
		if index == 0:
			app.resume_button.pressed.emit()
		else:
			escape()
		check(app.page == "playing" and not paused and not player.actions.placing and not player.actions.breaking, "Resume or Escape restores gameplay without old interactions in cycle %d" % index)
		check(app.active_world.blocks.size() == count, "resume preserves construction without block action")
	app.pause_game()
	Input.action_press("jump")
	app.resume_button.pressed.emit()
	check(player.wait_jump_release, "Space activating Resume is not reused as jump")
	Input.action_release("jump")
	player._physics_process(1.0/60.0)
	check(not player.wait_jump_release, "fresh jump allowed after release")
	check(DisplayServer.get_name() == "headless" and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "headless verification never captures OS pointer")
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	print("RESULT: %d history/resume checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)