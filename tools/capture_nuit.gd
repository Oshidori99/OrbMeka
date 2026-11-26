extends SceneTree
# 0.0.8.43 : captures de la nuit (pleine lune, nouvelle lune) et du jour, regard vers la lune. Fenêtre hors écran, sans
# clavier ni souris :
#   & '<Godot console>' --path . --position 20000,20000 --resolution 640x360 --script res://tools/capture_nuit.gd -- <dossier>
const DayNight = preload("res://scripts/day_night.gd")

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

func shot(world: Node3D, folder: String, name: String, minutes: float, day: int) -> void:
	world.day_count = day
	world.day_time = minutes
	world._update_day(0.0)
	world.apply_day_sky()
	var toward: Vector3 = world.sun_light.global_basis.z.normalized()
	world.player.camera.look_at(world.player.camera.global_position + Vector3(toward.x, maxf(toward.y, 0.15), toward.z) * 10.0)
	await frames(40)
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
	print("CAPTURE ", name, " lune ", DayNight.moon_name(DayNight.moon_phase(day, minutes, 28)))

func _run() -> void:
	var folder: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else OS.get_user_data_dir()
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await frames(120)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	world.player.set_physics_process(false)
	# Pleine lune : phase 0,5 (MOON_START 0,15 : jour 10 environ à minuit).
	var full := int(round((0.5 - DayNight.MOON_START) * 28.0))
	await shot(world, folder, "nuit_pleine_lune", 60.0, full)
	await shot(world, folder, "nuit_croissant", 60.0, 0)
	await shot(world, folder, "nuit_nouvelle_lune", 60.0, int(round((1.0 - DayNight.MOON_START) * 28.0)))
	await shot(world, folder, "jour", 720.0, 0)
	for label in ["jour", "nuit"]:
		world.day_time = 720.0 if label == "jour" else 60.0
		world._update_day(0.0)
		await frames(60)
		var start := Time.get_ticks_usec()
		for index in range(240):
			await process_frame
		print("MESURE ", label, " images par seconde ", snappedf(240.0 / ((Time.get_ticks_usec() - start) / 1000000.0), 0.1))
	quit(0)
