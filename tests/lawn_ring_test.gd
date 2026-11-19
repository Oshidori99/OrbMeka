extends SceneTree
# 0.0.7.28 : l'herbe et les plantes viennent sur toutes les colonnes construites en se déplaçant ou après l'ouverture
# (en 0.0.7.25 à 0.0.7.27, la file des détails était vidée par _show_column_objects : herbe seulement sur les 9 colonnes
# du milieu ; signalé par l'utilisateur).
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

func _bare(world, column: Vector2i) -> bool:
	return world.TerrainMaterials.lawn_points(column, world.generated, world.terrain_seed, world.SAND_CENTER, world.SAND_RADIUS, world._grass_skipped, world.terrain.height_at).is_empty()

func _run() -> void:
	var fixture := "res://.godot/lawn-ring-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	current_scene = app
	await process_frame
	app.open_world(app.catalog.create_world("Herbe", "12345").id)
	var world = app.active_world
	for i in range(400):
		await process_frame
	var built: Array = world.built_columns.keys()
	var far_built: Array = built.filter(func(c: Vector2i): return maxi(absi(c.x - world.view_center.x), absi(c.y - world.view_center.y)) >= 2)
	# Sans herbe possible (désert, lac, aiguilles…) : pas de carré, c'est normal.
	var missing: Array = built.filter(func(c: Vector2i): return not world.lawn_tiles.has(c) and not world.detail_queue.has(c) and not _bare(world, c))
	print("MESURE: %d colonnes construites (%d à 2 zones ou plus), %d carrés d'herbe, %d sans herbe ni attente" % [built.size(), far_built.size(), world.lawn_tiles.size(), missing.size()])
	check(far_built.size() > 10 and missing.is_empty(), "every built column gets its grass (or waits for it), also beyond the 9 middle columns")
	world.finish_terrain()
	check(world.built_columns.keys().all(func(c): return world.lawn_tiles.has(c) or _bare(world, c)), "after finishing, every built column has its grass")
	print("RESULT: %d lawn ring checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
