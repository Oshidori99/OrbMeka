extends SceneTree
# 0.0.8.53 (lot C1) : les modèles faits dans Blender, vus de près dans le jeu : feux de camp (éteint, allumé), torches
# (éteinte, allumée, forte), archet à feu, posés au sol en plein jour ; puis la même chose la nuit ; puis une torche en
# main. Fenêtre hors écran, sans clavier ni souris (jamais capturée) :
#   & '<Godot console>' --path . --position 20000,20000 --resolution 960x540 --script res://tools/capture_modeles.gd -- <dossier>
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

func drop(item: Dictionary, at: Vector3) -> void:
	at.y = w._rest_height(at)
	w.ground.drop(item, at + Vector3.UP * 0.2, at, w._rest_height, 0.0)

func shot(folder: String, name: String) -> void:
	await frames(40)
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
	print("CAPTURE ", name)

func _run() -> void:
	var folder: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else OS.get_user_data_dir()
	w = load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	await frames(120)
	w.player.set_physics_process(false)
	w.set_shadows("medium")
	var start: Vector3 = w.player.global_position
	var center := start + Vector3(0.0, 0.0, -2.2)
	# L'herbe coupée autour (comme en prenant des mottes) : on voit les objets.
	for dx in range(-4, 5):
		for dz in range(-4, 5):
			w._set_grass(center + Vector3(dx * 0.35, 0.0, dz * 0.35), false)
	var stick := {"essence": 1, "epaisseur": 3.0, "fin": 2.6, "longueur": 0.55, "poids": 260.0}
	drop({"objet": "feu_camp", "poids": 3000.0}, center + Vector3(-1.0, 0.0, 0.0))
	drop({"objet": "feu_camp", "allume": 1, "brule": 600.0, "poids": 3000.0}, center + Vector3(0.9, 0.0, 0.0))
	var torch := stick.duplicate()
	torch.objet = "torche"
	drop(torch, center + Vector3(-0.5, 0.0, 0.9))
	var plain := stick.duplicate()
	plain.objet = "branche"
	drop(plain, center + Vector3(-0.9, 0.0, 0.5))
	var lit := torch.duplicate()
	lit.allume = 1
	lit.brule = 600.0
	drop(lit, center + Vector3(0.0, 0.0, 0.9))
	var strong := stick.duplicate()
	strong.objet = "torche_forte"
	strong.epaisseur = 3.4
	drop(strong, center + Vector3(0.5, 0.0, 0.9))
	drop({"objet": "archet", "essence": 1, "age": 3, "souplesse": 4, "epaisseur": 2.0, "fin": 1.6, "longueur": 0.7, "poids": 250.0}, center + Vector3(0.0, 0.0, -0.6))
	await create_timer(1.5).timeout
	w.day_time = 720.0
	w._update_day(0.0)
	w.player.global_position = start + Vector3(0.0, 0.0, 0.2)
	await frames(5)
	w.player.camera.look_at(center + Vector3(0.0, 0.0, 0.3))
	await shot(folder, "modeles_jour")
	w.day_time = 60.0
	w.sky_open = 1.0
	w._update_day(0.0)
	w._apply_light_shadows()
	await shot(folder, "modeles_nuit")
	# Une torche forte allumée en main, regard vers le sol devant.
	w.inventory.set_mode(Inventory.CREATIVE)
	var held := strong.duplicate()
	held.allume = 1
	held.brule = 300.0
	w.inventory._store().bar[0] = {"objet": "torche_forte", "pile": [held]}
	w.inventory.select(0)
	w.inventory.changed.emit()
	w.player.camera.look_at(center + Vector3(0.0, -0.4, 1.0))
	await shot(folder, "modeles_main")
	# Le menu de fabrication (O + F) : les images des actions.
	w.toggle_crafting()
	await shot(folder, "modeles_fabrication")
	quit(0)
