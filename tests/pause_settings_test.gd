extends SceneTree
# 0.0.3.9 : Paramètres dans la pause (2e bouton), réglages appliqués en direct,
# Attributs proposant le mode développeur dans un monde par défaut.
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

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/pause-settings-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = Catalog.new(fixture + ".worlds")
	var normal: Dictionary = app.catalog.create_world("Normal", "3")
	var dev: Dictionary = app.catalog.create_world("Dev", "4", Catalog.MODE_DEVELOPER)
	root.add_child(app)
	current_scene = app
	await process_frame
	# Hors partie : Attributs normal, Retour vers l'accueil.
	app.show_page("settings")
	check(not app.attributes_gate.visible and app.attributes_scroll.visible, "home settings show attributes directly")
	app.settings_back_button.pressed.emit()
	check(app.page == "home", "home settings return to home")
	# Pause d'un monde par défaut.
	app.open_world(normal.id)
	app.pause_game()
	var buttons: Array = app.pages.pause.find_children("*", "Button", true, false).map(func(button): return button.text)
	check(buttons.slice(0, 2) == ["Reprendre", "Paramètres"], "Paramètres is the second pause button, under Reprendre")
	app.pause_settings_button.pressed.emit()
	check(app.page == "settings" and paused and is_instance_valid(app.active_world), "pause opens the settings, game stays paused")
	check(app.settings_tabs.attributes.visible, "Attributs tab stays in the left column")
	app.settings_tabs.attributes.pressed.emit()
	check(app.attributes_gate.visible and not app.attributes_scroll.visible and app.attributes_gate_button.visible, "default world: Attributs proposes developer mode instead of fields")
	check(app.attributes_gate_text.text.contains("mode développeur"), "gate explains developer mode is needed")
	app.attributes_gate_button.pressed.emit()
	check(app.attributes_gate_text.text.contains("irréversible") and app.attributes_gate_confirm.visible and app.attributes_gate_cancel.has_focus(), "clear irreversible warning, Annuler focused")
	app.attributes_gate_cancel.pressed.emit()
	check(app.catalog.find_world(normal.id).mode == Catalog.MODE_DEFAULT and app.attributes_gate_button.visible, "Annuler keeps the default mode")
	# Réglages appliqués en direct, attributs toujours par défaut dans ce monde.
	app.setting_sliders.fov.value = 95
	app.setting_fields.jump_height.text = "5"
	app.setting_fields.jump_height.text_changed.emit("5")
	var player: CharacterBody3D = app.active_world.player
	check(player.camera.fov == 95, "FOV changed in pause applies at once")
	check(player.jump_height == Settings.SPECS.jump_height.default, "default world still ignores attributes")
	app.setting_fields.text_px.text = "24"
	app.setting_fields.text_px.text_changed.emit("24")
	# 0.0.3.11 : taille enregistrée tout de suite, appliquée avec le bouton (ou en quittant).
	check(settings.values.text_px == 24 and app.active_world.selected_block_label.get_theme_font_size("font_size") != 24 and not app.layout_apply_button.disabled, "text size saved, applied later")
	app.layout_apply_button.pressed.emit()
	check(app.active_world.selected_block_label.get_theme_font_size("font_size") == 24 and app.layout_apply_button.disabled, "Appliquer la taille des menus applies to game texts")
	# Passage au mode développeur depuis la pause.
	app.attributes_gate_button.pressed.emit()
	app.attributes_gate_confirm.pressed.emit()
	check(app.catalog.find_world(normal.id).mode == Catalog.MODE_DEVELOPER and app.active_world.developer_mode, "confirm switches this world to developer mode")
	check(not app.attributes_gate.visible and app.attributes_scroll.visible, "attributes become editable")
	check(player.jump_height == 5, "saved attributes apply at once after the switch")
	check(Catalog.new(fixture + ".worlds").find_world(normal.id).mode == Catalog.MODE_DEVELOPER, "switch is saved with the world")
	# Retour, Échap, F1.
	app.settings_back_button.pressed.emit()
	check(app.page == "pause" and paused, "Retour goes back to the pause")
	app.open_world_info()
	check(app.info_text.text.contains("Mode développeur"), "F3 info shows the new mode")
	app.show_page("pause")
	app.pause_settings_button.pressed.emit()
	key(KEY_ESCAPE)
	check(app.page == "pause", "Escape from settings goes back to the pause")
	app.pause_settings_button.pressed.emit()
	key(KEY_F1)
	check(app.page == "worlds" and not is_instance_valid(app.active_world) and not paused, "F1 from settings returns to the worlds")
	# Monde développeur : champs directs.
	app.open_world(dev.id)
	app.pause_game()
	app.pause_settings_button.pressed.emit()
	app.settings_tabs.attributes.pressed.emit()
	check(not app.attributes_gate.visible and app.attributes_scroll.visible, "developer world shows attribute fields directly")
	app.setting_fields.walk_forward.text = "9"
	app.setting_fields.walk_forward.text_changed.emit("9")
	check(app.active_world.player.walk_forward == 9, "developer world: attributes apply at once in pause")
	app.settings_back_button.pressed.emit()
	app.resume_game()
	check(app.page == "playing" and not paused, "resume after settings")
	app.return_to_worlds()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "verification never captures pointer")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for menu in Settings.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.file_path(menu)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d pause settings checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
