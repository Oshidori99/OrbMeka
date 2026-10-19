extends SceneTree
const Catalog = preload("res://scripts/world_catalog.gd")
const PATH := "res://.godot/world-management-test.json"
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
	if OS.get_cmdline_user_args().has("--verify-restart"):
		var reopened := Catalog.new(PATH)
		check(reopened.worlds.size() == 1 and reopened.worlds[0].name == "Mon monde renommé", "new process restores rename and confirmed deletion")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		print("RESULT: %d restart checks, %d failures" % [checks, failures])
		quit(failures)
		return
	# Fichier de test seulement (.godot/) : un reste d'une exécution interrompue est remplacé.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var catalog := Catalog.new(PATH)
	var first: Dictionary = catalog.create_world("Mon monde")
	var second: Dictionary = catalog.create_world("À supprimer")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.catalog = catalog
	root.add_child(app)
	current_scene = app
	app.show_page("worlds")
	check(not app.rename_button.disabled and not app.delete_button.disabled, "selected world enables rename and delete")
	app.rename_button.pressed.emit()
	check(app.page == "rename" and app.rename_field.text == first.name, "rename pre-fills selected world's name")
	app.rename_field.text = " "
	app.confirm_rename()
	check(app.page == "rename" and not app.rename_error.text.is_empty(), "rename rejects blank name")
	app.rename_field.text = second.name
	app.confirm_rename()
	check(app.page == "rename", "rename rejects another world's name")
	app.rename_field.text = " Mon monde renommé "
	app.confirm_rename()
	check(app.page == "worlds" and app.world_list.get_item_text(0) == "Mon monde renommé", "rename refreshes list with trimmed name")
	check(catalog.find_world(first.id).seed == first.seed and catalog.find_world(first.id).id == first.id, "rename preserves identity and seed")
	check(Catalog.new(PATH).find_world(first.id).name == "Mon monde renommé", "rename is written to disk")
	app.refresh_world_list(second.id)
	app.delete_button.pressed.emit()
	check(app.page == "delete" and app.delete_message.text.contains(second.name), "delete confirmation names chosen world")
	check(app.cancel_delete_button.has_focus(), "confirmation defaults to cancel")
	app.cancel_delete_button.pressed.emit()
	check(catalog.worlds.size() == 2 and Catalog.new(PATH).worlds.size() == 2, "cancel leaves all metadata intact in memory and on disk")
	app.refresh_world_list(second.id)
	app.delete_button.pressed.emit()
	# A later selection change must never change the ID captured for confirmation.
	app.world_list.select(0)
	app.confirm_delete()
	check(catalog.find_world(second.id).is_empty() and not catalog.find_world(first.id).is_empty(), "confirm deletes only the originally chosen world")
	check(app.page == "worlds" and app.world_list.item_count == 1, "confirmed deletion refreshes list")
	check(Catalog.new(PATH).find_world(second.id).is_empty(), "confirmed deletion persists")
	check(not catalog.delete_world("missing"), "unknown world cannot delete any other entry")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "management never captures pointer")
	# Last-world deletion disables actions; restore the survivor for process restart.
	var restored: Dictionary = catalog.find_world(first.id)
	app.refresh_world_list(first.id)
	app.request_delete()
	app.confirm_delete()
	check(app.world_list.item_count == 0 and app.rename_button.disabled and app.delete_button.disabled, "empty list disables rename and delete")
	catalog.worlds.append(restored)
	check(catalog._save_worlds(), "restart fixture retains the renamed survivor")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/world_management_test.gd", "--", "--verify-restart"], output, true)
	check(code == 0, "separate process restores rename and confirmed deletion")
	if code != 0:
		print("".join(output))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("RESULT: %d management checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)