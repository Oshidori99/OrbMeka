extends SceneTree
const Catalog = preload("res://scripts/world_catalog.gd")
const Terrain = preload("res://scripts/terrain_generator.gd")
var checks := 0
var failures := 0
var test_path := ""

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
	# Unique disposable fixture: never touches the user's actual saved worlds.
	test_path = "res://.godot/catalog-test-%d.json" % Time.get_ticks_usec()
	var catalog := Catalog.new(test_path)
	check(catalog.worlds.is_empty(), "fresh catalog is empty")
	check(catalog.create_world(" 	 ").is_empty(), "blank name rejected")
	check(catalog.create_world("x".repeat(49)).is_empty(), "name longer than 48 characters rejected")
	var first: Dictionary = catalog.create_world("  Ma plaine  ")
	check(not first.is_empty() and first.name == "Ma plaine", "world is created with trimmed name")
	check(catalog.create_world("ma PLAINE").is_empty(), "duplicate name rejected without case sensitivity")
	var second: Dictionary = catalog.create_world("Collines été")
	check(not second.is_empty() and first.seed != second.seed, "new worlds receive different automatic seeds")
	check(FileAccess.file_exists(test_path), "creating a world persists the metadata")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(test_path))
	check(saved.worlds[0].keys().size() == 4 and saved.worlds[0].mode == "default" and not saved.worlds[0].has("blocks"), "saved world contains only id name seed mode")
	var reloaded := Catalog.new(test_path)
	check(reloaded.worlds.size() == 2 and reloaded.find_world(first.id).seed == first.seed, "new catalog reloads the world and exact seed")
	check(reloaded.find_world(second.id).name == "Collines été", "Unicode world name survives reload")
	check(Terrain.generate_cells(first.seed) == Terrain.generate_cells(reloaded.find_world(first.id).seed), "reloaded seed regenerates identical terrain")
	check(Terrain.generate_cells(first.seed) != Terrain.generate_cells(second.seed), "different worlds generate different terrain")
	var counts: Dictionary = {}
	var valid_hills := true
	var valid_heights := true
	for seed_value in range(32):
		var hills := Terrain.generate_hills(seed_value)
		counts[hills.size()] = true
		valid_hills = valid_hills and hills.size() >= 3 and hills.size() <= 4
		for height in Terrain.generate_heights(seed_value).values():
			valid_heights = valid_heights and height > 0 and height <= 3
	check(valid_hills and counts.has(3) and counts.has(4), "seed sample produces only three or four hills, including both counts")
	check(valid_heights, "all sampled hills stay at most three blocks high")
	# Verify actual page/button signals and worlds, without OS keyboard/mouse.
	var app: Control = load("res://scenes/main.tscn").instantiate()
	# Réglages par défaut isolés : jamais ceux du joueur (user://settings.json).
	app.settings = load("res://scripts/user_settings.gd").new("res://.godot/test-default-settings.json")
	app.catalog = reloaded
	root.add_child(app)
	current_scene = app
	await process_frame
	check(app.page == "home" and app.play_button.visible, "startup opens home with Play")
	check(app.pages.home.get_children().filter(func(child): return child is Button).size() == 4, "home has four main buttons")
	app.play_button.pressed.emit()
	await process_frame
	check(app.page == "worlds" and app.world_list.item_count == 2, "Play opens the world list")
	app.new_world_button.pressed.emit()
	await process_frame
	check(app.page == "create" and app.name_field.has_focus(), "create page focuses the name field")
	check(app.pages.create.get_children().filter(func(child): return child is LineEdit).size() == 2, "creation form has name and seed fields")
	app.name_field.text = " "
	app.create_button.pressed.emit()
	check(app.page == "create" and not app.form_error.text.is_empty(), "form explains empty-name error")
	app.name_field.text = "Troisième monde"
	app.create_button.pressed.emit()
	await physics_frame
	check(app.page == "playing" and is_instance_valid(app.active_world), "creating a named world opens gameplay")
	var id: String = app.current_world_id
	var seed_value: int = app.active_world.terrain_seed
	check(app.catalog.find_world(id).seed == seed_value, "world receives its stored seed before generation")
	var original_cells: Array = app.active_world.blocks.keys()
	app.active_world.add_block(Vector3i(40, 0, 40), 0)
	app.active_world.player.actions.set_place_pressed(true, true)
	app.active_world.player.actions.set_break_pressed(true, true)
	app.return_to_worlds()
	await process_frame
	check(app.page == "worlds" and not is_instance_valid(app.active_world), "F1 return unloads gameplay and restores list")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "return to list frees the mouse")
	app.open_world(id)
	await physics_frame
	check(app.active_world.terrain_seed == seed_value, "reopening a world preserves seed")
	check(not app.active_world.blocks.has(Vector3i(40, 0, 40)) and app.active_world.blocks.keys() == original_cells, "reopening regenerates original terrain without saving constructions")
	var key := InputEventKey.new()
	key.keycode = KEY_F1
	key.pressed = true
	app._unhandled_key_input(key)
	check(app.page == "worlds", "F1 returns from gameplay to list")
	app.show_page("create")
	key.keycode = KEY_ESCAPE
	app._unhandled_key_input(key)
	check(app.page == "worlds", "Escape returns from creation to list")
	app._unhandled_key_input(key)
	check(app.page == "home" and app.play_button.has_focus(), "Escape returns from list to keyboard-focused home")
	check(Catalog.new(test_path).worlds.size() == 3, "created worlds still exist in a new catalog after leaving gameplay")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	# Corrupt-file safety: preserve existing content and refuse destructive overwrite.
	var bad_path := test_path + ".bad"
	var file := FileAccess.open(bad_path, FileAccess.WRITE)
	file.store_string("invalid-json")
	file.close()
	var bad_catalog := Catalog.new(bad_path)
	check(not bad_catalog.load_error.is_empty() and bad_catalog.create_world("Do not overwrite").is_empty(), "invalid catalog is reported and never overwritten")
	check(FileAccess.get_file_as_string(bad_path) == "invalid-json", "invalid original file remains intact")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))
	print("RESULT: %d menu/catalog checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)