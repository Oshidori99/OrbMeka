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
const Inventory = preload("res://scripts/inventory.gd")
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
			"hole":
				# 0.0.6.21 (#177) : fond du trou dans le tronc, brun presque noir, mat.
				made.albedo_color = Color(0.05, 0.035, 0.025)
				made.roughness = 1.0
			_:
				made.albedo_color = FRUIT_COLORS[kind]
				# 0.0.7.5 : couleur de chaque pomme dans ses données de série ou ses sommets (_series, _fruit_mesh).
				if kind == APPLE:
					made.albedo_color = Color.WHITE
					made.vertex_color_use_as_albedo = true
					made.vertex_color_is_srgb = true
				made.roughness = 0.45 if kind == APPLE else 0.7
		_materials[key] = made
	return _materials[key]

# Modèle de près (far = false) ou de loin (far = true), lu une fois dans assets/trees, avec nos matériaux.
# 0.0.6.21 (#177) : form 0, 1 ou 2 (trois formes un peu différentes ; fichiers _f2 et _f3 pour les deux dernières).
static func mesh(kind: int, size: int = 3, far := false, form := 0) -> ArrayMesh:
	size = clampi(size, 1, SIZES)
	form = clampi(form, 0, FORMS - 1)
	var key := "%d_%d_%s_%d" % [kind, size, far, form]
	if not _meshes.has(key):
		_meshes[key] = _load(kind, size, far, form)
	return _meshes[key]

const FORMS := 3

static func _path(kind: int, size: int, far: bool, form := 0) -> String:
	return FOLDER + "%s_%d%s_%s.glb" % [FILES[kind], size, "" if form == 0 else "_f%d" % (form + 1), "loin" if far else "jeu"]

# 0.0.6.18 (#175) : modèles lus d'avance : sur PC, les fichiers en arrière-plan dès l'ouverture du monde ; ensuite
# (warm_next), un modèle préparé par image calme. Avant : 10 à 20 ms d'à-coup au premier arbre de chaque sorte et taille.
static var _requested: Dictionary = {}
static var _warm_list: Array = []

static func read_ahead(forms := 1) -> void:
	if not _warm_list.is_empty():
		return
	for form in range(forms):
		for kind in range(FILES.size()):
			for size in range(1, SIZES + 1):
				for far in [false, true]:
					if _meshes.has("%d_%d_%s_%d" % [kind, size, far, form]):
						continue
					_warm_list.append([kind, size, far, form])
					var path := _path(kind, size, far, form)
					# Rendu Compatibility (Web, vieux PC) : les fichiers y sont lus un par un (warm_next) ; en arrière-plan,
					# ses maillages bloquaient la première image 5 s.
					if RenderingServer.get_current_rendering_method() != "gl_compatibility" and ResourceLoader.load_threaded_request(path) == OK:
						_requested[path] = true

# Prépare le prochain modèle pas encore prêt ; faux quand tous le sont.
static func warm_next() -> bool:
	# Rendu Compatibility (Web) : préparer un modèle y prend 50 à 100 ms (à-coups quand on ne bouge pas) ; lus à la demande.
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return false
	while not _warm_list.is_empty():
		var next: Array = _warm_list.pop_front()
		if not _meshes.has("%d_%d_%s_%d" % next):
			mesh(next[0], next[1], next[2], next[3])
			return true
	return false

