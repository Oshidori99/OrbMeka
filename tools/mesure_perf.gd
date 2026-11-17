extends SceneTree
# 0.0.7.20 : mesure des performances (avant / après une optimisation), à lancer AVEC fenêtre, hors de l'écran :
#   & '<Godot console>' --path . --position 20000,20000 --resolution 1280x720 --script res://tools/mesure_perf.gd
# Variables : MESURE=accueil|monde (défaut : les deux, l'un après l'autre), GRAINE (défaut 1864659616).
# Imprime des lignes « MESURE clé = valeur » : temps (ms), images par seconde, images lentes (> 50 ms), dessins par image,
# objets dessinés, mémoire. Synchronisation verticale coupée pour mesurer le vrai temps de calcul.
const Generation = preload("res://scripts/world_generation.gd")
const TreeParts = preload("res://scripts/tree_parts.gd")
const Inventory = preload("res://scripts/inventory.gd")

func _initialize() -> void:
	call_deferred("_run")

func report(key: String, value: Variant) -> void:
	print("MESURE %s = %s" % [key, str(value)])

# Temps de chaque image (ms) pendant « count » images.
func sample(count: int, on_frame: Callable = Callable()) -> Array:
	var times := []
	var last := Time.get_ticks_usec()
	for index in range(count):
		if on_frame.is_valid():
			on_frame.call(index)
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	return times

func summary(prefix: String, times: Array) -> void:
	var sorted := times.duplicate()
	sorted.sort()
	var total := 0.0
	for value in times:
		total += value
	report(prefix + ".fps_moyen", snappedf(1000.0 * times.size() / maxf(total, 0.001), 0.1))
	report(prefix + ".ms_mediane", snappedf(sorted[sorted.size() / 2], 0.01))
	report(prefix + ".ms_p95", snappedf(sorted[int(sorted.size() * 0.95)], 0.01))
	report(prefix + ".ms_max", snappedf(sorted[-1], 0.01))
	report(prefix + ".images_lentes_50ms", times.filter(func(value): return value > 50.0).size())

