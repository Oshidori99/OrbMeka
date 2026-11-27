extends SceneTree
# 0.0.8.58 : le corps vu à la première personne, tête baissée (89° et 72°), pour chaque personnage humain ; puis baissé
# (se baisser) et vu de dos (le corps entier). Fenêtre hors écran, petite, sans clavier ni souris (jamais capturée) :
#   & '<Godot console>' --path . --position 20000,20000 --resolution 480x270 --script res://tools/capture_corps.gd -- <dossier> [personnages]
const Inventory = preload("res://scripts/inventory.gd")

var w: Node3D

func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	root.gui_disable_input = true
	root.set_disable_input(true)
	process_frame.connect(func() -> void:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	call_deferred("_run")

func frames(count: int) -> void:
	for index in range(count):
		await process_frame

func shot(folder: String, name: String) -> void:
	await create_timer(0.3).timeout
	await frames(10)
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
	print("CAPTURE ", name)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var who: Array = args[1].split(",") if args.size() > 1 else ["boy9", "girl9", "boy14", "girl14"]
	w = load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	await frames(120)
	w.player.set_physics_process(false)
	w.day_time = 600.0
	w._update_day(0.0)
	w.set_game_mode(Inventory.SURVIVAL)
	for index in range(Inventory.BAR_SIZE):
		w.inventory._store().bar[index] = {}
	w.inventory.put("bar", 0, {"objet": "caillou", "pile": [{"taille": 3, "forme": 3}]})
	w.inventory.select(1)
	w.apply_held()
	for id in who:
		w.player.character = id
		w.player.body_key = ""
		w.player.sync_body()
		w.player.set_view("first")
		w.player.camera.rotation.x = deg_to_rad(-89.0)
		w.player._update_rigs(0.016)
		await shot(folder, "corps_%s_89" % id)
		w.player.camera.rotation.x = deg_to_rad(-72.0)
		await shot(folder, "corps_%s_72" % id)
	# Baissé (yeux plus bas), et vu de dos.
	w.player.camera.rotation.x = deg_to_rad(-89.0)
	w.player.crouching = true
	w.player.camera.position.y = w.player.eye_height - w.player.CROUCH_DROP
	w.player._update_rigs(0.016)
	await shot(folder, "corps_baisse_89")
	w.player.crouching = false
	w.player.camera.position.y = w.player.eye_height
	w.player.camera.rotation.x = deg_to_rad(-20.0)
	w.player.set_view("back")
	w.player.view_camera.position = Vector3(0.0, -0.4, 1.7)
	await shot(folder, "corps_dos")
	quit(0)
