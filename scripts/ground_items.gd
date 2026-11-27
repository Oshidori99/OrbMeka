extends Node3D
# 0.0.7.3 : objets posés au sol (morceaux de pierre cassée, cailloux, fruits, poignées qui ne tiennent plus en main).
# Décision du 15.11.2026 (issue #40) : chaque objet reste visible tel quel, à sa place (pas de tas fusionnés ; 0.0.8.23 :
# sauf les feuilles, en tas de 20 au plus, demande de l'utilisateur) ;
# les objets du même type sont dessinés ensemble (un MultiMesh par type et par forme), léger même avec beaucoup d'objets.
# 0.0.7.5 : chaque objet garde toutes ses caractéristiques (inventory.gd : taille, poids, forme, orientation, couleur,
# coups reçus) ; cailloux et éclats ont le même rendu que les cailloux du monde (matière des pierres, aspect pierre,
# calcaire ou silex), si bien qu'un caillou ramassé puis reposé est exactement le même.
# Chaque objet a une petite collision ronde pour le viser (R : ramasser) ; elle n'arrête pas le joueur.
# Sauvegarde : objets.json, « objets_au_sol ».
const Inventory = preload("res://scripts/inventory.gd")
const Rocks = preload("res://scripts/rocks.gd")
const Trees = preload("res://scripts/trees.gd")
const ReturnOrb = preload("res://scripts/return_orb.gd")
const Fibers = preload("res://scripts/fibers.gd")
const Plants = preload("res://scripts/plants.gd")
const StoneHeads = preload("res://scripts/stone_heads.gd")
const ToolModels = preload("res://scripts/tool_models.gd")
const NetBag = preload("res://scripts/net_bag.gd")
# Au-delà, les plus anciens disparaissent (seulement s'ils sont très nombreux).
const MAX_ITEMS := 3000
# 0.0.8.23 : tas de feuilles : comptés à part (ils ne font jamais disparaître les autres objets) ; au-delà, le plus
# ancien tas disparaît. Des feuilles qui tombent à moins de LEAF_MERGE d'un tas pas plein le complètent d'abord.
const MAX_LEAF_PILES := 600
const LEAF_MERGE := 0.6
var _pile_count := 0
const FALL_SECONDS := 0.35
# Taille d'un éclat et d'une poignée, en mètres (les cailloux et les fruits gardent leur taille).
# 0.0.8.21 (demande de l'utilisateur : on le voyait mal) : éclats un peu plus grands au sol (avant 7 cm).
const PIECE_SIZE := 0.1
# 0.0.8.15 (#239) : plante arrachée posée au sol (hauteur, m) ; motte de gazon (rayon, épaisseur).
const PLANT_SIZE := 0.35
const TURF_RADIUS := 0.12
const TURF_HEIGHT := 0.05
static var _turf: ArrayMesh

# Motte : un disque de terre (côtés et dessous) au dessus vert.
static func turf_mesh() -> ArrayMesh:
	if _turf != null:
		return _turf
	var made := ArrayMesh.new()
	var side := CylinderMesh.new()
	side.top_radius = TURF_RADIUS
	side.bottom_radius = TURF_RADIUS * 0.92
	side.height = TURF_HEIGHT
	side.radial_segments = 12
	side.rings = 1
	side.cap_top = false
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, side.get_mesh_arrays())
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color("#6b4a2c")
	soil.roughness = 1.0
	made.surface_set_material(0, soil)
	var top := CylinderMesh.new()
	top.top_radius = TURF_RADIUS * 1.02
	top.bottom_radius = TURF_RADIUS * 1.02
	top.height = 0.012
	top.radial_segments = 12
	top.rings = 1
	var arrays := top.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in range(points.size()):
		points[index].y += TURF_HEIGHT * 0.5
	arrays[Mesh.ARRAY_VERTEX] = points
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color("#5e8a2f")
	grass.roughness = 0.95
	made.surface_set_material(1, grass)
	_turf = made
	return made
const HANDFUL_SIZE := 0.08
const HAZELNUT_SIZE := 0.025
const AIM_RADIUS := 0.09

signal changed

# Matière des pierres du monde (world.gd, aspect par objet : données propres à chaque instance).
var stone_material: Material
# 0.0.8.9 : pente du sol sous un point (donnée par le monde) : les objets se couchent dessus.
var normal_at := Callable()
# {"item": objet à plat {"objet": id, …caractéristiques}, "position": Vector3}
var entries: Array = []
var bodies: Array = []
var _drawn: Dictionary = {}
var _materials: Dictionary = {}
var _dirty := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	name = "GroundItems"
	rng.randomize()

