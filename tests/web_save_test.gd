extends SceneTree
# 0.0.7.23 : sur le Web, la partie est enregistrée 2 s après un changement (le navigateur recopie ses fichiers un peu
# après coup ; à la fermeture de l'onglet seulement, le dernier changement pouvait être perdu).
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
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	world.generation_options = Generation.defaults()
	world.terrain_seed = 1864659616
	root.add_child(world)
	world.set_process(false)
	var folder := "res://.godot/test-web-save-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	world.save_folder = folder
	world.save_now()
	check(not world._save_due(5.0), "on PC: nothing more than the regular save")
	world.web_save_test = true
	check(not world._save_due(5.0), "Web, nothing changed: no save")
	world.objects_dirty = true
	check(not world._save_due(0.3), "Web, a change: not at once")
	check(world._save_due(0.3), "Web, 0,5 s after a change: saved (0.0.7.24, 2 s before)")
	world.save_now()
	check(not world._save_due(3.0), "after saving: nothing to save")
	world.inventory_unsaved = true
	world.terrain.unstable[Vector3i(0, 0, 0)] = true
	check(not world._save_due(3.0), "something still falling: wait (it would be settled at once)")
	world.terrain.unstable.clear()
	check(world._save_due(0.1), "nothing falling any more: saved (inventory changed)")
	root.remove_child(world)
	world.free()
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(file)))
	for sub in DirAccess.get_directories_at(folder):
		for file in DirAccess.get_files_at(folder.path_join(sub)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(sub).path_join(file)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(sub)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	print("RESULT: %d web save checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
