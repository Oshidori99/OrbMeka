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

# Maillage d'un rocher (taille 1 à 7, forme 1 à 7), toujours le même ; couleur de la pierre du terrain.
static func rock_mesh(size: int, shape: int) -> ArrayMesh:
	var key := Vector2i(size, shape)
	if _meshes.has(key):
		return _meshes[key]
	var spec: Dictionary = SHAPES[shape - 1]
	var radius: float = SIZES[size - 1] / 2.0
	var noise := FastNoiseLite.new()
	noise.seed = 9100 + size * 13 + shape * 101
	noise.frequency = 0.9
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
