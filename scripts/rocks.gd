extends RefCounted
# 0.0.5.18 : rochers (essai, demande de l'utilisateur) : une norme de 7 tailles et 7 formes, faites dans le jeu
# (formes originales, aucun modèle externe). Taille 1 à 7 : minuscule, petit, plutôt petit, moyen,
# plutôt grand, grand, énorme ; diamètre moyen en mètres ci-dessous. Plus tard : des cailloux à travailler.
# Les rochers d'un monde sont dans son dossier : objets.json (voir world.gd, _load_objects).
# Demande de l'utilisateur : le plus petit rocher reste plus gros qu'un gros caillou (les cailloux viendront à part).
# 0.0.5.19 : encore plus gros (40 cm à 4 m avant).
const SIZES := [0.6, 0.9, 1.3, 1.9, 2.7, 3.8, 5.4]
const SIZE_NAMES := ["minuscule", "petit", "plutôt petit", "moyen", "plutôt grand", "grand", "énorme"]
# Formes : proportions (largeur, hauteur, profondeur), relief de la surface, faces nettes, coin coupé.
const SHAPES := [
	{"name": "rond", "scale": Vector3(1.0, 0.8, 1.0), "rough": 0.08},
	{"name": "plat", "scale": Vector3(1.35, 0.45, 1.1), "rough": 0.1},
	{"name": "dressé", "scale": Vector3(0.75, 1.5, 0.8), "rough": 0.1},
	{"name": "anguleux", "scale": Vector3(1.0, 0.85, 0.95), "rough": 0.22, "facets": true},
	{"name": "allongé", "scale": Vector3(1.7, 0.65, 0.8), "rough": 0.1},
	{"name": "bosselé", "scale": Vector3(1.0, 0.85, 1.0), "rough": 0.32},
	{"name": "en coin", "scale": Vector3(1.1, 0.95, 1.0), "rough": 0.1, "cut": true},
]
# Part du rocher enfoncée dans le sol (il ne flotte pas sur les pentes).
const SINK := 0.18
static var _meshes := {}
static var _shapes := {}

# Sphère de triangles (icosaèdre subdivisé) : sommets de longueur 1.
static func _sphere(subdivisions: int) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var points: Array[Vector3] = []
	for p in [[-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0], [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t], [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]]:
		points.append(Vector3(p[0], p[1], p[2]).normalized())
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for step in range(subdivisions):
		var middle := {}
		var next := []
		for face in faces:
			var mids := []
			for edge in [[face[0], face[1]], [face[1], face[2]], [face[2], face[0]]]:
				var key := Vector2i(mini(edge[0], edge[1]), maxi(edge[0], edge[1]))
				if not middle.has(key):
					points.append(((points[edge[0]] + points[edge[1]]) / 2.0).normalized())
					middle[key] = points.size() - 1
				mids.append(middle[key])
			next.append_array([[face[0], mids[0], mids[2]], [face[1], mids[1], mids[0]], [face[2], mids[2], mids[1]], [mids[0], mids[1], mids[2]]])
		faces = next
	return [points, faces]

# 0.0.6.3 (génération 17) : cailloux posés sur le sol, 7 tailles (diamètre en m) et les 7 formes des rochers ;
# le plus gros (60 cm) ne dépasse pas le plus petit rocher (demande de l'utilisateur). Plus de petits que de gros.
const PEBBLE_SIZES := [0.08, 0.12, 0.17, 0.24, 0.32, 0.45, 0.6]
const PEBBLE_WEIGHTS := [30, 24, 18, 12, 8, 5, 3]
# Coups de pioche : un pour les petits, jusqu'à 3 pour les plus gros (ils rapetissent entre deux coups).
const PEBBLE_HITS := [1, 1, 1, 1, 2, 2, 3]
static var _pebble_meshes := {}

