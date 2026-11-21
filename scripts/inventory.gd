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
# 0.0.7.19 (demande de l'utilisateur) : 4 kg par main, 8 kg à deux mains ; et un volume : 1,5 L par main, 3 L à deux
# mains, 0,5 L pour les poches (instance_volume : le bois compte par sa longueur, 1 L par mètre). Au-delà de ce que tient
# une main (poids, volume ou nombre), l'objet se porte à deux mains (l'autre main ne prend plus rien) et on marche plus
# lentement (carry_factor). Petits objets qui tomberaient : un nombre au plus par main (HAND_COUNTS).
const HANDS_LIMIT := 8000.0
const TWO_HANDS := 4000.0
const HAND_VOLUME := 1.5
const HANDS_VOLUME := 3.0
const POCKETS_LIMIT := 500.0
const POCKETS_VOLUME := 0.5
const HAND_COUNTS := {"noisette": 5, "pomme": 2, "caillou": 4, "eclat": 4}
# 0.0.8.3 (demandes de l'utilisateur) : dans les mains, les objets comptés (HAND_COUNTS) ne comptent plus en litres, seulement
# en nombre : 2 pommes par main, 3 pommes en tout pour les deux mains ; 5 noisettes par main, 10 avec les deux
# (BOTH_HANDS_COUNTS : total des deux mains, une pile tenue à deux mains comprise). Les poches gardent poids et volume,
# avec en plus un nombre au plus par poche (POCKET_COUNTS : 15 noisettes, plus faciles à garder en poche qu'en main).
const BOTH_HANDS_COUNTS := {"pomme": 3, "noisette": 10}
const POCKET_COUNTS := {"noisette": 15}
const HANDFUL_VOLUME := 0.25
const WOOD_LITERS_PER_METER := 1.0
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
	"longueur": TYPE_FLOAT, "epaisseur": TYPE_FLOAT, "fin": TYPE_FLOAT, "essence": TYPE_INT, "age": TYPE_INT, "souplesse": TYPE_INT,
	# 0.0.7.26 (#212) : bois mort (1), tordu (1), pourri (1), rejet de noisetier (1) ; 0 ou absent : non.
	"morte": TYPE_INT, "tordue": TYPE_INT, "pourrie": TYPE_INT, "rejet": TYPE_INT}
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
	# 0.0.8.2 (#231) : orbe de retour (return_orb.gd), 200 g, 2 dl (volume : poids / 1 kg par L).
	"orbe_retour": {"nom": "Orbe de retour", "forme": "orbe", "poids": 200.0, "couleur": Color("#3fd6c8")},
	# 0.0.7.8 : bois d'un arbre coupé (#212) : tronc et branches, chacun unique.
	"tronc": {"nom": "Tronc", "forme": "bois", "couleur": Color("#6b4a2e")},
	"branche": {"nom": "Branche", "forme": "bois", "couleur": Color("#7a5634")},
	# 0.0.7.12 (demande de l'utilisateur) : branche cassée avec ses feuilles (« Tige de noisetier », « Rameau de
	# pommier »…) ; seule la taille compte : un même petit feuillage pour tous (icône, au sol).
	"rameau": {"nom": "Rameau", "forme": "bois", "feuilles": true, "couleur": Color("#7a5634")},
}
const LEAFY_NAMES := ["Rameau de pommier", "Tige de noisetier", "Rameau de pin", "Rameau de tilleul"]
# 0.0.7.18 : bois du Créatif : tronc (gros bout, petit bout) puis branche (cm), 1 m de long.
const CATALOG_WOOD := [20.0, 18.0, 4.0, 3.4]
const ESSENCE_NAMES := ["pommier", "noisetier", "pin", "tilleul"]
# Catégories de l'inventaire en Créatif, dans l'ordre des onglets (0.0.7.5 : Cailloux et Fruits ; l'onglet Inventaire,
# tout à droite, est dans inventory_ui.gd). Objets illimités : identifiant, avec leur modèle (CATALOG_MODELS).
const CATEGORIES := [
	{"id": "natural", "nom": "Matériaux naturels", "objets": ["sable", "terre", "argile", "boue", "gravier", "pierre", "calcaire", "pierre_sombre", "silex"]},
	{"id": "pebbles", "nom": "Cailloux", "objets": ["caillou", "caillou_calcaire", "caillou_silex"]},
	{"id": "fruits", "nom": "Fruits", "objets": ["pomme", "noisette"]},
	{"id": "tools", "nom": "Outils", "objets": ["pioche"]},
	# 0.0.7.18 (demande de l'utilisateur) : pour chaque espèce, un tronc (20 cm × 1 m) et une branche (4 cm × 1 m),
	# séparés ; « objet:essence » (catalog_item).
	{"id": "wood", "nom": "Bois", "objets": ["tronc:0", "branche:0", "tronc:1", "branche:1", "tronc:2", "branche:2", "tronc:3", "branche:3"]},
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

# Cases de la barre montrées : toutes en Créatif ; en Survie, les mains et les poches. 0.0.7.10 : objet lourd porté à
# deux mains : une seule case pour les deux mains (l'autre main n'est plus une case : une de moins dans la barre).
func bar_slots() -> Array:
	var heavy := two_handed()
	return range(BAR_SIZE).filter(func(index): return usable("bar", index) and not (heavy >= 0 and index in HANDS and index != heavy))

# --- Objets ---

static func is_object(value: Dictionary) -> bool:
	return ITEMS.get(value.get("objet", ""), {}).has("forme")

static func catalog_item(id: String) -> Dictionary:
	# 0.0.7.18 : bois du Créatif : « tronc:2 » = un tronc de pin, toujours le même (graine fixe), illimité.
	if id.contains(":"):
		var parts := id.split(":")
		var essence := int(parts[1])
		var trunk: bool = parts[0] == "tronc"
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id)
		var wood := wood_piece(parts[0], essence, CATALOG_WOOD[0] if trunk else CATALOG_WOOD[2], 1.0, rng)
		wood.epaisseur = CATALOG_WOOD[0] if trunk else CATALOG_WOOD[2]
		wood.fin = CATALOG_WOOD[1] if trunk else CATALOG_WOOD[3]
		wood.age = 2
		wood.forme = 1
		return wood
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

