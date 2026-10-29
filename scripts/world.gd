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
const FarTerrain = preload("res://scripts/far_terrain.gd")
const Rocks = preload("res://scripts/rocks.gd")
const DIRT := 2
const BLOCK_COLORS := [Color("#d8c291"), Color("#888b90"), Color("#855332")]
const BLOCK_NAMES := ["Sable", "Pierre", "Terre"]
const MAX_BLOCKS := 1200
# 0.0.5.20 : monde de 48 × 48 zones de 8 m (384 m ; 20 × 20 en 0.0.5.18, 16 × 16 avant).
# (Préparation des niveaux de détail, #128 : on ne charge que les zones autour du joueur.)
const BASE_SIZE := Vector3(384, 1, 384)
const MAX_BUILD_HEIGHT := 25
# Construction permise de X et Z −189 à 189, à l'intérieur de la base (−73 à 73 en 0.0.5.18, −57 à 57 avant).
const BUILD_LIMIT := 189

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
var selected_block_label: Label
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

func _ready() -> void:
	_read_creation_date()
	_setup_inputs()
	_setup_environment()
	# 0.0.5.1 : une seule matière pour tous les blocs, couleur portée par les sommets de chaque section.
	TerrainMaterials.density = grass_density
	TerrainMaterials.grass_range = grass_distance
	block_material = TerrainMaterials.surface()
	block_box = BoxShape3D.new()
	_create_ground()
	var saved_player := _read_saved_player()
	var start_at := Vector3.ZERO
	if not saved_player.is_empty():
		start_at = Vector3(float(saved_player.position[0]), 0.0, float(saved_player.position[2]))
	_create_terrain(start_at)
	_load_objects()
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
	_create_selection()
	_create_hud()

func _setup_inputs() -> void:
	# Touches choisies dans Paramètres → Contrôles (0.0.3.12), appliquées par le menu ;
	# monde lancé seul (tests) : touches par défaut.
	Controls.ensure_defaults()

# 0.0.4.17 : rendu Compatibility (version Web) : la lumière y paraît bien plus forte qu'avec Forward+ (Windows),
# couleurs délavées (sable et pierre blancs). 0.0.4.19 : réglé en comparant des captures des deux rendus :
# conversion des couleurs simple (tonemap linéaire). 0.0.5.8 : le Web paraissait trop sombre (herbe, soleil) :
# soleil × 0,75 (avant 0,48), lumière ambiante × 0,6 (avant 0,38).
const COMPAT_SUN := 0.75
const COMPAT_AMBIENT := 0.6

static func apply_compat_light(environment: Environment, sun: DirectionalLight3D) -> void:
	if not is_compat():
		return
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	sun.light_energy *= COMPAT_SUN
	environment.ambient_light_energy *= COMPAT_AMBIENT

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
	apply_compat_light(environment, sun)
	add_child(sun)

func _create_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.add_to_group("ground")
	# 0.0.5.8 : la base indestructible (Roche-mère depuis 0.0.5.12) est sous la terre et la pierre ; le sol visible au-dessus
	# est le terrain lisse (pièces par zone, _create_terrain).
	ground.position = Vector3(0, BASE_TOP - 0.5, 0)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = BASE_SIZE
	mesh.mesh = box
	ground_material = TerrainMaterials.surface(true)
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
	update_terrain_view(true)
	# Le socle (Roche-mère) n'est jamais à voir : seulement sa collision, sous le terrain.
	get_node("Ground").get_child(0).visible = false

# 0.0.5.17 : distance d'affichage (Paramètres → Vidéo, 8 zones par défaut, 1 à 32), comptée à l'horizontale :
# toutes les zones où passe la surface d'une colonne proche sont affichées, quelle que soit la hauteur du
# joueur (en volant, on voit toujours le sol). Colonnes proches (NEAR_ZONES) faites tout de suite ; les autres
# d'abord plates, puis refaites peu à peu (les plus proches d'abord). Hors distance : retirées (terrain, herbe).
const NEAR_ZONES := 2
const TERRAIN_BUDGET_USEC := 5000
var terrain_queue: Array = []
var shown_columns: Dictionary = {}
var view_center := Vector2i(999999, 0)

