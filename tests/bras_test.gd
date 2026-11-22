extends SceneTree
# 0.0.8.17 (#224, demande de l'utilisateur) : bras et mains à la première personne animés : la main a ses poses (formes de
# mélange : prise, griffe, ouverte, pince), serre ce qu'elle tient, creuse en griffe, s'ouvre pour poser, attrape en
# ramassant, serre en tirant (récolter, arracher), porte le fruit à la bouche.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const FirstPersonHand = preload("res://scripts/first_person_hand.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _run() -> void:
	var model: Node = load(FirstPersonHand.MODEL).instantiate()
	var mesh: Mesh = model.find_children("*", "MeshInstance3D", true, false)[0].mesh
	var names := []
	for index in range(mesh.get_blend_shape_count()):
		names.append(str(mesh.get_blend_shape_name(index)))
	model.free()
	check(names == ["prise", "griffe", "ouverte", "pince"], "the hand model has its four poses (%s)" % str(names))
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/bras-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(fixture)
	app.catalog = Catalog.new(fixture + ".worlds")
	var made: Dictionary = app.catalog.create_world("Bras", "78")
	app.catalog.set_game_mode(made.id, Catalog.GAME_SURVIVAL)
	root.add_child(app)
	current_scene = app
	await process_frame
	app.open_world(made.id)
	await frames(5)
	var world: Node3D = app.active_world
	var hand: Node3D = world.player.hand_view
	check(hand.pose_mesh != null, "the hand in the game has its poses")
	world.inventory.select(1)
	world.inventory.put("bar", 1, {"objet": "caillou", "pile": [{"taille": 2, "forme": 3}]})
	world.apply_held()
	await frames(20)
	check(hand.pose_value("prise") > 0.4 and hand.pose_value("griffe") < 0.05, "holding a pebble: the fingers close on it (%.2f)" % hand.pose_value("prise"))
	world.inventory.put("bar", 1, {"objet": "fibre_lin", "pile": [{}]})
	world.apply_held()
	await frames(20)
	check(hand.pose_value("pince") > 0.5 and hand.pose_value("prise") < 0.1, "holding fibres: thumb and index pinch")
	world.inventory.put("bar", 1, {})
	world.apply_held()
	await frames(20)
	check(FirstPersonHand.POSES.all(func(name): return hand.pose_value(name) < 0.05), "empty hand: the base pose")
	hand.dig()
	await frames(6)
	check(hand.pose_value("griffe") > 0.4 and hand.position != hand.rest, "digging: a claw that scratches")
	await frames(40)
	check(hand.pose_value("griffe") < 0.1 and hand.position.is_equal_approx(hand.rest), "then back to rest")
	hand.place()
	await frames(5)
	check(hand.pose_value("ouverte") > 0.4, "placing: an open hand pushes")
	await frames(40)
	hand.grab()
	await frames(4)
	var reached: bool = hand.position.distance_to(hand.rest) > 0.05
	await frames(14)
	check(reached and hand.pose_value("prise") > 0.3, "picking up: it reaches, then closes")
	await frames(40)
	# (Le monde appelle pull à chaque image en récoltant ; ici, un seul appel : on regarde la pose voulue.)
	hand.pull(0.5, 0.2)
	check(hand.pulling and hand._pose_goal.prise == 1.0 and hand.position != hand.rest, "harvesting or pulling: it grips and tugs")
	hand.pull(0.0, 0.0)
	await frames(30)
	world.inventory.put("bar", 1, {"objet": "pomme", "pile": [{"taille": 2, "couleur": 1}]})
	world.apply_held()
	hand.eat(0.7)
	check(hand.eating and hand.position.distance_to(hand.rest) > 0.1 and hand.rotation.x > 0.2, "eating: the fruit goes up to the mouth")
	hand.eat(0.0)
	check(not hand.eating and hand.position == hand.rest, "then back")
	# Les deux mains de la fabrication ont leurs poses aussi.
	world.open_crafting()
	await frames(4)
	check(world.crafting_ui.hands.size() == 2 and world.crafting_ui.hands.all(func(each): return each.pose_mesh != null), "crafting: both hands have their poses")
	world.close_crafting(false)
	app.return_to_worlds()
	for path in [fixture, fixture + ".worlds"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d arms checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
