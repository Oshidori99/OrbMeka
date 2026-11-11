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
const NEWS_VERSION := "0.0.6.13"
const NEWS_TEXT := "Nouveau : des forêts !
Pinèdes, feuillus, lisières et clairières."

# 0.0.3.25 : les trois nouveautés de 0.0.3.23 en aller-retour au-dessus de l'herbe libre, devant la place
# de sable et pierre (sous le panneau des menus, vers la droite), chacune sur sa rangée.
# 0.0.4.5 (gardé ensuite) : elles volent, montent et descendent en avançant (FLY_LOW à FLY_HIGH, cycle FLY_CYCLE s,
# décalé par rangée). Pas encore d'animation de vol : le modèle glisse, tourné vers où il va.
const NEWS_RUNNERS := [["fox", ""], ["rabbit", ""]]
const NEWS_Z := [6.3, 7.1]
const RUN_FROM := 5.4
const RUN_TO := 9.2
const RUN_SPEEDS := [3.0, 2.8]
# 0.0.4.2 et suivantes : le renard (première rangée) accélère peu à peu jusqu'à FOX_TOP puis ralentit,
# comme ↑ puis ↓ maintenus ; cycle de FOX_CYCLE secondes.
const FOX_TOP := 7.5
const FOX_CYCLE := 6.0
var travelled_by := [3.1, 6.2]
const GROUND_TOP := 0.0
const NEWS_HEIGHT := 1
const FLY_LOW := 0.6
const FLY_HIGH := 3.6
const FLY_CYCLE := 5.0
const Trees = preload("res://scripts/trees.gd")
# [espèce, taille 1 à 5, place, rotation]
const NEWS_TREES := [[2, 3, Vector2(2.6, 9.6), 0.4], [3, 2, Vector2(10.6, 3.2), 1.9], [0, 2, Vector2(2.2, 3.6), 3.1]]
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
	# 0.0.6.9 : un pommier, un noisetier et un jeune pommier autour de la plage (arbres du jeu, trees.gd).
	# Comme dans le jeu, seulement sur l'herbe : chaque arbre prend le coin d'herbe le plus proche de sa place.
	for tree in NEWS_TREES:
		var spot := _grass_near(tree[2])
		if spot == Vector2.INF:
			continue
		var body := Trees.tree_body(tree[0], tree[1])
		body.position = Vector3(spot.x, terrain.height_at(spot.x, spot.y) - 0.05, spot.y)
		body.rotation.y = tree[3]
		add_child(body)
	_animate_news(0.0)

func _grass_near(wanted: Vector2) -> Vector2:
	for ring in range(0, 25):
		for step in range(maxi(1, ring * 6)):
			var at := wanted + Vector2.from_angle(TAU * step / maxi(1, ring * 6)) * ring * 0.5
			var column := Vector2i(roundi(at.x / 0.5), roundi(at.y / 0.5))
			if at.distance_to(BEACH_CENTER) > BEACH_RADIUS + 1.5 and not terrain.is_desert(at) and terrain.surface_kind(column) in [-1, Terrain.DIRT] and not terrain.muddy(column):
				return at
	return Vector2.INF

func _animate_news(delta: float) -> void:
	# Aller-retour décalé ; demi-tour net au bout de la place.
	var length := RUN_TO - RUN_FROM
	for index in range(runners.size()):
		var speed: float = RUN_SPEEDS[index]
		if index == 0:
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
# 0.0.6.5 : graine du monde d'essai de la version (T35, T36 en 0.0.6.6, T37 en 0.0.6.7, T38 en 0.0.6.8, T39 en 0.0.6.9, T40 en 0.0.6.10, T41 en 0.0.6.11, T42 en 0.0.6.12, T43 en 0.0.6.13 : monde standard créé dans la liste du joueur), vue depuis une hauteur.
const SCENE_SEED := 2114718997
# Point de vue : en hauteur (0.0.5.37), pour voir la crevasse ; à hauteur d'homme, le relief la cache.
# Il tourne lentement la tête ; la vitrine reste sur le côté, hors du panneau des menus.
const TOWER_CELL := Vector2i(12, 12)
const TOWER_HEIGHT := 14
# Plage de sable de la vitrine (même matière que dans le jeu), sous les personnages.
const BEACH_CENTER := Vector2(6.5, 6.0)
const BEACH_RADIUS := 3.2
const EYE_HEIGHT := 1.62
const SIDE_TURN := 0.42
const PAN_RANGE := 0.15
const PAN_SPEED := 0.12
const LOOK_DOWN := 0.42

var camera: Camera3D
var orb: MeshInstance3D
var elapsed := 0.0

func _ready() -> void:
	_setup_environment()
	_plan_ground()

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
	_continue_building()

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
	environment.fog_depth_begin = 80.0
	environment.fog_depth_end = 240.0
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

# 0.0.5.37 : construit petit à petit, les morceaux les plus proches d'abord : le menu s'affiche tout de suite et
# reste fluide (surtout sur le Web, qui n'a qu'un seul fil de calcul).
const BUILD_BUDGET_USEC := 6000
var build_queue: Array[Callable] = []
var ground_material: ShaderMaterial
var water_material: ShaderMaterial