# Caillou de 1 m de diamètre, d'une forme (1 à 7), même style que les rochers, moins de facettes (ils sont nombreux).
# Chaque caillou est ce maillage mis à sa taille (plusieurs cailloux dessinés d'un coup).
static func pebble_mesh(shape: int) -> ArrayMesh:
	if _pebble_meshes.has(shape):
		return _pebble_meshes[shape]
	var spec: Dictionary = SHAPES[shape - 1]
	var noise := _noise_for(1, shape)
	var sphere := _sphere(1)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_color(Color(1.0, 0.0, 1.0, 1.0))
	if spec.get("facets", false):
		tool.set_smooth_group(-1)
	var points: Array = []
	for direction: Vector3 in sphere[0]:
		points.append(direction * (1.0 + spec.rough * noise.get_noise_3dv(direction * 2.0)) * spec.scale * 0.5)
	for face in sphere[1]:
		for index in [face[0], face[2], face[1]]:
			tool.add_vertex(points[index])
	tool.generate_normals()
	_pebble_meshes[shape] = tool.commit()
	return _pebble_meshes[shape]

# Hauteur du centre d'un caillou au-dessus du sol : un peu enfoncé, comme les rochers.
static func pebble_lift(size: int, shape: int) -> float:
	return PEBBLE_SIZES[size - 1] / 2.0 * SHAPES[shape - 1].scale.y * (1.0 - 2.0 * SINK)

# Maillage d'un rocher (taille 1 à 7, forme 1 à 7), toujours le même ; couleur de la pierre du terrain.
static func rock_mesh(size: int, shape: int) -> ArrayMesh:
	var key := Vector2i(size, shape)
	if _meshes.has(key):
		return _meshes[key]
	var spec: Dictionary = SHAPES[shape - 1]
	var radius: float = SIZES[size - 1] / 2.0
	var noise := _noise_for(size, shape)
	var sphere := _sphere(2)
	var points: Array = []
	for direction: Vector3 in sphere[0]:
		var bump: float = 1.0 + spec.rough * noise.get_noise_3dv(direction * 2.0)
		var at: Vector3 = direction * bump * spec.scale
		if spec.get("cut", false):
			# Coin coupé : un plan penché tranche le haut d'un côté.
			var plane := Vector3(0.55, 1.0, 0.2).normalized()
			var over: float = at.dot(plane) - 0.35
			if over > 0.0:
				at -= plane * over
		points.append(at * radius)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_color(Color(1.0, 0.0, 1.0, 1.0))
	if spec.get("facets", false):
		tool.set_smooth_group(-1)
	for face in sphere[1]:
		# Sens des aiguilles d'une montre vu de dehors, comme le terrain.
		for index in [face[0], face[2], face[1]]:
			tool.add_vertex(points[index])
	tool.generate_normals()
	_meshes[key] = tool.commit()
	return _meshes[key]

