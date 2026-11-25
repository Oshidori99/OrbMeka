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
	# 0.0.7.35 (demande de l'utilisateur) : vitesse de la molette dans les menus et listes (100 % : celle de Godot).
	"scroll_speed": {"label": "Vitesse de défilement", "unit": "%", "default": 100.0, "min": 25.0, "max": 300.0},
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
	# 0.0.8.7 (demande de l'utilisateur) : 60° par défaut (avant 75°).
	"fov": {"label": "Champ de vision (FOV)", "unit": "°", "default": 60.0, "min": 50.0, "max": 110.0},
	# 0.0.5.1 : zones de 8 m chargées autour du joueur (dans chaque direction).
	# 0.0.5.17 : en zones de 8 m (avant : en mètres, 0.0.5.16), ancien réglage ignoré.
	"grass_zones": {"label": "Distance d’affichage de l’herbe", "unit": "zones de 8 m", "default": 4.0, "min": 1.0, "max": 12.0, "step": 1.0},
	# 0.0.5.17 : distance d'affichage, comptée à l'horizontale (8 par défaut, 1 à 32) ; remplace load_distance (4, 1 à 8).
	"view_distance": {"label": "Distance d’affichage", "unit": "zones de 8 m", "default": 8.0, "min": 1.0, "max": 32.0, "step": 1.0},
	# 0.0.5.22 (#128) : terrain lointain simplifié jusqu'à cette distance (0 : aucun), au-delà du terrain détaillé.
	# 0.0.7.21 (demande de l'utilisateur) : en plus de la distance d'affichage (« +16 »), et non plus au total (far_distance,
	# relu une fois des anciens fichiers : far_distance − view_distance).
	"far_extra": {"label": "Distance lointaine (relief simplifié)", "unit": "zones de 8 m en plus", "default": 16.0, "min": 0.0, "max": 48.0, "step": 1.0, "plus": true},
	# 0.0.6.12 : images par seconde au plus (menus et jeu). Sans limite, la carte graphique calculait jusqu'à 240 images
	# par seconde (plus de 500 sans synchronisation) et pouvait siffler ou grésiller ; 60 suffit et chauffe moins.
	# 0.0.7.24 (demande de l'utilisateur) : résolution du rendu 3D (l'interface reste nette) ; moins = plus rapide, plus flou.
	"resolution_3d": {"label": "Résolution 3D", "unit": "%", "default": 100.0, "min": 50.0, "max": 100.0, "step": 5.0},
	"max_fps": {"label": "Images par seconde au plus", "unit": "images par seconde", "default": 60.0, "min": 30.0, "max": 240.0, "step": 10.0},
}
# 0.0.5.36 (#128) : sur le Web, distances plus courtes par défaut (le joueur peut les changer dans Vidéo).
# 0.0.6.19 : encore plus courtes (le navigateur calcule 3 à 5 fois moins vite que le jeu sur PC).
const WEB_DEFAULTS := {"grass_zones": 2.0, "view_distance": 5.0, "far_extra": 7.0}
static func default_of(key: String, web: bool = OS.has_feature("web")) -> float:
	return WEB_DEFAULTS[key] if web and WEB_DEFAULTS.has(key) else SPECS[key].default
# 0.0.6.20 : herbe peu dense par défaut sur le Web (le joueur peut la remettre dans Vidéo).
# 0.0.7.23 (mesures Web sur une petite carte graphique) : Performance sur le Web sans ombres, herbe très basse.
const WEB_CHOICES := {"grass_density": "minimal", "quality": "performance", "shadows": "off", "shadow_size": "1024", "antialiasing": "off"}
const WEB_PERFORMANCE := {"grass_density": "minimal", "shadows": "off"}
# 0.0.7.24 (mesures Web, accord de l'utilisateur) : sur le Web, Équilibré et Beauté moins loin (Beauté 16 zones : plus de 1 800
# dessins, moins de 9 images par seconde). 0.0.7.25 : résolution 3D à 100 % aussi sur le Web (mesures : 75 % y était le plus
# lent, 60 % ne gagnait presque rien ; le rendu réduit puis agrandi coûte plus qu'il ne fait gagner sur une petite carte).
const WEB_BALANCED := {"view_distance": 6.0, "far_extra": 10.0}
const WEB_BEAUTY := {"view_distance": 8.0, "far_extra": 16.0, "shadow_size": "2048"}
static func choice_default(key: String, web: bool = OS.has_feature("web")) -> String:
	return WEB_CHOICES[key] if web and WEB_CHOICES.has(key) else CHOICES[key].default
