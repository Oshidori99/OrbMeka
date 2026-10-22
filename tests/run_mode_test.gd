extends SceneTree
# 0.0.3.25 : Contrôles → Courir : Maintenir, Maintenir conditionnel ou Basculer.
# Maintenir conditionnel : un appui lance la course ; s'arrêter, sauter, se baisser,
# la pause, un menu ou la perte de focus l'arrêtent ; il faut alors réappuyer sur R.
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

# Une image de jeu : touche R enfoncée ou non, appui à cette image, marche, saut.
func frame(player: CharacterBody3D, held: bool, pressed: bool = false, moving: bool = true, jumped: bool = false) -> bool:
	player.update_run(true, held, pressed, moving, jumped)
	return player.running

# Lance la course en mode conditionnel : appui sur R en marchant, puis touche relâchée.
func start_latch(player: CharacterBody3D) -> bool:
	frame(player, true, true)
	return frame(player, false)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var spec: Dictionary = Controls.OPTIONS.run_mode
	check(spec.options.keys() == ["hold", "latch", "toggle"] and spec.options.values() == ["Maintenir", "Maintenir conditionnel", "Basculer"], "three modes in order: Maintenir, Maintenir conditionnel, Basculer")
	check(spec.default == "hold" and Settings.new("res://.godot/none-%d.json" % Time.get_ticks_usec()).control_options.run_mode == "hold", "Maintenir by default (as in 0.0.3.24)")
	var fixture := "res://.godot/run-mode-%d.json" % Time.get_ticks_usec()
	# Ancien controles.json (0.0.3.24, sans run_mode) : lisible, mode par défaut.
	var old := FileAccess.open(Settings.new(fixture + ".old").controls_path(), FileAccess.WRITE)
	old.store_string('{"crouch_mode": "toggle", "sprint": {"key": %d}}' % KEY_T)
	old.close()
	var legacy := Settings.new(fixture + ".old")
	check(legacy.control_options.run_mode == "hold" and legacy.control_options.crouch_mode == "toggle" and legacy.controls.sprint == {"key": KEY_T} and legacy.load_notice.is_empty(), "old controles.json still readable, Maintenir")
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var item: Dictionary = app.catalog.create_world("Courir", "9")
	root.add_child(app)
	current_scene = app
	await process_frame
	app.show_page("settings")
	app.settings_tabs.controls.pressed.emit()
	var buttons: Dictionary = app.control_option_buttons.run_mode
	check(app.settings_sections.controls.is_ancestor_of(buttons.latch) and buttons.hold.text == "Maintenir" and buttons.latch.text == "Maintenir conditionnel" and buttons.toggle.text == "Basculer" and buttons.hold.button_pressed, "Courir category in Contrôles, Maintenir selected")
	check(app.control_option_buttons.crouch_mode.hold.get_parent() != buttons.hold.get_parent(), "Courir has its own row, apart from Se baisser")
	buttons.latch.pressed.emit()
	check(settings.control_options.run_mode == "latch" and buttons.latch.button_pressed and not buttons.hold.button_pressed, "Maintenir conditionnel saved at once")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings.controls_path()))
	check(saved.run_mode == "latch" and saved.has("sprint") and saved.crouch_mode == "hold", "saved in controles.json with the keys")
	check(Settings.new(fixture).control_options.run_mode == "latch", "mode reloads")
	# En partie : Maintenir conditionnel.
	app.open_world(item.id)
	var player: CharacterBody3D = app.active_world.player
	check(player.run_mode == "latch", "game uses Maintenir conditionnel")
	check(start_latch(player) and frame(player, false), "latch: one press keeps running after release")
	frame(player, false, false, false)
	check(not frame(player, false), "latch: stopping walking ends the run")
	check(not frame(player, true) and not frame(player, false), "latch: R still held is not a new press")
	start_latch(player)
	check(not frame(player, false, false, true, true) and not frame(player, false), "latch: jumping ends the run")
	start_latch(player)
	player.crouching = true
	check(not frame(player, false), "latch: crouching ends the run")
	player.crouching = false
	check(not frame(player, false) and start_latch(player), "latch: standing up does not restart, pressing R again does")
	player.update_run(false, false, false, true, false)
	check(not player.running and not frame(player, false), "latch: inactive game (menu, pause) ends the run")
	start_latch(player)
	app.pause_game()
	app.resume_game()
	check(not frame(player, false), "latch: pause / Échap ends the run")
	start_latch(player)
	player.release_controls()
	player.resume_controls()
	check(not frame(player, false), "latch: menu opening (released controls) ends the run")
	start_latch(player)
	player._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	player.resume_controls()
	check(not frame(player, false), "latch: losing focus ends the run")
	# R enfoncé à l'arrêt : la course part au premier pas, puis continue touche relâchée.
	frame(player, true, true, false)
	check(frame(player, true, false, true) and frame(player, false), "latch: R pressed while still starts with the first step")
	# Basculer.
	app.pause_game()
	app.pause_settings_button.pressed.emit()
	app.settings_tabs.controls.pressed.emit()
	buttons.toggle.pressed.emit()
	check(player.run_mode == "toggle", "Basculer applied in game")
	frame(player, true, true)
	check(frame(player, false) and frame(player, false, false, false) and frame(player, false, false, true, true), "toggle: one press keeps running, even stopped or jumping")
	frame(player, true, true)
	check(not frame(player, false), "toggle: second press walks")
	# Maintenir.
	app.control_resets.run_mode.pressed.emit()
	check(settings.control_options.run_mode == "hold" and player.run_mode == "hold", "↻ back to Maintenir, applied in game")
	check(frame(player, true, true) and frame(player, true), "hold: running while held")
	check(not frame(player, false), "hold: walking when released")
	buttons.latch.pressed.emit()
	app.controls_reset_all_button.pressed.emit()
	check(settings.control_options.run_mode == "hold", "↻ Tout réinitialiser restores Maintenir")
	app.return_to_worlds()
	var bad := fixture + ".bad.json"
	var file := FileAccess.open(Settings.new(bad).controls_path(), FileAccess.WRITE)
	file.store_string('{"run_mode": "sometimes"}')
	file.close()
	var loaded := Settings.new(bad)
	check(loaded.control_options.run_mode == "hold" and not loaded.load_notice.is_empty(), "unknown mode falls back to Maintenir")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for path in [settings.controls_path(), legacy.controls_path(), Settings.new(bad).controls_path(), fixture + ".worlds"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d run mode checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
