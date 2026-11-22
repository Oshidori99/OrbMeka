extends SceneTree
# 0.0.7.2 : inventaire (5 × 10 et barre de 10), objet en main, Créatif (catégories, tout ouvert) et Survie
# (seulement les 4 cases de droite de la barre), touche O + I, Échap, sauvegarde dans joueur.json.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Store = preload("res://scripts/world_store.gd")
const Controls = preload("res://scripts/controls.gd")
const Inventory = preload("res://scripts/inventory.gd")
const ItemIcons = preload("res://scripts/item_icons.gd")
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
	check(Controls.GROUPS.has("Inventaire") and Controls.GROUPS.Inventaire == ["inventory", "crafting", "block_previous", "block_next", "pick_up", "pick_aimed", "gather", "throw", "delete_item", "show_details"] and not "block_next" in Controls.GROUPS.Blocs, "Contrôles: Inventaire part with O + I, O + F (0.0.8.5), the wheel and its click (0.0.8.15)")
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
	var tab_names: Array = ui.tab_buttons.map(func(tab): return tab.tooltip_text)
	check(ui.creative_box.visible and tab_names == ["Matériaux naturels", "Cailloux", "Fruits", "Outils", "Bois", "Plantes", "Inventaire"] and ui.tab_buttons.all(func(tab): return tab.text == "" and tab.icon != null), "creative: picture tabs (0.0.8.4 : Plantes), Inventaire at the right (0.0.7.5)")
	check(ui.tab_buttons[6].get_index() == ui.tab_buttons[5].get_index() + 2, "Inventaire tab pushed to the right")
	var natural: Array = ui.catalog_slots.filter(func(slot): return slot.visible).map(func(slot): return slot.item.objet)
	check(natural == ["sable", "terre", "argile", "boue", "gravier", "pierre", "calcaire", "pierre_sombre", "silex"], "natural materials listed (gravier 0.0.7.3)")
	check(ui.catalog.visible and not ui.grid_box.visible and ui.creative_bar.visible, "creative: the items of the tab and only the bar")
	ui.show_category(1)
	check(ui.catalog_slots.filter(func(slot): return slot.visible).map(func(slot): return slot.item) == [{"objet": "caillou", "taille": 4}, {"objet": "caillou_calcaire", "taille": 4}, {"objet": "caillou_silex", "taille": 4}], "Cailloux: stone, limestone, flint, size 4")
	ui.show_category(2)
	check(ui.catalog_slots.filter(func(slot): return slot.visible).map(func(slot): return slot.item) == [{"objet": "pomme", "taille": 2, "couleur": 1}, {"objet": "noisette"}], "Fruits: a red apple of size 2, a hazelnut")
	# 0.0.7.18 : Bois : pour chaque espèce, un tronc et une branche séparés, 1 m, toujours les mêmes.
	ui.show_category(4)
	var wood: Array = ui.catalog_slots.filter(func(slot): return slot.visible).map(func(slot): return slot.item)
	check(wood.size() == 8 and wood.map(func(item): return item.objet) == ["tronc", "branche", "tronc", "branche", "tronc", "branche", "tronc", "branche"] and wood.map(func(item): return int(item.essence)) == [0, 0, 1, 1, 2, 2, 3, 3], "Bois: a trunk and a branch for each tree")
	check(wood.all(func(item): return float(item.longueur) == 1.0 and float(item.epaisseur) == (20.0 if item.objet == "tronc" else 4.0)) and Inventory.catalog_item("tronc:2") == Inventory.catalog_item("tronc:2"), "trunks 20 cm, branches 4 cm, 1 m long, always the same")
	check(Inventory.item_name(wood[2]) == "Tronc de noisetier" and Inventory.item_name(wood[7]) == "Branche de tilleul" and ItemIcons.tab("wood", 34) != null, "named after their tree, with a tab picture")
	# 0.0.8.15 : l'onglet Plantes montre ses objets (avant : la grille, par erreur), la grille est le dernier onglet.
	ui.show_category(5)
	check(ui.catalog.visible and not ui.grid_box.visible and ui.catalog_slots.filter(func(slot): return slot.visible).map(func(slot): return slot.item.objet).has("fibre_lin"), "Plantes tab: its items, not the grid")
	ui.show_category(ui.INVENTORY_TAB)
	check(ui.INVENTORY_TAB == Inventory.CATEGORIES.size() and not ui.catalog.visible and ui.grid_box.visible and ui.creative_bar.visible, "Inventaire tab (last): the grid of 5 rows and the bar")
	ui.show_category(0)
	check(ui.grid_slots.all(func(slot): return not slot.locked) and ui.bar_slots.all(func(slot): return not slot.locked and slot.visible), "creative: nothing greyed, 10 bar slots")
	# Prendre dans une catégorie, poser dans la barre.
	ui._on_catalog(MOUSE_BUTTON_LEFT, 1)
	check(ui.cursor.visible and ui.cursor_item.objet == "terre", "click on a category item takes it")
	ui._on_slot(MOUSE_BUTTON_LEFT, "bar", 0)
	check(world.inventory.item("bar", 0).objet == "terre" and ui.cursor_item.is_empty(), "click on a bar slot puts it there")
	ui._on_catalog(MOUSE_BUTTON_LEFT, 5)
	ui._on_slot(MOUSE_BUTTON_LEFT, "grid", 12)
	check(world.inventory.item("grid", 12).objet == "pierre", "and in the grid")
	ui.show_category(3)
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
	# 0.0.7.6 : main à la première personne, qui tient l'objet choisi ; gravier enfin posable ; caillou de taille 6 ramassable.
	check(world.player.hand_view != null and world.player.hand_view.held.get_child_count() >= 1 and world.player.hand_view.visible, "the first-person hand holds the chosen item")
	check(world.PLACEABLE.has(world.SmoothTerrain.GRAVEL) and Inventory.PICKABLE_SIZE == 6 and Inventory.PEBBLE_WEIGHTS[5] == 2750.0 and Inventory.HANDS_LIMIT == 8000.0 and Inventory.TWO_HANDS == 4000.0, "gravel can be placed; size 6 pebbles (2,75 kg since 0.0.8.7) fit in the hands (4 kg per hand, 8 kg for both since 0.0.7.19)")
	check(world.PLACEABLE.has(world.SmoothTerrain.STONE) and world.PLACEABLE.has(world.SmoothTerrain.FLINT), "stone kinds can be placed")
	# Créatif : un morceau de pierre (pioche) se ramasse aussi. 0.0.7.5 : dans la case choisie, avec ses caractéristiques.
	world.drop_pieces("eclat_calcaire", 1, 125.0, world.player.global_position + Vector3.UP)
	check(world.ground.entries.size() == 1, "creative: stone pieces fall too")
	var piece: Dictionary = world.ground.entries[0].item.duplicate()
	check(piece.has("forme") and piece.has("rotation") and piece.poids == 125.0, "a piece on the ground has its own shape and turn")
	world.pick_up({"collider": world.ground.bodies[0], "position": world.ground.entries[0].position})
	check(world.ground.entries.size() == 1 and world.notice.contains("occupée"), "chosen slot taken by another item: refused, the piece stays")
	world.inventory.select(3)
	world.pick_up({"collider": world.ground.bodies[0], "position": world.ground.entries[0].position})
	check(world.ground.entries.is_empty() and world.inventory.item("bar", 3) == {"objet": "eclat_calcaire", "pile": [Inventory.traits(piece)]}, "picked up into the chosen slot, with all its characteristics")
	world.inventory.take("bar", 3)
	# Barre pleine : dans une case libre de l'inventaire.
	for index in range(10):
		if world.inventory.item("bar", index).is_empty():
			world.inventory.put("bar", index, {"objet": "sable"})
	world.drop_pieces("eclat_pierre", 1, 125.0, world.player.global_position + Vector3.UP)
	world.pick_up({"collider": world.ground.bodies[0], "position": world.ground.entries[0].position})
	check(world.ground.entries.is_empty() and world.inventory.item("grid", 0).objet == "eclat_pierre", "full bar: into a free slot of the inventory")
	world.inventory.take("grid", 0)
	for index in range(3, 10):
		world.inventory.take("bar", index)
	# Cueillir (0.0.7.5) : seulement en visant vraiment une pomme.
	var Trees = world.Trees
	var tree: Node3D = Trees.tree_body(Trees.APPLE, 3)
	tree.set_meta("id", "pommier-essai")
	world.add_child(tree)
	tree.global_position = world.player.global_position + Vector3(2.0, 0.0, 0.0)
	var column: Vector2i = world._player_column()
	world.column_objects[column] = world.column_objects.get(column, []) + [tree]
	var eye: Vector3 = world.player.camera.global_position
	var nearest: Vector3 = Vector3.ZERO
	for spot in Trees.fruit_spots(Trees.APPLE, 3):
		var at: Vector3 = tree.global_transform * spot[0]
		if nearest == Vector3.ZERO or eye.distance_to(at) < eye.distance_to(nearest):
			nearest = at
	var saved_turn: Vector3 = world.player.camera.rotation
	world.player.camera.look_at(nearest + Vector3(0.0, 0.0, 0.001))
	check(Trees.fruit_spots(Trees.APPLE, 3).size() > 10 and not world.aimed_fruit({}).is_empty(), "aiming right at an apple finds it")
	world.inventory.select(3)
	check(world.pick_up({}) and world.inventory.item("bar", 3).objet == "pomme" and world.picked_fruits.get("pommier-essai", []).size() == 1 and tree.get_node_or_null("Modele/Fruits") != null, "R picks the apple; it disappears from this tree only")
	var apple_traits: Dictionary = world.inventory.item("bar", 3).pile[0]
	check(apple_traits.taille in [1, 2, 3] and apple_traits.couleur in [0, 1, 2, 3, 4] and float(apple_traits.get("diametre", 0.0)) > 0.04, "the apple keeps its size, colour and true diameter from the tree")
	world.player.camera.look_at(nearest + Vector3(0.0, 3.0, 0.0))
	world.player.camera.look_at(eye + Vector3(0.0, 5.0, 0.3))
	check(world.aimed_fruit({}).is_empty(), "looking at the sky: no fruit")
	world.player.camera.rotation = saved_turn
	world.column_objects[column].erase(tree)
	tree.queue_free()
	world.picked_fruits.erase("pommier-essai")
	world.inventory.take("bar", 3)
	world.inventory.select(0)
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
	check(ui.weights_label.visible and ui.hud_carried.mains[1].text == "0,000 g / 8,000 kg · 0,00 L / 3,0 L" and ui.hud_carried.poches[1].text == "0,000 g / 1,000 kg · 0,00 L / 0,50 L" and ui.hud_carried.mains[0].share == 0.0, "hands and pockets at the bottom right: a picture, a bar, weight and volume (0.0.7.19)")
	action(app, "inventory")
	check(ui.is_open() and not ui.creative_box.visible and not ui.grid_box.visible and ui.survival_box.visible and ui.hands_weight.text == "0,000 g / 8,000 kg · 0,00 L / 3,0 L" and ui.pockets_weight.text == "0,000 g / 1,000 kg · 0,00 L / 0,50 L" and ui.panel_bars.Mains.size() == 2, "survival screen: a row for the hands, a row for the pockets, no grid")
	check(ui.bar_slots.size() == 10 and ui.survival_box.is_ancestor_of(ui.bar_slots[0]) and ui.survival_box.is_ancestor_of(ui.bar_slots[5]), "survival slots are in the hands and pockets rows")
	check(ui.equipment_slots.size() == 8 and ui.equipment_slots.all(func(slot): return slot.locked and slot.item.is_empty() and slot.picture != null) and ui.survival_area.is_ancestor_of(ui.equipment_slots[0]), "equipment to come at the right: 2 bags, 2 baskets, 2 travois, 2 carts, greyed (0.0.7.7)")
	action(app, "inventory")
	check(not ui.is_open(), "O + I closes it again")
	key(world, KEY_7)
	check(world.inventory.selected() == 0 and world.notice.contains("Survie"), "key 7: no such slot in survival")
	key(world, KEY_6)
	check(world.inventory.selected() == 5, "key 6: last pocket")
	world.player.cycle_block(1)
	check(world.inventory.selected() == 0, "wheel goes round hands and pockets")
	# Morceaux de pierre au sol, ramassés avec R : la main choisie (gauche), puis l'autre main libre (droite), puis poches.
	world.drop_pieces("eclat_pierre", 2, 125.0, world.player.global_position + Vector3.UP)
	world.drop_pieces("charbon", 1, 125.0, world.player.global_position + Vector3.UP)
	check(world.ground.entries.size() == 3 and world.ground.entries.all(func(entry): return world.player.global_position.distance_to(entry.position) < 2.0), "pieces fall beside the player")
	for index in range(2):
		world.pick_up({"collider": world.ground.bodies[0], "position": world.ground.entries[0].position})
	check(world.inventory.item("bar", 0).objet == "eclat_pierre" and Inventory.count(world.inventory.item("bar", 0)) == 2 and Inventory.stack_weight(world.inventory.item("bar", 0)) == 250.0, "pieces of the same kind go together in the chosen slot (left hand)")
	var coal: Dictionary = world.ground.entries[0].item.duplicate()
	world.pick_up({"collider": world.ground.bodies[0], "position": world.ground.entries[0].position})
	check(world.inventory.item("bar", 1).get("objet") == "charbon" and world.ground.entries.is_empty(), "chosen hand busy: the coal goes to the other (right) hand (0.0.7.10)")
	check(ui.hud_slots[0].title == "" and ui.hud_slots[0].note == "250,0 g" and ui.hud_slots[1].note == "125,0 g" and ui.hud_slots[2].title == "" and ui.hud_slots[2].note == "", "0.0.8.3: only the weight under each slot (name shown above when taken in hand), nothing under an empty one")
	check(world.inventory.add({"objet": "terre", "nombre": 6}) == 2 and ui.hud_carried.poches[1].text.begins_with("650,0 g / 1,000 kg") and is_equal_approx(ui.panel_bars.Poches[0].share, 0.65) and is_equal_approx(ui.panel_bars.Poches[1].share, 1.0), "pockets: 1 kg in all since 0.0.8.7 (two handfuls of earth of 325 g fill the 0,5 L)")
	# Reposer un objet tenu (clic droit) : il retourne au sol là où l'on vise.
	world.inventory.select(1)
	world.player.brush = 0
	var spot: Vector3 = world.player.global_position - world.player.global_transform.basis.z * 1.5
	check(world.place_target({"collider": world.ground, "position": spot}, world.player.selected_type) and world.inventory.item("bar", 1).is_empty() and world.ground.entries.size() == 1 and Vector2(world.ground.entries[0].position.x - spot.x, world.ground.entries[0].position.z - spot.z).length() < 0.01, "right click puts the held piece down where aimed")
	check(world.ground.entries[0].item == coal, "put back exactly as it was (shape, turn, weight)")
	world.pick_up({"collider": world.ground.bodies[0], "position": world.ground.entries[0].position})
	world.inventory.select(0)
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
	# 0.0.8.15 (#239) : sur l'herbe, d'abord une motte de gazon (l'herbe disparaît) ; ensuite la terre dessous.
	if handful.get("objet") == "gazon":
		check(true, "on grass: a turf first")
		world.inventory.take("bar", 0)
		world.step_gather(0.1, false)
		world.step_gather(0.6, true)
		world.step_gather(0.6, true)
		handful = world.inventory.item("bar", 0)
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
	# 0.0.7.27 (#217) : en Survie, on creuse en maintenant le clic, selon la matière (terre 0,6 s par sous-cellule).
	check(not world.break_target(dig_hit) and world.terrain.changes == before, "survival: a click alone does not dig")
	var dig_held := 0.0
	var dug_now := false
	while not dug_now and dig_held < 5.0:
		dug_now = world.step_dig(1.0 / 60.0, true, dig_hit)
		dig_held += 1.0 / 60.0
	check(dug_now and dig_held >= 0.25 and dig_held <= 1.1, "survival: holding digs by hand (%.2f s)" % dig_held)
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
	# 0.0.7.4 : 1 kg pour les deux mains ensemble, 500 g pour les quatre poches ensemble (0.0.8.7 : 1 kg).
	# 0.0.7.19 : une poignée = 0,25 L : 3 L à deux mains = 12 poignées (3,9 kg) ; la 13e va dans les poches (0,5 L, 1 kg depuis 0.0.8.7).
	check(bag.add({"objet": "terre", "nombre": 13}) == 13 and Inventory.count(bag.item("bar", 0)) == 12 and bag.item("bar", 1).is_empty() and Inventory.count(bag.item("bar", 2)) == 1 and bag.two_handed() == 0, "3 L in both hands (0.0.7.19): 12 handfuls of earth carried with both hands, the right hand stays empty, 1 in the pockets")
	check(bag.add({"objet": "caillou", "pile": [{"taille": 4}]}) == 0, "a 1 kg pebble no longer fits anywhere")
	check(bag.add({"objet": "caillou", "pile": [{"taille": 1, "forme": 2}, {"taille": 1, "forme": 5}]}) == 2 and bag.item("bar", 1).is_empty() and Inventory.count(bag.item("bar", 3)) == 2 and bag.hands_weight() == 3900.0 and bag.pockets_weight() == 575.0 and bag.two_handed() == 0, "two 125 g pebbles: not in the busy right hand, both in a pocket (%s / %s / %d g)" % [bag.item("bar", 3), bag.item("bar", 4), bag.pockets_weight()])
	check(Inventory.same_kind({"objet": "caillou", "pile": [{"taille": 1}]}, {"objet": "caillou", "pile": [{"taille": 2}]}) and not Inventory.same_kind({"objet": "caillou", "pile": [{"taille": 1}]}, {"objet": "caillou_silex", "pile": [{"taille": 1}]}), "pebbles of different sizes share a slot, not different kinds (0.0.7.5)")
	check(bag.put("bar", 4, {"objet": "silex", "nombre": 1}) == {"objet": "silex", "nombre": 1}, "a 650 g stone does not fit in the 425 g left in the pockets")
	bag.select(0)
	check(bag.use_held(3) and Inventory.count(bag.held()) == 9 and bag.held_kind() == 2, "placing uses handfuls")
	var icons := Inventory.ITEMS.keys().all(func(id): return ItemIcons.texture(id) != null and ItemIcons.texture(id).get_width() == ItemIcons.SIZE)
	check(icons and ItemIcons.hand() != null and ItemIcons.pocket() != null and ItemIcons.natural_tab(34) != null and ItemIcons.texture("sable") == ItemIcons.texture("sable"), "an icon for every item, hand and pocket pictures, made once")
	var weights := [[0.0, "0,000 g"], [0.5, "500,0 mg"], [1.0, "1,000 g"], [12.5, "12,50 g"], [150.0, "150,0 g"], [999.96, "1,000 kg"], [1000.0, "1,000 kg"], [12345.0, "12,35 kg"], [999999.0, "1,000 Mg"], [2500000.0, "2,500 Mg"]]
	check(weights.all(func(pair): return Inventory.format_weight(pair[0]) == pair[1]), "weights always with 4 digits: " + str(weights.map(func(pair): return Inventory.format_weight(pair[0]))))
	var saved_bag := Inventory.new()
	saved_bag.mode = Inventory.SURVIVAL
	saved_bag.from_dict(JSON.parse_string(JSON.stringify(bag.to_dict())))
	check(saved_bag.item("bar", 3) == {"objet": "caillou", "pile": [{"taille": 1, "forme": 2}, {"taille": 1, "forme": 5}]} and saved_bag.item("bar", 0) == {"objet": "terre", "nombre": 9}, "each object saved with its own characteristics")
	# 0.0.7.5 : le dernier pris est le premier reposé ; chacun garde sa taille.
	var mixed := Inventory.new()
	mixed.mode = Inventory.SURVIVAL
	mixed.set_mode(Inventory.SURVIVAL)
	check(mixed.add_to_selected({"objet": "caillou_silex", "pile": [{"taille": 4, "forme": 3, "rotation": 1.25}]}).added == 1 and mixed.add_to_selected({"objet": "caillou_silex", "pile": [{"taille": 1, "forme": 6}]}).added == 1, "a big then a small flint nodule in the same hand")
	check(Inventory.stack_weight(mixed.held()) == 1125.0 and mixed.pop_held() == {"objet": "caillou_silex", "taille": 1, "forme": 6} and mixed.pop_held() == {"objet": "caillou_silex", "taille": 4, "forme": 3, "rotation": 1.25} and mixed.held().is_empty(), "put down: the small one first, then the big one, each unchanged")
	# 0.0.7.19 : à deux mains au-delà de 4 kg ; 8 kg au plus. 0.0.8.7 : 1,75 kg + 2,75 kg (4,5 kg : à deux mains), puis 2,75 kg (7,25 kg) ; le dernier (10 kg) est refusé.
	check(mixed.add_to_selected({"objet": "caillou", "pile": [{"taille": 5}]}).added == 1 and mixed.add_to_selected({"objet": "caillou", "pile": [{"taille": 6}]}).added == 1, "4,5 kg of stones: carried with both hands")
	var too_much: Dictionary = mixed.add_to_selected({"objet": "caillou", "pile": [{"taille": 6}, {"taille": 6}]})
	check(too_much.added == 1 and too_much.reason == "lourd", "8 kg in the hands at most: the last big stone is refused (too heavy)")
	mixed.select(1)
	check(mixed.two_handed() == 0 and mixed.add_to_selected({"objet": "sable", "nombre": 1}).added == 0 and mixed.carry_factor() < 0.8, "carried with both hands: the other hand takes nothing, walking is slower")
	# 0.0.7.19 : nombre au plus par main (noisettes : 8, 16 à deux mains ; 0.0.8.3 : 5 et 10), volume (le bois compte par sa longueur).
	var nuts := Inventory.new()
	nuts.mode = Inventory.SURVIVAL
	nuts.set_mode(Inventory.SURVIVAL)
	var many := {"objet": "noisette", "pile": []}
	for index in range(20):
		many.pile.append({"diametre": 0.018})
	var nut_result: Dictionary = nuts.add_to_selected(many)
	check(Inventory.hand_count("noisette") == 5 and Inventory.count(nuts.item("bar", 0)) == 10 and nuts.two_handed() == 0, "hazelnuts: 5 in a hand, 10 with both hands (%d)" % Inventory.count(nuts.item("bar", 0)))
	var wood_bag := Inventory.new()
	wood_bag.mode = Inventory.SURVIVAL
	wood_bag.set_mode(Inventory.SURVIVAL)
	var wood_rng := RandomNumberGenerator.new()
	wood_rng.seed = 19
	var long_stick := Inventory.wood_piece("branche", 1, 4.0, 3.5, wood_rng)
	var refused: Dictionary = wood_bag.add_to_selected(Inventory.single(long_stick))
	check(refused.added == 0 and refused.reason == "encombrant" and absf(Inventory.instance_volume("branche", long_stick) - 3.5) < 0.01, "a 3.5 m stick is too cumbersome (wood counts 1 L per metre)")
	var log_piece := Inventory.wood_piece("tronc", 0, 15.0, 0.6, wood_rng)
	check(wood_bag.add_to_selected(Inventory.single(log_piece)).added == 1 and wood_bag.two_handed() == 0 and float(log_piece.poids) > 7000.0, "a log of 15 cm × 60 cm (%s) is carried with both hands" % Inventory.format_weight(float(log_piece.poids)))
	check(Inventory.plural_name({"objet": "noisette"}) == "noisettes" and Inventory.plural_name({"objet": "caillou"}) == "cailloux" and Inventory.format_volume(0.25) == "0,25 L" and Inventory.format_volume(3.0) == "3,0 L", "plural names and volumes written the French way")
	check(not (1 in mixed.bar_slots()) and mixed.bar_slots().size() == 5 and mixed.selected() == 0 and mixed.held().get("objet") == "caillou", "both hands in one slot: one slot less in the bar, choosing the other hand chooses it (0.0.7.10)")
	mixed.select(0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var stick := Inventory.wood_piece("branche", 1, 3.0, 0.8, rng)
	check(stick.taille == 2 and stick.age >= 1 and stick.age <= 5 and stick.souplesse >= 1 and stick.souplesse <= 5 and stick.poids > 100.0 and stick.poids < 600.0 and Inventory.valid_item(Inventory.single(stick)), "a branch: thickness, length, essence, age, suppleness, weight (0.0.7.8)")
	mixed.select(2)
	check(mixed.add_to_selected({"objet": "sable", "nombre": 1}).added == 1 and mixed.item("bar", 2).objet == "sable", "into the chosen pocket")
	mixed.select(3)
	mixed.put("bar", 3, {"objet": "noisette", "pile": [{}]})
	check(mixed.add_to_selected({"objet": "sable", "nombre": 1}).reason == "occupee", "chosen slot taken, other slots free: refused (choose another)")
	# Anciennes sauvegardes (0.0.7.3, 0.0.7.4) : cailloux et éclats avec « nombre » deviennent des piles.
	var old := Inventory.new()
	old.from_dict({"format": 2, "survie": {"barre": [{"objet": "caillou", "nombre": 2, "taille": 3}, {"objet": "eclat_pierre", "nombre": 1, "poids": 125.0}], "main": 0}})
	old.set_mode(Inventory.SURVIVAL)
	check(old.item("bar", 0) == {"objet": "caillou", "pile": [{"taille": 3}, {"taille": 3}]} and old.item("bar", 1) == {"objet": "eclat_pierre", "pile": [{"poids": 125.0}]}, "old saves read as piles")
	check(ItemIcons.for_value({"objet": "pomme", "pile": [{"taille": 2, "couleur": 0}]}) != ItemIcons.for_value({"objet": "pomme", "pile": [{"taille": 2, "couleur": 1}]}) and ItemIcons.tab("inventory", 34) != null and ItemIcons.tab("fruits", 34) != null, "apple icon follows its colour; tab pictures")
