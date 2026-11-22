extends SceneTree
# 0.0.8.14 (rapport d'optimisation) : ce que coûte chaque sorte de chose à la carte graphique, à 4 endroits (départ, forêt,
# bord du lac, rivière) : temps de la carte graphique avec tout, puis sans chaque sorte (scripts/diagnostic.gd) et sans
# chaque effet. À lancer AVEC fenêtre, hors de l'écran, en rendu du Web de préférence :
#   & '<Godot console>' --path . --position 20000,20000 --resolution 2560x1440 --rendering-method gl_compatibility --script res://tools/mesure_gpu.gd
# Variables : QUALITE (performance, balanced, beauty ; défaut balanced, valeurs du Web en rendu Compatibility), IMAGES (images
# mesurées par essai, défaut 120). SORTES, EFFETS : seulement ceux-là (listes séparées par des virgules) ; ECHELLE :
# échelle du rendu 3D (défaut 2). Une grande fenêtre grossit les coûts par point d'écran (la carte du PC est très rapide).
const Generation = preload("res://scripts/world_generation.gd")
const UserSettings = preload("res://scripts/user_settings.gd")
const Diagnostic = preload("res://scripts/diagnostic.gd")

var frames := 120

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

# Moyennes sur « frames » images : carte graphique (ms), rendu côté processeur (ms), dessins, triangles.
func _measure() -> Dictionary:
	var viewport := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	for wait in range(6):
		await process_frame
	var gpu := 0.0
	var cpu := 0.0
	var draws := 0.0
	var triangles := 0.0
	for index in range(frames):
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		triangles += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	return {"gpu": gpu / frames, "cpu": cpu / frames, "dessins": draws / frames, "triangles": triangles / frames}

func _wait_built(world: Node3D) -> void:
	# La vue suit le joueur à l'image suivante : attendre qu'elle ait commencé, que tout soit construit, puis que le nombre de
	# dessins ne bouge plus pendant 30 images (herbe, plantes, arbres, lointain finis).
	for wait in range(20):
		await process_frame
	var start := Time.get_ticks_msec()
	var same := 0
	var last := -1.0
	while Time.get_ticks_msec() - start < 40000:
		await process_frame
		var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var busy: bool = not world.terrain_queue.is_empty() or not world.far_queue.is_empty() or not world.tree_queue.is_empty() or not world.detail_queue.is_empty()
		same = same + 1 if draws == last and not busy else 0
		last = draws
		if same >= 30:
			break
	if same < 30:
		var workers: RefCounted = world.terrain_workers
		report("attente_trop_longue", "files terrain %d, lointain %d, arbres %d, détails %d ; colonnes envoyées %d, carrés du lointain envoyés %d ; fils prêts %d, travaux en cours %d" % [world.terrain_queue.size(), world.far_queue.size(), world.tree_queue.size(), world.detail_queue.size(), world.worker_columns.size(), world.worker_far.size(), workers.ready_count() if workers != null else -1, workers.pending_count() if workers != null else -1])

# Avec tout, sans (apply), avec tout de nouveau (undo) : l'écart avec la moyenne des deux mesures « avec tout » (la carte du PC
# change de vitesse d'elle-même : une seule mesure de référence dérivait).
func _pair(apply: Callable, undo: Callable) -> Dictionary:
	var before: Dictionary = await _measure()
	apply.call()
	var without: Dictionary = await _measure()
	undo.call()
	var after: Dictionary = await _measure()
	var result := {}
	for key in before:
		result[key] = (before[key] + after[key]) * 0.5 - without[key]
	result.base = (before.gpu + after.gpu) * 0.5
	return result

