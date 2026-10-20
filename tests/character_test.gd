extends SceneTree
# 0.0.3.16 : Paramètres → Personnage (entre Contrôles et Attributs) : garçon, fille,
# homme, femme ; choix enregistré dans personnage.json et repris en partie.
const Settings = preload("res://scripts/user_settings.gd")
const CharacterPreview = preload("res://scripts/character_preview.gd")
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
	check(CharacterPreview.CHARACTERS.keys() == ["boy", "girl", "man", "woman"], "four characters: boy, girl, man, woman")
	check(CharacterPreview.CHARACTERS.boy.height < CharacterPreview.CHARACTERS.man.height and CharacterPreview.CHARACTERS.girl.height < CharacterPreview.CHARACTERS.woman.height, "teenagers drawn a bit smaller")
	check(Settings.new().file_path("character") == "user://personnage.json", "player file named after the menu")
	var fixture := "res://.godot/character-test-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	check(settings.values.character == "boy", "Garçon by default")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var item: Dictionary = app.catalog.create_world("Moi", "4")
	root.add_child(app)
	current_scene = app
	await process_frame
	var tabs: Array = app.settings_tabs.keys()
	check(tabs.find("character") == tabs.find("controls") + 1 and tabs.find("attributes") == tabs.find("character") + 1 and app.settings_tabs.character.text == "Personnage", "Personnage tab between Contrôles and Attributs")
	app.show_page("settings")
	app.settings_tabs.character.pressed.emit()
	await process_frame
	await process_frame
	check(app.settings_sections.character.visible and app.choice_buttons.character.size() == 4 and app.character_previews.size() == 4, "four cards with a preview and a button")
	check(app.choice_buttons.character.values().map(func(button): return button.text) == ["Garçon", "Fille", "Homme", "Femme"], "character names")
	check(app.character_previews.values().all(func(preview): return preview.size.y >= 100 and preview.size.x > 0), "previews have room to draw")
	check(app.choice_buttons.character.boy.button_pressed, "saved character shown selected")
	app.choice_buttons.character.woman.pressed.emit()
	check(settings.values.character == "woman" and app.choice_buttons.character.woman.button_pressed and not app.choice_buttons.character.boy.button_pressed, "choosing saves at once")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings.file_path("character")))
	check(saved is Dictionary and saved.character == "woman" and saved.size() == 1, "personnage.json holds only the character")
	check(Settings.new(fixture).values.character == "woman", "character reloads")
	# En partie : on est ce personnage.
	app.open_world(item.id)
	check(app.active_world.player.character == "woman", "player is the chosen character")
	app.pause_game()
	app.open_world_info()
	check(app.info_text.text.contains("Personnage : Femme"), "world info names the character")
	app.show_page("pause")
	app.pause_settings_button.pressed.emit()
	app.settings_tabs.character.pressed.emit()
	app.choice_buttons.character.girl.pressed.emit()
	check(app.active_world.player.character == "girl", "changing in pause applies at once")
	app.return_to_worlds()
	# Fichier invalide : défaut, sans plantage.
	var bad := fixture + ".bad.json"
	var file := FileAccess.open(Settings.new(bad).file_path("character"), FileAccess.WRITE)
	file.store_string('{"character": "dragon"}')
	file.close()
	var loaded := Settings.new(bad)
	check(loaded.values.character == "boy" and not loaded.load_notice.is_empty(), "unknown character falls back to Garçon")
	app.show_page("settings")
	app.setting_resets.character.pressed.emit()
	check(settings.values.character == "boy", "↻ restores Garçon")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "verification never captures pointer")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for base in [fixture, bad]:
		for menu in Settings.FILES:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(base.get_basename() + "-" + Settings.FILES[menu]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d character checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
