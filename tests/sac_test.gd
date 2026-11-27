extends SceneTree
# 0.0.8.21 (#207, demandes de l'utilisateur) : sac en filet. Cordelette (3 ficelles tressées), Nouer (4 cordelettes pour
# les mailles, 1 cordelette ou 1 liane pour la bretelle, 6 à 10 rangées) ; le sac va sur l'épaule : cases 7 à 10 de la
# barre ; un deuxième sac : 4 cases dans l'inventaire ; charge de 3,45 à 5 kg (0.0.8.24 ; avant 2,5 à 3,5 kg) et 10 L ; terre, sable et fibres passent
# entre les mailles ; un sac s'enlève vide ; sauvegarde ; à la mort, tout tombe ; fiche de fabrication ; Carnet de route.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Rules = preload("res://scripts/crafting_rules.gd")
const Carnet = preload("res://scripts/carnet.gd")
const Controls = preload("res://scripts/controls.gd")
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

static func pile(id: String, units: Array) -> Dictionary:
	return {"objet": id, "pile": units}

func _run() -> void:
	# --- Règles seules ---
	var bag := {"objet": "sac_filet", "lien": 1, "rangees": 10, "bretelle": 0, "poids": 90.0}
	check(is_equal_approx(Inventory.bag_capacity(bag), 5000.0), "linen, 10 rows, cord strap: the best bag carries 5 kg")
	check(is_equal_approx(Inventory.bag_capacity({"lien": 2, "rangees": 6, "bretelle": 1}), 3450.0), "grass, 6 rows, vine strap: 3.45 kg (the least)")
	check(Inventory.bag_capacity({"lien": 0, "rangees": 8}) > 4200.0 and Inventory.bag_capacity({"lien": 0, "rangees": 8}) < 4300.0, "nettle, 8 rows: about 4.3 kg")
	var inv := Inventory.new()
	inv.set_mode(Inventory.SURVIVAL)
	check(not inv.usable("bar", 6) and not inv.usable("sac", 0) and inv.bar_slots().size() == 6, "no bag: hands and pockets only (6 slots)")
	check(inv.wear_bag(pile("sac_filet", [bag.duplicate()])) == 0, "a bag goes on the shoulder (first place)")
	check(inv.usable("bar", 6) and inv.usable("bar", 9) and not inv.usable("sac", 0) and inv.bar_slots().size() == 10, "the bag's 4 slots are slots 7 to 10 of the bar")
	inv.put("bar", 6, pile("caillou", [{"taille": 4}, {"taille": 4}]))
	check(Inventory.count(inv.item("bar", 6)) == 2 and is_equal_approx(inv.bag_weight(0), 2000.0), "two 1 kg pebbles in the bag")
	var left := inv.put("bar", 7, pile("caillou", [{"taille": 4}, {"taille": 4}, {"taille": 4}, {"taille": 4}]))
	check(Inventory.count(inv.item("bar", 7)) == 3 and Inventory.count(left) == 1 and inv.last_refusal == "lourd", "5 kg at most: the sixth pebble does not fit")
	var earth := inv.put("bar", 8, {"objet": "terre", "nombre": 1})
	check(inv.item("bar", 8).is_empty() and earth.get("objet") == "terre", "a handful of earth falls through the mesh")
	inv.put("bar", 8, pile("fibre_lin", [{}]))
	check(inv.item("bar", 8).is_empty() and inv.last_refusal == "mailles", "fibres too (« mailles »)")
	inv.select(7)
	check(inv.held().get("objet") == "caillou", "a bag slot can be chosen: its object is used directly, like a pocket")
	# 0.0.8.41 (#210, demande de l'utilisateur) : un sac plein s'enlève avec ses objets (rangés à part, comptés dans son poids) ;
	# remis sur l'épaule, il les retrouve.
	var full_off := inv.take_off_bag(0)
	check(full_off.has("sac_id") and not inv.bag_worn(0) and Inventory.stored_bags.has(int(full_off.sac_id)) and Inventory.instance_weight("sac_filet", full_off) > float(full_off.get("poids", 90.0)), "a full bag comes off with its things (they count in its weight)")
	check(inv.wear_bag(pile("sac_filet", [full_off]), 0) == 0 and inv.item("bar", 7).get("objet") == "caillou" and not Inventory.stored_bags.has(int(full_off.sac_id)) and not inv.bag(0).has("sac_id"), "worn again: it finds its things back")
	inv.select(7)
	check(inv.wear_bag(pile("sac_filet", [bag.duplicate()])) == 1 and inv.usable("sac", 0) and inv.carried_places().size() == 14, "a second bag: 4 slots in the inventory (zone « sac »)")
	inv.put("sac", 0, pile("pomme", [{"taille": 2}]))
	var saved := inv.to_dict()
	var loaded := Inventory.new()
	loaded.from_dict(JSON.parse_string(JSON.stringify(saved)))
	loaded.set_mode(Inventory.SURVIVAL)
	check(saved.format == 4 and loaded.bag_worn(0) and loaded.bag_worn(1) and Inventory.count(loaded.item("bar", 6)) == 2 and loaded.item("sac", 0).get("objet") == "pomme" and int(loaded.bag(0).get("rangees", 0)) == 10, "saved and read back: both bags, their make and their contents")
	# 0.0.8.48 (#262) : usure selon le remplissage, en minutes réelles ; à 0 : « Sac cassé », contenu rendu.
	check(Inventory.bag_wear_per_minute(0.02) == 0.0 and Inventory.bag_wear_per_minute(0.3) == 1.0 and Inventory.bag_wear_per_minute(0.8) == 2.0, "wear: none under 5 %, 1 %/min up to 55 %, 2 %/min above")
	var worn := Inventory.new()
	worn.set_mode(Inventory.SURVIVAL)
	worn.wear_bag(pile("sac_filet", [bag.duplicate()]), 0)
	worn.wear_bags(10.0)
	check(is_equal_approx(Inventory.bag_solidity(worn.bag(0)), 100.0), "an empty bag does not wear")
	worn.put("bar", 6, pile("caillou", [{"taille": 4}]))
	worn.wear_bags(10.0)
	check(is_equal_approx(Inventory.bag_solidity(worn.bag(0)), 90.0), "1 kg in a 5 kg bag (20 %): 10 minutes, 10 % worn")
	worn.put("bar", 7, pile("caillou", [{"taille": 4}, {"taille": 4}]))
	worn.wear_bags(10.0)
	check(is_equal_approx(Inventory.bag_solidity(worn.bag(0)), 70.0), "3 kg (60 %): twice faster")
	var reread := Inventory.new()
	reread.from_dict(JSON.parse_string(JSON.stringify(worn.to_dict())))
	reread.set_mode(Inventory.SURVIVAL)
	check(is_equal_approx(Inventory.bag_solidity(reread.bag(0)), 70.0) and "Solidité : 70 %" in Inventory.bag_lines(reread.bag(0)), "its solidity is saved and shown in its details")
	var broken_list := worn.wear_bags(60.0)
	check(broken_list == [0], "worn out: the bag breaks")
	var result := worn.break_bag(0)
	check(not worn.bag_worn(0) and result.sac.objet == "sac_casse" and result.contenu.size() == 2 and worn.item("bar", 6).is_empty(), "it becomes a « Sac cassé », its contents given back (nothing lost)")
	var creative := Inventory.new()
	creative.set_mode(Inventory.CREATIVE)
	check(creative.wear_bags(100.0).is_empty(), "Creative: no wear")
	var old := Inventory.new()
	old.from_dict({"format": 3, "survie": {"barre": [null, null, null, null, null, null, {"objet": "pomme", "pile": [{}]}]}})
	old.set_mode(Inventory.SURVIVAL)
	check(not old.bag_worn(0) and not old.usable("bar", 6), "an old world: no bag")
	for place in Inventory.bag_places(1):
		inv.remove(place[0], place[1], true)
	var taken := inv.take_off_bag(1)
	check(Inventory.is_bag(taken) and not inv.bag_worn(1) and not inv.usable("sac", 0), "an empty bag comes off")
	var report := Inventory.tool_report(bag)
	check(report.etapes.size() == 3 and report.etapes.all(func(step): return step[2] == "bien") and report.resume.contains("5,000 kg"), "the bag's card: three steps, all « bien », 5 kg")
	check(Inventory.has_tool_report(bag) and Inventory.detail_lines(bag).any(func(line): return line.begins_with("Porte :")), "details: what it carries")
	# Bug signalé par l'utilisateur : un tronc posé (porté à deux mains, l'autre main choisie) restait aussi en main.
	var trunk := Inventory.new()
	trunk.set_mode(Inventory.SURVIVAL)
	trunk.put("bar", Inventory.HANDS[0], pile("tronc", [{"epaisseur": 15.0, "longueur": 0.5, "poids": 4600.0, "essence": 0}]))
	trunk.select(Inventory.HANDS[0])
	trunk._store().selected = Inventory.HANDS[1]
	var put_down := trunk.pop_held()
	check(put_down.get("objet") == "tronc" and trunk.item("bar", Inventory.HANDS[0]).is_empty() and trunk.item("bar", Inventory.HANDS[1]).is_empty(), "a trunk carried with both hands, put down: it leaves the hands (no copy)")
	# Demande de l'utilisateur : tresser deux fois plus vite avec un éclat tranchant sur soi.
	var braid := Inventory.new()
	braid.set_mode(Inventory.SURVIVAL)
	check(is_equal_approx(Rules.braid_seconds(false), 3.0), "braiding: 3 s without a flake")
	braid.put("bar", Inventory.POCKETS[0], pile("eclat_silex", [{"poids": 40.0}]))
	check(is_equal_approx(Rules.braid_seconds(true), 1.5) and Rules.has_flake(braid), "with a sharp flake chosen (offered, 0.0.8.24): 1.5 s")
	check(not Carnet.node("cordelette").is_empty() and Carnet.node("sac").parent == "cordelette" and Carnet.node("cordelette").parent == "eclat", "Carnet de route: Éclat → Cordelette → Sac en filet")
	# --- 0.0.8.25 (choix de l'utilisateur) : changer de mode garde le même inventaire, rangé selon les règles ---
	var both := Inventory.new()
	both.set_mode(Inventory.CREATIVE)
	both.put("bar", 0, {"objet": "terre"})
	both.put("bar", 1, {"objet": "pioche_pierre"})
	both.put("grid", 0, pile("caillou", [{"taille": 4}]))
	var fell: Array = both.carry_to(Inventory.SURVIVAL)
	var kept := 0
	for place in both.carried_places():
		kept += Inventory.count(both.item(place[0], place[1]))
	var fallen_units := 0
	for each in fell:
		fallen_units += Inventory.count(each[0]) - int(each[1])
	check(both.mode == Inventory.SURVIVAL and kept + fallen_units == 99 + 1 + 1 and fallen_units > 0, "creative to survival: the same items (99 earth, a pickaxe, a pebble), what does not fit falls (%d kept, %d fall)" % [kept, fallen_units])
	check(both.carried_places().any(func(place): return both.item(place[0], place[1]).get("objet", "") == "pioche_pierre"), "the pickaxe is carried (one)")
	var back: Array = both.carry_to(Inventory.CREATIVE)
	var in_creative := 0
	for index in range(Inventory.BAR_SIZE):
		in_creative += Inventory.count(both.item("bar", index))
	for index in range(Inventory.GRID_SIZE):
		in_creative += Inventory.count(both.item("grid", index))
	check(back.is_empty() and in_creative == kept, "and back to creative: everything carried comes along")
	# --- En partie (Survie) : cordelettes, Nouer, porter ---
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/sac-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(fixture)
	app.catalog = Catalog.new(fixture + ".worlds")
	var made: Dictionary = app.catalog.create_world("Sac", "81")
	app.catalog.set_game_mode(made.id, Catalog.GAME_SURVIVAL)
	root.add_child(app)
	current_scene = app
	await process_frame
	app.open_world(made.id)
	for i in range(600):
		if app.page == "playing":
			break
		await process_frame
	var world: Node3D = app.active_world
	var items: Inventory = world.inventory
	for place in items.carried_places():
		items.put(place[0], place[1], {})
	var strings := []
	for i in range(15):
		strings.append({"longueur": 0.33})
	items.put("bar", 2, pile("ficelle_lin", strings))
	world.toggle_crafting()
	await process_frame
	await process_frame
	var ui: CanvasLayer = world.crafting_ui
	ui.choose_action("tresser")
	var choice: Array = Rules.choices(items, "fibres").filter(func(c): return c.get("fibres") == "ficelle_lin")
	check(choice.size() == 1, "Tresser: 3 linen strings can be braided")
	if not choice.is_empty():
		ui.pick("fibres", choice[0])
	for cord in range(5):
		ui.holding = true
		for i in range(31):
			ui.step_braid(0.1)
	check(Rules.owned(items, "cordelette_lin") == 5 and Rules.owned(items, "ficelle_lin") == 0, "15 strings → 5 linen cords")
	ui.choose_action("nouer")
	var nets: Array = Rules.more_choices(items, "filet")
	var straps: Array = Rules.more_choices(items, "bretelle")
	check(nets.size() == 1 and straps.size() == 1, "Nouer: 4 cords for the mesh, 1 for the strap")
	if not nets.is_empty() and not straps.is_empty():
		ui.pick("filet", nets[0])
		ui.pick("bretelle", straps[0])
	ui.holding = true
	ui.step_knot(Rules.ROW_SECONDS * 3.0)
	ui.release_hold()
	check(not items.bag_worn(0) and Rules.owned(items, "cordelette_lin") == 5, "released after 3 rows: not enough, nothing used")
	ui.holding = true
	for i in range(int(Rules.ROW_SECONDS * Inventory.BAG_ROWS.y / 0.1) + 2):
		ui.step_knot(0.1)
	check(items.bag_worn(0) and int(items.bag(0).get("rangees", 0)) == 10 and Rules.owned(items, "cordelette_lin") == 0, "held long enough: 10 rows, the bag is on the shoulder, the 5 cords used")
	check(ui.slots.filter(func(s): return s.visible).size() == 10, "the crafting screen shows the bag's slots too")
	world.close_crafting(false)
	await process_frame
	var hud: Array = world.inventory_ui.hud_slots
	check(hud[6].visible and hud[9].visible and world.inventory_ui.hud_rows["sac"].visible, "in game: slots 7 to 10 and the bag's load (bottom right)")
	check(world.notebook.is_done("sac") and world.notebook.is_done("cordelette"), "Carnet de route: Cordelette and Sac en filet ticked")
	check(world.player.bag_views.size() == 2 and world.player.bag_views[0].visible and not world.player.bag_views[1].visible, "the bag hangs on the character")
	items.put("bar", 6, pile("pomme", [{"taille": 2}]))
	items.put("bar", Inventory.HANDS[1], pile("caillou", [{"taille": 2}]))
	var fetched := []
	world.player.hand_view.gestured.connect(func(name: String) -> void: fetched.append(name))
	items.select(6)
	check(world.held_text() == "Pomme" and world.right_hand_item().get("objet") == "caillou", "the hand still holds the pebble; the apple in the bag is the chosen object")
	# 0.0.8.54 (lot C1) : ce qui est dans le sac porté se voit à travers les mailles ; le prendre : la main va au sac.
	world.apply_held()
	var worn_view: MeshInstance3D = world.player.bag_views[0]
	check(worn_view.visible and worn_view.get_child_count() >= 1, "the worn bag shows what is inside (%d)" % worn_view.get_child_count())
	check(fetched.has("fetch"), "choosing the bag's slot: the hand goes to the bag to take the apple (#250)")
	world.open_inventory()
	await process_frame
	check(world.inventory_ui.survival_rows["Sac"].visible and not world.inventory_ui.survival_rows["Sac 2"].visible and world.inventory_ui.bag_equipment[0].item.get("objet") == "sac_filet", "inventory: the bag row, the bag in Équipement")
	world.inventory_ui._on_equipment(MOUSE_BUTTON_LEFT, 0)
	# 0.0.8.41 : plein, il s'enlève avec ses objets (sous la souris) ; reposé à sa place, il les retrouve.
	check(not items.bag_worn(0) and world.inventory_ui.cursor_item.get("objet") == "sac_filet" and world.inventory_ui.cursor_item.pile[0].has("sac_id"), "full: it comes off with its things")
	world.inventory_ui._on_equipment(MOUSE_BUTTON_LEFT, 0)
	check(items.bag_worn(0) and items.item("bar", 6).get("objet") == "pomme", "put back on: its things are back")
	# --- 0.0.8.41 (#210, demandes de l'utilisateur) : le sac posé au sol plein ; O + V l'ouvre ; R le reprend ; enregistré. ---
	check(Controls.ACTIONS.open_bag.default.key == KEY_O and Controls.ACTIONS.open_bag.default.second.key == KEY_V, "O + V opens a bag on the ground")
	world.open_inventory()
	await process_frame
	world.inventory_ui._on_equipment(MOUSE_BUTTON_LEFT, 0)
	var bag_held: Dictionary = world.inventory_ui.cursor_item
	world.inventory_ui.throw_cursor()
	world.close_inventory(false)
	await frames(10)
	var bag_index := -1
	for at in range(world.ground.entries.size()):
		if world.ground.entries[at].item.get("objet") == "sac_filet" and world.ground.entries[at].item.has("sac_id"):
			bag_index = at
	check(bag_index >= 0 and not items.bag_worn(0), "the full bag lies on the ground (thrown with J, with its things)")
	for wait in range(120):
		if bag_index < 0 or not world.ground.entries[bag_index].has("hidden"):
			break
		await process_frame
	await frames(3)
	check(not world.ground._bag_contents.is_empty() and world.ground._bag_contents[0].get_child_count() >= 1, "the bag on the ground shows what is inside (0.0.8.54)")
	if bag_index >= 0:
		var body: Node3D = world.ground.bodies[bag_index]
		world.player.camera.look_at(body.global_position)
		var hit := {"collider": body, "position": body.global_position, "normal": Vector3.UP}
		check(world.open_aimed_bag(hit) and world.inventory_open and world.inventory_ui.ground_bag_row.visible and world.inventory_ui.ground_bag_line.visible and world.inventory_ui.ground_bag_line.get_child(1).color.r > 0.9 and items.item("sol", 0).get("objet") == "pomme", "O + V: the inventory opens on the bag's 4 slots, its things inside")
		var apple: Dictionary = items.take("sol", 0)
		var pocket: int = (Inventory.HANDS + Inventory.POCKETS).filter(func(index): return items.item("bar", index).is_empty() and items.fit_count("bar", index, apple) > 0)[0]
		check(items.put("bar", pocket, apple).is_empty() and items.item("sol", 0).is_empty(), "take an apple out of the bag on the ground")
		items.put("sol", 1, items.take("bar", pocket))
		check(items.item("sol", 1).get("objet") == "pomme", "and put it back in")
		world.close_inventory(false)
		check(items.ground_bag.is_empty() and not world.inventory_ui.ground_bag_row.visible and Inventory.stored_bags.has(int(world.ground.entries[bag_index].item.sac_id)), "closed: its things stay in it")
		# 0.0.8.45 : un clic droit sur le sac lui-même l'ouvre aussi.
		await frames(2)
		check(world.aimed_ground_bag() and world.eat_press() and world.inventory_open and not items.ground_bag.is_empty(), "a right click on the bag itself opens it too")
		world.close_inventory(false)
		# Enregistré avec les objets du monde, relu.
		world.objects_dirty = true
		world._save_objects()
		var saved_objects: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_folder.path_join("objets.json")))
		var read_again := Inventory.valid_stored(saved_objects.get("sacs_contenus"))
		check(read_again.has(int(world.ground.entries[bag_index].item.sac_id)) and read_again[int(world.ground.entries[bag_index].item.sac_id)][1].get("objet") == "pomme", "saved with the world (objets.json « sacs_contenus ») and read back")
		# R : repris avec son contenu (et son poids).
		world.pick_up({"collider": world.ground.bodies[bag_index], "position": world.ground.bodies[bag_index].global_position, "normal": Vector3.UP})
		var in_hand: Dictionary = {}
		var bag_place: Array = []
		for place in items.carried_places():
			if items.item(place[0], place[1]).get("objet") == "sac_filet":
				in_hand = items.item(place[0], place[1])
				bag_place = place
		# (une place sur l'épaule libre : R le remet directement sur l'épaule, ses objets retrouvés)
		var back_on: bool = items.bag_worn(0) and Inventory.BAG.any(func(index): return items.item("bar", index).get("objet") == "pomme")
		check(back_on or (in_hand.get("objet") == "sac_filet" and in_hand.pile[0].has("sac_id") and Inventory.stack_weight(in_hand) > float(in_hand.pile[0].get("poids", 90.0))), "R: picked up with its things (back on the shoulder, or in hand and heavier)")
		# Remis sur l'épaule : il retrouve ses objets (pour la suite du test).
		if not bag_place.is_empty():
			items.wear_bag(items.take(bag_place[0], bag_place[1]), 0)
	check(not Carnet.node("sac_sol").is_empty(), "a notebook case for the bag on the ground")
	world.close_inventory(false)
	var dropped: int = world.drop_all_items(world.player.global_position)
	check(dropped == 3 and not items.bag_worn(0) and not items.usable("bar", 6) and world.ground.entries.any(func(e): return e.item.get("objet") == "sac_filet"), "at death: the apple, the pebble and the bag fall")
	app.return_to_worlds()
	for path in [fixture, fixture + ".worlds"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d net bag checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func frames(count: int) -> void:
	for index in range(count):
		await process_frame
		await physics_frame
