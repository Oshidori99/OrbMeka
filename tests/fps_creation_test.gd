extends SceneTree
const World = preload("res://scripts/world.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Store = preload("res://scripts/world_store.gd")
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "res://.godot/fps-creation-%d.json" % Time.get_ticks_usec()
	var catalog := Catalog.new(path)
	var item: Dictionary = catalog.create_world("Date conservée", "42")
	var folder: String = catalog.world_folder(item.id)
	var base_path := folder.path_join(Store.BASE_FILE)
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base_path))
	metadata.creation = "2024-02-29T23:07:05"
	Store.write_json(base_path, metadata)
	catalog = Catalog.new(path)
	var before := FileAccess.get_file_as_bytes(base_path)
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	world.save_folder = folder
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	check(world.creation_text == "Création : 29/02/2024 à 23:07:05 (heure locale enregistrée)", "stored local creation date and time formatted in French")
	for level in range(3):
		check(world.get_world_info_text(level).contains(world.creation_text), "all information levels include creation")
	check(FileAccess.get_file_as_bytes(base_path) == before, "display does not change monde.json")
	var fps: Label = world.fps_label
	check(fps.text == "FPS : —" and fps.mouse_filter == Control.MOUSE_FILTER_IGNORE, "discreet FPS starts without taking mouse input")
	world._update_fps(0.49)
	check(fps.text == "FPS : —", "FPS text does not refresh each frame")
	world._update_fps(0.01)
	check(fps.text.begins_with("FPS : ") and fps.text != "FPS : —", "FPS refreshes after half a second")
	fps.text = "sentinel"
	world._update_fps(0.01)
	check(fps.text == "sentinel", "next frame leaves FPS text unchanged")
	for scale in [0.5,1.0,1.5]:
		world.apply_text_scale(scale)
		await process_frame
		var note: Label = world.find_child("ExplorationNotice",true,false)
		check(world.selected_block_label.get_rect().end.y <= note.position.y and note.get_rect().end.y <= fps.position.y, "HUD rows do not overlap at scale %.1f" % scale)
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	paused = true
	check(not fps.visible, "pause hides FPS under menus")
	paused = false
	check(fps.visible and world.fps_elapsed == 0.0, "resume restores FPS without counting pause time")
	for invalid in [null, 123, "", "2024-02-30T12:00:00", "2023-02-29T12:00:00", "2024-01-01T24:00:00", "2024-01-01", "nonsense"]:
		check(World.format_creation_date(invalid) == "Création : inconnue", "missing or invalid date is never invented")
	check(catalog.rename_world(item.id,"Nouveau nom"), "world can be renamed")
	check(JSON.parse_string(FileAccess.get_file_as_string(base_path)).creation == metadata.creation, "rename keeps creation date")
	var copy: Dictionary = catalog.duplicate_world(item.id)
	var copy_metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalog.world_folder(copy.id).path_join(Store.BASE_FILE)))
	check(copy.id != item.id and copy_metadata.creation != metadata.creation and not str(copy_metadata.creation).is_empty(), "duplicate receives its own creation date")
	metadata.erase("creation")
	Store.write_json(base_path,metadata)
	world._read_creation_date()
	check(world.creation_text == "Création : inconnue", "old world without creation shows unknown")
	# Migration d'un index ancien sans dossier : ne pas inventer la date d'aujourd'hui.
	var old_path := path.get_basename() + "-old.json"
	Store.write_json(old_path,{"version":1,"worlds":[{"id":"777","name":"Ancien","seed":42}]})
	var old := Catalog.new(old_path)
	check(JSON.parse_string(FileAccess.get_file_as_string(old.world_folder("777").path_join(Store.BASE_FILE))).creation == "", "migration keeps missing creation unknown")
	world.save_folder = ""
	root.remove_child(world)
	world.free()
	Store.delete_folder(catalog.worlds_root)
	Store.delete_folder(old.worlds_root)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "test never captures pointer")
	print("RESULT: %d FPS/creation checks, %d failures" % [checks,failures])
	quit(failures)