static func _noise_for(size: int, shape: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = 9100 + size * 13 + shape * 101
	noise.frequency = 0.9
	return noise

# 0.0.6 : rocher entamé à la pioche, sous-cellule par sous-cellule (cubes de 50 cm alignés sur le terrain).
# Distance approchée (m) à la surface du rocher entier, dans son repère (négatif dedans) : même forme que rock_mesh.
static func shape_distance(local: Vector3, size: int, shape: int, noise: FastNoiseLite) -> float:
	var spec: Dictionary = SHAPES[shape - 1]
	var radius: float = SIZES[size - 1] / 2.0
	var scaled: Vector3 = local / radius
	var q: Vector3 = scaled / spec.scale
	var length := q.length()
	var bump := 1.0
	if length > 0.0001:
		bump = 1.0 + spec.rough * noise.get_noise_3dv(q / length * 2.0)
	var smallest: float = minf(spec.scale.x, minf(spec.scale.y, spec.scale.z))
	var distance := (length - bump) * radius * smallest
	if spec.get("cut", false):
		distance = maxf(distance, (scaled.dot(Vector3(0.55, 1.0, 0.2).normalized()) - 0.35) * radius)
	return distance

static func _box_distance(at: Vector3, center: Vector3, half: float) -> float:
	var d := (at - center).abs() - Vector3.ONE * half
	return Vector3(maxf(d.x, 0.0), maxf(d.y, 0.0), maxf(d.z, 0.0)).length() + minf(maxf(d.x, maxf(d.y, d.z)), 0.0)

# Grille des distances du rocher entier, en coordonnées du monde (gardée par le monde : on ne la refait pas à chaque coup).
# Pas de la grille : environ 20 points sur la largeur, entre 6 et 30 cm.
static func shape_grid(size: int, shape: int, placement: Transform3D) -> Dictionary:
	var spec: Dictionary = SHAPES[shape - 1]
	var reach: float = SIZES[size - 1] / 2.0 * maxf(spec.scale.x, maxf(spec.scale.y, spec.scale.z)) * (1.0 + spec.rough) + 0.3
	var step := clampf(reach * 2.0 / 20.0, 0.06, 0.3)
	var origin: Vector3 = placement.origin - Vector3.ONE * reach
	var count := ceili(reach * 2.0 / step) + 1
	var noise := _noise_for(size, shape)
	var inverse := placement.affine_inverse()
	var values := PackedFloat32Array()
	values.resize(count * count * count)
	for x in range(count):
		for y in range(count):
			for z in range(count):
				values[(x * count + y) * count + z] = shape_distance(inverse * (origin + Vector3(x, y, z) * step), size, shape, noise)
	return {"origin": origin, "step": step, "count": count, "values": values}

# Le rocher entier moins les cubes retirés : distances (négatif dedans).
static func carved_values(grid: Dictionary, removed: Array) -> PackedFloat32Array:
	var values: PackedFloat32Array = grid.values.duplicate()
	var count: int = grid.count
	var step: float = grid.step
	var origin: Vector3 = grid.origin
	for center: Vector3 in removed:
		var low := Vector3i(((center - origin - Vector3.ONE * (0.25 + step)) / step).floor())
		var high := Vector3i(((center - origin + Vector3.ONE * (0.25 + step)) / step).ceil())
		for x in range(maxi(low.x, 0), mini(high.x, count - 1) + 1):
			for y in range(maxi(low.y, 0), mini(high.y, count - 1) + 1):
				for z in range(maxi(low.z, 0), mini(high.z, count - 1) + 1):
					var index := (x * count + y) * count + z
					values[index] = maxf(values[index], -_box_distance(origin + Vector3(x, y, z) * step, center, 0.25))
	return values

# Surface du rocher entamé (sommets en coordonnées du monde) ; vide s'il ne reste rien.
static func carved_faces(grid: Dictionary, values: PackedFloat32Array) -> PackedVector3Array:
	var count: int = grid.count
	var step: float = grid.step
	var origin: Vector3 = grid.origin
	var size := count * count * count
	# Un sommet par cellule traversée par la surface : moyenne des points de passage sur ses arêtes.
	# Tableaux simples (pas de dictionnaire) : bien plus rapide.
	var vertex_of := PackedInt32Array()
	vertex_of.resize(size)
	vertex_of.fill(-1)
	var vertices := PackedVector3Array()
	var offsets := PackedInt32Array([0, count * count, count, count * count + count, 1, count * count + 1, count + 1, count * count + count + 1])
	var corner_at := [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1)]
	var edges := [0, 1, 2, 3, 4, 5, 6, 7, 0, 2, 1, 3, 4, 6, 5, 7, 0, 4, 1, 5, 2, 6, 3, 7]
	var corner := PackedFloat32Array()
	corner.resize(8)
	for x in range(count - 1):
		for y in range(count - 1):
			for z in range(count - 1):
				var base := (x * count + y) * count + z
				var inside := 0
				for k in range(8):
					var value := values[base + offsets[k]]
					corner[k] = value
					if value < 0.0:
						inside += 1
				if inside == 0 or inside == 8:
					continue
				var sum := Vector3.ZERO
				var crossings := 0
				for e in range(0, 24, 2):
					var a := corner[edges[e]]
					var b := corner[edges[e + 1]]
					if (a < 0.0) != (b < 0.0):
						sum += corner_at[edges[e]].lerp(corner_at[edges[e + 1]], a / (a - b))
						crossings += 1
				vertex_of[base] = vertices.size()
				vertices.append(origin + (Vector3(x, y, z) + sum / crossings) * step)
	var faces := PackedVector3Array()
	# Arête traversée entre deux points de la grille : un carré entre les 4 cellules qui la partagent.
	var strides := [count * count, count, 1]
	var axes := [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
	for axis_index in range(3):
		var stride: int = strides[axis_index]
		var side_a: int = strides[(axis_index + 1) % 3]
		var side_b: int = strides[(axis_index + 2) % 3]
		var axis: Vector3 = axes[axis_index]
		for x in range(1, count - 1):
			for y in range(1, count - 1):
				for z in range(1, count - 1):
					var index := (x * count + y) * count + z
					var first := values[index]
					if (first < 0.0) == (values[index + stride] < 0.0):
						continue
					var q0 := vertex_of[index]
					var q1 := vertex_of[index - side_a]
					var q2 := vertex_of[index - side_a - side_b]
					var q3 := vertex_of[index - side_b]
					if q0 < 0 or q1 < 0 or q2 < 0 or q3 < 0:
						continue
					# Dehors : du côté du point de la grille qui est hors du rocher. Même sens que le terrain.
					var outward := axis if first < 0.0 else -axis
					var a := vertices[q0]
					var b := vertices[q1]
					var c := vertices[q2]
					var d := vertices[q3]
					if (c - a).cross(b - a).dot(outward) < 0.0:
						faces.append_array([a, c, b, a, d, c])
					else:
						faces.append_array([a, b, c, a, c, d])
	return faces

# Rocher prêt à poser (pierre, collision à sa forme), enfoncé un peu dans le sol.
static func rock_body(size: int, shape: int, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Rocher_%d_%d" % [size, shape]
	body.add_to_group("rocks")
	body.set_meta("rock", Vector2i(size, shape))
	var instance := MeshInstance3D.new()
	instance.mesh = rock_mesh(size, shape)
	instance.material_override = material
	body.add_child(instance)
	var collision := CollisionShape3D.new()
	# Forme de collision calculée une fois par taille et forme (coûteuse).
	if not _shapes.has(Vector2i(size, shape)):
		_shapes[Vector2i(size, shape)] = instance.mesh.create_convex_shape(true, false)
	collision.shape = _shapes[Vector2i(size, shape)]
	body.add_child(collision)
	return body

# Hauteur sous le sol du centre d'un rocher posé : sa base est à SINK de sa hauteur sous la surface.
static func bottom_offset(size: int, shape: int) -> float:
	var spec: Dictionary = SHAPES[shape - 1]
	var half: float = SIZES[size - 1] / 2.0 * spec.scale.y
	return half * (1.0 - 2.0 * SINK)

# Monde d'essai « TestTailleRocher » : les 7 tailles (de gauche à droite) × 7 formes (en s'éloignant),
# devant l'apparition (vers −Z), avec une étiquette par taille et par forme.
static func size_shape_grid() -> Dictionary:
	var rocks := []
	var labels := []
	var widths := []
	var total := 0.0
	for size in range(1, 8):
		widths.append(SIZES[size - 1] * 1.7 + 1.0)
		total += widths[-1]
	for shape in range(1, 8):
		var z := -8.0 - (shape - 1) * 10.0
		var x := -total / 2.0
		for size in range(1, 8):
			x += widths[size - 1] / 2.0
			rocks.append({"taille": size, "forme": shape, "x": snappedf(x, 0.01), "z": z, "rotation": (size * 37 + shape * 53) % 360})
			if shape == 1:
				labels.append({"texte": "Taille %d\n%s" % [size, SIZE_NAMES[size - 1]], "x": snappedf(x, 0.01), "z": -2.5, "hauteur": 1.2})
			x += widths[size - 1] / 2.0
		labels.append({"texte": "Forme %d : %s" % [shape, SHAPES[shape - 1].name], "x": snappedf(-total / 2.0 - 2.5, 0.01), "z": z, "hauteur": 1.0})
	return {"format": 1, "rochers": rocks, "etiquettes": labels}
