extends SceneTree
# 0.0.2.14 : historique lu depuis docs/, menu latéral de Paramètres,
# réinitialisations par catégorie et totale, catégorie Marche utilisée par le joueur.
const Settings = preload("res://scripts/user_settings.gd")
const App = preload("res://scripts/app.gd")
const Player = preload("res://scripts/player.gd")
const HistoryExporter = preload("res://addons/history_export/history_exporter.gd")
const WALK_KEYS := ["walk_forward", "walk_side", "walk_back"]
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

func _inside(rect: Rect2, view: Rect2) -> bool:
	return view.grow(1).encloses(rect)

func _field_texts(app: Control) -> Dictionary:
	var result := {}
	for key in app.setting_fields:
		result[key] = app.setting_fields[key].text
	return result

func _horizontal_speed(player: CharacterBody3D, direction: Vector2) -> float:
	player.position = Vector3(45.5, 0.02, 45.5)
	player.velocity = Vector3.ZERO
	player.step_movement(1.0/60.0, direction, false)
	return Vector2(player.velocity.x, player.velocity.z).length()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/settings-walk-test-%d.json" % Time.get_ticks_usec()
	# Historique.
	check(FileAccess.file_exists(App.HISTORY_PATH) and App.HISTORY_PATH == HistoryExporter.HISTORY_PATH, "game and export plugin read the same existing history file")
	check(FileAccess.get_file_as_string(App.HISTORY_PATH).contains("0.0.2.14 — "), "history file lists this version")
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var item: Dictionary = app.catalog.create_world("Marche", "77", "developer")
	root.add_child(app)
	current_scene = app
	app.history_button.pressed.emit()
	check(app.page == "history" and app.history_text.text == FileAccess.get_file_as_string(App.HISTORY_PATH) and not app.history_text.text.contains("indisponible"), "history screen shows the version history")
	escape()
	# Menu latéral.
	app.settings_button.pressed.emit()
	check(app.page == "settings" and app.pages.settings.get_child(0).text == "Paramètres", "home opens Paramètres")
	var tabs: Array = app.settings_tabs.values()
	check(tabs.map(func(tab): return tab.text) == ["Paramètres généraux", "Attributs"], "side menu lists Paramètres généraux then Attributs")
	check(tabs.all(func(tab): return tab.theme_type_variation == "OrbTab" and tab.toggle_mode and tab.button_group == tabs[0].button_group), "side buttons are rectangular toggle tabs in one group")
	check(tabs[0].get_parent().get_index() == 0 and tabs[0].get_parent().get_parent() is HBoxContainer, "side menu sits on the left")
	check(app.settings_section == "general" and app.settings_sections.general.visible and not app.settings_sections.attributes.visible and tabs[0].button_pressed, "general settings open first")
	var general_texts: Array = app.settings_sections.general.get_children().map(func(label): return label.text)
	check(general_texts.has("Aucun réglage disponible pour le moment."), "general settings say no setting is available")
	tabs[1].pressed.emit()
	check(app.settings_section == "attributes" and app.settings_sections.attributes.visible and not app.settings_sections.general.visible and tabs[1].button_pressed and not tabs[0].button_pressed, "Attributs tab shows the attribute screen")
	app.setting_fields.walk_forward.text = "9"
	tabs[0].pressed.emit()
	tabs[1].pressed.emit()
	check(app.setting_fields.walk_forward.text == "9", "switching sections keeps unsaved edits")
	escape()
	check(app.page == "home" and settings.values.walk_forward == Settings.SPECS.walk_forward.default, "Escape abandons edits")
	app.settings_button.pressed.emit()
	check(app.setting_fields.walk_forward.text == Settings.number_text(Settings.SPECS.walk_forward.default) and app.settings_section == "general", "reopening shows saved values on the first tab")
	# Catégorie Marche.
	check(App.ATTRIBUTE_CATEGORIES.keys() == ["Saut", "Blocs", "Marche"] and App.ATTRIBUTE_CATEGORIES.Marche.keys == WALK_KEYS, "Marche is the last category with three speeds")
	for key in WALK_KEYS:
		check(Settings.SPECS[key].default == Player.SPEED, "walking default is the former player speed: " + key)
	check(["Avancer", "Avancer de côté", "Reculer"] == WALK_KEYS.map(func(key): return Settings.SPECS[key].label), "walking labels")
	# Réinitialisations.
	var custom := {"jump_height": "3", "jump_speed": "9", "fall_gravity": "18", "place_ms": "450", "break_ms": "650", "walk_forward": "7", "walk_side": "4", "walk_back": "3"}
	for category in App.ATTRIBUTE_CATEGORIES:
		for key in custom:
			app.setting_fields[key].text = custom[key]
		var reset: Button = app.category_resets[category]
		check(reset.text == "↻" and not reset.tooltip_text.is_empty(), "category reset uses the round arrow: " + category)
		reset.pressed.emit()
		var keys: Array = App.ATTRIBUTE_CATEGORIES[category].keys
		var ok := true
		for key in custom:
			var expected: String = Settings.number_text(Settings.SPECS[key].default) if key in keys else custom[key]
			ok = ok and app.setting_fields[key].text == expected
		check(ok, "category reset affects only " + category)
	check(settings.values.jump_height == Settings.SPECS.jump_height.default, "category reset is not saved before Apply")
	for key in custom:
		app.setting_fields[key].text = custom[key]
	check(app.settings_reset_all_button.text.begins_with("↻"), "reset all uses the round arrow")
	# 0.0.2.14.2 : ↻ de catégorie en orange, catégories espacées ; les autres ↻ gardent le violet.
	check(app.category_resets.values().all(func(button): return button.theme_type_variation == "OrbCategoryReset"), "category resets are orange")
	var orange: Color = app.category_resets.Saut.get_theme_stylebox("normal").bg_color
	check(orange.r > 0.8 and orange.g > 0.5 and orange.b < 0.4, "category reset colour is orange-yellow")
	check(app.settings_reset_all_button.theme_type_variation == "" and app.setting_resets.values().all(func(button): return button.theme_type_variation == ""), "reset all and field resets keep the normal style")
	var gaps_ok := true
	for category in app.category_resets:
		var header: Node = app.category_resets[category].get_parent()
		var gap: Control = header.get_parent().get_child(header.get_index() - 1)
		gaps_ok = gaps_ok and gap.custom_minimum_size.y >= 20
	check(gaps_ok, "extra space before each category")
	app.settings_reset_all_button.pressed.emit()
	var all_default := true
	for key in Settings.SPECS:
		all_default = all_default and app.setting_fields[key].text == Settings.number_text(Settings.SPECS[key].default)
	check(all_default, "reset all restores every default")
	# Bornes et sauvegarde.
	for invalid in ["0,5", "12,5", "abc"]:
		app.setting_fields.walk_back.text = invalid
		app.settings_apply_button.pressed.emit()
		check(settings.values.walk_back == 5.5 and app.settings_message.text.begins_with("Reculer"), "walking speed rejected: " + invalid)
	for key in custom:
		app.setting_fields[key].text = custom[key]
	app.settings_apply_button.pressed.emit()
	check(settings.values.walk_forward == 7 and settings.values.walk_side == 4 and settings.values.walk_back == 3, "walking speeds saved")
	check(Settings.new(fixture).values == settings.values, "walking speeds reload from the settings file")
	var old := fixture + ".old"
	var file := FileAccess.open(old, FileAccess.WRITE)
	file.store_string('{"jump_height":3,"jump_speed":9,"fall_gravity":18,"place_ms":450,"break_ms":650}')
	file.close()
	var upgraded := Settings.new(old)
	check(upgraded.load_notice.is_empty() and upgraded.values.jump_height == 3 and upgraded.values.walk_side == 5.5, "older settings file loads silently with walking defaults")
	# Mise en page à toutes les tailles.
	for window_size in [Vector2i(800, 450), Vector2i(1280, 720), Vector2i(2560, 1080)]:
		root.size = window_size
		for section in ["general", "attributes"]:
			app.show_settings_section(section)
			await process_frame
			await process_frame
			check(_inside(app.menu_panel.get_global_rect(), root.get_visible_rect()), "settings %s fits at %dx%d" % [section, window_size.x, window_size.y])
	root.size = Vector2i(1280, 720)
	# Le jeu utilise les vitesses.
	app.show_page("worlds")
	app.open_world(item.id)
	var player: CharacterBody3D = app.active_world.player
	player.set_physics_process(false)
	await physics_frame
	check(player.walk_forward == 7 and player.walk_side == 4 and player.walk_back == 3, "world receives walking speeds")
	check(absf(_horizontal_speed(player, Vector2(0, -1)) - 7.0) < 0.01, "forward speed used in game")
	check(absf(_horizontal_speed(player, Vector2(1, 0)) - 4.0) < 0.01 and absf(_horizontal_speed(player, Vector2(-1, 0)) - 4.0) < 0.01, "side speed used in game")
	check(absf(_horizontal_speed(player, Vector2(0, 1)) - 3.0) < 0.01, "back speed used in game")
	check(_horizontal_speed(player, Vector2(1, -1)) <= 7.0 and _horizontal_speed(player, Vector2(1, -1)) > 4.0, "diagonal mixes forward and side speeds")
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for path in [fixture, old, fixture + ".worlds"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d settings/walk checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
