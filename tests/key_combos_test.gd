extends SceneTree
# 0.0.3.27 : deux touches par action. La même deux fois = double appui (Controls.DOUBLE_PRESS_MS),
# deux différentes = en même temps ; 2e touche choisie et retirée dans Contrôles ; anciens
# controles.json (une touche) toujours lus ; même combinaison sur deux actions : avertir.
const Settings = preload("res://scripts/user_settings.gd")
const Controls = preload("res://scripts/controls.gd")
const KeyCombos = preload("res://scripts/key_combos.gd")
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

func key(code: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event

func push_key(code: int, pressed := true) -> void:
	root.push_input(key(code, pressed))

func _run() -> void:
	root.size = Vector2i(1280, 720)
	# Liaisons et noms.
	var double := {"key": KEY_W, "second": {"key": KEY_W}}
	var together := {"key": KEY_SHIFT, "second": {"key": KEY_Z}}
	check(Controls.kind({"key": KEY_W}) == "single" and Controls.kind(double) == "double" and Controls.kind(together) == "together" and Controls.kind({}) == "none", "one key, same key twice, two keys")
	check(Controls.label(double) == "W deux fois" and Controls.label(together) == "Shift + Z", "names say double press or together")
	check(Controls.same(together, {"key": KEY_Z, "second": {"key": KEY_SHIFT}}) and not Controls.same(together, {"key": KEY_Z}), "Maj + Z is the same as Z + Maj")
	check(Controls.is_valid(together) and Controls.is_valid({"key": KEY_E, "second": {"mouse": MOUSE_BUTTON_LEFT}}) and not Controls.is_valid({"key": KEY_E, "second": {"key": KEY_ESCAPE}}) and not Controls.is_valid({"key": KEY_E, "second": "x"}), "second key checked like the first")
	# Double appui.
	var combos := KeyCombos.new()
	combos.set_bindings({"sprint": double, "crouch": together, "jump": {"key": KEY_SPACE}})
	check(combos.feed(key(KEY_W, true), 1000).is_empty() and combos.feed(key(KEY_W, false), 1080).is_empty(), "one press of the double key does nothing")
	check(combos.feed(key(KEY_W, true), 1000 + Controls.DOUBLE_PRESS_MS) == [["sprint", true]], "second press within the delay starts the action")
	check(combos.feed(key(KEY_W, false), 1500) == [["sprint", false]], "releasing it stops the action")
	combos.feed(key(KEY_W, true), 3000)
	combos.feed(key(KEY_W, false), 3050)
	check(combos.feed(key(KEY_W, true), 3001 + Controls.DOUBLE_PRESS_MS).is_empty(), "too slow: not a double press")
	combos.feed(key(KEY_W, false), 3400)
	var echo := key(KEY_W, true)
	echo.echo = true
	check(combos.feed(echo, 3420).is_empty(), "held key repeats are ignored")
	# En même temps, dans les deux ordres.
	check(combos.feed(key(KEY_SHIFT, true), 5000).is_empty() and combos.feed(key(KEY_Z, true), 9000) == [["crouch", true]], "Maj then Z starts the action")
	check(combos.feed(key(KEY_SHIFT, false), 9100) == [["crouch", false]], "releasing either key stops it")
	combos.feed(key(KEY_Z, false), 9200)
	combos.feed(key(KEY_Z, true), 9300)
	check(combos.feed(key(KEY_SHIFT, true), 9400) == [["crouch", true]], "Z then Maj works too")
	check(combos.release_all() == [["crouch", false]] and combos.feed(key(KEY_Z, false), 9500).is_empty(), "release all (pause) stops the action once")
	check(combos.feed(key(KEY_SPACE, true), 9600).is_empty(), "one-key actions stay with the game input")
	# Anciens fichiers (une touche par action) toujours lus ; nouveau format enregistré et relu.
	var fixture := "res://.godot/key-combos-test-%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(Settings.new(fixture).controls_path(), FileAccess.WRITE)
	file.store_string('{"jump": {"key": %d}, "break_block": {"mouse": 1}, "crouch_mode": "toggle"}' % KEY_G)
	file.close()
	var old := Settings.new(fixture)
	check(old.load_notice.is_empty() and old.controls.jump == {"key": KEY_G} and old.controls.break_block == {"mouse": MOUSE_BUTTON_LEFT} and old.control_options.crouch_mode == "toggle", "old controles.json still read")
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var item: Dictionary = app.catalog.create_world("Deux touches", "3")
	root.add_child(app)
	current_scene = app
	await process_frame
	app.show_page("settings")
	app.settings_tabs.controls.pressed.emit()
	check(app.control_second_buttons.size() == Controls.ACTIONS.size() and app.control_second_buttons.jump.text == "2e touche…" and app.control_second_clears.jump.disabled, "a second-key button and ✕ per action")
	# Double appui choisi : même touche.
	app.control_second_buttons.sprint.pressed.emit()
	check(app.capturing_action == "sprint" and app.capturing_second, "second button waits for a key")
	push_key(KEY_R)
	check(settings.controls.sprint == {"key": KEY_R, "second": {"key": KEY_R}} and app.control_labels.sprint.text.contains("double appui") and not app.control_second_clears.sprint.disabled, "same key twice: double press shown")
	check(not InputMap.action_get_events("sprint").any(func(event): return event is InputEventKey and event.physical_keycode == KEY_R), "a single R no longer runs")
	# En même temps : Maj + Z sur Avancer (plus de flèche depuis 0.0.4.3).
	app.control_second_buttons.move_forward.pressed.emit()
	push_key(KEY_SHIFT)
	check(Controls.kind(settings.controls.move_forward) == "together" and app.control_labels.move_forward.text.contains("en même temps") and app.settings_message.text.contains("W + Shift"), "different key: together")
	check(InputMap.action_get_events("move_forward").is_empty(), "nothing left in the game input")
	var reloaded := Settings.new(fixture)
	check(reloaded.controls.move_forward == {"key": KEY_W, "second": {"key": KEY_SHIFT}} and reloaded.controls.sprint == settings.controls.sprint and reloaded.load_notice.is_empty(), "two keys saved in controles.json and reloaded")
	# Changer la première touche garde la deuxième.
	app.control_buttons.sprint.pressed.emit()
	push_key(KEY_T)
	check(settings.controls.sprint == {"key": KEY_T, "second": {"key": KEY_R}}, "new first key keeps the second")
	# Conflits : même combinaison sur deux actions (retirée de l'autre) ; touche seule incluse (avertir).
	app.control_buttons.jump.pressed.emit()
	push_key(KEY_SHIFT)
	app.control_second_buttons.jump.pressed.emit()
	push_key(KEY_W)
	check(settings.controls.jump == {"key": KEY_SHIFT, "second": {"key": KEY_W}} and settings.controls.move_forward == {} and app.settings_message.text.contains("retirée de Avancer"), "same combination on two actions: warned and taken away")
	app.control_buttons.move_forward.pressed.emit()
	push_key(KEY_W)
	check(app.settings_message.text.contains("Attention") and app.settings_message.text.contains("Sauter"), "a single key inside a combination is warned about")
	# Retirer la deuxième touche : ✕ ou Échap.
	app.control_second_clears.jump.pressed.emit()
	check(settings.controls.jump == {"key": KEY_SHIFT} and app.control_second_clears.jump.disabled and app.control_labels.jump.text == "Sauter", "✕ removes the second key")
	app.control_second_buttons.sprint.pressed.emit()
	push_key(KEY_ESCAPE)
	check(settings.controls.sprint == {"key": KEY_T} and app.page == "settings", "Escape removes the second key")
	app.control_buttons.place_block.pressed.emit()
	push_key(KEY_ESCAPE)
	check(settings.controls.place_block == {} and app.control_second_buttons.place_block.disabled, "no key: no second key either")
	# Dans le jeu : le double appui et Maj + Z arrivent comme les autres touches.
	app.controls_reset_all_button.pressed.emit()
	settings.set_control("sprint", double)
	settings.set_control("crouch", together)
	app._apply_controls()
	app.open_world(item.id)
	push_key(KEY_W)
	push_key(KEY_W, false)
	push_key(KEY_W)
	Input.flush_buffered_events()
	check(Input.is_action_pressed("sprint"), "double press reaches the game")
	push_key(KEY_W, false)
	Input.flush_buffered_events()
	check(not Input.is_action_pressed("sprint"), "released with the key")
	push_key(KEY_SHIFT)
	push_key(KEY_Z)
	Input.flush_buffered_events()
	check(Input.is_action_pressed("crouch"), "Maj + Z reaches the game")
	app.pause_game()
	Input.flush_buffered_events()
	check(not Input.is_action_pressed("crouch"), "pause releases two-key actions")
	push_key(KEY_SHIFT, false)
	push_key(KEY_Z, false)
	app.controls_reset_all_button.pressed.emit()
	app.return_to_worlds()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "verification never captures pointer")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for path in [settings.controls_path(), fixture + ".worlds"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d key combo checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
