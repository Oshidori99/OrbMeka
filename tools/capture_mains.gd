extends SceneTree
# 0.0.8.57 (règles des mains) : la vue à la première personne : l'objet choisi dans la main gauche, la main droite qui
# porte les cases « main » ; un objet lourd tenu à deux mains ; le Créatif. Fenêtre hors écran, petite, sans clavier ni
# souris (jamais capturée) :
#   & '<Godot console>' --path . --position 20000,20000 --resolution 480x270 --script res://tools/capture_mains.gd -- <dossier>
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
	await create_timer(0.8).timeout
	await frames(30)
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
	print("CAPTURE ", name)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else OS.get_user_data_dir()
	w = load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	await frames(120)
	w.player.set_physics_process(false)
	w.day_time = 600.0
	w._update_day(0.0)
	w.player.camera.rotation.x = -0.35
	w.set_game_mode(Inventory.SURVIVAL)
	var store: Dictionary = w.inventory._store()
	for index in range(Inventory.BAR_SIZE):
		store.bar[index] = {}
	w.inventory.put("bar", 0, {"objet": "caillou", "pile": [{"taille": 3, "forme": 3}]})
	w.inventory.put("bar", 2, {"objet": "noisette", "pile": [{"diametre": 0.02}]})
	w.inventory.select(2)
	w.apply_held()
	await shot(folder, "mains_poche")
	w.inventory.select(0)
	w.apply_held()
	await shot(folder, "mains_case1")
	w.inventory.put("bar", 0, {})
	w.inventory.put("bar", 0, {"objet": "tronc", "pile": [{"epaisseur": 12.0, "longueur": 0.5, "poids": 4200.0, "essence": 0, "forme": 3}]})
	w.inventory.select(0)
	w.apply_held()
	await shot(folder, "mains_lourd")
	w.inventory.select(2)
	w.apply_held()
	await shot(folder, "mains_lourd_poche")
	w.set_game_mode(Inventory.CREATIVE)
	w.inventory._store().bar[0] = {"objet": "hache_pierre", "pile": [Inventory.CATALOG_MODELS.hache_pierre.duplicate()]}
	w.inventory.select(0)
	w.apply_held()
	await shot(folder, "mains_creatif")
	quit(0)
