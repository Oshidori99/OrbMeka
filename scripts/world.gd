extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const TerrainGenerator = preload("res://scripts/terrain_generator.gd")
const Controls = preload("res://scripts/controls.gd")
const CharacterPreview = preload("res://scripts/character_preview.gd")
const Store = preload("res://scripts/world_store.gd")
const Zones = preload("res://scripts/world_zones.gd")
const TerrainMaterials = preload("res://scripts/terrain_materials.gd")
const WorldMetadata = preload("res://scripts/world_metadata.gd")
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
const Generation = preload("res://scripts/world_generation.gd")
const FarTerrain = preload("res://scripts/far_terrain.gd")
const Rocks = preload("res://scripts/rocks.gd")
const Trees = preload("res://scripts/trees.gd")
const Plants = preload("res://scripts/plants.gd")
const Water = preload("res://scripts/water.gd")
const Inventory = preload("res://scripts/inventory.gd")
const InventoryUI = preload("res://scripts/inventory_ui.gd")
const DIRT := 2
const BLOCK_COLORS := [Color("#d8c291"), Color("#888b90"), Color("#855332")]
const BLOCK_NAMES := ["Sable", "Pierre", "Terre"]
const MAX_BLOCKS := 1200
# 0.0.6 : monde de 64 × 64 zones de 8 m (512 m, génération version 15) ; 48 × 48 pour les mondes d'avant (384 m ; 20 × 20 en 0.0.5.18, 16 × 16 avant).
# (Préparation des niveaux de détail, #128 : on ne charge que les zones autour du joueur.)
var base_size := Vector3(384, 1, 384)
const MAX_BUILD_HEIGHT := 25
# Construction permise jusqu'à 3 m du bord de la base (−253 à 253, ou −189 à 189 pour les mondes d'avant).
var build_limit := 189

var generated_hill_count := 0
var generated_max_height := 0
var generation_options: Dictionary = {}
var terrain_seed: int = TerrainGenerator.SEED
var world_name := "OrbMeka"
# Mode du monde, affiché dans Informations du monde (F3).
var world_mode_text := "Par défaut"
var developer_mode := false
# 0.0.4.10 : mode développeur utilisé au moins une fois (mention définitive des Informations du monde).
var developer_used := false
const DEVELOPER_USED_NOTE := "Mode développeur utilisé au moins une fois."
# Réglage Vidéo → Taille du texte, pour les textes affichés en jeu.
var text_scale := 1.0
var blocks: Dictionary = {}
var materials: Array[StandardMaterial3D] = []
var player: CharacterBody3D
var selection: MeshInstance3D
var hint: Label
var coordinates_label: Label
var fps_label: Label
var fps_elapsed := 0.0
const FPS_INTERVAL := 0.5
var creation_text := "Création : inconnue"
var notice := ""
var notice_time := 0.0
# 0.0.5 : dossier du monde (world_store.gd) ; vide = rien n'est enregistré (monde lancé seul, tests).
var save_folder := ""
# 0.0.5.1 : blocks = blocs des zones chargées (case → sorte) ; generated = terrain de la graine.
var generated: Dictionary = {}
var generated_by_zone: Dictionary = {}
var loaded_zones: Dictionary = {}
var dirty_zones: Dictionary = {}
var sections: Dictionary = {}
var zone_queue: Array = []
var zone_center := Vector3i(999999, 0, 0)
# Distance d'affichage en zones (Paramètres → Vidéo ; 0.0.5.17 : 8 par défaut, comptée à l'horizontale pour le terrain).
var load_distance := 8
# Densité de l'herbe (Paramètres → Vidéo), appliquée à l'ouverture du monde.
var grass_density := "medium"
var grass_distance := 36.0
var block_material: Material
var block_box: BoxShape3D
# Mesures affichées dans Informations du monde (F3).
var last_zone_load_ms := 0.0
var last_section_ms := 0.0
var autosave_time := 0.0
# 0.0.5.8 : terrain lisse (smooth_terrain.gd) : une pièce par zone (sol plat ou sculpté), herbe par carré de 8 m.
var terrain := SmoothTerrain.new()
# Collines de la graine (false : sol plat, pour les tests qui mesurent sur un sol plat).
var relief := true
var terrain_pieces: Dictionary = {}
var terrain_dirty: Dictionary = {}
var terrain_node: Node3D
var ground_material: ShaderMaterial
var lawn: Node3D
var flat_ground_mesh: ArrayMesh
var flat_ground_shape: BoxShape3D
const AUTOSAVE_SECONDS := 45.0
var save_error := ""

func _half_zones() -> int:
	return Generation.half_zones(int(generation_options.get("version", 0)))

func _ready() -> void:
	# 0.0.6 : taille du monde selon sa version de génération.
	base_size = Vector3(base_side(_half_zones()), 1, base_side(_half_zones()))
	build_limit = base_side(_half_zones()) / 2 - 3
	base_zones_low = Vector2i(-_half_zones(), -_half_zones())
	base_zones_high = Vector2i(_half_zones() - 1, _half_zones() - 1)
	_read_creation_date()
	_setup_inputs()
	_setup_environment()
	# 0.0.5.1 : une seule matière pour tous les blocs, couleur portée par les sommets de chaque section.
	TerrainMaterials.density = grass_density
	TerrainMaterials.grass_range = grass_distance
	block_material = TerrainMaterials.surface()
	block_box = BoxShape3D.new()
	_create_ground()
	# 0.0.6.18 (#175) : modèles d'arbres lus d'avance (en arrière-plan sur PC) pendant que le terrain se prépare.
	if relief and int(generation_options.get("version", 0)) >= 21:
		Trees.read_ahead(Trees.FORMS if int(generation_options.get("version", 0)) >= 29 else 1)
	var saved_player := _read_saved_player()
	var start_at := Vector3.ZERO
	if not saved_player.is_empty():
		start_at = Vector3(float(saved_player.position[0]), 0.0, float(saved_player.position[2]))
	_create_terrain(start_at)
	_load_objects()
	_create_ground_items()
	_create_blocks()
	_migrate_step1()
	# Ouverture : zones autour du point d'arrivée chargées tout de suite (ensuite, étalées sur les images).
	var arrival := Vector3i(0, 0, 0)
	if not saved_player.is_empty():
		arrival = Vector3i(floori(saved_player.position[0]), floori(saved_player.position[1]), floori(saved_player.position[2]))
	update_zones(arrival, true)
	player = PlayerScript.new()
	player.name = "Player"
	player.position = spawn_position()
	add_child(player)
	_apply_saved_player(saved_player)
	# 0.0.7.2 : inventaire relu (ancien monde : vide, sans erreur), dans le mode de jeu du monde.
	inventory.mode = game_mode
	inventory.from_dict(saved_player.get("inventaire"))
	inventory.changed.connect(apply_held)
	_create_selection()
	_create_hud()
	apply_held()

func _setup_inputs() -> void:
	# Touches choisies dans Paramètres → Contrôles (0.0.3.12), appliquées par le menu ;
	# monde lancé seul (tests) : touches par défaut.
	Controls.ensure_defaults()

# 0.0.4.17 : rendu Compatibility (version Web) : la lumière y paraît bien plus forte qu'avec Forward+ (Windows),
# couleurs délavées (sable et pierre blancs). 0.0.4.19 : réglé en comparant des captures des deux rendus :
# conversion des couleurs simple (tonemap linéaire). 0.0.5.8 : le Web paraissait trop sombre (herbe, soleil) :
# soleil × 0,75 (avant 0,48), lumière ambiante × 0,6 (avant 0,38).
# 0.0.5.30 : PC et Web rapprochés, herbe entre les deux aspects d'avant : même tonemap filmique, lumière propre à chacun,
# saturation 0,8 sur le Web (mesuré sur captures : herbe proche #6d8452 PC, #4a682f Web ; avant #97b06b et #344f21).
const COMPAT_SUN := 0.65
const PC_SUN := 0.42
const COMPAT_AMBIENT := 1.3
const PC_AMBIENT := 0.42

static func apply_compat_light(environment: Environment, sun: DirectionalLight3D) -> void:
	if not is_compat():
		sun.light_energy *= PC_SUN
		environment.ambient_light_energy *= PC_AMBIENT
		return
	sun.light_energy *= COMPAT_SUN
	environment.ambient_light_energy *= COMPAT_AMBIENT
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.68

static func is_compat() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"

var environment: Environment

func _setup_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#428de0")
	sky_material.sky_horizon_color = Color("#b9e2fa")
	sky_material.ground_horizon_color = Color("#b9e2fa")
	# 0.0.5.17 : sous l'horizon, au-delà du terrain affiché : même teinte que la brume (plus de bande noire).
	sky_material.ground_bottom_color = Color("#b9e2fa")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#dbe7ed")
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.light_energy = 1.1
	sun.light_color = Color("#fff1d8")
	sun.shadow_enabled = true
	# 0.0.5.25 : ombres jusqu'à 64 m, en 2 niveaux (moitié moins de dessins, presque rien ne change à l'œil).
	sun.directional_shadow_max_distance = 64.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	# 0.0.6.19 : Web (rendu Compatibility) allégé : ombres en un seul niveau, jusqu'à 40 m (moitié moins de dessins pour elles).
	if is_compat():
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 40.0
	apply_compat_light(environment, sun)
	add_child(sun)

func _create_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.add_to_group("ground")
	# 0.0.5.8 : la base indestructible (Roche-mère depuis 0.0.5.12) est sous la terre et la pierre ; le sol visible au-dessus
	# est le terrain lisse (pièces par zone, _create_terrain).
	ground.position = Vector3(0, SmoothTerrain.layers_of(generation_options)[3] * SmoothTerrain.STEP - 0.5, 0)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = base_size
	mesh.mesh = box
	ground_material = TerrainMaterials.surface(true)
	# 0.0.6.17 : le sol lit les minerais et la litière (CUSTOM0) ; pas les rochers ni les cailloux (rendu Web).
	ground_material.set_shader_parameter("terrain_layers", true)
	ground_material.set_shader_parameter("compat_look", is_compat())
	ground_material.set_shader_parameter("sand_center", SAND_CENTER)
	ground_material.set_shader_parameter("sand_radius", SAND_RADIUS)
	mesh.material_override = ground_material
	ground.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	ground.add_child(collision)
	add_child(ground)

# 0.0.5.5 : plus de collines de blocs ni de blocs de pierre (demande de l'utilisateur) ; 0.0.5.14 : petites
# collines de terrain lisse selon la graine (smooth_terrain.gd). terrain_generator.gd (anciennes collines) reste.
func _create_terrain(start_at: Vector3 = Vector3.ZERO) -> void:
	generated_hill_count = 0
	generated_max_height = 0
	# 0.0.5.14 : petites collines selon la graine, plates autour de l'apparition et de la plage.
	if relief:
		terrain.setup(terrain_seed, [[Vector2(0.5, 0.5), 9.0], [SAND_CENTER, SAND_RADIUS + 2.0]], generation_options)
	_read_terrain_changes()
	_read_objects()
	# 0.0.6.6 (#124) : eau qui coule (lacs qui baissent, eau libre), relue depuis le dossier du monde.
	flowing = Water.new(terrain)
	flowing.load_from(save_folder)
	terrain_node = Node3D.new()
	terrain_node.name = "Terrain"
	add_child(terrain_node)
	flat_ground_mesh = SmoothTerrain.flat_mesh()
	flat_ground_shape = BoxShape3D.new()
	flat_ground_shape.size = Vector3(SmoothTerrain.ZONE_SIZE, 1, SmoothTerrain.ZONE_SIZE)
	# 0.0.5.17 : herbe par carré de 8 m, chargée avec la colonne de zones (voir update_terrain_view).
	lawn = Node3D.new()
	lawn.name = "Lawn"
	add_child(lawn)
	view_center = Vector2i(floori(start_at.x / SmoothTerrain.ZONE_SIZE), floori(start_at.z / SmoothTerrain.ZONE_SIZE))
	collision_center = view_center
	update_terrain_view(true)
	# Le socle (Roche-mère) n'est jamais à voir : seulement sa collision, sous le terrain.
	get_node("Ground").get_child(0).visible = false

# 0.0.5.17 : distance d'affichage (Paramètres → Vidéo, 8 zones par défaut, 1 à 32), comptée à l'horizontale :
# toutes les zones où passe la surface d'une colonne proche sont affichées, quelle que soit la hauteur du
# joueur (en volant, on voit toujours le sol). Colonnes proches (NEAR_ZONES) faites tout de suite ; les autres
# d'abord plates, puis refaites peu à peu (les plus proches d'abord). Hors distance : retirées (terrain, herbe).
# 0.0.6.2 : seulement la colonne du joueur tout de suite (les autres, juste après, par la file, les plus proches d'abord).
const NEAR_ZONES := 0
const TERRAIN_BUDGET_USEC := 5000
var terrain_queue: Array = []
var shown_columns: Dictionary = {}
var view_center := Vector2i(999999, 0)

func wanted_columns(center: Vector2i) -> Dictionary:
	var result := {}
	for x in range(maxi(base_zones_low.x, center.x - load_distance), mini(base_zones_high.x, center.x + load_distance) + 1):
		for z in range(maxi(base_zones_low.y, center.y - load_distance), mini(base_zones_high.y, center.y + load_distance) + 1):
			result[Vector2i(x, z)] = true
	return result

func update_terrain_view(force: bool = false, center: Vector2i = view_center) -> void:
	if not force and center == view_center:
		return
	view_center = center
	_update_fog()
	var wanted := wanted_columns(center)
	# 0.0.6.18 (#175) : colonnes sorties de la vue retirées peu à peu (_process_hide_queue) ; avant : toute une rangée
	# d'un coup à chaque zone traversée (environ 8 ms en vol).
	for column: Vector2i in shown_columns:
		if not wanted.has(column) and not hiding.has(column):
			hiding[column] = true
			hide_queue.append(column)
	# 0.0.5.20 : seulement les colonnes à portée (monde de 48 × 48 zones : jamais tout le monde d'un coup).
	var near_low := Vector2i(maxi(base_zones_low.x, center.x - load_distance), maxi(base_zones_low.y, center.y - load_distance))
	var near_high := Vector2i(mini(base_zones_high.x, center.x + load_distance), mini(base_zones_high.y, center.y + load_distance))
	var later: Array = []
	for column: Vector2i in wanted:
		if shown_columns.has(column):
			# Revenue avant d'être retirée : gardée, et finie si elle ne l'était pas.
			if hiding.erase(column) and not built_columns.has(column):
				later.append(column)
			continue
		# 0.0.6.18 (#175) : zones de la nouvelle colonne relevées plus tard, dans le temps de chaque image (avant : toute la
		# vue relevée d'un coup à chaque zone traversée, 30 à 50 ms d'à-coup en vol).
		shown_columns[column] = []
		unsurveyed[column] = true
		if maxi(absi(column.x - center.x), absi(column.y - center.y)) <= NEAR_ZONES:
			_show_column(column)
		else:
			# 0.0.6 : avec le lointain, c'est lui qui montre la colonne en attendant (pas de sol plat par-dessus).
			if not _far_active():
				rebuild_terrain_piece(Vector3i(column.x, -1, column.y), true)
			later.append(column)
	# 0.0.6.18 : les plus proches d'abord, rangées par anneau (avant : un tri complet de la file à chaque zone traversée).
	var rings: Array = []
	rings.resize(load_distance + 1)
	for ring in range(rings.size()):
		rings[ring] = []
	for column: Vector2i in terrain_queue + later:
		if wanted.has(column):
			rings[mini(load_distance, maxi(absi(column.x - center.x), absi(column.y - center.y)))].append(column)
	terrain_queue = []
	for ring: Array in rings:
		terrain_queue.append_array(ring)
	_update_far(center, Rect2(Vector2(near_low) * SmoothTerrain.ZONE_SIZE, Vector2(near_high - near_low + Vector2i.ONE) * SmoothTerrain.ZONE_SIZE))
	_update_caves(center)

# Colonnes sorties de la vue, à retirer (dans le temps de chaque image).
const HIDE_BUDGET_USEC := 1500
var hiding: Dictionary = {}
var hide_queue: Array = []

func _process_hide_queue(budget_usec: int = HIDE_BUDGET_USEC) -> void:
	var started := Time.get_ticks_usec()
	while not hide_queue.is_empty() and Time.get_ticks_usec() - started < budget_usec:
		var column: Vector2i = hide_queue.pop_front()
		if hiding.erase(column):
			_hide_column(column)

# Colonnes affichées dont les zones de surface ne sont pas encore relevées.
var unsurveyed: Dictionary = {}

# Zones de surface d'une colonne affichée (relevées à la première demande).
func _surveyed(column: Vector2i) -> Array:
	if unsurveyed.erase(column):
		var zones: Array = shown_columns[column]
		for zone: Vector3i in terrain.surface_zones(column, column):
			if not zone in zones:
				zones.append(zone)
	return shown_columns[column]

# Colonne affichée : ses zones de surface et son herbe.
func _show_column(column: Vector2i) -> void:
	for zone: Vector3i in _surveyed(column):
		rebuild_terrain_piece(zone)
	column_pending.erase(column)
	_finish_column(column)

