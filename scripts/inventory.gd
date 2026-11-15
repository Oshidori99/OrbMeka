extends RefCounted
# 0.0.7.2 : inventaire du joueur (données seules ; l'affichage est dans inventory_ui.gd).
# Un inventaire par mode de jeu, gardés tous les deux.
# - Créatif : grille de 5 lignes × 10 colonnes et barre d'objets de 10 cases ; objets pris dans les catégories, illimités.
# - Survie (0.0.7.3, décision du 15.11.2026, issue #40) : presque pas d'inventaire. Seulement deux mains (case 1 : main
#   gauche, case 2 : main droite, 1 kg à elles deux) et quatre poches (cases 3 à 6, 500 g en tout ; 0.0.7.4). Plus tard,
#   sacs et paniers ajouteront des cases (10 au plus dans la barre). Le reste se pose au sol.
# Contenu d'une case :
# - matière (poignées, toutes pareilles) : {"objet": id, "nombre": n} ;
# - objet unique (caillou, éclat, fruit ; 0.0.7.5) : {"objet": id, "pile": [objet, …]} : chacun garde TOUTES ses
#   caractéristiques (taille, poids, forme, orientation, couleur, coups reçus), ramassé, porté, reposé ou sauvegardé ;
#   des objets du même type mais de tailles différentes vont dans la même case ; le dernier pris est le premier reposé ;
# - illimité (Créatif) : sans « nombre » ni « pile » ({"objet": id} + modèle, par exemple « taille » pour un caillou).
# Case vide : {}. Sauvegarde dans joueur.json (« inventaire »).
const COLUMNS := 10
const ROWS := 5
const GRID_SIZE := COLUMNS * ROWS
const BAR_SIZE := 10
const SURVIVAL := "survival"
const CREATIVE := "creative"
const FORMAT := 3
# Survie : mains et poches (cases de la barre), limites en grammes.
const HANDS := [0, 1]
const POCKETS := [2, 3, 4, 5]
# 0.0.7.4 (demande de l'utilisateur) : 1 kg pour les deux mains ensemble (0.0.7.6 : 1,4 kg), 500 g pour les quatre poches.
const HANDS_LIMIT := 3000.0
# 0.0.7.8 (demande de l'utilisateur) : mains 3 kg en tout ; au-delà de TWO_HANDS dans une main, l'objet se porte à deux
# mains (l'autre main ne prend plus rien) et on marche plus lentement (carry_factor).
const TWO_HANDS := 1500.0
const POCKETS_LIMIT := 500.0
# Valeur d'outil de la pioche (même valeur que world.gd PICKAXE) ; -1 : main vide ou objet sans usage.
const PICKAXE := 3
# Poids d'un caillou selon sa taille (1 à 7, comme rocks.gd), en grammes. 0.0.7.6 : la taille 6 (1,1 kg) se ramasse ; la 7, non.
const PEBBLE_WEIGHTS := [50.0, 120.0, 250.0, 400.0, 700.0, 1100.0, 2000.0]
const PICKABLE_SIZE := 6
# 0.0.7.5 : pommes en trois tailles (taille 2 : la normale) et cinq couleurs, comme les vraies.
const APPLE_WEIGHTS := [130.0, 200.0, 300.0]
const APPLE_SIZES := [0.075, 0.105, 0.13]
const APPLE_COLORS := [Color("#6aa531"), Color("#b5281c"), Color("#dcbb2c"), Color("#7a4a26"), Color("#c9452a")]
const APPLE_COLOR_NAMES := ["verte", "rouge", "jaune", "brune", "rouge et jaune"]
# Caractéristiques gardées pour chaque objet unique (et leur type).
const INSTANCE_FIELDS := {"taille": TYPE_INT, "poids": TYPE_FLOAT, "forme": TYPE_INT, "rotation": TYPE_FLOAT, "couleur": TYPE_INT, "coups": TYPE_INT, "diametre": TYPE_FLOAT,
	# 0.0.7.8 : bâtons et troncs : longueur (m), épaisseur (cm), essence (espèce d'arbre), âge et souplesse (1 à 5,
	# enregistrés dès maintenant ; leurs effets viendront avec la fabrication, #228).
	"longueur": TYPE_FLOAT, "epaisseur": TYPE_FLOAT, "essence": TYPE_INT, "age": TYPE_INT, "souplesse": TYPE_INT}
