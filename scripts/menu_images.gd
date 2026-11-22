extends RefCounted
# 0.0.8.14 (#247, demande de l'utilisateur) : images des menus, faites dans Blender à partir des modèles du jeu
# (sources_blender/menus/generer_images_menus.py ; modèles et couleurs sortis du jeu par tools/modeles_menus.gd) :
# menu des actions (B + T), actions de la fabrication (O + F), main et poche de l'inventaire (O + I). Toutes dans le même
# style (angle, lumière, contour) ; 192 × 192, avec mipmaps (nettes en petit comme en grand). Celles où l'on voit la main
# existent dans les trois couleurs de peau du jeu : on prend celle du personnage joué (player.gd la donne).
const FOLDER := "res://assets/ui/menus/"
const WITH_HAND := ["main", "creuser", "casser_objets", "recuperer_materiaux", "arracher", "tailler"]
const SKINS := ["light", "brown", "dark"]
# Menu des actions : [ligne du clic gauche, ligne du clic droit], dans l'ordre de action_menu.gd.
const ACTIONS := [["creuser", "casser_objets", "recuperer_materiaux", "arracher"], ["poser", "aplanir", "lisser", "manger"]]

# Peau du personnage joué : les images avec la main la prennent.
static var skin := "light"
static var _cache := {}

static func path_of(name: String, skin_id: String = "") -> String:
	if not name in WITH_HAND:
		return FOLDER + name + ".png"
	var tone := skin_id if skin_id in SKINS else (skin if skin in SKINS else "light")
	return FOLDER + "%s_%s.png" % [name, tone]

static func texture(name: String, skin_id: String = "") -> Texture2D:
	var path := path_of(name, skin_id)
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

# Image d'une case du menu des actions (ligne 0 : clic gauche, 1 : clic droit).
static func action(row: int, index: int) -> Texture2D:
	if row < 0 or row >= ACTIONS.size() or index < 0 or index >= ACTIONS[row].size():
		return null
	return texture(ACTIONS[row][index])
