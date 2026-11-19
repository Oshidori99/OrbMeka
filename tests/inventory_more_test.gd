extends SceneTree
# 0.0.7.29 (demandes de l'utilisateur) : mode de jeu choisi à la création (Survie par défaut), zone « Jeter » avec une
# croix et lâcher hors de la fenêtre, touche J (Survie), bouton « + » des cases (variantes en Créatif, détails en Survie,
# dans un ordre fixe), ligne ajoutée sous la case, touche D + T et Échap, zone qui défile.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
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

func press(ui: CanvasLayer, code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	ui._input(event)

func _run() -> void:
	# Données : variantes et ordre des détails.
	var branch := {"objet": "branche", "essence": 1, "longueur": 0.55, "epaisseur": 3.0, "fin": 2.4, "age": 2, "souplesse": 4, "poids": 300.0}
	check(Inventory.variants(branch).size() == 7 * 5 * 5 and Inventory.variants({"objet": "caillou", "taille": 4}).size() == 7 and Inventory.variants({"objet": "pomme"}).size() == 15 and Inventory.variants({"objet": "noisette"}).is_empty(), "variants: wood 7 sizes × 5 states × 5 suppleness, pebbles 7, apples 15, hazelnut none")
	check(Inventory.variants(branch).all(func(v): return Inventory.valid_item(v)), "every variant is a valid item")
	var lines: Array = Inventory.detail_lines(branch)
	var order := ["Longueur", "Épaisseur", "Forme", "État", "Souplesse", "Âge", "Manche", "Poids"]
	var at: Array = order.map(func(word): return lines.find(lines.filter(func(line): return line.begins_with(word))[0]) if lines.any(func(line): return line.begins_with(word)) else -1)
	check(lines[0] == "Branche de noisetier" and not at.has(-1) and at == at.duplicate().map(func(x): return x) and _sorted(at) and lines[-1].begins_with("Poids"), "details: name, length, thickness, shape, state, suppleness, age, handle, weight last: " + " | ".join(lines))
	check(Inventory.detail_lines({"objet": "caillou", "taille": 3})[-1].begins_with("Poids") and Inventory.detail_lines({"objet": "pomme", "taille": 1, "couleur": 2}).has("Couleur : jaune"), "pebble and apple details, weight last")
	check(Controls.ACTIONS.has("throw") and Controls.ACTIONS.throw.default.key == KEY_J and Controls.GROUPS.Inventaire.has("throw"), "Jeter: J by default, in Contrôles → Inventaire")
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/inventory-more-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(fixture)
	app.catalog = Catalog.new(fixture + ".worlds")
	root.add_child(app)
	current_scene = app
	await process_frame
	# Création : Survie choisie par défaut.
	app.show_page("create")
	await process_frame
	check(app.create_game_mode == Catalog.GAME_SURVIVAL and app.create_game_buttons[Catalog.GAME_SURVIVAL].button_pressed and not app.create_game_buttons[Catalog.GAME_CREATIVE].button_pressed, "create page: Survie chosen by default")
	app.create_game_buttons[Catalog.GAME_CREATIVE].pressed.emit()
	check(app.create_game_mode == Catalog.GAME_CREATIVE, "Créatif can be chosen")
	app.set_create_game_mode(Catalog.GAME_SURVIVAL)
	app.name_field.text = "Survie neuve"
	app.seed_field.text = "77"
	app.create_named_world()
	for i in range(5):
		await process_frame
	var created: Dictionary = app.catalog.worlds.filter(func(w): return w.name == "Survie neuve")[0]
	check(created.get("game_mode") == Catalog.GAME_SURVIVAL, "the new world is in Survie")
	var world: Node3D = app.active_world
	while world == null or not is_instance_valid(world):
		await process_frame
		world = app.active_world
	for i in range(5):
		await process_frame
	check(world.game_mode == Inventory.SURVIVAL, "opened in Survie")
	var ui: CanvasLayer = world.inventory_ui
	# Survie : J jette l'objet en main au sol.
	world.inventory.put("bar", 0, Inventory.single({"objet": "caillou", "taille": 2}))
	world.inventory.put("bar", 0, Inventory.single({"objet": "caillou", "taille": 3}))
	world.inventory.select(0)
	var before: int = world.ground.entries.size()
	check(world.throw_held() and world.ground.entries.size() == before + 1 and Inventory.count(world.inventory.item("bar", 0)) == 1, "J: one pebble thrown on the ground, one left in hand")
	# Survie : « + » sur la main : une carte de détails par caillou porté (main et poches).
	world.inventory.put("bar", 2, Inventory.single({"objet": "caillou_calcaire", "taille": 1}))
	world.open_inventory()
	await process_frame
	var hand: Object = ui._survival_bar_slots[0]
	check(hand.more and not ui.hud_slots[0].more, "survival: « + » on the inventory slot, never on the game bar")
	ui._toggle_more(hand)
	await process_frame
	var cards: Array = ui.more_nodes[0].get_children() if not ui.more_nodes.is_empty() else []
	check(cards.size() == 2 and ui.more_nodes[0].get_parent() == ui.survival_box and ui.more_nodes[0].get_index() == hand.get_parent().get_index() + 1, "survival details: a line just under the hands, one card per pebble carried (hand and pocket)")
	# 0.0.7.30 : « − » rouge une fois ouvert ; cartes compactes : le nom, puis deux détails par ligne, le poids en dernier.
	check(hand.opened, "opened: the « + » became a « − »")
	var details: Node = cards[0].find_child("Details", true, false) if not cards.is_empty() else null
	var title: Node = cards[0].find_child("Title", true, false) if not cards.is_empty() else null
	check(title != null and title.text.begins_with("Caillou") and details is GridContainer and details.columns == 2 and details.get_children()[-1].text.begins_with("Poids") and cards[0].tooltip_text.split("\n").size() == details.get_child_count() + 1, "a compact card: name, then two details per line, weight last, all on hover")
	check(cards[0].get_combined_minimum_size().y <= 70.0, "a compact card: %d px high at most 70" % roundi(cards[0].get_combined_minimum_size().y))
	ui._toggle_more(hand)
	check(ui.more_slot == null and not hand.opened, "closed again: back to « + »")
	ui._toggle_more(hand)
	# Jeter en Survie : par la zone, l'objet tombe au sol.
	ui._on_slot(MOUSE_BUTTON_LEFT, "bar", 2)
	before = world.ground.entries.size()
	ui.throw_cursor()
	await process_frame
	check(ui.cursor_item.is_empty() and world.inventory.item("bar", 2).is_empty() and world.ground.entries.size() == before + 1, "survival: thrown on the ground with the Jeter zone")
	var zones: Array = ui.screen.find_children("Throw", "", true, false)
	check(zones.size() == 2 and zones.any(func(zone): return zone.is_visible_in_tree()), "a Jeter zone under the bar (one shown)")
	world.close_inventory(false)
	# Créatif : variantes sous la ligne, défilement, jeter hors de la fenêtre.
	app.set_world_game_mode(Catalog.GAME_CREATIVE)
	world.open_inventory()
	ui.show_category(4)
	await process_frame
	var trunk: Object = ui.catalog_slots[0]
	check(trunk.more and trunk.item.objet == "tronc", "creative: « + » on an apple trunk")
	var children_before: int = ui.catalog.get_child_count()
	ui._toggle_more(trunk)
	await process_frame
	await process_frame
	var added: int = ui.catalog.get_child_count() - children_before
	var first_variant: int = ui.more_nodes.filter(func(node): return node.get("variant") == true)[0].get_index()
	check(added % Inventory.COLUMNS == 0 and added >= 175 and first_variant == 2 * Inventory.COLUMNS, "175 variants inserted as full lines just under the first line (the 8 woods line completed, then the details line)")
	# 0.0.7.30 : Créatif : une carte de détails au-dessus des variantes, sur toute la largeur.
	var flow: Control = ui.more_cards[0] if ui.more_cards.size() == 2 else null
	check(flow != null and flow.get_child_count() == 1 and flow.get_child(0).name == "DetailCard" and flow.size.y > 10.0 and absf(ui.more_cards[1][0].custom_minimum_size.y - flow.size.y) < 1.0 and flow.size.x >= ui.catalog.size.x - 1.0, "creative: the details card over a full line, before the variants")
	check(ui.creative_scroll.custom_minimum_size.y <= root.size.y * 0.5 + 1.0 and ui.creative_scroll.get_v_scroll_bar().custom_minimum_size.x >= 12, "a visible scroll bar, the list at most half the screen")
	var variant: Object = ui.more_nodes.filter(func(node): return node.get("variant") == true)[0]
	ui._on_variant(MOUSE_BUTTON_LEFT, variant.item)
	check(ui.cursor_item.get("epaisseur") == 2.0 and int(ui.cursor_item.get("age")) == 1, "a variant taken with the mouse (2 cm, young)")
	ui._on_background(_click())
	check(ui.cursor_item.is_empty() and ui.message.text.ends_with("jeté au sol."), "released outside the window: on the ground (Créatif too)")
	press(ui, KEY_ESCAPE)
	check(ui.more_slot == null and ui.is_open(), "Échap closes the variants first, the inventory stays open")
	# D + T (0.0.7.30 ; D seul avant) : ouvre sous la souris, D + T referme ; D seul ne fait plus rien.
	ui._open_more(trunk, true)
	check(ui.more_slot == trunk and ui.more_sticky, "D + T: opened, stays open")
	press(ui, KEY_D)
	check(ui.more_slot == trunk, "D alone: nothing (D + T now)")
	send_action(ui, "show_details")
	check(ui.more_slot == null, "D + T again: closed")
	# 0.0.7.30 : Créatif, objet qu'on a (barre) : ses cartes de détails (une par objet du tas).
	var inv: RefCounted = world.inventory
	inv.put("bar", 1, {})
	inv.put("bar", 1, {"objet": "caillou", "pile": [{"taille": 2}, {"taille": 5}]})
	await process_frame
	var owned: Object = ui._creative_bar_slots[1]
	ui._toggle_more(owned)
	await process_frame
	var owned_cards: Array = ui.more_nodes[0].find_child("Cards", true, false).get_children() if not ui.more_nodes.is_empty() else []
	check(owned.more and owned_cards.size() == 2 and ui.more_nodes[0].get_parent() == owned.get_parent().get_parent(), "creative, an owned stack: one details card per object, under the bar")
	ui._close_more()
	# Touche J dans l'inventaire : l'objet tenu (un seul, ou tout avec Ctrl droit) au sol, en Créatif aussi.
	ui._on_slot(MOUSE_BUTTON_LEFT, "bar", 1)
	before = world.ground.entries.size()
	check(ui.throw_key(false) and Inventory.count(ui.cursor_item) == 1 and int(ui.cursor_item.pile[0].taille) == 2 and world.ground.entries.size() == before + 1, "creative J in the inventory: one object of the held stack on the ground (the last taken)")
	ui._drop_cursor()
	inv.put("bar", 1, {"objet": "caillou", "pile": [{"taille": 3}]})
	ui._on_slot(MOUSE_BUTTON_LEFT, "bar", 1)
	before = world.ground.entries.size()
	check(ui.throw_key(true) and ui.cursor_item.is_empty() and inv.item("bar", 1).is_empty() and world.ground.entries.size() == before + 2, "Ctrl right + J: the whole held stack on the ground")
	check(not ui.throw_key(false), "J with nothing held and nothing under the mouse: nothing happens")
	# D + E (Créatif) : supprimé, rien ne tombe ; un objet du haut (illimité) : une copie tombe avec J, D + E le lâche.
	inv.put("bar", 1, {"objet": "caillou", "pile": [{"taille": 3}, {"taille": 4}]})
	ui._on_slot(MOUSE_BUTTON_LEFT, "bar", 1)
	before = world.ground.entries.size()
	check(ui.throw_key(false, true) and Inventory.count(ui.cursor_item) == 1 and world.ground.entries.size() == before and ui.message.text.ends_with("supprimé."), "D + E in the inventory: one object deleted, nothing on the ground")
	check(ui.throw_key(true, true) and ui.cursor_item.is_empty() and world.ground.entries.size() == before, "right Ctrl + D + E: the whole held stack deleted")
	ui._on_catalog(MOUSE_BUTTON_LEFT, 0)
	check(ui.throw_key(false) and not ui.cursor_item.is_empty() and world.ground.entries.size() == before + 1, "J on an unlimited object: a copy falls, it stays held")
	check(ui.throw_key(false, true) and ui.cursor_item.is_empty(), "D + E on an unlimited object: let go")
	check(Controls.ACTIONS.delete_item.default.key == KEY_D and Controls.ACTIONS.delete_item.default.second.key == KEY_E and Controls.ACTIONS.show_details.default.key == KEY_D and Controls.ACTIONS.show_details.default.second.key == KEY_T and Controls.GROUPS.Inventaire.has("delete_item") and Controls.GROUPS.Inventaire.has("show_details"), "Supprimer D + E, Détails D + T by default, in Contrôles → Inventaire")
	inv.put("bar", 1, {"objet": "caillou", "pile": [{"taille": 3}]})
	ui._on_slot(MOUSE_BUTTON_LEFT, "bar", 1)
	Controls.right_ctrl = false
	send_action(ui, "delete_item")
	check(ui.cursor_item.is_empty() and ui.message.text.ends_with("supprimé."), "D + E (sent as an action by the key combos): deletes the held object")
	# Ctrl droit : seulement celui de droite.
	var ctrl := InputEventKey.new()
	ctrl.keycode = KEY_CTRL
	ctrl.pressed = true
	ctrl.location = KEY_LOCATION_LEFT
	Controls.watch_right_ctrl(ctrl)
	var j := InputEventKey.new()
	j.keycode = KEY_J
	j.pressed = true
	j.ctrl_pressed = true
	check(not Controls.throw_all(j), "left Ctrl + J: one object only")
	ctrl.location = KEY_LOCATION_RIGHT
	Controls.watch_right_ctrl(ctrl)
	check(Controls.throw_all(j), "right Ctrl + J: the whole stack")
	ctrl.pressed = false
	Controls.watch_right_ctrl(ctrl)
	check(not Controls.throw_all(j), "right Ctrl released: one object again")
	world.close_inventory(false)
	# En jeu, en Créatif : J au sol, D + E supprime ; Ctrl droit : tout le tas.
	inv.put("bar", 0, {})
	inv.put("bar", 0, {"objet": "caillou", "pile": [{"taille": 1}, {"taille": 2}, {"taille": 3}, {"taille": 4}]})
	inv.select(0)
	before = world.ground.entries.size()
	check(world.throw_held(false) and Inventory.count(inv.item("bar", 0)) == 3 and world.ground.entries.size() == before + 1, "creative J in game: one object on the ground")
	check(world.delete_held(false) and Inventory.count(inv.item("bar", 0)) == 2 and world.ground.entries.size() == before + 1, "creative D + E in game: one object deleted, nothing on the ground")
	check(world.delete_held(true) and inv.item("bar", 0).is_empty() and world.ground.entries.size() == before + 1, "creative right Ctrl + D + E in game: the whole stack deleted")
	# Survie : Ctrl droit + J : tout le tas au sol.
	app.set_world_game_mode(Catalog.GAME_SURVIVAL)
	inv.put("bar", 0, {})
	inv.put("bar", 0, Inventory.single({"objet": "caillou", "taille": 1}))
	inv.put("bar", 0, Inventory.single({"objet": "caillou", "taille": 2}))
	inv.select(0)
	before = world.ground.entries.size()
	inv.put("bar", 1, Inventory.single({"objet": "caillou", "taille": 1}))
	inv.select(1)
	check(not world.delete_held(false) and Inventory.count(inv.item("bar", 1)) == 1, "survival: D + E deletes nothing")
	inv.select(0)
	check(world.throw_held(true) and inv.item("bar", 0).is_empty() and world.ground.entries.size() == before + 2, "survival right Ctrl + J: the whole stack on the ground")
	check(Controls.ACTIONS.throw.label.contains("Ctrl droit") and not Controls.ACTIONS.throw.label.contains("Survie"), "Contrôles: the Jeter label tells about right Ctrl")
	print("RESULT: %d inventory more checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

static func _sorted(values: Array) -> bool:
	for index in range(1, values.size()):
		if values[index] <= values[index - 1]:
			return false
	return true

static func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event

func send_action(ui: CanvasLayer, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	ui._input(event)