# 0.0.7.19 : volume (litres) d'un objet ou d'une poignée : poignée 0,25 L ; bois : sa longueur (1 L par mètre : une bûche
# se tient dans les bras, c'est son poids qui la limite) ; fruit : sa boule ; caillou, éclat : son poids / 2,6 kg par L.
static func instance_volume(id: String, instance: Dictionary) -> float:
	var spec: Dictionary = ITEMS.get(id, {})
	if spec.has("matiere"):
		return HANDFUL_VOLUME
	if spec.has("outil"):
		return 0.0
	match spec.get("forme", ""):
		"bois":
			return float(instance.get("longueur", 1.0)) * WOOD_LITERS_PER_METER
		"fruit":
			var diameter: float = float(instance.get("diametre", APPLE_SIZES[1] if id == "pomme" else 0.02))
			return 4.0 / 3.0 * PI * pow(diameter * 0.5, 3.0) * 1000.0
		"caillou", "eclat":
			return instance_weight(id, instance) / 2600.0
	return instance_weight(id, instance) / 1000.0

static func stack_volume(value: Dictionary) -> float:
	if unlimited(value) or value.is_empty():
		return 0.0
	if value.has("pile"):
		var total := 0.0
		for instance: Dictionary in value.pile:
			total += instance_volume(value.objet, instance)
		return total
	return instance_volume(value.objet, value) * count(value)

# Combien au plus dans une main (petits objets qui tomberaient) ; 0 : pas de limite.
static func hand_count(id: String) -> int:
	if HAND_COUNTS.has(id):
		return HAND_COUNTS[id]
	return HAND_COUNTS.get(ITEMS.get(id, {}).get("forme", ""), 0)

# Une main ne suffit pas : trop lourd, trop encombrant ou trop nombreux pour une main.
static func needs_both_hands(value: Dictionary) -> bool:
	if value.is_empty() or unlimited(value):
		return false
	var limit := hand_count(value.objet)
	# 0.0.8.3 : objet compté : son nombre seulement (pas ses litres).
	if limit > 0:
		return stack_weight(value) > TWO_HANDS + 0.001 or count(value) > limit
	return stack_weight(value) > TWO_HANDS + 0.001 or stack_volume(value) > HAND_VOLUME + 0.0001

