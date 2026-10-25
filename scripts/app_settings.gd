extends "res://scripts/app_launcher.gd"
# Menus du jeu, partie 4 sur 5 : Paramètres (réglages, Personnage, Attributs, enregistrement automatique).

func _on_player_speeds() -> void:
	if not is_instance_valid(active_world) or not active_world.developer_mode:
		return
	var player: Node = active_world.player
	for scale in player.SCALES:
		var key: String = "current_" + scale
		var percent := snappedf(float(player.get(scale + "_scale")) * 100.0, 0.1)
		settings.values[key] = percent
		setting_fields[key].text = UserSettings.number_text(percent)
		_sync_slider(key)
	if speed_save_timer == null:
		speed_save_timer = Timer.new()
		speed_save_timer.one_shot = true
		speed_save_timer.timeout.connect(func(): settings.save_values())
		add_child(speed_save_timer)
	speed_save_timer.start(SPEED_SAVE_DELAY)

func _add_setting_row(parent: Node, key: String) -> void:
	_row_line(parent)
	if UserSettings.CHOICES.has(key):
		_add_choice_row(parent, key)
		return
	var spec: Dictionary = UserSettings.SPECS[key]
	var row := HBoxContainer.new()
	_sep(row, 10)
	parent.add_child(row)
	var label := _text_label()
	var default_text := UserSettings.number_text(spec.default)
	# Minimum et maximum toujours affichés, quel que soit le niveau de détail (0.0.3.12).
	detail_labels[label] = ["%s · %s à %s %s" % [spec.label, UserSettings.number_text(spec.min), UserSettings.number_text(spec.max), spec.unit], "%s (%s) · défaut %s · %s à %s" % [spec.label, spec.unit, default_text, UserSettings.number_text(spec.min), UserSettings.number_text(spec.max)], "%s (%s)
Défaut : %s · %s à %s" % [spec.label, spec.unit, default_text, UserSettings.number_text(spec.min), UserSettings.number_text(spec.max)]]
	label.text = _detail(detail_labels[label])
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	# Barre (0.0.3.7) : la glisser remplit le champ ; saisir dans le champ déplace la barre.
	var slider := HSlider.new()
	slider.min_value = spec.min
	slider.max_value = spec.max
	slider.step = _slider_step(spec)
	_min_size(slider, Vector2(SLIDER_WIDTH, 0))
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.tooltip_text = "%s — %s à %s %s" % [spec.label, UserSettings.number_text(spec.min), UserSettings.number_text(spec.max), spec.unit]
	row.add_child(slider)
	setting_sliders[key] = slider
	var field := LineEdit.new()
	_min_size(field, Vector2(85, 46))
	field.max_length = 24
	field.placeholder_text = UserSettings.number_text(spec.default)
	field.tooltip_text = slider.tooltip_text
	row.add_child(field)
	field.text_submitted.connect(func(_text: String): apply_user_settings())
	field.text_changed.connect(func(_text: String):
		_sync_slider(key)
		_autosave())
	slider.value_changed.connect(func(value: float):
		field.text = UserSettings.number_text(value)
		_autosave())
	setting_fields[key] = field
	var reset := _button("↻", row, func(): reset_setting(key))
	_min_size(reset, Vector2(42, 0))
	reset.tooltip_text = "Rétablir le défaut de ce champ : " + UserSettings.number_text(spec.default)
	setting_resets[key] = reset

# Choix en boutons exclusifs (synthèse, thème, profondeur), avec ↻ comme les champs.
func _add_choice_row(parent: Node, key: String) -> void:
	var spec: Dictionary = UserSettings.CHOICES[key]
	var row := HBoxContainer.new()
	_sep(row, 10)
	parent.add_child(row)
	var label := _text_label()
	label.text = spec.label
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if spec.options.keys() == ["on", "off"]:
		# Oui / Non : interrupteur on/off (0.0.3.7) plutôt que deux boutons.
		var switch := CheckButton.new()
		switch.tooltip_text = spec.label
		switch.toggled.connect(func(on: bool): _choose(key, "on" if on else "off"))
		_sounds().attach(switch)
		row.add_child(switch)
		choice_switches[key] = switch
	var group := ButtonGroup.new()
	choice_buttons[key] = {}
	for option in spec.options:
		if choice_switches.has(key):
			break
		var button := _button(spec.options[option], row, func(): _choose(key, option))
		button.theme_type_variation = "OrbTab"
		button.toggle_mode = true
		button.button_group = group
		_min_size(button, Vector2(52, 0))
		choice_buttons[key][option] = button
	var reset := _button("↻", row, func(): reset_setting(key))
	_min_size(reset, Vector2(42, 0))
	reset.tooltip_text = "Rétablir le défaut : " + spec.options[spec.default]
	setting_resets[key] = reset

func _set_choice(key: String, option: String) -> void:
	choice_values[key] = option
	if choice_switches.has(key):
		choice_switches[key].set_pressed_no_signal(option == "on")
	for each in choice_buttons[key]:
		choice_buttons[key][each].set_pressed_no_signal(each == option)
	if key in ["character", "skin"]:
		_refresh_character_cards()

func _set_default(key: String) -> void:
	if UserSettings.CHOICES.has(key):
		_set_choice(key, UserSettings.CHOICES[key].default)
	else:
		setting_fields[key].text = UserSettings.number_text(UserSettings.SPECS[key].default)
		_sync_slider(key)

# Pas de la barre : fin pour les petites plages (mètres), plus large pour les millisecondes.
static func _slider_step(spec: Dictionary) -> float:
	if spec.has("step"):
		return spec.step
	var span: float = spec.max - spec.min
	if span <= 50.0:
		return 0.1
	return 1.0 if span <= 300.0 else 10.0

func _sync_slider(key: String) -> void:
	# Champ vide : défaut ; saisie invalide : la barre ne bouge pas (le message signale l'erreur).
	var text: String = setting_fields[key].text.strip_edges().replace(",", ".")
	var value: float = UserSettings.SPECS[key].default
	if not text.is_empty():
		if not text.is_valid_float():
			return
		value = text.to_float()
	setting_sliders[key].set_value_no_signal(value)

# Onglet Personnage (0.0.3.16), entre Contrôles et Attributs : quatre personnages simples,
# un aperçu et un bouton chacun. Le choix est enregistré aussitôt et vaut pour la partie.
func _build_character_section(parent: Node) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sep(box, 10)
	parent.add_child(box)
	settings_sections.character = box
	var top := HBoxContainer.new()
	_sep(top, 10)
	box.add_child(top)
	_explanation(top, ["", "Choisissez votre personnage et sa peau.", "Choisissez votre personnage : peau claire en haut, brune au milieu, foncée en bas, animaux tout en bas. Vous le serez dans la partie, même si on ne peut pas encore se voir."])
	top.get_child(-1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reset := _button("↻", top, reset_character)
	_min_size(reset, Vector2(42, 0))
	reset.tooltip_text = "Rétablir le défaut : " + UserSettings.CHOICES.character.options[UserSettings.CHOICES.character.default] + ", " + UserSettings.CHOICES.skin.options[UserSettings.CHOICES.skin.default].to_lower()
	setting_resets["character"] = reset
	setting_resets["skin"] = reset
	# 0.0.3.22 : une rangée par ton de peau (claire, brune, foncée), puis les animaux tout en bas (0.0.3.23 : six par rangée).
	# Carte « boy9:light » : personnage et ton choisis ensemble ; un animal garde le ton enregistré.
	var cards := GridContainer.new()
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 8)
	box.add_child(cards)
	var group := ButtonGroup.new()
	choice_buttons["character"] = {}
	choice_buttons["skin"] = {}
	var rows: Array = []
	for skin in CharacterPreview.SKINS:
		rows.append([CharacterPreview.SKINS[skin].name, skin, CharacterPreview.CHARACTERS.keys().filter(func(id): return CharacterPreview.is_human(id))])
	rows.append(["Animaux", "", CharacterPreview.CHARACTERS.keys().filter(func(id): return not CharacterPreview.is_human(id))])
	var per_row := 0
	for row in rows:
		per_row = maxi(per_row, row[2].size())
	cards.columns = per_row + 1
	for row in rows:
		var heading := _text_label()
		heading.text = row[0]
		heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cards.add_child(heading)
		for column_index in range(per_row):
			if column_index >= row[2].size():
				cards.add_child(Control.new())
				continue
			var id: String = row[2][column_index]
			var skin: String = row[1]
			var card_id := id + (":" + skin if not skin.is_empty() else "")
			var data: Dictionary = CharacterPreview.CHARACTERS[id]
			var card := PanelContainer.new()
			card.theme_type_variation = "OrbInsetDeep"
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cards.add_child(card)
			var column := VBoxContainer.new()
			_sep(column, 4)
			card.add_child(column)
			var preview := CharacterPreview.new()
			preview.character = id
			if not skin.is_empty():
				preview.skin = skin
			_min_size(preview, Vector2(60, 96))
			column.add_child(preview)
			character_previews[card_id] = preview
			var button := _button(data.name, column, func(): _choose_character(id, skin))
			button.theme_type_variation = "OrbTab"
			button.toggle_mode = true
			button.button_group = group
			button.tooltip_text = "%s (%s)" % [data.name, data.age] if skin.is_empty() else "%s, %s (%s)" % [data.name, CharacterPreview.SKINS[skin].name.to_lower(), data.age]
			character_buttons[card_id] = button
			# 0.0.3.27 : un clic sur l'aperçu (ou le cadre) choisit aussi le personnage.
			preview.mouse_filter = Control.MOUSE_FILTER_PASS
			column.mouse_filter = Control.MOUSE_FILTER_PASS
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			card.tooltip_text = button.tooltip_text
			card.gui_input.connect(func(event: InputEvent): _click_character_card(event, button, id, skin))

# Clic gauche sur une carte : comme son bouton, qui prend aussi le focus (clavier).
func _click_character_card(event: InputEvent, button: Button, id: String, skin: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		button.grab_focus()
		_choose_character(id, skin)
		get_viewport().set_input_as_handled()

# ↻ du menu Personnage : Garçon 14 ans, peau claire.
func reset_character() -> void:
	_set_default("skin")
	reset_setting("character")

func _choose_character(id: String, skin: String) -> void:
	choice_values["character"] = id
	if not skin.is_empty():
		choice_values["skin"] = skin
	_refresh_character_cards()
	_autosave()
	# 0.0.4.12 : le personnage choisi parle (humain) ou pousse son cri (animal).
	_voices().speak(id, CharacterPreview.CHARACTERS.get(id, {}).get("age", "adulte"))

func _refresh_character_cards() -> void:
	var id: String = choice_values.get("character", UserSettings.CHOICES.character.default)
	var skin: String = choice_values.get("skin", UserSettings.CHOICES.skin.default)
	var selected := id + ":" + skin if CharacterPreview.is_human(id) else id
	for card_id in character_buttons:
		character_buttons[card_id].set_pressed_no_signal(card_id == selected)

func _add_setting_category(parent: Node, category: String, data: Dictionary) -> void:
	# Espace avant chaque catégorie : titres et ↻ de catégorie bien détachés des champs.
	var gap := Control.new()
	_min_size(gap, Vector2(0, CATEGORY_GAP))
	parent.add_child(gap)
	# Profondeur : chaque catégorie dans un encadré plus creusé que la page.
	var inset := PanelContainer.new()
	inset.theme_type_variation = "OrbInsetDeep"
	parent.add_child(inset)
	parent = VBoxContainer.new()
	_sep(parent, 10)
	inset.add_child(parent)
	var header := HBoxContainer.new()
	parent.add_child(header)
	_explanation(header, category)
	header.get_child(-1).theme_type_variation = "OrbSection"
	header.get_child(-1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reset := _button("↻", header, func(): reset_category(category))
	_min_size(reset, Vector2(48, 0))
	reset.theme_type_variation = "OrbCategoryReset"
	reset.tooltip_text = "Rétablir les défauts de la catégorie " + category
	category_resets[category] = reset
	# 0.0.4.14 : un clic sur le titre réduit ou développe la catégorie (aide et champs).
	var body := _fold_body(parent)
	_make_foldable(header.get_child(0), body, "cat:" + category)
	_explanation(body, data.help)
	# 0.0.4.16 : sous-catégories (ex. Voler : Normal, Rapide, Monter et descendre), repliables aussi.
	if data.has("groups"):
		for group in data.groups:
			var sub_gap := Control.new()
			_min_size(sub_gap, Vector2(0, 10))
			body.add_child(sub_gap)
			_explanation(body, group)
			var subtitle: Node = body.get_child(-1)
			subtitle.theme_type_variation = "OrbSubsection"
			var group_body := _fold_body(body)
			_make_foldable(subtitle, group_body, "sub:%s/%s" % [category, group])
			for key in data.groups[group]:
				_add_setting_row(group_body, key)
		return
	for key in data.keys:
		_add_setting_row(body, key)

func _fill_settings() -> void:
	for key in setting_fields:
		setting_fields[key].text = UserSettings.number_text(settings.values[key])
		_sync_slider(key)
	for key in choice_buttons:
		_set_choice(key, settings.values[key])
	settings_message.text = settings.load_notice

func reset_setting(key: String) -> void:
	_set_default(key)
	settings_message.text = "Défaut rétabli pour ce champ."
	_autosave()

func _category_keys(category: String) -> Array:
	if ATTRIBUTE_CATEGORIES.has(category):
		return ATTRIBUTE_CATEGORIES[category].keys
	for section in GENERAL_CATEGORIES:
		if GENERAL_CATEGORIES[section].has(category):
			return GENERAL_CATEGORIES[section][category].keys
	return []

func reset_category(category: String) -> void:
	for key in _category_keys(category):
		_set_default(key)
	settings_message.text = "Défauts rétablis : %s." % category
	_autosave()

func reset_all_settings() -> void:
	# Bouton de l'écran Attributs : seuls les attributs reprennent leur défaut.
	for key in UserSettings.ATTRIBUTE_KEYS:
		_set_default(key)
	settings_message.text = "Tous les attributs par défaut."
	_autosave()

# Attributs verrouillés : en pause, dans un monde en mode par défaut.
func _attributes_locked() -> bool:
	return is_instance_valid(active_world) and not active_world.developer_mode

func _show_attributes_gate(confirming: bool) -> void:
	var locked := _attributes_locked()
	attributes_gate.visible = locked
	attributes_scroll.visible = not locked
	attributes_gate_button.visible = locked and not confirming
	attributes_gate_confirm.visible = confirming
	attributes_gate_cancel.visible = confirming
	attributes_default_button.visible = is_instance_valid(active_world) and active_world.developer_mode
	if confirming:
		attributes_gate_text.text = "Ce monde passera en mode développeur. Le retour au mode par défaut reste possible,
mais la mention « mode développeur utilisé » est irréversible (Informations du monde)."
		attributes_gate_cancel.grab_focus()
	else:
		attributes_gate_text.text = "Ce monde est en mode par défaut : ses attributs ne sont pas modifiables.
Pour les régler, passez-le en mode développeur."

func request_game_developer_mode() -> void:
	_show_attributes_gate(true)

func confirm_game_developer_mode() -> void:
	if not _attributes_locked():
		return
	if not catalog.enable_developer_mode(current_world_id):
		attributes_gate_text.text = catalog.last_error
		return
	active_world.developer_used = true
	active_world.developer_mode = true
	active_world.world_mode_text = Catalog.MODE_NAMES[Catalog.MODE_DEVELOPER]
	_apply_to_game()
	_show_attributes_gate(false)
	settings_message.text = "Monde passé en mode développeur : attributs modifiables."

# 0.0.4.10 : en partie, retour au mode par défaut (la mention « utilisé » reste).
func return_game_default_mode() -> void:
	if not is_instance_valid(active_world) or not active_world.developer_mode:
		return
	if not catalog.disable_developer_mode(current_world_id):
		settings_message.text = catalog.last_error
		return
	active_world.developer_mode = false
	active_world.world_mode_text = Catalog.MODE_NAMES[Catalog.MODE_DEFAULT]
	_apply_to_game()
	_show_attributes_gate(false)
	settings_message.text = "Monde repassé en mode par défaut : attributs par défaut."

# En partie, les réglages s'appliquent tout de suite au joueur et aux textes du jeu.
func _apply_to_game() -> void:
	if not is_instance_valid(active_world):
		return
	active_world.player.apply_settings(settings.world_values(active_world.developer_mode))
	active_world.apply_text_scale(_text_scale())
	active_world.set_coordinates_visible(settings.values.show_coords == "on")
	# Distance de chargement changée en pause : zones mises à jour peu à peu.
	active_world.set_grass_distance(float(settings.values.grass_distance))
	active_world.load_distance = int(settings.values.load_distance)
	active_world.update_zones(active_world.player_coordinates())
	active_world.player.crouch_toggle = settings.control_options.crouch_mode == "toggle"
	active_world.player.run_mode = settings.control_options.run_mode

func open_pause_settings() -> void:
	if page != "pause" or not is_instance_valid(active_world):
		return
	show_page("settings")

# Retour de Paramètres : vers la pause en partie, sinon vers l'accueil.
func leave_settings() -> void:
	show_page("pause" if is_instance_valid(active_world) else "home")

func show_settings_section(section: String) -> void:
	# Changer de section ne change rien : chaque réglage est déjà enregistré (0.0.3.8).
	settings_section = section
	for key in settings_sections:
		settings_sections[key].visible = key == section
		settings_tabs[key].set_pressed_no_signal(key == section)

# Enregistrement automatique (0.0.3.8) : chaque changement est validé, enregistré et appliqué
# aussitôt, sans bouton Appliquer. Valeur invalide : message, rien n'est enregistré.
# Les champs ne sont pas réécrits ici, pour ne pas gêner la saisie en cours.
func _autosave() -> bool:
	var texts := {}
	for key in setting_fields:
		texts[key] = setting_fields[key].text
	texts.merge(choice_values, true)
	if not settings.apply_texts(texts):
		settings_message.text = settings.last_error
		return false
	apply_appearance()
	_apply_to_game()
	if layout_pending():
		layout_apply_button.disabled = false
		settings_message.text = "Enregistré. Taille des menus appliquée en quittant Paramètres ou avec « Appliquer la taille des menus »."
	else:
		settings_message.text = "Enregistré."
	return true

func layout_pending() -> bool:
	for key in LAYOUT_KEYS:
		if layout_values.get(key) != settings.values[key]:
			return true
	return false

# Applique les réglages de taille des menus enregistrés (bouton, Entrée, sortie de Paramètres).
func apply_layout() -> void:
	for key in LAYOUT_KEYS:
		layout_values[key] = settings.values[key]
	if not is_instance_valid(menu_root):
		return
	apply_appearance()
	_apply_to_game()
	fit_menus_to_window()
	# Mise en page refaite tout de suite, puis encore une fois une fois les textes repliés.
	menu_panel.reset_size()
	fit_menus_to_window.call_deferred()
	layout_apply_button.disabled = true

func _choose(key: String, option: String) -> void:
	_set_choice(key, option)
	_autosave()

# Entrée dans un champ : enregistre, applique tout (taille des menus comprise) et affiche
# les valeurs telles qu'enregistrées.
func apply_user_settings() -> void:
	if _autosave():
		apply_layout()
		_fill_settings()
		settings_message.text = "Enregistré."