func render_stats(prefix: String) -> void:
	report(prefix + ".dessins", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	report(prefix + ".objets", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	report(prefix + ".triangles", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	report(prefix + ".memoire_mo", snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1))
	report(prefix + ".memoire_video_mo", snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1))

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var which := OS.get_environment("MESURE")
	if which.is_empty() or which == "accueil":
		await measure_menu()
	if which.is_empty() or which == "monde":
		await measure_world()
	quit(0)

# Accueil : du chargement de la scène des menus à la première image, puis les 3 premières secondes.
func measure_menu() -> void:
	var start := Time.get_ticks_usec()
	var scene: PackedScene = load("res://scenes/main.tscn")
	report("accueil.chargement_scene_ms", (Time.get_ticks_usec() - start) / 1000.0)
	var made := Time.get_ticks_usec()
	var app := scene.instantiate()
	root.add_child(app)
	# Les réglages du jeu remettent la limite d'images : on la recoupe.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	report("accueil.creation_ms", (Time.get_ticks_usec() - made) / 1000.0)
	await process_frame
	report("accueil.premiere_image_ms", (Time.get_ticks_usec() - start) / 1000.0)
	var times: Array = await sample(180)
	summary("accueil", times)
	report("accueil.etapes_lentes", str(app.showcase.slow_steps))
	render_stats("accueil")
	root.remove_child(app)
	app.queue_free()
	await process_frame

# Monde : ouverture, puis marche à travers la forêt la plus dense des environs, puis une première coupe.
func measure_world() -> void:
	var graine := int(OS.get_environment("GRAINE")) if not OS.get_environment("GRAINE").is_empty() else 1864659616
	var start := Time.get_ticks_usec()
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	world.generation_options = Generation.defaults()
	world.terrain_seed = graine
	world.game_mode = Inventory.CREATIVE
	root.add_child(world)
	report("monde.creation_ms", (Time.get_ticks_usec() - start) / 1000.0)
	await process_frame
	report("monde.premiere_image_ms", (Time.get_ticks_usec() - start) / 1000.0)
	var opening: Array = await sample(240)
	summary("monde.ouverture", opening)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	# La forêt de pins la plus proche du départ (sinon la forêt la plus proche) : on la traverse par son centre.
	var nearest := {}
	for forest in world.terrain.forests():
		var pine: bool = forest.kind == world.terrain.FOREST_PINE
		var distance: float = (forest.center as Vector2).length() - (10000.0 if pine else 0.0)
		if nearest.is_empty() or distance < nearest.distance:
			nearest = {"forest": forest, "distance": distance}
	var forest: Dictionary = nearest.forest
	report("foret.pins", forest.kind == world.terrain.FOREST_PINE)
	report("foret.rayon_m", snappedf(forest.radius, 0.1))
	var center := Vector3(forest.center.x, 0.0, forest.center.y)
	var from := center - Vector3(forest.radius + 10.0, 0.0, 0.0)
	player.global_position = Vector3(from.x, world.terrain.height_at(from.x, from.z) + 2.0, from.z)
	player.rotation.y = -PI * 0.5
	var settle: Array = await sample(300)
	summary("foret.arrivee", settle)
	# Traversée à 4 m/s (une image sur 60 de seconde, quelle que soit la vitesse réelle : même chemin à chaque mesure).
	var length: float = (forest.radius + 10.0) * 2.0
	var steps := int(length / 4.0 * 60.0)
	var walk := func(index: int) -> void:
		var x: float = from.x + index * length / steps
		player.global_position = Vector3(x, world.terrain.height_at(x, from.z) + 1.0, from.z)
	world.perf = {}
	world.perf_on = true
	var walking: Array = await sample(steps, walk)
	world.perf_on = false
	summary("foret.marche", walking)
	# Temps par tâche du monde pendant la traversée (total, plus long, nombre de fois > 20 ms).
	var names: Array = world.perf.keys()
	names.sort_custom(func(a, b): return world.perf[a].total > world.perf[b].total)
	for name in names:
		report("taches." + name, "total %.0f ms, max %.1f ms, lentes %d" % [world.perf[name].total, world.perf[name].max, world.perf[name].lentes])
	report("surfaces_lentes", str(world.perf_slow.slice(0, 12)))
	# Même zone, trois fois de suite (tout déjà en mémoire) : coût propre du calcul de surface, en jeu.
	if not world.perf_slow.is_empty():
		var zone: Vector3i = world.perf_slow[0][0]
		var again := []
		for repeat in range(3):
			var at := Time.get_ticks_usec()
			world.terrain.zone_surface(zone)
			again.append(snappedf((Time.get_ticks_usec() - at) / 1000.0, 0.1))
		report("surface_repetee_ms", str(again))
	player.global_position = Vector3(center.x, world.terrain.height_at(center.x, center.z) + 1.0, center.z)
	await sample(30)
	render_stats("foret")
	# Première coupe : squelette du modèle (froid) puis la coupe.
	var tree: Node3D = null
	for node in world.column_objects.get(world._player_column(), []):
		if is_instance_valid(node) and node.is_in_group("trees") and node.has_meta("kind"):
			tree = node
			break
	if tree != null:
		var kind := int(tree.get_meta("kind"))
		var size := int(tree.get_meta("size"))
		var form := int(tree.get_meta("form"))
		var cold := Time.get_ticks_usec()
		var skeleton: Dictionary = TreeParts.skeleton(kind, size, form)
		report("coupe.squelette_ms", (Time.get_ticks_usec() - cold) / 1000.0)
		var trunk := 0
		for number in range(skeleton.pieces.size()):
			if skeleton.pieces[number].root and skeleton.pieces[number].length > skeleton.pieces[trunk].length:
				trunk = number
		var cut := Time.get_ticks_usec()
		world.cut_wood(tree, trunk, minf(skeleton.pieces[trunk].length * 0.4, 1.4), tree.global_position)
		report("coupe.couper_ms", (Time.get_ticks_usec() - cut) / 1000.0)
		var after: Array = await sample(200)
		summary("coupe.apres", after)
	root.remove_child(world)
	world.queue_free()
	await process_frame