# Zones déjà faites : l’herbe, les objets, puis le lointain s’efface sous la colonne.
var column_pending: Dictionary = {}

func _finish_column(column: Vector2i) -> void:
	_rebuild_lawn_tile(column)
	_show_column_objects(column)
	built_columns[column] = true
	_far_follow_column(column)

# 0.0.5.37 : sous terre, seulement les grottes autour du joueur : invisibles de la surface, elles ne coûtent rien de loin.
const CAVE_REACH := 4
const CAVE_REACH_SURFACE := 2
var cave_underground := false
const CAVE_DEEP := -2.0
var cave_queue: Array = []
var cave_pieces: Dictionary = {}

func _update_caves(center: Vector2i) -> void:
	var wanted := {}
	cave_underground = is_instance_valid(player) and player.position.y < CAVE_DEEP
	for zone: Vector3i in terrain.cave_zones_near(center, CAVE_REACH if cave_underground else CAVE_REACH_SURFACE):
		wanted[zone] = true
	for zone: Vector3i in cave_pieces.keys():
		if not wanted.has(zone):
			cave_pieces.erase(zone)
			if terrain_pieces.has(zone) and not terrain.by_zone.has(zone) and not zone in shown_columns.get(Vector2i(zone.x, zone.z), []):
				terrain_pieces[zone].free()
				terrain_pieces.erase(zone)
				pending_collisions.erase(zone)
	cave_queue = wanted.keys().filter(func(zone: Vector3i): return not cave_pieces.has(zone))
	cave_queue.sort_custom(func(a: Vector3i, b: Vector3i): return maxi(absi(a.x - center.x), absi(a.z - center.y)) < maxi(absi(b.x - center.x), absi(b.z - center.y)))

func _show_cave_zone(zone: Vector3i) -> void:
	cave_pieces[zone] = true
	if not terrain_pieces.has(zone):
		rebuild_terrain_piece(zone)

func _hide_column(column: Vector2i) -> void:
	hiding.erase(column)
	# 0.0.6.18 (#175) : calculs du terrain de cette colonne libérés (recalculés à l'identique au retour).
	terrain.forget_column(column)
	shown_columns.erase(column)
	unsurveyed.erase(column)
	column_pending.erase(column)
	_hide_column_objects(column)
	# 0.0.6.2 : morceaux, herbe et objets retrouvés par colonne (avant : tout le monde parcouru pour chaque colonne).
	for zone: Vector3i in column_zones.get(column, {}):
		if terrain_pieces.has(zone):
			terrain_pieces[zone].free()
			terrain_pieces.erase(zone)
		pending_collisions.erase(zone)
	column_zones.erase(column)
	if is_instance_valid(lawn_tiles.get(column)):
		lawn_tiles[column].free()
	lawn_tiles.erase(column)
	if built_columns.erase(column):
		_far_follow_column(column)

# 0.0.6.2 : index par colonne (zones affichées, carré d’herbe, rochers et eau).
var column_zones: Dictionary = {}
var lawn_tiles: Dictionary = {}
var column_objects: Dictionary = {}

func column_shown(column: Vector2i) -> bool:
	return shown_columns.has(column)

func _process_terrain_queue() -> void:
	# Sous terre, les grottes d'abord ; en surface, seulement quand le reste du terrain est prêt.
	if is_instance_valid(player) and (player.position.y < CAVE_DEEP) != cave_underground:
		_update_caves(view_center)
	if not cave_queue.is_empty() and (cave_underground or terrain_queue.is_empty()):
		_show_cave_zone(cave_queue.pop_front())
	var started := Time.get_ticks_usec()
	# 0.0.6.2 : zone par zone (une colonne de montagne dépassait 40 ms d’un coup) ; l’herbe et les objets quand la colonne est finie.
	# 0.0.6.18 (#175) : une étape de plus seulement si elle tient dans le temps restant (durée moyenne des dernières) :
	# avant, une zone commencée à la fin du budget pouvait le dépasser de 10 ms.
	while not terrain_queue.is_empty():
		var step_started := Time.get_ticks_usec()
		if step_started > started and step_started - started + terrain_step_usec > TERRAIN_BUDGET_USEC:
			break
		_terrain_step()
		terrain_step_usec = terrain_step_usec * 0.8 + (Time.get_ticks_usec() - step_started) * 0.2

# Durée moyenne d'une étape du terrain (µs), pour ne pas dépasser le temps de chaque image.
var terrain_step_usec := 2000.0

func _terrain_step() -> void:
	var column: Vector2i = terrain_queue[0]
	if not shown_columns.has(column):
		terrain_queue.pop_front()
		column_pending.erase(column)
		return
	if not column_pending.has(column):
		column_pending[column] = _surveyed(column).duplicate()
	var pending: Array = column_pending[column]
	if pending.is_empty():
		terrain_queue.pop_front()
		column_pending.erase(column)
		_finish_column(column)
	else:
		rebuild_terrain_piece(pending.pop_back())

# Tout le terrain en attente, d'un coup (tests, captures).
func finish_terrain() -> void:
	_process_hide_queue(FAR_NO_LIMIT)
	while not cave_queue.is_empty():
		_show_cave_zone(cave_queue.pop_front())
	while not terrain_queue.is_empty():
		var column: Vector2i = terrain_queue.pop_front()
		if shown_columns.has(column):
			_show_column(column)
	while not far_queue.is_empty():
		_build_far_tile(far_queue.pop_front())
	# Toutes les collisions en attente (terrain, cailloux) : les tests et les captures visent partout.
	for zone: Vector3i in pending_collisions.keys():
		_build_collision(zone)
	for column: Vector2i in pebble_bodies:
		_build_pebble_bodies(column)
	_update_pebble_blocks()

# Brume au loin, au bord de la distance d'affichage : le terrain ne s'arrête pas d'un coup.
# 0.0.6.6 (#124) : eau qui coule (water.gd) : un pas tous les dixièmes de seconde autour du joueur ; l'eau libre est
# redessinée par zone de 8 m, les lacs qui ont bougé changent de hauteur.
var flowing: RefCounted
var water_time := 0.0
var water_pieces: Dictionary = {}

func _update_water(delta: float) -> void:
	if flowing == null:
		return
	water_time += delta
	if water_time < Water.STEP_SECONDS:
		return
	water_time = 0.0
	flowing.step(Vector2(player.position.x, player.position.z))
	show_water_changes()

func show_water_changes() -> void:
	for zone: Vector2i in flowing.changed_zones.keys():
		if is_instance_valid(water_pieces.get(zone)):
			water_pieces[zone].free()
		water_pieces.erase(zone)
		var faces: PackedVector3Array = flowing.zone_faces(zone)
		if faces.is_empty():
			continue
		var normals := PackedVector3Array()
		normals.resize(faces.size())
		normals.fill(Vector3.UP)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = faces
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var piece := MeshInstance3D.new()
		piece.name = "EauLibre"
		piece.mesh = mesh
		if _water_material == null:
			_water_material = ShaderMaterial.new()
			_water_material.shader = preload("res://shaders/water.gdshader")
			_water_material.set_shader_parameter("tone", 0.85 if is_compat() else 1.0)
			_clip_water()
		piece.material_override = _water_material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.add_to_group("water")
		add_child(piece)
		water_pieces[zone] = piece
	flowing.changed_zones.clear()
	if not flowing.changed_lakes.is_empty():
		for node in get_tree().get_nodes_in_group("water"):
			if node.has_meta("lake_id") and flowing.changed_lakes.has(node.get_meta("lake_id")):
				node.position.y = flowing.lake_level_now(flowing.changed_lakes[node.get_meta("lake_id")])
		flowing.changed_lakes.clear()

# 0.0.6 : sous l'eau (caméra plus basse que la surface d'un lac) : brume bleu-vert épaisse et voile teinté ; on ne
# voit plus qu'à quelques mètres, la surface paraît claire au-dessus. En sortant : la brume normale revient.
var underwater := false
var underwater_veil: ColorRect
const UNDERWATER_COLOR := Color(0.06, 0.24, 0.29)

# 0.0.6.8 : nage : hauteur de l'eau (lacs, rivières, eau libre) à cet endroit, -INF sans eau.
func water_surface(at: Vector2) -> float:
	if flowing != null:
		return flowing.surface_at(at)
	return terrain.water_level_at(at) if terrain != null else -INF

# Courant d'une rivière (m/s, vers l'aval) à cet endroit ; nul hors des rivières.
const RIVER_CURRENT := 1.2

func water_current(at: Vector2) -> Vector2:
	if terrain == null:
		return Vector2.ZERO
	var river: Dictionary = terrain.river_near(at)
	if river.is_empty() or river.distance > river.width:
		return Vector2.ZERO
	return river.direction * RIVER_CURRENT * (1.0 - 0.5 * river.distance / river.width)

func _update_underwater() -> void:
	var view := get_viewport().get_camera_3d() if is_inside_tree() else null
	if view == null or terrain == null:
		return
	var at := view.global_position
	var now: bool = at.y < (flowing.surface_at(Vector2(at.x, at.z)) if flowing != null else terrain.water_level_at(Vector2(at.x, at.z))) - 0.05
	if now == underwater:
		return
	underwater = now
	if not is_instance_valid(underwater_veil):
		var layer := CanvasLayer.new()
		layer.layer = -1
		add_child(layer)
		underwater_veil = ColorRect.new()
		underwater_veil.name = "UnderwaterVeil"
		underwater_veil.color = Color(UNDERWATER_COLOR, 0.28)
		underwater_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		underwater_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(underwater_veil)
	underwater_veil.visible = underwater
	if underwater:
		environment.fog_enabled = true
		environment.fog_mode = Environment.FOG_MODE_DEPTH
		environment.fog_light_color = UNDERWATER_COLOR
		environment.fog_depth_begin = 0.5
		environment.fog_depth_end = 12.0
		environment.fog_sky_affect = 1.0
	else:
		_update_fog()

func _update_fog() -> void:
	if not is_instance_valid(environment):
		return
	if underwater:
		return
	# 0.0.5.22 : jusqu'au bout du terrain lointain (niveaux de détail) s'il va plus loin.
	var reach := float(maxi(load_distance, far_distance if relief else 0) * SmoothTerrain.ZONE_SIZE)
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color("#b9e2fa")
	environment.fog_density = 1.0
	# Brume seulement tout au bout : les montagnes lointaines gardent leurs couleurs.
	environment.fog_depth_begin = reach * 0.82
	environment.fog_depth_end = reach
	environment.fog_sky_affect = 0.0

# 0.0.5.8 : terrain lisse sur toute la base (0.0.5.18 : zones de X et Z −80 à 79) ; base indestructible en dessous.
# 0.0.5.12 : la base (« Roche-mère », incassable) commence à 8 m sous le sol, sous 4 m de terre et 4 m de pierre.
var base_zones_low := Vector2i(-24, -24)
var base_zones_high := Vector2i(23, 23)

# 0.0.6.18 (#175) : zones qui ont un fichier (lu seulement pour celles-là).
var zone_files: Dictionary = {}

# Points changés de tous les fichiers de zone (lus une fois à l'ouverture ; les blocs restent lus par zone).
func _read_terrain_changes() -> void:
	if save_folder.is_empty():
		return
	var folder := save_folder.path_join("zones")
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file in DirAccess.get_files_at(folder):
		if not file.begins_with("zone_") or not file.ends_with(".bin"):
			continue
		var numbers := file.trim_prefix("zone_").trim_suffix(".bin").split("_")
		if numbers.size() == 3:
			zone_files[Vector3i(int(numbers[0]), int(numbers[1]), int(numbers[2]))] = true
		var saved := Zones.read_zone(folder.path_join(file))
		if saved.has("data"):
			terrain.load_entries(saved.data.get("densite", []))
		elif saved.has("error"):
			_notify(saved.error)
			notice_time = 8.0

# Pièce de terrain d'une zone : carré plat partagé si rien n'a changé, sinon surface lisse calculée.
func rebuild_terrain_piece(zone: Vector3i, flat_for_now: bool = false) -> void:
	var started := Time.get_ticks_usec()
	if terrain_pieces.has(zone):
		terrain_pieces[zone].free()
		terrain_pieces.erase(zone)
	pending_collisions.erase(zone)
	var body := StaticBody3D.new()
	body.name = "Terrain_%d_%d_%d" % [zone.x, zone.y, zone.z]
	body.add_to_group("ground")
	body.set_meta("zone", zone)
	var instance := MeshInstance3D.new()
	instance.material_override = ground_material
	var collision: CollisionShape3D = null
	var faces: Array = []
	if flat_for_now or terrain.is_flat(zone):
		if not SmoothTerrain.ground_zone(zone):
			body.free()
			return
		body.position = Vector3(zone.x, 0, zone.z) * SmoothTerrain.ZONE_SIZE
		instance.mesh = flat_ground_mesh
		collision = CollisionShape3D.new()
		collision.shape = flat_ground_shape
		collision.position = Vector3(SmoothTerrain.ZONE_SIZE / 2.0, -0.5, SmoothTerrain.ZONE_SIZE / 2.0)
	else:
		# 0.0.6.18 (#175) : sommets partagés et triangles par indices (même image, environ 6 fois moins de sommets).
		var surface := terrain.zone_surface(zone)
		if surface[6].is_empty():
			body.free()
			return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surface[0]
		arrays[Mesh.ARRAY_NORMAL] = surface[1]
		arrays[Mesh.ARRAY_COLOR] = surface[2]
		arrays[Mesh.ARRAY_TEX_UV] = surface[3]
		arrays[Mesh.ARRAY_TEX_UV2] = surface[4]
		# 0.0.6.4 : calcaire, charbon, silex (CUSTOM0).
		arrays[Mesh.ARRAY_CUSTOM0] = surface[5]
		arrays[Mesh.ARRAY_INDEX] = surface[6]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		instance.mesh = mesh
		faces = [surface[0], surface[6]]
	body.add_child(instance)
	if collision != null:
		body.add_child(collision)
	terrain_node.add_child(body)
	terrain_pieces[zone] = body
	if not faces.is_empty():
		pending_collisions[zone] = faces
		if _near_collision(zone):
			_build_collision(zone)
	var column := Vector2i(zone.x, zone.z)
	if not column_zones.has(column):
		column_zones[column] = {}
	column_zones[column][zone] = true
	last_section_ms = (Time.get_ticks_usec() - started) / 1000.0

# 0.0.6.18 (#175) : collision du terrain lisse seulement près du joueur (COLLISION_REACH zones autour) ; au loin, seulement
# le dessin. Les triangles en attente (sommets et indices) pèsent bien moins qu'une collision faite.
const COLLISION_REACH := 2
const COLLISION_BUDGET_USEC := 1500
var collision_center := Vector2i.ZERO
var pending_collisions: Dictionary = {}
var collision_queue: Array = []

# Zone (colonne de 8 m) du joueur ; avant son arrivée, celle de l'ouverture.
func _player_column() -> Vector2i:
	if is_instance_valid(player):
		return Vector2i(floori(player.position.x / SmoothTerrain.ZONE_SIZE), floori(player.position.z / SmoothTerrain.ZONE_SIZE))
	return collision_center

func _near_collision(zone: Vector3i) -> bool:
	var here := _player_column()
	return maxi(absi(zone.x - here.x), absi(zone.z - here.y)) <= COLLISION_REACH

func _build_collision(zone: Vector3i) -> void:
	var faces: Array = pending_collisions.get(zone, [])
	pending_collisions.erase(zone)
	if faces.is_empty() or not terrain_pieces.has(zone):
		return
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(SmoothTerrain.surface_faces(faces[0], faces[1]))
	var collision := CollisionShape3D.new()
	collision.shape = shape
	terrain_pieces[zone].add_child(collision)

# Le joueur change de zone : collisions des zones voisines tout de suite, puis celles un peu plus loin, peu à peu.
func _update_collisions() -> void:
	if not is_instance_valid(player):
		return
	var here := _player_column()
	if here != collision_center:
		collision_center = here
		collision_queue.clear()
		# Cailloux : collisions des colonnes proches faites, celles des colonnes laissées derrière retirées.
		for column: Vector2i in column_pebbles.keys():
			if not _pebble_near(column):
				for node in column_pebbles[column]:
					if is_instance_valid(node):
						node.free()
				column_pebbles.erase(column)
		for x in range(here.x - PEBBLE_REACH, here.x + PEBBLE_REACH + 1):
			for z in range(here.y - PEBBLE_REACH, here.y + PEBBLE_REACH + 1):
				_build_pebble_bodies(Vector2i(x, z))
		for x in range(here.x - COLLISION_REACH, here.x + COLLISION_REACH + 1):
			for z in range(here.y - COLLISION_REACH, here.y + COLLISION_REACH + 1):
				for zone: Vector3i in column_zones.get(Vector2i(x, z), {}):
					if not pending_collisions.has(zone):
						continue
					if maxi(absi(x - here.x), absi(z - here.y)) <= 1:
						_build_collision(zone)
					else:
						collision_queue.append(zone)
	var started := Time.get_ticks_usec()
	while not collision_queue.is_empty() and Time.get_ticks_usec() - started < COLLISION_BUDGET_USEC:
		_build_collision(collision_queue.pop_front())

