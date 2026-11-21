extends SceneTree
# 0.0.8.1 (#205, #188, demandes de l'utilisateur) : vie à 0 en Survie : écran « À bout de forces… », puis « Revenir au
# départ » (vie pleine). Objets à la mort : réglage du monde (création, Paramètres → Monde), défaut dans Paramètres →
# Survie : ils tombent sur place, éparpillés, et restent (objets.json), ou on les garde. Créatif : revenir au point de
# départ (touche H par défaut, bouton de la pause, Créatif seulement).
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Controls = preload("res://scripts/controls.gd")
const Store = preload("res://scripts/world_store.gd")
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
	check(Controls.ACTIONS.has("go_home") and Controls.ACTIONS.go_home.default.key == KEY_H and Controls.GROUPS.Raccourcis.has("go_home"), "go home: H by default, in Contrôles → Raccourcis")
	check(Settings.CHOICES.death_items.default == "drop" and "death_items" in Settings.GENERAL_KEYS, "Paramètres: items at death, drop by default, in parametres-generaux.json")
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/death-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = Catalog.new(fixture + ".worlds")
	root.add_child(app)
	current_scene = app
	await process_frame
	# Création : le défaut de Paramètres, puis « Gardés » choisi.
	settings.values.death_items = "keep"
	app.show_page("create")
	await process_frame
	check(app.create_death_items == "keep" and app.create_death_buttons.keep.button_pressed, "create page: the Paramètres default is proposed")
	app.create_death_buttons.drop.pressed.emit()
	check(app.create_death_items == "drop", "create page: Tombent sur place can be chosen")
	app.name_field.text = "Mort"
	app.seed_field.text = "73"
	app.create_named_world()
	var world: Node3D = app.active_world
	while world == null or not is_instance_valid(world):
		await process_frame
		world = app.active_world
	for i in range(8):
		await process_frame
	for i in range(600):
		if app.page == "playing":
			break
		await process_frame
	var id: String = app.current_world_id
	check(app.catalog.find_world(id).get("death_items", "drop") == "drop" and world.death_items == "drop", "new world: items drop at death")
	var base := Store.read_json(app.catalog.world_folder(id).path_join(Store.BASE_FILE), Store.valid_base)
	check(base.get("data", {}).get("objets_a_la_mort") == "drop", "saved in monde.json")
	world.set_game_mode(Inventory.SURVIVAL)
	world.inventory.put("bar", 0, Inventory.single({"objet": "pomme", "taille": 2, "couleur": 1}))
	world.inventory.put("bar", 2, Inventory.single({"objet": "caillou", "taille": 2}))
	world.inventory.put("bar", 3, Inventory.single({"objet": "noisette"}))
	var spot: Vector3 = world.player.global_position
	var before: int = _placed(world)
	world.hurt(500)
	check(world.death_open and world.death_layer.visible and world.death_note.text.contains("tombé"), "life at 0: death screen, items left on the spot")
	check(Inventory.HANDS.all(func(i): return world.inventory.item("bar", i).is_empty()) and Inventory.POCKETS.all(func(i): return world.inventory.item("bar", i).is_empty()), "hands and pockets emptied")
	var dropped: Array = world.ground.entries.filter(func(e): return not e.item.has("graine")).slice(before)
	check(dropped.size() == 3 and dropped.all(func(e): return Vector2(e.position.x - spot.x, e.position.z - spot.z).length() < 1.6), "3 items scattered around the spot (%d)" % dropped.size())
	check(world.player_data().vie == 100 and Vector3(world.player_data().position[0], world.player_data().position[1], world.player_data().position[2]).distance_to(world.spawn_position()) < 0.01, "saved during the screen: already back at the start, full life")
	app._cancel_page()
	check(world.death_open and app.page == "playing", "Échap does not close the death screen (page %s)" % app.page)
	world.open_inventory()
	check(not world.inventory_open, "no inventory during the death screen")
	world.death_button.pressed.emit()
	check(not world.death_open and world.health.value == 100 and world.player.position.distance_to(world.spawn_position()) < 0.01, "Revenir au départ: start, full life")
	# Gardés pour toujours : relus avec le monde.
	world.save_now()
	app.return_to_worlds()
	app.open_world(id)
	for i in range(8):
		await process_frame
	world = app.active_world
	var kept: Array = world.ground.entries.filter(func(e): return not e.item.has("graine") and Vector2(e.position.x - spot.x, e.position.z - spot.z).length() < 1.6)
	check(kept.size() >= 3, "dropped items still there after reopening (%d)" % kept.size())
	# Paramètres → Monde : « Gardés ».
	app.pause_game()
	app.pause_settings_button.pressed.emit()
	app.death_items_buttons.keep.pressed.emit()
	check(app.catalog.find_world(id).get("death_items") == "keep" and world.death_items == "keep" and app.death_items_buttons.keep.button_pressed, "world settings: Gardés chosen, applied at once")
	app.show_page("pause")
	app.resume_game()
	world.set_game_mode(Inventory.SURVIVAL)
	world.inventory.put("bar", 0, Inventory.single({"objet": "pomme", "taille": 2, "couleur": 1}))
	before = _placed(world)
	world.hurt(500)
	check(world.death_open and not world.inventory.item("bar", 0).is_empty() and _placed(world) == before and world.death_note.text.contains("gardez"), "Gardés: items kept at death")
	world.respawn()
	# Créatif : retour au point de départ.
	world.player.position += Vector3(30.0, 4.0, 30.0)
	check(not world.go_home(), "Survie: no direct return to the start")
	world.set_game_mode(Inventory.CREATIVE)
	app.catalog.set_game_mode(id, Catalog.GAME_CREATIVE)
	check(world.go_home() and world.player.position.distance_to(world.spawn_position()) < 0.01, "Créatif: back to the start")
	world.player.position += Vector3(30.0, 4.0, 30.0)
	app.pause_game()
	check(app.home_button.visible, "pause: Revenir au point de départ shown in Créatif")
	app.home_button.pressed.emit()
	check(app.page == "playing" and world.player.position.distance_to(world.spawn_position()) < 0.01, "pause button: back to the start, game resumed")
	world.set_game_mode(Inventory.SURVIVAL)
	app.pause_game()
	check(not app.home_button.visible, "pause: no such button in Survie")
	app.resume_game()
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for menu in Settings.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.file_path(menu)))
	print("RESULT: %d death checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

static func _placed(world: Node3D) -> int:
	return world.ground.entries.filter(func(e): return not e.item.has("graine")).size()
