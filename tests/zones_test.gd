extends SceneTree
# 0.0.5.1 : découpage en zones de 8 m, chargement et déchargement autour du joueur, sauvegarde par zone,
# migration de l'étape 1, même monde pour une même graine, recalcul limité à la section touchée.
const Store = preload("res://scripts/world_store.gd")
const Zones = preload("res://scripts/world_zones.gd")
const TerrainGenerator = preload("res://scripts/terrain_generator.gd")
const WorldScene = preload("res://scenes/world.tscn")
const FOLDER := "res://.godot/zones-test-monde"
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

func open(folder: String, seed_value: int, distance: int = 8) -> Node3D:
	var world: Node3D = WorldScene.instantiate()
	world.terrain_seed = seed_value
	world.save_folder = folder
	world.load_distance = distance
	root.add_child(world)
	return world

func close(world: Node3D) -> void:
	root.remove_child(world)
	world.free()

func _run() -> void:
	Store.delete_folder(FOLDER)
	# Découpage.
	check(Zones.ZONE_SIZE == 8 and Zones.SECTION_SIZE == 8 and Zones.DENSITY_POINTS == 16, "zones of 8 m, density grid of 16 points (50 cm) ready for step 3")
	check(Zones.zone_of(Vector3i(0, 0, 0)) == Vector3i.ZERO and Zones.zone_of(Vector3i(7, 7, 7)) == Vector3i.ZERO and Zones.zone_of(Vector3i(8, 0, -1)) == Vector3i(1, 0, -1) and Zones.zone_of(Vector3i(-8, 16, -9)) == Vector3i(-1, 2, -2), "cells map to stacked zones, negatives included")
	check(Zones.touched_sections(Vector3i(3, 3, 3)).size() == 1 and Zones.touched_sections(Vector3i(7, 3, 3)).size() == 2, "inner change touches one section, border change also its neighbours")
	# Même monde pour une même graine, quel que soit le découpage.
	var world := open("", 4321)
	var expected := {}
	for cell in TerrainGenerator.generate_cells(4321):
		expected[cell] = world.DIRT
	var same := true
	for cell in expected:
		same = same and world.blocks.get(cell, -1) == world.DIRT
	check(same and world.blocks.size() == world.generated.size(), "all zones loaded: same terrain as the seed generation")
	var other := open("", 4321)
	check(other.blocks == world.blocks, "two openings with the same seed give identical worlds")
	close(other)
	# Recalcul limité : poser un bloc ne refait que sa section.
	var before: Dictionary = {}
	for section in world.sections:
		before[section] = world.sections[section].get_instance_id()
	var started := Time.get_ticks_usec()
	world.add_block(Vector3i(-27, 0, -27), 1)
	var rebuild_ms := (Time.get_ticks_usec() - started) / 1000.0
	var rebuilt := 0
	for section in before:
		if not world.sections.has(section) or world.sections[section].get_instance_id() != before[section]:
			rebuilt += 1
	check(rebuilt == 0 and world.sections.has(Zones.section_of(Vector3i(-27, 0, -27))), "a change rebuilds only its section (others untouched)")
	print("MESURE: recalcul d'une section après un bloc posé : %.2f ms" % rebuild_ms)
	var ray := PhysicsRayQueryParameters3D.create(Vector3(-26.5, 5, -26.5), Vector3(-26.5, -1, -26.5))
	await physics_frame
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider.is_in_group("blocks") and world.hit_cell(hit) == Vector3i(-27, 0, -27), "merged section keeps collisions and aimed cell")
	close(world)
	# Chargement et déchargement autour du joueur, étalés sur plusieurs images.
	world = open(FOLDER, 4321, 1)
	check(world.loaded_zones.size() <= 3 * 3 * 2 and world.loaded_zones.has(Vector3i.ZERO) and not world.loaded_zones.has(Vector3i(5, 0, 5)), "only zones near the player are loaded (distance 1)")
	world.add_block(Vector3i(2, 5, 2), 0)
	world._changed(Vector3i(2, 5, 2))
	world.update_zones(Vector3i(44, 0, 44))
	var queued: int = world.zone_queue.size()
	world.process_zone_queue(3000, 1)
	check(queued > 1 and not world.zone_queue.is_empty(), "work is spread over several frames (%d items queued)" % queued)
	var frames := 0
	var slowest := 0.0
	while not world.zone_queue.is_empty():
		var frame_start := Time.get_ticks_usec()
		world.process_zone_queue()
		slowest = maxf(slowest, (Time.get_ticks_usec() - frame_start) / 1000.0)
		frames += 1
	print("MESURE: chargement d'une zone : %.2f ms ; image la plus chargée : %.2f ms sur %d images" % [world.last_zone_load_ms, slowest, frames])
	check(slowest < 12.0, "no frame spends more than 12 ms on zones (%.2f ms)" % slowest)
	check(not world.loaded_zones.has(Vector3i.ZERO) and world.loaded_zones.has(Vector3i(5, 0, 5)) and not world.blocks.has(Vector3i(2, 5, 2)), "far zones unloaded, near ones loaded")
	check(FileAccess.file_exists(FOLDER.path_join(Zones.zone_file(Vector3i.ZERO))), "unloading a modified zone saves it")
	world.update_zones(Vector3i(0, 0, 0), true)
	check(world.blocks.get(Vector3i(2, 5, 2), -1) == 0, "coming back reloads the change")
	world.blocks.erase(Vector3i(2, 5, 2))
	world._changed(Vector3i(2, 5, 2))
	world.save_now()
	check(not FileAccess.file_exists(FOLDER.path_join(Zones.zone_file(Vector3i.ZERO))), "zone back to the seed terrain has no file")
	close(world)
	# Migration de l'étape 1 : modifications.json → fichiers de zone, ancien fichier gardé.
	Store.delete_folder(FOLDER)
	var generated_cell: Vector3i = TerrainGenerator.generate_cells(4321)[0]
	Store.write_json(FOLDER.path_join(Store.CHANGES_FILE), {"format": 1, "type": "blocs", "poses": [[30, 0, 30, 1], [-30, 2, 10, 0]], "casses": [[generated_cell.x, generated_cell.y, generated_cell.z]]})
	world = open(FOLDER, 4321)
	check(world.blocks.get(Vector3i(30, 0, 30), -1) == 1 and world.blocks.get(Vector3i(-30, 2, 10), -1) == 0 and not world.blocks.has(generated_cell), "step 1 save migrates without losing anything")
	check(not FileAccess.file_exists(FOLDER.path_join(Store.CHANGES_FILE)) and FileAccess.file_exists(FOLDER.path_join(Zones.STEP1_KEPT)), "old file kept under another name")
	check(FileAccess.file_exists(FOLDER.path_join(Zones.zone_file(Zones.zone_of(Vector3i(30, 0, 30))))), "one file per modified zone after migration")
	var fps_sections: int = world.sections.size()
	close(world)
	world = open(FOLDER, 4321)
	check(world.blocks.get(Vector3i(30, 0, 30), -1) == 1, "migrated world reopens from zone files")
	print("MESURE: %d sections affichées, monde complet" % fps_sections)
	close(world)
	Store.delete_folder(FOLDER)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(failures)