# Herbe écartée là où le terrain a été sculpté (colonne de 50 cm et ses voisines) et dans les déserts.
func _grass_skipped(at: Vector3) -> bool:
	# 0.0.5.15 : pas d'herbe dans les déserts.
	# 0.0.5.20 : ni sur la boue au bord des lacs.
	var column := Vector2i(roundi(at.x / SmoothTerrain.STEP), roundi(at.z / SmoothTerrain.STEP))
	# 0.0.6.15 : ni sur la litière d'aiguilles des pinèdes.
	return terrain.column_changed(column) or terrain.is_desert(Vector2(at.x, at.z)) or terrain.muddy(column) or terrain.needle_floor(column)

func _rebuild_lawn_tile(tile: Vector2i) -> void:
	if is_instance_valid(lawn_tiles.get(tile)):
		lawn_tiles[tile].free()
	lawn_tiles.erase(tile)
	var node := TerrainMaterials.lawn_tile(tile, generated, terrain_seed, SAND_CENTER, SAND_RADIUS, _grass_skipped, terrain.height_at)
	if node != null:
		lawn.add_child(node)
		lawn_tiles[tile] = node
# Gestes de terrain (0.0.5.8, pinceaux en 0.0.5.9). Clic gauche : creuser ; clic droit : le pinceau
# choisi avec B + T (poser, aplanir, lisser). Taille (B + molette) : 1/8, 1/4 ou 1/2 bloc, soit 1, 2 ou
# 4 sous-cellules de 50 cm ; aplanir et lisser agissent autour, sur 50 cm, 1 m ou 1,5 m.
const BRUSH_NAMES := ["Poser", "Aplanir", "Lisser"]
const SIZE_NAMES := ["1/8 de bloc", "1/4 de bloc", "1/2 bloc"]
const SIZE_CELLS := [1, 2, 4]
# Matières qu'on peut poser. 0.0.7.2 : plus pierre, calcaire, pierre sombre et silex (inventaire, Matériaux naturels) ;
# 0.0.7.6 : plus le gravier (oublié en 0.0.7.3) : toutes les matières de l'inventaire se posent.
const PLACEABLE := [0, 2, SmoothTerrain.CLAY, SmoothTerrain.MUD, SmoothTerrain.STONE, SmoothTerrain.LIMESTONE, SmoothTerrain.DARK_STONE, SmoothTerrain.FLINT, SmoothTerrain.GRAVEL]
# 0.0.5.13 : la pioche. 0.0.7.2 : plus de choix de matière (molette, touches 1 à 5, texte en haut à gauche) :
# l'objet en main est la case choisie de la barre d'objets (inventory.gd) ; player.selected_type en est la valeur
# (matière, PICKAXE, ou -1 : main vide).
const PICKAXE := 3

# 0.0.7.2 : inventaire, barre d'objets et mode de jeu du monde (Paramètres → Monde ; « creative » ou « survival »).
var game_mode := Inventory.CREATIVE
var inventory := Inventory.new()
var inventory_ui: CanvasLayer
var inventory_open := false

func held_text() -> String:
	var name := Inventory.item_name(inventory.held())
	return name if not name.is_empty() else "Main vide"

func apply_held() -> void:
	if is_instance_valid(player):
		player.selected_type = inventory.held_kind()
		player.show_held(inventory.held())

func set_game_mode(new_mode: String) -> void:
	game_mode = new_mode
	inventory.set_mode(new_mode)

# Touches 1 à 9 et 0 : cases 1 à 10 de la barre. En Survie (0.0.7.3) : 1 et 2 les mains, 3 à 6 les poches.
func select_slot(index: int) -> void:
	if inventory.select(index):
		show_choice(held_text())
	else:
		_notify("En Survie : deux mains (1 et 2) et quatre poches (3 à 6).")

func cycle_slot(direction: int) -> void:
	inventory.cycle(direction)
	show_choice(held_text())

func toggle_inventory() -> void:
	if inventory_open:
		close_inventory()
	else:
		open_inventory()

func open_inventory() -> void:
	if inventory_open or not is_instance_valid(inventory_ui):
		return
	inventory_open = true
	player.release_controls()
	inventory_ui.open()
	_show_aim(false)

# recapture : la souris revient au jeu (pas en se mettant en pause).
func close_inventory(recapture: bool = true) -> void:
	if not inventory_open:
		return
	inventory_open = false
	inventory_ui.close()
	_show_aim(true)
	if recapture and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# Croix de visée et message du bas : cachés derrière l'inventaire ouvert (le panneau est un peu transparent).
func _show_aim(on: bool) -> void:
	var crosshair: Control = find_child("Crosshair", true, false)
	if is_instance_valid(crosshair):
		crosshair.visible = on
	if is_instance_valid(hint):
		hint.visible = on

# Message quand une pioche manque : en Créatif, elle est dans l'inventaire (Outils) ; pas encore en Survie.
func _needs_pickaxe(subject: String) -> String:
	return subject + (" avec la pioche (inventaire : O + I, onglet Outils)." if game_mode == Inventory.CREATIVE else " avec une pioche : pas encore en Survie.")

# --- 0.0.7.3 : objets au sol, ramasser (R), récupérer une poignée (R + I), terre rejetée derrière soi (Survie) ---
const GroundItems = preload("res://scripts/ground_items.gd")
var ground: Node3D
# Sous-cellules du dernier geste (poser : autant de poignées utilisées).
var last_gesture_points := 0
# Morceaux de pierre cassée à la pioche : deux de 125 g par sous-cellule (250 g en tout), de la matière frappée.
const STONE_PIECE_WEIGHT := 125.0
const STONE_PIECES := {SmoothTerrain.STONE: "eclat_pierre", SmoothTerrain.DARK_STONE: "eclat_pierre_sombre", SmoothTerrain.LIMESTONE: "eclat_calcaire", SmoothTerrain.FLINT: "eclat_silex", SmoothTerrain.COAL: "charbon"}
# Aspect d'un caillou (0 pierre, 1 calcaire, 2 silex) : objet ramassé, ou éclats quand on le casse.
const PEBBLE_ITEMS := ["caillou", "caillou_calcaire", "caillou_silex"]
const PEBBLE_PIECES := ["eclat_pierre", "eclat_calcaire", "eclat_silex"]

func _create_ground_items() -> void:
	ground = GroundItems.new()
	# 0.0.7.5 : cailloux et éclats au sol avec la matière des cailloux du monde (même aspect une fois reposés).
	ground.stone_material = _pebble_material()
	add_child(ground)
	ground.from_array(objects_data.get("objets_au_sol"))
	ground.changed.connect(func(): objects_dirty = true)