# Ajoute un objet (à plat) tombé de « from » jusqu'au sol, près de « near » ; rend son numéro.
# spread : écart au hasard autour de « near » (0 : exactement là, objet posé à la main). Forme et orientation : celles
# de l'objet ; un objet qui n'en a pas encore (éclat neuf) en reçoit une, gardée ensuite.
func drop(value: Dictionary, from: Vector3, near: Vector3, rest_height: Callable, spread: float = 0.25) -> int:
	# 0.0.7.26 : un objet reposé n'est plus celui de la graine.
	value = value.duplicate(true)
	value.erase("graine")
	var item := value.duplicate(true)
	item.erase("nombre")
	if Inventory.is_object(item):
		if not item.has("forme"):
			item.forme = rng.randi_range(1, 7)
		if not item.has("rotation"):
			item.rotation = rng.randf_range(0.0, TAU)
	var spot := near + Vector3(rng.randf_range(-spread, spread), 0.0, rng.randf_range(-spread, spread))
	var pile := _kind(item) == "feuilles"
	if pile:
		# 0.0.8.23 (l'utilisateur : « quand le tas a 20 feuilles, un nouveau tas apparaît ») : d'abord le tas pas plein le
		# plus proche ; seulement le reste fait un nouveau tas.
		item.tas = clampi(int(item.get("tas", 1)), 1, Inventory.LEAF_PILE)
		var filled := _top_up_pile(item, spot)
		if filled >= 0:
			return filled
	var ground: float = rest_height.call(spot)
	var entry := {"item": item, "position": Vector3(spot.x, ground + lift(item), spot.z)}
	entries.append(entry)
	if pile:
		_pile_count += 1
		while _pile_count > MAX_LEAF_PILES:
			for at in range(entries.size()):
				if _kind(entries[at].item) == "feuilles":
					remove(at)
					break
	# Trop d'objets posés : le plus ancien part (jamais ceux de la graine, qui ne comptent pas ; 0.0.8.23 : ni les tas de
	# feuilles, comptés à part). Compté seulement s'il peut y en avoir trop (avant : à chaque objet posé, tous recomptés).
	elif entries.size() > MAX_ITEMS:
		var placed := entries.filter(func(other): return not other.item.has("graine") and _kind(other.item) != "feuilles").size()
		while placed > MAX_ITEMS:
			for at in range(entries.size()):
				if not entries[at].item.has("graine") and _kind(entries[at].item) != "feuilles":
					remove(at)
					break
			placed -= 1
	var index := entries.size() - 1
	_add_body(index)
	_dirty = true
	changed.emit()
	# Chute courte et visible : le petit objet glisse du point cassé jusqu'au sol.
	if is_inside_tree() and from.distance_to(entry.position) > 0.05:
		var falling := MeshInstance3D.new()
		falling.mesh = _mesh(item)
		# 0.0.8.7 (bug signalé par l'utilisateur : un silex posé n'avait pas tout de suite sa couleur) : une pierre qui tombe
		# n'a pas encore son aspect par objet (donné par la série au sol) : couleur unie de sa pierre pendant la chute.
		falling.material_override = _fall_material(item) if _kind(item) == "fruit" or (_look(item) >= 0 and stone_material != null) else _plain_material(item)
		falling.basis = _basis(item)
		add_child(falling)
		falling.global_position = from
		entry.hidden = true
		var tween := create_tween()
		tween.tween_property(falling, "global_position", entry.position, FALL_SECONDS).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(func():
			entry.erase("hidden")
			_dirty = true
			falling.queue_free())
	return index


# 0.0.7.26 (#212) : objets de la graine (branches mortes) près du joueur : posés sans chute, pas enregistrés tant qu'on n'y
# touche pas (« graine » : leur identifiant ; « colonne » : retirés avec elle). Ramassé ou recassé : seed_taken(id).
signal seed_taken(id: String)

func add_seeded(value: Dictionary, position: Vector3, column: Vector2i) -> void:
	entries.append({"item": value.duplicate(true), "position": position, "colonne": column})
	_add_body(entries.size() - 1)
	_dirty = true

# 0.0.8.29 : le sol a changé sous cet objet (creusé, retombé, posé) : il est reposé dessus. Vrai s'il a bougé.
func rest_again(index: int, ground_y: float) -> bool:
	if index < 0 or index >= entries.size() or index >= bodies.size():
		return false
	var entry: Dictionary = entries[index]
	var height := ground_y + lift(entry.item)
	var lowered := absf(float(entry.position.y) - height) >= 0.02
	if lowered:
		entry.position = Vector3(entry.position.x, height, entry.position.z)
		entry.erase("normal")
	var moved := lowered
	# 0.0.8.31 : un bois repose sur ses appuis tout du long : le sol a pu changer sous un bout seulement.
	if _kind(entry.item) == "bois" and ground_at.is_valid():
		var before: Variant = entry.get("pose")
		entry.erase("pose")
		var now := _wood_pose(entry)
		moved = moved or not (before is Vector2 and (before as Vector2).distance_to(now) < 0.02)
	if not moved:
		return false
	var old: Node = bodies[index]
	_add_body(index)
	bodies[index] = bodies.pop_back()
	if is_instance_valid(old):
		old.free()
	_dirty = true
	if lowered and not entry.item.has("graine"):
		changed.emit()
	return true

func remove_column_seeds(column: Vector2i) -> void:
	for index in range(entries.size() - 1, -1, -1):
		if entries[index].get("colonne") == column and entries[index].item.has("graine"):
			remove(index, false)
func remove(index: int, taken := true) -> Dictionary:
	if index < 0 or index >= entries.size():
		return {}
	var entry: Dictionary = entries[index]
	entries.remove_at(index)
	if _kind(entry.item) == "feuilles":
		_pile_count -= 1
	var body: Node = bodies[index]
	bodies.remove_at(index)
	if is_instance_valid(body):
		body.queue_free()
	for at in range(index, bodies.size()):
		bodies[at].set_meta("ground_index", at)
	_dirty = true
	var item: Dictionary = entry.item
	if item.has("graine"):
		if taken:
			seed_taken.emit(str(item.graine))
			changed.emit()
		item = item.duplicate(true)
		item.erase("graine")
	else:
		changed.emit()
	return item

func index_of(body: Node) -> int:
	return int(body.get_meta("ground_index", -1)) if is_instance_valid(body) else -1

# 0.0.8.23 : complète le tas de feuilles de la même essence pas plein le plus proche de « spot » (à moins de LEAF_MERGE)
# avec les feuilles de « item » (item.tas diminue d'autant). Rend son numéro si tout y est entré, -1 sinon.
func _top_up_pile(item: Dictionary, spot: Vector3) -> int:
	if int(item.tas) >= Inventory.LEAF_PILE:
		return -1
	var best := -1
	var closest := LEAF_MERGE
	var essence := int(item.get("essence", 0))
	for at in range(entries.size()):
		var other: Dictionary = entries[at].item
		if _kind(other) != "feuilles" or int(other.get("essence", 0)) != essence or int(other.get("tas", 1)) >= Inventory.LEAF_PILE:
			continue
		var gap := Vector2(entries[at].position.x - spot.x, entries[at].position.z - spot.z).length()
		if gap < closest:
			closest = gap
			best = at
	if best < 0:
		return -1
	var pile: Dictionary = entries[best].item
	var moved := mini(Inventory.LEAF_PILE - int(pile.get("tas", 1)), int(item.tas))
	pile.tas = int(pile.get("tas", 1)) + moved
	item.tas = int(item.tas) - moved
	_dirty = true
	changed.emit()
	return best if int(item.tas) <= 0 else -1

# 0.0.8.23 : feuilles restées dans un tas après en avoir ramassé (0 : le tas disparaît).
func set_pile(index: int, count: int) -> void:
	if index < 0 or index >= entries.size():
		return
	if count <= 0:
		remove(index)
		return
	entries[index].item.tas = mini(count, Inventory.LEAF_PILE)
	_dirty = true
	changed.emit()

