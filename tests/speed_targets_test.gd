extends SceneTree
# 0.0.4.6 (#105) : ↑ ↓ + W (marche), + R (course), + clic gauche (casse), + clic droit (pose) ;
# ⌫ + la même touche : cette valeur par défaut ; ⌫ deux fois : tout. ↑ ↓ seules : tout le déplacement.
# Monde par défaut : 75 à 150 %, casse et pose fixes ; mode développeur : limites des Attributs.
# 0.0.4.7 : tout le déplacement avec ↑ / ↓ + A ; ⌫ + A le remet par défaut ; A ou W tenus avec ↑, ↓ ou ⌫
# ne font pas bouger.
const Settings = preload("res://scripts/user_settings.gd")
const Controls = preload("res://scripts/controls.gd")
const KeyCombos = preload("res://scripts/key_combos.gd")
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

func hold(player: CharacterBody3D, count: int, changes: Dictionary, resets: Array = []) -> void:
	for index in range(count):
		player.update_speed(DELTA, true, false, false, false, changes, resets)

func walk(player: CharacterBody3D, steps: int) -> float:
	player.position = Vector3(0.5, 0.02, 8.5)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	for index in range(5):
		await physics_frame
		player.step_movement(DELTA, Vector2.ZERO, false)
	var start := player.position
	for index in range(steps):
		await physics_frame
		player.step_movement(DELTA, Vector2(0, -1), false)
	return Vector2(player.position.x - start.x, player.position.z - start.z).length() * 60.0 / steps

