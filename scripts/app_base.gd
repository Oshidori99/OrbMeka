extends Control
# Menus du jeu, partie 1 sur 5 (0.0.4.21 : app.gd découpé, chaque partie s'appuie sur la précédente) :
# constantes, variables, outils d'interface (boutons, textes, tailles), sons et voix, titres repliables,
# ajustement à la fenêtre. Suite : app_controls.gd, app_launcher.gd, app_settings.gd, app.gd.

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
const Licences = preload("res://scripts/licences.gd")
const MenuSounds = preload("res://scripts/menu_sounds.gd")
const CharacterVoices = preload("res://scripts/character_voices.gd")
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
	"Voler": {"keys": ["fly_forward", "fly_side", "fly_back", "fly_run_forward", "fly_run_side", "fly_run_back", "fly_up", "fly_down"], "groups": {"Normal": ["fly_forward", "fly_side", "fly_back"], "Rapide": ["fly_run_forward", "fly_run_side", "fly_run_back"], "Monter et descendre": ["fly_up", "fly_down"]}, "help": ["", "Vitesses en vol, et en volant vite.", "En vol (touche de Contrôles, Espace deux fois par défaut) : vitesse dans chaque direction, en volant vite (touche Courir, R par défaut, avec son mode), et pour monter (touche Sauter) ou descendre (touche Se baisser). Pas de gravité en vol."]},
	"Changer de vitesse": {"keys": ["speed_max", "speed_min", "speed_up_rate", "speed_down_rate"], "help": ["", "↑ ↓ + touche : vitesses ; ⌫ : par défaut. Limites et rapidité.", "↑ ou ↓ maintenue avec A : tout le déplacement (marche, course, baissé, vol) plus ou moins vite, peu à peu, en % de la vitesse normale ; avec W : la marche seule ; avec R : la course seule ; avec clic gauche ou droit : la casse ou la pose (mode développeur seulement). ⌫ + la même touche : cette valeur par défaut ; ⌫ deux fois : tout par défaut. Vitesse maximale et minimale : limites en mode développeur (monde par défaut : 75 à 150 %). Rapidités : % gagnés ou perdus par seconde."]},
	"Vitesses actuelles": {"keys": ["current_speed", "current_walk", "current_run", "current_break", "current_place"], "help": ["", "Où en sont les vitesses, en direct.", "Position actuelle des vitesses réglées en jeu avec ↑ ↓ (+ A : déplacement, + W : marche, + R : course, + clic : casse ou pose), en % de la normale. Les barres bougent en direct ; on peut aussi les régler ici. Gardées dans les limites de Changer de vitesse."]},
	"Vue": {"keys": ["eye_height"], "help": ["", "Hauteur de la vue, en blocs.", "Hauteur des yeux au-dessus des pieds, en blocs : 1 = vue à un bloc du sol, 2 = à deux blocs. Deux décimales possibles (ex. 1,9 ou 2,15)."]},
}
# Réglages généraux (tous les mondes, quel que soit leur mode), par section du menu latéral.
const GENERAL_CATEGORIES := {
	"general": {
		"Souris": {"keys": ["mouse_sensitivity"], "help": ["", "Rotation de la vue.", "Vitesse de rotation de la vue."]},
		"Son": {"keys": ["menu_volume", "character_volume"], "help": ["", "Volume des menus et des personnages.", "Volume des petits sons des menus (survol, clic, retour), et des voix et cris des personnages quand on les choisit ; 0 = muet. Voix : synthèse vocale de l'ordinateur (rien n'est enregistré)."]},
		"Textes": {"keys": ["text_detail"], "help": ["", "Détail des explications.", "Quantité de détails dans les explications : − l'essentiel, + tout."]},
	},
	"video": {
		# 0.0.5.8 : réglages du jeu en premier (demande de l'utilisateur).
		"Jeu": {"keys": ["fov", "view_distance", "far_distance", "grass_density", "grass_zones", "show_coords"], "help": ["", "Champ de vision, distance d'affichage et coordonnées en partie.", "Champ de vision de la caméra en partie, en degrés (75° : vue d'origine). Distance d’affichage : nombre de zones de 8 m affichées autour du joueur, comptées à l'horizontale (le sol reste visible même très haut ; moins = plus rapide, surtout sur le Web). Distance lointaine : au-delà, relief simplifié (sans herbe) jusqu'à cette distance, pour voir loin sans ralentir (0 : rien). Densité de l'herbe : nombre de brins (appliquée à la prochaine ouverture d'un monde). Distance d’affichage de l’herbe : en zones de 8 m, appliquée immédiatement. Coordonnées en blocs, en haut à droite : X largeur, Y hauteur des pieds (0 sur le sol plat), Z longueur."]},
		"Panneaux": {"keys": ["panel_size", "nav_percent"], "help": ["", "Largeur des menus et de la colonne d'onglets.", "Largeur des menus ; le menu de gauche est la colonne d'onglets."]},
		"Zones": {"keys": ["element_scale"], "help": ["", "Boutons, champs, marges et espaces.", "Taille des boutons, des zones de saisie, des marges et des espaces des menus, sans changer le texte, qui reste toujours dans sa zone."]},
		"Texte": {"keys": ["text_px"], "help": ["", "Taille des textes.", "Taille de tous les textes, menus et jeu (13 px par défaut ; 18 px : taille d'avant 0.0.3.10)."]},
		"Apparence": {"keys": ["theme_mode", "menu_depth"], "help": ["", "Couleurs et encadrés des menus.", "Thème de couleurs des menus. Profondeur : contenu dans des encadrés creusés sous le titre."]},
	},
}
# Menu latéral de Paramètres : sections dans l'ordre des boutons ; la première s'ouvre par défaut.
const SETTINGS_SECTIONS := {"general": "Paramètres généraux", "video": "Vidéo", "controls": "Contrôles", "character": "Personnage", "attributes": "Attributs", "licences": "Licences"}
# 0.0.4.16 : plus d'espace entre catégories, moins entre les lignes (séparées par un trait fin).
const CATEGORY_GAP := 30.0
const ROW_GAP := 4
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
# 0.0.4.20 : bloc de chaque action, liaison en cours de modification, touches (case → bouton), +,
# options dépliées, parties, et la recherche (mode, texte, Conflits).
var control_action_boxes: Dictionary = {}
var control_pending: Dictionary = {}
var control_slot_buttons: Dictionary = {}
var control_more_buttons: Dictionary = {}
var control_expanded: Dictionary = {}
var control_group_bodies: Dictionary = {}
var capturing_slot: Array = []
var controls_search: LineEdit
var controls_search_keys: LineEdit
var controls_search_group: LineEdit
var controls_conflicts_button: Button
var controls_conflicts_text: RichTextLabel
# Parties de Contrôles (0.0.4.8) : titres, et touches réservées de la partie Menus.
var control_group_labels: Dictionary = {}
var control_group_resets: Dictionary = {}
var appearance_key: Array = []
var control_menu_buttons: Dictionary = {}
# Titres repliables de Paramètres (0.0.4.14) : clé → {"title", "body", "text"}.
var fold_entries: Dictionary = {}
var fold_collapse_button: Button
var fold_expand_button: Button
var fold_open_button: Button
const FOLD_OPEN_MODES := {"last": "À l'ouverture : comme la dernière fois", "expanded": "À l'ouverture : tout développé", "collapsed": "À l'ouverture : tout réduit"}
var control_labels: Dictionary = {}
var key_combos := KeyCombos.new()
var menu_sounds: Node
var character_voices: Node
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
# Rappel JavaScript gardé en vie (version Web : sauvegarde quand la page est cachée ou fermée).
var web_hide_callback: JavaScriptObject
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
const Generation = preload("res://scripts/world_generation.gd")
var custom_generation: Dictionary = {}
var custom_draft: Dictionary = {}
var custom_sliders: Dictionary = {}
var custom_enabled: Dictionary = {}
var custom_labels: Dictionary = {}
var custom_world_button: Button
var custom_status: RichTextLabel
var custom_apply_button: Button
var world_options_title: RichTextLabel
var duplicate_button: Button
var world_settings_button: Button
var world_settings_text: RichTextLabel
var world_settings_back_button: Button
# Mode du monde : choix à la création, puis mode développeur ou retour au mode par défaut (0.0.4.10).
var create_mode: String = Catalog.MODE_DEFAULT
var create_default_button: Button
var create_developer_button: Button
var create_mode_note: RichTextLabel
var world_developer_button: Button
var world_default_button: Button
var attributes_default_button: Button
var developer_confirm_message: RichTextLabel
var developer_confirm_button: Button
var developer_cancel_button: Button
var form_error: RichTextLabel
var shortcut_hints: Label
var play_button: Button
var settings_button: Button
var information_button: Button
var history_button: Button
var licences_scroll: ScrollContainer
var licences_text: RichTextLabel
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
var launcher_box: VBoxContainer
# 0.0.4.16 : versions visibles à la fois dans la liste ▼ (moins si la fenêtre est petite).
const LAUNCHER_LIST_ROWS := 6
var launcher_back_button: Button
var launcher_play_buttons: Dictionary = {}
var launcher_remove_buttons: Dictionary = {}
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
var home_generation_text: RichTextLabel
var world_generation_text: RichTextLabel
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
var home_version: RichTextLabel
var pause_version: RichTextLabel
var info_button: Button
var info_back_button: Button
var info_text: RichTextLabel
var showcase: Node3D
var backdrop: ColorRect
var news_label: RichTextLabel