# 0.0.8.3 : nombre au plus pour les deux mains ensemble (défaut : deux fois celui d'une main) ; 0 : pas de limite.
static func both_hands_count(id: String) -> int:
	return int(BOTH_HANDS_COUNTS.get(id, hand_count(id) * 2))

# 0.0.8.3 : nombre au plus dans une poche ; 0 : pas de limite (poids et volume seulement).
static func pocket_count(id: String) -> int:
	return int(POCKET_COUNTS.get(id, 0))

# 0.0.8.3 : message du refus « nombre » : par main, à deux mains, et par poche s'il y a une limite.
static func count_rule(value: Dictionary) -> String:
	var id: String = value.get("objet", "")
	var text := "%d %s au plus dans une main, %d à deux mains" % [hand_count(id), plural_name(value), both_hands_count(id)]
	if pocket_count(id) > 0:
		text += ", %d par poche" % pocket_count(id)
	return text + "."

# Nom au pluriel, en minuscules (« noisettes », « cailloux », « éclats de silex »).
static func plural_name(value: Dictionary) -> String:
	var name := item_name(value).to_lower()
	var words := name.split(" ")
	var first: String = words[0]
	if first.ends_with("au") or first.ends_with("ou") and first in ["caillou", "bijou", "genou"]:
		first += "x"
	elif not first.ends_with("s") and not first.ends_with("x"):
		first += "s"
	words[0] = first
	return " ".join(words)

static func format_volume(liters: float) -> String:
	return (("%.2f" if liters < 0.995 else "%.1f") % maxf(liters, 0.0)).replace(".", ",") + " L"

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

func _volume_of(indexes: Array, except: int) -> float:
	var total := 0.0
	for index in indexes:
		if index != except:
			total += stack_volume(item("bar", index))
	return total

func hands_volume(except: int = -1) -> float:
	return _volume_of(HANDS, except)

func pockets_volume(except: int = -1) -> float:
	return _volume_of(POCKETS, except)

# 0.0.7.19 : pourquoi le dernier objet n'a pas tenu (fit_count) : "lourd", "encombrant" ou "nombre".
var last_refusal := ""

# Une case de main peut-elle tenir ce poids, ce volume et ce nombre (l'autre main étant ce qu'elle est) ?
func _hand_holds(index: int, id: String, weight: float, volume: float, amount: int) -> String:
	var other: int = HANDS[1] if index == HANDS[0] else HANDS[0]
	var other_value := item("bar", other)
	var limit := hand_count(id)
	if not other_value.is_empty():
		if needs_both_hands(other_value):
			return "lourd"
		# Une seule main libre.
		if weight > TWO_HANDS + 0.001:
			return "lourd"
		# 0.0.8.3 : objet compté : son nombre dans cette main, et le total des deux mains (pas ses litres).
		if limit > 0:
			var same := count(other_value) if other_value.get("objet", "") == id else 0
			if amount > limit or amount + same > both_hands_count(id):
				return "nombre"
			return ""
		if volume > HAND_VOLUME + 0.0001:
			return "encombrant"
		return ""
	# Les deux mains libres : une main, ou les deux pour un seul objet (ou une seule pile).
	if weight > HANDS_LIMIT + 0.001:
		return "lourd"
	if limit > 0:
		return "nombre" if amount > both_hands_count(id) else ""
	if volume > HANDS_VOLUME + 0.0001:
		return "encombrant"
	return ""

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
		if needs_both_hands(item("bar", index)):
			return index
	return -1

func carry_factor() -> float:
	if mode != SURVIVAL:
		return 1.0
	return 1.0 - 0.4 * clampf((hands_weight() - TWO_HANDS) / (HANDS_LIMIT - TWO_HANDS), 0.0, 1.0)