# Hauteur du sol sous un point (collisions du terrain près du joueur, sinon le sol de la graine).
func _rest_height(spot: Vector3) -> float:
	if is_inside_tree():
		var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 1.5, spot + Vector3.DOWN * 6.0, 1)
		if is_instance_valid(player):
			query.exclude = [player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			return hit.position.y
	return terrain.height_at(spot.x, spot.z)

# Point au sol à côté du joueur (à sa droite, un peu devant) : là où tombent les morceaux.
func _beside_player() -> Vector3:
	var basis := player.global_transform.basis
	return player.global_position + basis.x * 0.6 - basis.z * 0.35

func drop_pieces(id: String, pieces: int, weight: float, from: Vector3) -> void:
	if not is_instance_valid(ground) or not is_instance_valid(player):
		return
	for index in range(pieces):
		ground.drop({"objet": id, "poids": weight}, from, _beside_player(), _rest_height)

# 0.0.7.4 : poser au sol l'objet en main (clic droit), un à la fois, là où l'on vise (à portée de pose).
# 0.0.7.5 : c'est le dernier objet pris dans la case, avec toutes ses caractéristiques (forme, taille, orientation…).
func put_down_held(hit: Dictionary) -> bool:
	var value := inventory.held()
	if not Inventory.is_object(value) or not is_instance_valid(ground):
		return false
	if hit.is_empty() or not is_instance_valid(hit.get("collider")):
		_notify("Visez le sol pour y poser %s." % Inventory.item_name(value).to_lower())
		return false
	if player.camera.global_position.distance_to(hit.position) > player.place_reach + 0.01:
		_notify("Trop loin : %s m au plus." % str(snappedf(player.place_reach, 0.1)).replace(".", ","))
		return false
	var one := inventory.pop_held()
	if one.is_empty():
		return false
	ground.drop(one, hit.position + Vector3.UP * 0.3, hit.position, _rest_height, 0.0)
	show_choice("%s posé au sol" % Inventory.item_name(value))
	return true

# Objets qui ne tiennent plus dans l'inventaire : posés au sol devant le joueur, jamais perdus (chacun tel qu'il est).
func drop_items(value: Dictionary) -> void:
	if not is_instance_valid(ground) or not is_instance_valid(player):
		return
	var near := player.global_position - player.global_transform.basis.z * 0.6
	var units: Array = value.pile.map(func(instance): return Inventory.flat(value.objet, instance)) if value.has("pile") else []
	if units.is_empty():
		for index in range(maxi(Inventory.count(value), 1)):
			units.append({"objet": value.objet})
	for unit in units:
		ground.drop(unit, player.global_position + Vector3.UP, near, _rest_height)

# Message quand rien n'a pu être pris (inventory.add_to_selected).
func _refused_message(reason: String, value: Dictionary) -> String:
	match reason:
		"occupee":
			return "Case choisie occupée : choisissez une case vide (molette ou chiffres)."
		"lourd":
			return "Trop lourd pour cette case (%s)." % Inventory.format_weight(Inventory.unit_weight(value))
	return "Inventaire plein." if game_mode == Inventory.CREATIVE else "Mains et poches pleines."

# --- 0.0.7.5 : cueillir (demande de l'utilisateur : il faut vraiment viser la pomme ou la noisette) ---
# Les fruits des arbres proches (colonne du joueur et voisines) sont des petites sphères (trees.gd fruit_spots) ; le rayon
# de visée doit en traverser une, à portée, sans rien de solide devant (tronc, sol). Une marge de FRUIT_AIM sur leur rayon
# rend la visée moins difficile. Le fruit cueilli disparaît de cet arbre seulement (Trees.apply_picked) ; sauvegardé.
const FRUIT_AIM := 1.5

func aimed_fruit(hit: Dictionary) -> Dictionary:
	if not is_instance_valid(player):
		return {}
	var origin: Vector3 = player.camera.global_position
	var direction: Vector3 = -player.camera.global_transform.basis.z
	var reach: float = player.break_reach
	# Rien de solide devant le fruit : le point visé (tronc, sol, rocher) doit être plus loin.
	if not hit.is_empty():
		reach = minf(reach, origin.distance_to(hit.position) + 0.15)
	var best := {}
	var here := _player_column()
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for tree in column_objects.get(here + Vector2i(dx, dz), []):
				if not is_instance_valid(tree) or not tree.is_in_group("trees") or not tree.has_meta("kind"):
					continue
				if tree.global_position.distance_to(origin) > reach + 12.0:
					continue
				var spots: Array = Trees.fruit_spots(tree.get_meta("kind"), tree.get_meta("size"), tree.get_meta("form"))
				if spots.is_empty():
					continue
				var picked: Array = picked_fruits.get(str(tree.get_meta("id", "")), [])
				var place: Transform3D = tree.global_transform
				var scale: float = place.basis.get_scale().x
				for number in range(spots.size()):
					if number in picked:
						continue
					var center: Vector3 = place * spots[number][0]
					var radius: float = maxf(spots[number][1] * scale * FRUIT_AIM, 0.05)
					var offset: Vector3 = origin - center
					var along: float = offset.dot(direction)
					var gap: float = along * along - (offset.length_squared() - radius * radius)
					if gap < 0.0:
						continue
					var distance: float = -along - sqrt(gap)
					if distance < 0.0:
						distance = -along + sqrt(gap)
					if distance < 0.0 or distance > reach:
						continue
					if best.is_empty() or distance < best.distance:
						best = {"tree": tree, "number": number, "spot": spots[number], "distance": distance}
	return best

func _pick_fruit(fruit: Dictionary) -> bool:
	var tree: Node3D = fruit.tree
	var spot: Array = fruit.spot
	var apple: bool = int(tree.get_meta("kind")) == Trees.APPLE
	# 0.0.7.6 : le fruit garde sa vraie taille dans l'arbre (diamètre, en mètres) : reposé, il reste le même.
	var diameter := snappedf(float(spot[1]) * 2.0 * tree.global_transform.basis.get_scale().x, 0.001)
	var value := {"objet": "pomme", "pile": [{"taille": int(spot[2]), "couleur": int(spot[3]), "diametre": diameter}]} if apple else {"objet": "noisette", "pile": [{"diametre": diameter}]}
	var result := inventory.add_to_selected(value)
	if result.added == 0:
		_notify(_refused_message(result.reason, value))
		return true
	var id := str(tree.get_meta("id", ""))
	var picked: Array = picked_fruits.get(id, [])
	picked.append(int(fruit.number))
	picked_fruits[id] = picked
	objects_dirty = true
	Trees.apply_picked(tree, picked)
	var name: String = ("Pomme " + Inventory.APPLE_COLOR_NAMES[int(spot[3])]) if apple else "Noisette"
	show_choice("%s (%s)" % [name, Inventory.format_weight(Inventory.unit_weight(value))])
	return true

# R : ramasser l'objet visé (objet au sol ou petit caillou du monde), avec toutes ses caractéristiques.
# 0.0.7.5 (demande de l'utilisateur) : dans la case choisie de la barre ; barre pleine : dans une case libre de l'inventaire.
# Faux si rien n'est visé (R garde alors son autre usage : courir).
# 0.0.7.5 : aussi cueillir une pomme ou une noisette, seulement si la visée passe vraiment par elle.
func pick_up(hit: Dictionary) -> bool:
	var fruit := aimed_fruit(hit)
	if not fruit.is_empty():
		return _pick_fruit(fruit)
	if hit.is_empty() or not is_instance_valid(hit.get("collider")):
		return false
	var collider: Node = hit.collider
	if not (collider.is_in_group("ground_items") or collider.is_in_group("pebbles")):
		return false
	if player.camera.global_position.distance_to(hit.position) > player.break_reach + 0.01:
		_notify("Trop loin : %s m au plus." % str(snappedf(player.break_reach, 0.1)).replace(".", ","))
		return true
	var value := {}
	if collider.is_in_group("ground_items"):
		var index: int = ground.index_of(collider)
		if index < 0:
			return false
		value = Inventory.single(ground.entries[index].item)
		var result := inventory.add_to_selected(value)
		if result.added == 0:
			_notify(_refused_message(result.reason, value))
			return true
		ground.remove(index)
	else:
		var size: int = collider.get_meta("pebble").x
		if size > Inventory.PICKABLE_SIZE:
			_notify("Trop gros pour être ramassé : cassez-le d'abord.")
			return true
		# Le caillou du monde garde sa taille, sa forme, son orientation et les coups déjà reçus.
		var instance := {"taille": size, "forme": int(collider.get_meta("pebble").y), "rotation": deg_to_rad(float(collider.get_meta("rotation", 0.0)))}
		if int(pebble_hits.get(collider.get_meta("id"), 0)) > 0:
			instance.coups = int(pebble_hits.get(collider.get_meta("id"), 0))
		value = {"objet": PEBBLE_ITEMS[clampi(int(collider.get_meta("look", 0)), 0, 2)], "pile": [instance]}
		var result := inventory.add_to_selected(value)
		if result.added == 0:
			_notify(_refused_message(result.reason, value))
			return true
		var column: Vector2i = collider.get_meta("column")
		broken_pebbles[collider.get_meta("id")] = true
		pebble_hits.erase(collider.get_meta("id"))
		objects_dirty = true
		_show_column_pebbles(column)
		_build_pebble_bodies(column)
	show_choice("%s (%s)" % [Inventory.item_name(value), Inventory.format_weight(Inventory.unit_weight(value))])
	return true

# R + I maintenus : prendre une poignée de matière en vrac (terre, sable, argile, boue, gravier) là où l'on vise,
# après GATHER_SECONDS (plus long que creuser). Survie seulement ; dans la case choisie (0.0.7.5), comme ramasser.
const GATHER_SECONDS := 1.0
const GATHER_ITEMS := {SmoothTerrain.SAND: "sable", SmoothTerrain.DIRT: "terre", SmoothTerrain.CLAY: "argile", SmoothTerrain.MUD: "boue", SmoothTerrain.GRAVEL: "gravier", SmoothTerrain.NEEDLES: "terre"}
var gather_point := Vector3i(999999, 0, 0)
var gather_time := 0.0

static func handful_text(id: String) -> String:
	var name := Inventory.item_name({"objet": id}).to_lower()
	return ("Poignée d'" if name.left(1) in ["a", "e", "i", "o", "u", "é"] else "Poignée de ") + name

func step_gather(delta: float, holding: bool) -> bool:
	if not holding:
		gather_time = 0.0
		gather_point = Vector3i(999999, 0, 0)
		return false
	if game_mode == Inventory.CREATIVE:
		_notify("En Créatif, les matières sont illimitées (inventaire : O + I).")
		return false
	var hit: Dictionary = player.get_target()
	if not _valid_hit(hit, player.break_reach) or not hit.collider.is_in_group("ground"):
		gather_time = 0.0
		_notify("Visez la terre ou le sable pour en prendre une poignée.")
		return false
	var point := SmoothTerrain.point_of(hit.position - hit.normal * 0.3)
	# Terre ordinaire : -1 dans le terrain (sans matière particulière).
	var kind: int = terrain.materials.get(point, terrain.natural_kind(point))
	if kind < 0:
		kind = SmoothTerrain.DIRT
	if terrain.density(point) <= 0.0 or not _in_terrain_limits(point):
		gather_time = 0.0
		return false
	if not GATHER_ITEMS.has(kind):
		gather_time = 0.0
		_notify("La pierre ne se prend pas à la main." if kind in SmoothTerrain.ROCKS else "Rien à prendre ici.")
		return false
	if point != gather_point:
		gather_point = point
		gather_time = 0.0
	var id: String = GATHER_ITEMS[kind]
	gather_time += delta
	if gather_time < GATHER_SECONDS:
		_notify("%s… %d %%" % [handful_text(id), int(gather_time / GATHER_SECONDS * 100.0)])
		return false
	gather_time = 0.0
	var result := inventory.add_to_selected({"objet": id, "nombre": 1})
	if result.added == 0:
		_notify(_refused_message(result.reason, {"objet": id}))
		return false
	_apply_terrain({point: [SmoothTerrain.DUG, -1]})
	show_choice("%s (%s)" % [handful_text(id), Inventory.format_weight(Inventory.unit_weight({"objet": id}))])
	return true

# Survie : la matière creusée est rejetée derrière soi en petit tas. Jamais dans le trou qu'on creuse, jamais assez haut
# pour boucher un passage (2 m libres au-dessus, au plus 50 cm plus haut que les pieds) ; mur derrière : sur le côté.
const THROW_CENTERS := [[1.5, 0.0], [1.2, 1.0], [1.2, -1.0], [0.0, 1.5], [0.0, -1.5], [2.5, 0.0]]
const NO_SPOT := Vector3i(999999, 0, 0)

func _throw_behind(dug: Array) -> void:
	var feet := player.global_position
	var back := player.global_transform.basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var side := Vector3(-back.z, 0.0, back.x)
	var hole: Array = dug.map(func(entry): return Vector3(entry[0]) * SmoothTerrain.STEP)
	var updates := {}
	for entry in dug:
		var kind: int = entry[1] if entry[1] >= 0 else SmoothTerrain.DIRT
		if kind in SmoothTerrain.ROCKS:
			continue
		var spot := _throw_spot(feet, back, side, hole, updates)
		if spot != NO_SPOT:
			updates[spot] = [SmoothTerrain.ADDED, kind]
	_apply_terrain(updates)

func _throw_spot(feet: Vector3, back: Vector3, side: Vector3, hole: Array, pending: Dictionary) -> Vector3i:
	for pair in THROW_CENTERS:
		var center := SmoothTerrain.point_of(feet + back * pair[0] + side * pair[1])
		var best := NO_SPOT
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var top := _pile_top(Vector2i(center.x + dx, center.z + dz), feet, pending)
				if top == NO_SPOT or not _in_terrain_limits(top) or _inside_player(top):
					continue
				var at := Vector3(top) * SmoothTerrain.STEP
				if hole.any(func(dug_at: Vector3): return Vector2(dug_at.x - at.x, dug_at.z - at.z).length() < 0.8):
					continue
				if best == NO_SPOT or top.y < best.y:
					best = top
		if best != NO_SPOT:
			return best
	return NO_SPOT

# Première place libre sur la colonne, au plus 50 cm au-dessus des pieds, avec 2 m libres au-dessus.
func _pile_top(column: Vector2i, feet: Vector3, pending: Dictionary) -> Vector3i:
	var feet_y := SmoothTerrain.point_of(feet).y
	for y in range(feet_y + 2, feet_y - 8, -1):
		var point := Vector3i(column.x, y, column.y)
		if pending.has(point) or terrain.density(point) > 0.0:
			var top := point + Vector3i.UP
			if top.y > feet_y + 1:
				return NO_SPOT
			for height in range(1, 5):
				var above := top + Vector3i.UP * height
				if pending.has(above) or terrain.density(above) > 0.0:
					return NO_SPOT
			return top
	return NO_SPOT

func _aimed_ground(hit: Dictionary, reach: float) -> bool:
	if not _valid_hit(hit, reach):
		# 0.0.6 : jamais un clic sans réponse : on dit pourquoi rien ne se passe.
		if hit.is_empty() or not is_instance_valid(hit.get("collider")):
			_notify("Rien à portée : visez le sol à moins de %s m." % str(snappedf(reach, 0.1)).replace(".", ","))
		elif player.camera.global_position.distance_to(hit.position) > reach + 0.01:
			_notify("Trop loin : %s m au plus." % str(snappedf(reach, 0.1)).replace(".", ","))
		else:
			_notify("Visez le sol pour le sculpter.")
		return false
	if not hit.collider.is_in_group("ground"):
		_notify("Visez le sol pour le sculpter.")
		return false
	return true

# Sous-cellules d'un geste : la visée, puis ses voisines dans le plan de la surface visée.
static func gesture_points(center: Vector3i, normal: Vector3, cells: int) -> Array[Vector3i]:
	var axis := 0
	if absf(normal.y) >= absf(normal.x) and absf(normal.y) >= absf(normal.z):
		axis = 1
	elif absf(normal.z) > absf(normal.x):
		axis = 2
	var side_a := Vector3i.ZERO
	var side_b := Vector3i.ZERO
	side_a[(axis + 1) % 3] = 1
	side_b[(axis + 2) % 3] = 1
	var result: Array[Vector3i] = [center]
	if cells >= 2:
		result.append(center + side_a)
	if cells >= 4:
		result.append_array([center + side_b, center + side_a + side_b])
	return result

# 0.0.5.31 : matière du sol sous les pieds (boue et argile : un peu glissantes).
var test_ground_kind := Callable()

func ground_kind_under(at: Vector3) -> int:
	if test_ground_kind.is_valid():
		return test_ground_kind.call()
	var point := SmoothTerrain.point_of(at + Vector3.DOWN * 0.3)
	if terrain.density(point) <= 0.0:
		point += Vector3i.DOWN
	return terrain.materials.get(point, terrain.natural_kind(point))

# 0.0.5.13 : jusqu'à la pierre juste au-dessus de la Roche-mère (la pierre : seulement à la pioche).
func _in_terrain_limits(point: Vector3i) -> bool:
	return point.y > terrain.mother_rock_top and point.y <= SmoothTerrain.HIGH_POINT and absi(point.x) <= build_limit * 2 and absi(point.z) <= build_limit * 2

func _inside_player(point: Vector3i) -> bool:
	return AABB(player.global_position + Vector3(-0.33, 0.01, -0.33), Vector3(0.66, 1.78, 0.66)).intersects(AABB(Vector3(point) * SmoothTerrain.STEP - Vector3.ONE * 0.25, Vector3.ONE * 0.5))

# Creuser (add false) ou poser (add true, matière kind).
func sculpt(hit: Dictionary, add: bool, kind: int = SmoothTerrain.DIRT, cells: int = 1, pickaxe: bool = false) -> bool:
	if not _aimed_ground(hit, player.place_reach if add else player.break_reach):
		return false
	var center := SmoothTerrain.point_of(hit.position + hit.normal * (0.15 if add else -0.3))
	var updates := {}
	var message := ""
	for point in gesture_points(center, hit.normal, cells):
		if not _in_terrain_limits(point):
			if point.y <= terrain.mother_rock_top:
				message = "Roche-mère : incassable."
			elif point.y > SmoothTerrain.HIGH_POINT:
				message = "Hauteur maximale atteinte : 40 blocs."
			else:
				message = "Limite de construction atteinte."
			continue
		if (terrain.density(point) > 0.0) == add:
			continue
		if not add and terrain.is_stone(point) and not pickaxe:
			message = _needs_pickaxe("La pierre se casse")
			continue
		if add and _inside_player(point):
			message = "Reculez un peu pour ajouter du terrain."
			continue
		updates[point] = [SmoothTerrain.ADDED if add else SmoothTerrain.DUG, kind if add else -1]
	if updates.is_empty():
		_notify(message if not message.is_empty() else ("Déjà plein ici." if add else "Rien à creuser ici."))
	last_gesture_points = updates.size()
	# 0.0.7.3 : en Survie, la terre, le sable, l'argile, la boue ou le gravier creusés sont rejetés derrière soi.
	var dug := []
	if not add and game_mode == Inventory.SURVIVAL:
		for point: Vector3i in updates:
			dug.append([point, terrain.materials.get(point, terrain.natural_kind(point))])
	var done := _apply_terrain(updates)
	if done and not dug.is_empty():
		_throw_behind(dug)
	return done

# Aplanir : bosses coupées à la hauteur visée, sur un disque autour. 0.0.5.10 : n'ajoute jamais de matière
# (les creux restent : seul Poser ajoute).
func flatten(hit: Dictionary, cells: int = 1) -> bool:
	if not _aimed_ground(hit, player.place_reach):
		return false
	var level := clampf(hit.position.y, terrain.low_point * SmoothTerrain.STEP, SmoothTerrain.HIGH_POINT * SmoothTerrain.STEP)
	var center := SmoothTerrain.point_of(hit.position)
	var radius: int = [1, 2, 3][SIZE_CELLS.find(cells)]
	var updates := {}
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			if dx * dx + dz * dz > radius * radius:
				continue
			for y in range(floori((level - 1.5) / SmoothTerrain.STEP), ceili((level + 1.5) / SmoothTerrain.STEP) + 1):
				var point := Vector3i(center.x + dx, y, center.z + dz)
				if not _in_terrain_limits(point) or terrain.is_stone(point):
					continue
				var value := clampf(level - y * SmoothTerrain.STEP, -1.0, 1.0)
				var old := terrain.density(point)
				if value >= old - 0.001:
					continue
				updates[point] = [value, -1]
	return _apply_terrain(updates)

# Lisser : chaque point se rapproche de la moyenne de ses 6 voisins (angles et marches adoucis) ;
# 0.0.5.10 : sans créer de matière dans l'air (seul Poser ajoute).
func smooth(hit: Dictionary, cells: int = 1) -> bool:
	if not _aimed_ground(hit, player.place_reach):
		return false
	var center := SmoothTerrain.point_of(hit.position)
	var radius: int = [1, 2, 3][SIZE_CELLS.find(cells)]
	var updates := {}
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if dx * dx + dy * dy + dz * dz > radius * radius:
					continue
				var point := center + Vector3i(dx, dy, dz)
				if not _in_terrain_limits(point) or terrain.is_stone(point):
					continue
				var around := 0.0
				for step in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
					around += terrain.density(point + step)
				var old := terrain.density(point)
				var value := clampf(old * 0.5 + around / 12.0, -1.0, 1.0)
				if absf(value - old) < 0.01:
					continue
				if value > 0.0 and old <= 0.0:
					continue
				updates[point] = [value, -1]
	return _apply_terrain(updates)

# Applique un geste : points changés, zones et herbe autour recalculées une seule fois.
func _apply_terrain(updates: Dictionary) -> bool:
	if updates.is_empty():
		return false
	var fresh := updates.keys().filter(func(point): return not terrain.changes.has(point)).size()
	if terrain.changes.size() + fresh > SmoothTerrain.MAX_CHANGES:
		_notify("Limite du terrain sculpté atteinte.")
		return false
	var zones := {}
	var tiles := {}
	for point: Vector3i in updates:
		terrain.set_density(point, updates[point][0], updates[point][1])
		terrain.wake(point)
	_refresh_terrain(updates.keys())
	return true

# Points changés (geste ou chute) : zones à enregistrer, pièces et herbe autour recalculées une fois.
func _refresh_terrain(points: Array) -> void:
	if flowing != null:
		flowing.terrain_changed(points)
	var zones := {}
	var tiles := {}
	for point: Vector3i in points:
		terrain_dirty[SmoothTerrain.point_zone(point)] = true
		for zone in SmoothTerrain.zones_using(point):
			if zone.x >= base_zones_low.x and zone.x <= base_zones_high.x and zone.z >= base_zones_low.y and zone.z <= base_zones_high.y:
				zones[zone] = true
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				tiles[Vector2i(floori((point.x + dx * 2) * SmoothTerrain.STEP / 8.0), floori((point.z + dz * 2) * SmoothTerrain.STEP / 8.0))] = true
	# 0.0.5.17 : seulement les colonnes affichées ; les autres seront faites en arrivant à portée.
	for zone: Vector3i in zones:
		var column := Vector2i(zone.x, zone.z)
		if column_shown(column):
			if not zone in shown_columns[column]:
				shown_columns[column].append(zone)
			rebuild_terrain_piece(zone)
	for tile: Vector2i in tiles:
		if column_shown(tile):
			_rebuild_lawn_tile(tile)

# 0.0.5.11 : la terre et le sable tombent peu à peu (un cran de 50 cm toutes les FALL_SECONDS) ;
# 0.0.5.12 : plus lent (0,15 s par cran au lieu de 0,06), pour bien voir tomber.
const FALL_SECONDS := 0.15
var fall_time := 0.0

func _settle_terrain(delta: float) -> void:
	if terrain.unstable.is_empty():
		fall_time = 0.0
		return
	fall_time += delta
	if fall_time < FALL_SECONDS:
		return
	fall_time = 0.0
	var moved := terrain.settle_step()
	if not moved.is_empty():
		_refresh_terrain(moved)

# Tout laisser retomber d'un coup (tests, et avant d'enregistrer en quittant).
func settle_all(limit: int = 2000) -> void:
	var moved := {}
	while not terrain.unstable.is_empty() and limit > 0:
		limit -= 1
		for point in terrain.settle_step():
			moved[point] = true
	if not moved.is_empty():
		_refresh_terrain(moved.keys())


func spawn_position() -> Vector3:
	# Apparition en X 0, Y 0, Z 0 (Y 1 avant 0.0.3.22) : pieds posés sur le sol plat, au centre de la case 0, 0.
	# Les blocs posés depuis comptent aussi : on réapparaît dessus, sans chevauchement.
	var top := 0
	for cell: Vector3i in blocks:
		if cell.x == 0 and cell.z == 0:
			top = maxi(top, cell.y + 1)
	return Vector3(0.5, top + 0.01, 0.5)

# Coordonnées affichées : case des pieds, en blocs. Y = hauteur des pieds au-dessus du sol plat
# (0.0.3.22 ; Y 1 au sol avant) : Y 0 au sol, Y 2 sur 2 blocs empilés.
func player_coordinates() -> Vector3i:
	var feet: Vector3 = player.position
	return Vector3i(floori(feet.x), floori(feet.y + 0.001), floori(feet.z))

# Bornes des cases (min, max) d'une étendue centrée sur 0, ex. base de 160 : −80 à 79.
static func cell_range(size: int) -> Vector2i:
	var low := -floori(size / 2.0)
	return Vector2i(low, low + size - 1)

# Textes communs (0.0.3.22) : mêmes repères que les coordonnées affichées, pour Comment jouer,
# Informations du monde (F3) et Accueil → Informations.
const COORDINATES_NOTE := "Coordonnées en blocs (1 bloc = 1 m) : X largeur, Y hauteur des pieds (Y 0 sur le sol plat), Z longueur."

static func base_side(half_zones: int = Generation.half_zones()) -> int:
	return half_zones * 16

static func base_range_text(half_zones: int = Generation.half_zones()) -> String:
	var base := cell_range(base_side(half_zones))
	return "X et Z de %d à %d" % [base.x, base.y]

static func generation_range_text() -> String:
	return "X et Z de %d à %d" % [TerrainGenerator.MIN_CELL, TerrainGenerator.MAX_CELL]

static func build_range_text(half_zones: int = Generation.half_zones()) -> String:
	return "X et Z de %d à %d" % [3 - base_side(half_zones) / 2, base_side(half_zones) / 2 - 3]

# 0.0.5.5 : monde tout plat, sans bloc au départ (demande de l'utilisateur, le terrain deviendra lisse) ;
# une plage de sable plate d'environ 21 m², au niveau de l'herbe, à une dizaine de mètres de l'apparition.
# Peinte par la matière du sol (terrain_surface.gdshader), bord irrégulier ; pas d'herbe dessus.
const SAND_CENTER := Vector2(11.0, 9.0)
const SAND_RADIUS := 2.6

static func sand_area() -> int:
	return roundi(PI * SAND_RADIUS * SAND_RADIUS)

func _create_blocks() -> void:
	pass

# Blocs de départ (aucun depuis 0.0.5.5), rangés par zone.
# Il ne change pas avec le découpage : même graine, même monde. Seules les différences sont enregistrées.
func _generate_block(cell: Vector3i, kind: int) -> void:
	if generated.has(cell) or generated.size() >= MAX_BLOCKS:
		return
	generated[cell] = kind
	var zone := Zones.zone_of(cell)
	if not generated_by_zone.has(zone):
		generated_by_zone[zone] = []
	generated_by_zone[zone].append(cell)

func player_data() -> Dictionary:
	return {"format": Store.FORMAT, "position": [player.position.x, player.position.y, player.position.z],
		"regard_horizontal": player.rotation.y, "regard_vertical": player.camera.rotation.x,
		# 0.0.7.2 : inventaire (Survie et Créatif), barre d'objets et case en main.
		"inventaire": inventory.to_dict()}

func _read_saved_player() -> Dictionary:
	if save_folder.is_empty():
		return {}
	var saved := Store.read_json(save_folder.path_join(Store.PLAYER_FILE), Store.valid_player)
	if saved.has("error"):
		_notify(saved.error)
		notice_time = 8.0
	return saved.get("data", {})

func _apply_saved_player(data: Dictionary) -> void:
	if data.is_empty():
		return
	player.position = Vector3(float(data.position[0]), float(data.position[1]), float(data.position[2]))
	player.rotation.y = float(data.regard_horizontal)
	player.camera.rotation.x = clampf(float(data.regard_vertical), deg_to_rad(-89.0), deg_to_rad(89.0))

# Migration de l'étape 1 (0.0.5) : zones/modifications.json réparti en fichiers de zone ;
# l'ancien fichier est gardé (renommé) une fois toutes les zones écrites.
func _migrate_step1() -> void:
	if save_folder.is_empty() or not FileAccess.file_exists(save_folder.path_join(Store.CHANGES_FILE)):
		return
	var old := Store.read_json(save_folder.path_join(Store.CHANGES_FILE), Store.valid_changes)
	if old.has("error"):
		_notify(old.error)
		notice_time = 8.0
		return
	var by_zone := {}
	for entry in old.data.poses + old.data.casses:
		var cell := Vector3i(int(entry[0]), int(entry[1]), int(entry[2]))
		var zone := Zones.zone_of(cell)
		if not by_zone.has(zone):
			by_zone[zone] = [[], []]
		if entry.size() == 4:
			by_zone[zone][0].append([cell.x, cell.y, cell.z, int(entry[3])])
		else:
			by_zone[zone][1].append([cell.x, cell.y, cell.z])
	for zone: Vector3i in by_zone:
		if not Zones.write_zone(save_folder.path_join(Zones.zone_file(zone)), Zones.zone_data(zone, by_zone[zone][0], by_zone[zone][1])):
			_notify("Conversion en zones impossible : l'ancien fichier est gardé.")
			return
		zone_files[zone] = true
	DirAccess.rename_absolute(ProjectSettings.globalize_path(save_folder.path_join(Store.CHANGES_FILE)), ProjectSettings.globalize_path(save_folder.path_join(Zones.STEP1_KEPT)))

# Zones voulues autour d'une case : distance de chargement en zones, dans les limites de construction.
func wanted_zones(center: Vector3i) -> Dictionary:
	var result := {}
	var here := Zones.zone_of(center)
	var low := Zones.zone_of(Vector3i(-build_limit, 0, -build_limit))
	var high := Zones.zone_of(Vector3i(build_limit, MAX_BUILD_HEIGHT - 1, build_limit))
	for x in range(maxi(low.x, here.x - load_distance), mini(high.x, here.x + load_distance) + 1):
		for y in range(maxi(low.y, here.y - load_distance), mini(high.y, here.y + load_distance) + 1):
			for z in range(maxi(low.z, here.z - load_distance), mini(high.z, here.z + load_distance) + 1):
				result[Vector3i(x, y, z)] = true
	return result

# Met en file les zones à charger (les plus proches d'abord) et à décharger ; now : tout de suite.
func update_zones(center: Vector3i, now: bool = false) -> void:
	zone_center = Zones.zone_of(center)
	# 0.0.6.18 (#175) : mêmes zones que wanted_zones, comparées à leurs bornes (avant : un dictionnaire de 1 500 zones refait
	# et filtré à chaque zone traversée, plus de 3 ms en vol).
	var here := Zones.zone_of(center)
	var limit_low := Zones.zone_of(Vector3i(-build_limit, 0, -build_limit))
	var limit_high := Zones.zone_of(Vector3i(build_limit, MAX_BUILD_HEIGHT - 1, build_limit))
	var low := Vector3i(maxi(limit_low.x, here.x - load_distance), maxi(limit_low.y, here.y - load_distance), maxi(limit_low.z, here.z - load_distance))
	var high := Vector3i(mini(limit_high.x, here.x + load_distance), mini(limit_high.y, here.y + load_distance), mini(limit_high.z, here.z + load_distance))
	zone_queue = zone_queue.filter(func(item: Array): return item[0] == "section")
	for zone: Vector3i in loaded_zones:
		if zone.x < low.x or zone.y < low.y or zone.z < low.z or zone.x > high.x or zone.y > high.y or zone.z > high.z:
			zone_queue.append(["unload", zone])
	var missing: Array = []
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for z in range(low.z, high.z + 1):
				var zone := Vector3i(x, y, z)
				if not loaded_zones.has(zone):
					missing.append(zone)
	missing.sort_custom(func(a: Vector3i, b: Vector3i): return (a - zone_center).length_squared() < (b - zone_center).length_squared())
	for zone in missing:
		zone_queue.append(["load", zone])
	if now:
		while not zone_queue.is_empty():
			_run_queue_item(zone_queue.pop_front())

# Travail étalé : quelques zones ou sections par image, dans un budget de temps.
func process_zone_queue(budget_usec: int = 3000, max_items: int = -1) -> void:
	var started := Time.get_ticks_usec()
	var done := 0
	while not zone_queue.is_empty() and Time.get_ticks_usec() - started < budget_usec and done != max_items:
		done += 1
		_run_queue_item(zone_queue.pop_front())

func _run_queue_item(item: Array) -> void:
	if item[0] == "load":
		load_zone(item[1])
	elif item[0] == "unload":
		unload_zone(item[1])
	elif loaded_zones.has(Zones.zone_of(item[1] * Zones.SECTION_SIZE)):
		rebuild_section(item[1])

func load_zone(zone: Vector3i) -> void:
	if loaded_zones.has(zone):
		return
	var started := Time.get_ticks_usec()
	for cell: Vector3i in generated_by_zone.get(zone, []):
		blocks[cell] = generated[cell]
	# 0.0.6.18 (#175) : fichiers de zone connus depuis l'ouverture (avant : deux vérifications sur le disque par zone chargée).
	if zone_files.has(zone):
		var saved := Zones.read_zone(save_folder.path_join(Zones.zone_file(zone)))
		if saved.has("data"):
			for entry in saved.data.casses:
				blocks.erase(Vector3i(entry[0], entry[1], entry[2]))
			for entry in saved.data.poses:
				blocks[Vector3i(entry[0], entry[1], entry[2])] = entry[3]
		elif saved.has("error"):
			_notify(saved.error)
			notice_time = 8.0
	loaded_zones[zone] = true
	# Zone vide (ni terrain ni fichier) : rien à afficher, le cas le plus courant en hauteur.
	if generated_by_zone.has(zone) or zone_files.has(zone):
		for section in Zones.zone_sections(zone):
			rebuild_section(section)
	last_zone_load_ms = (Time.get_ticks_usec() - started) / 1000.0

func unload_zone(zone: Vector3i) -> void:
	if not loaded_zones.has(zone):
		return
	if dirty_zones.has(zone):
		_save_zone(zone)
	for cell: Vector3i in blocks.keys():
		if Zones.zone_of(cell) == zone:
			blocks.erase(cell)
	loaded_zones.erase(zone)
	for section in Zones.zone_sections(zone):
		if sections.has(section):
			sections[section].free()
			sections.erase(section)
	# Les faces des zones voisines cachées par celle-ci réapparaissent (0.0.6.18 : rien à refaire sans aucun bloc).
	for face in Zones.FACES if not blocks.is_empty() else []:
		if loaded_zones.has(zone + face[0]):
			for section in Zones.zone_sections(zone + face[0]):
				zone_queue.append(["section", section])

func rebuild_section(section: Vector3i) -> void:
	var started := Time.get_ticks_usec()
	if sections.has(section):
		sections[section].free()
		sections.erase(section)
	var body := Zones.build_section(blocks, section, BLOCK_COLORS, block_material, block_box)
	if body != null:
		add_child(body)
		sections[section] = body
	last_section_ms = (Time.get_ticks_usec() - started) / 1000.0

func section_body(cell: Vector3i) -> StaticBody3D:
	return sections.get(Zones.section_of(cell))

func _zone_changes(zone: Vector3i) -> Array:
	var placed: Array = []
	var removed: Array = []
	for cell: Vector3i in blocks:
		if Zones.zone_of(cell) == zone and generated.get(cell, -1) != blocks[cell]:
			placed.append([cell.x, cell.y, cell.z, blocks[cell]])
	for cell: Vector3i in generated_by_zone.get(zone, []):
		if not blocks.has(cell):
			removed.append([cell.x, cell.y, cell.z])
	return [placed, removed]

# Une zone revenue au terrain de la graine n'a plus de fichier.
func _save_zone(zone: Vector3i) -> bool:
	if save_folder.is_empty():
		dirty_zones.erase(zone)
		return true
	var path := save_folder.path_join(Zones.zone_file(zone))
	# 0.0.5.8 : même fichier pour les blocs et le terrain ; zone de blocs pas chargée : ses blocs sont relus.
	var changes := [[], []]
	if loaded_zones.has(zone):
		changes = _zone_changes(zone)
	elif FileAccess.file_exists(path):
		var saved: Dictionary = Zones.read_zone(path).get("data", {})
		changes = [saved.get("poses", []), saved.get("casses", [])]
	var dense := terrain.zone_entries(zone)
	var ok := true
	if changes[0].is_empty() and changes[1].is_empty() and dense.is_empty():
		if FileAccess.file_exists(path):
			ok = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
		if ok:
			zone_files.erase(zone)
	else:
		ok = Zones.write_zone(path, Zones.zone_data(zone, changes[0], changes[1], dense))
		if ok:
			zone_files[zone] = true
	if ok:
		dirty_zones.erase(zone)
		terrain_dirty.erase(zone)
	return ok

# Au retour aux mondes, à la pause, à la fermeture et toutes les 45 s : joueur et zones modifiées.
func save_now() -> bool:
	autosave_time = 0.0
	if save_folder.is_empty() or not is_instance_valid(player):
		return true
	# 0.0.5.11 : ce qui tombe encore est posé à sa place avant d'enregistrer.
	settle_all()
	var ok := Store.write_json(save_folder.path_join(Store.PLAYER_FILE), player_data())
	# 0.0.5.19 : rochers minés.
	ok = _save_objects() and ok
	# 0.0.6.6 : eau (niveaux des lacs, eau libre), seulement si elle a bougé.
	if flowing != null:
		ok = flowing.save(save_folder) and ok
	for zone: Vector3i in dirty_zones.keys():
		if loaded_zones.has(zone) and not _save_zone(zone):
			ok = false
	for zone: Vector3i in terrain_dirty.keys():
		if not _save_zone(zone):
			ok = false
	save_error = "" if ok else "Sauvegarde impossible : vérifiez l'espace disque."
	if not ok:
		_notify(save_error)
	return ok

# Bloc posé ou cassé par le joueur : zone à enregistrer, sections touchées recalculées tout de suite.
func _changed(cell: Vector3i) -> void:
	dirty_zones[Zones.zone_of(cell)] = true
	for section in Zones.touched_sections(cell):
		rebuild_section(section)

func add_block(cell: Vector3i, kind: int) -> bool:
	if blocks.has(cell) or blocks.size() >= MAX_BLOCKS:
		return false
	if kind < 0 or kind >= BLOCK_COLORS.size():
		return false
	blocks[cell] = kind
	for section in Zones.touched_sections(cell):
		rebuild_section(section)
	return true

# reach : portée de l'action (casse ou pose), réglable dans Attributs → Blocs.
func _valid_hit(hit: Dictionary, reach: float) -> bool:
	if hit.is_empty() or not is_instance_valid(hit.get("collider")):
		return false
	if player.camera.global_position.distance_to(hit.position) > reach + 0.01:
		return false
	return hit.collider.is_in_group("blocks") or hit.collider.is_in_group("ground") or hit.collider.is_in_group("rocks") or hit.collider.is_in_group("pebbles")

# 0.0.5.8 : clic gauche : creuser le terrain lisse (les blocs posés avant restent, sans casse ni pose).
func break_target(hit: Dictionary) -> bool:
	# 0.0.6.9 : les arbres ne se coupent pas (série 0.0.6).
	if not hit.is_empty() and is_instance_valid(hit.get("collider")) and hit.collider.is_in_group("trees"):
		return false
	# 0.0.5.19 : un rocher se mine à la pioche (sinon un message).
	# 0.0.6.3 : un caillou se casse à la pioche, en 1 à 3 coups selon sa taille.
	if not hit.is_empty() and is_instance_valid(hit.get("collider")) and hit.collider.is_in_group("pebbles"):
		if not _valid_hit(hit, player.break_reach):
			return false
		if player.selected_type != PICKAXE:
			_notify(_needs_pickaxe("Les cailloux se cassent"))
			return false
		return strike_pebble(hit.collider)
	if not hit.is_empty() and is_instance_valid(hit.get("collider")) and hit.collider.is_in_group("rocks"):
		if not _valid_hit(hit, player.break_reach):
			return false
		if player.selected_type != PICKAXE:
			_notify(_needs_pickaxe("Les rochers se cassent"))
			return false
		return mine_rock(hit.collider, hit)
	var pickaxe: bool = player.selected_type == PICKAXE
	# 0.0.6 : pierre à la pioche : une sous-cellule de 50 cm par coup, là où l'on vise ; pierre sombre : 2 coups.
	if pickaxe and _aimed_ground(hit, player.break_reach):
		var aimed := SmoothTerrain.point_of(hit.position - hit.normal * 0.3)
		if terrain.is_stone(aimed) and _in_terrain_limits(aimed):
			return _strike_stone(aimed, hit.position)
	var stone := not hit.is_empty() and terrain.is_stone(SmoothTerrain.point_of(hit.position - hit.normal * 0.3))
	var done := sculpt(hit, false, -1, SIZE_CELLS[player.brush_size], pickaxe)
	if done:
		_debris(hit.position, Color("#6f6b66") if stone else Color("#6b4a2e"))
	return done

# Legacy domain operation for saved-data/constraint regression tests; not player input.
func _edit_break_target(hit: Dictionary) -> bool:
	if not _valid_hit(hit, player.break_reach):
		return false
	var collider: Node = hit.collider
	if not collider.is_in_group("blocks"):
		_notify("Le sol est indestructible. Visez un bloc.")
		return false
	var cell := hit_cell(hit)
	if not blocks.has(cell):
		return false
	blocks.erase(cell)
	_changed(cell)
	return true

# Case du bloc visé : juste derrière la face touchée (ou « cell » donné par une visée simulée).
static func hit_cell(hit: Dictionary) -> Vector3i:
	if hit.has("cell"):
		return hit.cell
	var point: Vector3 = hit.position - hit.normal * 0.02
	return Vector3i(floori(point.x), floori(point.y), floori(point.z))

# Clic droit : le pinceau choisi (B + T), avec la matière choisie (sable ou terre) et la taille (B + molette).
func place_target(hit: Dictionary, kind: int) -> bool:
	if not hit.is_empty() and is_instance_valid(hit.get("collider")) and hit.collider.is_in_group("trees"):
		return false
	# 0.0.7.4 : un objet en main (caillou, éclat…) se pose au sol là où l'on vise.
	if player.brush == 0 and Inventory.is_object(inventory.held()):
		return put_down_held(hit)
	# 0.0.7.2 : poser seulement ce qu'on a en main (barre d'objets) ; aplanir et lisser n'ajoutent pas de matière.
	if player.brush == 0 and not kind in PLACEABLE:
		_notify("Rien à poser : prenez une matière en main (inventaire : O + I)." if game_mode == Inventory.CREATIVE else "Rien à poser en main.")
		return false
	var cells: int = SIZE_CELLS[player.brush_size]
	match player.brush:
		1:
			return flatten(hit, cells)
		2:
			return smooth(hit, cells)
	# 0.0.7.3 : en Survie, poser utilise ce qu'on tient (une poignée par sous-cellule) ; en Créatif, illimité.
	if game_mode == Inventory.SURVIVAL:
		cells = mini(cells, Inventory.count(inventory.held()))
		if cells <= 0:
			_notify("Rien à poser en main.")
			return false
	var done := sculpt(hit, true, kind, cells)
	if done and game_mode == Inventory.SURVIVAL:
		inventory.use_held(last_gesture_points)
	return done

func _edit_place_target(hit: Dictionary, kind: int) -> bool:
	if not _valid_hit(hit, player.place_reach):
		return false
	var point: Vector3 = hit.position + hit.normal * 0.02
	var cell := Vector3i(floori(point.x), floori(point.y), floori(point.z))
	if cell.y < 0 or cell.y >= MAX_BUILD_HEIGHT or absi(cell.x) > build_limit or absi(cell.z) > build_limit:
		_notify("Limite de construction atteinte.")
		return false
	if player.overlaps_cell(cell):
		_notify("Reculez un peu pour poser ce bloc.")
		return false
	if blocks.size() >= MAX_BLOCKS:
		_notify("Limite de 1200 blocs atteinte : cassez-en quelques-uns.")
		return false
	if not add_block(cell, kind):
		return false
	dirty_zones[Zones.zone_of(cell)] = true
	return true

func _create_selection() -> void:
	selection = MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#fff5c4")
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for axis in range(3):
		for a in [-1.0, 1.0]:
			for b in [-1.0, 1.0]:
				var start := Vector3.ZERO
				var finish := Vector3.ZERO
				start[axis] = -0.505
				finish[axis] = 0.505
				start[(axis + 1) % 3] = a * 0.505
				finish[(axis + 1) % 3] = a * 0.505
				start[(axis + 2) % 3] = b * 0.505
				finish[(axis + 2) % 3] = b * 0.505
				mesh.surface_add_vertex(start)
				mesh.surface_add_vertex(finish)
	mesh.surface_end()
	selection.mesh = mesh
	selection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(selection)

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var left := VBoxContainer.new()
	left.name = "LeftHUD"
	left.position = Vector2(18,18)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation",roundi(5 * text_scale))
	layer.add_child(left)
	# 0.0.7.2 : plus de « Bloc sélectionné » en haut à gauche : l'objet en main se voit dans la barre d'objets.
	var exploration := Label.new()
	exploration.name = "ExplorationNotice"
	exploration.text = "Clic gauche : creuser · clic droit : pinceau (B + T) · taille : B + molette · inventaire : O + I"
	exploration.add_theme_font_size_override("font_size",roundi(14 * text_scale))
	exploration.add_theme_color_override("font_shadow_color",Color.BLACK)
	exploration.add_theme_constant_override("shadow_outline_size",3)
	exploration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(exploration)
	fps_label = Label.new()
	fps_label.name = "FPS"
	fps_label.text = "FPS : —"
	fps_label.add_theme_font_size_override("font_size",roundi(20 * text_scale))
	fps_label.add_theme_color_override("font_color",Color(1,1,1,1))
	fps_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	fps_label.add_theme_constant_override("shadow_outline_size",4)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(fps_label)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 30)
	crosshair.add_theme_color_override("font_shadow_color", Color.BLACK)
	crosshair.add_theme_constant_override("shadow_outline_size", 3)
	crosshair.name = "Crosshair"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -20
	crosshair.offset_right = 20
	crosshair.offset_top = -24
	crosshair.offset_bottom = 24
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(crosshair)
	# 0.0.7.2 : barre d'objets en bas au centre, écran d'inventaire (inventory_ui.gd) ; les messages juste au-dessus.
	inventory_ui = InventoryUI.new()
	add_child(inventory_ui)
	inventory_ui.setup(inventory, text_scale)
	inventory_ui.overflow.connect(drop_items)
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_bottom = -inventory_ui.hud_height() - 8
	hint.offset_top = hint.offset_bottom - 40
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", roundi(19 * text_scale))
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_outline_size", 4)
	layer.add_child(hint)
	# Coordonnées (0.0.3.14) : en haut à droite, sous les rappels F1 à F3, si activées dans Vidéo.
	coordinates_label = Label.new()
	coordinates_label.name = "Coordinates"
	coordinates_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	coordinates_label.offset_left = -280
	coordinates_label.offset_right = -18
	coordinates_label.offset_top = 18 + roundi(80 * text_scale)
	coordinates_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coordinates_label.add_theme_font_size_override("font_size", roundi(16 * text_scale))
	coordinates_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	coordinates_label.add_theme_constant_override("shadow_outline_size", 3)
	coordinates_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coordinates_label.visible = false
	layer.add_child(coordinates_label)

