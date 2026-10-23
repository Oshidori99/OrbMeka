extends SceneTree
# 0.0.3.28 : « Aller au launcher » puis « Quitter le jeu » tout en bas de l'accueil ;
# page Launcher : Dernière version, versions groupées par 0.0.x avec leur nom.
# Sans GitHub ni téléchargement : la liste est donnée par le test.
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

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/launcher-test-%d" % Time.get_ticks_usec()
	Launcher.root = fixture
	# Groupes, noms tirés de l'historique, liste des Releases.
	check(Launcher.group_of("0.0.3.27") == "0.0.3" and Launcher.group_of("0.0.2.14.2") == "0.0.2" and Launcher.group_of("0.0.3") == "0.0.3", "versions grouped by 0.0.x")
	var names := Launcher.names_from_history("TITRE\n0.0.3.27 — Deux touches\r\nTexte — pas une version\n0.0.2.14.2 — Raccourcis\n")
	check(names == {"0.0.3.27": "Deux touches", "0.0.2.14.2": "Raccourcis"}, "names read from the history")
	var local := Launcher.names_from_history(FileAccess.get_file_as_string(Launcher.LOCAL_HISTORY))
	check(local.has(Launcher.current_version()) and local.has("0.0.2.6"), "the game's own history names every version")
	var current := Launcher.current_version()
	var list := Launcher.build_list(["v9.9.9.1", "v" + current, "v0.0.2.6"], local)
	check(list[0] == {"version": "9.9.9.1", "name": ""} and list[1].name == local[current], "Release tags become versions with names")
	# Installé : un .exe dans le dossier de la version (jamais le programme console).
	check(Launcher.executable("0.0.2.6").is_empty(), "not installed at first")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Launcher.folder("0.0.2.6")))
	for file_name in ["OrbMeka_console.exe", "OrbMeka.exe"]:
		FileAccess.open(Launcher.folder("0.0.2.6").path_join(file_name), FileAccess.WRITE).close()
	check(Launcher.executable("0.0.2.6").ends_with("/OrbMeka.exe"), "installed version found in its own folder")
	# Accueil : launcher puis Quitter, tout en bas.
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	app.settings = load("res://scripts/user_settings.gd").new(fixture + ".json")
	app.launcher_online = false
	root.add_child(app)
	current_scene = app
	await process_frame
	var buttons: Array = app.play_button.get_parent().get_children().filter(func(node): return node is Button)
	check(buttons.slice(-3) == [app.history_button, app.launcher_button, app.quit_button] and app.launcher_button.text == "Aller au launcher" and app.quit_button.text == "Quitter le jeu", "launcher just above Quitter, at the bottom of home")
	check(app.quit_button.visible, "Quitter shown outside a browser")
	# Page Launcher (0.0.3.29) : écran à part, versions jouées, gros Jouer vert et ▼.
	Launcher.note_played("0.0.2.6")
	for version in ["0.0.3.1", "0.0.3.2", "0.0.3.3", "0.0.3.4", "0.0.3.5", "0.0.2.6"]:
		Launcher.note_played(version)
	check(Launcher.played() == ["0.0.3.1", "0.0.3.2", "0.0.3.3", "0.0.3.4", "0.0.3.5", "0.0.2.6"], "played versions: no duplicate, latest last")
	Launcher.note_played("0.0.3.6")
	check(Launcher.played().size() == Launcher.PLAYED_MAX and Launcher.played()[0] == "0.0.3.2" and Launcher.played()[-1] == "0.0.3.6", "at most six played versions kept")
	app.launcher.versions = list
	app.open_launcher(false)
	check(app.page == "launcher" and app.get_viewport().gui_get_focus_owner() == app.launcher_latest_button and not app.launcher_latest_button.disabled, "launcher page opens on the big Jouer")
	check(app.launcher_screen.visible and app.get_window().title == "OrbMeka — Launcher" and app.menu_panel.has_theme_stylebox_override("panel"), "launcher looks outside the game")
	check(app.launcher_latest_button.theme_type_variation == "OrbLaunch" and app.launcher_arrow_button.theme_type_variation == "OrbLaunch" and app.launcher_arrow_button.text == "▼", "Jouer and ▼ are the green buttons")
	check(app.launcher_latest_button.text.begins_with("▶ Jouer — 9.9.9.1"), "Jouer is always the latest version")
	var page_items: Array = app.launcher_latest_button.get_parent().get_parent().get_children()
	check(page_items.find(app.launcher_played) < page_items.find(app.launcher_latest_button.get_parent()) and page_items.find(app.launcher_latest_button.get_parent()) < page_items.find(app.launcher_scroll), "played versions above, all versions below Jouer")
	var played_rows: Array = app.launcher_played.get_children().map(func(row): return row.get_child(0).text.get_slice(" ", 0))
	var expected_played: Array = Launcher.played()
	check(played_rows == expected_played and played_rows[-1] == (current if Launcher.supported() else "0.0.3.6"), "played versions shown, last played at the bottom")
	check(not app.launcher_scroll.visible, "all versions folded at first")
	app.launcher_arrow_button.pressed.emit()
	check(app.launcher_scroll.visible and app.launcher_arrow_button.button_pressed, "▼ unfolds every version")
	var headings: Array = app.launcher_list.get_children().filter(func(node): return node is RichTextLabel).map(func(node): return node.text)
	check(headings == ["0.0.2", "0.0.3", "9.9.9"], "one heading per 0.0.x group, latest at the bottom")
	var rows: Array = app.launcher_list.get_children().filter(func(node): return node is HBoxContainer)
	check(rows.size() == 3 and rows[-1].get_child(1) == app.launcher_play_buttons["9.9.9.1"] and app.launcher_list.get_children().any(func(node): return not node is HBoxContainer and not node is RichTextLabel), "rows spaced between groups, latest version last")
	app.launcher_arrow_button.pressed.emit()
	check(not app.launcher_scroll.visible, "▼ again folds the list")
	var row_text: String = app.launcher_play_buttons[current].get_parent().get_child(0).text
	check(row_text == current + " — " + local[current], "each row shows the version and its name")
	if Launcher.supported():
		check(app.launcher_play_buttons[current].text == "Ouverte" and app.launcher_play_buttons["0.0.2.6"].text == "Jouer" and app.launcher_play_buttons["9.9.9.1"].text == "Installer et jouer", "open, installed and missing versions told apart")
	else:
		check(app.launcher_play_buttons["0.0.2.6"].disabled and app.launcher_status.text.contains("Windows"), "outside Windows: shown, but cannot play")
	# La version ouverte : retour à l'accueil ; Échap aussi.
	app.launcher_play_buttons[current].pressed.emit()
	check(app.page == "home", "playing the open version goes back to home")
	app.launcher_button.pressed.emit()
	await process_frame
	check(app.page == "launcher", "home button opens the launcher")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	check(app.page == "home", "Escape goes back to home")
	if app.launcher_thread != null:
		app.launcher_thread.wait_to_finish()
		app.launcher_thread = null
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "verification never captures pointer")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for path in [Launcher.played_path(), Launcher.folder("0.0.2.6").path_join("OrbMeka.exe"), Launcher.folder("0.0.2.6").path_join("OrbMeka_console.exe"), Launcher.folder("0.0.2.6"), fixture, fixture + ".worlds"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d launcher checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
