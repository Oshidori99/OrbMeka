extends SceneTree
# 0.0.2.12 : thème commun, fond 3D « vitrine » de l'accueil, pause semi-transparente.
const MenuShowcase = preload("res://scripts/menu_showcase.gd")
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
	app.catalog = load("res://scripts/world_catalog.gd").new("res://.godot/style-test-unused.json")
	app.catalog.worlds.append({"id": "style-test", "name": "Mon monde", "seed": 123})
	root.add_child(app)
	current_scene = app
	await process_frame
	# Thème commun.
	check(app.menu_root.theme != null and app.return_button.theme == app.menu_root.theme, "menus and return button share one theme")
	check(app.menu_panel.get_theme_stylebox("panel").bg_color.a < 1.0, "menu panel is slightly transparent")
	for key in app.pages:
		var title: Label = app.pages[key].get_child(0)
		check(title.theme_type_variation == "OrbTitle", "page title uses common style: " + key)
	check(not app.play_button.has_theme_font_size_override("font_size"), "buttons take their size from the theme")
	# Fond 3D de l'accueil.
	var showcase: Node3D = app.showcase
	check(showcase.is_inside_tree() and showcase.camera.is_current(), "home shows the 3D showcase with its own camera")
	check(showcase.find_children("*", "MultiMeshInstance3D", true, false).size() >= 3, "showcase is built from block meshes in code")
	check(app.news_label.text == MenuShowcase.NEWS_TEXT and app.news_label.is_visible_in_tree(), "home shows the version news")
	check(MenuShowcase.NEWS_VERSION == ProjectSettings.get_setting("application/config/version"), "showcase news matches project version")
	var start_position: Vector3 = showcase.camera.position
	showcase._process(3.0)
	check(not showcase.camera.position.is_equal_approx(start_position), "showcase camera turns slowly")
	var widths := {}
	for step in range(40):
		showcase._process(0.25)
		widths[showcase.frame_width] = true
	check(widths.size() >= 3, "showcase window frame resizes step by step")
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