# Matières : valeurs de smooth_terrain.gd (SAND 0, STONE 1, DIRT 2, CLAY 4, MUD 5, DARK_STONE 6, GRAVEL 8, LIMESTONE 9,
# FLINT 11). Poids : une poignée. 0.0.7.6 (plus réaliste, accepté par l'utilisateur) : une grosse poignée d'environ 0,25 L × la
# densité de la matière ; elle compte toujours pour une sous-cellule de 50 cm (règle de jeu).
# « forme » : objet unique (caillou, éclat, fruit) ; « aspect » : rendu des pierres (0 pierre, 1 calcaire, 2 silex).
const ITEMS := {
	"sable": {"nom": "Sable", "matiere": 0, "poids": 400.0, "couleur": Color("#c9a467")},
	"terre": {"nom": "Terre", "matiere": 2, "poids": 325.0, "couleur": Color("#6e4a2c")},
	"argile": {"nom": "Argile", "matiere": 4, "poids": 450.0, "couleur": Color("#8c8a84")},
	"boue": {"nom": "Boue", "matiere": 5, "poids": 400.0, "couleur": Color("#4b3b2b")},
	"gravier": {"nom": "Gravier", "matiere": 8, "poids": 440.0, "couleur": Color("#8a8276")},
	"pierre": {"nom": "Pierre", "matiere": 1, "poids": 650.0, "couleur": Color("#7d7a75")},
	"calcaire": {"nom": "Calcaire", "matiere": 9, "poids": 650.0, "couleur": Color("#c4bca8")},
	"pierre_sombre": {"nom": "Pierre sombre", "matiere": 6, "poids": 750.0, "couleur": Color("#4a4744")},
	"silex": {"nom": "Silex", "matiere": 11, "poids": 650.0, "couleur": Color("#2e2e33")},
	"pioche": {"nom": "Pioche", "outil": PICKAXE, "poids": 0.0, "couleur": Color("#8d9196")},
	# 0.0.7.3 : cailloux ramassés au sol (« taille » 1 à 7).
	"caillou": {"nom": "Caillou", "forme": "caillou", "aspect": 0, "couleur": Color("#7d7a75")},
	"caillou_calcaire": {"nom": "Caillou de calcaire", "forme": "caillou", "aspect": 1, "couleur": Color("#c4bca8")},
	"caillou_silex": {"nom": "Rognon de silex", "forme": "caillou", "aspect": 2, "couleur": Color("#2e2e33")},
	# 0.0.7.3 : morceaux de pierre cassée à la pioche (« poids » propre à chacun).
	"eclat_pierre": {"nom": "Éclat de pierre", "forme": "eclat", "aspect": 0, "couleur": Color("#7d7a75")},
	"eclat_pierre_sombre": {"nom": "Éclat de pierre sombre", "forme": "eclat", "couleur": Color("#4a4744")},
	"eclat_calcaire": {"nom": "Éclat de calcaire", "forme": "eclat", "aspect": 1, "couleur": Color("#c4bca8")},
	"eclat_silex": {"nom": "Éclat de silex", "forme": "eclat", "aspect": 2, "couleur": Color("#2e2e33")},
	"charbon": {"nom": "Morceau de charbon", "forme": "eclat", "couleur": Color("#18181b")},
	# 0.0.7.5 : fruits (onglet Fruits en Créatif).
	"pomme": {"nom": "Pomme", "forme": "fruit", "couleur": Color("#b5281c")},
	"noisette": {"nom": "Noisette", "forme": "fruit", "poids": 3.0, "couleur": Color("#8a5a2b")},
	# 0.0.7.8 : bois d'un arbre coupé (#212) : tronc et branches, chacun unique.
	"tronc": {"nom": "Tronc", "forme": "bois", "couleur": Color("#6b4a2e")},
	"branche": {"nom": "Branche", "forme": "bois", "couleur": Color("#7a5634")},
}
# Catégories de l'inventaire en Créatif, dans l'ordre des onglets (0.0.7.5 : Cailloux et Fruits ; l'onglet Inventaire,
# tout à droite, est dans inventory_ui.gd). Objets illimités : identifiant, avec leur modèle (CATALOG_MODELS).
const CATEGORIES := [
	{"id": "natural", "nom": "Matériaux naturels", "objets": ["sable", "terre", "argile", "boue", "gravier", "pierre", "calcaire", "pierre_sombre", "silex"]},
	{"id": "pebbles", "nom": "Cailloux", "objets": ["caillou", "caillou_calcaire", "caillou_silex"]},
	{"id": "fruits", "nom": "Fruits", "objets": ["pomme", "noisette"]},
	{"id": "tools", "nom": "Outils", "objets": ["pioche"]},
]
# Pour l'instant une seule version par objet : cailloux de taille 4, pomme rouge de taille 2.
const CATALOG_MODELS := {"caillou": {"taille": 4}, "caillou_calcaire": {"taille": 4}, "caillou_silex": {"taille": 4}, "pomme": {"taille": 2, "couleur": 1}}

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

