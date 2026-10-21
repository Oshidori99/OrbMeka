extends Node3D
# Fond 3D de l'accueil : un petit monde en blocs, généré en code, avec une caméra qui tourne lentement.
# Règle : n'y montrer que ce qui existe déjà dans le jeu (blocs Sable, Pierre, Terre, sol, collines, ciel,
# personnages du menu Personnage). Les idées pas encore dans le jeu sont gardées en image dans docs/idees/.
#
# ===== VITRINE DE LA VERSION (à modifier à chaque mise à jour) =====
# 1. NEWS_VERSION et NEWS_TEXT : le bandeau « Nouveau » affiché sous la version, à l'accueil.
# 2. _build_news() : la construction 3D qui met en scène la nouveauté, au centre du petit monde.
#    _animate_news(delta) l'anime (vide si rien ne bouge).
# Règle (0.0.3.22, demandée par l'utilisateur) : les personnages du menu Personnage sautent, chacun sur
# son bloc. Depuis 0.0.3.23 (30 personnages avec les peaux, trop pour la vitrine), on n'en montre que
# 2 ou 3, choisis parmi les nouveautés : liste NEWS_JUMPERS ([id, peau], peau vide pour un animal).
# Chacun prend son modèle Blender (CharacterPreview.MODELS, ou MODELS ci-dessous), sinon une forme simple.
# Le reste du fichier (sol, collines, ciel, caméra) ne change pas d'une version à l'autre.
const NEWS_VERSION := "0.0.3.23"
const NEWS_TEXT := "Nouveau : enfants de 9 et 14 ans, écureuil, renard, tortue
et lapin bleu, en 3D (Paramètres → Personnage)."

# 0.0.3.23 : trois nouveautés sautent sur leur bloc, devant l'orbe.
const NEWS_JUMPERS := [["girl9", "brown"], ["fox", ""], ["rabbit", ""]]
const NEWS_X := [1, 3, 5]
const NEWS_HEIGHT := 3
const HUMAN_JUMP := 1.2
const HUMAN_PERIOD := 1.6
const CAT_JUMP := 0.7
const CAT_PERIOD := 1.0
const CAT_SCALE := 1.4
var pads: Array[MultiMeshInstance3D] = []
var jumpers: Array[Node3D] = []
var jumper_ids: Array[String] = []

func _build_news() -> void:
	var eye := Vector3(TOWER_CELL.x + 1.5, 0, TOWER_CELL.y + 1.5)
	var stone_cells: Array[Vector3i] = []
	var sand_cells: Array[Vector3i] = []
	for index in range(NEWS_JUMPERS.size()):
		var id: String = NEWS_JUMPERS[index][0]
		var skin: String = NEWS_JUMPERS[index][1]
		var x: int = NEWS_X[index]
		(sand_cells if skin.is_empty() else stone_cells).append(Vector3i(x, 0, 0))
		var jumper := _character_model(id, skin)
		jumper.name = "Jumper_%s_%s" % [id, skin] if not skin.is_empty() else "Jumper_" + id
		jumper.position = Vector3(x + 0.5, 1.0, 0.5)
		# Face vers le point de vue (la tour).
		jumper.rotation.y = atan2(eye.x - jumper.position.x, eye.z - jumper.position.z)
		add_child(jumper)
		jumpers.append(jumper)
		jumper_ids.append(id)
	for kind_cells in [[STONE, stone_cells], [SAND, sand_cells]]:
		var pad := _multimesh(kind_cells[0])
		add_child(pad)
		_fill_multimesh(pad, kind_cells[1])
		pads.append(pad)

func _animate_news(_delta: float) -> void:
	# Sauts décalés ; les animaux font de petits bonds plus rapides et s'écrasent un peu en retombant.
	for index in range(jumpers.size()):
		var cat := not CharacterPreview.is_human(jumper_ids[index])
		var period := CAT_PERIOD if cat else HUMAN_PERIOD
		var phase: float = fmod(elapsed + index * 0.37, period) / period
		jumpers[index].position.y = 1.0 + (CAT_JUMP if cat else HUMAN_JUMP) * 4.0 * phase * (1.0 - phase)
		if cat:
			var squash := 1.0 - 0.12 * maxf(0.0, 1.0 - phase * 8.0)
			jumpers[index].scale = Vector3(2.0 - squash, squash, 2.0 - squash) * CAT_SCALE

