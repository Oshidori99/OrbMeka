extends RefCounted
# Modèles 3D des personnages (0.0.3.26), partagés par la vitrine de l'accueil et le corps du joueur en jeu.
# Chacun prend son modèle Blender (CharacterPreview.MODELS, ou MODELS ci-dessous), sinon une forme simple.
# Le modèle regarde vers +Z, pieds à peu près à Y 0 ; les animaux sont agrandis (CAT_SCALE).

const CharacterPreview = preload("res://scripts/character_preview.gd")
const CAT_SCALE := 1.4

static func build(id: String, skin: String) -> Node3D:
	var data: Dictionary = CharacterPreview.CHARACTERS[id]
	if CharacterPreview.MODELS.has(id) or MODELS.has(id):
		return _blender_model(id, skin if not skin.is_empty() else "light")
	if data.get("lying", false):
		return _brioche_model()
	if data.get("plush", false):
		return _cat_model()
	return _human_model(id, skin if not skin.is_empty() else "light")

# Modèles détaillés faits dans Blender (sources_blender/personnages.blend), exportés en .glb.
# Les autres personnages gardent leurs volumes simples ci-dessous.
const MODELS := {
	"brioche": preload("res://assets/characters/brioche.glb"),
	"cat": preload("res://assets/characters/cat.glb"),
}

# La matière « Skin » du modèle prend la couleur de peau choisie ; les animaux sont agrandis.
static func _blender_model(id: String, skin: String) -> Node3D:
	var model := Node3D.new()
	var scene: Node3D = CharacterPreview.MODELS.get(id, MODELS.get(id)).instantiate()
	model.add_child(scene)
	if not CharacterPreview.is_human(id):
		model.scale = Vector3.ONE * CAT_SCALE
	var skin_material := _material(CharacterPreview.tone_color(skin), 0.6)
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.mesh.surface_get_material(surface)
			if material and material.resource_name == "Skin":
				mesh_instance.set_surface_override_material(surface, skin_material)
	return model

