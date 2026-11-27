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
const NEWS_VERSION := "0.0.8.53"
const NEWS_TEXT := "Nouveau : feu, torches et archet
en vrais modèles !"

# 0.0.3.25 : les nouveautés en aller-retour sur l'herbe libre, devant la place de sable et pierre (sous le panneau des
# menus, vers la droite), chacune sur sa rangée.
# 0.0.7.20 : au sol (avant : elles volaient, 0.0.4.5) ; le renard court, le lapin marche. Pas encore d'animation :
# le modèle glisse, tourné vers où il va.
const NEWS_RUNNERS := [["fox", ""], ["rabbit", ""]]
const NEWS_Z := [6.3, 7.1]
const RUN_FROM := 5.4
const RUN_TO := 9.2
const RUN_SPEEDS := [3.0, 1.4]
# 0.0.4.2 et suivantes : le renard (première rangée) accélère peu à peu jusqu'à FOX_TOP puis ralentit,
# comme ↑ puis ↓ maintenus ; cycle de FOX_CYCLE secondes.
const FOX_TOP := 7.5
const FOX_CYCLE := 6.0
var travelled_by := [3.1, 6.2]
const NEWS_HEIGHT := 1
const Trees = preload("res://scripts/trees.gd")
const CharacterModel = preload("res://scripts/character_model.gd")
var runners: Array[Node3D] = []
var runner_ids: Array[String] = []
var runner_ground: Array[float] = []

func _build_news() -> void:
	for index in range(NEWS_RUNNERS.size()):
		var id: String = NEWS_RUNNERS[index][0]
		var skin: String = NEWS_RUNNERS[index][1]
		var runner := CharacterModel.build(id, skin)
		runner.name = "Runner_%s_%s" % [id, skin] if not skin.is_empty() else "Runner_" + id
		add_child(runner)
		runners.append(runner)
		runner_ids.append(id)
		runner_ground.append(terrain.height_at((RUN_FROM + RUN_TO) * 0.5, NEWS_Z[index]))
	_animate_news(0.0)

# 0.0.7.20 : forêt de pins en fond (pins du jeu, trees.gd), seulement du côté que regarde la caméra, sur l'herbe.
# Dessinés en série (un dessin par modèle, MultiMesh) ; détaillés jusqu'à PINE_DETAIL de la caméra, simplifiés et sans
# ombre au-delà, jusqu'à PINE_FAR (dans la brume). Quatre modèles seulement (tailles 4 et 5, deux formes), un par image.
const PINE_COUNT := 120
# 0.0.7.23 : rendu Compatibility (Web, vieux PC) : moitié moins de pins, et pas de terrain lointain au-delà de la brume.
const PINE_COUNT_WEB := 60
static var WEB := RenderingServer.get_current_rendering_method() == "gl_compatibility"
const PINE_CLEAR := 11.0
const PINE_FAR := 110.0
const PINE_DETAIL := 25.0
const PINE_GAP := 3.2
const PINE_SIZES := [4, 5]
const PINE_FORMS := [0, 1]

func _plan_pines() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SCENE_SEED
	var eye := Vector2(camera.position.x, camera.position.z)
	var ahead := Vector2(-camera.basis.z.x, -camera.basis.z.z).normalized()
	var placed: Array[Vector2] = []
	var groups := {}
	for attempt in range(PINE_COUNT * 10):
		if placed.size() >= (PINE_COUNT_WEB if WEB else PINE_COUNT):
			break
		var at := BEACH_CENTER + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf_range(PINE_CLEAR * PINE_CLEAR, PINE_FAR * PINE_FAR))
		var size: int = PINE_SIZES[rng.randi() % PINE_SIZES.size()]
		var form: int = PINE_FORMS[rng.randi() % PINE_FORMS.size()]
		var turn := rng.randf() * TAU
		var grow := rng.randf_range(0.9, 1.1)
		if (at - eye).normalized().dot(ahead) < 0.25 or at.distance_to(eye) < 9.0 or not _grass_at(at):
			continue
		if placed.any(func(other: Vector2): return other.distance_to(at) < PINE_GAP):
			continue
		placed.append(at)
		var far := at.distance_to(eye) > PINE_DETAIL
		var key := [size, form, far]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * grow), Vector3(at.x, terrain.height_at(at.x, at.y) - 0.05, at.y)))
	for key in groups:
		build_queue.append(_build_pines.bind(key[0], key[1], key[2], groups[key]))

