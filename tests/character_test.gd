extends SceneTree
# 0.0.3.16 : Paramètres → Personnage (entre Contrôles et Attributs) ; 0.0.3.22 : trois peaux
# (claire, brune, foncée) pour les humains, chats en bas ; choix dans personnage.json, repris en partie.
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
	check(CharacterPreview.CHARACTERS.keys() == ["boy", "girl", "man", "woman", "cat", "brioche"], "six characters, with the two plush cats")
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
	# 0.0.3.22 : quatre humains × trois peaux (claire, brune, foncée, de haut en bas), puis les deux chats.
	var cards: Dictionary = app.character_buttons
	var expected := []
	for skin in ["light", "brown", "dark"]:
		for id in ["boy", "girl", "man", "woman"]:
			expected.append(id + ":" + skin)
	expected.append_array(["cat", "brioche"])
	check(app.settings_sections.character.visible and cards.keys() == expected and app.character_previews.size() == 14, "fourteen cards: three skins, then the cats")
	check(cards.values().map(func(button): return button.text) == ["Garçon", "Fille", "Homme", "Femme", "Garçon", "Fille", "Homme", "Femme", "Garçon", "Fille", "Homme", "Femme", "Chat", "Brioche"], "character names")
	var row_y := func(card_id: String) -> float: return cards[card_id].get_global_rect().position.y
	check(row_y.call("boy:light") < row_y.call("boy:brown") and row_y.call("boy:brown") < row_y.call("boy:dark") and row_y.call("boy:dark") < row_y.call("cat") and is_equal_approx(row_y.call("cat"), row_y.call("brioche")), "light skin on top, brown in the middle, dark below, cats at the bottom")
	check(app.character_previews["girl:dark"].skin == "dark" and app.character_previews["girl:light"].skin == "light", "previews drawn with their skin")
	check(app.character_previews.values().all(func(preview): return preview.size.y >= 90 and preview.size.x > 0), "previews have room to draw")
	check(cards["boy:light"].button_pressed and cards.values().filter(func(button): return button.button_pressed).size() == 1, "saved character shown selected")
	cards["woman:brown"].pressed.emit()
	check(settings.values.character == "woman" and settings.values.skin == "brown" and cards["woman:brown"].button_pressed and not cards["boy:light"].button_pressed and not cards["woman:light"].button_pressed, "choosing saves character and skin at once")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings.file_path("character")))
	check(saved is Dictionary and saved.character == "woman" and saved.skin == "brown" and saved.size() == 2, "personnage.json holds the character and the skin")
	check(Settings.new(fixture).values.character == "woman" and Settings.new(fixture).values.skin == "brown", "character and skin reload")
	# En partie : on est ce personnage.
	app.open_world(item.id)
	check(app.active_world.player.character == "woman" and app.active_world.player.skin == "brown", "player is the chosen character")
	app.pause_game()
	app.open_world_info()
	check(app.info_text.text.contains("Personnage : Femme, peau brune"), "world info names the character and skin")
	app.show_page("pause")
	app.pause_settings_button.pressed.emit()
	app.settings_tabs.character.pressed.emit()
	cards["girl:dark"].pressed.emit()
	check(app.active_world.player.character == "girl" and app.active_world.player.skin == "dark", "changing in pause applies at once")
	cards["cat"].pressed.emit()
	check(app.active_world.player.character == "cat" and settings.values.character == "cat" and settings.values.skin == "dark", "the plush cat can be chosen, skin kept")
	check(cards["cat"].button_pressed and not cards["girl:dark"].button_pressed, "only the cat card selected")
	app.show_page("pause")
	app.open_world_info()
	check(app.info_text.text.contains("Personnage : Chat\n"), "world info names the cat, without skin")
	app.show_page("pause")
	app.pause_settings_button.pressed.emit()
	app.settings_tabs.character.pressed.emit()
	cards["brioche"].pressed.emit()
	check(app.active_world.player.character == "brioche" and settings.values.character == "brioche", "Brioche, the lying mochi cat, can be chosen")
	app.return_to_worlds()
	# Fichier invalide : défaut, sans plantage.
	var bad := fixture + ".bad.json"
	var file := FileAccess.open(Settings.new(bad).file_path("character"), FileAccess.WRITE)
	file.store_string('{"character": "dragon"}')
	file.close()
	var loaded := Settings.new(bad)
	check(loaded.values.character == "boy" and loaded.values.skin == "light" and not loaded.load_notice.is_empty(), "unknown character falls back to Garçon")
	# Ancien personnage.json (avant 0.0.3.22, sans peau) : lisible, ton d'avant gardé.
	var old := fixture + ".old.json"
	for case in [["girl", "brown"], ["man", "dark"], ["woman", "light"], ["cat", "light"]]:
		file = FileAccess.open(Settings.new(old).file_path("character"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"character": case[0]}))
		file.close()
		loaded = Settings.new(old)
		check(loaded.values.character == case[0] and loaded.values.skin == case[1] and loaded.load_notice.is_empty(), "old file with %s reads, skin %s" % case)
	app.show_page("settings")
	app.setting_resets.character.pressed.emit()
	check(settings.values.character == "boy" and settings.values.skin == "light" and cards["boy:light"].button_pressed, "↻ restores Garçon, peau claire")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "verification never captures pointer")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for base in [fixture, bad, fixture + ".old.json"]:
		for menu in Settings.FILES:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(base.get_basename() + "-" + Settings.FILES[menu]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d character checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
