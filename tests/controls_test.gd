extends SceneTree
# 0.0.3.12 : onglet Contrôles (entre Vidéo et Attributs), touches et boutons de souris
# modifiables (clic gauche, droit, molette), Échap = aucune, ↻, fichier controles.json.
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

func press_key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event)

func press_mouse(button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = Vector2(5, 5)
	root.push_input(event)

func has_key(action: String, code: int) -> bool:
	return InputMap.action_get_events(action).any(func(event): return event is InputEventKey and event.physical_keycode == code)

func has_mouse(action: String, button: int) -> bool:
	return InputMap.action_get_events(action).any(func(event): return event is InputEventMouseButton and event.button_index == button)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/controls-test-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	check(Settings.new().controls_path() == "user://parametres/controles.json", "player controls file is named after the menu")
	check(settings.controls == Controls.defaults(), "default controls")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var item: Dictionary = app.catalog.create_world("Touches", "6")
	root.add_child(app)
	current_scene = app
	await process_frame
	check(app.settings_tabs.keys() == ["general", "video", "controls", "character", "attributes", "licences"], "Contrôles tab after Vidéo (Licences last, 0.0.4.17)")
	check(has_key("move_forward", KEY_W) and not has_key("move_forward", KEY_UP) and has_key("move_left", KEY_LEFT) and has_mouse("break_block", MOUSE_BUTTON_LEFT) and has_mouse("place_block", MOUSE_BUTTON_RIGHT), "defaults applied to the game")
	check(has_mouse("block_previous", MOUSE_BUTTON_WHEEL_UP) and has_mouse("block_next", MOUSE_BUTTON_WHEEL_DOWN), "mouse wheel changes the block by default")
	app.show_page("settings")
	app.settings_tabs.controls.pressed.emit()
	check(app.settings_sections.controls.visible and app.control_buttons.size() == Controls.ACTIONS.size(), "one key button per action")
	check(app.control_buttons.break_block.text == "Clic gauche" and app.control_buttons.place_block.text == "Clic droit" and app.control_buttons.block_next.text == "Molette bas", "mouse buttons shown by name")
	# Nouvelle touche.
	app.control_buttons.move_forward.pressed.emit()
	check(app.capturing_action == "move_forward" and app.control_buttons.move_forward.text.begins_with("Appuyez"), "button waits for a key")
	press_key(KEY_K)
	check(app.capturing_action == "" and settings.controls.move_forward == Controls.normalize({"key": KEY_K}) and has_key("move_forward", KEY_K) and not has_key("move_forward", KEY_W) and not has_key("move_forward", KEY_UP), "new key applied at once, no arrow (0.0.4.3)")
	check(app.page == "settings", "the pressed key does nothing else")
	# Échap : aucune touche ; le menu reste ouvert.
	app.control_buttons.jump.pressed.emit()
	press_key(KEY_ESCAPE)
	check(app.page == "settings" and settings.controls.jump == Controls.normalize({}) and InputMap.action_get_events("jump").is_empty() and app.control_buttons.jump.text == "Aucune", "Escape leaves the action without any key")
	# 0.0.5.10 : F1 n'est plus réservée (seul Échap l'est) : elle peut être choisie.
	app.control_buttons.jump.pressed.emit()
	press_key(KEY_F1)
	check(settings.controls.jump == Controls.normalize({"key": KEY_F1}), "F1 can be chosen (0.0.5.10)")
	app.control_buttons.jump.pressed.emit()
	# Boutons de souris : clic molette, molette, clic gauche.
	press_mouse(MOUSE_BUTTON_MIDDLE)
	check(settings.controls.jump == Controls.normalize({"mouse": MOUSE_BUTTON_MIDDLE}) and has_mouse("jump", MOUSE_BUTTON_MIDDLE), "middle click can be chosen")
	app.control_buttons.place_block.pressed.emit()
	press_mouse(MOUSE_BUTTON_WHEEL_UP)
	check(settings.controls.place_block == Controls.normalize({"mouse": MOUSE_BUTTON_WHEEL_UP}) and settings.controls.block_previous == Controls.normalize({}), "wheel can be chosen; taken from its previous action")
	check(app.settings_message.text.contains("retirée de Bloc précédent"), "message says where the key was taken from")
	# ↻ par action et pour tout.
	app.control_resets.block_previous.pressed.emit()
	check(settings.controls.block_previous == Controls.normalize({"mouse": MOUSE_BUTTON_WHEEL_UP}) and settings.controls.place_block == Controls.normalize({}), "↻ restores the default and frees it elsewhere")
	app.controls_reset_all_button.pressed.emit()
	check(settings.controls == Controls.defaults() and has_key("move_forward", KEY_W) and not InputMap.action_get_events("jump").is_empty(), "↻ Tout réinitialiser restores every default")
	# Fichier controles.json : enregistré, relu, jamais dans les autres fichiers.
	app.control_buttons.move_left.pressed.emit()
	press_key(KEY_J)
	var reloaded := Settings.new(fixture)
	check(reloaded.controls.move_left == Controls.normalize({"key": KEY_J}) and FileAccess.file_exists(settings.controls_path()), "controls saved in controles.json and reloaded")
	var damaged := settings.controls_path() + ".bad.json"
	var file := FileAccess.open(settings.controls_path(), FileAccess.WRITE)
	file.store_string('{"jump": {"key": 4194305}, "move_back": "x"}')
	file.close()
	var bad := Settings.new(fixture)
	check(not bad.load_notice.is_empty() and bad.controls.jump == Controls.default_for("jump") and bad.controls.move_back == Controls.default_for("move_back"), "invalid or reserved saved keys fall back to defaults")
	# Toujours disponible en pause ; un monde lancé garde les touches choisies.
	app.open_world(item.id)
	check(has_key("move_left", KEY_J), "world keeps the chosen keys")
	app.pause_game()
	app.pause_settings_button.pressed.emit()
	app.settings_tabs.controls.pressed.emit()
	check(app.settings_sections.controls.visible, "Contrôles also in the pause settings")
	app.control_buttons.break_block.pressed.emit()
	press_key(KEY_E)
	check(has_key("break_block", KEY_E) and app.page == "settings", "keys can be changed in game")
	app.controls_reset_all_button.pressed.emit()
	app.return_to_worlds()
	# Minimum et maximum toujours affichés, même en synthèse « − ».
	settings.values.text_detail = "minus"
	app._refresh_details()
	var label: RichTextLabel = app.setting_fields.mouse_sensitivity.get_parent().get_child(0)
	check(label.text.contains("10") and label.text.contains("300"), "min and max shown even at −")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "verification never captures pointer")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for path in [settings.controls_path(), damaged, fixture + ".worlds"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d controls checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
