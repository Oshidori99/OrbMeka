extends RefCounted
# 0.0.6.9 (#149, #138) : premiers arbres fruitiers, pommier et noisetier. Pas de récolte ni de coupe (série 0.0.6).
# 0.0.6.10 : modèles faits dans Blender (sources_blender/arbres : generer_arbres.py pour les modèles détaillés,
# version_jeu.py pour cette version légère). De près (jusqu'à DETAIL_END) : branches à peu de facettes, feuillage en
# plaques croisées avec une image de grappe de feuilles (bords découpés, sans transparence coûteuse), pommes et noisettes
# simples ; au loin (jusqu'à FAR_END) : tronc, grosses branches et quelques grandes plaques ; ensuite rien.
# 0.0.6.11 : cinq tailles par espèce (1 petit, 2 plutôt petit, 3 standard, 4 plutôt grand, 5 grand), chacune son propre
# modèle (proportions naturelles : un grand arbre a un tronc plus épais et plus de branches, pas le même arbre agrandi).
# Pommier : 4,0 / 5,5 / 7,5 / 8,4 / 9,6 m ; noisetier : 3,0 / 4,3 / 5,8 / 6,5 / 7,5 m.
# 0.0.6.12 : pin sylvestre (7 à 21 m, tronc nu sur la moitié de sa hauteur une fois adulte, touffes d'aiguilles, pommes de pin)
# et tilleul (6 à 20 m, couronne ovale dense, feuilles en cœur).
const Plants = preload("res://scripts/plants.gd")
const APPLE := 0
const HAZEL := 1
const PINE := 2
const LINDEN := 3
const KIND_NAMES := ["pommier", "noisetier", "pin", "tilleul"]
const SIZES := 5
const SIZE_NAMES := ["petit", "plutôt petit", "standard", "plutôt grand", "grand"]
# Collision du tronc (pommier) ou du pied de la touffe (noisetier) par taille : [rayon, hauteur].
const APPLE_TRUNKS := [Vector2(0.12, 1.0), Vector2(0.2, 1.5), Vector2(0.3, 2.0), Vector2(0.36, 2.2), Vector2(0.41, 2.4)]
const HAZEL_TRUNKS := [Vector2(0.15, 0.8), Vector2(0.2, 1.2), Vector2(0.24, 1.6), Vector2(0.27, 1.8), Vector2(0.3, 2.0)]
const PINE_TRUNKS := [Vector2(0.14, 3.0), Vector2(0.22, 4.0), Vector2(0.31, 5.0), Vector2(0.37, 5.0), Vector2(0.43, 5.0)]
const LINDEN_TRUNKS := [Vector2(0.14, 1.3), Vector2(0.24, 2.0), Vector2(0.35, 2.8), Vector2(0.43, 3.3), Vector2(0.51, 3.8)]
const TRUNKS := [APPLE_TRUNKS, HAZEL_TRUNKS, PINE_TRUNKS, LINDEN_TRUNKS]
# Distances d'affichage (m) : détaillé jusqu'à DETAIL_END, simplifié jusqu'à FAR_END, ensuite rien.
const DETAIL_END := 40.0
const FAR_END := 150.0
const FOLDER := "res://assets/trees/"
const FILES := ["pommier", "noisetier", "pin", "tilleul"]
# Fruits : pommes, noisettes, pommes de pin (le tilleul n'en a pas dans le modèle).
const FRUIT_COLORS := [Color("#b5281c"), Color("#8a5a2b"), Color("#7a5532"), Color("#c9c27a")]
# Teinte du feuillage (la lumière ambiante bleutée du jeu rendait le feuillage bleu-gris).
const LEAF_TINTS := [Color(1.12, 1.18, 0.78), Color(1.05, 1.1, 0.8), Color(1.02, 1.08, 0.74), Color(1.12, 1.16, 0.74)]

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
				made.albedo_color = LEAF_TINTS[kind]
				# 0.0.6.17 : rendu Web : feuillage nettement plus clair qu'au PC (mesuré sur captures) : un peu assombri.
				if RenderingServer.get_current_rendering_method() == "gl_compatibility":
					made.albedo_color = Color(made.albedo_color.r * 0.74, made.albedo_color.g * 0.74, made.albedo_color.b * 0.74)
				made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				made.alpha_scissor_threshold = 0.5
				made.cull_mode = BaseMaterial3D.CULL_DISABLED
				made.roughness = 0.85
			_:
				made.albedo_color = FRUIT_COLORS[kind]
				made.roughness = 0.45 if kind == APPLE else 0.7
		_materials[key] = made
	return _materials[key]

