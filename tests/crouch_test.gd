extends SceneTree
# 0.0.3.15 : se baisser (touche Y par défaut) : plus lent dans chaque direction,
# chute plus lourde ; vitesses et gravité réglables dans Attributs → Se baisser.
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
	return Vector2(player.position.x - start.x, player.position.z - start.z).length()

func fall_time(player: CharacterBody3D) -> float:
	player.position = Vector3(30.5, 12.0, 30.5)
	player.velocity = Vector3.ZERO
	for index in range(600):
		await physics_frame
		player.step_movement(1.0 / 60.0, Vector2.ZERO, false)
		if player.is_on_floor():
			return (index + 1) / 60.0
	return 99.0

func _run() -> void:
	root.size = Vector2i(1280, 720)
	check(Controls.ACTIONS.has("crouch") and Controls.ACTIONS.crouch.label == "Se baisser" and Controls.ACTIONS.crouch.default == {"key": KEY_Y}, "Se baisser in Contrôles, Y by default")
	for key in ["crouch_forward", "crouch_side", "crouch_back", "crouch_gravity"]:
		check(key in Settings.ATTRIBUTE_KEYS, "crouch attribute: " + key)
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	player.apply_settings(Settings.default_values())
	var normal_forward: float = await walk(player, Vector2(0, -1), 60)
	player.crouching = true
	var crouch_forward: float = await walk(player, Vector2(0, -1), 60)
	var crouch_back: float = await walk(player, Vector2(0, 1), 60)
	var crouch_side: float = await walk(player, Vector2(1, 0), 60)
	check(crouch_forward < normal_forward * 0.5, "crouching walks forward much slower (%.2f < %.2f)" % [crouch_forward, normal_forward])
	check(absf(crouch_forward - 1.5) < 0.15 and absf(crouch_back - 1.5) < 0.15 and absf(crouch_side - 1.5) < 0.15, "default crouch speed 1.5 m/s in every direction")
	player.crouching = false
	var normal_fall: float = await fall_time(player)
	player.crouching = true
	var heavy_fall: float = await fall_time(player)
	check(heavy_fall < normal_fall - 0.2, "crouching falls faster (%.2f s < %.2f s)" % [heavy_fall, normal_fall])
	var values := Settings.default_values()
	values.crouch_forward = 3.0
	values.crouch_gravity = 60.0
	player.apply_settings(values)
	var tuned: float = await walk(player, Vector2(0, -1), 60)
	var heavier: float = await fall_time(player)
	check(absf(tuned - 3.0) < 0.2 and heavier < heavy_fall, "crouch speed and gravity follow the attributes")
	player.crouching = false
	root.remove_child(world)
	world.queue_free()
	# Paramètres : catégorie sous Marche, touche dans Contrôles.
	var fixture := "res://.godot/crouch-test-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	await process_frame
	var categories: Array = app.ATTRIBUTE_CATEGORIES.keys()
	check(categories.find("Se baisser") == categories.find("Courir") + 1 and categories.find("Courir") == categories.find("Marche") + 1, "Se baisser category under Marche and Courir (0.0.3.24)")
	check(app.setting_fields.has("crouch_gravity") and app.setting_sliders.has("crouch_forward"), "crouch fields with sliders")
	check(app.control_buttons.has("crouch") and app.control_buttons.crouch.text == "Y", "Se baisser key shown as Y")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d crouch checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
