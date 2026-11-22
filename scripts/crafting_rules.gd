extends RefCounted
# 0.0.8.5 (#211, #213, demandes de l'utilisateur) : règles de la fabrication à la main (écran : crafting_ui.gd, O + F).
# On choisit l'action, puis ses objets (mains et poches en Survie ; le catalogue en Créatif), qui viennent dans les
# deux mains, puis on fait l'action :
# - Tresser : 3 fibres du même type, clic gauche maintenu BRAID_SECONDS : 1 ficelle de 33 cm, du type des fibres.
# - Tailler : un caillou percuteur (n'importe lequel) dans une main, un silex ou un calcaire de taille 3, 4 ou 5 dans
#   l'autre ; tête de hache ou de pioche ; un clic par coup (5, 6 ou 8 coups) ; la pierre change de forme à chaque coup.
#   Résultat : la tête (pierre et taille gardées : la taille 3 donne une moins bonne tête), et un éclat tranchant de la
#   même pierre (pour fendre, plus tard). Le percuteur reste. Pas de coup raté pour l'instant.
# Fendre, Assembler, Ficeler : bientôt.
const Inventory = preload("res://scripts/inventory.gd")

const ACTIONS := ["tresser", "tailler", "fendre", "assembler", "ficeler"]
const ACTION_NAMES := {"tresser": "Tresser", "tailler": "Tailler", "fendre": "Fendre", "assembler": "Assembler", "ficeler": "Ficeler"}
const READY := ["tresser", "tailler"]
const BRAID_FIBERS := 3
const BRAID_SECONDS := 3.0
const CORD_LENGTH := 0.33
const CORDS := {"fibre_ortie": "ficelle_ortie", "fibre_lin": "ficelle_lin", "fibre_herbe": "ficelle_herbe"}
const HAMMERS := ["caillou", "caillou_calcaire", "caillou_silex"]
# Pierre à tailler : identifiant → pierre de la tête (0 calcaire, 1 silex).
const KNAP_STONES := {"caillou_calcaire": 0, "caillou_silex": 1}
const KNAP_SIZES := [3, 4, 5]
const KNAP_HITS := {3: 5, 4: 6, 5: 8}
const HEADS := {"hache": "tete_hache", "pioche": "tete_pioche"}
const HEAD_NAMES := {"hache": "Tête de hache", "pioche": "Tête de pioche"}
const FLAKES := {0: "eclat_calcaire", 1: "eclat_silex"}
const FLAKE_WEIGHT := 40.0
# Poids de la tête : une part de la pierre de départ (le reste part en éclats).
const HEAD_SHARE := 0.6

static func is_ready(action: String) -> bool:
	return action in READY

# Toutes les cases où l'on prend des objets : en Survie, les mains et les poches ; en Créatif, la barre et la grille.
static func places(inventory: Inventory) -> Array:
	if inventory.mode == Inventory.SURVIVAL:
		return (Inventory.HANDS + Inventory.POCKETS).map(func(index): return ["bar", index])
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
			"percuteur", "pierre":
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
		"pierre":
			for id in KNAP_STONES:
				for size in KNAP_SIZES:
					var value := {"objet": id, "taille": size}
					result.append({"label": "%s (taille %d, Créatif)" % [Inventory.ITEMS[id].nom, size], "value": value, "area": "", "index": -1, "unit": -1, "creative": true})
	return result

static func hits_for(stone: Dictionary) -> int:
	return int(KNAP_HITS.get(int(stone.get("taille", 4)), 6))

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