func _spot(world: Node3D, name: String) -> void:
	var base: Dictionary = await _measure()
	report("%s.tout" % name, "GPU %.2f ms, rendu processeur %.2f ms, %d dessins, %d triangles" % [base.gpu, base.cpu, base.dessins, base.triangles])
	# APPLIQUER=a,b,c : réglages plus légers ajoutés un à un (cumulés), mesure après chacun, puis tout remis.
	var cumulative := OS.get_environment("APPLIQUER").split(",", false)
	if not cumulative.is_empty():
		var applied := []
		for variant in cumulative:
			Diagnostic.set_effect(world, variant, false)
			applied.append(variant)
			var now: Dictionary = await _measure()
			report("%s.cumul_%s" % [name, "+".join(applied)], "GPU %.2f ms (%d images/s possibles), %d dessins" % [now.gpu, roundi(1000.0 / maxf(now.gpu, 0.001)), now.dessins])
		Diagnostic.restore_all(world)
		return
	report("%s.choses" % name, str(Diagnostic.counts(world)))
	var only_sorts := OS.get_environment("SORTES").split(",", false)
	var only_effects := OS.get_environment("EFFETS").split(",", false)
	for sort in Diagnostic.SORTS:
		if not only_sorts.is_empty() and not sort in only_sorts:
			continue
		var gain: Dictionary = await _pair(func(): Diagnostic.show_sort(world, sort, false), func(): Diagnostic.show_sort(world, sort, true))
		report("%s.sans_%s" % [name, sort], "GPU −%.2f ms (%d %%), rendu processeur −%.2f ms, −%d dessins, −%d triangles" % [gain.gpu, roundi(100.0 * gain.gpu / maxf(gain.base, 0.001)), gain.cpu, gain.dessins, gain.triangles])
	for effect in Diagnostic.EFFECTS + Diagnostic.VARIANTS:
		if not only_effects.is_empty() and not effect in only_effects:
			continue
		var gain: Dictionary = await _pair(func(): Diagnostic.set_effect(world, effect, false), func(): Diagnostic.set_effect(world, effect, true))
		report("%s.%s_%s" % [name, "avec" if effect in Diagnostic.VARIANTS else "sans", effect], "GPU −%.2f ms (%d %%), −%d dessins, −%d triangles" % [gain.gpu, roundi(100.0 * gain.gpu / maxf(gain.base, 0.001)), gain.dessins, gain.triangles])
	Diagnostic.restore_all(world)

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	frames = int(OS.get_environment("IMAGES")) if not OS.get_environment("IMAGES").is_empty() else 120
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var fixture := "user://mesure-gpu-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = UserSettings.new(fixture)
	# Mesure : jamais le message « qualité conseillée » (il met le jeu en pause sur un PC lent).
	app.settings.quality_hint_done = true
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var quality := OS.get_environment("QUALITE") if not OS.get_environment("QUALITE").is_empty() else "balanced"
	app.settings.values.merge(UserSettings.preset_values(quality, compat), true)
	app.settings.values.quality = quality
	root.add_child(app)
	for wait in range(10):
		await process_frame
	var item: Dictionary = app.catalog.create_world("Carte", "3463503054", "default", false, Generation.defaults())
	app.open_world_loading(item.id)
	while not (is_instance_valid(app.active_world) and app.page == "playing"):
		await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var world: Node3D = app.active_world
	world.player.set_physics_process(false)
	# Rendu plus fin que la fenêtre (ECHELLE, défaut 2) : la carte du PC travaille assez pour que les écarts se voient.
	root.scaling_3d_scale = float(OS.get_environment("ECHELLE")) if not OS.get_environment("ECHELLE").is_empty() else 2.0
	report("rendu", "%s, qualité %s, fenêtre %s, échelle 3D %.1f" % [RenderingServer.get_current_rendering_method(), quality, str(root.size), root.scaling_3d_scale])
	await _wait_built(world)
	# Endroits de mesure : départ (vers le lac), forêt, bord du lac, rivière (scripts/diagnostic.gd).
	for spot in Diagnostic.SPOTS:
		if not Diagnostic.go_to_spot(world, spot):
			continue
		await _wait_built(world)
		await _spot(world, spot)
	app.return_to_worlds()
	for wait in range(5):
		await process_frame
	quit(0)