static func _kind(value: Dictionary) -> String:
	return Inventory.ITEMS.get(value.get("objet", ""), {}).get("forme", "")

# Diamètre de l'objet, en mètres : un caillou rapetisse de 20 % par coup déjà reçu (comme dans le monde).
static func size_of(value: Dictionary) -> float:
	match _kind(value):
		"caillou":
			return Rocks.PEBBLE_SIZES[clampi(int(value.get("taille", 3)), 1, 7) - 1] * (1.0 - 0.2 * int(value.get("coups", 0)))
		"fruit":
			# 0.0.7.6 : fruit cueilli : sa vraie taille dans l'arbre (« diametre »), il reste le même une fois reposé.
			if value.has("diametre"):
				return float(value.diametre)
			if value.get("objet") == "pomme":
				return Inventory.APPLE_SIZES[clampi(int(value.get("taille", 2)), 1, 3) - 1]
			return HAZELNUT_SIZE
		"eclat":
			return PIECE_SIZE
		# 0.0.8.4 (#213) : fibres et liane : modèles déjà à leur taille (fibers.gd). 0.0.8.23 : tas de feuilles aussi.
		"fibre", "liane", "ficelle", "outil_brut", "outil_pierre", "sac", "feuilles", "feu":
			return 1.0
		# 0.0.8.5 (#211) : tête taillée : selon sa taille (3 petite, 4 moyenne, 5 grande).
		"tete":
			return StoneHeads.scale_for("hache" if value.get("objet") == "tete_hache" else "pioche", int(value.get("taille", 4)))
		# 0.0.8.2 (#231) : orbe de retour.
		"orbe":
			return ReturnOrb.SIZE
		# 0.0.8.15 (#239) : plante : son modèle (Plants.SIZES m) mis à PLANT_SIZE de haut ; motte : modèle à sa taille.
		"plante":
			return PLANT_SIZE / Plants.SIZES[clampi(int(Inventory.ITEMS.get(value.get("objet", ""), {}).get("plante", 0)), 0, 2)]
		"gazon":
			return 1.0
		# 0.0.7.8 : bâton ou tronc : son épaisseur (la longueur est à part).
		"bois":
			return float(value.get("epaisseur", 3.0)) / 100.0
	return HANDFUL_SIZE

# Hauteur du centre au-dessus du sol (cailloux : comme ceux du monde).
static func lift(value: Dictionary) -> float:
	if _kind(value) == "caillou":
		return Rocks.pebble_lift(clampi(int(value.get("taille", 3)), 1, 7), clampi(int(value.get("forme", 1)), 1, 7)) * (1.0 - 0.2 * int(value.get("coups", 0)))
	if _kind(value) in ["outil_brut", "outil_pierre"]:
		return float(value.get("epaisseur", 3.5)) / 200.0
	if _kind(value) in ["fibre", "liane", "ficelle"]:
		return 0.012
	if _kind(value) in ["plante", "sac", "feuilles", "feu"]:
		return 0.0
	if _kind(value) == "gazon":
		return TURF_HEIGHT * 0.5
	return size_of(value) * (0.5 if _kind(value) in ["fruit", "bois", "orbe"] else 0.3)

# Fruits : le modèle des arbres (rayon 1) ; bois : cylindre couché le long de son orientation ; autres : diamètre 1.
static func _basis(value: Dictionary) -> Basis:
	var turn := Basis(Vector3.UP, float(value.get("rotation", 0.0)))
	# 0.0.8.6 : outil couché, le manche le long du sol (son modèle est déjà à sa taille).
	if _kind(value) in ["outil_brut", "outil_pierre"]:
		return turn * Basis(Vector3.RIGHT, PI * 0.5)
	if _kind(value) == "bois":
		var thick := size_of(value)
		return turn * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(thick, float(value.get("longueur", 1.0)), thick))
	var scale := size_of(value) * (0.5 if _kind(value) == "fruit" else 1.0)
	return turn.scaled(Vector3.ONE * scale)

# 0.0.7.9 : bois conique : gros bout (« epaisseur ») et petit bout (« fin »), par pas de 5 %.
# 0.0.8.22 : jusqu'à 5 % (avant 20 % au moins) : une tige qui finit en pointe garde sa pointe fine.
static var _sticks: Dictionary = {}

static func taper_step(value: Dictionary) -> int:
	var thick := float(value.get("epaisseur", 3.0))
	return clampi(roundi(float(value.get("fin", thick * 0.84)) / maxf(thick, 0.01) * 20.0), 1, 20)

static func _two_tone(value: Dictionary) -> bool:
	return value.get("objet") == "pomme" and int(value.get("couleur", 1)) == 4

# 0.0.7.6 : pommes et noisettes au sol avec le même petit modèle que dans les arbres (Trees._fruit_mesh).
# 0.0.8.54 (lot C1, #230) : un objet à sa vraie taille, pour la main d'un personnage vu de dos ou de face (character_rig.gd) :
# le même modèle et la même matière qu'au sol ; un bois tenu par son milieu, le long de l'avant-bras (y du modèle). La
# valeur : une case (pile) ou à plat.
func held_model(value: Dictionary) -> MeshInstance3D:
	if value.is_empty() or not Inventory.ITEMS.has(value.get("objet", "")):
		return null
	var item: Dictionary = Inventory.flat(value.objet, value.pile[-1]) if value.has("pile") and not value.pile.is_empty() else value.duplicate(true)
	item.erase("rotation")
	var made := MeshInstance3D.new()
	made.name = "ObjetTenu"
	made.mesh = _mesh(item)
	var material := _plain_material(item)
	if material != null:
		made.material_override = material
	var shape := _basis(item)
	if _kind(item) == "bois":
		# Debout dans la main (le long de y), pas couché comme au sol.
		var thick := size_of(item)
		var length := float(item.get("longueur", 1.0))
		shape = Basis.from_scale(Vector3(thick, length, thick))
		# Torche allumée : sa flamme au bout (à sa vraie taille malgré l'échelle du bâton).
		if Fire.is_torch(item) and Fire.is_lit(item):
			var flame := MeshInstance3D.new()
			flame.name = "Flamme"
			flame.mesh = Fire.torch_flame_mesh()
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var size := 0.45 if item.objet == "torche_forte" else 0.35
			flame.scale = Vector3(size / thick, size / length, size / thick)
			flame.position = Vector3(0.0, 0.5, 0.0)
			made.add_child(flame)
	made.transform = Transform3D(shape, Vector3.ZERO)
	return made

