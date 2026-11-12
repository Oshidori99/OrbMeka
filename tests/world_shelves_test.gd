extends SceneTree
# 0.0.6 : listes de mondes sécurisées, sous-dossiers, anciens mondes cachés ou rangés automatiquement.
const Catalog = preload("res://scripts/world_catalog.gd")
const Shelves = preload("res://scripts/world_shelves.gd")
const Store = preload("res://scripts/world_store.gd")
const Generation = preload("res://scripts/world_generation.gd")
const PATH := "res://.godot/world-shelves-test.json"
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

func _clean() -> void:
	var base := PATH.get_basename()
	for root in [base + "-mondes", base + "-securises", base + "-versions"]:
		Store.delete_folder(root)
	for file in [PATH, base + "-securises.json", base + "-versions.json", base + "-dossiers.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file))

func _run() -> void:
	_clean()
	var catalog := Catalog.new(PATH)
	var old_options := Generation.defaults()
	old_options.version = Generation.VERSION - 1
	var fresh: Dictionary = catalog.create_world("Neuf", "1")
	var old: Dictionary = catalog.create_world("Ancien", "2", Catalog.MODE_DEFAULT, false, old_options)
	var precious: Dictionary = catalog.create_world("Précieux", "3")
	var shelves := Shelves.new(catalog)
	# Déplacement : dossier et index suivent, rien d'autre ne change.
	var before := catalog.world_folder(precious.id)
	check(shelves.move_world(precious.id, "secure"), "a world moves to the secure list")
	check(not DirAccess.dir_exists_absolute(before) and DirAccess.dir_exists_absolute(shelves.catalogs.secure.world_folder(precious.id)), "its folder moves out of the shared worlds folder")
	check(catalog.find_world(precious.id).is_empty() and Catalog.new(PATH).find_world(precious.id).is_empty(), "the shared index (read by old game versions) no longer lists it")
	check(Catalog.new(PATH.get_basename() + "-securises.json", PATH.get_basename() + "-securises").find_world(precious.id).seed == 3, "the secure index keeps seed and identity")
	check(catalog.create_world("précieux", "4").is_empty(), "names stay unique across all lists")
	# Rangement automatique et exception.
	check(shelves.auto_secure() == 1 and shelves.list_of(old.id) == "versions" and shelves.list_of(fresh.id) == "default", "old worlds go to secured versions, current ones stay")
	check(shelves.move_world(old.id, "default") and old.id in shelves.exceptions, "bringing an old world back makes it an exception")
	check(shelves.auto_secure() == 0 and shelves.list_of(old.id) == "default", "an exception is never moved again")
	# Sous-dossiers : un seul niveau, seulement vides à la suppression.
	check(shelves.create_folder("default", "Essais") and not shelves.create_folder("default", "essais") and not shelves.create_folder("default", " "), "subfolders need a new, non-empty name")
	check(shelves.put_in_folder(fresh.id, "Essais") and shelves.folder_of(fresh.id) == "Essais" and shelves.worlds_in("default", "").size() == 1, "a world goes into a subfolder")
	check(not shelves.delete_folder("default", "Essais"), "a subfolder with worlds is never deleted")
	var reread := Shelves.new(Catalog.new(PATH))
	check(reread.folder_of(fresh.id) == "Essais" and old.id in reread.exceptions and reread.list_of(precious.id) == "secure", "folders, places and exceptions are saved")
	# Menus.
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = load("res://scripts/user_settings.gd").new("res://.godot/world-shelves-settings.json")
	app.catalog = Catalog.new(PATH)
	root.add_child(app)
	current_scene = app
	app.show_page("worlds")
	check(not app.list_tabs_row.visible and not app.move_button.visible and not app.new_folder_button.visible, "without the option, Mes mondes looks as before")
	check(app.world_list.item_count == 2 and app.list_message.text.contains("1 monde(s) en sécurité"), "secured worlds are hidden but announced")
	app.settings.values.hide_old_worlds = "on"
	app.refresh_world_list()
	check(app.world_list.item_count == 1 and app.world_list.get_item_text(0) == "Neuf", "old worlds can be hidden")
	app.settings.values.hide_old_worlds = "off"
	app.settings.values.world_shelves = "on"
	app.refresh_world_list()
	check(app.list_tabs_row.visible and app.list_tabs.size() == 3 and app.list_tabs.default.button_pressed and app.new_folder_button.visible, "the option shows three list tabs and the + for subfolders")
	check(app.world_list.get_item_text(0).begins_with("📁 Essais (1)") and app.world_list.get_item_text(1) == "Ancien", "subfolders come first, their worlds stay inside")
	app.world_list.select(0)
	app._update_world_actions()
	app.open_selected_world()
	check(app.world_subfolder == "Essais" and app.world_list.get_item_text(1) == "Neuf" and not app.new_folder_button.visible, "opening a subfolder shows its worlds, no sub-subfolder")
	app.world_list.select(1)
	app._update_world_actions()
	app.request_move()
	check(app.page == "move" and app.move_choices.get_child_count() == 3, "move offers the two other lists and leaving the subfolder")
	app.move_pending_world("secure")
	check(app.page == "worlds" and app.shelves.list_of(fresh.id) == "secure", "a world moves from the menu")
	app.show_world_list("secure")
	check(app.catalog == app.shelves.catalogs.secure and app.world_list.item_count == 2 and app.list_help.text.contains("abri"), "the secure tab lists its worlds and says what it does")
	app.request_new_folder()
	app.folder_name_field.text = "Coffre"
	app.confirm_new_folder()
	check(app.page == "worlds" and "Coffre" in app.shelves.folders.secure, "the + creates a subfolder in the current list")
	root.remove_child(app)
	app.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.godot/world-shelves-settings.json"))
	_clean()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "test never captures pointer")
	print("RESULT: %d world shelves checks, %d failures" % [checks, failures])
	quit(failures)