func wanted_columns(center: Vector2i) -> Dictionary:
	var result := {}
	for x in range(maxi(BASE_ZONES_LOW.x, center.x - load_distance), mini(BASE_ZONES_HIGH.x, center.x + load_distance) + 1):
		for z in range(maxi(BASE_ZONES_LOW.y, center.y - load_distance), mini(BASE_ZONES_HIGH.y, center.y + load_distance) + 1):
			result[Vector2i(x, z)] = true
	return result

func update_terrain_view(force: bool = false, center: Vector2i = view_center) -> void:
	if not force and center == view_center:
		return
	view_center = center
	_update_fog()
	var wanted := wanted_columns(center)
	for column: Vector2i in shown_columns.keys():
		if not wanted.has(column):
			_hide_column(column)
	var by_column := {}
	# 0.0.5.20 : seulement les colonnes à portée (monde de 48 × 48 zones : jamais tout le monde d'un coup).
	var near_low := Vector2i(maxi(BASE_ZONES_LOW.x, center.x - load_distance), maxi(BASE_ZONES_LOW.y, center.y - load_distance))
	var near_high := Vector2i(mini(BASE_ZONES_HIGH.x, center.x + load_distance), mini(BASE_ZONES_HIGH.y, center.y + load_distance))
	for zone: Vector3i in terrain.surface_zones(near_low, near_high):
		var column := Vector2i(zone.x, zone.z)
		if wanted.has(column) and not shown_columns.has(column):
			if not by_column.has(column):
				by_column[column] = []
			by_column[column].append(zone)
	var later: Array = []
	for column: Vector2i in by_column:
		shown_columns[column] = by_column[column]
		if maxi(absi(column.x - center.x), absi(column.y - center.y)) <= NEAR_ZONES:
			_show_column(column)
		else:
			for zone: Vector3i in by_column[column]:
				if SmoothTerrain.ground_zone(zone):
					rebuild_terrain_piece(zone, true)
			later.append(column)
	terrain_queue = terrain_queue.filter(func(column: Vector2i): return wanted.has(column)) + later
	terrain_queue.sort_custom(func(a: Vector2i, b: Vector2i): return maxi(absi(a.x - center.x), absi(a.y - center.y)) < maxi(absi(b.x - center.x), absi(b.y - center.y)))
	_update_far(center, Rect2(Vector2(near_low) * SmoothTerrain.ZONE_SIZE, Vector2(near_high - near_low + Vector2i.ONE) * SmoothTerrain.ZONE_SIZE))

# Colonne affichée : ses zones de surface et son herbe.
func _show_column(column: Vector2i) -> void:
	for zone: Vector3i in shown_columns.get(column, []):
		rebuild_terrain_piece(zone)
	_rebuild_lawn_tile(column)
	_show_column_objects(column)

func _hide_column(column: Vector2i) -> void:
	shown_columns.erase(column)
	_hide_column_objects(column)
	for zone: Vector3i in terrain_pieces.keys():
		if zone.x == column.x and zone.z == column.y:
			terrain_pieces[zone].free()
			terrain_pieces.erase(zone)
	for child in lawn.get_children():
		if child.get_meta("tile", Vector2i(999, 999)) == column:
			child.free()

func column_shown(column: Vector2i) -> bool:
	return shown_columns.has(column)

func _process_terrain_queue() -> void:
	var started := Time.get_ticks_usec()
	while not terrain_queue.is_empty() and Time.get_ticks_usec() - started < TERRAIN_BUDGET_USEC:
		var column: Vector2i = terrain_queue.pop_front()
		if shown_columns.has(column):
			_show_column(column)

