extends SceneTree
# 0.0.3.14 : apparition en X 0, Y 1, Z 0 ; coordonnées en jeu (Vidéo → Afficher les
# coordonnées) et « Votre position actuelle » dans Informations du monde.
const Settings = preload("res://scripts/user_settings.gd")
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
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/coordinates-test-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	check(settings.values.show_coords == "off", "coordinates hidden by default")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var item: Dictionary = app.catalog.create_world("Origine", "11")
	root.add_child(app)
	current_scene = app
	await process_frame
	app.open_world(item.id)
	var world: Node3D = app.active_world
	for index in range(30):
		await physics_frame
	check(not world.blocks.has(Vector3i(0, 0, 0)) and world.blocks.has(Vector3i(0, 0, -1)), "demo blocks shifted, cell 0, 0 left free")
	check(world.player_coordinates() == Vector3i(0, 1, 0), "player appears at X 0, Y 1, Z 0")
	check(not world.coordinates_label.visible, "no coordinates in game while the option is off")
	app.pause_game()
	app.open_world_info()
	check(app.info_text.text.begins_with("Votre position actuelle : X 0 · Y 1 · Z 0"), "world info shows the current position")
	# Option dans Vidéo, interrupteur, effet immédiat.
	app.show_page("pause")
	app.pause_settings_button.pressed.emit()
	app.settings_tabs.video.pressed.emit()
	check(app.choice_switches.has("show_coords") and app.settings_sections.video.is_ancestor_of(app.choice_switches.show_coords) and not app.choice_switches.show_coords.button_pressed, "Afficher les coordonnées switch in Vidéo")
	app.choice_switches.show_coords.button_pressed = true
	check(settings.values.show_coords == "on" and world.coordinates_label.visible and world.coordinates_label.text == "X 0 · Y 1 · Z 0", "switch shows coordinates at once")
	var label_rect: Rect2 = world.coordinates_label.get_global_rect()
	check(label_rect.position.x > 640 and label_rect.position.y < 200, "coordinates shown top right")
	app.settings_back_button.pressed.emit()
	app.resume_game()
	# Déplacement : X largeur, Y hauteur, Z longueur.
	world.player.set_physics_process(false)
	world.player.position = Vector3(12.3, 2.0, -7.6)
	await process_frame
	await process_frame
	check(world.coordinates_label.text == "X 12 · Y 3 · Z -8", "coordinates follow the player")
	# Réapparition sur un bloc posé en 0, 0.
	world.add_block(Vector3i(0, 0, 0), world.DIRT)
	world.player.position = world.spawn_position()
	await process_frame
	check(world.player_coordinates() == Vector3i(0, 2, 0), "respawn on a block built at 0, 0 gives Y 2")
	app.return_to_worlds()
	# Option gardée et appliquée à l'ouverture d'un monde.
	app.open_world(item.id)
	check(app.active_world.coordinates_label.visible, "option kept when opening a world")
	app.return_to_worlds()
	check(Settings.new(fixture).values.show_coords == "on", "option saved in video.json")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for menu in Settings.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.file_path(menu)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d coordinates checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
