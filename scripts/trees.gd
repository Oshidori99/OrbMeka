extends RefCounted
# 0.0.6.9 (#149, #138) : premiers arbres fruitiers, faits en code (formes douces, comme les rochers) :
# pommier (tronc, couronne de boules de feuilles, pommes rouges) et noisetier (touffe de tiges droites, feuillage clair,
# noisettes en grappes). Trois variantes chacun. Un modèle détaillé de près, un modèle simplifié au loin, rien au-delà.
# Pas de récolte ni de coupe (série 0.0.6).
const APPLE := 0
const HAZEL := 1
const KIND_NAMES := ["pommier", "noisetier"]
const VARIANTS := 3
# Distances d'affichage (m) : détaillé jusqu'à DETAIL_END, simplifié jusqu'à FAR_END, ensuite rien.
const DETAIL_END := 40.0
const FAR_END := 150.0

const BARK := Color("#4a3020")
const HAZEL_BARK := Color("#5c4330")
const APPLE_LEAVES := Color("#2f6b22")
const HAZEL_LEAVES := Color("#5a8526")
const APPLE_RED := Color("#c01e16")
const APPLE_BLUSH := Color("#d98a1c")
const NUT := Color("#7a4f22")

# Formes : [hauteur du tronc, rayon du tronc, centre de la couronne (hauteur), rayons de la couronne, nombre de pommes]
# pour le pommier ; [nombre de tiges, hauteur des tiges, écart des tiges, nombre de grappes de noisettes] pour le noisetier.
const APPLE_SHAPES := [
	[1.5, 0.16, 2.7, Vector3(1.6, 1.2, 1.5), 22],
	[1.2, 0.18, 2.3, Vector3(2.1, 1.0, 1.9), 26],
	[1.1, 0.1, 1.9, Vector3(0.95, 0.85, 0.95), 10],
]
const HAZEL_SHAPES := [
	[9, 3.0, 0.24, 9],
	[12, 3.6, 0.3, 12],
	[6, 2.2, 0.18, 5],
]

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}

static func material(name: String) -> StandardMaterial3D:
	if not _materials.has(name):
		var made := StandardMaterial3D.new()
		made.vertex_color_use_as_albedo = true
		made.vertex_color_is_srgb = true
		made.roughness = 0.9 if name != "fruit" else 0.45
		# Boules fermées : faces arrière cachées (moins de dessin) ; écorce des deux côtés (tiges fines).
		made.cull_mode = BaseMaterial3D.CULL_DISABLED if name == "bark" else BaseMaterial3D.CULL_BACK
		_materials[name] = made
	return _materials[name]

# Modèle détaillé (far = false) ou simplifié (far = true) ; gardé une fois fait.
static func mesh(kind: int, variant: int, far := false) -> ArrayMesh:
	var key := "%d_%d_%s" % [kind, variant, far]
	if not _meshes.has(key):
		_meshes[key] = _build(kind, clampi(variant, 0, VARIANTS - 1), far)
	return _meshes[key]

# Collision simple : le tronc (pommier) ou le pied de la touffe (noisetier) : [rayon, hauteur].
static func trunk(kind: int, variant: int) -> Vector2:
	if kind == APPLE:
		var shape: Array = APPLE_SHAPES[clampi(variant, 0, VARIANTS - 1)]
		return Vector2(shape[1] + 0.05, shape[2])
	var hazel: Array = HAZEL_SHAPES[clampi(variant, 0, VARIANTS - 1)]
	return Vector2(hazel[2] + 0.12, 1.8)

