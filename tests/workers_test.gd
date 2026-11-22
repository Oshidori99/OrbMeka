extends SceneTree
# 0.0.8.13 « Plusieurs cœurs » : les fils de calcul du terrain (terrain_workers.gd, une copie du terrain chacun) donnent
# exactement les mêmes nombres que le fil principal (même graine = même monde) : hauteurs, surfaces des zones, relevés du
# lointain ; montagnes tirées pareil dans tous les fils ; dans le monde, les colonnes de la graine viennent des fils, une
# colonne changée par le joueur est faite ici ; fils arrêtés quand le monde se ferme.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Generation = preload("res://scripts/world_generation.gd")
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
const FarTerrain = preload("res://scripts/far_terrain.gd")
const TerrainWorkers = preload("res://scripts/terrain_workers.gd")
const WorldScript = preload("res://scripts/world.gd")
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

func _wait_ready(workers: RefCounted, count: int) -> bool:
	var start := Time.get_ticks_msec()
	while workers.ready_count() < count and Time.get_ticks_msec() - start < 60000:
		await process_frame
	return workers.ready_count() >= count

func _wait_results(workers: RefCounted, wanted: int) -> Array:
	var got: Array = []
	var start := Time.get_ticks_msec()
	while got.size() < wanted and Time.get_ticks_msec() - start < 60000:
		got.append_array(workers.take_results())
		await process_frame
	return got

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var seed := 3463503054
	var options := Generation.defaults()
	# Montagnes : le même tirage dans deux fils à la fois (avant : un seul tirage partagé, les fils se seraient mélangés).
	var here := []
	for x in range(-40, 40):
		here.append(Generation.zone_mountain(seed, Vector2i(x, 7), options))
	var threads: Array[Thread] = []
	for index in range(3):
		var thread := Thread.new()
		thread.start(func() -> Array:
			var list := []
			for round in range(20):
				list = []
				for x in range(-40, 40):
					list.append(Generation.zone_mountain(seed, Vector2i(x, 7), options))
			return list)
		threads.append(thread)
	var same := true
	for thread in threads:
		same = same and str(thread.wait_to_finish()) == str(here)
	check(same, "mountains drawn the same in several threads at once")
	# Terrain préparé ici (fil principal) et deux fils de calcul.
	var main := SmoothTerrain.new()
	main.setup(seed, WorldScript.flat_spots(), options, false)
	main.prepare_step(1 << 40)
	var workers := TerrainWorkers.new()
	workers.start(seed, WorldScript.flat_spots(), options, 2)
	check(await _wait_ready(workers, 2), "two workers prepare their own copy of the terrain")
	# Colonnes variées : départ, loin, collines, et toutes celles des montagnes ou lacs proches de ces points.
	var columns: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, -2), Vector2i(-12, 9), Vector2i(20, 20), Vector2i(-30, -25), Vector2i(41, -7)]
	for column in columns:
		workers.add_column(column)
	var tiles := [Vector2i(2, 1), Vector2i(-3, 4)]
	for tile: Vector2i in tiles:
		workers.add_far(Vector3i(tile.x, tile.y, 4), tile, 4.0)
	var results := await _wait_results(workers, columns.size() + tiles.size())
	check(results.size() == columns.size() + tiles.size(), "all jobs come back (%d)" % results.size())
	var heights_same := true
	var surfaces_same := true
	var zones_same := true
	var surfaces_count := 0
	var far_same := true
	for result: Dictionary in results:
		if result.kind == "lointain":
			var survey := FarTerrain.new_survey(Vector2i(result.key.x, result.key.y), 4.0)
			FarTerrain.advance(main, survey, 1 << 62)
			far_same = far_same and survey.heights == result.survey.heights and survey.colors == result.survey.colors
			continue
		var column: Vector2i = result.column
		for point: Vector2i in result.heights:
			heights_same = heights_same and main.ground_height(point) == result.heights[point]
		var zones: Array = main.surface_zones(column, column).keys()
		zones.sort()
		var theirs: Array = result.zones.duplicate()
		theirs.sort()
		zones_same = zones_same and zones == theirs
		for zone: Vector3i in result.surfaces:
			surfaces_count += 1
			surfaces_same = surfaces_same and main.zone_surface(zone) == result.surfaces[zone]
	check(heights_same, "worker heights equal the main thread's")
	check(zones_same, "worker surface zones equal the main thread's")
	check(surfaces_same and surfaces_count > 0, "worker zone surfaces equal the main thread's (%d zones)" % surfaces_count)
	check(far_same, "worker far surveys equal the main thread's")
	workers.stop()
	check(workers.pending_count() == 0, "workers stop")
	# Anciennes générations (les mondes gardent la leur) : mêmes nombres aussi (rivières et lacs calculés à la demande).
	for version in [20, 28]:
		var old := {"version": version}
		for spec in Generation.specs_for(version):
			old[spec.key] = spec.default
		var here_terrain := SmoothTerrain.new()
		here_terrain.setup(seed, WorldScript.flat_spots(), old)
		var old_workers := TerrainWorkers.new()
		old_workers.start(seed, WorldScript.flat_spots(), old, 1)
		await _wait_ready(old_workers, 1)
		for column in [Vector2i(0, 0), Vector2i(-12, 9), Vector2i(20, 20)]:
			old_workers.add_column(column)
		var old_results := await _wait_results(old_workers, 3)
		var old_same := old_results.size() == 3
		var old_zones := 0
		for result: Dictionary in old_results:
			for point: Vector2i in result.heights:
				old_same = old_same and here_terrain.ground_height(point) == result.heights[point]
			for zone: Vector3i in result.surfaces:
				old_zones += 1
				old_same = old_same and here_terrain.zone_surface(zone) == result.surfaces[zone]
		old_workers.stop()
		check(old_same, "generation %d: worker results equal the main thread's (%d zones)" % [version, old_zones])
	# Dans le monde : les colonnes découvertes viennent des fils de calcul.
	var fixture := "res://.godot/workers-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(fixture)
	app.catalog = Catalog.new(fixture + ".worlds")
	var made: Dictionary = app.catalog.create_world("Coeurs", str(seed))
	app.catalog.set_game_mode(made.id, Catalog.GAME_CREATIVE)
	root.add_child(app)
	current_scene = app
	await process_frame
	app.open_world(made.id)
	var world: Node3D = app.active_world
	check(world.terrain_workers != null, "the world starts its terrain workers")
	check(await _wait_ready(world.terrain_workers, 1), "and they get ready")
	# Une colonne changée par le joueur (un trou devant lui) : faite ici, jamais envoyée.
	var away := Vector3(180.0, 0.0, -150.0)
	var edit_column := Vector2i(floori(away.x / 8.0), floori(away.z / 8.0))
	var point := SmoothTerrain.point_of(Vector3(away.x, world.terrain.height_at(away.x, away.z) - 0.4, away.z))
	world.terrain.set_density(point, -1.0)
	check(world.terrain.zone_column_changed(edit_column) and not world._worker_fits(edit_column), "a column changed by the player is not sent to the workers")
	world.player.position = Vector3(away.x, world.terrain.height_at(away.x, away.z) + 1.0, away.z)
	var before: int = world.worker_built
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 30000:
		await process_frame
		if world.terrain_queue.is_empty() and world.far_queue.is_empty() and world.worker_columns.is_empty():
			break
	check(world.terrain_queue.is_empty() and world.far_queue.is_empty(), "the whole view gets built (%.1f s)" % ((Time.get_ticks_msec() - start) / 1000.0))
	check(world.worker_built - before > 20, "most zones come from the workers (%d)" % (world.worker_built - before))
	check(world.built_columns.has(edit_column) and world.worker_surfaces.is_empty(), "the changed column is built here; no worker surface left over")
	var edited_zone := SmoothTerrain.point_zone(point)
	var edited: Node = world.terrain_pieces.get(edited_zone)
	check(edited != null and (edited.get_child(0) as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == world.terrain.zone_surface(edited_zone)[0], "and its piece has the player's change (same as computed here with it)")
	# Une zone montée avec une surface d'un fil de calcul : la même qu'ici.
	var compared := 0
	var equal := true
	for zone: Vector3i in world.terrain_pieces:
		if compared >= 12 or world.terrain.zone_column_changed(Vector2i(zone.x, zone.z)):
			continue
		var piece: Node = world.terrain_pieces[zone]
		var mesh: Mesh = (piece.get_child(0) as MeshInstance3D).mesh
		if mesh == world.flat_ground_mesh or mesh.get_surface_count() == 0:
			continue
		var surface: Array = world.terrain.zone_surface(zone)
		equal = equal and mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == surface[0] and mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] == surface[6]
		compared += 1
	check(equal and compared >= 6, "pieces in the world are the same as computed here (%d compared)" % compared)
	var kept: RefCounted = world.terrain_workers
	app.return_to_worlds()
	await process_frame
	await process_frame
	check(kept.pending_count() == 0 and kept._threads.is_empty(), "the workers stop when the world closes")
	# Monde fermé tout de suite après l'ouverture (les fils préparent encore leur copie) : pas d'attente.
	app.open_world(made.id)
	var closing := Time.get_ticks_msec()
	app.return_to_worlds()
	await process_frame
	await process_frame
	check(Time.get_ticks_msec() - closing < 1000, "a world closed right after opening does not wait for its workers (%d ms)" % (Time.get_ticks_msec() - closing))
	for path in [fixture, fixture + ".worlds"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d workers checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