static func _load(kind: int, size: int, far: bool, form := 0) -> ArrayMesh:
	var path := _path(kind, size, far, form)
	var scene: PackedScene = ResourceLoader.load_threaded_get(path) if _requested.erase(path) else load(path)
	var root := scene.instantiate()
	var source: Mesh = (root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	root.free()
	var result := ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface)
		var name := str(source.surface_get_material(surface).resource_name) if source.surface_get_material(surface) else ""
		var role := "bark" if name.contains("Ecorce") else ("leaves" if name.contains("Feuille") else ("hole" if name.contains("Trou") else "fruit"))
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
		# 0.0.7.5 : pommes et noisettes retrouvées et refaites (taille, couleur, place gardée pour la cueillette).
		# Ils ne restent pas dans le modèle de l'arbre : ils sont dessinés à part, en série (fruit_node).
		if (kind == APPLE or kind == HAZEL) and role == "fruit" and not far:
			_fruits[_fruit_key(kind, size, form)] = _find_fruits(arrays, kind)
			continue
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(result.get_surface_count() - 1, material(kind, role))
	return result

# --- 0.0.7.5 : fruits (pommes et noisettes) ---
# Demande de l'utilisateur : pommes en trois tailles et cinq couleurs, comme les vraies (inventory.gd : APPLE_SIZES,
# APPLE_COLORS) ; cueillir une pomme ou une noisette en la visant (R). Les fruits du modèle Blender (un petit polyèdre
# chacun) sont retrouvés au chargement du modèle (une fois), retirés du modèle et dessinés à part, en série (un même
# petit modèle de fruit lisse pour tous, MultiMesh), à la même place.
# Chaque pomme a une taille (1, 2 ou 3 ; la 2 un peu plus grande qu'avant) et une couleur, toujours les mêmes (selon sa
# place) ; moitié rouge moitié jaune : rouge du côté du soleil. Leur place est gardée (fruit_spots) pour la visée ; un
# arbre dont on a cueilli des fruits reçoit sa propre série de fruits restants (apply_picked).
const APPLE_SCALES := [0.8, 1.12, 1.38]
const FRUIT_RINGS := 5
const FRUIT_SIDES := 8
# Fruits de chaque modèle : clé « espèce_taille_forme » → [[centre, rayon, taille 1 à 3, couleur], …] (repère de l'arbre).
static var _fruits: Dictionary = {}

static func _fruit_key(kind: int, size: int, form: int) -> String:
	return "%d_%d_%d" % [kind, clampi(size, 1, SIZES), clampi(form, 0, FORMS - 1)]

# Retrouve les fruits d'une surface : sommets reliés par leurs triangles (ou au même endroit) = un fruit.
static func _find_fruits(arrays: Array, kind: int) -> Array:
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var count := points.size()
	# Tableau ordinaire : partagé avec les fonctions ci-dessous (un tableau « Packed » y serait copié).
	var parent := []
	parent.resize(count)
	for index in range(count):
		parent[index] = index
	var find := func(start: int) -> int:
		var at := start
		while parent[at] != at:
			parent[at] = parent[parent[at]]
			at = parent[at]
		return at
	var join := func(a: int, b: int) -> void:
		var ra: int = find.call(a)
		var rb: int = find.call(b)
		if ra != rb:
			parent[ra] = rb
	var corners := indices if not indices.is_empty() else PackedInt32Array(range(count))
	for at in range(0, corners.size() - 2, 3):
		join.call(corners[at], corners[at + 1])
		join.call(corners[at], corners[at + 2])
	var same_place := {}
	for index in range(count):
		var key := Vector3i((points[index] * 1000.0).round())
		if same_place.has(key):
			join.call(index, same_place[key])
		else:
			same_place[key] = index
	var groups := {}
	for index in range(count):
		var root: int = find.call(index)
		if not groups.has(root):
			groups[root] = []
		groups[root].append(points[index])
	var spots := []
	for root in groups:
		var list: Array = groups[root]
		var center := Vector3.ZERO
		for point in list:
			center += point
		center /= list.size()
		var radius := 0.0
		for point in list:
			radius += center.distance_to(point)
		radius /= list.size()
		var seed := hash(Vector3i((center * 100.0).round()))
		var size: int = absi(seed) % 3 + 1 if kind == APPLE else 2
		var tint: int = absi(seed / 3) % Inventory.APPLE_COLORS.size() if kind == APPLE else -1
		spots.append([center, radius * (APPLE_SCALES[size - 1] if kind == APPLE else 1.0), size, tint])
	# Ordre fixe (numéro de chaque fruit, gardé dans la sauvegarde des fruits cueillis).
	spots.sort_custom(func(a, b): return [a[0].x, a[0].y, a[0].z] < [b[0].x, b[0].y, b[0].z])
	return spots