func set_coordinates_visible(on: bool) -> void:
	coordinates_label.visible = on
	_update_coordinates()

func coordinates_text() -> String:
	var at := player_coordinates()
	return "X %d · Y %d · Z %d" % [at.x, at.y, at.z]

func _update_coordinates() -> void:
	if is_instance_valid(coordinates_label) and coordinates_label.visible and is_instance_valid(player):
		coordinates_label.text = coordinates_text()

# Taille du texte changée en pause (Paramètres, 0.0.3.9) : textes du jeu mis à jour aussitôt.
func apply_text_scale(scale: float) -> void:
	text_scale = scale
	if is_instance_valid(hint):
		hint.add_theme_font_size_override("font_size", roundi(19 * text_scale))
		coordinates_label.add_theme_font_size_override("font_size", roundi(16 * text_scale))
		coordinates_label.offset_top = 18 + roundi(80 * text_scale)
		var exploration: Label = find_child("ExplorationNotice",true,false)
		exploration.add_theme_font_size_override("font_size",roundi(14 * text_scale))
		fps_label.add_theme_font_size_override("font_size",roundi(20 * text_scale))
		fps_label.get_parent().add_theme_constant_override("separation",roundi(5 * text_scale))

# 0.0.5.9 : choix du joueur (matière, pinceau, taille), en bas, seulement quand il change.
func show_choice(message: String) -> void:
	_notify(message)

