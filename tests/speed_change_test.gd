extends SceneTree
# 0.0.4.7 : ↑ / ↓ + A (Tout plus vite / moins vite) à la place de la flèche seule.
# 0.0.4.3 : Plus vite (↑) et Moins vite (↓), maintenus : marche et course changent ensemble,
# peu à peu, entre une vitesse minimale et une maximale (Attributs → Changer de vitesse).
# ↑ ↓ ne font plus avancer ni reculer ; les touches R + T, R + F, R + G de 0.0.4.2 sont retirées.
# 0.0.4.4 : la marche baissée suit aussi ↑ ↓. 0.0.4.6 : R + ↓ remplacé par ⌫ deux fois (tout par défaut) ;
# ce test se joue dans un monde en mode développeur (limites des Attributs).
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

func hold(player: CharacterBody3D, count: int, up: bool, down: bool, active: bool = true) -> void:
	for index in range(count):
		player.update_speed(DELTA, active, up, down)

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

func has_key(action: String, code: int) -> bool:
	return InputMap.action_get_events(action).any(func(event): return event is InputEventKey and event.physical_keycode == code)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	# Contrôles : ↑ ↓ pour la vitesse, plus pour marcher ; anciennes actions retirées.
	var names: Array = Controls.ACTIONS.keys()
	check(names.slice(names.find("sprint") + 1, names.find("sprint") + 3) == ["speed_up", "speed_down"], "Tout plus vite, Tout moins vite just after Courir")
	check(not names.has("speed_reset") and Controls.default_for("speed_reset_all") == {"key": KEY_BACKSPACE, "second": {"key": KEY_BACKSPACE}} and Controls.label(Controls.default_for("speed_reset_all")) == "⌫ deux fois", "Tout par défaut: ⌫ deux fois (R + ↓ removed)")
	check(Controls.ACTIONS.speed_up.label == "Tout plus vite" and Controls.ACTIONS.speed_down.label == "Tout moins vite", "labels")
	check(Controls.default_for("speed_up") == {"key": KEY_UP, "second": {"key": KEY_A}} and Controls.default_for("speed_down") == {"key": KEY_DOWN, "second": {"key": KEY_A}}, "↑ + A and ↓ + A by default (0.0.4.7)")
	check(not names.has("run_faster") and not names.has("run_slower") and not names.has("run_normal"), "R + T, R + F, R + G removed")
	check(Controls.ACTIONS.move_forward.fixed.is_empty() and Controls.ACTIONS.move_back.fixed.is_empty() and Controls.ACTIONS.move_left.fixed == [KEY_LEFT] and Controls.ACTIONS.move_right.fixed == [KEY_RIGHT], "↑ ↓ no longer walk, ← → still do")
	Controls.apply(Controls.defaults())
	var combos: RefCounted = load("res://scripts/key_combos.gd").new()
	combos.set_bindings(Controls.defaults())
	var erase := InputEventKey.new()
	erase.physical_keycode = KEY_BACKSPACE
	erase.pressed = true
	combos.feed(erase, 0)
	erase.pressed = false
	combos.feed(erase, 60)
	erase.pressed = true
	check(combos.feed(erase, 150) == [["speed_reset_all", true]], "⌫ twice triggers Tout par défaut")
	check(not has_key("speed_up", KEY_UP) and not has_key("speed_down", KEY_DOWN) and not has_key("move_forward", KEY_UP) and not has_key("move_back", KEY_DOWN), "game input: arrows alone do nothing (0.0.4.7)")
	# Attributs.
	for key in ["speed_max", "speed_min", "speed_up_rate", "speed_down_rate"]:
		check(key in Settings.ATTRIBUTE_KEYS, "attribute: " + key)
	for key in ["run_max", "run_accel", "run_decel"]:
		check(not Settings.SPECS.has(key), "0.0.4.2 attribute removed: " + key)
	check(Settings.SPECS.speed_max.default == 200.0 and Settings.SPECS.speed_min.default == 50.0 and Settings.SPECS.speed_up_rate.default == 40.0 and Settings.SPECS.speed_down_rate.default == 40.0, "defaults 200 %, 50 %, 40 %/s")
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.developer_mode = true
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	player.apply_settings(Settings.default_values())
	check(player.speed_scale == 1.0, "normal speed at start")
	# Accélération progressive, maximum.
	hold(player, 30, true, false)
	check(absf(player.speed_scale - 1.2) < 0.01, "half a second of ↑: 120 %% (%.2f)" % player.speed_scale)
	hold(player, 30, true, false)
	check(absf(player.speed_scale - 1.4) < 0.01, "one second of ↑: 140 %")
	hold(player, 300, true, false)
	check(player.speed_scale == 2.0, "capped at the maximum, 200 %")
	var walked: float = await walk(player, 30)
	check(absf(walked - 11.0) < 0.4, "walking at 200 %%: 11 m/s (%.2f)" % walked)
	player.running = true
	var ran: float = await walk(player, 20)
	check(absf(ran - 17.0) < 0.6 and ran > walked, "running at 200 %%: 17 m/s, still faster than walking (%.2f)" % ran)
	player.running = false
	# La vitesse reste : touche relâchée, saut, pause.
	hold(player, 60, false, false)
	player.release_controls()
	hold(player, 60, true, false, false)
	check(player.speed_scale == 2.0, "speed kept after release and pause; nothing while paused")
	# Ralentir jusqu'au minimum.
	hold(player, 60, false, true)
	check(absf(player.speed_scale - 1.6) < 0.01, "one second of ↓: 160 %")
	hold(player, 600, false, true)
	check(player.speed_scale == 0.5, "never below the minimum, 50 %")
	var slow: float = await walk(player, 30)
	check(absf(slow - 2.75) < 0.2, "walking at 50 %%: 2,75 m/s (%.2f)" % slow)
	player.crouching = true
	var crouched: float = await walk(player, 30)
	check(absf(crouched - 0.75) < 0.1, "crouching follows too: 0,75 m/s at 50 %% (%.2f)" % crouched)
	player.crouching = false
	hold(player, 60, true, true)
	check(player.speed_scale == 0.5, "↑ and ↓ together cancel out")
	# ⌫ deux fois : tout par défaut, même avec ↓ tenue ; rien en pause.
	player.update_speed(DELTA, false, false, true, true)
	check(player.speed_scale == 0.5, "⌫ ⌫ does nothing while paused")
	player.update_speed(DELTA, true, false, true, true)
	check(player.speed_scale == 1.0, "⌫ ⌫ goes back to 100 %, even with ↓ held")
	hold(player, 60, true, false)
	player.update_speed(DELTA, true, true, false, true)
	check(player.speed_scale == 1.0, "⌫ ⌫ also cancels a faster speed")
	player.crouching = true
	var crouch_normal: float = await walk(player, 30)
	check(absf(crouch_normal - 1.5) < 0.15, "crouching back to 1,5 m/s (%.2f)" % crouch_normal)
	player.crouching = false
	# Attributs appliqués.
	var values := Settings.default_values()
	values.speed_max = 150.0
	values.speed_up_rate = 300.0
	player.apply_settings(values)
	hold(player, 30, true, false)
	check(player.speed_scale == 1.5, "maximum and rapidity follow the attributes")
	values.speed_min = 100.0
	values.speed_down_rate = 300.0
	player.apply_settings(values)
	hold(player, 30, false, true)
	check(player.speed_scale == 1.0, "minimum 100 %: never slower than normal")
	root.remove_child(world)
	world.queue_free()
	# Anciens fichiers (0.0.4.2) : attributs.json et controles.json avec les touches retirées.
	var fixture := "res://.godot/speed-change-%d.json" % Time.get_ticks_usec()
	var blank := Settings.new(fixture)
	var file := FileAccess.open(blank.file_path("attributes"), FileAccess.WRITE)
	file.store_string('{"run_forward": 9.0, "run_max": 14.0, "run_accel": 3.0, "run_decel": 6.0}')
	file.close()
	file = FileAccess.open(blank.controls_path(), FileAccess.WRITE)
	file.store_string('{"sprint": {"key": %d}, "run_faster": {"key": %d, "second": {"key": %d}}, "move_forward": {"key": %d}, "run_mode": "toggle"}' % [KEY_E, KEY_R, KEY_T, KEY_W])
	file.close()
	var legacy := Settings.new(fixture)
	check(legacy.values.run_forward == 9.0 and legacy.values.speed_max == 200.0 and not legacy.values.has("run_max") and legacy.load_notice.is_empty(), "old attributs.json: new attributes by default, old ones ignored, no warning")
	check(legacy.controls.sprint == {"key": KEY_E} and legacy.controls.speed_up == Controls.default_for("speed_up") and not legacy.controls.has("run_faster") and legacy.control_options.run_mode == "toggle" and legacy.load_notice.is_empty(), "old controles.json: ↑ ↓ by default, R + T ignored, no warning")
	# Menus : Contrôles, Attributs, Comment jouer.
	var settings := Settings.new(fixture + ".app")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	await process_frame
	check(app.control_buttons.has("speed_up") and app.control_buttons.speed_up.text == "↑" and app.control_second_buttons.speed_up.text == "A", "Tout plus vite in Contrôles (↑ + A)")
	var categories: Array = app.ATTRIBUTE_CATEGORIES.keys()
	check(categories.find("Changer de vitesse") == categories.find("Voler") + 1 and app.setting_fields.has("speed_max") and app.setting_sliders.has("speed_down_rate"), "Changer de vitesse under Voler, with fields and sliders")
	var help: String = load("res://scripts/world.gd").get_help_text(2)
	check(help.contains("↑ + A maintenus") and help.contains("⌫ deux fois") and not help.contains("R + T") and not help.contains("flèches : marcher"), "Comment jouer explains ↑ ↓")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d speed change checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
