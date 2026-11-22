extends RefCounted
# 0.0.8.6 (#211, #145) : modèles des outils fabriqués, faits en code : le manche (branche, couleur de son écorce, sa
# longueur et son épaisseur), la tête taillée glissée dans la fente du haut (stone_heads.gd), et les tours du lien autour
# (ficelle : fins anneaux serrés ; liane : plus épais). En mètres, manche le long de +y. Un seul modèle par sorte d'outil
# (matières sur ses surfaces) : dessiné en série au sol.
const StoneHeads = preload("res://scripts/stone_heads.gd")
const Trees = preload("res://scripts/trees.gd")
const BIND_COLORS := [Color("#6f7d4c"), Color("#c2b27c"), Color("#8e9c52"), Color("#5d6b34")]
static var _meshes: Dictionary = {}
static var _bind_materials: Dictionary = {}

static func key_of(value: Dictionary) -> String:
	return "%s/%d/%d/%d/%d/%d/%d" % [value.get("objet", ""), int(value.get("pierre", 1)), int(value.get("taille", 4)), int(value.get("essence", 0)), roundi(float(value.get("longueur", 0.6)) * 20.0), int(value.get("lien", -1)), int(value.get("tours", 0))]

static func mesh(value: Dictionary) -> ArrayMesh:
	var key := key_of(value)
	if _meshes.has(key):
		return _meshes[key]
	var length := clampf(float(value.get("longueur", 0.6)), 0.3, 1.0)
	var radius := clampf(float(value.get("epaisseur", 3.5)), 1.5, 6.0) / 200.0
	var head_size: float = StoneHeads.scale_for("hache" if str(value.get("objet", "")).begins_with("hache") else "pioche", int(value.get("taille", 4)))
	var axe: bool = str(value.get("objet", "")).begins_with("hache")
	var made := ArrayMesh.new()
	# Manche.
	var handle := CylinderMesh.new()
	handle.top_radius = radius * 0.9
	handle.bottom_radius = radius
	handle.height = length
	handle.radial_segments = 8
	handle.rings = 1
	_add(made, handle.get_mesh_arrays(), Transform3D(Basis(), Vector3(0.0, length * 0.5, 0.0)), Trees.material(clampi(int(value.get("essence", 0)), 0, 3), "bark"))
	# Tête : en travers du haut du manche, le tranchant (ou la pointe) vers +x.
	var head: ArrayMesh = StoneHeads.mesh("hache" if axe else "pioche", 1.0)
	var head_basis := Basis.from_scale(Vector3.ONE * head_size)
	_add(made, head.surface_get_arrays(0), Transform3D(head_basis, Vector3(head_size * (0.35 if axe else 0.1), length - head_size * 0.35, 0.0)), StoneHeads.material(int(value.get("pierre", 1))))
	# Lien (0.0.8.9, demande de l'utilisateur : on ne voyait pas qu'il tenait la pierre) : des tours serrés autour du manche
	# juste sous la tête, et des bandes en croix par-dessus la tête, de chaque côté (un « X » par paire de tours).
	var turns := int(value.get("tours", 0))
	if value.has("lien") and turns > 0:
		var thick := 0.006 if int(value.lien) == 3 else 0.0035
		var ring := TorusMesh.new()
		ring.inner_radius = radius + 0.001
		ring.outer_radius = radius + thick * 2.0
		ring.rings = 10
		ring.ring_segments = 4
		var ring_arrays := ring.get_mesh_arrays()
		var band := BoxMesh.new()
		var head_y := length - head_size * 0.35
		var head_x := head_size * (0.35 if axe else 0.1)
		var half_depth := head_size * (0.24 if axe else 0.38)
		band.size = Vector3(thick * 1.4, head_size * 0.6, thick * 1.8)
		var band_arrays := band.get_mesh_arrays()
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Autour du manche, sous la tête.
		var wraps := maxi(2, turns / 2)
		for index in range(wraps):
			tool.append_from(_mesh_of(ring_arrays), 0, Transform3D(Basis(), Vector3(0.0, head_y - head_size * 0.45 - index * thick * 2.2, 0.0)))
		# En croix par-dessus la tête, des deux côtés (devant, derrière), autour du manche.
		var crosses := maxi(1, (turns + 1) / 2)
		for index in range(crosses):
			var shift := (index - (crosses - 1) * 0.5) * thick * 2.4
			for side in [1.0, -1.0]:
				for lean in [0.75, -0.75]:
					var place := Transform3D(Basis(Vector3.BACK, lean), Vector3(shift, head_y, side * (half_depth + thick)))
					tool.append_from(_mesh_of(band_arrays), 0, place)
		var bound := tool.commit()
		made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bound.surface_get_arrays(0))
		made.surface_set_material(made.get_surface_count() - 1, bind_material(int(value.lien)))
	_meshes[key] = made
	return made

static func _mesh_of(arrays: Array) -> ArrayMesh:
	var single := ArrayMesh.new()
	single.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return single

static func _add(made: ArrayMesh, arrays: Array, place: Transform3D, look: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.append_from(_mesh_of(arrays), 0, place)
	var placed := tool.commit()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, placed.surface_get_arrays(0))
	made.surface_set_material(made.get_surface_count() - 1, look)

static func bind_material(bind: int) -> StandardMaterial3D:
	var key := clampi(bind, 0, BIND_COLORS.size() - 1)
	if not _bind_materials.has(key):
		var made := StandardMaterial3D.new()
		made.albedo_color = BIND_COLORS[key]
		made.roughness = 0.95
		_bind_materials[key] = made
	return _bind_materials[key]