func _notify(message: String) -> void:
	notice = message
	notice_time = 2.5

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_update_fps(delta)
	_update_collisions()
	_update_underwater()
	_update_water(delta)
	# Sauvegarde régulière (petits fichiers, seulement les zones modifiées : pas de saccade).
	autosave_time += delta
	if autosave_time >= AUTOSAVE_SECONDS:
		save_now()
	notice_time = maxf(0.0, notice_time - delta)
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var hit: Dictionary = player.get_target()
	selection.visible = false
	if selection.visible:
		selection.global_position = Vector3(hit_cell(hit)) + Vector3.ONE * 0.5
	# Zones autour du joueur : file mise à jour en changeant de zone, travail étalé sur les images.
	var here := player_coordinates()
	if Zones.zone_of(here) != zone_center:
		update_zones(here)
	process_zone_queue()
	_settle_terrain(delta)
	_process_hide_queue()
	update_terrain_view(false, Vector2i(floori(player.position.x / SmoothTerrain.ZONE_SIZE), floori(player.position.z / SmoothTerrain.ZONE_SIZE)))
	_process_far_queue()
	_process_terrain_queue()
	_update_pebble_blocks()
	# Image calme (rien à construire) : un modèle d'arbre de plus préparé d'avance.
	if terrain_queue.is_empty() and far_queue.is_empty():
		Trees.warm_next()
	hint.text = notice if notice_time > 0.0 else ""
	_update_coordinates()

# level : 0 = −, 1 = Par défaut, 2 = + (textes complets d'avant 0.0.3.3), selon Synthèse des textes.
# 0.0.5.11 : plus affiché (page Comment jouer retirée) ; gardé comme résumé des commandes, vérifié par les tests.
static func get_help_text(level: int = 2) -> String:
	if level == 0:
		return "ZQSD : marcher. ↑ ↓ + A : vitesse (⌫ ⌫ : défaut). Espace : sauter ; deux fois : voler. Clic gauche : creuser ; droit : poser, aplanir ou lisser (B + T).
Molette ou 1 à 0 : barre d'objets ; O + I : inventaire ; B + molette : taille. Échap : pause. F1 : mondes. F4 : vue."
	if level == 1:
		return "ZQSD / WASD : marcher (← → : de côté). Souris : regarder. Espace : sauter.
Y : se baisser. R : courir (mode dans Contrôles).
↑ ↓ + A : tout le déplacement plus ou moins vite ; + W : marche, + R : course,
⌫ + touche : par défaut ; ⌫ deux fois : tout.
Espace deux fois : voler (Espace monte, Y descend) ; encore deux fois : arrêter.
Clic gauche : creuser ; clic droit : pinceau (B + T : poser, aplanir, lisser).
B + molette : taille du geste (1/8, 1/4, 1/2 bloc). Molette ou 1 à 0 : barre d'objets. O + I : inventaire.
Échap : pause. F1 : liste des mondes. F3 : Informations.
F4 : vue (première personne, de derrière, de devant).
Portée : %d blocs. Maximum : %d blocs, hauteur %d (Y 0 sur le sol plat).
Constructions et position sauvegardées (pause, retour, fermeture, toutes les 45 s).
Touches modifiables : Paramètres → Contrôles." % [int(PlayerScript.REACH), MAX_BLOCKS, MAX_BUILD_HEIGHT]
	return "ZQSD / WASD : marcher ; ← → : aller de côté. Souris : regarder. Espace : sauter.
Y : se baisser. R : courir. Modes dans Contrôles : Maintenir, Basculer,
et pour courir Maintenir conditionnel (un appui lance la course ; s'arrêter,
sauter, se baisser ou la pause l'arrêtent, puis il faut réappuyer sur R).
↑ + A maintenus : tout le déplacement (marche, course, baissé, vol) de plus en plus rapide ;
↓ + A : de plus en plus lent. ↑ ou ↓ avec W : la marche seule ; avec R : la course seule ;
avec clic gauche ou droit : rien pour l'instant (un clic = un geste sur le terrain).
Limites : 75 à 150 %% dans un monde par défaut, Attributs en mode développeur.
La vitesse choisie reste. A ou W tenus avec ↑, ↓ ou ⌫ ne font pas bouger.
⌫ + la même touche (A, W, R, clic) : cette valeur par défaut ;
⌫ deux fois : tout par défaut.
Voler : Espace deux fois (rapidement) ; en vol, pas de gravité, Espace maintenu monte,
Y maintenu descend ; Espace deux fois à nouveau : on retombe. Vitesses dans Attributs → Voler,
↑ ↓ comptent aussi en vol. R en vol : voler vite.
Nager : dans l'eau profonde, on flotte ; Espace maintenu monte, Y maintenu plonge (ou avancer en regardant en bas) ;
R : nager vite ; Espace contre la rive : sortir de l'eau. Les rivières emportent doucement vers l'aval.

Terrain lisse (sous-cellules de 50 cm, 8 par bloc de 1 m) : clic gauche creuse ; clic droit utilise le pinceau
choisi avec B + T : Poser (la matière en main), Aplanir (sol mis à la hauteur visée)
ou Lisser (formes adoucies). B + molette : taille du geste, 1/8, 1/4 ou 1/2 bloc (1, 2 ou 4 sous-cellules).
Le choix s'affiche en bas quand on le change. Poser : jusqu'à 40 blocs de haut.
Sous le gazon : 5 m de terre qu'on peut creuser, 10 m de pierre et 10 m de pierre sombre (à la pioche), puis la Roche-mère, incassable.
Les blocs posés avant sont conservés ; plus de casse ni de pose de blocs pour l'instant.

Barre d'objets (molette ou 1 à 0) : l'objet en main. O + I : inventaire (Créatif : Matériaux naturels, Outils ; Survie : 4 cases). Avec la pioche, le clic gauche casse aussi la pierre.
Le sable reste immobile, même sans support.

Échap : pause et souris libre. Reprendre / Échap : retour direct au jeu.
Le clic de capture ne casse ni ne pose. F1 : liste des mondes.
F3 : Informations du monde (jeu en pause).
F4 : changer de vue, première personne, de derrière, puis de devant (on voit son personnage).

Portée : %d blocs. Base protégée. Maximum : %d blocs présents.
Hauteur maximale : %d blocs au-dessus du sol plat (sommet à Y %d).
Construction : %s.
%s

Nom, graine, mode, constructions et position sauvegardés : pause, retour aux mondes, fermeture, toutes les 45 s.
Touches modifiables (clavier, clics, molette) : Paramètres → Contrôles, aussi depuis la pause." % [int(PlayerScript.REACH), MAX_BLOCKS, MAX_BUILD_HEIGHT, MAX_BUILD_HEIGHT, build_range_text(), COORDINATES_NOTE]

func get_world_info_text(level: int = 2) -> String:
	# Position du joueur (0.0.3.14), en tête, à tous les niveaux de détail.
	var who: String = CharacterPreview.CHARACTERS.get(player.character, CharacterPreview.CHARACTERS.boy14).name
	if CharacterPreview.is_human(player.character):
		who += ", " + CharacterPreview.SKINS.get(player.skin, CharacterPreview.SKINS.light).name.to_lower()
	return "Votre position actuelle : %s
Personnage : %s
%s
%s
%s" % [coordinates_text(), who, creation_text, zones_text(), _world_info_body(level)]

# 0.0.5.1 : mesures en direct (aussi dans le navigateur) : zones, temps de chargement et de recalcul, images/s.
func zones_text() -> String:
	return "Zones de %d m chargées : %d (distance %d) · zone : %.1f ms · recalcul : %.1f ms · %d images/s" % [Zones.ZONE_SIZE, loaded_zones.size(), load_distance, last_zone_load_ms, last_section_ms, Engine.get_frames_per_second()]

# Ligne ajoutée au mode quand le mode développeur a déjà servi (vide sinon).
func _used_note() -> String:
	return "
" + DEVELOPER_USED_NOTE if developer_used else ""

# Le compteur ne refait son texte que deux fois par seconde pendant le jeu.
func _update_fps(delta: float) -> void:
	fps_elapsed += delta
	if fps_elapsed < FPS_INTERVAL:
		return
	fps_elapsed = fmod(fps_elapsed,FPS_INTERVAL)
	fps_label.text = "FPS : %d" % Engine.get_frames_per_second()

func _notification(what: int) -> void:
	if is_instance_valid(fps_label) and what in [NOTIFICATION_PAUSED,NOTIFICATION_UNPAUSED]:
		fps_label.visible = what == NOTIFICATION_UNPAUSED
		fps_elapsed = 0.0

func _read_creation_date() -> void:
	creation_text = WorldMetadata.read_creation(save_folder)

static func format_creation_date(value: Variant) -> String:
	return WorldMetadata.format_creation_date(value)

func _world_info_body(level: int) -> String:
	if level == 0:
		return "Monde : %s · Graine : %d
Mode : %s" % [world_name, terrain_seed, world_mode_text] + _used_note()
	if level == 1:
		return "Monde : %s
Graine : %d
Mode : %s
Base %d × %d, plage de sable d'environ %d m².
Constructions sauvegardées." % [world_name, terrain_seed, world_mode_text, int(base_size.x), int(base_size.z), sand_area()] + _used_note()
	var mode_line := "Mode : %s — %s" % [world_mode_text, "attributs de Paramètres → Attributs" if developer_mode else "attributs par défaut, non modifiables"]
	mode_line += _used_note()
	return "Monde : %s
Graine : %d
%s

Relief selon la graine : collines jusqu'à 3 m, petites bosses, parfois une crête abrupte ou un trou,
petits et grands déserts de sable ; plat autour de l'apparition ; en herbe ;
une plage de sable d'environ %d m² à une dizaine de mètres de l'apparition.
Sous-sol : %s (à casser à la pioche), puis la Roche-mère incassable.

Base plate : largeur %d × longueur %d blocs (%s), sol à Y 0
Construction : hauteur maximale %d blocs au-dessus du sol plat (sommet à Y %d), %s.
%s

Nom, graine, mode, constructions et position sauvegardés." % [world_name, terrain_seed, mode_line, sand_area(), ("5 m de terre, 20 m de pierre et 20 m de pierre sombre" if int(generation_options.get("version", 0)) >= 19 else "5 m de terre, 10 m de pierre et 10 m de pierre sombre"), int(base_size.x), int(base_size.z), base_range_text(_half_zones()), MAX_BUILD_HEIGHT, MAX_BUILD_HEIGHT, build_range_text(_half_zones()), COORDINATES_NOTE]

# 0.0.5.13 : éclats de terre ou de pierre là où l'on vient de creuser (animation simple, une fois).
func _debris(at: Vector3, color: Color) -> void:
	var burst := CPUParticles3D.new()
	burst.name = "Debris"
	burst.one_shot = true
	burst.amount = 14
	burst.lifetime = 0.7
	burst.explosiveness = 1.0
	burst.direction = Vector3.UP
	burst.spread = 55.0
	burst.initial_velocity_min = 1.2
	burst.initial_velocity_max = 2.6
	burst.scale_amount_min = 0.6
	burst.scale_amount_max = 1.2
	var piece := BoxMesh.new()
	piece.size = Vector3.ONE * 0.06
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	piece.material = material
	burst.mesh = piece
	burst.position = at + Vector3.UP * 0.05
	add_child(burst)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)

func set_grass_distance(distance: float) -> void:
	grass_distance = clampf(distance,8.0,96.0)
	TerrainMaterials.grass_range = grass_distance
	for patch in find_children("GrassDetail","MultiMeshInstance3D",true,false):
		TerrainMaterials.set_patch_range(patch, grass_distance)

# 0.0.5.18 : objets du monde (objets.json, dans son dossier) : rochers (taille et forme 1 à 7, position X Z,
# rotation) et étiquettes (textes flottants, pour les mondes d'essai). Posés sur le sol de la graine.
# 0.0.5.19 : rochers de la graine (génération version 4), affichés avec leur colonne ; rochers minés à la pioche
# gardés dans objets.json (« rochers_mines » : identifiants), jamais recréés.
var rocks_node: Node3D
var objects_data: Dictionary = {}
var mined_rocks: Dictionary = {}
var objects_dirty := false
var _rock_material: ShaderMaterial
var _water_material: ShaderMaterial

