extends "res://scripts/app_base.gd"
# Menus du jeu, partie 2 sur 5 : Paramètres → Contrôles (touches, options, en même temps, après, recherche,
# Conflits) et touches à combinaisons envoyées au jeu.

# Onglet Contrôles (0.0.3.12), entre Vidéo et Attributs : une touche par action,
# Échap pendant le choix = aucune touche, ↻ par action et pour tout.
func _build_controls_section(parent: Node) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sep(box, 10)
	parent.add_child(box)
	settings_sections.controls = box
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(top)
	controls_reset_all_button = _button("↻ Tout réinitialiser", top, reset_all_controls)
	controls_reset_all_button.tooltip_text = "Rétablir toutes les touches par défaut"
	_build_controls_search(box)
	var inset := PanelContainer.new()
	inset.theme_type_variation = "OrbInsetDeep"
	box.add_child(inset)
	var list := VBoxContainer.new()
	_sep(list, 10)
	inset.add_child(list)
	_explanation(list, ["", "Cliquez une touche puis appuyez sur la nouvelle. Échap : aucune. + : options et combinaisons.", "Cliquez une touche, puis appuyez sur la touche ou le bouton de souris voulu (molette comprise). Échap : aucune touche. + : Nouvelle option (une autre façon de faire l'action), Appuyer en même temps (︸ sous les touches), Appuyer après (→ ; 0,5 s au plus entre deux, la même touche deux fois = double appui) ; 4 touches et 3 options au plus. ✕ retire une touche ou une option. Les flèches ← → restent toujours actives pour aller de côté. Celles des Menus (Échap, F1 à F4) sont réservées."])
	# Parties (0.0.4.8) : Mouvements, Blocs, Vitesses, puis Menus (touches réservées).
	for group in Controls.GROUPS:
		_explanation(list, group)
		list.get_child(-1).theme_type_variation = "OrbSection"
		control_group_labels[group] = list.get_child(-1)
		var group_body := _fold_body(list)
		control_group_bodies[group] = group_body
		_make_foldable(control_group_labels[group], group_body, "controls:" + group)
		for action in Controls.GROUPS[group]:
			_add_control_row(group_body, action)
	_explanation(list, "Menus")
	list.get_child(-1).theme_type_variation = "OrbSection"
	control_group_labels.Menus = list.get_child(-1)
	var menus_body := _fold_body(list)
	control_group_bodies.Menus = menus_body
	_make_foldable(control_group_labels.Menus, menus_body, "controls:Menus")
	for entry in Controls.MENU_KEYS:
		_row_line(menus_body)
		var menu_row := HBoxContainer.new()
		_sep(menu_row, 10)
		menus_body.add_child(menu_row)
		var menu_label := _text_label()
		menu_label.text = entry[0]
		menu_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		menu_row.add_child(menu_label)
		var fixed := _button(entry[1], menu_row, func(): pass)
		_min_size(fixed, Vector2(170, 0))
		fixed.disabled = true
		fixed.tooltip_text = "Touche réservée, non modifiable"
		control_menu_buttons[entry[0]] = fixed
	_build_control_options(box)

# Une action de Contrôles (0.0.4.20) : un bloc, refait à chaque changement, avec une ligne par option
# (Avancer, Avancer (2)…). Sur chaque ligne : les touches (︸ sous celles en même temps, → entre deux
# étapes, ✕ sur chaque touche ajoutée), ↻ (première ligne), puis + : Nouvelle option, Appuyer en
# même temps, Appuyer après. Un clic sur le nom replie ou déplie les options suivantes.
func _add_control_row(list: Node, action: String) -> void:
	_row_line(list)
	var block := VBoxContainer.new()
	_sep(block, 4)
	list.add_child(block)
	control_action_boxes[action] = block
	_build_control_action(action)

func _control_binding(action: String) -> Dictionary:
	return control_pending.get(action, Controls.normalize(settings.controls[action]))