# Tout le terrain en attente, d'un coup (tests, captures).
func finish_terrain() -> void:
	while not terrain_queue.is_empty():
		var column: Vector2i = terrain_queue.pop_front()
		if shown_columns.has(column):
			_show_column(column)
	while not far_queue.is_empty():
		_build_far_tile(far_queue.pop_front())

# Brume au loin, au bord de la distance d'affichage : le terrain ne s'arrête pas d'un coup.
func _update_fog() -> void:
	if not is_instance_valid(environment):
		return
	# 0.0.5.22 : jusqu'au bout du terrain lointain (niveaux de détail) s'il va plus loin.
	var reach := float(maxi(load_distance, far_distance if relief else 0) * SmoothTerrain.ZONE_SIZE)
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color("#b9e2fa")
	environment.fog_density = 1.0
	environment.fog_depth_begin = reach * 0.65
	environment.fog_depth_end = reach
	environment.fog_sky_affect = 0.0

# 0.0.5.8 : terrain lisse sur toute la base (0.0.5.18 : zones de X et Z −80 à 79) ; base indestructible en dessous.
# 0.0.5.12 : la base (« Roche-mère », incassable) commence à 8 m sous le sol, sous 4 m de terre et 4 m de pierre.
const BASE_TOP := SmoothTerrain.BEDROCK_TOP * SmoothTerrain.STEP
const BASE_ZONES_LOW := Vector2i(-24, -24)
const BASE_ZONES_HIGH := Vector2i(23, 23)

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
	var body := StaticBody3D.new()
	body.name = "Terrain_%d_%d_%d" % [zone.x, zone.y, zone.z]
	body.add_to_group("ground")
	body.set_meta("zone", zone)
	var instance := MeshInstance3D.new()
	instance.material_override = ground_material
	var collision := CollisionShape3D.new()
	if flat_for_now or terrain.is_flat(zone):
		if not SmoothTerrain.ground_zone(zone):
			body.free()
			return
		body.position = Vector3(zone.x, 0, zone.z) * SmoothTerrain.ZONE_SIZE
		instance.mesh = flat_ground_mesh
		collision.shape = flat_ground_shape
		collision.position = Vector3(SmoothTerrain.ZONE_SIZE / 2.0, -0.5, SmoothTerrain.ZONE_SIZE / 2.0)
	else:
		var surface := terrain.zone_mesh(zone)
		if surface[0].is_empty():
			body.free()
			return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surface[0]
		arrays[Mesh.ARRAY_NORMAL] = surface[1]
		arrays[Mesh.ARRAY_COLOR] = surface[2]
		arrays[Mesh.ARRAY_TEX_UV] = surface[3]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		instance.mesh = mesh
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(surface[0])
		collision.shape = shape
	body.add_child(instance)
	body.add_child(collision)
	terrain_node.add_child(body)
	terrain_pieces[zone] = body
	last_section_ms = (Time.get_ticks_usec() - started) / 1000.0

# Herbe écartée là où le terrain a été sculpté (colonne de 50 cm et ses voisines) et dans les déserts.
func _grass_skipped(at: Vector3) -> bool:
	# 0.0.5.15 : pas d'herbe dans les déserts.
	# 0.0.5.20 : ni sur la boue au bord des lacs.
	var column := Vector2i(roundi(at.x / SmoothTerrain.STEP), roundi(at.z / SmoothTerrain.STEP))
	return terrain.column_changed(column) or terrain.is_desert(Vector2(at.x, at.z)) or terrain.muddy(column)

func _rebuild_lawn_tile(tile: Vector2i) -> void:
	for child in lawn.get_children():
		if child.get_meta("tile", Vector2i(999, 999)) == tile:
			child.free()
	var node := TerrainMaterials.lawn_tile(tile, generated, terrain_seed, SAND_CENTER, SAND_RADIUS, _grass_skipped, terrain.height_at)
	if node != null:
		lawn.add_child(node)
