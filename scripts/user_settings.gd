extends RefCounted
const Controls = preload("res://scripts/controls.gd")
const ORIGINAL_JUMP_SPEED := 8.4
const ORIGINAL_GRAVITY := 14.0
# Vitesse de marche unique avant 0.0.2.14 : défaut des trois directions.
const ORIGINAL_WALK_SPEED := 5.5
const SPECS := {
	"jump_height": {"label": "Hauteur du saut", "unit": "m", "default": ORIGINAL_JUMP_SPEED * ORIGINAL_JUMP_SPEED / (2.0 * ORIGINAL_GRAVITY), "min": 1.1, "max": 8.0},
	"jump_speed": {"label": "Vitesse de montée", "unit": "m/s", "default": ORIGINAL_JUMP_SPEED, "min": 3.0, "max": 16.0},
	"fall_gravity": {"label": "Gravité de descente", "unit": "m/s²", "default": ORIGINAL_GRAVITY, "min": 4.0, "max": 40.0},
	"place_ms": {"label": "Intervalle de pose", "unit": "ms", "default": 300.0, "min": 100.0, "max": 2000.0},
	"break_ms": {"label": "Intervalle de casse", "unit": "ms", "default": 300.0, "min": 100.0, "max": 2000.0},
	# 0.0.3.13 : portées, distance maximale (en blocs) pour casser et pour poser.
	"break_reach": {"label": "Portée de casse", "unit": "blocs", "default": 5.0, "min": 1.0, "max": 20.0},
	"place_reach": {"label": "Portée de pose", "unit": "blocs", "default": 5.0, "min": 1.0, "max": 20.0},
	"walk_forward": {"label": "Avancer", "unit": "m/s", "default": ORIGINAL_WALK_SPEED, "min": 1.0, "max": 12.0},
	"walk_side": {"label": "Avancer de côté", "unit": "m/s", "default": ORIGINAL_WALK_SPEED, "min": 1.0, "max": 12.0},
	"walk_back": {"label": "Reculer", "unit": "m/s", "default": ORIGINAL_WALK_SPEED, "min": 1.0, "max": 12.0},
	# 0.0.3.15 : se baisser, plus lent dans chaque direction et plus lourd à la chute.
	"crouch_forward": {"label": "Avancer baissé", "unit": "m/s", "default": 1.5, "min": 0.5, "max": 12.0},
	"crouch_side": {"label": "De côté baissé", "unit": "m/s", "default": 1.5, "min": 0.5, "max": 12.0},
	"crouch_back": {"label": "Reculer baissé", "unit": "m/s", "default": 1.5, "min": 0.5, "max": 12.0},
	"crouch_gravity": {"label": "Gravité baissé", "unit": "m/s²", "default": 28.0, "min": 4.0, "max": 80.0},
	# 0.0.3.17 : hauteur de la vue en blocs (1 = vue à un bloc du sol), deux décimales (pas de 0,01).
	"eye_height": {"label": "Hauteur des yeux", "unit": "blocs", "default": 1.62, "min": 0.3, "max": 3.0, "step": 0.01},
	# Réglages généraux (0.0.3.1) : valables dans tous les mondes, quel que soit leur mode.
	"mouse_sensitivity": {"label": "Sensibilité de la souris", "unit": "%", "default": 100.0, "min": 10.0, "max": 300.0},
	"panel_size": {"label": "Taille des panneaux", "unit": "% de la fenêtre", "default": 72.0, "min": 50.0, "max": 95.0},
	# 0.0.3.8 : largeur du menu de gauche en % de la largeur du panneau (avant : en px, ignorée).
	"nav_percent": {"label": "Largeur du menu de gauche", "unit": "% du panneau", "default": 15.0, "min": 5.0, "max": 40.0},
	# Taille du texte en px (0.0.3.3) : taille réelle du texte courant ; 13 px par défaut depuis 0.0.3.10
	# (18 px avant). Titres, boutons et notes suivent dans la même proportion.
	"text_px": {"label": "Taille du texte", "unit": "px", "default": 13.0, "min": 7.0, "max": 27.0},
	# 0.0.3.10 : taille des zones et boutons (marges, espaces, boutons), sans le texte ;
	# remplace l'échelle totale de 0.0.3.6 (ancien réglage ui_scale ignoré). 0.0.3.6 : FOV en jeu.
	"element_scale": {"label": "Taille des zones et boutons", "unit": "%", "default": 100.0, "min": 50.0, "max": 150.0},
	"fov": {"label": "Champ de vision (FOV)", "unit": "°", "default": 75.0, "min": 50.0, "max": 110.0},
}
# Réglages à choix (0.0.3.4 ; profondeur 0.0.3.5), affichés en boutons ; options dans l'ordre d'affichage.
const CHOICES := {
	"text_detail": {"label": "Synthèse des textes", "options": {"minus": "−", "default": "Par défaut", "plus": "+"}, "default": "default"},
	"theme_mode": {"label": "Thème", "options": {"dark": "Sombre", "default": "Par défaut", "light": "Clair"}, "default": "default"},
	"menu_depth": {"label": "Profondeur des menus", "options": {"on": "Oui", "off": "Non"}, "default": "on"},
	# 0.0.3.14 : coordonnées du joueur affichées en jeu, en haut à droite.
	"show_coords": {"label": "Afficher les coordonnées", "options": {"on": "Oui", "off": "Non"}, "default": "off"},
	# 0.0.3.16 : personnage choisi (Paramètres → Personnage), enregistré dans personnage.json.
	"character": {"label": "Personnage", "options": {"boy": "Garçon", "girl": "Fille", "man": "Homme", "woman": "Femme"}, "default": "boy"},
}
# Attributs du joueur : par défaut dans un monde par défaut, réglables en mode développeur.
const ATTRIBUTE_KEYS := ["jump_height", "jump_speed", "fall_gravity", "place_ms", "break_ms", "break_reach", "place_reach", "walk_forward", "walk_side", "walk_back", "crouch_forward", "crouch_side", "crouch_back", "crouch_gravity", "eye_height"]
# Un fichier par menu de Paramètres (0.0.3.6), nommé d'après le menu, dans user://
# (Windows : %APPDATA%\Godot\app_userdata\OrbMeka\). L'ancien settings.json (avant 0.0.3.6)
# n'est que lu, pour reprendre les réglages, si aucun de ces fichiers n'existe encore.
const DEFAULT_PATH := "user://settings.json"
# Taille de référence du texte courant dans le thème : Taille du texte / 18 = facteur des polices.
const BASE_TEXT_PX := 18.0
const FILES := {"general": "parametres-generaux.json", "video": "video.json", "character": "personnage.json", "attributes": "attributs.json"}
const GENERAL_KEYS := ["mouse_sensitivity", "text_detail"]
const CONTROLS_FILE := "controles.json"
var values: Dictionary = {}
var controls: Dictionary = {}
var control_options: Dictionary = {}
var storage_path: String
var last_error := ""
var load_notice := ""