# 0.0.7.19 : remplissage (0 à 1) des mains et des poches : poids et volume (barres de l'inventaire et du jeu).
func fill(group: String) -> Dictionary:
	if group == "mains":
		return {"poids": hands_weight() / HANDS_LIMIT, "volume": hands_volume() / HANDS_VOLUME}
	return {"poids": pockets_weight() / POCKETS_LIMIT, "volume": pockets_volume() / POCKETS_VOLUME}

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
	# 0.0.7.19 : objet après objet : poids, volume et nombre (mains), poids et volume (poches).
	last_refusal = ""
	var weight := stack_weight(there)
	var volume := stack_volume(there)
	var amount := count(there)
	var fits := 0
	for unit in range(count(value)):
		var instance: Dictionary = value.pile[unit] if value.has("pile") else value
		weight += instance_weight(value.objet, instance)
		volume += instance_volume(value.objet, instance)
		amount += 1
		var why := ""
		if area == "bar" and index in HANDS:
			why = _hand_holds(index, value.objet, weight, volume, amount)
		elif area == "bar" and index in POCKETS:
			if pockets_weight(index) + weight > POCKETS_LIMIT + 0.001:
				why = "lourd"
			elif pockets_volume(index) + volume > POCKETS_VOLUME + 0.0001:
				why = "encombrant"
			elif pocket_count(value.objet) > 0 and amount > pocket_count(value.objet):
				why = "nombre"
		else:
			why = "lourd"
		if not why.is_empty():
			last_refusal = why
			break
		fits += 1
	return fits

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

# 0.0.7.30 (touche Jeter) : retire un seul objet d'une case (le dernier pris) ou tout le tas (all) ; un objet illimité
# (Créatif) vide la case. Rend ce qui est retiré, comme une case ({} si rien).
func remove(area: String, index: int, all: bool = false) -> Dictionary:
	if not usable(area, index):
		return {}
	var there := item(area, index)
	if there.is_empty():
		return {}
	if all or unlimited(there) or count(there) <= 1:
		_store()[area][index] = {}
		changed.emit()
		return there.duplicate(true)
	var parts := _split(there, count(there) - 1)
	_store()[area][index] = parts[0]
	changed.emit()
	return parts[1]

# Les objets d'une case, un par un, à plat (pour les poser au sol).
static func units(value: Dictionary) -> Array:
	if value.is_empty():
		return []
	if unlimited(value):
		return [value.duplicate(true)]
	if value.has("pile"):
		return value.pile.map(func(instance): return flat(value.objet, instance))
	var result := []
	for index in range(maxi(count(value), 1)):
		result.append({"objet": value.objet})
	return result

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
	# 0.0.7.10 (Survie) : case choisie pleine : dans l'autre main libre (la droite d'abord), qu'on voit le tenir.
	if mode == SURVIVAL and not rest.is_empty():
		for index in [HANDS[1], HANDS[0]]:
			if not rest.is_empty() and index != selected() and index in bar_slots():
				rest = _merge_into("bar", index, rest)
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
			reason = last_refusal if not last_refusal.is_empty() else "lourd"
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
	# 0.0.7.10 : l'autre main tient aussi l'objet lourd : c'est la même case.
	var heavy := two_handed()
	if heavy >= 0 and index in HANDS:
		index = heavy
	_store().selected = index
	changed.emit()
	return true

# Molette : case suivante ou précédente de la barre, en boucle (en Survie : mains et poches).
func cycle(direction: int) -> void:
	var open := bar_slots()
	var at: int = maxi(open.find(selected()), 0)
	select(open[wrapi(at + direction, 0, open.size())])

func held() -> Dictionary:
	var heavy := two_handed()
	if heavy >= 0 and selected() in HANDS:
		return item("bar", heavy)
	return item("bar", selected())

# Valeur pour le monde : matière à poser, PICKAXE, ou -1 (main vide, caillou, éclat, fruit).
func held_kind() -> int:
	var id: String = held().get("objet", "")
	if not ITEMS.has(id):
		return -1
	return ITEMS[id].get("matiere", ITEMS[id].get("outil", -1))

# 0.0.7.26 (#212) : qualité d'un bâton comme manche d'outil. Bon manche : droit, sain, 40 à 70 cm, 2 à 4 cm d'épaisseur ;
# noisetier excellent (rejet : le meilleur), tilleul et pin moyens ; pourri : fragile. 0 mauvais, 1 moyen, 2 bon,
# 3 excellent (HANDLE_NAMES) ; -1 : pas un bâton.
const HANDLE_NAMES := ["mauvais", "moyen", "bon", "excellent"]

static func handle_quality(value: Dictionary) -> int:
	if not value.get("objet", "") in ["branche", "rameau"]:
		return -1
	if int(value.get("pourrie", 0)) == 1 or int(value.get("tordue", 0)) == 1:
		return 0
	var length := float(value.get("longueur", 0.0))
	var thickness := float(value.get("epaisseur", 0.0))
	if length < 0.4 or length > 0.7 or thickness < 2.0 or thickness > 4.0:
		return 0 if length < 0.25 or thickness < 1.2 or thickness > 6.0 else 1
	var essence := int(value.get("essence", 0))
	if int(value.get("rejet", 0)) == 1 or essence == 1:
		return 3
	return 2 if essence == 0 else 1

