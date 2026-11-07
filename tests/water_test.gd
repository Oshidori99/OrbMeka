extends SceneTree
# 0.0.6.6 (#124) : eau qui coule. Un fossé creusé depuis la rive d'un lac se remplit, le lac baisse (même volume),
# l'eau ne bouge pas sans changement, tout est gardé dans eau/lacs.json et eau/cases.json et relu.
const Store = preload("res://scripts/world_store.gd")
const FOLDER := "res://.godot/eau-test-monde"
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _open() -> Node3D:
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	world.generation_options = load("res://scripts/world_generation.gd").defaults()
	world.terrain_seed = 42
	world.save_folder = FOLDER
	root.add_child(world)
	world.set_process(false)
	return world

func _run() -> void:
	Store.delete_folder(FOLDER)
	var world := _open()
	var terrain = world.terrain
	check(world.flowing != null and world.flowing.active.is_empty(), "water is quiet when nothing changed")
	var lake := {}
	for r in range(10, 200, 4):
		for angle in range(0, 360, 15):
			var found: Dictionary = terrain.lake_at(Vector2.from_angle(deg_to_rad(angle)) * r)
			if lake.is_empty() and not found.is_empty() and not found.has("on_mountain"):
				lake = found
	var center: Vector2 = (lake.start + lake.end) / 2.0
	var level: float = terrain.lake_level(lake)
	var area: float = terrain.lake_area(lake)
	# Fossé de 1 m sous le niveau du lac, de son centre jusqu'à 8 m au-delà de sa rive.
	var updates := {}
	for step in range(0, int((lake.radius + 8.0) / 0.5)):
		var at := center + Vector2(step * 0.5, 0)
		var column := Vector2i(roundi(at.x / 0.5), roundi(at.y / 0.5))
		for y in range(floori((level - 1.0) / 0.5), floori((terrain.ground_height(column) + 1.0) / 0.5) + 1):
			for dz in [-1, 0, 1]:
				updates[Vector3i(column.x, y, column.y + dz)] = [-1.0, -1]
	world._apply_terrain(updates)
	check(not world.flowing.active.is_empty(), "digging next to a lake wakes the water up")
	for i in range(300):
		world.flowing.step(center)
	var free: float = world.flowing.free_volume()
	var gone: float = (level - world.flowing.lake_level_now(lake)) * area
	check(free > 2.0, "water flows out of the lake into the ditch (%.1f m³)" % free)
	check(gone > 0.0 and absf(gone - free) < 0.05 * gone, "the lake goes down by the same volume (%.2f m³ out, %.2f m³ in the ditch)" % [gone, free])
	var outside := center + Vector2(lake.radius + 4.0, 0.0)
	check(world.flowing.surface_at(outside) > world.flowing.floor_of(world.flowing.column_of(outside)), "the ditch past the shore holds water")
	world.show_water_changes()
	check(not world.water_pieces.is_empty(), "flowing water is drawn")
	check(world.save_now() and FileAccess.file_exists(FOLDER.path_join("eau/lacs.json")) and FileAccess.file_exists(FOLDER.path_join("eau/cases.json")), "water saved in eau/lacs.json and eau/cases.json")
	var saved_level: float = world.flowing.lake_level_now(lake)
	var saved_free: float = world.flowing.free_volume()
	world.save_folder = ""
	root.remove_child(world)
	world.free()
	var again := _open()
	check(absf(again.flowing.lake_level_now(lake) - saved_level) < 0.0005 and absf(again.flowing.free_volume() - saved_free) < 0.01, "lake level and flowing water come back when the world reopens")
	again.save_folder = ""
	root.remove_child(again)
	again.free()
	Store.delete_folder(FOLDER)
	var untouched := _open()
	check(not DirAccess.dir_exists_absolute(FOLDER.path_join("eau")) and untouched.flowing.lake_levels.is_empty(), "a world where water never moved has no water files")
	untouched.save_folder = ""
	root.remove_child(untouched)
	untouched.free()
	Store.delete_folder(FOLDER)
	print("RESULT: %d water checks, %d failures" % [checks, failures])
	quit(failures)
