extends SceneTree
# 0.0.8.11 : ouverture d'un monde comme sur le Web (écran de chargement, puis monde préparé derrière), à lancer AVEC fenêtre,
# hors de l'écran, en rendu Compatibility (celui du Web) :
#   & '<Godot console>' --path . --position 20000,20000 --resolution 1280x720 --rendering-method gl_compatibility --script res://tools/mesure_ouverture.gd
# Variables : QUALITE (performance, balanced, beauty ; défaut performance, valeurs du Web), GRAINE (défaut 3463503054),
# MODE (survie ou creatif, défaut creatif), FOIS (ouvertures du même monde, défaut 2 : neuf puis existant).
# Imprime des lignes « MESURE clé = valeur » : durée de chaque étape, images lentes, temps par tâche du monde.
const Generation = preload("res://scripts/world_generation.gd")
const UserSettings = preload("res://scripts/user_settings.gd")

func _initialize() -> void:
	call_deferred("_run")

func report(key: String, value: Variant) -> void:
	print("MESURE %s = %s" % [key, str(value)])

func _run() -> void:
	var fixture := "user://mesure-ouverture-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = UserSettings.new(fixture)
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var quality := OS.get_environment("QUALITE") if not OS.get_environment("QUALITE").is_empty() else "performance"
	app.settings.values.merge(UserSettings.preset_values(quality, true), true)
	app.settings.values.quality = quality
	root.add_child(app)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for wait in range(30):
		await process_frame
	var seed := OS.get_environment("GRAINE") if not OS.get_environment("GRAINE").is_empty() else "3463503054"
	var survival := OS.get_environment("MODE") == "survie"
	var item: Dictionary = app.catalog.create_world("Mesure", seed, "default", false, Generation.defaults())
	if item.has("id") and app.catalog.has_method("set_game_mode"):
		app.catalog.set_game_mode(item.id, "survival" if survival else "creative")
	elif survival:
		item.game_mode = "survival"
	var times := int(OS.get_environment("FOIS")) if not OS.get_environment("FOIS").is_empty() else 2
	report("compatibilite", RenderingServer.get_current_rendering_method())
	for round in range(times):
		await _open_once(app, item.id, "ouverture%d" % (round + 1))
	quit(0)

func _open_once(app: Control, id: String, prefix: String) -> void:
	var start := Time.get_ticks_usec()
	app.open_world_loading(id)
	var frames := []
	var last := start
	var seed_done := 0
	var world_made := 0
	var task_start := 0
	while (not is_instance_valid(app.active_world) or app.page != "playing") and Time.get_ticks_usec() - start < 60_000_000:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		if now - last > 150000:
			var world_now: Node3D = app.active_world
			report(prefix + ".image_lente", "%.0f ms à %.2f s (%s, préchauffage restant %s)" % [(now - last) / 1000.0, (now - start) / 1_000_000.0, "monde" if is_instance_valid(world_now) else "graine", str(world_now.warm_pending.size()) if is_instance_valid(world_now) else "-"])
		last = now
		if seed_done == 0 and app.loading_ready:
			seed_done = now
		if world_made == 0 and is_instance_valid(app.active_world):
			world_made = now
			app.active_world.perf = {}
			app.active_world.perf_on = true
	var end := Time.get_ticks_usec()
	report(prefix + ".total_s", snappedf((end - start) / 1_000_000.0, 0.01))
	report(prefix + ".graine_s", snappedf((seed_done - start) / 1_000_000.0, 0.01))
	report(prefix + ".monde_cree_s", snappedf((world_made - start) / 1_000_000.0, 0.01))
	report(prefix + ".derriere_ecran_s", snappedf((end - world_made) / 1_000_000.0, 0.01))
	var sorted := frames.duplicate()
	sorted.sort()
	report(prefix + ".images", frames.size())
	report(prefix + ".pires_images_ms", str(sorted.slice(-6).map(func(value): return snappedf(value, 0.1))))
	var world: Node3D = app.active_world
	if is_instance_valid(world):
		world.perf_on = false
		report(prefix + ".colonnes", "%d construites sur %d" % [world.built_columns.size(), world.shown_columns.size()])
		var names: Array = world.perf.keys()
		names.sort_custom(func(a, b): return world.perf[a].total > world.perf[b].total)
		for name in names:
			report(prefix + ".taches." + name, "total %.0f ms, max %.1f ms, lentes %d" % [world.perf[name].total, world.perf[name].max, world.perf[name].lentes])
		report(prefix + ".objets_3d", world.find_children("*", "GeometryInstance3D", true, false).size())
		report(prefix + ".lumieres", world.find_children("*", "Light3D", true, false).size())
		report(prefix + ".couches_camera", world.player.camera.cull_mask)
		report(prefix + ".memoire_mo", snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1))
		report(prefix + ".fils_de_calcul", "%d prêts, %d zones faites par eux" % [world.terrain_workers.ready_count() if world.terrain_workers != null else 0, world.worker_built])
		report(prefix + ".interface_preparee", "%d (0 : faite), fabrication créée : %s" % [world.ui_prewarm_left, str(is_instance_valid(world.crafting_ui))])
	# Quelques secondes de jeu, puis retour aux mondes.
	var after := []
	last = Time.get_ticks_usec()
	for index in range(180):
		await process_frame
		var now := Time.get_ticks_usec()
		after.append((now - last) / 1000.0)
		last = now
	after.sort()
	report(prefix + ".apres_3s_pires_ms", str(after.slice(-5).map(func(value): return snappedf(value, 0.1))))
	if is_instance_valid(world):
		report(prefix + ".couches_camera_apres", "%d (préchauffage fini : %s)" % [world.player.camera.cull_mask, str(world.warm_node == null)])
	app.return_to_worlds()
	for wait in range(10):
		await process_frame