# Gestes de terrain (0.0.5.8, pinceaux en 0.0.5.9). Clic gauche : creuser ; clic droit : le pinceau
# choisi avec B + T (poser, aplanir, lisser). Taille (B + molette) : 1/8, 1/4 ou 1/2 bloc, soit 1, 2 ou
# 4 sous-cellules de 50 cm ; aplanir et lisser agissent autour, sur 50 cm, 1 m ou 1,5 m.
const BRUSH_NAMES := ["Poser", "Aplanir", "Lisser"]
const SIZE_NAMES := ["1/8 de bloc", "1/4 de bloc", "1/2 bloc"]
const SIZE_CELLS := [1, 2, 4]
# Matières qu'on peut poser pour l'instant (0.0.5.9 : plus la pierre).
const PLACEABLE := [0, 2, SmoothTerrain.CLAY, SmoothTerrain.MUD]
# 0.0.5.13 : la pioche, dans la même sélection (molette : Sable, Terre, Pioche ; touches 1, 2, 3).
const PICKAXE := 3
# 0.0.5.20 : argile (touche 4) et boue (touche 5) avant la pioche.
const SELECTION := [0, 2, SmoothTerrain.CLAY, SmoothTerrain.MUD, PICKAXE]

func choice_name(kind: int) -> String:
	if kind == SmoothTerrain.CLAY:
		return "Argile"
	if kind == SmoothTerrain.MUD:
		return "Boue"
	return "Pioche" if kind == PICKAXE else BLOCK_NAMES[kind]

func choice_text(kind: int) -> String:
	return ("Outil : %s" if kind == PICKAXE else "Matière : %s") % choice_name(kind)

func _aimed_ground(hit: Dictionary, reach: float) -> bool:
	if not _valid_hit(hit, reach):
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

# 0.0.5.13 : jusqu'à la pierre juste au-dessus de la Roche-mère (la pierre : seulement à la pioche).
func _in_terrain_limits(point: Vector3i) -> bool:
	return point.y > SmoothTerrain.BEDROCK_TOP and point.y <= SmoothTerrain.HIGH_POINT and absi(point.x) <= BUILD_LIMIT * 2 and absi(point.z) <= BUILD_LIMIT * 2

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
			if point.y <= SmoothTerrain.BEDROCK_TOP:
				message = "Roche-mère : incassable."
			elif point.y > SmoothTerrain.HIGH_POINT:
				message = "Hauteur maximale atteinte : 40 blocs."
			else:
				message = "Limite de construction atteinte."
			continue
		if (terrain.density(point) > 0.0) == add:
			continue
		if not add and terrain.is_stone(point) and not pickaxe:
			message = "La pierre se casse avec la pioche (molette ou touche 3)."
			continue
		if add and _inside_player(point):
			message = "Reculez un peu pour ajouter du terrain."
			continue
		updates[point] = [SmoothTerrain.ADDED if add else SmoothTerrain.DUG, kind if add else -1]
	if updates.is_empty() and not message.is_empty():
		_notify(message)
	return _apply_terrain(updates)

# Aplanir : bosses coupées à la hauteur visée, sur un disque autour. 0.0.5.10 : n'ajoute jamais de matière
# (les creux restent : seul Poser ajoute).
func flatten(hit: Dictionary, cells: int = 1) -> bool:
	if not _aimed_ground(hit, player.place_reach):
		return false
	var level := clampf(hit.position.y, SmoothTerrain.LOW_POINT * SmoothTerrain.STEP, SmoothTerrain.HIGH_POINT * SmoothTerrain.STEP)
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
	var zones := {}
	var tiles := {}
	for point: Vector3i in points:
		terrain_dirty[SmoothTerrain.point_zone(point)] = true
		for zone in SmoothTerrain.zones_using(point):
			if zone.x >= BASE_ZONES_LOW.x and zone.x <= BASE_ZONES_HIGH.x and zone.z >= BASE_ZONES_LOW.y and zone.z <= BASE_ZONES_HIGH.y:
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

