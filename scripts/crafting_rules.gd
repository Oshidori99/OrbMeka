extends RefCounted
# 0.0.8.5 (#211, #213, demandes de l'utilisateur) : règles de la fabrication à la main (écran : crafting_ui.gd, O + F).
# On choisit l'action, puis ses objets (mains et poches en Survie ; le catalogue en Créatif), qui viennent dans les
# deux mains, puis on fait l'action :
# - Tresser : 3 fibres du même type, clic gauche maintenu BRAID_SECONDS : 1 ficelle de 33 cm, du type des fibres.
# - Tailler : un caillou percuteur (n'importe lequel) dans une main, un silex ou un calcaire de taille 3, 4 ou 5 dans
#   l'autre ; tête de hache ou de pioche ; un clic par coup (5, 6 ou 8 coups) ; la pierre change de forme à chaque coup.
#   Résultat : la tête (pierre et taille gardées : la taille 3 donne une moins bonne tête), et un éclat tranchant de la
#   même pierre (pour fendre, plus tard). Le percuteur reste. Pas de coup raté pour l'instant.
# 0.0.8.6 (#211, #145, demandes de l'utilisateur) :
# - Fendre : une branche (2 à 5 cm, 40 cm à 1 m, pas pourrie ; morte : moins bon outil) et un éclat, clic gauche maintenu
#   SPLIT_SECONDS : la branche est fendue au bout ; l'éclat reste.
# - Assembler : une branche fendue et une tête, un clic : hache ou pioche « à ficeler ».
# - Ficeler : l'outil à ficeler et 3 ficelles du même type (ou 1 liane, lien plus grossier) ; clic gauche maintenu, un
#   tour toutes les TURN_SECONDS, de TURNS_MIN à TURNS_MAX tours (relâcher pour finir) : hache ou pioche en pierre, qui
#   garde sa fabrication (pierre et taille de la tête, bois du manche, lien, tours).
const Inventory = preload("res://scripts/inventory.gd")

# 0.0.8.21 (#207, demandes de l'utilisateur) :
# - Tresser aussi 3 ficelles du même type : une cordelette (plus épaisse ; une ficelle seule est trop fine pour un sac).
# - Nouer : 4 cordelettes du même type pour les mailles (main gauche) et 1 cordelette ou 1 liane pour la bretelle (main
#   droite) ; clic gauche maintenu, une rangée de mailles toutes les ROW_SECONDS, de BAG_ROWS.x à BAG_ROWS.y (relâcher
#   pour finir) : un sac en filet (sa charge dépend des cordelettes, des rangées et de la bretelle : Inventory.bag_capacity).
# 0.0.8.40 (#255 à #258, demandes de l'utilisateur : les actions qu'on devrait déjà pouvoir faire) : Détresser,
# Défaire un outil, Refaire le lien, Écorcer.
const ACTIONS := ["tresser", "tailler", "fendre", "assembler", "ficeler", "nouer", "detresser", "defaire", "relier", "ecorcer", "torche", "archet", "feu"]
const ACTION_NAMES := {"tresser": "Tresser", "tailler": "Tailler", "fendre": "Fendre", "assembler": "Assembler", "ficeler": "Ficeler", "nouer": "Nouer", "detresser": "Détresser", "defaire": "Défaire un outil", "relier": "Refaire le lien", "ecorcer": "Écorcer", "torche": "Faire une torche", "archet": "Faire un archet à feu", "feu": "Monter un feu"}
const READY := ["tresser", "tailler", "fendre", "assembler", "ficeler", "nouer", "detresser", "defaire", "relier", "ecorcer", "torche", "archet", "feu"]
const BRAID_FIBERS := 3
const BRAID_SECONDS := 3.0
const CORD_LENGTH := 0.33
const CORDS := {"fibre_ortie": "ficelle_ortie", "fibre_lin": "ficelle_lin", "fibre_herbe": "ficelle_herbe",
	"ficelle_ortie": "cordelette_ortie", "ficelle_lin": "cordelette_lin", "ficelle_herbe": "cordelette_herbe"}
# Cordelettes : identifiant → fil (Inventory.BAG_CORD_FACTORS : 0 ortie, 1 lin, 2 herbe).
const BAG_CORDS := {"cordelette_ortie": 0, "cordelette_lin": 1, "cordelette_herbe": 2}
const NET_CORDS := 4
const ROW_SECONDS := 0.8
const HAMMERS := ["caillou", "caillou_calcaire", "caillou_silex"]
# Pierre à tailler : identifiant → pierre de la tête (0 calcaire, 1 silex).
const KNAP_STONES := {"caillou_calcaire": 0, "caillou_silex": 1}
const KNAP_SIZES := [3, 4, 5]
# 0.0.8.8 (demande de l'utilisateur) : 2,5 fois plus de coups (avant 5, 6, 8).
const KNAP_HITS := {3: 13, 4: 15, 5: 20}
# 0.0.8.8 : tailler un éclat tranchant : FLAKE_HITS coups, une pierre de taille 2 à 5, qui perd une taille (la 2 est
# entièrement utilisée).
const FLAKE_HITS := 8
const FLAKE_SIZES := [2, 3, 4, 5]
const HEADS := {"hache": "tete_hache", "pioche": "tete_pioche"}
const HEAD_NAMES := {"hache": "Tête de hache", "pioche": "Tête de pioche", "eclat": "Éclat tranchant"}
const FLAKES := {0: "eclat_calcaire", 1: "eclat_silex"}
const FLAKE_WEIGHT := 40.0
# Poids de la tête : une part de la pierre de départ (le reste part en éclats).
const HEAD_SHARE := 0.6