func _build_pines(size: int, form: int, far: bool, places: Array) -> void:
	var series := MultiMesh.new()
	series.transform_format = MultiMesh.TRANSFORM_3D
	series.mesh = Trees.mesh(Trees.PINE, size, far, form)
	series.instance_count = places.size()
	for index in range(places.size()):
		series.set_instance_transform(index, places[index])
	var node := MultiMeshInstance3D.new()
	node.name = "Pins"
	node.multimesh = series
	if far:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node, true)

func _grass_at(at: Vector2) -> bool:
	var column := Vector2i(roundi(at.x / 0.5), roundi(at.y / 0.5))
	return at.distance_to(BEACH_CENTER) > BEACH_RADIUS + 1.5 and not terrain.is_desert(at) and terrain.surface_kind(column) in [-1, Terrain.DIRT] and not terrain.muddy(column) and terrain.lake_at(at).is_empty()

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
		runners[index].position = Vector3(x, runner_ground[index], NEWS_Z[index])
		runners[index].rotation.y = PI / 2.0 if forward else -PI / 2.0

# ===== FIN DE LA VITRINE =====

const CharacterPreview = preload("res://scripts/character_preview.gd")

const TerrainMaterials = preload("res://scripts/terrain_materials.gd")
const WorldRules = preload("res://scripts/world.gd")
# 0.0.6.5 : graine du monde d'essai de la version (T35, T36 en 0.0.6.6, T37 en 0.0.6.7, T38 en 0.0.6.8, T39 en 0.0.6.9, T40 en 0.0.6.10, T41 en 0.0.6.11, T42 en 0.0.6.12, T43 en 0.0.6.13, T44 en 0.0.6.14, T45 en 0.0.6.15, T46 en 0.0.6.16, T47 en 0.0.6.17, T48 en 0.0.6.18, T49 en 0.0.6.19, T50 en 0.0.6.20, T51 en 0.0.6.21, T52 en 0.0.6.22, T53 en 0.0.6.23, T54 en 0.0.6.24 : monde standard créé dans la liste du joueur), vue depuis une hauteur.
const SCENE_SEED := 3652994865
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
	_build_orb()
	camera = Camera3D.new()
	camera.fov = 60
	add_child(camera)
	_place_camera()
	# 0.0.7.20 : le sol (graine préparée en petites étapes), les personnages et les pins après la première
	# image : l'accueil s'affiche d'abord (ciel, orbe, menus), le petit monde apparaît ensuite.
	build_queue.append(_plan_ground)

func _process(delta: float) -> void:
	elapsed += delta
	frame_usec = lerpf(frame_usec, delta * 1_000_000.0, 0.1)
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
	environment.fog_depth_begin = 60.0 if WEB else 80.0
	environment.fog_depth_end = 150.0 if WEB else 240.0
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
var frame_usec := 16_000.0
# 0.0.7.20 : durée d'une petite étape (graine, surface d'une zone).
const STEP_USEC := 3000
const SurfaceJob = preload("res://scripts/surface_job.gd")
var build_queue: Array[Callable] = []
var ground_material: ShaderMaterial
var water_material: ShaderMaterial

func _plan_ground() -> void:
	terrain.setup(SCENE_SEED, [[Vector2(TOWER_CELL) + Vector2(1.5, 1.5), 5.0], [BEACH_CENTER, BEACH_RADIUS + 4.0]], Generation.defaults(), false)
	ground_material = TerrainMaterials.surface(true)
	# 0.0.6.17 : le sol lit les minerais et la litière (CUSTOM0) ; pas les rochers ni les cailloux (rendu Web).
	ground_material.set_shader_parameter("terrain_layers", true)
	ground_material.set_shader_parameter("compat_look", RenderingServer.get_current_rendering_method() == "gl_compatibility")
	ground_material.set_shader_parameter("sand_center", BEACH_CENTER)
	ground_material.set_shader_parameter("sand_radius", BEACH_RADIUS)
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://shaders/water.gdshader")
	water_material.set_shader_parameter("tone", 0.85 if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 1.0)
	TerrainMaterials.density = "low"
	# 0.0.7.20 : montagnes, lacs, rivières, crevasses et grottes de la graine en petites étapes (avant : 1,4 s d'un coup).
	build_queue.push_front(_plan_zones)
	build_queue.push_front(_prepare_seed)

func _prepare_seed() -> void:
	if not terrain.prepare_step(STEP_USEC):
		build_queue.push_front(_prepare_seed)