# Modèle d'un fruit, rayon 1 : sphère lisse (FRUIT_RINGS × FRUIT_SIDES) ; pomme un peu aplatie, creusée en haut et en
# bas ; noisette un peu pointue. two_tone : pomme moitié rouge moitié jaune (rouge du côté du soleil), couleur dans les
# sommets ; sinon sommets blancs et couleur de chaque fruit dans ses données (MultiMesh).
static var _fruit_meshes: Dictionary = {}

static func _fruit_mesh(kind: int, two_tone: bool) -> ArrayMesh:
	var key := "%d_%s" % [kind, two_tone]
	if _fruit_meshes.has(key):
		return _fruit_meshes[key]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var faces := PackedInt32Array()
	for ring in range(FRUIT_RINGS + 1):
		var polar := PI * ring / FRUIT_RINGS
		for side in range(FRUIT_SIDES + 1):
			var around := TAU * side / FRUIT_SIDES
			var direction := Vector3(sin(polar) * cos(around), cos(polar), sin(polar) * sin(around))
			var shape := direction * Vector3(1.0, 0.9 if kind == APPLE else 1.15, 1.0)
			if kind == APPLE and ring == 0:
				shape.y = 0.62
			elif kind == APPLE and ring == FRUIT_RINGS:
				shape.y = -0.8
			vertices.append(shape)
			normals.append(direction)
			var color := Color.WHITE
			if two_tone:
				color = Inventory.APPLE_COLORS[1].lerp(Inventory.APPLE_COLORS[2], smoothstep(-0.6, 0.6, direction.x * 0.7 - direction.y * 0.4 + direction.z * 0.3))
			colors.append(color)
	for ring in range(FRUIT_RINGS):
		for side in range(FRUIT_SIDES):
			var a := ring * (FRUIT_SIDES + 1) + side
			var b := a + FRUIT_SIDES + 1
			faces.append_array([a, b, a + 1, a + 1, b, b + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = faces
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	made.surface_set_material(0, material(kind, "fruit"))
	_fruit_meshes[key] = made
	return made

# Fruits d'un modèle (repère de l'arbre, avant son échelle et sa rotation) ; le modèle est lu s'il ne l'est pas.
static func fruit_spots(kind: int, size: int, form: int = 0) -> Array:
	if kind != APPLE and kind != HAZEL:
		return []
	mesh(kind, size, false, form)
	return _fruits.get(_fruit_key(kind, size, form), [])

# Séries de fruits (MultiMesh) d'un modèle, sans les fruits cueillis (skip) : une pour les fruits d'une seule couleur,
# une pour les pommes moitié rouge moitié jaune. Sans fruit cueilli : partagées par tous les arbres du même modèle.
static var _fruit_series: Dictionary = {}

# own_spots : fruits propres à un arbre (0.0.7.8 : arbre tombé, fruits déplacés avec lui) ; jamais gardées en commun.
static func _series(kind: int, size: int, form: int, skip: Dictionary, own_spots: Array = []) -> Array:
	var key := _fruit_key(kind, size, form)
	var shared := skip.is_empty() and own_spots.is_empty()
	if shared and _fruit_series.has(key):
		return _fruit_series[key]
	var lists := [[], []]
	var spots := own_spots if not own_spots.is_empty() else fruit_spots(kind, size, form)
	for number in range(spots.size()):
		if not skip.has(number):
			lists[1 if kind == APPLE and spots[number][3] == 4 else 0].append(spots[number])
	var made := []
	for two_tone in [false, true]:
		var list: Array = lists[1 if two_tone else 0]
		if list.is_empty():
			continue
		var series := MultiMesh.new()
		series.transform_format = MultiMesh.TRANSFORM_3D
		series.use_colors = true
		series.mesh = _fruit_mesh(kind, two_tone)
		series.instance_count = list.size()
		for at in range(list.size()):
			var spot: Array = list[at]
			series.set_instance_transform(at, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * spot[1]), spot[0]))
			var color: Color = FRUIT_COLORS[kind] if kind != APPLE else (Color.WHITE if two_tone else Inventory.APPLE_COLORS[spot[3]])
			series.set_instance_color(at, color)
		made.append(series)
	if shared:
		_fruit_series[key] = made
	return made

