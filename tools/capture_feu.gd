extends SceneTree
# 0.0.8.44 : capture de nuit (nouvelle lune) : un feu de camp allumé devant soi, une torche forte allumée en main ; puis
# images par seconde avec et sans le feu. Fenêtre hors écran, sans clavier ni souris :
#   & '<Godot console>' --path . --position 20000,20000 --resolution 640x360 --script res://tools/capture_feu.gd -- <dossier>
const DayNight = preload("res://scripts/day_night.gd")
const Inventory = preload("res://scripts/inventory.gd")

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

func fps() -> float:
	var start := Time.get_ticks_usec()
	for index in range(240):
		await process_frame
	return snappedf(240.0 / ((Time.get_ticks_usec() - start) / 1000000.0), 0.1)

func _run() -> void:
	var folder: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else OS.get_user_data_dir()
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await frames(120)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	world.player.set_physics_process(false)
	world.day_count = int(round((1.0 - DayNight.MOON_START) * 28.0))
	world.day_time = 60.0
	world._update_day(0.0)
	world.apply_day_sky()
	var ahead: Vector3 = world.player.global_position - world.player.global_transform.basis.z * 2.5
	ahead.y = world._rest_height(ahead)
	await frames(30)
	print("MESURE nuit sans feu images par seconde ", await fps())
	world.ground.drop({"objet": "feu_camp", "allume": 1, "brule": 600.0, "poids": 3000.0}, ahead + Vector3.UP * 0.2, ahead, world._rest_height, 0.0)
	world.inventory.set_mode(Inventory.CREATIVE)
	world.inventory._store().bar[0] = {"objet": "torche_forte", "pile": [{"essence": 2, "epaisseur": 3.4, "fin": 2.8, "longueur": 0.55, "allume": 1, "brule": 300.0, "poids": 300.0}]}
	world.inventory.select(0)
	world.inventory.changed.emit()
	world.player.camera.look_at(ahead + Vector3.UP * 0.3)
	await frames(60)
	root.get_texture().get_image().save_png(folder.path_join("nuit_feu_torche.png"))
	print("CAPTURE nuit_feu_torche")
	print("MESURE nuit avec feu et torche images par seconde ", await fps())
	quit(0)