func _mesh(value: Dictionary) -> Mesh:
	if _kind(value) == "fibre":
		return Fibers.bundle_mesh()
	if _kind(value) == "liane":
		return Fibers.coil_mesh()
	if _kind(value) in ["outil_brut", "outil_pierre"]:
		return ToolModels.mesh(value)
	if _kind(value) == "ficelle":
		return Fibers.cord_mesh()
	if _kind(value) == "tete":
		return StoneHeads.mesh("hache" if value.get("objet") == "tete_hache" else "pioche", 1.0)
	# 0.0.8.44 : feu de camp (éteint ou allumé).
	if _kind(value) == "feu":
		return Fire.campfire_mesh(Fire.is_lit(value))
	if _kind(value) == "orbe":
		return ReturnOrb.mesh()
	# 0.0.8.21 (#207) : sac en filet posé à plat (modèle fait dans Blender).
	if _kind(value) == "sac":
		return NetBag.mesh()
	# 0.0.8.15 (#239) : plante arrachée : la plante du monde, petite (PLANT_SIZE) ; motte de gazon.
	if _kind(value) == "plante":
		return Plants.mesh(int(Inventory.ITEMS.get(value.get("objet", ""), {}).get("plante", 0)))
	if _kind(value) == "gazon":
		return turf_mesh()
	if _kind(value) == "feuilles":
		return leaf_pile_mesh(clampi(int(value.get("essence", 0)), 0, 3), leaf_pile_step(value))
	if _kind(value) == "fruit":
		return Trees._fruit_mesh(Trees.APPLE if value.get("objet") == "pomme" else Trees.HAZEL, _two_tone(value))
	# 0.0.8.53 : torche et archet : leur modèle (fait dans Blender, fire.gd).
	if _kind(value) == "bois" and Fire.wood_model(value) != null:
		return Fire.wood_model(value)
	if _kind(value) == "bois":
		var step := taper_step(value)
		if not _sticks.has(step):
			var stick := CylinderMesh.new()
			stick.top_radius = 0.5 * step / 20.0
			stick.bottom_radius = 0.5
			stick.height = 1.0
			stick.radial_segments = 10
			stick.rings = 1
			_sticks[step] = stick
		return _sticks[step]
	return Rocks.pebble_mesh(clampi(int(value.get("forme", 1)), 1, 7))

# 0.0.7.12 : petit feuillage d'un rameau : quelques feuilles en croix sur la moitié fine du bâton (un seul modèle,
# repère du bâton : y le long du bâton de 0 à 1, x et z en travers ; mis à la taille de chaque rameau par leaf_basis).
static var _tuft: ArrayMesh

static func leaf_tuft() -> ArrayMesh:
	if _tuft != null:
		return _tuft
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 712
	for leaf in range(14):
		var y := rng.randf_range(0.1, 0.48)
		# Vers les côtés et vers le haut seulement (bâton couché : -z du modèle est le haut), pas dans le sol.
		var angle := rng.randf_range(0.0, PI)
		var out := Vector3(cos(angle), 0.0, -sin(angle))
		var size := rng.randf_range(0.09, 0.16)
		var base := Vector3(0.0, y, 0.0) + out * 0.02
		var tip := base + (out * 0.9 + Vector3(0.0, 0.35, 0.0)).normalized() * size * 2.0
		var side := out.cross(Vector3.UP).normalized() * size * 0.55
		var corners := [base - side, base + side, tip + side, tip - side]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for index in [0, 1, 2, 0, 2, 3]:
			points.append(corners[index])
			normals.append((out + Vector3.UP * 0.5).normalized())
			uvs.append(uv[index])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	_tuft = ArrayMesh.new()
	_tuft.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _tuft

# 0.0.8.23 (demandes de l'utilisateur : « elles restent de la même taille », tas de 20 feuilles) : tas de feuilles : les
# plaques du feuillage de son arbre (la même image, à la même taille que sur l'arbre : Trees.leaf_plate), une par
# feuille, couchées en petit dôme, un peu penchées et tournées au hasard. LEAF_PILE_STEPS grandeurs (5, 10, 15 et 20
# plaques) : un modèle par essence et grandeur, fait une fois ; tous les tas semblables dessinés ensemble.
const LEAF_PILE_STEPS := 4
static var _leaf_piles: Dictionary = {}

static func leaf_pile_step(value: Dictionary) -> int:
	var count := clampi(int(value.get("tas", 1)), 1, Inventory.LEAF_PILE)
	return clampi(ceili(float(count) * LEAF_PILE_STEPS / Inventory.LEAF_PILE), 1, LEAF_PILE_STEPS)

# Rayon où sont posés les centres des plaques d'un tas (m).
static func leaf_pile_radius(value: Dictionary) -> float:
	return _pile_radius(clampi(int(value.get("essence", 0)), 0, 3), leaf_pile_step(value))

static func _pile_radius(essence: int, step: int) -> float:
	return Trees.leaf_plate(essence) * (0.2 + 0.25 * float(step) / LEAF_PILE_STEPS)

