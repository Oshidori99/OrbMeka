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

func key(code: int, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event)

func _run() -> void:
	var app: Control = load("res://scenes/main.tscn").instantiate()
	# Réglages par défaut isolés : jamais ceux du joueur (user://settings.json).
	app.settings = load("res://scripts/user_settings.gd").new("res://.godot/test-default-settings.json")
	app.catalog = load("res://scripts/world_catalog.gd").new("res://.godot/shortcuts-unused.json")
	app.catalog.worlds.append({"id": "test", "name": "Raccourcis", "seed": 456})
	root.add_child(app)
	current_scene = app
	key(KEY_F2)
	key(KEY_F3)
	check(app.page == "home" and not paused, "F2 F3 ignored without loaded world")
	app.open_world("test")
	var world: Node3D = app.active_world
	var player: CharacterBody3D = world.player
	await process_frame
	await process_frame
	check(world.selected_block_label.text == "Bloc sélectionné : Sable", "initial selected block is displayed")
	for pair in [[KEY_2, "Pierre"], [KEY_3, "Terre"], [KEY_1, "Sable"]]:
		key(pair[0])
		check(world.selected_block_label.text == "Bloc sélectionné : " + pair[1], "number key immediately updates " + pair[1])
	# Same cycling function called by the wheel handler; no OS mouse input.
	for expected in ["Pierre", "Terre", "Sable"]:
		player.cycle_block(1)
		check(world.selected_block_label.text == "Bloc sélectionné : " + expected, "wheel forward cycle updates " + expected)
	player.cycle_block(-1)
	check(world.selected_block_label.text == "Bloc sélectionné : Terre", "wheel reverse wraps selection")
	check(world.selected_block_label.position == Vector2(18, 18) and world.selected_block_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "discreet top-left indicator does not intercept clicks")
	check(world.find_child("Help", true, false) == null, "old help panel remains absent")
	player.position.y = 4
	player.actions.set_place_pressed(true, true)
	player.actions.set_break_pressed(true, true)
	var count: int = world.blocks.size()
	key(KEY_F2)
	check(app.page == "help" and paused, "F2 from gameplay opens help and pauses")
	check(not player.actions.placing and not player.actions.breaking and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "shortcut cancels interactions and releases mouse")
	var position: Vector3 = player.position
	await create_timer(0.1, true).timeout
	check(player.position == position and not world.can_process(), "physics stays frozen in shortcut screen")
	key(KEY_F3, true)
	check(app.page == "help", "keyboard echo does not switch screens")
	key(KEY_ESCAPE)
	check(app.page == "pause" and paused, "Escape from help goes only to pause")
	key(KEY_F3)
	check(app.page == "world_info" and paused and app.info_text.text.contains("Graine : 456"), "F3 from pause opens actual world information")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE)
	check(app.page == "playing" and not paused and world.blocks.size() == count and not player.actions.placing and not player.actions.breaking, "Escape screen pause gameplay preserves blocks without residual action")
	key(KEY_F3)
	check(app.page == "world_info" and paused, "F3 also works directly from gameplay")
	key(KEY_ESCAPE)
	key(KEY_F2)
	check(app.page == "help" and paused, "F2 also works from pause")
	check(app.help_text.text.contains("F2") and app.help_text.text.contains("F3"), "help documents both shortcuts")
	key(KEY_F1)
	check(app.page == "worlds" and not paused and not is_instance_valid(app.active_world), "F1 still returns to world list")
	key(KEY_F2)
	key(KEY_F3)
	check(app.page == "worlds" and not paused, "shortcuts remain inactive after leaving world")
	check(app.home_version.text == "v0.0.4.8" and app.pause_version.text == "v0.0.4.8", "home and pause show new version")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	print("RESULT: %d shortcut/selection checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)