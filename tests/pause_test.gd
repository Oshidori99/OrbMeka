extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	# Réglages par défaut isolés : jamais ceux du joueur (user://settings.json).
	app.settings = load("res://scripts/user_settings.gd").new("res://.godot/test-default-settings.json")
	# Textes complets (Synthèse des textes : +) : ce test vérifie tout leur contenu.
	app.settings.values.text_detail = "plus"
	app.catalog = load("res://scripts/world_catalog.gd").new("res://.godot/pause-test-unused.json")
	app.catalog.worlds.append({"id": "pause-test", "name": "Mon monde", "seed": 123})
	root.add_child(app)
	current_scene = app
	check(app.home_version.text == "v0.0.3.26", "version visible on home")
	app.open_world("pause-test")
	var world: Node3D = app.active_world
	var player: CharacterBody3D = world.player
	check(world.find_child("Help", true, false) == null, "old gameplay help/version panel removed")
	check(app.pages.has("worlds"), "world-list details retained")
	world.add_block(Vector3i(40, 0, 40), 2)
	player.position.y = 4
	player.velocity.y = -2
	player.actions.set_place_pressed(true, true)
	player.actions.set_break_pressed(true, true)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	app._unhandled_key_input(escape)
	check(app.page == "pause" and paused, "Escape opens real pause")
	check(app.pause_version.text == "v0.0.3.26" and app.pause_version.is_visible_in_tree(), "version visible in pause")
	check(not world.can_process() and app.can_process(), "world stops processing while menus remain active")
	check(not player.actions.placing and not player.actions.breaking, "pause cancels both repeat timers")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pause releases pointer")
	var saved_position := player.position
	var saved_velocity := player.velocity
	var count: int = world.blocks.size()
	await create_timer(0.15, true).timeout
	check(player.position == saved_position and player.velocity == saved_velocity, "physics remains frozen while paused")
	check(world.blocks.size() == count and player.actions.place_remaining == 0 and player.actions.break_remaining == 0, "no block action or countdown while paused")
	app.how_button.pressed.emit()
	await process_frame
	check(app.page == "help" and paused, "Comment jouer opens while game stays paused")
	for text in ["Molette", "paramètres", "25 blocs", "5 blocs", "1200", "collines comprises", "réinitialisées"]:
		check(app.help_text.text.contains(text), "help retains information: " + text)
	app._unhandled_key_input(escape)
	check(app.page == "pause" and paused, "Escape from help returns to pause without resuming")
	app.how_button.pressed.emit()
	app.help_back_button.pressed.emit()
	check(app.page == "pause" and paused, "help Back button returns to pause")
	await process_frame
	await process_frame
	var panel: Control = app.menu_panel
	check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= 720, "pause fits 1280 by 720 viewport")
	app.resume_button.pressed.emit()
	check(app.page == "playing" and not paused and world.can_process(), "Resume reactivates gameplay")
	check(is_instance_valid(world) and world.blocks.has(Vector3i(40, 0, 40)), "resume preserves session constructions")
	check(not player.actions.placing and not player.actions.breaking and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "resume keeps repeats stopped (headless pointer remains free)")
	var capture := InputEventMouseButton.new()
	capture.button_index = MOUSE_BUTTON_LEFT
	capture.pressed = true
	player._unhandled_input(capture)
	check(world.blocks.size() == count and not player.actions.breaking, "capture click performs no block action")
	await physics_frame
	await physics_frame
	check(player.position.y < saved_position.y, "physics resumes after pause")
	# Dispatch through the headless viewport, never through OS mouse/keyboard.
	# This also verifies that a handled Escape cannot reach the player a second time.
	for index in range(3):
		root.push_input(escape.duplicate())
		check(app.page == "pause" and paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape cycle %d opens pause even with free mouse" % index)
		var repeated: InputEventKey = escape.duplicate()
		repeated.echo = true
		root.push_input(repeated)
		check(app.page == "pause" and paused, "keyboard echo does not close pause in cycle %d" % index)
		root.push_input(escape.duplicate())
		check(app.page == "playing" and not paused and not player.actions.breaking and not player.actions.placing, "Escape cycle %d resumes exactly once without residual interaction" % index)
	app.pause_game()
	app.open_help()
	var key := InputEventKey.new()
	key.keycode = KEY_F1
	key.pressed = true
	app._unhandled_key_input(key)
	check(app.page == "worlds" and not paused and not is_instance_valid(app.active_world), "F1 exits help to world list and clears pause")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "world-list return keeps pointer free")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	print("RESULT: %d pause/help checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)