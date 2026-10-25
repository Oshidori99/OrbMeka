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
const DIRT := 2
const BLOCK_COLORS := [Color("#d8c291"), Color("#888b90"), Color("#855332")]
const BLOCK_NAMES := ["Sable", "Pierre", "Terre"]
const MAX_BLOCKS := 1200
const BASE_SIZE := Vector3(128, 1, 128)
const MAX_BUILD_HEIGHT := 25
# Construction permise de X et Z −57 à 57 (115 × 115 blocs), à l'intérieur de la base.
const BUILD_LIMIT := 57

var generated_hill_count := 0
var generated_max_height := 0
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
# Distance de chargement en zones (Paramètres → Vidéo).
var load_distance := 4
# Densité de l'herbe (Paramètres → Vidéo), appliquée à l'ouverture du monde.
var grass_density := "medium"
var block_material: Material
var block_box: BoxShape3D
# Mesures affichées dans Informations du monde (F3).
var last_zone_load_ms := 0.0
var last_section_ms := 0.0
var autosave_time := 0.0
# 0.0.5.8 : terrain lisse (smooth_terrain.gd) : une pièce par zone (sol plat ou sculpté), herbe par carré de 8 m.
var terrain := SmoothTerrain.new()
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
	block_material = TerrainMaterials.surface()
	block_box = BoxShape3D.new()
	_create_ground()
	_create_terrain()
	_create_blocks()
	_migrate_step1()
	var saved_player := _read_saved_player()
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
	lawn = TerrainMaterials.ground_grass(generated, terrain_seed, SAND_CENTER, SAND_RADIUS, _grass_skipped)
	add_child(lawn)

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

func _setup_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#428de0")
	sky_material.sky_horizon_color = Color("#b9e2fa")
	sky_material.ground_horizon_color = Color("#b9e2fa")
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

# 0.0.5.5 : plus de collines de terre ni de blocs de pierre (demande de l'utilisateur) ; le relief
# reviendra avec l'étape 4 (relief procédural). terrain_generator.gd reste pour cette étape.
func _create_terrain() -> void:
	generated_hill_count = 0
	generated_max_height = 0
	_read_terrain_changes()
	terrain_node = Node3D.new()
	terrain_node.name = "Terrain"
	add_child(terrain_node)
	flat_ground_mesh = SmoothTerrain.flat_mesh()
	flat_ground_shape = BoxShape3D.new()
	flat_ground_shape.size = Vector3(SmoothTerrain.ZONE_SIZE, 1, SmoothTerrain.ZONE_SIZE)
	for zone: Vector3i in terrain.surface_zones(BASE_ZONES_LOW, BASE_ZONES_HIGH):
		rebuild_terrain_piece(zone)

# 0.0.5.8 : terrain lisse sur toute la base (zones de X et Z −64 à 63) ; base indestructible en dessous.
# 0.0.5.12 : la base (« Roche-mère », incassable) commence à 8 m sous le sol, sous 4 m de terre et 4 m de pierre.
const BASE_TOP := SmoothTerrain.BEDROCK_TOP * SmoothTerrain.STEP
const BASE_ZONES_LOW := Vector2i(-8, -8)
const BASE_ZONES_HIGH := Vector2i(7, 7)

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
func rebuild_terrain_piece(zone: Vector3i) -> void:
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
	if terrain.is_flat(zone):
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

# Herbe écartée là où le terrain a été sculpté (colonne de 50 cm et ses voisines).
func _grass_skipped(at: Vector3) -> bool:
	return terrain.column_changed(Vector2i(roundi(at.x / SmoothTerrain.STEP), roundi(at.z / SmoothTerrain.STEP)))

func _rebuild_lawn_tile(tile: Vector2i) -> void:
	for child in lawn.get_children():
		if child.get_meta("tile", Vector2i(999, 999)) == tile:
			child.free()
	var node := TerrainMaterials.lawn_tile(tile, generated, terrain_seed, SAND_CENTER, SAND_RADIUS, _grass_skipped)
	if node != null:
		lawn.add_child(node)
# Gestes de terrain (0.0.5.8, pinceaux en 0.0.5.9). Clic gauche : creuser ; clic droit : le pinceau
# choisi avec B + T (poser, aplanir, lisser). Taille (B + molette) : 1/8, 1/4 ou 1/2 bloc, soit 1, 2 ou
# 4 sous-cellules de 50 cm ; aplanir et lisser agissent autour, sur 50 cm, 1 m ou 1,5 m.
const BRUSH_NAMES := ["Poser", "Aplanir", "Lisser"]
const SIZE_NAMES := ["1/8 de bloc", "1/4 de bloc", "1/2 bloc"]
const SIZE_CELLS := [1, 2, 4]
# Matières qu'on peut poser pour l'instant (0.0.5.9 : plus la pierre).
const PLACEABLE := [0, 2]

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

