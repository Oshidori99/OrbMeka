extends SceneTree
# 0.0.3.17 : Attributs → Vue : hauteur des yeux en blocs, deux décimales.
const Settings = preload("res://scripts/user_settings.gd")
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
	root.size = Vector2i(1280, 720)
	var spec: Dictionary = Settings.SPECS.eye_height
	check(spec.default == 1.62 and spec.unit == "blocs" and spec.step == 0.01 and "eye_height" in Settings.ATTRIBUTE_KEYS, "eye height attribute in blocks, original 1,62 by default")
	var fixture := "res://.godot/eye-test-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var dev: Dictionary = app.catalog.create_world("Vue haute", "7", "developer")
	var normal: Dictionary = app.catalog.create_world("Vue normale", "7")
	root.add_child(app)
	current_scene = app
	await process_frame
	var categories: Array = app.ATTRIBUTE_CATEGORIES.keys()
	check(categories.find("Vue") == categories.find("Se baisser") + 1 and app.ATTRIBUTE_CATEGORIES.Vue.keys == ["eye_height"], "Vue category in Attributs")
	check(app.setting_sliders.eye_height.step == 0.01, "slider moves by 0,01")
	app.show_page("settings")
	for pair in [["1,9", 1.9], ["2,15", 2.15], ["1", 1.0], ["1,999", 2.0]]:
		app.setting_fields.eye_height.text = pair[0]
		app.apply_user_settings()
		check(is_equal_approx(settings.values.eye_height, pair[1]), "eye height %s saved as %s" % [pair[0], str(pair[1])])
	app.setting_fields.eye_height.text = "0,1"
	app.apply_user_settings()
	check(is_equal_approx(settings.values.eye_height, 2.0) and app.settings_message.text.begins_with("Hauteur des yeux"), "too low refused")
	app.setting_fields.eye_height.text = "2,15"
	app.apply_user_settings()
	check(app.setting_fields.eye_height.text == "2,15", "two decimals shown")
	app.open_world(dev.id)
	await process_frame
	var player: CharacterBody3D = app.active_world.player
	check(is_equal_approx(player.camera.position.y, 2.15), "developer world: eyes at 2,15 blocks")
	player.set_physics_process(false)
	player.crouching = true
	for index in range(60):
		player.step_movement(1.0 / 60.0, Vector2.ZERO, false)
	check(player.camera.position.y < 2.15 - 0.2, "crouching lowers the view from the chosen height")
	player.crouching = false
	app.return_to_worlds()
	app.open_world(normal.id)
	await process_frame
	check(is_equal_approx(app.active_world.player.camera.position.y, 1.62), "default world keeps 1,62")
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for menu in Settings.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.file_path(menu)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d eye height checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
