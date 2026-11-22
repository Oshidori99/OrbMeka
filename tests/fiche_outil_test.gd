extends SceneTree
# 0.0.8.18 (#246, demande de l'utilisateur) : fiche de fabrication d'un outil (et d'une tête taillée) : chaque étape notée
# (bien, moyen, à améliorer) avec son effet, des conseils pour un meilleur outil ; bouton « Fiche de fabrication » sur
# les détails de l'outil (« + » ou D + T).
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
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

func _run() -> void:
	var best := {"objet": "hache_pierre", "pierre": 1, "taille": 5, "essence": 1, "souplesse": 3, "age": 3, "epaisseur": 3.5, "longueur": 0.6, "lien": 1, "tours": 8}
	var report := Inventory.tool_report(best)
	check(report.etapes.size() == 6 and report.etapes.all(func(step): return step[2] == "bien"), "the best axe: six steps, all « bien »")
	check(report.conseils == ["Rien à améliorer : c'est le meilleur outil possible."] and report.resume.contains("300"), "nothing to improve; 300 hits (%s)" % report.resume)
	var worst := {"objet": "pioche_pierre", "pierre": 0, "taille": 3, "essence": 0, "morte": 1, "souplesse": 5, "lien": 3, "tours": 4}
	report = Inventory.tool_report(worst)
	check(report.etapes.all(func(step): return step[2] == "à améliorer") and report.conseils.size() == 6, "a poor pickaxe: every step to improve, six tips")
	check(report.resume.begins_with("Elle casse la pierre") and report.resume.contains("%d coups" % Inventory.tool_durability(worst)), "summary: speed and hits from the real rules")
	var bare := {"objet": "hache_a_ficeler", "pierre": 1, "taille": 4, "souplesse": 2}
	report = Inventory.tool_report(bare)
	check(report.etapes.any(func(step): return step[0] == "Ficelage" and step[2] == "à améliorer") and report.conseils.any(func(tip): return tip.contains("8 tours")), "not tied yet: tie it (8 turns of linen cord)")
	report = Inventory.tool_report({"objet": "tete_hache", "pierre": 1, "taille": 4})
	check(report.etapes.size() == 2 and report.etapes[1][2] == "moyen", "a stone head: stone and size only")
	check(Inventory.has_tool_report(best) and not Inventory.has_tool_report({"objet": "caillou"}), "only tools and heads have a card")
	# Dans l'inventaire.
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/fiche-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(fixture)
	app.catalog = Catalog.new(fixture + ".worlds")
	var made: Dictionary = app.catalog.create_world("Fiche", "78")
	app.catalog.set_game_mode(made.id, Catalog.GAME_SURVIVAL)
	root.add_child(app)
	current_scene = app
	await process_frame
	app.open_world(made.id)
	for i in range(5):
		await process_frame
	var world: Node3D = app.active_world
	world.inventory.select(Inventory.HANDS[0])
	var tool := best.duplicate()
	tool.erase("objet")
	tool.poids = 700.0
	world.inventory.put("bar", Inventory.HANDS[0], {"objet": "hache_pierre", "pile": [tool]})
	world.show_held_details()
	for i in range(3):
		await process_frame
	var ui: CanvasLayer = world.inventory_ui
	var buttons: Array = ui.find_children("FicheButton", "Button", true, false)
	check(world.inventory_open and buttons.size() == 1, "D + T on the axe: its details, with a « Fiche de fabrication » button")
	if not buttons.is_empty():
		buttons[0].pressed.emit()
	await process_frame
	check(is_instance_valid(ui.tool_card) and ui.tool_card.find_child("Steps", true, false).get_child_count() == 4 * 7, "the card: a heading line and six steps")
	check(ui.tool_card.find_child("Title", true, false).text == "Fiche : Hache en pierre", "titled with the tool")
	ui.close_tool_card()
	await process_frame
	check(not is_instance_valid(ui.tool_card), "closed")
	world.close_inventory(false)
	app.return_to_worlds()
	for path in [fixture, fixture + ".worlds"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d tool card checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