# Détail d'un bâton (inventaire, au survol) : essence, longueur, épaisseur, droit ou tordu, sain ou pourri, mort, manche.
static func wood_details(value: Dictionary) -> String:
	if not value.get("objet", "") in ["tronc", "branche", "rameau"]:
		return ""
	var parts := []
	parts.append("%s cm de long" % str(roundi(float(value.get("longueur", 0.0)) * 100.0)))
	parts.append("%s cm d'épaisseur" % str(snappedf(float(value.get("epaisseur", 0.0)), 0.1)).replace(".", ","))
	parts.append("tordu" if int(value.get("tordue", 0)) == 1 else "droit")
	parts.append("pourri" if int(value.get("pourrie", 0)) == 1 else ("mort" if int(value.get("morte", 0)) == 1 else "sain"))
	var quality := handle_quality(value)
	if quality >= 0:
		parts.append("manche %s" % HANDLE_NAMES[quality])
	return ", ".join(parts)

# --- 0.0.7.29 (demande de l'utilisateur) : sous-possibilités (bouton « + » des cases de l'inventaire) ---
const AGE_NAMES := ["très jeune", "jeune", "adulte", "vieux", "très vieux"]
const SUPPLE_NAMES := ["cassant", "raide", "moyen", "souple", "très souple"]
const APPLE_SIZE_NAMES := ["petite", "moyenne", "grosse"]
# États du bois en Créatif : [nom, âge, mort, pourri, facteur de poids].
const WOOD_STATES := [["jeune", 1, 0, 0, 1.0], ["adulte", 3, 0, 0, 1.0], ["vieux", 5, 0, 0, 0.7], ["mort", 4, 1, 0, 0.55], ["pourri", 5, 1, 1, 0.35]]

static func is_wood(value: Dictionary) -> bool:
	return value.get("objet", "") in ["tronc", "branche", "rameau"]

# Créatif : toutes les variantes d'un objet (illimitées, à plat) ; vide s'il n'en a qu'une. Bois : 7 tailles × 5 états
# (jeune, adulte, vieux, mort, pourri) × 5 souplesses, 1 m de long ; cailloux : 7 tailles ; pommes : 3 tailles × 5 couleurs.
static func variants(value: Dictionary) -> Array:
	var id: String = value.get("objet", "")
	var result := []
	if is_wood(value):
		var essence := int(value.get("essence", 0))
		for size in range(WOOD_SIZES.size()):
			var thick: float = WOOD_SIZES[size]
			for state in WOOD_STATES:
				for supple in range(1, 6):
					var radius := thick / 200.0
					var variant := {"objet": id, "essence": essence, "taille": size + 1, "epaisseur": thick, "fin": snappedf(thick * 0.85, 0.1), "longueur": 1.0, "age": state[1], "souplesse": supple, "forme": 1,
						"poids": maxf(snappedf(PI * radius * radius * 1.0 * 750000.0 * state[4], 1.0), 1.0)}
					if state[2] == 1:
						variant.morte = 1
					if state[3] == 1:
						variant.pourrie = 1
					result.append(variant)
	elif ITEMS.get(id, {}).get("forme", "") == "caillou":
		for size in range(1, PEBBLE_WEIGHTS.size() + 1):
			result.append({"objet": id, "taille": size})
	elif id == "pomme":
		for size in range(1, APPLE_WEIGHTS.size() + 1):
			for color in range(APPLE_COLORS.size()):
				result.append({"objet": id, "taille": size, "couleur": color})
	return result

