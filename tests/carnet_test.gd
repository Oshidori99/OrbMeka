extends SceneTree
# 0.0.8.16 (#208, demande de l'utilisateur) : Carnet de route (O + C, menu Échap) : commandes en cases avec leurs détails,
# chemin des premiers outils, coches (cases faites, objets fabriqués), « Réinitialiser », message la première fois,
# enregistré par monde ; l'aide de l'inventaire est dans le carnet.
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

func _run() -> void:
	# Données.
	var ids: Array = (Carnet.CASES + Carnet.STEPS).map(func(entry): return entry.id)
	var unique := {}
	for id in ids:
		unique[id] = true
	check(Carnet.CASES.size() == 10 and Carnet.STEPS.size() == 10 and unique.size() == ids.size(), "10 commands, 10 steps, all different")
	check((Carnet.CASES + Carnet.STEPS).all(func(entry): return CarnetUI.picture(entry.image) != null), "every case and step has a picture")
	check(Carnet.STEPS.map(func(step): return step.id).slice(2, 10) == ["tresser", "eclat", "tete", "branche", "fendre", "assembler", "hache", "pioche"], "the path: braid, knap, split, assemble, tie: axe then pickaxe")
	var book := Carnet.new()
	check(book.mark("inventaire") and not book.mark("inventaire") and not book.mark("inconnu") and book.is_done("inventaire"), "a case is ticked once; unknown ids ignored")
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
	check(world.notebook_seen and world.notice.contains("O + C"), "first time in the world: how to open it (%s)" % world.notice)
	check(is_instance_valid(app.notebook_button) and app.notebook_button.text.begins_with("Carnet de route"), "a button in the Échap menu")
	world.open_notebook()
	await process_frame
	var ui: CanvasLayer = world.notebook_ui
	check(world.notebook_open and ui.visible and ui.case_buttons.size() == 10 and ui.step_marks.size() == 10, "opened: the cases and the path")
	ui.choose("inventaire")
	check(ui.detail_title.text.ends_with("Ouvrir l'inventaire") and ui.detail_text.text.contains("deux mains") and ui.detail_keys.text == "O + I", "a case clicked: its details (the inventory help is here now)")
	world.open_inventory()
	check(not world.inventory_open, "the inventory does not open over it")
	world.close_notebook(false)
	check(not world.notebook_open and not ui.visible, "closed")
	world.open_inventory()
	await process_frame
	check(world.notebook.is_done("inventaire") and world.inventory_ui.message.text.contains("Carnet de route"), "inventory opened: case ticked; its short line points to the notebook")
	world.close_inventory(false)
	# Étape du chemin : une ficelle sur soi.
	world.inventory.put("bar", Inventory.HANDS[0], {"objet": "ficelle_lin", "pile": [{}]})
	check(world.notebook.is_done("tresser") and not world.notebook.is_done("hache"), "a cord in hand: « Tresser » ticked")
	world.open_notebook()
	await process_frame
	check(ui.step_marks.tresser.text == "✓" and ui.step_marks.hache.text == "○" and ui.case_buttons.inventaire.text.begins_with("✓"), "ticks shown")
	ui._on_reset()
	check(world.notebook.is_done("tresser"), "Réinitialiser asks first (one click: nothing yet)")
	ui._on_reset()
	check(world.notebook.to_array().is_empty() and ui.step_marks.tresser.text == "○", "second click: everything unticked")
	world.close_notebook(false)
	world.notebook_mark("manger")
	check(world.player_data().carnet == ["manger"] and world.player_data().carnet_vu == true, "saved in joueur.json")
	app.return_to_worlds()
	for path in [fixture, fixture + ".worlds"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d notebook checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
