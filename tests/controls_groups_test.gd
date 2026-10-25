extends SceneTree
# 0.0.4.8 : Contrôles rangés en Mouvements, Blocs, Vitesses et Menus (touches réservées, non
# modifiables) ; courir en volant (Attributs → Voler : Avancer, De côté, Reculer en volant vite).
const Settings = preload("res://scripts/user_settings.gd")
const Controls = preload("res://scripts/controls.gd")
const DELTA := 1.0 / 60.0
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

func fly(player: CharacterBody3D, direction: Vector2, steps: int) -> float:
	player.position = Vector3(0.5, 20.0, 8.5)
	player.rotation = Vector3.ZERO
	await physics_frame
	var start := player.position
	for index in range(steps):
		await physics_frame
		player.step_flight(DELTA, direction, 0.0)
	return (player.position - start).length() * 60.0 / steps

func _run() -> void:
	root.size = Vector2i(1280, 720)
	# Parties.
	check(Controls.GROUPS.keys() == ["Mouvements", "Blocs", "Vitesses", "Vitesses — réinitialiser", "Raccourcis"], "groups: Mouvements, Blocs, Vitesses, Vitesses — réinitialiser, Raccourcis (then Menus)")
	var seen := []
	for group in Controls.GROUPS:
		seen.append_array(Controls.GROUPS[group])
	var once := seen.size() == Controls.ACTIONS.size()
	for action in Controls.ACTIONS:
		once = once and seen.count(action) == 1
	check(once, "every action in exactly one group")
	check(Controls.GROUPS.Mouvements.has("fly") and Controls.GROUPS.Mouvements.has("sprint") and Controls.GROUPS.Blocs.has("break_block") and Controls.GROUPS["Vitesses — réinitialiser"].has("speed_reset_all") and Controls.GROUPS.Vitesses.has("speed_up"), "actions in the right group")
	check(Controls.MENU_KEYS == [["Pause", "Échap"]] and Controls.RESERVED_KEYS == [KEY_ESCAPE], "Menus: only Escape stays reserved (0.0.5.10)")
	check(Controls.GROUPS.Raccourcis == ["worlds_menu", "world_info_page", "change_view"] and Controls.GROUPS.Blocs.has("brush_next") and Controls.GROUPS.Blocs.has("size_up"), "F1, F3, F4, brush and gesture size are changeable (no F2 since 0.0.5.11)")
	# Attributs de vol rapide.
	for key in ["fly_run_forward", "fly_run_side", "fly_run_back"]:
		check(key in Settings.ATTRIBUTE_KEYS and Settings.SPECS[key].default == 15.0, "attribute 15 m/s: " + key)
	check(Settings.SPECS.fly_run_forward.default > Settings.SPECS.fly_forward.default, "flying fast is faster than flying")
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	player.apply_settings(Settings.default_values())
	player.flying = true
	var normal: float = await fly(player, Vector2(0, -1), 30)
	player.running = true
	var fast: float = await fly(player, Vector2(0, -1), 30)
	var fast_back: float = await fly(player, Vector2(0, 1), 30)
	var fast_side: float = await fly(player, Vector2(1, 0), 30)
	check(absf(normal - 10.0) < 0.3 and absf(fast - 15.0) < 0.4 and absf(fast_back - 15.0) < 0.4 and absf(fast_side - 15.0) < 0.4, "running while flying: 15 m/s in every direction (%.2f, %.2f, %.2f)" % [fast, fast_back, fast_side])
	player.run_scale = 1.2
	var boosted: float = await fly(player, Vector2(0, -1), 30)
	check(absf(boosted - 18.0) < 0.5, "↑ + R counts while flying fast (%.2f)" % boosted)
	player.run_scale = 1.0
	var values := Settings.default_values()
	values.fly_run_forward = 25.0
	player.apply_settings(values)
	var tuned: float = await fly(player, Vector2(0, -1), 30)
	check(absf(tuned - 25.0) < 0.6, "flying fast follows the attributes (%.2f)" % tuned)
	player.running = false
	var slow: float = await fly(player, Vector2(0, -1), 30)
	check(absf(slow - 10.0) < 0.3, "releasing Courir: normal flight again")
	root.remove_child(world)
	world.queue_free()
	var fixture := "res://.godot/controls-groups-%d.json" % Time.get_ticks_usec()
	var blank := Settings.new(fixture)
	var file := FileAccess.open(blank.file_path("attributes"), FileAccess.WRITE)
	file.store_string('{"fly_forward": 12.0}')
	file.close()
	var legacy := Settings.new(fixture)
	check(legacy.values.fly_forward == 12.0 and legacy.values.fly_run_forward == 15.0 and legacy.load_notice.is_empty(), "old attributs.json: flying fast by default, no warning")
	# Menu Contrôles.
	var settings := Settings.new(fixture + ".app")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	await process_frame
	var titles: Array = ["Mouvements", "Blocs", "Vitesses", "Vitesses — réinitialiser", "Raccourcis", "Menus"]
	var ordered := titles.all(func(title): return app.control_group_labels.has(title))
	# 0.0.4.22 : le titre d'une partie est dans une ligne avec son ↻ (sauf Menus).
	var list: Node = app.control_group_labels.Menus.get_parent()
	var head := func(title: String) -> int:
		var label: Node = app.control_group_labels[title]
		return label.get_index() if label.get_parent() == list else label.get_parent().get_index()
	for index in range(titles.size() - 1):
		ordered = ordered and head.call(titles[index]) < head.call(titles[index + 1])
	check(ordered and app.control_group_labels.Menus.text == "▾ Menus", "six titled parts in order (▾ : repliables, 0.0.4.14 ; Raccourcis 0.0.5.10)")
	var placed := true
	for index in range(Controls.GROUPS.size()):
		var group: String = titles[index]
		for action in Controls.GROUPS[group]:
			var group_body: Node = app.control_action_boxes[action].get_parent()
			placed = placed and group_body.get_parent() == list and group_body.get_index() == head.call(group) + 1
	check(placed, "each action under its part")
	check(app.control_menu_buttons.size() == Controls.MENU_KEYS.size() and app.control_menu_buttons.values().all(func(button): return button.disabled) and app.control_menu_buttons.Pause.text == "Échap", "Menus: reserved key shown, not editable")
	check(app.control_menu_buttons.Pause.get_parent().get_parent().get_index() == app.control_group_labels.Menus.get_index() + 1, "reserved key under Menus")
	# ↻ par partie (0.0.4.22) : seulement les touches de cette partie reviennent par défaut, d'un coup.
	check(Controls.GROUPS.keys().all(func(group): return app.control_group_resets.has(group) and app.control_group_resets[group].get_parent() == app.control_group_labels[group].get_parent()) and not app.control_group_resets.has("Menus"), "a ↻ beside each part title (not Menus)")
	var block_action: String = Controls.GROUPS.Blocs[0]
	var move_action: String = Controls.GROUPS.Mouvements[0]
	app.set_control(block_action, {"key": KEY_F7})
	app.set_control(move_action, {"key": KEY_F8})
	app.control_group_resets.Blocs.pressed.emit()
	check(Controls.same(settings.controls[block_action], Controls.default_for(block_action)) and Controls.label(settings.controls[move_action]) == "F8", "↻ Blocs: only Blocs back to default")
	check(Controls.same(Settings.new(fixture + ".app").controls[block_action], Controls.default_for(block_action)), "group reset saved")
	app.reset_all_controls()
	check(Controls.ACTIONS.keys().all(func(action): return Controls.same(settings.controls[action], Controls.default_for(action))) and app.settings_message.text == "Toutes les touches par défaut.", "Tout réinitialiser: everything back, at once")
	check(Controls.label(Settings.new(fixture + ".app").controls[move_action]) != "F8", "reset all saved")
	check(app.ATTRIBUTE_CATEGORIES.Voler.keys.has("fly_run_forward") and app.setting_fields.has("fly_run_back"), "flying fast in Attributs → Voler")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d controls groups checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