static func _build(kind: int, variant: int, far: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["arbre", kind, variant])
	var parts := {"bark": SurfaceTool.new(), "leaves": SurfaceTool.new(), "fruit": SurfaceTool.new()}
	for tool: SurfaceTool in parts.values():
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind == APPLE:
		_apple(parts, APPLE_SHAPES[variant], rng, far)
	else:
		_hazel(parts, HAZEL_SHAPES[variant], rng, far)
	var result := ArrayMesh.new()
	for name in ["bark", "leaves", "fruit"]:
		var tool: SurfaceTool = parts[name]
		# Sommets identiques partagés (bien moins de sommets à calculer).
		tool.index()
		var arrays := tool.commit_to_arrays()
		if arrays[Mesh.ARRAY_VERTEX] == null or (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			continue
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(result.get_surface_count() - 1, material(name))
	return result

# Pommier : tronc un peu penché qui se partage en deux ou trois branches, couronne ronde de boules de feuilles,
# pommes posées sur le feuillage (plus nombreuses du côté du soleil, en haut).
static func _apple(parts: Dictionary, shape: Array, rng: RandomNumberGenerator, far: bool) -> void:
	var height: float = shape[0]
	var radius: float = shape[1]
	var crown := Vector3(0.0, shape[2], 0.0)
	var size: Vector3 = shape[3]
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
	var top := Vector3(0.0, height, 0.0) + lean
	_tube(parts.bark, Vector3.ZERO, top, radius * 1.25, radius, BARK, 5 if far else 8)
	if far:
		_blob(parts.leaves, crown + lean, size * 1.05, APPLE_LEAVES, rng, 8, 5, 0.0)
		return
	for index in range(3 if size.x > 1.2 else 2):
		var angle := TAU * index / 3.0 + rng.randf_range(-0.4, 0.4)
		var end := crown + lean + Vector3(cos(angle) * size.x * 0.45, size.y * 0.1, sin(angle) * size.z * 0.45)
		_tube(parts.bark, top, end, radius * 0.75, radius * 0.35, BARK, 6)
	var blobs: Array = [[crown + lean + Vector3(0.0, size.y * 0.15, 0.0), size * 0.75]]
	for index in range(6):
		var angle := TAU * index / 6.0 + rng.randf_range(-0.3, 0.3)
		var at := crown + lean + Vector3(cos(angle) * size.x * 0.5, rng.randf_range(-0.25, 0.2) * size.y, sin(angle) * size.z * 0.5)
		blobs.append([at, size * rng.randf_range(0.45, 0.6)])
	for blob in blobs:
		_blob(parts.leaves, blob[0], blob[1], APPLE_LEAVES.lerp(Color("#22561a"), rng.randf() * 0.6), rng, 10, 6, 0.12)
	for index in range(int(shape[4])):
		# Sur le bord extérieur du feuillage (sinon cachées dedans) : depuis le dehors, on avance vers le centre
		# jusqu'à toucher une boule de feuilles.
		var direction := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.5, 0.7), rng.randf_range(-1.0, 1.0)).normalized()
		var at: Vector3 = crown + lean
		for step in range(30):
			var probe: Vector3 = crown + lean + direction * size * (1.4 - step * 0.04)
			if blobs.any(func(blob: Array): return ((probe - blob[0]) / blob[1]).length() < 1.02):
				at = probe
				break
		var color := APPLE_RED.lerp(APPLE_BLUSH, rng.randf_range(0.0, 0.35))
		_blob(parts.fruit, at, Vector3.ONE * 0.09, color, rng, 6, 4, 0.0)
		_tube(parts.bark, at + Vector3(0, 0.07, 0), at + Vector3(0, 0.13, 0), 0.012, 0.01, BARK, 3)

