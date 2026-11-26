extends RefCounted
# 0.0.8.16 (#208, demande de l'utilisateur) : Carnet de route (O + C, ou le menu Échap). Écran : carnet_ui.gd.
# 0.0.8.19 (demande de l'utilisateur) : en arbre : des cases (une image, deux ou trois mots dessous) reliées par des
# lignes, à partir d'une case « Départ » au centre. Trois branches, chacune dans l'ordre où l'on doit faire les choses (la
# plus facile près du centre) : à gauche les commandes, en haut ce qu'on récupère, à droite ce qu'on fabrique ; plus c'est
# avancé, plus c'est loin du centre. En bas : rien pour l'instant. Un clic sur une case : tous ses détails.
# Les cases se cochent quand on les a faites (une fois, par monde : joueur.json « carnet ») : une action faite
# (world.notebook_mark), ou un objet qu'on a sur soi (Survie : « objets ») ; « Réinitialiser » efface tout.
# image : « menu:nom » (images des menus, menu_images.gd) ou « objet:id » (images des objets, item_icons.gd).
const Inventory = preload("res://scripts/inventory.gd")

signal changed(id: String)

const BRANCHES := ["gauche", "haut", "droite"]
const BRANCH_NAMES := {"gauche": "Commandes", "haut": "Récupérer", "droite": "Fabriquer"}

