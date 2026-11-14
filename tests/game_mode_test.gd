extends SceneTree
# 0.0.7 : Paramètres → Monde (en partie seulement, tout en haut) : mode de jeu Survie / Créatif,
# propre à chaque monde, enregistré dans worlds.json et monde.json ; ancien monde : Créatif.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Store = preload("res://scripts/world_store.gd")
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
	var fixture := "res://.godot/game-mode-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = Catalog.new(fixture + ".worlds")
	var first: Dictionary = app.catalog.create_world("Premier", "5")
	var second: Dictionary = app.catalog.create_world("Second", "6")
	root.add_child(app)
	current_scene = app
	await process_frame
	check(app.SETTINGS_SECTIONS.keys()[0] == "world" and app.SETTINGS_SECTIONS.world == "Monde", "Monde is the first settings section")
	# Hors partie : pas d'onglet Monde.
	app.show_page("settings")
	check(not app.settings_tabs.world.visible and app.settings_section == "general", "home settings: no Monde tab, general opens")
	app.settings_back_button.pressed.emit()
	check(app.catalog.find_world(first.id).get("game_mode") == null or app.catalog.find_world(first.id).get("game_mode") == Catalog.GAME_CREATIVE, "new world: creative by default")
	# En partie : Monde ouvert en premier, Survie à gauche, Créatif à droite.
	app.open_world(first.id)
	app.pause_game()
	app.pause_settings_button.pressed.emit()
	check(app.settings_tabs.world.visible and app.settings_section == "world" and app.settings_sections.world.visible, "in game: Monde tab shown and opened first")
	var survival: Button = app.game_mode_buttons[Catalog.GAME_SURVIVAL]
	var creative: Button = app.game_mode_buttons[Catalog.GAME_CREATIVE]
	check(survival.text == "Survie" and creative.text == "Créatif" and survival.get_index() < creative.get_index(), "Survie on the left, Créatif on the right")
	check(creative.button_pressed and not survival.button_pressed, "creative selected at first")
	survival.pressed.emit()
	check(survival.button_pressed and not creative.button_pressed, "Survie selected")
	check(app.catalog.find_world(first.id).game_mode == Catalog.GAME_SURVIVAL, "mode saved in the catalog")
	var base := Store.read_json(app.catalog.world_folder(first.id).path_join(Store.BASE_FILE), Store.valid_base)
	check(base.get("data", {}).get("mode_de_jeu") == Catalog.GAME_SURVIVAL, "mode saved in monde.json")
	var reloaded := Catalog.new(fixture + ".worlds")
	check(reloaded.find_world(first.id).game_mode == Catalog.GAME_SURVIVAL and reloaded.find_world(second.id).game_mode == Catalog.GAME_CREATIVE, "mode read again, per world")
	app.return_to_worlds()
	# Autre monde : son propre mode.
	app.open_world(second.id)
	app.pause_game()
	app.pause_settings_button.pressed.emit()
	check(app.game_mode_buttons[Catalog.GAME_CREATIVE].button_pressed, "other world keeps its own mode")
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for menu in Settings.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.file_path(menu)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d game mode checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
