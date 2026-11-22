extends RefCounted
# 0.0.8.16 (#208, demande de l'utilisateur) : Carnet de route (O + C, ou le menu Échap) : à gauche, les commandes du jeu
# en cases (un clic : leurs détails au milieu) ; à droite, le chemin pour fabriquer ses premiers outils, étape par étape.
# Les cases et les étapes se cochent quand on les a faites (une fois, par monde : joueur.json « carnet ») ; un bouton
# « Réinitialiser » efface tout pour recommencer. Écran : carnet_ui.gd. Nom original (choix de l'utilisateur).
# image : « menu:nom » (images des menus, menu_images.gd) ou « objet:id » (images des objets, item_icons.gd).
const Inventory = preload("res://scripts/inventory.gd")

signal changed(id: String)

const CASES := [
	{"id": "deplacer", "nom": "Se déplacer", "touches": "Z Q S D · Espace · souris", "image": "objet:orbe_retour",
		"details": "Z Q S D : marcher (← → : aller de côté). La souris : regarder. Espace : sauter ; deux fois de suite : voler (Espace monte, Y descend) ; encore deux fois : se poser.\nY : se baisser. R : courir.\n↑ ou ↓ avec A : tout le déplacement plus ou moins vite ; avec Z : la marche ; avec R : la course. ⌫ avec la même touche : par défaut ; ⌫ deux fois : tout par défaut.\nToutes les touches se changent dans Paramètres → Contrôles."},
	{"id": "inventaire", "nom": "Ouvrir l'inventaire", "touches": "O + I", "image": "menu:poche",
		"details": "O + I ouvre et ferme l'inventaire (Échap le ferme aussi).\nClic gauche : prendre ou poser (glisser : partager le tas entre les cases). Clic droit avec un objet tenu : en poser un (glisser : un par case). « + » : les détails (et les variantes, en Créatif). D + T : détails de l'objet en main. Jeter au sol : la croix, hors de la fenêtre, ou J (Ctrl + J : tout le tas).\nSurvie : deux mains (4 kg et 1,5 L chacune, 8 kg et 3 L à deux) et quatre poches (1 kg et 0,5 L chacune).\nCréatif : tout est illimité, rangé par onglets ; clic droit sur un objet du haut : dans la première case libre ; D + E : supprimer le tas."},
	{"id": "fabrication", "nom": "Ouvrir la fabrication", "touches": "O + F", "image": "menu:tresser",
		"details": "O + F ouvre et ferme la fabrication. On choisit l'action, puis ses objets (mains et poches en Survie), qui viennent dans les deux mains :\n• Tresser : 3 fibres du même type, clic gauche maintenu : une ficelle.\n• Tailler : un caillou pour frapper et un silex ou un calcaire (taille 3 à 5) : un clic par coup ; une tête de hache, de pioche, ou un éclat tranchant.\n• Fendre : une branche (2 à 5 cm, 40 cm à 1 m) et un éclat, clic gauche maintenu : le bout est fendu.\n• Assembler : la branche fendue et une tête, un clic.\n• Ficeler : l'outil assemblé et 3 ficelles (ou une liane), clic gauche maintenu : un tour à la fois."},
	{"id": "actions", "nom": "Changer d'action", "touches": "B + T", "image": "menu:creuser",
		"details": "B + T ouvre le menu des actions ; la molette choisit, T passe à l'autre ligne.\nClic gauche : Creuser / Casser (creuse, coupe le bois), Casser / Récupérer des objets (clic court : ramasser ; maintenu : arracher une plante, l'herbe), Récupérer des matériaux (une poignée de terre, de sable… ; sur l'herbe : une motte de gazon), Casser / Arracher (la plante ou l'herbe arrachée reste au sol).\nClic droit : Poser (la matière, la plante ou le gazon en main), Aplanir, Lisser, Manger.\nB + molette : taille du geste."},
	{"id": "ramasser", "nom": "Ramasser un objet", "touches": "R · clic de la molette", "image": "menu:casser_objets",
		"details": "R en visant un objet au sol (caillou, bâton, fruit…) : il va dans la main choisie, sinon l'autre main ou une poche, s'il reste de la place.\nLe clic de la molette fait pareil ; en Créatif, il met toujours l'objet dans la case choisie."},
	{"id": "recolter", "nom": "Récolter des fibres", "touches": "R maintenu sur une plante", "image": "objet:fibre_lin",
		"details": "R maintenu 3 secondes sur une ortie, du lin ou des herbes longues : 1 à 3 fibres ; la plante reste, coupée. Avec un éclat tranchant en main : deux fois plus vite.\nL'ortie pique : à mains nues, beaucoup ; avec un éclat, un peu.\nSur le tronc d'un tilleul à liane : un morceau de liane (3 par arbre)."},
	{"id": "recuperer", "nom": "Récupérer des matériaux", "touches": "R + I maintenus", "image": "menu:recuperer_materiaux",
		"details": "R + I maintenus en visant le sol (ou le mode « Récupérer des matériaux » du clic gauche) : une poignée de terre, de sable, d'argile, de boue ou de gravier. Sur l'herbe : d'abord une motte de gazon.\nPoser (clic droit) utilise ce qu'on tient : une poignée par petit cube."},
	{"id": "planter", "nom": "Planter, poser du gazon", "touches": "clic droit (Poser)", "image": "objet:plante_lin",
		"details": "Une plante arrachée (clic gauche maintenu sur elle) se replante avec le clic droit, dans la terre ou l'herbe ; coupée, elle repousse après 10 minutes de jeu.\nUne motte de gazon posée sur la terre : l'herbe y repousse."},
	{"id": "manger", "nom": "Manger", "touches": "clic droit maintenu", "image": "menu:manger",
		"details": "Un fruit en main (pomme, noisette), clic droit maintenu : on le mange, la vie remonte. Choisir « Manger » dans le menu des actions (B + T) pour que le clic droit ne pose rien."},
	{"id": "jeter", "nom": "Jeter au sol", "touches": "J · Ctrl + J", "image": "objet:caillou",
		"details": "J : l'objet en main tombe au sol devant soi, un à la fois ; Ctrl + J : tout le tas. En Créatif, D + E le supprime (rien ne tombe)."},
]