# 0.0.8.21 (demande de l'utilisateur) : avec un éclat tranchant sur soi (mains, poches, sac), on tresse deux fois plus vite
# (il coupe et égalise les brins) : 1,5 s au lieu de 3 s, pour les ficelles comme pour les cordelettes.
# 0.0.8.24 (demande de l'utilisateur) : seulement s'il est choisi (proposé dans le menu, crafting_ui « eclat_aide »).
const BRAID_FLAKE_FACTOR := 0.5

static func has_flake(inventory: Inventory) -> bool:
	for place in places(inventory):
		var there := inventory.item(place[0], place[1])
		if not there.is_empty() and Inventory.ITEMS.get(there.objet, {}).get("forme", "") == "eclat" and there.objet != "charbon":
			return true
	return false

static func braid_seconds(with_flake: bool) -> float:
	return BRAID_SECONDS * (BRAID_FLAKE_FACTOR if with_flake else 1.0)

static func is_ready(action: String) -> bool:
	return action in READY

# Toutes les cases où l'on prend des objets : en Survie, les mains, les poches et les sacs ; en Créatif, la barre et la grille.
static func places(inventory: Inventory) -> Array:
	if inventory.mode == Inventory.SURVIVAL:
		return inventory.carried_places()
	var list: Array = inventory.bar_slots().map(func(index): return ["bar", index])
	for index in range(Inventory.GRID_SIZE):
		list.append(["grid", index])
	return list

# Objets possibles, un par unité ({"label", "value" (à plat), "area", "index", "unit"}) ; Créatif : en plus, le catalogue
# (illimité, « area » vide). role : « fibres », « percuteur » ou « pierre ».
static func choices(inventory: Inventory, role: String) -> Array:
	var result := []
	var fibre_totals := {}
	for place in places(inventory):
		var there := inventory.item(place[0], place[1])
		if there.is_empty() or Inventory.unlimited(there):
			continue
		var units := Inventory.units(there)
		match role:
			"fibres":
				if CORDS.has(there.objet):
					fibre_totals[there.objet] = int(fibre_totals.get(there.objet, 0)) + units.size()
			"percuteur", "pierre", "pierre_eclat":
				for unit in range(units.size()):
					var value: Dictionary = units[unit]
					if _fits(role, value):
						result.append({"label": _label(value), "value": value, "area": place[0], "index": place[1], "unit": unit})
	if role == "fibres":
		for id in CORDS:
			if int(fibre_totals.get(id, 0)) >= BRAID_FIBERS:
				result.append({"label": "%s × %d" % [Inventory.ITEMS[id].nom, int(fibre_totals[id])], "value": {"objet": id}, "area": "", "index": -1, "unit": -1, "fibres": id})
	if inventory.mode == Inventory.CREATIVE:
		result.append_array(_catalog(role))
	return result

static func _fits(role: String, value: Dictionary) -> bool:
	if role == "percuteur":
		return value.get("objet", "") in HAMMERS
	if role == "pierre_eclat":
		return KNAP_STONES.has(value.get("objet", "")) and int(value.get("taille", 0)) in FLAKE_SIZES
	return KNAP_STONES.has(value.get("objet", "")) and int(value.get("taille", 0)) in KNAP_SIZES

static func _label(value: Dictionary) -> String:
	if value.has("taille"):
		return "%s (taille %d)" % [Inventory.item_name(value), int(value.taille)]
	return Inventory.item_name(value)

# Créatif : objets illimités du catalogue (fibres de chaque type ; percuteur ; silex et calcaire de taille 3, 4 et 5).
static func _catalog(role: String) -> Array:
	var result := []
	match role:
		"fibres":
			for id in CORDS:
				result.append({"label": "%s (Créatif)" % Inventory.ITEMS[id].nom, "value": {"objet": id}, "area": "", "index": -1, "unit": -1, "fibres": id, "creative": true})
		"percuteur":
			result.append({"label": "Caillou (taille 4, Créatif)", "value": {"objet": "caillou", "taille": 4}, "area": "", "index": -1, "unit": -1, "creative": true})
		"pierre", "pierre_eclat":
			for id in KNAP_STONES:
				for size in (FLAKE_SIZES if role == "pierre_eclat" else KNAP_SIZES):
					var value := {"objet": id, "taille": size}
					result.append({"label": "%s (taille %d, Créatif)" % [Inventory.ITEMS[id].nom, size], "value": value, "area": "", "index": -1, "unit": -1, "creative": true})
	return result

static func hits_for(stone: Dictionary, head: String = "hache") -> int:
	if head == "eclat":
		return FLAKE_HITS
	return int(KNAP_HITS.get(int(stone.get("taille", 4)), 15))

