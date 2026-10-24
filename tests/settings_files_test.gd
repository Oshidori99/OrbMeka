extends SceneTree
# 0.0.3.6 : un fichier par menu de Paramètres et champ de vision (FOV).
# 0.0.3.10 : taille des zones et boutons (marges, espaces), sans le texte ni la largeur des menus.
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

func read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func apply(app: Control, values: Dictionary) -> void:
	app.show_page("settings")
	for key in values:
		app.setting_fields[key].text = values[key]
	app.apply_user_settings()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	# Noms des fichiers du joueur : le nom du menu, dans user://parametres/ (lecture seule ici).
	var player_files := Settings.new()
	check(player_files.file_path("general") == "user://parametres/parametres-generaux.json" and player_files.file_path("video") == "user://parametres/video.json" and player_files.file_path("attributes") == "user://parametres/attributs.json", "player files are named after their menu")
	var fixture := "res://.godot/files-test-%d.json" % Time.get_ticks_usec()
	# 0.0.4.22 : anciens fichiers (à la racine) déplacés dans parametres/, sans écraser ceux qui y sont déjà.
	var old_dir := fixture.get_basename() + "-old"
	var new_dir := old_dir.path_join(Settings.FOLDER)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(new_dir))
	for name in ["video.json", "controles.json", "menus.json", "worlds.json"]:
		var old_file := FileAccess.open(old_dir.path_join(name), FileAccess.WRITE)
		old_file.store_string("{\"old\": true}")
		old_file.close()
	var kept_file := FileAccess.open(new_dir.path_join("menus.json"), FileAccess.WRITE)
	kept_file.store_string("{\"new\": true}")
	kept_file.close()
	var moved: Array = Settings.move_old_files(old_dir, new_dir)
	check(moved == ["video.json", "controles.json"] and FileAccess.file_exists(new_dir.path_join("video.json")) and not FileAccess.file_exists(old_dir.path_join("video.json")), "old settings files moved into parametres/")
	check(FileAccess.get_file_as_string(new_dir.path_join("menus.json")).contains("new") and FileAccess.file_exists(old_dir.path_join("worlds.json")), "never overwrites, worlds stay where they are")
	for name in ["video.json", "controles.json", "menus.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(new_dir.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old_dir.path_join("menus.json")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old_dir.path_join("worlds.json")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(new_dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old_dir))
	var paths: Array = []
	var settings := Settings.new(fixture)
	for menu in Settings.FILES:
		paths.append(settings.file_path(menu))
	check(paths == Settings.FILES.values().map(func(name): return fixture.get_basename() + "-" + name), "test files stay apart from the player's files")
	var texts := {}
	for key in settings.values:
		texts[key] = str(settings.values[key])
	texts.fov = "90"
	texts.jump_height = "3"
	texts.text_detail = "plus"
	check(settings.apply_texts(texts), "settings saved")
	var general: Dictionary = read_json(settings.file_path("general"))
	var video: Dictionary = read_json(settings.file_path("video"))
	var attributes: Dictionary = read_json(settings.file_path("attributes"))
	check(general.keys() == Settings.GENERAL_KEYS.filter(func(key): return general.has(key)) and general.text_detail == "plus" and general.has("mouse_sensitivity"), "Paramètres généraux file holds only its settings")
	check(video.fov == 90 and video.has("panel_size") and video.has("theme_mode") and not video.has("jump_height") and not video.has("mouse_sensitivity"), "Vidéo file holds only video settings")
	check(attributes.keys().size() == Settings.ATTRIBUTE_KEYS.size() and attributes.jump_height == 3, "Attributs file holds only the eight attributes")
	check(not FileAccess.file_exists(fixture), "no single settings file is written any more")
	check(Settings.new(fixture).values == settings.values, "three files reload into the same settings")
	# Reprise de l'ancien fichier unique (avant 0.0.3.6), jamais modifié.
	var legacy := "res://.godot/files-legacy-%d.json" % Time.get_ticks_usec()
	var legacy_text := '{"jump_height": 3.5, "mouse_sensitivity": 150, "nav_width": 150}'
	var file := FileAccess.open(legacy, FileAccess.WRITE)
	file.store_string(legacy_text)
	file.close()
	var migrated := Settings.new(legacy)
	check(migrated.values.jump_height == 3.5 and migrated.values.mouse_sensitivity == 150 and migrated.load_notice.is_empty(), "old single file is read when no menu file exists")
	check(migrated.apply_texts(texts) and FileAccess.get_file_as_string(legacy) == legacy_text, "old file kept unchanged after saving")
	# Fichier illisible : défauts, aucun plantage.
	file = FileAccess.open(settings.file_path("video"), FileAccess.WRITE)
	file.store_string("{ pas du json")
	file.close()
	var damaged := Settings.new(fixture)
	check(not damaged.load_notice.is_empty() and damaged.values.fov == 75 and damaged.values.jump_height == 3, "unreadable menu file: its settings fall back to defaults, others kept")
	# Échelle des menus et FOV dans le jeu.
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(fixture + ".app.json")
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var item: Dictionary = app.catalog.create_world("Vue", "8")
	root.add_child(app)
	current_scene = app
	await process_frame
	check(app.play_button.custom_minimum_size.y == 40 and Settings.SPECS.element_scale.default == 100, "default zones and buttons size is 100 %")
	for scale in ["150", "50", "100"]:
		for size in [Vector2i(800, 450), Vector2i(1280, 720)]:
			root.size = size
			app.show_page("home")
			var width_before: float = app.menu_panel.custom_minimum_size.x
			apply(app, {"element_scale": scale})
			var factor: float = scale.to_float() / 100.0
			check(is_equal_approx(root.content_scale_factor, 1.0) and is_equal_approx(app.play_button.custom_minimum_size.y, 40 * factor) and app.pages.home.get_theme_constant("separation") == roundi(12 * factor), "zones, buttons and spaces follow %s %%" % scale)
			check(app.menu_root.theme.get_font_size("font_size", "Button") == roundi(20 * 13.0 / 18.0) and is_equal_approx(app.menu_root.theme.get_stylebox("normal", "Button").content_margin_left, 14 * factor), "text size unchanged, button padding scaled: %s %%" % scale)
			check(is_equal_approx(app.menu_root.theme.get_stylebox("panel", "PanelContainer").content_margin_left, 26 * factor), "margin between menu edge and text follows %s %%" % scale)
			await process_frame
			check(app.play_button.size.y >= app.play_button.get_theme_font("font").get_height(app.play_button.get_theme_font_size("font_size")), "text always fits its button: %s %%" % scale)
			apply(app, {"panel_size": "72"})
			app.show_page("home")
			check(is_equal_approx(app.menu_panel.custom_minimum_size.x, width_before), "menu width unchanged by zones size: %s %%" % scale)
			var ok := true
			for page_name in ["home", "settings", "worlds", "create", "information"]:
				app.show_page(page_name)
				await process_frame
				await process_frame
				var view: Vector2 = app.get_viewport().get_visible_rect().size
				var rect: Rect2 = app.menu_panel.get_global_rect()
				var inside: bool = rect.position.x >= -0.5 and rect.position.y >= -0.5 and rect.end.x <= view.x + 0.5 and rect.end.y <= view.y + 0.5
				if not inside:
					print("OVERFLOW: ", page_name, " ", rect, " in ", view)
				ok = ok and inside
			check(ok, "pages inside %dx%d at %s %%" % [size.x, size.y, scale])
	root.size = Vector2i(1280, 720)
	# Les textes prennent toute la largeur du menu : menu plus large, lignes plus longues.
	var widths := []
	for panel in ["50", "90"]:
		apply(app, {"panel_size": panel})
		app.show_page("information")
		await process_frame
		await process_frame
		widths.append(app.generation_info.size.x)
	check(widths[1] > widths[0] + 200, "texts widen with the menu")
	apply(app, {"panel_size": "72"})
	apply(app, {"fov": "100"})
	app.show_page("worlds")
	app.open_world(item.id)
	check(app.active_world.player.camera.fov == 100, "FOV applies in game, even in a default-mode world")
	app.return_to_worlds()
	apply(app, {"fov": "75"})
	app.open_world(item.id)
	check(app.active_world.player.camera.fov == 75, "default FOV is the original view")
	app.return_to_worlds()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "verification never captures pointer")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	var cleanup: Array = [fixture, legacy, fixture + ".worlds"]
	for base in [fixture, legacy, fixture + ".app.json"]:
		for menu in Settings.FILES:
			cleanup.append(base.get_basename() + "-" + Settings.FILES[menu])
	for path in cleanup:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d settings files/scale/FOV checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