# Modèle de près (far = false) ou de loin (far = true), lu une fois dans assets/trees, avec nos matériaux.
static func mesh(kind: int, size: int = 3, far := false) -> ArrayMesh:
	size = clampi(size, 1, SIZES)
	var key := "%d_%d_%s" % [kind, size, far]
	if not _meshes.has(key):
		_meshes[key] = _load(kind, size, far)
	return _meshes[key]

static func _path(kind: int, size: int, far: bool) -> String:
	return FOLDER + "%s_%d_%s.glb" % [FILES[kind], size, "loin" if far else "jeu"]

# 0.0.6.18 (#175) : modèles lus d'avance : sur PC, les fichiers en arrière-plan dès l'ouverture du monde ; ensuite
# (warm_next), un modèle préparé par image calme. Avant : 10 à 20 ms d'à-coup au premier arbre de chaque sorte et taille.
static var _requested: Dictionary = {}
static var _warm_list: Array = []

static func read_ahead() -> void:
	if not _warm_list.is_empty() or _meshes.size() >= FILES.size() * SIZES * 2:
		return
	for kind in range(FILES.size()):
		for size in range(1, SIZES + 1):
			for far in [false, true]:
				_warm_list.append([kind, size, far])
				var path := _path(kind, size, far)
				# Rendu Compatibility (Web, vieux PC) : les fichiers y sont lus un par un (warm_next) ; en arrière-plan,
				# ses maillages bloquaient la première image 5 s.
				if RenderingServer.get_current_rendering_method() != "gl_compatibility" and not _meshes.has("%d_%d_%s" % [kind, size, far]) and ResourceLoader.load_threaded_request(path) == OK:
					_requested[path] = true

# Prépare le prochain modèle pas encore prêt ; faux quand tous le sont.
static func warm_next() -> bool:
	while not _warm_list.is_empty():
		var next: Array = _warm_list.pop_front()
		if not _meshes.has("%d_%d_%s" % next):
			mesh(next[0], next[1], next[2])
			return true
	return false

static func _load(kind: int, size: int, far: bool) -> ArrayMesh:
	var path := _path(kind, size, far)
	var scene: PackedScene = ResourceLoader.load_threaded_get(path) if _requested.erase(path) else load(path)
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
	return TRUNKS[kind][clampi(size, 1, SIZES) - 1]

static func triangles(made: Mesh) -> int:
	var count := 0
	for surface in range(made.get_surface_count()):
		var indices: PackedInt32Array = made.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
		count += (indices.size() if not indices.is_empty() else made.surface_get_array_len(surface)) / 3
	return count

# Arbre posé dans le monde : corps immobile (collision du tronc), modèle détaillé de près, simplifié au loin.
static func tree_body(kind: int, size: int, vine := false) -> StaticBody3D:
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
	# 0.0.6.16 : liane enroulée sur le tronc (tilleuls du cœur des forêts de feuillus), visible de près seulement.
	if vine:
		var climb := MeshInstance3D.new()
		climb.name = "Liane"
		var base := trunk(kind, size)
		climb.mesh = Plants.vine_mesh(base.x, base.y + 1.5)
		climb.visibility_range_end = DETAIL_END
		climb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(climb)
	var foot := trunk(kind, size)
	var shape := CylinderShape3D.new()
	shape.radius = foot.x
	shape.height = foot.y
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = foot.y / 2.0
	model.add_child(collision)
	return body