# Volume simple : boîte ou ellipsoïde (sphère étirée), couleur unie.
static func _part(parent: Node3D, mesh: Mesh, color: Color, at: Vector3, stretch: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = _material(color, 0.8)
	part.position = at
	part.scale = stretch
	parent.add_child(part)
	return part

static func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box

static func _ball(radius: float) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	return sphere

# Humain du menu Personnage (character_preview.gd) : tête ronde, corps, bras couleur de peau, jambes.
static func _human_model(id: String, skin: String) -> Node3D:
	var data: Dictionary = CharacterPreview.CHARACTERS[id]
	var skin_color := CharacterPreview.tone_color(skin)
	var u: float = 1.9 * data.height
	var model := Node3D.new()
	var legs := u * 0.37
	for side in [-1.0, 1.0]:
		_part(model, _box(Vector3(u * 0.13, legs, u * 0.14)), data.bottom, Vector3(side * u * 0.08, legs * 0.5, 0))
	var body_y := legs + u * 0.18
	_part(model, _box(Vector3(u * 0.32, u * 0.36, u * 0.18)), data.top, Vector3(0, body_y, 0))
	for side in [-1.0, 1.0]:
		_part(model, _box(Vector3(u * 0.07, u * 0.31, u * 0.08)), skin_color, Vector3(side * u * 0.2, body_y + u * 0.01, 0))
	var head_y := legs + u * 0.36 + u * 0.14
	var head := u * 0.13
	_part(model, _ball(head), skin_color, Vector3(0, head_y, 0))
	# Cheveux : calotte un peu plus grande, en arrière et au-dessus ; cheveux longs jusqu'aux épaules.
	_part(model, _ball(head * 1.05), data.hair, Vector3(0, head_y + head * 0.25, -head * 0.22))
	if data.long_hair:
		_part(model, _box(Vector3(head * 2.1, head * 2.0, head * 0.7)), data.hair, Vector3(0, head_y - head * 0.5, -head * 0.6))
	for side in [-1.0, 1.0]:
		_part(model, _ball(head * 0.13), Color("#1d1430"), Vector3(side * head * 0.35, head_y, head * 0.95))
	return model

# Brioche (character_preview.gd) : chat blanc couché, grosse tête « mochi », dos rond, oreilles
# lavande, joues pêche, couronne dorée avec orbes turquoise.
static func _brioche_model() -> Node3D:
	var data: Dictionary = CharacterPreview.CHARACTERS.brioche
	var model := Node3D.new()
	model.scale = Vector3.ONE * CAT_SCALE
	_part(model, _ball(1.0), data.back, Vector3(0.04, 0.2, -0.28), Vector3(0.3, 0.2, 0.32))
	_part(model, _ball(1.0), data.fur, Vector3(0, 0.25, 0.04), Vector3(0.4, 0.25, 0.32))
	for side in [-1.0, 1.0]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.1
		ear.height = 0.2
		var outer := _part(model, ear, data.fur, Vector3(side * 0.24, 0.5, 0.02))
		outer.rotation.z = -side * 0.35
		var inner := _part(model, ear, data.inner, Vector3(side * 0.235, 0.49, 0.06), Vector3(0.6, 0.7, 0.6))
		inner.rotation.z = -side * 0.35
		_part(model, _ball(1.0), data.eyes, Vector3(side * 0.1, 0.27, 0.34), Vector3(0.04, 0.055, 0.03))
		_part(model, _ball(1.0), data.cheeks, Vector3(side * 0.19, 0.2, 0.3), Vector3(0.05, 0.028, 0.03))
		_part(model, _ball(1.0), data.fur, Vector3(side * 0.16, 0.04, 0.3), Vector3(0.07, 0.04, 0.06))
	_part(model, _ball(0.018), Color("#f4a3b5"), Vector3(0, 0.22, 0.36))
	# Couronne inclinée : anneau doré, trois orbes turquoise.
	var ring := CylinderMesh.new()
	ring.top_radius = 0.09
	ring.bottom_radius = 0.08
	ring.height = 0.08
	var crown := _part(model, ring, data.crown, Vector3(-0.08, 0.51, 0.02))
	crown.rotation.z = 0.22
	for index in range(3):
		var angle := TAU * index / 3.0 + 0.5
		_part(model, _ball(0.022), data.orbs, Vector3(-0.08 + cos(angle) * 0.07, 0.57 - cos(angle) * 0.015, 0.02 + sin(angle) * 0.07))
	return model

# Chat peluche (character_preview.gd) : assis, grosse tête ronde, ventre clair, rayures sur le front,
# oreilles à intérieur rose, foulard violet, queue qui remonte.
static func _cat_model() -> Node3D:
	var data: Dictionary = CharacterPreview.CHARACTERS.cat
	var model := Node3D.new()
	model.scale = Vector3.ONE * CAT_SCALE
	_part(model, _ball(1.0), data.fur, Vector3(0, 0.15, 0), Vector3(0.22, 0.17, 0.2))
	_part(model, _ball(1.0), data.belly, Vector3(0, 0.15, 0.1), Vector3(0.13, 0.12, 0.12))
	var tail := _part(model, _box(Vector3(0.07, 0.28, 0.07)), data.fur, Vector3(0.2, 0.2, -0.12))
	tail.rotation.z = -0.4
	_part(model, _ball(0.045), data.stripes, Vector3(0.26, 0.34, -0.12))
	var scarf := CylinderMesh.new()
	scarf.top_radius = 0.17
	scarf.bottom_radius = 0.18
	scarf.height = 0.06
	_part(model, scarf, data.scarf, Vector3(0, 0.31, 0))
	var head_y := 0.52
	_part(model, _ball(1.0), data.fur, Vector3(0, head_y, 0), Vector3(0.27, 0.24, 0.24))
	for side in [-1.0, 1.0]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.09
		ear.height = 0.17
		var outer := _part(model, ear, data.fur, Vector3(side * 0.17, head_y + 0.22, 0))
		outer.rotation.z = -side * 0.3
		var inner := _part(model, ear, data.pink, Vector3(side * 0.165, head_y + 0.21, 0.04), Vector3(0.55, 0.7, 0.55))
		inner.rotation.z = -side * 0.3
		_part(model, _ball(1.0), data.eyes, Vector3(side * 0.1, head_y + 0.01, 0.21), Vector3(0.04, 0.055, 0.03))
		_part(model, _ball(1.0), data.pink, Vector3(side * 0.17, head_y - 0.08, 0.18), Vector3(0.04, 0.025, 0.03))
		_part(model, _ball(1.0), data.fur, Vector3(side * 0.09, 0.03, 0.15), Vector3(0.07, 0.04, 0.06))
	for offset in [-0.06, 0.0, 0.06]:
		_part(model, _box(Vector3(0.025, 0.07, 0.02)), data.stripes, Vector3(offset, head_y + 0.19, 0.12))
	_part(model, _ball(0.02), data.pink, Vector3(0, head_y - 0.05, 0.235))
	return model

static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
