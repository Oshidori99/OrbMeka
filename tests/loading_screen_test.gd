extends SceneTree
# 0.0.7.23 : écran de chargement d'un monde (graine préparée par étapes, barre), puis le monde, le même qu'ouvert d'un coup.
const Generation = preload("res://scripts/world_generation.gd")
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
	var fixture := "res://.godot/loading-test-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = load("res://scripts/user_settings.gd").new(fixture)
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	await process_frame
	var item: Dictionary = app.catalog.create_world("Chargement", "1864659616", "default", false, Generation.defaults())
	app.open_world_loading(item.id)
	check(app.page == "loading" and app.pages.loading.visible and not is_instance_valid(app.active_world), "opening from the menus: loading screen first")
	var values := []
	var frames := 0
	var behind := false
	while not (is_instance_valid(app.active_world) and app.page == "playing") and frames < 3000:
		await process_frame
		frames += 1
		values.append(app.loading_bar.value)
		behind = behind or (is_instance_valid(app.active_world) and app.page == "loading" and app.launcher_screen.visible)
	check(is_instance_valid(app.active_world) and app.page == "playing", "then the world opens (%d images)" % frames)
	check(behind and not app.showcase.is_inside_tree(), "0.0.7.24: the world gets ready behind the loading screen (columns, trees, shaders), home 3D removed")
	var here: Vector2i = app.active_world._player_column()
	var around := true
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			around = around and (app.active_world.built_columns.has(here + Vector2i(dx, dz)) or not app.active_world.shown_columns.has(here + Vector2i(dx, dz)))
	check(around and not app.active_world.behind_loading, "shown once the 9 columns around are built")
	var growing := values.size() > 3
	for index in range(1, values.size()):
		growing = growing and values[index] >= values[index - 1]
	check(growing and values.max() >= 100.0 and values.filter(func(value): return value > 0.0 and value < 100.0).size() >= 3, "the bar moves forward to 100 %")
	var whole = load("res://scripts/smooth_terrain.gd").new()
	whole.setup(int(item.seed), app.active_world.flat_spots(), Generation.defaults())
	check(str(app.active_world.terrain.rivers()) == str(whole.rivers()) and app.active_world.terrain.height_at(37.5, -120.0) == whole.height_at(37.5, -120.0), "the same world as opened at once (rivers, heights)")
	app.return_to_worlds()
	print("RESULT: %d loading checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