# Deux lignes courtes sous une variante (taille, puis état).
static func variant_label(value: Dictionary) -> Array:
	if is_wood(value):
		# Court (sous une case) : jeune, adulte, vieux, mort ou pourri.
		var age := int(value.get("age", 3))
		var state: String = "pourri" if int(value.get("pourrie", 0)) == 1 else ("mort" if int(value.get("morte", 0)) == 1 else ("jeune" if age <= 2 else ("adulte" if age == 3 else "vieux")))
		return ["%s cm" % _number(float(value.get("epaisseur", 0.0))), "%s · s%d" % [state, int(value.get("souplesse", 3))]]
	if value.get("objet", "") == "pomme":
		return [APPLE_SIZE_NAMES[clampi(int(value.get("taille", 2)), 1, 3) - 1], APPLE_COLOR_NAMES[clampi(int(value.get("couleur", 1)), 0, APPLE_COLOR_NAMES.size() - 1)]]
	if value.has("taille"):
		return ["Taille %d" % int(value.taille), format_weight(instance_weight(value.get("objet", ""), value))]
	return [item_name(value), ""]

static func _number(value: float) -> String:
	return str(snappedf(value, 0.1)).replace(".", ",")

# Détails d'un objet, un par ligne, toujours dans le même ordre (accepté par l'utilisateur) : nom, longueur, épaisseur,
# forme, état, souplesse, âge, note de manche ; puis taille, couleur, diamètre, coups ; le poids toujours en dernier.
static func detail_lines(value: Dictionary) -> Array:
	var id: String = value.get("objet", "")
	var lines := [item_name(value)]
	if value.has("longueur"):
		lines.append("Longueur : %d cm" % roundi(float(value.longueur) * 100.0))
	if value.has("epaisseur"):
		var thick := float(value.epaisseur)
		lines.append("Épaisseur : %s cm" % _number(thick) if not value.has("fin") else "Épaisseur : %s → %s cm" % [_number(thick), _number(float(value.fin))])
	if is_wood(value):
		lines.append("Forme : %s" % ("tordu" if int(value.get("tordue", 0)) == 1 else "droit"))
		lines.append("État : %s" % ("pourri" if int(value.get("pourrie", 0)) == 1 else ("mort" if int(value.get("morte", 0)) == 1 else "vert")))
		if value.has("souplesse"):
			lines.append("Souplesse : %s (%d sur 5)" % [SUPPLE_NAMES[clampi(int(value.souplesse), 1, 5) - 1], int(value.souplesse)])
		if value.has("age"):
			lines.append("Âge : %s (%d sur 5)" % [AGE_NAMES[clampi(int(value.age), 1, 5) - 1], int(value.age)])
		var quality := handle_quality(value)
		if quality >= 0:
			lines.append("Manche : %s" % HANDLE_NAMES[quality])
	elif value.has("taille"):
		if id == "pomme":
			lines.append("Taille : %s" % APPLE_SIZE_NAMES[clampi(int(value.taille), 1, 3) - 1])
		else:
			lines.append("Taille : %d sur %d" % [int(value.taille), PEBBLE_WEIGHTS.size()])
	if value.has("couleur") and id == "pomme":
		lines.append("Couleur : %s" % APPLE_COLOR_NAMES[clampi(int(value.couleur), 0, APPLE_COLOR_NAMES.size() - 1)])
	if value.has("diametre"):
		lines.append("Diamètre : %s cm" % _number(float(value.diametre) * 100.0))
	if int(value.get("coups", 0)) > 0:
		lines.append("Entamé : %d coup%s" % [int(value.coups), "s" if int(value.coups) > 1 else ""])
	var weight := instance_weight(id, value)
	if weight > 0.0:
		lines.append("Poids : %s" % format_weight(weight))
	return lines

static func item_name(value: Dictionary) -> String:
	var id: String = value.get("objet", "")
	if id == "rameau" and value.has("essence"):
		return LEAFY_NAMES[clampi(int(value.essence), 0, LEAFY_NAMES.size() - 1)]
	# 0.0.7.26 (#212) : branche morte ramassée au sol, rejet de noisetier.
	if id == "branche" and int(value.get("rejet", 0)) == 1:
		return "Rejet de noisetier"
	if id == "branche" and int(value.get("morte", 0)) == 1 and value.has("essence"):
		return "Branche morte de %s" % ESSENCE_NAMES[clampi(int(value.essence), 0, ESSENCE_NAMES.size() - 1)]
	# 0.0.7.18 : tronc et branche nommés selon leur arbre (« Tronc de pin », « Branche de noisetier »).
	if id in ["tronc", "branche"] and value.has("essence"):
		return "%s de %s" % [ITEMS[id].nom, ESSENCE_NAMES[clampi(int(value.essence), 0, ESSENCE_NAMES.size() - 1)]]
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
