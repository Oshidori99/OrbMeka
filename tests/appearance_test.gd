extends SceneTree
# 0.0.3.4 : synthèse des textes (− / Par défaut / +) et thème (sombre / par défaut / clair).
const Settings = preload("res://scripts/user_settings.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
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

func choose(app: Control, values: Dictionary) -> void:
	app.show_page("settings")
	for key in values:
		app.choice_buttons[key][values[key]].pressed.emit()
	app.settings_apply_button.pressed.emit()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/appearance-test-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	check(settings.values.text_detail == "default" and settings.values.theme_mode == "default", "choice defaults: default detail and default theme")
	check(Settings.SPECS.nav_width.default == 120 and Settings.SPECS.nav_width.min == 80 and Settings.SPECS.nav_width.max == 250, "left menu scale lowered to 80-250 px, 120 by default")
	check(Settings.SPECS.text_px.unit == "px" and Settings.SPECS.text_px.default == 18 and Settings.SPECS.text_px.min <= 18 * 0.4 + 0.5, "text size in px, minimum about 40 %")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var item: Dictionary = app.catalog.create_world("Apparence", "5")
	root.add_child(app)
	current_scene = app
	await process_frame
	# Boutons de choix, à leur place et dans l'ordre demandé.
	check(app.choice_buttons.text_detail.keys() == ["minus", "default", "plus"] and app.choice_buttons.text_detail.plus.text == "+", "synthesis offers −, Par défaut, +")
	check(app.choice_buttons.theme_mode.values().map(func(button): return button.text) == ["Sombre", "Par défaut", "Clair"], "theme offers Sombre, Par défaut, Clair")
	check(app.settings_sections.general.is_ancestor_of(app.choice_buttons.text_detail.plus) and app.settings_sections.video.is_ancestor_of(app.choice_buttons.theme_mode.light), "synthesis in general settings, theme in Vidéo")
	app.show_page("settings")
	check(app.choice_buttons.text_detail.default.button_pressed and not app.choice_buttons.text_detail.plus.button_pressed, "saved choice shown pressed")
	# Thèmes.
	for mode in ["dark", "light", "default"]:
		choose(app, {"theme_mode": mode})
		var colors: Dictionary = UiTheme.palette(mode)
		var theme: Theme = app.menu_root.theme
		check(theme.get_stylebox("panel", "PanelContainer").bg_color == colors.panel and theme.get_color("default_color", "RichTextLabel") == colors.text and app.news_label.get_theme_color("default_color") == colors.section, "theme applied everywhere: " + mode)
	check(UiTheme.palette("light").text.get_luminance() < 0.3 and UiTheme.palette("light").panel.get_luminance() > 0.8, "light theme: dark text on light panel")
	check(UiTheme.palette("dark").panel.get_luminance() < UiTheme.palette("default").panel.get_luminance(), "dark theme darker than default")
	# Synthèse des textes : + = textes complets d'avant, − = l'essentiel.
	var lengths := []
	for level in ["minus", "default", "plus"]:
		choose(app, {"text_detail": level})
		lengths.append(app.generation_info.text.length())
	check(lengths[0] < lengths[1] and lengths[1] < lengths[2] and app.generation_info.text.contains("Réouvrir un monde régénère son terrain initial."), "information text shorter at −, complete at +")
	choose(app, {"text_detail": "minus"})
	var hidden: Array = app.detail_labels.keys().filter(func(label): return label.text.is_empty())
	check(not hidden.is_empty() and hidden.all(func(label): return not label.visible), "empty − texts are hidden")
	app.show_page("worlds")
	app.open_world(item.id)
	var help := []
	for level in range(3):
		app.settings.values.text_detail = app.DETAIL_LEVELS[level]
		app.pause_game()
		app.open_help()
		help.append(app.help_text.text.length())
		app.show_page("pause")
		app.open_world_info()
		check(app.info_text.text.contains("Mode : Par défaut"), "world info always shows the mode: " + app.DETAIL_LEVELS[level])
		app.show_page("pause")
		app.resume_game()
	check(help[0] < help[1] and help[1] < help[2], "help text follows synthesis level")
	app.return_to_worlds()
	app.refresh_world_list(item.id)
	app.world_settings_button.pressed.emit()
	app.world_developer_button.pressed.emit()
	check(app.developer_confirm_message.text.contains("irréversible"), "irreversibility stays stated at −")
	app.developer_cancel_button.pressed.emit()
	choose(app, {"text_detail": "default"})
	# Réinitialisations et sauvegarde des choix.
	app.show_page("settings")
	app.choice_buttons.theme_mode.light.pressed.emit()
	app.setting_resets.theme_mode.pressed.emit()
	check(app.choice_values.theme_mode == "default" and app.choice_buttons.theme_mode.default.button_pressed, "↻ restores the default choice")
	app.choice_buttons.theme_mode.dark.pressed.emit()
	app.category_resets.Apparence.pressed.emit()
	check(app.choice_values.theme_mode == "default" and settings.values.theme_mode == "default", "category ↻ restores choices, not saved before Apply")
	choose(app, {"theme_mode": "light", "text_detail": "plus"})
	check(Settings.new(fixture).values == settings.values and settings.values.theme_mode == "light", "choices reload from the settings file")
	var texts := {}
	for key in settings.values:
		texts[key] = str(settings.values[key])
	texts.theme_mode = "violet"
	check(not settings.apply_texts(texts) and settings.values.theme_mode == "light", "unknown choice rejected")
	var bad := fixture + ".bad"
	var file := FileAccess.open(bad, FileAccess.WRITE)
	file.store_string('{"theme_mode": "violet", "text_detail": 3, "text_size": 120}')
	file.close()
	var loaded := Settings.new(bad)
	check(not loaded.load_notice.is_empty() and loaded.values.theme_mode == "default" and loaded.values.text_detail == "default" and loaded.values.text_px == 18, "invalid choices fall back to defaults; old % text size ignored")
	# Toutes les pages restent dans la fenêtre : thèmes clair et sombre, petit écran, grand texte.
	for size in [Vector2i(800, 450), Vector2i(1280, 720)]:
		root.size = size
		await process_frame
		for theme_name in ["light", "dark"]:
			app.show_page("settings")
			app.setting_fields.text_px.text = "27"
			choose(app, {"theme_mode": theme_name})
			var ok := true
			for page_name in ["home", "settings", "information", "worlds", "create", "rename", "delete"]:
				app.show_page(page_name)
				await process_frame
				await process_frame
				var rect: Rect2 = app.menu_panel.get_global_rect()
				var view: Vector2 = app.get_viewport().get_visible_rect().size
				var inside: bool = rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= view.x + 0.5 and rect.end.y <= view.y + 0.5
				if not inside:
					print("OVERFLOW: ", page_name, " ", rect)
				ok = ok and inside
			check(ok, "pages inside %dx%d with 27 px text, theme %s" % [size.x, size.y, theme_name])
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "verification never captures pointer")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for path in [fixture, bad, fixture + ".worlds"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d appearance checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