static func base_range_text() -> String:
	var base := cell_range(int(BASE_SIZE.x))
	return "X et Z de %d à %d" % [base.x, base.y]

static func generation_range_text() -> String:
	return "X et Z de %d à %d" % [TerrainGenerator.MIN_CELL, TerrainGenerator.MAX_CELL]

static func build_range_text() -> String:
	return "X et Z de %d à %d" % [-BUILD_LIMIT, BUILD_LIMIT]

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
		"regard_horizontal": player.rotation.y, "regard_vertical": player.camera.rotation.x}

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
	DirAccess.rename_absolute(ProjectSettings.globalize_path(save_folder.path_join(Store.CHANGES_FILE)), ProjectSettings.globalize_path(save_folder.path_join(Zones.STEP1_KEPT)))

# Zones voulues autour d'une case : distance de chargement en zones, dans les limites de construction.
func wanted_zones(center: Vector3i) -> Dictionary:
	var result := {}
	var here := Zones.zone_of(center)
	var low := Zones.zone_of(Vector3i(-BUILD_LIMIT, 0, -BUILD_LIMIT))
	var high := Zones.zone_of(Vector3i(BUILD_LIMIT, MAX_BUILD_HEIGHT - 1, BUILD_LIMIT))
	for x in range(maxi(low.x, here.x - load_distance), mini(high.x, here.x + load_distance) + 1):
		for y in range(maxi(low.y, here.y - load_distance), mini(high.y, here.y + load_distance) + 1):
			for z in range(maxi(low.z, here.z - load_distance), mini(high.z, here.z + load_distance) + 1):
				result[Vector3i(x, y, z)] = true
	return result

# Met en file les zones à charger (les plus proches d'abord) et à décharger ; now : tout de suite.
func update_zones(center: Vector3i, now: bool = false) -> void:
	zone_center = Zones.zone_of(center)
	var wanted := wanted_zones(center)
	zone_queue = zone_queue.filter(func(item: Array): return item[0] == "section")
	for zone: Vector3i in loaded_zones.keys():
		if not wanted.has(zone):
			zone_queue.append(["unload", zone])
	var missing: Array = wanted.keys().filter(func(zone: Vector3i): return not loaded_zones.has(zone))
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
	if not save_folder.is_empty():
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
	if generated_by_zone.has(zone) or FileAccess.file_exists(save_folder.path_join(Zones.zone_file(zone))) and not save_folder.is_empty():
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
	# Les faces des zones voisines cachées par celle-ci réapparaissent.
	for face in Zones.FACES:
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
	else:
		ok = Zones.write_zone(path, Zones.zone_data(zone, changes[0], changes[1], dense))
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
	return hit.collider.is_in_group("blocks") or hit.collider.is_in_group("ground") or hit.collider.is_in_group("rocks")

# 0.0.5.8 : clic gauche : creuser le terrain lisse (les blocs posés avant restent, sans casse ni pose).
func break_target(hit: Dictionary) -> bool:
	# 0.0.5.19 : un rocher se mine à la pioche (sinon un message).
	if not hit.is_empty() and is_instance_valid(hit.get("collider")) and hit.collider.is_in_group("rocks"):
		if not _valid_hit(hit, player.break_reach):
			return false
		if player.selected_type != PICKAXE:
			_notify("Les rochers se cassent avec la pioche (molette ou touche 3).")
			return false
		return mine_rock(hit.collider)
	var pickaxe: bool = player.selected_type == PICKAXE
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
	if kind == PICKAXE and player.brush == 0:
		_notify("Choisissez du sable ou de la terre pour poser (molette).")
		return false
	var cells: int = SIZE_CELLS[player.brush_size]
	if not kind in PLACEABLE:
		kind = SmoothTerrain.DIRT
	match player.brush:
		1:
			return flatten(hit, cells)
		2:
			return smooth(hit, cells)
	return sculpt(hit, true, kind, cells)

