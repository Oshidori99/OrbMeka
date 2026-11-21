extends SceneTree
# 0.0.8.3 (demandes de l'utilisateur) : mains : objets comptés en nombre (pas en litres) : 2 pommes par main, 3 pour les
# deux mains ; 5 noisettes par main, 10 à deux mains ; poches : 15 noisettes au plus par poche. Manger : noisette 0,5 s,
# pomme 1 s ; en restant appuyé, on mange le suivant ; « Manger » au bout de la ligne du clic droit (B + T) : il mange
# seulement, ne pose jamais. Barre en jeu : plus de nom sous les cases ; le nom s'affiche au-dessus quand on prend en main.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Health = preload("res://scripts/health.gd")
const ActionMenu = preload("res://scripts/action_menu.gd")
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

static func apples(amount: int, size: int = 3) -> Dictionary:
	var value := {"objet": "pomme", "pile": []}
	for i in range(amount):
		value.pile.append({"taille": size, "couleur": 1})
	return value

static func nuts(amount: int) -> Dictionary:
	var value := {"objet": "noisette", "pile": []}
	for i in range(amount):
		value.pile.append({})
	return value

static func survival() -> Inventory:
	var made := Inventory.new()
	made.mode = Inventory.SURVIVAL
	made.set_mode(Inventory.SURVIVAL)
	return made

func _run() -> void:
	# Mains : nombre, pas litres (grosses pommes : 1,15 L chacune).
	var inv := survival()
	inv.put("bar", 0, apples(2))
	check(Inventory.count(inv.item("bar", 0)) == 2 and not Inventory.needs_both_hands(inv.item("bar", 0)), "2 big apples in one hand (volume no longer blocks)")
	inv.put("bar", 1, apples(2))
	check(Inventory.count(inv.item("bar", 1)) == 1, "the other hand: only 1 more apple (3 for both hands)")
	inv = survival()
	inv.put("bar", 0, apples(4))
	check(Inventory.count(inv.item("bar", 0)) == 3 and inv.two_handed() == 0, "one pile with both hands: 3 apples at most")
	inv = survival()
	inv.put("bar", 0, nuts(8))
	check(Inventory.count(inv.item("bar", 0)) == 8 and inv.two_handed() == 0, "8 hazelnuts: held with both hands (5 per hand)")
	inv = survival()
	inv.put("bar", 0, nuts(5))
	inv.put("bar", 1, nuts(8))
	check(Inventory.count(inv.item("bar", 0)) == 5 and Inventory.count(inv.item("bar", 1)) == 5, "5 hazelnuts in each hand")
	inv.put("bar", 2, nuts(20))
	check(Inventory.count(inv.item("bar", 2)) == 15 and inv.last_refusal == "nombre", "a pocket: 15 hazelnuts at most")
	check(Inventory.count_rule({"objet": "noisette"}) == "5 noisettes au plus dans une main, 10 à deux mains, 15 par poche.", "refusal message: " + Inventory.count_rule({"objet": "noisette"}))
	check(Inventory.HAND_COUNTS.caillou == 4 and Inventory.both_hands_count("caillou") == 8, "pebbles unchanged: 4 per hand, 8 with both")
	# Manger : durées.
	check(Health.eat_seconds({"objet": "noisette"}) == 0.5 and Health.eat_seconds({"objet": "pomme"}) == 1.0, "hazelnut 0.5 s, apple 1 s")
	check(ActionMenu.ROWS[1][-1] == "Manger", "B + T: Manger at the end of the right-click row")
	# En partie.
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/hands-eat-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = Catalog.new(fixture + ".worlds")
	var made: Dictionary = app.catalog.create_world("Manger", "77")
	app.catalog.set_game_mode(made.id, Catalog.GAME_SURVIVAL)
	root.add_child(app)
	current_scene = app
	await process_frame
	app.open_world(made.id)
	for i in range(5):
		await process_frame
	var world: Node3D = app.active_world
	# Barre : plus de nom sous les cases, seulement le poids.
	var slot: Control = world.inventory_ui.hud_slots[2]
	check(not slot.show_title and slot.title == "" and not slot.note.is_empty(), "hot bar: no name under the slot, only the weight")
	# Le nom en main, au-dessus.
	world.inventory.put("bar", 1, nuts(5))
	world.inventory.select(1)
	await process_frame
	check(world.held_label.visible and world.held_label.text == "Noisette", "name of the item taken in hand shown above (%s)" % world.held_label.text)
	for i in range(int(world.HELD_NAME_SECONDS * 60) + 30):
		world._update_held_name(1.0 / 60.0)
	check(not world.held_label.visible, "then it fades away")
	# Manger en continu, noisette rapide.
	world.health.value = 50
	check(world.eat_press(), "right click held: eating starts")
	for i in range(16):
		world.step_eat(0.1, true)
	check(world.health.value == 59 and Inventory.count(world.inventory.held()) == 2, "held 1.6 s: 3 hazelnuts eaten one after the other (%d)" % world.health.value)
	world.eat_release({})
	check(Inventory.count(world.inventory.held()) == 2, "release after eating: nothing put down")
	# Clic droit « Manger » : jamais de pose, mange même d'un clic maintenu.
	world.player.brush = world.EAT_BRUSH
	check(world.hold_use() == "manger" and world.eat_press(), "Manger brush: right click eats")
	world.step_eat(0.1, true)
	world.eat_release({})
	check(Inventory.count(world.inventory.held()) == 2 and not world.place_target({}, -1), "Manger brush: a short click puts nothing down")
	world.inventory.put("bar", 1, {})
	check(world.eat_press() and world.eat_time < 0.0, "Manger brush with nothing to eat: nothing happens")
	world.player.brush = 0
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for menu in Settings.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.file_path(menu)))
	print("RESULT: %d hands and eating checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