func key(code: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event

func _run() -> void:
	root.size = Vector2i(1280, 720)
	# Contrôles.
	var expected := {
		"walk_up": "↑ + W", "walk_down": "↓ + W", "run_up": "↑ + R", "run_down": "↓ + R",
		"break_up": "↑ + Clic gauche", "break_down": "↓ + Clic gauche", "place_up": "↑ + Clic droit", "place_down": "↓ + Clic droit",
		"walk_reset": "⌫ + W", "run_reset": "⌫ + R", "break_reset": "⌫ + Clic gauche", "place_reset": "⌫ + Clic droit", "speed_reset_all": "⌫ → ⌫",
		"speed_up": "↑ + A", "speed_down": "↓ + A", "move_reset": "⌫ + A",
	}
	for action in expected:
		check(Controls.ACTIONS.has(action) and Controls.label(Controls.default_for(action)) == expected[action], "%s: %s" % [action, expected[action]])
	check(Controls.ACTIONS.walk_up.label == "Marche plus vite" and Controls.ACTIONS.break_reset.label == "Casse par défaut" and Controls.ACTIONS.speed_reset_all.label == "Tout par défaut", "labels")
	var modifiers: Array = Controls.click_modifiers(Controls.defaults())
	check(modifiers.has(KEY_UP) and modifiers.has(KEY_DOWN) and modifiers.has(KEY_BACKSPACE) and modifiers.size() == 3, "↑, ↓ and ⌫ turn a click into a setting")
	var blocks: Dictionary = Controls.blocked_moves(Controls.defaults())
	check(blocks.keys().size() == 2 and blocks.move_left.size() == 3 and blocks.move_left.has(KEY_UP) and blocks.move_left.has(KEY_BACKSPACE) and blocks.move_forward.has(KEY_DOWN), "A (left) and W (forward) blocked while ↑, ↓ or ⌫ is held")
	var combos := KeyCombos.new()
	combos.set_bindings(Controls.defaults())
	combos.feed(key(KEY_UP, true), 0)
	check(combos.feed(key(KEY_W, true), 50) == [["walk_up", true]], "↑ then W: Marche plus vite")
	combos.release_all()
	combos.feed(key(KEY_BACKSPACE, true), 0)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	check(combos.feed(click, 50) == [["break_reset", true]], "⌫ then left click: Casse par défaut")
	# Monde par défaut.
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	player.apply_settings(Settings.default_values())
	hold(player, 60, {"walk": 1.0})
	check(absf(player.walk_scale - 1.4) < 0.01 and player.speed_scale == 1.0 and player.run_scale == 1.0, "↑ + W: only the walk, +40 %%/s (%.2f)" % player.walk_scale)
	hold(player, 300, {"walk": 1.0})
	check(player.walk_scale == 1.5, "default world: at most 150 %")
	var walked: float = await walk(player, 30)
	check(absf(walked - 8.25) < 0.3, "walking at 150 %%: 8,25 m/s (%.2f)" % walked)
	player.running = true
	var ran: float = await walk(player, 20)
	check(absf(ran - 8.5) < 0.3, "running unchanged by the walk (%.2f)" % ran)
	hold(player, 60, {"run": 1.0})
	var ran_fast: float = await walk(player, 20)
	check(absf(player.run_scale - 1.4) < 0.01 and absf(ran_fast - 8.5 * 1.4) < 0.4, "↑ + R: only the run (%.2f)" % ran_fast)
	player.running = false
	hold(player, 600, {"run": -1.0})
	check(player.run_scale == 0.75, "default world: at least 75 %")
	hold(player, 60, {"break": 1.0, "place": -1.0})
	check(player.break_scale == 1.0 and player.place_scale == 1.0 and is_equal_approx(player.actions.break_interval, 0.3), "default world: breaking and placing unchanged")
	hold(player, 1, {}, ["walk"])
	check(player.walk_scale == 1.0 and player.run_scale == 0.75, "⌫ + W: walk back to 100 %, run kept")
	player.update_speed(DELTA * 300, true, true, false)
	check(player.speed_scale == 1.5 and player.walk_scale == 1.0, "↑ alone: all movement, also limited to 150 %")
	player.update_speed(DELTA, true, true, false, false, {"walk": -1.0})
	check(player.speed_scale == 1.5 and player.walk_scale < 1.0, "↑ with W held: the arrow alone does not count")
	# Mode développeur : limites des Attributs, casse et pose réglables.
	world.developer_mode = true
	player.apply_settings(Settings.default_values())
	hold(player, 600, {"walk": 1.0, "break": 1.0})
	hold(player, 600, {"place": -1.0})
	check(player.walk_scale == 2.0 and player.break_scale == 2.0 and player.place_scale == 0.5, "developer world: limits of the attributes (50 to 200 %)")
	check(is_equal_approx(player.actions.break_interval, 0.15) and is_equal_approx(player.actions.place_interval, 0.6), "breaking twice as fast, placing half as fast")
	hold(player, 1, {}, ["break"])
	check(player.break_scale == 1.0 and is_equal_approx(player.actions.break_interval, 0.3) and player.place_scale == 0.5, "⌫ + left click: breaking back to normal only")
	player.update_speed(DELTA, true, false, false, true)
	check(player.speed_scale == 1.0 and player.walk_scale == 1.0 and player.run_scale == 1.0 and player.break_scale == 1.0 and player.place_scale == 1.0 and is_equal_approx(player.actions.place_interval, 0.3), "⌫ twice: everything back to normal")
	# Retour en monde par défaut : valeurs ramenées dans 75 à 150 %.
	hold(player, 600, {"walk": 1.0})
	world.developer_mode = false
	player.apply_settings(Settings.default_values())
	check(player.walk_scale == 1.5, "limits applied again in a default world")
	# Un clic avec ↑ ou ⌫ ne casse ni ne pose.
	Input.parse_input_event(key(KEY_UP, true))
	Input.flush_buffered_events()
	check(player.click_modified(), "↑ held: a click is a setting")
	Input.parse_input_event(key(KEY_UP, false))
	Input.flush_buffered_events()
	check(not player.click_modified(), "nothing held: a click breaks or places")
	# A tenu avec ↑ : réglage de vitesse, pas un pas à gauche.
	Controls.apply(Controls.defaults())
	Input.parse_input_event(key(KEY_A, true))
	Input.flush_buffered_events()
	check(player.move_strength("move_left") == 1.0, "A alone: goes left")
	Input.parse_input_event(key(KEY_UP, true))
	Input.flush_buffered_events()
	check(player.move_strength("move_left") == 0.0 and player.move_strength("move_right") == 0.0, "↑ + A: does not go left")
	Input.parse_input_event(key(KEY_UP, false))
	Input.parse_input_event(key(KEY_A, false))
	Input.flush_buffered_events()
	# ⌫ + A : tout le déplacement par défaut, le reste gardé.
	world.developer_mode = true
	player.apply_settings(Settings.default_values())
	player.update_speed(DELTA * 60, true, true, false)
	player.walk_scale = 1.3
	hold(player, 1, {}, ["speed"])
	check(player.speed_scale == 1.0 and player.walk_scale == 1.3, "⌫ + A: all-movement speed back to 100 %, walk kept")
	world.developer_mode = false
	root.remove_child(world)
	world.queue_free()
	# Ancien controles.json (0.0.4.5) : R + ↓ (speed_reset) ignoré.
	var fixture := "res://.godot/speed-targets-%d.json" % Time.get_ticks_usec()
	var blank := Settings.new(fixture)
	var file := FileAccess.open(blank.controls_path(), FileAccess.WRITE)
	file.store_string('{"speed_reset": {"key": %d, "second": {"key": %d}}, "speed_up": {"key": %d}}' % [KEY_R, KEY_DOWN, KEY_UP])
	file.close()
	var legacy := Settings.new(fixture)
	check(legacy.controls.speed_up == Controls.default_for("speed_up"), "old controles.json: ↑ alone (former default) becomes ↑ + A")
	check(not legacy.controls.has("speed_reset") and legacy.controls.speed_reset_all == Controls.default_for("speed_reset_all") and legacy.controls.run_down == Controls.default_for("run_down") and legacy.load_notice.is_empty(), "old controles.json: R + ↓ ignored, new keys by default")
	# Menus.
	var settings := Settings.new(fixture + ".app")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	await process_frame
	check(app.control_buttons.walk_up.text == "↑" and app.control_slot_texts("walk_up")[1] == "W" and app.control_slot_texts("break_up")[1] == "Clic gauche" and app.control_buttons.speed_reset_all.text == "⌫", "new actions in Contrôles")
	var help: String = load("res://scripts/world.gd").get_help_text(2)
	check(help.contains("avec W : la marche seule") and help.contains("⌫ deux fois") and help.contains("75 à 150 % dans") and help.contains("Portée : 5 blocs"), "Comment jouer explains the combinations")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d speed target checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
