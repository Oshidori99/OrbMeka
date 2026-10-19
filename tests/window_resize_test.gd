extends SceneTree
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
	app.catalog = load("res://scripts/world_catalog.gd").new("res://.godot/resize-test-unused.json")
	app.catalog.worlds.append({"id": "resize-test", "name": "Mon monde", "seed": 123})
	root.add_child(app)
	current_scene = app
	check(ProjectSettings.get_setting("display/window/size/resizable") and not root.borderless and not root.unresizable and ProjectSettings.get_setting("display/window/size/mode") == DisplayServer.WINDOW_MODE_WINDOWED, "window stays resizable, framed and not fullscreen")
	check(root.min_size == Vector2i(800, 450), "window has a usable minimum size")
	check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items" and ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "stretch adapts content to any window size")
	for window_size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(800, 900), Vector2i(2560, 1080)]:
		root.size = window_size
		await process_frame
		await process_frame
		var view: Rect2 = root.get_visible_rect()
		var tag := " at %dx%d" % [window_size.x, window_size.y]
		print("visible rect", tag, ": ", view)
		check(app.menu_root.get_global_rect().is_equal_approx(view), "menu background fills window" + tag)
		var panel: Control = app.pages.home.get_parent().get_parent()
		check(_inside(panel.get_global_rect(), view), "menu panel stays inside window" + tag)
		check(panel.get_global_rect().get_center().distance_to(view.get_center()) < 2, "menu panel stays centred" + tag)
		# Accueil compact ; pages de contenu larges (0.0.2.13).
		var expected_width := minf(560.0 * maxf(1.0, view.size.x / 1280.0), view.size.x * 0.7)
		check(absf(panel.size.x - expected_width) < 2, "menu panel width follows window width" + tag)
		check(is_equal_approx(app.history_scroll.custom_minimum_size.y, maxf(140.0, view.size.y - 300.0)), "scroll areas fill free window height" + tag)
		for page_name in ["history", "settings", "worlds"]:
			app.show_page(page_name)
			await process_frame
			check(_inside(panel.get_global_rect(), view), page_name + " page fits in window" + tag)
			check(absf(panel.size.x - clampf(view.size.x * 0.72, 560.0, view.size.x * 0.92)) < 2, page_name + " page uses a wide panel" + tag)
		app.show_page("home")
	root.size = Vector2i(1280, 720)
	app.open_world("resize-test")
	var world: Node3D = app.active_world
	for window_size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(2560, 1080)]:
		root.size = window_size
		await process_frame
		await process_frame
		var view: Rect2 = root.get_visible_rect()
		var tag := " at %dx%d" % [window_size.x, window_size.y]
		var crosshair: Control = world.find_child("Crosshair", true, false)
		check(crosshair != null and crosshair.get_global_rect().get_center().distance_to(view.get_center()) < 4, "crosshair centred" + tag)
		check(_inside(world.hint.get_global_rect(), view) and world.hint.get_global_rect().end.y > view.end.y - 80, "hint stays at bottom" + tag)
		check(_inside(world.selected_block_label.get_global_rect(), view), "selected block label visible" + tag)
		check(app.shortcut_hints.visible and _inside(app.shortcut_hints.get_global_rect(), view) and app.shortcut_hints.get_global_rect().end.x > view.end.x - 40, "shortcut hints stay top right" + tag)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
