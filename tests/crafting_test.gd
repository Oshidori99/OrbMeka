extends SceneTree
# 0.0.8.5 (#211, #213, demandes de l'utilisateur) : fabrication à la main, O + F. Tresser : 3 fibres du même type, clic
# gauche maintenu 3 s : 1 ficelle de 33 cm de ce type. Tailler : un caillou percuteur, un silex ou un calcaire de taille 3,
# 4 ou 5 ; 5, 6 ou 8 coups ; tête de hache ou de pioche (pierre et taille gardées) et un éclat tranchant ; le percuteur
# reste. Fendre, Assembler, Ficeler : grisées (« bientôt »). Créatif : aussi, avec le catalogue.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Rules = preload("res://scripts/crafting_rules.gd")
const Controls = preload("res://scripts/controls.gd")
const StoneHeads = preload("res://scripts/stone_heads.gd")
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

static func pile(id: String, instances: Array) -> Dictionary:
	return {"objet": id, "pile": instances}

static func survival() -> Inventory:
	var made := Inventory.new()
	made.mode = Inventory.SURVIVAL
	made.set_mode(Inventory.SURVIVAL)
	return made

func _run() -> void:
	check(Controls.ACTIONS.crafting.default.key == KEY_O and Controls.ACTIONS.crafting.default.second.key == KEY_F and Controls.GROUPS.Inventaire.has("crafting"), "O + F: Fabrication, in Contrôles → Inventaire")
	check(Rules.READY == ["tresser", "tailler"] and Rules.ACTIONS.size() == 5, "Tresser and Tailler ready; Fendre, Assembler, Ficeler: later")
	check(Rules.KNAP_HITS == {3: 5, 4: 6, 5: 8} and Rules.BRAID_FIBERS == 3 and Rules.BRAID_SECONDS == 3.0, "5, 6 or 8 hits; 3 fibres in 3 s")
	check(is_equal_approx(Inventory.instance_volume("fibre_lin", {}), 0.01), "a fibre: 10 ml")
	# Tresser : fibres prises dans les mains et les poches.
	var inv := survival()
	inv.put("bar", 0, pile("fibre_lin", [{}, {}]))
	inv.put("bar", 2, pile("fibre_lin", [{}, {}]))
	inv.put("bar", 3, pile("fibre_ortie", [{}, {}]))
	var fibres := Rules.choices(inv, "fibres")
	check(fibres.size() == 1 and fibres[0].fibres == "fibre_lin", "only a type with 3 fibres or more is proposed (lin: 4, ortie: 2)")
	check(Rules.take_fibres(inv, fibres[0]) and Inventory.count(inv.item("bar", 0)) + Inventory.count(inv.item("bar", 2)) == 1, "3 fibres taken from hands and pockets")
	var cord := Rules.cord_for("fibre_lin")
	check(cord.objet == "ficelle_lin" and is_equal_approx(cord.pile[0].longueur, 0.33) and Inventory.item_name(Inventory.flat(cord.objet, cord.pile[0])) == "Ficelle de lin", "1 Ficelle de lin, 33 cm")
	# Tailler.
	inv = survival()
	inv.put("bar", 0, pile("caillou", [{"taille": 3}]))
	inv.put("bar", 1, pile("caillou_silex", [{"taille": 4}]))
	inv.put("bar", 2, pile("caillou_calcaire", [{"taille": 2}]))
	check(Rules.choices(inv, "percuteur").size() == 3, "any pebble can be the hammer")
	var stones := Rules.choices(inv, "pierre")
	check(stones.size() == 1 and stones[0].value.objet == "caillou_silex", "only flint or limestone of size 3 to 5 can be knapped")
	check(Rules.hits_for(stones[0].value) == 6, "size 4: 6 hits")
	var results := Rules.knap_results({"objet": "caillou_silex", "taille": 4}, "pioche")
	var made_head: Dictionary = Inventory.flat(results[0].objet, results[0].pile[0])
	check(made_head.objet == "tete_pioche" and made_head.pierre == 1 and made_head.taille == 4 and Inventory.item_name(made_head) == "Tête de pioche en silex" and results[1].objet == "eclat_silex", "a flint pickaxe head (size kept) and a flint flake")
	check(Inventory.detail_lines(made_head).has("Taille : moyenne") and Inventory.valid_item(results[0]), "head details: its size")
	check(StoneHeads.mesh("hache", 0.0) != StoneHeads.mesh("hache", 1.0) and ItemIcons.for_value(results[0]) != null and ItemIcons.texture("ficelle_lin") != null, "the stone changes shape; icons")
	check(Inventory.CATEGORIES.filter(func(c): return c.id == "tools")[0].objets.has("tete_hache"), "Créatif: heads in the Outils tab")
	# En partie.
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/crafting-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = Catalog.new(fixture + ".worlds")
	var made: Dictionary = app.catalog.create_world("Fabrication", "79")
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
	for index in Inventory.HANDS + Inventory.POCKETS:
		world.inventory.put("bar", index, {})
	world.inventory.put("bar", 0, pile("fibre_ortie", [{}, {}, {}, {}]))
	world.inventory.put("bar", 2, pile("caillou", [{"taille": 3}]))
	world.inventory.put("bar", 3, pile("caillou_silex", [{"taille": 3}]))
	world.toggle_crafting()
	await process_frame
	await process_frame
	var ui: CanvasLayer = world.crafting_ui
	check(world.crafting_open and ui.visible and root.disable_3d and not world.hud_layer.visible and not world.inventory_ui.visible, "O + F: the crafting screen opens, the world frozen behind, the game HUD hidden")
	check(ui.slots.filter(func(s): return s.visible).size() == 6 and ui.slots[0].item.get("objet") == "fibre_ortie", "the usual slots (hands and pockets) shown under the scene")
	world.open_inventory()
	check(not world.inventory_open, "no inventory while crafting")
	ui.choose_action("tresser")
	ui.pick("fibres", Rules.choices(world.inventory, "fibres")[0])
	check(ui.hands[0].held.get_child_count() > 0 and ui.hands[1].held.get_child_count() > 0, "the fibres come into both hands")
	ui.holding = true
	for i in range(31):
		ui.step_braid(0.1)
	var cords := Rules.places(world.inventory).filter(func(p): return world.inventory.item(p[0], p[1]).get("objet") == "ficelle_ortie")
	check(cords.size() == 1 and Inventory.count(world.inventory.item("bar", 0)) == 1, "held 3 s: a nettle string, 3 fibres used")
	ui.choose_action("tailler")
	ui.pick("percuteur", Rules.choices(world.inventory, "percuteur").filter(func(c): return c.value.objet == "caillou")[0])
	ui.pick("pierre", Rules.choices(world.inventory, "pierre")[0])
	ui.choose_head("hache")
	ui.strike()
	check(ui.hits == 1 and is_instance_valid(ui.shaped), "first hit: the stone starts to take shape")
	for i in range(4):
		ui.strike()
	var heads := Rules.places(world.inventory).filter(func(p): return world.inventory.item(p[0], p[1]).get("objet") == "tete_hache")
	var flakes := Rules.places(world.inventory).filter(func(p): return world.inventory.item(p[0], p[1]).get("objet") == "eclat_silex")
	var hammers := Rules.places(world.inventory).filter(func(p): return world.inventory.item(p[0], p[1]).get("objet") == "caillou")
	var flints := Rules.places(world.inventory).filter(func(p): return world.inventory.item(p[0], p[1]).get("objet") == "caillou_silex")
	check(heads.size() == 1 and flakes.size() == 1 and hammers.size() == 1 and flints.is_empty(), "5 hits (size 3): an axe head and a flake; the flint is used, the hammer stays")
	app._cancel_page()
	check(not world.crafting_open and not ui.visible and not root.disable_3d and app.page == "playing" and world.hud_layer.visible, "Échap closes the crafting screen, back to the game (HUD shown again)")
	# Créatif : le catalogue, rien n'est pris.
	world.set_game_mode(Inventory.CREATIVE)
	world.toggle_crafting()
	await process_frame
	await process_frame
	var creative: Array = Rules.choices(world.inventory, "fibres").filter(func(c): return c.get("creative", false))
	check(creative.size() == 3, "Créatif: every fibre type from the catalogue")
	ui.choose_action("tresser")
	ui.pick("fibres", creative[1])
	ui.holding = true
	for i in range(31):
		ui.step_braid(0.1)
	check(Rules.places(world.inventory).any(func(p): return world.inventory.item(p[0], p[1]).get("objet") == "ficelle_lin"), "Créatif: a flax string made")
	world.toggle_crafting()
	await process_frame
	await process_frame
	check(not world.crafting_open, "O + F again: closed")
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for menu in Settings.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.file_path(menu)))
	print("RESULT: %d crafting checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
