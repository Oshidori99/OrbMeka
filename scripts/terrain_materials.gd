extends RefCounted
# Original world-space procedural materials; no imported bitmap or save-data change.
const SURFACE = preload("res://shaders/terrain_surface.gdshader")
static var _tuft: ArrayMesh
static var _leaf: StandardMaterial3D

static func surface(ground := false, dirt := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE
	material.set_shader_parameter("ground_surface",ground)
	material.set_shader_parameter("dirt_surface",dirt)
	return material

static func grass_mesh() -> ArrayMesh:
	if _tuft != null:
		return _tuft
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(5):
		var angle := index*2.4
		var width := Vector3(cos(angle),0,sin(angle))*0.007
		var base := Vector3(sin(index*4.1),0,cos(index*3.3))*0.027
		var tip := base+Vector3(cos(angle)*0.035,0.10+index*0.021,sin(angle)*0.035)
		for point in [base-width,tip,base+width]:
			tool.set_normal(Vector3(0.15,0.96,0.22).normalized())
			tool.set_color(Color(0.26+index*0.018,0.34+index*0.012,0.08))
			tool.add_vertex(point)
	_tuft = tool.commit()
	return _tuft

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
		var size := rng.randf_range(0.65,1.15)
		multi.set_instance_transform(index,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),points[index]))
		var tint := rng.randf_range(0.7,1.1)
		multi.set_instance_color(index,Color(tint,tint,tint,1))
	node.multimesh = multi
	if _leaf == null:
		_leaf = StandardMaterial3D.new()
		_leaf.vertex_color_use_as_albedo = true
		_leaf.roughness = 1.0
		_leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = _leaf
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 35.0
	node.visibility_range_end_margin = 5.0
	return node

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
				for index in range(4):
					points.append(Vector3(cell)+Vector3(rng.randf_range(0.08,0.92),1.002,rng.randf_range(0.08,0.92)))
	return grass_instance(points,hash(section))

static func ground_grass(blocks: Dictionary, terrain_seed: int) -> MultiMeshInstance3D:
	var points: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_seed
	for x in range(-24,25):
		for z in range(-24,25):
			if blocks.has(Vector3i(x,0,z)) or rng.randf() < 0.35:
				continue
			points.append(Vector3(x+rng.randf(),0.002,z+rng.randf()))
	return grass_instance(points,terrain_seed)
