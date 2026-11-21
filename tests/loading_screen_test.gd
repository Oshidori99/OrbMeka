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
	# 0.0.7.34 (demande de l'utilisateur : long après 81 %) : sur PC, montré dès que les colonnes proches (9 × 9) sont faites,
	# le reste de la vue se construit en jouant ; deux fois plus de travail par image derrière l'écran.
	var w: Node = app.active_world
	var near_built := true
	for column: Vector2i in w.shown_columns:
		if w._ring(column) <= w.NEAR_REVEAL_ZONES and not w.built_columns.has(column):
			near_built = false
	check(near_built and w.opening_progress(true) >= 1.0, "PC: the 9 × 9 columns around are built when the world is shown (%d of %d columns built)" % [w.built_columns.size(), w.shown_columns.size()])
	check(w.LOADING_WORK_PC_USEC == 2 * w.LOADING_WORK_USEC and app.LOADING_STEP_PC_USEC > app.LOADING_STEP_USEC, "PC: twice the work per image behind the loading screen (the Web keeps 40 ms)")
	# 0.0.7.34 (signalé : sur le Web, une personne ne pouvait appuyer sur aucune touche) : message « Cliquez dans le jeu »
	# quand la souris n'est pas capturée (jamais sans fenêtre), et le clic donne le clavier au jeu sur itch.io.
	check(app.click_hint != null and not app.click_hint.visible and app.click_hint.text.begins_with("Cliquez dans le jeu"), "a « Cliquez dans le jeu » message exists (hidden without a window)")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	check(presets.contains("window.focus()") and presets.contains("canvas.focus()"), "Web export: a click in the game gives it the keyboard (itch.io frame)")
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
