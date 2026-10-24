extends SceneTree
# 0.0.4.14 : dans Paramètres, chaque titre (catégories, parties de Contrôles, modes) se réduit et se
# développe d'un clic ; en haut : Tout réduire, Tout développer, et ce qu'on voit à l'ouverture
# (comme la dernière fois, tout développé, tout réduit). Enregistré dans menus.json.
const Settings = preload("res://scripts/user_settings.gd")
const Controls = preload("res://scripts/controls.gd")
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

func click(label: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	label.gui_input.emit(event)

func open_app(fixture: String) -> Control:
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(fixture)
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	current_scene = app
	return app

func close_app(app: Control) -> void:
	root.remove_child(app)
	app.queue_free()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/folds-%d.json" % Time.get_ticks_usec()
	var app := open_app(fixture)
	await process_frame
	app.show_page("settings")
	# Tous les titres sont repliables.
	var expected := ["cat:Saut", "cat:Marche", "cat:Voler", "cat:Souris", "cat:Son", "controls:Mouvements", "controls:Blocs", "controls:Vitesses", "controls:Menus", "option:run_mode", "option:crouch_mode"]
	check(expected.all(func(key): return app.fold_entries.has(key)), "every title can fold (%d titles)" % app.fold_entries.size())
	var general_count := 0
	for section in app.GENERAL_CATEGORIES:
		general_count += app.GENERAL_CATEGORIES[section].size()
	check(app.fold_entries.size() == app.ATTRIBUTE_CATEGORIES.size() + general_count + 4 + Controls.OPTIONS.size(), "attributes, general, video, controls and modes titles")
	check(app.fold_entries.keys().all(func(key): return not app.is_folded(key) and app.fold_entries[key].title.text.begins_with("▾ ")), "all developed at first, ▾")
	# Un clic sur un titre.
	var marche: Dictionary = app.fold_entries["cat:Marche"]
	click(marche.title)
	check(app.is_folded("cat:Marche") and not marche.body.visible and marche.title.text == "▸ Marche" and marche.title.visible, "click: Marche folds, only its title stays")
	check(not app.setting_fields.walk_forward.is_visible_in_tree() and app.setting_fields.run_forward.get_parent().get_parent().visible, "its fields are hidden, not the others")
	click(marche.title)
	check(not app.is_folded("cat:Marche") and marche.title.text == "▾ Marche", "click again: developed")
	click(app.fold_entries["controls:Mouvements"].title)
	check(app.is_folded("controls:Mouvements") and not app.control_buttons.jump.is_visible_in_tree() and app.control_group_labels.Mouvements.visible, "Contrôles parts fold too")
	# Les trois boutons, sur une seule ligne, en haut.
	var row: Node = app.fold_collapse_button.get_parent()
	check(row == app.fold_expand_button.get_parent() and row == app.fold_open_button.get_parent() and app.fold_collapse_button.get_index() < app.fold_expand_button.get_index() and app.fold_expand_button.get_index() < app.fold_open_button.get_index(), "one line: Tout réduire, Tout développer, then the opening choice")
	check(row.get_index() < app.settings_tabs.general.get_parent().get_parent().get_index() and app.fold_collapse_button.theme_type_variation == "OrbFold", "small buttons at the top of Paramètres")
	app.fold_collapse_button.pressed.emit()
	check(app.fold_entries.keys().all(func(key): return app.is_folded(key)), "Tout réduire")
	app.fold_expand_button.pressed.emit()
	check(app.fold_entries.keys().all(func(key): return not app.is_folded(key)), "Tout développer")
	# Choix à l'ouverture.
	check(app.settings.menu_open_mode == "last" and app.fold_open_button.text.contains("comme la dernière fois"), "opening: as last time by default")
	click(app.fold_entries["cat:Saut"].title)
	click(app.fold_entries["controls:Blocs"].title)
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(app.settings.menus_path()))
	check(saved.open_mode == "last" and saved.folded.has("cat:Saut") and saved.folded.has("controls:Blocs") and saved.folded.size() == 2, "folds saved in menus.json")
	app.settings_back_button.pressed.emit()
	app.fold_expand_button.pressed.emit()
	click(app.fold_entries["cat:Saut"].title)
	app.show_page("home")
	app.show_page("settings")
	check(app.is_folded("cat:Saut") and not app.is_folded("controls:Blocs"), "reopening: as last time")
	close_app(app)
	await process_frame
	app = open_app(fixture)
	await process_frame
	app.show_page("settings")
	check(app.is_folded("cat:Saut") and not app.is_folded("cat:Marche"), "kept after restarting the game")
	app.fold_open_button.pressed.emit()
	check(app.settings.menu_open_mode == "expanded" and app.fold_open_button.text.contains("tout développé"), "opening choice: tout développé")
	app.show_page("home")
	app.show_page("settings")
	check(app.fold_entries.keys().all(func(key): return not app.is_folded(key)), "opens all developed")
	app.fold_open_button.pressed.emit()
	check(app.settings.menu_open_mode == "collapsed" and app.fold_open_button.text.contains("tout réduit"), "opening choice: tout réduit")
	app.show_page("home")
	app.show_page("settings")
	check(app.fold_entries.keys().all(func(key): return app.is_folded(key)), "opens all folded")
	app.fold_open_button.pressed.emit()
	check(app.settings.menu_open_mode == "last", "third click: back to as last time")
	check(Settings.new(fixture).menu_open_mode == "last", "choice saved")
	close_app(app)
	await process_frame
	# Fichier abîmé : valeurs par défaut.
	var file := FileAccess.open(Settings.new(fixture).menus_path(), FileAccess.WRITE)
	file.store_string("{abîmé")
	file.close()
	var broken := Settings.new(fixture)
	check(broken.menu_open_mode == "last" and broken.menu_folded.is_empty(), "unreadable menus.json: defaults")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d fold checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