func _in_terrain_limits(point: Vector3i) -> bool:
	return point.y >= SmoothTerrain.LOW_POINT and point.y <= SmoothTerrain.HIGH_POINT and absi(point.x) <= BUILD_LIMIT * 2 and absi(point.z) <= BUILD_LIMIT * 2

func _inside_player(point: Vector3i) -> bool:
	return AABB(player.global_position + Vector3(-0.33, 0.01, -0.33), Vector3(0.66, 1.78, 0.66)).intersects(AABB(Vector3(point) * SmoothTerrain.STEP - Vector3.ONE * 0.25, Vector3.ONE * 0.5))

# Creuser (add false) ou poser (add true, matière kind).
func sculpt(hit: Dictionary, add: bool, kind: int = SmoothTerrain.DIRT, cells: int = 1) -> bool:
	if not _aimed_ground(hit, player.place_reach if add else player.break_reach):
		return false
	var center := SmoothTerrain.point_of(hit.position + hit.normal * (0.15 if add else -0.3))
	var updates := {}
	var message := ""
	for point in gesture_points(center, hit.normal, cells):
		if not _in_terrain_limits(point):
			if point.y < SmoothTerrain.LOW_POINT:
				message = "Roche-mère : incassable." if point.y < SmoothTerrain.BEDROCK_TOP else "La pierre ne se casse pas encore."
			elif point.y > SmoothTerrain.HIGH_POINT:
				message = "Hauteur maximale atteinte : 4 blocs au-dessus du sol."
			else:
				message = "Limite de construction atteinte."
			continue
		if (terrain.density(point) > 0.0) == add:
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
				if not _in_terrain_limits(point):
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
				if not _in_terrain_limits(point):
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
	for zone: Vector3i in zones:
		rebuild_terrain_piece(zone)
	for tile: Vector2i in tiles:
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

# Bornes des cases (min, max) d'une étendue centrée sur 0, ex. base de 128 : −64 à 63.
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
	return hit.collider.is_in_group("blocks") or hit.collider.is_in_group("ground")

# 0.0.5.8 : clic gauche : creuser le terrain lisse (les blocs posés avant restent, sans casse ni pose).
func break_target(hit: Dictionary) -> bool:
	return sculpt(hit, false, -1, SIZE_CELLS[player.brush_size])

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
		selected_block_label.text = "Bloc sélectionné : %s" % BLOCK_NAMES[player.selected_type]

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
	hint.text = notice if notice_time > 0.0 else ""
	_update_coordinates()

# level : 0 = −, 1 = Par défaut, 2 = + (textes complets d'avant 0.0.3.3), selon Synthèse des textes.
# 0.0.5.11 : plus affiché (page Comment jouer retirée) ; gardé comme résumé des commandes, vérifié par les tests.
static func get_help_text(level: int = 2) -> String:
	if level == 0:
		return "ZQSD : marcher. ↑ ↓ + A : vitesse (⌫ ⌫ : défaut). Espace : sauter ; deux fois : voler. Clic gauche : creuser ; droit : poser, aplanir ou lisser (B + T).
Molette : sable ou terre ; B + molette : taille. Échap : pause. F1 : mondes. F4 : vue."
	if level == 1:
		return "ZQSD / WASD : marcher (← → : de côté). Souris : regarder. Espace : sauter.
Y : se baisser. R : courir (mode dans Contrôles).
↑ ↓ + A : tout le déplacement plus ou moins vite ; + W : marche, + R : course,
⌫ + touche : par défaut ; ⌫ deux fois : tout.
Espace deux fois : voler (Espace monte, Y descend) ; encore deux fois : arrêter.
Clic gauche : creuser ; clic droit : pinceau (B + T : poser, aplanir, lisser).
B + molette : taille du geste (1/8, 1/4, 1/2 bloc). Molette : sable ou terre.
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
Le choix s'affiche en bas quand on le change. Poser : jusqu'à 4 blocs au-dessus du sol.
Sous le gazon : 4 m de terre qu'on peut creuser, puis 4 m de pierre (pas encore cassable), puis la Roche-mère, incassable.
Les blocs posés avant sont conservés ; plus de casse ni de pose de blocs pour l'instant.

Molette : sable ou terre (la pierre n'est plus posée pour l'instant).
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

Relief : tout plat, en herbe ; une plage de sable d'environ %d m² à une dizaine de mètres de l'apparition.
Sous-sol : 4 m de terre, 4 m de pierre, puis la Roche-mère incassable.

Base plate : largeur %d × longueur %d blocs (%s), sol à Y 0
Construction : hauteur maximale %d blocs au-dessus du sol plat (sommet à Y %d), %s.
%s

Nom, graine, mode, constructions et position sauvegardés." % [world_name, terrain_seed, mode_line, sand_area(), int(BASE_SIZE.x), int(BASE_SIZE.z), base_range_text(), MAX_BUILD_HEIGHT, MAX_BUILD_HEIGHT, build_range_text(), COORDINATES_NOTE]