func _character_model(id: String, skin: String) -> Node3D:
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
func _blender_model(id: String, skin: String) -> Node3D:
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
func _part(parent: Node3D, mesh: Mesh, color: Color, at: Vector3, stretch: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = _material(color, 0.8)
	part.position = at
	part.scale = stretch
	parent.add_child(part)
	return part

func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box

func _ball(radius: float) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	return sphere

# Humain du menu Personnage (character_preview.gd) : tête ronde, corps, bras couleur de peau, jambes.
func _human_model(id: String, skin: String) -> Node3D:
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
func _brioche_model() -> Node3D:
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
func _cat_model() -> Node3D:
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
# ===== FIN DE LA VITRINE =====

const CharacterPreview = preload("res://scripts/character_preview.gd")

const Terrain = preload("res://scripts/terrain_generator.gd")
const WorldRules = preload("res://scripts/world.gd")
const SAND := 0
const STONE := 1
const DIRT := 2
const SCENE_SEED := 20612
# Point de vue : un joueur debout sur une tour de pierre (on ne vole pas dans le jeu).
# Il tourne lentement la tête ; la vitrine reste sur le côté, hors du panneau des menus.
const TOWER_CELL := Vector2i(12, 12)
const TOWER_HEIGHT := 4
const EYE_HEIGHT := 1.62
const SIDE_TURN := 0.42
const PAN_RANGE := 0.15
const PAN_SPEED := 0.12
const LOOK_DOWN := 0.2

var camera: Camera3D
var materials: Array[StandardMaterial3D] = []
var orb: MeshInstance3D
var elapsed := 0.0

func _ready() -> void:
	for color in WorldRules.BLOCK_COLORS:
		materials.append(_material(color, 0.85))
	_setup_environment()
	_build_ground()
	_build_hills()
	_build_orb()
	_build_news()
	camera = Camera3D.new()
	camera.fov = 60
	add_child(camera)
	_place_camera()

func _process(delta: float) -> void:
	elapsed += delta
	_place_camera()
	orb.position.y = NEWS_HEIGHT + 1.6 + sin(elapsed * 1.3) * 0.25
	_animate_news(delta)

func _place_camera() -> void:
	camera.position = Vector3(TOWER_CELL.x + 1.5, TOWER_HEIGHT + EYE_HEIGHT, TOWER_CELL.y + 1.5)
	camera.look_at(Vector3(0.5, camera.position.y, -0.5))
	camera.rotate_y(SIDE_TURN + sin(elapsed * PAN_SPEED) * PAN_RANGE)
	camera.rotate_object_local(Vector3.RIGHT, -LOOK_DOWN)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _multimesh(kind: int) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = MultiMesh.new()
	instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	instance.multimesh.mesh = BoxMesh.new()
	instance.material_override = materials[kind]
	return instance

func _fill_multimesh(instance: MultiMeshInstance3D, cells: Array[Vector3i]) -> void:
	instance.multimesh.instance_count = cells.size()
	for index in range(cells.size()):
		instance.multimesh.set_instance_transform(index, Transform3D(Basis(), Vector3(cells[index]) + Vector3.ONE * 0.5))

func _setup_environment() -> void:
	# Ciel de fin de journée, légèrement violet pour s'accorder aux menus.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#4f63c4")
	sky_material.sky_horizon_color = Color("#e7c3d6")
	sky_material.ground_horizon_color = Color("#e7c3d6")
	sky_material.ground_bottom_color = Color("#759a65")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#e6dcff")
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_color = Color("#fff0d8")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(240, 1, 240)
	ground.mesh = box
	ground.position = Vector3(0, -0.5, 0)
	ground.material_override = _material(Color("#759a65"), 1.0)
	add_child(ground)

func _build_hills() -> void:
	# Mêmes collines que dans le jeu (graine fixe), plus une petite place en sable et pierre.
	var dirt: Array[Vector3i] = Terrain.generate_cells(SCENE_SEED)
	var sand: Array[Vector3i] = []
	var stone: Array[Vector3i] = []
	for x in range(-5, 6):
		for z in range(1, 5):
			if (x + z) % 2 == 0:
				sand.append(Vector3i(x, 0, z))
			else:
				stone.append(Vector3i(x, 0, z))
	for y in range(1, 4):
		stone.append(Vector3i(-4, y - 1, 7))
	for x in range(2, 5):
		for y in range(x - 1):
			sand.append(Vector3i(x, y, -4))
	for x in range(3):
		for z in range(3):
			for y in range(TOWER_HEIGHT):
				stone.append(Vector3i(TOWER_CELL.x + x, y, TOWER_CELL.y + z))
	for cells_kind in [[dirt, DIRT], [sand, SAND], [stone, STONE]]:
		var instance := _multimesh(cells_kind[1])
		add_child(instance)
		_fill_multimesh(instance, cells_kind[0])

func _build_orb() -> void:
	# L'orbe de OrbMeka : une sphère lumineuse qui flotte au-dessus de la vitrine.
	orb = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	orb.mesh = sphere
	var material := _material(Color("#b48cff"), 0.3)
	material.emission_enabled = true
	material.emission = Color("#9a6cff")
	material.emission_energy_multiplier = 1.6
	orb.material_override = material
	orb.position = Vector3(0.5, NEWS_HEIGHT + 1.6, -0.5)
	add_child(orb)
