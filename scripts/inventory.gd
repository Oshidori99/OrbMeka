extends RefCounted
# 0.0.7.2 : inventaire du joueur (données seules ; l'affichage est dans inventory_ui.gd).
# Une grille de 5 lignes × 10 colonnes et la barre d'objets de 10 cases (objet en main : la case choisie de la barre).
# Un inventaire par mode de jeu, gardés tous les deux : Créatif (objets illimités pris dans les catégories,
# toutes les cases ouvertes) et Survie (pour l'instant, seulement les 4 cases de droite de la barre).
# Objet d'une case : {"objet": identifiant} ; case vide : {}. Sauvegarde dans joueur.json (« inventaire »).
const COLUMNS := 10
const ROWS := 5
const GRID_SIZE := COLUMNS * ROWS
const BAR_SIZE := 10
# Survie : cases ouvertes de la barre (les 4 de droite) ; tout le reste est grisé.
const SURVIVAL_BAR := [6, 7, 8, 9]
const SURVIVAL := "survival"
const CREATIVE := "creative"
const FORMAT := 1
# Valeur d'outil de la pioche (même valeur que world.gd PICKAXE) ; -1 : main vide ou objet sans usage.
const PICKAXE := 3
# Matières : valeurs de smooth_terrain.gd (SAND 0, STONE 1, DIRT 2, CLAY 4, MUD 5, DARK_STONE 6, LIMESTONE 9, FLINT 11).
const ITEMS := {
	"sable": {"nom": "Sable", "matiere": 0, "couleur": Color("#c9a467")},
	"terre": {"nom": "Terre", "matiere": 2, "couleur": Color("#6e4a2c")},
	"argile": {"nom": "Argile", "matiere": 4, "couleur": Color("#8c8a84")},
	"boue": {"nom": "Boue", "matiere": 5, "couleur": Color("#4b3b2b")},
	"pierre": {"nom": "Pierre", "matiere": 1, "couleur": Color("#7d7a75")},
	"calcaire": {"nom": "Calcaire", "matiere": 9, "couleur": Color("#c4bca8")},
	"pierre_sombre": {"nom": "Pierre sombre", "matiere": 6, "couleur": Color("#4a4744")},
	"silex": {"nom": "Silex", "matiere": 11, "couleur": Color("#2e2e33")},
	"pioche": {"nom": "Pioche", "outil": PICKAXE, "couleur": Color("#8d9196")},
}
# Catégories de l'inventaire en Créatif, dans l'ordre des onglets. La pioche : en Créatif seulement, pour l'instant.
const CATEGORIES := [
	{"id": "natural", "nom": "Matériaux naturels", "objets": ["sable", "terre", "argile", "boue", "pierre", "calcaire", "pierre_sombre", "silex"]},
	{"id": "tools", "nom": "Outils", "objets": ["pioche"]},
]

signal changed

var mode := CREATIVE
var _stores := {SURVIVAL: _empty_store(), CREATIVE: _empty_store()}

static func _empty_store() -> Dictionary:
	var grid := []
	grid.resize(GRID_SIZE)
	grid.fill({})
	var bar := []
	bar.resize(BAR_SIZE)
	bar.fill({})
	return {"grid": grid, "bar": bar, "selected": 0}

func _store() -> Dictionary:
	return _stores[mode]

func set_mode(new_mode: String) -> void:
	mode = new_mode if new_mode in [SURVIVAL, CREATIVE] else CREATIVE
	var store := _store()
	if not usable("bar", store.selected):
		store.selected = SURVIVAL_BAR[0]
	changed.emit()

# area : « grid » (grille de 5 × 10) ou « bar » (barre d'objets).
func size_of(area: String) -> int:
	return BAR_SIZE if area == "bar" else GRID_SIZE

func item(area: String, index: int) -> Dictionary:
	if index < 0 or index >= size_of(area):
		return {}
	return _store()[area][index]

func usable(area: String, index: int) -> bool:
	if index < 0 or index >= size_of(area):
		return false
	return mode == CREATIVE or (area == "bar" and index in SURVIVAL_BAR)

# Met un objet dans une case ouverte ; rend celui qui y était (ou {}).
func put(area: String, index: int, value: Dictionary) -> Dictionary:
	if not usable(area, index):
		return value
	var before: Dictionary = _store()[area][index]
	_store()[area][index] = value.duplicate() if valid_item(value) else {}
	changed.emit()
	return before

func take(area: String, index: int) -> Dictionary:
	return put(area, index, {}) if usable(area, index) else {}

# Première case ouverte et vide : barre d'abord, puis grille ; [] s'il n'y en a pas.
func first_free() -> Array:
	for area in ["bar", "grid"]:
		for index in range(size_of(area)):
			if usable(area, index) and item(area, index).is_empty():
				return [area, index]
	return []

# --- Objet en main ---

func selected() -> int:
	return _store().selected

func select(index: int) -> bool:
	if not usable("bar", index):
		return false
	_store().selected = index
	changed.emit()
	return true

# Molette : case ouverte suivante ou précédente de la barre, en boucle.
func cycle(direction: int) -> void:
	var open: Array = range(BAR_SIZE).filter(func(index): return usable("bar", index))
	var at: int = maxi(open.find(selected()), 0)
	select(open[wrapi(at + direction, 0, open.size())])

func held() -> Dictionary:
	return item("bar", selected())

# Valeur pour le monde : matière à poser, PICKAXE, ou -1 (main vide).
func held_kind() -> int:
	var id: String = held().get("objet", "")
	if not ITEMS.has(id):
		return -1
	return ITEMS[id].get("matiere", ITEMS[id].get("outil", -1))

static func item_name(value: Dictionary) -> String:
	var id: String = value.get("objet", "")
	return ITEMS[id].nom if ITEMS.has(id) else ""

static func valid_item(value: Variant) -> bool:
	return value is Dictionary and ITEMS.has(value.get("objet"))

# --- Sauvegarde (joueur.json) ---
const SAVE_NAMES := {SURVIVAL: "survie", CREATIVE: "creatif"}

func to_dict() -> Dictionary:
	var data := {"format": FORMAT}
	for key in SAVE_NAMES:
		var store: Dictionary = _stores[key]
		data[SAVE_NAMES[key]] = {"grille": store.grid.map(_saved), "barre": store.bar.map(_saved), "main": store.selected}
	return data

static func _saved(value: Dictionary) -> Variant:
	return {"objet": value.objet} if valid_item(value) else null

# Lecture tolérante : ancien monde sans inventaire, objet inconnu ou case en trop : ignorés, sans erreur.
func from_dict(data: Variant) -> void:
	_stores = {SURVIVAL: _empty_store(), CREATIVE: _empty_store()}
	if data is Dictionary:
		for key in SAVE_NAMES:
			var saved: Variant = data.get(SAVE_NAMES[key])
			if not saved is Dictionary:
				continue
			var store: Dictionary = _stores[key]
			for pair in [["grille", "grid"], ["barre", "bar"]]:
				var cells: Variant = saved.get(pair[0])
				if not cells is Array:
					continue
				for index in range(mini(cells.size(), store[pair[1]].size())):
					if valid_item(cells[index]):
						store[pair[1]][index] = {"objet": cells[index].objet}
			var main: Variant = saved.get("main")
			if (main is int or main is float) and int(main) >= 0 and int(main) < BAR_SIZE:
				store.selected = int(main)
	set_mode(mode)