# 0.0.7.21 : préréglages de « Qualité d'affichage ». Beauté : l'affichage d'avant 0.0.7.21, et depuis 0.0.7.22 (demande de
# l'utilisateur) 16 zones et lointain +24 ; Équilibré (défaut sur PC) :
# ombres un peu moins loin, herbe un peu moins dense (même portée) ; Performance (défaut sur le Web) : toutes les
# concessions (sur le Web, ses distances courtes, WEB_DEFAULTS). Les optimisations qui ne changent pas l'image valent pour tous.
const QUALITY_KEYS := ["grass_density", "grass_zones", "view_distance", "far_extra", "shadows", "shadow_size", "antialiasing", "resolution_3d"]
const PRESETS := {
	"performance": {"grass_density": "low", "grass_zones": 3.0, "view_distance": 6.0, "far_extra": 10.0, "shadows": "near", "shadow_size": "1024", "antialiasing": "off", "resolution_3d": 100.0},
	"balanced": {"grass_density": "reduced", "grass_zones": 4.0, "view_distance": 8.0, "far_extra": 16.0, "shadows": "medium", "shadow_size": "2048", "antialiasing": "on", "resolution_3d": 100.0},
	"beauty": {"grass_density": "medium", "grass_zones": 4.0, "view_distance": 16.0, "far_extra": 24.0, "shadows": "far", "shadow_size": "4096", "antialiasing": "on", "resolution_3d": 100.0},
}

static func preset_values(name: String, web: bool = OS.has_feature("web")) -> Dictionary:
	var result: Dictionary = PRESETS[name].duplicate()
	if web and name == "performance":
		result.merge(WEB_DEFAULTS, true)
		result.merge(WEB_PERFORMANCE, true)
	elif web:
		result.merge(WEB_BALANCED if name == "balanced" else WEB_BEAUTY, true)
	return result


# 0.0.7.24 : joueurs Web restés sur l'ancienne Performance (avant 0.0.7.23 : herbe basse, ombres proches) : passés à la
# nouvelle (sans ombres, herbe très basse, sol simplifié) au lieu de Personnalisé (mesures Web du 18.11.2026).
const OLD_WEB_PERFORMANCE := {"grass_density": "low", "grass_zones": 2.0, "view_distance": 5.0, "far_extra": 7.0, "shadows": "near", "antialiasing": "off"}

static func upgrade_web(current: Dictionary, web: bool = OS.has_feature("web")) -> bool:
	# 0.0.7.25 : préréglages Web de 0.0.7.24 (Résolution 3D 60 ou 75 %) : à 100 %, comme les nouveaux.
	if web and (current.get("resolution_3d") == 60.0 or current.get("resolution_3d") == 75.0):
		for name in PRESETS:
			var before := preset_values(name, true)
			before.resolution_3d = 60.0 if name == "performance" else 75.0
			if before.keys().all(func(key: String): return current.get(key) == before[key]):
				current.resolution_3d = 100.0
				return true
	if not web or not OLD_WEB_PERFORMANCE.keys().all(func(key: String): return current.get(key) == OLD_WEB_PERFORMANCE[key]):
		return false
	current.merge(preset_values("performance", true), true)
	return true

# Préréglage dont toutes les valeurs correspondent, sinon « custom » (Personnalisé).
# 0.0.8.14 : taille de la carte des ombres du préréglage dont les autres réglages correspondent (sinon le défaut).
static func shadow_size_for(current: Dictionary, web: bool = OS.has_feature("web")) -> String:
	for name in PRESETS:
		var preset := preset_values(name, web)
		if preset.keys().all(func(key: String): return key == "shadow_size" or current.get(key) == preset[key]):
			return preset.shadow_size
	return choice_default("shadow_size", web)

static func matching_preset(current: Dictionary, web: bool = OS.has_feature("web")) -> String:
	for name in PRESETS:
		var preset := preset_values(name, web)
		if preset.keys().all(func(key: String): return current.get(key) == preset[key]):
			return name
	return "custom"