func _init(path: String = DEFAULT_PATH) -> void:
	storage_path = path
	values = default_values()
	var found := false
	for menu in FILES:
		if FileAccess.file_exists(file_path(menu)):
			found = true
			_read(file_path(menu))
	if not found and FileAccess.file_exists(path):
		_read(path)
	controls = Controls.defaults()
	control_options = Controls.default_options()
	_read_controls()

# Contrôles (0.0.3.12) : leur propre fichier, controles.json, écrit seulement par set_control.
func controls_path() -> String:
	if storage_path == DEFAULT_PATH:
		return storage_path.get_base_dir().path_join(CONTROLS_FILE)
	return storage_path.get_basename() + "-" + CONTROLS_FILE

func _read_controls() -> void:
	if not FileAccess.file_exists(controls_path()):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(controls_path()))
	if not data is Dictionary:
		load_notice = "Contrôles illisibles : touches par défaut chargées."
		return
	for action in Controls.ACTIONS:
		if not data.has(action):
			continue
		if Controls.is_valid(data[action]):
			controls[action] = Controls.clean(data[action])
		else:
			load_notice = "Certains contrôles invalides ont repris leur touche par défaut."
	for option in Controls.OPTIONS:
		if not data.has(option):
			continue
		if Controls.OPTIONS[option].options.has(data[option]):
			control_options[option] = data[option]
		else:
			load_notice = "Certains contrôles invalides ont repris leur touche par défaut."

func _write_controls(bindings: Dictionary, options: Dictionary) -> bool:
	var data := bindings.duplicate(true)
	data.merge(options, true)
	return _write(controls_path(), data)

# Nouvelle liaison d'une action ; la même touche est retirée de l'action qui l'avait
# (renvoie le nom de cette action, ou "" s'il n'y en avait pas).
func set_control(action: String, binding: Dictionary) -> String:
	last_error = ""
	var candidate := controls.duplicate(true)
	var freed := ""
	if not binding.is_empty():
		for other in candidate:
			if other != action and candidate[other] == binding:
				candidate[other] = {}
				freed = Controls.ACTIONS[other].label
	candidate[action] = binding
	if not _write_controls(candidate, control_options):
		return ""
	controls = candidate
	return freed

