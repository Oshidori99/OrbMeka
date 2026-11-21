extends SceneTree
# 0.0.7.17 : menu des actions (B + T) : deux lignes de cases (clic gauche en haut, clic droit en bas), molette pour
# choisir, T pour changer de ligne, fermé par un clic, Échap, Entrée ou un moment sans rien ; cases assez larges pour
# leur texte ; ce que fait le clic gauche dans chaque mode (creuser ou jamais).
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
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

func frames(count: int) -> void:
	for index in range(count):
		await process_frame
		await physics_frame

func wheel(menu: Control, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	menu._input(event)

func key(menu: Control, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	menu._input(event)

func _run() -> void:
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	var menu: Control = world.action_menu
	check(menu != null and not menu.is_open(), "the action menu exists, closed")
	check(world.find_child("ExplorationNotice", true, false).text.begins_with("Clic gauche : creuser / casser · clic droit : poser"), "the help line shows both clicks")
	world.open_action_menu()
	await frames(2)
	check(menu.is_open() and menu.row == 0, "B + T opens the menu on the left-click row")
	# Disposition : la ligne du clic gauche au-dessus de celle du clic droit, au-dessus de la barre d'objets ; chaque case
	# assez large pour son texte, sans chevauchement.
	var top: Array = menu.tiles(0)
	var bottom: Array = menu.tiles(1)
	check(top.size() == 3 and bottom.size() == 4, "three left-click modes, three right-click brushes and Manger (0.0.8.3)")
	check((top[0][0] as Rect2).end.y < (bottom[0][0] as Rect2).position.y, "the left-click row is above the right-click row")
	check((bottom[0][0] as Rect2).end.y <= menu.get_viewport_rect().size.y - world.inventory_ui.hud_height() and (top[0][0] as Rect2).position.y > 0.0, "both rows stay above the item bar")
	var fits := true
	for row in [top, bottom]:
		for index in range(row.size()):
			var rect: Rect2 = row[index][0]
			var width: float = menu.get_theme_default_font().get_string_size(row[index][1], HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(12 * menu.text_scale)).x
			fits = fits and rect.size.x >= width and rect.position.x >= 0.0 and rect.end.x <= menu.get_viewport_rect().size.x
			if index > 0:
				fits = fits and rect.position.x > (row[index - 1][0] as Rect2).end.x
	check(fits, "every tile is wide enough for its text, none overlap, all on screen (screen %s, %s)" % [str(menu.size), str(top.map(func(t): return t[0]) + bottom.map(func(t): return t[0]))])
	# Molette : choisit dans la ligne active, aussitôt.
	wheel(menu, true)
	check(player.left_mode == 1 and world.notice == "Clic gauche : Casser / Récupérer des objets", "wheel down: left click breaks and picks up objects")
	wheel(menu, true)
	wheel(menu, true)
	check(player.left_mode == 0, "the wheel loops back to Creuser / Casser")
	wheel(menu, false)
	check(player.left_mode == 2, "wheel up: Récupérer des matériaux")
	# T : l'autre ligne.
	key(menu, KEY_T)
	check(menu.row == 1, "T switches to the right-click row")
	wheel(menu, true)
	check(player.brush == 1 and world.notice == "Clic droit : Aplanir", "wheel down: right click flattens")
	check(world.find_child("ExplorationNotice", true, false).text.begins_with("Clic gauche : récupérer des matériaux · clic droit : aplanir"), "the help line follows the choices")
	key(menu, KEY_T)
	check(menu.row == 0, "T again: back to the left-click row")
	# Fermer : Échap, Entrée, un clic, un moment sans rien.
	key(menu, KEY_ESCAPE)
	check(not menu.is_open(), "Escape closes the menu")
	world.open_action_menu()
	key(menu, KEY_ENTER)
	check(not menu.is_open(), "Enter closes the menu")
	world.open_action_menu()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	menu._input(click)
	check(not menu.is_open() and player.left_mode == 2 and player.brush == 1, "a click closes the menu, choices kept")
	world.open_action_menu()
	menu._process(menu.IDLE_SECONDS + 0.1)
	check(not menu.is_open(), "the menu closes by itself after a moment")
	world.open_action_menu()
	menu._process(1.5)
	wheel(menu, true)
	menu._process(1.5)
	check(menu.is_open(), "each choice restarts the moment")
	menu.close()
	# Clic gauche selon le mode : seul « Creuser / Casser » creuse le terrain.
	player.camera.look_at(player.camera.global_position + Vector3(0.5, -1.0, -0.6))
	await frames(2)
	var hit: Dictionary = player.get_target()
	check(not hit.is_empty() and hit.collider.is_in_group("ground"), "aiming at the ground")
	player.brush_size = 0
	for mode in [2, 1]:
		player.left_mode = mode
		var before: int = world.terrain.changes.size()
		check(not world.break_target(hit) and world.terrain.changes.size() == before, "left click mode %d never digs" % mode)
	player.left_mode = 0
	var before_dig: int = world.terrain.changes.size()
	check(world.break_target(hit) and world.terrain.changes.size() > before_dig, "Creuser / Casser digs")
	root.remove_child(world)
	world.queue_free()
	await process_frame
	print("RESULT: %d action menu checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