# Noisetier : tiges droites qui partent d'une même souche en s'écartant un peu, feuillage clair en touffes sur le haut
# des tiges (forme de vase), noisettes par deux ou trois dans le feuillage.
static func _hazel(parts: Dictionary, shape: Array, rng: RandomNumberGenerator, far: bool) -> void:
	var stems: int = shape[0]
	var height: float = shape[1]
	var spread: float = shape[2]
	if far:
		_tube(parts.bark, Vector3.ZERO, Vector3(0, height * 0.45, 0), spread, spread * 1.6, HAZEL_BARK, 5)
		_blob(parts.leaves, Vector3(0, height * 0.68, 0), Vector3(height * 0.36, height * 0.4, height * 0.36), HAZEL_LEAVES, rng, 8, 5, 0.0)
		return
	var tips: Array = []
	for index in range(stems):
		var angle := TAU * index / stems + rng.randf_range(-0.3, 0.3)
		var foot := Vector3(cos(angle), 0.0, sin(angle)) * spread * rng.randf_range(0.4, 1.0)
		var tilt := rng.randf_range(0.08, 0.28)
		var length := height * rng.randf_range(0.75, 1.05)
		var tip := foot + Vector3(cos(angle) * sin(tilt), cos(tilt), sin(angle) * sin(tilt)) * length
		_tube(parts.bark, foot, tip, 0.045, 0.02, HAZEL_BARK.lerp(Color("#7a6048"), rng.randf() * 0.4), 5)
		tips.append([foot, tip])
	var blobs: Array = []
	for stem in tips:
		for part in [0.7, 0.95]:
			var at: Vector3 = stem[0].lerp(stem[1], part)
			var puff := height * rng.randf_range(0.15, 0.2)
			blobs.append([at, Vector3(puff, puff * 0.8, puff)])
			_blob(parts.leaves, at, Vector3(puff, puff * 0.8, puff), HAZEL_LEAVES.lerp(Color("#3f6b1e"), rng.randf() * 0.5), rng, 8, 5, 0.15)
	for index in range(int(shape[3])):
		var blob: Array = blobs[rng.randi_range(0, blobs.size() - 1)]
		var direction := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.9, 0.2), rng.randf_range(-1.0, 1.0)).normalized()
		var at: Vector3 = blob[0] + direction * blob[1].x * 0.9
		for nut in range(rng.randi_range(2, 3)):
			var offset := Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.04, 0.02), rng.randf_range(-0.05, 0.05))
			_blob(parts.fruit, at + offset, Vector3(0.045, 0.055, 0.045), NUT.lerp(Color("#9c7038"), rng.randf() * 0.3), rng, 5, 3, 0.0)

# Tube (tronc, branche, tige) de a à b, rayon r0 en bas et r1 en haut.
static func _tube(tool: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, color: Color, sides: int) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var other := axis.cross(side)
	for index in range(sides):
		var angles := [TAU * index / sides, TAU * (index + 1) / sides]
		var ring := []
		for angle: float in angles:
			var out := side * cos(angle) + other * sin(angle)
			ring.append([a + out * r0, b + out * r1, out])
		var shade := color.darkened(0.12)
		for corner in [[ring[0][0], ring[0][2], shade], [ring[1][1], ring[1][2], color], [ring[1][0], ring[1][2], shade], [ring[0][0], ring[0][2], shade], [ring[0][1], ring[0][2], color], [ring[1][1], ring[1][2], color]]:
			tool.set_color(corner[2])
			tool.set_normal(corner[1])
			tool.add_vertex(corner[0])

# Boule douce (feuillage, pomme, noisette) : un peu bosselée (bumps), plus sombre en dessous.
static func _blob(tool: SurfaceTool, center: Vector3, radii: Vector3, color: Color, rng: RandomNumberGenerator, radial: int, rings: int, bumps: float) -> void:
	var sphere := SphereMesh.new()
	sphere.radial_segments = radial
	sphere.rings = rings
	var arrays := sphere.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var phase := rng.randf() * TAU
	var placed := PackedVector3Array()
	placed.resize(points.size())
	for index in range(points.size()):
		var unit := points[index] * 2.0
		var bump := 1.0 + bumps * sin(unit.x * 5.0 + phase) * sin(unit.y * 4.0 + phase * 0.7) * sin(unit.z * 5.0 - phase)
		placed[index] = center + unit * radii * bump
	for index in indices:
		var normal := (normals[index] / radii).normalized()
		tool.set_color(color.darkened(0.28 * (1.0 - normal.y) * 0.5))
		tool.set_normal(normal)
		tool.add_vertex(placed[index])

# Arbre posé dans le monde : corps immobile (collision du tronc), modèle détaillé de près, simplifié au loin.
static func tree_body(kind: int, variant: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Arbre"
	body.add_to_group("trees")
	var near := MeshInstance3D.new()
	near.name = "Detail"
	near.mesh = mesh(kind, variant)
	near.visibility_range_end = DETAIL_END
	near.visibility_range_end_margin = 2.0
	body.add_child(near)
	var far := MeshInstance3D.new()
	far.name = "Loin"
	far.mesh = mesh(kind, variant, true)
	far.visibility_range_begin = DETAIL_END
	far.visibility_range_begin_margin = 2.0
	far.visibility_range_end = FAR_END
	body.add_child(far)
	var size := trunk(kind, variant)
	var shape := CylinderShape3D.new()
	shape.radius = size.x
	shape.height = size.y
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = size.y / 2.0
	body.add_child(collision)
	return body