# 0.0.8.8 : un éclat tranchant de la pierre, et la pierre une taille plus petite ({} : taille 2, entièrement utilisée).
static func flake_results(stone: Dictionary) -> Array:
	var kind: int = KNAP_STONES.get(stone.get("objet", ""), 1)
	var flake := {"objet": FLAKES[kind], "pile": [{"poids": FLAKE_WEIGHT}]}
	var size := int(stone.get("taille", 3))
	if size <= FLAKE_SIZES[0]:
		return [flake, {}]
	var smaller := stone.duplicate(true)
	smaller.taille = size - 1
	smaller.erase("poids")
	smaller.erase("objet")
	return [flake, {"objet": stone.objet, "pile": [smaller]}]

# 0.0.8.8 (demande de l'utilisateur) : ce que fait l'action en cours (pour « Vous avez … »).
static func result_id(action: String, picks: Dictionary, head: String) -> String:
	match action:
		"tresser":
			return CORDS.get(picks.get("fibres", {}).get("fibres", ""), "")
		"tailler":
			if head == "eclat":
				return FLAKES.get(KNAP_STONES.get(picks.get("pierre", {}).get("value", {}).get("objet", ""), 1), "")
			return HEADS.get(head, "")
		"fendre":
			return "branche_fendue"
		"assembler":
			return UNBOUND.get(picks.get("tete", {}).get("value", {}).get("objet", ""), "")
		"ficeler":
			return BOUND.get(picks.get("a_ficeler", {}).get("value", {}).get("objet", ""), "")
		"detresser":
			return UNTWIST.get(picks.get("tresse", {}).get("value", {}).get("objet", ""), "")
		"relier":
			return picks.get("outil_use", {}).get("value", {}).get("objet", "")
		"nouer":
			return Inventory.BAG_ID
	return ""

# Combien d'objets « id » dans les cases (« branche_fendue » : les branches fendues).
static func owned(inventory: Inventory, id: String) -> int:
	var total := 0
	# 0.0.8.21 : les sacs portés comptent aussi.
	if id == Inventory.BAG_ID:
		total += [0, 1].filter(func(which): return inventory.bag_worn(which)).size()
	for place in places(inventory):
		var there := inventory.item(place[0], place[1])
		if there.is_empty():
			continue
		if id == "branche_fendue":
			if there.objet == "branche":
				total += Inventory.units(there).filter(func(v): return int(v.get("fendue", 0)) == 1).size()
		elif there.objet == id:
			total += Inventory.count(there)
	return total

# Prend 3 fibres du type choisi dans les cases (de la dernière case vers la première) ; Créatif : rien n'est pris.
# Rend vrai si elles y étaient.
static func take_fibres(inventory: Inventory, choice: Dictionary) -> bool:
	if choice.get("creative", false):
		return true
	var id: String = choice.get("fibres", "")
	var found := 0
	for place in places(inventory):
		var there := inventory.item(place[0], place[1])
		if there.get("objet", "") == id:
			found += Inventory.count(there)
	if found < BRAID_FIBERS:
		return false
	var left := BRAID_FIBERS
	var list := places(inventory)
	list.reverse()
	for place in list:
		while left > 0 and inventory.item(place[0], place[1]).get("objet", "") == id:
			inventory.take_unit(place[0], place[1])
			left -= 1
	return left == 0

# La pierre choisie est-elle toujours là (rien n'a bougé entre-temps) ?
static func still_there(inventory: Inventory, choice: Dictionary) -> bool:
	if choice.get("creative", false):
		return true
	var there := inventory.item(choice.area, choice.index)
	var units := Inventory.units(there)
	return int(choice.unit) < units.size() and units[int(choice.unit)] == choice.value

static func cord_for(fibre_id: String) -> Dictionary:
	return {"objet": CORDS[fibre_id], "pile": [{"longueur": CORD_LENGTH}]}

# Résultat de la taille : [tête, éclat], chacun prêt à ranger (une pile d'un objet).
static func knap_results(stone: Dictionary, head: String) -> Array:
	var kind: int = KNAP_STONES.get(stone.get("objet", ""), 1)
	var size := int(stone.get("taille", 4))
	var weight := Inventory.instance_weight(stone.objet, stone) * HEAD_SHARE
	var made := {"objet": HEADS[head], "pile": [{"pierre": kind, "taille": size, "poids": snappedf(weight, 1.0)}]}
	var flake := {"objet": FLAKES[kind], "pile": [{"poids": FLAKE_WEIGHT}]}
	return [made, flake]