static func leaf_pile_mesh(essence: int, step: int) -> ArrayMesh:
	var key := "%d/%d" % [essence, step]
	if _leaf_piles.has(key):
		return _leaf_piles[key]
	var plate := Trees.leaf_plate(essence)
	var half := plate * 0.5
	var radius := _pile_radius(essence, step)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7351 + essence * 31 + step
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var corner_uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for leaf in range(step * Inventory.LEAF_PILE / LEAF_PILE_STEPS):
		var angle := rng.randf() * TAU
		var distance := sqrt(rng.randf()) * radius
		var turn := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.22, 0.22)) * Basis(Vector3.BACK, rng.randf_range(-0.22, 0.22))
		var corners := [turn * Vector3(-half, 0.0, -half), turn * Vector3(half, 0.0, -half), turn * Vector3(half, 0.0, half), turn * Vector3(-half, 0.0, half)]
		var lowest := INF
		for corner: Vector3 in corners:
			lowest = minf(lowest, corner.y)
		# Le coin le plus bas juste sur le sol ; plus haut au centre (dôme), chaque plaque un peu au-dessus de la précédente.
		var center := Vector3(cos(angle) * distance, -lowest + 0.004 + (1.0 - distance / maxf(radius, 0.001)) * plate * 0.1 + leaf * 0.0015, sin(angle) * distance)
		var normal: Vector3 = (turn * Vector3.UP).normalized()
		for corner in [0, 1, 2, 0, 2, 3]:
			points.append(center + corners[corner])
			normals.append(normal)
			uvs.append(corner_uvs[corner])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_leaf_piles[key] = made
	return made

# Couché comme son bâton (le bout fin vers +y du modèle), à sa longueur ; feuilles à la taille d'un vrai rameau.
static func leaf_basis(value: Dictionary) -> Basis:
	var length := float(value.get("longueur", 0.5))
	var across := clampf(length * 0.6, 0.25, 0.9)
	var turn := Basis(Vector3.UP, float(value.get("rotation", 0.0)))
	return turn * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(across, length, across))

# Aspect des pierres (0 pierre, 1 calcaire, 2 silex) ou -1 : couleur unie.
static func _look(value: Dictionary) -> int:
	return int(Inventory.ITEMS.get(value.get("objet", ""), {}).get("aspect", -1))

func _color(value: Dictionary) -> Color:
	if value.get("objet") == "pomme":
		return Inventory.APPLE_COLORS[clampi(int(value.get("couleur", 1)), 0, Inventory.APPLE_COLORS.size() - 1)]
	return Inventory.ITEMS.get(value.get("objet", ""), {}).get("couleur", Color.GRAY)

# Fruit qui tombe (un instant) : couleur unie, le modèle partagé n'ayant pas la couleur de chaque pomme.
func _fall_material(value: Dictionary) -> Material:
	var key := "chute/%s/%d" % [value.get("objet", ""), int(value.get("couleur", -1))]
	if not _materials.has(key):
		var made := StandardMaterial3D.new()
		made.albedo_color = _color(value)
		made.roughness = 0.5
		_materials[key] = made
	return _materials[key]

func _plain_material(value: Dictionary) -> Material:
	if _look(value) >= 0 and stone_material != null:
		return stone_material
	# 0.0.8.6 : liane (tige et feuilles) et outils (manche, tête, lien) : les matières de leur modèle.
	if _kind(value) in ["liane", "outil_brut", "outil_pierre"]:
		return null
	# 0.0.8.5 : tête taillée : la pierre (calcaire clair, silex sombre).
	if _kind(value) == "tete":
		return StoneHeads.material(int(value.get("pierre", 1)))
	# 0.0.8.2 : orbe de retour : les matières de son modèle (boule lumineuse, anneau doré).
	if _kind(value) == "orbe":
		return null
	# 0.0.8.15 : plante (image du monde) et motte (terre, herbe) : les matières de leur modèle ; 0.0.8.21 : sac aussi.
	if _kind(value) in ["plante", "gazon", "sac", "feu"]:
		return null
	# Fruits : le matériau de leur modèle (celui des arbres), couleur de chaque pomme dans ses données.
	if _kind(value) == "fruit":
		return null
	# Bois : l'écorce de son essence (comme les arbres) ; 0.0.8.53 : torche et archet : les matières de leur modèle.
	if _kind(value) == "bois" and Fire.wood_model(value) != null:
		return null
	if _kind(value) == "bois":
		return Trees.material(clampi(int(value.get("essence", 0)), 0, 3), "bark")
	# 0.0.8.23 : tas de feuilles : le feuillage de son arbre (même image).
	if _kind(value) == "feuilles":
		return Trees.material(clampi(int(value.get("essence", 0)), 0, 3), "leaves")
	var key := "%s/%d" % [value.get("objet", ""), int(value.get("couleur", -1))]
	if not _materials.has(key):
		var made := StandardMaterial3D.new()
		made.albedo_color = _color(value)
		made.roughness = 0.5 if _kind(value) == "fruit" else 0.92
		# 0.0.8.4 : brins de fibres plats : visibles des deux côtés.
		if _kind(value) == "fibre":
			made.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = made
	return _materials[key]


# 0.0.8.9 (bug signalé par l'utilisateur) : un objet posé sur une pente se couche sur elle (et non plus à plat, à moitié
# dans le sol). Pente calculée une fois par objet (gardée pendant la partie, pas enregistrée).
func _slope(entry: Dictionary) -> Vector3:
	if not entry.has("normal"):
		entry.normal = Vector3.UP
		if normal_at.is_valid():
			var ground := Vector3(entry.position.x, entry.position.y - lift(entry.item), entry.position.z)
			var normal: Vector3 = normal_at.call(ground)
			entry.normal = normal if normal.y > 0.3 else Vector3.UP
	return entry.normal

# 0.0.8.31 (demande de l'utilisateur : le bois posé jamais dans le sol ni en l'air ; mesuré sur 500 bois : un bout en
# l'air de plus de 5 cm pour 87, jusqu'à 69 cm, un bout dans le sol pour 68, jusqu'à 66 cm : un bâton droit était posé
# par son centre seulement, penché selon la pente à cet endroit) : un bois est rigide et repose sur ses appuis. Le sol est
# mesuré sous lui tout du long (3 points sous 1 m, 5 sous 3 m, 9 au-delà), à son rayon (gros bout, petit bout) ; il se
# pose sur la ligne la plus basse qui reste au-dessus partout (elle passe par deux appuis), penché le long de son axe
# seulement. Calculé une fois par bois (gardé pendant la partie, pas enregistré) ; refait si le sol change dessous.
var ground_at := Callable()
const WOOD_MAX_SLOPE := 1.5

