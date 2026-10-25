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
	# 0.0.3.24 : courir (touche de Contrôles maintenue), plus rapide dans chaque direction.
	"run_forward": {"label": "Avancer en courant", "unit": "m/s", "default": 8.5, "min": 1.0, "max": 20.0},
	"run_side": {"label": "De côté en courant", "unit": "m/s", "default": 8.5, "min": 1.0, "max": 20.0},
	"run_back": {"label": "Reculer en courant", "unit": "m/s", "default": 8.5, "min": 1.0, "max": 20.0},
	# 0.0.4.3 : Plus vite / Moins vite (↑ ↓) : marche et course multipliées ensemble, en % de la
	# vitesse normale, entre un minimum et un maximum ; rapidité du changement en % par seconde.
	# (Les attributs run_max, run_accel, run_decel de 0.0.4.2 sont ignorés à la lecture.)
	# 0.0.4.5 : voler, un peu plus vite que courir (8,5 m/s) ; montée et descente à part.
	"fly_forward": {"label": "Avancer en volant", "unit": "m/s", "default": 10.0, "min": 1.0, "max": 30.0},
	"fly_side": {"label": "De côté en volant", "unit": "m/s", "default": 10.0, "min": 1.0, "max": 30.0},
	"fly_back": {"label": "Reculer en volant", "unit": "m/s", "default": 10.0, "min": 1.0, "max": 30.0},
	# 0.0.4.8 : courir en volant (touche Courir en vol), plus rapide encore.
	"fly_run_forward": {"label": "Avancer en volant vite", "unit": "m/s", "default": 15.0, "min": 1.0, "max": 40.0},
	"fly_run_side": {"label": "De côté en volant vite", "unit": "m/s", "default": 15.0, "min": 1.0, "max": 40.0},
	"fly_run_back": {"label": "Reculer en volant vite", "unit": "m/s", "default": 15.0, "min": 1.0, "max": 40.0},
	"fly_up": {"label": "Monter en volant", "unit": "m/s", "default": 7.0, "min": 1.0, "max": 30.0},
	"fly_down": {"label": "Descendre en volant", "unit": "m/s", "default": 7.0, "min": 1.0, "max": 30.0},
	"speed_max": {"label": "Vitesse maximale", "unit": "%", "default": 200.0, "min": 100.0, "max": 500.0},
	"speed_min": {"label": "Vitesse minimale", "unit": "%", "default": 50.0, "min": 10.0, "max": 100.0},
	"speed_up_rate": {"label": "Rapidité pour accélérer", "unit": "%/s", "default": 40.0, "min": 1.0, "max": 300.0},
	"speed_down_rate": {"label": "Rapidité pour ralentir", "unit": "%/s", "default": 40.0, "min": 1.0, "max": 300.0},
	# 0.0.4.15 : vitesses actuelles (en % de la normale), changées en direct par ↑ ↓ (+ A, W, R, clic)
	# dans un monde en mode développeur ; ramenées dans les limites vitesse minimale / maximale.
	"current_speed": {"label": "Déplacement actuel", "unit": "%", "default": 100.0, "min": 10.0, "max": 500.0},
	"current_walk": {"label": "Marche actuelle", "unit": "%", "default": 100.0, "min": 10.0, "max": 500.0},
	"current_run": {"label": "Course actuelle", "unit": "%", "default": 100.0, "min": 10.0, "max": 500.0},
	"current_break": {"label": "Casse actuelle", "unit": "%", "default": 100.0, "min": 10.0, "max": 500.0},
	"current_place": {"label": "Pose actuelle", "unit": "%", "default": 100.0, "min": 10.0, "max": 500.0},
	# 0.0.3.17 : hauteur de la vue en blocs (1 = vue à un bloc du sol), deux décimales (pas de 0,01).
	"eye_height": {"label": "Hauteur des yeux", "unit": "blocs", "default": 1.62, "min": 0.3, "max": 3.0, "step": 0.01},
	# Réglages généraux (0.0.3.1) : valables dans tous les mondes, quel que soit leur mode.
	"mouse_sensitivity": {"label": "Sensibilité de la souris", "unit": "%", "default": 100.0, "min": 10.0, "max": 300.0},
	# 0.0.4.11 : volume des sons des menus (0 = muet), réglage général.
	"menu_volume": {"label": "Volume des menus", "unit": "%", "default": 60.0, "min": 0.0, "max": 100.0},
	# 0.0.4.12 : volume des voix et cris des personnages (0 = muet).
	"character_volume": {"label": "Volume des personnages", "unit": "%", "default": 80.0, "min": 0.0, "max": 100.0},
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
	# 0.0.5.1 : zones de 8 m chargées autour du joueur (dans chaque direction).
	# 0.0.5.17 : en zones de 8 m (avant : en mètres, 0.0.5.16), ancien réglage ignoré.
	"grass_zones": {"label": "Distance d’affichage de l’herbe", "unit": "zones de 8 m", "default": 4.0, "min": 1.0, "max": 12.0, "step": 1.0},
	# 0.0.5.17 : distance d'affichage, comptée à l'horizontale (8 par défaut, 1 à 32) ; remplace load_distance (4, 1 à 8).
	"view_distance": {"label": "Distance d’affichage", "unit": "zones de 8 m", "default": 8.0, "min": 1.0, "max": 32.0, "step": 1.0},
}
# Réglages à choix (0.0.3.4 ; profondeur 0.0.3.5), affichés en boutons ; options dans l'ordre d'affichage.
const CHOICES := {
	"text_detail": {"label": "Synthèse des textes", "options": {"minus": "−", "default": "Par défaut", "plus": "+"}, "default": "default"},
	"theme_mode": {"label": "Thème", "options": {"dark": "Sombre", "default": "Par défaut", "light": "Clair"}, "default": "default"},
	"menu_depth": {"label": "Profondeur des menus", "options": {"on": "Oui", "off": "Non"}, "default": "on"},
	# 0.0.3.14 : coordonnées du joueur affichées en jeu, en haut à droite.
	"show_coords": {"label": "Afficher les coordonnées", "options": {"on": "Oui", "off": "Non"}, "default": "off"},
	# 0.0.5.4 : brins par carré de 50 cm (terrain_materials.gd) ; moins = plus rapide, surtout sur le Web.
	"grass_density": {"label": "Densité de l'herbe", "options": {"low": "Basse", "medium": "Moyenne", "high": "Haute"}, "default": "medium"},
	# 0.0.3.16 : personnage choisi (Paramètres → Personnage), enregistré dans personnage.json.
	# 0.0.3.23 : enfants de 9 et 14 ans (à la place de « boy » et « girl »), quatre nouveaux animaux.
	"character": {"label": "Personnage", "options": {"boy9": "Garçon 9 ans", "girl9": "Fille 9 ans", "boy14": "Garçon 14 ans", "girl14": "Fille 14 ans", "man": "Homme", "woman": "Femme", "cat": "Chat", "brioche": "Brioche", "squirrel": "Écureuil", "fox": "Renard", "turtle": "Tortue", "rabbit": "Lapin bleu"}, "default": "boy14"},
	# 0.0.3.22 : ton de peau des humains, même fichier ; absent (ancien fichier) : ton d'avant du personnage.
	"skin": {"label": "Couleur de peau", "options": {"light": "Peau claire", "brown": "Peau brune", "dark": "Peau foncée"}, "default": "light"},
}
# Ton de chaque humain avant 0.0.3.22 (mêmes valeurs que former_skin dans character_preview.gd).
const FORMER_SKINS := {"boy": "light", "girl": "brown", "man": "dark", "woman": "light"}
# Personnages d'avant 0.0.3.23 remplacés : l'ancien Garçon et l'ancienne Fille (≈ 14 ans) deviennent ceux de 14 ans.
const FORMER_CHARACTERS := {"boy": "boy14", "girl": "girl14"}
# Attributs du joueur : par défaut dans un monde par défaut, réglables en mode développeur.
const ATTRIBUTE_KEYS := ["jump_height", "jump_speed", "fall_gravity", "place_ms", "break_ms", "break_reach", "place_reach", "walk_forward", "walk_side", "walk_back", "crouch_forward", "crouch_side", "crouch_back", "crouch_gravity", "run_forward", "run_side", "run_back", "fly_forward", "fly_side", "fly_back", "fly_run_forward", "fly_run_side", "fly_run_back", "fly_up", "fly_down", "speed_max", "speed_min", "speed_up_rate", "speed_down_rate", "current_speed", "current_walk", "current_run", "current_break", "current_place", "eye_height"]
# Un fichier par menu de Paramètres (0.0.3.6), nommé d'après le menu, dans user://parametres/
# (Windows : %APPDATA%\Godot\app_userdata\OrbMeka\). L'ancien settings.json (avant 0.0.3.6)
# n'est que lu, pour reprendre les réglages, si aucun de ces fichiers n'existe encore.
const DEFAULT_PATH := "user://settings.json"
# Taille de référence du texte courant dans le thème : Taille du texte / 18 = facteur des polices.
const BASE_TEXT_PX := 18.0
const FILES := {"general": "parametres-generaux.json", "video": "video.json", "character": "personnage.json", "attributes": "attributs.json"}
const GENERAL_KEYS := ["character_volume", "menu_volume", "mouse_sensitivity", "text_detail"]
const CONTROLS_FILE := "controles.json"
# 0.0.4.14 : titres réduits de Paramètres et choix à l'ouverture (last, expanded, collapsed).
const MENUS_FILE := "menus.json"
const MENU_OPEN_MODES := ["last", "expanded", "collapsed"]
# 0.0.4.22 : fichiers du joueur rangés dans user://parametres/ (avant : directement dans user://).
const FOLDER := "parametres"
var menu_open_mode := "last"
var menu_folded: Array = []
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
	# 0.0.4.21 : l'ancien settings.json (avant 0.0.3.6), déjà repris dans les fichiers par menu, est effacé
	# une fois ces fichiers tous écrits (seulement les vrais fichiers du joueur, jamais ceux des tests).
	if path == DEFAULT_PATH and FileAccess.file_exists(path) and FILES.keys().all(func(menu): return FileAccess.file_exists(file_path(menu))):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	controls = Controls.defaults()
	control_options = Controls.default_options()
	_read_controls()
	_read_menus()