# Définies plus loin (app_settings.gd, app.gd) ; ici pour que les parties précédentes puissent les appeler.
func show_page(_next_page: String) -> void:
	pass

func _apply_to_game() -> void:
	pass

func _button(text: String, parent: Node, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	_min_size(button, Vector2(0, 40))
	parent.add_child(button)
	button.pressed.connect(action)
	_sounds().attach(button)
	return button

# Voix des personnages (0.0.4.12), créées à la première utilisation.
func _voices() -> Node:
	if character_voices == null:
		character_voices = CharacterVoices.new()
		character_voices.name = "CharacterVoices"
		add_child(character_voices)
	return character_voices

# 0.0.4.15 : en mode développeur, les vitesses changées en jeu (↑ ↓, ⌫) s'affichent tout de suite dans
# Attributs → Vitesses actuelles (champ et barre) ; enregistrées peu après le dernier changement.
const SPEED_SAVE_DELAY := 0.6
var speed_save_timer: Timer

# Sons des menus (0.0.4.11), créés au premier bouton.
func _sounds() -> Node:
	if menu_sounds == null:
		menu_sounds = MenuSounds.new()
		menu_sounds.name = "MenuSounds"
		add_child(menu_sounds)
	return menu_sounds

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
	appearance_key = _appearance_key()
	_sounds().set_volume(settings.values.get("menu_volume", 60.0))
	_voices().set_volume(settings.values.get("character_volume", 80.0))
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

# 0.0.4.22 : en changeant de page, le thème n'est refait que si un de ces réglages a changé
# (avant : à chaque page, environ 0,15 s).
func _appearance_key() -> Array:
	return [_text_scale(), _element_scale(), settings.values.theme_mode, settings.values.menu_depth, settings.values.text_detail]

func _apply_appearance_if_changed() -> void:
	if appearance_key != _appearance_key():
		apply_appearance()

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

# 0.0.4.16 : trait fin et discret entre deux lignes, pour suivre une ligne de gauche à droite.
func _row_line(parent: Node) -> void:
	if parent.get_children().any(func(child): return child is BoxContainer):
		var line := HSeparator.new()
		line.theme_type_variation = "OrbRowLine"
		parent.add_child(line)

# 0.0.4.14 : bloc sous un titre, caché quand le titre est réduit.
func _fold_body(parent: Node) -> VBoxContainer:
	var body := VBoxContainer.new()
	_sep(body, ROW_GAP)
	parent.add_child(body)
	return body

# Titre cliquable (▾ développé, ▸ réduit) ; l'état est enregistré dans menus.json.
func _make_foldable(title: Node, body: Control, key: String) -> void:
	var label := title as RichTextLabel
	fold_entries[key] = {"title": label, "body": body, "text": label.text}
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	label.tooltip_text = "Cliquer pour réduire ou développer"
	label.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			toggle_fold(key))
	set_folded(key, false)

