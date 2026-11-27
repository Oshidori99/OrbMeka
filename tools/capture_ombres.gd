extends SceneTree
# 0.0.8.51 (lot Ombres) : mêmes scènes avant et après les changements d'ombres, avec captures et mesures :
# - nuit_feu : nouvelle lune, un feu de camp allumé entre deux arbres, du bois au sol, une torche en main ;
# - galerie : une salle creusée à 6 m sous terre, un pilier au milieu, des cailloux et du bois au sol, une torche en main ;
# - pleine_lune : nuit de pleine lune, les mêmes arbres ;
# - jour : midi, les mêmes arbres (pour comparer le coût des ombres du soleil).
# Fenêtre hors écran, sans clavier ni souris (jamais capturée) :
#   & '<Godot console>' --path . --position 20000,20000 --resolution 640x360 --script res://tools/capture_ombres.gd -- <dossier> <étiquette>
# Rendu du Web : ajouter --rendering-method gl_compatibility. Variable QUALITE : performance, balanced (défaut) ou beauty.
const DayNight = preload("res://scripts/day_night.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Trees = preload("res://scripts/trees.gd")
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
const UserSettings = preload("res://scripts/user_settings.gd")

var w: Node3D

func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.gui_disable_input = true
	root.set_disable_input(true)
	process_frame.connect(func() -> void:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	call_deferred("_run")

func frames(count: int) -> void:
	for index in range(count):
		await process_frame

# Carte graphique (ms), images par seconde, dessins, sur 120 images.
func measure(label: String) -> void:
	var viewport := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	await frames(10)
	var gpu := 0.0
	var draws := 0.0
	var start := Time.get_ticks_usec()
	for index in range(120):
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var fps := 120.0 / ((Time.get_ticks_usec() - start) / 1000000.0)
	print("MESURE %s : carte graphique %.2f ms, %.1f images par seconde, %d dessins" % [label, gpu / 120.0, fps, roundi(draws / 120.0)])

func shot(folder: String, tag: String, name: String) -> void:
	await frames(45)
	root.get_texture().get_image().save_png(folder.path_join("%s_%s.png" % [name, tag]))
	print("CAPTURE ", name)
	await measure(name)

func set_time(minutes: float, day: int) -> void:
	w.day_count = day
	w.day_time = minutes
	# Le ciel visible d'ici tout de suite (en jeu : en une seconde environ).
	w._sky_target = w.sky_visible_share(w.player.camera.global_position)
	w.sky_open = w._sky_target
	w._update_day(0.0)
	w.apply_day_sky()
	if w.has_method("_apply_light_shadows"):
		w._apply_light_shadows()

func plant(id: String, kind: int, size: int, at: Vector3) -> void:
	var tree: Node3D = Trees.tree_body(kind, size)
	tree.set_meta("id", id)
	var column: Vector2i = w._player_column()
	tree.set_meta("column", column)
	w._rocks_parent().add_child(tree)
	tree.global_position = Vector3(at.x, w.terrain.height_at(at.x, at.z) - 0.05, at.z)
	w.column_objects[column] = w.column_objects.get(column, []) + [tree]

func hold(id: String) -> void:
	w.inventory.set_mode(Inventory.CREATIVE)
	var item := {"essence": 1, "epaisseur": 3.0, "fin": 2.6, "longueur": 0.55, "allume": 1, "brule": 600.0, "poids": 260.0}
	w.inventory._store().bar[0] = {"objet": id, "pile": [item]}
	w.inventory.select(0)
	w.inventory.changed.emit()
	if w.has_method("_apply_light_shadows"):
		w._apply_light_shadows()

func drop(item: Dictionary, at: Vector3) -> void:
	w.ground.drop(item, at + Vector3.UP * 0.3, at, w._rest_height, 0.0)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var tag: String = args[1] if args.size() > 1 else "essai"
	w = load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	await frames(120)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var quality := OS.get_environment("QUALITE") if not OS.get_environment("QUALITE").is_empty() else "balanced"
	var preset := UserSettings.preset_values(quality, OS.get_environment("WEB") == "1")
	w.set_shadows(str(preset.shadows))
	if w.has_method("apply_shadow_options"):
		w.apply_shadow_options(str(preset.shadows))
	w.player.set_physics_process(false)
	var start: Vector3 = w.player.global_position
	var ahead := start + Vector3(0.0, 0.0, -4.0)
	ahead.y = w._rest_height(ahead)
	# Nuit, nouvelle lune : un feu entre deux arbres, du bois au sol, une torche en main.
	plant("ombres-arbre-1", Trees.APPLE, 4, ahead + Vector3(-2.6, 0.0, -1.5))
	plant("ombres-arbre-2", Trees.LINDEN, 3, ahead + Vector3(2.4, 0.0, -2.2))
	drop({"objet": "feu_camp", "allume": 1, "brule": 600.0, "poids": 3000.0}, ahead)
	for index in range(5):
		var spot := ahead + Vector3(-1.2 + index * 0.6, 0.0, 1.2 + (index % 2) * 0.4)
		spot.y = w._rest_height(spot)
		drop({"objet": "caillou", "taille": 5} if index % 2 == 0 else {"objet": "branche", "essence": 1, "epaisseur": 4.0, "fin": 3.0, "longueur": 0.9, "poids": 600.0}, spot)
	await create_timer(1.5).timeout
	set_time(60.0, int(round((1.0 - DayNight.MOON_START) * 28.0)))
	# Le feu vu de côté, sans torche en main : les ombres des arbres et du bois partent du feu.
	w.player.global_position = ahead + Vector3(4.5, 0.0, 2.5)
	w.player.global_position.y = w._rest_height(w.player.global_position)
	await frames(10)
	w.player.camera.look_at(ahead + Vector3(-0.5, 0.3, -1.0))
	await shot(folder, tag, "nuit_feu")
	# Torche en main, face à l'arbre : l'herbe derrière son tronc reste dans l'ombre.
	hold("torche")
	w.player.global_position = ahead + Vector3(-2.6, 0.0, 2.2)
	w.player.global_position.y = w._rest_height(w.player.global_position)
	await frames(10)
	w.player.camera.look_at(ahead + Vector3(-2.6, 0.6, -1.5))
	await shot(folder, tag, "nuit_torche")
	# Pleine lune, sans torche en main.
	w.inventory._store().bar[0] = {}
	w.inventory.changed.emit()
	if w.has_method("_apply_light_shadows"):
		w._apply_light_shadows()
	w.player.global_position = start
	await frames(10)
	set_time(60.0, int(round((0.5 - DayNight.MOON_START) * 28.0)))
	w.player.camera.look_at(ahead + Vector3.UP * 0.4)
	await shot(folder, tag, "pleine_lune")
	set_time(720.0, 0)
	await shot(folder, tag, "jour")
	# Galerie : salle de 6 m × 6 m × 2,5 m, 6 m sous terre, un pilier de 1 m au milieu, des cailloux et du bois au sol.
	var center := start + Vector3(14.0, 0.0, 0.0)
	var floor_point := SmoothTerrain.point_of(Vector3(center.x, w.terrain.height_at(center.x, center.z) - 6.0, center.z))
	var dug := []
	for dx in range(-6, 7):
		for dz in range(-6, 7):
			if absi(dx) <= 1 and absi(dz) <= 1:
				continue
			for dy in range(0, 5):
				var point := floor_point + Vector3i(dx, dy, dz)
				if w.terrain.density(point) > 0.0:
					w.terrain.set_density(point, SmoothTerrain.DUG)
					dug.append(point)
	w._refresh_terrain(dug)
	var room_floor := Vector3(floor_point) * SmoothTerrain.STEP
	w.player.global_position = room_floor + Vector3(-2.2, 0.0, -2.2)
	await frames(90)
	w.finish_terrain()
	for index in range(6):
		var spot := room_floor + Vector3(0.9 + (index % 3) * 0.5, 0.3, 1.0 + (index / 3) * 0.6)
		drop({"objet": "caillou", "taille": 4 + index % 3} if index % 2 == 0 else {"objet": "branche", "essence": 2, "epaisseur": 3.0, "fin": 2.0, "longueur": 0.7, "poids": 300.0}, spot)
	set_time(720.0, 0)
	hold("torche")
	await frames(120)
	w.player.camera.look_at(room_floor + Vector3(1.6, 0.6, 1.8))
	await shot(folder, tag, "galerie")
	# Une torche posée au sol de l'autre côté du pilier, rien en main : l'ombre du pilier sur le sol et le mur.
	w.inventory._store().bar[0] = {}
	w.inventory.changed.emit()
	if w.has_method("_apply_light_shadows"):
		w._apply_light_shadows()
	drop({"objet": "torche", "essence": 1, "epaisseur": 3.0, "fin": 2.6, "longueur": 0.55, "allume": 1, "brule": 600.0, "poids": 260.0}, room_floor + Vector3(1.4, 0.2, -1.6))
	w.player.global_position = room_floor + Vector3(-2.4, 0.0, 0.4)
	# La torche lâchée tombe (environ une seconde) avant d'éclairer.
	await create_timer(1.5).timeout
	await frames(60)
	w.player.camera.look_at(room_floor + Vector3(1.2, 0.5, 1.6))
	await shot(folder, tag, "galerie_posee")
	quit(0)
