extends Node3D
# Fond 3D de l'accueil : un petit monde (0.0.5.18 : collines du jeu), généré en code, avec une caméra qui tourne lentement.
# Règle : n'y montrer que ce qui existe déjà dans le jeu (collines, gazon, plage de sable, ciel,
# personnages du menu Personnage). Les idées pas encore dans le jeu sont gardées en image dans docs/idees/.
#
# ===== VITRINE DE LA VERSION (à modifier à chaque mise à jour) =====
# 1. NEWS_VERSION et NEWS_TEXT : le bandeau « Nouveau » affiché sous la version, à l'accueil.
# 2. _build_news() : la construction 3D qui met en scène la nouveauté, au centre du petit monde.
#    _animate_news(delta) l'anime (vide si rien ne bouge).
# Règle (0.0.3.22, demandée par l'utilisateur) : les personnages du menu Personnage sont mis en scène.
# Depuis 0.0.3.23 (30 personnages avec les peaux, trop pour la vitrine), on n'en montre que
# 2 ou 3, choisis parmi les nouveautés : liste NEWS_RUNNERS ([id, peau], peau vide pour un animal).
# Chacun prend son modèle Blender, sinon une forme simple (character_model.gd, partagé avec le jeu).
# Le reste du fichier (sol, gazon, plage, ciel, caméra) ne change pas d'une version à l'autre.
const NEWS_VERSION := "0.0.5.21"
const NEWS_TEXT := "Nouveau : grands lacs, boue et argile grise !
Bords irréguliers, grands déserts seulement."

# 0.0.3.25 : les trois nouveautés de 0.0.3.23 en aller-retour au-dessus de l'herbe libre, devant la place
# de sable et pierre (sous le panneau des menus, vers la droite), chacune sur sa rangée.
# 0.0.4.5 (gardé ensuite) : elles volent, montent et descendent en avançant (FLY_LOW à FLY_HIGH, cycle FLY_CYCLE s,
# décalé par rangée). Pas encore d'animation de vol : le modèle glisse, tourné vers où il va.
const NEWS_RUNNERS := [["girl9", "brown"], ["fox", ""], ["rabbit", ""]]
const NEWS_Z := [5.5, 6.3, 7.1]
const RUN_FROM := 5.4
const RUN_TO := 9.2
const RUN_SPEEDS := [2.6, 3.0, 2.8]
# 0.0.4.2 et suivantes : le renard (rangée du milieu) accélère peu à peu jusqu'à FOX_TOP puis ralentit,
# comme ↑ puis ↓ maintenus ; cycle de FOX_CYCLE secondes.
const FOX_TOP := 7.5
const FOX_CYCLE := 6.0
var travelled_by := [0.0, 3.1, 6.2]
const GROUND_TOP := 0.0
const NEWS_HEIGHT := 1
const FLY_LOW := 0.6
const FLY_HIGH := 3.6
const FLY_CYCLE := 5.0
const CharacterModel = preload("res://scripts/character_model.gd")
var runners: Array[Node3D] = []
var runner_ids: Array[String] = []

func _build_news() -> void:
	for index in range(NEWS_RUNNERS.size()):
		var id: String = NEWS_RUNNERS[index][0]
		var skin: String = NEWS_RUNNERS[index][1]
		var runner := CharacterModel.build(id, skin)
		runner.name = "Runner_%s_%s" % [id, skin] if not skin.is_empty() else "Runner_" + id
		add_child(runner)
		runners.append(runner)
		runner_ids.append(id)
	_animate_news(0.0)

func _animate_news(delta: float) -> void:
	# Aller-retour décalé ; demi-tour net au bout de la place.
	var length := RUN_TO - RUN_FROM
	for index in range(runners.size()):
		var speed: float = RUN_SPEEDS[index]
		if index == 1:
			speed = lerpf(speed, FOX_TOP, pingpong(elapsed * 2.0 / FOX_CYCLE, 1.0))
		travelled_by[index] += delta * speed
		var travelled: float = travelled_by[index]
		var x := RUN_FROM + pingpong(travelled, length)
		var forward := fmod(travelled, 2.0 * length) < length
		var height := FLY_LOW + (FLY_HIGH - FLY_LOW) * (0.5 - 0.5 * cos(TAU * (elapsed / FLY_CYCLE + index / 3.0)))
		runners[index].position = Vector3(x, GROUND_TOP + height, NEWS_Z[index])
		runners[index].rotation.y = PI / 2.0 if forward else -PI / 2.0