# Dossier des fichiers du joueur (user://parametres) ; les tests gardent leurs fichiers à part.
func folder() -> String:
	return storage_path.get_base_dir().path_join(FOLDER)

# Au démarrage du jeu : fichiers d'avant 0.0.4.22 (directement dans user://) copiés dans le dossier,
# sauf s'il y en a déjà un du même nom. Les originaux restent pour les anciennes versions du launcher.
# Renvoie les noms copiés.
static func copy_old_files(from_dir: String, to_dir: String) -> Array:
	var copied := []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(to_dir))
	for name in FILES.values() + [CONTROLS_FILE, MENUS_FILE]:
		var old_path := ProjectSettings.globalize_path(from_dir.path_join(name))
		var new_path := ProjectSettings.globalize_path(to_dir.path_join(name))
		if FileAccess.file_exists(old_path) and not FileAccess.file_exists(new_path) and DirAccess.copy_absolute(old_path, new_path) == OK:
			copied.append(name)
	return copied

# Menus (0.0.4.14) : menus.json, à côté des autres fichiers.
func menus_path() -> String:
	if storage_path == DEFAULT_PATH:
		return folder().path_join(MENUS_FILE)
	return storage_path.get_basename() + "-" + MENUS_FILE

func _read_menus() -> void:
	if not FileAccess.file_exists(menus_path()):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(menus_path()))
	if not data is Dictionary:
		return
	if data.get("open_mode") in MENU_OPEN_MODES:
		menu_open_mode = data.open_mode
	if data.get("folded") is Array:
		menu_folded = data.folded.filter(func(key): return key is String)

