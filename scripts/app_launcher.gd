extends "res://scripts/app_controls.gd"
# Menus du jeu, partie 3 sur 5 : le launcher (versions, installation, lancement, suppression).

# Launcher (0.0.4) : versions des Releases GitHub, groupées par 0.0.x, avec leur nom.
# refresh = false : garder la liste déjà connue (tests, sans GitHub).
func open_launcher(refresh := true) -> void:
	if is_instance_valid(active_world):
		return
	show_page("launcher")
	show_all_versions(false)
	# La version ouverte compte comme jouée (en bas de la liste des dernières versions jouées).
	if Launcher.supported():
		Launcher.note_played(Launcher.current_version())
	if not Launcher.supported():
		launcher_status.text = "Le launcher fonctionne seulement dans la version Windows."
	elif refresh and launcher_online and launcher_thread == null:
		launcher_status.text = "Recherche des versions…"
		_launcher_work(func(): return launcher.refresh(), func(_ok): fill_launcher())
		return
	fill_launcher()

func fill_launcher() -> void:
	_clear_launcher_rows(launcher_list)
	_clear_launcher_rows(launcher_played)
	launcher_play_buttons.clear()
	launcher_remove_buttons.clear()
	launcher_played_buttons.clear()
	var current := Launcher.current_version()
	var busy := launcher_thread != null or launcher_child != -1
	if not launcher.error.is_empty():
		launcher_status.text = launcher.error
	elif Launcher.supported() and not busy:
		launcher_status.text = "Version ouverte : %s. Les versions sont installées dans les données du jeu (AppData)." % current
	var names := {}
	for item in launcher.versions:
		names[item.version] = item.name
	# Dernières versions jouées : la plus récente en bas.
	var played := Launcher.played()
	launcher_played_title.visible = not played.is_empty()
	fit_menus_to_window()
	for version in played:
		launcher_played_buttons[version] = _launcher_row(launcher_played, version, names.get(version, ""), busy)
	# Gros bouton : toujours la dernière version.
	launcher_latest_button.disabled = launcher.versions.is_empty() or busy
	launcher_arrow_button.disabled = launcher.versions.is_empty()
	if launcher.versions.is_empty():
		launcher_latest_button.text = "▶ Jouer"
	else:
		var latest: Dictionary = launcher.versions[0]
		launcher_latest_button.text = "▶ Jouer — " + latest.version + (" · " + latest.name if not latest.name.is_empty() else "")
	# Toutes les versions (▼), de la plus ancienne à la dernière, tout en bas ; groupes 0.0.x espacés.
	var group := ""
	for index in range(launcher.versions.size() - 1, -1, -1):
		var item: Dictionary = launcher.versions[index]
		if Launcher.group_of(item.version) != group:
			group = Launcher.group_of(item.version)
			if launcher_list.get_child_count() > 0:
				var gap := Control.new()
				_min_size(gap, Vector2(0, CATEGORY_GAP))
				launcher_list.add_child(gap)
			var heading := _text_label()
			heading.text = group
			heading.theme_type_variation = "OrbSection"
			launcher_list.add_child(heading)
		launcher_play_buttons[item.version] = _launcher_row(launcher_list, item.version, item.name, busy)
	if launcher_scroll.visible:
		_scroll_launcher_to_latest()

# Ligne « 0.0.3.27 — Nom » et son bouton (Ouverte, Jouer ou Installer et jouer).
func _launcher_row(parent: Node, version: String, version_name: String, busy: bool) -> Button:
	_row_line(parent)
	var row := HBoxContainer.new()
	_sep(row, 10)
	parent.add_child(row)
	var label := _text_label()
	label.text = version + (" — " + version_name if not version_name.is_empty() else "")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var text := "Ouverte" if version == Launcher.current_version() else ("Jouer" if not Launcher.executable(version).is_empty() else "Installer et jouer")
	var button := _button(text, row, func(): play_version(version))
	button.theme_type_variation = "OrbLauncherButton"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 0.0.4.16 : lignes plus basses, pour voir plus de versions.
	_min_size(button, Vector2(170, 30))
	button.disabled = busy or not Launcher.supported()
	# 0.0.4.21 : une version installée (sauf celle ouverte) peut être supprimée, pour la place.
	if version != Launcher.current_version() and not Launcher.executable(version).is_empty():
		var remove := _button("Supprimer", row, func(): remove_installed_version(version))
		remove.theme_type_variation = "OrbFold"
		remove.tooltip_text = "Supprimer cette version de l'ordinateur (environ 100 Mo) ; elle peut être réinstallée"
		remove.disabled = busy
		launcher_remove_buttons[version] = remove
	return button

func _clear_launcher_rows(container: Node) -> void:
	for child in container.get_children():
		for node in [child] + child.find_children("*", "Control", true, false):
			scaled_sizes.erase(node)
			scaled_separations.erase(node)
			font_sizes.erase(node)
		container.remove_child(child)
		child.queue_free()

# ▼ : déplie (ou replie) toutes les versions sous le bouton Jouer, la dernière visible en bas.
func show_all_versions(open: bool) -> void:
	launcher_arrow_button.set_pressed_no_signal(open)
	launcher_scroll.visible = open
	_queue_fit()
	if open:
		_scroll_launcher_to_latest()

func _scroll_launcher_to_latest() -> void:
	(func():
		await get_tree().process_frame
		launcher_scroll.scroll_vertical = int(launcher_scroll.get_v_scroll_bar().max_value)).call()

func play_latest_version() -> void:
	if not launcher.versions.is_empty():
		play_version(launcher.versions[0].version)

# La version ouverte : retour à l'accueil. Une autre : installée au besoin, puis lancée ;
# cette fenêtre se réduit et revient quand l'autre version est fermée.
func remove_installed_version(version: String) -> void:
	if launcher_thread != null or launcher_child != -1:
		return
	var removed := Launcher.remove_version(version)
	fill_launcher()
	launcher_status.text = ("Version %s supprimée de l'ordinateur." if removed else "Impossible de supprimer la version %s.") % version

func play_version(version: String) -> void:
	if version == Launcher.current_version():
		show_page("home")
		return
	if launcher_thread != null or launcher_child != -1 or not Launcher.supported():
		return
	if Launcher.executable(version).is_empty():
		launcher_status.text = "Téléchargement de %s…" % version
		_launcher_work(func(): return launcher.install(version), func(ok): _start_version(version) if ok else fill_launcher())
		fill_launcher()
		return
	_start_version(version)

func _start_version(version: String) -> void:
	var pid := Launcher.launch(version)
	if pid == -1:
		launcher_status.text = "Impossible de lancer la version %s." % version
		fill_launcher()
		return
	Launcher.note_played(version)
	# 0.0.4.21 : seules les versions jouées récemment restent installées.
	Launcher.cleanup(version)
	launcher_child = pid
	launcher_status.text = "Version %s ouverte : fermez-la pour revenir ici." % version
	fill_launcher()
	launcher_window_mode = get_window().mode
	get_window().mode = Window.MODE_MINIMIZED

# Travail long (gh, décompression) dans un fil à part ; done(résultat) ensuite, ici.
func _launcher_work(work: Callable, done: Callable) -> void:
	launcher_thread = Thread.new()
	launcher_thread.start(func():
		var ok: bool = work.call()
		call_deferred("_launcher_finished", done, ok))

func _launcher_finished(done: Callable, ok: bool) -> void:
	launcher_thread.wait_to_finish()
	launcher_thread = null
	done.call(ok)
