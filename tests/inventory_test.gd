extends SceneTree
# 0.0.7.2 : inventaire (5 × 10 et barre de 10), objet en main, Créatif (catégories, tout ouvert) et Survie
# (seulement les 4 cases de droite de la barre), touche O + I, Échap, sauvegarde dans joueur.json.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Store = preload("res://scripts/world_store.gd")
const Controls = preload("res://scripts/controls.gd")
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

func action(app: Control, name: String) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	app._menu_shortcut(event)

func key(world: Node, code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	world.player._unhandled_input(event)

func _run() -> void:
	_data_checks()
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/inventory-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = Catalog.new(fixture + ".worlds")
	var item: Dictionary = app.catalog.create_world("Sac", "7")
	root.add_child(app)
	current_scene = app
	await process_frame
	# Contrôles : O + I, nouvelle partie Inventaire avec la molette.
	check(Controls.GROUPS.has("Inventaire") and Controls.GROUPS.Inventaire == ["inventory", "block_previous", "block_next", "pick_up", "gather"] and not "block_next" in Controls.GROUPS.Blocs, "Contrôles: Inventaire part with O + I and the wheel")
	check(Controls.combo_kind(Controls.options(Controls.default_for("inventory"))[0]) == "chord" and Controls.ACTIONS.inventory.label == "Inventaire", "Inventaire: O and I at the same time")
	app.open_world(item.id)
	await process_frame
	var world: Node3D = app.active_world
	var ui: CanvasLayer = world.inventory_ui
	check(world.find_child("SelectedBlock", true, false) == null and world.find_child("HotBar", true, false) != null, "no selected block text at the top left; hot bar shown")
	check(ui.hud_slots.size() == 10 and ui.hud_bar.visible and not ui.is_open(), "bar of 10 slots at the bottom, inventory closed")
	check(world.player.selected_type == -1 and world.held_text() == "Main vide", "new world: empty hand")
	check(not world.place_target({}, world.player.selected_type) and world.notice.contains("Rien à poser"), "nothing in hand: nothing is placed")
	# Ouvrir avec O + I.
	action(app, "inventory")
	check(ui.is_open() and world.inventory_open and not ui.hud_bar.visible and app.page == "playing", "O + I opens the inventory, game not paused")
	check(ui.grid_slots.size() == 50 and ui.bar_slots.size() == 10 and ui.panel.get_parent() == ui.screen, "grid of 5 × 10 and the bar of 10")
	var panel_style: StyleBoxFlat = ui.panel.get_theme_stylebox("panel")
	check(panel_style.bg_color.a < 1.0 and panel_style.bg_color.a > 0.5, "panel slightly transparent")
	check(ui.creative_box.visible and ui.tab_buttons.size() == 2 and ui.tab_buttons[0].text == "Matériaux naturels" and ui.tab_buttons[1].text == "Outils", "creative: categories Matériaux naturels and Outils")
	var natural: Array = ui.catalog_slots.filter(func(slot): return slot.visible).map(func(slot): return slot.item.objet)
	check(natural == ["sable", "terre", "argile", "boue", "gravier", "pierre", "calcaire", "pierre_sombre", "silex"], "natural materials listed (gravier 0.0.7.3)")
	check(ui.grid_slots.all(func(slot): return not slot.locked) and ui.bar_slots.all(func(slot): return not slot.locked and slot.visible), "creative: nothing greyed, 10 bar slots")
	# Prendre dans une catégorie, poser dans la barre.
	ui._on_catalog(MOUSE_BUTTON_LEFT, 1)
	check(ui.cursor.visible and ui.cursor_item.objet == "terre", "click on a category item takes it")
	ui._on_slot(MOUSE_BUTTON_LEFT, "bar", 0)
	check(world.inventory.item("bar", 0).objet == "terre" and ui.cursor_item.is_empty(), "click on a bar slot puts it there")
	ui._on_catalog(MOUSE_BUTTON_LEFT, 5)
	ui._on_slot(MOUSE_BUTTON_LEFT, "grid", 12)
	check(world.inventory.item("grid", 12).objet == "pierre", "and in the grid")
	ui.show_category(1)
	ui._on_catalog(MOUSE_BUTTON_RIGHT, 0)
	check(world.inventory.item("bar", 1).objet == "pioche", "right click on Outils: pickaxe in the first free slot")
	# Déplacer d'une case à l'autre, échanger, vider.
	ui._on_slot(MOUSE_BUTTON_LEFT, "grid", 12)
	ui._on_slot(MOUSE_BUTTON_LEFT, "bar", 1)
	check(world.inventory.item("bar", 1).objet == "pierre" and ui.cursor_item.objet == "pioche", "swap: stone in the bar, pickaxe held")
	ui._on_slot(MOUSE_BUTTON_LEFT, "bar", 2)
	ui._on_slot(MOUSE_BUTTON_RIGHT, "grid", 12)
	check(world.inventory.item("bar", 2).objet == "pioche" and world.inventory.item("grid", 12).is_empty(), "pickaxe placed, right click empties")
	# Échap ferme (sans pause).
	app._cancel_page()
	check(not ui.is_open() and not world.inventory_open and app.page == "playing" and ui.hud_bar.visible, "Escape closes the inventory, still playing")
	# Objet en main : touches 1 à 0 et molette.
	check(world.player.selected_type == 2, "slot 1 (terre) in hand")
	key(world, KEY_2)
	check(world.inventory.selected() == 1 and world.player.selected_type == 1 and world.notice == "Pierre", "key 2: stone in hand")
	key(world, KEY_3)
	check(world.player.selected_type == world.PICKAXE, "key 3: pickaxe in hand")
	key(world, KEY_0)
	check(world.inventory.selected() == 9 and world.player.selected_type == -1, "key 0: tenth slot, empty hand")
	world.player.cycle_block(1)
	check(world.inventory.selected() == 0, "wheel wraps to the first slot")
	check(ui.hud_slots[0].chosen and ui.hud_slots[0].item.objet == "terre", "bar shows the chosen slot and its item")
	check(world.PLACEABLE.has(world.SmoothTerrain.STONE) and world.PLACEABLE.has(world.SmoothTerrain.FLINT), "stone kinds can be placed")
	# Créatif : un morceau de pierre (pioche) se ramasse aussi ; il va dans la première case libre.
	world.drop_pieces("eclat_calcaire", 1, 125.0, world.player.global_position + Vector3.UP)
	check(world.ground.entries.size() == 1, "creative: stone pieces fall too")
	world.pick_up({"collider": world.ground.bodies[0], "position": world.ground.entries[0].position})
	check(world.ground.entries.is_empty() and world.inventory.item("bar", 3) == {"objet": "eclat_calcaire", "poids": 125.0, "nombre": 1}, "creative: piece picked up into the first free slot")
	world.inventory.take("bar", 3)
	# Survie (0.0.7.3) : deux mains (cases 1 et 2) et quatre poches (cases 3 à 6), rien de grisé, pas de grille.
	app.pause_game()
	app.pause_settings_button.pressed.emit()
	app.game_mode_buttons[Catalog.GAME_SURVIVAL].pressed.emit()
	app.settings_back_button.pressed.emit()
	app.resume_game()
	await process_frame
	check(world.inventory.mode == Inventory.SURVIVAL and world.inventory.selected() == 0 and world.player.selected_type == -1, "survival: own empty inventory, left hand chosen")
	var shown: Array = range(10).filter(func(index): return ui.hud_slots[index].visible)
	check(world.inventory.bar_slots() == [0, 1, 2, 3, 4, 5] and shown == [0, 1, 2, 3, 4, 5] and ui.hud_gap.visible, "survival bar: 2 hands, a gap, 4 pockets")
	check(ui.pockets_label.visible and ui.pockets_label.text == "Poches : 0,000 g / 150,0 g", "pockets weight at the bottom right")
	action(app, "inventory")
	check(ui.is_open() and not ui.creative_box.visible and not ui.grid_box.visible and ui.bar_titles.visible, "survival screen: only hands and pockets, no grid")
	action(app, "inventory")
	check(not ui.is_open(), "O + I closes it again")
	key(world, KEY_7)
	check(world.inventory.selected() == 0 and world.notice.contains("Survie"), "key 7: no such slot in survival")
	key(world, KEY_6)
	check(world.inventory.selected() == 5, "key 6: last pocket")
	world.player.cycle_block(1)
	check(world.inventory.selected() == 0, "wheel goes round hands and pockets")
	# Morceaux de pierre au sol, ramassés avec R : main gauche, puis main droite (objets différents), puis poches.
	world.drop_pieces("eclat_pierre", 2, 125.0, world.player.global_position + Vector3.UP)
	world.drop_pieces("charbon", 1, 125.0, world.player.global_position + Vector3.UP)
	check(world.ground.entries.size() == 3 and world.ground.entries.all(func(entry): return world.player.global_position.distance_to(entry.position) < 2.0), "pieces fall beside the player")
	for index in range(2):
		world.pick_up({"collider": world.ground.bodies[0], "position": world.ground.entries[0].position})
	check(world.inventory.item("bar", 0) == {"objet": "eclat_pierre", "poids": 125.0, "nombre": 2}, "identical pieces stack in the left hand")
	world.pick_up({"collider": world.ground.bodies[0], "position": world.ground.entries[0].position})
	check(world.inventory.item("bar", 1).objet == "charbon" and world.ground.entries.is_empty(), "another kind goes to the right hand")
	check(ui.hud_slots[0].note == "250,0 g" and ui.hud_slots[1].note == "125,0 g" and ui.hud_slots[2].note == "", "weight under each slot, nothing under an empty one")
	check(world.inventory.add({"objet": "terre", "nombre": 3}) == 1 and ui.pockets_label.text == "Poches : 100,0 g / 150,0 g", "pockets: 150 g in all (one handful of earth, not two)")
	world.drop_items({"objet": "terre", "nombre": 1})
	check(world.ground.entries.size() == 1 and world.ground.entries[0].item == {"objet": "terre"}, "what no longer fits is put on the ground")
	# Récupérer une poignée (R + I) : visée vers le sol, plus long que creuser ; puis poser l'utilise.
	for index in range(6):
		world.inventory.take("bar", index)
	world.player.camera.rotation.x = -1.35
	for index in range(40):
		await physics_frame
	var aimed: Dictionary = world.player.get_target()
	check(not aimed.is_empty() and aimed.collider.is_in_group("ground"), "player aims at the ground")
	check(not world.step_gather(0.6, true), "not yet after 0,6 s")
	var gathered: bool = world.step_gather(0.6, true)
	var aim_point: Vector3i = world.SmoothTerrain.point_of(aimed.position - aimed.normal * 0.3)
	check(gathered, "a handful after 1 s or more (" + world.notice + ", sorte " + str(world.terrain.materials.get(aim_point, world.terrain.natural_kind(aim_point))) + ")")
	var handful: Dictionary = world.inventory.item("bar", 0)
	check(world.GATHER_ITEMS.values().has(handful.get("objet")) and handful.nombre == 1, "handful in the left hand: " + str(handful))
	world.step_gather(0.1, false)
	world.inventory.select(0)
	world.player.brush = 0
	world.player.brush_size = 0
	await physics_frame
	check(world.place_target(world.player.get_target(), world.player.selected_type) and world.inventory.item("bar", 0).is_empty(), "placing uses the handful")
	check(not world.place_target(world.player.get_target(), world.player.selected_type), "nothing left to place")
	# Creuser en Survie : la matière est rejetée derrière soi (jamais dans le trou).
	for index in range(10):
		await physics_frame
	var before: Dictionary = world.terrain.changes.duplicate()
	var dig_hit: Dictionary = world.player.get_target()
	check(world.break_target(dig_hit), "survival: digging works by hand")
	var thrown := []
	for point in world.terrain.changes:
		if not before.has(point) and world.terrain.changes[point] > 0.0:
			thrown.append(point)
	var behind: Vector3 = world.player.global_transform.basis.z
	check(thrown.size() >= 1 and thrown.all(func(point): return (Vector3(point) * 0.5 - world.player.global_position).dot(behind) > -0.2 or absf((Vector3(point) * 0.5 - world.player.global_position).dot(world.player.global_transform.basis.x)) > 0.8), "dug earth thrown behind (or beside)")
	check(thrown.all(func(point): return Vector2(point.x * 0.5 - dig_hit.position.x, point.z * 0.5 - dig_hit.position.z).length() > 0.5), "never back into the hole")
	world.player.camera.rotation.x = 0.0
	app.set_world_game_mode(Catalog.GAME_CREATIVE)
	check(world.inventory.item("bar", 0).objet == "terre" and world.player.selected_type == 2, "back to creative: its inventory is back")
	# Pause avec l'inventaire ouvert : fermé.
	action(app, "inventory")
	app.pause_game()
	check(not world.inventory_open and app.page == "pause", "pausing closes the inventory")
	app.resume_game()
	await process_frame
	# Sauvegarde et relecture.
	world.save_now()
	var saved := Store.read_json(app.catalog.world_folder(item.id).path_join(Store.PLAYER_FILE), Store.valid_player)
	var bag: Dictionary = saved.get("data", {}).get("inventaire", {})
	check(bag.get("creatif", {}).get("barre", [])[0] == {"objet": "terre"} and bag.has("survie"), "inventory saved in joueur.json")
	var objects := Store.read_json(app.catalog.world_folder(item.id).path_join(Store.OBJECTS_FILE), func(_data): return true)
	check(objects.get("data", {}).get("objets_au_sol", []).size() == 1, "objects on the ground saved in objets.json")
	app.return_to_worlds()
	app.open_world(item.id)
	await process_frame
	world = app.active_world
	check(world.inventory.item("bar", 2).objet == "pioche" and world.inventory.selected() == 0 and world.player.selected_type == 2, "inventory read again with the world")
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for menu in Settings.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.file_path(menu)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d inventory checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

# Données seules : ancien monde, objets inconnus, aller-retour.
func _data_checks() -> void:
	var bag := Inventory.new()
	bag.from_dict(null)
	check(bag.item("bar", 0).is_empty() and bag.held_kind() == -1 and bag.mode == Inventory.CREATIVE, "old world without inventory: empty, no error")
	bag.from_dict({"format": 1, "creatif": {"barre": [{"objet": "sable"}, {"objet": "inconnu"}, 5], "grille": [null, {"objet": "silex"}], "main": 40}})
	check(bag.item("bar", 0).objet == "sable" and bag.item("bar", 1).is_empty() and bag.item("grid", 1).objet == "silex" and bag.selected() == 0, "unknown items and bad values ignored")
	var copy := Inventory.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(bag.to_dict())))
	check(copy.item("bar", 0).objet == "sable" and copy.item("grid", 1).objet == "silex", "save round trip through JSON")
	bag.set_mode(Inventory.SURVIVAL)
	check(bag.put("bar", 0, {"objet": "terre"}) == {"objet": "terre"} and bag.item("bar", 0).is_empty() and bag.put("bar", 7, {"objet": "terre", "nombre": 1}) == {"objet": "terre", "nombre": 1}, "survival: no unlimited items, no slot 8")
	# Poids et piles (0.0.7.3).
	check(bag.add({"objet": "terre", "nombre": 6}) == 6 and Inventory.count(bag.item("bar", 0)) == 4 and Inventory.count(bag.item("bar", 1)) == 2, "400 g per hand: 4 handfuls of earth, then the right hand")
	check(bag.add({"objet": "caillou", "nombre": 1, "taille": 4}) == 0, "a 400 g pebble no longer fits anywhere")
	check(bag.add({"objet": "caillou", "nombre": 3, "taille": 1}) == 3 and Inventory.count(bag.item("bar", 2)) == 3 and bag.pockets_weight() == 150.0, "pockets: 150 g in all (three 50 g pebbles)")
	check(not Inventory.same_kind({"objet": "caillou", "taille": 1, "nombre": 1}, {"objet": "caillou", "taille": 2, "nombre": 1}), "pebbles of another size do not stack")
	check(bag.put("bar", 3, {"objet": "silex", "nombre": 1}) == {"objet": "silex", "nombre": 1}, "a 250 g stone does not fit in full pockets")
	bag.select(0)
	check(bag.use_held(3) and Inventory.count(bag.held()) == 1 and bag.held_kind() == 2, "placing uses handfuls")
	var weights := [[0.0, "0,000 g"], [0.5, "500,0 mg"], [1.0, "1,000 g"], [12.5, "12,50 g"], [150.0, "150,0 g"], [999.96, "1,000 kg"], [1000.0, "1,000 kg"], [12345.0, "12,35 kg"], [999999.0, "1,000 Mg"], [2500000.0, "2,500 Mg"]]
	check(weights.all(func(pair): return Inventory.format_weight(pair[0]) == pair[1]), "weights always with 4 digits: " + str(weights.map(func(pair): return Inventory.format_weight(pair[0]))))
	var saved_bag := Inventory.new()
	saved_bag.mode = Inventory.SURVIVAL
	saved_bag.from_dict(JSON.parse_string(JSON.stringify(bag.to_dict())))
	check(saved_bag.item("bar", 2) == {"objet": "caillou", "nombre": 3, "taille": 1} and saved_bag.item("bar", 0) == {"objet": "terre", "nombre": 1}, "counts and sizes saved")