# Réglages à choix (0.0.3.4 ; profondeur 0.0.3.5), affichés en boutons ; options dans l'ordre d'affichage.
const CHOICES := {
	"text_detail": {"label": "Synthèse des textes", "options": {"minus": "−", "default": "Par défaut", "plus": "+"}, "default": "default"},
	"theme_mode": {"label": "Thème", "options": {"dark": "Sombre", "default": "Par défaut", "light": "Clair"}, "default": "default"},
	"menu_depth": {"label": "Profondeur des menus", "options": {"on": "Oui", "off": "Non"}, "default": "on"},
	# 0.0.3.14 : coordonnées du joueur affichées en jeu, en haut à droite.
	"show_coords": {"label": "Afficher les coordonnées", "options": {"on": "Oui", "off": "Non"}, "default": "off"},
	# 0.0.8.28 (#154, demande de l'utilisateur) : la mini-carte (en haut à droite) : la montrer, sa taille, son zoom, nord
	# en haut ou carte qui tourne avec le regard.
	"map_show": {"label": "Mini-carte", "options": {"on": "Oui", "off": "Non"}, "default": "on"},
	"map_size": {"label": "Taille de la mini-carte", "options": {"small": "Petite", "medium": "Moyenne", "large": "Grande"}, "default": "medium"},
	"map_zoom": {"label": "Zoom de la mini-carte", "options": {"1": "Loin", "2": "Moyen", "4": "Près"}, "default": "2"},
	"map_north": {"label": "Orientation", "options": {"fixed": "Nord en haut", "turning": "Tourne avec le regard"}, "default": "fixed"},
	# 0.0.5.4 : brins par carré de 50 cm (terrain_materials.gd) ; moins = plus rapide, surtout sur le Web.
	# 0.0.7.21 : « Réduite » (140 brins), celle du réglage Équilibré, devenue le défaut.
	"grass_density": {"label": "Densité de l'herbe", "options": {"minimal": "Très basse", "low": "Basse", "reduced": "Réduite", "medium": "Moyenne", "high": "Haute"}, "default": "reduced"},
	# 0.0.7.21 (demande de l'utilisateur) : qualité d'affichage en tête de Vidéo ; règle d'un coup les réglages de
	# QUALITY_KEYS (PRESETS) ; « Personnalisé » dès qu'un d'eux ne correspond plus à un préréglage.
	"quality": {"label": "Qualité d'affichage", "options": {"performance": "Performance", "balanced": "Équilibré", "beauty": "Beauté", "custom": "Personnalisé"}, "default": "balanced"},
	# 0.0.7.21 : ombres du soleil : jusqu'à 64 m (Loin, comme avant), 48 m (Moyennes) ou 32 m (Proches, un seul niveau).
	"shadows": {"label": "Ombres", "options": {"off": "Aucune", "near": "Proches", "medium": "Moyennes", "far": "Loin"}, "default": "medium"},
	# 0.0.8.14 (rapport d'optimisation, demande de l'utilisateur) : taille de la carte des ombres du soleil (points de côté) ;
	# plus grande = ombres plus nettes mais plus lent (Radeon 610M : 2048 au lieu de 4096 = 12 à 23 ms de moins par image).
	"shadow_size": {"label": "Taille de la carte des ombres", "options": {"512": "512", "1024": "1024", "2048": "2048", "4096": "4096", "8192": "8192"}, "default": "2048"},
	# 0.0.7.21 : anticrénelage (MSAA 2×) : bords lisses ; sans, un peu en escalier mais plus rapide.
	"antialiasing": {"label": "Anticrénelage", "options": {"on": "Oui", "off": "Non"}, "default": "on"},
	# 0.0.3.16 : personnage choisi (Paramètres → Personnage), enregistré dans personnage.json.
	# 0.0.3.23 : enfants de 9 et 14 ans (à la place de « boy » et « girl »), quatre nouveaux animaux.
	"character": {"label": "Personnage", "options": {"boy9": "Garçon 9 ans", "girl9": "Fille 9 ans", "boy14": "Garçon 14 ans", "girl14": "Fille 14 ans", "man": "Homme", "woman": "Femme", "cat": "Chat", "brioche": "Brioche", "squirrel": "Écureuil", "fox": "Renard", "turtle": "Tortue", "rabbit": "Lapin bleu"}, "default": "boy14"},
	# 0.0.3.22 : ton de peau des humains, même fichier ; absent (ancien fichier) : ton d'avant du personnage.
	"skin": {"label": "Couleur de peau", "options": {"light": "Peau claire", "brown": "Peau brune", "dark": "Peau foncée"}, "default": "light"},
	# 0.0.6 : liste des mondes : cacher les anciennes générations, listes sécurisées (world_shelves.gd), rangement automatique.
	"hide_old_worlds": {"label": "Cacher les mondes d'anciennes générations", "options": {"on": "Oui", "off": "Non"}, "default": "off"},
	"world_shelves": {"label": "Dossiers sécurisés", "options": {"on": "Oui", "off": "Non"}, "default": "off"},
	"auto_secure_old": {"label": "Ranger les anciens mondes dans « Versions sécurisées »", "options": {"on": "Oui", "off": "Non"}, "default": "off"},
	# 0.0.8.1 (#205, demande de l'utilisateur) : objets à la mort, choix proposé pour les nouveaux mondes (chaque monde garde
	# ensuite le sien : création, Paramètres → Monde).
	"death_items": {"label": "Objets à la mort (nouveaux mondes)", "options": {"drop": "Tombent sur place", "keep": "Gardés"}, "default": "drop"},
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
const GENERAL_KEYS := ["auto_secure_old", "character_volume", "death_items", "hide_old_worlds", "menu_volume", "mouse_sensitivity", "scroll_speed", "text_detail", "world_shelves"]
const CONTROLS_FILE := "controles.json"
# 0.0.4.14 : titres réduits de Paramètres et choix à l'ouverture (last, expanded, collapsed).
const MENUS_FILE := "menus.json"
const MENU_OPEN_MODES := ["last", "expanded", "collapsed"]
# 0.0.4.22 : fichiers du joueur rangés dans user://parametres/ (avant : directement dans user://).
const FOLDER := "parametres"
# Réglages lus dans les fichiers (les absents viennent d'une version précédente).
var _seen_keys: Dictionary = {}
var menu_open_mode := "last"
var menu_folded: Array = []
# 0.0.8.14 : qualité Performance déjà proposée une fois (PC trop lent : quality_hint.gd), gardé dans menus.json.
var quality_hint_done := false
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
	# 0.0.8.14 : fichiers d'avant la taille de la carte des ombres : celle de leur qualité (sinon, « Personnalisé »).
	if not _seen_keys.has("shadow_size"):
		values.shadow_size = shadow_size_for(values)
	# 0.0.7.21 : qualité d'affichage toujours d'accord avec les réglages lus (anciens fichiers : Personnalisé, ou le
	# préréglage auquel ils correspondent).
	upgrade_web(values)
	values.quality = matching_preset(values)

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
	quality_hint_done = data.get("qualite_conseillee", false) == true

func _write_menus() -> bool:
	return _write(menus_path(), {"open_mode": menu_open_mode, "folded": menu_folded, "qualite_conseillee": quality_hint_done})

func set_quality_hint_done() -> bool:
	quality_hint_done = true
	return _write_menus()

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
	for key in parser.data:
		_seen_keys[key] = true
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
	# 0.0.7.21 : ancienne distance lointaine (au total) : ce qu'elle ajoutait à la distance d'affichage.
	if parser.data.has("far_distance") and not parser.data.has("far_extra") and (parser.data.far_distance is int or parser.data.far_distance is float):
		values.far_extra = clampf(float(parser.data.far_distance) - float(values.view_distance), SPECS.far_extra.min, SPECS.far_extra.max)
	# personnage.json d'avant 0.0.3.22 (sans « skin ») : le personnage garde son ton d'avant.
	if parser.data.has("character") and not parser.data.has("skin"):
		values.skin = FORMER_SKINS.get(str(parser.data.get("character")), CHOICES.skin.default)

# Valeurs d'un monde en mode par défaut, quels que soient les réglages enregistrés.
static func default_values() -> Dictionary:
	var result := {}
	for key in SPECS:
		result[key] = default_of(key)
	for key in CHOICES:
		result[key] = choice_default(key)
	return result

# Valeurs pour une partie : monde développeur = tous les réglages ; monde par défaut =
# attributs par défaut, réglages généraux (souris…) conservés.
func world_values(developer: bool) -> Dictionary:
	var result := values.duplicate()
	if not developer:
		for key in ATTRIBUTE_KEYS:
			result[key] = default_of(key)
	return result

static func number_text(value: float) -> String:
	return str(snappedf(value, 0.001)).replace(".", ",")

# 0.0.7.21 : texte d'un champ ; « + » devant ce qui s'ajoute à un autre réglage (distance lointaine : « +16 »).
static func field_text(key: String, value: float) -> String:
	if SPECS.get(key, {}).get("plus", false):
		return "+" + (str(int(value)) if is_equal_approx(value, roundf(value)) else number_text(value))
	return number_text(value)

func apply_texts(texts: Dictionary) -> bool:
	last_error = ""
	var candidate := {}
	for key in SPECS:
		var text: String = str(texts.get(key, "")).strip_edges().replace(",", ".").trim_prefix("+")
		var value: float = default_of(key)
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
		var choice: String = str(texts.get(key, choice_default(key)))
		if not CHOICES[key].options.has(choice):
			last_error = "%s : choix inconnu." % CHOICES[key].label
			return false
		candidate[key] = choice
	# 0.0.7.21 : un préréglage choisi s'applique à ses réglages ; sinon, la qualité suit les réglages (Personnalisé dès
	# que l'un d'eux ne correspond plus).
	if PRESETS.has(texts.get("quality", "")) and texts.get("quality_chosen", false):
		candidate.merge(preset_values(texts.quality), true)
	candidate.quality = matching_preset(candidate)
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