# --- 0.0.8.6 : Fendre, Assembler, Ficeler ---
const SPLIT_SECONDS := 4.0
const TURN_SECONDS := 0.6
const TURNS_MIN := 4
const TURNS_MAX := 8
const CORDS_PER_TOOL := 3
const HANDLE_THICKNESS := Vector2(2.0, 5.0)
const HANDLE_LENGTH := Vector2(0.4, 1.0)
# Lien d'un outil : identifiant → code (Inventory.BIND_NAMES).
const BINDS := {"ficelle_ortie": 0, "ficelle_lin": 1, "ficelle_herbe": 2, "liane": 3}
const UNBOUND := {"tete_hache": "hache_a_ficeler", "tete_pioche": "pioche_a_ficeler"}
const BOUND := {"hache_a_ficeler": "hache_pierre", "pioche_a_ficeler": "pioche_pierre"}
const WOOD_KEYS := ["essence", "age", "souplesse", "epaisseur", "fin", "longueur", "morte"]
const CREATIVE_HANDLE := {"objet": "branche", "essence": 1, "age": 3, "souplesse": 3, "epaisseur": 3.5, "longueur": 0.6, "poids": 450.0}

# Rôle d'un objet pour les nouvelles actions.
static func fits_more(role: String, value: Dictionary) -> bool:
	var id: String = value.get("objet", "")
	match role:
		"manche":
			# 0.0.8.26 (signalé : les bâtons de noisetier ramassés sont des bûches, dès 4 cm) : une bûche fine aussi.
			return id in ["branche", "tronc"] and int(value.get("fendue", 0)) == 0 and (good_handle(value) or good_shuttle(value))
		# 0.0.8.25 : navette, facultative pour Ficeler.
		"navette":
			return id == "navette"
		"eclat":
			return Inventory.ITEMS.get(id, {}).get("forme", "") == "eclat" and id != "charbon"
		"fendu":
			return id == "branche" and int(value.get("fendue", 0)) == 1
		"tete":
			return UNBOUND.has(id)
		# 0.0.8.40 : une ficelle ou une cordelette à détresser ; un outil à défaire ; un outil ficelé (refaire le lien) ;
		# du bois à écorcer (pas déjà écorcé, pas fendu).
		"tresse":
			return UNTWIST.has(id)
		"outil_fait":
			return BOUND.has(id) or BOUND.values().has(id)
		"outil_use":
			return BOUND.values().has(id)
		# 0.0.8.44 : torche, archet, feu de camp ; écorce de pin (torche forte).
		"baton_torche":
			return _wood_size(value, TORCH_THICKNESS, TORCH_LENGTH)
		"arc":
			return _wood_size(value, BOW_THICKNESS, BOW_LENGTH)
		"corde_arc":
			return id.begins_with("cordelette_")
		"bois_feu":
			return id in ["branche", "tronc"] and int(value.get("brulee", 0)) == 0
		"resine":
			return id == "ecorce_pin"
		"bois":
			return id in ["branche", "tronc"] and int(value.get("ecorce", 0)) == 0 and int(value.get("fendue", 0)) == 0
		"a_ficeler":
			return BOUND.has(id)
	return false

# --- 0.0.8.40 (#255 à #258) : les actions qui manquaient ---
# Détresser : une ficelle redonne ses 3 fibres, une cordelette ses 3 ficelles (le contraire de Tresser).
const UNTWIST := {"ficelle_ortie": "fibre_ortie", "ficelle_lin": "fibre_lin", "ficelle_herbe": "fibre_herbe", "cordelette_ortie": "ficelle_ortie", "cordelette_lin": "ficelle_lin", "cordelette_herbe": "ficelle_herbe"}
const UNTWIST_SECONDS := 2.0
const BARK_SECONDS := 3.0
const RELINK_SECONDS := 4.0
# Écorcé : plus léger (l'écorce est partie).
const BARK_SHARE := 0.92
# Refaire le lien : l'outil retrouve cette part de ses coups (la tête et le manche s'usent quand même).
const RELINK_SHARE := 0.6
const BIND_IDS := ["ficelle_ortie", "ficelle_lin", "ficelle_herbe", "liane"]

static func untwist_result(value: Dictionary) -> Dictionary:
	var id: String = UNTWIST.get(value.get("objet", ""), "")
	if id.is_empty():
		return {}
	var pile := []
	for index in range(BRAID_FIBERS):
		pile.append({"longueur": CORD_LENGTH} if id.begins_with("ficelle_") else {})
	return {"objet": id, "pile": pile}

# Poids du manche d'un outil (comme Inventory.wood_piece : son volume).
static func _stick_weight(tool: Dictionary) -> float:
	var radius := float(tool.get("epaisseur", 3.5)) / 200.0
	return PI * radius * radius * float(tool.get("longueur", 0.6)) * 750000.0 * (0.7 if int(tool.get("age", 3)) == 5 else 1.0)

static func _tie_weight(tool: Dictionary) -> float:
	if not tool.has("lien"):
		return 0.0
	var bind: String = BIND_IDS[clampi(int(tool.lien), 0, BIND_IDS.size() - 1)]
	return Inventory.instance_weight(bind, {}) * (1 if bind == "liane" else CORDS_PER_TOOL)

