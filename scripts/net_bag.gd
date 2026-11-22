extends RefCounted
# 0.0.8.21 (#207, demandes de l'utilisateur) : modèle 3D du sac en filet (posé au sol, porté à l'épaule en vue F4), fait
# dans Blender par script (sources_blender/sac/generer_sac.py) : mailles nouées en cordelette, bretelle. À sa vraie taille
# (environ 35 cm de haut une fois plein, à plat au sol : base à y = 0). Le modèle porté (WORN) pend, bretelle en haut.
# Sans le fichier (tests sans fenêtre), une forme simple de remplacement.
const LYING := "res://assets/items/sac_filet.glb"
const WORN := "res://assets/items/sac_filet_porte.glb"
const COLOR := Color("#b9a66c")

static var _meshes := {}

static func mesh(worn: bool = false) -> Mesh:
	var path := WORN if worn else LYING
	if _meshes.has(path):
		return _meshes[path]
	var found: Mesh = null
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		if scene != null:
			var root := scene.instantiate()
			found = _first_mesh(root)
			root.free()
	if found == null:
		var shape := SphereMesh.new()
		shape.radius = 0.16
		shape.height = 0.1 if not worn else 0.34
		shape.radial_segments = 12
		shape.rings = 6
		var paint := StandardMaterial3D.new()
		paint.albedo_color = COLOR
		paint.roughness = 0.95
		shape.material = paint
		found = shape
	_meshes[path] = found
	return found

static func _first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null