func _edit_place_target(hit: Dictionary, kind: int) -> bool:
	if not _valid_hit(hit, player.place_reach):
		return false
	var point: Vector3 = hit.position + hit.normal * 0.02
	var cell := Vector3i(floori(point.x), floori(point.y), floori(point.z))
	if cell.y < 0 or cell.y >= MAX_BUILD_HEIGHT or absi(cell.x) > BUILD_LIMIT or absi(cell.z) > BUILD_LIMIT:
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
	selected_block_label = Label.new()
	selected_block_label.name = "SelectedBlock"
	selected_block_label.add_theme_font_size_override("font_size", roundi(18 * text_scale))
	selected_block_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	selected_block_label.add_theme_constant_override("shadow_outline_size", 3)
	selected_block_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(selected_block_label)
	update_selected_block()
	var exploration := Label.new()
	exploration.name = "ExplorationNotice"
	exploration.text = "Clic gauche : creuser · clic droit : pinceau (B + T) · taille : B + molette"
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
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -60
	hint.offset_bottom = -20
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
	if is_instance_valid(selected_block_label):
		selected_block_label.add_theme_font_size_override("font_size", roundi(18 * text_scale))
		hint.add_theme_font_size_override("font_size", roundi(19 * text_scale))
		coordinates_label.add_theme_font_size_override("font_size", roundi(16 * text_scale))
		coordinates_label.offset_top = 18 + roundi(80 * text_scale)
		var exploration: Label = find_child("ExplorationNotice",true,false)
		exploration.add_theme_font_size_override("font_size",roundi(14 * text_scale))
		fps_label.add_theme_font_size_override("font_size",roundi(20 * text_scale))
		selected_block_label.get_parent().add_theme_constant_override("separation",roundi(5 * text_scale))

func update_selected_block() -> void:
	if is_instance_valid(selected_block_label) and is_instance_valid(player):
		selected_block_label.text = "Bloc sélectionné : %s" % choice_name(player.selected_type)

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
	update_terrain_view(false, Vector2i(floori(player.position.x / SmoothTerrain.ZONE_SIZE), floori(player.position.z / SmoothTerrain.ZONE_SIZE)))
	_process_terrain_queue()
	_process_far_queue()
	hint.text = notice if notice_time > 0.0 else ""
	_update_coordinates()

# level : 0 = −, 1 = Par défaut, 2 = + (textes complets d'avant 0.0.3.3), selon Synthèse des textes.
# 0.0.5.11 : plus affiché (page Comment jouer retirée) ; gardé comme résumé des commandes, vérifié par les tests.
static func get_help_text(level: int = 2) -> String:
	if level == 0:
		return "ZQSD : marcher. ↑ ↓ + A : vitesse (⌫ ⌫ : défaut). Espace : sauter ; deux fois : voler. Clic gauche : creuser ; droit : poser, aplanir ou lisser (B + T).
Molette : sable, terre, argile, boue ou pioche ; B + molette : taille. Échap : pause. F1 : mondes. F4 : vue."
	if level == 1:
		return "ZQSD / WASD : marcher (← → : de côté). Souris : regarder. Espace : sauter.
Y : se baisser. R : courir (mode dans Contrôles).
↑ ↓ + A : tout le déplacement plus ou moins vite ; + W : marche, + R : course,
⌫ + touche : par défaut ; ⌫ deux fois : tout.
Espace deux fois : voler (Espace monte, Y descend) ; encore deux fois : arrêter.
Clic gauche : creuser ; clic droit : pinceau (B + T : poser, aplanir, lisser).
B + molette : taille du geste (1/8, 1/4, 1/2 bloc). Molette : sable, terre, argile, boue ou pioche.
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