# Défaire un outil : [tête, branche fendue, reste du lien (une ficelle usée ; rien pour une liane)].
static func undo_results(tool: Dictionary) -> Array:
	var unbound: String = tool.get("objet", "")
	for id in BOUND:
		if BOUND[id] == unbound:
			unbound = id
	var head_id := ""
	for id in UNBOUND:
		if UNBOUND[id] == unbound:
			head_id = id
	if head_id.is_empty():
		return []
	var stick := {"fendue": 1}
	for key in WOOD_KEYS:
		if tool.has(key):
			stick[key] = tool[key]
	var stick_weight := _stick_weight(tool)
	stick.poids = snappedf(stick_weight, 1.0)
	var head_weight := maxf(float(tool.get("poids", 0.0)) - stick_weight - _tie_weight(tool), 60.0)
	var result := [{"objet": head_id, "pile": [{"pierre": int(tool.get("pierre", 1)), "taille": int(tool.get("taille", 4)), "poids": snappedf(head_weight, 1.0)}]}, {"objet": "branche", "pile": [stick]}]
	if tool.has("lien") and int(tool.lien) < 3:
		result.append({"objet": BIND_IDS[int(tool.lien)], "pile": [{"longueur": CORD_LENGTH}]})
	return result

# Refaire le lien : le nouveau lien, ses tours, et l'outil retrouve RELINK_SHARE de ses coups.
static func relink_result(tool: Dictionary, bind: String) -> Dictionary:
	var made := tool.duplicate(true)
	made.poids = snappedf(float(tool.get("poids", 0.0)) - _tie_weight(tool), 1.0)
	made.lien = int(BINDS[bind])
	made.tours = TURNS_MAX
	made.poids = snappedf(float(made.poids) + _tie_weight(made), 1.0)
	var full := Inventory.tool_durability(made)
	made.usure = mini(full, Inventory.tool_left(tool) + roundi(full * RELINK_SHARE))
	return _pile(made)

# Écorcer : le même bois, écorcé, plus léger.
static func bark_result(wood: Dictionary) -> Dictionary:
	var made := wood.duplicate(true)
	made.ecorce = 1
	made.poids = snappedf(float(wood.get("poids", Inventory.instance_weight(wood.get("objet", "branche"), wood))) * BARK_SHARE, 1.0)
	return _pile(made)

static func good_handle(value: Dictionary) -> bool:
	var thick := float(value.get("epaisseur", 0.0))
	var length := float(value.get("longueur", 0.0))
	return int(value.get("pourrie", 0)) == 0 and thick >= HANDLE_THICKNESS.x - 0.001 and thick <= HANDLE_THICKNESS.y + 0.001 and length >= HANDLE_LENGTH.x - 0.001 and length <= HANDLE_LENGTH.y + 0.001

# 0.0.8.25 : branche pour une navette (fendue au bout, la ficelle enroulée dessus) : fine et courte, pas pourrie.
const SHUTTLE_THICKNESS := Vector2(1.0, 2.5)
const SHUTTLE_LENGTH := Vector2(0.15, 0.4)
# Ficeler avec une navette : deux fois plus vite.
const SHUTTLE_FACTOR := 0.5

static func good_shuttle(value: Dictionary) -> bool:
	var thick := float(value.get("epaisseur", 0.0))
	var length := float(value.get("longueur", 0.0))
	return int(value.get("pourrie", 0)) == 0 and thick >= SHUTTLE_THICKNESS.x - 0.001 and thick <= SHUTTLE_THICKNESS.y + 0.001 and length >= SHUTTLE_LENGTH.x - 0.001 and length < SHUTTLE_LENGTH.y - 0.001

static func turn_seconds(with_shuttle: bool) -> float:
	return TURN_SECONDS * (SHUTTLE_FACTOR if with_shuttle else 1.0)

# Liens possibles : ficelles d'un même type (3 au moins, toutes cases), ou chaque liane.
static func bind_choices(inventory: Inventory) -> Array:
	var result := []
	var totals := {}
	for place in places(inventory):
		var there := inventory.item(place[0], place[1])
		if there.is_empty() or Inventory.unlimited(there):
			continue
		var id: String = there.objet
		if id.begins_with("ficelle_"):
			totals[id] = int(totals.get(id, 0)) + Inventory.count(there)
		elif id == "liane":
			var units := Inventory.units(there)
			for unit in range(units.size()):
				result.append({"label": "Liane (lien grossier)", "value": units[unit], "area": place[0], "index": place[1], "unit": unit, "bind": "liane"})
	for id in ["ficelle_ortie", "ficelle_lin", "ficelle_herbe"]:
		if int(totals.get(id, 0)) >= CORDS_PER_TOOL:
			result.append({"label": "%s × %d (3 pour un outil)" % [Inventory.ITEMS[id].nom, int(totals[id])], "value": {"objet": id}, "area": "", "index": -1, "unit": -1, "bind": id})
	if inventory.mode == Inventory.CREATIVE:
		for id in BINDS:
			result.append({"label": "%s (Créatif)" % Inventory.ITEMS[id].nom, "value": {"objet": id}, "area": "", "index": -1, "unit": -1, "bind": id, "creative": true})
	return result