# --- Objets ---

static func is_object(value: Dictionary) -> bool:
	return ITEMS.get(value.get("objet", ""), {}).has("forme")

static func catalog_item(id: String) -> Dictionary:
	var value := {"objet": id}
	value.merge(CATALOG_MODELS.get(id, {}))
	return value

# Caractéristiques d'un objet (sans son identifiant) / objet complet à plat {"objet": id, …} (au sol, illimité).
static func traits(value: Dictionary) -> Dictionary:
	var kept := {}
	for field in INSTANCE_FIELDS:
		if value.has(field):
			kept[field] = value[field]
	return kept

static func flat(id: String, instance: Dictionary) -> Dictionary:
	var value := {"objet": id}
	value.merge(traits(instance))
	return value

# Un seul objet (ou une poignée) prêt à mettre dans une case.
static func single(flat_value: Dictionary) -> Dictionary:
	if is_object(flat_value):
		return {"objet": flat_value.objet, "pile": [traits(flat_value)]}
	return {"objet": flat_value.objet, "nombre": 1}

# --- Poids et piles ---

static func instance_weight(id: String, instance: Dictionary) -> float:
	if instance.has("poids"):
		return float(instance.poids)
	var spec: Dictionary = ITEMS.get(id, {})
	if instance.has("taille"):
		var size := int(instance.taille)
		if id == "pomme":
			return APPLE_WEIGHTS[clampi(size, 1, APPLE_WEIGHTS.size()) - 1]
		if spec.get("forme", "") == "caillou":
			return PEBBLE_WEIGHTS[clampi(size, 1, PEBBLE_WEIGHTS.size()) - 1]
	if id == "pomme":
		return APPLE_WEIGHTS[1]
	return float(spec.get("poids", 0.0))

# Poids d'une unité : le dernier objet d'une pile (celui qui sortira en premier), une poignée, ou le modèle illimité.
static func unit_weight(value: Dictionary) -> float:
	var id: String = value.get("objet", "")
	if value.has("pile") and not value.pile.is_empty():
		return instance_weight(id, value.pile[-1])
	return instance_weight(id, value)

static func count(value: Dictionary) -> int:
	if value.has("pile"):
		return value.pile.size()
	return int(value.get("nombre", 0))

static func unlimited(value: Dictionary) -> bool:
	return not value.is_empty() and not value.has("nombre") and not value.has("pile")

static func stack_weight(value: Dictionary) -> float:
	if unlimited(value):
		return 0.0
	if value.has("pile"):
		var total := 0.0
		for instance: Dictionary in value.pile:
			total += instance_weight(value.objet, instance)
		return total
	return unit_weight(value) * count(value)

