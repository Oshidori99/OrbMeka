extends RefCounted
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
	"walk_forward": {"label": "Avancer", "unit": "m/s", "default": ORIGINAL_WALK_SPEED, "min": 1.0, "max": 12.0},
	"walk_side": {"label": "Avancer de côté", "unit": "m/s", "default": ORIGINAL_WALK_SPEED, "min": 1.0, "max": 12.0},
	"walk_back": {"label": "Reculer", "unit": "m/s", "default": ORIGINAL_WALK_SPEED, "min": 1.0, "max": 12.0},
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
}
# Attributs du joueur : par défaut dans un monde par défaut, réglables en mode développeur.
const ATTRIBUTE_KEYS := ["jump_height", "jump_speed", "fall_gravity", "place_ms", "break_ms", "walk_forward", "walk_side", "walk_back"]
# Un fichier par menu de Paramètres (0.0.3.6), nommé d'après le menu, dans user://
# (Windows : %APPDATA%\Godot\app_userdata\OrbMeka\). L'ancien settings.json (avant 0.0.3.6)
# n'est que lu, pour reprendre les réglages, si aucun de ces fichiers n'existe encore.
const DEFAULT_PATH := "user://settings.json"
# Taille de référence du texte courant dans le thème : Taille du texte / 18 = facteur des polices.
const BASE_TEXT_PX := 18.0
const FILES := {"general": "parametres-generaux.json", "video": "video.json", "attributes": "attributs.json"}
const GENERAL_KEYS := ["mouse_sensitivity", "text_detail"]
var values: Dictionary = {}
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

# Fichier d'un menu. Chemin par défaut : user://video.json… ; autre chemin (tests) :
# même dossier, préfixé du nom de ce chemin, pour ne jamais toucher aux fichiers du joueur.
func file_path(menu: String) -> String:
	if storage_path == DEFAULT_PATH:
		return storage_path.get_base_dir().path_join(FILES[menu])
	return storage_path.get_basename() + "-" + FILES[menu]

static func menu_of(key: String) -> String:
	if key in ATTRIBUTE_KEYS:
		return "attributes"
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
		candidate[key] = value
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