func set_folded(key: String, folded: bool) -> void:
	var entry: Dictionary = fold_entries[key]
	entry.body.visible = not folded
	entry.title.text = ("▸ " if folded else "▾ ") + entry.text

func is_folded(key: String) -> bool:
	return not fold_entries[key].body.visible

func toggle_fold(key: String) -> void:
	set_folded(key, not is_folded(key))
	_sounds().play("click")
	_save_folds()

func fold_all(folded: bool) -> void:
	for key in fold_entries:
		set_folded(key, folded)
	_save_folds()

func _save_folds() -> void:
	settings.set_menu_folded(fold_entries.keys().filter(func(key): return is_folded(key)))

# Bouton d'ouverture : comme la dernière fois → tout développé → tout réduit → …
func cycle_fold_open_mode() -> void:
	var modes := FOLD_OPEN_MODES.keys()
	settings.set_menu_open_mode(modes[(modes.find(settings.menu_open_mode) + 1) % modes.size()])
	_refresh_fold_open_button()

func _refresh_fold_open_button() -> void:
	fold_open_button.text = FOLD_OPEN_MODES.get(settings.menu_open_mode, FOLD_OPEN_MODES.last)

# En ouvrant Paramètres : état d'avant, tout développé ou tout réduit, selon le choix.
func apply_fold_open() -> void:
	for key in fold_entries:
		match settings.menu_open_mode:
			"expanded":
				set_folded(key, false)
			"collapsed":
				set_folded(key, true)
			_:
				set_folded(key, key in settings.menu_folded)

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
	if not is_inside_tree():
		return
	var view := get_viewport().get_visible_rect().size
	var frame: float = menu_panel.get_theme_stylebox("panel").get_minimum_size().y
	var available := maxf(SCROLL_MIN_HEIGHT, view.y - frame - 2.0 * WINDOW_MARGIN)
	if page == "launcher" and is_instance_valid(launcher_box):
		_fit_launcher(available)
	menu_scroll.custom_minimum_size.y = minf(menu_stack.get_combined_minimum_size().y, available)