func _build_control_action(action: String) -> void:
	var block: VBoxContainer = control_action_boxes[action]
	for child in block.get_children():
		for node in [child] + child.find_children("*", "Control", true, false):
			scaled_sizes.erase(node)
			scaled_separations.erase(node)
			font_sizes.erase(node)
		block.remove_child(child)
		child.queue_free()
	var binding := _control_binding(action)
	var all: Array = binding.options
	var action_name: String = Controls.ACTIONS[action].label
	control_slot_buttons[action] = []
	for index in range(maxi(1, all.size())):
		var combo: Dictionary = all[index] if index < all.size() else {"steps": [[{}]]}
		var row := HBoxContainer.new()
		_sep(row, 6)
		row.visible = index == 0 or control_expanded.get(action, true)
		block.add_child(row)
		var label := _text_label()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if index == 0:
			control_labels[action] = label
			if all.size() > 1:
				label.text = ("▾ " if control_expanded.get(action, true) else "▸ ") + action_name
				label.mouse_filter = Control.MOUSE_FILTER_STOP
				label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				label.tooltip_text = "Cliquer pour montrer ou cacher les autres options"
				label.gui_input.connect(func(event: InputEvent):
					if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
						toggle_control_options(action))
			else:
				label.text = action_name
		else:
			label.text = "%s (%d)" % [action_name, index + 1]
		var keys := HBoxContainer.new()
		_sep(keys, 4)
		row.add_child(keys)
		var steps: Array = combo.steps if not combo.steps.is_empty() else [[{}]]
		for step in range(steps.size()):
			if step > 0:
				var arrow := _text_label()
				arrow.text = "→"
				arrow.autowrap_mode = TextServer.AUTOWRAP_OFF
				arrow.tooltip_text = "Puis, juste après (%s s au plus)" % str(Controls.SEQUENCE_MS / 1000.0).replace(".", ",")
				keys.add_child(arrow)
			var chord_box := VBoxContainer.new()
			_sep(chord_box, 0)
			keys.add_child(chord_box)
			var chord_row := HBoxContainer.new()
			_sep(chord_row, 2)
			chord_box.add_child(chord_row)
			var chord: Array = steps[step]
			for part_index in range(chord.size()):
				var slot := [index, step, part_index]
				var part: Dictionary = chord[part_index]
				var waiting: bool = capturing_action == action and capturing_slot == slot
				var text := "Appuyez…" if waiting else Controls.part_label(part)
				var key_button := _button(text, chord_row, func(): start_control_capture(action, slot))
				_min_size(key_button, Vector2(110 if index == 0 and step == 0 and part_index == 0 else 90, 0))
				key_button.tooltip_text = "Changer la touche : " + label.text
				control_slot_buttons[action].append([slot, key_button])
				# Première touche d'une option : pas de ✕ (celui de l'option, à droite, la retire).
				if step == 0 and part_index == 0:
					if index == 0:
						control_buttons[action] = key_button
				else:
					var remove := _button("✕", chord_row, func(): remove_control_part(action, slot))
					remove.theme_type_variation = "OrbFold"
					_min_size(remove, Vector2(22, 0))
					remove.tooltip_text = "Retirer cette touche"
			if chord.size() > 1:
				var brace := _text_label()
				brace.text = "︸"
				brace.autowrap_mode = TextServer.AUTOWRAP_OFF
				brace.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				brace.tooltip_text = "En même temps"
				chord_box.add_child(brace)
		if index == 0:
			var reset := _button("↻", row, func(): reset_control(action))
			_min_size(reset, Vector2(42, 0))
			reset.tooltip_text = "Rétablir : " + Controls.label(Controls.default_for(action))
			control_resets[action] = reset
		else:
			var remove_option := _button("✕", row, func(): remove_control_option(action, index))
			_min_size(remove_option, Vector2(42, 0))
			remove_option.tooltip_text = "Retirer cette option"
		var more := MenuButton.new()
		more.text = "+"
		more.flat = false
		_min_size(more, Vector2(42, 0))
		more.tooltip_text = "Nouvelle option, appuyer en même temps, appuyer après"
		row.add_child(more)
		var popup := more.get_popup()
		var parts_count := Controls.combo_parts(combo).size()
		popup.add_item("Nouvelle option", 0)
		popup.set_item_disabled(0, all.size() >= Controls.MAX_OPTIONS)
		popup.add_item("Appuyer en même temps", 1)
		popup.set_item_disabled(1, parts_count >= Controls.MAX_KEYS or all.is_empty())
		popup.add_item("Appuyer après", 2)
		popup.set_item_disabled(2, parts_count >= Controls.MAX_KEYS or all.is_empty())
		popup.id_pressed.connect(func(id: int): control_more(action, index, id))
		if index == 0:
			control_more_buttons[action] = more
	_filter_controls()