# Fruits d'un arbre (nœud « Fruits » de son modèle), visibles de près seulement, comme le modèle détaillé.
static func fruit_node(kind: int, size: int, form: int, skip: Dictionary = {}, own_spots: Array = []) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Fruits"
	for series in _series(kind, size, form, skip, own_spots):
		var drawn := MultiMeshInstance3D.new()
		drawn.multimesh = series
		drawn.visibility_range_end = DETAIL_END
		drawn.visibility_range_end_margin = 2.0
		holder.add_child(drawn)
	return holder

# Arbre dont on a cueilli des fruits (numéros dans « picked ») : ses fruits restants seulement.
static func apply_picked(body: Node3D, picked: Array) -> void:
	var model: Node3D = body.get_node_or_null("Modele")
	if model == null or not body.has_meta("kind"):
		return
	var old: Node = model.get_node_or_null("Fruits")
	if old != null:
		model.remove_child(old)
		old.free()
	var skip := {}
	for number in picked:
		skip[int(number)] = true
	model.add_child(fruit_node(body.get_meta("kind"), body.get_meta("size"), body.get_meta("form"), skip, body.get_meta("fruit_spots", [])))

# 0.0.7.9 : épaisseur du bois (diamètre, en mètres, repère du modèle, avant l'échelle de l'arbre) à un point visé : on part
# du sommet d'écorce le plus proche et on traverse le bois (contre sa normale) jusqu'à l'écorce d'en face, celle de la même
# tige ou branche (les tiges voisines d'une touffe ne comptent pas). Sert au temps de coupe et aux troncs coupés (world.gd).
# Les sommets d'écorce et leurs normales sont lus une fois par modèle.
static var _bark_points: Dictionary = {}

static func _bark(kind: int, size: int, form: int) -> Array:
	var key := _fruit_key(kind, size, form)
	if not _bark_points.has(key):
		var points := PackedVector3Array()
		var normals := PackedVector3Array()
		var made := mesh(kind, size, false, form)
		for surface in range(made.get_surface_count()):
			if made.surface_get_material(surface) == material(kind, "bark"):
				var arrays: Array = made.surface_get_arrays(surface)
				points.append_array(arrays[Mesh.ARRAY_VERTEX])
				normals.append_array(arrays[Mesh.ARRAY_NORMAL])
		_bark_points[key] = [points, normals]
	return _bark_points[key]