# Choix des Contrôles (0.0.3.18), ex. mode pour se baisser ; même fichier controles.json.
func set_control_option(option: String, choice: String) -> bool:
	last_error = ""
	if not Controls.OPTIONS.has(option) or not Controls.OPTIONS[option].options.has(choice):
		last_error = "Choix inconnu."
		return false
	var candidate := control_options.duplicate()
	candidate[option] = choice
	if not _write_controls(controls, candidate):
		return false
	control_options = candidate
	return true

# Fichier d'un menu. Chemin par défaut : user://video.json… ; autre chemin (tests) :
# même dossier, préfixé du nom de ce chemin, pour ne jamais toucher aux fichiers du joueur.
func file_path(menu: String) -> String:
	if storage_path == DEFAULT_PATH:
		return storage_path.get_base_dir().path_join(FILES[menu])
	return storage_path.get_basename() + "-" + FILES[menu]

static func menu_of(key: String) -> String:
	if key in ATTRIBUTE_KEYS:
		return "attributes"
	if key == "character":
		return "character"
	return "general" if key in GENERAL_KEYS else "video"

func _read(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	var parser := JSON.new()
	if file == null or parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		load_notice = "Réglages illisibles : valeurs par défaut chargées."
		return
	for key in SPECS:
		# Réglage absent (fichier d'une version précédente) : défaut, sans avertissement.
		if not parser.data.has(key):
			continue
		var value: Variant = parser.data.get(key)
		if (value is int or value is float) and is_finite(float(value)) and value >= SPECS[key].min and value <= SPECS[key].max:
			values[key] = float(value)
		else:
			load_notice = "Certains réglages invalides ont repris leur valeur par défaut."
	for key in CHOICES:
		if not parser.data.has(key):
			continue
		if CHOICES[key].options.has(parser.data.get(key)):
			values[key] = parser.data.get(key)
		else:
			load_notice = "Certains réglages invalides ont repris leur valeur par défaut."

# Valeurs d'un monde en mode par défaut, quels que soient les réglages enregistrés.
static func default_values() -> Dictionary:
	var result := {}
	for key in SPECS:
		result[key] = SPECS[key].default
	for key in CHOICES:
		result[key] = CHOICES[key].default
	return result

# Valeurs pour une partie : monde développeur = tous les réglages ; monde par défaut =
# attributs par défaut, réglages généraux (souris…) conservés.
func world_values(developer: bool) -> Dictionary:
	var result := values.duplicate()
	if not developer:
		for key in ATTRIBUTE_KEYS:
			result[key] = SPECS[key].default
	return result

static func number_text(value: float) -> String:
	return str(snappedf(value, 0.001)).replace(".", ",")

func apply_texts(texts: Dictionary) -> bool:
	last_error = ""
	var candidate := {}
	for key in SPECS:
		var text: String = str(texts.get(key, "")).strip_edges().replace(",", ".")
		var value: float = SPECS[key].default
		if not text.is_empty():
			if text.to_lower().contains("e") or not text.is_valid_float():
				last_error = "%s : saisissez un nombre." % SPECS[key].label
				return false
			value = text.to_float()
		if not is_finite(value) or value < SPECS[key].min or value > SPECS[key].max:
			last_error = "%s : valeur entre %s et %s %s." % [SPECS[key].label, number_text(SPECS[key].min), number_text(SPECS[key].max), SPECS[key].unit]
			return false
		# Pas fixé (ex. 0,01 pour la hauteur des yeux) : valeur arrondie à ce pas.
		candidate[key] = snappedf(value, SPECS[key].step) if SPECS[key].has("step") else value
	for key in CHOICES:
		# Choix absent : défaut ; choix inconnu : refusé.
		var choice: String = str(texts.get(key, CHOICES[key].default))
		if not CHOICES[key].options.has(choice):
			last_error = "%s : choix inconnu." % CHOICES[key].label
			return false
		candidate[key] = choice
	# Chaque menu dans son fichier, écrit d'abord à côté (.tmp) puis remplacé d'un coup.
	for menu in FILES:
		var part := {}
		for key in candidate:
			if menu_of(key) == menu:
				part[key] = candidate[key]
		if not _write(file_path(menu), part):
			return false
	values = candidate
	load_notice = ""
	return true

func _write(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Impossible d'enregistrer les paramètres."
		return false
	file.store_string(JSON.stringify(data, "	"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK:
		last_error = "Échec de l'enregistrement des paramètres."
		return false
	return true
