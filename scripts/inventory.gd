extends RefCounted
# 0.0.7.2 : inventaire du joueur (données seules ; l'affichage est dans inventory_ui.gd).
# Un inventaire par mode de jeu, gardés tous les deux.
# - Créatif : grille de 5 lignes × 10 colonnes et barre d'objets de 10 cases ; objets pris dans les catégories, illimités.
# - Survie (0.0.7.3, décision du 15.11.2026, issue #40) : presque pas d'inventaire. Seulement deux mains (case 1 : main
#   gauche, case 2 : main droite, 1 kg à elles deux) et quatre poches (cases 3 à 6, 500 g en tout ; 0.0.7.4). Plus tard, sacs et paniers
#   ajouteront des cases (10 au plus dans la barre). Le reste se pose au sol.
# Objet d'une case : {"objet": identifiant, "nombre": n} (+ « taille » pour un caillou, « poids » pour un éclat) ;
# sans « nombre » : illimité (Créatif). Case vide : {}. Seuls des objets vraiment identiques s'empilent.
# Sauvegarde dans joueur.json (« inventaire »).
const COLUMNS := 10
const ROWS := 5
const GRID_SIZE := COLUMNS * ROWS
const BAR_SIZE := 10
const SURVIVAL := "survival"
const CREATIVE := "creative"
const FORMAT := 2
# Survie : mains et poches (cases de la barre), limites en grammes.
const HANDS := [0, 1]
const POCKETS := [2, 3, 4, 5]
# 0.0.7.4 (demande de l'utilisateur) : 1 kg pour les deux mains ensemble, 500 g pour les quatre poches ensemble.
const HANDS_LIMIT := 1000.0
const POCKETS_LIMIT := 500.0
# Valeur d'outil de la pioche (même valeur que world.gd PICKAXE) ; -1 : main vide ou objet sans usage.
const PICKAXE := 3
# Poids d'un caillou selon sa taille (1 à 7, comme rocks.gd), en grammes (gardés en 0.0.7.4, les mains et les poches portent plus).
# Tailles 6 et 7 : trop gros pour être ramassés.
const PEBBLE_WEIGHTS := [50.0, 120.0, 250.0, 400.0, 700.0, 1200.0, 2000.0]
const PICKABLE_SIZE := 5
# Matières : valeurs de smooth_terrain.gd (SAND 0, STONE 1, DIRT 2, CLAY 4, MUD 5, DARK_STONE 6, GRAVEL 8, LIMESTONE 9,
# FLINT 11). Poids : une poignée (une sous-cellule de 50 cm) ; décision du 14.11.2026.
const ITEMS := {
	"sable": {"nom": "Sable", "matiere": 0, "poids": 120.0, "couleur": Color("#c9a467")},
	"terre": {"nom": "Terre", "matiere": 2, "poids": 100.0, "couleur": Color("#6e4a2c")},
	"argile": {"nom": "Argile", "matiere": 4, "poids": 130.0, "couleur": Color("#8c8a84")},
	"boue": {"nom": "Boue", "matiere": 5, "poids": 150.0, "couleur": Color("#4b3b2b")},
	"gravier": {"nom": "Gravier", "matiere": 8, "poids": 140.0, "couleur": Color("#8a8276")},
	"pierre": {"nom": "Pierre", "matiere": 1, "poids": 250.0, "couleur": Color("#7d7a75")},
	"calcaire": {"nom": "Calcaire", "matiere": 9, "poids": 250.0, "couleur": Color("#c4bca8")},
	"pierre_sombre": {"nom": "Pierre sombre", "matiere": 6, "poids": 250.0, "couleur": Color("#4a4744")},
	"silex": {"nom": "Silex", "matiere": 11, "poids": 250.0, "couleur": Color("#2e2e33")},
	"pioche": {"nom": "Pioche", "outil": PICKAXE, "poids": 0.0, "couleur": Color("#8d9196")},
	# 0.0.7.3 : cailloux ramassés au sol (« taille » 1 à 7).
	"caillou": {"nom": "Caillou", "forme": "caillou", "couleur": Color("#7d7a75")},
	"caillou_calcaire": {"nom": "Caillou de calcaire", "forme": "caillou", "couleur": Color("#c4bca8")},
	"caillou_silex": {"nom": "Rognon de silex", "forme": "caillou", "couleur": Color("#2e2e33")},
	# 0.0.7.3 : morceaux de pierre cassée à la pioche (« poids » propre à chacun).
	"eclat_pierre": {"nom": "Éclat de pierre", "forme": "eclat", "couleur": Color("#7d7a75")},
	"eclat_pierre_sombre": {"nom": "Éclat de pierre sombre", "forme": "eclat", "couleur": Color("#4a4744")},
	"eclat_calcaire": {"nom": "Éclat de calcaire", "forme": "eclat", "couleur": Color("#c4bca8")},
	"eclat_silex": {"nom": "Éclat de silex", "forme": "eclat", "couleur": Color("#2e2e33")},
	"charbon": {"nom": "Morceau de charbon", "forme": "eclat", "couleur": Color("#18181b")},
}
# Catégories de l'inventaire en Créatif, dans l'ordre des onglets. La pioche : en Créatif seulement, pour l'instant.
const CATEGORIES := [
	{"id": "natural", "nom": "Matériaux naturels", "objets": ["sable", "terre", "argile", "boue", "gravier", "pierre", "calcaire", "pierre_sombre", "silex"]},
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
		store.selected = 0
	changed.emit()

# area : « grid » (grille de 5 × 10) ou « bar » (barre d'objets).
func size_of(area: String) -> int:
	return BAR_SIZE if area == "bar" else GRID_SIZE

func item(area: String, index: int) -> Dictionary:
	if index < 0 or index >= size_of(area):
		return {}
	return _store()[area][index]

# Survie : seulement les mains et les poches (pas de grille avant les sacs).
func usable(area: String, index: int) -> bool:
	if index < 0 or index >= size_of(area):
		return false
	return mode == CREATIVE or (area == "bar" and (index in HANDS or index in POCKETS))

# Cases de la barre montrées : toutes en Créatif ; en Survie, les mains et les poches.
func bar_slots() -> Array:
	return range(BAR_SIZE).filter(func(index): return usable("bar", index))

# --- Poids et piles ---

static func unit_weight(value: Dictionary) -> float:
	var id: String = value.get("objet", "")
	if value.has("poids"):
		return float(value.poids)
	if value.has("taille"):
		return PEBBLE_WEIGHTS[clampi(int(value.taille), 1, PEBBLE_WEIGHTS.size()) - 1]
	return float(ITEMS.get(id, {}).get("poids", 0.0))

static func count(value: Dictionary) -> int:
	return int(value.get("nombre", 0))

static func unlimited(value: Dictionary) -> bool:
	return not value.is_empty() and not value.has("nombre")

static func stack_weight(value: Dictionary) -> float:
	return 0.0 if unlimited(value) else unit_weight(value) * count(value)

# Objets vraiment identiques (même objet, même taille, même poids) : ils s'empilent.
static func same_kind(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	for key in ["objet", "taille", "poids"]:
		if a.get(key) != b.get(key):
			return false
	return unlimited(a) == unlimited(b)

func _weight_of(indexes: Array, except: int) -> float:
	var total := 0.0
	for index in indexes:
		if index != except:
			total += stack_weight(item("bar", index))
	return total

func pockets_weight(except: int = -1) -> float:
	return _weight_of(POCKETS, except)

func hands_weight(except: int = -1) -> float:
	return _weight_of(HANDS, except)

# Poids encore permis dans une case (Survie) : ce que laissent les autres cases du même groupe (mains ou poches) ;
# sans limite en Créatif.
func room(area: String, index: int) -> float:
	if mode == CREATIVE:
		return INF
	if area != "bar":
		return 0.0
	if index in HANDS:
		return HANDS_LIMIT - hands_weight(index)
	if index in POCKETS:
		return POCKETS_LIMIT - pockets_weight(index)
	return 0.0

# Objet posé au sol à la main (clic droit) : caillou, éclat… (pas les matières, qui se posent dans le terrain).
static func is_object(value: Dictionary) -> bool:
	return ITEMS.get(value.get("objet", ""), {}).has("forme")

# Combien de cet objet tiennent dans la case (en plus de ce qui y est déjà, s'il est identique).
func fit_count(area: String, index: int, value: Dictionary) -> int:
	if not usable(area, index) or value.is_empty():
		return 0
	var there := item(area, index)
	if not there.is_empty() and not same_kind(there, value):
		return 0
	if unlimited(value):
		return 1 if there.is_empty() else 0
	var unit := unit_weight(value)
	var already := count(there)
	if unit <= 0.0 or mode == CREATIVE:
		return 1000000
	return maxi(int(floor((room(area, index) + 0.001) / unit)) - already, 0)

# Met un objet (une pile) dans une case : s'il est identique, s'empile autant que le poids le permet ; sinon échange,
# si l'objet tient dans la case. Rend ce qui reste à tenir (l'objet de la case, le reste de la pile, ou {}).
func put(area: String, index: int, value: Dictionary) -> Dictionary:
	if not usable(area, index):
		return value
	var there := item(area, index)
	if value.is_empty():
		_store()[area][index] = {}
		changed.emit()
		return there
	if not valid_item(value) or (mode == SURVIVAL and unlimited(value)):
		return value
	if not there.is_empty() and same_kind(there, value) and not unlimited(value):
		var moved := mini(fit_count(area, index, value), count(value))
		if moved <= 0:
			return value
		there = there.duplicate()
		there.nombre = count(there) + moved
		_store()[area][index] = there
		changed.emit()
		var rest := value.duplicate()
		rest.nombre = count(value) - moved
		return rest if rest.nombre > 0 else {}
	# Échange : l'objet doit tenir seul dans la case.
	if mode == SURVIVAL and stack_weight(value) > room(area, index) + 0.001:
		return value
	_store()[area][index] = value.duplicate()
	changed.emit()
	return there

func take(area: String, index: int) -> Dictionary:
	return put(area, index, {}) if usable(area, index) else {}

# Ajoute des objets (ramasser, récupérer) : d'abord sur une pile identique, puis dans une case vide.
# Survie : main gauche, main droite, puis poches. Rend le nombre ajouté.
func add(value: Dictionary) -> int:
	if not valid_item(value) or unlimited(value):
		return 0
	var left := count(value)
	var order: Array = HANDS + POCKETS if mode == SURVIVAL else bar_slots().map(func(index): return ["bar", index]) + range(GRID_SIZE).map(func(index): return ["grid", index])
	var places: Array = order.map(func(entry): return entry if entry is Array else ["bar", entry])
	for pass_same in [true, false]:
		for place in places:
			if left <= 0:
				break
			var there := item(place[0], place[1])
			if pass_same != (not there.is_empty()):
				continue
			if not there.is_empty() and not same_kind(there, value):
				continue
			var moved := mini(fit_count(place[0], place[1], value), left)
			if moved <= 0:
				continue
			var stack := value.duplicate()
			stack.nombre = count(there) + moved
			_store()[place[0]][place[1]] = stack
			left -= moved
	if left != count(value):
		changed.emit()
	return count(value) - left

# Retire un objet de la case en main (poser) ; illimité : rien ne change. Faux s'il n'y a rien.
func use_held(amount: int = 1) -> bool:
	var there := held()
	if there.is_empty():
		return false
	if unlimited(there):
		return true
	if count(there) < amount:
		return false
	there = there.duplicate()
	there.nombre = count(there) - amount
	_store().bar[selected()] = there if there.nombre > 0 else {}
	changed.emit()
	return true

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

# Molette : case suivante ou précédente de la barre, en boucle (en Survie : mains et poches).
func cycle(direction: int) -> void:
	var open := bar_slots()
	var at: int = maxi(open.find(selected()), 0)
	select(open[wrapi(at + direction, 0, open.size())])

func held() -> Dictionary:
	return item("bar", selected())

# Valeur pour le monde : matière à poser, PICKAXE, ou -1 (main vide, caillou, éclat).
func held_kind() -> int:
	var id: String = held().get("objet", "")
	if not ITEMS.has(id):
		return -1
	return ITEMS[id].get("matiere", ITEMS[id].get("outil", -1))

static func item_name(value: Dictionary) -> String:
	var id: String = value.get("objet", "")
	return ITEMS[id].nom if ITEMS.has(id) else ""

static func valid_item(value: Variant) -> bool:
	if not value is Dictionary or not ITEMS.has(value.get("objet")):
		return false
	if value.has("nombre") and not ((value.nombre is int or value.nombre is float) and int(value.nombre) > 0):
		return false
	if value.has("taille") and not ((value.taille is int or value.taille is float) and int(value.taille) >= 1 and int(value.taille) <= PEBBLE_WEIGHTS.size()):
		return false
	return not value.has("poids") or ((value.poids is int or value.poids is float) and float(value.poids) > 0.0)

# Poids en 4 chiffres, chaque unité de 1,000 à 999,9 (décision du 14.11.2026) : mg, g, kg, Mg ; virgule française.
static func format_weight(grams: float) -> String:
	if grams <= 0.0:
		return "0,000 g"
	var units := ["mg", "g", "kg", "Mg"]
	var value := grams * 1000.0
	var unit := 0
	while unit < units.size() - 1:
		if snappedf(value, _step(value)) < 1000.0:
			break
		value /= 1000.0
		unit += 1
	var decimals := 3 if value < 9.9995 else (2 if value < 99.995 else (1 if value < 999.95 else 0))
	return (("%." + str(decimals) + "f") % value).replace(".", ",") + " " + units[unit]

static func _step(value: float) -> float:
	return 0.001 if value < 10.0 else (0.01 if value < 100.0 else 0.1)

# --- Sauvegarde (joueur.json) ---
const SAVE_NAMES := {SURVIVAL: "survie", CREATIVE: "creatif"}
const SAVED_FIELDS := ["objet", "nombre", "taille", "poids"]

func to_dict() -> Dictionary:
	var data := {"format": FORMAT}
	for key in SAVE_NAMES:
		var store: Dictionary = _stores[key]
		data[SAVE_NAMES[key]] = {"grille": store.grid.map(_saved), "barre": store.bar.map(_saved), "main": store.selected}
	return data

static func _saved(value: Dictionary) -> Variant:
	if not valid_item(value):
		return null
	var kept := {}
	for field in SAVED_FIELDS:
		if value.has(field):
			kept[field] = value[field]
	return kept

static func _read(value: Variant) -> Dictionary:
	if not valid_item(value):
		return {}
	var kept := {"objet": value.objet}
	for field in ["nombre", "taille"]:
		if value.has(field):
			kept[field] = int(value[field])
	if value.has("poids"):
		kept.poids = float(value.poids)
	return kept

# Lecture tolérante : ancien monde sans inventaire, objet inconnu ou case en trop : ignorés, sans erreur.
# Format 1 (0.0.7.2) : objets sans « nombre » (illimités) ; en Survie il n'y en avait aucun.
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
					var value := _read(cells[index])
					# Survie : jamais d'objet illimité.
					if key == SURVIVAL and unlimited(value):
						continue
					store[pair[1]][index] = value
			var main: Variant = saved.get("main")
			if (main is int or main is float) and int(main) >= 0 and int(main) < BAR_SIZE:
				store.selected = int(main)
	set_mode(mode)
