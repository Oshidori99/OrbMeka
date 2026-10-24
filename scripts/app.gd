extends "res://scripts/app_settings.gd"
# Menus du jeu, partie 5 sur 5 : construction des pages, accueil, mondes, partie, pause, touches du clavier.
# Constantes et variables : app_base.gd.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiTheme.use_web_fonts()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_window().min_size = MIN_WINDOW_SIZE
	if catalog == null:
		catalog = Catalog.new()
	if settings == null:
		settings = UserSettings.new()
	for key in LAYOUT_KEYS:
		layout_values[key] = settings.values[key]
	# Touches choisies dans Paramètres → Contrôles, pour tout le jeu.
	_apply_controls()
	showcase = MenuShowcase.new()
	showcase.name = "MenuShowcase"
	add_child(showcase)
	_build_interface()
	get_viewport().size_changed.connect(fit_menus_to_window)
	fit_menus_to_window()
	show_page("home")

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	menu_root = Control.new()
	layer.add_child(menu_root)
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.theme = _build_theme()
	# Voile derrière le panneau : léger sur le fond 3D de l'accueil, sombre et flou en pause.
	backdrop = ColorRect.new()
	backdrop.material = ShaderMaterial.new()
	backdrop.material.shader = BackdropShader
	menu_root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Launcher (0.0.4.1) : fond opaque qui cache le monde de l'accueil.
	launcher_screen = ColorRect.new()
	launcher_screen.color = UiTheme.LAUNCHER_SCREEN
	launcher_screen.visible = false
	menu_root.add_child(launcher_screen)
	launcher_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	menu_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	menu_panel = panel
	center.add_child(panel)
	var stack := VBoxContainer.new()
	# Défilement de tout le panneau si son contenu dépasse la hauteur de la fenêtre
	# (grand texte, petite fenêtre) : le panneau ne sort jamais de l'écran.
	menu_scroll = ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.follow_focus = true
	panel.add_child(menu_scroll)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_scroll.add_child(stack)
	menu_stack = stack
	stack.minimum_size_changed.connect(_queue_fit)
	var home := _page(stack, "OrbMeka™")
	pages.home = _page_root(home)
	var version := _text_label()
	version.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.3.21"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.theme_type_variation = "OrbNote"
	home.add_child(version)
	home_version = version
	news_label = _text_label()
	news_label.text = MenuShowcase.NEWS_TEXT
	news_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	news_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	home.add_child(news_label)
	play_button = _button("Jouer", home, func(): show_page("worlds"))
	settings_button = _button("Paramètres", home, func(): show_page("settings"))
	information_button = _button("Informations", home, func(): show_page("information"))
	history_button = _button("Historique des versions", home, open_history)
	# 0.0.4 : launcher puis Quitter, tout en bas (pas de Quitter dans un navigateur).
	launcher_button = _button("Aller au launcher", home, open_launcher)
	# 0.0.4.18 : version Web à part : un navigateur ne lance pas de programme, pas de launcher.
	launcher_button.visible = not OS.has_feature("web")
	quit_button = _button("Quitter le jeu", home, func(): get_tree().quit())
	quit_button.visible = not OS.has_feature("web")
	# 0.0.4.1 : écran à part (gris, sans le monde derrière). De haut en bas : Retour au jeu,
	# dernières versions jouées (la plus récente en bas), gros bouton vert Jouer (dernière
	# version) avec ▼ qui déplie toutes les versions en dessous, la dernière tout en bas.
	var launcher_page := _page(stack, "OrbMeka — Launcher")
	pages.launcher = _page_root(launcher_page)
	launcher_box = launcher_page
	launcher_back_button = _button("Retour au jeu", launcher_page, func(): show_page("home"))
	launcher_back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	launcher_back_button.theme_type_variation = "OrbLauncherButton"
	launcher_status = _text_label()
	launcher_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	launcher_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	launcher_page.add_child(launcher_status)
	launcher_played_title = _text_label()
	launcher_played_title.text = "Dernières versions jouées"
	launcher_played_title.theme_type_variation = "OrbSection"
	launcher_page.add_child(launcher_played_title)
	launcher_played = VBoxContainer.new()
	_sep(launcher_played, 2)
	launcher_page.add_child(launcher_played)
	# 0.0.4.16 : la page prend toute la hauteur ; la liste ▼ s'ouvre au-dessus de Jouer, tout en bas.
	var launcher_spacer := Control.new()
	launcher_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	launcher_page.add_child(launcher_spacer)
	launcher_scroll = ScrollContainer.new()
	launcher_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	launcher_page.add_child(launcher_scroll)
	launcher_list = VBoxContainer.new()
	launcher_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sep(launcher_list, 2)
	launcher_scroll.add_child(launcher_list)
	launcher_scroll.visible = false
	var play_row := HBoxContainer.new()
	_sep(play_row, 4)
	launcher_page.add_child(play_row)
	launcher_latest_button = _button("Jouer", play_row, play_latest_version)
	launcher_latest_button.theme_type_variation = "OrbLaunch"
	launcher_latest_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_min_size(launcher_latest_button, Vector2(0, 64))
	launcher_arrow_button = _button("▼", play_row, func(): show_all_versions(not launcher_scroll.visible))
	launcher_arrow_button.theme_type_variation = "OrbLaunch"
	launcher_arrow_button.toggle_mode = true
	launcher_arrow_button.tooltip_text = "Choisir une autre version"
	_min_size(launcher_arrow_button, Vector2(64, 64))
	var history_page := _page(stack, "Historique des versions")
	pages.history = _page_root(history_page)
	history_scroll = ScrollContainer.new()
	history_scroll.custom_minimum_size = Vector2(0, 350)
	menu_reserved_heights[history_scroll] = 300.0
	history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	history_scroll.focus_mode = Control.FOCUS_ALL
	history_page.add_child(history_scroll)
	history_text = _text_label()
	history_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font_size(history_text, 17)
	history_scroll.add_child(history_text)
	history_back_button = _button("Retour", history_page, func(): show_page("home"))
	var settings_page := _page(stack, "Paramètres")
	_sep(settings_page, 10)
	pages.settings = _page_root(settings_page)
	# 0.0.4.14 : une ligne discrète en haut : Tout réduire, Tout développer, et ce qu'on voit à l'ouverture.
	var fold_row := HBoxContainer.new()
	_sep(fold_row, 8)
	settings_page.add_child(fold_row)
	fold_collapse_button = _button("Tout réduire", fold_row, func(): fold_all(true))
	fold_expand_button = _button("Tout développer", fold_row, func(): fold_all(false))
	fold_open_button = _button("", fold_row, cycle_fold_open_mode)
	fold_open_button.tooltip_text = "À l'ouverture de Paramètres : comme la dernière fois, tout développé ou tout réduit (cliquer pour changer)"
	for button in [fold_collapse_button, fold_expand_button, fold_open_button]:
		button.theme_type_variation = "OrbFold"
		_min_size(button, Vector2(0, 28))
	_refresh_fold_open_button()
	# Menu latéral à gauche (onglets rectangulaires), contenu de la section à droite.
	var settings_body := HBoxContainer.new()
	_sep(settings_body, 16)
	settings_page.add_child(settings_body)
	settings_nav = VBoxContainer.new()
	_sep(settings_nav, 6)
	settings_body.add_child(settings_nav)
	var nav_group := ButtonGroup.new()
	for section in SETTINGS_SECTIONS:
		var tab := _button(SETTINGS_SECTIONS[section], settings_nav, func(): show_settings_section(section))
		tab.theme_type_variation = "OrbTab"
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tab.toggle_mode = true
		tab.button_group = nav_group
		settings_tabs[section] = tab
	for section in GENERAL_CATEGORIES:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_sep(box, 10)
		settings_body.add_child(box)
		settings_sections[section] = box
		# Pas de titre de section : l'onglet de gauche le donne déjà.
		for category in GENERAL_CATEGORIES[section]:
			_add_setting_category(box, category, GENERAL_CATEGORIES[section][category])
			if category == "Texte":
				# 0.0.3.11 : juste sous les réglages de taille (Panneaux, Zones, Texte). La taille des
				# menus ne change pas pendant qu'on règle (la barre resterait sous la souris) :
				# elle s'applique en quittant Paramètres ou avec ce bouton.
				layout_apply_button = _button("Appliquer la taille des menus", box, apply_layout)
				layout_apply_button.disabled = true
		_explanation(box, ["", "Commun à tous les mondes.", "Commun à tous les mondes. Champ vide : défaut."])
		box.get_child(-1).theme_type_variation = "OrbNote"
	_build_controls_section(settings_body)
	_build_character_section(settings_body)
	var attributes_box := VBoxContainer.new()
	attributes_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sep(attributes_box, 10)
	settings_body.add_child(attributes_box)
	settings_sections.attributes = attributes_box
	# En pause dans un monde par défaut (0.0.3.9) : les attributs sont remplacés par une
	# proposition de passer le monde en mode développeur, avec avertissement (mention « utilisé » irréversible, 0.0.4.10).
	attributes_gate = VBoxContainer.new()
	_sep(attributes_gate, 10)
	attributes_box.add_child(attributes_gate)
	attributes_gate_text = _text_label()
	attributes_gate_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attributes_gate.add_child(attributes_gate_text)
	attributes_gate_button = _button("Passer ce monde en mode développeur…", attributes_gate, request_game_developer_mode)
	attributes_gate_confirm = _button("Confirmer : mode développeur", attributes_gate, confirm_game_developer_mode)
	attributes_gate_cancel = _button("Annuler", attributes_gate, func(): _show_attributes_gate(false))
	# 0.0.4.10 : monde en mode développeur, en partie : bouton pour repasser en mode par défaut.
	attributes_default_button = _button("Repasser ce monde en mode par défaut", attributes_box, return_game_default_mode)
	attributes_default_button.visible = false
	var settings_scroll := ScrollContainer.new()
	attributes_scroll = settings_scroll
	settings_scroll.custom_minimum_size = Vector2(0, 320)
	menu_reserved_heights[settings_scroll] = 300.0
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_scroll.focus_mode = Control.FOCUS_ALL
	settings_scroll.follow_focus = true
	attributes_box.add_child(settings_scroll)
	var attributes := VBoxContainer.new()
	attributes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sep(attributes, 10)
	settings_scroll.add_child(attributes)
	var all_row := HBoxContainer.new()
	attributes.add_child(all_row)
	# Pas de titre « Attributs » (déjà sur l'onglet) : seul ↻ Tout réinitialiser, à droite.
	all_row.alignment = BoxContainer.ALIGNMENT_END
	settings_reset_all_button = _button("↻ Tout réinitialiser", all_row, reset_all_settings)
	settings_reset_all_button.tooltip_text = "Rétablir les défauts de tous les attributs"
	for category in ATTRIBUTE_CATEGORIES:
		_add_setting_category(attributes, category, ATTRIBUTE_CATEGORIES[category])
	_explanation(attributes, ["", "Mondes en mode développeur seulement.", "Utilisés seulement par les mondes en mode développeur. Champ vide : défaut."])
	attributes.get_child(-1).theme_type_variation = "OrbNote"
	# 0.0.4.17 : dernier onglet, Licences : mentions obligatoires (Godot, licence MIT, composants,
	# polices) et origine des sons, sur Windows comme dans un navigateur.
	var licences_box := VBoxContainer.new()
	licences_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_body.add_child(licences_box)
	settings_sections.licences = licences_box
	licences_scroll = ScrollContainer.new()
	licences_scroll.custom_minimum_size = Vector2(0, 320)
	menu_reserved_heights[licences_scroll] = 300.0
	licences_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	licences_scroll.focus_mode = Control.FOCUS_ALL
	licences_box.add_child(licences_scroll)
	licences_text = _text_label()
	licences_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	licences_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font_size(licences_text, 15)
	licences_text.text = Licences.summary()
	licences_scroll.add_child(licences_text)
	# Message commun aux trois sections : enregistrement automatique à chaque changement (0.0.3.8).
	settings_message = _text_label()
	settings_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_page.add_child(settings_message)
	settings_back_button = _button("Retour", settings_page, leave_settings)
	var information_page := _page(stack, "Génération des mondes")
	pages.information = _page_root(information_page)
	var span := Terrain.MAX_CELL - Terrain.MIN_CELL + 1
	var sizes := [int(WorldRules.BASE_SIZE.x), int(WorldRules.BASE_SIZE.z), span, span, WorldRules.MAX_BUILD_HEIGHT, Terrain.MAX_HEIGHT]
	_explanation(information_page, [
		"Base %d × %d, hauteur maximale %d. Constructions non sauvegardées." % [sizes[0], sizes[1], sizes[4]],
		"Base plate : %d × %d blocs ; génération : %d × %d.
Hauteur maximale : %d blocs ; 3 ou 4 collines de %d blocs au plus.
Graine aléatoire si vide. Constructions non sauvegardées." % sizes,
		"Base plate : largeur %d × longueur %d blocs (%s), sol à Y 0
Zone de génération : largeur %d × longueur %d blocs (%s)
Construction : hauteur maximale %d blocs au-dessus du sol plat, collines comprises (sommet à Y %d), %s.
Collines : 3 ou 4, hauteur maximale %d blocs (sommet à Y %d)
%s

Graine choisie à la création, ou aléatoire si le champ est vide.
Nom, graine et mode conservés ; constructions non sauvegardées.
Réouvrir un monde régénère son terrain initial.
F1 : revenir à la liste des mondes depuis la partie." % [sizes[0], sizes[1], WorldRules.base_range_text(), span, span, WorldRules.generation_range_text(), sizes[4], sizes[4], WorldRules.build_range_text(), sizes[5], sizes[5], WorldRules.COORDINATES_NOTE],
	])
	generation_info = information_page.get_child(-1)
	information_back_button = _button("Retour", information_page, func(): show_page("home"))
	var list_page := _page(stack, "Mes mondes")
	pages.worlds = _page_root(list_page)
	_sep(list_page, 10)
	world_list = ItemList.new()
	world_list.custom_minimum_size = Vector2(0, 144)
	menu_reserved_heights[world_list] = 380.0
	_font_size(world_list, 21)
	list_page.add_child(world_list)
	world_list.item_selected.connect(func(_index: int): _update_world_actions())
	world_list.item_activated.connect(func(_index: int): open_selected_world())
	list_message = _text_label()
	list_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_page.add_child(list_message)
	# Une seule rangée : Ouvrir en toutes lettres, les autres actions en icônes (nom au survol).
	var actions_row := HBoxContainer.new()
	_sep(actions_row, 8)
	list_page.add_child(actions_row)
	open_button = _button("▶ Ouvrir", actions_row, open_selected_world)
	open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_world_button = _icon_button("➕", "Créer un monde", actions_row, func(): show_page("create"))
	rename_button = _icon_button("✏️", "Renommer", actions_row, request_rename)
	duplicate_button = _icon_button("📋", "Dupliquer (même graine)", actions_row, duplicate_selected_world)
	world_settings_button = _icon_button("⚙️", "Paramètres du monde", actions_row, open_world_settings)
	delete_button = _icon_button("🗑️", "Supprimer", actions_row, request_delete)
	_button("Retour", list_page, func(): show_page("home"))
	var form := _page(stack, "Créer un monde")
	pages.create = _page_root(form)
	_sep(form, 10)
	var name_label := _text_label()
	name_label.text = "Nom du monde"
	form.add_child(name_label)
	_explanation(form, ["", "Graine facultative : vide = aléatoire.", "Un nom de 1 à %d caractères suffit.
Graine facultative : vide pour un terrain aléatoire.
Nom, graine et mode conservés ; constructions non sauvegardées." % Catalog.MAX_NAME_LENGTH])
	name_field = LineEdit.new()
	name_field.placeholder_text = "Mon monde"
	name_field.max_length = Catalog.MAX_NAME_LENGTH
	_min_size(name_field, Vector2(0, 46))
	_font_size(name_field, 22)
	form.add_child(name_field)
	name_field.text_submitted.connect(func(_text: String): create_named_world())
	var seed_label := _text_label()
	seed_label.text = "Graine de génération (facultatif)"
	form.add_child(seed_label)
	seed_field = LineEdit.new()
	seed_field.placeholder_text = "Vide : aléatoire · Entier de 0 à 4294967295"
	seed_field.max_length = 32
	_min_size(seed_field, Vector2(0, 46))
	_font_size(seed_field, 18)
	form.add_child(seed_field)
	seed_field.text_submitted.connect(func(_text: String): create_named_world())
	world_options_title = _text_label()
	world_options_title.text = "Options du monde"
	world_options_title.theme_type_variation = "OrbSection"
	form.add_child(world_options_title)
	# Deux boutons exclusifs : Par défaut à gauche, Mode développeur à droite.
	var mode_row := HBoxContainer.new()
	_sep(mode_row, 10)
	form.add_child(mode_row)
	var mode_group := ButtonGroup.new()
	create_default_button = _button(Catalog.MODE_NAMES[Catalog.MODE_DEFAULT], mode_row, func(): set_create_mode(Catalog.MODE_DEFAULT))
	create_developer_button = _button(Catalog.MODE_NAMES[Catalog.MODE_DEVELOPER], mode_row, func(): set_create_mode(Catalog.MODE_DEVELOPER))
	for button in [create_default_button, create_developer_button]:
		button.theme_type_variation = "OrbTab"
		button.toggle_mode = true
		button.button_group = mode_group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_mode_note = _text_label()
	create_mode_note.theme_type_variation = "OrbNote"
	create_mode_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(create_mode_note)
	form_error = _text_label()
	form_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(form_error)
	create_button = _button("➕ Créer", form, create_named_world)
	_button("Retour", form, func(): show_page("worlds"))
	var world_settings_page := _page(stack, "Paramètres du monde")
	pages.world_settings = _page_root(world_settings_page)
	world_settings_text = _text_label()
	world_settings_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_settings_page.add_child(world_settings_text)
	world_developer_button = _button("Passer en mode développeur…", world_settings_page, request_developer_mode)
	world_default_button = _button("Repasser en mode par défaut", world_settings_page, return_world_default_mode)
	world_settings_back_button = _button("Retour", world_settings_page, cancel_world_action)
	var developer_page := _page(stack, "Passer en mode développeur ?")
	pages.developer_confirm = _page_root(developer_page)
	developer_confirm_message = _text_label()
	developer_confirm_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	developer_page.add_child(developer_confirm_message)
	developer_confirm_button = _button("Confirmer : mode développeur", developer_page, confirm_developer_mode)
	developer_cancel_button = _button("Annuler", developer_page, open_world_settings_for_pending)
	var rename_page := _page(stack, "Renommer le monde")
	pages.rename = _page_root(rename_page)
	_explanation(rename_page, ["", "Seul le nom change.", "Seul le nom change (1 à %d caractères).
La graine et le terrain initial sont conservés." % Catalog.MAX_NAME_LENGTH])
	rename_field = LineEdit.new()
	rename_field.max_length = Catalog.MAX_NAME_LENGTH
	_min_size(rename_field, Vector2(0, 46))
	rename_page.add_child(rename_field)
	rename_field.text_submitted.connect(func(_text: String): confirm_rename())
	rename_error = _text_label()
	rename_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rename_page.add_child(rename_error)
	_button("✏️ Renommer", rename_page, confirm_rename)
	_button("Annuler", rename_page, cancel_world_action)
	var delete_page := _page(stack, "Supprimer ce monde ?")
	pages.delete = _page_root(delete_page)
	delete_message = _text_label()
	delete_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delete_page.add_child(delete_message)
	_button("🗑️ Confirmer la suppression", delete_page, confirm_delete)
	cancel_delete_button = _button("Annuler", delete_page, cancel_world_action)
	var pause_page := _page(stack, "Pause")
	pages.pause = _page_root(pause_page)
	pause_version = _text_label()
	pause_version.text = version.text
	pause_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_version.theme_type_variation = "OrbNote"
	pause_page.add_child(pause_version)
	resume_button = _button("Reprendre", pause_page, resume_game)
	# 0.0.3.9 : Paramètres aussi en pause, juste sous Reprendre (sans Attributs dans un monde par défaut).
	pause_settings_button = _button("Paramètres", pause_page, open_pause_settings)
	how_button = _button("Comment jouer", pause_page, open_help)
	info_button = _button("Informations du monde", pause_page, open_world_info)
	_button("Retour aux mondes", pause_page, return_to_worlds)
	var help_page := _page(stack, "Comment jouer")
	pages.help = _page_root(help_page)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 350)
	menu_reserved_heights[scroll] = 300.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	help_page.add_child(scroll)
	help_text = _text_label()
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font_size(help_text, 17)
	scroll.add_child(help_text)
	help_back_button = _button("Retour à la pause", help_page, func(): show_page("pause"))
	var info_page := _page(stack, "Informations du monde")
	pages.world_info = _page_root(info_page)
	info_text = _text_label()
	info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_page.add_child(info_text)
	info_back_button = _button("Retour à la pause", info_page, func(): show_page("pause"))
	# Rappels des raccourcis en jeu, en haut à droite : simple texte, sans bouton.
	shortcut_hints = Label.new()
	shortcut_hints.name = "ShortcutHints"
	shortcut_hints.text = "F1 : Retour aux mondes
F2 : Comment jouer
F3 : Informations du monde
F4 : Changer de vue"
	layer.add_child(shortcut_hints)
	shortcut_hints.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	shortcut_hints.offset_left = -280
	shortcut_hints.offset_right = -18
	shortcut_hints.offset_top = 18
	_font_size(shortcut_hints, 15)
	shortcut_hints.add_theme_color_override("font_shadow_color", Color.BLACK)
	shortcut_hints.add_theme_constant_override("shadow_outline_size", 3)
	shortcut_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shortcut_hints.visible = false
	apply_appearance()
	apply_appearance()

func _update_backdrop() -> void:
	# En pause : monde visible derrière, assombri et flouté. À l'accueil : fond 3D à peine voilé.
	var paused_world := is_instance_valid(active_world)
	backdrop.material.set_shader_parameter("blur", 2.5 if paused_world else 0.0)
	backdrop.material.set_shader_parameter("tint", Color(0.07, 0.04, 0.13, 0.5 if paused_world else 0.12))
	# Launcher (0.0.4.1) : on sort du jeu (fond gris uni, panneau sobre, titre de fenêtre).
	var outside := page == "launcher"
	launcher_screen.visible = outside
	if outside:
		var panel_box := StyleBoxFlat.new()
		panel_box.bg_color = UiTheme.LAUNCHER_PANEL
		panel_box.set_corner_radius_all(6)
		# 0.0.4.16 : marges réduites, pour la place.
		panel_box.set_content_margin_all(12)
		menu_panel.add_theme_stylebox_override("panel", panel_box)
	else:
		menu_panel.remove_theme_stylebox_override("panel")
	get_window().title = "OrbMeka — Launcher" if outside else str(ProjectSettings.get_setting("application/config/name", "OrbMeka"))

func show_page(next_page: String) -> void:
	# 0.0.4.14 : en entrant dans Paramètres, titres réduits ou développés selon le choix d'ouverture.
	if next_page == "settings" and page != "settings":
		apply_fold_open()
	# En quittant Paramètres, la taille des menus réglée s'applique.
	if page == "settings" and next_page != "settings" and layout_pending():
		apply_layout()
	page = next_page
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_root.visible = true
	fit_menus_to_window()
	_update_backdrop()
	shortcut_hints.visible = false
	apply_appearance()
	for key in pages:
		pages[key].visible = key == page
	_fit_height()
	menu_scroll.scroll_vertical = 0
	if page == "worlds":
		refresh_world_list()
		if world_list.item_count > 0:
			world_list.grab_focus()
		else:
			# Open is disabled on an empty list; focus the next actionable button.
			new_world_button.grab_focus()
	elif page == "history":
		history_back_button.grab_focus()
	elif page == "launcher":
		launcher_latest_button.grab_focus()
	elif page == "settings":
		_fill_settings()
		_show_attributes_gate(false)
		show_settings_section(SETTINGS_SECTIONS.keys()[0])
		settings_tabs[settings_section].grab_focus()
	elif page == "information":
		information_back_button.grab_focus()
	elif page == "create":
		name_field.clear()
		seed_field.clear()
		form_error.text = ""
		create_button.disabled = not catalog.load_error.is_empty()
		set_create_mode(Catalog.MODE_DEFAULT)
		name_field.grab_focus()
	elif page == "world_settings":
		world_settings_back_button.grab_focus()
	elif page == "developer_confirm":
		developer_cancel_button.grab_focus()
	elif page == "rename":
		rename_field.grab_focus()
	elif page == "pause":
		resume_button.grab_focus()
	elif page == "world_info":
		info_back_button.grab_focus()
	elif page == "help":
		help_back_button.grab_focus()
	elif page == "delete":
		cancel_delete_button.grab_focus()
	else:
		play_button.grab_focus()

func refresh_world_list(preferred_id: String = "") -> void:
	world_list.clear()
	for item in catalog.worlds:
		world_list.add_item(item.name)
		world_list.set_item_metadata(world_list.item_count - 1, item.id)
	open_button.disabled = true
	if not catalog.load_error.is_empty():
		list_message.text = catalog.load_error
	elif world_list.item_count == 0:
		list_message.text = "Aucun monde. Créez votre premier monde."
	else:
		list_message.text = "Choisissez un monde à ouvrir."
		world_list.select(0)
		open_button.disabled = false
		for index in range(world_list.item_count):
			if world_list.get_item_metadata(index) == preferred_id:
				world_list.select(index)
	_update_world_actions()

func _selected_world_id() -> String:
	var selection := world_list.get_selected_items()
	return "" if selection.is_empty() else str(world_list.get_item_metadata(selection[0]))

func _update_world_actions() -> void:
	var available: bool = not _selected_world_id().is_empty() and catalog.load_error.is_empty()
	open_button.disabled = not available
	rename_button.disabled = not available
	delete_button.disabled = not available
	duplicate_button.disabled = not available
	world_settings_button.disabled = not available

func duplicate_selected_world() -> void:
	var item: Dictionary = catalog.duplicate_world(_selected_world_id())
	if item.is_empty():
		list_message.text = catalog.last_error
		return
	refresh_world_list(item.id)
	list_message.text = "Copie créée : %s" % item.name
	world_list.grab_focus()

func set_create_mode(mode: String) -> void:
	create_mode = mode
	create_default_button.set_pressed_no_signal(mode == Catalog.MODE_DEFAULT)
	create_developer_button.set_pressed_no_signal(mode == Catalog.MODE_DEVELOPER)
	if mode == Catalog.MODE_DEVELOPER:
		create_mode_note.text = _detail(["", "Attributs modifiables. Définitif.", "Attributs modifiables (Paramètres → Attributs). Définitif pour ce monde."])
	else:
		create_mode_note.text = _detail(["", "Attributs par défaut, non modifiables.", "Attributs par défaut, non modifiables. Passage au mode développeur possible plus tard."])
	create_mode_note.visible = not create_mode_note.text.is_empty()

func open_world_settings() -> void:
	var item: Dictionary = catalog.find_world(_selected_world_id())
	if item.is_empty():
		return
	pending_world_id = item.id
	_show_world_settings(item)

func open_world_settings_for_pending() -> void:
	var item: Dictionary = catalog.find_world(pending_world_id)
	if item.is_empty():
		cancel_world_action()
		return
	_show_world_settings(item)

func _show_world_settings(item: Dictionary) -> void:
	var developer: bool = item.get("mode", Catalog.MODE_DEFAULT) == Catalog.MODE_DEVELOPER
	var mode_name: String = Catalog.MODE_NAMES[Catalog.MODE_DEVELOPER if developer else Catalog.MODE_DEFAULT]
	var plus := "Attributs modifiables dans Paramètres → Attributs. Retour au mode par défaut possible." if developer else "Attributs par défaut, non modifiables."
	# 0.0.4.10 : mention définitive quand le mode développeur a déjà servi.
	if item.get("developer_used", false):
		mode_name += " (mode développeur déjà utilisé)"
	world_settings_text.text = _detail(["« %s » · Mode : %s" % [item.name, mode_name], "Monde : %s
Mode : %s" % [item.name, mode_name], "Monde : %s
Mode : %s
%s" % [item.name, mode_name, plus]])
	world_developer_button.visible = not developer
	world_default_button.visible = developer
	show_page("world_settings")

func request_developer_mode() -> void:
	var item: Dictionary = catalog.find_world(pending_world_id)
	if item.is_empty() or item.get("mode", Catalog.MODE_DEFAULT) == Catalog.MODE_DEVELOPER:
		return
	# Toujours « irréversible », quel que soit le niveau de détail.
	developer_confirm_message.text = _detail(["« %s » : mention irréversible." % item.name, "« %s » passera en mode développeur.
Retour possible, mais la mention « mode développeur utilisé » est irréversible." % item.name, "Le monde « %s » utilisera les attributs de Paramètres → Attributs.
Le retour au mode par défaut reste possible, mais la mention « mode développeur utilisé
au moins une fois » est irréversible (Informations du monde)." % item.name])
	show_page("developer_confirm")

# 0.0.4.10 : depuis Paramètres du monde, retour au mode par défaut.
func return_world_default_mode() -> void:
	if not catalog.disable_developer_mode(pending_world_id):
		world_settings_text.text = catalog.last_error
		return
	open_world_settings_for_pending()

func confirm_developer_mode() -> void:
	if not catalog.enable_developer_mode(pending_world_id):
		developer_confirm_message.text = catalog.last_error
		return
	open_world_settings_for_pending()

func request_rename() -> void:
	var item: Dictionary = catalog.find_world(_selected_world_id())
	if item.is_empty():
		return
	pending_world_id = item.id
	show_page("rename")
	rename_field.text = item.name
	rename_field.select_all()
	rename_error.text = ""

func confirm_rename() -> void:
	if not catalog.rename_world(pending_world_id, rename_field.text):
		rename_error.text = catalog.last_error
		return
	cancel_world_action()

func request_delete() -> void:
	var item: Dictionary = catalog.find_world(_selected_world_id())
	if item.is_empty():
		return
	pending_world_id = item.id
	delete_message.text = _detail(["« %s »" % item.name, "Supprimer le monde « %s » ?" % item.name, "Supprimer le monde « %s » ?
Son nom et sa graine seront retirés de la liste." % item.name])
	show_page("delete")

func confirm_delete() -> void:
	if not catalog.delete_world(pending_world_id):
		delete_message.text = catalog.last_error
		return
	cancel_world_action()

func cancel_world_action() -> void:
	var previous_id := pending_world_id
	pending_world_id = ""
	show_page("worlds")
	refresh_world_list(previous_id)

func create_named_world() -> void:
	var item: Dictionary = catalog.create_world(name_field.text, seed_field.text, create_mode)
	if item.is_empty():
		form_error.text = catalog.last_error
		if catalog.last_error.begins_with("La graine"):
			seed_field.grab_focus()
		else:
			name_field.grab_focus()
		return
	open_world(item.id)

func open_selected_world() -> void:
	var selection := world_list.get_selected_items()
	if not selection.is_empty():
		open_world(str(world_list.get_item_metadata(selection[0])))

func open_world(id: String) -> void:
	var item: Dictionary = catalog.find_world(id)
	if item.is_empty() or is_instance_valid(active_world):
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	menu_root.hide()
	page = "playing"
	current_world_id = id
	# Le fond 3D de l'accueil laisse la place au monde (une seule caméra, un seul ciel).
	if showcase.is_inside_tree():
		remove_child(showcase)
	active_world = WorldScene.instantiate()
	active_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	active_world.terrain_seed = item.seed
	active_world.world_name = item.name
	active_world.text_scale = _text_scale()
	var developer: bool = item.get("mode", Catalog.MODE_DEFAULT) == Catalog.MODE_DEVELOPER
	active_world.developer_mode = developer
	active_world.developer_used = item.get("developer_used", developer)
	active_world.world_mode_text = Catalog.MODE_NAMES[Catalog.MODE_DEVELOPER if developer else Catalog.MODE_DEFAULT]
	add_child(active_world)
	shortcut_hints.show()
	# Monde par défaut : réglages ignorés ; monde développeur : réglages globaux.
	active_world.player.apply_settings(settings.world_values(developer))
	active_world.set_coordinates_visible(settings.values.show_coords == "on")
	active_world.player.crouch_toggle = settings.control_options.crouch_mode == "toggle"
	active_world.player.run_mode = settings.control_options.run_mode
	# 0.0.4.15 : vitesses changées en jeu → Attributs → Vitesses actuelles, en direct.
	active_world.player.speeds_changed.connect(_on_player_speeds)
	active_world.player.click_modifiers = Controls.click_modifiers(settings.controls)
	active_world.player.move_blocks = Controls.blocked_moves(settings.controls)
	# Opening from a menu is an explicit request to play immediately.
	active_world.player.resume_controls()

func return_to_worlds() -> void:
	get_tree().paused = false
	if is_instance_valid(active_world):
		active_world.player.release_controls()
		remove_child(active_world)
		active_world.queue_free()
		active_world = null
	current_world_id = ""
	if not showcase.is_inside_tree():
		add_child(showcase)
		showcase.camera.make_current()
	show_page("worlds")

func pause_game() -> void:
	if page != "playing" or not is_instance_valid(active_world):
		return
	active_world.player.release_controls()
	_send_combos(key_combos.release_all())
	get_tree().paused = true
	show_page("pause")

func open_history() -> void:
	if is_instance_valid(active_world):
		return
	var file := FileAccess.open(HISTORY_PATH, FileAccess.READ)
	history_text.text = file.get_as_text() if file != null else "L'historique des versions est indisponible."
	history_scroll.scroll_vertical = 0
	show_page("history")

func _process(_delta: float) -> void:
	if launcher_child != -1 and not OS.is_process_running(launcher_child):
		launcher_child = -1
		get_window().mode = launcher_window_mode
		get_window().grab_focus()
		launcher_status.text = ""
		fill_launcher()

func open_help() -> void:
	if page != "pause" or not is_instance_valid(active_world):
		return
	help_text.text = WorldRules.get_help_text(DETAIL_LEVELS.find(settings.values.text_detail)) + "

Bloc choisi : %s · %d blocs présents." % [WorldRules.BLOCK_NAMES[active_world.player.selected_type], active_world.blocks.size()]
	show_page("help")

func open_world_info() -> void:
	if page != "pause" or not is_instance_valid(active_world):
		return
	info_text.text = active_world.get_world_info_text(DETAIL_LEVELS.find(settings.values.text_detail))
	show_page("world_info")

func resume_game() -> void:
	if page != "pause" or not is_instance_valid(active_world):
		return
	active_world.player.release_controls()
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	menu_root.hide()
	page = "playing"
	get_tree().paused = false
	shortcut_hints.show()
	active_world.player.resume_controls()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	# Paramètres ouverts depuis la pause comptent comme une page de la partie (F1, F2, F3).
	var in_game_pages := ["playing", "pause", "help", "world_info", "settings"] if is_instance_valid(active_world) else ["playing", "pause", "help", "world_info"]
	if page in in_game_pages and event is InputEventKey and event.keycode == KEY_F1:
		return_to_worlds()
		get_viewport().set_input_as_handled()
	elif is_instance_valid(active_world) and page in in_game_pages and event is InputEventKey and event.keycode in [KEY_F2, KEY_F3]:
		if page == "playing":
			pause_game()
		else:
			show_page("pause")
		if event.keycode == KEY_F2:
			open_help()
		else:
			open_world_info()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_cancel_page()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Choix d'une touche (Contrôles) : le prochain appui, clavier ou souris, est pris en entier.
	if not capturing_action.is_empty():
		_capture_control(event)
		return
	if event is InputEventKey or event is InputEventMouseButton:
		_send_combos(key_combos.feed(event, Time.get_ticks_msec()))
	# Un champ de saisie actif garde Échap pour lui : on le reprend pour quitter la page.
	if event.is_action_pressed("ui_cancel") and not event.is_echo() and get_viewport().gui_get_focus_owner() is LineEdit:
		_cancel_page()
		get_viewport().set_input_as_handled()

func _cancel_page() -> void:
	if page == "playing":
		pause_game()
	elif page in ["help", "world_info"]:
		show_page("pause")
	elif page == "pause":
		resume_game()
	elif page in ["rename", "delete", "world_settings"]:
		cancel_world_action()
	elif page == "developer_confirm":
		open_world_settings_for_pending()
	elif page == "settings" and is_instance_valid(active_world):
		leave_settings()
	elif page in ["settings", "information", "history", "launcher"]:
		show_page("home")
	elif page == "create":
		show_page("worlds")
	elif page == "worlds":
		show_page("home")

func _notification(what: int) -> void:
	# Fenêtre quittée : les touches tenues ne seront pas relâchées ici.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_send_combos(key_combos.release_all())
	# Le fond 3D peut être hors de l'arbre pendant une partie : le libérer avec l'application.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(showcase) and not showcase.is_inside_tree():
		showcase.free()
