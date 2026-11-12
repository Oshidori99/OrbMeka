extends RefCounted
# 0.0.6.16 (#182) : plantes à fibres et lianes, modélisées dans Blender (sources_blender/plantes/generer_plantes.py) puis
# rendues en images (assets/plants) : ortie, lin, herbes longues sur trois plaques croisées ; liane en ruban enroulé
# autour du tronc des tilleuls. Dessinées par colonne de 8 m, une MultiMesh par sorte de plante (très peu de dessins).
# Pas de récolte dans la série 0.0.6 ; on passe au travers (pas de collision).
const NETTLE := 0
const FLAX := 1
const TALL_GRASS := 2
const NAMES := ["ortie", "lin", "herbe_longue"]
# Taille de l'image (m) : largeur = hauteur (rendu carré de Blender, pied en bas).
const SIZES := [1.5, 1.0, 1.5]
const VIEW_END := 45.0
const FOLDER := "res://assets/plants/"
const TINT := Color(1.08, 1.12, 0.85)
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

static func material(name: String) -> StandardMaterial3D:
	if not _materials.has(name):
		var made := StandardMaterial3D.new()
		made.albedo_texture = load(FOLDER + name + ".png")
		made.albedo_color = TINT
		if RenderingServer.get_current_rendering_method() == "gl_compatibility":
			made.albedo_color = Color(TINT.r * 0.8, TINT.g * 0.8, TINT.b * 0.8)
		made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		made.alpha_scissor_threshold = 0.5
		made.cull_mode = BaseMaterial3D.CULL_DISABLED
		made.roughness = 0.9
		_materials[name] = made
	return _materials[name]

# Trois plaques croisées (à 60°), pied au sol ; normales vers le haut (éclairées comme l'herbe).
static func mesh(kind: int) -> ArrayMesh:
	if not _meshes.has(kind):
		var size: float = SIZES[kind]
		var vertices := PackedVector3Array()
		var uvs := PackedVector2Array()
		for k in range(3):
			var across := Vector3.RIGHT.rotated(Vector3.UP, k * PI / 3.0) * size * 0.5
			var low_l := -across
			var low_r := across
			var high_l := -across + Vector3.UP * size
			var high_r := across + Vector3.UP * size
			vertices.append_array([low_l, high_l, high_r, low_l, high_r, low_r])
			uvs.append_array([Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)])
		var normals := PackedVector3Array()
		normals.resize(vertices.size())
		normals.fill(Vector3.UP)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var made := ArrayMesh.new()
		made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		made.surface_set_material(0, material(NAMES[kind]))
		_meshes[kind] = made
	return _meshes[kind]

# Plantes d'une colonne : une MultiMeshInstance3D par sorte (height_at : hauteur du sol).
static func column_nodes(plants: Array, height_at: Callable) -> Array:
	var by_kind := {}
	for plant in plants:
		if not by_kind.has(int(plant.plante)):
			by_kind[int(plant.plante)] = []
		by_kind[int(plant.plante)].append(plant)
	var nodes := []
	for kind: int in by_kind:
		var list: Array = by_kind[kind]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh(kind)
		multi.instance_count = list.size()
		for index in range(list.size()):
			var plant: Dictionary = list[index]
			var basis := Basis(Vector3.UP, deg_to_rad(float(plant.rotation))).scaled(Vector3.ONE * float(plant.taille))
			multi.set_instance_transform(index, Transform3D(basis, Vector3(plant.x, height_at.call(plant.x, plant.z) - 0.03, plant.z)))
		var node := MultiMeshInstance3D.new()
		node.name = "Plantes_" + NAMES[kind]
		node.multimesh = multi
		node.visibility_range_end = VIEW_END
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_to_group("plants")
		nodes.append(node)
	return nodes

# Liane enroulée autour d'un tronc : deux rubans en hélice (rayon, hauteur atteinte), image qui se répète tous les 1 m.
static func vine_mesh(radius: float, height: float) -> ArrayMesh:
	var key := "liane_%.2f_%.2f" % [radius, height]
	if _meshes.has(key):
		return _meshes[key]
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var width := 0.25
	for strand in range(2):
		var phase := strand * PI
		var steps := int(height / 0.12)
		var length := 0.0
		var previous := Vector3.ZERO
		var points := []
		for j in range(steps + 1):
			var y := 0.15 + (height - 0.15) * j / steps
			var angle := phase + y / 1.3 * TAU
			var r := radius * (1.0 - 0.25 * y / maxf(height, 0.1)) + 0.03
			var at := Vector3(cos(angle) * r, y, sin(angle) * r)
			if j > 0:
				length += at.distance_to(previous)
			previous = at
			points.append([at, Vector3(cos(angle), 0, sin(angle)), length])
		for j in range(points.size() - 1):
			var a: Array = points[j]
			var b: Array = points[j + 1]
			var tangent: Vector3 = (b[0] - a[0]).normalized()
			var across_a: Vector3 = tangent.cross(a[1]).normalized() * width * 0.5
			var across_b: Vector3 = tangent.cross(b[1]).normalized() * width * 0.5
			var quad := [a[0] - across_a, a[0] + across_a, b[0] + across_b, b[0] - across_b]
			var quad_uv := [Vector2(0, -a[2]), Vector2(1, -a[2]), Vector2(1, -b[2]), Vector2(0, -b[2])]
			for index in [0, 1, 2, 0, 2, 3]:
				vertices.append(quad[index] + (a[1] if index < 2 else b[1]) * 0.02)
				uvs.append(quad_uv[index])
				normals.append(a[1] if index < 2 else b[1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	made.surface_set_material(0, material("liane"))
	_meshes[key] = made
	return made
