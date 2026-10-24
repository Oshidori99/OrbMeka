extends SceneTree
# 0.0.4.5 : voler. Espace deux fois (touche Voler, modifiable) pour commencer ou arrêter ;
# en vol, sans gravité, Sauter monte et Se baisser descend ; vitesses dans Attributs → Voler,
# un peu plus rapides que courir ; ↑ ↓ comptent aussi. Contrôles : « Aucune » sans 2e touche.
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

# Vitesse moyenne (m/s) en vol, à 20 m de haut, loin des collines.
func fly(player: CharacterBody3D, direction: Vector2, vertical: float, steps: int) -> Vector3:
	player.position = Vector3(0.5, 20.0, 8.5)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await physics_frame
	var start := player.position
	for index in range(steps):
		await physics_frame
		player.step_flight(DELTA, direction, vertical)
	return (player.position - start) * 60.0 / steps

func press(combos: KeyCombos, code: int, pressed: bool, now: int) -> Array:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return combos.feed(event, now)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	# Contrôles.
	check(Controls.ACTIONS.has("fly") and Controls.ACTIONS.fly.label == "Voler", "Voler in Contrôles")
	check(Controls.default_for("fly") == Controls.normalize({"key": KEY_SPACE, "second": {"key": KEY_SPACE}}) and Controls.label(Controls.default_for("fly")) == "Espace → Espace", "Espace deux fois by default (Espace → Espace)")
	var combos := KeyCombos.new()
	combos.set_bindings(Controls.defaults())
	press(combos, KEY_SPACE, true, 0)
	press(combos, KEY_SPACE, false, 80)
	check(press(combos, KEY_SPACE, true, 200) == [["fly", true]], "two quick Space presses trigger Voler")
	press(combos, KEY_SPACE, false, 300)
	press(combos, KEY_SPACE, true, 1500)
	check(press(combos, KEY_SPACE, true, 2100) == [], "two slow presses do not")
	# Attributs.
	for key in ["fly_forward", "fly_side", "fly_back", "fly_up", "fly_down"]:
		check(key in Settings.ATTRIBUTE_KEYS, "attribute: " + key)
	check(Settings.SPECS.fly_forward.default > Settings.SPECS.run_forward.default and Settings.SPECS.fly_side.default > Settings.SPECS.run_side.default and Settings.SPECS.fly_back.default > Settings.SPECS.run_back.default, "flying a bit faster than running by default")
	check(Settings.SPECS.fly_up.default == 7.0 and Settings.SPECS.fly_down.default == 7.0, "up and down 7 m/s by default")
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	player.apply_settings(Settings.default_values())
	# Voler : appui = commencer / arrêter, rien en pause.
	check(not player.flying, "not flying at start")
	player.update_fly(false, true)
	check(not player.flying, "nothing while paused")
	player.update_fly(true, true)
	check(player.flying, "Voler starts flying")
	var hover: Vector3 = await fly(player, Vector2.ZERO, 0.0, 30)
	check(hover.length() < 0.01, "no gravity while flying (%.2f)" % hover.y)
	var forward: Vector3 = await fly(player, Vector2(0, -1), 0.0, 30)
	var back: Vector3 = await fly(player, Vector2(0, 1), 0.0, 30)
	var side: Vector3 = await fly(player, Vector2(1, 0), 0.0, 30)
	check(absf(forward.length() - 10.0) < 0.3 and absf(back.length() - 10.0) < 0.3 and absf(side.length() - 10.0) < 0.3 and absf(forward.y) < 0.01, "10 m/s in every direction (%.2f, %.2f, %.2f)" % [forward.length(), back.length(), side.length()])
	var up: Vector3 = await fly(player, Vector2.ZERO, 1.0, 30)
	var down: Vector3 = await fly(player, Vector2.ZERO, -1.0, 30)
	check(absf(up.y - 7.0) < 0.2 and absf(down.y + 7.0) < 0.2, "up and down 7 m/s (%.2f, %.2f)" % [up.y, down.y])
	var climb: Vector3 = await fly(player, Vector2(0, -1), 1.0, 30)
	check(absf(climb.y - 7.0) < 0.2 and absf(Vector2(climb.x, climb.z).length() - 10.0) < 0.3, "forward and up together")
	# ↑ ↓ comptent aussi en vol.
	player.speed_scale = 2.0
	var fast: Vector3 = await fly(player, Vector2(0, -1), 1.0, 30)
	check(absf(fast.z + 20.0) < 0.6 and absf(fast.y - 14.0) < 0.4, "↑ ↓ speed also counts in the air (%.2f, %.2f)" % [fast.z, fast.y])
	player.speed_scale = 1.0
	# Attributs appliqués.
	var values := Settings.default_values()
	values.fly_forward = 20.0
	values.fly_up = 3.0
	values.fly_down = 12.0
	player.apply_settings(values)
	var tuned: Vector3 = await fly(player, Vector2(0, -1), 0.0, 30)
	var tuned_up: Vector3 = await fly(player, Vector2.ZERO, 1.0, 30)
	var tuned_down: Vector3 = await fly(player, Vector2.ZERO, -1.0, 30)
	check(absf(tuned.z + 20.0) < 0.6 and absf(tuned_up.y - 3.0) < 0.15 and absf(tuned_down.y + 12.0) < 0.4, "speeds follow the attributes")
	player.apply_settings(Settings.default_values())
	# Plafond, sol.
	player.position = Vector3(0.5, player.FLY_CEILING - 0.5, 8.5)
	for index in range(60):
		await physics_frame
		player.step_flight(DELTA, Vector2.ZERO, 1.0)
	check(player.position.y <= player.FLY_CEILING + 0.001, "flight ceiling")
	player.position = Vector3(0.5, 3.0, 8.5)
	for index in range(120):
		await physics_frame
		player.step_flight(DELTA, Vector2.ZERO, -1.0)
	check(player.position.y > -0.5, "descending stops on the ground")
	# Arrêter de voler : la gravité revient.
	player.update_fly(true, true)
	check(not player.flying, "Voler again stops flying")
	player.position = Vector3(0.5, 20.0, 8.5)
	player.velocity = Vector3.ZERO
	for index in range(30):
		await physics_frame
		player.step_movement(DELTA, Vector2.ZERO, false)
	check(player.position.y < 19.0, "falls again after flying")
	root.remove_child(world)
	world.queue_free()
	# Anciens fichiers (0.0.4.4) : sans vol.
	var fixture := "res://.godot/fly-%d.json" % Time.get_ticks_usec()
	var blank := Settings.new(fixture)
	var file := FileAccess.open(blank.file_path("attributes"), FileAccess.WRITE)
	file.store_string('{"run_forward": 9.0, "speed_max": 300.0}')
	file.close()
	file = FileAccess.open(blank.controls_path(), FileAccess.WRITE)
	file.store_string('{"jump": {"key": %d}, "run_mode": "toggle"}' % KEY_SPACE)
	file.close()
	var legacy := Settings.new(fixture)
	check(legacy.values.fly_forward == 10.0 and legacy.values.speed_max == 300.0 and legacy.load_notice.is_empty(), "old attributs.json: flight by default, no warning")
	check(legacy.controls.fly == Controls.default_for("fly") and legacy.controls.jump == Controls.normalize({"key": KEY_SPACE}) and legacy.load_notice.is_empty(), "old controles.json: Voler by default, no warning")
	# Menus.
	var settings := Settings.new(fixture + ".app")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	await process_frame
	check(app.control_buttons.fly.text == "Espace" and app.control_slot_texts("fly") == ["Espace", "Espace"] and app.control_labels.fly.text == "Voler", "Voler shown as Espace → Espace")
	check(app.control_slot_texts("jump").size() == 1 and app.control_slot_texts("sprint").size() == 1, "one key: one box (0.0.4.20, no second-key column)")
	var categories: Array = app.ATTRIBUTE_CATEGORIES.keys()
	check(categories.find("Voler") == categories.find("Se baisser") + 1 and app.setting_fields.has("fly_up") and app.setting_sliders.has("fly_down"), "Voler category under Se baisser, with fields and sliders")
	var help: String = load("res://scripts/world.gd").get_help_text(2)
	check(help.contains("Voler : Espace deux fois") and load("res://scripts/world.gd").get_help_text(0).contains("voler"), "Comment jouer explains flying")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d fly checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
