extends Node3D
# Fond 3D de l'accueil : un petit monde en blocs, généré en code, avec une caméra qui tourne lentement.
#
# ===== VITRINE DE LA VERSION (à modifier à chaque mise à jour) =====
# 1. NEWS_VERSION et NEWS_TEXT : le bandeau « Nouveau » affiché sous la version, à l'accueil.
# 2. _build_news() : la construction 3D qui met en scène la nouveauté, au centre du petit monde.
#    _animate_news(delta) l'anime (vide si rien ne bouge).
# Le reste du fichier (sol, collines, ciel, caméra) ne change pas d'une version à l'autre.
const NEWS_VERSION := "0.0.2.12"
const NEWS_TEXT := "Nouveau : menus Orbe violet, pause transparente,\nfenêtre redimensionnable à toutes les tailles."

# 0.0.2.12 : un cadre de fenêtre en blocs qui s'élargit et se resserre pas à pas
# (fenêtre redimensionnable), avec un panneau de menu violet et ses boutons sable.
const FRAME_HEIGHT := 6
const FRAME_MIN_WIDTH := 5
const FRAME_MAX_WIDTH := 11
var frame_width := 0
var frame_blocks: MultiMeshInstance3D
var frame_pane: MeshInstance3D
var frame_buttons: Array[MeshInstance3D] = []

func _build_news() -> void:
	frame_blocks = _multimesh(STONE)
	add_child(frame_blocks)
	frame_pane = MeshInstance3D.new()
	frame_pane.mesh = BoxMesh.new()
	frame_pane.material_override = _material(Color(0.36, 0.2, 0.58, 0.72), 0.35)
	frame_pane.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	add_child(frame_pane)
	for index in range(3):
		var button := MeshInstance3D.new()
		button.mesh = BoxMesh.new()
		button.material_override = materials[SAND]
		add_child(button)
		frame_buttons.append(button)
	_set_frame_width(FRAME_MIN_WIDTH)

func _animate_news(_delta: float) -> void:
	var wave := sin(elapsed * 0.7) * 0.5 + 0.5
	_set_frame_width(FRAME_MIN_WIDTH + 2 * roundi(wave * (FRAME_MAX_WIDTH - FRAME_MIN_WIDTH) / 2.0))

func _set_frame_width(width: int) -> void:
	if width == frame_width:
		return
	frame_width = width
	var half := width / 2
	var cells: Array[Vector3i] = []
	for x in range(-half, half + 1):
		for y in range(FRAME_HEIGHT):
			if x == -half or x == half or y == 0 or y == FRAME_HEIGHT - 1:
				cells.append(Vector3i(x, y, -1))
	_fill_multimesh(frame_blocks, cells)
	var inner := float(width - 2)
	frame_pane.mesh.size = Vector3(inner, FRAME_HEIGHT - 2, 0.2)
	frame_pane.position = Vector3(0.5, FRAME_HEIGHT / 2.0, -0.5)
	for index in range(frame_buttons.size()):
		frame_buttons[index].mesh.size = Vector3(maxf(1.0, inner * 0.6), 0.5, 0.25)
		frame_buttons[index].position = Vector3(0.5, FRAME_HEIGHT - 2.0 - index * 1.0, -0.3)
# ===== FIN DE LA VITRINE =====

const Terrain = preload("res://scripts/terrain_generator.gd")
const WorldRules = preload("res://scripts/world.gd")
const SAND := 0
const STONE := 1
const DIRT := 2
const SCENE_SEED := 20612
const ORBIT_RADIUS := 18.0
const ORBIT_HEIGHT := 10.0
# Décalage de visée : la vitrine apparaît sur le côté, hors du panneau des menus.
const SIDE_TURN := 0.55
const ORBIT_SPEED := 0.07

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
	orb.position.y = FRAME_HEIGHT + 1.6 + sin(elapsed * 1.3) * 0.25
	_animate_news(delta)

func _place_camera() -> void:
	var angle := elapsed * ORBIT_SPEED + 0.6
	camera.position = Vector3(sin(angle) * ORBIT_RADIUS, ORBIT_HEIGHT, cos(angle) * ORBIT_RADIUS)
	camera.look_at(Vector3(0.5, 3.0, -0.5))
	camera.rotate_object_local(Vector3.UP, SIDE_TURN)

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
	orb.position = Vector3(0.5, FRAME_HEIGHT + 1.6, -0.5)
	add_child(orb)