# ===== FIN DE LA VITRINE =====

const CharacterPreview = preload("res://scripts/character_preview.gd")

const TerrainMaterials = preload("res://scripts/terrain_materials.gd")
const WorldRules = preload("res://scripts/world.gd")
const SCENE_SEED := 20612
# Point de vue : un joueur debout sur le sol plat (0.0.5.5 : plus de tour de pierre).
# Il tourne lentement la tête ; la vitrine reste sur le côté, hors du panneau des menus.
const TOWER_CELL := Vector2i(12, 12)
const TOWER_HEIGHT := 0
# Plage de sable de la vitrine (même matière que dans le jeu), sous les personnages.
const BEACH_CENTER := Vector2(6.5, 6.0)
const BEACH_RADIUS := 3.2
const EYE_HEIGHT := 1.62
const SIDE_TURN := 0.42
const PAN_RANGE := 0.15
const PAN_SPEED := 0.12
const LOOK_DOWN := 0.12

var camera: Camera3D
var orb: MeshInstance3D
var elapsed := 0.0

func _ready() -> void:
	_setup_environment()
	_build_ground()
	_build_scene()
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

func _setup_environment() -> void:
	# Ciel de fin de journée, légèrement violet pour s'accorder aux menus.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#4f63c4")
	sky_material.sky_horizon_color = Color("#e7c3d6")
	sky_material.ground_horizon_color = Color("#e7c3d6")
	sky_material.ground_bottom_color = Color("#e7c3d6")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#e6dcff")
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# 0.0.5.18 : brume au bord du terrain de la vitrine (comme la distance d'affichage en partie).
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color("#e7c3d6")
	environment.fog_depth_begin = 30.0
	environment.fog_depth_end = 58.0
	environment.fog_sky_affect = 0.0
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_color = Color("#fff0d8")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	# 0.0.4.17 : version Web (rendu Compatibility) : lumière baissée, comme en partie.
	WorldRules.apply_compat_light(environment, sun)
	add_child(sun)

# 0.0.5.18 : sol de la vitrine comme en partie : terrain lisse de la génération standard (collines douces,
# parfois un désert), plat sous la caméra et la plage des personnages ; herbe posée dessus ; brume au loin.
const Terrain = preload("res://scripts/smooth_terrain.gd")
const Generation = preload("res://scripts/world_generation.gd")
const SHOWCASE_ZONES := Vector2i(-5, 2)
var terrain := Terrain.new()

func _build_ground() -> void:
	terrain.setup(SCENE_SEED, [[Vector2(TOWER_CELL) + Vector2(1.5, 1.5), 5.0], [BEACH_CENTER, BEACH_RADIUS + 4.0]], Generation.defaults())
	var ground_material := TerrainMaterials.surface(true)
	ground_material.set_shader_parameter("sand_center", BEACH_CENTER)
	ground_material.set_shader_parameter("sand_radius", BEACH_RADIUS)
	for x in range(SHOWCASE_ZONES.x, SHOWCASE_ZONES.y + 1):
		for z in range(SHOWCASE_ZONES.x, SHOWCASE_ZONES.y + 1):
			for y in [-1, 0]:
				var surface: Array = terrain.zone_mesh(Vector3i(x, y, z))
				if surface[0].is_empty():
					continue
				var arrays := []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = surface[0]
				arrays[Mesh.ARRAY_NORMAL] = surface[1]
				arrays[Mesh.ARRAY_COLOR] = surface[2]
				arrays[Mesh.ARRAY_TEX_UV] = surface[3]
				var mesh := ArrayMesh.new()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				var piece := MeshInstance3D.new()
				piece.mesh = mesh
				piece.material_override = ground_material
				add_child(piece)

func _build_scene() -> void:
	# 0.0.5.5 : gazon réaliste et plage de sable plate ; 0.0.5.18 : sur les collines (pas dans les déserts).
	# Herbe moins dense qu'en partie : l'accueil reste fluide derrière les menus flous.
	TerrainMaterials.density = "low"
	var lawn := TerrainMaterials.ground_grass({}, SCENE_SEED, BEACH_CENTER, BEACH_RADIUS, func(at: Vector3): return terrain.is_desert(Vector2(at.x, at.z)), terrain.height_at)
	add_child(lawn)


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
