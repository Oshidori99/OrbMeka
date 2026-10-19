extends SceneTree
const Catalog = preload("res://scripts/world_catalog.gd")
const PATH := "res://.godot/catalog-restart-test.json"

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--verify"):
		var reopened := Catalog.new(PATH)
		if reopened.worlds.size() != 1 or reopened.worlds[0].name != "Persistant après fermeture" or not reopened.worlds[0].seed is int:
			push_error("Second process did not restore the saved world.")
			quit(1)
			return
		print("PASS: second process restores world name and seed after first process exits")
		quit(0)
		return
	# Fichier de test seulement (.godot/) : un reste d'une exécution interrompue est remplacé.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var catalog := Catalog.new(PATH)
	var item: Dictionary = catalog.create_world("Persistant après fermeture")
	if item.is_empty():
		push_error(catalog.last_error)
		quit(1)
		return
	print("PASS: first process saves world metadata")
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/catalog_restart_test.gd", "--", "--verify"], output, true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if code != 0:
		push_error("FAIL: second process exited with %d\n%s" % [code, "".join(output)])
		quit(1)
		return
	print("PASS: restart verified in a separate process")
	quit(0)