# 0.0.8.26 (demande de l'utilisateur : l'outil à ficeler dans les deux mains, la navette n'était pas proposée) : aides
# facultatives (éclat, navette) : n'importe où dans la barre (mains, poches, cases du sac), même les mains prises ; jamais
# la grille de l'inventaire ni le deuxième sac ; Créatif : toute la barre (et le modèle du catalogue).
static func aid_choices(inventory: Inventory, kind: String) -> Array:
	var result := []
	for index in range(Inventory.BAR_SIZE):
		if not inventory.usable("bar", index):
			continue
		var there := inventory.item("bar", index)
		if there.is_empty() or Inventory.unlimited(there):
			continue
		var units := Inventory.units(there)
		for unit in range(units.size()):
			if fits_more(kind, units[unit]):
				result.append({"label": _label(units[unit]), "value": units[unit], "area": "bar", "index": index, "unit": unit})
	if inventory.mode == Inventory.CREATIVE:
		result.append_array(more_choices(inventory, kind).filter(func(choice): return choice.get("creative", false)))
	return result

# Objets possibles pour un rôle des nouvelles actions (comme choices).
static func more_choices(inventory: Inventory, role: String) -> Array:
	if role == "lien":
		return bind_choices(inventory)
	if role in ["filet", "bretelle"]:
		return net_choices(inventory, role)
	var result := []
	for place in places(inventory):
		var there := inventory.item(place[0], place[1])
		if there.is_empty() or Inventory.unlimited(there):
			continue
		var units := Inventory.units(there)
		for unit in range(units.size()):
			var value: Dictionary = units[unit]
			if fits_more(role, value):
				result.append({"label": _label(value), "value": value, "area": place[0], "index": place[1], "unit": unit})
	if inventory.mode == Inventory.CREATIVE:
		var model := {}
		match role:
			"manche":
				model = CREATIVE_HANDLE.duplicate()
			"fendu":
				model = CREATIVE_HANDLE.duplicate()
				model.fendue = 1
			"eclat":
				model = {"objet": "eclat_silex", "poids": FLAKE_WEIGHT}
			"navette":
				model = {"objet": "navette", "essence": 1, "age": 3, "souplesse": 3, "epaisseur": 1.8, "longueur": 0.3, "poids": 60.0}
			"tete":
				for id in UNBOUND:
					result.append({"label": "%s (Créatif)" % Inventory.ITEMS[id].nom, "value": {"objet": id, "pierre": 1, "taille": 5, "poids": 420.0}, "area": "", "index": -1, "unit": -1, "creative": true})
			"tresse":
				for id in UNTWIST:
					result.append({"label": "%s (Créatif)" % Inventory.ITEMS[id].nom, "value": {"objet": id, "longueur": CORD_LENGTH}, "area": "", "index": -1, "unit": -1, "creative": true})
			"baton_torche", "arc", "bois_feu":
				model = CREATIVE_HANDLE.duplicate()
				if role == "arc":
					model.epaisseur = 2.0
			"corde_arc":
				model = {"objet": "cordelette_lin", "longueur": CORD_LENGTH}
			"resine":
				model = {"objet": "ecorce_pin"}
			"bois":
				model = CREATIVE_HANDLE.duplicate()
			"outil_fait", "outil_use":
				for id in BOUND:
					var made := CREATIVE_HANDLE.duplicate()
					made.objet = BOUND[id]
					made.merge({"pierre": 1, "taille": 5, "lien": 1, "tours": TURNS_MAX, "poids": 870.0}, true)
					made.usure = Inventory.tool_durability(made) / 3
					result.append({"label": "%s usée (Créatif)" % Inventory.ITEMS[BOUND[id]].nom, "value": made, "area": "", "index": -1, "unit": -1, "creative": true})
			"a_ficeler":
				for id in BOUND:
					var tool := CREATIVE_HANDLE.duplicate()
					tool.objet = id
					tool.merge({"pierre": 1, "taille": 5, "poids": 870.0}, true)
					result.append({"label": "%s (Créatif)" % Inventory.ITEMS[id].nom, "value": tool, "area": "", "index": -1, "unit": -1, "creative": true})
		if not model.is_empty():
			result.append({"label": "%s (Créatif)" % Inventory.item_name(model), "value": model, "area": "", "index": -1, "unit": -1, "creative": true})
	return result

# Prend « amount » objets « id » dans les cases (de la dernière vers la première) ; Créatif : rien n'est pris.
static func take_count(inventory: Inventory, id: String, amount: int, creative := false) -> bool:
	if creative:
		return true
	var found := 0
	for place in places(inventory):
		var there := inventory.item(place[0], place[1])
		if there.get("objet", "") == id:
			found += Inventory.count(there)
	if found < amount:
		return false
	var left := amount
	var list := places(inventory)
	list.reverse()
	for place in list:
		while left > 0 and inventory.item(place[0], place[1]).get("objet", "") == id:
			inventory.take_unit(place[0], place[1])
			left -= 1
	return left == 0

# Prend l'objet choisi (sauf Créatif) ; rend vrai s'il était encore là.
static func take_choice(inventory: Inventory, choice: Dictionary) -> bool:
	if choice.get("creative", false):
		return true
	if not still_there(inventory, choice):
		return false
	inventory.take_unit(choice.area, choice.index, choice.unit)
	return true

static func _pile(value: Dictionary) -> Dictionary:
	var instance := value.duplicate(true)
	instance.erase("objet")
	return {"objet": value.objet, "pile": [instance]}

