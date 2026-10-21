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

func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	# Réglages par défaut isolés : jamais ceux du joueur (user://settings.json).
	app.settings = load("res://scripts/user_settings.gd").new("res://.godot/test-default-settings.json")
	# Textes complets (Synthèse des textes : +) : ce test vérifie tout leur contenu.
	app.settings.values.text_detail = "plus"
	app.catalog = load("res://scripts/world_catalog.gd").new("res://.godot/home-info-unused.json")
	app.catalog.worlds.append({"id": "test", "name": "Monde privé", "seed": 123456789})
	root.add_child(app)
	current_scene = app
	var buttons: Array = app.pages.home.find_children("*", "Button", true, false).map(func(button): return button.text)
	check(buttons == ["Jouer", "Paramètres", "Informations", "Historique des versions"], "home buttons appear in requested order")
	check(app.home_version.text == "v" + str(ProjectSettings.get_setting("application/config/version")), "home shows current project version")
	app.settings_button.pressed.emit()
	check(app.page == "settings" and app.settings_tabs.general.has_focus(), "settings opens with keyboard focus on the first side tab")
	check(app.pages.settings.get_child(0).text == "Paramètres" and app.setting_fields.size() == 24, "settings shows Paramètres with twenty-four fields (18 attributes, mouse, 5 video)")
	check(app.pages.settings.find_children("*", "Button", true, false).back() == app.settings_back_button and not app.pages.settings.find_children("*", "Button", true, false).any(func(button): return button.text == "Appliquer"), "no Apply button, Return available")
	app.settings_back_button.pressed.emit()
	check(app.page == "home", "settings return button restores home")
	app.settings_button.pressed.emit()
	escape()
	check(app.page == "home", "Escape returns from settings to home")
	app.information_button.pressed.emit()
	check(app.page == "information" and app.pages.information.get_child(0).text == "Génération des mondes", "home information opens generation section")
	for text in ["largeur 128 × longueur 128", "largeur 41 × longueur 41", "hauteur maximale 25", "3 ou 4, hauteur maximale 3", "Graine choisie à la création", "constructions non sauvegardées"]:
		check(app.generation_info.text.contains(text), "general information includes: " + text)
	check(not app.generation_info.text.contains("Monde privé") and not app.generation_info.text.contains("123456789"), "home information contains no specific world name or seed")
	check(not is_instance_valid(app.active_world) and not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "home screens do not start gameplay or capture pointer")
	await process_frame
	await process_frame
	var panel: Control = app.menu_panel
	var rect := panel.get_global_rect()
	check(rect.position.y >= 0 and rect.end.y <= 720, "information page fits 1280 by 720 viewport")
	app.information_back_button.pressed.emit()
	check(app.page == "home", "information return button restores home")
	app.information_button.pressed.emit()
	escape()
	check(app.page == "home", "Escape returns from information to home")
	app.play_button.pressed.emit()
	check(app.page == "worlds" and app.world_list.item_count == 1 and app.world_list.get_item_text(0) == "Monde privé", "Play still opens named-world list")
	check(not app.list_message.text.contains("128") and app.get("world_details") == null, "generation details removed from world list")
	check(not app.open_button.disabled and not app.rename_button.disabled and not app.delete_button.disabled and is_instance_valid(app.new_world_button), "world actions are retained")
	app.open_button.pressed.emit()
	check(app.page == "playing" and app.active_world.terrain_seed == 123456789, "selected world still opens")
	app.pause_game()
	app.info_button.pressed.emit()
	check(app.page == "world_info" and paused and app.info_text.text.contains("123456789"), "pause information still describes actual world")
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	print("RESULT: %d home/interface checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)