# Vector2(hauteur de l'axe au milieu, pente le long de l'axe vers le bout fin).
func _wood_pose(entry: Dictionary) -> Vector2:
	if entry.has("pose"):
		return entry.pose
	var item: Dictionary = entry.item
	var length := float(item.get("longueur", 1.0))
	var big := float(item.get("epaisseur", 3.0)) / 200.0
	var small := float(item.get("fin", item.get("epaisseur", 3.0))) / 200.0
	var turn := float(item.get("rotation", 0.0))
	var axis := Vector3(sin(turn), 0.0, cos(turn))
	var center: Vector3 = entry.position
	var count := 3 if length < 1.0 else (5 if length < 3.0 else 9)
	var points := PackedVector2Array()
	for index in range(count):
		var share := float(index) / (count - 1)
		var spot := center + axis * ((share - 0.5) * length)
		# 0.0.8.51 : mesuré depuis la hauteur où ce bout peut être (pente la plus forte), pas plus haut (sous terre : le
		# sol du dessus).
		var reach := absf(share - 0.5) * length * WOOD_MAX_SLOPE
		var ground: float = ground_at.call(Vector3(spot.x, center.y + reach, spot.z))
		points.append(Vector2((share - 0.5) * length, ground + lerpf(big, small, share)))
	var best := Vector2(INF, 0.0)
	for first in range(count):
		for second in range(first, count):
			var slope := 0.0 if second == first else clampf((points[second].y - points[first].y) / (points[second].x - points[first].x), -WOOD_MAX_SLOPE, WOOD_MAX_SLOPE)
			# La ligne de cette pente posée sur le point le plus haut : sa hauteur au milieu.
			var height := -INF
			for point in points:
				height = maxf(height, point.y - slope * point.x)
			if height < best.x - 0.0005:
				best = Vector2(height, slope)
	entry.pose = best
	return best

# Place d'un objet : couché sur la pente, son centre à « lift » au-dessus du sol, le long de la pente.
func place_of(entry: Dictionary, basis: Basis) -> Transform3D:
	if _kind(entry.item) == "bois" and ground_at.is_valid():
		var pose := _wood_pose(entry)
		var turn := float(entry.item.get("rotation", 0.0))
		var along := Vector3(sin(turn), 0.0, cos(turn))
		return Transform3D(Basis(along.cross(Vector3.UP).normalized(), atan(pose.y)) * basis, Vector3(entry.position.x, pose.x, entry.position.z))
	var normal := _slope(entry)
	var lifted := lift(entry.item)
	var ground := Vector3(entry.position.x, entry.position.y - lifted, entry.position.z)
	var tilt := Basis()
	if normal.dot(Vector3.UP) < 0.9999:
		var axis := Vector3.UP.cross(normal).normalized()
		tilt = Basis(axis, Vector3.UP.angle_to(normal))
	return Transform3D(tilt * basis, ground + normal * lifted)
func _add_body(index: int) -> void:
	var entry: Dictionary = entries[index]
	var body := StaticBody3D.new()
	body.name = "Objet"
	body.add_to_group("ground_items")
	body.set_meta("ground_index", index)
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	if _kind(entry.item) == "bois":
		# Bâton : une boîte sur toute sa longueur (facile à viser).
		var stick := BoxShape3D.new()
		var thick := maxf(size_of(entry.item), AIM_RADIUS * 1.5)
		stick.size = Vector3(thick, thick, float(entry.item.get("longueur", 1.0)))
		shape.shape = stick
		body.rotation.y = float(entry.item.get("rotation", 0.0))
	elif _kind(entry.item) in ["outil_brut", "outil_pierre"]:
		# 0.0.8.9 (bug signalé par l'utilisateur : on prenait autre chose que ce qu'on visait) : outil : une boîte le long
		# de son manche (avant : une boule d'un mètre).
		var tool := BoxShape3D.new()
		var length := float(entry.item.get("longueur", 0.6))
		tool.size = Vector3(0.12, 0.08, length)
		shape.shape = tool
		shape.position = Vector3(0.0, 0.0, length * 0.5)
		body.rotation.y = float(entry.item.get("rotation", 0.0))
	elif _kind(entry.item) in ["plante", "gazon"]:
		# 0.0.8.15 : plante debout (PLANT_SIZE), motte plate : leur vraie taille.
		var box := BoxShape3D.new()
		box.size = Vector3(0.22, PLANT_SIZE, 0.22) if _kind(entry.item) == "plante" else Vector3(TURF_RADIUS * 2.0, TURF_HEIGHT + 0.02, TURF_RADIUS * 2.0)
		shape.shape = box
		shape.position = Vector3(0.0, PLANT_SIZE * 0.5, 0.0) if _kind(entry.item) == "plante" else Vector3.ZERO
	elif _kind(entry.item) == "feu":
		# 0.0.8.44 : feu de camp : une boîte basse de sa largeur.
		var ring := BoxShape3D.new()
		ring.size = Vector3(0.8, 0.3, 0.8)
		shape.shape = ring
		shape.position = Vector3(0.0, 0.15, 0.0)
	elif _kind(entry.item) == "feuilles":
		# 0.0.8.23 : tas de feuilles : une boîte basse de sa largeur.
		var heap := BoxShape3D.new()
		var wide := leaf_pile_radius(entry.item) * 2.0 + Trees.leaf_plate(clampi(int(entry.item.get("essence", 0)), 0, 3)) * 0.3
		heap.size = Vector3(wide, 0.1, wide)
		shape.shape = heap
		shape.position = Vector3(0.0, 0.05, 0.0)
	elif _kind(entry.item) == "sac":
		# 0.0.8.21 : sac à plat, environ 35 × 30 cm.
		var lying := BoxShape3D.new()
		lying.size = Vector3(0.36, 0.08, 0.3)
		shape.shape = lying
		shape.position = Vector3(0.0, 0.04, 0.0)
		body.rotation.y = float(entry.item.get("rotation", 0.0))
	elif _kind(entry.item) in ["fibre", "liane", "ficelle"]:
		# 0.0.8.9 : fibres, herbe arrachée (botte de 25 cm), liane (boucles de 55 cm), ficelle (rouleau de 9 cm) : leur
		# vraie taille (avant : une boule d'un mètre qui prenait la place des objets voisins).
		var flat := BoxShape3D.new()
		match _kind(entry.item):
			"fibre":
				flat.size = Vector3(0.26, 0.06, 0.08)
			"liane":
				flat.size = Vector3(0.55, 0.06, 0.55)
			_:
				flat.size = Vector3(0.12, 0.05, 0.12)
		shape.shape = flat
		body.rotation.y = float(entry.item.get("rotation", 0.0))
	else:
		var sphere := SphereShape3D.new()
		sphere.radius = maxf(size_of(entry.item) * 0.5, AIM_RADIUS)
		shape.shape = sphere
	body.add_child(shape)
	# 0.0.8.9 : couché sur la pente comme l'objet dessiné.
	body.transform = place_of(entry, body.transform.basis)
	add_child(body)
	bodies.append(body)