func _plan_ground() -> void:
	terrain.setup(SCENE_SEED, [[Vector2(TOWER_CELL) + Vector2(1.5, 1.5), 5.0], [BEACH_CENTER, BEACH_RADIUS + 4.0]], Generation.defaults())
	ground_material = TerrainMaterials.surface(true)
	ground_material.set_shader_parameter("sand_center", BEACH_CENTER)
	ground_material.set_shader_parameter("sand_radius", BEACH_RADIUS)
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://shaders/water.gdshader")
	TerrainMaterials.density = "low"
	var near_low := Vector2i(SHOWCASE_ZONES.x, SHOWCASE_ZONES.x)
	var near_high := Vector2i(SHOWCASE_ZONES.y, SHOWCASE_ZONES.y)
	var eye := Vector2(TOWER_CELL) / 8.0
	var zones: Array = terrain.surface_zones(near_low, near_high).keys()
	zones.sort_custom(func(a: Vector3i, b: Vector3i): return Vector2(a.x, a.z).distance_to(eye) < Vector2(b.x, b.z).distance_to(eye))
	for zone: Vector3i in zones:
		build_queue.append(_build_zone.bind(zone))
	var near_area := Rect2(Vector2(near_low) * 8.0, Vector2(near_high - near_low + Vector2i.ONE) * 8.0)
	var tiles: Array[Vector2i] = []
	for x in range(FAR_TILES.position.x, FAR_TILES.end.x):
		for z in range(FAR_TILES.position.y, FAR_TILES.end.y):
			tiles.append(Vector2i(x, z))
	tiles.sort_custom(func(a: Vector2i, b: Vector2i): return Vector2(a).distance_to(eye / 4.0) < Vector2(b).distance_to(eye / 4.0))
	for tile in tiles:
		build_queue.append(_build_far_tile.bind(tile, near_area))
	for x in range(FAR_TILES.position.x * 4, FAR_TILES.end.x * 4):
		for z in range(FAR_TILES.position.y * 4, FAR_TILES.end.y * 4):
			build_queue.append(_build_water.bind(Vector2i(x, z)))
	# 0.0.5.5 : gazon réaliste ; seulement les carrés assez proches pour être vus (avant : 4 fois trop).
	var lawn_node := Node3D.new()
	lawn_node.name = "Lawn"
	add_child(lawn_node)
	var grass: Array[Vector2i] = []
	for x in range(-12, 12):
		for z in range(-12, 12):
			if (Vector2(x, z) + Vector2(0.5, 0.5)).distance_to(eye) * 8.0 < TerrainMaterials.GRASS_RANGE:
				grass.append(Vector2i(x, z))
	grass.sort_custom(func(a: Vector2i, b: Vector2i): return Vector2(a).distance_to(eye) < Vector2(b).distance_to(eye))
	for tile in grass:
		build_queue.append(_build_grass.bind(tile, lawn_node))

func _continue_building() -> void:
	var deadline := Time.get_ticks_usec() + BUILD_BUDGET_USEC
	while not build_queue.is_empty() and Time.get_ticks_usec() < deadline:
		build_queue.pop_front().call()

# Tout d'un coup (tests, captures).
func finish_building() -> void:
	while not build_queue.is_empty():
		build_queue.pop_front().call()

func _build_zone(zone: Vector3i) -> void:
	var surface: Array = terrain.zone_mesh(zone)
	if surface[0].is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = surface[0]
	arrays[Mesh.ARRAY_NORMAL] = surface[1]
	arrays[Mesh.ARRAY_COLOR] = surface[2]
	arrays[Mesh.ARRAY_TEX_UV] = surface[3]
	arrays[Mesh.ARRAY_TEX_UV2] = surface[4]
	arrays[Mesh.ARRAY_CUSTOM0] = surface[5]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = ground_material
	add_child(piece)

func _build_grass(tile: Vector2i, parent: Node3D) -> void:
	var node := TerrainMaterials.lawn_tile(tile, {}, SCENE_SEED, BEACH_CENTER, BEACH_RADIUS, func(at: Vector3): return terrain.muddy(Vector2i(roundi(at.x * 2.0), roundi(at.z * 2.0))) or terrain.is_desert(Vector2(at.x, at.z)), terrain.height_at)
	if node != null:
		parent.add_child(node)

# 0.0.5.23 : au loin, comme en partie : terrain simplifié (seulement vers où regarde la caméra) et eau des lacs.
const FarTerrain = preload("res://scripts/far_terrain.gd")
const FAR_TILES := Rect2i(-6, -4, 7, 6)

func _build_far_tile(tile: Vector2i, near: Rect2) -> void:
	var mesh := FarTerrain.build(terrain, tile, near.grow(-2.0), FarTerrain.CELL * 2.0)
	if mesh == null:
		return
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = FarTerrain.material()
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(piece)

func _build_water(zone: Vector2i) -> void:
	for lake in terrain.lakes_in_zone(zone):
		var water := MeshInstance3D.new()
		water.mesh = WorldRules.lake_water_mesh(terrain, lake)
		water.material_override = water_material
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		water.position = Vector3(lake.center.x, lake.level, lake.center.y)
		add_child(water)

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