static func valid_objects(data: Dictionary) -> bool:
	if data.get("format") != 1.0 and data.get("format") != 1:
		return false
	for rock in data.get("rochers", []):
		if not rock is Dictionary or not int(rock.get("taille", 0)) in range(1, 8) or not int(rock.get("forme", 0)) in range(1, 8):
			return false
		if not (rock.get("x") is float or rock.get("x") is int) or not (rock.get("z") is float or rock.get("z") is int):
			return false
	for label in data.get("etiquettes", []):
		if not label is Dictionary or not label.get("texte") is String:
			return false
	for id in data.get("rochers_mines", []):
		if not id is String:
			return false
	for id in data.get("cailloux_casses", []):
		if not id is String:
			return false
	# 0.0.6 : cubes retirés des rochers entamés : [x, y, z] entiers (sous-cellules du terrain).
	var carved: Variant = data.get("rochers_entames", {})
	if not carved is Dictionary:
		return false
	for id in carved:
		if not carved[id] is Array or not carved[id].all(func(entry): return entry is Array and entry.size() == 3 and entry.all(func(n): return (n is int or n is float) and float(n) == floorf(float(n)))):
			return false
	return true

# Lu avant d'afficher le terrain : les rochers minés ne doivent pas réapparaître avec leur colonne.
func _read_objects() -> void:
	if save_folder.is_empty() or not FileAccess.file_exists(save_folder.path_join(Store.OBJECTS_FILE)):
		return
	var saved := Store.read_json(save_folder.path_join(Store.OBJECTS_FILE), valid_objects)
	if saved.has("error"):
		_notify(saved.error)
		notice_time = 8.0
		return
	objects_data = saved.get("data", {})
	for id in objects_data.get("rochers_mines", []):
		mined_rocks[id] = true
	_read_carved(objects_data)

func _read_carved(data: Dictionary) -> void:
	for id in data.get("cailloux_casses", []):
		broken_pebbles[id] = true
	# 0.0.7.5 : fruits cueillis, par arbre (numéros des fruits du modèle, trees.gd fruit_spots).
	var picked: Variant = data.get("fruits_cueillis", {})
	if picked is Dictionary:
		for id in picked:
			if picked[id] is Array:
				picked_fruits[str(id)] = picked[id].filter(func(number): return number is int or number is float).map(func(number): return int(number))
	var carved: Dictionary = data.get("rochers_entames", {})
	for id in carved:
		carved_rocks[id] = carved[id].map(func(entry): return [int(entry[0]), int(entry[1]), int(entry[2])])

# Objets de la liste du monde (rochers et étiquettes des mondes d'essai), une fois le terrain prêt.
func _load_objects() -> void:
	if not objects_data.is_empty():
		place_objects(objects_data)

func _rocks_parent() -> Node3D:
	if not is_instance_valid(rocks_node):
		rocks_node = Node3D.new()
		rocks_node.name = "Rocks"
		add_child(rocks_node)
	return rocks_node

func _make_rock(rock: Dictionary, id: String) -> StaticBody3D:
	if _rock_material == null:
		_rock_material = TerrainMaterials.surface(true)
	var size := int(rock.taille)
	var shape := int(rock.forme)
	var body := Rocks.rock_body(size, shape, _rock_material)
	var x := float(rock.x)
	var z := float(rock.z)
	body.position = Vector3(x, terrain.height_at(x, z) + Rocks.bottom_offset(size, shape), z)
	body.rotation.y = deg_to_rad(float(rock.get("rotation", 0.0)))
	body.set_meta("id", id)
	body.set_meta("hits", 0)
	# 0.0.6.4 : rocher de calcaire ; rognon de silex caché au milieu, visible quand on le creuse.
	body.set_meta("look", 1 if rock.get("calcaire", false) else 0)
	if rock.get("calcaire", false):
		for child in body.get_children():
			if child is MeshInstance3D:
				child.material_override = _kind_material(1)
	if rock.get("silex", false):
		var nodule := MeshInstance3D.new()
		nodule.name = "Silex"
		nodule.mesh = Rocks.pebble_mesh(1)
		nodule.scale = Vector3.ONE * minf(0.35, Rocks.SIZES[size - 1] * 0.3)
		nodule.material_override = _kind_material(2)
		body.add_child(nodule)
	_rocks_parent().add_child(body)
	if carved_rocks.has(id) and not _apply_carving(body):
		body.free()
		mined_rocks[id] = true
		return null
	return body

func place_objects(data: Dictionary) -> void:
	objects_data = data
	for id in data.get("rochers_mines", []):
		mined_rocks[id] = true
	_read_carved(data)
	var index := 0
	for rock in data.get("rochers", []):
		var id := "liste_%d" % index
		index += 1
		if not mined_rocks.has(id):
			_make_rock(rock, id)
	for label in data.get("etiquettes", []):
		var text := Label3D.new()
		text.text = label.texte
		text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		text.font_size = 64
		text.pixel_size = 0.006
		text.outline_size = 12
		var x := float(label.get("x", 0.0))
		var z := float(label.get("z", 0.0))
		text.position = Vector3(x, terrain.height_at(x, z) + float(label.get("hauteur", 1.5)), z)
		_rocks_parent().add_child(text)

# Rochers et lacs de la graine d'une colonne (affichés et retirés avec elle).
func _show_column_objects(column: Vector2i) -> void:
	_hide_column_objects(column)
	_show_column_pebbles(column)
	_show_column_river(column)
	for rock in terrain.rocks_in_zone(column):
		if not mined_rocks.has(rock.id):
			var made := _make_rock(rock, rock.id)
			if made != null:
				made.set_meta("column", column)
				_column_object(column, made)
	# 0.0.6.9 (#149) : arbres fruitiers de la colonne (génération 21), détaillés de près, simplifiés au loin.
	for tree in terrain.trees_in_zone(column):
		var made := Trees.tree_body(int(tree.espece), int(tree.get("classe", 3)), tree.get("liane", false), int(tree.get("forme", 0)))
		made.position = Vector3(tree.x, terrain.height_at(tree.x, tree.z) - 0.05, tree.z)
		made.rotation.y = deg_to_rad(float(tree.rotation))
		made.scale = Vector3.ONE * float(tree.taille)
		made.set_meta("id", tree.id)
		if picked_fruits.has(str(tree.id)):
			Trees.apply_picked(made, picked_fruits[str(tree.id)])
		made.set_meta("column", column)
		_rocks_parent().add_child(made)
		_column_object(column, made)
	# 0.0.6.16 (#182) : plantes à fibres de la colonne (génération 27).
	var plant_list: Array = terrain.plants_in_zone(column)
	if not plant_list.is_empty():
		for node in Plants.column_nodes(plant_list, terrain.height_at):
			node.set_meta("column", column)
			_rocks_parent().add_child(node)
			_column_object(column, node)
	for lake in terrain.lakes_in_zone(column):
		var water := MeshInstance3D.new()
		water.name = "Lac"
		water.mesh = lake_water_mesh(terrain, lake)
		if _water_material == null:
			_water_material = ShaderMaterial.new()
			_water_material.shader = preload("res://shaders/water.gdshader")
			_water_material.set_shader_parameter("tone", 0.85 if is_compat() else 1.0)
			_clip_water()
		water.material_override = _water_material
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		water.position = Vector3(lake.center.x, flowing.lake_level_now(lake) if flowing != null else lake.level, lake.center.y)
		water.set_meta("lake_id", terrain.lake_id(lake))
		water.set_meta("column", column)
		water.add_to_group("water")
		_rocks_parent().add_child(water)
		_column_object(column, water)

# 0.0.6.7 (#124) : eau des rivières de cette colonne : un ruban posé sur le lit, à la hauteur de l'eau, du point de chaque
# morceau de rivière qui commence ici jusqu'au suivant ; rides qui descendent le courant (river.gdshader).
var _river_material: ShaderMaterial

func _show_column_river(column: Vector2i) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for river: Dictionary in terrain.rivers():
		var points: PackedVector2Array = river.points
		for index in range(points.size() - 1):
			if Vector2i(floori(points[index].x / SmoothTerrain.ZONE_SIZE), floori(points[index].y / SmoothTerrain.ZONE_SIZE)) != column:
				continue
			# 0.0.6.24 : bouts de lit creusés dans un lac : pas d'eau dessinée (celle du lac suffit).
			if (index == 0 and river.get("sans_debut", false)) or (index == points.size() - 2 and river.get("sans_fin", false)):
				continue
			var ends := []
			for k in [index, index + 1]:
				var before: Vector2 = points[maxi(k - 1, 0)]
				var after: Vector2 = points[mini(k + 1, points.size() - 1)]
				var side: Vector2 = (after - before).normalized().orthogonal() * river.widths[k] * 0.95
				var y: float = river.beds[k] + SmoothTerrain.RIVER_WATER
				ends.append([Vector3(points[k].x + side.x, y, points[k].y + side.y), Vector3(points[k].x - side.x, y, points[k].y - side.y), river.lengths[k]])
			var a: Vector3 = ends[0][0]
			var b: Vector3 = ends[0][1]
			var c: Vector3 = ends[1][1]
			var d: Vector3 = ends[1][0]
			vertices.append_array([a, b, c, a, c, d])
			uvs.append_array([Vector2(0, ends[0][2]), Vector2(1, ends[0][2]), Vector2(1, ends[1][2]), Vector2(0, ends[0][2]), Vector2(1, ends[1][2]), Vector2(0, ends[1][2])])
	if vertices.is_empty():
		return
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _river_material == null:
		_river_material = ShaderMaterial.new()
		_river_material.shader = preload("res://shaders/river.gdshader")
		_river_material.set_shader_parameter("tone", 0.66 if is_compat() else 1.0)
	var ribbon := MeshInstance3D.new()
	ribbon.name = "Riviere"
	ribbon.mesh = mesh
	ribbon.material_override = _river_material
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbon.add_to_group("water")
	_rocks_parent().add_child(ribbon)
	_column_object(column, ribbon)

func _column_object(column: Vector2i, node: Node) -> void:
	if not column_objects.has(column):
		column_objects[column] = []
	column_objects[column].append(node)

# 0.0.6.3 : cailloux d'une colonne, dessinés d'un coup par forme ; chacun a une petite collision ronde pour la pioche,
# sur la couche 2 : le joueur passe sur les petits sans buter, les deux plus gros (couches 1 et 2) l'arrêtent.
# Cassés : objets.json, « cailloux_casses » (identifiants) ; coups déjà donnés : seulement pendant la partie.
var broken_pebbles: Dictionary = {}
# 0.0.7.5 : fruits cueillis : identifiant de l'arbre → numéros des fruits.
var picked_fruits: Dictionary = {}
var pebble_hits: Dictionary = {}
var column_pebbles: Dictionary = {}

func _stone_material() -> ShaderMaterial:
	if _rock_material == null:
		_rock_material = TerrainMaterials.surface(true)
	return _rock_material

# 0.0.6.4 : calcaire (rochers) et silex (cailloux, rognons) : même matière, autre aspect (rock_kind 1 ou 2).
var _kind_materials: Dictionary = {}

func _kind_material(kind: int) -> ShaderMaterial:
	if not _kind_materials.has(kind):
		var made := TerrainMaterials.surface(true)
		made.set_shader_parameter("rock_kind", kind)
		_kind_materials[kind] = made
	return _kind_materials[kind]

func _show_column_pebbles(column: Vector2i) -> void:
	_hide_column_pebbles(column)
	# 0.0.6.18 (#175) : placements gardés par colonne et par forme ; dessinés par carré de 4 × 4 colonnes (avant : un dessin
	# par forme et par colonne, près de 2 000 dessins par image, les trois quarts de tous) ; collisions seulement près du joueur.
	var by_shape := {}
	var bodies := []
	for pebble in terrain.pebbles_in_zone(column):
		if broken_pebbles.has(pebble.id):
			continue
		var size: int = pebble.taille
		var shape: int = pebble.forme
		# Rapetisse un peu à chaque coup déjà reçu.
		var shrink: float = 1.0 - 0.2 * pebble_hits.get(pebble.id, 0)
		var diameter: float = Rocks.PEBBLE_SIZES[size - 1] * shrink
		var at := Vector3(pebble.x, terrain.height_at(pebble.x, pebble.z) + Rocks.pebble_lift(size, shape) * shrink, pebble.z)
		# Formes 1 à 7 ; aspect de chacun dans la donnée du caillou (0 pierre, 1 calcaire, 2 silex : terrain_surface.gdshader).
		var group := shape
		var look := 2.0 if pebble.get("silex", false) else (1.0 if pebble.get("calcaire", false) else 0.0)
		var basis := Basis(Vector3.UP, deg_to_rad(pebble.rotation)).scaled(Vector3.ONE * diameter)
		var placed: PackedFloat32Array = by_shape.get(group, PackedFloat32Array())
		placed.append_array([basis.x.x, basis.y.x, basis.z.x, at.x, basis.x.y, basis.y.y, basis.z.y, at.y, basis.x.z, basis.y.z, basis.z.z, at.z, 1.0, 1.0, 1.0, 1.0, look, 0.0, 0.0, 0.0])
		by_shape[group] = placed
		bodies.append([pebble.id, size, shape, diameter, at, int(look), float(pebble.rotation)])
	pebble_shapes[column] = by_shape
	pebble_bodies[column] = bodies
	_pebble_block_changed(column)
	if _pebble_near(column):
		_build_pebble_bodies(column)

# Petites collisions rondes des cailloux d'une colonne (pour la pioche ; les deux plus gros arrêtent le joueur).
func _build_pebble_bodies(column: Vector2i) -> void:
	if column_pebbles.has(column) or not pebble_bodies.has(column):
		return
	var nodes := []
	for spec: Array in pebble_bodies[column]:
		var size: int = spec[1]
		var body := StaticBody3D.new()
		body.name = "Caillou"
		body.add_to_group("pebbles")
		body.set_meta("id", spec[0])
		body.set_meta("pebble", Vector2i(size, spec[2]))
		body.set_meta("column", column)
		# 0.0.7.3 : aspect (0 pierre, 1 calcaire, 2 silex) : objet ramassé ou éclats.
		body.set_meta("look", spec[5] if spec.size() > 5 else 0)
		body.set_meta("rotation", spec[6] if spec.size() > 6 else 0.0)
		body.collision_layer = 3 if size >= 6 else 2
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = maxf(float(spec[3]) * 0.42, 0.04)
		collision.shape = sphere
		body.add_child(collision)
		body.position = spec[4]
		_rocks_parent().add_child(body)
		nodes.append(body)
	column_pebbles[column] = nodes

func _hide_column_pebbles(column: Vector2i) -> void:
	for node in column_pebbles.get(column, []):
		if is_instance_valid(node):
			node.free()
	column_pebbles.erase(column)
	pebble_bodies.erase(column)
	if pebble_shapes.erase(column):
		_pebble_block_changed(column)

# Carrés de cailloux (4 × 4 colonnes) : un dessin par forme et par aspect, refait quand une de ses colonnes change.
const PEBBLE_BLOCK := 4
var pebble_shapes: Dictionary = {}
var pebble_bodies: Dictionary = {}
var pebble_blocks: Dictionary = {}
var changed_pebble_blocks: Dictionary = {}
# Collisions des cailloux : colonne du joueur et ses voisines (la pioche porte à quelques mètres).
const PEBBLE_REACH := 1

func _pebble_near(column: Vector2i) -> bool:
	var here := _player_column()
	return maxi(absi(column.x - here.x), absi(column.y - here.y)) <= PEBBLE_REACH

var _pebbles_look: ShaderMaterial

func _pebble_material() -> ShaderMaterial:
	if _pebbles_look == null:
		_pebbles_look = TerrainMaterials.surface(true)
		_pebbles_look.set_shader_parameter("kind_per_instance", true)
	return _pebbles_look

func _pebble_block_changed(column: Vector2i) -> void:
	changed_pebble_blocks[Vector2i(floori(column.x / float(PEBBLE_BLOCK)), floori(column.y / float(PEBBLE_BLOCK)))] = true

func _update_pebble_blocks() -> void:
	for block: Vector2i in changed_pebble_blocks:
		_rebuild_pebble_block(block)
	changed_pebble_blocks.clear()