func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_redraw()

# Un dessin par type, forme et couleur : tous les objets semblables ensemble ; l'aspect des pierres par objet.
func _redraw() -> void:
	var groups := {}
	for entry: Dictionary in entries:
		if entry.get("hidden", false):
			continue
		var item: Dictionary = entry.item
		var stone := _look(item) >= 0 and stone_material != null
		var key: String = "pierre/%d" % int(item.get("forme", 1)) if stone else "%s/%d/%d/%d" % [item.objet, int(item.get("forme", 1)), int(item.get("couleur", -1)), int(item.get("essence", -1))]
		if _kind(item) in ["outil_brut", "outil_pierre"]:
			key = "outil/" + ToolModels.key_of(item)
		if _kind(item) == "tete":
			key += "/p%d" % int(item.get("pierre", 1))
		if _kind(item) == "bois":
			# 0.0.8.22 : un bois est toujours un cylindre (sa « forme » ne change rien au dessin) : groupé par objet, essence
			# et pointe seulement (bien moins de séries : un arbre coupé donne maintenant un bois par pièce).
			key = "bois/%s/%d/%d" % [item.objet, int(item.get("essence", -1)), taper_step(item)]
		# 0.0.8.23 : tas de feuilles : par essence et grandeur (tous les tas semblables en un seul dessin).
		if _kind(item) == "feu":
			key = "feu/%d" % int(Fire.is_lit(item))
		if _kind(item) == "feuilles":
			key = "tas/%d/%d" % [int(item.get("essence", 0)), leaf_pile_step(item)]
		if not groups.has(key):
			groups[key] = {"item": item, "stone": stone, "list": []}
		groups[key].list.append(entry)
		# 0.0.7.12 : rameau : son petit feuillage (le même pour tous, aux feuilles de son essence).
		if Inventory.ITEMS.get(item.objet, {}).get("feuilles", false):
			var leaves_key := "feuilles/%d" % int(item.get("essence", 0))
			if not groups.has(leaves_key):
				groups[leaves_key] = {"item": item, "stone": false, "leaves": true, "list": []}
			groups[leaves_key].list.append(entry)
	for key in _drawn.keys():
		if not groups.has(key):
			_drawn[key].queue_free()
			_drawn.erase(key)
	for key in groups:
		var group: Dictionary = groups[key]
		var drawn: MultiMeshInstance3D = _drawn.get(key)
		if drawn == null:
			drawn = MultiMeshInstance3D.new()
			drawn.name = "Objets"
			drawn.multimesh = MultiMesh.new()
			drawn.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			# Pierres : comme les cailloux du monde, couleur blanche et aspect dans les données de chaque objet.
			drawn.multimesh.use_colors = group.stone or _kind(group.item) == "fruit"
			drawn.multimesh.use_custom_data = group.stone
			drawn.multimesh.mesh = leaf_tuft() if group.get("leaves", false) else _mesh(group.item)
			drawn.material_override = Trees.material(clampi(int(group.item.get("essence", 0)), 0, 3), "leaves") if group.get("leaves", false) else _plain_material(group.item)
			# 0.0.8.11 (rapport Web : les ombres coûtaient 17 ms de GPU) : les petits objets au sol ne projettent plus d'ombre
			# (seuls arbres, rochers et personnages).
			drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(drawn)
			_drawn[key] = drawn
		var multi := drawn.multimesh
		multi.instance_count = group.list.size()
		for at in range(group.list.size()):
			var entry: Dictionary = group.list[at]
			if group.get("leaves", false):
				multi.set_instance_transform(at, place_of(entry, leaf_basis(entry.item)))
				continue
			multi.set_instance_transform(at, place_of(entry, _basis(entry.item)))
			if group.stone:
				multi.set_instance_color(at, Color.WHITE)
				multi.set_instance_custom_data(at, Color(float(_look(entry.item)), 0.0, 0.0, 0.0))
			elif _kind(entry.item) == "fruit":
				multi.set_instance_color(at, Color.WHITE if _two_tone(entry.item) or entry.item.objet != "pomme" else _color(entry.item))
	_update_orb_lights()
	_update_glows()
	_update_bag_contents()

# 0.0.8.3 (demande de l'utilisateur) : chaque orbe de retour posée luit et éclaire un peu autour d'elle (au plus
# MAX_ORB_LIGHTS, pour rester léger).
const MAX_ORB_LIGHTS := 16
var _orb_lights: Array = []

# 0.0.8.54 (lot C1, demande de l'utilisateur) : un sac posé plein : ce qu'il contient se voit à travers les mailles
# (une petite copie par case, 4 au plus, couchées dans le sac). Refait avec les objets au sol.
const BAG_GROUND_SPOTS := [Vector3(-0.07, 0.035, 0.02), Vector3(0.0, 0.04, -0.03), Vector3(0.07, 0.035, 0.015), Vector3(0.03, 0.06, 0.04)]
var _bag_contents: Array = []

func _update_bag_contents() -> void:
	for node in _bag_contents:
		if is_instance_valid(node):
			node.queue_free()
	_bag_contents.clear()
	for entry: Dictionary in entries:
		if entry.get("hidden", false) or not Inventory.is_bag(entry.item) or not entry.item.has("sac_id"):
			continue
		var slots: Array = Inventory.stored_bags.get(int(entry.item.sac_id), [])
		var holder := Node3D.new()
		holder.name = "ContenuSac"
		holder.transform = place_of(entry, _basis(entry.item).orthonormalized())
		var placed := 0
		for value: Dictionary in slots:
			if value.is_empty() or placed >= BAG_GROUND_SPOTS.size():
				continue
			var wood: bool = Inventory.ITEMS.get(value.get("objet", ""), {}).get("forme", "") == "bois"
			var shown: Dictionary = value
			if wood and value.has("pile"):
				shown = value.duplicate(true)
				shown.pile[-1].longueur = minf(float(shown.pile[-1].get("longueur", 0.3)), 0.3)
			var item := held_model(shown)
			if item == null:
				continue
			if wood:
				item.transform.basis = Basis(Vector3.RIGHT, PI * 0.5) * item.transform.basis
			item.position = BAG_GROUND_SPOTS[placed]
			item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(item)
			placed += 1
		if placed == 0:
			holder.free()
			continue
		add_child(holder)
		_bag_contents.append(holder)

