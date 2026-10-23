extends SceneTree
# 0.0.4.10 : retour au mode par défaut après le mode développeur (Paramètres du monde, ou Attributs
# en partie) ; les Informations du monde disent alors « Mode développeur utilisé au moins une fois ».
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
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
	var fixture := "res://.godot/developer-return-%d.json" % Time.get_ticks_usec()
	# Catalogue.
	var catalog := Catalog.new(fixture + ".worlds")
	var plain: Dictionary = catalog.create_world("Simple", "1")
	var dev: Dictionary = catalog.create_world("Dev", "2", Catalog.MODE_DEVELOPER)
	check(not plain.developer_used and dev.developer_used, "developer_used: false by default, true for a developer world")
	check(catalog.enable_developer_mode(plain.id) and catalog.find_world(plain.id).developer_used, "enabling marks the world")
	check(catalog.disable_developer_mode(plain.id) and catalog.find_world(plain.id).mode == Catalog.MODE_DEFAULT and catalog.find_world(plain.id).developer_used, "back to default, the mark stays")
	check(catalog.disable_developer_mode(plain.id) and not catalog.disable_developer_mode("absent"), "already default: fine ; unknown world: refused")
	var reloaded := Catalog.new(fixture + ".worlds")
	check(reloaded.find_world(plain.id).mode == Catalog.MODE_DEFAULT and reloaded.find_world(plain.id).developer_used, "mark saved in worlds.json")
	var copy: Dictionary = reloaded.duplicate_world(plain.id)
	check(copy.mode == Catalog.MODE_DEFAULT and copy.developer_used, "a copy keeps the mark")
	# Ancien worlds.json (sans developer_used).
	var old_path := fixture + ".old"
	var file := FileAccess.open(old_path, FileAccess.WRITE)
	file.store_string('{"version": 1, "worlds": [{"id": "1", "name": "A", "seed": 1, "mode": "developer"}, {"id": "2", "name": "B", "seed": 2, "mode": "default"}]}')
	file.close()
	var old := Catalog.new(old_path)
	check(old.load_error.is_empty() and old.find_world("1").developer_used and not old.find_world("2").developer_used, "old worlds.json: developer worlds marked, others not")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))
	# Paramètres du monde.
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = Catalog.new(fixture + ".app-worlds")
	var world_item: Dictionary = app.catalog.create_world("Essai", "5")
	root.add_child(app)
	current_scene = app
	await process_frame
	app.refresh_world_list(world_item.id)
	app.world_settings_button.pressed.emit()
	check(app.world_developer_button.visible and not app.world_default_button.visible and not app.world_settings_text.text.contains("déjà utilisé"), "default world: no way back needed, no mark")
	app.world_developer_button.pressed.emit()
	check(app.developer_confirm_message.text.contains("irréversible") and app.developer_confirm_button.text == "Confirmer : mode développeur", "confirmation: only the mark is irreversible")
	app.developer_confirm_button.pressed.emit()
	check(app.world_default_button.visible and not app.world_developer_button.visible, "developer world: Repasser en mode par défaut")
	app.world_default_button.pressed.emit()
	check(app.page == "world_settings" and app.catalog.find_world(world_item.id).mode == Catalog.MODE_DEFAULT and app.world_developer_button.visible and app.world_settings_text.text.contains("déjà utilisé"), "back to default from Paramètres du monde, mark shown")
	app.world_settings_back_button.pressed.emit()
	# Informations du monde.
	app.open_world(world_item.id)
	await process_frame
	check(not app.active_world.developer_mode and app.active_world.developer_used, "game: default mode, mark known")
	for level in range(3):
		check(app.active_world.get_world_info_text(level).contains("Mode développeur utilisé au moins une fois") and app.active_world.get_world_info_text(level).contains("Par défaut"), "world info says so, detail level %d" % level)
	# En partie : passer en développeur, puis revenir depuis Attributs.
	app.pause_game()
	app.pause_settings_button.pressed.emit()
	app.settings_tabs.attributes.pressed.emit()
	check(app.attributes_gate.visible and not app.attributes_default_button.visible, "default world in game: gate, no way-back button")
	app.attributes_gate_button.pressed.emit()
	app.attributes_gate_confirm.pressed.emit()
	check(app.active_world.developer_mode and app.attributes_default_button.visible and app.attributes_scroll.visible, "developer in game: fields and Repasser button")
	app.settings.values.walk_forward = 11.0
	app.attributes_default_button.pressed.emit()
	check(not app.active_world.developer_mode and app.catalog.find_world(world_item.id).mode == Catalog.MODE_DEFAULT and app.attributes_gate.visible and not app.attributes_default_button.visible, "back to default in game")
	check(app.active_world.player.walk_forward == Settings.SPECS.walk_forward.default and app.active_world.world_mode_text == "Par défaut", "default attributes apply at once")
	check(app.active_world.get_world_info_text(2).contains("Mode développeur utilisé au moins une fois"), "mark still shown")
	# Un monde jamais passé en développeur : pas de mention.
	app.return_to_worlds()
	var fresh: Dictionary = app.catalog.create_world("Neuf", "6")
	app.open_world(fresh.id)
	await process_frame
	check(not app.active_world.get_world_info_text(2).contains("utilisé au moins une fois"), "never used: no mark")
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for path in [fixture + ".worlds", fixture + ".app-worlds"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d developer return checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