func _rebuild_pebble_block(block: Vector2i) -> void:
	for node in pebble_blocks.get(block, []):
		if is_instance_valid(node):
			node.free()
	pebble_blocks.erase(block)
	var by_shape := {}
	for x in range(block.x * PEBBLE_BLOCK, block.x * PEBBLE_BLOCK + PEBBLE_BLOCK):
		for z in range(block.y * PEBBLE_BLOCK, block.y * PEBBLE_BLOCK + PEBBLE_BLOCK):
			var shapes: Dictionary = pebble_shapes.get(Vector2i(x, z), {})
			for group: int in shapes:
				var placed: PackedFloat32Array = by_shape.get(group, PackedFloat32Array())
				placed.append_array(shapes[group])
				by_shape[group] = placed
	var nodes := []
	for group: int in by_shape:
		var buffer: PackedFloat32Array = by_shape[group]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		# Couleur blanche (neutre) en plus de l'aspect : sans elle, le rendu Compatibility (Web) lisait l'aspect comme couleur.
		multi.use_colors = true
		multi.use_custom_data = true
		multi.mesh = Rocks.pebble_mesh(group)
		multi.instance_count = buffer.size() / 20
		multi.buffer = buffer
		var drawn := MultiMeshInstance3D.new()
		drawn.name = "Cailloux"
		drawn.multimesh = multi
		drawn.material_override = _pebble_material()
		_rocks_parent().add_child(drawn)
		nodes.append(drawn)
	if not nodes.is_empty():
		pebble_blocks[block] = nodes

func strike_pebble(body: StaticBody3D) -> bool:
	var id: String = body.get_meta("id")
	var kind: Vector2i = body.get_meta("pebble")
	var column: Vector2i = body.get_meta("column")
	var at := body.global_position
	_debris(at, Color("#6f6b66"))
	_impact_sound(at)
	pebble_hits[id] = pebble_hits.get(id, 0) + 1
	if pebble_hits[id] >= Rocks.PEBBLE_HITS[kind.x - 1]:
		pebble_hits.erase(id)
		broken_pebbles[id] = true
		objects_dirty = true
		# 0.0.7.3 : le caillou cassé donne des éclats (250 g au plus chacun), qui tombent à côté du joueur.
		var weight: float = Inventory.PEBBLE_WEIGHTS[kind.x - 1]
		var pieces := maxi(1, ceili(weight / 250.0))
		drop_pieces(PEBBLE_PIECES[int(body.get_meta("look", 0))], pieces, roundf(weight / pieces), at)
	_show_column_pebbles(column)
	# Colonne visée : ses collisions refaites tout de suite (elle est près du joueur).
	_build_pebble_bodies(column)
	return true

func _hide_column_objects(column: Vector2i) -> void:
	for node in column_objects.get(column, []):
		if is_instance_valid(node):
			node.free()
	column_objects.erase(column)
	_hide_column_pebbles(column)

# Disque d'eau (surface plate, vue de dessus et de dessous) ; 0.0.5.20 : allongé (half : demi-segment du lac).
# 0.0.5.25 : lacs irréguliers (version 7 et plus) : l'eau suit le contour du lac, jamais par-dessus la rive.
static func lake_water_mesh(terrain, lake: Dictionary) -> ArrayMesh:
	if not lake.has("wobble_scale"):
		return _water_disc(lake.radius + lake.get("bank", 0.0) + 0.25, (lake.end - lake.start) / 2.0)
	var outline: PackedVector2Array = terrain.lake_outline(lake)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for index in range(outline.size()):
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		vertices.append_array([Vector3.ZERO, Vector3(b.x, 0, b.y), Vector3(a.x, 0, a.y)])
		normals.append_array([Vector3.UP, Vector3.UP, Vector3.UP])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _water_disc(radius: float, half: Vector2 = Vector2.ZERO) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 48
	var edge := func(angle: float) -> Vector3:
		var direction := Vector2(cos(angle), sin(angle))
		var at := direction * radius + (half if direction.dot(half) >= 0.0 else -half)
		return Vector3(at.x, 0, at.y)
	for index in range(sides):
		var a := TAU * index / sides
		var b := TAU * (index + 1) / sides
		for at in [Vector3.ZERO, edge.call(b), edge.call(a)]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(at)
	return tool.commit()

# Coup de pioche sur un rocher : il se fend un peu à chaque coup ; au bout d'autant de coups que sa taille, il casse.
# Coups de pioche par sous-cellule selon la pierre (plus dure : plus de coups). Roche-mère : jamais (hors limites).
const STONE_HITS := {SmoothTerrain.STONE: 1, SmoothTerrain.DARK_STONE: 2, SmoothTerrain.LIMESTONE: 1, SmoothTerrain.COAL: 1, SmoothTerrain.FLINT: 2}
# 0.0.6.4 : éclats de la couleur de la matière frappée.
const STONE_DEBRIS := {SmoothTerrain.DARK_STONE: Color("#4a4744"), SmoothTerrain.LIMESTONE: Color("#c4bca8"), SmoothTerrain.COAL: Color("#141416"), SmoothTerrain.FLINT: Color("#2a2a2e")}
var stone_target := Vector3i(999999, 0, 0)
var stone_hits := 0

func _strike_stone(point: Vector3i, at: Vector3) -> bool:
	var kind: int = terrain.materials.get(point, terrain.natural_kind(point))
	if point != stone_target:
		stone_target = point
		stone_hits = 0
	stone_hits += 1
	_debris(at, STONE_DEBRIS.get(kind, Color("#6f6b66")))
	_impact_sound(at)
	if stone_hits < STONE_HITS.get(kind, 1):
		return true
	stone_target = Vector3i(999999, 0, 0)
	stone_hits = 0
	var done := _apply_terrain({point: [SmoothTerrain.DUG, -1]})
	# 0.0.7.3 : la sous-cellule cassée donne deux morceaux (250 g en tout), qui tombent à côté du joueur.
	if done:
		drop_pieces(STONE_PIECES.get(kind, "eclat_pierre"), 2, STONE_PIECE_WEIGHT, at)
	return done

# 0.0.6 : rocher creusé à la pioche, une sous-cellule de 50 cm par coup (cubes alignés sur le terrain) ;
# la forme se creuse là où l'on frappe. Sauvegarde : objets.json, « rochers_entames » (cubes retirés par rocher).
var carved_rocks: Dictionary = {}

func mine_rock(body: StaticBody3D, hit: Dictionary = {}) -> bool:
	var id: String = body.get_meta("id")
	if not body.has_meta("grid"):
		var rock: Vector2i = body.get_meta("rock")
		body.set_meta("grid", Rocks.shape_grid(rock.x, rock.y, body.global_transform))
	var grid: Dictionary = body.get_meta("grid")
	var aim: Vector3 = hit.get("position", body.global_position)
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	var removed: Array = carved_rocks.get(id, [])
	var rock_size: Vector2i = body.get_meta("rock")
	var noise := Rocks._noise_for(rock_size.x, rock_size.y)
	var inverse := body.global_transform.affine_inverse()
	# La sous-cellule visée, ou la suivante plus au fond si elle est déjà vide ou hors du rocher.
	var chosen := Vector3i(999999, 0, 0)
	for depth in [0.15, 0.4, 0.65, 0.9]:
		var point := SmoothTerrain.point_of(aim - normal * depth)
		if [point.x, point.y, point.z] in removed:
			continue
		if Rocks.shape_distance(inverse * (Vector3(point) * SmoothTerrain.STEP), rock_size.x, rock_size.y, noise) < 0.3:
			chosen = point
			break
	_debris(aim, Color("#6f6b66"))
	_impact_sound(aim)
	if chosen.x == 999999:
		return false
	removed.append([chosen.x, chosen.y, chosen.z])
	carved_rocks[id] = removed
	objects_dirty = true
	drop_pieces("eclat_calcaire" if body.get_meta("look", 0) == 1 else "eclat_pierre", 2, STONE_PIECE_WEIGHT, aim)
	if not _apply_carving(body):
		carved_rocks.erase(id)
		mined_rocks[id] = true
		body.queue_free()
		show_choice("Rocher cassé")
	return true

# Refait la forme et la collision d'un rocher entamé ; faux s'il ne reste rien.
func _apply_carving(body: StaticBody3D) -> bool:
	if not body.has_meta("grid"):
		var rock: Vector2i = body.get_meta("rock")
		body.set_meta("grid", Rocks.shape_grid(rock.x, rock.y, body.global_transform))
	var centers: Array = carved_rocks.get(body.get_meta("id"), []).map(func(entry): return Vector3(entry[0], entry[1], entry[2]) * SmoothTerrain.STEP)
	var grid: Dictionary = body.get_meta("grid")
	var faces := Rocks.carved_faces(grid, Rocks.carved_values(grid, centers))
	if faces.is_empty():
		return false
	var inverse := body.global_transform.affine_inverse()
	var local := PackedVector3Array()
	local.resize(faces.size())
	for index in range(faces.size()):
		local[index] = inverse * faces[index]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_color(Color(1.0, 0.0, 1.0, 1.0))
	for vertex in local:
		tool.add_vertex(vertex)
	tool.index()
	tool.generate_normals()
	for child in body.get_children():
		if child is MeshInstance3D and child.name != "Silex":
			child.mesh = tool.commit()
		elif child is CollisionShape3D:
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = true
			shape.set_faces(local)
			child.shape = shape
	return true

# Petit choc de pioche : son fait ici (bruit bref et note sourde qui s'éteignent vite), aucun fichier externe.
static var _impact_stream: AudioStreamWAV

func _impact_sound(at: Vector3) -> void:
	if _impact_stream == null:
		var rate := 22050
		var data := PackedByteArray()
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var length := int(rate * 0.14)
		data.resize(length * 2)
		for index in range(length):
			var t := float(index) / rate
			var fade := exp(-t * 38.0)
			var sample := (rng.randf_range(-1.0, 1.0) * 0.55 + sin(TAU * 190.0 * t) * 0.45 + sin(TAU * 1300.0 * t) * 0.2 * exp(-t * 90.0)) * fade
			data.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 26000.0))
		_impact_stream = AudioStreamWAV.new()
		_impact_stream.format = AudioStreamWAV.FORMAT_16_BITS
		_impact_stream.mix_rate = rate
		_impact_stream.data = data
	var player_3d := AudioStreamPlayer3D.new()
	player_3d.stream = _impact_stream
	player_3d.pitch_scale = randf_range(0.9, 1.1)
	player_3d.volume_db = -6.0
	add_child(player_3d)
	player_3d.global_position = at
	player_3d.finished.connect(player_3d.queue_free)
	player_3d.play()

func _save_objects() -> bool:
	if save_folder.is_empty() or not objects_dirty:
		return true
	var data := objects_data.duplicate(true)
	if data.is_empty():
		data = {"format": 1}
	data.rochers_mines = mined_rocks.keys()
	data.rochers_entames = carved_rocks.duplicate(true)
	data.cailloux_casses = broken_pebbles.keys()
	data.fruits_cueillis = picked_fruits.duplicate(true)
	# 0.0.7.3 : objets posés au sol (ground_items.gd).
	if is_instance_valid(ground):
		data.objets_au_sol = ground.to_array()
	var ok := Store.write_json(save_folder.path_join(Store.OBJECTS_FILE), data)
	if ok:
		objects_dirty = false
	return ok

# 0.0.5.22 (#128) : terrain lointain simplifié (far_terrain.gd), au-delà de la distance d'affichage, jusqu'à la
# distance lointaine (Paramètres → Vidéo, en zones ; 0 : rien au-delà). Carrés de 4 × 4 zones refaits peu à peu.
var far_distance := 24
var far_node: Node3D
var far_tiles: Dictionary = {}
var far_queue: Array = []
var near_area := Rect2()
const FAR_BUDGET_USEC := 4000
const FAR_NO_LIMIT := 9223372036854775807
var far_opening := true

func _update_far(center: Vector2i, area: Rect2) -> void:
	far_center = center
	near_area = area
	_clip_water()
	if not is_instance_valid(far_node):
		far_node = Node3D.new()
		far_node.name = "FarTerrain"
		add_child(far_node)
	var wanted := {}
	if far_distance > load_distance and relief:
		var here := FarTerrain.tile_of(center)
		var reach := ceili(far_distance / float(FarTerrain.TILE_ZONES))
		var low := FarTerrain.tile_of(base_zones_low)
		var high := FarTerrain.tile_of(base_zones_high)
		for x in range(maxi(low.x, here.x - reach), mini(high.x, here.x + reach) + 1):
			for z in range(maxi(low.y, here.y - reach), mini(high.y, here.y + reach) + 1):
				# 0.0.6 : aussi les carrés à portée du terrain détaillé : ils restent tant que le détail n'est pas affiché.
				wanted[Vector2i(x, z)] = true
	for tile: Vector2i in far_cells.keys():
		if not wanted.has(tile):
			if far_tiles.has(tile):
				far_tiles[tile].free()
				far_tiles.erase(tile)
			far_cells.erase(tile)
	far_queue = far_queue.filter(func(tile: Vector2i): return wanted.has(tile))
	for tile: Vector2i in wanted:
		# Nouveau carré ou finesse changée (2 m près du joueur, 4 m, puis 8 m au loin) : à refaire (0.0.5.25 : sinon,
		# rien à faire ; le trou suit les colonnes affichées, _far_follow_column).
		var changed: bool = far_cells.has(tile) and far_cells[tile] != _far_cell(tile)
		if (not far_cells.has(tile) or changed) and not tile in far_queue:
			far_queue.append(tile)
	var center_tile := FarTerrain.tile_of(center)
	far_queue.sort_custom(func(a: Vector2i, b: Vector2i): return maxi(absi(a.x - center_tile.x), absi(a.y - center_tile.y)) < maxi(absi(b.x - center_tile.x), absi(b.y - center_tile.y)))

var far_center := Vector2i.ZERO
# 0.0.6 : finesse de chaque carré lointain fait (même sans morceau : tout couvert par le détail).
var far_cells: Dictionary = {}
# Colonnes dont le terrain détaillé est vraiment affiché : le lointain s'efface seulement là.
var built_columns: Dictionary = {}

func _far_active() -> bool:
	return far_distance > load_distance and relief

# Une colonne affichée ou cachée : les carrés lointains autour refont leur trou en premier (relevé déjà fait),
# dans le temps de chaque image (pas d'à-coup quand toute une rangée change).
func _far_follow_column(column: Vector2i) -> void:
	if not _far_active():
		return
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var tile := FarTerrain.tile_of(column + Vector2i(dx, dz))
			if far_cells.has(tile) and not tile in far_queue:
				far_queue.push_front(tile)

func _clip_water() -> void:
	if _water_material == null:
		return
	var inner := near_area.grow(-2.0) if far_distance > load_distance and relief else Rect2(-100000.0, -100000.0, 200000.0, 200000.0)
	_water_material.set_shader_parameter("near_rect", Vector4(inner.position.x, inner.position.y, inner.end.x, inner.end.y))

func _far_cell(tile: Vector2i) -> float:
	# Au bord du terrain détaillé : toujours fin (pas de relief grossier qui dépasse).
	if Rect2(Vector2(tile) * FarTerrain.TILE_METERS, Vector2.ONE * FarTerrain.TILE_METERS).intersects(near_area):
		return FarTerrain.CELL
	var here := FarTerrain.tile_of(far_center)
	var ring := maxi(absi(tile.x - here.x), absi(tile.y - here.y))
	return FarTerrain.CELL if ring <= 2 else (FarTerrain.CELL * 2.0 if ring <= 4 else FarTerrain.CELL * 4.0)

# 0.0.5.25 : relevés gardés (finesse comprise) : ne recalcule jamais un carré déjà vu.
var far_surveys: Dictionary = {}

func _far_survey(tile: Vector2i) -> Dictionary:
	var cell := _far_cell(tile)
	var key := Vector3i(tile.x, tile.y, int(cell))
	if not far_surveys.has(key):
		far_surveys[key] = FarTerrain.new_survey(tile, cell)
	return far_surveys[key]

func _build_far_tile(tile: Vector2i, deadline: int = FAR_NO_LIMIT) -> bool:
	var survey := _far_survey(tile)
	if not FarTerrain.advance(terrain, survey, deadline):
		return false
	if far_tiles.has(tile):
		far_tiles[tile].free()
		far_tiles.erase(tile)
	far_cells[tile] = survey.cell
	# Le terrain lointain passe 2 m sous le bord du terrain détaillé : pas de fente entre les deux.
	# 0.0.6 : seulement sous les colonnes déjà affichées (built_columns), pas sous toute la distance d'affichage.
	var mesh := FarTerrain.mesh_of(survey, Rect2(), built_columns)
	if mesh == null:
		return true
	var piece := MeshInstance3D.new()
	piece.name = "Lointain_%d_%d" % [tile.x, tile.y]
	piece.mesh = mesh
	piece.set_meta("cell", survey.cell)
	piece.material_override = FarTerrain.material()
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far_node.add_child(piece)
	far_tiles[tile] = piece
	return true

func _process_far_queue() -> void:
	# Beaucoup de carrés à faire à l'ouverture du monde : deux fois plus de temps par image. 0.0.6.18 (#175) : seulement
	# à l'ouverture (en vol, la file dépasse souvent 20 carrés : 8 ms par image en plus du terrain, des à-coups).
	var deadline := Time.get_ticks_usec() + (FAR_BUDGET_USEC * 2 if far_opening and far_queue.size() > 20 else FAR_BUDGET_USEC)
	if far_queue.is_empty():
		far_opening = false
	while not far_queue.is_empty() and Time.get_ticks_usec() < deadline:
		if not _build_far_tile(far_queue[0], deadline):
			return
		far_queue.pop_front()
