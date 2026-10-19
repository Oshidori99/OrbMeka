extends Node3D
# Fond 3D de l'accueil : un petit monde en blocs, généré en code, avec une caméra qui tourne lentement.
# Règle : n'y montrer que ce qui existe déjà dans le jeu (blocs Sable, Pierre, Terre, sol, collines, ciel).
# Les idées pas encore dans le jeu sont gardées en image dans docs/idees/.
#
# ===== VITRINE DE LA VERSION (à modifier à chaque mise à jour) =====
# 1. NEWS_VERSION et NEWS_TEXT : le bandeau « Nouveau » affiché sous la version, à l'accueil.
# 2. _build_news() : la construction 3D qui met en scène la nouveauté, au centre du petit monde.
#    _animate_news(delta) l'anime (vide si rien ne bouge).
# Le reste du fichier (sol, collines, ciel, caméra) ne change pas d'une version à l'autre.
const NEWS_VERSION := "0.0.3.7"
const NEWS_TEXT := "Nouveau : barres de réglage dans Paramètres,
interrupteur on/off pour la profondeur des menus."

# 0.0.3.1 à 0.0.3.7 : réglages de menus, sans scène 3D propre : les sauteurs de la 0.0.3 restent en vitrine.
# 0.0.3 : deux sauteurs (deux blocs de pierre, taille du joueur) côte à côte.
# À gauche, sur la pierre, le monde par défaut : saut normal. À droite, sur le sable,
# le monde développeur : attributs réglés, saut plus haut.
const NEWS_HEIGHT := 3
const PAD_X := [-3, 2]
const PAD_KINDS := [STONE, SAND]
const JUMP_HEIGHTS := [1.2, 3.0]
const JUMP_PERIOD := 1.6
var pads: Array[MultiMeshInstance3D] = []
var jumpers: Array[MultiMeshInstance3D] = []
var jumper_heights: Array[float] = [0.0, 0.0]

func _build_news() -> void:
	for index in range(2):
		var pad := _multimesh(PAD_KINDS[index])
		add_child(pad)
		var cells: Array[Vector3i] = []
		for x in range(PAD_X[index], PAD_X[index] + 2):
			for z in range(-2, 0):
				cells.append(Vector3i(x, 0, z))
		_fill_multimesh(pad, cells)
		pads.append(pad)
		var jumper := _multimesh(STONE)
		add_child(jumper)
		jumper.multimesh.instance_count = 2
		jumpers.append(jumper)
	_place_jumpers()

func _animate_news(_delta: float) -> void:
	# Même rythme pour les deux ; seule la hauteur du saut change.
	var phase := fmod(elapsed, JUMP_PERIOD) / JUMP_PERIOD
	for index in range(2):
		jumper_heights[index] = JUMP_HEIGHTS[index] * 4.0 * phase * (1.0 - phase)
	_place_jumpers()

func _place_jumpers() -> void:
	for index in range(2):
		for y in range(2):
			jumpers[index].multimesh.set_instance_transform(y, Transform3D(Basis(), Vector3(PAD_X[index] + 1.0, y + 1.5 + jumper_heights[index], -1.0)))
# ===== FIN DE LA VITRINE =====

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
