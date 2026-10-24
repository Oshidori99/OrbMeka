extends SceneTree
# 0.0.3.16 : Paramètres → Personnage (entre Contrôles et Attributs) ; 0.0.3.22 : trois peaux
# (claire, brune, foncée) pour les humains, animaux en bas ; choix dans personnage.json, repris en partie.
# 0.0.3.23 : enfants de 9 et 14 ans (à la place de « boy » et « girl ») et quatre animaux, en 3D.
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
	check(CharacterPreview.CHARACTERS.keys() == ["boy9", "girl9", "boy14", "girl14", "man", "woman", "cat", "brioche", "squirrel", "fox", "turtle", "rabbit"], "twelve characters: four children, two adults, six animals")
	check(CharacterPreview.CHARACTERS.keys().all(func(id): return Settings.CHOICES.character.options[id] == CharacterPreview.CHARACTERS[id].name), "same names in the menu and the save file")
	check(CharacterPreview.MODELS.keys() == ["boy9", "girl9", "boy14", "girl14", "squirrel", "fox", "turtle", "rabbit"], "new characters modelled in Blender")
	var tall := func(id: String) -> float: return CharacterPreview.CHARACTERS[id].height
	check(tall.call("boy9") < tall.call("boy14") and tall.call("boy14") < tall.call("man") and tall.call("girl9") < tall.call("girl14") and tall.call("girl14") < tall.call("woman"), "9-year-olds smaller than 14-year-olds, smaller than adults")
	check(Settings.new().file_path("character") == "user://parametres/personnage.json", "player file named after the menu")
	var fixture := "res://.godot/character-test-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	check(settings.values.character == "boy14", "Garçon 14 ans by default")
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
	# Six humains × trois peaux (claire, brune, foncée, de haut en bas), puis les six animaux.
	var cards: Dictionary = app.character_buttons
	var expected := []
	for skin in ["light", "brown", "dark"]:
		for id in ["boy9", "girl9", "boy14", "girl14", "man", "woman"]:
			expected.append(id + ":" + skin)
	expected.append_array(["cat", "brioche", "squirrel", "fox", "turtle", "rabbit"])
	check(app.settings_sections.character.visible and cards.keys() == expected and app.character_previews.size() == 24, "24 cards: three skins, then the animals")
	var humans := ["Garçon 9 ans", "Fille 9 ans", "Garçon 14 ans", "Fille 14 ans", "Homme", "Femme"]
	check(cards.values().map(func(button): return button.text) == humans + humans + humans + ["Chat", "Brioche", "Écureuil", "Renard", "Tortue", "Lapin bleu"], "character names")
	var row_y := func(card_id: String) -> float: return cards[card_id].get_global_rect().position.y
	check(row_y.call("boy9:light") < row_y.call("boy9:brown") and row_y.call("boy9:brown") < row_y.call("woman:dark") and row_y.call("woman:dark") < row_y.call("cat") and is_equal_approx(row_y.call("cat"), row_y.call("rabbit")), "light skin on top, brown in the middle, dark below, animals at the bottom")
	check(app.character_previews["girl9:dark"].skin == "dark" and app.character_previews["girl9:light"].skin == "light", "previews drawn with their skin")
	check(app.character_previews["girl9:dark"].viewport != null and app.character_previews["rabbit"].viewport != null and app.character_previews["man:light"].viewport == null and app.character_previews["cat"].viewport == null, "Blender characters shown in 3D, others still drawn")
	var skin_of := func(preview: Control) -> Color:
		for node in preview.model.find_children("*", "MeshInstance3D", true, false):
			for surface in range(node.mesh.get_surface_count()):
				if node.get_surface_override_material(surface):
					return node.get_surface_override_material(surface).albedo_color
		return Color.TRANSPARENT
	check(skin_of.call(app.character_previews["boy14:dark"]) == CharacterPreview.tone_color("dark") and skin_of.call(app.character_previews["boy14:light"]) == CharacterPreview.tone_color("light") and skin_of.call(app.character_previews["fox"]) == Color.TRANSPARENT, "3D children take the chosen skin, animals keep their fur")
	check(app.character_previews.values().all(func(preview): return preview.size.y >= 90 and preview.size.x > 0), "previews have room to draw")
	check(cards["boy14:light"].button_pressed and cards.values().filter(func(button): return button.button_pressed).size() == 1, "saved character shown selected")
	cards["woman:brown"].pressed.emit()
	check(settings.values.character == "woman" and settings.values.skin == "brown" and cards["woman:brown"].button_pressed and not cards["boy14:light"].button_pressed and not cards["woman:light"].button_pressed, "choosing saves character and skin at once")
	# 0.0.3.27 : un clic sur l'aperçu choisit aussi le personnage ; le clavier suit.
	var preview: Control = app.character_previews["girl9:dark"]
	var scroll := preview.get_parent()
	while scroll != null and not scroll is ScrollContainer:
		scroll = scroll.get_parent()
	if scroll != null:
		scroll.ensure_control_visible(preview)
	await process_frame
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = preview.get_global_rect().get_center()
	click.global_position = click.position
	root.push_input(click)
	var release := click.duplicate()
	release.pressed = false
	root.push_input(release)
	await process_frame
	check(settings.values.character == "girl9" and settings.values.skin == "dark" and cards["girl9:dark"].button_pressed and not cards["woman:brown"].button_pressed, "clicking the preview selects the character")
	check(app.get_viewport().gui_get_focus_owner() == cards["girl9:dark"], "the clicked card takes the keyboard focus")
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.physical_keycode = KEY_RIGHT
	key.pressed = true
	root.push_input(key)
	await process_frame
	var next: Control = app.get_viewport().gui_get_focus_owner()
	check(next is Button and cards.values().has(next) and next != cards["girl9:dark"], "arrow keys move between cards")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter)
	enter = enter.duplicate()
	enter.pressed = false
	root.push_input(enter)
	await process_frame
	check(next.button_pressed and not cards["girl9:dark"].button_pressed, "Enter selects the focused card")
	cards["woman:brown"].pressed.emit()
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
	cards["girl14:dark"].pressed.emit()
	check(app.active_world.player.character == "girl14" and app.active_world.player.skin == "dark", "changing in pause applies at once")
	cards["cat"].pressed.emit()
	check(app.active_world.player.character == "cat" and settings.values.character == "cat" and settings.values.skin == "dark", "the plush cat can be chosen, skin kept")
	check(cards["cat"].button_pressed and not cards["girl14:dark"].button_pressed, "only the cat card selected")
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
	check(loaded.values.character == "boy14" and loaded.values.skin == "light" and not loaded.load_notice.is_empty(), "unknown character falls back to Garçon 14 ans")
	# Ancien personnage.json (avant 0.0.3.22, sans peau) : lisible, ton d'avant gardé.
	var old := fixture + ".old.json"
	# Avant 0.0.3.23 : « boy » et « girl » (≈ 14 ans) deviennent les enfants de 14 ans.
	for case in [["boy", "light", "boy14"], ["girl", "brown", "girl14"], ["man", "dark", "man"], ["woman", "light", "woman"], ["cat", "light", "cat"]]:
		file = FileAccess.open(Settings.new(old).file_path("character"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"character": case[0]}))
		file.close()
		loaded = Settings.new(old)
		check(loaded.values.character == case[2] and loaded.values.skin == case[1] and loaded.load_notice.is_empty(), "old file with %s reads, skin %s, now %s" % case)
	file = FileAccess.open(Settings.new(old).file_path("character"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"character": "girl", "skin": "dark"}))
	file.close()
	loaded = Settings.new(old)
	check(loaded.values.character == "girl14" and loaded.values.skin == "dark" and loaded.load_notice.is_empty(), "0.0.3.22 file with girl and a skin reads as Fille 14 ans, same skin")
	app.show_page("settings")
	app.setting_resets.character.pressed.emit()
	check(settings.values.character == "boy14" and settings.values.skin == "light" and cards["boy14:light"].button_pressed, "↻ restores Garçon 14 ans, peau claire")
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
