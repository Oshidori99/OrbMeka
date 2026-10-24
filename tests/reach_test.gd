extends SceneTree
# 0.0.3.13 : portées de casse et de pose réglables (Attributs → Blocs).
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

# Visée simulée : un bloc touché à « distance » mètres de la caméra.
func hit_at(world: Node3D, cell: Vector3i, distance: float) -> Dictionary:
	var camera: Camera3D = world.player.camera
	return {"collider": world.section_body(cell), "cell": cell, "position": camera.global_position + Vector3(0, 0, -distance), "normal": Vector3.UP}

func _run() -> void:
	root.size = Vector2i(1280, 720)
	check(Settings.SPECS.break_reach.default == 5 and Settings.SPECS.place_reach.default == 5 and "break_reach" in Settings.ATTRIBUTE_KEYS and "place_reach" in Settings.ATTRIBUTE_KEYS, "two reach attributes, 5 blocks by default")
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var values := Settings.default_values()
	values.break_reach = 3.0
	values.place_reach = 8.0
	world.player.apply_settings(values)
	var cell: Vector3i = world.blocks.keys()[0]
	check(not world.break_target(hit_at(world, cell, 4.0)) and world.blocks.has(cell), "break refused beyond break reach (4 > 3)")
	check(world.break_target(hit_at(world, cell, 2.5)) and not world.blocks.has(cell), "break allowed within break reach")
	var target: Vector3i = world.blocks.keys()[0]
	var count: int = world.blocks.size()
	var far := hit_at(world, target, 7.0)
	far.position = Vector3(target) + Vector3(0.5, 1.0, 0.5)
	var camera_far: float = world.player.camera.global_position.distance_to(far.position)
	values.place_reach = camera_far + 1.0
	world.player.apply_settings(values)
	world.place_target(far, 0)
	var placed_far: bool = world.blocks.size() == count + 1
	values.place_reach = maxf(1.0, camera_far - 1.0)
	world.player.apply_settings(values)
	count = world.blocks.size()
	check(not world.place_target(far, 0) and world.blocks.size() == count, "place refused beyond place reach")
	check(placed_far, "place allowed within place reach")
	check(world.player.break_reach == 3 and world.player.place_reach == values.place_reach, "player receives both reaches")
	# Le rayon de visée va jusqu'à la plus grande portée.
	values.break_reach = 12.0
	values.place_reach = 2.0
	world.player.apply_settings(values)
	check(maxf(world.player.break_reach, world.player.place_reach) == 12, "aiming reaches the largest reach")
	root.remove_child(world)
	world.queue_free()
	# Paramètres : catégorie Blocs, défauts dans un monde par défaut.
	var fixture := "res://.godot/reach-test-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var normal: Dictionary = app.catalog.create_world("Portée normale", "2")
	var dev: Dictionary = app.catalog.create_world("Portée dev", "2", "developer")
	root.add_child(app)
	await process_frame
	check(app.ATTRIBUTE_CATEGORIES.Blocs.keys.has("break_reach") and app.ATTRIBUTE_CATEGORIES.Blocs.keys.has("place_reach") and app.setting_sliders.has("break_reach"), "reaches in Attributs → Blocs with sliders")
	app.show_page("settings")
	app.setting_fields.break_reach.text = "9"
	app.setting_fields.place_reach.text = "11"
	app.apply_user_settings()
	app.open_world(dev.id)
	check(app.active_world.player.break_reach == 9 and app.active_world.player.place_reach == 11, "developer world uses the chosen reaches")
	app.return_to_worlds()
	app.open_world(normal.id)
	check(app.active_world.player.break_reach == 5 and app.active_world.player.place_reach == 5, "default world keeps 5 blocks")
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for menu in Settings.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.file_path(menu)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d reach checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
