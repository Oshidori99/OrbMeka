extends SceneTree
# 0.0.3.18 : Contrôles → Se baisser : Maintenir ou Basculer ; défaut = touche marquée Y.
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

func _run() -> void:
	root.size = Vector2i(1280, 720)
	check(Controls.OPTIONS.crouch_mode.options.keys() == ["hold", "toggle"] and Controls.OPTIONS.crouch_mode.default == "hold", "Maintenir by default, or Basculer")
	check(Controls.ACTIONS.crouch.get("by_letter", false) and Controls.default_for("crouch") == Controls.single({"key": KEY_Y}), "crouch default follows the letter Y")
	var fixture := "res://.godot/crouch-mode-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var item: Dictionary = app.catalog.create_world("Basculer", "9")
	root.add_child(app)
	current_scene = app
	await process_frame
	app.show_page("settings")
	app.settings_tabs.controls.pressed.emit()
	var buttons: Dictionary = app.control_option_buttons.crouch_mode
	check(app.settings_sections.controls.is_ancestor_of(buttons.hold) and buttons.hold.text == "Maintenir" and buttons.toggle.text == "Basculer" and buttons.hold.button_pressed, "Se baisser category in Contrôles, Maintenir selected")
	buttons.toggle.pressed.emit()
	check(settings.control_options.crouch_mode == "toggle" and buttons.toggle.button_pressed and not buttons.hold.button_pressed, "Basculer saved at once")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings.controls_path()))
	check(saved.crouch_mode == "toggle" and saved.has("jump"), "saved in controles.json with the keys")
	check(Settings.new(fixture).control_options.crouch_mode == "toggle", "mode reloads")
	# En partie.
	app.open_world(item.id)
	var player: CharacterBody3D = app.active_world.player
	check(player.crouch_toggle, "game uses Basculer")
	player.update_crouch(true, true, true)
	player.update_crouch(true, false, false)
	check(player.crouching, "Basculer: one press keeps crouching after release")
	player.update_crouch(true, true, true)
	player.update_crouch(true, false, false)
	check(not player.crouching, "Basculer: second press stands up")
	app.pause_game()
	app.pause_settings_button.pressed.emit()
	app.settings_tabs.controls.pressed.emit()
	app.control_resets.crouch_mode.pressed.emit()
	check(settings.control_options.crouch_mode == "hold" and not player.crouch_toggle, "↻ back to Maintenir, applied in game")
	player.update_crouch(true, true, true)
	check(player.crouching, "Maintenir: crouching while held")
	player.update_crouch(true, false, false)
	check(not player.crouching, "Maintenir: standing when released")
	app.control_option_buttons.crouch_mode.toggle.pressed.emit()
	app.controls_reset_all_button.pressed.emit()
	check(settings.control_options.crouch_mode == "hold", "↻ Tout réinitialiser restores Maintenir")
	app.return_to_worlds()
	var bad := fixture + ".bad.json"
	var file := FileAccess.open(Settings.new(bad).controls_path(), FileAccess.WRITE)
	file.store_string('{"crouch_mode": "sometimes"}')
	file.close()
	var loaded := Settings.new(bad)
	check(loaded.control_options.crouch_mode == "hold" and not loaded.load_notice.is_empty(), "unknown mode falls back to Maintenir")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for path in [settings.controls_path(), Settings.new(bad).controls_path(), fixture + ".worlds"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d crouch mode checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
