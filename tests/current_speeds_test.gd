extends SceneTree
# 0.0.4.15 : Attributs → Vitesses actuelles (déplacement, marche, course, casse, pose, en %) : changées
# en direct par les touches de vitesse dans un monde en mode développeur (champ et barre), enregistrées ;
# réglables à la main aussi. Monde par défaut : rien d'enregistré.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
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

func hold(player: Node, count: int, changes: Dictionary, up := false) -> void:
	for index in range(count):
		player.update_speed(DELTA, true, up, false, false, changes)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var keys := ["current_speed", "current_walk", "current_run", "current_break", "current_place"]
	for key in keys:
		check(key in Settings.ATTRIBUTE_KEYS and Settings.SPECS[key].default == 100.0, "attribute 100 %%: %s" % key)
	var fixture := "res://.godot/current-speeds-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = Catalog.new(fixture + ".worlds")
	var dev: Dictionary = app.catalog.create_world("Dev", "1", Catalog.MODE_DEVELOPER)
	var plain: Dictionary = app.catalog.create_world("Simple", "2")
	root.add_child(app)
	current_scene = app
	await process_frame
	var categories: Array = app.ATTRIBUTE_CATEGORIES.keys()
	check(app.ATTRIBUTE_CATEGORIES["Vitesses actuelles"].keys == keys and categories.find("Vitesses actuelles") == categories.find("Changer de vitesse") + 1, "Vitesses actuelles, just under Changer de vitesse")
	check(keys.all(func(key): return app.setting_sliders.has(key)), "a bar for each")
	# Monde développeur : les touches changent les Attributs en direct.
	app.open_world(dev.id)
	await process_frame
	var player: Node = app.active_world.player
	player.set_physics_process(false)
	hold(player, 60, {"walk": 1.0})
	check(absf(settings.values.current_walk - 140.0) < 0.5 and app.setting_fields.current_walk.text == Settings.number_text(settings.values.current_walk) and absf(app.setting_sliders.current_walk.value - 140.0) < 0.6, "↑ + W: Marche actuelle 140 %%, field and bar follow (%s)" % app.setting_fields.current_walk.text)
	hold(player, 30, {}, true)
	check(absf(settings.values.current_speed - 120.0) < 0.5, "↑ + A: Déplacement actuel 120 %%")
	hold(player, 600, {"break": 1.0})
	check(settings.values.current_break == 200.0 and app.setting_sliders.current_break.value == 200.0, "casse at the maximum: 200 %%")
	app.speed_save_timer.timeout.emit()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings.file_path("attributes")))
	check(absf(saved.current_walk - 140.0) < 0.5 and saved.current_break == 200.0, "saved in attributs.json")
	player.update_speed(DELTA, true, false, false, true)
	check(settings.values.current_walk == 100.0 and app.setting_fields.current_break.text == Settings.number_text(100.0), "⌫ twice: back to 100 %% in the Attributs too")
	# Réglage à la main dans les Attributs.
	app.setting_fields.current_run.text = "150"
	app._autosave()
	check(is_equal_approx(player.run_scale, 1.5), "typing 150 %% sets the run speed in game")
	app.setting_fields.current_run.text = "450"
	app._autosave()
	check(is_equal_approx(player.run_scale, 2.0), "kept within Vitesse maximale (200 %%)")
	app.return_to_worlds()
	var reloaded := Settings.new(fixture)
	check(reloaded.values.current_run == 450.0, "typed value kept as typed (limited only in game)")
	# Monde par défaut : rien n'est changé dans les Attributs.
	app.open_world(plain.id)
	await process_frame
	player = app.active_world.player
	player.set_physics_process(false)
	var before: float = settings.values.current_walk
	hold(player, 60, {"walk": 1.0})
	check(settings.values.current_walk == before and player.walk_scale > 1.0 and player.walk_scale <= 1.5, "default world: speed changes in game only (75-150 %%)")
	app.return_to_worlds()
	# Ancien attributs.json.
	var old := Settings.new(fixture + ".old")
	var file := FileAccess.open(old.file_path("attributes"), FileAccess.WRITE)
	file.store_string('{"walk_forward": 6.0}')
	file.close()
	var legacy := Settings.new(fixture + ".old")
	check(legacy.values.current_speed == 100.0 and legacy.load_notice.is_empty(), "old attributs.json: 100 %%, no warning")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d current speed checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