# Menu + : 0 nouvelle option, 1 une touche de plus en même temps (dernière étape), 2 une étape après.
func control_more(action: String, option: int, choice: int) -> void:
	var binding := _control_binding(action).duplicate(true)
	var all: Array = binding.options
	if all.is_empty():
		all.append({"steps": [[{}]]})
	match choice:
		0:
			if all.size() >= Controls.MAX_OPTIONS:
				return
			all.append({"steps": [[{}]]})
			control_expanded[action] = true
			control_pending[action] = binding
			start_control_capture(action, [all.size() - 1, 0, 0])
		1, 2:
			var combo: Dictionary = all[option]
			if Controls.combo_parts(combo).size() >= Controls.MAX_KEYS:
				return
			if choice == 1:
				combo.steps[-1].append({})
				control_pending[action] = binding
				start_control_capture(action, [option, combo.steps.size() - 1, combo.steps[-1].size() - 1])
			else:
				combo.steps.append([{}])
				control_pending[action] = binding
				start_control_capture(action, [option, combo.steps.size() - 1, 0])

# Textes des cases de touches de la première option (pour lire le menu, et les tests).
func control_slot_texts(action: String) -> Array:
	return control_slot_buttons.get(action, []).filter(func(entry): return entry[0][0] == 0).map(func(entry): return entry[1].text)

func toggle_control_options(action: String) -> void:
	control_expanded[action] = not control_expanded.get(action, true)
	_build_control_action(action)

func remove_control_part(action: String, slot: Array) -> void:
	var binding := _control_binding(action).duplicate(true)
	var chord: Array = binding.options[slot[0]].steps[slot[1]]
	chord.remove_at(slot[2])
	set_control(action, _tidy_binding(binding))

func remove_control_option(action: String, option: int) -> void:
	var binding := _control_binding(action).duplicate(true)
	binding.options.remove_at(option)
	set_control(action, _tidy_binding(binding))

# Sans touches vides, étapes vides ni options vides (après Échap ou ✕).
func _tidy_binding(binding: Dictionary) -> Dictionary:
	var all := []
	for combo in binding.options:
		var steps := []
		for chord in combo.steps:
			var kept: Array = chord.filter(func(part): return not part.is_empty())
			if not kept.is_empty():
				steps.append(kept)
		if not steps.is_empty():
			all.append({"steps": steps})
	return {"options": all}

# --- Recherche et conflits (0.0.4.20) ---

# Trois barres fines, qui se combinent : la partie (et Conflits à droite), le nom, puis la touche.

func _build_controls_search(box: Node) -> void:
	var bars := VBoxContainer.new()
	_sep(bars, 3)
	box.add_child(bars)
	var top_bar := HBoxContainer.new()
	_sep(top_bar, 6)
	bars.add_child(top_bar)
	controls_search_group = LineEdit.new()
	controls_search_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_search_group.clear_button_enabled = true
	controls_search_group.placeholder_text = "Partie : Mouvements, Blocs, Vitesses…"
	controls_search_group.text_changed.connect(func(_text): _filter_controls())
	_min_size(controls_search_group, Vector2(0, 30))
	top_bar.add_child(controls_search_group)
	controls_conflicts_button = _button("Conflits", top_bar, func(): _filter_controls())
	controls_conflicts_button.toggle_mode = true
	controls_conflicts_button.theme_type_variation = "OrbFold"
	_min_size(controls_conflicts_button, Vector2(0, 30))
	controls_conflicts_button.tooltip_text = "Montrer seulement les touches en conflit"
	controls_search = _search_bar(bars, "Nom : Avancer, Voler… (ou premières lettres : tpv, mar pl)")
	controls_search_keys = _search_bar(bars, "Touche : Espace ; « Z, X » = Z puis X ; « ↑ A » = en même temps")
	controls_conflicts_text = _text_label()
	controls_conflicts_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_conflicts_text.theme_type_variation = "OrbNote"
	controls_conflicts_text.visible = false
	box.add_child(controls_conflicts_text)