func _plan_zones() -> void:
	var near_low := Vector2i(SHOWCASE_ZONES.x, SHOWCASE_ZONES.x)
	var near_high := Vector2i(SHOWCASE_ZONES.y, SHOWCASE_ZONES.y)
	var eye := Vector2(TOWER_CELL) / 8.0
	# 0.0.7.20 : colonne par colonne, les plus proches d'abord (avant : toutes d'un coup, 0,2 s) ; chaque colonne ajoute
	# ses zones à construire.
	var columns: Array[Vector2i] = []
	for x in range(near_low.x, near_high.x + 1):
		for z in range(near_low.y, near_high.y + 1):
			columns.append(Vector2i(x, z))
	columns.sort_custom(func(a: Vector2i, b: Vector2i): return Vector2(a).distance_to(eye) < Vector2(b).distance_to(eye))
	for column in columns:
		build_queue.append(_plan_column.bind(column))
	build_queue.append(_build_news)
	build_queue.append(_plan_pines)
	var near_area := Rect2(Vector2(near_low) * 8.0, Vector2(near_high - near_low + Vector2i.ONE) * 8.0)
	var tiles: Array[Vector2i] = []
	for x in range(far_tiles.position.x, far_tiles.end.x):
		for z in range(far_tiles.position.y, far_tiles.end.y):
			tiles.append(Vector2i(x, z))
	tiles.sort_custom(func(a: Vector2i, b: Vector2i): return Vector2(a).distance_to(eye / 4.0) < Vector2(b).distance_to(eye / 4.0))
	for tile in tiles:
		build_queue.append(_build_far_tile.bind(tile, near_area))
	for x in range(far_tiles.position.x * 4, far_tiles.end.x * 4):
		for z in range(far_tiles.position.y * 4, far_tiles.end.y * 4):
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

func _plan_column(column: Vector2i) -> void:
	for zone: Vector3i in terrain.surface_zones(column, column):
		build_queue.push_front(_build_zone.bind(zone))

func _continue_building() -> void:
	# 0.0.7.23 : sous 30 images par seconde (Web, PC bon marché), un quart de la durée de l'image (30 ms au plus) : à 8 images
	# par seconde, le petit monde mettait 60 à 75 s à se construire.
	var budget := BUILD_BUDGET_USEC if frame_usec < 33_000.0 else clampi(int(frame_usec * 0.25), BUILD_BUDGET_USEC, 30_000)
	var deadline := Time.get_ticks_usec() + budget
	while not build_queue.is_empty() and Time.get_ticks_usec() < deadline:
		var step: Callable = build_queue.pop_front()
		var at := Time.get_ticks_usec()
		step.call()
		# 0.0.7.20 : étapes trop longues notées (mesures : tools/mesure_perf.gd).
		var ms := (Time.get_ticks_usec() - at) / 1000.0
		if ms > 30.0 and slow_steps.size() < 20:
			slow_steps.append("%s %.0f ms" % [step.get_method(), ms])

var slow_steps: Array[String] = []

# Tout d'un coup (tests, captures).
func finish_building() -> void:
	while not build_queue.is_empty():
		build_queue.pop_front().call()

func _build_zone(zone: Vector3i, job: RefCounted = null) -> void:
	# 0.0.7.20 : surface calculée en petites étapes (surface_job.gd), comme dans la partie.
	if job == null:
		job = SurfaceJob.new(terrain, zone)
	if not job.step(STEP_USEC):
		build_queue.push_front(_build_zone.bind(zone, job))
		return
	# 0.0.6.18 : sommets partagés, triangles par indices (comme dans la partie).
	var surface: Array = job.result
	if surface[6].is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = surface[0]
	arrays[Mesh.ARRAY_NORMAL] = surface[1]
	arrays[Mesh.ARRAY_COLOR] = surface[2]
	arrays[Mesh.ARRAY_TEX_UV] = surface[3]
	arrays[Mesh.ARRAY_TEX_UV2] = surface[4]
	arrays[Mesh.ARRAY_CUSTOM0] = surface[5]
	arrays[Mesh.ARRAY_INDEX] = surface[6]
	var mesh := ArrayMesh.new()
	var format := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	# 0.0.8.52 : coins et creux assombris (CUSTOM1), comme dans la partie.
	if surface.size() > 7 and (surface[7] as PackedFloat32Array).size() == (surface[0] as PackedVector3Array).size():
		arrays[Mesh.ARRAY_CUSTOM1] = surface[7]
		format |= Mesh.ARRAY_CUSTOM_R_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format)
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
# 0.0.7.23 : Web : lointain jusqu'à environ 130 m (brume plus proche), moitié moins de carrés.
const FAR_TILES_WEB := Rect2i(-4, -3, 5, 5)
var far_tiles: Rect2i = FAR_TILES_WEB if WEB else FAR_TILES

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
