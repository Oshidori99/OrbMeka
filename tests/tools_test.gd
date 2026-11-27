extends SceneTree
# 0.0.8.10 (#202, demandes de l'utilisateur) : outils utiles et usure. Hache en pierre : le bois 3 fois plus vite, troncs
# jusqu'à 80 cm (0.0.8.47 ; avant 1 m) ; pioche en pierre : la pierre 4 fois plus vite (avec des éclats), la terre 2 fois ; selon la qualité.
# Usure : 50 à 300 coups selon la fabrication ; à 0, l'outil casse (tête et manche au sol) ; barre verte → rouge ;
# détails : « Usure : N coups restants sur M ».
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Rules = preload("res://scripts/crafting_rules.gd")
const InventoryUI = preload("res://scripts/inventory_ui.gd")
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

func _run() -> void:
	var best := {"objet": "hache_pierre", "pierre": 1, "taille": 5, "essence": 1, "souplesse": 3, "lien": 1, "tours": 8}
	var worst := {"objet": "hache_pierre", "pierre": 0, "taille": 3, "essence": 2, "souplesse": 5, "morte": 1, "lien": 3, "tours": 4}
	check(Inventory.tool_durability(best) >= 250 and Inventory.tool_durability(best) <= 300, "best axe: about 300 hits (%d)" % Inventory.tool_durability(best))
	check(Inventory.tool_durability(worst) >= 50 and Inventory.tool_durability(worst) <= 70, "worst axe: about 50 hits (%d)" % Inventory.tool_durability(worst))
	check(Inventory.tool_quality(best) > Inventory.tool_quality(worst) and Inventory.tool_speed(best, "bois") > 3.0 and Inventory.tool_speed(worst, "bois") < 3.0 and Inventory.tool_speed(best, "pierre") == 1.0, "quality: a better axe is faster; an axe does not help with stone")
	var pick := {"objet": "pioche_pierre", "pierre": 1, "taille": 4, "lien": 1, "tours": 6}
	check(Inventory.tool_speed(pick, "pierre") > 3.5 and Inventory.tool_speed(pick, "terre") > 1.8 and Inventory.tool_speed(pick, "bois") == 1.0, "pickaxe: stone about 4 times faster, earth 2 times")
	var made := Rules.bind_result({"objet": "hache_a_ficeler", "pierre": 1, "taille": 5, "essence": 1, "souplesse": 3, "poids": 600.0}, "ficelle_lin", 8)
	check(int(made.pile[0].usure) == Inventory.tool_durability(Inventory.flat(made.objet, made.pile[0])), "a new tool has all its hits")
	var lines := Inventory.detail_lines(Inventory.flat(made.objet, made.pile[0]))
	check(lines.any(func(l): return l.begins_with("Usure : ") and l.contains("coups restants sur")), "details: hits left out of the new tool's: " + " | ".join(lines))
	check(InventoryUI.Slot.wear_color(1.0).g > 0.8 and InventoryUI.Slot.wear_color(0.5).r > 0.9 and InventoryUI.Slot.wear_color(0.05).g < 0.3, "wear bar: green, then yellow, ... red")
	# En partie.
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/tools-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = Catalog.new(fixture + ".worlds")
	var world_item: Dictionary = app.catalog.create_world("Outils", "80")
	app.catalog.set_game_mode(world_item.id, Catalog.GAME_SURVIVAL)
	root.add_child(app)
	current_scene = app
	await process_frame
	app.open_world(world_item.id)
	for i in range(600):
		if app.page == "playing":
			break
		await process_frame
	var world: Node3D = app.active_world
	for index in Inventory.HANDS + Inventory.POCKETS:
		world.inventory.put("bar", index, {})
	world.inventory.select(0)
	check(world.tool_speed("bois") == 1.0 and is_equal_approx(world.max_chop_thickness(), 0.4), "bare hands: normal speed, 40 cm at most")
	var axe: Dictionary = best.duplicate()
	axe.erase("objet")
	axe.usure = 3
	world.inventory.put("bar", 0, {})
	world.inventory.put("bar", 0, {"objet": "hache_pierre", "pile": [axe.duplicate()]})
	check(world.tool_speed("bois") > 3.0 and is_equal_approx(world.max_chop_thickness(), 0.8), "an axe in hand: wood 3 times faster, trunks up to 80 cm (0.0.8.47)")
	check(is_equal_approx(world.big_wood_factor(0.3), 1.0) and is_equal_approx(world.big_wood_factor(0.8), 2.0), "beyond 40 cm the time grows faster (80 cm: twice)")
	axe.usure = 100
	world.inventory.put("bar", 0, {})
	world.inventory.put("bar", 0, {"objet": "hache_pierre", "pile": [axe.duplicate()]})
	check(not world.use_tool("bois", 5.0) and int(world.inventory.item("bar", 0).pile[0].usure) == 90, "5 s of chopping: 10 hits used (100 → 90)")
	check(not world.use_tool("pierre", 5.0) and int(world.inventory.item("bar", 0).pile[0].usure) == 90, "an axe does not wear on stone (it does not help there)")
	axe.usure = 3
	world.inventory.put("bar", 0, {})
	world.inventory.put("bar", 0, {"objet": "hache_pierre", "pile": [axe.duplicate()]})
	var before: int = world.ground.entries.size()
	check(world.use_tool("bois", 2.0), "worn out: the axe breaks")
	var fallen: Array = world.ground.entries.slice(before).map(func(e): return e.item.objet)
	check(world.inventory.item("bar", 0).is_empty() and fallen.has("tete_hache") and fallen.has("branche"), "its head and handle fall on the ground (%s)" % str(fallen))
	world.inventory.put("bar", 0, {"objet": "pioche_pierre", "pile": [{"pierre": 1, "taille": 4, "lien": 1, "tours": 6}]})
	check(world.tool_speed("pierre") > 3.5 and world.tool_speed("terre") > 1.8, "a pickaxe in hand: stone and earth faster")
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for menu in Settings.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.file_path(menu)))
	print("RESULT: %d tools checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
