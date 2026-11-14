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
	check(Controls.GROUPS.has("Inventaire") and Controls.GROUPS.Inventaire == ["inventory", "block_previous", "block_next"] and not "block_next" in Controls.GROUPS.Blocs, "Contrôles: Inventaire part with O + I and the wheel")
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
	check(natural == ["sable", "terre", "argile", "boue", "pierre", "calcaire", "pierre_sombre", "silex"], "natural materials listed")
	check(ui.grid_slots.all(func(slot): return not slot.locked) and ui.bar_slots.all(func(slot): return not slot.locked), "creative: nothing greyed")
	# Prendre dans une catégorie, poser dans la barre.
	ui._on_catalog(MOUSE_BUTTON_LEFT, 1)
	check(ui.cursor.visible and ui.cursor_item.objet == "terre", "click on a category item takes it")
	ui._on_slot(MOUSE_BUTTON_LEFT, "bar", 0)
	check(world.inventory.item("bar", 0).objet == "terre" and ui.cursor_item.is_empty(), "click on a bar slot puts it there")
	ui._on_catalog(MOUSE_BUTTON_LEFT, 4)
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
	# Survie : seules les 4 cases de droite, tout le reste grisé ; l'inventaire de Créatif est gardé à part.
	app.pause_game()
	app.pause_settings_button.pressed.emit()
	app.game_mode_buttons[Catalog.GAME_SURVIVAL].pressed.emit()
	app.settings_back_button.pressed.emit()
	app.resume_game()
	await process_frame
	check(world.inventory.mode == Inventory.SURVIVAL and world.inventory.selected() == 6 and world.player.selected_type == -1, "survival: own empty inventory, hand on slot 7")
	action(app, "inventory")
	check(ui.is_open() and not ui.creative_box.visible, "survival: no categories")
	var open_bar: Array = range(10).filter(func(index): return not ui.bar_slots[index].locked)
	check(open_bar == [6, 7, 8, 9] and ui.grid_slots.all(func(slot): return slot.locked), "survival: only the 4 right bar slots are not greyed")
	ui._on_slot(MOUSE_BUTTON_LEFT, "grid", 0)
	check(ui.message.text.contains("fermée"), "greyed slot says it is closed")
	action(app, "inventory")
	check(not ui.is_open(), "O + I closes it again")
	key(world, KEY_1)
	check(world.inventory.selected() == 6 and world.notice.contains("fermée"), "key 1 refused in survival")
	key(world, KEY_9)
	check(world.inventory.selected() == 8, "key 9 accepted in survival")
	world.player.cycle_block(1)
	world.player.cycle_block(1)
	check(world.inventory.selected() == 6, "wheel stays on the 4 open slots")
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
	check(bag.put("bar", 0, {"objet": "terre"}) == {"objet": "terre"} and bag.item("bar", 0).is_empty() and bag.first_free() == ["bar", 6], "survival: closed slots refuse items")
