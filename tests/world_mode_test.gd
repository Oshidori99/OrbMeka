extends SceneTree
# Mode du monde (0.0.3) : Par défaut / Mode développeur, F3. 0.0.4.10 : retour au mode par défaut possible
# (voir developer_return_test.gd) ; la mention « utilisé » reste.
const Catalog = preload("res://scripts/world_catalog.gd")
const Settings = preload("res://scripts/user_settings.gd")
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
	var stamp := Time.get_ticks_usec()
	var path := "res://.godot/mode-test-%d.json" % stamp
	var settings_path := "res://.godot/mode-settings-%d.json" % stamp
	# Anciens mondes sans mode : chargés en Par défaut ; mode inconnu : fichier conservé.
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"version": 1, "worlds": [{"id": "1", "name": "Ancien", "seed": 5}]}')
	file.close()
	var catalog := Catalog.new(path)
	check(catalog.load_error.is_empty() and catalog.find_world("1").mode == Catalog.MODE_DEFAULT, "world without mode loads as default")
	var bad := path + ".bad"
	file = FileAccess.open(bad, FileAccess.WRITE)
	var bad_text := '{"version": 1, "worlds": [{"id": "1", "name": "X", "seed": 5, "mode": "admin"}]}'
	file.store_string(bad_text)
	file.close()
	var bad_catalog := Catalog.new(bad)
	check(not bad_catalog.load_error.is_empty() and bad_catalog.create_world("Y").is_empty() and FileAccess.get_file_as_string(bad) == bad_text, "unknown mode is reported and file never overwritten")
	check(catalog.create_world("Inconnu", "", "admin").is_empty(), "unknown mode rejected at creation")

	var settings := Settings.new(settings_path)
	var custom := {}
	for key in Settings.SPECS:
		custom[key] = str(Settings.SPECS[key].max)
	check(settings.apply_texts(custom), "custom global attributes saved")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.catalog = catalog
	app.settings = settings
	root.add_child(app)
	current_scene = app
	await process_frame
	# Création : Par défaut à gauche, Mode développeur à droite, Par défaut choisi.
	app.show_page("create")
	var row: Node = app.create_default_button.get_parent()
	check(row is HBoxContainer and row == app.create_developer_button.get_parent() and app.create_default_button.get_index() < app.create_developer_button.get_index(), "default button left, developer button right")
	check(row.get_index() > app.world_options_title.get_index(), "mode buttons sit in world options")
	check(app.create_default_button.text == "Par défaut" and app.create_developer_button.text == "Mode développeur", "mode button labels")
	check(app.create_mode == Catalog.MODE_DEFAULT and app.create_default_button.button_pressed and not app.create_developer_button.button_pressed, "default mode preselected")
	await process_frame
	await process_frame
	var panel: Control = app.menu_panel
	print("MODE_FORM: ", panel.get_global_rect())
	check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= 720, "creation form with mode fits 1280 by 720")
	app.name_field.text = "Monde normal"
	app.create_button.pressed.emit()
	check(app.page == "playing" and app.active_world.player.jump_speed == Settings.SPECS.jump_speed.default and app.active_world.player.walk_forward == Settings.SPECS.walk_forward.default, "default world ignores global attributes")
	check(app.active_world.player.actions.place_interval == Settings.SPECS.place_ms.default / 1000.0, "default world keeps default block interval")
	check(app.active_world.get_world_info_text().contains("Mode : Par défaut"), "F3 info shows default mode")
	var normal_id: String = app.current_world_id
	check(catalog.find_world(normal_id).mode == Catalog.MODE_DEFAULT, "default mode stored with world")
	app.return_to_worlds()
	app.show_page("create")
	app.create_developer_button.pressed.emit()
	check(app.create_mode == Catalog.MODE_DEVELOPER and app.create_developer_button.button_pressed and not app.create_default_button.button_pressed, "developer button selects developer mode")
	app.name_field.text = "Monde dev"
	app.create_button.pressed.emit()
	check(app.active_world.player.jump_speed == Settings.SPECS.jump_speed.max and app.active_world.player.walk_forward == Settings.SPECS.walk_forward.max, "developer world uses global attributes")
	check(app.active_world.get_world_info_text().contains("Mode : Mode développeur"), "F3 info shows developer mode")
	var dev_id: String = app.current_world_id
	app.return_to_worlds()
	app.show_page("create")
	check(app.create_mode == Catalog.MODE_DEFAULT and app.create_default_button.button_pressed, "creation form resets to default mode")
	app.show_page("worlds")

	# Paramètres du monde : passage au mode développeur avec confirmation, Annuler par défaut.
	app.refresh_world_list(normal_id)
	app.world_settings_button.pressed.emit()
	check(app.world_settings_text.text.contains("Mode : Par défaut") and app.world_developer_button.visible, "default world offers developer mode")
	app.world_developer_button.pressed.emit()
	check(app.page == "developer_confirm" and app.developer_confirm_message.text.contains("irréversible") and app.developer_cancel_button.has_focus(), "clear confirmation with Cancel focused")
	app.developer_cancel_button.pressed.emit()
	check(app.page == "world_settings" and catalog.find_world(normal_id).mode == Catalog.MODE_DEFAULT, "Cancel keeps default mode")
	app.world_developer_button.pressed.emit()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	check(app.page == "world_settings" and catalog.find_world(normal_id).mode == Catalog.MODE_DEFAULT, "Escape cancels confirmation")
	app.world_developer_button.pressed.emit()
	app.developer_confirm_button.pressed.emit()
	check(app.page == "world_settings" and catalog.find_world(normal_id).mode == Catalog.MODE_DEVELOPER, "confirmation switches to developer mode")
	check(app.world_settings_text.text.contains("Mode : Mode développeur") and not app.world_developer_button.visible and app.world_default_button.visible, "developer world offers the way back (0.0.4.10)")
	app.world_settings_back_button.pressed.emit()
	app.refresh_world_list(dev_id)
	app.world_settings_button.pressed.emit()
	check(not app.world_developer_button.visible and app.world_default_button.visible, "world created in developer mode can go back")
	app.world_settings_back_button.pressed.emit()

	# Duplication et rechargement conservent le mode.
	check(catalog.enable_developer_mode(normal_id) and catalog.find_world(normal_id).mode == Catalog.MODE_DEVELOPER, "enabling again keeps developer mode")
	check(not catalog.enable_developer_mode("absent"), "unknown world cannot change mode")
	var copy: Dictionary = catalog.duplicate_world(dev_id)
	check(copy.mode == Catalog.MODE_DEVELOPER, "duplicate keeps developer mode")
	var restored := Catalog.new(path)
	check(restored.find_world(normal_id).mode == Catalog.MODE_DEVELOPER and restored.find_world(dev_id).mode == Catalog.MODE_DEVELOPER and restored.find_world("1").mode == Catalog.MODE_DEFAULT, "modes persist through reload")
	app.open_world(normal_id)
	check(app.active_world.player.jump_speed == Settings.SPECS.jump_speed.max, "switched world now uses global attributes")
	app.return_to_worlds()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "verification never captures pointer")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for item in [path, bad, settings_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(item))
	print("RESULT: %d world mode checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