func _update_orb_lights() -> void:
	var spots: Array = []
	for entry: Dictionary in entries:
		if not entry.get("hidden", false) and ReturnOrb.is_orb(entry.item) and spots.size() < MAX_ORB_LIGHTS:
			spots.append(entry.position)
	while _orb_lights.size() > spots.size():
		_orb_lights.pop_back().queue_free()
	while _orb_lights.size() < spots.size():
		var made := ReturnOrb.light()
		add_child(made)
		_orb_lights.append(made)
	for index in range(spots.size()):
		_orb_lights[index].position = spots[index] + Vector3.UP * 0.2

# --- Sauvegarde (objets.json) ---

func to_array() -> Array:
	# 0.0.7.26 : sans les objets de la graine pas encore touchés (refaits avec leur colonne).
	return entries.filter(func(entry): return not entry.item.has("graine")).map(func(entry): return {"objet": Inventory._saved(entry.item), "position": [entry.position.x, entry.position.y, entry.position.z]})

# Format de 0.0.7.3 et 0.0.7.4 compris (forme et orientation à part : elles rejoignent l'objet).
func from_array(data: Variant) -> void:
	entries.clear()
	_pile_count = 0
	for body in bodies:
		if is_instance_valid(body):
			body.queue_free()
	bodies.clear()
	if not data is Array:
		return
	for saved in data:
		if not saved is Dictionary or not saved.get("position") is Array or saved.position.size() != 3:
			continue
		var value := Inventory._read(saved.get("objet"))
		if value.is_empty():
			continue
		value.erase("nombre")
		if Inventory.is_object(value):
			if not value.has("forme"):
				value.forme = clampi(int(saved.get("forme", 1)), 1, 7)
			if not value.has("rotation"):
				value.rotation = float(saved.get("rotation", 0.0))
		var at: Array = saved.position
		if not at.all(func(v): return v is float or v is int):
			continue
		entries.append({"item": value, "position": Vector3(float(at[0]), float(at[1]), float(at[2]))})
		_add_body(entries.size() - 1)
		if _kind(value) == "feuilles":
			_pile_count += 1
		if entries.size() >= MAX_ITEMS + MAX_LEAF_PILES:
			break
	_dirty = true

# --- 0.0.8.44 : feux de camp et torches posés (fire.gd) ---
const Fire = preload("res://scripts/fire.gd")
var _glows: Array = []
# 0.0.8.51 (lot Ombres) : nombre de feux et torches posés (les plus proches) dont la lumière fait des ombres (réglage
# Ombres de Vidéo, world.gd set_shadows) ; revu chaque seconde (le joueur bouge : les plus proches changent).
var shadow_lights := 0

func set_shadow_lights(count: int) -> void:
	shadow_lights = count
	_update_glows()

func refresh_glows() -> void:
	if not _glows.is_empty():
		_update_glows()

# Change un objet posé (feu allumé, nourri…) : redessiné, enregistré.
func set_item(index: int, value: Dictionary) -> void:
	if index < 0 or index >= entries.size():
		return
	entries[index].item = value
	_dirty = true
	changed.emit()

# Les feux et les torches allumés posés brûlent « minutes » de jeu de plus. Vrai si l'un a changé d'état.
func burn_all(minutes: float) -> bool:
	var changed_state := false
	for index in range(entries.size()):
		var item: Dictionary = entries[index].item
		if not Fire.is_lit(item):
			continue
		var burnt := Fire.burn(item, minutes)
		entries[index].item = burnt
		if Fire.is_lit(burnt) != true or burnt.get("objet") != item.get("objet"):
			changed_state = true
	if changed_state:
		_dirty = true
		changed.emit()
	return changed_state

# Lumière (et flamme d'une torche) des feux et torches allumés posés : les MAX_LIGHTS plus proches de la caméra.
func _update_glows() -> void:
	var lit: Array = []
	for entry: Dictionary in entries:
		if not entry.get("hidden", false) and Fire.is_lit(entry.item):
			lit.append(entry)
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	# 0.0.8.51 : toujours du plus proche au plus loin (les shadow_lights plus proches font des ombres).
	if camera != null and lit.size() > 1:
		var eye := camera.global_position
		lit.sort_custom(func(a, b): return eye.distance_squared_to(a.position) < eye.distance_squared_to(b.position))
	if lit.size() > Fire.MAX_LIGHTS:
		lit = lit.slice(0, Fire.MAX_LIGHTS)
	while _glows.size() > lit.size():
		var gone: Array = _glows.pop_back()
		for node in gone:
			node.queue_free()
	while _glows.size() < lit.size():
		var light := Fire.make_light({"objet": "feu_camp"})
		add_child(light)
		var flame := MeshInstance3D.new()
		flame.mesh = Fire.torch_flame_mesh()
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame)
		_glows.append([light, flame])
	for index in range(lit.size()):
		var entry: Dictionary = lit[index]
		var light: OmniLight3D = _glows[index][0]
		var flame: MeshInstance3D = _glows[index][1]
		var spec := Fire.light_spec(entry.item)
		light.omni_range = spec.x
		light.light_energy = spec.y
		Fire.set_shadow(light, index < shadow_lights)
		if Fire.is_fire(entry.item):
			light.position = entry.position + Vector3.UP * 0.5
			flame.visible = false
		else:
			# Torche posée : la flamme et la lumière au bout du bâton.
			var place := place_of(entry, _basis(entry.item))
			var tip: Vector3 = place.origin + place.basis.y * 0.5
			light.position = tip + Vector3.UP * 0.15
			flame.position = tip
			flame.visible = true