# Le chemin des premiers outils. « objets » : avoir l'un d'eux sur soi (Survie) coche l'étape ; « branche_fendue » : une
# branche fendue.
const STEPS := [
	{"id": "cailloux", "nom": "Ramasser des cailloux : un pour frapper, et un silex ou un calcaire à tailler", "image": "objet:caillou_silex", "objets": ["caillou", "caillou_calcaire", "caillou_silex"]},
	{"id": "fibres", "nom": "Récolter des fibres (R sur une ortie, du lin ou des herbes longues)", "image": "objet:fibre_lin", "objets": ["fibre_ortie", "fibre_lin", "fibre_herbe"]},
	{"id": "tresser", "nom": "Tresser une ficelle : 3 fibres du même type (O + F → Tresser)", "image": "menu:tresser", "objets": ["ficelle_ortie", "ficelle_lin", "ficelle_herbe"]},
	{"id": "eclat", "nom": "Tailler un éclat tranchant (O + F → Tailler)", "image": "menu:tailler", "objets": ["eclat_silex", "eclat_calcaire"]},
	{"id": "tete", "nom": "Tailler une tête de hache ou de pioche", "image": "objet:tete_hache", "objets": ["tete_hache", "tete_pioche"]},
	{"id": "branche", "nom": "Ramasser une branche (2 à 5 cm, 40 cm à 1 m)", "image": "objet:branche", "objets": ["branche"]},
	{"id": "fendre", "nom": "Fendre le bout de la branche avec l'éclat (O + F → Fendre)", "image": "menu:fendre", "objets": ["branche_fendue"]},
	{"id": "assembler", "nom": "Assembler : la tête dans la fente (O + F → Assembler)", "image": "menu:assembler", "objets": ["hache_a_ficeler", "pioche_a_ficeler"]},
	{"id": "hache", "nom": "Ficeler : une hache en pierre (3 ficelles ou une liane)", "image": "menu:ficeler", "objets": ["hache_pierre"]},
	{"id": "pioche", "nom": "Et une pioche en pierre (elle casse la pierre)", "image": "objet:pioche_pierre", "objets": ["pioche_pierre"]},
]

var done: Dictionary = {}

static func name_of(id: String) -> String:
	for entry: Dictionary in CASES + STEPS:
		if entry.id == id:
			return entry.nom
	return id

# Coche une case ou une étape ; vrai si c'est nouveau.
func mark(id: String) -> bool:
	if done.has(id) or name_of(id) == id:
		return false
	done[id] = true
	changed.emit(id)
	return true

func is_done(id: String) -> bool:
	return done.has(id)

func reset() -> void:
	done.clear()
	changed.emit("")

func to_array() -> Array:
	return done.keys()

func from_array(saved: Variant) -> void:
	done.clear()
	if saved is Array:
		for id in saved:
			if name_of(str(id)) != str(id):
				done[str(id)] = true

# Étapes du chemin cochées par ce qu'on a sur soi (Survie : mains et poches). Rend les étapes nouvellement cochées.
func check_inventory(inventory: Inventory) -> Array:
	var have := {}
	for place in _places(inventory):
		var there: Dictionary = inventory.item(place[0], place[1])
		if there.is_empty():
			continue
		have[str(there.get("objet", ""))] = true
		if there.get("objet") == "branche":
			for unit in Inventory.units(there):
				if int(unit.get("fendue", 0)) == 1:
					have["branche_fendue"] = true
	var fresh := []
	for step: Dictionary in STEPS:
		if not done.has(step.id) and step.objets.any(func(id): return have.has(id)):
			mark(step.id)
			fresh.append(step.id)
	return fresh

static func _places(inventory: Inventory) -> Array:
	if inventory.mode == Inventory.SURVIVAL:
		return (Inventory.HANDS + Inventory.POCKETS).map(func(index): return ["bar", index])
	return inventory.bar_slots().map(func(index): return ["bar", index])
