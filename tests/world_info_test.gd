extends SceneTree
const Terrain = preload("res://scripts/terrain_generator.gd")
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
	app.catalog = load("res://scripts/world_catalog.gd").new("res://.godot/info-active-unused.json")
	var seeds: Dictionary = {}
	for value in range(32):
		var count := Terrain.generate_hills(value).size()
		if not seeds.has(count):
			seeds[count] = value
	var values: Array = seeds.values()
	values.append(4294967295)
	for index in range(values.size()):
		app.catalog.worlds.append({"id": str(index), "name": "Monde chargé %d" % index, "seed": values[index]})
	root.add_child(app)
	current_scene = app
	check(seeds.has(3) and seeds.has(4), "fixtures cover seeds generating three and four hills")
	for index in range(values.size()):
		app.open_world(str(index))
		var world: Node3D = app.active_world
		world.player.position.y = 4
		world.player.actions.set_place_pressed(true, true)
		world.player.actions.set_break_pressed(true, true)
		app.pause_game()
		app.info_button.pressed.emit()
		check(app.page == "world_info" and paused, "information button keeps world paused")
		check(app.info_text.text.contains("Monde : Monde chargé %d" % index) and app.info_text.text.contains("Graine : %d
" % values[index]), "information shows exact active name and seed")
		check(app.info_text.text.contains("plage de sable d'environ 21 m²"), "information shows the sand beach")
		var saved_position: Vector3 = world.player.position
		await create_timer(0.05, true).timeout
		check(world.player.position == saved_position and not world.can_process() and not world.player.actions.placing and not world.player.actions.breaking, "information freezes physics and cancels interactions")
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "information keeps pointer free")
		if index == 0:
			app.info_back_button.pressed.emit()
		else:
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			root.push_input(escape)
		check(app.page == "pause" and paused, "Back or Escape returns only to pause")
		app.show_page("pause")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		root.push_input(escape)
		check(app.page == "playing" and not paused and not world.player.actions.placing and not world.player.actions.breaking, "Escape from pause resumes with no residual hold")
		app.return_to_worlds()
		await process_frame
	root.remove_child(app)
	app.queue_free()
	await process_frame
	print("RESULT: %d active-world-info checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)