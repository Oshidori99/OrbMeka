extends RefCounted
# 0.0.6 : dernières mises à jour du jeu, des menus et de la génération du terrain (Accueil → Informations).
# Les versions de la génération sont celles enregistrées avec chaque monde (world_generation.gd) ; la version des menus
# compte les changements des menus depuis 0.0.6 (1 : menus de 0.0.5.37 et avant). À compléter à chaque version.
const Generation = preload("res://scripts/world_generation.gd")
const MENUS_VERSION := 3
const MENUS := [
	{"menu": "Contrôles", "version": "0.0.6.1", "text": "Échap et un clic ailleurs annulent, ✕ pour désactiver une touche seule (Aucune)"},
	{"menu": "Mes mondes", "version": "0.0.6", "text": "« ! » jaune des mondes d'anciennes générations, listes sécurisées en onglets, sous-dossiers, déplacement des mondes"},
	{"menu": "Paramètres", "version": "0.0.6", "text": "Paramètres généraux → Mondes : cacher les anciens mondes, dossiers sécurisés, rangement automatique"},
	{"menu": "Informations", "version": "0.0.6", "text": "mises à jour du jeu, des menus et de la génération"},
	{"menu": "Monde personnalisé", "version": "0.0.6", "text": "estimations pour un monde de 64 × 64 zones"},
	{"menu": "Accueil", "version": "0.0.5.37", "text": "menu disponible tout de suite, vitrine sur une crevasse"},
]
# Version de génération → version du jeu qui l'a apportée, et ce qu'elle change.
const GENERATIONS := [
	[16, "0.0.6", "neige sur 1 montagne sur 4, gravier"],
	[15, "0.0.6", "monde de 64 × 64 zones (512 m)"],
	[14, "0.0.5.37", "grottes et crevasses en éclair"],
	[13, "0.0.5.35", "grands lacs, chaînes de montagnes"],
	[12, "0.0.5.34", "lacs de montagne, moins de trous"],
	[11, "0.0.5.33", "très grands déserts, montagnes de sable"],
	[10, "0.0.5.32", "trous de boue"],
	[9, "0.0.5.26", "sous-sol plus profond"],
	[8, "0.0.5.24", "montagnes où l'on peut monter"],
	[7, "0.0.5.23", "montagnes, grands lacs et grands déserts"],
	[6, "0.0.5.21", "lacs irréguliers, boue et argile grise"],
	[5, "0.0.5.20", "monde de 48 × 48 zones, argile, boue"],
	[4, "0.0.5.19", "rochers et petits lacs"],
	[3, "0.0.5.18", "monde de 20 × 20 zones, déserts"],
	[2, "0.0.5.17", "relief moins plat"],
	[1, "0.0.5.16", "mondes personnalisés"],
]

static func text(game_version: String) -> String:
	var lines := ["Jeu : version %s." % game_version, "", "Génération du terrain : version %d (nouveaux mondes)." % Generation.VERSION]
	for entry in GENERATIONS.slice(0, 4):
		lines.append("· Version %d (%s) : %s." % entry)
	lines.append("")
	lines.append("Menus : version %d." % MENUS_VERSION)
	for entry in MENUS:
		lines.append("· %s (%s) : %s." % [entry.menu, entry.version, entry.text])
	return "\n".join(lines)
