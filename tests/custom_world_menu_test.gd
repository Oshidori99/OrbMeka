extends SceneTree
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Store = preload("res://scripts/world_store.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280,720)
	var path := "res://.godot/custom-menu-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(path.get_basename()+"-settings.json")
	app.settings.values.grass_density = "low"
	app.settings.values.view_distance = 1
	app.catalog = Catalog.new(path)
	root.add_child(app)
	app.show_page("create")
	app.name_field.text = "Personnalisé"
	app.seed_field.text = "123"
	app.custom_world_button.pressed.emit()
	check(app.page == "custom_world" and app.custom_sliders.size() == 14, "custom menu offers fourteen generation sliders (long lakes and clay since 0.0.5.20)")
	for size in [Vector2i(1280,720),Vector2i(800,600)]:
		root.size = size
		app.fit_menus_to_window()
		await process_frame
		await process_frame
		var bounds: Rect2 = app.menu_panel.get_global_rect()
		var view: Vector2 = root.get_visible_rect().size
		check(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= view.x+1 and bounds.end.y <= view.y+1, "custom menu stays inside window %s : %s" % [str(size),str(bounds)])
	root.size = Vector2i(1280,720)
	var slider: HSlider = app.custom_sliders.small_deserts
	check(slider.get_parent().get_child(1).size.x > 20 and slider.get_parent().get_child(3).size.x > 15, "frequency endpoint labels are visible")
	check(app.custom_draft.small_deserts == 133 and int(slider.value) == 268, "slider starts at the standard 1/133 chance per zone")
	check(app.custom_labels.small_deserts.text.contains("Valeur par défaut : 1 chance sur 133 par zone") and app.custom_labels.small_deserts.text.contains("% du sol"), "default and estimated share of the ground shown")
	slider.value = 1
	check(app.custom_draft.small_deserts == 400 and app.custom_labels.small_deserts.text.contains("400"), "left endpoint is 1/400")
	slider.value = 400
	check(app.custom_draft.small_deserts == 1 and app.custom_labels.small_deserts.text.begins_with("Dans chaque zone"), "right endpoint is 1/1")
	app.reset_custom_option("small_deserts")
	check(app.custom_draft.small_deserts == 133 and int(slider.value) == 268, "per-slider reset restores the standard value")
	check(not app.custom_sliders.deep_holes.editable and app.custom_labels.deep_holes.text.contains("jamais dans le monde standard"), "absent category has no invented active frequency")
	app.custom_enabled.deep_holes.button_pressed = true
	check(app.custom_sliders.deep_holes.editable and app.custom_draft.deep_holes == 400, "absent category can be enabled at 1/400")
	app.reset_custom_option("deep_holes")
	check(app.custom_draft.deep_holes == 0 and not app.custom_sliders.deep_holes.editable, "reset disables a category absent from the standard world")
	slider.value = 370
	check(app.custom_draft.small_deserts == 31, "slider supports every intermediate integer")
	app.custom_apply_button.pressed.emit()
	check(app.page == "create" and app.name_field.text == "Personnalisé" and app.seed_field.text == "123", "applying preserves name and seed")
	check(app.custom_generation.small_deserts == 31, "applying retains chosen settings")
	app.open_custom_world()
	slider.value = 400
	app._cancel_page()
	check(app.page == "create" and app.custom_generation.small_deserts == 31, "Escape cancels draft without discarding applied options")
	check(app.GENERAL_CATEGORIES.video.Jeu.keys.has("grass_zones") and app.GENERAL_CATEGORIES.video.Jeu.keys.has("view_distance"), "grass and view distances are under Video / Jeu")
	check(Settings.SPECS.grass_zones.default == 4 and Settings.SPECS.grass_zones.unit == "zones de 8 m" and Settings.SPECS.view_distance.default == 8 and Settings.SPECS.view_distance.max == 32, "grass distance in zones (4); view distance 8, from 1 to 32")
	app.create_named_world()
	var world: Node3D = app.active_world
	check(app.page == "playing" and world.generation_options == app.custom_generation, "creation supplies chosen generation to the actual world")
	check(world.grass_distance == 32, "actual world receives the grass distance (4 zones = 32 m)")
	app.setting_sliders.grass_zones.value = 6
	check(Settings.new(path.get_basename()+"-settings.json").values.grass_zones == 6, "grass distance saved through the real video slider")
	var patches := world.find_children("GrassDetail","MultiMeshInstance3D",true,false)
	check(not patches.is_empty() and patches.all(func(patch): return patch.visibility_range_end == 48), "grass distance changes actual patch culling")
	# FPS : lecture directe de la mesure moteur existante, aucune modification d'apparence.
	world._update_fps(0.5)
	check(world.fps_label.text == "FPS : %d" % Engine.get_frames_per_second(), "FPS display uses current engine measurement")
	app.return_to_worlds()
	root.remove_child(app)
	var settings_path: String = app.settings.storage_path
	var settings_files: Array = []
	for menu in Settings.FILES:
		settings_files.append(app.settings.file_path(menu))
	app.free()
	for file in settings_files:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	Store.delete_folder(path.get_basename()+"-mondes")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "headless menu verification never captures mouse")
	print("RESULT: %d custom menu checks, %d failures" % [checks,failures])
	quit(failures)
