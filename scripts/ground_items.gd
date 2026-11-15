extends Node3D
# 0.0.7.3 : objets posés au sol (morceaux de pierre cassée, cailloux, poignées qui ne tiennent plus dans les mains).
# Décision du 15.11.2026 (issue #40) : chaque objet reste visible tel quel, à sa place (pas de tas fusionnés) ;
# les objets du même type sont dessinés ensemble (un MultiMesh par type), ce qui reste léger même avec beaucoup d'objets.
# Petits modèles (quelques centimètres). Chaque objet a une petite collision ronde pour le viser (R : ramasser) ;
# elle n'arrête pas le joueur. Sauvegarde : objets.json, « objets_au_sol ».
const Inventory = preload("res://scripts/inventory.gd")
const Rocks = preload("res://scripts/rocks.gd")
# Au-delà, les plus anciens disparaissent (seulement s'ils sont très nombreux).
const MAX_ITEMS := 3000
const FALL_SECONDS := 0.35
# Taille d'un éclat et d'une poignée, en mètres (les cailloux gardent leur taille).
const PIECE_SIZE := 0.07
const HANDFUL_SIZE := 0.08
const AIM_RADIUS := 0.09

signal changed

# {"item": objet (une seule unité), "position": Vector3, "rotation": float, "shape": forme 1 à 7}
var entries: Array = []
var bodies: Array = []
var _drawn: Dictionary = {}
var _materials: Dictionary = {}
var _dirty := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	name = "GroundItems"
	rng.randomize()

# Ajoute un objet tombé de « from » jusqu'au sol, près de « near » ; rend son numéro.
# spread : écart au hasard autour de « near » (0 : exactement là, objet posé à la main).
func drop(value: Dictionary, from: Vector3, near: Vector3, rest_height: Callable, spread: float = 0.25) -> int:
	var single := value.duplicate()
	single.erase("nombre")
	var spot := near + Vector3(rng.randf_range(-spread, spread), 0.0, rng.randf_range(-spread, spread))
	var ground: float = rest_height.call(spot)
	var entry := {"item": single, "position": Vector3(spot.x, ground + _lift(single), spot.z), "rotation": rng.randf_range(0.0, TAU), "shape": rng.randi_range(1, 7)}
	entries.append(entry)
	while entries.size() > MAX_ITEMS:
		remove(0)
	var index := entries.size() - 1
	_add_body(index)
	_dirty = true
	changed.emit()
	# Chute courte et visible : le petit corps glisse du point cassé jusqu'au sol.
	if is_inside_tree() and from.distance_to(entry.position) > 0.05:
		var falling := MeshInstance3D.new()
		falling.mesh = _mesh(single, entry.shape)
		falling.material_override = _material(single)
		falling.scale = Vector3.ONE * _size(single)
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

static func _size(value: Dictionary) -> float:
	if value.has("taille"):
		return Rocks.PEBBLE_SIZES[clampi(int(value.taille), 1, 7) - 1]
	return PIECE_SIZE if Inventory.ITEMS.get(value.get("objet", ""), {}).get("forme", "") == "eclat" else HANDFUL_SIZE

static func _lift(value: Dictionary) -> float:
	return _size(value) * 0.3

func _mesh(value: Dictionary, shape: int) -> Mesh:
	return Rocks.pebble_mesh(shape if value.has("taille") or Inventory.ITEMS.get(value.get("objet", ""), {}).get("forme", "") == "eclat" else 1)

func _material(value: Dictionary) -> StandardMaterial3D:
	var id: String = value.get("objet", "")
	if not _materials.has(id):
		var made := StandardMaterial3D.new()
		made.albedo_color = Inventory.ITEMS.get(id, {}).get("couleur", Color.GRAY)
		made.roughness = 0.92
		_materials[id] = made
	return _materials[id]

func _add_body(index: int) -> void:
	var entry: Dictionary = entries[index]
	var body := StaticBody3D.new()
	body.name = "Objet"
	body.add_to_group("ground_items")
	body.set_meta("ground_index", index)
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(_size(entry.item) * 0.5, AIM_RADIUS)
	shape.shape = sphere
	body.add_child(shape)
	body.position = entry.position
	add_child(body)
	bodies.append(body)

func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_redraw()

# Un dessin par objet et par forme : tous les objets du même type ensemble.
func _redraw() -> void:
	var groups := {}
	for entry: Dictionary in entries:
		if entry.get("hidden", false):
			continue
		var key: String = "%s/%d" % [entry.item.objet, entry.shape]
		if not groups.has(key):
			groups[key] = {"item": entry.item, "shape": entry.shape, "list": []}
		groups[key].list.append(entry)
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
			drawn.multimesh.mesh = _mesh(group.item, group.shape)
			drawn.material_override = _material(group.item)
			add_child(drawn)
			_drawn[key] = drawn
		var multi := drawn.multimesh
		multi.instance_count = group.list.size()
		for at in range(group.list.size()):
			var entry: Dictionary = group.list[at]
			var basis := Basis(Vector3.UP, entry.rotation).scaled(Vector3.ONE * _size(entry.item))
			multi.set_instance_transform(at, Transform3D(basis, entry.position))

# --- Sauvegarde (objets.json) ---

func to_array() -> Array:
	return entries.map(func(entry): return {"objet": Inventory._saved(entry.item), "position": [entry.position.x, entry.position.y, entry.position.z], "rotation": entry.rotation, "forme": entry.shape})

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
		var at: Array = saved.position
		if not at.all(func(v): return v is float or v is int):
			continue
		entries.append({"item": value, "position": Vector3(float(at[0]), float(at[1]), float(at[2])), "rotation": float(saved.get("rotation", 0.0)), "shape": clampi(int(saved.get("forme", 1)), 1, 7)})
		_add_body(entries.size() - 1)
		if entries.size() >= MAX_ITEMS:
			break
	_dirty = true
