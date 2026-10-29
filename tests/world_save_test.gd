extends SceneTree
# 0.0.5 : dossier du monde, sauvegarde des différences, rechargement (deux processus), migration,
# duplication, suppression, fichiers illisibles.
const Catalog = preload("res://scripts/world_catalog.gd")
const Store = preload("res://scripts/world_store.gd")
const Zones = preload("res://scripts/world_zones.gd")
const WorldScene = preload("res://scenes/world.tscn")
const PATH := "res://.godot/world-save-test.json"
const OLD_PATH := "res://.godot/world-save-old-test.json"
const PLACED := Vector3i(20, 0, 20)
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

func open(folder: String, seed_value: int) -> Node3D:
	var world: Node3D = WorldScene.instantiate()
	world.terrain_seed = seed_value
	world.save_folder = folder
	root.add_child(world)
	return world

func close(world: Node3D) -> void:
	root.remove_child(world)
	world.free()

func read(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func clean(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Store.delete_folder(path.get_basename() + "-mondes")

func first_generated(world: Node3D) -> Vector3i:
	var cells: Array = world.generated.keys()
	cells.sort()
	return cells[0]

func _run() -> void:
	if OS.get_cmdline_user_args().has("--verify"):
		_verify_restart()
		return
	clean(PATH)
	clean(OLD_PATH)
	var catalog := Catalog.new(PATH)
	var item: Dictionary = catalog.create_world("Sauvegardé", "1234")
	var folder: String = catalog.world_folder(item.id)
	var base: Variant = read(folder.path_join(Store.BASE_FILE))
	check(base is Dictionary and int(base.graine) == 1234 and base.nom == "Sauvegardé" and base.format == Store.FORMAT and not str(base.creation).is_empty(), "monde.json holds name, seed, format and creation date")
	# Partie : un bloc posé, un bloc généré cassé, déplacement et regard.
	var world := open(folder, item.seed)
	# 0.0.5.5 : monde plat sans bloc de départ ; un bloc « généré » est ajouté pour tester les cassés.
	var removed := Vector3i(-20, 0, -20)
	world._generate_block(removed, 0)
	world.blocks[removed] = 0
	var count_generated: int = world.blocks.size()
	world.blocks.erase(removed)
	world._changed(removed)
	world.add_block(PLACED, 1)
	world._changed(PLACED)
	world.player.position = Vector3(3.5, 2.0, -7.5)
	world.player.rotation.y = 1.25
	world.player.camera.rotation.x = -0.4
	check(world.save_now(), "save succeeds")
	var placed_file := folder.path_join(Zones.zone_file(Zones.zone_of(PLACED)))
	var removed_file := folder.path_join(Zones.zone_file(Zones.zone_of(removed)))
	var placed_zone: Dictionary = Zones.read_zone(placed_file).get("data", {})
	var removed_zone: Dictionary = Zones.read_zone(removed_file).get("data", {})
	check(placed_zone.get("poses", []).size() == 1 and removed_zone.get("casses", []).size() == 1, "only differences from the seed terrain are saved, per zone (%d generated blocks)" % count_generated)
	var zone_files := Array(DirAccess.get_files_at(ProjectSettings.globalize_path(folder.path_join(Store.ZONES_DIR))))
	check(zone_files.size() == 2 and FileAccess.get_file_as_bytes(placed_file).size() < 400, "one small file per modified zone, none for untouched zones")
	check(not FileAccess.file_exists(placed_file + ".tmp"), "temporary file replaced")
	close(world)
	# Redémarrage : un second processus recharge blocs, position et regard.
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/world_save_test.gd", "--", "--verify", item.id, var_to_str(removed)], output, true)
	check(code == 0, "second process restores blocks, position and look\n" + "".join(output))
	check(catalog.world_size(item.id) > 0 and Store.size_text(catalog.world_size(item.id)).ends_with("o"), "world size is measured")
	# Duplication : la copie reprend les constructions ; suppression : le dossier disparaît.
	var copy: Dictionary = catalog.duplicate_world(item.id)
	var copy_folder: String = catalog.world_folder(copy.id)
	check(FileAccess.file_exists(copy_folder.path_join(Zones.zone_file(Zones.zone_of(PLACED)))) and FileAccess.file_exists(copy_folder.path_join(Store.PLAYER_FILE)), "duplicate copies changes and player")
	check(read(copy_folder.path_join(Store.BASE_FILE)).nom == copy.name, "duplicate keeps its own monde.json")
	var copied := open(copy_folder, copy.seed)
	check(copied.blocks.has(PLACED) and not copied.blocks.has(removed), "duplicate opens with the same constructions")
	close(copied)
	check(catalog.rename_world(copy.id, "Renommé") and read(catalog.world_folder(copy.id).path_join(Store.BASE_FILE)).nom == "Renommé" and catalog.world_folder(copy.id).get_file() == "Renommé" and not DirAccess.dir_exists_absolute(copy_folder), "rename updates monde.json and the folder name (0.0.5.20)")
	copy_folder = catalog.world_folder(copy.id)
	check(catalog.delete_world(copy.id) and not DirAccess.dir_exists_absolute(copy_folder), "delete removes the world folder")
	check(DirAccess.dir_exists_absolute(folder), "delete leaves other worlds' folders")
	# Fichiers illisibles : pas de plantage, rien n'est écrasé, le fichier est gardé de côté.
	var bad := FileAccess.open(placed_file, FileAccess.WRITE)
	bad.store_string("{ illisible")
	bad.close()
	var broken := open(folder, item.seed)
	check(not broken.blocks.has(PLACED) and not broken.blocks.has(removed) and broken.notice.begins_with("Zone illisible"), "unreadable zone: seed terrain there, other zones kept, and a message")
	var kept := DirAccess.get_files_at(ProjectSettings.globalize_path(folder.path_join(Store.ZONES_DIR)))
	check(Array(kept).any(func(name: String): return name.contains(".illisible-")) and not FileAccess.file_exists(placed_file), "unreadable file kept aside, never overwritten")
	broken.add_block(PLACED, 2)
	broken._changed(PLACED)
	broken.save_now()
	kept = DirAccess.get_files_at(ProjectSettings.globalize_path(folder.path_join(Store.ZONES_DIR)))
	check(Array(kept).filter(func(name: String): return name.contains(".illisible-")).size() == 1, "later save keeps the set-aside file")
	close(broken)
	bad = FileAccess.open(folder.path_join(Store.BASE_FILE), FileAccess.WRITE)
	bad.store_string("pas du json")
	bad.close()
	var repaired := Catalog.new(PATH)
	check(not repaired.repair_note.is_empty() and int(read(folder.path_join(Store.BASE_FILE)).graine) == 1234, "unreadable monde.json is set aside and rebuilt from the index")
	# Migration : ancien worlds.json (sans dossiers) → un dossier par monde, rien de perdu.
	var old := FileAccess.open(OLD_PATH, FileAccess.WRITE)
	old.store_string(JSON.stringify({"version": 1, "worlds": [{"id": "777", "name": "Ancien", "seed": 42, "mode": "developer"}, {"id": "778", "name": "Sans mode", "seed": 0}]}))
	old.close()
	var migrated := Catalog.new(OLD_PATH)
	var old_base: Variant = read(migrated.world_folder("777").path_join(Store.BASE_FILE))
	check(migrated.load_error.is_empty() and migrated.worlds.size() == 2 and old_base.nom == "Ancien" and int(old_base.graine) == 42 and old_base.mode == "developer", "old worlds migrate with id, name, seed and mode")
	check(read(migrated.world_folder("778").path_join(Store.BASE_FILE)).mode == "default", "world without mode migrates as default")
	check(migrated.world_folder("777").get_file() == "Ancien" and migrated.world_folder("778").get_file() == "Sans mode", "old world folders take the world name (0.0.5.20)")
	check(Store.clean_folder_name("a/..\\b:c*") == "a_.._b_c_" and Store.clean_folder_name("CON") == "CON_" and Store.clean_folder_name(" .x. ") == "x" and Store.unique_folder_name("Test", ["test"]) == "Test (2)", "folder names stay safe and unique")
	check(Catalog.new(OLD_PATH).find_world("777").seed == 42, "index stays readable after migration")
	clean(PATH)
	clean(OLD_PATH)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(failures)

func _verify_restart() -> void:
	var args := OS.get_cmdline_user_args()
	var catalog := Catalog.new(PATH)
	var item: Dictionary = catalog.find_world(args[1])
	var removed: Vector3i = str_to_var(args[2])
	var world := open(catalog.world_folder(item.id), item.seed)
	check(world.blocks.has(PLACED) and world.blocks[PLACED] == 1, "placed block restored")
	check(not world.blocks.has(removed), "broken block stays broken")
	check(world.player.position.distance_to(Vector3(3.5, 2.0, -7.5)) < 0.01, "position restored")
	check(is_equal_approx(world.player.rotation.y, 1.25) and is_equal_approx(world.player.camera.rotation.x, -0.4), "look restored")
	close(world)
	quit(failures)
