extends SceneTree
# 0.0.8.14 : mémoire dans la durée (fuites, mémoires de calcul qui grossissent sans limite), à lancer AVEC fenêtre, hors de
# l'écran :
#   & '<Godot console>' --path . --position 20000,20000 --resolution 1280x720 [--rendering-method gl_compatibility] --script res://tools/mesure_memoire.gd
# Variables : QUALITE (performance, balanced, beauty ; défaut balanced, valeurs du PC), TOURS (tours du monde en vol, défaut 2),
# VITESSE (m/s, défaut 15 : vol rapide).
# Ouvre un monde neuf (graine 3463503054) par l'écran de chargement, puis vole en carré autour du monde (près des bords), et
# imprime toutes les 10 s : mémoire de Godot, mémoire vidéo, objets (et objets orphelins : fuites), puis à la fin la taille de
# chaque mémoire du monde et du terrain (dictionnaires et listes), pour voir ce qui grossit sans jamais être libéré.
const Generation = preload("res://scripts/world_generation.gd")
const UserSettings = preload("res://scripts/user_settings.gd")

func _initialize() -> void:
	# 0.0.8.14 : jamais la souris de l'utilisateur capturée (un monde ouvert la capture) : rendue libre à chaque image.
	process_frame.connect(func() -> void:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	# 0.0.8.14 : fenêtre de mesure (hors écran) : ne prend jamais le focus et ignore le clavier (sinon, les touches tapées
	# ailleurs par l'utilisateur arrivaient dans le jeu : pause, fabrication, et la mesure était fausse).
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.gui_disable_input = true
	root.set_disable_input(true)
	call_deferred("_run")

func report(key: String, value: Variant) -> void:
	print("MESURE %s = %s" % [key, str(value)])

func _mo(monitor: int) -> float:
	return snappedf(Performance.get_monitor(monitor) / 1048576.0, 0.1)

func _sizes(object: Object) -> Dictionary:
	var sizes := {}
	for property in object.get_property_list():
		if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value: Variant = object.get(property.name)
		if value is Dictionary or value is Array:
			sizes[property.name] = value.size()
	return sizes

func _sample(label: String, world: Node3D, start: int) -> void:
	report(label, "%3d s : Godot %.1f Mo, vidéo %.1f Mo (textures %.1f, tampons %.1f), objets %d (ressources %d, nœuds %d, orphelins %d), colonnes %d, lointain %d (relevés %d)" % [
		(Time.get_ticks_msec() - start) / 1000,
		_mo(Performance.MEMORY_STATIC), _mo(Performance.RENDER_VIDEO_MEM_USED), _mo(Performance.RENDER_TEXTURE_MEM_USED), _mo(Performance.RENDER_BUFFER_MEM_USED),
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		world.built_columns.size(), world.far_tiles.size(), world.far_surveys.size()] + " ; joueur %s, vue %s" % [str(Vector2i(world.player.global_position.x, world.player.global_position.z)), str(world.view_center)])

func _run() -> void:
	var fixture := "user://mesure-memoire-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = UserSettings.new(fixture)
	# Mesure : jamais le message « qualité conseillée » (il met le jeu en pause sur un PC lent).
	app.settings.quality_hint_done = true
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var quality := OS.get_environment("QUALITE") if not OS.get_environment("QUALITE").is_empty() else "balanced"
	app.settings.values.merge(UserSettings.preset_values(quality, RenderingServer.get_current_rendering_method() == "gl_compatibility"), true)
	app.settings.values.quality = quality
	root.add_child(app)
	for wait in range(20):
		await process_frame
	report("depart_accueil", "Godot %.1f Mo, vidéo %.1f Mo, objets %d" % [_mo(Performance.MEMORY_STATIC), _mo(Performance.RENDER_VIDEO_MEM_USED), Performance.get_monitor(Performance.OBJECT_COUNT)])
	var item: Dictionary = app.catalog.create_world("Memoire", "3463503054", "default", false, Generation.defaults())
	app.open_world_loading(item.id)
	while not (is_instance_valid(app.active_world) and app.page == "playing"):
		await process_frame
	var world: Node3D = app.active_world
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	var start := Time.get_ticks_msec()
	_sample("echantillon", world, start)
	var terrain_start := _sizes(world.terrain)
	var world_start := _sizes(world)
	# Vol en carré près des bords du monde (le monde fait 768 m ; 300 m du centre).
	var corners := [Vector2(-300, -300), Vector2(300, -300), Vector2(300, 300), Vector2(-300, 300)]
	var speed := float(OS.get_environment("VITESSE")) if not OS.get_environment("VITESSE").is_empty() else 15.0
	var laps := int(OS.get_environment("TOURS")) if not OS.get_environment("TOURS").is_empty() else 2
	var at := Vector2(player.global_position.x, player.global_position.z)
	var next_sample := Time.get_ticks_msec() + 10000
	var last := Time.get_ticks_usec()
	for lap in range(laps):
		for corner: Vector2 in corners:
			while at.distance_to(corner) > 1.0:
				var now := Time.get_ticks_usec()
				var step := minf(speed * (now - last) / 1_000_000.0, 2.0)
				last = now
				at = at.move_toward(corner, step)
				player.global_position = Vector3(at.x, world.terrain.height_at(at.x, at.y) + 4.0, at.y)
				await process_frame
				if Time.get_ticks_msec() >= next_sample:
					next_sample += 10000
					_sample("echantillon", world, start)
		report("tour_%d" % (lap + 1), "fini")
		_sample("echantillon", world, start)
	# Mémoires du monde et du terrain : taille au départ → à la fin (celles qui grossissent).
	for pair in [["terrain", world.terrain, terrain_start], ["monde", world, world_start]]:
		var now_sizes := _sizes(pair[1])
		var names: Array = now_sizes.keys()
		names.sort_custom(func(a, b): return now_sizes[a] > now_sizes[b])
		for name in names.slice(0, 18):
			report("taille.%s.%s" % [pair[0], name], "%d → %d" % [pair[2].get(name, 0), now_sizes[name]])
	app.return_to_worlds()
	for wait in range(10):
		await process_frame
	report("apres_retour_accueil", "Godot %.1f Mo, vidéo %.1f Mo, objets %d, orphelins %d" % [_mo(Performance.MEMORY_STATIC), _mo(Performance.RENDER_VIDEO_MEM_USED), Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	quit(0)
