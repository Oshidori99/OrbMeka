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
# 0.0.7.21 : aussi, par image, le calcul du jeu (processeur : _process, physique) et l'affichage (processeur et carte
# graphique), moyennés dans last_split.
var last_split := {}

func sample(count: int, on_frame: Callable = Callable()) -> Array:
	var times := []
	var split := {"jeu": 0.0, "physique": 0.0, "rendu_cpu": 0.0, "rendu_gpu": 0.0}
	var viewport := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var last := Time.get_ticks_usec()
	for index in range(count):
		if on_frame.is_valid():
			on_frame.call(index)
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		split.jeu += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		split.physique += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		split.rendu_cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport) + RenderingServer.get_frame_setup_time_cpu()
		split.rendu_gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
	for key in split:
		split[key] = snappedf(split[key] / maxf(count, 1), 0.01)
	last_split = split
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
	report(prefix + ".images_sous_100fps", times.filter(func(value): return value > 10.0).size())
	report(prefix + ".temps_ms", str(last_split))

func render_stats(prefix: String) -> void:
	report(prefix + ".dessins", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	report(prefix + ".objets", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	report(prefix + ".triangles", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	report(prefix + ".memoire_mo", snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1))
	report(prefix + ".memoire_video_mo", snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1))

# 0.0.7.21 : ce qui peut être dessiné (dans le champ de la caméra, à portée de sa distance d'affichage), par sorte
# (nom du nœud ou de son parent) : surfaces (un dessin chacune, sans compter les ombres).
func draw_breakdown(prefix: String, world: Node3D) -> void:
	var camera: Camera3D = world.player.camera
	var counts := {}
	for node: GeometryInstance3D in world.find_children("*", "GeometryInstance3D", true, false):
		if not node.is_visible_in_tree():
			continue
		var box: AABB = node.get_aabb()
		var center: Vector3 = node.global_transform * box.get_center()
		var distance := camera.global_position.distance_to(center)
		if node.visibility_range_end > 0.0 and distance > node.visibility_range_end + box.size.length():
			continue
		if distance < node.visibility_range_begin - box.size.length():
			continue
		if not camera.is_position_in_frustum(center) and distance > box.size.length():
			continue
		var mesh: Mesh = node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else (node.mesh if node is MeshInstance3D else null)
		var surfaces := mesh.get_surface_count() if mesh != null else 1
		var name := str(node.name).rstrip("0123456789@_")
		if name.begins_with("@") or name in ["Detail", "Loin", "Ombre", "Coupe"]:
			name = str(node.get_parent().name).rstrip("0123456789@_") + "/" + name
		if name.begins_with("Terrain") or name.begins_with("Lointain"):
			name = name.left(8)
		var look: Material = node.material_override if node.material_override != null else (mesh.surface_get_material(0) if mesh != null and mesh.get_surface_count() > 0 else null)
		var look_name: String = "" if look == null else (look.resource_name if not look.resource_name.is_empty() else (str(look.albedo_texture.resource_path.get_file()) if look is BaseMaterial3D and look.albedo_texture != null else (look.shader.resource_path.get_file() if look is ShaderMaterial and look.shader != null else look.get_class())))
		var kind := "%s %s %s" % [node.get_class().replace("Instance3D", ""), name.left(20), look_name.left(22)]
		counts[kind] = counts.get(kind, 0) + surfaces
	var sorted := counts.keys()
	sorted.sort_custom(func(a, b): return counts[a] > counts[b])
	for key in sorted.slice(0, 14):
		report(prefix + ".dessins_par_sorte." + key.replace(" ", "_"), counts[key])

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
	report("foret.files_apres_marche", "terrain %d, lointain %d, arbres %d" % [world.terrain_queue.size(), world.far_queue.size(), world.tree_queue.size()])
	# 0.0.7.21 : vol à 15 m/s pendant 6 s (temps réel) : images, et colonnes à 2 zones ou moins du joueur pas encore
	# construites (le monde suit-il ?).
	var flight_times := []
	var unbuilt_max := 0
	var unbuilt_frames := 0
	var flight_start := Time.get_ticks_usec()
	var last_frame := flight_start
	var flight_from: Vector3 = player.global_position
	while Time.get_ticks_usec() - flight_start < 6_000_000:
		var seconds := (Time.get_ticks_usec() - flight_start) / 1_000_000.0
		var fx: float = flight_from.x + 15.0 * seconds
		player.global_position = Vector3(fx, world.terrain.height_at(fx, flight_from.z) + 4.0, flight_from.z)
		await process_frame
		var now := Time.get_ticks_usec()
		flight_times.append((now - last_frame) / 1000.0)
		last_frame = now
		var here: Vector2i = world._player_column()
		var unbuilt := 0
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var column := here + Vector2i(dx, dz)
				if world.shown_columns.has(column) and not world.built_columns.has(column):
					unbuilt += 1
		unbuilt_max = maxi(unbuilt_max, unbuilt)
		if unbuilt > 0:
			unbuilt_frames += 1
	last_split = {}
	summary("vol", flight_times)
	report("vol.colonnes_proches_pas_finies_max", unbuilt_max)
	report("vol.images_avec_colonne_proche_pas_finie", "%d sur %d" % [unbuilt_frames, flight_times.size()])
	# 0.0.7.21 : monde entièrement construit autour (files vides, 20 s au plus), immobile : images et dessins.
	var wait_start := Time.get_ticks_msec()
	while (not world.terrain_queue.is_empty() or not world.far_queue.is_empty() or not world.tree_queue.is_empty()) and Time.get_ticks_msec() - wait_start < 20000:
		await process_frame
	report("complet.attente_s", snappedf((Time.get_ticks_msec() - wait_start) / 1000.0, 0.1))
	summary("complet", await sample(240))
	render_stats("complet")
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
	draw_breakdown("foret", world)
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