# 0.0.4.16 : launcher sur toute la hauteur de la fenêtre, Jouer tout en bas ; la liste ▼ montre
# LAUNCHER_LIST_ROWS versions au plus, et moins si la place manque : rien n'est coupé.
func _fit_launcher(available: float) -> void:
	launcher_scroll.custom_minimum_size.y = 0.0
	launcher_box.custom_minimum_size.y = 0.0
	# Versions jouées montrées, sauf si la liste ouverte manque de place (au moins 3 lignes).
	var has_played := launcher_played.get_child_count() > 0
	launcher_played.visible = true
	launcher_played_title.visible = has_played
	var overhead := menu_stack.get_combined_minimum_size().y - launcher_box.get_combined_minimum_size().y
	var inner := available - overhead
	if launcher_scroll.visible:
		var row_height := 46.0
		for child in launcher_list.get_children():
			if child is HBoxContainer:
				row_height = child.get_combined_minimum_size().y + float(launcher_list.get_theme_constant("separation"))
				break
		var free := inner - launcher_box.get_combined_minimum_size().y
		if free < row_height * 3.0 and has_played:
			launcher_played.visible = false
			launcher_played_title.visible = false
			free = inner - launcher_box.get_combined_minimum_size().y
		launcher_scroll.custom_minimum_size.y = clampf(free, row_height, row_height * LAUNCHER_LIST_ROWS)
	launcher_box.custom_minimum_size.y = maxf(inner, launcher_box.get_combined_minimum_size().y)

func _queue_fit() -> void:
	# Le contenu a changé de taille (texte replié, page changée) : réajuster une fois, plus tard.
	if fit_queued:
		return
	fit_queued = true
	(func():
		fit_queued = false
		_fit_height()).call_deferred()
