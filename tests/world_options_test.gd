extends SceneTree
const Catalog = preload("res://scripts/world_catalog.gd")
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
	root.size = Vector2i(1280,720)
	var path := "res://.godot/options-test-%d.json" % Time.get_ticks_usec()
	var catalog := Catalog.new(path)
	var zero: Dictionary = catalog.create_world("Zéro", "0")
	var maximum: Dictionary = catalog.create_world("Maximum", "4294967295")
	check(zero.seed == 0 and maximum.seed == 4294967295, "seed endpoints are accepted exactly")
	var random_world: Dictionary = catalog.create_world("Aléatoire")
	check(not random_world.is_empty() and random_world.seed >= 0 and random_world.seed <= Catalog.MAX_SEED, "blank seed retains automatic generation")
	var count: int = catalog.worlds.size()
	for invalid in ["-1", "4294967296", "1.2", "abc", "99999999999999999999"]:
		check(catalog.create_world("Invalide", invalid).is_empty(), "invalid seed rejected: " + invalid)
	check(catalog.worlds.size() == count, "invalid seeds leave catalog unchanged")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.catalog = catalog
	root.add_child(app)
	current_scene = app
	app.show_page("create")
	check(app.world_options_title.text == "Options du monde", "creation shows empty world-options heading")
	check(app.pages.create.get_children().filter(func(child): return child is LineEdit).size() == 2, "creation contains name and optional seed")
	await process_frame
	await process_frame
	var panel: Control = app.pages.create.get_parent().get_parent()
	print("FORM_BOUNDS: ", panel.get_global_rect())
	check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= 720, "creation form fits 1280 by 720")
	app.name_field.text = "Mon monde"
	app.seed_field.text = " 12345 "
	app.create_button.pressed.emit()
	check(app.page == "playing" and app.active_world.terrain_seed == 12345, "form creates gameplay with exact chosen seed")
	var original_id: String = app.current_world_id
	app.return_to_worlds()
	app.refresh_world_list(original_id)
	app.duplicate_button.pressed.emit()
	var selection: PackedInt32Array = app.world_list.get_selected_items()
	var copy_id: String = str(app.world_list.get_item_metadata(selection[0]))
	var copy: Dictionary = catalog.find_world(copy_id)
	check(app.page == "worlds" and copy_id != original_id and copy.seed == 12345, "duplicate has new identity, same seed and stays in list")
	check(copy.name == "Mon monde (copie)", "duplicate receives readable unique name")
	check(Terrain.generate_cells(copy.seed) == Terrain.generate_cells(catalog.find_world(original_id).seed), "copy regenerates same original terrain")
	app.refresh_world_list(original_id)
	app.duplicate_button.pressed.emit()
	var copy2: Dictionary = catalog.find_world(str(app.world_list.get_item_metadata(app.world_list.get_selected_items()[0])))
	check(copy2.name == "Mon monde (copie 2)" and copy2.id != copy_id, "repeated duplication uses another unique name and identity")
	app.refresh_world_list(copy_id)
	await process_frame
	await process_frame
	check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= 720, "world list with additional actions fits 1280 by 720")
	app.world_settings_button.pressed.emit()
	check(app.page == "world_settings" and app.world_settings_text.text.contains(copy.name), "world settings refers to selected world")
	check(app.world_settings_text.text.contains("Mode : Par défaut") and app.pages.world_settings.get_children().filter(func(child): return child is LineEdit).is_empty(), "world settings shows the world mode without text fields")
	app.world_settings_back_button.pressed.emit()
	check(app.page == "worlds" and str(app.world_list.get_item_metadata(app.world_list.get_selected_items()[0])) == copy_id, "settings Return preserves world selection")
	app.open_world_settings()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	check(app.page == "worlds", "Escape exits world settings to list")
	var restored := Catalog.new(path)
	check(restored.find_world(original_id).seed == 12345 and restored.find_world(copy_id).seed == 12345 and restored.find_world(copy_id).name == copy.name, "chosen seed and duplicate persist through reload")
	check(restored.rename_world(copy_id, "Copie renommée") and restored.find_world(original_id).name == "Mon monde", "renaming copy leaves original intact")
	check(restored.delete_world(copy_id) and not restored.find_world(original_id).is_empty(), "deleting copy leaves original intact")
	var long_world: Dictionary = restored.create_world("x".repeat(48), "12345")
	var long_copy: Dictionary = restored.duplicate_world(long_world.id)
	check(not long_copy.is_empty() and long_copy.name.length() <= 48, "long names can be duplicated within length limit")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "verification never captures pointer")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d seed/duplication/options checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)