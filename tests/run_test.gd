extends SceneTree
# 0.0.3.24 : courir (touche R par défaut, maintenue) : plus rapide dans chaque direction ;
# vitesses réglables dans Attributs → Courir ; se baisser l'emporte sur courir.
const Settings = preload("res://scripts/user_settings.gd")
const Controls = preload("res://scripts/controls.gd")
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

func walk(player: CharacterBody3D, direction: Vector2, steps: int) -> float:
	player.position = Vector3(0.5, 0.02, 8.5)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	for index in range(5):
		await physics_frame
		player.step_movement(1.0 / 60.0, Vector2.ZERO, false)
	var start := player.position
	for index in range(steps):
		await physics_frame
		player.step_movement(1.0 / 60.0, direction, false)
	# Vitesse moyenne en m/s (pas trop loin : collines et blocs de démonstration).
	return Vector2(player.position.x - start.x, player.position.z - start.z).length() * 60.0 / steps


func _run() -> void:
	root.size = Vector2i(1280, 720)
	check(Controls.ACTIONS.has("sprint") and Controls.ACTIONS.sprint.label == "Courir" and Controls.ACTIONS.sprint.default == {"key": KEY_R} and Controls.ACTIONS.sprint.get("by_letter", false), "Courir in Contrôles, R by default (by letter)")
	check(Controls.ACTIONS.keys().find("sprint") == Controls.ACTIONS.keys().find("crouch") + 1, "Courir listed after Se baisser")
	for key in ["run_forward", "run_side", "run_back"]:
		check(key in Settings.ATTRIBUTE_KEYS and is_equal_approx(Settings.SPECS[key].default, 8.5), "run attribute, 8.5 m/s by default: " + key)
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	player.apply_settings(Settings.default_values())
	var normal_forward: float = await walk(player, Vector2(0, -1), 30)
	player.running = true
	var run_forward: float = await walk(player, Vector2(0, -1), 30)
	# Reculer : trajet court (un relief commence à 2 m derrière le départ).
	var run_back: float = await walk(player, Vector2(0, 1), 12)
	var run_side: float = await walk(player, Vector2(1, 0), 30)
	check(run_forward > normal_forward * 1.4, "running is faster than walking (%.2f > %.2f)" % [run_forward, normal_forward])
	check(absf(run_forward - 8.5) < 0.3 and absf(run_back - 8.5) < 0.3 and absf(run_side - 8.5) < 0.3, "default run speed 8.5 m/s in every direction (%.2f, %.2f, %.2f)" % [run_forward, run_back, run_side])
	player.crouching = true
	var crouch_run: float = await walk(player, Vector2(0, -1), 30)
	check(absf(crouch_run - 1.5) < 0.15, "crouching wins over running (%.2f m/s)" % crouch_run)
	player.crouching = false
	var values := Settings.default_values()
	values.run_forward = 12.0
	player.apply_settings(values)
	var tuned: float = await walk(player, Vector2(0, -1), 30)
	check(absf(tuned - 12.0) < 0.4, "run speed follows the attributes (%.2f m/s)" % tuned)
	player.running = false
	var walked: float = await walk(player, Vector2(0, -1), 30)
	check(absf(walked - normal_forward) < 0.1, "releasing the key walks again")
	root.remove_child(world)
	world.queue_free()
	# Paramètres : catégorie Courir sous Marche, touche dans Contrôles.
	var fixture := "res://.godot/run-test-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	await process_frame
	var categories: Array = app.ATTRIBUTE_CATEGORIES.keys()
	check(categories.find("Courir") == categories.find("Marche") + 1, "Courir category just under Marche")
	check(app.setting_fields.has("run_forward") and app.setting_sliders.has("run_back"), "run fields with sliders")
	check(app.control_buttons.has("sprint") and app.control_buttons.sprint.text == "R", "Courir key shown as R")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d run checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
