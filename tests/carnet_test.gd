extends SceneTree
# 0.0.8.16 (#208) puis 0.0.8.19 (demande de l'utilisateur : en arbre) : Carnet de route (O + C, menu Échap) : la case
# « Départ » au centre, à gauche les commandes, en haut ce qu'on récupère, à droite ce qu'on fabrique, chaque branche du
# plus facile au plus difficile, de plus en plus loin du centre ; cases reliées par des lignes, un clic : les détails ;
# coches (actions faites, objets sur soi), cases pas encore possibles plus pâles, « Réinitialiser », message la première
# fois, enregistré par monde ; vue déplaçable et molette.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Controls = preload("res://scripts/controls.gd")
const Carnet = preload("res://scripts/carnet.gd")
const CarnetUI = preload("res://scripts/carnet_ui.gd")
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

func branch_ids(branch: String) -> Array:
	return Carnet.NODES.filter(func(entry): return entry.branche == branch).map(func(entry): return entry.id)

func _run() -> void:
	# Données : un plan en arbre.
	var ids: Array = Carnet.NODES.map(func(entry): return entry.id)
	var unique := {}
	for id in ids:
		unique[id] = true
	check(unique.size() == ids.size() and Carnet.place_of(Carnet.node("depart")) == Vector2.ZERO, "every case different; Départ in the centre")
	check(Carnet.NODES.all(func(entry): return CarnetUI.picture(entry.image) != null and entry.nom.split(" ").size() <= 3), "every case: a picture and two or three words")
	check(Carnet.NODES.all(func(entry): return entry.parent == "" or not Carnet.node(entry.parent).is_empty()), "every case linked to the one before")
	check(branch_ids("gauche").slice(0, 4) == ["deplacer", "inventaire", "actions", "fabrication"], "left: the commands, easiest first")
	check(branch_ids("haut").slice(0, 3) == ["cailloux", "fibres", "branche"], "up: what we gather, easiest first")
	# 0.0.8.21 (#207) : après l'éclat, une branche vers le bas : cordelette puis sac en filet.
	check(branch_ids("droite") == ["tresser", "eclat", "cordelette", "sac", "tete", "fendre", "navette", "assembler", "hache", "pioche"], "right: what we make, up to the axe and the pickaxe (and the net bag)")
	check(Carnet.place_of(Carnet.node("jeter")).x < Carnet.place_of(Carnet.node("deplacer")).x and Carnet.place_of(Carnet.node("planter")).y < Carnet.place_of(Carnet.node("cailloux")).y and Carnet.place_of(Carnet.node("assembler")).x > Carnet.place_of(Carnet.node("tresser")).x, "further = more advanced: left goes left, up goes up, right goes right")
	check(Carnet.place_of(Carnet.node("hache")).y < 0.0 and Carnet.place_of(Carnet.node("pioche")).y > 0.0, "after Assembler, a fork: the axe a bit up, the pickaxe a bit down")
	# 0.0.8.36 (demande de l'utilisateur) : les suites pile en dessous, même colonne ; la navette sous Fendre.
	check(Carnet.place_of(Carnet.node("cordelette")) == Carnet.place_of(Carnet.node("eclat")) + Vector2(0, 1) and Carnet.place_of(Carnet.node("sac")) == Carnet.place_of(Carnet.node("eclat")) + Vector2(0, 2), "Éclat → Cordelette → Sac en filet: straight below, same column")
	check(Carnet.place_of(Carnet.node("navette")) == Carnet.place_of(Carnet.node("fendre")) + Vector2(0, 1) and Carnet.node("navette").objets == ["navette"], "Navette: its own case, right under Fendre")
	check(branch_ids("bas").is_empty(), "nothing below for now")
	var book := Carnet.new()
	check(book.is_done("depart") and not book.is_open("inventaire") and book.is_open("deplacer"), "Départ always done; a case is possible once the one before is done")
	check(book.mark("deplacer") and not book.mark("deplacer") and not book.mark("inconnu") and book.is_open("inventaire"), "a case is ticked once; unknown ids ignored")
	book.from_array(["tresser", "faux"])
	check(book.to_array() == ["tresser"], "read back from joueur.json (unknown ids dropped)")
	book.reset()
	check(book.to_array().is_empty(), "Réinitialiser: everything unticked")
	check(Controls.ACTIONS.notebook.default.key == KEY_O and Controls.ACTIONS.notebook.default.second.key == KEY_C, "O + C opens it (modifiable)")
	# En partie (Survie).
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/carnet-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(fixture)
	app.catalog = Catalog.new(fixture + ".worlds")
	var made: Dictionary = app.catalog.create_world("Carnet", "78")
	app.catalog.set_game_mode(made.id, Catalog.GAME_SURVIVAL)
	root.add_child(app)
	current_scene = app
	await process_frame
	app.open_world(made.id)
	for i in range(5):
		await process_frame
	var world: Node3D = app.active_world
	# 0.0.8.35 : un rappel en bas, jusqu'à la première ouverture (avant : un message de 9 s).
	check(world.notebook_seen and world.notebook_reminder.visible and world.notebook_reminder.text.contains("O + C"), "a new world: how to open it, at the bottom")
	check(is_instance_valid(app.notebook_button) and app.notebook_button.text.begins_with("Carnet de route"), "a button in the Échap menu")
	check(world.held_text() == "Main vide", "empty hand: « Main vide »")
	# (Une poche vide : la première tient l'orbe de retour du début.)
	world.inventory.select(Inventory.POCKETS.filter(func(index): return world.inventory.item("bar", index).is_empty())[0])
	check(world.held_text() == "Poche vide", "an empty pocket chosen: « Poche vide » (0.0.8.19)")
	world.inventory.select(Inventory.HANDS[0])
	world.open_notebook()
	for i in range(3):
		await process_frame
	var ui: CanvasLayer = world.notebook_ui
	check(world.notebook_open and ui.visible and ui.tiles.size() == Carnet.NODES.size(), "opened: every case on the plan")
	var left: Vector2 = ui.tiles.jeter.position
	var right: Vector2 = ui.tiles.pioche.position
	var up: Vector2 = ui.tiles.planter.position
	var middle: Vector2 = ui.tiles.depart.position
	check(left.x < middle.x and right.x > middle.x and up.y < middle.y, "on screen too: left, right and up from the centre")
	check(ui.tiles.inventaire.modulate.a < 0.9 and ui.tiles.deplacer.modulate.a == 1.0, "not yet possible: paler")
	ui.choose("inventaire")
	check(ui.detail_title.text == "Inventaire" and ui.detail_text.text.contains("deux mains") and ui.detail_keys.text == "O + I" and ui.detail_state.text.contains("d'abord"), "a case clicked: its details (and what comes first)")
	var before: float = ui.zoom
	ui.zoom_at(ui.view.size * 0.5, 1.12)
	var moved: Vector2 = ui.plan.position
	ui._on_view_input(_press(Vector2(100, 100), true))
	ui._on_view_input(_motion(Vector2(160, 130)))
	ui._on_view_input(_press(Vector2(160, 130), false))
	check(ui.zoom > before and ui.plan.position.is_equal_approx(moved + Vector2(60, 30)), "the wheel brings closer; dragging moves the view")
	world.open_inventory()
	check(not world.inventory_open, "the inventory does not open over it")
	world.close_notebook(false)
	check(not world.notebook_open and not ui.visible, "closed")
	world.open_inventory()
	await process_frame
	check(world.notebook.is_done("inventaire") and world.inventory_ui.message.text.contains("Carnet de route"), "inventory opened: case ticked; its short line points to the notebook")
	world.close_inventory(false)
	world.inventory.put("bar", Inventory.HANDS[0], {"objet": "ficelle_lin", "pile": [{}]})
	check(world.notebook.is_done("tresser") and not world.notebook.is_done("hache"), "a cord in hand: « Ficelle » ticked")
	world.open_notebook()
	await process_frame
	check(ui.marks.tresser.visible and not ui.marks.hache.visible and ui.marks.inventaire.visible, "ticks shown on the cases")
	ui._on_reset()
	check(world.notebook.is_done("tresser"), "Réinitialiser asks first (one click: nothing yet)")
	ui._on_reset()
	check(world.notebook.to_array().is_empty() and not ui.marks.tresser.visible, "second click: everything unticked")
	world.close_notebook(false)
	world.notebook_mark("manger")
	check(world.player_data().carnet == ["manger"] and world.player_data().carnet_vu == true, "saved in joueur.json")
	app.return_to_worlds()
	for path in [fixture, fixture + ".worlds"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# 0.0.8.36 : « Revenir au centre ».
	var book_ui = load("res://scripts/carnet_ui.gd").new()
	book_ui.setup(Carnet.new(), 1.0)
	root.add_child(book_ui)
	book_ui.open()
	await process_frame
	await process_frame
	book_ui.plan.position += Vector2(900, -700)
	book_ui.center_on_start()
	var start: Vector2 = book_ui.plan.position + book_ui.center_of("depart") * book_ui.zoom
	check(is_instance_valid(book_ui.center_button) and book_ui.center_button.text == "Revenir au centre" and start.distance_to(book_ui.view.size * 0.5) < 1.0, "« Revenir au centre » brings Départ back to the middle")
	book_ui.queue_free()
	print("RESULT: %d notebook checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _press(at: Vector2, down: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = at
	return event

func _motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	return event