Terrain lisse (sous-cellules de 50 cm, 8 par bloc de 1 m) : clic gauche creuse ; clic droit utilise le pinceau
choisi avec B + T : Poser (sable ou terre, molette ou 1 et 2), Aplanir (sol mis à la hauteur visée)
ou Lisser (formes adoucies). B + molette : taille du geste, 1/8, 1/4 ou 1/2 bloc (1, 2 ou 4 sous-cellules).
Le choix s'affiche en bas quand on le change. Poser : jusqu'à 40 blocs de haut.
Sous le gazon : 4 m de terre qu'on peut creuser, puis 4 m de pierre (à la pioche), puis la Roche-mère, incassable.
Les blocs posés avant sont conservés ; plus de casse ni de pose de blocs pour l'instant.

Molette (ou 1 à 5) : sable, terre, pioche (3), argile (4), boue (5). Avec la pioche, le clic gauche casse aussi la pierre.
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
Constructions sauvegardées." % [world_name, terrain_seed, world_mode_text, int(BASE_SIZE.x), int(BASE_SIZE.z), sand_area()] + _used_note()
	var mode_line := "Mode : %s — %s" % [world_mode_text, "attributs de Paramètres → Attributs" if developer_mode else "attributs par défaut, non modifiables"]
	mode_line += _used_note()
	return "Monde : %s
Graine : %d
%s

Relief selon la graine : collines jusqu'à 3 m, petites bosses, parfois une crête abrupte ou un trou,
petits et grands déserts de sable ; plat autour de l'apparition ; en herbe ;
une plage de sable d'environ %d m² à une dizaine de mètres de l'apparition.
Sous-sol : 4 m de terre, 4 m de pierre (à casser à la pioche), puis la Roche-mère incassable.

Base plate : largeur %d × longueur %d blocs (%s), sol à Y 0
Construction : hauteur maximale %d blocs au-dessus du sol plat (sommet à Y %d), %s.
%s

Nom, graine, mode, constructions et position sauvegardés." % [world_name, terrain_seed, mode_line, sand_area(), int(BASE_SIZE.x), int(BASE_SIZE.z), base_range_text(), MAX_BUILD_HEIGHT, MAX_BUILD_HEIGHT, build_range_text(), COORDINATES_NOTE]

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
		patch.visibility_range_end = grass_distance

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
	_rocks_parent().add_child(body)
	return body

func place_objects(data: Dictionary) -> void:
	objects_data = data
	for id in data.get("rochers_mines", []):
		mined_rocks[id] = true
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
	for rock in terrain.rocks_in_zone(column):
		if not mined_rocks.has(rock.id):
			_make_rock(rock, rock.id).set_meta("column", column)
	for lake in terrain.lakes_in_zone(column):
		var water := MeshInstance3D.new()
		water.name = "Lac"
		water.mesh = _water_disc(lake.radius + lake.get("bank", 0.0) + (lake.wobble if lake.has("wobble_scale") else 0.0) + 0.25, (lake.end - lake.start) / 2.0)
		if _water_material == null:
			_water_material = ShaderMaterial.new()
			_water_material.shader = preload("res://shaders/water.gdshader")
		water.material_override = _water_material
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		water.position = Vector3(lake.center.x, lake.level, lake.center.y)
		water.set_meta("column", column)
		water.add_to_group("water")
		_rocks_parent().add_child(water)

func _hide_column_objects(column: Vector2i) -> void:
	if not is_instance_valid(rocks_node):
		return
	for child in rocks_node.get_children():
		if child.get_meta("column", Vector2i(999999, 0)) == column:
			child.free()

# Disque d'eau (surface plate, vue de dessus et de dessous) ; 0.0.5.20 : allongé (half : demi-segment du lac).
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
func mine_rock(body: StaticBody3D) -> bool:
	var size: int = body.get_meta("rock").x
	var hits: int = body.get_meta("hits") + 1
	body.set_meta("hits", hits)
	_debris(body.global_position + Vector3.UP * 0.3, Color("#6f6b66"))
	if hits < size:
		body.scale = Vector3.ONE * (1.0 - 0.06 * hits)
		show_choice("Rocher : %d / %d coups" % [hits, size])
		return true
	mined_rocks[body.get_meta("id")] = true
	objects_dirty = true
	body.queue_free()
	show_choice("Rocher cassé")
	return true

