extends SceneTree
# 0.0.4.16 : launcher sur toute la hauteur, Jouer tout en bas, liste ▼ au-dessus (6 versions au plus,
# rien de coupé, même en ouvrant et fermant souvent) ; traits fins entre les lignes des menus ;
# Voler en sous-catégories repliables ; moins d'espace entre lignes, plus entre catégories.
const Settings = preload("res://scripts/user_settings.gd")
const Launcher = preload("res://scripts/launcher.gd")
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

func settle() -> void:
	for index in range(4):
		await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/layout-lines-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(fixture)
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	app.launcher_online = false
	root.add_child(app)
	current_scene = app
	await process_frame
	# Launcher : 40 versions, comme sur GitHub.
	var versions := []
	for index in range(40):
		versions.append({"version": "0.0.%d.%d" % [2 + index / 20, 39 - index], "name": "Version %d" % index})
	app.launcher.versions = versions
	app.open_launcher(false)
	await settle()
	var window_height: float = root.get_visible_rect().size.y
	var play_row: Control = app.launcher_latest_button.get_parent()
	var play_bottom: float = play_row.get_global_rect().end.y
	check(play_bottom > window_height - 80.0 and play_bottom <= window_height, "Jouer at the bottom of the window (%.0f of %.0f)" % [play_bottom, window_height])
	for round in range(6):
		app.launcher_arrow_button.pressed.emit()
		await settle()
		var open: bool = app.launcher_scroll.visible
		var bottom: float = play_row.get_global_rect().end.y
		var top: float = app.launcher_back_button.get_global_rect().position.y
		check(bottom <= window_height + 0.5 and top >= -0.5 and app.menu_scroll.get_v_scroll_bar().max_value <= app.menu_scroll.size.y + 1.0, "round %d (%s): everything fits, nothing cut" % [round, "open" if open else "closed"])
		if open:
			check(app.launcher_scroll.get_global_rect().end.y <= play_row.get_global_rect().position.y + 0.5, "list just above Jouer")
			var rows: Array = app.launcher_list.get_children().filter(func(node): return node is HBoxContainer)
			var row_height: float = rows[0].size.y
			check(app.launcher_scroll.size.y <= row_height * 6.0 + 6.0 * 6.0 + 1.0 and app.launcher_scroll.size.y >= row_height * 2.0, "about six versions visible at once (%.0f px)" % app.launcher_scroll.size.y)
	# Petite fenêtre : toujours rien de coupé.
	root.size = Vector2i(1280, 600)
	app.fit_menus_to_window()
	await settle()
	if not app.launcher_scroll.visible:
		app.launcher_arrow_button.pressed.emit()
		await settle()
	check(play_row.get_global_rect().end.y <= root.get_visible_rect().size.y + 0.5, "small window: Jouer still visible (%.0f of %.0f, list %.0f, played %s)" % [play_row.get_global_rect().end.y, root.get_visible_rect().size.y, app.launcher_scroll.size.y, str(app.launcher_played.visible)])
	root.size = Vector2i(1280, 720)
	app.show_page("home")
	await settle()
	# Traits entre les lignes.
	app.show_page("settings")
	await settle()
	var walk_body: Node = app.setting_fields.walk_side.get_parent().get_parent()
	var lines: Array = walk_body.get_children().filter(func(node): return node is HSeparator)
	check(lines.size() == 2 and lines.all(func(line): return line.theme_type_variation == "OrbRowLine"), "a thin line between each Marche row")
	check(app.control_buttons.move_back.get_parent().get_index() > 0 and app.control_buttons.move_back.get_parent().get_parent().get_child(app.control_buttons.move_back.get_parent().get_index() - 1) is HSeparator, "lines between Contrôles rows")
	var style: StyleBoxLine = app.menu_root.theme.get_stylebox("separator", "OrbRowLine")
	check(style.color.a > 0.1 and style.color.a < 0.4 and style.thickness == 1, "line discreet but visible")
	# Espacements.
	check(walk_body.get_theme_constant("separation") < 10 and app.CATEGORY_GAP > 22.0, "less space between rows, more between categories")
	# Voler en sous-catégories.
	check(app.ATTRIBUTE_CATEGORIES.Voler.groups.keys() == ["Normal", "Rapide", "Monter et descendre"], "Voler: Normal, Rapide, Monter et descendre")
	for key in ["sub:Voler/Normal", "sub:Voler/Rapide", "sub:Voler/Monter et descendre"]:
		check(app.fold_entries.has(key), "sub-title can fold: " + key)
	var rapid: Dictionary = app.fold_entries["sub:Voler/Rapide"]
	check(rapid.title.theme_type_variation == "OrbSubsection" and rapid.body.is_ancestor_of(app.setting_fields.fly_run_forward), "Rapide holds the fast flight speeds")
	app.settings_tabs.attributes.pressed.emit()
	app.toggle_fold("sub:Voler/Rapide")
	check(not app.setting_fields.fly_run_forward.is_visible_in_tree() and app.setting_fields.fly_forward.is_visible_in_tree(), "folding Rapide keeps Normal shown")
	app.toggle_fold("sub:Voler/Rapide")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d layout checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
