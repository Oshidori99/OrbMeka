extends SceneTree
# 0.0.3.1 : Vidéo (taille des panneaux, menu de gauche) et sensibilité de la souris.
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
	app.settings_apply_button.pressed.emit()

func panels_fit(app: Control, tag: String) -> void:
	var view: Vector2 = app.get_viewport().get_visible_rect().size
	var ok := true
	for page_name in ["home", "settings", "information", "history", "worlds", "create", "world_settings", "rename", "delete", "developer_confirm"]:
		app.show_page(page_name)
		await process_frame
		await process_frame
		var rect: Rect2 = app.menu_panel.get_global_rect()
		if rect.position.x < 0 or rect.end.x > view.x + 0.5:
			ok = false
			print("OVERFLOW: ", page_name, " ", rect, " in ", view)
	check(ok, "every panel stays inside the window " + tag)

func _run() -> void:
	var fixture := "res://.godot/display-test-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	check(settings.values.mouse_sensitivity == 100 and settings.values.panel_size == 72 and settings.values.nav_width == 190, "defaults keep previous look and feel")
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
		apply(app, {"panel_size": "95", "nav_width": "400"})
		await panels_fit(app, "at 95 %% in %dx%d" % [size.x, size.y])
		app.show_page("settings")
		apply(app, {"panel_size": "50", "nav_width": "120"})
		await panels_fit(app, "at 50 %% in %dx%d" % [size.x, size.y])
	root.size = Vector2i(1280, 720)
	await process_frame
	app.show_page("settings")
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
	apply(app, {"nav_width": "300"})
	check(app.settings_nav.custom_minimum_size.x == 300, "left menu takes the chosen width")
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
	apply(app, {"mouse_sensitivity": "250", "panel_size": "60", "nav_width": "250", "jump_height": "4"})
	check(Settings.new(fixture).values == settings.values and settings.values.mouse_sensitivity == 250, "general and video settings reload from the settings file")
	app.show_page("settings")
	app.settings_reset_all_button.pressed.emit()
	check(app.setting_fields.mouse_sensitivity.text == Settings.number_text(250) and app.setting_fields.panel_size.text == Settings.number_text(60) and app.setting_fields.jump_height.text == Settings.number_text(Settings.SPECS.jump_height.default), "Attributs reset all leaves mouse and video untouched")
	app.category_resets.Panneaux.pressed.emit()
	check(app.setting_fields.panel_size.text == Settings.number_text(72) and app.setting_fields.nav_width.text == Settings.number_text(190) and app.setting_fields.mouse_sensitivity.text == Settings.number_text(250), "Panneaux reset restores both video defaults only")
	app.category_resets.Souris.pressed.emit()
	check(app.setting_fields.mouse_sensitivity.text == Settings.number_text(100), "Souris reset restores sensitivity")
	app.setting_fields.mouse_sensitivity.text = "250"
	app.setting_resets.mouse_sensitivity.pressed.emit()
	check(app.setting_fields.mouse_sensitivity.text == Settings.number_text(100), "field reset restores sensitivity")
	check(settings.values.mouse_sensitivity == 250 and settings.values.panel_size == 60, "resets are not saved before Apply")
	app.setting_fields.mouse_sensitivity.text = "250"
	app.settings_apply_button.pressed.emit()
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
	check(upgraded.load_notice.is_empty() and upgraded.values.mouse_sensitivity == 100 and upgraded.values.panel_size == 72 and upgraded.values.nav_width == 190, "older settings file loads silently with new defaults")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "verification never captures pointer")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for path in [fixture, old, fixture + ".worlds"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d display/mouse checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
