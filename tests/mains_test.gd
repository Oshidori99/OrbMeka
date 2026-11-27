extends SceneTree
# 0.0.8.57 (décisions de l'utilisateur) : l'objet choisi (molette, touches), où qu'il soit, est pris dans la main gauche,
# qui fait les gestes ; la main droite porte les deux cases « main » (2,5 kg chacune) ; plus de 2,5 kg : les deux cases,
# 5 kg au plus ; porter ralentit de 6 % par kg ; dans une partie d'avant, ce qui ne tient plus sort des mains.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
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

func shown(hand: Node3D) -> bool:
	return hand.held.get_children().any(func(child: Node) -> bool: return not child.is_queued_for_deletion())

func _run() -> void:
	# Règles seules (sans monde).
	var rules := Inventory.new()
	rules.set_mode(Inventory.SURVIVAL)
	check(Inventory.TWO_HANDS == 2500.0 and Inventory.HANDS_LIMIT == 5000.0, "2,5 kg per hand slot, 5 kg for both")
	rules.put("bar", 0, {"objet": "caillou", "pile": [{"taille": 5}]})
	rules.put("bar", 1, {"objet": "caillou", "pile": [{"taille": 5}]})
	check(Inventory.count(rules.item("bar", 0)) == 1 and Inventory.count(rules.item("bar", 1)) == 1 and rules.two_handed() < 0, "1,75 kg in each slot of the right hand")
	check(is_equal_approx(rules.carry_factor(), 1.0 - 0.06 * 3.5), "3,5 kg in the hands: 21 %% slower (%.3f)" % rules.carry_factor())
	var big := Inventory.new()
	big.set_mode(Inventory.SURVIVAL)
	big.put("bar", 0, {"objet": "caillou", "pile": [{"taille": 6}]})
	check(big.two_handed() == 0 and big.bar_slots() == [0, 2, 3, 4, 5], "a 2,75 kg stone takes both slots of the hands")
	check(big.add_to_selected({"objet": "caillou", "pile": [{"taille": 6}]}).added == 0, "a second one is refused (5 kg at most)")
	# Partie d'avant : 7 kg et 3 kg dans les mains (permis avant 0.0.8.57).
	var old := Inventory.new()
	old.set_mode(Inventory.SURVIVAL)
	old._store().bar[0] = {"objet": "tronc", "pile": [{"epaisseur": 15.0, "longueur": 0.55, "poids": 7000.0, "essence": 0}]}
	old._store().bar[1] = {"objet": "caillou", "pile": [{"taille": 4}, {"taille": 4}]}
	var spilled: Array = old.hands_overflow()
	check(spilled.size() == 1 and spilled[0].objet == "tronc" and old.item("bar", 0).is_empty() and Inventory.count(old.item("bar", 1)) == 2, "an old 7 kg log leaves the hands, the 2 kg of pebbles stay (%s)" % str(spilled.map(func(each): return each.objet)))
	var none := Inventory.new()
	none.set_mode(Inventory.SURVIVAL)
	none.put("bar", 1, {"objet": "pomme", "pile": [{"taille": 2, "couleur": 1}]})
	check(none.hands_overflow().is_empty() and Inventory.count(none.item("bar", 1)) == 1, "nothing changes when everything still fits")
	# Dans le monde.
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/mains-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(fixture)
	app.catalog = Catalog.new(fixture + ".worlds")
	var made: Dictionary = app.catalog.create_world("Mains", "57")
	app.catalog.set_game_mode(made.id, Catalog.GAME_SURVIVAL)
	root.add_child(app)
	current_scene = app
	await process_frame
	app.open_world(made.id)
	await frames(5)
	var world: Node3D = app.active_world
	var inv = world.inventory
	var player: Node3D = world.player
	check(player.hand_view.left and player.hand_view.active and not player.right_hand_view.left, "the working hand is the left one")
	for index in range(Inventory.BAR_SIZE):
		inv._store().bar[index] = {}
	inv.put("bar", 0, {"objet": "caillou", "pile": [{"taille": 2, "forme": 3}]})
	inv.put("bar", 2, {"objet": "noisette", "pile": [{"diametre": 0.018}]})
	inv.select(0)
	world.apply_held()
	await frames(3)
	check(world.left_hand_item().get("objet") == "caillou" and world.right_hand_item().is_empty() and shown(player.hand_view) and not shown(player.right_hand_view), "choosing the first hand slot: the pebble goes to the left hand")
	inv.select(2)
	world.apply_held()
	# Selon le temps (pas le nombre d'images).
	var reached := 0.0
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 300:
		await process_frame
		reached = maxf(reached, player.hand_view.position.distance_to(player.hand_view.rest))
	check(world.left_hand_item().get("objet") == "noisette" and world.right_hand_item().get("objet") == "caillou" and shown(player.hand_view) and shown(player.right_hand_view), "choosing a pocket: the hazelnut in the left hand, the right hand keeps the pebble (%s / %s / %s %s)" % [world.left_hand_item().get("objet"), world.right_hand_item().get("objet"), shown(player.hand_view), shown(player.right_hand_view)])
	check(reached > 0.05 and player.hand_view.position.x < 0.0, "the left hand reaches into the pocket (%.2f m)" % reached)
	# Un objet lourd (les deux cases) : choisi, tenu à deux mains ; pas choisi, porté par la main droite.
	inv.put("bar", 0, {})
	inv.put("bar", 0, {"objet": "tronc", "pile": [{"epaisseur": 12.0, "longueur": 0.5, "poids": 4200.0, "essence": 0}]})
	inv.select(0)
	world.apply_held()
	await frames(3)
	check(inv.two_handed() == 0 and world.both_hands_held() and player.hand_view.both and player.right_hand_view.both and world.right_hand_item().is_empty(), "a 4,2 kg log chosen: held with both hands")
	check(absf(player.carry_slow - (1.0 - 0.06 * 4.2)) < 0.001, "walking 25 %% slower with 4,2 kg (%.3f)" % player.carry_slow)
	inv.select(2)
	world.apply_held()
	await frames(3)
	check(not world.both_hands_held() and world.right_hand_item().get("objet") == "tronc" and world.left_hand_item().get("objet") == "noisette" and not player.hand_view.both, "the hazelnut chosen: the right hand carries the log, the left one takes the hazelnut")
	# Les gestes sont faits par la main gauche, aussi par le corps (vu de dos, ombre).
	player.hand_view.dig()
	check(player.shadow_rig == null or player.shadow_rig.gesture_side == "G", "the body makes the gesture with its left arm")
	# Créatif : l'objet choisi aussi dans la main gauche.
	world.set_game_mode(Inventory.CREATIVE)
	inv._store().bar[3] = {"objet": "terre", "nombre": 99}
	inv.select(3)
	world.apply_held()
	await frames(3)
	check(world.left_hand_item().get("objet") == "terre" and world.right_hand_item().is_empty() and shown(player.hand_view) and not shown(player.right_hand_view), "creative: the chosen item in the left hand, the right one empty")
	app.return_to_worlds()
	for path in [fixture, fixture + ".worlds"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d hands checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
