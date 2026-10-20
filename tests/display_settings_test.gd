extends SceneTree
# 0.0.3.1 : Vidéo (taille des panneaux, menu de gauche) et sensibilité de la souris.
# 0.0.3.2 : taille du texte, textes sélectionnables, menu de gauche à 150 px par défaut.
# 0.0.3.3 : taille du texte en px (7 à 27), menu de gauche 80 à 250 px (120 par défaut).
const Settings = preload("res://scripts/user_settings.gd")
const Player = preload("res://scripts/player.gd")
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

func apply(app: Control, values: Dictionary) -> void:
	for key in values:
		app.setting_fields[key].text = values[key]
	app.apply_user_settings()

func panels_fit(app: Control, tag: String) -> void:
	var view: Vector2 = app.get_viewport().get_visible_rect().size
	var ok := true
	for page_name in ["home", "settings", "information", "history", "worlds", "create", "world_settings", "rename", "delete", "developer_confirm"]:
		app.show_page(page_name)
		await process_frame
		await process_frame
		var rect: Rect2 = app.menu_panel.get_global_rect()
		if rect.position.x < 0 or rect.end.x > view.x + 0.5 or rect.position.y < 0 or rect.end.y > view.y + 0.5:
			ok = false
			print("OVERFLOW: ", page_name, " ", rect, " in ", view)
	check(ok, "every panel stays inside the window " + tag)

