extends SceneTree
const Catalog = preload("res://scripts/world_catalog.gd")
const PATH := "res://.godot/catalog-restart-test.json"

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--write"):
		if FileAccess.file_exists(PATH):
			push_error("Test fixture already exists; refusing to overwrite.")
			quit(1)
			return
		var catalog := Catalog.new(PATH)
		var item: Dictionary = catalog.create_world("Persistant après fermeture")
		if item.is_empty():
			push_error(catalog.last_error)
			quit(1)
			return
		print("PASS: first process saves world metadata")
	else:
		var catalog := Catalog.new(PATH)
		if catalog.worlds.size() != 1 or catalog.worlds[0].name != "Persistant après fermeture" or not catalog.worlds[0].seed is int:
			push_error("Second process did not restore the saved world.")
			quit(1)
			return
		print("PASS: second process restores world name and seed after first process exits")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	quit(0)