# 0.0.7.9 : morceau d'un arbre coupé : seulement les triangles dont le centre est entre lo et hi (hauteur dans le modèle,
# le long du tronc), écorce, feuilles et trous ; gardé en commun par morceau.
static func mesh_range(kind: int, size: int, form: int, lo: float, hi: float) -> ArrayMesh:
	var key := "morceau_%s_%.3f_%.3f" % [_fruit_key(kind, size, form), lo, hi]
	if _meshes.has(key):
		return _meshes[key]
	var full := mesh(kind, size, false, form)
	var made := ArrayMesh.new()
	for surface in range(full.get_surface_count()):
		var arrays := full.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for at in range(0, indices.size() - 2, 3):
			var middle := (points[indices[at]].y + points[indices[at + 1]].y + points[indices[at + 2]].y) / 3.0
			if middle >= lo and middle < hi:
				kept.append_array([indices[at], indices[at + 1], indices[at + 2]])
		if kept.is_empty():
			continue
		# Seulement les sommets de ce morceau (taille et collision justes, moins de mémoire).
		var count := points.size()
		var remap := {}
		var order := PackedInt32Array()
		for index in kept:
			if not remap.has(index):
				remap[index] = order.size()
				order.append(index)
		for kind_index in range(Mesh.ARRAY_MAX):
			if kind_index == Mesh.ARRAY_INDEX or arrays[kind_index] == null:
				continue
			var source = arrays[kind_index]
			var stride: int = source.size() / count
			var packed = source.slice(0, 0)
			for index in order:
				for part in range(stride):
					packed.append(source[index * stride + part])
			arrays[kind_index] = packed
		for at in range(kept.size()):
			kept[at] = remap[kept[at]]
		arrays[Mesh.ARRAY_INDEX] = kept
		made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		made.surface_set_material(made.get_surface_count() - 1, full.surface_get_material(surface))
	_meshes[key] = made
	return made

# Feuilles entre lo et hi : un morceau sans feuilles est du bois nu (il devient un tronc ou un bâton).
static func has_leaves(kind: int, size: int, form: int, lo: float, hi: float) -> bool:
	var full := mesh(kind, size, false, form)
	for surface in range(full.get_surface_count()):
		if full.surface_get_material(surface) != material(kind, "leaves"):
			continue
		for point in full.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			if point.y >= lo and point.y < hi:
				return true
	return false

static func top(kind: int, size: int, form: int) -> float:
	return mesh(kind, size, false, form).get_aabb().end.y

static func wood_thickness(kind: int, size: int, form: int, local: Vector3) -> float:
	var bark := _bark(kind, size, form)
	var points: PackedVector3Array = bark[0]
	var normals: PackedVector3Array = bark[1]
	if points.is_empty() or normals.size() != points.size():
		return 0.1
	var start := 0
	var nearest := INF
	for index in range(points.size()):
		var away := points[index].distance_squared_to(local)
		if away < nearest:
			nearest = away
			start = index
	var from := points[start]
	var outward := normals[start].normalized()
	var best := INF
	for index in range(points.size()):
		var toward := points[index] - from
		var depth := -toward.dot(outward)
		if depth < 0.005 or depth >= best or normals[index].dot(outward) > -0.3:
			continue
		if (toward + outward * depth).length() <= 0.35 * depth + 0.015:
			best = depth
	return clampf(best if best < INF else 0.03, 0.005, 1.5)

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
static func tree_body(kind: int, size: int, vine := false, form := 0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Arbre"
	body.add_to_group("trees")
	# 0.0.7.5 : espèce, taille et forme du modèle (fruits à cueillir).
	body.set_meta("kind", kind)
	body.set_meta("size", clampi(size, 1, SIZES))
	body.set_meta("form", clampi(form, 0, FORMS - 1))
	var model := Node3D.new()
	model.name = "Modele"
	body.add_child(model)
	var near := MeshInstance3D.new()
	near.name = "Detail"
	near.mesh = mesh(kind, size, false, form)
	near.visibility_range_end = DETAIL_END
	near.visibility_range_end_margin = 2.0
	model.add_child(near)
	# 0.0.7.5 : pommes et noisettes dessinées à part, en série (fruit_node).
	if kind == APPLE or kind == HAZEL:
		model.add_child(fruit_node(kind, clampi(size, 1, SIZES), clampi(form, 0, FORMS - 1)))
	var far := MeshInstance3D.new()
	far.name = "Loin"
	far.mesh = mesh(kind, size, true, form)
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
	# 0.0.7.8 : directement sous le corps de l'arbre (sous « Modele », Godot l'ignorait : on traversait les troncs).
	body.add_child(collision)
	return body
