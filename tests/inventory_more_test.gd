extends SceneTree
# 0.0.7.29 (demandes de l'utilisateur) : mode de jeu choisi à la création (Survie par défaut), zone « Jeter » avec une
# croix et lâcher hors de la fenêtre, touche J (Survie), bouton « + » des cases (variantes en Créatif, détails en Survie,
# dans un ordre fixe), ligne ajoutée sous la case, touche D et Échap, zone qui défile.
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
	var text: String = cards[0].find_child("Details", true, false).text if not cards.is_empty() else ""
	check(text.begins_with("Caillou") and text.split("\n")[-1].begins_with("Poids"), "a card: one detail per line, weight last")
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
	check(added % Inventory.COLUMNS == 0 and added >= 175 and first_variant == Inventory.COLUMNS, "175 variants inserted as full lines just under the first line (the 8 woods line completed)")
	check(ui.creative_scroll.custom_minimum_size.y <= root.size.y * 0.5 + 1.0 and ui.creative_scroll.get_v_scroll_bar().custom_minimum_size.x >= 12, "a visible scroll bar, the list at most half the screen")
	var variant: Object = ui.more_nodes.filter(func(node): return node.get("variant") == true)[0]
	ui._on_variant(MOUSE_BUTTON_LEFT, variant.item)
	check(ui.cursor_item.get("epaisseur") == 2.0 and int(ui.cursor_item.get("age")) == 1, "a variant taken with the mouse (2 cm, young)")
	ui._on_background(_click())
	check(ui.cursor_item.is_empty() and ui.message.text.ends_with("jeté."), "released outside the window: thrown away")
	press(ui, KEY_ESCAPE)
	check(ui.more_slot == null and ui.is_open(), "Échap closes the variants first, the inventory stays open")
	# Touche D : ouvre sous la souris, D referme.
	ui._open_more(trunk, true)
	check(ui.more_slot == trunk and ui.more_sticky, "D: opened, stays open")
	press(ui, KEY_D)
	check(ui.more_slot == null, "D again: closed")
	world.close_inventory(false)
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
