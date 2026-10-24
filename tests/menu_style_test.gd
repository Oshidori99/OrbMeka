extends SceneTree
# 0.0.2.12-0.0.2.13 : thème commun, fond 3D « vitrine » de l'accueil, pause semi-transparente,
# point de vue posé sur une tour, boutons-icônes, menus larges.
const MenuShowcase = preload("res://scripts/menu_showcase.gd")
const CharacterPreview = preload("res://scripts/character_preview.gd")
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

func _inside(rect: Rect2, view: Rect2) -> bool:
	return view.grow(1).encloses(rect)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	# Réglages par défaut isolés : jamais ceux du joueur (user://settings.json).
	app.settings = load("res://scripts/user_settings.gd").new("res://.godot/test-default-settings.json")
	app.catalog = load("res://scripts/world_catalog.gd").new("res://.godot/style-test-unused.json")
	app.catalog.worlds.append({"id": "style-test", "name": "Mon monde", "seed": 123})
	root.add_child(app)
	current_scene = app
	await process_frame
	# Thème commun.
	check(app.menu_root.theme != null and app.shortcut_hints is Label and app.shortcut_hints.text.begins_with("F1 : Retour aux mondes
F2 : Comment jouer
F3 : "), "menus share one theme; in-game shortcuts F1, F2, F3 are plain text")
	var alpha: float = app.menu_panel.get_theme_stylebox("panel").bg_color.a
	check(alpha > 0.4 and alpha < 0.75, "menu panel is see-through but readable")
	for key in app.pages:
		var title: RichTextLabel = app.pages[key].get_child(0)
		check(title.theme_type_variation == "OrbTitle", "page title uses common style: " + key)
	check(not app.play_button.has_theme_font_size_override("font_size"), "buttons take their size from the theme")
	# Fond 3D de l'accueil.
	var showcase: Node3D = app.showcase
	check(showcase.is_inside_tree() and showcase.camera.is_current(), "home shows the 3D showcase with its own camera")
	check(showcase.find_children("*", "MultiMeshInstance3D", true, false).size() >= 3, "showcase shows the game's flat lawn (0.0.5.5)")
	# 0.0.3.23 : trois nouveautés (trop de personnages pour les montrer tous) ; 0.0.3.25 : elles courent.
	check(showcase.runners.size() >= 2 and showcase.runners.size() <= 3 and showcase.runner_ids.all(func(id): return CharacterPreview.CHARACTERS.has(id)), "showcase shows 2 or 3 characters of the menu")
	check(showcase.runner_ids == ["girl9", "fox", "rabbit"] and showcase.runners.all(func(runner): return not runner.find_children("*", "MeshInstance3D", true, false).is_empty()), "new characters run with their Blender models")
	var start_x: float = showcase.runners[0].position.x
	showcase._process(0.4)
	check(not is_equal_approx(showcase.runners[0].position.x, start_x), "characters run")
	check(app.news_label.text == MenuShowcase.NEWS_TEXT and app.news_label.is_visible_in_tree(), "home shows the version news")
	check(MenuShowcase.NEWS_VERSION == ProjectSettings.get_setting("application/config/version"), "showcase news matches project version")
	var start_basis: Basis = showcase.camera.basis
	var start_position: Vector3 = showcase.camera.position
	showcase._process(3.0)
	check(not showcase.camera.basis.is_equal_approx(start_basis), "showcase camera turns slowly")
	check(showcase.camera.position.is_equal_approx(start_position), "showcase viewpoint stays in place (no flying)")
	var feet: float = showcase.camera.position.y - showcase.EYE_HEIGHT
	check(is_equal_approx(feet, 0.0), "viewpoint stands on the flat ground (no tower since 0.0.5.5)")
	check(showcase.find_children("*", "MeshInstance3D", true, false).filter(func(mesh): return mesh.material_override is BaseMaterial3D and mesh.material_override.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED).is_empty(), "showcase shows no glass (not in the game yet)")
	# Boutons-icônes de Mes mondes.
	for button in [app.new_world_button, app.rename_button, app.duplicate_button, app.world_settings_button, app.delete_button]:
		check(button.text.length() <= 2 and not button.tooltip_text.is_empty(), "icon button with tooltip: " + button.tooltip_text)
	check(app.delete_button.tooltip_text == "Supprimer" and app.rename_button.tooltip_text == "Renommer", "icons keep their action names")
	# Vitrine : vols au-dessus de l'herbe libre devant la place (0.0.4.5 : de haut en bas), sans toucher place, colline ni tour, tournées vers où elles vont.
	var in_lane := true
	var turned := {}
	var heights := []
	for step in range(80):
		var before: Array = showcase.runners.map(func(runner): return runner.position.x)
		showcase._process(0.05)
		for index in range(showcase.runners.size()):
			var runner: Node3D = showcase.runners[index]
			heights.append(runner.position.y)
			in_lane = in_lane and runner.position.y >= showcase.FLY_LOW - 0.01 and runner.position.y <= showcase.FLY_HIGH + 0.01 and runner.position.x >= 5.0 and runner.position.x <= 11.0 and runner.position.z > 5.0 and runner.position.z < 8.0
			var moved: float = runner.position.x - before[index]
			# Hors des demi-tours (une image peut aller au bout puis revenir).
			var far_from_ends: bool = minf(runner.position.x, before[index]) > showcase.RUN_FROM + 0.25 and maxf(runner.position.x, before[index]) < showcase.RUN_TO - 0.25
			if far_from_ends and absf(moved) > 0.01:
				# Le modèle regarde vers +Z : rotation de +90° = vers +X.
				turned[signf(moved) == signf(sin(runner.rotation.y))] = true
	check(in_lane, "fliers stay above the free grass lane, between low and high")
	check(heights.min() < 1.2 and heights.max() > 3.0, "fliers go up and down")
	check(turned.has(true) and not turned.has(false), "runners face where they run")
	check(app.backdrop.material.get_shader_parameter("blur") == 0.0, "home backdrop keeps the 3D scene sharp")
	# Pause semi-transparente.
	app.open_world("style-test")
	check(not showcase.is_inside_tree() and app.active_world.player.camera.is_current(), "world replaces the showcase while playing")
	app.pause_game()
	await process_frame
	check(app.menu_root.visible and app.backdrop.material.get_shader_parameter("blur") > 0.0, "pause blurs the world behind")
	var tint: Color = app.backdrop.material.get_shader_parameter("tint")
	check(tint.a > 0.2 and tint.a < 0.8, "pause darkens the world without hiding it")
	app.return_to_worlds()
	await process_frame
	check(showcase.is_inside_tree() and showcase.camera.is_current(), "showcase returns with the world list")
	# Toutes tailles de fenêtre.
	for window_size in [Vector2i(800, 450), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(800, 900)]:
		root.size = window_size
		for page_name in ["home", "worlds", "create", "settings", "information", "history"]:
			app.show_page(page_name)
			await process_frame
			await process_frame
			var view: Rect2 = root.get_visible_rect()
			check(_inside(app.menu_panel.get_global_rect(), view), "%s fits at %dx%d" % [page_name, window_size.x, window_size.y])
	root.remove_child(app)
	app.queue_free()
	await process_frame
	print("RESULT: %d style checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
