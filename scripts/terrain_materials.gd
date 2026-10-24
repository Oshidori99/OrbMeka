extends RefCounted
# Original world-space procedural materials; no imported bitmap or save-data change.
const SURFACE = preload("res://shaders/terrain_surface.gdshader")

static func surface(ground := false, dirt := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE
	material.set_shader_parameter("ground_surface",ground)
	material.set_shader_parameter("dirt_surface",dirt)
	return material

# 0.0.5.4 : gazon dense, brins de 3 à 7 cm (environ 5 cm), regroupés en carrés de 50 cm (PATCH).
# Densité (Paramètres → Vidéo → Densité de l'herbe) : brins par carré, donc par m² × 4.
const GRASS_SHADER = preload("res://shaders/grass_blades.gdshader")
const PATCH := 0.5
const BLADES := {"low": 40, "medium": 100, "high": 220}
# Herbe visible jusqu'à cette distance (m) ; au-delà, la surface verte du sol suffit.
const GRASS_RANGE := 24.0
static var density := "medium"
static var _patches := {}
static var _blade_material: ShaderMaterial

# Carré de 50 cm rempli de brins : un triangle effilé par brin, penché au hasard (toujours le même).
static func grass_mesh() -> ArrayMesh:
	if _patches.has(density):
		return _patches[density]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5_000_004
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(BLADES.get(density, BLADES.medium)):
		var base := Vector3(rng.randf_range(-PATCH, PATCH) * 0.5, 0.0, rng.randf_range(-PATCH, PATCH) * 0.5)
		var facing := rng.randf() * TAU
		var side := Vector3(cos(facing), 0.0, sin(facing)) * rng.randf_range(0.0025, 0.0045)
		var lean := Vector3(-sin(facing), 0.0, cos(facing)) * rng.randf_range(-0.03, 0.03)
		var tip := base + lean + Vector3(0.0, rng.randf_range(0.03, 0.07), 0.0)
		var normal := Vector3(-sin(facing), 0.4, cos(facing)).normalized()
		for point in [[base - side, 0.0], [tip, 1.0], [base + side, 0.0]]:
			tool.set_normal(normal)
			tool.set_uv(Vector2(0.5, point[1]))
			tool.add_vertex(point[0])
	_patches[density] = tool.commit()
	return _patches[density]

static func grass_instance(points: Array[Vector3], terrain_seed: int) -> MultiMeshInstance3D:
	if points.is_empty():
		return null
	var node := MultiMeshInstance3D.new()
	node.name = "GrassDetail"
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = grass_mesh()
	multi.instance_count = points.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_seed
	for index in range(points.size()):
		var size := rng.randf_range(0.85, 1.15)
		multi.set_instance_transform(index, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, size, 1.0)), points[index]))
		var tint := rng.randf_range(0.85, 1.1)
		multi.set_instance_color(index, Color(tint, tint, tint, 1))
	node.multimesh = multi
	if _blade_material == null:
		_blade_material = ShaderMaterial.new()
		_blade_material.shader = GRASS_SHADER
	node.material_override = _blade_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = GRASS_RANGE
	node.visibility_range_end_margin = 4.0
	node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return node

# Carrés de 50 cm sur une case de 1 m (sommet de bloc ou sol), un peu décalés pour éviter une grille visible.
static func _cell_patches(points: Array[Vector3], corner: Vector3, rng: RandomNumberGenerator) -> void:
	for a in range(2):
		for b in range(2):
			points.append(corner + Vector3((a + 0.5) * PATCH + rng.randf_range(-0.08, 0.08), 0.0, (b + 0.5) * PATCH + rng.randf_range(-0.08, 0.08)))

static func section_grass(blocks: Dictionary, section: Vector3i, size: int) -> MultiMeshInstance3D:
	var points: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(section)
	var origin := section*size
	for x in range(size):
		for y in range(size):
			for z in range(size):
				var cell := origin+Vector3i(x,y,z)
				if blocks.get(cell,-1) != 2 or blocks.has(cell+Vector3i.UP):
					continue
				_cell_patches(points, Vector3(cell) + Vector3(0, 1.001, 0), rng)
	return grass_instance(points,hash(section))

# Sol plat : une pelouse par carré de 8 m (chacun masqué au loin séparément).
static func ground_grass(blocks: Dictionary, terrain_seed: int) -> Node3D:
	var lawn := Node3D.new()
	lawn.name = "Lawn"
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_seed
	for tile_x in range(-8, 8):
		for tile_z in range(-8, 8):
			var points: Array[Vector3] = []
			for x in range(tile_x * 8, tile_x * 8 + 8):
				for z in range(tile_z * 8, tile_z * 8 + 8):
					if not blocks.has(Vector3i(x, 0, z)):
						_cell_patches(points, Vector3(x, 0.001, z), rng)
			var tile := grass_instance(points, terrain_seed + tile_x * 31 + tile_z)
			if tile != null:
				lawn.add_child(tile)
	return lawn
