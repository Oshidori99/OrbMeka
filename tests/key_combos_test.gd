extends SceneTree
# Combinaisons de touches. 0.0.3.27 : deux touches (double appui, en même temps). 0.0.4.20 : jusqu'à
# 3 options par action et 4 touches par combinaison, étapes simultanées (accolade) et « après » (→,
# Controls.SEQUENCE_MS au plus), bouton + (Nouvelle option, Appuyer en même temps, Appuyer après),
# ✕ par touche et par option, recherche par partie, nom ou touche, bouton Conflits. Anciens
# controles.json toujours lus.
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

func combo(steps: Array) -> Dictionary:
	return {"steps": steps}

func k(code: int) -> Dictionary:
	return {"key": code}

func visible_actions(app: Control) -> Array:
	return Controls.ACTIONS.keys().filter(func(action): return app.control_action_boxes[action].visible)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	# Format : anciennes écritures converties.
	var double := Controls.normalize({"key": KEY_W, "second": {"key": KEY_W}})
	var together := Controls.normalize({"key": KEY_SHIFT, "second": {"key": KEY_Z}})
	check(double == {"options": [combo([[k(KEY_W)], [k(KEY_W)]])]} and together == {"options": [combo([[k(KEY_SHIFT), k(KEY_Z)]])]} and Controls.normalize({}) == {"options": []}, "old bindings converted (double press = same key after)")
	check(Controls.kind({"key": KEY_W}) == "single" and Controls.kind(double) == "double" and Controls.kind(together) == "together" and Controls.kind({}) == "none", "kinds kept")
	check(Controls.label(double) == "W → W" and Controls.label(together) == "Shift + Z", "names: → for after, + for together")
	check(Controls.same(together, {"key": KEY_Z, "second": {"key": KEY_SHIFT}}) and not Controls.same(together, {"key": KEY_Z}), "Maj + Z is the same as Z + Maj")
	var big := {"options": [combo([[k(KEY_A), k(KEY_B)], [k(KEY_C), k(KEY_D)]])]}
	check(Controls.is_valid(big) and not Controls.is_valid({"options": [combo([[k(KEY_A), k(KEY_B), k(KEY_C)], [k(KEY_D), k(KEY_E)]])]}), "4 keys at most per combination")
	check(Controls.is_valid({"options": [combo([[k(KEY_A)]]), combo([[k(KEY_B)]]), combo([[k(KEY_C)]])]}) and not Controls.is_valid({"options": [combo([[k(KEY_A)]]), combo([[k(KEY_B)]]), combo([[k(KEY_C)]]), combo([[k(KEY_D)]])]}), "3 options at most per action")
	check(not Controls.is_valid({"options": [combo([[k(KEY_ESCAPE)]])]}) and not Controls.is_valid({"options": [combo([[]])]}) and Controls.is_valid({"key": KEY_E, "second": {"mouse": MOUSE_BUTTON_LEFT}}), "reserved keys and empty steps refused; old writing accepted")
	# Dans le jeu : double appui, en même temps, après, options.
	var combos := KeyCombos.new()
	combos.set_bindings({"sprint": double, "crouch": together, "jump": {"key": KEY_SPACE}, "fly": {"options": [combo([[k(KEY_UP), k(KEY_A)], [k(KEY_X)]]), combo([[k(KEY_G)], [k(KEY_H)]])]}})
	check(combos.feed(key(KEY_W, true), 1000).is_empty() and combos.feed(key(KEY_W, false), 1080).is_empty(), "one press of the double key does nothing")
	check(combos.feed(key(KEY_W, true), 1000 + Controls.SEQUENCE_MS) == [["sprint", true]], "second press within the delay starts the action")
	check(combos.feed(key(KEY_W, false), 1600) == [["sprint", false]], "releasing it stops the action")
	combos.feed(key(KEY_W, true), 3000)
	combos.feed(key(KEY_W, false), 3050)
	check(combos.feed(key(KEY_W, true), 3001 + Controls.SEQUENCE_MS).is_empty(), "too slow: not a double press")
	combos.feed(key(KEY_W, false), 3600)
	var echo := key(KEY_W, true)
	echo.echo = true
	check(combos.feed(echo, 3620).is_empty(), "held key repeats are ignored")
	check(combos.feed(key(KEY_SHIFT, true), 5000).is_empty() and combos.feed(key(KEY_Z, true), 9000) == [["crouch", true]], "Maj then Z starts the action")
	check(combos.feed(key(KEY_SHIFT, false), 9100) == [["crouch", false]], "releasing either key stops it")
	combos.feed(key(KEY_Z, false), 9200)
	combos.feed(key(KEY_Z, true), 9300)
	check(combos.feed(key(KEY_SHIFT, true), 9400) == [["crouch", true]], "Z then Maj works too")
	check(combos.release_all() == [["crouch", false]] and combos.feed(key(KEY_Z, false), 9500).is_empty(), "release all (pause) stops the action once")
	check(combos.feed(key(KEY_SPACE, true), 9600).is_empty(), "one-key actions stay with the game input")
	combos.feed(key(KEY_SPACE, false), 9650)
	combos.feed(key(KEY_UP, true), 10000)
	combos.feed(key(KEY_A, true), 10050)
	combos.feed(key(KEY_UP, false), 10100)
	combos.feed(key(KEY_A, false), 10120)
	check(combos.feed(key(KEY_X, true), 10300) == [["fly", true]], "↑ + A, then X: together, then after")
	combos.feed(key(KEY_X, false), 10400)
	combos.feed(key(KEY_UP, true), 11000)
	combos.feed(key(KEY_A, true), 11050)
	combos.feed(key(KEY_UP, false), 11100)
	combos.feed(key(KEY_A, false), 11120)
	check(combos.feed(key(KEY_X, true), 11100 + Controls.SEQUENCE_MS + 100).is_empty(), "too late after the first step: nothing")
	combos.feed(key(KEY_X, false), 11800)
	combos.feed(key(KEY_G, true), 12000)
	combos.feed(key(KEY_G, false), 12050)
	check(combos.feed(key(KEY_H, true), 12200) == [["fly", true]], "second option (G → H) works too")
	combos.feed(key(KEY_H, false), 12300)
	# Ancien controles.json (une ou deux touches) toujours lu.
	var fixture := "res://.godot/key-combos-test-%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(Settings.new(fixture).controls_path(), FileAccess.WRITE)
	file.store_string('{"jump": {"key": %d}, "fly": {"key": %d, "second": {"key": %d}}, "break_block": {"mouse": 1}, "crouch_mode": "toggle"}' % [KEY_G, KEY_G, KEY_G])
	file.close()
	var old := Settings.new(fixture)
	check(old.load_notice.is_empty() and old.controls.jump == Controls.single({"key": KEY_G}) and old.controls.fly == Controls.normalize({"key": KEY_G, "second": {"key": KEY_G}}) and old.control_options.crouch_mode == "toggle", "old controles.json still read")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.new(fixture).controls_path()))
	# Menu Contrôles.
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	var item: Dictionary = app.catalog.create_world("Combinaisons", "3")
	root.add_child(app)
	current_scene = app
	await process_frame
	app.show_page("settings")
	app.settings_tabs.controls.pressed.emit()
	check(app.control_more_buttons.size() == Controls.ACTIONS.size() and app.control_more_buttons.jump.text == "+" and app.control_more_buttons.jump.get_popup().item_count == 3, "a + button per action, with three choices")
	check(app.control_resets.jump.get_index() < app.control_more_buttons.jump.get_index(), "+ right of ↻")
	check(not "control_second_buttons" in app, "the old second-key column is gone")
	# Nouvelle option.
	app.control_more_buttons.move_forward.get_popup().id_pressed.emit(0)
	check(app.capturing_action == "move_forward" and app.capturing_slot == [1, 0, 0], "Nouvelle option waits for its key")
	push_key(KEY_I)
	check(settings.controls.move_forward == {"options": [combo([[k(KEY_W)]]), combo([[k(KEY_I)]])]} and InputMap.action_get_events("move_forward").size() == 2, "Avancer (2): a second way, both in the game")
	var rows: Array = app.control_action_boxes.move_forward.get_children()
	check(rows.size() == 2 and rows[1].get_child(0).text == "Avancer (2)" and app.control_labels.move_forward.text == "▾ Avancer", "shown as Avancer (2) under Avancer")
	app.toggle_control_options("move_forward")
	check(not app.control_action_boxes.move_forward.get_child(1).visible and app.control_labels.move_forward.text == "▸ Avancer", "click on Avancer hides the other options")
	app.toggle_control_options("move_forward")
	check(app.control_action_boxes.move_forward.get_child(1).visible, "and shows them again")
	# Simultanément.
	app.control_more_buttons.sprint.get_popup().id_pressed.emit(1)
	check(app.capturing_slot == [0, 0, 1], "Simultanément adds a key on the right")
	push_key(KEY_SHIFT)
	check(settings.controls.sprint == {"options": [combo([[k(KEY_R), k(KEY_SHIFT)]])]} and Controls.label(settings.controls.sprint) == "R + Shift", "R + Shift together")
	# 0.0.4.22 : accolade dessinée, de la première à la dernière touche simultanée ; menu « Simultanément ».
	var braces: Array = app.control_action_boxes.sprint.find_children("Brace", "Control", true, false)
	check(braces.size() == 1 and braces[0].get_parent().get_child(0).get_child_count() == 3, "brace under keys pressed together (R, Shift and its ✕)")
	check(app.control_more_buttons.sprint.get_popup().get_item_text(1) == "Simultanément", "+ menu: Simultanément")
	check(not InputMap.action_get_events("sprint").any(func(event): return event is InputEventKey and event.physical_keycode == KEY_R), "a single R no longer runs")
	# Appuyer après.
	app.control_more_buttons.sprint.get_popup().id_pressed.emit(2)
	check(app.capturing_slot == [0, 1, 0], "Appuyer après adds a step")
	push_key(KEY_L)
	check(settings.controls.sprint == {"options": [combo([[k(KEY_R), k(KEY_SHIFT)], [k(KEY_L)]])]} and Controls.label(settings.controls.sprint) == "R + Shift → L", "R + Shift, then L")
	var arrows: Array = app.control_action_boxes.sprint.find_children("*", "RichTextLabel", true, false).filter(func(node): return node.text == "→")
	check(arrows.size() == 1, "arrow between steps, no brace around them")
	# Limites : 4 touches.
	app.control_more_buttons.sprint.get_popup().id_pressed.emit(1)
	push_key(KEY_M)
	var popup: PopupMenu = app.control_more_buttons.sprint.get_popup()
	check(Controls.combo_parts(Controls.options(settings.controls.sprint)[0]).size() == 4 and popup.is_item_disabled(1) and popup.is_item_disabled(2) and not popup.is_item_disabled(0), "4 keys: no more together or after")
	# ✕ sur une touche ; Échap sur une case ajoutée la retire.
	app.remove_control_part("sprint", [0, 1, 1])
	app.remove_control_part("sprint", [0, 1, 0])
	app.remove_control_part("sprint", [0, 0, 1])
	check(settings.controls.sprint == Controls.single({"key": KEY_R}), "✕ removes keys one by one")
	app.control_more_buttons.sprint.get_popup().id_pressed.emit(2)
	push_key(KEY_ESCAPE)
	check(settings.controls.sprint == Controls.single({"key": KEY_R}) and app.page == "settings", "Escape on a new key: nothing added")
	# 3 options au plus ; ✕ sur une option.
	app.control_more_buttons.move_forward.get_popup().id_pressed.emit(0)
	push_key(KEY_O)
	check(Controls.options(settings.controls.move_forward).size() == 3 and app.control_more_buttons.move_forward.get_popup().is_item_disabled(0), "3 options: no new option")
	app.remove_control_option("move_forward", 1)
	check(settings.controls.move_forward == {"options": [combo([[k(KEY_W)]]), combo([[k(KEY_O)]])]}, "✕ removes an option")
	app.remove_control_option("move_forward", 1)
	check(settings.controls.move_forward == Controls.single({"key": KEY_W}) and app.control_labels.move_forward.text == "Avancer", "back to one way: plain name")
	# Même combinaison ailleurs : retirée de l'autre action ; touche seule incluse : avertir.
	app.control_buttons.jump.pressed.emit()
	push_key(KEY_K)
	app.control_more_buttons.crouch.get_popup().id_pressed.emit(0)
	push_key(KEY_K)
	check(Controls.singles(settings.controls.crouch).has({"key": KEY_K}) and settings.controls.jump == {"options": []} and app.settings_message.text.contains("retirée de Sauter"), "same key on two actions: taken away")
	app.controls_reset_all_button.pressed.emit()
	app.control_more_buttons.jump.get_popup().id_pressed.emit(1)
	push_key(KEY_W)
	check(app.settings_message.text.contains("Attention") and app.settings_message.text.contains("Avancer"), "a single key inside a combination is warned about")
	app.controls_reset_all_button.pressed.emit()
	# Partie Vitesses — réinitialiser.
	check(Controls.GROUPS["Vitesses — réinitialiser"].has("speed_reset_all") and not Controls.GROUPS.Vitesses.has("walk_reset") and app.control_group_labels.has("Vitesses — réinitialiser"), "resets in their own part")
	# Recherche : trois barres (partie, nom, touche) qui se combinent.
	var bars: Node = app.controls_search_group.get_parent().get_parent()
	check(app.controls_search.get_parent() == bars and app.controls_search_keys.get_parent() == bars and app.controls_search_group.get_parent().get_index() < app.controls_search.get_index() and app.controls_search.get_index() < app.controls_search_keys.get_index(), "three bars: part, then name, then key")
	app.controls_search.text = "avan"
	app._filter_controls()
	check(visible_actions(app) == ["move_forward"] and not app.control_group_labels.Blocs.visible, "by name: Avancer only")
	app.controls_search.text = "tpv"
	app._filter_controls()
	check(visible_actions(app) == ["speed_up"], "first letters: tpv = Tout plus vite")
	app.controls_search.text = "mar pl"
	app._filter_controls()
	check(visible_actions(app) == ["walk_up"], "beginnings of words: mar pl = Marche plus vite")
	app.controls_search.text = ""
	app.controls_search_group.text = "blocs"
	app._filter_controls()
	check(visible_actions(app) == Controls.GROUPS.Blocs, "by part: the Blocs actions")
	app.controls_search_group.text = "vit"
	app.controls_search.text = "course"
	app._filter_controls()
	check(visible_actions(app) == ["run_up", "run_down", "run_reset"], "part and name together: Vitesses parts, Course")
	app.controls_search_group.text = "vr"
	app.controls_search.text = ""
	app._filter_controls()
	check(visible_actions(app) == Controls.GROUPS["Vitesses — réinitialiser"], "part by first letters: vr = Vitesses — réinitialiser")
	app.controls_search_group.text = ""
	app.controls_search_keys.text = "Espace"
	app._filter_controls()
	check(visible_actions(app) == ["jump", "fly"], "by key: everything using Espace")
	app.controls_search_keys.text = "espace, espace"
	app._filter_controls()
	check(visible_actions(app) == ["fly"], "« espace, espace »: Espace then Espace (Voler)")
	app.controls_search_keys.text = "↑ a"
	app._filter_controls()
	check(visible_actions(app) == ["speed_up"], "« ↑ a »: ↑ and A together")
	app.controls_search_keys.text = "clic gauche"
	app._filter_controls()
	check(visible_actions(app).has("break_block") and visible_actions(app).has("break_up") and visible_actions(app).has("break_reset"), "names in two words work (clic gauche)")
	app.controls_search_keys.text = "↑"
	app.controls_search.text = "course"
	app._filter_controls()
	check(visible_actions(app) == ["run_up"], "name and key together: Course with ↑")
	app.controls_search.text = ""
	app.controls_search_keys.text = ""
	app._filter_controls()
	check(visible_actions(app).size() == Controls.ACTIONS.size() and app.control_group_labels.Menus.visible, "empty search: everything back")
	# Conflits.
	var conflicts: Array = Controls.conflicts(settings.controls)
	var involved := []
	for conflict in conflicts:
		involved.append_array(conflict.actions)
	check(involved.has("sprint") and involved.has("run_up") and involved.has("jump") and involved.has("fly"), "defaults: R inside ↑ + R, Espace inside Espace → Espace")
	check(not involved.has("move_left") and not involved.has("break_block"), "already handled by the game: not a conflict (A with ↑, click with ↑)")
	app.controls_conflicts_button.button_pressed = true
	app._filter_controls()
	check(not app.controls_conflicts_text.visible and visible_actions(app).has("sprint") and visible_actions(app).has("fly") and not visible_actions(app).has("move_forward"), "Conflits shows only the rows in conflict")
	var saved_controls: Dictionary = settings.controls
	var none := {}
	for action in Controls.ACTIONS:
		none[action] = {"options": []}
	settings.controls = none
	app._filter_controls()
	check(visible_actions(app).is_empty() and app.controls_conflicts_text.visible and app.controls_conflicts_text.text == "Aucun conflit.", "no conflict: no row, just « Aucun conflit. »")
	settings.controls = saved_controls
	app.controls_conflicts_button.button_pressed = false
	app._filter_controls()
	check(app.controls_conflicts_button.get_parent() == app.controls_search_group.get_parent() and app.controls_conflicts_button.get_index() > app.controls_search_group.get_index(), "Conflits on the right of the part bar")
	# Enregistré et relu.
	settings.set_control("fly", {"options": [combo([[k(KEY_UP), k(KEY_A)], [k(KEY_X)]]), combo([[k(KEY_G)], [k(KEY_H)]])]})
	var reloaded := Settings.new(fixture)
	check(reloaded.controls.fly == settings.controls.fly and reloaded.load_notice.is_empty(), "options and steps saved in controles.json and reloaded")
	# Dans le jeu.
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
	check(not Input.is_action_pressed("crouch"), "pause releases combinations")
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
