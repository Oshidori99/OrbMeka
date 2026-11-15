extends Node3D
# 0.0.7.3 : objets posés au sol (morceaux de pierre cassée, cailloux, fruits, poignées qui ne tiennent plus en main).
# Décision du 15.11.2026 (issue #40) : chaque objet reste visible tel quel, à sa place (pas de tas fusionnés) ;
# les objets du même type sont dessinés ensemble (un MultiMesh par type et par forme), léger même avec beaucoup d'objets.
# 0.0.7.5 : chaque objet garde toutes ses caractéristiques (inventory.gd : taille, poids, forme, orientation, couleur,
# coups reçus) ; cailloux et éclats ont le même rendu que les cailloux du monde (matière des pierres, aspect pierre,
# calcaire ou silex), si bien qu'un caillou ramassé puis reposé est exactement le même.
# Chaque objet a une petite collision ronde pour le viser (R : ramasser) ; elle n'arrête pas le joueur.
# Sauvegarde : objets.json, « objets_au_sol ».
const Inventory = preload("res://scripts/inventory.gd")
const Rocks = preload("res://scripts/rocks.gd")
const Trees = preload("res://scripts/trees.gd")
# Au-delà, les plus anciens disparaissent (seulement s'ils sont très nombreux).
const MAX_ITEMS := 3000
const FALL_SECONDS := 0.35
# Taille d'un éclat et d'une poignée, en mètres (les cailloux et les fruits gardent leur taille).
const PIECE_SIZE := 0.07
const HANDFUL_SIZE := 0.08
const HAZELNUT_SIZE := 0.025
const AIM_RADIUS := 0.09

signal changed

# Matière des pierres du monde (world.gd, aspect par objet : données propres à chaque instance).
var stone_material: Material
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
	var item := value.duplicate(true)
	item.erase("nombre")
	if Inventory.is_object(item):
		if not item.has("forme"):
			item.forme = rng.randi_range(1, 7)
		if not item.has("rotation"):
			item.rotation = rng.randf_range(0.0, TAU)
	var spot := near + Vector3(rng.randf_range(-spread, spread), 0.0, rng.randf_range(-spread, spread))
	var ground: float = rest_height.call(spot)
	var entry := {"item": item, "position": Vector3(spot.x, ground + lift(item), spot.z)}
	entries.append(entry)
	while entries.size() > MAX_ITEMS:
		remove(0)
	var index := entries.size() - 1
	_add_body(index)
	_dirty = true
	changed.emit()
	# Chute courte et visible : le petit objet glisse du point cassé jusqu'au sol.
	if is_inside_tree() and from.distance_to(entry.position) > 0.05:
		var falling := MeshInstance3D.new()
		falling.mesh = _mesh(item)
		falling.material_override = _plain_material(item) if _kind(item) != "fruit" else _fall_material(item)
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

func remove(index: int) -> Dictionary:
	if index < 0 or index >= entries.size():
		return {}
	var entry: Dictionary = entries[index]
	entries.remove_at(index)
	var body: Node = bodies[index]
	bodies.remove_at(index)
	if is_instance_valid(body):
		body.queue_free()
	for at in range(index, bodies.size()):
		bodies[at].set_meta("ground_index", at)
	_dirty = true
	changed.emit()
	return entry.item

func index_of(body: Node) -> int:
	return int(body.get_meta("ground_index", -1)) if is_instance_valid(body) else -1

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
		# 0.0.7.8 : bâton ou tronc : son épaisseur (la longueur est à part).
		"bois":
			return float(value.get("epaisseur", 3.0)) / 100.0
	return HANDFUL_SIZE

# Hauteur du centre au-dessus du sol (cailloux : comme ceux du monde).
static func lift(value: Dictionary) -> float:
	if _kind(value) == "caillou":
		return Rocks.pebble_lift(clampi(int(value.get("taille", 3)), 1, 7), clampi(int(value.get("forme", 1)), 1, 7)) * (1.0 - 0.2 * int(value.get("coups", 0)))
	return size_of(value) * (0.5 if _kind(value) in ["fruit", "bois"] else 0.3)