func _save_objects() -> bool:
	if save_folder.is_empty() or not objects_dirty:
		return true
	var data := objects_data.duplicate(true)
	if data.is_empty():
		data = {"format": 1}
	data.rochers_mines = mined_rocks.keys()
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
const FAR_BUDGET_USEC := 2500

func _update_far(center: Vector2i, area: Rect2) -> void:
	far_center = center
	var old_area := near_area
	near_area = area
	if not is_instance_valid(far_node):
		far_node = Node3D.new()
		far_node.name = "FarTerrain"
		add_child(far_node)
	var wanted := {}
	if far_distance > load_distance and relief:
		var here := FarTerrain.tile_of(center)
		var reach := ceili(far_distance / float(FarTerrain.TILE_ZONES))
		var low := FarTerrain.tile_of(BASE_ZONES_LOW)
		var high := FarTerrain.tile_of(BASE_ZONES_HIGH)
		for x in range(maxi(low.x, here.x - reach), mini(high.x, here.x + reach) + 1):
			for z in range(maxi(low.y, here.y - reach), mini(high.y, here.y + reach) + 1):
				var tile_area := Rect2(Vector2(x, z) * FarTerrain.TILE_METERS, Vector2.ONE * FarTerrain.TILE_METERS)
				if not area.encloses(tile_area):
					wanted[Vector2i(x, z)] = tile_area
	for tile: Vector2i in far_tiles.keys():
		if not wanted.has(tile):
			far_tiles[tile].free()
			far_tiles.erase(tile)
	far_queue = far_queue.filter(func(tile: Vector2i): return wanted.has(tile))
	for tile: Vector2i in wanted:
		var tile_area: Rect2 = wanted[tile]
		# Nouveau carré, ou carré au bord du terrain détaillé (avant ou maintenant) : à refaire.
		# 0.0.5.23 : ou carré dont la finesse change (2 m près du joueur, 4 m plus loin).
		var changed: bool = far_tiles.has(tile) and far_tiles[tile].get_meta("cell") != _far_cell(tile)
		if (not far_tiles.has(tile) or changed or tile_area.intersects(area) or tile_area.intersects(old_area)) and not tile in far_queue:
			far_queue.append(tile)
	var center_tile := FarTerrain.tile_of(center)
	far_queue.sort_custom(func(a: Vector2i, b: Vector2i): return maxi(absi(a.x - center_tile.x), absi(a.y - center_tile.y)) < maxi(absi(b.x - center_tile.x), absi(b.y - center_tile.y)))

var far_center := Vector2i.ZERO

func _far_cell(tile: Vector2i) -> float:
	var here := FarTerrain.tile_of(far_center)
	return FarTerrain.CELL if maxi(absi(tile.x - here.x), absi(tile.y - here.y)) <= 2 else FarTerrain.CELL * 2.0

func _build_far_tile(tile: Vector2i) -> void:
	if far_tiles.has(tile):
		far_tiles[tile].free()
		far_tiles.erase(tile)
	# Le terrain lointain passe 2 m sous le bord du terrain détaillé : pas de fente entre les deux.
	var cell := _far_cell(tile)
	var mesh := FarTerrain.build(terrain, tile, near_area.grow(-2.0), cell)
	if mesh == null:
		return
	var piece := MeshInstance3D.new()
	piece.name = "Lointain_%d_%d" % [tile.x, tile.y]
	piece.mesh = mesh
	piece.set_meta("cell", cell)
	piece.material_override = FarTerrain.material()
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far_node.add_child(piece)
	far_tiles[tile] = piece

func _process_far_queue() -> void:
	var started := Time.get_ticks_usec()
	while not far_queue.is_empty() and Time.get_ticks_usec() - started < FAR_BUDGET_USEC:
		_build_far_tile(far_queue.pop_front())