static func split_result(stick: Dictionary) -> Dictionary:
	var made := stick.duplicate(true)
	# 0.0.8.25 : une branche fine et courte fendue devient une navette.
	if good_shuttle(stick) and not good_handle(stick):
		made.objet = "navette"
		return _pile(made)
	# Une bûche fine fendue devient une branche fendue (le manche d'un outil).
	made.objet = "branche"
	made.fendue = 1
	return _pile(made)

static func assemble_result(stick: Dictionary, head: Dictionary) -> Dictionary:
	var made := {"objet": UNBOUND[head.objet], "pierre": int(head.get("pierre", 1)), "taille": int(head.get("taille", 4))}
	for key in WOOD_KEYS:
		if stick.has(key):
			made[key] = stick[key]
	made.poids = snappedf(Inventory.instance_weight(head.objet, head) + Inventory.instance_weight("branche", stick), 1.0)
	return _pile(made)

static func bind_result(tool: Dictionary, bind: String, turns: int) -> Dictionary:
	var made := tool.duplicate(true)
	made.objet = BOUND[tool.objet]
	made.lien = int(BINDS[bind])
	made.tours = clampi(turns, TURNS_MIN, TURNS_MAX)
	var tie := Inventory.instance_weight(bind, {}) * (1 if bind == "liane" else CORDS_PER_TOOL)
	made.poids = snappedf(float(tool.get("poids", 0.0)) + tie, 1.0)
	# 0.0.8.10 : un outil neuf a tous ses coups.
	made.usure = Inventory.tool_durability(made)
	return _pile(made)

# --- 0.0.8.21 (#207) : Nouer un sac en filet ---
# Mailles (« filet ») : 4 cordelettes d'un même type (toutes cases) ; bretelle : 1 cordelette (n'importe quel type) ou
# 1 liane. Une même sorte pour les deux : il en faut 5.
static func net_choices(inventory: Inventory, role: String) -> Array:
	var result := []
	var totals := {}
	for place in places(inventory):
		var there := inventory.item(place[0], place[1])
		if there.is_empty() or Inventory.unlimited(there):
			continue
		if BAG_CORDS.has(there.objet):
			totals[there.objet] = int(totals.get(there.objet, 0)) + Inventory.count(there)
		elif there.objet == "liane" and role == "bretelle":
			var units := Inventory.units(there)
			for unit in range(units.size()):
				result.append({"label": "Liane (bretelle plus grossière)", "value": units[unit], "area": place[0], "index": place[1], "unit": unit, "bretelle": "liane"})
	for id in BAG_CORDS:
		var have := int(totals.get(id, 0))
		if role == "filet" and have >= NET_CORDS:
			result.append({"label": "%s × %d (4 pour les mailles)" % [Inventory.ITEMS[id].nom, have], "value": {"objet": id}, "area": "", "index": -1, "unit": -1, "cordes": id})
		elif role == "bretelle" and have >= 1:
			result.append({"label": "%s × %d (1 pour la bretelle)" % [Inventory.ITEMS[id].nom, have], "value": {"objet": id}, "area": "", "index": -1, "unit": -1, "bretelle": id})
	if inventory.mode == Inventory.CREATIVE:
		for id in BAG_CORDS:
			var entry := {"label": "%s (Créatif)" % Inventory.ITEMS[id].nom, "value": {"objet": id}, "area": "", "index": -1, "unit": -1, "creative": true}
			entry["cordes" if role == "filet" else "bretelle"] = id
			result.append(entry)
		if role == "bretelle":
			result.append({"label": "Liane (Créatif)", "value": {"objet": "liane"}, "area": "", "index": -1, "unit": -1, "bretelle": "liane", "creative": true})
	return result

# Assez de cordelettes pour les deux choix (5 d'un même type si les deux sont pareils) ?
static func net_ready(inventory: Inventory, net: Dictionary, strap: Dictionary) -> bool:
	if net.get("creative", false):
		return true
	var id: String = net.get("cordes", "")
	var need := NET_CORDS + (1 if strap.get("bretelle", "") == id and not strap.get("creative", false) else 0)
	var have := 0
	for place in places(inventory):
		if inventory.item(place[0], place[1]).get("objet", "") == id:
			have += Inventory.count(inventory.item(place[0], place[1]))
	return have >= need

static func bag_result(net_id: String, strap_id: String, rows: int) -> Dictionary:
	var vine := strap_id == "liane"
	var weight := Inventory.instance_weight(net_id, {}) * NET_CORDS + Inventory.instance_weight(strap_id, {})
	return {"objet": Inventory.BAG_ID, "pile": [{"lien": int(BAG_CORDS.get(net_id, 0)), "rangees": clampi(rows, Inventory.BAG_ROWS.x, Inventory.BAG_ROWS.y), "bretelle": 1 if vine else 0, "poids": snappedf(weight, 1.0)}]}