# Fruits : le modèle des arbres (rayon 1) ; bois : cylindre couché le long de son orientation ; autres : diamètre 1.
static func _basis(value: Dictionary) -> Basis:
	var turn := Basis(Vector3.UP, float(value.get("rotation", 0.0)))
	if _kind(value) == "bois":
		var thick := size_of(value)
		return turn * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(thick, float(value.get("longueur", 1.0)), thick))
	var scale := size_of(value) * (0.5 if _kind(value) == "fruit" else 1.0)
	return turn.scaled(Vector3.ONE * scale)

# 0.0.7.9 : bois conique : gros bout (« epaisseur ») et petit bout (« fin »), par pas de 5 %.
static var _sticks: Dictionary = {}

static func taper_step(value: Dictionary) -> int:
	var thick := float(value.get("epaisseur", 3.0))
	return clampi(roundi(float(value.get("fin", thick * 0.84)) / maxf(thick, 0.01) * 20.0), 4, 20)

static func _two_tone(value: Dictionary) -> bool:
	return value.get("objet") == "pomme" and int(value.get("couleur", 1)) == 4

# 0.0.7.6 : pommes et noisettes au sol avec le même petit modèle que dans les arbres (Trees._fruit_mesh).
func _mesh(value: Dictionary) -> Mesh:
	if _kind(value) == "fruit":
		return Trees._fruit_mesh(Trees.APPLE if value.get("objet") == "pomme" else Trees.HAZEL, _two_tone(value))
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
	# Fruits : le matériau de leur modèle (celui des arbres), couleur de chaque pomme dans ses données.
	if _kind(value) == "fruit":
		return null
	# Bois : l'écorce de son essence (comme les arbres).
	if _kind(value) == "bois":
		return Trees.material(clampi(int(value.get("essence", 0)), 0, 3), "bark")
	var key := "%s/%d" % [value.get("objet", ""), int(value.get("couleur", -1))]
	if not _materials.has(key):
		var made := StandardMaterial3D.new()
		made.albedo_color = _color(value)
		made.roughness = 0.5 if _kind(value) == "fruit" else 0.92
		_materials[key] = made
	return _materials[key]

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
	else:
		var sphere := SphereShape3D.new()
		sphere.radius = maxf(size_of(entry.item) * 0.5, AIM_RADIUS)
		shape.shape = sphere
	body.add_child(shape)
	body.position = entry.position
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
		if _kind(item) == "bois":
			key += "/%d" % taper_step(item)
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
			add_child(drawn)
			_drawn[key] = drawn
		var multi := drawn.multimesh
		multi.instance_count = group.list.size()
		for at in range(group.list.size()):
			var entry: Dictionary = group.list[at]
			if group.get("leaves", false):
				multi.set_instance_transform(at, Transform3D(leaf_basis(entry.item), entry.position))
				continue
			multi.set_instance_transform(at, Transform3D(_basis(entry.item), entry.position))
			if group.stone:
				multi.set_instance_color(at, Color.WHITE)
				multi.set_instance_custom_data(at, Color(float(_look(entry.item)), 0.0, 0.0, 0.0))
			elif _kind(entry.item) == "fruit":
				multi.set_instance_color(at, Color.WHITE if _two_tone(entry.item) or entry.item.objet != "pomme" else _color(entry.item))

# --- Sauvegarde (objets.json) ---

func to_array() -> Array:
	return entries.map(func(entry): return {"objet": Inventory._saved(entry.item), "position": [entry.position.x, entry.position.y, entry.position.z]})

# Format de 0.0.7.3 et 0.0.7.4 compris (forme et orientation à part : elles rejoignent l'objet).
func from_array(data: Variant) -> void:
	entries.clear()
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
		if entries.size() >= MAX_ITEMS:
			break
	_dirty = true