func _write_menus() -> bool:
	return _write(menus_path(), {"open_mode": menu_open_mode, "folded": menu_folded})

func set_menu_folded(keys: Array) -> bool:
	menu_folded = keys.duplicate()
	return _write_menus()

func set_menu_open_mode(mode: String) -> bool:
	if not mode in MENU_OPEN_MODES:
		return false
	menu_open_mode = mode
	return _write_menus()

# Contrôles (0.0.3.12) : leur propre fichier, controles.json, écrit seulement par set_control.
func controls_path() -> String:
	if storage_path == DEFAULT_PATH:
		return folder().path_join(CONTROLS_FILE)
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
			if Controls.FORMER_DEFAULTS.has(action) and Controls.normalize(Controls.FORMER_DEFAULTS[action]) == controls[action]:
				controls[action] = Controls.default_for(action)
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

# Nouvelle liaison d'une action (toutes ses options, 0.0.4.20 ; ancienne écriture acceptée) ; une même
# combinaison est retirée de l'action qui l'avait (renvoie le nom de cette action, ou "" s'il n'y en avait pas).
func set_control(action: String, raw: Dictionary) -> String:
	return set_controls({action: raw})

# Plusieurs actions d'un coup (0.0.4.22 : ↻ d'une partie, Tout réinitialiser) : un seul fichier écrit ;
# options = choix des Contrôles à changer aussi. Renvoie le nom de la dernière action qui a perdu une combinaison.
func set_controls(changes: Dictionary, options: Dictionary = {}) -> String:
	last_error = ""
	var bindings := {}
	for action in changes:
		bindings[action] = Controls.normalize(changes[action])
	var candidate := controls.duplicate(true)
	var freed := ""
	for other in candidate:
		if bindings.has(other):
			continue
		var kept := []
		for combo in Controls.options(candidate[other]):
			if bindings.values().any(func(binding): return binding.options.any(func(mine): return Controls.same_combo(mine, combo))):
				freed = Controls.ACTIONS[other].label
			else:
				kept.append(combo)
		candidate[other] = {"options": kept}
	candidate.merge(bindings, true)
	var chosen := control_options.duplicate()
	chosen.merge(options, true)
	if not _write_controls(candidate, chosen):
		return ""
	controls = candidate
	control_options = chosen
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
		return folder().path_join(FILES[menu])
	return storage_path.get_basename() + "-" + FILES[menu]

static func menu_of(key: String) -> String:
	if key in ATTRIBUTE_KEYS:
		return "attributes"
	if key in ["character", "skin"]:
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
		elif key == "character" and FORMER_CHARACTERS.has(parser.data.get(key)):
			values[key] = FORMER_CHARACTERS[parser.data.get(key)]
		else:
			load_notice = "Certains réglages invalides ont repris leur valeur par défaut."
	# personnage.json d'avant 0.0.3.22 (sans « skin ») : le personnage garde son ton d'avant.
	if parser.data.has("character") and not parser.data.has("skin"):
		values.skin = FORMER_SKINS.get(str(parser.data.get("character")), CHOICES.skin.default)

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

# 0.0.4.15 : enregistre les valeurs actuelles telles quelles (vitesses changées en jeu), menu par menu.
func save_values() -> bool:
	last_error = ""
	for menu in FILES:
		var part := {}
		for key in values:
			if menu_of(key) == menu:
				part[key] = values[key]
		if not _write(file_path(menu), part):
			return false
	return true

func _write(path: String, data: Dictionary) -> bool:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path.get_base_dir())):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
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