func _search_bar(box: Node, hint: String) -> LineEdit:
	var field := LineEdit.new()
	field.clear_button_enabled = true
	field.placeholder_text = hint
	field.text_changed.connect(func(_text): _filter_controls())
	_min_size(field, Vector2(0, 30))
	box.add_child(field)
	return field

# Montre seulement les actions qui correspondent à la recherche (et aux conflits si demandé).
func _filter_controls() -> void:
	if controls_search == null or control_action_boxes.size() < Controls.ACTIONS.size() or not control_group_bodies.has("Menus"):
		return
	var text := controls_search.text.strip_edges()
	var group_text := controls_search_group.text.strip_edges()
	var key_text := controls_search_keys.text.strip_edges()
	var conflict_actions := {}
	var conflicts: Array = Controls.conflicts(settings.controls) if controls_conflicts_button.button_pressed else []
	for conflict in conflicts:
		for action in conflict.actions:
			conflict_actions[action] = true
	# Conflits : seulement les lignes en conflit ; s'il n'y en a aucun, rien que ce texte.
	controls_conflicts_text.visible = controls_conflicts_button.button_pressed and conflicts.is_empty()
	controls_conflicts_text.text = "Aucun conflit."
	var query := Controls.parse_key_query(key_text)
	for group in Controls.GROUPS:
		var shown := 0
		var group_ok := Controls.text_matches(group, group_text)
		for action in Controls.GROUPS[group]:
			var match_text := group_ok and Controls.text_matches(Controls.ACTIONS[action].label, text)
			if match_text and not query.is_empty():
				match_text = Controls.options(settings.controls[action]).any(func(combo): return Controls.combo_matches_keys(combo, query))
			var visible := match_text and (not controls_conflicts_button.button_pressed or conflict_actions.has(action))
			control_action_boxes[action].visible = visible
			var line_index: int = control_action_boxes[action].get_index() - 1
			var parent: Node = control_action_boxes[action].get_parent()
			if line_index >= 0 and parent.get_child(line_index) is HSeparator:
				parent.get_child(line_index).visible = visible
			if visible:
				shown += 1
		control_group_labels[group].visible = shown > 0
		control_group_bodies[group].visible = shown > 0 and not is_folded("controls:" + group)
	var searching := not text.is_empty() or not group_text.is_empty() or not key_text.is_empty() or controls_conflicts_button.button_pressed
	control_group_labels.Menus.visible = not searching
	control_group_bodies.Menus.visible = not searching and not is_folded("controls:Menus")

# Choix des Contrôles, sous la liste des touches.
func _build_control_options(box: Node) -> void:
	# Catégories « Se baisser » (0.0.3.18) et « Courir » (0.0.3.25) : mode de la touche.
	for option in Controls.OPTIONS:
		var spec: Dictionary = Controls.OPTIONS[option]
		var gap := Control.new()
		_min_size(gap, Vector2(0, CATEGORY_GAP))
		box.add_child(gap)
		var options_inset := PanelContainer.new()
		options_inset.theme_type_variation = "OrbInsetDeep"
		box.add_child(options_inset)
		var options := VBoxContainer.new()
		_sep(options, 10)
		options_inset.add_child(options)
		_explanation(options, spec.category)
		options.get_child(-1).theme_type_variation = "OrbSection"
		var option_body := _fold_body(options)
		_make_foldable(options.get_child(0), option_body, "option:" + option)
		_explanation(option_body, spec.help)
		var row := HBoxContainer.new()
		_sep(row, 10)
		option_body.add_child(row)
		var label := _text_label()
		label.text = spec.label
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var group := ButtonGroup.new()
		control_option_buttons[option] = {}
		for choice in spec.options:
			var button := _button(spec.options[choice], row, func(): set_control_option(option, choice))
			button.theme_type_variation = "OrbTab"
			button.toggle_mode = true
			button.button_group = group
			_min_size(button, Vector2(52, 0))
			control_option_buttons[option][choice] = button
		var reset := _button("↻", row, func(): set_control_option(option, spec.default))
		_min_size(reset, Vector2(42, 0))
		reset.tooltip_text = "Rétablir le défaut : " + spec.options[spec.default]
		control_resets[option] = reset
	_refresh_controls()

