extends SceneTree
# 0.0.4.2 : courir plus vite. Accélérer (R + T) monte peu à peu jusqu'au maximum, Ralentir (R + F)
# redescend sans passer sous la course normale, Vitesse normale (R + G) y revient d'un coup.
# Course accélérée gardée après un saut ; arrêt réel ou pause : vitesse normale.
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

# Images de jeu : R tenue ou non, appui sur R, touches Accélérer / Ralentir / Vitesse normale.
func frames(player: CharacterBody3D, count: int, held: bool, faster: bool = false, slower: bool = false, normal: bool = false, moving: bool = true, jumped: bool = false, pressed: bool = false) -> void:
	for index in range(count):
		player.update_run(true, held, pressed and index == 0, moving, jumped)
		player.update_boost(DELTA, true, faster, slower, normal, moving)

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

func press(combos: KeyCombos, code: int, pressed: bool, now: int) -> Array:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return combos.feed(event, now)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	# Contrôles : trois actions après Courir, deux touches par défaut.
	var names: Array = Controls.ACTIONS.keys()
	check(names.slice(names.find("sprint") + 1, names.find("sprint") + 4) == ["run_faster", "run_slower", "run_normal"], "three actions just after Courir")
	check(Controls.ACTIONS.run_faster.label == "Accélérer" and Controls.ACTIONS.run_slower.label == "Ralentir" and Controls.ACTIONS.run_normal.label == "Vitesse normale", "labels")
	check(Controls.default_for("run_faster") == {"key": KEY_R, "second": {"key": KEY_T}} and Controls.default_for("run_slower") == {"key": KEY_R, "second": {"key": KEY_F}} and Controls.default_for("run_normal") == {"key": KEY_R, "second": {"key": KEY_G}}, "defaults R + T, R + F, R + G")
	check(Controls.label(Controls.default_for("run_faster")) == "R + T", "shown as R + T")
	var used := []
	for action in Controls.ACTIONS:
		var binding: Dictionary = Controls.default_for(action)
		if Controls.kind(binding) == "single":
			used.append(binding)
	check(not {"key": KEY_T} in used and not {"key": KEY_F} in used and not {"key": KEY_G} in used, "T, F and G free for other actions")
	var combos := KeyCombos.new()
	combos.set_bindings(Controls.defaults())
	press(combos, KEY_R, true, 0)
	check(press(combos, KEY_T, true, 50) == [["run_faster", true]] and press(combos, KEY_T, false, 900) == [["run_faster", false]], "R then T triggers Accélérer while held")
	# Attributs.
	for key in ["run_max", "run_accel", "run_decel"]:
		check(key in Settings.ATTRIBUTE_KEYS, "attribute: " + key)
	check(Settings.SPECS.run_max.default == 14.0 and Settings.SPECS.run_accel.default == 3.0 and Settings.SPECS.run_decel.default == 6.0, "defaults 14 m/s, 3 and 6 m/s²")
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	player.apply_settings(Settings.default_values())
	player.run_mode = "hold"
	# Accélération progressive puis maximum.
	frames(player, 30, true, true)
	check(player.running and player.boosted and absf(player.run_boost - 1.5) < 0.05, "half a second: +1.5 m/s (%.2f)" % player.run_boost)
	frames(player, 30, true, true)
	check(absf(player.run_boost - 3.0) < 0.05, "one second: +3 m/s (%.2f)" % player.run_boost)
	frames(player, 300, true, true)
	check(is_equal_approx(player.run_boost, 14.0 - 8.5), "capped at the maximum (%.2f)" % player.run_boost)
	var fast: float = await walk(player, 20)
	check(absf(fast - 14.0) < 0.5, "forward speed at the maximum: 14 m/s (%.2f)" % fast)
	# Vitesse gardée : R tenue, puis relâchée, puis un saut.
	frames(player, 60, true)
	check(is_equal_approx(player.run_boost, 5.5), "speed kept while running")
	frames(player, 10, false)
	frames(player, 1, false, false, false, false, true, true)
	check(player.running and is_equal_approx(player.run_boost, 5.5), "accelerated run continues after release and a jump")
	# Ralentir.
	frames(player, 30, false, false, true)
	check(player.running and absf(player.run_boost - 2.5) < 0.05, "Ralentir: -6 m/s² (%.2f)" % player.run_boost)
	frames(player, 60, false, false, true)
	check(player.running and player.run_boost == 0.0, "never below the normal run")
	# Vitesse normale.
	frames(player, 60, true, true)
	frames(player, 1, true, false, false, true)
	check(player.running and player.run_boost == 0.0 and not player.boosted, "Vitesse normale: normal run at once")
	# Arrêt réel, pause.
	frames(player, 60, true, true)
	frames(player, 1, true, false, false, false, false)
	check(player.run_boost == 0.0 and not player.boosted, "stopping resets the speed")
	frames(player, 60, true, true)
	player.release_controls()
	check(player.run_boost == 0.0 and not player.boosted and not player.running, "pause resets the speed")
	# Maintenir conditionnel : un saut arrête la course normale, pas la course accélérée.
	player.run_mode = "latch"
	frames(player, 1, true, false, false, false, true, false, true)
	frames(player, 1, false, false, false, false, true, true)
	check(not player.running, "latch: a jump still stops the normal run")
	frames(player, 1, true, false, false, false, true, false, true)
	frames(player, 30, true, true)
	frames(player, 1, false, false, false, false, true, true)
	check(player.running and player.run_boost > 1.0, "latch: accelerated run continues after a jump")
	player.release_controls()
	# Basculer : R + T ne coupe pas la course lancée.
	player.run_mode = "toggle"
	frames(player, 1, true, false, false, false, true, false, true)
	frames(player, 5, false)
	frames(player, 1, true, true, false, false, true, false, true)
	check(player.running and player.boosted, "toggle: R + T keeps running")
	frames(player, 1, true, false, false, true, true, false, true)
	frames(player, 5, false)
	check(player.running and not player.boosted, "toggle: R + G keeps the normal run")
	player.release_controls()
	player.run_latched = false
	player.run_mode = "hold"
	# Attributs appliqués.
	var values := Settings.default_values()
	values.run_max = 10.0
	values.run_accel = 50.0
	player.apply_settings(values)
	frames(player, 10, true, true)
	check(is_equal_approx(player.run_boost, 1.5), "maximum and acceleration follow the attributes")
	values.run_max = 5.0
	player.apply_settings(values)
	frames(player, 10, true, true)
	check(player.run_boost == 0.0, "maximum below the run speed: no extra speed")
	root.remove_child(world)
	world.queue_free()
	# Anciens fichiers (0.0.4.1) : attributs.json et controles.json sans les nouveautés.
	var fixture := "res://.godot/run-faster-%d.json" % Time.get_ticks_usec()
	var blank := Settings.new(fixture)
	var file := FileAccess.open(blank.file_path("attributes"), FileAccess.WRITE)
	file.store_string('{"run_forward": 9.0, "walk_forward": 6.0}')
	file.close()
	file = FileAccess.open(blank.controls_path(), FileAccess.WRITE)
	file.store_string('{"sprint": {"key": %d}, "run_mode": "toggle"}' % KEY_E)
	file.close()
	var legacy := Settings.new(fixture)
	check(legacy.values.run_forward == 9.0 and legacy.values.run_max == 14.0 and legacy.values.run_accel == 3.0 and legacy.values.run_decel == 6.0 and legacy.load_notice.is_empty(), "old attributs.json: new attributes by default, no warning")
	check(legacy.controls.sprint == {"key": KEY_E} and legacy.controls.run_faster == Controls.default_for("run_faster") and legacy.control_options.run_mode == "toggle" and legacy.load_notice.is_empty(), "old controles.json: new actions by default, no warning")
	# Menus : Contrôles, Attributs → Courir, Comment jouer.
	var settings := Settings.new(fixture + ".app")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	await process_frame
	check(app.control_buttons.has("run_faster") and app.control_buttons.run_faster.text == "R" and app.control_second_buttons.run_faster.text == "T", "Accélérer in Contrôles: R, second key T")
	check(app.control_second_buttons.run_slower.text == "F" and app.control_second_buttons.run_normal.text == "G", "Ralentir R + F, Vitesse normale R + G")
	check(app.ATTRIBUTE_CATEGORIES.Courir.keys.has("run_max") and app.setting_fields.has("run_accel") and app.setting_sliders.has("run_decel"), "attributes in Courir with fields and sliders")
	var help: String = load("res://scripts/world.gd").get_help_text(2)
	check(help.contains("R + T") and help.contains("R + F") and help.contains("R + G"), "Comment jouer explains the keys")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d run faster checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