# Cases : id, nom court (sous la case), branche et rang (1 : près du centre), parent (case d'avant), décalage (embranchement,
# en cases : vers le haut si négatif, pour la branche de droite), touches, image, détails ; « objets » : avoir l'un d'eux sur soi la coche.
const NODES := [
	{"id": "depart", "nom": "Départ", "branche": "", "rang": 0, "parent": "", "image": "objet:orbe_retour", "touches": "O + C : ce carnet",
		"details": "Bienvenue ! Ce carnet montre tout ce qu'on peut faire, dans l'ordre, du plus facile au plus difficile :\n• à gauche, les commandes du jeu ;\n• en haut, ce qu'on récupère dans la nature ;\n• à droite, ce qu'on fabrique, jusqu'à la hache et la pioche.\nUn clic sur une case : ses détails. Les cases se cochent toutes seules quand c'est fait. On déplace la vue en glissant avec la souris ; la molette rapproche ou éloigne."},
	# --- À gauche : les commandes ---
	{"id": "deplacer", "nom": "Se déplacer", "branche": "gauche", "rang": 1, "parent": "depart", "image": "objet:orbe_retour", "touches": "Z Q S D · Espace · souris",
		"details": "Z Q S D : marcher (← → : aller de côté). La souris : regarder. Espace : sauter ; deux fois de suite : voler (Espace monte, Y descend) ; encore deux fois : se poser.\nY : se baisser. R : courir.\n↑ ou ↓ avec A : tout le déplacement plus ou moins vite ; avec Z : la marche ; avec R : la course. ⌫ avec la même touche : par défaut ; ⌫ deux fois : tout par défaut.\nToutes les touches se changent dans Paramètres → Contrôles."},
	{"id": "inventaire", "nom": "Inventaire", "branche": "gauche", "rang": 2, "parent": "deplacer", "image": "menu:poche", "touches": "O + I",
		"details": "O + I ouvre et ferme l'inventaire (Échap le ferme aussi).\nClic gauche : prendre ou poser (glisser : partager le tas entre les cases). Clic droit avec un objet tenu : en poser un (glisser : un par case) ; la main vide : prendre la moitié de la pile. Double clic : les objets pareils se rassemblent dans la case (jusqu'à 99). En Créatif, « Supprimer » (sous « Jeter ») fait disparaître l'objet tenu. « + » : les détails (et les variantes, en Créatif). D + T : détails de l'objet en main. Jeter au sol : la croix, hors de la fenêtre, ou J (Ctrl + J : tout le tas).\nSurvie : deux mains (4 kg et 1,5 L chacune, 8 kg et 3 L à deux) et quatre poches (1 kg et 0,5 L en tout) ; avec un sac en filet, 4 cases de plus (7 à 10, environ 3 kg et 10 L).\nCréatif : tout est illimité, rangé par onglets ; clic droit sur un objet du haut : dans la première case libre ; D + E : supprimer le tas."},
	{"id": "actions", "nom": "Actions", "branche": "gauche", "rang": 3, "parent": "inventaire", "image": "menu:creuser", "touches": "B + T",
		"details": "B + T ouvre le menu des actions ; la molette choisit, T passe à l'autre ligne.\nClic gauche : Creuser / Casser (creuse, coupe le bois), Casser / Récupérer des objets (clic court : ramasser ; maintenu : arracher une plante, l'herbe), Récupérer des matériaux (une poignée de terre, de sable… ; sur l'herbe : une motte de gazon), Casser / Arracher (la plante ou l'herbe arrachée reste au sol).\nClic droit : Poser (la matière, la plante ou le gazon en main), Aplanir, Lisser, Manger.\nB + molette : taille du geste."},
	{"id": "fabrication", "nom": "Fabrication", "branche": "gauche", "rang": 4, "parent": "actions", "image": "menu:tresser", "touches": "O + F",
		"details": "O + F ouvre et ferme la fabrication. On choisit l'action, puis ses objets (mains et poches en Survie), qui viennent dans les deux mains :\n• Tresser : 3 fibres du même type, clic gauche maintenu : une ficelle.\n• Tailler : un caillou pour frapper et un silex ou un calcaire (taille 3 à 5) : un clic par coup ; une tête de hache, de pioche, ou un éclat tranchant.\n• Fendre : une branche (2 à 5 cm, 40 cm à 1 m) et un éclat, clic gauche maintenu : le bout est fendu.\n• Assembler : la branche fendue et une tête, un clic.\n• Ficeler : l'outil assemblé et 3 ficelles (ou une liane), clic gauche maintenu : un tour à la fois.\n• Tresser 3 ficelles : une cordelette ; Nouer : 5 cordelettes (ou 4 et une liane), clic gauche maintenu : un sac en filet.\nChaque outil a sa fiche de fabrication (« + » ou D + T, puis « Fiche de fabrication »)."},
	{"id": "manger", "nom": "Manger", "branche": "gauche", "rang": 5, "parent": "fabrication", "image": "menu:manger", "touches": "clic droit maintenu",
		"details": "Un fruit en main (pomme, noisette), clic droit maintenu : on le mange, la vie remonte. Choisir « Manger » dans le menu des actions (B + T) pour que le clic droit ne pose rien."},
	{"id": "jeter", "nom": "Jeter", "branche": "gauche", "rang": 6, "parent": "manger", "image": "objet:caillou", "touches": "J · Ctrl + J",
		"details": "J : l'objet en main tombe au sol devant soi, un à la fois ; Ctrl + J : tout le tas. En Créatif, D + E le supprime (rien ne tombe)."},
	# --- En haut : récupérer ---
	{"id": "cailloux", "nom": "Cailloux", "branche": "haut", "rang": 1, "parent": "depart", "image": "objet:caillou_silex", "touches": "R · clic de la molette", "objets": ["caillou", "caillou_calcaire", "caillou_silex"],
		"details": "Ramasser des cailloux : R en visant un caillou au sol (ou le clic de la molette) ; il va dans la main choisie, sinon l'autre main ou une poche, s'il reste de la place.\nIl en faut un pour frapper, et un silex ou un calcaire (taille 3 à 5) à tailler."},
	{"id": "fibres", "nom": "Fibres", "branche": "haut", "rang": 2, "parent": "cailloux", "image": "objet:fibre_lin", "touches": "R maintenu sur une plante", "objets": ["fibre_ortie", "fibre_lin", "fibre_herbe"],
		"details": "R maintenu 3 secondes sur une ortie, du lin ou des herbes longues : 1 à 3 fibres ; la plante reste, coupée. Avec un éclat tranchant en main : deux fois plus vite.\nL'ortie pique : à mains nues, beaucoup ; avec un éclat, un peu.\nSur le tronc d'un tilleul à liane : un morceau de liane (3 par arbre)."},
	{"id": "branche", "nom": "Branche", "branche": "haut", "rang": 3, "parent": "fibres", "image": "objet:branche", "touches": "R · couper un arbre", "objets": ["branche"],
		"details": "Une branche pour le manche : 2 à 5 cm d'épaisseur, 40 cm à 1 m de long. On en trouve au sol (branches mortes : moins bon manche) ou on la coupe sur un arbre (clic gauche maintenu sur une branche)."},
	{"id": "recuperer", "nom": "Terre, sable", "branche": "haut", "rang": 4, "parent": "branche", "image": "menu:recuperer_materiaux", "touches": "R + I maintenus",
		"details": "R + I maintenus en visant le sol (ou le mode « Récupérer des matériaux » du clic gauche) : une poignée de terre, de sable, d'argile, de boue ou de gravier. Sur l'herbe : d'abord une motte de gazon.\nPoser (clic droit) utilise ce qu'on tient : une poignée par petit cube."},
	{"id": "planter", "nom": "Plantes", "branche": "haut", "rang": 5, "parent": "recuperer", "image": "objet:plante_lin", "touches": "clic gauche maintenu · clic droit",
		"details": "Une plante s'arrache entière (clic gauche maintenu, modes « Casser / Arracher » ou « Casser / Récupérer des objets ») et se replante avec le clic droit, dans la terre ou l'herbe ; coupée, elle repousse après 10 minutes de jeu.\nUne motte de gazon posée sur la terre : l'herbe y repousse."},
	# --- À droite : fabriquer ---
	{"id": "tresser", "nom": "Ficelle", "branche": "droite", "rang": 1, "parent": "depart", "image": "menu:tresser", "touches": "O + F → Tresser", "objets": ["ficelle_ortie", "ficelle_lin", "ficelle_herbe"],
		"details": "Tresser une ficelle : 3 fibres du même type (O + F → Tresser, clic gauche maintenu). Les fibres de lin donnent la ficelle la plus solide. Tresser des fibres d'ortie pique un peu."},
	{"id": "eclat", "nom": "Éclat", "branche": "droite", "rang": 2, "parent": "tresser", "image": "menu:tailler", "touches": "O + F → Tailler", "objets": ["eclat_silex", "eclat_calcaire"],
		"details": "Tailler un éclat tranchant : un caillou pour frapper dans une main, un silex ou un calcaire dans l'autre (O + F → Tailler, un clic par coup).\nAvec l'éclat en main, on récolte les fibres DEUX FOIS PLUS VITE (1,5 s au lieu de 3 s) et l'ortie pique moins : à faire avant les cordelettes du sac. Il sert aussi à fendre une branche."},
		# 0.0.8.21 (#207, demandes de l'utilisateur) : l'éclat (récolte plus rapide), puis la cordelette, puis le sac en filet.
		{"id": "cordelette", "nom": "Cordelette", "branche": "droite", "dessous": true, "parent": "eclat", "image": "objet:cordelette_lin", "touches": "O + F → Tresser", "objets": ["cordelette_ortie", "cordelette_lin", "cordelette_herbe"],
			"details": "Une cordelette : 3 ficelles du même type tressées ensemble (O + F → Tresser, clic gauche maintenu) ; plus épaisse et solide qu'une ficelle. Il en faut 5 pour un sac en filet, soit 15 ficelles (45 fibres) : récoltez avec un éclat tranchant en main, c'est deux fois plus rapide."},
		{"id": "sac", "nom": "Sac en filet", "branche": "droite", "dessous": true, "parent": "cordelette", "image": "objet:sac_filet", "touches": "O + F → Nouer", "objets": ["sac_filet"],
			"details": "Nouer un sac en filet (O + F → Nouer) : 4 cordelettes du même type pour les mailles, 1 cordelette ou 1 liane pour la bretelle ; clic gauche maintenu, une rangée de mailles à la fois (6 à 10 : plus il y en a, plus les mailles sont serrées).\nIl va sur l'épaule : ses 4 cases sont les cases 7 à 10 de la barre ; il porte environ 4,3 kg (lin et 10 rangées : 5 kg) et 10 L. On se sert d'un objet du sac directement, même la main pleine.\nUn deuxième sac : ses 4 cases sont dans l'inventaire (O + I), au-dessus des mains. Les poignées de terre, de sable… et les fibres passent entre les mailles. Un sac s'enlève vide, dans l'inventaire (Équipement)."},
	{"id": "tete", "nom": "Tête taillée", "branche": "droite", "rang": 3, "parent": "eclat", "image": "objet:tete_hache", "touches": "O + F → Tailler", "objets": ["tete_hache", "tete_pioche"],
		"details": "Tailler une tête de hache ou de pioche (O + F → Tailler) : plus la pierre est grande (taille 5), meilleure est la tête ; le silex est le plus dur."},
	{"id": "fendre", "nom": "Fendre", "branche": "droite", "rang": 4, "parent": "tete", "image": "menu:fendre", "touches": "O + F → Fendre", "objets": ["branche_fendue"],
		"details": "Fendre le bout de la branche avec l'éclat (O + F → Fendre, clic gauche maintenu) : la fente recevra la tête.
Une branche fine (1 à 2,5 cm, 15 à 40 cm) fendue devient une navette (sa case, juste en dessous)."},
		# 0.0.8.36 (demande de l'utilisateur) : la navette, sa propre case, sous Fendre.
		{"id": "navette", "nom": "Navette", "branche": "droite", "dessous": true, "parent": "fendre", "image": "objet:navette", "touches": "O + F → Fendre", "objets": ["navette"],
			"details": "Une navette : une branche fine (1 à 2,5 cm d'épaisseur, 15 à 40 cm de long) fendue au bout (O + F → Fendre, avec un éclat). La ficelle s'enroule dessus.
Choisie pour Ficeler (dans la barre : mains, poches ou sac), on ficelle deux fois plus vite. Elle s'use un peu à chaque outil ficelé."},
	{"id": "assembler", "nom": "Assembler", "branche": "droite", "rang": 5, "parent": "fendre", "image": "menu:assembler", "touches": "O + F → Assembler", "objets": ["hache_a_ficeler", "pioche_a_ficeler"],
		"details": "Assembler : la tête dans la fente de la branche (O + F → Assembler, un clic). L'outil est à ficeler."},
	{"id": "hache", "nom": "Hache", "branche": "droite", "rang": 6, "decalage": -0.7, "parent": "assembler", "image": "menu:ficeler", "touches": "O + F → Ficeler", "objets": ["hache_pierre"],
		"details": "Ficeler une hache : 3 ficelles (ou une liane), clic gauche maintenu, un tour à la fois (8 tours : le plus solide). La hache coupe le bois 3 fois plus vite."},
	{"id": "pioche", "nom": "Pioche", "branche": "droite", "rang": 6, "decalage": 0.7, "parent": "assembler", "image": "objet:pioche_pierre", "touches": "O + F → Ficeler", "objets": ["pioche_pierre"],
		"details": "Ficeler une pioche, comme la hache. La pioche casse la pierre 4 fois plus vite (avec des éclats) et creuse la terre 2 fois plus vite."},
	# 0.0.8.40 (demandes de l'utilisateur : toutes les actions qu'on peut faire, dans le carnet) : Défeuiller, Détresser,
	# Écorcer, Refaire le lien, Défaire un outil. Images provisoires (celles de Blender viendront plus tard).
	{"id": "defeuiller", "nom": "Défeuiller", "branche": "haut", "rang": 3, "decalage": 1.0, "parent": "fibres", "image": "objet:feuilles", "touches": "R sur une branche couchée",
		"details": "Défeuiller : R sur une branche, une tige ou un arbre couché fait tomber ses feuilles en tas (à ramasser avec R) ; R encore : son bois au sol, des bâtons et des bûches à leur vraie taille.\nUne petite branche feuillue coupée donne aussi un bâton, ses feuilles à part."},
	{"id": "detresser", "nom": "Détresser", "branche": "droite", "dessous": true, "parent": "tresser", "image": "menu:tresser", "touches": "O + F → Détresser",
		"details": "Détresser (O + F → Détresser, clic gauche maintenu 2 s) : une ficelle redonne ses 3 fibres, une cordelette ses 3 ficelles. Utile si on s'est trompé de type."},
	{"id": "ecorcer", "nom": "Écorcer", "branche": "droite", "dessous": true, "parent": "navette", "image": "menu:fendre", "touches": "O + F → Écorcer",
		"details": "Écorcer un bâton ou une bûche (O + F → Écorcer, avec un éclat tranchant, clic gauche maintenu 3 s) : l'écorce part, le bois est plus léger (« écorcé » dans ses détails)."},
	{"id": "relier", "nom": "Refaire le lien", "branche": "droite", "rang": 7, "decalage": -0.7, "parent": "hache", "image": "menu:ficeler", "touches": "O + F → Refaire le lien",
		"details": "Refaire le lien d'une hache ou d'une pioche usée (O + F → Refaire le lien) : 3 ficelles du même type ou une liane, clic gauche maintenu 4 s. L'outil retrouve une bonne part de ses coups (la tête et le manche s'usent quand même)."},
	{"id": "defaire", "nom": "Défaire un outil", "branche": "droite", "rang": 7, "decalage": 0.7, "parent": "pioche", "image": "menu:assembler", "touches": "O + F → Défaire un outil",
		"details": "Défaire une hache ou une pioche (O + F → Défaire un outil, un clic) : on récupère la tête, le manche (branche fendue) et une ficelle usée (rien pour une liane)."},
]

var done: Dictionary = {}

static func node(id: String) -> Dictionary:
	for entry: Dictionary in NODES:
		if entry.id == id:
			return entry
	return {}

static func name_of(id: String) -> String:
	var entry := node(id)
	return entry.nom if not entry.is_empty() else id

# Place d'une case, en cases depuis le centre : x vers la droite, y vers le bas (la branche du haut monte).
# 0.0.8.36 (demande de l'utilisateur) : « dessous » : une suite d'une case, pile en dessous d'elle, dans la même colonne
# (Éclat → Cordelette → Sac en filet, Fendre → Navette).
static func place_of(entry: Dictionary) -> Vector2:
	if entry.get("dessous", false):
		return place_of(node(str(entry.get("parent", "")))) + Vector2(0.0, 1.0)
	return _own_place(entry)

static func _own_place(entry: Dictionary) -> Vector2:
	var rank := float(entry.get("rang", 0))
	var side := float(entry.get("decalage", 0.0))
	match entry.get("branche", ""):
		"gauche":
			return Vector2(-rank, side)
		"droite":
			return Vector2(rank, side)
		"bas":
			return Vector2(side, rank)
		"haut":
			return Vector2(side, -rank)
	return Vector2.ZERO

# Coche une case ; vrai si c'est nouveau. La case « Départ » est toujours faite.
func mark(id: String) -> bool:
	if done.has(id) or node(id).is_empty() or id == "depart":
		return false
	done[id] = true
	changed.emit(id)
	return true

func is_done(id: String) -> bool:
	return id == "depart" or done.has(id)

# Une case qu'on peut faire maintenant : celle d'avant est faite.
func is_open(id: String) -> bool:
	var entry := node(id)
	return entry.is_empty() or str(entry.get("parent", "")).is_empty() or is_done(entry.parent)

func reset() -> void:
	done.clear()
	changed.emit("")

func to_array() -> Array:
	return done.keys()

func from_array(saved: Variant) -> void:
	done.clear()
	if saved is Array:
		for id in saved:
			if not node(str(id)).is_empty() and str(id) != "depart":
				done[str(id)] = true

# Cases cochées par ce qu'on a sur soi (Survie : mains et poches). Rend les cases nouvellement cochées.
func check_inventory(inventory: Inventory) -> Array:
	var have := {}
	# 0.0.8.21 (#207) : un sac porté sur l'épaule compte.
	if inventory.bag_worn(0) or inventory.bag_worn(1):
		have[Inventory.BAG_ID] = true
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
	for entry: Dictionary in NODES:
		if not done.has(entry.id) and entry.get("objets", []).any(func(id): return have.has(id)):
			mark(entry.id)
			fresh.append(entry.id)
	return fresh

static func _places(inventory: Inventory) -> Array:
	if inventory.mode == Inventory.SURVIVAL:
		return inventory.carried_places()
	return inventory.bar_slots().map(func(index): return ["bar", index])
