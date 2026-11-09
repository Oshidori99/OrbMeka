extends RefCounted
# 0.0.6.9 (#149, #138) : premiers arbres fruitiers, pommier et noisetier. Pas de récolte ni de coupe (série 0.0.6).
# 0.0.6.10 : modèles faits dans Blender (sources_blender/arbres : generer_arbres.py pour les modèles détaillés,
# version_jeu.py pour cette version légère). De près (jusqu'à DETAIL_END) : branches à peu de facettes, feuillage en
# plaques croisées avec une image de grappe de feuilles (bords découpés, sans transparence coûteuse), pommes et noisettes
# simples ; au loin (jusqu'à FAR_END) : tronc, grosses branches et quelques grandes plaques ; ensuite rien.
# 0.0.6.11 : cinq tailles par espèce (1 petit, 2 plutôt petit, 3 standard, 4 plutôt grand, 5 grand), chacune son propre
# modèle (proportions naturelles : un grand arbre a un tronc plus épais et plus de branches, pas le même arbre agrandi).
# Pommier : 4,0 / 5,5 / 7,5 / 8,4 / 9,6 m ; noisetier : 3,0 / 4,3 / 5,8 / 6,5 / 7,5 m.
const APPLE := 0
const HAZEL := 1
const KIND_NAMES := ["pommier", "noisetier"]
const SIZES := 5
const SIZE_NAMES := ["petit", "plutôt petit", "standard", "plutôt grand", "grand"]
# Collision du tronc (pommier) ou du pied de la touffe (noisetier) par taille : [rayon, hauteur].
const APPLE_TRUNKS := [Vector2(0.12, 1.0), Vector2(0.2, 1.5), Vector2(0.3, 2.0), Vector2(0.36, 2.2), Vector2(0.41, 2.4)]
const HAZEL_TRUNKS := [Vector2(0.15, 0.8), Vector2(0.2, 1.2), Vector2(0.24, 1.6), Vector2(0.27, 1.8), Vector2(0.3, 2.0)]
# Distances d'affichage (m) : détaillé jusqu'à DETAIL_END, simplifié jusqu'à FAR_END, ensuite rien.
const DETAIL_END := 40.0
const FAR_END := 150.0
const FOLDER := "res://assets/trees/"
const FILES := ["pommier", "noisetier"]
const APPLE_RED := Color("#b5281c")
const NUT := Color("#8a5a2b")

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}

# Matériaux : écorce et feuillage (images de assets/trees), fruits (couleur unie).
static func material(kind: int, role: String) -> StandardMaterial3D:
	var key := "%d_%s" % [kind, role]
	if not _materials.has(key):
		var made := StandardMaterial3D.new()
		match role:
			"bark":
				made.albedo_texture = load(FOLDER + "ecorce_%s.png" % FILES[kind])
				# Écorce un peu éclaircie (l'image est sombre sous la lumière du jeu).
				made.albedo_color = Color(1.7, 1.55, 1.4)
				made.roughness = 0.95
			"leaves":
				made.albedo_texture = load(FOLDER + "feuilles_%s.png" % FILES[kind])
				# Teinte plus chaude : la lumière ambiante bleutée du jeu rendait le feuillage bleu-gris.
				made.albedo_color = Color(1.12, 1.18, 0.78) if kind == APPLE else Color(1.05, 1.1, 0.8)
				made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				made.alpha_scissor_threshold = 0.5
				made.cull_mode = BaseMaterial3D.CULL_DISABLED
				made.roughness = 0.85
			_:
				made.albedo_color = APPLE_RED if kind == APPLE else NUT
				made.roughness = 0.45 if kind == APPLE else 0.6
		_materials[key] = made
	return _materials[key]

# Modèle de près (far = false) ou de loin (far = true), lu une fois dans assets/trees, avec nos matériaux.
static func mesh(kind: int, size: int = 3, far := false) -> ArrayMesh:
	size = clampi(size, 1, SIZES)
	var key := "%d_%d_%s" % [kind, size, far]
	if not _meshes.has(key):
		_meshes[key] = _load(kind, size, far)
	return _meshes[key]

static func _load(kind: int, size: int, far: bool) -> ArrayMesh:
	var scene: PackedScene = load(FOLDER + "%s_%d_%s.glb" % [FILES[kind], size, "loin" if far else "jeu"])
	var root := scene.instantiate()
	var source: Mesh = (root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	root.free()
	var result := ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface)
		var name := str(source.surface_get_material(surface).resource_name) if source.surface_get_material(surface) else ""
		var role := "bark" if name.contains("Ecorce") else ("leaves" if name.contains("Feuille") else "fruit")
		if role == "leaves":
			# Feuillage éclairé comme une boule (normales vers l'extérieur de la couronne) : plus doux que des plaques à plat.
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var box := AABB(points[0], Vector3.ZERO)
			for point in points:
				box = box.expand(point)
			var center := box.get_center() - Vector3(0.0, box.size.y * 0.15, 0.0)
			var normals := PackedVector3Array()
			normals.resize(points.size())
			for index in range(points.size()):
				normals[index] = (points[index] - center).normalized().lerp(Vector3.UP, 0.3).normalized()
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TANGENT] = null
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(result.get_surface_count() - 1, material(kind, role))
	return result

# Collision simple : le tronc (pommier) ou le pied de la touffe (noisetier) : [rayon, hauteur].
static func trunk(kind: int, size: int = 3) -> Vector2:
	return (APPLE_TRUNKS if kind == APPLE else HAZEL_TRUNKS)[clampi(size, 1, SIZES) - 1]

static func triangles(made: Mesh) -> int:
	var count := 0
	for surface in range(made.get_surface_count()):
		var indices: PackedInt32Array = made.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
		count += (indices.size() if not indices.is_empty() else made.surface_get_array_len(surface)) / 3
	return count

# Arbre posé dans le monde : corps immobile (collision du tronc), modèle détaillé de près, simplifié au loin.
static func tree_body(kind: int, size: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Arbre"
	body.add_to_group("trees")
	var model := Node3D.new()
	model.name = "Modele"
	body.add_child(model)
	var near := MeshInstance3D.new()
	near.name = "Detail"
	near.mesh = mesh(kind, size)
	near.visibility_range_end = DETAIL_END
	near.visibility_range_end_margin = 2.0
	model.add_child(near)
	var far := MeshInstance3D.new()
	far.name = "Loin"
	far.mesh = mesh(kind, size, true)
	far.visibility_range_begin = DETAIL_END
	far.visibility_range_begin_margin = 2.0
	far.visibility_range_end = FAR_END
	model.add_child(far)
	var foot := trunk(kind, size)
	var shape := CylinderShape3D.new()
	shape.radius = foot.x
	shape.height = foot.y
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = foot.y / 2.0
	model.add_child(collision)
	return body