func set_control_option(option: String, choice: String) -> void:
	if not settings.set_control_option(option, choice):
		settings_message.text = settings.last_error
		return
	settings_message.text = "%s : %s." % [Controls.OPTIONS[option].label, Controls.OPTIONS[option].options[choice]]
	_refresh_controls()
	_apply_to_game()

func _refresh_controls() -> void:
	for action in control_action_boxes:
		_build_control_action(action)
	for option in control_option_buttons:
		for choice in control_option_buttons[option]:
			control_option_buttons[option][choice].set_pressed_no_signal(settings.control_options[option] == choice)

# Choisir la touche d'une case [option, étape, touche] (par défaut : la première de la première option).
func start_control_capture(action: String, slot: Array = [0, 0, 0]) -> void:
	var previous := capturing_action
	if not previous.is_empty() and previous != action:
		control_pending.erase(previous)
		_build_control_action(previous)
	capturing_action = action
	capturing_slot = slot
	_build_control_action(action)
	settings_message.text = "%s : appuyez sur une touche ou un bouton de souris. Échap : aucune." % Controls.ACTIONS[action].label

func _capture_control(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	var part := {}
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		part = {}
	else:
		part = Controls.from_event(event)
		if part.is_empty():
			settings_message.text = "Touche réservée (Échap, F1, F2, F3) : choisissez-en une autre."
			return
	# 0.0.4.20 : la touche va dans la case choisie ; Échap la vide (case retirée, sauf la seule de l'action :
	# plus aucune touche). Les autres touches restent.
	var binding := _control_binding(capturing_action).duplicate(true)
	if binding.options.is_empty():
		binding.options.append({"steps": [[{}]]})
	binding.options[capturing_slot[0]].steps[capturing_slot[1]][capturing_slot[2]] = part
	set_control(capturing_action, _tidy_binding(binding))

func set_control(action: String, binding: Dictionary) -> void:
	capturing_action = ""
	capturing_slot = []
	control_pending.erase(action)
	var freed: String = settings.set_control(action, binding)
	if not settings.last_error.is_empty():
		settings_message.text = settings.last_error
	elif not freed.is_empty():
		settings_message.text = "%s : %s (retirée de %s)." % [Controls.ACTIONS[action].label, Controls.label(binding), freed]
	else:
		settings_message.text = "%s : %s." % [Controls.ACTIONS[action].label, Controls.label(binding)]
	# Une touche seule qui fait partie d'une combinaison déclenche les deux actions : avertir.
	var overlaps: Array = Controls.overlaps(settings.controls, action)
	if settings.last_error.is_empty() and not overlaps.is_empty():
		settings_message.text += " Attention : déclenche aussi %s." % ", ".join(overlaps)
	_apply_controls()
	_refresh_controls()

# Touches dans le jeu (InputMap) et suivi des actions à deux touches.
func _apply_controls() -> void:
	Controls.apply(settings.controls)
	_send_combos(key_combos.set_bindings(settings.controls))
	if is_instance_valid(active_world):
		active_world.player.click_modifiers = Controls.click_modifiers(settings.controls)
		active_world.player.move_blocks = Controls.blocked_moves(settings.controls)

# Changements des actions à deux touches, lus par le jeu comme les autres touches.
func _send_combos(changes: Array) -> void:
	for change in changes:
		var event := InputEventAction.new()
		event.action = change[0]
		event.pressed = change[1]
		event.strength = 1.0 if change[1] else 0.0
		Input.parse_input_event(event)

func reset_control(action: String) -> void:
	set_control(action, Controls.default_for(action))

func reset_all_controls() -> void:
	for action in Controls.ACTIONS:
		set_control(action, Controls.default_for(action))
	for option in Controls.OPTIONS:
		set_control_option(option, Controls.OPTIONS[option].default)
	settings_message.text = "Toutes les touches par défaut."
