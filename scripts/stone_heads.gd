extends RefCounted
# 0.0.8.5 (#211) : têtes de hache et de pioche taillées, faites en code (pas de Blender) : une pierre ronde et bosselée
# qui, coup après coup (progress de 0 à 1), prend sa forme à facettes : hache : plate, large, au tranchant d'un côté ;
# pioche : longue, pointue au bout. Diamètre 1 (mise à la taille par l'appelant), facettes plates (taille à éclats).
const COLORS := [Color("#c4bca8"), Color("#2e2e33")]
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

static func mesh(head: String, progress: float, stone_seed: int = 1) -> ArrayMesh:
	var step := clampi(roundi(progress * 8.0), 0, 8)
	var key := "%s/%d/%d" % [head, step, stone_seed % 4]
	if _meshes.has(key):
		return _meshes[key]
	var p := step / 8.0
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 9
	ball.rings = 5
	var arrays := ball.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var faces: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var rng := RandomNumberGenerator.new()
	rng.seed = 211 + stone_seed % 4
	var bumps := {}
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for index in faces:
		var point: Vector3 = points[index]
		var round_key := Vector3i(roundi(point.x * 100.0), roundi(point.y * 100.0), roundi(point.z * 100.0))
		if not bumps.has(round_key):
			bumps[round_key] = rng.randf_range(0.9, 1.08)
		var rough: Vector3 = point * bumps[round_key]
		surface.add_vertex(rough.lerp(_shape(head, point), p))
	surface.generate_normals()
	var made := surface.commit()
	_meshes[key] = made
	return made

# Forme finale d'un point de la boule : x le long de la tête, y en hauteur, z son épaisseur.
static func _shape(head: String, point: Vector3) -> Vector3:
	if head == "hache":
		# Plate et large, le tranchant (x > 0) plus mince.
		var thin := lerpf(0.42, 0.12, clampf(point.x + 0.5, 0.0, 1.0))
		return Vector3(point.x * 1.3, point.y * 1.05, point.z * thin)
	# Pioche : longue, pointue vers x > 0.
	var taper := lerpf(1.0, 0.25, clampf(point.x + 0.5, 0.0, 1.0))
	return Vector3(point.x * 1.8, point.y * 0.55 * taper, point.z * 0.55 * taper)

static func material(stone: int) -> StandardMaterial3D:
	var key := clampi(stone, 0, 1)
	if not _materials.has(key):
		var made := StandardMaterial3D.new()
		made.albedo_color = COLORS[key]
		made.roughness = 0.45 if key == 1 else 0.85
		_materials[key] = made
	return _materials[key]