func _run() -> void:
	var fixture := "res://.godot/display-test-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	check(settings.values.mouse_sensitivity == 100 and settings.values.panel_size == 72 and settings.values.nav_percent == 15 and settings.values.text_px == 13, "defaults keep previous look and feel")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var item: Dictionary = app.catalog.create_world("Souris", "9")
	root.add_child(app)
	current_scene = app
	for size in [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(2560, 1080)]:
		root.size = size
		await process_frame
		app.show_page("settings")
		apply(app, {"panel_size": "95", "nav_percent": "40", "text_px": "27"})
		await panels_fit(app, "at 95 %% and text 27 px in %dx%d" % [size.x, size.y])
		app.show_page("settings")
		apply(app, {"panel_size": "50", "nav_percent": "5", "text_px": "7"})
		await panels_fit(app, "at 50 %% and text 7 px in %dx%d" % [size.x, size.y])
	root.size = Vector2i(1280, 720)
	await process_frame
	# Taille du texte : thème et tailles particulières suivent ; retour au défaut ensuite.
	app.show_page("settings")
	apply(app, {"text_px": "27"})
	var theme: Theme = app.menu_root.theme
	check(theme.get_font_size("normal_font_size", "RichTextLabel") == 27 and theme.get_font_size("font_size", "Button") == 30 and theme.get_font_size("normal_font_size", "OrbTitle") == 51, "text size scales theme fonts")
	check(app.history_text.get_theme_font_size("normal_font_size") == 26 and app.shortcut_hints.get_theme_font_size("font_size") == 23, "text size scales particular sizes")
	app.show_page("worlds")
	app.open_world(item.id)
	check(app.active_world.selected_block_label.get_theme_font_size("font_size") == 27, "text size applies to in-game texts")
	app.return_to_worlds()
	app.show_page("settings")
	apply(app, {"text_px": "18"})
	check(app.menu_root.theme.get_font_size("normal_font_size", "RichTextLabel") == 18 and app.history_text.get_theme_font_size("normal_font_size") == 17, "default text size restores original sizes")
	# Textes sélectionnables et copiables ; plus aucun Label dans les menus.
	var texts: Array = app.menu_root.find_children("*", "RichTextLabel", true, false)
	check(texts.size() > 30 and texts.all(func(label): return label.selection_enabled and label.context_menu_enabled), "every menu text is selectable and copyable")
	check(app.menu_root.find_children("*", "Label", true, false).is_empty(), "menus contain no unselectable Label")
	# Moins de répétitions : pas de titre de section (déjà sur l'onglet), noms de champs en blanc.
	var repeated := false
	for section in app.settings_sections:
		for label in app.settings_sections[section].find_children("*", "RichTextLabel", true, false):
			if label.text == app.SETTINGS_SECTIONS[section] or label.text.contains("Jamais plus large"):
				repeated = true
	check(not repeated, "no section title repeating the side tab")
	var field_label: RichTextLabel = app.setting_fields.mouse_sensitivity.get_parent().get_child(0)
	check(field_label.theme_type_variation == "" and field_label.text.begins_with("Sensibilité"), "field names use the white text style")
	apply(app, {"panel_size": "50"})
	await process_frame
	var small: float = app.menu_panel.custom_minimum_size.x
	apply(app, {"panel_size": "80"})
	await process_frame
	var large: float = app.menu_panel.custom_minimum_size.x
	check(is_equal_approx(small, 640.0) and is_equal_approx(large, 1024.0), "wide panels follow the percentage of the window width")
	app.show_page("home")
	var home_large: float = app.menu_panel.custom_minimum_size.x
	apply(app, {"panel_size": "72"})
	app.show_page("home")
	check(home_large > app.menu_panel.custom_minimum_size.x and is_equal_approx(app.menu_panel.custom_minimum_size.x, 560.0), "compact panels grow in the same proportion")
	app.show_page("settings")
	apply(app, {"nav_percent": "25"})
	check(is_equal_approx(app.settings_nav.custom_minimum_size.x, app.menu_panel.custom_minimum_size.x * 0.25), "left menu takes the chosen share of the panel")
	root.size = Vector2i(800, 450)
	await process_frame
	check(app.settings_nav.custom_minimum_size.x <= app.menu_panel.custom_minimum_size.x * 0.4 + 0.01, "left menu always leaves room for content")
	root.size = Vector2i(1280, 720)
	await process_frame
	# Bornes, réinitialisations et sauvegarde.
	for invalid in ["49", "96", "abc"]:
		apply(app, {"panel_size": invalid})
		check(settings.values.panel_size == 72 and app.settings_message.text.begins_with("Taille des panneaux"), "panel size rejected: " + invalid)
	app.setting_fields.panel_size.text = "72"
	for invalid in ["9", "301"]:
		apply(app, {"mouse_sensitivity": invalid})
		check(settings.values.mouse_sensitivity == 100, "mouse sensitivity rejected: " + invalid)
	app.setting_fields.mouse_sensitivity.text = "100"
	apply(app, {"mouse_sensitivity": "250", "panel_size": "60", "nav_percent": "40", "jump_height": "4"})
	check(Settings.new(fixture).values == settings.values and settings.values.mouse_sensitivity == 250, "general and video settings reload from the settings file")
	app.show_page("settings")
	app.settings_reset_all_button.pressed.emit()
	check(app.setting_fields.mouse_sensitivity.text == Settings.number_text(250) and app.setting_fields.panel_size.text == Settings.number_text(60) and app.setting_fields.jump_height.text == Settings.number_text(Settings.SPECS.jump_height.default), "Attributs reset all leaves mouse and video untouched")
	app.category_resets.Panneaux.pressed.emit()
	check(app.setting_fields.panel_size.text == Settings.number_text(72) and app.setting_fields.nav_percent.text == Settings.number_text(15) and app.setting_fields.mouse_sensitivity.text == Settings.number_text(250), "Panneaux reset restores both video defaults only")
	app.category_resets.Souris.pressed.emit()
	check(app.setting_fields.mouse_sensitivity.text == Settings.number_text(100), "Souris reset restores sensitivity")
	app.setting_fields.mouse_sensitivity.text = "250"
	app.setting_resets.mouse_sensitivity.pressed.emit()
	check(app.setting_fields.mouse_sensitivity.text == Settings.number_text(100), "field reset restores sensitivity")
	check(settings.values.mouse_sensitivity == 100 and settings.values.panel_size == 72, "resets are saved at once")
	app.setting_fields.mouse_sensitivity.text = "250"
	app.apply_user_settings()
	# Sensibilité : valable aussi dans un monde par défaut ; attributs restent par défaut.
	app.show_page("worlds")
	app.open_world(item.id)
	var player: CharacterBody3D = app.active_world.player
	check(is_equal_approx(player.sensitivity, Player.SENSITIVITY * 2.5), "mouse sensitivity applies in a default-mode world")
	check(player.jump_height == Settings.SPECS.jump_height.default, "default-mode world still ignores attributes")
	app.return_to_worlds()
	var old := fixture + ".old"
	var file := FileAccess.open(old, FileAccess.WRITE)
	file.store_string('{"jump_height":3,"walk_side":4}')
	file.close()
	var upgraded := Settings.new(old)
	check(upgraded.load_notice.is_empty() and upgraded.values.mouse_sensitivity == 100 and upgraded.values.panel_size == 72 and upgraded.values.nav_percent == 15 and upgraded.values.text_px == 13, "older settings file loads silently with new defaults")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "verification never captures pointer")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for path in [fixture, old, fixture + ".worlds"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d display/mouse checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
