extends SceneTree
# 0.0.3.22 : les textes (Accueil → Informations, F3, Comment jouer) annoncent les mêmes
# valeurs que le monde et que les coordonnées affichées : base, zone générée, collines,
# hauteur et zone de construction, Y 0 sur le sol plat.
const Settings = preload("res://scripts/user_settings.gd")
const Terrain = preload("res://scripts/terrain_generator.gd")
const WorldRules = preload("res://scripts/world.gd")
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

func stand(world: Node3D, x: float, y: float, z: float) -> Vector3i:
	world.player.position = Vector3(x, y + 0.01, z)
	return world.player_coordinates()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/consistency-test-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	settings.values.text_detail = "plus"
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var item: Dictionary = app.catalog.create_world("Mesures", "11")
	root.add_child(app)
	current_scene = app
	await process_frame
	var home_info: String = app.detail_labels[app.generation_info][2]
	var help := WorldRules.get_help_text(2)
	app.open_world(item.id)
	var world: Node3D = app.active_world
	world.player.set_physics_process(false)
	var info: String = world.get_world_info_text(2)
	# Sol plat : apparition à Y 0, comme annoncé.
	check(world.player_coordinates() == Vector3i(0, 0, 0), "spawn at X 0, Y 0, Z 0")
	check(home_info.contains("sol à Y 0") and info.contains("sol à Y 0") and help.contains("Y 0 sur le sol plat"), "texts say the flat ground is Y 0")
	# Base : le sol réel va de -80 à 80, soit les cases -80 à 79 (0.0.5.18 : 20 × 20 zones de 8 m).
	var ground: StaticBody3D = world.get_node("Ground")
	var half: float = ground.get_child(1).shape.size.x / 2.0
	check(is_equal_approx(ground.position.x - half, -80.0) and is_equal_approx(ground.position.x + half, 80.0), "ground spans 160 blocks around 0")
	var low_corner: Vector3i = stand(world, -79.9, 4, -79.9)
	var high_corner: Vector3i = stand(world, 79.9, 4, 79.9)
	check(low_corner.x == -80 and low_corner.z == -80 and high_corner.x == 79 and high_corner.z == 79, "ground corners shown as X/Z -80 and 79 (hills may raise Y)")
	for text in [home_info, info]:
		check(text.contains("largeur 160 × longueur 160 blocs (X et Z de -80 à 79)"), "base size and range announced")
	# Zone générée : 41 × 41 cases, de -20 à 20.
	var span := Terrain.MAX_CELL - Terrain.MIN_CELL + 1
	var heights := {}
	var tallest := 0
	var outside := 0
	for terrain_seed in [11, 70621, 1, 2, 3, 4, 5, 999, 123456]:
		heights = Terrain.generate_heights(terrain_seed)
		for column: Vector2i in heights:
			if column.x < -20 or column.x > 20 or column.y < -20 or column.y > 20:
				outside += 1
			tallest = maxi(tallest, heights[column])
	check(span == 41 and outside == 0, "hills stay inside the 41 × 41 zone, -20 to 20")
	check(tallest == Terrain.MAX_HEIGHT and tallest == 3, "hills go up to 3 blocks, as announced")
	# 0.0.5.5 : tout plat, plage de sable ; colonne de 3 blocs posée pour vérifier Y 3.
	for text in [home_info, info]:
		check(text.contains("plage de sable d'environ 21 m²"), "sand beach announced")
	for y in range(3):
		world.add_block(Vector3i(11, y, 9), 0)
	var dune_top := stand(world, 11.5, 3, 9.5)
	check(dune_top.y == 3 and world.blocks.has(Vector3i(11, 2, 9)) and not world.blocks.has(Vector3i(11, 3, 9)), "standing on a 3-block column shows Y 3, top block just under the feet")
	# Construction : 25 blocs de haut ; debout sur le plus haut bloc permis, Y 25.
	world.add_block(Vector3i(30, WorldRules.MAX_BUILD_HEIGHT - 1, 30), 1)
	check(stand(world, 30.5, WorldRules.MAX_BUILD_HEIGHT, 30.5).y == 25, "standing on the highest allowed block shows Y 25")
	for text in [home_info, info, help]:
		check(text.contains("hauteur maximale 25 blocs au-dessus du sol plat") or text.contains("Hauteur maximale : 25 blocs au-dessus du sol plat"), "build height 25 announced")
		check(text.contains("sommet à Y 25") and text.contains("X et Z de -73 à 73"), "build top Y 25 and build zone -73 to 73 announced")
		check(text.contains(WorldRules.COORDINATES_NOTE), "coordinate note in every text")
	# Pose réelle : au bord de la zone de construction acceptée, juste après refusée ; hauteur 24 acceptée, 25 refusée.
	world.player.position = Vector3(73.5, 0.01, 71.5)
	check(world._edit_place_target({"collider": ground, "position": Vector3(73.5, 0.0, 73.5), "normal": Vector3.UP}, 1), "block placed at X 73")
	world.player.position = Vector3(74.5, 0.01, 71.5)
	check(not world._edit_place_target({"collider": ground, "position": Vector3(74.5, 0.0, 73.5), "normal": Vector3.UP}, 1), "block refused at X 74")
	var column_top: StaticBody3D = world.section_body(Vector3i(30, 24, 30))
	world.player.position = Vector3(30.5, 22.01, 28.5)
	check(not world._edit_place_target({"collider": column_top, "position": Vector3(30.5, 25.0, 30.5), "normal": Vector3.UP}, 1), "block refused above height 25")
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for menu in Settings.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.file_path(menu)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d consistency checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
