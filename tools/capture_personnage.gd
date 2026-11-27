extends SceneTree
# 0.0.8.54 (lot C1, #224, #225, #230) : le personnage vu de dos et de face (squelette, character_rig.gd) : un outil en
# main, un geste (frapper), la marche. Fenêtre hors écran, sans clavier ni souris (jamais capturée) :
#   & '<Godot console>' --path . --position 20000,20000 --resolution 960x540 --script res://tools/capture_personnage.gd -- <dossier> [objet] [personnage]
const Inventory = preload("res://scripts/inventory.gd")

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

func shot(folder: String, name: String) -> void:
	await frames(20)
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
	print("CAPTURE ", name)

func walk(seconds: float, speed: float) -> void:
	var steps := int(seconds * 60.0)
	for index in range(steps):
		w.player.shadow_rig.update(1.0 / 60.0, speed, true)
		await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var held: String = args[1] if args.size() > 1 else "hache_pierre"
	w = load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	await frames(120)
	w.player.set_physics_process(false)
	# Le corps du personnage (en jeu : construit par les réglages).
	w.player.body_key = ""
	if args.size() > 2:
		w.player.character = args[2]
	w.player.sync_body()
	w.day_time = 600.0
	w._update_day(0.0)
	w.inventory.set_mode(Inventory.CREATIVE)
	var model: Dictionary = Inventory.CATALOG_MODELS.get(held, {}).duplicate(true)
	w.inventory._store().bar[0] = {"objet": held, "pile": [model]}
	w.inventory.select(0)
	w.inventory.changed.emit()
	await frames(5)
	print("SQUELETTE ", w.player.character, " ", w.player.body_shadow, " ", w.player.shadow_rig != null, " ", load("res://scripts/character_rig.gd").find_skeleton(w.player.body_shadow) if is_instance_valid(w.player.body_shadow) else null)
	w.player.set_view("back")
	w.player.view_camera.position = Vector3(0.0, -0.4, 1.7)
	await walk(0.3, 0.0)
	await shot(folder, "perso_dos")
	w.player.set_view("front")
	w.player.view_camera.position = Vector3(0.0, -0.4, -1.7)
	await walk(0.3, 0.0)
	await shot(folder, "perso_face")
	w.player.hand_view.dig()
	await walk(0.16, 0.0)
	await shot(folder, "perso_geste")
	await walk(0.7, 3.0)
	await shot(folder, "perso_marche")
	# Première personne, regard vers le bas : le corps (coupé au cou) marche, sans gêner les mains du jeu.
	w.player.set_view("first")
	w.player.camera.rotation.x = -1.25
	await walk(0.5, 3.0)
	for index in range(30):
		w.player.body_rig.update(1.0 / 60.0, 3.0, false)
		await process_frame
	await shot(folder, "perso_bas")
	quit(0)