# --- 0.0.8.44 (#214, #209) : torche, archet à feu, feu de camp ---
# Torche : un bâton (2 à 5 cm, 30 cm à 1,2 m) et 3 fibres du même type (la mèche) ; avec de l'écorce de pin (facultative,
# la résine brûle mieux) : une torche forte. Archet à feu : une branche souple (1 à 3 cm, 40 cm à 1,2 m) et une
# cordelette. Feu de camp : 4 cailloux, un bâton ou une bûche, et de l'amadou (3 fibres ou un morceau d'écorce).
const TORCH_THICKNESS := Vector2(2.0, 5.0)
const TORCH_LENGTH := Vector2(0.3, 1.2)
const BOW_THICKNESS := Vector2(1.0, 3.0)
const BOW_LENGTH := Vector2(0.4, 1.2)
const FIRE_STONES := 4
const PEBBLE_IDS := ["caillou", "caillou_calcaire", "caillou_silex"]
const FIRE_START := 120.0

static func _wood_size(value: Dictionary, thick: Vector2, long: Vector2) -> bool:
	var t := float(value.get("epaisseur", 0.0))
	var l := float(value.get("longueur", 0.0))
	return value.get("objet", "") in ["branche", "tronc"] and int(value.get("fendue", 0)) == 0 and int(value.get("pourrie", 0)) == 0 and int(value.get("brulee", 0)) == 0 and t >= thick.x - 0.001 and t <= thick.y + 0.001 and l >= long.x - 0.001 and l <= long.y + 0.001

# Mèche d'une torche : 3 fibres du même type (pas des ficelles).
static func wick_choices(inventory: Inventory) -> Array:
	return choices(inventory, "fibres").filter(func(choice): return str(choice.get("fibres", "")).begins_with("fibre_"))

# Feu de camp : les cailloux (4, de n'importe quelle sorte) ; l'amadou (3 fibres, ou un morceau d'écorce).
static func fire_choices(inventory: Inventory, role: String) -> Array:
	var result := []
	if role == "pierres":
		var total := 0
		for place in places(inventory):
			var there := inventory.item(place[0], place[1])
			if not there.is_empty() and not Inventory.unlimited(there) and there.objet in PEBBLE_IDS:
				total += Inventory.count(there)
		if total >= FIRE_STONES:
			result.append({"label": "Cailloux × %d (4 pour un feu)" % total, "value": {"objet": "caillou"}, "area": "", "index": -1, "unit": -1, "stones": true})
		if inventory.mode == Inventory.CREATIVE:
			result.append({"label": "Cailloux (Créatif)", "value": {"objet": "caillou"}, "area": "", "index": -1, "unit": -1, "stones": true, "creative": true})
		return result
	result = wick_choices(inventory)
	for place in places(inventory):
		var there := inventory.item(place[0], place[1])
		if there.is_empty() or Inventory.unlimited(there) or not there.objet in ["ecorce", "ecorce_pin"]:
			continue
		var units := Inventory.units(there)
		for unit in range(units.size()):
			result.append({"label": _label(units[unit]), "value": units[unit], "area": place[0], "index": place[1], "unit": unit})
	return result

# Prend 4 cailloux (n'importe lesquels) ; Créatif : rien n'est pris.
static func take_stones(inventory: Inventory, creative: bool) -> bool:
	if creative:
		return true
	var list := places(inventory)
	var total := 0
	for place in list:
		var there := inventory.item(place[0], place[1])
		if not there.is_empty() and there.get("objet", "") in PEBBLE_IDS:
			total += Inventory.count(there)
	if total < FIRE_STONES:
		return false
	var left := FIRE_STONES
	list.reverse()
	for place in list:
		while left > 0 and inventory.item(place[0], place[1]).get("objet", "") in PEBBLE_IDS:
			inventory.take_unit(place[0], place[1])
			left -= 1
	return left == 0

static func torch_result(stick: Dictionary, strong: bool) -> Dictionary:
	var made := {"objet": "torche_forte" if strong else "torche", "allume": 0}
	for key in ["essence", "epaisseur", "fin", "longueur"]:
		if stick.has(key):
			made[key] = stick[key]
	made.poids = snappedf(float(stick.get("poids", 200.0)) + 3.0 * Inventory.instance_weight("fibre_lin", {}) + (Inventory.instance_weight("ecorce_pin", {}) if strong else 0.0), 1.0)
	return _pile(made)

static func bow_result(stick: Dictionary, cord: Dictionary) -> Dictionary:
	var made := {"objet": "archet"}
	for key in ["essence", "epaisseur", "fin", "longueur", "souplesse", "age"]:
		if stick.has(key):
			made[key] = stick[key]
	made.poids = snappedf(float(stick.get("poids", 200.0)) + Inventory.instance_weight(cord.get("objet", "cordelette_lin"), cord) + 60.0, 1.0)
	return _pile(made)

static func fire_result() -> Dictionary:
	return {"objet": "feu_camp", "pile": [{"brule": FIRE_START, "allume": 0, "poids": 3000.0}]}

# Écorcer : l'écorce qui se détache (de pin : résineuse, pour la torche forte).
static func bark_piece(wood: Dictionary) -> Dictionary:
	return {"objet": "ecorce_pin" if int(wood.get("essence", -1)) == 2 else "ecorce", "pile": [{}]}
