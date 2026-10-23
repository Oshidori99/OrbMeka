extends Control

const Catalog = preload("res://scripts/world_catalog.gd")
const WorldScene = preload("res://scenes/world.tscn")
const WorldRules = preload("res://scripts/world.gd")
const UserSettings = preload("res://scripts/user_settings.gd")
const Terrain = preload("res://scripts/terrain_generator.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const Controls = preload("res://scripts/controls.gd")
const KeyCombos = preload("res://scripts/key_combos.gd")
const CharacterPreview = preload("res://scripts/character_preview.gd")
const MenuShowcase = preload("res://scripts/menu_showcase.gd")
const Launcher = preload("res://scripts/launcher.gd")
const BackdropShader = preload("res://scripts/menu_backdrop.gdshader")
const MIN_WINDOW_SIZE := Vector2i(800, 450)
const MENU_BASE_SIZE := Vector2(1280, 720)
const MENU_BASE_WIDTH := 560.0
const MENU_MAX_WIDTH_RATIO := 0.7
# Pages de contenu (paramètres, listes, textes) : plus larges, pour moins de lignes et de défilement.
const COMPACT_PAGES := ["home", "pause", "delete", "developer_confirm"]
# Pages larges : réglage Vidéo → Taille des panneaux (72 % par défaut). Les pages compactes
# suivent dans la même proportion. Jamais plus de 95 % de la fenêtre.
const WIDE_MAX_RATIO := 0.95
const COMPACT_MIN_WIDTH := 400.0
const SCROLL_MIN_HEIGHT := 140.0
# Lu à chaque ouverture de l'écran Historique ; inclus dans les exports par addons/history_export.
const HISTORY_PATH := "res://docs/HISTORIQUE.txt"
# Textes à trois niveaux de détail (Paramètres généraux → Synthèse des textes) :
# [−, Par défaut, +] ; « + » garde les textes complets d'avant 0.0.3.3, « − » l'essentiel.
const DETAIL_LEVELS := ["minus", "default", "plus"]
# Catégories de l'écran Attributs, dans l'ordre d'affichage, avec leur texte d'aide.
const ATTRIBUTE_CATEGORIES := {
	"Saut": {"keys": ["jump_height", "jump_speed", "fall_gravity"], "help": ["", "Hauteur, vitesse de montée et retombée du saut.", "Hauteur : sommet visé (1 m = 1 bloc).
Vitesse : départ plus vif ou plus doux ; hauteur conservée.
Gravité de descente : retombée plus ou moins rapide."]},
	"Blocs": {"keys": ["place_ms", "break_ms", "break_reach", "place_reach"], "help": ["", "Rythme et portée de la casse et de la pose.", "Temps entre deux actions au maintien du clic, et distance maximale (en blocs) pour casser et pour poser.
Première action immédiate ; un délai plus court accélère la répétition."]},
	"Marche": {"keys": ["walk_forward", "walk_side", "walk_back"], "help": ["", "Vitesse au sol par direction.", "Vitesse au sol dans chaque direction (1 bloc = 1 m)."]},
	"Courir": {"keys": ["run_forward", "run_side", "run_back"], "help": ["", "Vitesse quand on court.", "En courant (touche de Contrôles maintenue, R par défaut) : vitesse au sol dans chaque direction (1 bloc = 1 m). Se baisser l'emporte sur courir."]},
	"Se baisser": {"keys": ["crouch_forward", "crouch_side", "crouch_back", "crouch_gravity"], "help": ["", "Vitesses et chute quand on se baisse.", "En se baissant (touche de Contrôles) : vitesse dans chaque direction, et gravité de chute, plus forte pour tomber plus vite."]},
	"Changer de vitesse": {"keys": ["speed_max", "speed_min", "speed_up_rate", "speed_down_rate"], "help": ["", "Plus vite (↑) et moins vite (↓) : limites et rapidité.", "Plus vite (↑) et Moins vite (↓), maintenus : la marche et la course changent ensemble, peu à peu, en % de leur vitesse normale (la course reste plus rapide que la marche). La vitesse choisie reste jusqu'au prochain changement. Rapidités : % gagnés ou perdus par seconde. Se baisser n'est pas touché."]},
	"Vue": {"keys": ["eye_height"], "help": ["", "Hauteur de la vue, en blocs.", "Hauteur des yeux au-dessus des pieds, en blocs : 1 = vue à un bloc du sol, 2 = à deux blocs. Deux décimales possibles (ex. 1,9 ou 2,15)."]},
}
# Réglages généraux (tous les mondes, quel que soit leur mode), par section du menu latéral.
const GENERAL_CATEGORIES := {
	"general": {
		"Souris": {"keys": ["mouse_sensitivity"], "help": ["", "Rotation de la vue.", "Vitesse de rotation de la vue."]},
		"Textes": {"keys": ["text_detail"], "help": ["", "Détail des explications.", "Quantité de détails dans les explications : − l'essentiel, + tout."]},
	},
	"video": {
		"Panneaux": {"keys": ["panel_size", "nav_percent"], "help": ["", "Largeur des menus et de la colonne d'onglets.", "Largeur des menus ; le menu de gauche est la colonne d'onglets."]},
		"Zones": {"keys": ["element_scale"], "help": ["", "Boutons, champs, marges et espaces.", "Taille des boutons, des zones de saisie, des marges et des espaces des menus, sans changer le texte, qui reste toujours dans sa zone."]},
		"Texte": {"keys": ["text_px"], "help": ["", "Taille des textes.", "Taille de tous les textes, menus et jeu (13 px par défaut ; 18 px : taille d'avant 0.0.3.10)."]},
		"Apparence": {"keys": ["theme_mode", "menu_depth"], "help": ["", "Couleurs et encadrés des menus.", "Thème de couleurs des menus. Profondeur : contenu dans des encadrés creusés sous le titre."]},
		"Jeu": {"keys": ["fov", "show_coords"], "help": ["", "Champ de vision et coordonnées en partie.", "Champ de vision de la caméra en partie, en degrés (75° : vue d'origine). Coordonnées en blocs, en haut à droite : X largeur, Y hauteur des pieds (0 sur le sol plat), Z longueur."]},
	},
}
# Menu latéral de Paramètres : sections dans l'ordre des boutons ; la première s'ouvre par défaut.
const SETTINGS_SECTIONS := {"general": "Paramètres généraux", "video": "Vidéo", "controls": "Contrôles", "character": "Personnage", "attributes": "Attributs"}
const CATEGORY_GAP := 22.0
const SLIDER_WIDTH := 150.0

var settings: RefCounted
var setting_fields: Dictionary = {}
var setting_resets: Dictionary = {}
var category_resets: Dictionary = {}
var settings_reset_all_button: Button
var settings_tabs: Dictionary = {}
var settings_sections: Dictionary = {}
var settings_section := "general"
var settings_nav: VBoxContainer
var font_sizes: Dictionary = {}
# Tailles et espaces de base des menus, mis à l'échelle par Taille des zones et boutons.
var scaled_sizes: Dictionary = {}
var scaled_separations: Dictionary = {}
# Réglages de taille des menus réellement affichés (0.0.3.11) : enregistrés aussitôt dans
# settings, mais appliqués seulement en quittant Paramètres ou avec le bouton Appliquer.
const LAYOUT_KEYS := ["panel_size", "nav_percent", "element_scale", "text_px"]
var layout_values: Dictionary = {}
var layout_apply_button: Button
# Contrôles (0.0.3.12) : bouton de touche et ↻ par action ; action en attente d'une touche.
var control_buttons: Dictionary = {}
var control_resets: Dictionary = {}
var controls_reset_all_button: Button
var capturing_action := ""
# 0.0.3.27 : deuxième touche (bouton et ✕ par action), choix de la deuxième touche en cours,
# nom de l'action avec « double appui » ou « en même temps », suivi des appuis à deux touches.
var control_second_buttons: Dictionary = {}
var control_second_clears: Dictionary = {}
var control_labels: Dictionary = {}
var capturing_second := false
var key_combos := KeyCombos.new()
var character_previews: Dictionary = {}
# Cartes du menu Personnage (0.0.3.22) : « boy9:light »… pour les humains, « cat », « fox »… pour les animaux.
var character_buttons: Dictionary = {}
var control_option_buttons: Dictionary = {}
# Réglages à choix : boutons par option, et choix en cours (enregistré aussitôt).
var choice_buttons: Dictionary = {}
var choice_values: Dictionary = {}
# 0.0.3.7 : barres des réglages chiffrés, interrupteurs des choix Oui / Non.
var setting_sliders: Dictionary = {}
var choice_switches: Dictionary = {}
# Textes fixes à trois niveaux de détail : label → [−, Par défaut, +].
var detail_labels: Dictionary = {}
var menu_scroll: ScrollContainer
var menu_stack: VBoxContainer
var fit_queued := false
# Marge entre le panneau et les bords haut et bas de la fenêtre.
const WINDOW_MARGIN := 12.0
var settings_message: RichTextLabel

var catalog: RefCounted
var page := "home"
var active_world: Node3D
var current_world_id := ""
var menu_root: Control
var menu_panel: PanelContainer
var menu_reserved_heights: Dictionary = {}
var pages: Dictionary = {}
var world_list: ItemList
var open_button: Button
var list_message: RichTextLabel
var name_field: LineEdit
var seed_field: LineEdit
var world_options_title: RichTextLabel
var duplicate_button: Button
var world_settings_button: Button
var world_settings_text: RichTextLabel
var world_settings_back_button: Button
# Mode du monde : choix à la création, passage définitif au mode développeur ensuite.
var create_mode: String = Catalog.MODE_DEFAULT
var create_default_button: Button
var create_developer_button: Button
var create_mode_note: RichTextLabel
var world_developer_button: Button
var developer_confirm_message: RichTextLabel
var developer_confirm_button: Button
var developer_cancel_button: Button
var form_error: RichTextLabel
var shortcut_hints: Label
var play_button: Button
var settings_button: Button
var information_button: Button
var history_button: Button
# Launcher (0.0.4) : bouton de l'accueil, page des versions, travail en fond (gh), version ouverte.
var launcher_button: Button
var quit_button: Button
var launcher := Launcher.new()
var launcher_status: RichTextLabel
var launcher_latest_button: Button
var launcher_arrow_button: Button
var launcher_played_title: RichTextLabel
var launcher_played: VBoxContainer
var launcher_played_buttons: Dictionary = {}
var launcher_screen: ColorRect
var launcher_list: VBoxContainer
var launcher_scroll: ScrollContainer
var launcher_back_button: Button
var launcher_play_buttons: Dictionary = {}
var launcher_thread: Thread
var launcher_child := -1
# Faux : ne pas interroger GitHub (tests).
var launcher_online := true
var launcher_window_mode := Window.MODE_WINDOWED
var history_back_button: Button
var history_text: RichTextLabel
var history_scroll: ScrollContainer
var settings_back_button: Button
var information_back_button: Button
var generation_info: RichTextLabel
var create_button: Button
var new_world_button: Button
var rename_button: Button
var delete_button: Button
var rename_field: LineEdit
var rename_error: RichTextLabel
var delete_message: RichTextLabel
var cancel_delete_button: Button
var pending_world_id := ""
var resume_button: Button
var pause_settings_button: Button
var attributes_gate: VBoxContainer
var attributes_gate_text: RichTextLabel
var attributes_gate_button: Button
var attributes_gate_confirm: Button
var attributes_gate_cancel: Button
var attributes_scroll: ScrollContainer
var how_button: Button
var help_back_button: Button
var help_text: RichTextLabel
var home_version: RichTextLabel
var pause_version: RichTextLabel
var info_button: Button
var info_back_button: Button
var info_text: RichTextLabel
var showcase: Node3D
var backdrop: ColorRect
var news_label: RichTextLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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

func _button(text: String, parent: Node, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	_min_size(button, Vector2(0, 40))
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func _icon_button(icon: String, label: String, parent: Node, action: Callable) -> Button:
	# Bouton compact à icône ; le nom de l'action reste dans l'infobulle et pour l'accessibilité.
	var button := _button(icon, parent, action)
	_min_size(button, Vector2(58, 0))
	button.tooltip_text = label
	button.accessibility_name = label
	_font_size(button, 22)
	return button

# Textes des menus : sélectionnables à la souris, copiables (Ctrl+C ou clic droit → Copier).
func _text_label() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.fit_content = true
	label.scroll_active = false
	label.selection_enabled = true
	label.context_menu_enabled = true
	label.focus_mode = Control.FOCUS_CLICK
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label

# Tailles particulières : suivent le réglage Vidéo → Taille du texte.
func _font_size(control: Control, base: int) -> void:
	var item := "normal_font_size" if control is RichTextLabel else "font_size"
	font_sizes[control] = [item, base]
	control.add_theme_font_size_override(item, UiTheme.scaled(base, _text_scale()))

func _text_scale() -> float:
	return layout_values.text_px / UserSettings.BASE_TEXT_PX

func _build_theme() -> Theme:
	return UiTheme.build(_text_scale(), settings.values.theme_mode, settings.values.menu_depth == "on", _element_scale())

# Taille des zones et boutons (0.0.3.10) : marges, espaces, hauteurs et largeurs minimales,
# sans changer le texte. Les zones ne descendent jamais sous la taille de leur texte.
func _element_scale() -> float:
	return layout_values.element_scale / 100.0

func _min_size(control: Control, base: Vector2) -> void:
	# Une seule dimension donnée (0 pour l'autre) : l'autre déjà enregistrée est gardée.
	var previous: Vector2 = scaled_sizes.get(control, Vector2.ZERO)
	scaled_sizes[control] = Vector2(base.x if base.x > 0.0 else previous.x, base.y if base.y > 0.0 else previous.y)
	control.custom_minimum_size = scaled_sizes[control] * _element_scale()

func _sep(container: Control, base: int) -> void:
	scaled_separations[container] = base
	container.add_theme_constant_override("separation", roundi(base * _element_scale()))

# Taille du texte, thème, profondeur et taille des zones : appliqués à tous les menus, immédiatement.
func apply_appearance() -> void:
	menu_root.theme = _build_theme()
	for control in scaled_sizes:
		control.custom_minimum_size = scaled_sizes[control] * _element_scale()
	for container in scaled_separations:
		container.add_theme_constant_override("separation", roundi(scaled_separations[container] * _element_scale()))
	for control in font_sizes:
		control.add_theme_font_size_override(font_sizes[control][0], UiTheme.scaled(font_sizes[control][1], _text_scale()))
	var colors := UiTheme.palette(settings.values.theme_mode)
	news_label.add_theme_color_override("default_color", colors.section)
	form_error.add_theme_color_override("default_color", colors.error)
	_refresh_details()

# Texte choisi selon Synthèse des textes ; « − » peut être vide (texte masqué).
func _detail(variants: Array) -> String:
	return variants[DETAIL_LEVELS.find(settings.values.text_detail)]

func _refresh_details() -> void:
	for label in detail_labels:
		label.text = _detail(detail_labels[label])
		label.visible = not label.text.is_empty()

func _explanation(parent: Node, text: Variant) -> void:
	# text : chaîne fixe, ou [−, Par défaut, +] selon Synthèse des textes.
	var label := _text_label()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	if text is Array:
		detail_labels[label] = text
		label.text = _detail(text)
		label.visible = not label.text.is_empty()
	else:
		label.text = text

func _add_setting_row(parent: Node, key: String) -> void:
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
	var inset := PanelContainer.new()
	inset.theme_type_variation = "OrbInsetDeep"
	box.add_child(inset)
	var list := VBoxContainer.new()
	_sep(list, 10)
	inset.add_child(list)
	_explanation(list, ["", "Cliquez une touche puis appuyez sur la nouvelle. Échap : aucune. 2e touche facultative.", "Cliquez le bouton d'une action, puis appuyez sur la touche ou le bouton de souris voulu (molette comprise). Échap : aucune touche. Deuxième touche facultative : la même touche = double appui (deux appuis rapprochés) ; une autre touche = les deux en même temps (par exemple Maj + Z). ✕ la retire. Les flèches ← → restent toujours actives pour aller de côté ; ↑ ↓ changent la vitesse. F1, F2, F3 et Échap sont réservées."])
	for action in Controls.ACTIONS:
		var row := HBoxContainer.new()
		_sep(row, 10)
		list.add_child(row)
		var label := _text_label()
		label.text = Controls.ACTIONS[action].label
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		control_labels[action] = label
		var key_button := _button("", row, func(): start_control_capture(action))
		_min_size(key_button, Vector2(170, 0))
		key_button.tooltip_text = "Changer la touche : " + Controls.ACTIONS[action].label
		control_buttons[action] = key_button
		var second_button := _button("", row, func(): start_control_capture(action, true))
		_min_size(second_button, Vector2(130, 0))
		second_button.tooltip_text = "Deuxième touche (même touche : double appui ; autre touche : en même temps) : " + Controls.ACTIONS[action].label
		control_second_buttons[action] = second_button
		var clear := _button("✕", row, func(): clear_second_key(action))
		_min_size(clear, Vector2(42, 0))
		clear.tooltip_text = "Retirer la deuxième touche : " + Controls.ACTIONS[action].label
		control_second_clears[action] = clear
		var reset := _button("↻", row, func(): reset_control(action))
		_min_size(reset, Vector2(42, 0))
		reset.tooltip_text = "Rétablir : " + Controls.label(Controls.default_for(action))
		control_resets[action] = reset
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
		_explanation(options, spec.help)
		var row := HBoxContainer.new()
		_sep(row, 10)
		options.add_child(row)
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

func _refresh_character_cards() -> void:
	var id: String = choice_values.get("character", UserSettings.CHOICES.character.default)
	var skin: String = choice_values.get("skin", UserSettings.CHOICES.skin.default)
	var selected := id + ":" + skin if CharacterPreview.is_human(id) else id
	for card_id in character_buttons:
		character_buttons[card_id].set_pressed_no_signal(card_id == selected)

func _refresh_controls() -> void:
	for action in control_buttons:
		var binding: Dictionary = settings.controls[action]
		control_buttons[action].text = Controls.part_label(Controls.first(binding))
		var second: Dictionary = Controls.second(binding)
		control_second_buttons[action].text = "2e touche…" if second.is_empty() else Controls.part_label(second)
		control_second_buttons[action].disabled = Controls.kind(binding) == "none"
		control_second_clears[action].disabled = second.is_empty()
		var how: String = {"double": " — double appui", "together": " — en même temps"}.get(Controls.kind(binding), "")
		control_labels[action].text = Controls.ACTIONS[action].label + how
	for option in control_option_buttons:
		for choice in control_option_buttons[option]:
			control_option_buttons[option][choice].set_pressed_no_signal(settings.control_options[option] == choice)

func start_control_capture(action: String, second := false) -> void:
	_refresh_controls()
	capturing_action = action
	capturing_second = second
	if second:
		control_second_buttons[action].text = "Appuyez…"
		settings_message.text = "%s : deuxième touche. La même = double appui, une autre = en même temps. Échap : la retirer." % Controls.ACTIONS[action].label
	else:
		control_buttons[action].text = "Appuyez sur une touche…"
		settings_message.text = "%s : appuyez sur une touche ou un bouton de souris. Échap : aucune." % Controls.ACTIONS[action].label

func clear_second_key(action: String) -> void:
	set_control(action, Controls.first(settings.controls[action]))

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
	# Nouvelle première touche : la deuxième reste ; Échap sur la première retire tout.
	var current: Dictionary = settings.controls[capturing_action]
	if capturing_second:
		set_control(capturing_action, Controls.combine(Controls.first(current), part))
	else:
		set_control(capturing_action, Controls.combine(part, Controls.second(current)))

func set_control(action: String, binding: Dictionary) -> void:
	capturing_action = ""
	capturing_second = false
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
	_explanation(parent, data.help)
	for key in data.keys:
		_add_setting_row(parent, key)

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
	if confirming:
		attributes_gate_text.text = "Attention : ce choix est irréversible.
Ce monde passera en mode développeur, sans retour possible au mode par défaut."
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
	active_world.developer_mode = true
	active_world.world_mode_text = Catalog.MODE_NAMES[Catalog.MODE_DEVELOPER]
	_apply_to_game()
	_show_attributes_gate(false)
	settings_message.text = "Monde passé en mode développeur : attributs modifiables."

# En partie, les réglages s'appliquent tout de suite au joueur et aux textes du jeu.
func _apply_to_game() -> void:
	if not is_instance_valid(active_world):
		return
	active_world.player.apply_settings(settings.world_values(active_world.developer_mode))
	active_world.apply_text_scale(_text_scale())
	active_world.set_coordinates_visible(settings.values.show_coords == "on")
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

# Page : titre sur le panneau, puis contenu « plus profond » dans un encadré creusé.
# Renvoie le contenu ; la page entière (titre compris) est _page_root(contenu).
func _page(parent: Node, heading: String) -> VBoxContainer:
	var root := VBoxContainer.new()
	_sep(root, 12)
	parent.add_child(root)
	var title := _text_label()
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "OrbTitle"
	root.add_child(title)
	var inset := PanelContainer.new()
	inset.theme_type_variation = "OrbInset"
	root.add_child(inset)
	var box := VBoxContainer.new()
	_sep(box, 16)
	inset.add_child(box)
	box.set_meta("page_root", root)
	return box

func _page_root(content: VBoxContainer) -> VBoxContainer:
	return content.get_meta("page_root")

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
	quit_button = _button("Quitter le jeu", home, func(): get_tree().quit())
	quit_button.visible = not OS.has_feature("web")
	# 0.0.4.1 : écran à part (gris, sans le monde derrière). De haut en bas : Retour au jeu,
	# dernières versions jouées (la plus récente en bas), gros bouton vert Jouer (dernière
	# version) avec ▼ qui déplie toutes les versions en dessous, la dernière tout en bas.
	var launcher_page := _page(stack, "OrbMeka — Launcher")
	pages.launcher = _page_root(launcher_page)
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
	_sep(launcher_played, 6)
	launcher_page.add_child(launcher_played)
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
	launcher_scroll = ScrollContainer.new()
	launcher_scroll.custom_minimum_size = Vector2(0, 260)
	menu_reserved_heights[launcher_scroll] = 200.0
	launcher_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	launcher_page.add_child(launcher_scroll)
	launcher_list = VBoxContainer.new()
	launcher_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sep(launcher_list, 6)
	launcher_scroll.add_child(launcher_list)
	launcher_scroll.visible = false
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
	# proposition de passer le monde en mode développeur, avec avertissement « sans retour ».
	attributes_gate = VBoxContainer.new()
	_sep(attributes_gate, 10)
	attributes_box.add_child(attributes_gate)
	attributes_gate_text = _text_label()
	attributes_gate_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attributes_gate.add_child(attributes_gate_text)
	attributes_gate_button = _button("Passer ce monde en mode développeur…", attributes_gate, request_game_developer_mode)
	attributes_gate_confirm = _button("Confirmer : mode développeur définitif", attributes_gate, confirm_game_developer_mode)
	attributes_gate_cancel = _button("Annuler", attributes_gate, func(): _show_attributes_gate(false))
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
	world_settings_back_button = _button("Retour", world_settings_page, cancel_world_action)
	var developer_page := _page(stack, "Passer en mode développeur ?")
	pages.developer_confirm = _page_root(developer_page)
	developer_confirm_message = _text_label()
	developer_confirm_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	developer_page.add_child(developer_confirm_message)
	developer_confirm_button = _button("Confirmer : mode développeur définitif", developer_page, confirm_developer_mode)
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
F3 : Informations du monde"
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

func fit_menus_to_window() -> void:
	if not is_inside_tree():
		return
	# Taille de base : 1280 × 720. Accueil et pause restent compacts ; les pages de contenu
	# prennent la plupart de la largeur, et leurs zones défilantes toute la hauteur libre
	# (hauteur de la fenêtre moins la place réservée au reste de la page).
	var view := get_viewport().get_visible_rect().size
	var grow := maxf(1.0, view.x / MENU_BASE_SIZE.x)
	var ratio: float = layout_values.panel_size / 100.0
	var limit := view.x * WIDE_MAX_RATIO
	if page in COMPACT_PAGES:
		var scale: float = layout_values.panel_size / UserSettings.SPECS.panel_size.default
		menu_panel.custom_minimum_size.x = minf(maxf(COMPACT_MIN_WIDTH, minf(MENU_BASE_WIDTH * grow, view.x * MENU_MAX_WIDTH_RATIO) * scale), limit)
	else:
		menu_panel.custom_minimum_size.x = minf(maxf(view.x * ratio, MENU_BASE_WIDTH), limit)
	settings_nav.custom_minimum_size.x = menu_panel.custom_minimum_size.x * layout_values.nav_percent / 100.0
	for control in menu_reserved_heights:
		control.custom_minimum_size.y = maxf(SCROLL_MIN_HEIGHT, view.y - menu_reserved_heights[control])
	_fit_height()

func _fit_height() -> void:
	# Hauteur du panneau : son contenu, sans dépasser la fenêtre ; au-delà, il défile.
	var view := get_viewport().get_visible_rect().size
	var frame: float = menu_panel.get_theme_stylebox("panel").get_minimum_size().y
	var available := maxf(SCROLL_MIN_HEIGHT, view.y - frame - 2.0 * WINDOW_MARGIN)
	menu_scroll.custom_minimum_size.y = minf(menu_stack.get_combined_minimum_size().y, available)

func _queue_fit() -> void:
	# Le contenu a changé de taille (texte replié, page changée) : réajuster une fois, plus tard.
	if fit_queued:
		return
	fit_queued = true
	(func():
		fit_queued = false
		_fit_height()).call_deferred()

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
		panel_box.set_content_margin_all(24)
		menu_panel.add_theme_stylebox_override("panel", panel_box)
	else:
		menu_panel.remove_theme_stylebox_override("panel")
	get_window().title = "OrbMeka — Launcher" if outside else str(ProjectSettings.get_setting("application/config/name", "OrbMeka"))

func show_page(next_page: String) -> void:
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
	var plus := "Attributs modifiables dans Paramètres → Attributs. Ce choix est définitif." if developer else "Attributs par défaut, non modifiables."
	world_settings_text.text = _detail(["« %s » · Mode : %s" % [item.name, mode_name], "Monde : %s
Mode : %s" % [item.name, mode_name], "Monde : %s
Mode : %s
%s" % [item.name, mode_name, plus]])
	world_developer_button.visible = not developer
	show_page("world_settings")

func request_developer_mode() -> void:
	var item: Dictionary = catalog.find_world(pending_world_id)
	if item.is_empty() or item.get("mode", Catalog.MODE_DEFAULT) == Catalog.MODE_DEVELOPER:
		return
	# Toujours « irréversible », quel que soit le niveau de détail.
	developer_confirm_message.text = _detail(["« %s » : irréversible." % item.name, "« %s » passera en mode développeur.
Choix irréversible : aucun retour au mode par défaut." % item.name, "Le monde « %s » utilisera les attributs de Paramètres → Attributs.
Attention : ce choix est irréversible. Le retour au mode par défaut sera impossible." % item.name])
	show_page("developer_confirm")

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
	active_world.world_mode_text = Catalog.MODE_NAMES[Catalog.MODE_DEVELOPER if developer else Catalog.MODE_DEFAULT]
	add_child(active_world)
	shortcut_hints.show()
	# Monde par défaut : réglages ignorés ; monde développeur : réglages globaux.
	active_world.player.apply_settings(settings.world_values(developer))
	active_world.set_coordinates_visible(settings.values.show_coords == "on")
	active_world.player.crouch_toggle = settings.control_options.crouch_mode == "toggle"
	active_world.player.run_mode = settings.control_options.run_mode
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

# Launcher (0.0.4) : versions des Releases GitHub, groupées par 0.0.x, avec leur nom.
# refresh = false : garder la liste déjà connue (tests, sans GitHub).
func open_launcher(refresh := true) -> void:
	if is_instance_valid(active_world):
		return
	show_page("launcher")
	show_all_versions(false)
	# La version ouverte compte comme jouée (en bas de la liste des dernières versions jouées).
	if Launcher.supported():
		Launcher.note_played(Launcher.current_version())
	if not Launcher.supported():
		launcher_status.text = "Le launcher fonctionne seulement dans la version Windows."
	elif refresh and launcher_online and launcher_thread == null:
		launcher_status.text = "Recherche des versions…"
		_launcher_work(func(): return launcher.refresh(), func(_ok): fill_launcher())
		return
	fill_launcher()

func fill_launcher() -> void:
	_clear_launcher_rows(launcher_list)
	_clear_launcher_rows(launcher_played)
	launcher_play_buttons.clear()
	launcher_played_buttons.clear()
	var current := Launcher.current_version()
	var busy := launcher_thread != null or launcher_child != -1
	if not launcher.error.is_empty():
		launcher_status.text = launcher.error
	elif Launcher.supported() and not busy:
		launcher_status.text = "Version ouverte : %s. Les versions sont installées dans les données du jeu (AppData)." % current
	var names := {}
	for item in launcher.versions:
		names[item.version] = item.name
	# Dernières versions jouées : la plus récente en bas.
	var played := Launcher.played()
	launcher_played_title.visible = not played.is_empty()
	# Place laissée au reste de la page (titre, versions jouées, Jouer) : la liste ▼ tient dans la fenêtre.
	menu_reserved_heights[launcher_scroll] = 340.0 + 40.0 * played.size()
	fit_menus_to_window()
	for version in played:
		launcher_played_buttons[version] = _launcher_row(launcher_played, version, names.get(version, ""), busy)
	# Gros bouton : toujours la dernière version.
	launcher_latest_button.disabled = launcher.versions.is_empty() or busy
	launcher_arrow_button.disabled = launcher.versions.is_empty()
	if launcher.versions.is_empty():
		launcher_latest_button.text = "▶ Jouer"
	else:
		var latest: Dictionary = launcher.versions[0]
		launcher_latest_button.text = "▶ Jouer — " + latest.version + (" · " + latest.name if not latest.name.is_empty() else "")
	# Toutes les versions (▼), de la plus ancienne à la dernière, tout en bas ; groupes 0.0.x espacés.
	var group := ""
	for index in range(launcher.versions.size() - 1, -1, -1):
		var item: Dictionary = launcher.versions[index]
		if Launcher.group_of(item.version) != group:
			group = Launcher.group_of(item.version)
			if launcher_list.get_child_count() > 0:
				var gap := Control.new()
				_min_size(gap, Vector2(0, CATEGORY_GAP))
				launcher_list.add_child(gap)
			var heading := _text_label()
			heading.text = group
			heading.theme_type_variation = "OrbSection"
			launcher_list.add_child(heading)
		launcher_play_buttons[item.version] = _launcher_row(launcher_list, item.version, item.name, busy)
	if launcher_scroll.visible:
		_scroll_launcher_to_latest()

# Ligne « 0.0.3.27 — Nom » et son bouton (Ouverte, Jouer ou Installer et jouer).
func _launcher_row(parent: Node, version: String, version_name: String, busy: bool) -> Button:
	var row := HBoxContainer.new()
	_sep(row, 10)
	parent.add_child(row)
	var label := _text_label()
	label.text = version + (" — " + version_name if not version_name.is_empty() else "")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var text := "Ouverte" if version == Launcher.current_version() else ("Jouer" if not Launcher.executable(version).is_empty() else "Installer et jouer")
	var button := _button(text, row, func(): play_version(version))
	button.theme_type_variation = "OrbLauncherButton"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_min_size(button, Vector2(170, 0))
	button.disabled = busy or not Launcher.supported()
	return button

func _clear_launcher_rows(container: Node) -> void:
	for child in container.get_children():
		for node in [child] + child.find_children("*", "Control", true, false):
			scaled_sizes.erase(node)
			scaled_separations.erase(node)
			font_sizes.erase(node)
		container.remove_child(child)
		child.queue_free()

# ▼ : déplie (ou replie) toutes les versions sous le bouton Jouer, la dernière visible en bas.
func show_all_versions(open: bool) -> void:
	launcher_arrow_button.set_pressed_no_signal(open)
	launcher_scroll.visible = open
	_queue_fit()
	if open:
		_scroll_launcher_to_latest()

func _scroll_launcher_to_latest() -> void:
	(func():
		await get_tree().process_frame
		launcher_scroll.scroll_vertical = int(launcher_scroll.get_v_scroll_bar().max_value)).call()

func play_latest_version() -> void:
	if not launcher.versions.is_empty():
		play_version(launcher.versions[0].version)

# La version ouverte : retour à l'accueil. Une autre : installée au besoin, puis lancée ;
# cette fenêtre se réduit et revient quand l'autre version est fermée.
func play_version(version: String) -> void:
	if version == Launcher.current_version():
		show_page("home")
		return
	if launcher_thread != null or launcher_child != -1 or not Launcher.supported():
		return
	if Launcher.executable(version).is_empty():
		launcher_status.text = "Téléchargement de %s…" % version
		_launcher_work(func(): return launcher.install(version), func(ok): _start_version(version) if ok else fill_launcher())
		fill_launcher()
		return
	_start_version(version)

func _start_version(version: String) -> void:
	var pid := Launcher.launch(version)
	if pid == -1:
		launcher_status.text = "Impossible de lancer la version %s." % version
		fill_launcher()
		return
	Launcher.note_played(version)
	launcher_child = pid
	launcher_status.text = "Version %s ouverte : fermez-la pour revenir ici." % version
	fill_launcher()
	launcher_window_mode = get_window().mode
	get_window().mode = Window.MODE_MINIMIZED

# Travail long (gh, décompression) dans un fil à part ; done(résultat) ensuite, ici.
func _launcher_work(work: Callable, done: Callable) -> void:
	launcher_thread = Thread.new()
	launcher_thread.start(func():
		var ok: bool = work.call()
		call_deferred("_launcher_finished", done, ok))

func _launcher_finished(done: Callable, ok: bool) -> void:
	launcher_thread.wait_to_finish()
	launcher_thread = null
	done.call(ok)

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