# Même type d'objet : il s'empile dans la même case (0.0.7.5 : même de tailles différentes, chacun gardé à part).
# Illimités : seulement s'ils ont le même modèle.
static func same_kind(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty() or a.get("objet") != b.get("objet") or unlimited(a) != unlimited(b):
		return false
	return not unlimited(a) or traits(a) == traits(b)

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

# Poids encore permis pour une case entière (Survie) : ce que laissent les autres cases du même groupe ;
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

# Sépare les « amount » premiers objets d'une pile (ou poignées) du reste : [début, reste].
static func _split(value: Dictionary, amount: int) -> Array:
	var first := value.duplicate(true)
	var rest := value.duplicate(true)
	if value.has("pile"):
		first.pile = value.pile.slice(0, amount)
		rest.pile = value.pile.slice(amount)
	else:
		first.nombre = amount
		rest.nombre = count(value) - amount
	return [first if count(first) > 0 else {}, rest if count(rest) > 0 else {}]

# 0.0.7.8 : porté à deux mains (une main au-delà de TWO_HANDS) ; vitesse de marche selon le poids dans les mains :
# 1 jusqu'à TWO_HANDS, puis jusqu'à 0,6 à HANDS_LIMIT.
func two_handed() -> int:
	if mode != SURVIVAL:
		return -1
	for index in HANDS:
		if stack_weight(item("bar", index)) > TWO_HANDS:
			return index
	return -1

func carry_factor() -> float:
	if mode != SURVIVAL:
		return 1.0
	return 1.0 - 0.4 * clampf((hands_weight() - TWO_HANDS) / (HANDS_LIMIT - TWO_HANDS), 0.0, 1.0)

# 0.0.7.8 : un tronc ou une branche (#212), à plat {"objet": …, caractéristiques} : épaisseur (cm), longueur (m),
# essence, âge (1 très jeune à 5 vieux, un peu pourri) et souplesse (1 cassant à 5 très souple : surtout le bois jeune ;
# noisetier plus souple, pin plus raide) ; taille 1 à 7 selon l'épaisseur ; poids : bois frais d'environ 0,75 kg/L.
const WOOD_SIZES := [2.0, 3.0, 4.0, 6.0, 8.0, 11.0, 15.0]

static func wood_piece(id: String, essence: int, thickness: float, length: float, rng: RandomNumberGenerator) -> Dictionary:
	var age := clampi(int(round(rng.randfn(2.6, 1.0))), 1, 5)
	var supple := clampi(6 - age + (1 if essence == 1 else 0) - (1 if essence == 2 else 0) + rng.randi_range(-1, 1), 1, 5)
	var size := WOOD_SIZES.size()
	for index in range(WOOD_SIZES.size()):
		if thickness <= WOOD_SIZES[index]:
			size = index + 1
			break
	var radius := thickness / 200.0
	var weight := PI * radius * radius * length * 750000.0 * (0.7 if age == 5 else 1.0)
	return {"objet": id, "taille": size, "epaisseur": snappedf(thickness, 0.1), "longueur": snappedf(length, 0.01), "essence": essence, "age": age, "souplesse": supple, "poids": snappedf(weight, 1.0), "forme": rng.randi_range(1, 7)}

# Combien des premiers objets de « value » tiennent encore dans la case (en plus de ce qui y est, s'il est du même type).
func fit_count(area: String, index: int, value: Dictionary) -> int:
	if not usable(area, index) or value.is_empty() or (mode == SURVIVAL and unlimited(value)):
		return 0
	var there := item(area, index)
	if not there.is_empty() and not same_kind(there, value):
		return 0
	if unlimited(value):
		return 1 if there.is_empty() else 0
	if mode == CREATIVE:
		return count(value)
	var free := room(area, index) - stack_weight(there) + 0.001
	# 0.0.7.8 : à deux mains : une main qui porte plus de TWO_HANDS laisse l'autre vide ; et une main ne dépasse
	# TWO_HANDS que si l'autre est vide.
	if area == "bar" and index in HANDS:
		var other: int = HANDS[1] if index == HANDS[0] else HANDS[0]
		var other_weight := stack_weight(item("bar", other))
		if other_weight > TWO_HANDS:
			return 0
		if other_weight > 0.0:
			free = minf(free, TWO_HANDS - stack_weight(there) + 0.001)
	var fits := 0
	if value.has("pile"):
		for instance: Dictionary in value.pile:
			free -= instance_weight(value.objet, instance)
			if free < 0.0:
				break
			fits += 1
		return fits
	var unit := unit_weight(value)
	return count(value) if unit <= 0.0 else mini(int(floor(free / unit)), count(value))

# Ajoute ce qui tient de « value » dans la case (vide, ou du même type) ; rend ce qui reste.
func _merge_into(area: String, index: int, value: Dictionary) -> Dictionary:
	var moved := fit_count(area, index, value)
	if moved <= 0:
		return value
	var parts := _split(value, moved) if not unlimited(value) else [value, {}]
	var there := item(area, index)
	if there.is_empty():
		_store()[area][index] = parts[0].duplicate(true)
	else:
		var merged := there.duplicate(true)
		if merged.has("pile"):
			merged.pile.append_array(parts[0].pile.duplicate(true))
		else:
			merged.nombre = count(merged) + count(parts[0])
		_store()[area][index] = merged
	changed.emit()
	return parts[1]

# Met un objet (une pile) dans une case : s'il est du même type, s'empile autant que le poids le permet ; sinon échange,
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
	if there.is_empty() or (same_kind(there, value) and not unlimited(value)):
		return _merge_into(area, index, value)
	# Échange : l'objet doit tenir seul dans la case.
	if mode == SURVIVAL and stack_weight(value) > room(area, index) + 0.001:
		return value
	_store()[area][index] = value.duplicate(true)
	changed.emit()
	return there

func take(area: String, index: int) -> Dictionary:
	return put(area, index, {}) if usable(area, index) else {}

func _places() -> Array:
	if mode == SURVIVAL:
		return (HANDS + POCKETS).map(func(index): return ["bar", index])
	return bar_slots().map(func(index): return ["bar", index]) + range(GRID_SIZE).map(func(index): return ["grid", index])

# Range des objets n'importe où (retour d'un objet tenu dans l'écran d'inventaire) : d'abord sur un même type, puis dans
# une case vide. Rend le nombre ajouté.
func add(value: Dictionary) -> int:
	if not valid_item(value) or unlimited(value):
		return 0
	var rest := value
	for pass_same in [true, false]:
		for place in _places():
			if rest.is_empty():
				break
			var there := item(place[0], place[1])
			if pass_same == there.is_empty():
				continue
			rest = _merge_into(place[0], place[1], rest)
	return count(value) - count(rest)

# 0.0.7.5 (demande de l'utilisateur) : ramasser ou récupérer va dans la case choisie de la barre ; si toute la barre est
# pleine, dans une case libre de l'inventaire. Rend {"added": nombre ajouté, "reason": "" | "occupee" | "lourd" | "plein"}.
func add_to_selected(value: Dictionary) -> Dictionary:
	if not valid_item(value) or unlimited(value):
		return {"added": 0, "reason": "plein"}
	var rest := _merge_into("bar", selected(), value)
	var bar_full := bar_slots().all(func(index): return not item("bar", index).is_empty())
	if not rest.is_empty() and bar_full:
		for pass_same in [true, false]:
			for index in range(GRID_SIZE):
				if rest.is_empty() or not usable("grid", index):
					continue
				var there := item("grid", index)
				if pass_same == there.is_empty():
					continue
				rest = _merge_into("grid", index, rest)
	var added := count(value) - count(rest)
	var reason := ""
	if added < count(value):
		var chosen := held()
		var other := not chosen.is_empty() and not same_kind(chosen, value)
		if other and not bar_full:
			reason = "occupee"
		elif other or mode == CREATIVE:
			reason = "plein"
		else:
			reason = "lourd"
	return {"added": added, "reason": reason}

# Retire des poignées de la case en main (poser une matière) ; illimité : rien ne change. Faux s'il n'y en a pas assez.
func use_held(amount: int = 1) -> bool:
	var there := held()
	if there.is_empty():
		return false
	if unlimited(there):
		return true
	if count(there) < amount:
		return false
	var parts := _split(there, count(there) - amount)
	_store().bar[selected()] = parts[0]
	changed.emit()
	return true

# 0.0.7.5 : prend en main un seul objet à reposer : le dernier pris (pile) ; illimité : une copie de son modèle.
# Rend l'objet à plat {"objet": id, …caractéristiques}, ou {}.
func pop_held() -> Dictionary:
	var there := held()
	if there.is_empty():
		return {}
	if unlimited(there):
		return there.duplicate(true)
	if there.has("pile"):
		var kept := there.duplicate(true)
		var last: Dictionary = kept.pile.pop_back()
		_store().bar[selected()] = kept if not kept.pile.is_empty() else {}
		changed.emit()
		return flat(there.objet, last)
	use_held(1)
	return {"objet": there.objet}

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

# Valeur pour le monde : matière à poser, PICKAXE, ou -1 (main vide, caillou, éclat, fruit).
func held_kind() -> int:
	var id: String = held().get("objet", "")
	if not ITEMS.has(id):
		return -1
	return ITEMS[id].get("matiere", ITEMS[id].get("outil", -1))

static func item_name(value: Dictionary) -> String:
	var id: String = value.get("objet", "")
	return ITEMS[id].nom if ITEMS.has(id) else ""

static func _valid_traits(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for field in value:
		if not INSTANCE_FIELDS.has(field) or not (value[field] is int or value[field] is float):
			return false
	if value.has("taille") and (int(value.taille) < 1 or int(value.taille) > PEBBLE_WEIGHTS.size()):
		return false
	if value.has("couleur") and (int(value.couleur) < 0 or int(value.couleur) >= APPLE_COLORS.size()):
		return false
	return not value.has("poids") or float(value.poids) > 0.0

static func valid_item(value: Variant) -> bool:
	if not value is Dictionary or not ITEMS.has(value.get("objet")):
		return false
	if value.has("nombre") and not ((value.nombre is int or value.nombre is float) and int(value.nombre) > 0):
		return false
	if value.has("pile"):
		return value.pile is Array and not value.pile.is_empty() and is_object(value) and value.pile.all(_valid_traits)
	var rest: Dictionary = value.duplicate()
	rest.erase("objet")
	rest.erase("nombre")
	return _valid_traits(rest)

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

func to_dict() -> Dictionary:
	var data := {"format": FORMAT}
	for key in SAVE_NAMES:
		var store: Dictionary = _stores[key]
		data[SAVE_NAMES[key]] = {"grille": store.grid.map(_saved), "barre": store.bar.map(_saved), "main": store.selected}
	return data

static func _saved(value: Dictionary) -> Variant:
	if not valid_item(value):
		return null
	var kept := {"objet": value.objet}
	if value.has("pile"):
		kept.pile = value.pile.map(func(instance): return traits(instance))
	elif value.has("nombre"):
		kept.nombre = int(value.nombre)
	else:
		kept.merge(traits(value))
	return kept

static func _clean_traits(value: Dictionary) -> Dictionary:
	var kept := {}
	for field in traits(value):
		kept[field] = int(value[field]) if INSTANCE_FIELDS[field] == TYPE_INT else float(value[field])
	return kept

# Lecture d'une case ; formats 1 et 2 (0.0.7.2 à 0.0.7.4) : un caillou ou un éclat avec « nombre » devient une pile.
static func _read(value: Variant) -> Dictionary:
	if not valid_item(value):
		return {}
	var kept := {"objet": value.objet}
	if value.has("pile"):
		kept.pile = value.pile.map(func(instance): return _clean_traits(instance))
	elif value.has("nombre") and is_object(value):
		var one := _clean_traits(value)
		kept.pile = []
		for index in range(int(value.nombre)):
			kept.pile.append(one.duplicate())
	elif value.has("nombre"):
		kept.nombre = int(value.nombre)
	else:
		kept.merge(_clean_traits(value))
	return kept

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
					var value := _read(cells[index])
					# Survie : jamais d'objet illimité.
					if key == SURVIVAL and unlimited(value):
						continue
					store[pair[1]][index] = value
			var main: Variant = saved.get("main")
			if (main is int or main is float) and int(main) >= 0 and int(main) < BAR_SIZE:
				store.selected = int(main)
	set_mode(mode)
