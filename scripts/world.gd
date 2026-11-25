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
const ReturnOrb = preload("res://scripts/return_orb.gd")
const Fibers = preload("res://scripts/fibers.gd")
const ToolModels = preload("res://scripts/tool_models.gd")
const StoneHeads = preload("res://scripts/stone_heads.gd")
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
# 0.0.8.25 (#140) : ce qu'on regarde, en haut au centre.
var looked_label: Label
var _looked_wait := 0.0
var fps_label: Label
var fps_elapsed := 0.0
const FPS_INTERVAL := 0.5
var creation_text := "Création : inconnue"
# 0.0.7.10 : statistiques du monde (WorldMetadata) et temps de jeu de cette partie, ajouté à chaque sauvegarde.
var world_stats: Dictionary = {}
var played_since_save := 0.0
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
	Trees.detail_end = tree_detail_end
	base_size = Vector3(base_side(_half_zones()), 1, base_side(_half_zones()))
	build_limit = base_side(_half_zones()) / 2 - 3
	base_zones_low = Vector2i(-_half_zones(), -_half_zones())
	base_zones_high = Vector2i(_half_zones() - 1, _half_zones() - 1)
	_read_creation_date()
	_setup_inputs()
	_setup_environment()
	# 0.0.5.1 : une seule matière pour tous les blocs, couleur portée par les sommets de chaque section.
	TerrainMaterials.density = grass_density
	TerrainMaterials.simple = simple_ground
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
	# 0.0.8 (#171) : vie relue (ancien monde : pleine), dégâts de chute.
	health.load_value(saved_player.get("vie"))
	player.landed.connect(_on_landed)
	saved_at = player.position
	# 0.0.7.2 : inventaire relu (ancien monde : vide, sans erreur), dans le mode de jeu du monde.
	inventory.mode = game_mode
	Inventory.current_mode = game_mode
	inventory.from_dict(saved_player.get("inventaire"))
	# 0.0.8.16 (#208) : Carnet de route relu (ancien monde : rien de coché, message du début à montrer).
	notebook.from_array(saved_player.get("carnet", []))
	notebook_seen = bool(saved_player.get("carnet_vu", false))
	# 0.0.8.27 (#160) : l'heure relue (ancien monde ou nouveau : 8 h).
	var saved_time: Variant = saved_player.get("heure", DayNight.START)
	day_time = DayNight.day_wrap(float(saved_time)) if saved_time is float or saved_time is int else DayNight.START
	apply_day_light()
	apply_day_sky()
	inventory.changed.connect(_on_notebook_inventory)
	inventory.changed.connect(apply_held)
	inventory.changed.connect(func(): inventory_unsaved = true)
	_create_selection()
	_create_hud()
	# 0.0.8.2 (#231) : orbes de retour du début (Survie, une fois par monde ; ouvert en Créatif : jamais).
	start_orbs_given = saved_player.get("orbes_depart", false) == true or game_mode != Inventory.SURVIVAL
	give_start_orbs()
	apply_held()
	_warm_shaders()
	# 0.0.7.26 : branches mortes et rejets des colonnes déjà construites (les objets au sol n'existaient pas encore).
	_refresh_sticks()


# 0.0.7.20 : shaders compilés pendant l'ouverture (surtout sur le Web, qui les compile au premier affichage : à-coup en
# découvrant de l'eau, un rocher ou un arbre d'une autre espèce) : une copie minuscule de chaque sorte de modèle
# (terrain, herbe, eau, rivière, lointain, rochers, plantes, arbres de chaque espèce, faces coupées), collée devant la
# caméra pendant WARM_FRAMES images, puis retirée. Invisible (plus petite qu'un pixel).
const WARM_FRAMES := 3
var warm_node: Node3D
var warm_left := 0

func _warm_shaders() -> void:
	# Seulement en rendu Compatibility (Web, vieux PC) : sur PC (Forward+), Godot prépare déjà les shaders d'avance
	# (mesuré : ici, une image de 0,7 s de plus à l'ouverture, sans rien gagner ensuite).
	if not is_compat() or not is_instance_valid(player) or player.camera == null:
		return
	warm_node = Node3D.new()
	warm_node.name = "Prechauffage"
	warm_node.position = Vector3(0.0, 0.0, -0.5)
	warm_node.scale = Vector3.ONE * 0.0005
	player.camera.add_child(warm_node)
	_warm_collect()
	# Ce qui n'est pas encore autour : arbres de chaque espèce (de près et de loin), faces coupées, eau, rivière.
	if relief and int(generation_options.get("version", 0)) >= 21:
		for kind in range(Trees.FILES.size()):
			for far in [false, true]:
				var tree := MeshInstance3D.new()
				tree.mesh = Trees.mesh(kind, 1, far)
				warm_pending.append(tree)
	var plane := QuadMesh.new()
	for material: Material in [Trees.cut_material(), _water_or_new(), _river_or_new(), FarTerrain.material()]:
		var flat := MeshInstance3D.new()
		flat.mesh = plane
		flat.material_override = material
		warm_pending.append(flat)
	# 0.0.8.11 (rapport Web : gels de 4,5 à 5 s à la première ouverture) : les objets de la série 0.0.8, en main (modèle
	# seul) et au sol (en série) : orbe, fibres, liane, ficelle, têtes, outils ficelés, et une matière simple (mains).
	var simple := StandardMaterial3D.new()
	simple.roughness = 0.7
	var ball := SphereMesh.new()
	ball.material = simple
	for mesh: Mesh in [ball, ReturnOrb.mesh(), Fibers.bundle_mesh(), Fibers.coil_mesh(), Fibers.cord_mesh(), StoneHeads.mesh("hache", 1.0), ToolModels.mesh({"objet": "hache_pierre", "lien": 3, "tours": 4}), ToolModels.mesh({"objet": "pioche_pierre", "lien": 0, "tours": 4})]:
		var held := MeshInstance3D.new()
		held.mesh = mesh
		warm_pending.append(held)
		var series := MultiMesh.new()
		series.transform_format = MultiMesh.TRANSFORM_3D
		series.use_colors = true
		series.mesh = mesh
		series.instance_count = 1
		var lying := MultiMeshInstance3D.new()
		lying.multimesh = series
		warm_pending.append(lying)
	# Lueur des orbes posées (Survie : une près du départ) : chaque matière éclairée par une petite lumière se dessine une
	# fois de plus, avec son propre shader (rendu Compatibility).
	if survival() or not ground_orb_lights().is_empty():
		var glow := OmniLight3D.new()
		glow.name = "LumierePrechauffage"
		glow.omni_range = 0.3
		glow.layers = WARM_LAYER
		glow.position = Vector3(0.0, 0.0, -0.4)
		player.camera.add_child(glow)
		warm_light = glow
	warm_left = WARM_FRAMES
	# 0.0.8.11 (rapport Web : 10 à 15 s pour ouvrir un monde) : derrière l'écran de chargement, la caméra ne dessine que les
	# copies (WARM_LAYER) : plus de monde dessiné pour rien à chaque image (le rendu prenait une bonne part de l'image sur
	# une petite carte graphique), et chaque shader se prépare à son tour au lieu de tous d'un coup à la première image.
	# Le reste (terrain, herbe, plantes, rochers, objets construits entre-temps) : second passage quand la vue est construite.
	if behind_loading:
		warm_waiting_late = true
		loading_cull = true
		player.camera.cull_mask = WARM_LAYER
		if sun_light != null:
			sun_light.layers |= WARM_LAYER

# Couche des copies du préchauffage (seule dessinée derrière l'écran de chargement, rendu Compatibility).
const WARM_LAYER := 1 << 19
const ALL_LAYERS := (1 << 20) - 1
var warm_seen := {}
var warm_waiting_late := false
var loading_cull := false
var warm_light: OmniLight3D

func ground_orb_lights() -> Array:
	return ground._orb_lights if is_instance_valid(ground) else []

# Une copie de chaque sorte de modèle du monde pas encore vue (le joueur et ses mains : même cachés).
func _warm_collect() -> void:
	var own: Array = player.find_children("*", "GeometryInstance3D", true, false) if is_instance_valid(player) else []
	for node in find_children("*", "GeometryInstance3D", true, false):
		if is_instance_valid(warm_node) and warm_node.is_ancestor_of(node):
			continue
		var key := _warm_key(node, own.has(node))
		if key.is_empty() or warm_seen.has(key):
			continue
		warm_seen[key] = true
		var copy: GeometryInstance3D = null
		if node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
			var series := MultiMesh.new()
			series.transform_format = node.multimesh.transform_format
			series.use_colors = node.multimesh.use_colors
			series.use_custom_data = node.multimesh.use_custom_data
			series.mesh = node.multimesh.mesh
			series.instance_count = 1
			copy = MultiMeshInstance3D.new()
			copy.multimesh = series
		elif node is MeshInstance3D and node.mesh != null:
			copy = MeshInstance3D.new()
			copy.mesh = node.mesh
			for surface in range(node.get_surface_override_material_count()):
				copy.set_surface_override_material(surface, node.get_surface_override_material(surface))
		if copy == null:
			continue
		copy.material_override = node.material_override
		copy.cast_shadow = node.cast_shadow
		warm_pending.append(copy)

# Sorte de modèle : format de ses sommets et matières (une copie suffit pour chaque sorte).
func _warm_key(node: GeometryInstance3D, even_hidden := false) -> String:
	var mesh: Mesh = null
	if node is MultiMeshInstance3D and node.multimesh != null:
		mesh = node.multimesh.mesh
	elif node is MeshInstance3D:
		mesh = node.mesh
	if mesh == null or not (even_hidden or node.is_visible_in_tree()):
		return ""
	var parts := [node.get_class(), node.material_override.get_instance_id() if node.material_override != null else 0]
	for surface in range(mesh.get_surface_count()):
		var material: Material = node.get_surface_override_material(surface) if node is MeshInstance3D and surface < node.get_surface_override_material_count() else null
		if material == null:
			material = mesh.surface_get_material(surface)
		var format: int = mesh.surface_get_format(surface) if mesh is ArrayMesh else 0
		parts.append([format, material.get_instance_id() if material != null else 0])
	return str(parts)

func _water_or_new() -> ShaderMaterial:
	if _water_material == null:
		_water_material = ShaderMaterial.new()
		_water_material.shader = preload("res://shaders/water.gdshader")
		_water_material.set_shader_parameter("tone", 0.85 if is_compat() else 1.0)
	return _water_material

func _river_or_new() -> ShaderMaterial:
	if _river_material == null:
		_river_material = ShaderMaterial.new()
		_river_material.shader = preload("res://shaders/river.gdshader")
		_river_material.set_shader_parameter("tone", 0.66 if is_compat() else 1.0)
	return _river_material

func _end_warm() -> void:
	# Monde montré : la caméra dessine de nouveau tout.
	if loading_cull and not behind_loading:
		loading_cull = false
		if is_instance_valid(player) and player.camera != null:
			player.camera.cull_mask = ALL_LAYERS
		if sun_light != null:
			sun_light.layers &= ~WARM_LAYER
		_restore_warm_shadows()
	# 0.0.7.24 : quelques copies par image (WARM_PER_FRAME) : la compilation des shaders étalée (mesures Web : 11 et 8 s
	# figées d'un coup à la première ouverture).
	if not warm_pending.is_empty():
		if not is_instance_valid(warm_node):
			warm_pending.clear()
			return
		var count := 1 if get_process_delta_time() > WARM_SLOW_FRAME else WARM_PER_FRAME
		for index in range(mini(count, warm_pending.size())):
			var copy: GeometryInstance3D = warm_pending.pop_front()
			copy.layers = WARM_LAYER
			warm_node.add_child(copy)
		return
	# 0.0.8.11 : second passage, quand les colonnes, leurs arbres et leurs détails sont construits (ou le monde déjà montré).
	if warm_waiting_late:
		if behind_loading and not (terrain_queue.is_empty() and tree_queue.is_empty() and detail_queue.is_empty()):
			return
		warm_waiting_late = false
		if is_instance_valid(warm_node):
			_warm_collect()
			warm_left = WARM_FRAMES
		return
	if warm_left <= 0:
		return
	warm_left -= 1
	if warm_left == 0:
		# 0.0.8.11 (rapport Web : gels de 4 à 20 s) : toutes les copies encore une fois, ombres du soleil dans l'autre état
		# (activées si elles sont coupées, coupées sinon) : changer les ombres en jeu ne prépare plus rien d'un coup. Seulement
		# derrière l'écran de chargement (rien ne se voit).
		if not warm_flipped and loading_cull and sun_light != null and is_instance_valid(warm_node):
			warm_flipped = true
			warm_shadows_changed = true
			if shadow_quality == "off":
				sun_light.shadow_enabled = true
				sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
				sun_light.directional_shadow_max_distance = SHADOW_DISTANCES.near
			else:
				sun_light.shadow_enabled = false
			for child in warm_node.get_children():
				warm_node.remove_child(child)
				warm_pending.append(child)
			warm_left = WARM_FRAMES
			return
		_restore_warm_shadows()
		if is_instance_valid(warm_node):
			warm_node.queue_free()
		warm_node = null
		if is_instance_valid(warm_light):
			warm_light.queue_free()
		warm_light = null

var warm_flipped := false
var warm_shadows_changed := false

func _restore_warm_shadows() -> void:
	if warm_shadows_changed:
		warm_shadows_changed = false
		set_shadows(shadow_quality)

const WARM_PER_FRAME := 4
# 0.0.8.11 : après une image lente (un shader préparé pour la première fois : jusqu'à plusieurs secondes sur le Web), une
# seule copie à la fois.
const WARM_SLOW_FRAME := 0.2
var warm_pending: Array = []

# Ouverture prête (écran de chargement, app.gd) : shaders préparés, colonnes autour construites, arbres créés.
func opening_progress(near_only: bool = false) -> float:
	# 0.0.7.25 : toute la vue proche construite (mesures Web : 10 à 15 s saccadées juste après l'arrivée quand l'écran se
	# retirait à 3 × 3 colonnes), arbres, herbe et plantes faits, shaders préparés, lointain fait.
	# 0.0.7.34 (demande de l'utilisateur : le chargement était long après 81 %) : near_only (PC) : seulement les colonnes à
	# NEAR_REVEAL_ZONES zones au plus (9 × 9), leurs arbres, herbe et plantes, et les shaders ; le reste se construit en jouant.
	var built := 0
	var wanted := 0
	for column: Vector2i in shown_columns:
		if near_only and _ring(column) > NEAR_REVEAL_ZONES:
			continue
		wanted += 1
		if built_columns.has(column):
			built += 1
	var columns := built / float(maxi(wanted, 1))
	var warm := 1.0 if warm_pending.is_empty() and warm_left <= 0 and not warm_waiting_late else (0.5 if warm_pending.is_empty() else 0.0)
	var details_left := tree_queue.size() + detail_queue.size()
	if near_only:
		details_left = tree_queue.filter(func(entry): return _ring(entry[0]) <= NEAR_REVEAL_ZONES).size() + detail_queue.filter(func(column): return _ring(column) <= NEAR_REVEAL_ZONES).size()
	var details := 1.0 if details_left == 0 else 0.5
	# Le lointain (horizon) prêt avant de montrer le monde ; near_only : quelques pièces de plus arrivent avec chaque colonne
	# construite (mesuré : 0 à 6), on n'attend pas les dernières.
	var far := 1.0 if far_queue.size() <= (NEAR_FAR_LEFT if near_only else 0) else 0.5
	return columns * 0.6 + warm * 0.15 + details * 0.15 + far * 0.1

const NEAR_REVEAL_ZONES := 4
const NEAR_FAR_LEFT := 8

func _ring(column: Vector2i) -> int:
	return maxi(absi(column.x - view_center.x), absi(column.y - view_center.y))

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
# 0.0.8.27 (#160) : jour et nuit (day_night.gd) : l'heure (minutes, 0 à 1440 ; 8 h dans un nouveau monde), sauvegardée
# avec le joueur ; lumière et ciel suivent l'heure.
const DayNight = preload("res://scripts/day_night.gd")
# Le ciel et la brume ne changent que toutes les SKY_EVERY s (recalculer le ciel coûte ; le changement est lent).
const SKY_EVERY := 2.0
var day_time := DayNight.START
var sky_material: ProceduralSkyMaterial
var sun_base_energy := 1.0
var ambient_base_energy := 0.7
var _sky_wait := 0.0
var clock_label: Label

func _update_day(delta: float) -> void:
	if sun_light == null or not is_instance_valid(environment):
		return
	day_time = DayNight.day_wrap(day_time + delta * DayNight.MINUTES_PER_SECOND)
	apply_day_light()
	_sky_wait -= delta
	if _sky_wait <= 0.0:
		_sky_wait = SKY_EVERY
		apply_day_sky()
	if is_instance_valid(clock_label):
		clock_label.text = DayNight.clock_text(day_time)

# Lumière directe (soleil ou lune) et lumière ambiante selon l'heure ; la nuit, pas d'ombres (la lune est faible : plus
# léger) ; pas pendant la préparation des ombres derrière l'écran de chargement.
func apply_day_light() -> void:
	sun_light.rotation_degrees = DayNight.light_rotation(day_time)
	sun_light.light_energy = sun_base_energy * DayNight.light_share(day_time)
	sun_light.light_color = DayNight.light_color(day_time)
	environment.ambient_light_energy = ambient_base_energy * DayNight.ambient_share(day_time)
	environment.ambient_light_color = DayNight.ambient_color(day_time)
	var shadows := shadow_quality != "off" and DayNight.daylight(day_time) > 0.05
	if warm_left <= 0 and sun_light.shadow_enabled != shadows:
		sun_light.shadow_enabled = shadows

func apply_day_sky() -> void:
	if sky_material == null:
		return
	var horizon := DayNight.sky_horizon(day_time)
	sky_material.sky_top_color = DayNight.sky_top(day_time)
	sky_material.sky_horizon_color = horizon
	sky_material.ground_horizon_color = horizon
	sky_material.ground_bottom_color = horizon
	_update_fog()

func _setup_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#428de0")
	sky_material.sky_horizon_color = Color("#b9e2fa")
	sky_material.ground_horizon_color = Color("#b9e2fa")
	# 0.0.5.17 : sous l'horizon, au-delà du terrain affiché : même teinte que la brume (plus de bande noire).
	sky_material.ground_bottom_color = Color("#b9e2fa")
	sky.sky_material = sky_material
	# 0.0.8.27 : le ciel change avec l'heure (toutes les SKY_EVERY s) : recalculé par petits morceaux, sur plusieurs images.
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
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
	# 0.0.7.21 : distance des ombres selon Paramètres → Vidéo → Ombres (set_shadows).
	sun_light = sun
	set_shadows(shadow_quality)
	apply_compat_light(environment, sun)
	# 0.0.8.27 : la lumière du jour (midi) ; l'heure la fait varier (apply_day_light).
	sun_base_energy = sun.light_energy
	ambient_base_energy = environment.ambient_light_energy
	add_child(sun)


# 0.0.7.21 : ombres du soleil : Loin (64 m, deux niveaux : comme avant), Moyennes (48 m), Proches (32 m, un seul niveau).
# Rendu Compatibility (Web) : toujours un seul niveau, 40 m au plus (0.0.6.19).
const SHADOW_DISTANCES := {"near": 32.0, "medium": 48.0, "far": 64.0}
var shadow_quality := "medium"
# 0.0.7.21 : qualité Performance : arbres simplifiés dès 28 m (sinon Trees.DETAIL_END, 40 m).
const PERFORMANCE_TREE_DETAIL := 28.0
var tree_detail_end := Trees.DETAIL_END
# 0.0.7.23 : qualité Performance : sol simplifié.
var simple_ground := false
# 0.0.7.24 : ouvert derrière l'écran de chargement (app.gd) : colonnes autour par la file, grand budget de fond.
var behind_loading := false
# 0.0.8.11 (rapport Web : 10 à 15 s pour ouvrir un monde) : 80 ms par image sur le Web aussi (avant 40) : la caméra n'y
# dessine plus le monde derrière l'écran (préchauffage), chaque image en moins est du temps gagné ; la barre avance
# encore une dizaine de fois par seconde.
const LOADING_WORK_USEC := 80000
# 0.0.7.34 (demande de l'utilisateur) : sur PC, deux fois plus de travail par image derrière l'écran de chargement (moins
# d'images à dessiner pour rien).
const LOADING_WORK_PC_USEC := 80000
var sun_light: DirectionalLight3D

# 0.0.8.14 (rapport d'optimisation, demandes de l'utilisateur) : taille de la carte des ombres du soleil (points de côté),
# réglage Paramètres → Vidéo « Taille de la carte des ombres » (512 à 8192 ; Performance 1024, Équilibré 2048, Beauté 4096),
# appliquée pour tout le jeu par app_base.apply_appearance. Le Web : 4096 au plus (8192 y est très lourd, et certaines
# cartes le refusent). Mesuré sur une Radeon 610M (PC bon marché) : 2048 au lieu de 4096 = 12 à 23 ms de moins par image.
const SHADOW_ATLAS_SIZES := [512, 1024, 2048, 4096, 8192]
const SHADOW_ATLAS_WEB_MAX := 4096
static var shadow_atlas := 0

static func shadow_atlas_size(size: int) -> int:
	var chosen: int = size if size in SHADOW_ATLAS_SIZES else 2048
	return mini(chosen, SHADOW_ATLAS_WEB_MAX) if OS.has_feature("web") else chosen

static func apply_shadow_atlas(size: int) -> void:
	shadow_atlas = shadow_atlas_size(size)
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.directional_shadow_atlas_set_size(shadow_atlas, ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits", true))

func set_shadows(quality: String) -> void:
	shadow_quality = quality if SHADOW_DISTANCES.has(quality) or quality == "off" else "medium"
	if sun_light == null:
		return
	# 0.0.7.23 : « Aucune » (Performance sur le Web) : pas d'ombres du soleil (sur une petite carte graphique, elles coûtent
	# beaucoup : chaque objet est dessiné une fois de plus pour elles).
	sun_light.shadow_enabled = shadow_quality != "off"
	if shadow_quality == "off":
		return
	var distance: float = SHADOW_DISTANCES[shadow_quality]
	var single := is_compat() or shadow_quality == "near"
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if single else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun_light.directional_shadow_max_distance = minf(distance, 40.0) if is_compat() else distance

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
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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

# 0.0.7.23 : écran de chargement (app.gd) : la graine du monde (montagnes, lacs, rivières, crevasses, grottes : 1 à 2 s sur
# PC, bien plus sur le Web) préparée en petites étapes avant d'ouvrir le monde, la barre de progression avance.
var prepared_terrain: SmoothTerrain = null

static func flat_spots() -> Array:
	return [[Vector2(0.5, 0.5), 9.0], [SAND_CENTER, SAND_RADIUS + 2.0]]

static func prepare_terrain(seed: int, options: Dictionary) -> SmoothTerrain:
	var made := SmoothTerrain.new()
	made.setup(seed, flat_spots(), options, false)
	return made
func _create_terrain(start_at: Vector3 = Vector3.ZERO) -> void:
	generated_hill_count = 0
	generated_max_height = 0
	# 0.0.5.14 : petites collines selon la graine, plates autour de l'apparition et de la plage.
	if relief:
		# 0.0.8.13 : fils de calcul du terrain (déjà lancés par l'écran de chargement, sinon maintenant) ; ils se préparent à
		# côté, le fil principal fait tout lui-même en attendant.
		if terrain_workers == null and TerrainWorkers.available():
			terrain_workers = TerrainWorkers.new()
			terrain_workers.start(terrain_seed, flat_spots(), generation_options)
		# 0.0.7.23 : graine déjà préparée par étapes pendant l'écran de chargement (prepare_terrain), sinon d'un coup.
		if prepared_terrain != null:
			prepared_terrain.prepare_step(1 << 40)
			terrain = prepared_terrain
		else:
			terrain.setup(terrain_seed, flat_spots(), generation_options)
	elif terrain_workers != null:
		terrain_workers.stop()
		terrain_workers = null
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
	# 0.0.7.26 : branches mortes et rejets des colonnes autour du joueur.
	_refresh_sticks()
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
		# 0.0.7.22 : à l'ouverture, les colonnes autour aussi (on peut y marcher dès la première image ; ensuite, la file).
		# 0.0.7.25 : derrière l'écran de chargement, même la colonne du joueur passe par la file (mesures Web : 1,7 s figées
		# en rouvrant un monde en forêt, arbres et plantes de cette colonne faits d'un coup).
		if maxi(absi(column.x - center.x), absi(column.y - center.y)) <= (-1 if behind_loading else (1 if opening_columns else NEAR_ZONES)):
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
		# 0.0.8.13 : surface d'un fil de calcul si elle est déjà là.
		rebuild_terrain_piece(zone, false, _take_worker_surface(zone))
	column_pending.erase(column)
	_finish_column(column)

# Zones déjà faites : l’herbe, les objets, puis le lointain s’efface sous la colonne.
var column_pending: Dictionary = {}

func _finish_column(column: Vector2i, progressive := false) -> void:
	var at := Time.get_ticks_usec()
	# 0.0.7.25 : en se déplaçant (progressive), l'herbe et les plantes viennent après la surface (detail_queue) : en vol
	# rapide, la surface et sa collision d'abord (mesures Web : arrêts « Chargement du terrain… »).
	# 0.0.7.28 : mise en file APRÈS _show_column_objects (il vide la file de la colonne en retirant ses anciens objets :
	# en 0.0.7.25 à 0.0.7.27, l'herbe et les plantes ne venaient jamais au-delà des 9 colonnes de l'ouverture).
	if not progressive:
		_rebuild_lawn_tile(column)
	if perf_on:
		_perf("colonne_herbe", at)
		at = Time.get_ticks_usec()
	_show_column_objects(column, progressive)
	if progressive and not detail_queue.has(column):
		detail_queue.append(column)
	if perf_on:
		_perf("colonne_objets", at)
		at = Time.get_ticks_usec()
	built_columns[column] = true
	if _in_stick_ring(column):
		_queue_sticks(column)
	_far_follow_column(column)
	if perf_on:
		_perf("colonne_lointain", at)

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
	heights_ready.erase(column)
	column_height_rows.erase(column)
	worker_done.erase(column)
	if worker_columns.has(column) and terrain_workers != null:
		terrain_workers.cancel_column(column)
	worker_columns.erase(column)
	for zone: Vector3i in worker_surfaces.keys():
		if zone.x == column.x and zone.z == column.y:
			worker_surfaces.erase(zone)
	for zone: Vector3i in surface_jobs.keys():
		if zone.x == column.x and zone.z == column.y:
			surface_jobs.erase(zone)
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

func _process_terrain_queue(budget_usec: int = TERRAIN_BUDGET_USEC) -> void:
	# Sous terre, les grottes d'abord ; en surface, seulement quand le reste du terrain est prêt.
	if is_instance_valid(player) and (player.position.y < CAVE_DEEP) != cave_underground:
		_update_caves(view_center)
	if not cave_queue.is_empty() and (cave_underground or terrain_queue.is_empty()):
		# 0.0.7.20 : zone de grotte calculée en petites étapes elle aussi (jusqu'à 160 ms d'un coup avant).
		var cave_zone: Vector3i = cave_queue[0]
		if cave_pieces.has(cave_zone) or terrain_pieces.has(cave_zone):
			cave_pieces[cave_zone] = true
			cave_queue.pop_front()
		else:
			if cave_job == null or cave_job.zone != cave_zone or cave_job_edits != terrain_edits:
				cave_job = SurfaceJob.new(terrain, cave_zone)
				cave_job_edits = terrain_edits
			if cave_job.step(SURFACE_STEP_USEC):
				cave_queue.pop_front()
				cave_pieces[cave_zone] = true
				var surface: Array = cave_job.result
				cave_job = null
				rebuild_terrain_piece(cave_zone, false, surface)
	if _workers_on():
		_collect_worker_results()
		_dispatch_worker_columns()
	var started := Time.get_ticks_usec()
	# 0.0.6.2 : zone par zone (une colonne de montagne dépassait 40 ms d’un coup) ; l’herbe et les objets quand la colonne est finie.
	# 0.0.6.18 (#175) : une étape de plus seulement si elle tient dans le temps restant (durée moyenne des dernières) :
	# avant, une zone commencée à la fin du budget pouvait le dépasser de 10 ms.
	while not terrain_queue.is_empty():
		var step_started := Time.get_ticks_usec()
		if step_started > started and step_started - started + terrain_step_usec > budget_usec:
			break
		var index := _next_terrain_index()
		if index < 0:
			break
		_terrain_step(index)
		terrain_step_usec = terrain_step_usec * 0.8 + (Time.get_ticks_usec() - step_started) * 0.2

# Colonnes dont les hauteurs sont prêtes (oubliées quand la colonne sort de la vue : terrain.forget_column).
var heights_ready: Dictionary = {}

# Durée moyenne d'une étape du terrain (µs), pour ne pas dépasser le temps de chaque image.
var terrain_step_usec := 2000.0

# 0.0.7.20 (mesures : à-coups de 20 à 100 ms en traversant une forêt) : avant la surface d'une colonne, ses hauteurs du
# sol (18 × 18 points, gardées ensuite par le terrain) se calculent par tranches de HEIGHT_ROWS lignes, une tranche par
# étape : la surface, qui les relit, ne prend plus que quelques millisecondes au lieu de 20 à 75.
const HEIGHT_ROWS := 3
var column_height_rows: Dictionary = {}
const SurfaceJob = preload("res://scripts/surface_job.gd")
const SURFACE_STEP_USEC := 1500
var surface_jobs: Dictionary = {}
var surface_job_edits := 0
var cave_job: RefCounted
var cave_job_edits := 0
var terrain_edits := 0
var opening_columns := true

func _terrain_step(index: int = 0) -> void:
	var column: Vector2i = terrain_queue[index]
	if not shown_columns.has(column):
		terrain_queue.remove_at(index)
		column_pending.erase(column)
		column_height_rows.erase(column)
		return
	var row: int = column_height_rows.get(column, 0)
	var points: int = SmoothTerrain.POINTS + 2
	# À l'ouverture, colonnes juste autour du joueur d'un coup, comme avant 0.0.7.20 : il peut y marcher tout de suite. La file
	# va des plus proches aux plus loin : la première colonne plus loin finit l'ouverture (ensuite, tout en petites étapes).
	var close := false
	if opening_columns:
		close = maxi(absi(column.x - view_center.x), absi(column.y - view_center.y)) <= 1
		opening_columns = close
	if row < points and not heights_ready.has(column) and not close:
		var at := Time.get_ticks_usec()
		for x in range(row, mini(row + HEIGHT_ROWS, points)):
			for z in range(points):
				terrain.ground_height(Vector2i(column.x * SmoothTerrain.POINTS - 1 + x, column.y * SmoothTerrain.POINTS - 1 + z))
		column_height_rows[column] = row + HEIGHT_ROWS
		if row + HEIGHT_ROWS >= points:
			heights_ready[column] = true
		if perf_on:
			_perf("terrain_hauteurs", at)
		return
	if not column_pending.has(column):
		column_pending[column] = _surveyed(column).duplicate()
	var pending: Array = column_pending[column]
	if pending.is_empty():
		terrain_queue.remove_at(index)
		column_pending.erase(column)
		column_height_rows.erase(column)
		worker_done.erase(column)
		_finish_column(column, true)
	else:
		var at := Time.get_ticks_usec()
		var zone: Vector3i = pending.back()
		# 0.0.7.20 : zone plate (carré partagé) : tout de suite ; sinon sa surface est calculée en petites étapes
		# (surface_job.gd, 3 ms au plus par image), puis la zone est montée d'un coup.
		# 0.0.8.13 : surface déjà calculée par un fil de calcul (colonne sans changement du joueur autour), sinon [].
		var ready_surface: Array = [] if close else _take_worker_surface(zone)
		if close or terrain.is_flat(zone):
			surface_jobs.erase(zone)
			pending.pop_back()
			rebuild_terrain_piece(zone)
		elif not ready_surface.is_empty():
			surface_jobs.erase(zone)
			pending.pop_back()
			rebuild_terrain_piece(zone, false, ready_surface)
		else:
			# 0.0.7.22 : un calcul commencé par zone, repris où il en était si une autre colonne passe devant (le joueur
			# attend au bord d'une autre) ; recommencé si le terrain a changé depuis (terrain_edits).
			if surface_job_edits != terrain_edits:
				surface_jobs.clear()
				surface_job_edits = terrain_edits
			var job: RefCounted = surface_jobs.get(zone)
			if job == null:
				job = SurfaceJob.new(terrain, zone)
				surface_jobs[zone] = job
			if job.step(SURFACE_STEP_USEC):
				pending.pop_back()
				surface_jobs.erase(zone)
				rebuild_terrain_piece(zone, false, job.result)
		if perf_on:
			_perf("terrain_morceau", at)

# 0.0.8.13 « Plusieurs cœurs » : les hauteurs et les surfaces des colonnes sans changement du joueur autour (la plupart, en
# découvrant le monde) sont calculées par les fils de calcul (terrain_workers.gd, une copie du terrain chacun) ; le fil
# principal reçoit les nombres, ne monte plus que les morceaux (maillage, collision), l'herbe et les objets. Les colonnes
# changées par le joueur, celles d'à côté, les grottes et les tout premiers instants de l'ouverture restent faits ici.
const TerrainWorkers = preload("res://scripts/terrain_workers.gd")
# Colonnes envoyées par fil de calcul prêt, au plus (les plus proches du joueur d'abord, comme la file).
const WORKER_AHEAD := 6
# Carrés du lointain envoyés par fil de calcul prêt, au plus.
const WORKER_FAR_AHEAD := 3
# Colonne en tête de la file attendue plus longtemps (fils de calcul très occupés ou ralentis par le système) : faite ici.
const WORKER_PATIENCE_MSEC := 1500
var terrain_workers: RefCounted = null
# Colonne envoyée → heure de l'envoi (ms) ; retirée quand son résultat arrive.
var worker_columns: Dictionary = {}
# Colonne dont les hauteurs viennent d'un fil de calcul (ses surfaces dans worker_surfaces), jusqu'à ce qu'elle soit finie.
var worker_done: Dictionary = {}
var worker_surfaces: Dictionary = {}
# Carré du lointain envoyé (clé de far_surveys) → résultat attendu.
var worker_far: Dictionary = {}
# Zones montées avec une surface d'un fil de calcul (mesures, tests).
var worker_built := 0

func _workers_on() -> bool:
	return terrain_workers != null and terrain_workers.is_ready()

# La colonne peut être calculée par un fil de calcul : sa copie ne connaît que la graine (aucun changement du joueur dans
# la colonne ni autour) ; les colonnes juste autour du joueur à l'ouverture sont faites tout de suite ici.
func _worker_fits(column: Vector2i) -> bool:
	if opening_columns and maxi(absi(column.x - view_center.x), absi(column.y - view_center.y)) <= 1:
		return false
	return not terrain.zone_column_changed(column)

# La colonne est (ou sera) faite ici : pas pour un fil de calcul, ou déjà commencée ici.
func _main_builds(column: Vector2i) -> bool:
	if worker_done.has(column):
		return false
	return not _worker_fits(column) or heights_ready.has(column) or column_height_rows.has(column) or column_pending.has(column)

# Prochaine colonne à avancer ici : la première de la file qui n'attend pas un fil de calcul ; -1 : toutes attendent.
# Seulement le début de la file (au-delà, rien n'est encore envoyé : les colonnes y attendent leur tour, plus proches
# d'abord) : la file entière (jusqu'à plus de 1 000 colonnes en Beauté) parcourue à chaque étape coûterait des millisecondes.
func _next_terrain_index() -> int:
	if not _workers_on():
		return 0
	var window := mini(terrain_queue.size(), terrain_workers.ready_count() * WORKER_AHEAD + WORKER_SCAN_EXTRA)
	for index in range(window):
		var column: Vector2i = terrain_queue[index]
		if not shown_columns.has(column) or worker_done.has(column) or _main_builds(column):
			return index
		# En tête et attendue trop longtemps : faite ici (son résultat, s'il arrive, sera laissé).
		if index == 0 and worker_columns.has(column) and Time.get_ticks_msec() - int(worker_columns[column]) > WORKER_PATIENCE_MSEC:
			return 0
	return -1

const WORKER_SCAN_EXTRA := 8

func _dispatch_worker_columns() -> void:
	var limit: int = terrain_workers.ready_count() * WORKER_AHEAD
	if worker_columns.size() >= limit:
		return
	var window := mini(terrain_queue.size(), limit + WORKER_SCAN_EXTRA)
	for index in range(window):
		if worker_columns.size() >= limit:
			return
		var column: Vector2i = terrain_queue[index]
		if worker_columns.has(column) or worker_done.has(column) or not shown_columns.has(column) or _main_builds(column):
			continue
		# La première de la file (le joueur attend peut-être au bord : ground_ready) passe devant les autres travaux.
		terrain_workers.add_column(column, index == 0)
		worker_columns[column] = Time.get_ticks_msec()

func _collect_worker_results() -> void:
	for result: Dictionary in terrain_workers.take_results():
		if result.kind == "lointain":
			worker_far.erase(result.key)
			var survey: Dictionary = far_surveys.get(result.key, {})
			if survey.is_empty() or survey.next < survey.side:
				far_surveys[result.key] = result.survey
			continue
		var column: Vector2i = result.column
		worker_columns.erase(column)
		# Sortie de la vue, déjà finie ou commencée ici entre-temps : rien à reprendre.
		if not shown_columns.has(column) or built_columns.has(column) or column_pending.has(column) or column_height_rows.has(column):
			continue
		# Hauteurs de la graine (jamais changées par le joueur) : gardées comme si elles avaient été calculées ici.
		var known: Dictionary = terrain._heights
		var heights: Dictionary = result.heights
		for point: Vector2i in heights:
			if not known.has(point):
				known[point] = heights[point]
		heights_ready[column] = true
		worker_done[column] = true
		# Changée par le joueur pendant le calcul : surfaces refaites ici (avec ses changements).
		if terrain.zone_column_changed(column):
			continue
		var surfaces: Dictionary = result.surfaces
		for zone: Vector3i in surfaces:
			worker_surfaces[zone] = surfaces[zone]

# Surface d'une zone reçue d'un fil de calcul (et toujours valable : rien changé autour depuis), sinon [] ; retirée.
func _take_worker_surface(zone: Vector3i) -> Array:
	if not worker_surfaces.has(zone):
		return []
	var surface: Array = worker_surfaces[zone]
	worker_surfaces.erase(zone)
	if terrain.zone_column_changed(Vector2i(zone.x, zone.z)):
		return []
	worker_built += 1
	return surface

# Lointain : les relevés des prochains carrés envoyés aux fils de calcul (une fois par image).
func _dispatch_worker_far() -> void:
	_collect_worker_results()
	var limit: int = terrain_workers.ready_count() * WORKER_FAR_AHEAD
	if worker_far.size() >= limit:
		return
	for tile: Vector2i in far_queue:
		if worker_far.size() >= limit:
			return
		var survey := _far_survey(tile)
		if survey.next >= survey.side:
			continue
		var key := Vector3i(tile.x, tile.y, int(survey.cell))
		if worker_far.has(key):
			continue
		terrain_workers.add_far(key, tile, survey.cell)
		worker_far[key] = true
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
	# 0.0.7.25 : herbe et plantes en attente aussi.
	_process_detail_queue(1 << 40)

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
	# 0.0.8.27 : la couleur de l'horizon selon l'heure (bleu le jour, orangée au crépuscule, sombre la nuit).
	environment.fog_light_color = DayNight.sky_horizon(day_time)
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
func rebuild_terrain_piece(zone: Vector3i, flat_for_now: bool = false, ready_surface: Array = []) -> void:
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
	# 0.0.8.11 (rapport Web : les ombres coûtaient 17 ms de GPU ; demande de l'utilisateur : aussi pour les PC bon marché) :
	# le terrain reçoit les ombres mais n'en projette plus (seuls arbres, rochers et personnages), sur le Web comme sur PC.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var collision: CollisionShape3D = null
	var faces: Array = []
	if flat_for_now or terrain.is_flat(zone):
		if not SmoothTerrain.ground_zone(zone):
			body.free()
			# 0.0.8.14 : zone vide : le modèle préparé n'est jamais montré (avant : jamais libéré, 200 à l'ouverture, 1 500 après
			# un tour du monde en vol).
			instance.free()
			return
		body.position = Vector3(zone.x, 0, zone.z) * SmoothTerrain.ZONE_SIZE
		instance.mesh = flat_ground_mesh
		collision = CollisionShape3D.new()
		collision.shape = flat_ground_shape
		collision.position = Vector3(SmoothTerrain.ZONE_SIZE / 2.0, -0.5, SmoothTerrain.ZONE_SIZE / 2.0)
	else:
		# 0.0.6.18 (#175) : sommets partagés et triangles par indices (même image, environ 6 fois moins de sommets).
		var surface_at := Time.get_ticks_usec()
		# 0.0.7.20 : surface déjà calculée en petites étapes (file du terrain), sinon d'un coup (gestes, grottes, tout près).
		var surface: Array = ready_surface if not ready_surface.is_empty() else terrain.zone_surface(zone)
		if perf_on:
			_perf("terrain_surface", surface_at)
			var spent := (Time.get_ticks_usec() - surface_at) / 1000.0
			if spent > 20.0:
				perf_slow.append([zone, snappedf(spent, 0.1), surface[0].size(), terrain.caves_in_zone(zone).size(), _player_column()])
		if surface[6].is_empty():
			body.free()
			# 0.0.8.14 : zone vide : le modèle préparé n'est jamais montré (avant : jamais libéré, 200 à l'ouverture, 1 500 après
			# un tour du monde en vol).
			instance.free()
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
			var collision_at := Time.get_ticks_usec()
			_build_collision(zone)
			if perf_on:
				_perf("terrain_collision", collision_at)
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
	# 0.0.8.8 : ni là où on l'a arrachée.
	# 0.0.8.15 (#239) : gazon posé : l'herbe repousse là, même sur un sol creusé.
	if turf_cells.has(column) and not pulled_grass.has(column):
		return false
	return pulled_grass.has(column) or terrain.column_changed(column) or terrain.is_desert(Vector2(at.x, at.z)) or terrain.muddy(column) or terrain.needle_floor(column)

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
# 0.0.8.3 (demande de l'utilisateur) : « Manger » au bout de la ligne du clic droit (EAT_BRUSH).
const BRUSH_NAMES := ["Poser", "Aplanir", "Lisser", "Manger"]
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
	if not name.is_empty():
		return name
	# 0.0.8.19 (correction de l'utilisateur) : une poche choisie, vide : « Poche vide » (avant : « Main vide »).
	if game_mode == Inventory.SURVIVAL and inventory.selected() in Inventory.BAG:
		return "Sac : case vide"
	return "Poche vide" if game_mode == Inventory.SURVIVAL and inventory.selected() in Inventory.POCKETS else "Main vide"

# 0.0.7.10 (demande de l'utilisateur) : ce que montre chaque main. Créatif : l'objet choisi dans la main droite, la
# gauche vide. Survie : case 1 dans la main gauche, case 2 dans la main droite ; une poche choisie : son objet sorti dans
# la main droite si elle est libre ; objet lourd à deux mains : tenu par la main droite, la gauche le soutient (vide).
func left_hand_item() -> Dictionary:
	if game_mode != Inventory.SURVIVAL or inventory.two_handed() >= 0:
		return {}
	return inventory.item("bar", Inventory.HANDS[0])

func right_hand_item() -> Dictionary:
	if game_mode != Inventory.SURVIVAL:
		return inventory.held()
	var heavy := inventory.two_handed()
	if heavy >= 0:
		return inventory.item("bar", heavy)
	var right: Dictionary = inventory.item("bar", Inventory.HANDS[1])
	# 0.0.8.21 (#207) : une case du sac choisie : comme une poche.
	if (inventory.selected() in Inventory.POCKETS or inventory.selected() in Inventory.BAG) and right.is_empty():
		return inventory.held()
	return right

func apply_held() -> void:
	if is_instance_valid(player):
		player.selected_type = inventory.held_kind()
		player.show_hands(left_hand_item(), right_hand_item(), game_mode == Inventory.SURVIVAL and inventory.two_handed() >= 0)
		# 0.0.8.21 (#207) : les sacs portés, sur le personnage.
		var survival_mode: bool = game_mode == Inventory.SURVIVAL
		player.show_bags([survival_mode and inventory.bag_worn(0), survival_mode and inventory.bag_worn(1)])
		# 0.0.7.8 : plus lent quand les mains portent lourd.
		player.carry_slow = inventory.carry_factor()


# carry : 0.0.8.25 (choix de l'utilisateur) : changement de mode en jouant (Paramètres) : le même inventaire passe dans
# l'autre mode (Inventory.carry_to) ; ce qui ne tient pas en Survie tombe aux pieds du joueur.
func set_game_mode(new_mode: String, carry := false) -> void:
	# 0.0.7.9 : en Survie, on ne vole pas (on retombe si on volait).
	if new_mode == Inventory.SURVIVAL and is_instance_valid(player):
		player.flying = false
		# 0.0.8 : la chute qui suit le passage en Survie (on volait peut-être très haut) ne blesse pas.
		fall_ignored = game_mode != Inventory.SURVIVAL
	var left: Array = inventory.carry_to(new_mode) if carry and new_mode != game_mode else []
	game_mode = new_mode
	inventory.set_mode(new_mode)
	if carry:
		inventory_unsaved = true
	for each in left:
		_drop_units(each[0], int(each[1]))
	if not left.is_empty():
		_notify("Survie : ce qui ne tient pas dans vos mains, vos poches et votre sac est tombé à vos pieds.")
		notice_time = 5.0

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
	if inventory_open or death_open or crafting_open or notebook_open or not is_instance_valid(inventory_ui):
		return
	inventory_open = true
	notebook_mark("inventaire")
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

# --- 0.0.8.16 (#208, demande de l'utilisateur) : Carnet de route (O + C, ou le menu Échap ; carnet.gd, carnet_ui.gd) ---
# Les cases (commandes) se cochent quand on les fait ; les étapes du chemin (Survie) quand on a l'objet sur soi. La première
# fois qu'on entre dans un monde, un message dit comment l'ouvrir.
const Carnet = preload("res://scripts/carnet.gd")
const CarnetUI = preload("res://scripts/carnet_ui.gd")
const NOTEBOOK_HINT := "Pour ouvrir le Carnet de route (commandes et premiers outils), appuyez sur O + C (aussi dans le menu Échap)."
const NOTEBOOK_WALK := 4.0
var notebook := Carnet.new()
var notebook_ui: CanvasLayer
var notebook_open := false
var notebook_seen := false
var _walk_from := Vector3.INF

func toggle_notebook() -> void:
	if notebook_open:
		close_notebook()
	else:
		open_notebook()

func open_notebook() -> void:
	if notebook_open or death_open or not is_instance_valid(player):
		return
	if inventory_open:
		close_inventory(false)
	if crafting_open:
		close_crafting(false)
	if not is_instance_valid(notebook_ui):
		notebook_ui = CarnetUI.new()
		notebook_ui.setup(notebook, text_scale)
		notebook_ui.closed.connect(close_notebook)
		add_child(notebook_ui)
	notebook_open = true
	_set_hud_visible(false)
	player.release_controls()
	_show_aim(false)
	notebook_ui.open()

func close_notebook(recapture: bool = true) -> void:
	if not notebook_open:
		return
	notebook_open = false
	notebook_ui.close()
	_set_hud_visible(true)
	_show_aim(true)
	if recapture and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# Coche une case ou une étape (une fois) : un petit message.
func notebook_mark(id: String) -> void:
	if notebook.mark(id):
		_notify("Carnet de route : « %s » ✓" % Carnet.name_of(id))
		inventory_unsaved = true

func _on_notebook_inventory() -> void:
	if game_mode != Inventory.SURVIVAL:
		return
	var fresh := notebook.check_inventory(inventory)
	if not fresh.is_empty():
		_notify("Carnet de route : « %s » ✓" % Carnet.name_of(fresh[-1]))
		inventory_unsaved = true

func _step_notebook() -> void:
	if behind_loading or not is_instance_valid(player):
		return
	if not notebook_seen:
		notebook_seen = true
		inventory_unsaved = true
		_notify(NOTEBOOK_HINT)
		notice_time = 9.0
	if not notebook.is_done("deplacer"):
		if _walk_from == Vector3.INF:
			_walk_from = player.global_position
		elif player.global_position.distance_to(_walk_from) > NOTEBOOK_WALK:
			notebook_mark("deplacer")

# --- 0.0.8.5 (#211, demandes de l'utilisateur) : fabrication à la main (O + F, crafting_ui.gd), créée à la première ouverture ---
const CraftingUI = preload("res://scripts/crafting_ui.gd")
var crafting_ui: CanvasLayer
var crafting_open := false

func toggle_crafting() -> void:
	if crafting_open:
		close_crafting()
	else:
		open_crafting()

func open_crafting() -> void:
	if crafting_open or inventory_open or death_open or notebook_open or not is_instance_valid(player):
		return
	_prepare_crafting()
	crafting_open = true
	notebook_mark("fabrication")
	# L'interface du jeu (barre, vie, messages) cachée : l'écran de fabrication montre ses propres cases.
	_set_hud_visible(false)
	player.release_controls()
	_show_aim(false)
	crafting_ui.open()

func _prepare_crafting() -> void:
	if not is_instance_valid(crafting_ui):
		crafting_ui = CraftingUI.new()
		crafting_ui.setup(self, inventory, player.skin, Callable(self, "_kind_material"), text_scale)
		crafting_ui.closed.connect(close_crafting)
		add_child(crafting_ui)

# 0.0.8.11 (rapport Web : 104 ms à la première ouverture de l'inventaire, 196 ms pour la fabrication) : derrière l'écran de
# chargement, une fois la vue construite, l'inventaire et la fabrication (créée d'avance) sont dessinés UI_PREWARM_FRAMES
# images, presque transparents, puis cachés. -1 : pas encore ; 0 : fait.
const UI_PREWARM_FRAMES := 3
var ui_prewarm_left := -1

func _step_ui_prewarm() -> void:
	if ui_prewarm_left == 0:
		return
	if ui_prewarm_left < 0:
		if not behind_loading or not terrain_queue.is_empty() or not is_instance_valid(inventory_ui):
			return
		_prepare_crafting()
		inventory_ui.prewarm(true)
		crafting_ui.prewarm(true)
		ui_prewarm_left = UI_PREWARM_FRAMES
		return
	ui_prewarm_left -= 1
	if ui_prewarm_left == 0:
		if not inventory_open:
			inventory_ui.prewarm(false)
		if is_instance_valid(crafting_ui) and not crafting_open:
			crafting_ui.prewarm(false)

func close_crafting(recapture: bool = true) -> void:
	if not crafting_open:
		return
	crafting_open = false
	crafting_ui.close()
	_set_hud_visible(true)
	_show_aim(true)
	apply_held()
	if recapture and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# Ce qui est fabriqué : rangé dans les mains et les poches (Survie) ou l'inventaire (Créatif) ; ce qui ne tient pas tombe
# au sol devant soi. 0.0.8.8 (demande de l'utilisateur) : en Survie, dans la première main (case 1) ; ce qu'elle tenait
# passe dans la deuxième main, sinon dans une poche, sinon au sol.
func give_crafted(value: Dictionary) -> int:
	var amount := Inventory.count(value)
	var rest := value
	if game_mode == Inventory.SURVIVAL:
		var hand: int = Inventory.HANDS[0]
		var there := inventory.item("bar", hand)
		if not there.is_empty() and not Inventory.same_kind(there, value):
			var moved := inventory.remove("bar", hand, true)
			rest = inventory._merge_into("bar", hand, value)
			var kept := inventory._merge_into("bar", Inventory.HANDS[1], moved)
			if not kept.is_empty():
				var placed := inventory.add(kept)
				_drop_units(kept, placed)
		else:
			rest = inventory._merge_into("bar", hand, value)
		inventory.changed.emit()
	var added := amount - Inventory.count(rest)
	if not rest.is_empty():
		var more := inventory.add(rest)
		added += more
		_drop_units(rest, more)
	inventory_unsaved = true
	return added

# 0.0.8.21 (#207) : un sac en filet fabriqué va directement sur l'épaule (Survie) s'il reste une place ; rend la place
# (0 : cases 7 à 10, 1 : dans l'inventaire) ou -1.
func wear_crafted_bag(value: Dictionary) -> int:
	if game_mode != Inventory.SURVIVAL:
		return -1
	var which := inventory.wear_bag(value)
	if which >= 0:
		inventory_unsaved = true
	return which

func _drop_units(value: Dictionary, skip: int) -> void:
	if not is_instance_valid(ground) or not is_instance_valid(player):
		return
	var near := player.global_position - player.global_transform.basis.z * 0.8
	for unit in Inventory.units(value).slice(skip):
		ground.drop(unit, player.camera.global_position - player.global_transform.basis.z * 0.3, near, _rest_height, 0.15)

# Croix de visée et message du bas : cachés derrière l'inventaire ouvert (le panneau est un peu transparent).
func _show_aim(on: bool) -> void:
	var crosshair: Control = find_child("Crosshair", true, false)
	if is_instance_valid(crosshair):
		crosshair.visible = on
	if is_instance_valid(hint):
		hint.visible = on

# Message quand une pioche manque (Survie seulement depuis 0.0.7.27 : en Créatif, les mains cassent tout).
func _needs_pickaxe(subject: String) -> String:
	# 0.0.8.10 : en Survie, la pioche en pierre (fabriquée : O + F).
	return subject + (" avec la pioche (inventaire : O + I, onglet Outils)." if game_mode == Inventory.CREATIVE else " plus vite avec une pioche en pierre (fabrication : O + F).")


# --- 0.0.7.8 : anneau de chargement, abattre et couper les arbres (demande de l'utilisateur) ---
const ProgressRing = preload("res://scripts/progress_ring.gd")
var ring: Control
var ring_value := 0.0
var ring_frame := -10

# Montre l'anneau de chargement (0 à 1) pour cette image ; il disparaît dès qu'on ne le montre plus.
func show_ring(value: float) -> void:
	ring_value = value
	ring_frame = Engine.get_process_frames()

func _update_ring() -> void:
	if is_instance_valid(ring):
		ring.progress = ring_value if Engine.get_process_frames() - ring_frame <= 1 else 0.0

# Abattre : clic gauche maintenu sur un arbre debout, CHOP_SECONDS à mains nues (Créatif : CHOP_SECONDS_CREATIVE) ;
# il tombe vers le joueur (plus tard, avec la vie, il faudra se décaler : #229). Arbre tombé : le même geste le coupe en
# deux à l'endroit visé (0.0.7.9, cut_tree) ; le bois nu devient des troncs et des branches au sol, à ramasser avec R.
# 0.0.7.11 : 5 s par tranche de 10 cm (avant : 8 s) ; 0.0.7.13 : 2,5 s (demande de l'utilisateur, tailles justes).
const CHOP_SECONDS := 2.5
# 0.0.7.27 (#217) : Créatif : tout en 0,3 s (avant : 1 s pour le bois).
const CHOP_SECONDS_CREATIVE := 0.3
const TREE_FALL_SECONDS := 1.6
var chop_target: Node3D
var chop_time := 0.0
# 0.0.7.9 : épaisseur du bois visé (m) et temps de coupe à mains nues (s).
var chop_thickness := 0.0
var chop_seconds := 0.0
# 0.0.7.11 : 40 cm au plus à mains nues (avant : 30 cm) ; 0.0.7.14 : de nouveau 40 cm (80 cm rendait la future hache inutile).
const MAX_HAND_THICKNESS := 0.40
# 0.0.7.9 : écart entre deux morceaux d'un arbre coupé (la coupe se voit) ; 0.0.7.12 : 40 cm et 20° (12 cm : caché par les feuilles).
const CUT_GAP := 0.40
const CUT_TURN := 0.3490659  # 20°
# Sauvegarde (objets.json) : arbres tombés {id: {"direction": [x, z], "position": [x, y, z]}} et arbres coupés {id: true}.
var fallen_trees: Dictionary = {}
var cut_trees: Dictionary = {}
var sliding_trees: Array = []

func step_chop(delta: float, holding: bool) -> bool:
	if not holding or not is_instance_valid(player):
		chop_target = null
		chop_time = 0.0
		chop_aim = {}
		return false
	var hit: Dictionary = player.get_target()
	# 0.0.7.26 (#212) : rejet de noisetier visé : cassé en maintenant.
	if not hit.is_empty() and is_instance_valid(hit.get("collider")) and hit.collider.is_in_group("shoots") and player.camera.global_position.distance_to(hit.position) <= player.break_reach + 0.01:
		return _step_break_shoot(delta, hit.collider)
	var tree: Node3D = null
	if not hit.is_empty() and is_instance_valid(hit.get("collider")) and hit.collider.is_in_group("trees") and player.camera.global_position.distance_to(hit.position) <= player.break_reach + 0.01:
		# 0.0.7.9 : la tige de visée d'un morceau coupé renvoie à son arbre.
		tree = hit.collider.get_meta("arbre", hit.collider)
	# 0.0.7.12 : la branche ou la tige visée (tree_parts.gd) ; seuls les arbres coupés avant (coupes par hauteur, mondes
	# de 0.0.7.9 à 0.0.7.11) gardent l'ancienne façon.
	if tree == null or not _legacy_cut(tree):
		return _step_chop_parts(delta, hit)
	if tree == null or tree.has_meta("falling"):
		chop_target = null
		chop_time = 0.0
		return false
	var id := str(tree.get_meta("id", ""))
	var lying := fallen_trees.has(id)
	if tree != chop_target or chop_seconds <= 0.0:
		chop_target = tree
		_leave_series(tree)
		chop_time = 0.0
		# 0.0.7.11 : temps selon l'épaisseur du bois visé : 5 s par tranche de 10 cm (40 cm : 20 s) ; 40 cm au plus à mains nues.
		var model: Node3D = tree.get_node_or_null("Modele")
		var local: Vector3 = (tree.global_transform * (model.transform if model != null else Transform3D.IDENTITY)).affine_inverse() * hit.position
		# 0.0.7.10 : jamais plus bas que 30 cm au-dessus du pied (l'évasement des racines grossirait la mesure).
		local.y = maxf(local.y, 0.3)
		chop_thickness = Trees.wood_thickness(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3)), int(tree.get_meta("form", 0)), local) * tree.scale.x
		chop_seconds = maxf(CHOP_SECONDS * chop_thickness / 0.1, 0.5)
	if game_mode == Inventory.SURVIVAL and chop_thickness > max_chop_thickness() + 0.001:
		_notify(_too_thick_message())
		return false
	var seconds := CHOP_SECONDS_CREATIVE if game_mode == Inventory.CREATIVE else chop_seconds / tool_speed("bois")
	chop_time += delta
	show_ring(chop_time / seconds)
	if chop_time < seconds:
		return false
	chop_target = null
	chop_time = 0.0
	use_tool("bois", seconds)
	if lying:
		cut_tree(tree, hit.position)
	else:
		fell_tree(tree)
	return true


# --- 0.0.7.26 (#212) : branches mortes au sol et rejets de noisetier (génération 33, smooth_terrain.gd) ---
# Montrés seulement dans les colonnes à STICK_RING zones ou moins du joueur (petits, visibles de près). Branches : objets au
# sol de la graine (ground_items.gd add_seeded), ramassées avec R ; rejets : debout au pied des noisetiers, cassés en
# maintenant le clic (SHOOT_SECONDS, bois vert). Enregistrés : seulement ceux ramassés ou cassés (objets.json).
const STICK_RING := 3
const SHOOT_SECONDS := 2.0
const SHOOT_SECONDS_CREATIVE := 0.3
var picked_branches: Dictionary = {}
var broken_shoots: Dictionary = {}
var stick_columns: Dictionary = {}
var shoot_nodes: Dictionary = {}

func _in_stick_ring(column: Vector2i) -> bool:
	return maxi(absi(column.x - view_center.x), absi(column.y - view_center.y)) <= STICK_RING

# Colonnes autour du joueur : branches et rejets ajoutés aux colonnes construites qui entrent, retirés de celles qui sortent.
# Ajout par la file de fond (stick_queue, _process_detail_queue), une colonne à la fois, la plus proche d'abord.
var stick_queue: Array = []

func _refresh_sticks() -> void:
	for column: Vector2i in stick_columns.keys():
		if not built_columns.has(column) or not _in_stick_ring(column):
			_hide_column_sticks(column)
	for dx in range(-STICK_RING, STICK_RING + 1):
		for dz in range(-STICK_RING, STICK_RING + 1):
			_queue_sticks(view_center + Vector2i(dx, dz))

func _queue_sticks(column: Vector2i) -> void:
	if built_columns.has(column) and not stick_columns.has(column) and not stick_queue.has(column):
		stick_queue.append(column)

# Une colonne de la file (la plus proche du joueur) ; faux si la file est vide.
func _process_one_stick_column() -> bool:
	while not stick_queue.is_empty():
		var best := 0
		for index in range(1, stick_queue.size()):
			if Vector2(stick_queue[index] - view_center).length_squared() < Vector2(stick_queue[best] - view_center).length_squared():
				best = index
		var column: Vector2i = stick_queue[best]
		stick_queue.remove_at(best)
		if built_columns.has(column) and _in_stick_ring(column):
			var at := Time.get_ticks_usec()
			_show_column_sticks(column)
			if perf_on:
				_perf("batons", at)
			return true
	return false

func _show_column_sticks(column: Vector2i) -> void:
	if stick_columns.has(column) or not is_instance_valid(ground):
		return
	stick_columns[column] = true
	for branch: Dictionary in terrain.dead_branches_in_zone(column):
		if picked_branches.has(branch.id):
			continue
		var item := dead_branch_item(branch)
		var spot := Vector3(float(branch.x), 0.0, float(branch.z))
		ground.add_seeded(item, Vector3(spot.x, _rest_height(spot) + GroundItems.lift(item), spot.z), column)
	_build_shoots(column)

func _hide_column_sticks(column: Vector2i) -> void:
	stick_columns.erase(column)
	if is_instance_valid(ground):
		ground.remove_column_seeds(column)
	if is_instance_valid(shoot_nodes.get(column)):
		shoot_nodes[column].queue_free()
	shoot_nodes.erase(column)

# Objet d'une branche morte : bois mort (léger, cassant), tordu ou droit, pourri ou sain ; l'épaisseur au gros bout.
static func dead_branch_item(branch: Dictionary) -> Dictionary:
	var thickness: float = branch.epaisseur
	var length: float = branch.longueur
	var rotten: bool = branch.pourrie
	var radius := thickness / 200.0
	var weight := PI * radius * radius * length * 750000.0 * (0.35 if rotten else 0.55)
	var size := Inventory.WOOD_SIZES.size()
	for index in range(Inventory.WOOD_SIZES.size()):
		if thickness <= Inventory.WOOD_SIZES[index]:
			size = index + 1
			break
	var item := {"objet": "branche", "taille": size, "epaisseur": snappedf(thickness, 0.1), "fin": snappedf(thickness * 0.6, 0.1), "longueur": length, "essence": int(branch.espece), "age": 5 if rotten else 4, "souplesse": 1, "poids": maxf(snappedf(weight, 1.0), 1.0), "forme": 1 + absi(hash(branch.id)) % 7, "rotation": float(branch.rotation), "morte": 1, "graine": str(branch.id)}
	if not branch.droite:
		item.tordue = 1
	if rotten:
		item.pourrie = 1
	return item

# Rejets debout d'une colonne : un dessin pour tous (écorce de noisetier) et une petite collision chacun pour les viser
# (couche 2 : le joueur passe au travers).
func _build_shoots(column: Vector2i) -> void:
	if is_instance_valid(shoot_nodes.get(column)):
		shoot_nodes[column].free()
	shoot_nodes.erase(column)
	var shoots := terrain.hazel_shoots_in_zone(column).filter(func(shoot: Dictionary): return not broken_shoots.has(shoot.id))
	if shoots.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "Rejets"
	var series := MultiMesh.new()
	series.transform_format = MultiMesh.TRANSFORM_3D
	series.mesh = _shoot_mesh()
	series.instance_count = shoots.size()
	for index in range(shoots.size()):
		var shoot: Dictionary = shoots[index]
		var foot := Vector3(float(shoot.x), terrain.height_at(float(shoot.x), float(shoot.z)) - 0.05, float(shoot.z))
		var lean := Basis(Vector3.UP.cross(Vector3.FORWARD.rotated(Vector3.UP, float(shoot.direction))).normalized(), float(shoot.penche)) if float(shoot.penche) > 0.0 else Basis.IDENTITY
		var shape_basis := lean * Basis.from_scale(Vector3(float(shoot.epaisseur) / 100.0, float(shoot.longueur), float(shoot.epaisseur) / 100.0))
		series.set_instance_transform(index, Transform3D(shape_basis, foot))
		var body := StaticBody3D.new()
		body.name = "Rejet"
		body.add_to_group("shoots")
		body.collision_layer = 2
		body.collision_mask = 0
		body.set_meta("shoot", shoot)
		body.set_meta("column", column)
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.12, float(shoot.longueur), 0.12)
		collision.shape = box
		collision.position = Vector3(0.0, float(shoot.longueur) * 0.5, 0.0)
		body.add_child(collision)
		body.transform = Transform3D(lean, foot)
		holder.add_child(body)
	var drawn := MultiMeshInstance3D.new()
	drawn.multimesh = series
	drawn.material_override = Trees.material(Trees.HAZEL, "bark")
	drawn.visibility_range_end = Trees.detail_end
	holder.add_child(drawn)
	_rocks_parent().add_child(holder)
	shoot_nodes[column] = holder

# Tige de 1 m de haut et 1 cm de diamètre (agrandie pour chaque rejet), un peu plus fine en haut.
static var _shoot_shape: CylinderMesh

static func _shoot_mesh() -> CylinderMesh:
	if _shoot_shape == null:
		_shoot_shape = CylinderMesh.new()
		_shoot_shape.top_radius = 0.35
		_shoot_shape.bottom_radius = 0.5
		_shoot_shape.height = 1.0
		_shoot_shape.radial_segments = 6
		_shoot_shape.rings = 1
		_shoot_shape.cap_top = true
		_shoot_shape.cap_bottom = false
	return _shoot_shape

# Rejet visé, clic maintenu : cassé au bout de SHOOT_SECONDS (bois vert) ; il tombe au sol, à ramasser avec R.
func _step_break_shoot(delta: float, body: Node3D) -> bool:
	if body != chop_target:
		chop_target = body
		chop_time = 0.0
	var seconds := SHOOT_SECONDS_CREATIVE if game_mode == Inventory.CREATIVE else SHOOT_SECONDS
	chop_time += delta
	show_ring(chop_time / seconds)
	if chop_time < seconds:
		return false
	chop_target = null
	chop_time = 0.0
	var shoot: Dictionary = body.get_meta("shoot")
	var column: Vector2i = body.get_meta("column")
	broken_shoots[str(shoot.id)] = true
	objects_dirty = true
	var item := shoot_item(shoot)
	var top: Vector3 = body.global_transform * Vector3(0.0, float(shoot.longueur) * 0.7, 0.0)
	ground.drop(item, top, body.global_position + Vector3(0.0, 0.0, 0.0), _rest_height, 0.15)
	_build_shoots(column)
	_impact_sound(top)
	show_choice("Rejet de noisetier au sol : à ramasser avec R")
	return true

# Objet d'un rejet cassé : bois vert de noisetier, droit et sain (le meilleur manche).
static func shoot_item(shoot: Dictionary) -> Dictionary:
	var thickness: float = shoot.epaisseur
	var length: float = shoot.longueur
	var radius := thickness / 200.0
	var size := Inventory.WOOD_SIZES.size()
	for index in range(Inventory.WOOD_SIZES.size()):
		if thickness <= Inventory.WOOD_SIZES[index]:
			size = index + 1
			break
	return {"objet": "branche", "taille": size, "epaisseur": snappedf(thickness, 0.1), "fin": snappedf(thickness * 0.55, 0.1), "longueur": length, "essence": Trees.HAZEL, "age": 2, "souplesse": 4, "poids": maxf(snappedf(PI * radius * radius * length * 750000.0 * 0.9, 1.0), 1.0), "forme": 1 + absi(hash(shoot.id)) % 7, "rejet": 1}
# --- 0.0.7.12 (demande de l'utilisateur) : couper SEULEMENT la branche ou la tige visée ---
# À mains nues, on coupe la pièce visée (tronc, tige, branche, brindille) à l'endroit visé ; plus tard, la hache en
# coupera plusieurs d'un coup. Ce qui est détaché (la fin de la pièce et tout ce qu'elle porte, tree_parts.gd) :
# - une branche : un bâton au sol (tronc ou branche, à sa vraie taille), ses feuilles tombent ;
# - le tronc d'un arbre debout : visé à moins de ROOT_CUT_HEIGHT du pied, tout l'arbre tombe depuis la racine ; plus
#   haut, une souche reste debout et le haut tombe depuis la coupe ; noisetier : seule la tige visée tombe ;
# - le tronc d'un arbre couché : coupé en deux, le bout détaché écarté de CUT_GAP et tourné de CUT_TURN.
# Un morceau couché presque sans feuilles devient du bois au sol (la souche reste) : voir _lying_bare (0.0.8.22).
# Sauvegarde : tree_cuts[id] = {"coupes": [[pièce, t], …], "morceaux": {"k": {"etat": "couche" ou "bois", place}}}.
const TreeParts = preload("res://scripts/tree_parts.gd")
const ROOT_CUT_HEIGHT := 0.5
const MIN_CUT_GAP := 0.05
var tree_cuts: Dictionary = {}
var chop_aim: Dictionary = {}

func _legacy_cut(tree: Node3D) -> bool:
	return fallen_trees.get(str(tree.get_meta("id", "")), {}).has("cuts")

func _model_of(tree: Node3D) -> Transform3D:
	var model: Node3D = tree.get_node_or_null("Modele")
	return tree.global_transform * (model.transform if model != null else Transform3D.IDENTITY)

func _cuts_of(tree: Node3D) -> Array:
	return tree_cuts.get(str(tree.get_meta("id", "")), {}).get("coupes", [])

func _tree_is_lying(tree: Node3D) -> bool:
	return int(tree.get_meta("part", 0)) != 0 or fallen_trees.has(str(tree.get_meta("id", "")))

func _part_hidden_fruits(tree: Node3D) -> Array:
	var cuts := _cuts_of(tree)
	if cuts.is_empty():
		return []
	return TreeParts.hidden_fruits(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3)), int(tree.get_meta("form", 0)), cuts, int(tree.get_meta("part", 0)))

# Branche ou tige visée : le rayon de visée contre les pièces des arbres proches, sans rien de solide devant.
func aimed_wood(hit: Dictionary) -> Dictionary:
	if not is_instance_valid(player):
		return {}
	var origin: Vector3 = player.camera.global_position
	var direction: Vector3 = -player.camera.global_transform.basis.z
	var reach: float = player.break_reach
	if not hit.is_empty() and is_instance_valid(hit.get("collider")) and not hit.collider.is_in_group("trees"):
		reach = minf(reach, origin.distance_to(hit.position) + 0.05)
	var best := {}
	var here := _player_column()
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for tree in column_objects.get(here + Vector2i(dx, dz), []):
				if not is_instance_valid(tree) or not tree.is_in_group("trees") or not tree.has_meta("kind") or tree.has_meta("falling") or _legacy_cut(tree):
					continue
				if tree.global_position.distance_to(origin) > reach + 30.0:
					continue
				var to_model := _model_of(tree).affine_inverse()
				var scale: float = tree.scale.x
				var from: Vector3 = to_model * origin
				var toward: Vector3 = (to_model.basis * direction).normalized()
				var detail: MeshInstance3D = tree.get_node_or_null("Modele/Detail")
				# 0.0.7.21 : arbre dessiné en série (sans modèle à lui) : la boîte de son modèle.
				var shown: Mesh = detail.mesh if detail != null else (Trees.mesh(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3)), false, int(tree.get_meta("form", 0))) if tree.has_meta("series") else null)
				if shown != null and shown.get_aabb().grow(0.3).intersects_ray(from, toward) == null:
					continue
				var kind := int(tree.get_meta("kind", 0))
				var size := int(tree.get_meta("size", 3))
				var form := int(tree.get_meta("form", 0))
				var found := TreeParts.ray(kind, size, form, _cuts_of(tree), int(tree.get_meta("part", 0)), from, toward, reach / scale)
				if found.is_empty():
					continue
				var distance: float = found.distance * scale
				if best.is_empty() or distance < best.distance:
					best = {"tree": tree, "piece": found.piece, "t": found.t, "distance": distance, "point": _model_of(tree) * (found.point as Vector3)}
	# Touffe visée entre ses tiges (collision du pied) : la tige la plus proche du point touché.
	if not hit.is_empty() and is_instance_valid(hit.get("collider")) and hit.collider.is_in_group("trees") and origin.distance_to(hit.position) <= reach + 0.01:
		var tree: Node3D = hit.collider.get_meta("arbre", hit.collider)
		if best.is_empty() or best.distance > origin.distance_to(hit.position) + 0.3:
			if tree.has_meta("kind") and not tree.has_meta("falling") and not _legacy_cut(tree):
				var local: Vector3 = _model_of(tree).affine_inverse() * (hit.position as Vector3)
				var found := TreeParts.nearest_in_part(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3)), int(tree.get_meta("form", 0)), _cuts_of(tree), int(tree.get_meta("part", 0)), local, 0.35)
				if not found.is_empty():
					var piece: Dictionary = TreeParts.skeleton(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3)), int(tree.get_meta("form", 0))).pieces[found.piece]
					best = {"tree": tree, "piece": found.piece, "t": found.t, "distance": origin.distance_to(hit.position), "point": _model_of(tree) * (piece.start + piece.direction * found.t)}
	return best

# Épaisseur visée (m) : tronc ou tige droite : la vraie tranche (Trees.wood_thickness, hors racines) ; branche : son profil.
func _aim_thickness(aim: Dictionary) -> float:
	var tree: Node3D = aim.tree
	var kind := int(tree.get_meta("kind", 0))
	var size := int(tree.get_meta("size", 3))
	var form := int(tree.get_meta("form", 0))
	var piece: Dictionary = TreeParts.skeleton(kind, size, form).pieces[aim.piece]
	# 0.0.8.22 : toujours la tranche de la pièce visée elle-même (avant, tige ou tronc droit : une tranche horizontale de
	# tout l'arbre, qui pouvait prendre une tige voisine) ; pied : au-dessus de l'évasement des racines.
	var t: float = aim.t
	if piece.root and absf(piece.direction.y) > 0.01 and (piece.start + piece.direction * t).y < ROOT_FLARE:
		t = clampf((ROOT_FLARE - piece.start.y) / piece.direction.y, t, piece.length)
	return TreeParts.true_thickness(piece, t) * tree.scale.x

func _step_chop_parts(delta: float, hit: Dictionary) -> bool:
	var aim := aimed_wood(hit)
	# 0.0.7.14 : bois au sol visé (tronc, branche, bâton, rameau) : le recasser là où on vise.
	var lying := _ground_wood(hit)
	if lying >= 0 and (aim.is_empty() or aim.distance > player.camera.global_position.distance_to(hit.position)):
		return _step_chop_ground(delta, lying, hit.position)
	if aim.is_empty():
		chop_target = null
		chop_time = 0.0
		chop_aim = {}
		return false
	if chop_aim.get("tree") != aim.tree or chop_aim.get("piece") != aim.piece or chop_seconds <= 0.0:
		chop_aim = aim
		chop_target = aim.tree
		chop_time = 0.0
		chop_thickness = _aim_thickness(aim)
		chop_seconds = maxf(CHOP_SECONDS * chop_thickness / 0.1, 0.5)
	if game_mode == Inventory.SURVIVAL and chop_thickness > max_chop_thickness() + 0.001:
		_notify(_too_thick_message())
		return false
	var seconds := CHOP_SECONDS_CREATIVE if game_mode == Inventory.CREATIVE else chop_seconds / tool_speed("bois")
	chop_time += delta
	show_ring(chop_time / seconds)
	if chop_time < seconds:
		return false
	chop_target = null
	chop_time = 0.0
	chop_aim = {}
	use_tool("bois", seconds)
	cut_wood(aim.tree, aim.piece, aim.t, aim.point)
	return true

# --- 0.0.7.14 (demande de l'utilisateur) : recasser le bois au sol en deux, là où on vise ---
# Bois au sol visé (numéro de l'objet au sol), à portée, ou -1.
func _ground_wood(hit: Dictionary) -> int:
	if hit.is_empty() or not is_instance_valid(hit.get("collider")) or not hit.collider.is_in_group("ground_items") or not is_instance_valid(player):
		return -1
	if player.camera.global_position.distance_to(hit.position) > player.break_reach + 0.01:
		return -1
	var index: int = ground.index_of(hit.collider)
	if index < 0 or Inventory.ITEMS.get(ground.entries[index].item.get("objet", ""), {}).get("forme", "") != "bois":
		return -1
	return index

# Axe d'un bois au sol (du gros bout vers le petit bout) et part s (0 au gros bout, 1 au petit) du point visé.
func _wood_axis(entry: Dictionary) -> Vector3:
	var turn := float(entry.item.get("rotation", 0.0))
	return Vector3(sin(turn), 0.0, cos(turn))

func _wood_share(entry: Dictionary, point: Vector3) -> float:
	var length := float(entry.item.get("longueur", 1.0))
	return clampf((point - (entry.position as Vector3)).dot(_wood_axis(entry)) / maxf(length, 0.01) + 0.5, 0.0, 1.0)

func _step_chop_ground(delta: float, index: int, point: Vector3) -> bool:
	var entry: Dictionary = ground.entries[index]
	var item: Dictionary = entry.item
	var share := _wood_share(entry, point)
	var thick := float(item.get("epaisseur", 3.0))
	var thickness := lerpf(thick, float(item.get("fin", thick)), share) / 100.0
	if chop_aim.get("sol") != ground.bodies[index] or chop_seconds <= 0.0:
		chop_aim = {"sol": ground.bodies[index]}
		chop_target = null
		chop_time = 0.0
		chop_thickness = thickness
		chop_seconds = ground_wood_seconds(item, thickness)
	if game_mode == Inventory.SURVIVAL and chop_thickness > max_chop_thickness() + 0.001:
		_notify(_too_thick_message())
		return false
	var seconds := CHOP_SECONDS_CREATIVE if game_mode == Inventory.CREATIVE else chop_seconds / tool_speed("bois")
	chop_time += delta
	show_ring(chop_time / seconds)
	if chop_time < seconds:
		return false
	chop_time = 0.0
	chop_aim = {}
	use_tool("bois", seconds)
	return split_wood(index, point)

# 0.0.7.26 (#212) : durée pour recasser un bois au sol (Survie) : comme une branche (CHOP_SECONDS par 10 cm d'épaisseur),
# bois mort 0,4 fois, pourri 0,3 fois (cassants), rejet vert 1,5 fois (plie avant de casser).
static func ground_wood_seconds(item: Dictionary, thickness: float) -> float:
	var factor := 1.0
	if int(item.get("pourrie", 0)) == 1:
		factor = 0.3
	elif int(item.get("morte", 0)) == 1:
		factor = 0.4
	elif int(item.get("rejet", 0)) == 1:
		factor = 1.5
	return maxf(CHOP_SECONDS * thickness / 0.1 * factor, 0.2)

# 0.0.7.26 (#212) : bois au sol visé : les deux longueurs qu'il donnerait, cassé là, et le temps (ou trop épais).
func ground_wood_hint(hit: Dictionary) -> String:
	if not is_instance_valid(ground):
		return ""
	var index := _ground_wood(hit)
	if index < 0:
		return ""
	var entry: Dictionary = ground.entries[index]
	var item: Dictionary = entry.item
	var length := float(item.get("longueur", 1.0))
	var share := _wood_share(entry, hit.position)
	var thick := float(item.get("epaisseur", 3.0))
	var thickness := lerpf(thick, float(item.get("fin", thick)), share) / 100.0
	if share * length < MIN_WOOD_PIECE or (1.0 - share) * length < MIN_WOOD_PIECE:
		return "%s : trop près du bout pour casser là" % Inventory.item_name(item)
	if game_mode == Inventory.SURVIVAL and thickness > MAX_HAND_THICKNESS + 0.001:
		return "%s : trop épais à mains nues (%d cm)" % [Inventory.item_name(item), roundi(thickness * 100.0)]
	var seconds := CHOP_SECONDS_CREATIVE if game_mode == Inventory.CREATIVE else ground_wood_seconds(item, thickness)
	return "Casser ici : %d cm et %d cm (%s s)" % [roundi(share * length * 100.0), roundi((1.0 - share) * length * 100.0), String.num(snappedf(seconds, 0.1)).replace(".", ",")]

# Coupe un bois au sol en deux au point visé : chaque moitié garde sa vraie longueur, ses épaisseurs (gros bout, petit
# bout), son essence, son âge, sa souplesse ; poids selon son volume. Un rameau garde ses feuilles sur la moitié fine.
const MIN_WOOD_PIECE := 0.05

func split_wood(index: int, point: Vector3) -> bool:
	var entry: Dictionary = ground.entries[index]
	var item: Dictionary = entry.item
	var length := float(item.get("longueur", 1.0))
	var share := _wood_share(entry, point)
	if share * length < MIN_WOOD_PIECE or (1.0 - share) * length < MIN_WOOD_PIECE:
		_notify("Trop près du bout pour être coupé là.")
		return false
	var thick := float(item.get("epaisseur", 3.0))
	var thin := float(item.get("fin", thick))
	var middle := lerpf(thick, thin, share)
	var volume := func(a: float, b: float, l: float) -> float: return l * (a * a + a * b + b * b)
	var whole: float = volume.call(thick, thin, length)
	var axis := _wood_axis(entry)
	var big_end: Vector3 = (entry.position as Vector3) - axis * length * 0.5
	var halves := []
	for side in range(2):
		var piece := item.duplicate(true)
		var from := 0.0 if side == 0 else share
		var to := share if side == 0 else 1.0
		piece.longueur = snappedf((to - from) * length, 0.01)
		piece.epaisseur = snappedf(lerpf(thick, thin, from), 0.1)
		piece.fin = snappedf(lerpf(thick, thin, to), 0.1)
		piece.poids = maxf(snappedf(float(item.get("poids", 1.0)) * volume.call(piece.epaisseur, piece.fin, piece.longueur) / maxf(whole, 0.000001), 1.0), 1.0)
		piece.taille = Inventory.WOOD_SIZES.size()
		for size in range(Inventory.WOOD_SIZES.size()):
			if (piece.epaisseur + piece.fin) * 0.5 <= Inventory.WOOD_SIZES[size]:
				piece.taille = size + 1
				break
		# Rameau : les feuilles restent sur la moitié fine ; l'autre moitié devient un tronc ou une branche.
		if item.objet != "rameau" or side == 0:
			piece.objet = "tronc" if piece.epaisseur >= 4.0 else "branche"
		var spot: Vector3 = big_end + axis * ((from + to) * 0.5 * length + (side * 2 - 1) * 0.02)
		halves.append([piece, spot])
	ground.remove(index)
	for half in halves:
		ground.drop(half[0], half[1], half[1], _ground_at, 0.0)
	_impact_sound(point)
	show_choice("Coupé en deux : %s et %s" % [Inventory.item_name(halves[0][0]), Inventory.item_name(halves[1][0])])
	return true

func cut_wood(tree: Node3D, number: int, t: float, point: Vector3) -> void:
	var id := str(tree.get_meta("id", ""))
	var kind := int(tree.get_meta("kind", 0))
	var size := int(tree.get_meta("size", 3))
	var form := int(tree.get_meta("form", 0))
	var pieces: Array = TreeParts.skeleton(kind, size, form).pieces
	var piece: Dictionary = pieces[number]
	var part := int(tree.get_meta("part", 0))
	var lying := _tree_is_lying(tree)
	if piece.root and not lying:
		var stems := pieces.filter(func(other): return other.root and other.tip.y > 0.5)
		var height: float = (piece.start + piece.direction * t).y
		# Racines, ou tronc unique visé près du pied : tout l'arbre tombe depuis la racine.
		if stems.size() <= 1 and (piece.tip.y <= 0.5 or height < ROOT_CUT_HEIGHT):
			fell_tree(tree)
			return
		if piece.tip.y <= 0.5:
			return
		t = maxf(t, 0.03)
	var entry: Dictionary = tree_cuts.get(id, {"coupes": [], "morceaux": {}, "v": 2})
	var cuts: Array = entry.coupes
	# 0.0.7.15 (monde T56 : une coupe enregistrée deux fois, morceau vide) : pas deux coupes à moins de MIN_CUT_GAP sur
	# la même pièce, ni tout au bout d'une pièce (rien à détacher).
	if t > float(piece.length) - MIN_CUT_GAP or cuts.any(func(other): return int(other[0]) == number and absf(float(other[1]) - t) < MIN_CUT_GAP):
		_notify("Trop près d'une coupe ou du bout pour couper là.")
		return
	cuts.append([number, snappedf(t, 0.001)])
	entry.coupes = cuts
	tree_cuts[id] = entry
	objects_dirty = true
	var cut := cuts.size()
	# 0.0.8.23 : un bout coupé d'un morceau dont les feuilles sont tombées n'en a pas non plus.
	if lying and _stripped(tree):
		_mark_stripped(id, cut)
	_show_part(tree, not lying)
	if not piece.root and (not lying or _felled_trunk(tree)):
		# 0.0.8.22 (demandes de l'utilisateur) : la branche coupée tombe telle qu'elle est (ses branches, ses feuilles) et
		# reste couchée ainsi (_drop_branch) ; sur un arbre abattu aussi (l'utilisateur : « tombe entière » ; avant, elle
		# devenait tout de suite des bâtons à plat, ses feuilles disparues).
		_drop_branch(tree, cut, number, t)
		show_choice("Branche coupée : au sol, R fait tomber ses feuilles, puis son bois")
	elif not lying:
		_fall_part(tree, cut, number, t)
	elif _cut_to_wood(tree, cut, number):
		# 0.0.8.22 (gels en recoupant) : le bout coupé devient son bois tout de suite, à sa place (sans construire d'abord
		# son morceau 3D, aussitôt défait).
		_part_to_wood(tree, cut, -1, false)
		show_choice(("Coupé en deux" if piece.root else "Branche coupée") + " : bois au sol, à ramasser avec R")
	else:
		# Le bout coupé, feuillu, se sépare et se pose dans le prolongement (tige, tronc, grosse branche).
		var made := _part_node(tree, cut)
		_place_split(tree, made, number, t)
		show_choice("Coupé en deux")
	# 0.0.7.15 : le morceau couché qui reste se repose (il a pu perdre les branches qui le portaient).
	if lying:
		_rest_rigid(tree)
		_bend_into_ground(tree, _lying_direction(tree))
		_save_part(tree)
	if lying and _bare_to_wood(tree):
		show_choice("Coupé : bois au sol, à ramasser avec R")
	_all_wood(id)
	_impact_sound(point)

func _lying_direction(tree: Node3D) -> Vector3:
	var along := tree.global_basis.y
	along.y = 0.0
	return along.normalized() if along.length() > 0.01 else Vector3.FORWARD

# Le morceau d'un nœud d'arbre : son modèle, ses faces coupées, ses fruits, sa collision (arbre debout : souche).
const SMALL_PART := 6.0
const SMALL_PART_RANGE := 70.0

# Ombre du modèle détaillé d'un morceau (Trees.own_shadow), sauf (0.0.8.22, perf : les branches couchées doublaient les
# dessins) un petit morceau couché (moins de SMALL_PART m de large) : pas d'ombre (posé au sol, elle se voit à peine),
# dessiné jusqu'à SMALL_PART_RANGE m.
func _part_shadow(tree: Node3D, standing: bool) -> void:
	var model: Node3D = tree.get_node_or_null("Modele")
	if model == null:
		return
	Trees.own_shadow(model)
	var detail: MeshInstance3D = model.get_node_or_null("Detail")
	if standing or detail == null or detail.mesh == null or int(tree.get_meta("part", 0)) == 0:
		return
	if detail.mesh.get_aabb().size.length() * tree.scale.x < SMALL_PART:
		detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		detail.visibility_range_end = SMALL_PART_RANGE
func _show_part(tree: Node3D, standing: bool) -> void:
	_leave_series(tree)
	var cuts := _cuts_of(tree)
	var model: Node3D = tree.get_node_or_null("Modele")
	# 0.0.8.23 : un arbre abattu jamais coupé, mais dont les feuilles sont tombées : son modèle sans feuilles.
	var bare := _stripped(tree)
	if model == null or (cuts.is_empty() and not bare):
		return
	var kind := int(tree.get_meta("kind", 0))
	var size := int(tree.get_meta("size", 3))
	var form := int(tree.get_meta("form", 0))
	var part := int(tree.get_meta("part", 0))
	var detail: MeshInstance3D = model.get_node_or_null("Detail")
	if detail != null:
		detail.mesh = TreeParts.part_mesh(kind, size, form, cuts, part, not bare)
		# Le modèle simplifié de loin montrerait l'arbre entier : le morceau détaillé est gardé plus loin.
		detail.visibility_range_end = Trees.FAR_END
		_part_shadow(tree, standing)
	for name in ["Loin", "Liane"]:
		var other: Node3D = model.get_node_or_null(name)
		if other != null and (name == "Loin" or cuts.any(func(cut): return TreeParts.skeleton(kind, size, form).pieces[int(cut[0])].root)):
			other.visible = false
	for old in model.get_children():
		if old.name.begins_with("Coupe"):
			model.remove_child(old)
			old.queue_free()
	var faces := MeshInstance3D.new()
	faces.name = "Coupe"
	faces.mesh = TreeParts.cut_faces(kind, size, form, cuts, part)
	faces.visibility_range_end = Trees.FAR_END
	# 0.0.8.22 (perf) : les faces coupées (petits disques) ne portent pas d'ombre.
	faces.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(faces)
	var hidden: Array = picked_fruits.get(str(tree.get_meta("id", "")), []) + TreeParts.hidden_fruits(kind, size, form, cuts, part)
	tree.set_meta("fruit_hidden", hidden)
	Trees.apply_picked(tree, hidden)
	_part_collision(tree, standing)

func _part_collision(tree: Node3D, standing: bool) -> void:
	_leave_series(tree)
	var model: Node3D = tree.get_node_or_null("Modele")
	if model == null:
		return
	for child in tree.get_children():
		if child is CollisionShape3D or child.name == "Visee":
			tree.remove_child(child)
			child.free()
	var kind := int(tree.get_meta("kind", 0))
	var size := int(tree.get_meta("size", 3))
	var form := int(tree.get_meta("form", 0))
	var main := TreeParts.main_span(kind, size, form, _cuts_of(tree) if not _cuts_of(tree).is_empty() else [], int(tree.get_meta("part", 0)))
	if main.is_empty():
		return
	var piece: Dictionary = TreeParts.skeleton(kind, size, form).pieces[main[0]]
	var a: Vector3 = piece.start + piece.direction * float(main[1])
	var b: Vector3 = piece.start + piece.direction * float(main[2])
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	if standing and piece.root:
		# Debout : le tronc comme avant (Trees.tree_body), jusqu'à la coupe.
		var foot := Trees.trunk(kind, size)
		shape.radius = foot.x
		shape.height = maxf(minf(foot.y, b.y), 0.05)
		collision.transform = model.transform * Transform3D(Basis.IDENTITY, Vector3(0.0, shape.height * 0.5, 0.0))
	else:
		shape.radius = TreeParts.true_thickness(piece, (float(main[1]) + float(main[2])) * 0.5) * 0.5
		if shape.radius * tree.scale.x < 0.03:
			return
		shape.height = maxf(a.distance_to(b), 0.05)
		var up: Vector3 = piece.direction
		var side: Vector3 = up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
		collision.transform = model.transform * Transform3D(Basis(side, up, side.cross(up)).orthonormalized(), (a + b) * 0.5)
	collision.shape = shape
	tree.add_child(collision)

# Nouveau nœud pour le morceau « part » de cet arbre (même place pour l'instant).
func _part_node(tree: Node3D, part: int) -> Node3D:
	var made := Trees.tree_body(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3)), false, int(tree.get_meta("form", 0)))
	made.set_meta("id", tree.get_meta("id", ""))
	made.set_meta("column", tree.get_meta("column", Vector2i(999999, 0)))
	made.set_meta("part", part)
	tree.get_parent().add_child(made)
	made.global_transform = tree.global_transform
	var column: Vector2i = made.get_meta("column")
	column_objects[column] = column_objects.get(column, []) + [made]
	_show_part(made, false)
	return made

# Arbre couché coupé : le bout détaché écarté de CUT_GAP le long de la pièce coupée et tourné de CUT_TURN autour de la coupe.
func _place_split(tree: Node3D, made: Node3D, number: int, t: float) -> void:
	_leave_series(tree)
	var piece: Dictionary = TreeParts.skeleton(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3)), int(tree.get_meta("form", 0))).pieces[number]
	var at: Vector3 = piece.start + piece.direction * t
	var place := _model_of(tree)
	var pivot: Vector3 = place * at
	var along: Vector3 = (place.basis * piece.direction).normalized()
	var turned := Basis(Vector3.UP, CUT_TURN) * tree.global_basis
	made.global_basis = turned
	var model: Node3D = made.get_node("Modele")
	made.global_position = pivot + along * CUT_GAP - turned * (model.transform * at)
	_rest_rigid(made)
	_bend_into_ground(made, _lying_direction(made))
	_save_part(made)

func _save_part(made: Node3D) -> void:
	var id := str(made.get_meta("id", ""))
	if not tree_cuts.has(id):
		return
	var basis := made.global_basis
	var spot := made.global_position
	tree_cuts[id].morceaux[str(int(made.get_meta("part", 0)))] = {"etat": "couche", "position": [spot.x, spot.y, spot.z], "base": [basis.x.x, basis.x.y, basis.x.z, basis.y.x, basis.y.y, basis.y.z, basis.z.x, basis.z.y, basis.z.z]}
	objects_dirty = true

# 0.0.8.22 (demandes de l'utilisateur) : une branche coupée sur un arbre debout tombe telle qu'elle est : elle part d'où
# elle était, descend en accélérant (comme un objet qui tombe) et se couche en tournant (sa pièce principale à plat,
# dans le sens où elle pointait), puis se pose (_rest_rigid). Elle reste couchée telle quelle, avec ses feuilles, même
# petite ; recoupée, seul le bout coupé change (_cut_to_wood, _lying_bare) ; R la défait en son bois.
const BRANCH_FALL_MIN := 0.25
const BRANCH_FALL_MAX := 1.4

func _drop_branch(tree: Node3D, part: int, number: int, t: float) -> void:
	_leave_series(tree)
	var id := str(tree.get_meta("id", ""))
	var kind := int(tree.get_meta("kind", 0))
	var size := int(tree.get_meta("size", 3))
	var form := int(tree.get_meta("form", 0))
	var made := _part_node(tree, part)
	made.set_meta("falling", true)
	if tree_cuts.has(id):
		tree_cuts[id].morceaux[str(part)] = {"etat": "chute"}
	var pieces: Array = TreeParts.skeleton(kind, size, form).pieces
	var main := TreeParts.main_span(kind, size, form, _cuts_of(made), part)
	var piece: Dictionary = pieces[int(main[0]) if not main.is_empty() else number]
	var middle_t: float = (float(main[1]) + float(main[2])) * 0.5 if not main.is_empty() else t
	var place := _model_of(made)
	var center: Vector3 = place * (piece.start + piece.direction * middle_t)
	var along: Vector3 = (place.basis * piece.direction).normalized()
	var flat := Vector3(along.x, 0.0, along.z)
	if flat.length() < 0.15:
		# Branche presque verticale : elle se couche en s'écartant du tronc.
		flat = center - tree.global_position
		flat.y = 0.0
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var turn := Quaternion(along, flat) if along.dot(flat) > -0.999 else Quaternion(Vector3.UP, PI)
	var radius := TreeParts.true_thickness(piece, middle_t) * tree.scale.x * 0.5
	var end_center := Vector3(center.x, _ground_at(center, made) + radius, center.z)
	var drop_height := maxf(center.y - end_center.y, 0.05)
	var seconds := clampf(sqrt(2.0 * drop_height / 9.8), BRANCH_FALL_MIN, BRANCH_FALL_MAX)
	var start_basis := made.global_basis
	var start_offset := made.global_position - center
	var fall := func(s: float) -> void:
		if not is_instance_valid(made):
			return
		var turned := Basis(Quaternion.IDENTITY.slerp(turn, s))
		made.global_basis = turned * start_basis
		made.global_position = center.lerp(end_center, s * s) + turned * start_offset
	var landed := func() -> void:
		if not is_instance_valid(made):
			return
		made.remove_meta("falling")
		_rest_rigid(made)
		_part_collision(made, false)
		_bend_into_ground(made, flat)
		_impact_sound(made.global_position)
		_save_part(made)
		_branch_hurts(made, part, drop_height)
	var motion := create_tween()
	motion.tween_method(fall, 0.0, 1.0, seconds)
	motion.tween_callback(landed)
	# (le bruit de la coupe : cut_wood ; celui de la chute : à l'arrivée)

# 0.0.8.22 (demande de l'utilisateur) : une branche qui tombe blesse en Survie celui qui est dessous à son arrivée, comme
# un arbre (Health.tree_damage : sa grosseur et l'endroit touché ; ses feuilles et ses branches : un peu), mais une
# branche fine bien moins (en proportion de son épaisseur sous Health.TREE_SMALL, 10 cm). Rend les points perdus.
# Et selon la hauteur de sa chute (« drop », mètres) : rien sous BRANCH_SAFE_DROP (une branche d'un arbre abattu, déjà
# presque au sol), tout dès BRANCH_FULL_DROP.
const BRANCH_SAFE_DROP := 0.3
const BRANCH_FULL_DROP := 1.5

func _branch_hurts(made: Node3D, part: int, drop := BRANCH_FULL_DROP) -> int:
	var height_share := clampf((drop - BRANCH_SAFE_DROP) / (BRANCH_FULL_DROP - BRANCH_SAFE_DROP), 0.0, 1.0)
	if height_share <= 0.0:
		return 0
	if not survival() or not is_instance_valid(player) or death_open or not is_instance_valid(made):
		return 0
	var kind := int(made.get_meta("kind", 0))
	var size := int(made.get_meta("size", 3))
	var form := int(made.get_meta("form", 0))
	var main := TreeParts.main_span(kind, size, form, _cuts_of(made), part)
	if main.is_empty():
		return 0
	var piece: Dictionary = TreeParts.skeleton(kind, size, form).pieces[main[0]]
	var place := _model_of(made)
	var base: Vector3 = place * (piece.start + piece.direction * float(main[1]))
	var tip: Vector3 = place * (piece.start + piece.direction * float(main[2]))
	var direction := tip - base
	direction.y = 0.0
	if direction.length() < 0.05:
		return 0
	var diameter := TreeParts.true_thickness(piece, (float(main[1]) + float(main[2])) * 0.5) * made.scale.x
	var detail: MeshInstance3D = made.get_node_or_null("Modele/Detail")
	var spread := 0.0
	if detail != null and detail.mesh != null:
		var box: AABB = detail.mesh.get_aabb()
		spread = minf(maxf(maxf(box.size.x, box.size.y), box.size.z) * 0.5 * made.scale.x, 2.5)
	var points := Health.tree_damage(base, direction.normalized(), direction.length(), diameter, 0.0, spread, player.global_position)
	if points <= 0:
		return 0
	points = maxi(1, roundi(points * clampf(diameter / Health.TREE_SMALL, 0.05, 1.0) * height_share))
	var lost := hurt(points)
	if lost > 0 and not death_open:
		_notify("Une branche vous est tombée dessus : −%d." % lost)
	return lost

# Le haut d'un arbre (ou une tige) coupé debout tombe vers le joueur depuis la coupe, puis se couche à côté de la souche.
func _fall_part(tree: Node3D, part: int, number: int, t: float) -> void:
	_leave_series(tree)
	var made := _part_node(tree, part)
	made.set_meta("falling", true)
	var piece: Dictionary = TreeParts.skeleton(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3)), int(tree.get_meta("form", 0))).pieces[number]
	var at: Vector3 = piece.start + piece.direction * t
	var model: Node3D = made.get_node("Modele")
	var local: Vector3 = model.transform * at
	var start: Vector3 = _model_of(tree) * at
	var toward := player.global_position - tree.global_position if is_instance_valid(player) else Vector3.FORWARD
	toward.y = 0.0
	var direction := toward.normalized() if toward.length() > 0.05 else Vector3.FORWARD
	var axis := Vector3.UP.cross(direction).normalized()
	var upright: Basis = tree.global_basis
	made.set_meta("upright", upright)
	var radius := TreeParts.true_thickness(piece, t) * tree.scale.x * 0.5
	var beside: Vector3 = tree.global_position + direction * (Trees.trunk(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3))).x * tree.scale.x + 0.15)
	var end := Vector3(beside.x, _ground_at(beside, tree) + radius, beside.z)
	# 0.0.8.2 (#229) : le haut coupé se couche depuis la souche : ce qui reste au-dessus de la coupe blesse aussi.
	var hit := _tree_hit(tree, beside, direction, maxf(start.y - tree.global_position.y, 0.0), radius * 2.0)
	var tilt := func(s: float) -> void:
		if is_instance_valid(made):
			var turned := Basis(axis, s * PI * 0.5) * upright
			made.global_basis = turned
			made.global_position = start.lerp(end, s * s) - turned * local
	var landed := func() -> void:
		_tree_hurts(hit)
		if not is_instance_valid(made):
			return
		made.remove_meta("falling")
		var from: float = (made.global_basis * local).dot(direction)
		_rest_pose(made, direction, maxf(from, 0.0), radius)
		_rest_rigid(made)
		_part_collision(made, false)
		_bend_into_ground(made, direction)
		_save_part(made)
		_bare_to_wood(made)
		_all_wood(str(made.get_meta("id", "")))
	var fall := create_tween()
	fall.tween_method(tilt, 0.0, 1.0, TREE_FALL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_callback(landed)
	tree_cuts[str(tree.get_meta("id", ""))].morceaux[str(part)] = {"etat": "chute"}

# 0.0.7.12 à 0.0.7.14 : un morceau tombé était ensuite soulevé d'un bloc (« posé sur ses branches ») : un bout pouvait
# rester en l'air. 0.0.7.15 : remplacé par de vrais appuis dans _rest_pose (léger : branches ; lourd : tronc).

# Morceau couché presque sans feuilles (_lying_bare) : il devient du bois au sol (jamais une souche debout), dessiné en
# série avec tous les bâtons (léger), à sa vraie taille et à sa place. Vrai s'il l'est devenu.
func _bare_to_wood(tree: Node3D) -> bool:
	if not is_instance_valid(tree) or not _tree_is_lying(tree):
		return false
	if _cuts_of(tree).is_empty() or not _lying_bare(tree):
		return false
	_part_to_wood(tree, int(tree.get_meta("part", 0)))
	return true

# 0.0.8.22 (l'utilisateur, sur un noisetier : « j'ai recassé un petit bout de la branche et le reste de la branche, toutes
# les feuilles ont disparu, et il s'est rapetissé beaucoup ») : avant, tout morceau couché qui portait moins de
# Trees.BARE_LEAF_SHARE (10 %) des feuilles de TOUT l'arbre devenait son bois au sol. Une tige de noisetier en porte à
# peine 10 % du buisson, une branche moins encore : recoupée d'un bout, elle devenait des bâtons posés à plat (plus de
# feuilles, plus de volume) ; une tige qui en portait moins devenait même du bois en tombant.
# 0.0.8.23 (« il faut qu'on enlève nous-mêmes les feuilles ») : un morceau couché qui a des feuilles reste tel qu'il est
# (branche, tige, arbre abattu) jusqu'à ce qu'on les fasse tomber (R, _strip_leaves) ; seul un morceau sans aucune
# feuille devient tout seul son bois (_lying_bare : le pied nu d'un arbre abattu). Ce qu'on coupe d'un morceau couché
# (_cut_to_wood) : une petite branche de côté d'une branche ou d'une tige devient son bois tout de suite (un rameau garde
# ses feuilles) ; coupé dans sa longueur, le bout garde sa forme et ses feuilles, sauf s'il n'est qu'une seule pièce (un
# bâton, un rameau) ou sans feuilles. Sur un arbre abattu, une branche tombe entière (cut_wood). Et quand un morceau
# devient du bois, ses feuilles tombent en tas (_part_to_wood) : aucune ne disparaît.

# Arbre abattu, ou son haut : la pièce principale du morceau est le tronc d'un arbre à un seul tronc (pas une tige de
# noisetier, qui est comme une branche).
func _felled_trunk(tree: Node3D) -> bool:
	var kind := int(tree.get_meta("kind", 0))
	var size := int(tree.get_meta("size", 3))
	var form := int(tree.get_meta("form", 0))
	var main := TreeParts.main_span(kind, size, form, _cuts_of(tree), int(tree.get_meta("part", 0)))
	if main.is_empty():
		return false
	var pieces: Array = TreeParts.skeleton(kind, size, form).pieces
	if int(pieces[main[0]].depth) != 0:
		return false
	return pieces.filter(func(other): return other.root and other.tip.y > 0.5).size() <= 1

# Morceau couché sans aucune feuille (voir plus haut) : il devient son bois tout seul.
func _lying_bare(tree: Node3D) -> bool:
	return _leaf_triangles(tree, int(tree.get_meta("part", 0))) == 0

# Triangles de feuilles du modèle dans un morceau (tombées ou non).
func _leaf_triangles(tree: Node3D, part: int) -> int:
	return int(TreeParts.assignment(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3)), int(tree.get_meta("form", 0)), _cuts_of(tree)).leaves[part])

# Le bout « cut » qu'on vient de couper (sur la pièce « number ») du morceau couché « tree » devient-il tout de suite son
# bois (voir plus haut) ? (Arbre abattu : une branche est déjà tombée entière, cut_wood ; ici une racine ou le tronc.)
func _cut_to_wood(tree: Node3D, cut: int, number: int) -> bool:
	var main := TreeParts.main_span(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3)), int(tree.get_meta("form", 0)), _cuts_of(tree), int(tree.get_meta("part", 0)))
	if main.is_empty() or number != int(main[0]):
		return true
	return _leaf_triangles(tree, cut) == 0 or _part_wood_items(tree, cut).size() <= 1

# --- 0.0.8.23 (demandes de l'utilisateur) : enlever soi-même les feuilles ---
# « Il faut qu'on enlève nous-mêmes les feuilles » ; « d'abord les feuilles tombent et on peut les récupérer avec R » ;
# « elles restent de la même taille » ; « quand le tas a 20 feuilles, un nouveau tas apparaît ». R sur une branche, une
# tige ou un arbre couchés qui ont leurs feuilles : elles tombent au sol en tas (ground_items.gd, Inventory.LEAF_PILE
# feuilles au plus), là où elles étaient ; le morceau reste, nu (tree_cuts[id].nus : ses morceaux nus ; un bout coupé
# d'un morceau nu l'est aussi). R sur un tas : on le ramasse (_pick_leaf_pile) ; R sur le morceau nu : il se défait en
# bois. Une feuille : une plaque du feuillage du modèle (LEAF_TRIANGLES triangles, une image de grappe de feuilles).
const LEAF_TRIANGLES := 2
# Cases (m) pour ranger les feuilles avant de les mettre en tas : un tas reprend des feuilles voisines.
const LEAF_CELL := 0.4

func _part_stripped(id: String, part: int) -> bool:
	for value in tree_cuts.get(id, {}).get("nus", []):
		if int(value) == part:
			return true
	return false

func _stripped(tree: Node3D) -> bool:
	return _part_stripped(str(tree.get_meta("id", "")), int(tree.get_meta("part", 0)))

func _mark_stripped(id: String, part: int) -> void:
	if not tree_cuts.has(id):
		tree_cuts[id] = {"coupes": [], "morceaux": {}, "v": 2}
	var list: Array = tree_cuts[id].get("nus", [])
	if not _part_stripped(id, part):
		list.append(part)
	tree_cuts[id].nus = list
	objects_dirty = true

# Rang d'une case dans une courbe qui serpente (Morton) : des cases voisines se suivent.
static func _morton(cell: Vector2i) -> int:
	var key := 0
	for bit in range(12):
		key |= ((cell.x >> bit) & 1) << (2 * bit)
		key |= ((cell.y >> bit) & 1) << (2 * bit + 1)
	return key

# Les feuilles d'un morceau (sauf celles des pièces de « skip ») tombent au sol en tas de Inventory.LEAF_PILE, là où elles
# étaient. Rend leur nombre.
func _drop_leaves(tree: Node3D, part: int, skip := {}) -> int:
	var kind := int(tree.get_meta("kind", 0))
	var size := int(tree.get_meta("size", 3))
	var form := int(tree.get_meta("form", 0))
	var made: Dictionary = TreeParts.skeleton(kind, size, form)
	var assigned: Dictionary = TreeParts.assignment(kind, size, form, _cuts_of(tree))
	var centers := _leaf_centers(kind, size, form)
	var place := _model_of(tree)
	var points := PackedVector3Array()
	for surface in centers:
		var of: PackedInt32Array = assigned.parts[surface]
		var owners = made.surfaces[surface].owner
		var list: PackedVector3Array = centers[surface]
		for at in range(0, list.size(), LEAF_TRIANGLES):
			if of[at] != part or (not skip.is_empty() and skip.has(int(owners[at]))):
				continue
			points.append(place * list[at])
	if points.is_empty():
		return 0
	var low := Vector2(INF, INF)
	for point in points:
		low = Vector2(minf(low.x, point.x), minf(low.y, point.z))
	var order := []
	for index in range(points.size()):
		order.append([_morton(Vector2i(floori((points[index].x - low.x) / LEAF_CELL), floori((points[index].z - low.y) / LEAF_CELL))), index])
	order.sort_custom(func(a, b): return a[0] < b[0])
	var start := 0
	while start < order.size():
		var end := mini(start + Inventory.LEAF_PILE, order.size())
		var middle := Vector3.ZERO
		for at in range(start, end):
			middle += points[order[at][1]]
		middle /= float(end - start)
		ground.drop({"objet": "feuilles", "essence": clampi(kind, 0, 3), "tas": end - start}, middle, middle, _ground_at.bind(tree), 0.0)
		start = end
	return points.size()

# R sur un morceau couché qui a ses feuilles : elles tombent ; il reste, nu, et se repose (elles ne le portent plus).
func _strip_leaves(tree: Node3D) -> int:
	var part := int(tree.get_meta("part", 0))
	var count := _drop_leaves(tree, part)
	_mark_stripped(str(tree.get_meta("id", "")), part)
	_show_part(tree, false)
	_rest_rigid(tree)
	_bend_into_ground(tree, _lying_direction(tree))
	_save_part(tree)
	return count

# R sur un tas de feuilles : toutes celles qui tiennent (main choisie, l'autre main, les poches…) ; le reste reste en tas.
func _pick_leaf_pile(index: int) -> bool:
	var pile: Dictionary = ground.entries[index].item
	var count := clampi(int(pile.get("tas", 1)), 1, Inventory.LEAF_PILE)
	var leaves := []
	for leaf in range(count):
		leaves.append({"essence": clampi(int(pile.get("essence", 0)), 0, 3)})
	var value := {"objet": "feuilles", "pile": leaves}
	var result := inventory.add_to_selected(value)
	if result.added == 0:
		_notify(_refused_message(result.reason, value))
		return true
	ground.set_pile(index, count - int(result.added))
	show_choice("%s : %d (%s)" % [Inventory.item_name(value), int(result.added), Inventory.format_weight(Inventory.unit_weight(value) * int(result.added))])
	notebook_mark("ramasser")
	if is_instance_valid(player.hand_view):
		player.hand_view.grab()
	return true

# 0.0.8.22 : un morceau couché devient son bois au sol (toutes ses pièces) et disparaît. keep : numéro d'une pièce dont le
# bois n'est pas posé mais rendu ([objet, milieu], pour la prendre en main) ; [] sinon. own_node faux : « tree » est le
# morceau d'où « part » vient d'être coupé (il reste ; « part » n'a jamais eu de nœud à lui).
func _part_to_wood(tree: Node3D, part: int, keep := -1, own_node := true) -> Array:
	var kept := []
	var id := str(tree.get_meta("id", ""))
	var items := _part_wood_items(tree, part)
	# 0.0.8.23 : ses feuilles ne disparaissent pas : elles tombent en tas (un rameau garde les siennes).
	if not _part_stripped(id, part):
		var twigs := {}
		for each in items:
			if each[0].objet == "rameau":
				twigs[int(each[2])] = true
		_drop_leaves(tree, part, twigs)
	for each in items:
		if int(each[2]) == keep and kept.is_empty():
			kept = [each[0], each[1]]
			continue
		ground.drop(each[0], each[1], each[1], _ground_at.bind(tree), 0.0)
	if tree_cuts.has(id):
		tree_cuts[id].morceaux[str(part)] = {"etat": "bois"}
	objects_dirty = true
	if not own_node:
		return kept
	var column: Vector2i = tree.get_meta("column", Vector2i(999999, 0))
	if column_objects.has(column):
		column_objects[column].erase(tree)
	tree.queue_free()
	return kept

# Plus aucun morceau (tout est du bois au sol, et pas de souche) : l'arbre est entièrement coupé.
func _all_wood(id: String) -> void:
	var entry: Dictionary = tree_cuts.get(id, {})
	if entry.is_empty() or not fallen_trees.has(id):
		return
	for part in range(entry.coupes.size() + 1):
		if entry.morceaux.get(str(part), {}).get("etat", "") != "bois":
			return
	cut_trees[id] = true
	fallen_trees.erase(id)
	tree_cuts.erase(id)

# 0.0.8.22 (demandes de l'utilisateur : « le bâton ou la bûche qui tombe est ultra fin, par moments » ; garder la taille
# qu'il avait sur l'arbre) : le bois au sol d'un morceau, c'est TOUTES ses pièces (tronc ou tige, branches, rameaux),
# chacune un bois à sa vraie longueur et à ses vraies épaisseurs, posé là où elle était, dans son sens (gros bout vers
# le pied). Avant : seulement sa pièce principale (une branche de pommier de 8 pièces devenait un seul bâton) ; et les
# tiges et troncs droits étaient mesurés dans une tranche horizontale de TOUT l'arbre, qui prenait parfois l'anneau
# d'une tige ou d'une branche voisine (un bout ultra fin, ou trop gros). Posé par _part_to_wood.

# Rameau : une pièce fine (moins de 4 cm) qui porte des feuilles (au moins RAMEAU_LEAVES triangles de feuilles).
const RAMEAU_LEAVES := 4
const RAMEAU_THICKNESS := 0.04

# Bois de chaque pièce d'un morceau : [objet, milieu (monde), numéro de la pièce], la pièce principale (la plus proche
# du pied) d'abord.
func _part_wood_items(tree: Node3D, part: int) -> Array:
	var kind := int(tree.get_meta("kind", 0))
	var size := int(tree.get_meta("size", 3))
	var form := int(tree.get_meta("form", 0))
	var cuts := _cuts_of(tree)
	var made_skeleton: Dictionary = TreeParts.skeleton(kind, size, form)
	var pieces: Array = made_skeleton.pieces
	var assigned: Dictionary = TreeParts.assignment(kind, size, form, cuts)
	var spans: Dictionary = assigned.ranges[part]
	if spans.is_empty():
		return []
	# Feuilles de chaque pièce dans ce morceau (0.0.8.23 : aucune si elles sont tombées : plus de rameaux).
	var leaves := {}
	var stripped := _part_stripped(str(tree.get_meta("id", "")), part)
	for surface in range(made_skeleton.surfaces.size()):
		var info: Dictionary = made_skeleton.surfaces[surface]
		if not info.leaves or stripped:
			continue
		var of: PackedInt32Array = assigned.parts[surface]
		for triangle in range(of.size()):
			if of[triangle] == part:
				var owner: int = info.owner[triangle]
				leaves[owner] = int(leaves.get(owner, 0)) + 1
	var main := TreeParts.main_span(kind, size, form, cuts, part)
	var order: Array = spans.keys()
	order.sort_custom(func(a, b): return (a == main[0]) if (a == main[0]) != (b == main[0]) else a < b)
	var scale := tree.scale.x
	var place := _model_of(tree)
	var tree_id := str(tree.get_meta("id", ""))
	var result := []
	for number in order:
		var piece: Dictionary = pieces[number]
		var span: Vector2 = spans[number]
		var length: float = (span.y - span.x) * scale
		if length < MIN_WOOD_PIECE:
			continue
		# Les racines (pièces du pied qui ne montent pas) ne font pas de bois : seulement la pièce principale.
		if piece.root and float(piece.tip.y) <= 0.5 and number != main[0]:
			continue
		var ends := wood_ends(piece, span.x, span.y)
		var big := ends.x * scale
		var small := ends.y * scale
		var thickness := maxf(big, small)
		var leafy: bool = int(leaves.get(number, 0)) >= RAMEAU_LEAVES and thickness < RAMEAU_THICKNESS
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(tree_id + "_" + str(part) + "_" + str(number))
		var id: String = "rameau" if leafy else ("tronc" if thickness >= 0.04 else "branche")
		var wood := Inventory.wood_piece(id, kind, (big + small) * 50.0, length, rng, Inventory.tree_wood(tree_id, kind))
		wood.epaisseur = snappedf(thickness * 100.0, 0.1)
		wood.fin = snappedf(maxf(minf(big, small) * 100.0, WOOD_TIP_CM), 0.1)
		# Le gros bout du côté du pied de la pièce (le dessin met le bout fin dans le sens de « rotation »).
		var along: Vector3 = (place.basis * piece.direction).normalized()
		if small > big:
			along = -along
		wood.rotation = atan2(along.x, along.z)
		var middle: Vector3 = place * (piece.start + piece.direction * ((span.x + span.y) * 0.5))
		result.append([wood, middle, number])
	return result

# Bout le plus fin d'un bois (cm) : la pointe d'une tige est presque nulle, le bois dessiné garde au moins ceci.
const WOOD_TIP_CM := 0.5
# Évasement des racines : pas de mesure sous cette hauteur (repère du modèle), comme pour abattre.
const ROOT_FLARE := 0.3

# 0.0.8.22 : épaisseurs (m, repère du modèle) aux deux bouts d'une pièce de « low » à « high » (mètres le long de la
# pièce) : la vraie tranche de SES triangles (TreeParts.true_thickness, jamais celle d'une voisine), mesurée tous les
# 10 % (hors évasement des racines), puis la droite la plus proche de ces mesures, prise à chaque bout : le bois au sol
# (un cône) suit au mieux la pièce. Vector2(bout de départ, bout de fin).
static func wood_ends(piece: Dictionary, low: float, high: float) -> Vector2:
	var xs := []
	var ys := []
	var flared := false
	for step in range(1, 10):
		var share := step / 10.0
		var t := lerpf(low, high, share)
		if piece.root and (piece.start + piece.direction * t).y < ROOT_FLARE:
			flared = true
			continue
		xs.append(share)
		ys.append(true_thickness_at(piece, t))
	if xs.size() < 2:
		# Morceau court tout près du sol : une seule mesure, juste au-dessus de l'évasement.
		var above := low
		if piece.root and absf(piece.direction.y) > 0.01:
			above = clampf((ROOT_FLARE - piece.start.y) / piece.direction.y, low, high)
		var one := true_thickness_at(piece, lerpf(above, high, 0.5) if above < high else high)
		return Vector2(one, one)
	var mean_x := 0.0
	var mean_y := 0.0
	for index in range(xs.size()):
		mean_x += xs[index]
		mean_y += ys[index]
	mean_x /= xs.size()
	mean_y /= ys.size()
	var top := 0.0
	var bottom := 0.0
	for index in range(xs.size()):
		top += (xs[index] - mean_x) * (ys[index] - mean_y)
		bottom += (xs[index] - mean_x) * (xs[index] - mean_x)
	var slope := top / maxf(bottom, 0.000001)
	# Bout dans l'évasement des racines : l'épaisseur juste au-dessus (pas la droite prolongée dans l'évasement).
	var start_share: float = xs[0] if flared else 0.0
	var at_start := mean_y + slope * (start_share - mean_x)
	var at_end := mean_y + slope * (1.0 - mean_x)
	var floor_m := WOOD_TIP_CM / 100.0
	return Vector2(maxf(at_start, floor_m), maxf(at_end, floor_m))

# 0.0.8.22 (gels en recoupant) : vraie épaisseur d'une pièce, lue sur son profil (TreeParts.true_thickness au milieu de
# chacune de ses TRUE_PROFILE_STEPS tranches, jamais tout au bout où la mesure est fausse ; mesuré une fois par pièce du
# modèle et gardé), entre deux mesures en ligne droite.
const TRUE_PROFILE_STEPS := 24

static func true_thickness_at(piece: Dictionary, t: float) -> float:
	var profile: PackedFloat32Array = piece.get("profil_vrai", PackedFloat32Array())
	if profile.is_empty():
		for step in range(TRUE_PROFILE_STEPS):
			profile.append(TreeParts.true_thickness(piece, float(piece.length) * (step + 0.5) / TRUE_PROFILE_STEPS))
		piece["profil_vrai"] = profile
	var at := clampf(t / maxf(float(piece.length), 0.0001) * TRUE_PROFILE_STEPS - 0.5, 0.0, TRUE_PROFILE_STEPS - 1.0)
	var below := mini(floori(at), TRUE_PROFILE_STEPS - 2)
	return lerpf(profile[below], profile[below + 1], at - below)

# Monde rouvert : morceaux d'un arbre coupé par branches (0.0.7.12).
func _restore_parts(tree: Node3D) -> void:
	var id := str(tree.get_meta("id", ""))
	var entry: Dictionary = tree_cuts.get(id, {})
	if entry.is_empty():
		return
	if entry.get("coupes", []).is_empty():
		# 0.0.8.23 : arbre abattu jamais coupé dont les feuilles sont tombées : nu, là où il s'est reposé.
		if fallen_trees.has(id) and _stripped(tree):
			_show_part(tree, false)
			var rest: Dictionary = entry.get("morceaux", {}).get("0", {})
			if rest.get("position") is Array and rest.get("base") is Array:
				var r: Array = rest.base
				tree.global_basis = Basis(Vector3(r[0], r[1], r[2]), Vector3(r[3], r[4], r[5]), Vector3(r[6], r[7], r[8]))
				tree.global_position = Vector3(float(rest.position[0]), float(rest.position[1]), float(rest.position[2]))
			_bend_into_ground(tree, _lying_direction(tree))
		return
	# 0.0.7.16 : sauvegarde d'avant (sans « v ») : les coupes restées vides avec l'ancienne règle sont retirées (morceaux
	# renumérotés) : l'arbre reste tel que le joueur le voyait.
	if int(entry.get("v", 1)) < 2:
		var empty: Array = TreeParts.old_empty_cuts(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3)), int(tree.get_meta("form", 0)), entry.coupes)
		empty.reverse()
		for number in empty:
			entry.coupes.remove_at(number - 1)
			var shifted := {}
			for key in entry.morceaux:
				var part := int(key)
				if part < number:
					shifted[str(part)] = entry.morceaux[key]
				elif part > number:
					shifted[str(part - 1)] = entry.morceaux[key]
			entry.morceaux = shifted
		entry.v = 2
		objects_dirty = true
	var lying := fallen_trees.has(id)
	_show_part(tree, not lying)
	if lying:
		# 0.0.7.15 : sa place après s'être reposé (sinon : celle de sa chute).
		var own: Dictionary = entry.morceaux.get("0", {})
		if own.get("position") is Array and own.get("base") is Array:
			var c: Array = own.base
			tree.global_basis = Basis(Vector3(c[0], c[1], c[2]), Vector3(c[3], c[4], c[5]), Vector3(c[6], c[7], c[8]))
			tree.global_position = Vector3(float(own.position[0]), float(own.position[1]), float(own.position[2]))
		_bend_into_ground(tree, _lying_direction(tree))
	for part in range(1, entry.coupes.size() + 1):
		var saved: Dictionary = entry.morceaux.get(str(part), {})
		if saved.get("etat", "") != "couche" or not (saved.get("position") is Array) or not (saved.get("base") is Array):
			continue
		var made := _part_node(tree, part)
		var b: Array = saved.base
		made.global_basis = Basis(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), Vector3(b[6], b[7], b[8]))
		made.global_position = Vector3(float(saved.position[0]), float(saved.position[1]), float(saved.position[2]))
		_bend_into_ground(made, _lying_direction(made))
	if entry.morceaux.get("0", {}).get("etat", "") == "bois":
		var column: Vector2i = tree.get_meta("column", Vector2i(999999, 0))
		if column_objects.has(column):
			column_objects[column].erase(tree)
		tree.queue_free()

# Tombe vers le joueur, depuis sa base, en accélérant ; puis il se couche (et glisse si la pente est raide).
func fell_tree(tree: Node3D) -> void:
	var toward := player.global_position - tree.global_position
	toward.y = 0.0
	var direction := toward.normalized() if toward.length() > 0.05 else Vector3.FORWARD
	var id := str(tree.get_meta("id", ""))
	fallen_trees[id] = {"direction": [direction.x, direction.z]}
	objects_dirty = true
	_leave_series(tree)
	tree.set_meta("falling", true)
	var upright: Basis = tree.global_basis
	tree.set_meta("upright", upright)
	var axis := Vector3.UP.cross(direction).normalized()
	var lift := _tree_lift(tree)
	var base := tree.global_position
	var hit := _tree_hit(tree, base, direction, 0.0)
	var tilt := func(t: float) -> void:
		if is_instance_valid(tree):
			tree.global_basis = Basis(axis, t * PI * 0.5) * upright
			tree.global_position = base + Vector3.UP * lift * t
	var landed := func() -> void:
		_tree_hurts(hit)
		if is_instance_valid(tree):
			tree.remove_meta("falling")
			_start_slide(tree, direction)
	var fall := create_tween()
	fall.tween_method(tilt, 0.0, 1.0, TREE_FALL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_callback(landed)
	_impact_sound(base)

# 0.0.8.2 (#229, demandes de l'utilisateur) : ce qui tombe blesse en Survie celui qui est dessous à la fin de la chute
# (Health.tree_damage : taille du tronc et endroit touché). cut : hauteur de la coupe (0 : tout l'arbre).
func _tree_hit(tree: Node3D, base: Vector3, direction: Vector3, cut: float, diameter: float = -1.0) -> Dictionary:
	var kind := int(tree.get_meta("kind", 0))
	var size := int(tree.get_meta("size", 3))
	var trunk := Trees.trunk(kind, size) * tree.scale.x
	var box := Trees.mesh(kind, size, false, int(tree.get_meta("form", 0))).get_aabb()
	return {"base": base, "direction": direction, "length": maxf(box.size.y * tree.scale.x - cut, 0.5),
		"diameter": trunk.x if diameter < 0.0 else diameter, "crown_from": maxf(trunk.y - cut, 0.0),
		"crown_radius": maxf(box.size.x, box.size.z) * 0.5 * tree.scale.x}

func _tree_hurts(hit: Dictionary) -> int:
	if not survival() or not is_instance_valid(player) or death_open:
		return 0
	var points := Health.tree_damage(hit.base, hit.direction, hit.length, hit.diameter, hit.crown_from, hit.crown_radius, player.global_position)
	var lost := hurt(points)
	if lost > 0 and not death_open:
		_notify("L'arbre vous est tombé dessus : −%d." % lost)
	return lost

# Le tronc couché repose sur le sol : son centre à la hauteur de son rayon.
func _tree_lift(tree: Node3D) -> float:
	return Trees.trunk(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3))).x * tree.scale.x * 0.5

func _tree_length(tree: Node3D) -> float:
	return Trees.mesh(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3)), false, int(tree.get_meta("form", 0))).get_aabb().size.y * tree.scale.x

# Glissade : sur une pente raide (plus de SLIDE_DEGREES sous le milieu du tronc), l'arbre couché glisse vers le bas,
# en accélérant puis freiné par le frottement ; il s'arrête sur un terrain plus plat ou après SLIDE_MAX_SECONDS.
const SLIDE_DEGREES := 25.0
const SLIDE_MAX_SECONDS := 4.0

func _start_slide(tree: Node3D, direction: Vector3) -> void:
	sliding_trees.append({"tree": tree, "direction": direction, "speed": Vector3.ZERO, "time": 0.0})
	_update_slides(0.0)

func _update_slides(delta: float) -> void:
	for slide in sliding_trees.duplicate():
		var tree: Node3D = slide.tree
		if not is_instance_valid(tree):
			sliding_trees.erase(slide)
			continue
		var middle: Vector3 = tree.global_position + slide.direction * _tree_length(tree) * 0.45
		var step := 0.5
		var gradient := Vector2(terrain.height_at(middle.x + step, middle.z) - terrain.height_at(middle.x - step, middle.z), terrain.height_at(middle.x, middle.z + step) - terrain.height_at(middle.x, middle.z - step)) / (2.0 * step)
		var slope := rad_to_deg(atan(gradient.length()))
		slide.time += delta
		if slope > SLIDE_DEGREES and slide.time < SLIDE_MAX_SECONDS:
			var downhill := Vector3(-gradient.x, 0.0, -gradient.y).normalized()
			var pull := 9.8 * (sin(deg_to_rad(slope)) - 0.45 * cos(deg_to_rad(slope)))
			slide.speed += downhill * pull * delta
		else:
			slide.speed = slide.speed.move_toward(Vector3.ZERO, 6.0 * delta)
		if slide.speed.length() > 0.01 and slide.time < SLIDE_MAX_SECONDS + 1.0:
			var moved: Vector3 = tree.global_position + slide.speed * delta
			moved.y = terrain.height_at(moved.x, moved.z) - 0.05 + _tree_lift(tree)
			tree.global_position = moved
			continue
		sliding_trees.erase(slide)
		_lay_down(tree, slide.direction)

# Arbre couché, arrêté : place gardée, branches et feuilles qui entreraient dans le sol repoussées au-dessus et sur
# les côtés (une seule fois), fruits déplacés avec elles.
func _lay_down(tree: Node3D, direction: Vector3) -> void:
	_rest_pose(tree, direction)
	tree.set_meta("lie_base", tree.global_position)
	_piece_collision(tree, _tree_range(tree))
	var id := str(tree.get_meta("id", ""))
	var place := tree.global_position
	fallen_trees[id] = {"direction": [direction.x, direction.z], "position": [place.x, place.y, place.z], "angle": float(tree.get_meta("lie_angle", PI * 0.5))}
	objects_dirty = true
	_bend_into_ground(tree, direction)

# 0.0.7.9 : hauteur du vrai sol (terrain creusé ou posé, rochers compris) sous un point ; sans collision : le sol d'origine.
func _ground_at(point: Vector3, tree: Node3D = null) -> float:
	var natural := terrain.height_at(point.x, point.z)
	if not is_inside_tree():
		return natural
	var skip := []
	if is_instance_valid(player):
		skip.append(player.get_rid())
	if tree is CollisionObject3D:
		skip.append(tree.get_rid())
	var found := -INF
	# Un rayon pile sur la jointure de deux zones du terrain peut passer par une fente très fine : s'il tombe bien plus
	# bas que le sol d'origine, on mesure aussi 5 cm à côté et on garde le plus haut.
	for shift in [Vector3.ZERO, Vector3(0.05, 0.0, 0.05)]:
		var spot: Vector3 = point + shift
		var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 6.0, spot + Vector3.DOWN * 10.0, 1)
		# Les arbres (debout, couchés, autres morceaux du même arbre) ne sont pas le sol : on passe au travers.
		for attempt in range(4):
			query.exclude = skip
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty():
				break
			if is_instance_valid(hit.collider) and hit.collider.is_in_group("trees"):
				skip.append(hit.rid)
				continue
			found = maxf(found, hit.position.y)
			break
		if found > natural - 0.5:
			break
	if found > natural - 0.5:
		return found
	# Bien plus bas que le sol d'origine : vrai trou creusé, ou zone dont la collision n'est pas encore prête (monde qui
	# s'ouvre). On descend dans les données du terrain (creusé, posé, appuis) jusqu'au premier point plein.
	var top: Vector3i = terrain.point_of(Vector3(point.x, maxf(natural, point.y) + 3.0, point.z))
	var bottom: int = terrain.point_of(Vector3(point.x, maxf(found, natural - 12.0), point.z)).y
	for y in range(top.y, bottom - 1, -1):
		var cell := Vector3i(top.x, y, top.z)
		if terrain.solid(cell):
			# Surface entre ce point plein et celui du dessus (selon leur densité, comme le terrain dessiné).
			var inside: float = terrain.density(cell)
			var above: float = terrain.density(cell + Vector3i.UP)
			var share := clampf(inside / (inside - above), 0.0, 1.0) if inside > 0.0 and above < inside else 1.0
			return maxf(found, (y + share) * terrain.STEP)
	return found if found > -INF else natural

# 0.0.7.9 (demande de l'utilisateur) : un tronc couché est rigide et repose sur ses points d'appui les plus hauts : on mesure
# le sol tout le long, puis on cherche la ligne la plus basse qui reste au-dessus partout (elle passe par deux appuis) ;
# l'arbre est incliné le long de cette ligne. Il ne rentre jamais dans le sol, même si une bosse ou un tas est sous lui.
# 0.0.7.12 : morceau tombé d'une souche : seulement à partir de « from » (m, depuis l'origine du modèle), rayon donné.
func _rest_pose(tree: Node3D, direction: Vector3, from := 0.0, given_radius := -1.0) -> void:
	var upright: Basis = tree.get_meta("upright", tree.global_basis)
	var axis := Vector3.UP.cross(direction).normalized()
	var length := _tree_length(tree) - from
	var base := tree.global_position
	var radius := Trees.wood_thickness(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3)), int(tree.get_meta("form", 0)), Vector3(0.0, 0.3, 0.0)) * tree.scale.x * 0.5
	if given_radius > 0.0:
		radius = given_radius
	var samples := []
	var step := 0.4
	var reach := maxf(length * 0.6, 1.0)
	var distance := 0.0
	while distance <= reach:
		var thickness := radius * (1.0 - 0.6 * distance / reach)
		if from > 0.0:
			samples.append(Vector2(from + distance, _ground_at(base + direction * (from + distance), tree) + thickness))
			distance += step
			continue
		samples.append(Vector2(distance, _ground_at(base + direction * distance, tree) + thickness))
		distance += step
	# 0.0.7.15 (demande de l'utilisateur, physique réelle) : un arbre léger (noisetier, taille 1) repose aussi sur ses
	# branches : il peut rester penché, un bout au sol et l'autre porté par ses branches (les feuilles s'écrasent un peu).
	# Un arbre lourd repose sur son tronc : ses branches du dessous s'écartent sur les côtés (_bend_into_ground).
	if _light_tree(tree):
		samples.append_array(_branch_supports(tree, axis, upright, base, direction))
	# Ligne d'appui : au-dessus de tous les points, la plus basse au tiers du tronc.
	var best_height := -INF
	var best_slope := 0.0
	var best_score := INF
	var candidates := []
	for i in range(samples.size()):
		candidates.append([samples[i].y, 0.0])
		for j in range(i + 1, samples.size()):
			var slope: float = (samples[j].y - samples[i].y) / (samples[j].x - samples[i].x)
			candidates.append([samples[i].y - slope * samples[i].x, slope])
	for candidate in candidates:
		var slope: float = clampf(candidate[1], -1.0, 1.0)
		var start: float = candidate[0]
		var above := true
		for point in samples:
			if point.y > start + slope * point.x + 0.002:
				above = false
				break
		if not above:
			continue
		var score := start + slope * (from + reach * 0.35)
		if score < best_score:
			best_score = score
			best_height = start
			best_slope = slope
	if best_height == -INF:
		best_height = base.y
	# 0.0.7.15 (captures : petit pommier couché, le pied en l'air sur sa couronne) : arbre léger : son bout lourd (le pied,
	# ou le bout coupé) reste au sol ; il ne monte en pente qu'autant que ses branches l'exigent (au plus LIGHT_MAX_SLOPE,
	# environ 20° : au-delà, sous son poids, ses branches plient, _bend_into_ground ; à 45°, il paraissait encore debout).
	if _light_tree(tree) and not samples.is_empty():
		var foot: Vector2 = samples[0]
		for point in samples:
			if absf(point.x - from) < absf(foot.x - from):
				foot = point
		var slope := 0.0
		for point in samples:
			if point.x > foot.x + 0.3:
				slope = maxf(slope, (point.y - foot.y) / (point.x - foot.x))
		best_slope = minf(slope, LIGHT_MAX_SLOPE)
		best_height = foot.y - best_slope * foot.x
	var pitch := atan(best_slope)
	var angle := PI * 0.5 - pitch
	tree.global_basis = Basis(axis, angle) * upright
	# Le pied de l'arbre (axe du tronc) sur la ligne d'appui, déjà à un rayon au-dessus du sol.
	tree.global_position = Vector3(base.x, best_height, base.z)
	tree.set_meta("lie_angle", angle)

# 0.0.8.22 (l'utilisateur : « une tige de noisetier était vraiment dans le sol ; il faut que ce soit réaliste : sur le
# sol, et si des feuilles sont en dessous, qu'il tienne un peu en hauteur selon les feuilles qui le maintiennent ») :
# mesuré : l'axe d'une tige tombée jusqu'à 46 cm sous le sol en pente (11 cm sur le plat), le modèle écrasé contre le sol
# (_bend_into_ground). La pose ne mesurait le sol que sur une ligne partant du pied de l'arbre (pas sous la tige, à côté
# du centre du buisson), et un arbre léger ne penchait pas à plus de 20°.
# Maintenant, un morceau couché repose comme un corps rigide sur ses vrais appuis, mesurés sous lui :
# - son bois (des points tous les REST_WOOD_STEP m le long de chaque pièce, à son vrai rayon) ne passe jamais sous le sol ;
#   les brindilles (moins de THIN_WOOD) plient un peu (THIN_GIVE) ; arbre lourd : seulement sa pièce principale (ses
#   branches s'écartent, _bend_into_ground) ;
# - arbre léger (noisetier, petits arbres) : ses feuilles s'écrasent de LEAF_SQUASH au plus, puis le portent, selon
#   combien il y en a dessous (la médiane des feuilles de chaque tranche : quelques feuilles seules ne le portent pas) ;
# - la ligne d'appui la plus basse sous son centre de masse (il bascule jusqu'à toucher de part et d'autre), pente au plus
#   REST_MAX_SLOPE ; deux passes pour corriger la rotation, puis plus aucun point de bois dans le sol.
const REST_WOOD_STEP := 0.25
const REST_MAX_SLOPE := 1.8
const THIN_WOOD := 0.02
const THIN_GIVE := 0.06
const REST_PASSES := 3
static var _leaf_points: Dictionary = {}

# Centres des triangles de feuilles d'un modèle (repère du modèle), par surface ; gardés.
static func _leaf_centers(kind: int, size: int, form: int) -> Dictionary:
	var key := "%d_%d_%d" % [kind, size, form]
	if _leaf_points.has(key):
		return _leaf_points[key]
	var made: Dictionary = TreeParts.skeleton(kind, size, form)
	var full := Trees.mesh(kind, size, false, form)
	var centers := {}
	for surface in range(made.surfaces.size()):
		if not made.surfaces[surface].leaves or surface >= full.get_surface_count():
			continue
		var arrays := full.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var list := PackedVector3Array()
		list.resize(indices.size() / 3)
		for at in range(0, indices.size() - 2, 3):
			list[at / 3] = (points[indices[at]] + points[indices[at + 1]] + points[indices[at + 2]]) / 3.0
		centers[surface] = list
	_leaf_points[key] = centers
	return centers

func _rest_rigid(node: Node3D) -> void:
	if not is_instance_valid(node) or node.get_node_or_null("Modele") == null:
		return
	_leave_series(node)
	var kind := int(node.get_meta("kind", 0))
	var size := int(node.get_meta("size", 3))
	var form := int(node.get_meta("form", 0))
	var part := int(node.get_meta("part", 0))
	var cuts := _cuts_of(node)
	var made: Dictionary = TreeParts.skeleton(kind, size, form)
	var pieces: Array = made.pieces
	var assigned: Dictionary = TreeParts.assignment(kind, size, form, cuts)
	var spans: Dictionary = assigned.ranges[part]
	var main := TreeParts.main_span(kind, size, form, cuts, part)
	if main.is_empty():
		return
	var light := _light_tree(node)
	var scale := node.scale.x
	var main_piece: Dictionary = pieces[main[0]]
	# 0.0.8.23 : ses feuilles tombées (R) ne le portent plus.
	var leaf_centers := _leaf_centers(kind, size, form) if light and not _stripped(node) else {}
	for attempt in range(REST_PASSES):
		var place := _model_of(node)
		var anchor: Vector3 = place * (main_piece.start + main_piece.direction * float(main[1]))
		var along: Vector3 = place.basis * (main_piece.direction as Vector3)
		along.y = 0.0
		if along.length() < 0.05:
			return
		along = along.normalized()
		var heights := _ground_grid(node)
		# Contraintes par tranche le long du morceau : de combien chaque tranche doit monter (bois : le plus ; feuilles :
		# la médiane), et le centre de masse (bois).
		var wood := {}
		var main_wood := {}
		var leaves := {}
		var mass := 0.0
		var mass_x := 0.0
		for number in spans:
			if not light and number != int(main[0]):
				continue
			var is_main: bool = number == int(main[0])
			var piece: Dictionary = pieces[number]
			var span: Vector2 = spans[number]
			var steps := maxi(1, ceili((span.y - span.x) * scale / REST_WOOD_STEP))
			for step in range(steps + 1):
				var t := lerpf(span.x, span.y, float(step) / steps)
				var radius := true_thickness_at(piece, t) * scale * 0.5
				var p: Vector3 = place * (piece.start + piece.direction * t)
				var x := (p - anchor).dot(along)
				var give := THIN_GIVE if radius * 2.0 < THIN_WOOD else 0.0
				var need: float = _grid_height(heights, p) - (p.y - radius) - give
				var bin := roundi(x / REST_WOOD_STEP)
				wood[bin] = maxf(float(wood.get(bin, -INF)), need)
				if is_main:
					main_wood[bin] = maxf(float(main_wood.get(bin, -INF)), need)
				var weight := radius * radius * (span.y - span.x) * scale / steps
				mass += weight
				mass_x += weight * x
		if light:
			for surface in leaf_centers:
				var of: PackedInt32Array = assigned.parts[surface]
				var list: PackedVector3Array = leaf_centers[surface]
				for at in range(0, list.size(), 2):
					if of[at] != part:
						continue
					var p: Vector3 = place * list[at]
					var bin := roundi((p - anchor).dot(along) / REST_WOOD_STEP)
					if not leaves.has(bin):
						leaves[bin] = []
					leaves[bin].append(_grid_height(heights, p) - p.y - LEAF_SQUASH)
		var needs := {}
		for bin in wood:
			needs[bin] = wood[bin]
		for bin in leaves:
			var list: Array = leaves[bin]
			list.sort()
			var middle: float = list[list.size() / 2]
			needs[bin] = maxf(float(needs.get(bin, -INF)), middle)
		if needs.is_empty() or main_wood.is_empty() or mass <= 0.0:
			return
		var center_x := mass_x / mass
		var all_points := []
		for bin in needs:
			all_points.append(Vector2(bin * REST_WOOD_STEP, needs[bin]))
		var main_points := []
		for bin in main_wood:
			main_points.append(Vector2(bin * REST_WOOD_STEP, main_wood[bin]))
		# Sa pièce principale seule suit le sol, quelle que soit la pente ; ses branches et ses feuilles ne la font pencher
		# que de LIGHT_MAX_SLOPE de plus (au-delà, sous son poids, elles plient : _bend_into_ground).
		var on_wood := _support_line(main_points, center_x)
		var best := _support_line(all_points, center_x)
		var clamped := clampf(best.y, on_wood.y - LIGHT_MAX_SLOPE, on_wood.y + LIGHT_MAX_SLOPE)
		if not is_equal_approx(clamped, best.y):
			var lowest := -INF
			for point in main_points:
				lowest = maxf(lowest, point.y - clamped * point.x)
			best = Vector2(lowest, clamped)
		if absf(best.x) < 0.003 and absf(best.y) < 0.002:
			break
		# Bascule autour d'un axe horizontal en travers du morceau, par son point d'ancrage ; puis la hauteur.
		var hinge := Vector3.UP.cross(along).normalized()
		var angle := atan(best.y)
		var turn := Basis(hinge, angle)
		if (turn * along).y * best.y < 0.0:
			turn = Basis(hinge, -angle)
		if absf(best.y) > 0.0005:
			node.global_transform = Transform3D(turn, anchor - turn * anchor) * node.global_transform
		node.global_position.y += best.x

# Ligne d'appui (hauteur à x = 0, pente) au-dessus de toutes les contraintes (x : le long du morceau, y : de combien il
# doit monter là), la plus basse sous le centre de masse ; pente au plus REST_MAX_SLOPE.
static func _support_line(points: Array, center_x: float) -> Vector2:
	var best := Vector2(INF, 0.0)
	var best_score := INF
	var tries := []
	for i in range(points.size()):
		tries.append(Vector2(points[i].y, 0.0))
		for j in range(i + 1, points.size()):
			if absf(points[j].x - points[i].x) < 0.01:
				continue
			var slope := clampf((points[j].y - points[i].y) / (points[j].x - points[i].x), -REST_MAX_SLOPE, REST_MAX_SLOPE)
			tries.append(Vector2(points[i].y - slope * points[i].x, slope))
	for line in tries:
		var above := true
		for point in points:
			if point.y > line.x + line.y * point.x + 0.002:
				above = false
				break
		if not above:
			continue
		var score: float = line.x + line.y * center_x
		if score < best_score:
			best_score = score
			best = line
	if best.x == INF:
		var highest := -INF
		for point in points:
			highest = maxf(highest, point.y)
		best = Vector2(highest, 0.0)
	return best

# 0.0.7.15 (test d'endurance : morceau couché en l'air après une coupe, il reposait sur des branches parties avec l'autre
# morceau) : un morceau couché se repose après chaque coupe, comme un objet rigide : il descend jusqu'à toucher (tronc,
# branches ; feuilles un peu écrasées ; arbre lourd : ses branches plient davantage), puis bascule autour de ce point
# jusqu'à ce que l'autre côté touche aussi. 0.0.8.22 : remplacé par _rest_rigid (gardé pour les arbres d'avant).
const SETTLE_MAX_TILT := 0.35
const LIGHT_MAX_SLOPE := 0.36

func _settle(node: Node3D) -> void:
	_leave_series(node)
	var detail: MeshInstance3D = node.get_node_or_null("Modele/Detail")
	if detail == null or detail.mesh == null:
		return
	var kind := int(node.get_meta("kind", 0))
	var size := int(node.get_meta("size", 3))
	var form := int(node.get_meta("form", 0))
	var light := _light_tree(node)
	var leaves := Trees.material(kind, "leaves")
	var main := TreeParts.main_span(kind, size, form, _cuts_of(node), int(node.get_meta("part", 0)))
	var model: Node3D = node.get_node("Modele")
	var axis_start := Vector3.ZERO
	var axis_dir := Vector3.UP
	var axis_radius := 0.1
	if not main.is_empty():
		var piece: Dictionary = TreeParts.skeleton(kind, size, form).pieces[main[0]]
		axis_start = piece.start
		axis_dir = piece.direction
		axis_radius = TreeParts.true_thickness(piece, (float(main[1]) + float(main[2])) * 0.5) * 0.5 + 0.05
	var heights := _ground_grid(node)
	var place: Transform3D = detail.global_transform
	var points := []
	for surface in range(detail.mesh.get_surface_count()):
		var is_leaf: bool = detail.mesh.surface_get_material(surface) == leaves
		if is_leaf and not light:
			continue
		var vertices: PackedVector3Array = detail.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for index in range(0, vertices.size(), 2):
			var local: Vector3 = model.transform * vertices[index]
			var on_axis := (local - axis_start).length() if axis_dir == Vector3.ZERO else (local - axis_start - axis_dir * (local - axis_start).dot(axis_dir)).length()
			var trunk_point: bool = not is_leaf and on_axis <= axis_radius
			if not light and not trunk_point:
				continue
			var allow := LEAF_SQUASH if is_leaf else (0.02 if trunk_point else 0.05)
			var at: Vector3 = place * vertices[index]
			points.append([at, at.y - _grid_height(heights, at) + allow, trunk_point])
	if points.is_empty():
		return
	# Comme à la chute (_rest_pose) : le bout lourd (début de sa pièce principale : le bout coupé ou le pied) se pose sur
	# le sol (tronc seulement) ; le morceau ne penche qu'autant que ses appuis plus loin l'exigent (léger : branches et
	# feuilles ; lourd : son tronc seulement, ses branches plient), au plus SETTLE_MAX_TILT.
	var along := (node.global_basis * axis_dir)
	along.y = 0.0
	along = along.normalized() if along.length() > 0.05 else Vector3.FORWARD
	var anchor_world: Vector3 = node.global_transform * (model.transform * (axis_start + axis_dir * (float(main[1]) if not main.is_empty() else 0.0)))
	var lift := -INF
	for point in points:
		if point[2] and ((point[0] as Vector3) - anchor_world).dot(along) < 0.5:
			lift = maxf(lift, -float(point[1]))
	if lift == -INF:
		for point in points:
			lift = maxf(lift, -float(point[1]))
	var slope := -SETTLE_MAX_TILT
	for point in points:
		var x: float = ((point[0] as Vector3) - anchor_world).dot(along)
		if x > 0.3:
			slope = maxf(slope, (-float(point[1]) - lift) / x)
	# Pente finale (la sienne plus le changement) au plus SETTLE_MAX_TILT dans un sens ou dans l'autre.
	var axis_world: Vector3 = node.global_basis * axis_dir
	var current := axis_world.y / maxf(Vector2(axis_world.x, axis_world.z).length(), 0.05)
	slope = clampf(current + slope, -SETTLE_MAX_TILT, SETTLE_MAX_TILT) - current
	# Pente : rotation autour d'un axe horizontal en travers du morceau, au bout lourd ; puis la hauteur.
	var tilt := atan(absf(slope))
	var hinge := Vector3.UP.cross(along).normalized()
	var turn := Basis(hinge, tilt)
	if (turn * along).y * slope < 0.0:
		turn = Basis(hinge, -tilt)
	if absf(slope) > 0.0005:
		node.global_transform = Transform3D(turn, anchor_world - turn * anchor_world) * node.global_transform
	node.global_position.y += lift

# Arbre léger : noisetier ou plus petite taille (ses fines branches le portent).
func _light_tree(tree: Node3D) -> bool:
	return int(tree.get_meta("kind", 0)) == Trees.HAZEL or int(tree.get_meta("size", 3)) <= 1

# Appuis des branches d'un arbre léger couché : pour chaque tranche de 30 cm le long de la chute, la hauteur où doit être
# l'axe pour qu'aucune branche ne rentre dans le sol (feuilles : LEAF_SQUASH de plus, elles s'écrasent).
const LEAF_SQUASH := 0.12

func _branch_supports(tree: Node3D, axis: Vector3, upright: Basis, base: Vector3, direction: Vector3) -> Array:
	_leave_series(tree)
	var model: Node3D = tree.get_node_or_null("Modele")
	var detail: MeshInstance3D = tree.get_node_or_null("Modele/Detail")
	if model == null or detail == null or detail.mesh == null:
		return []
	var lying := Basis(axis, PI * 0.5) * upright
	# 0.0.8.22 : la grille du sol sous la place où il sera couché (pas sous sa pose actuelle).
	var heights := _ground_grid(tree, Transform3D(lying, base) * (model.transform * detail.mesh.get_aabb()))
	var leaves := Trees.material(int(tree.get_meta("kind", 0)), "leaves")
	var bins := {}
	for surface in range(detail.mesh.get_surface_count()):
		var squash := LEAF_SQUASH if detail.mesh.surface_get_material(surface) == leaves else 0.02
		var points: PackedVector3Array = detail.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for index in range(0, points.size(), 2):
			var offset: Vector3 = lying * (model.transform * points[index])
			var along := offset.dot(direction)
			var need: float = _grid_height(heights, base + Vector3(offset.x, 0.0, offset.z)) - offset.y - squash
			var bin := roundi(along / 0.3)
			if not bins.has(bin) or need > bins[bin]:
				bins[bin] = need
	var supports := []
	for bin in bins:
		supports.append(Vector2(bin * 0.3, bins[bin]))
	return supports

func _bend_into_ground(tree: Node3D, direction: Vector3) -> void:
	_leave_series(tree)
	var model: Node3D = tree.get_node_or_null("Modele")
	if model == null:
		return
	var to_world := tree.global_transform * model.transform
	var to_local := to_world.affine_inverse()
	var base := tree.global_position
	var heights := _ground_grid(tree)
	# 0.0.7.15 : arbre lourd : les branches du dessous s'écartent nettement sur les côtés (léger : à peine).
	var spread := 0.15 if _light_tree(tree) else 0.6
	var spread_max := 0.1 if _light_tree(tree) else 0.6
	var push := func(point: Vector3) -> Vector3:
		var world_point: Vector3 = to_world * point
		var ground: float = _grid_height(heights, world_point) + 0.04
		if world_point.y >= ground:
			return point
		var sink := ground - world_point.y
		var side := world_point - base
		side -= direction * side.dot(direction)
		side.y = 0.0
		world_point.y = ground
		if side.length() > 0.01:
			world_point += side.normalized() * minf(sink * spread, spread_max)
		return to_local * world_point
	for part in ["Detail", "Loin"]:
		var shown: MeshInstance3D = model.get_node_or_null(part)
		if shown == null or shown.mesh == null:
			continue
		var bent := ArrayMesh.new()
		for surface in range(shown.mesh.get_surface_count()):
			var arrays: Array = shown.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for index in range(points.size()):
				points[index] = push.call(points[index])
			arrays[Mesh.ARRAY_VERTEX] = points
			bent.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			bent.surface_set_material(surface, shown.mesh.surface_get_material(surface))
		shown.mesh = bent
	_part_shadow(tree, not _tree_is_lying(tree))
	# Fruits : déplacés comme les branches qui les portent.
	var kind := int(tree.get_meta("kind", 0))
	var spots := Trees.fruit_spots(kind, int(tree.get_meta("size", 3)), int(tree.get_meta("form", 0)))
	if not spots.is_empty():
		var moved := []
		for spot in spots:
			moved.append([push.call(spot[0]), spot[1], spot[2], spot[3]])
		tree.set_meta("fruit_spots", moved)
		# 0.0.7.9 : morceau d'arbre coupé : seulement les fruits de ce morceau.
		var hidden: Array = picked_fruits.get(str(tree.get_meta("id", "")), []).duplicate()
		if tree.has_meta("range"):
			var part: Array = tree.get_meta("range")
			for number in range(spots.size()):
				if spots[number][0].y < float(part[0]) or spots[number][0].y >= float(part[1]):
					hidden.append(number)
		# 0.0.7.12 : fruits des autres morceaux (branches et tiges coupées).
		hidden += _part_hidden_fruits(tree)
		tree.set_meta("fruit_hidden", hidden)
		Trees.apply_picked(tree, hidden)

# Hauteurs du sol sous l'arbre couché, tous les 50 cm (peu de calculs, même pour un grand arbre).
# Hauteur du sol tous les 50 cm sous un arbre couché ou un morceau. 0.0.8.22 (à-coups quand un morceau se pose : la
# grille couvrait ± la hauteur de tout l'arbre autour de son pied, 1 400 à 6 000 mesures du sol, 2 ou 3 fois par pose) :
# seulement sous le morceau (sa boîte dans le monde, ou « area »), plus GROUND_GRID_MARGIN.
const GROUND_GRID_MARGIN := 1.0

func _ground_grid(tree: Node3D, area: AABB = AABB()) -> Dictionary:
	var box := area if area.size != Vector3.ZERO else _world_box(tree)
	var center := tree.global_position
	if box.size == Vector3.ZERO:
		var reach := _tree_length(tree) + 3.0
		box = AABB(center - Vector3(reach, 0.0, reach), Vector3(reach * 2.0, 0.0, reach * 2.0))
	var origin := Vector2(box.position.x - GROUND_GRID_MARGIN, box.position.z - GROUND_GRID_MARGIN)
	var columns := int(ceil((box.size.x + GROUND_GRID_MARGIN * 2.0) / 0.5)) + 2
	var rows := int(ceil((box.size.z + GROUND_GRID_MARGIN * 2.0) / 0.5)) + 2
	# 0.0.7.9 : tableau rempli ici puis rangé (un tableau « packed » lu dans un dictionnaire est une copie).
	var values := PackedFloat32Array()
	values.resize(columns * rows)
	for row in range(rows):
		for column in range(columns):
			var at: Vector2 = origin + Vector2(column, row) * 0.5
			values[row * columns + column] = _ground_at(Vector3(at.x, center.y, at.y), tree)
	return {"origin": origin, "step": 0.5, "columns": columns, "rows": rows, "values": values}

# Boîte (monde) du modèle détaillé d'un arbre ou d'un morceau ; vide sans modèle.
func _world_box(tree: Node3D) -> AABB:
	var detail: MeshInstance3D = tree.get_node_or_null("Modele/Detail")
	if detail == null or detail.mesh == null:
		return AABB()
	return detail.global_transform * detail.mesh.get_aabb()

func _grid_height(grid: Dictionary, point: Vector3) -> float:
	var columns: int = grid.columns
	var rows: int = grid.rows
	var local: Vector2 = (Vector2(point.x, point.z) - grid.origin) / grid.step
	var column := clampi(floori(local.x), 0, columns - 2)
	var row := clampi(floori(local.y), 0, rows - 2)
	var fx := clampf(local.x - column, 0.0, 1.0)
	var fz := clampf(local.y - row, 0.0, 1.0)
	var values: PackedFloat32Array = grid.values
	var top := lerpf(values[row * columns + column], values[row * columns + column + 1], fx)
	var bottom := lerpf(values[(row + 1) * columns + column], values[(row + 1) * columns + column + 1], fx)
	return lerpf(top, bottom, fz)

# Arbre déjà tombé (monde rouvert, colonne revue) : couché tout de suite à sa place.
func _restore_fallen(tree: Node3D) -> void:
	var saved: Dictionary = fallen_trees.get(str(tree.get_meta("id", "")), {})
	if saved.is_empty():
		return
	var direction := Vector3(float(saved.direction[0]), 0.0, float(saved.direction[1])).normalized()
	if direction.length() < 0.5:
		direction = Vector3.FORWARD
	var axis := Vector3.UP.cross(direction).normalized()
	tree.set_meta("upright", tree.global_basis)
	var angle := float(saved.get("angle", PI * 0.5))
	tree.set_meta("lie_angle", angle)
	tree.global_basis = Basis(axis, angle) * tree.global_basis
	if saved.has("position"):
		tree.global_position = Vector3(float(saved.position[0]), float(saved.position[1]), float(saved.position[2]))
	else:
		tree.global_position += Vector3.UP * _tree_lift(tree)
	tree.set_meta("lie_base", tree.global_position)
	_piece_collision(tree, _tree_range(tree))
	_bend_into_ground(tree, direction)

# 0.0.7.9 (demande de l'utilisateur) : couper un arbre couché EN DEUX, à l'endroit visé (plan à travers le tronc, à cette
# hauteur du modèle). Chaque morceau garde sa vraie forme et sa taille. Un morceau sans feuilles (bois nu) devient aussitôt
# un tronc ou une branche au sol, à ses dimensions exactes (dessinés en série : léger) ; un morceau avec branches et
# feuilles reste couché à sa place, avec sa forme, et peut être recoupé. Sauvegarde : fallen_trees[id].cuts (hauteurs des
# coupes) et .bois (morceaux déjà devenus du bois) ; les troncs au sol sont des objets au sol comme les autres.
func _tree_range(tree: Node3D) -> Array:
	return tree.get_meta("range", [-1.0, Trees.top(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3)), int(tree.get_meta("form", 0))) + 1.0])

func cut_tree(tree: Node3D, at_world: Vector3) -> void:
	_leave_series(tree)
	var id := str(tree.get_meta("id", ""))
	var kind := int(tree.get_meta("kind", 0))
	var size := int(tree.get_meta("size", 3))
	var form := int(tree.get_meta("form", 0))
	var model: Node3D = tree.get_node_or_null("Modele")
	var to_world: Transform3D = tree.global_transform * (model.transform if model != null else Transform3D.IDENTITY)
	var span := _tree_range(tree)
	var height: float = (to_world.affine_inverse() * at_world).y
	if height <= span[0] + 0.08 or height >= span[1] - 0.08:
		_notify("Trop près du bout pour être coupé là.")
		return
	height = snappedf(height, 0.001)
	var saved: Dictionary = fallen_trees.get(id, {})
	var cuts: Array = saved.get("cuts", [])
	cuts.append(height)
	cuts.sort()
	saved.cuts = cuts
	fallen_trees[id] = saved
	objects_dirty = true
	var node_used := false
	var pieces := 0
	for part in [[span[0], height], [height, span[1]]]:
		# 0.0.7.11 : bois nu = presque sans feuilles (quelques rameaux bas ne suffisent plus à garder le tronc entier).
		if Trees.is_bare_wood(kind, size, form, part[0], part[1]):
			_drop_wood_part(tree, part, to_world)
			var wood: Array = saved.get("bois", [])
			wood.append(part)
			saved.bois = wood
			pieces += 1
		elif not node_used:
			_show_range(tree, part)
			node_used = true
		else:
			_piece_copy(tree, part)
	if not node_used:
		# Ce morceau n'existe plus que sous forme de bois au sol.
		var column: Vector2i = tree.get_meta("column", Vector2i(999999, 0))
		if column_objects.has(column):
			column_objects[column].erase(tree)
		tree.queue_free()
		# Plus aucun morceau feuillu de cet arbre : il est entièrement coupé.
		var bounds: Array = [-1.0] + cuts + [Trees.top(kind, size, form) + 1.0]
		var wood: Array = saved.get("bois", [])
		var left := false
		for index in range(bounds.size() - 1):
			if not wood.any(func(done): return absf(float(done[0]) - float(bounds[index])) < 0.002 and absf(float(done[1]) - float(bounds[index + 1])) < 0.002):
				left = true
		if not left:
			cut_trees[id] = true
			fallen_trees.erase(id)
	_impact_sound(at_world)
	show_choice("Coupé en deux" + (" : bois au sol, à ramasser avec R" if pieces > 0 else ""))

# Morceau de bois nu : un tronc (4 cm d'épaisseur et plus) ou une branche, à ses dimensions exactes, posé à sa place.
func _drop_wood_part(tree: Node3D, part: Array, to_world: Transform3D) -> void:
	var kind := int(tree.get_meta("kind", 0))
	var lo := maxf(float(part[0]), 0.0)
	var hi := minf(float(part[1]), Trees.top(kind, int(tree.get_meta("size", 3)), int(tree.get_meta("form", 0))))
	var scale := tree.scale.x
	var middle := (lo + hi) * 0.5
	# Ses deux vraies épaisseurs (à un cinquième de chaque bout, hors évasement des racines) : gros bout et petit bout ;
	# poids selon leur moyenne.
	var near_end := (hi - lo) * 0.2
	var size := int(tree.get_meta("size", 3))
	var form := int(tree.get_meta("form", 0))
	# 0.0.7.11 : gros bout jamais mesuré sous 30 cm (l'évasement des racines doublait l'épaisseur), comme pour abattre.
	var base_thick := Trees.wood_thickness(kind, size, form, Vector3(0.0, clampf(maxf(lo + near_end, 0.3), lo, hi), 0.0)) * scale
	var end_thick := Trees.wood_thickness(kind, size, form, Vector3(0.0, hi - near_end, 0.0)) * scale
	var thickness := maxf(base_thick, end_thick)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(tree.get_meta("id", "")) + str(part))
	var piece := Inventory.wood_piece("tronc" if thickness >= 0.04 else "branche", kind, (base_thick + end_thick) * 50.0, (hi - lo) * scale, rng, Inventory.tree_wood(str(tree.get_meta("id", "")), kind))
	piece.epaisseur = snappedf(thickness * 100.0, 0.1)
	piece.fin = snappedf(minf(base_thick, end_thick) * 100.0, 0.1)
	var along: Vector3 = (to_world.basis * Vector3.UP).normalized()
	piece.rotation = atan2(along.x, along.z)
	var spot: Vector3 = to_world * Vector3(0.0, middle, 0.0)
	ground.drop(piece, spot + Vector3.UP * 0.2, spot, _ground_at.bind(tree), 0.0)

# N'affiche que le morceau [lo, hi] de cet arbre (modèle découpé, branches au-dessus du sol, collision à sa mesure).
func _show_range(tree: Node3D, part: Array) -> void:
	_leave_series(tree)
	var kind := int(tree.get_meta("kind", 0))
	var size := int(tree.get_meta("size", 3))
	var form := int(tree.get_meta("form", 0))
	tree.set_meta("range", part)
	var model: Node3D = tree.get_node_or_null("Modele")
	if model == null:
		return
	var detail: MeshInstance3D = model.get_node_or_null("Detail")
	var cut_mesh := Trees.mesh_range(kind, size, form, float(part[0]), float(part[1]))
	if detail != null:
		detail.mesh = cut_mesh
		Trees.own_shadow(model)
	var far: Node3D = model.get_node_or_null("Loin")
	if far != null:
		far.visible = false
	# 0.0.7.11 : faces coupées en bois clair aux deux bouts du morceau (tronc, tiges et branches tranchés).
	for old in model.get_children():
		if old.name.begins_with("Coupe"):
			model.remove_child(old)
			old.queue_free()
	var top := Trees.top(kind, size, form)
	for height in [float(part[0]), float(part[1])]:
		if height <= 0.0 or height >= top:
			continue
		var face := MeshInstance3D.new()
		face.name = "Coupe"
		face.mesh = Trees.cut_faces(kind, size, form, height)
		face.visibility_range_end = Trees.detail_end
		model.add_child(face)
	_piece_collision(tree, part)
	# Fente visible : chaque morceau est décalé de CUT_GAP par coupe avant lui, le long du tronc couché ; 0.0.7.11 : et tourné
	# de CUT_TURN par coupe autour de son bout coupé (en perspective, les feuilles cachaient une simple fente : ouverture en V).
	if not tree.has_meta("lie_base"):
		tree.set_meta("lie_base", tree.global_position)
	if not tree.has_meta("lie_basis"):
		tree.set_meta("lie_basis", tree.global_basis)
	var saved: Dictionary = fallen_trees.get(str(tree.get_meta("id", "")), {})
	# Morceau après morceau, depuis le pied : bout du morceau précédent, fente, puis tour.
	var turned: Basis = tree.get_meta("lie_basis")
	var point: Vector3 = tree.get_meta("lie_base")
	var previous := 0.0
	var cuts: Array = saved.get("cuts", []).duplicate()
	cuts.sort()
	for cut in cuts:
		if float(cut) > float(part[0]) + 0.001:
			break
		point += turned * Vector3(0.0, float(cut) - previous, 0.0) + turned.y.normalized() * CUT_GAP
		turned = Basis(Vector3.UP, CUT_TURN) * turned
		previous = float(cut)
	tree.global_basis = turned
	tree.global_position = point - turned * Vector3(0.0, previous, 0.0)
	var direction := Vector3(float(saved.get("direction", [0.0, -1.0])[0]), 0.0, float(saved.get("direction", [0.0, -1.0])[1])).normalized()
	_bend_into_ground(tree, direction)

# Collisions d'un arbre couché ou d'un morceau [lo, hi] : tronc solide, tige de visée pour couper.
func _piece_collision(tree: Node3D, part: Array) -> void:
	_leave_series(tree)
	var kind := int(tree.get_meta("kind", 0))
	var size := int(tree.get_meta("size", 3))
	var form := int(tree.get_meta("form", 0))
	var model: Node3D = tree.get_node_or_null("Modele")
	if model == null:
		return
	for child in tree.get_children():
		if child is CollisionShape3D or child.name == "Visee":
			tree.remove_child(child)
			child.free()
	# 0.0.7.9 : seul le tronc reste solide (comme l'arbre entier couché) ; une tige invisible le long du morceau sert
	# seulement à viser pour recouper (couche 2, comme les objets au sol) : on passe à travers la couronne.
	var foot := Trees.trunk(kind, size)
	var top := minf(float(part[1]), Trees.top(kind, size, form))
	var low := maxf(float(part[0]), 0.0)
	var trunk_end := minf(top, foot.y)
	if trunk_end - low > 0.05:
		var solid := CylinderShape3D.new()
		solid.radius = foot.x
		solid.height = trunk_end - low
		var collision := CollisionShape3D.new()
		collision.shape = solid
		collision.transform = model.transform * Transform3D(Basis.IDENTITY, Vector3(0.0, (low + trunk_end) * 0.5, 0.0))
		tree.add_child(collision)
	if top - low > 0.05:
		var aim := StaticBody3D.new()
		aim.name = "Visee"
		aim.add_to_group("trees")
		aim.set_meta("arbre", tree)
		aim.collision_layer = 2
		aim.collision_mask = 0
		var stem := CylinderShape3D.new()
		stem.radius = maxf(foot.x, 0.12)
		stem.height = top - low
		var aim_shape := CollisionShape3D.new()
		aim_shape.shape = stem
		aim.add_child(aim_shape)
		aim.transform = model.transform * Transform3D(Basis.IDENTITY, Vector3(0.0, (low + top) * 0.5, 0.0))
		tree.add_child(aim)

# Un deuxième morceau feuillu : un nouvel arbre couché à la même place, qui n'affiche que son morceau.
func _piece_copy(tree: Node3D, part: Array) -> Node3D:
	var copy := Trees.tree_body(int(tree.get_meta("kind", 0)), int(tree.get_meta("size", 3)), false, int(tree.get_meta("form", 0)))
	copy.set_meta("id", tree.get_meta("id", ""))
	copy.set_meta("column", tree.get_meta("column", Vector2i(999999, 0)))
	copy.set_meta("upright", tree.get_meta("upright", tree.global_basis))
	copy.set_meta("lie_angle", tree.get_meta("lie_angle", PI * 0.5))
	copy.set_meta("lie_base", tree.get_meta("lie_base", tree.global_position))
	copy.set_meta("lie_basis", tree.get_meta("lie_basis", tree.global_basis))
	tree.get_parent().add_child(copy)
	copy.global_transform = tree.global_transform
	var column: Vector2i = copy.get_meta("column")
	column_objects[column] = column_objects.get(column, []) + [copy]
	_show_range(copy, part)
	return copy

# Morceaux feuillus encore là après des coupes (monde rouvert) : entre deux coupes, sauf ceux devenus du bois.
func _restore_pieces(tree: Node3D) -> void:
	var saved: Dictionary = fallen_trees.get(str(tree.get_meta("id", "")), {})
	var cuts: Array = saved.get("cuts", [])
	if cuts.is_empty():
		return
	var span := _tree_range(tree)
	var bounds: Array = [span[0]] + cuts + [span[1]]
	var wood: Array = saved.get("bois", [])
	var first := true
	for index in range(bounds.size() - 1):
		var part := [float(bounds[index]), float(bounds[index + 1])]
		if wood.any(func(done): return absf(float(done[0]) - part[0]) < 0.002 and absf(float(done[1]) - part[1]) < 0.002):
			continue
		if first:
			_show_range(tree, part)
			first = false
		else:
			_piece_copy(tree, part)

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
	# 0.0.8.9 : pente du sol sous chaque objet (posé à plat sur elle).
	ground.normal_at = _rest_normal
	add_child(ground)
	ground.from_array(objects_data.get("objets_au_sol"))
	ground.changed.connect(func(): objects_dirty = true)
	ground.seed_taken.connect(func(id: String): picked_branches[id] = true)

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


# 0.0.8.9 (bug signalé par l'utilisateur : sur une pente, les objets posés étaient à moitié dans le sol) : la pente du sol
# sous un point (collisions du terrain, sinon le relief de la graine).
func _rest_normal(spot: Vector3) -> Vector3:
	if is_inside_tree():
		var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 1.5, spot + Vector3.DOWN * 6.0, 1)
		if is_instance_valid(player):
			query.exclude = [player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.normal.y > 0.3:
			return hit.normal
	var step := 0.25
	var dx := terrain.height_at(spot.x + step, spot.z) - terrain.height_at(spot.x - step, spot.z)
	var dz := terrain.height_at(spot.x, spot.z + step) - terrain.height_at(spot.x, spot.z - step)
	return Vector3(-dx, 2.0 * step, -dz).normalized()
# Point au sol à côté du joueur (à sa droite, un peu devant) : là où tombent les morceaux.
func _beside_player() -> Vector3:
	var basis := player.global_transform.basis
	return player.global_position + basis.x * 0.6 - basis.z * 0.35

func drop_pieces(id: String, pieces: int, weight: float, from: Vector3) -> void:
	if not is_instance_valid(ground) or not is_instance_valid(player):
		return
	for index in range(pieces):
		# 0.0.8.24 (l'utilisateur : « quand je casse de la pierre avec une pioche, ça ne me fait pas récupérer la pierre ») :
		# en Survie, les éclats vont dans la main choisie (sinon l'autre main, une poche…), comme une récolte ; seulement
		# ce qui ne tient pas tombe à côté du joueur (avant : tout tombait au sol, souvent caché dans l'herbe).
		var piece := {"objet": id, "pile": [{"poids": weight}]}
		if survival() and inventory.add_to_selected(piece).added > 0:
			continue
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

# 0.0.7.29 (demande de l'utilisateur) : Survie, touche Jeter (J) : l'objet en main (un seul, le dernier pris) tombe au sol
# devant soi. 0.0.7.30 (demandes de l'utilisateur) : en Créatif aussi (un objet illimité : une copie tombe, il reste en
# main) ; all (Ctrl + J, 0.0.7.31 : l'un ou l'autre Ctrl) : tout le tas.
func throw_held(all: bool = false) -> bool:
	var value := inventory.held()
	if value.is_empty() or not is_instance_valid(player):
		_notify("Rien en main à jeter.")
		return false
	if not is_instance_valid(ground):
		return false
	var thrown := value.duplicate(true) if Inventory.unlimited(value) else inventory.remove("bar", _held_index(), all)
	if thrown.is_empty():
		return false
	var near := player.global_position - player.global_transform.basis.z * 0.9
	for unit in Inventory.units(thrown):
		ground.drop(unit, player.camera.global_position - player.global_transform.basis.z * 0.3, near, _rest_height, 0.15)
	show_choice("%s jeté au sol" % _thrown_name(thrown))
	notebook_mark("jeter")
	return true

# 0.0.7.30 (demande de l'utilisateur) : Supprimer (D + E), Créatif seulement : l'objet en main disparaît (rien ne tombe).
# 0.0.7.31 (demande de l'utilisateur) : toujours tout le tas ; un objet illimité : la case est vidée.
func delete_held() -> bool:
	if game_mode == Inventory.SURVIVAL:
		_notify("En Survie, on ne supprime rien : J pour jeter au sol.")
		return false
	if inventory.held().is_empty():
		_notify("Rien en main à supprimer.")
		return false
	var gone := inventory.remove("bar", _held_index(), true)
	if gone.is_empty():
		return false
	show_choice("%s supprimé" % _thrown_name(gone))
	return true

# 0.0.7.31 (demande de l'utilisateur) : Détails (D + T) en jeu : l'inventaire s'ouvre sur les détails de l'objet en main.
func show_held_details() -> void:
	if not is_instance_valid(inventory_ui):
		return
	open_inventory()
	inventory_ui.show_held_details()

# Case de l'objet en main (objet lourd à deux mains : sa case).
func _held_index() -> int:
	var index: int = inventory.selected()
	var heavy: int = inventory.two_handed()
	return heavy if heavy >= 0 and index in Inventory.HANDS else index


# --- 0.0.8.10 (#202, demandes de l'utilisateur) : outils utiles et usure (règles : inventory.gd, TOOL_SPEEDS) ---
# L'outil en main (Survie) accélère son travail ; chaque travail fini l'use (Inventory.TOOL_WEAR_PER_SECOND coups par
# seconde de travail) ; à 0 coup, il casse : la tête et le manche tombent au sol.
func held_tool() -> Dictionary:
	if game_mode != Inventory.SURVIVAL:
		return {}
	var there := inventory.item("bar", _held_index())
	if there.is_empty() or not Inventory.is_stone_tool(there):
		return {}
	var units := Inventory.units(there)
	return units[-1] if not units.is_empty() else {}

func tool_speed(work: String) -> float:
	var tool := held_tool()
	return Inventory.tool_speed(tool, work) if not tool.is_empty() else 1.0

# Le plus gros bois qu'on coupe : 40 cm à mains nues ; une hache : jusqu'à 1 m.
func max_chop_thickness() -> float:
	return 1.0 if tool_speed("bois") > 1.0 else MAX_HAND_THICKNESS

func _too_thick_message() -> String:
	return "Trop épais %s : %d cm (%d cm au plus)." % ["pour cette hache" if tool_speed("bois") > 1.0 else "à mains nues", roundi(chop_thickness * 100.0), roundi(max_chop_thickness() * 100.0)]

# Use l'outil en main après un travail de « seconds » s (seulement s'il l'a accéléré) ; rend vrai s'il casse.
func use_tool(work: String, seconds: float) -> bool:
	var tool := held_tool()
	# 0.0.8.24 (demande de l'utilisateur) : en Créatif, les outils ne s'usent pas.
	if tool.is_empty() or Inventory.tool_speed(tool, work) <= 1.0 or not survival():
		return false
	var index := _held_index()
	var there := inventory.item("bar", index).duplicate(true)
	var left := Inventory.tool_left(tool) - maxi(1, roundi(seconds * Inventory.TOOL_WEAR_PER_SECOND))
	if left > 0:
		there.pile[-1].usure = left
		inventory._store().bar[index] = there
		inventory.changed.emit()
		inventory_unsaved = true
		return false
	# Cassé : la tête et le manche (une branche fendue) tombent à ses pieds.
	inventory.take_unit("bar", index)
	var head := {"objet": "tete_hache" if tool.objet == "hache_pierre" else "tete_pioche", "pierre": int(tool.get("pierre", 1)), "taille": int(tool.get("taille", 4))}
	var handle := {"objet": "branche", "fendue": 1}
	for key in ["essence", "age", "souplesse", "epaisseur", "fin", "longueur", "morte"]:
		if tool.has(key):
			handle[key] = tool[key]
	var feet := player.global_position + player.global_transform.basis.x * 0.4 - player.global_transform.basis.z * 0.4
	ground.drop(head, player.camera.global_position, feet, _rest_height, 0.1)
	ground.drop(handle, player.camera.global_position, feet + player.global_transform.basis.x * 0.3, _rest_height, 0.1)
	_impact_sound(player.global_position)
	_notify("%s s'est cassée : la tête et le manche sont au sol." % Inventory.ITEMS[tool.objet].nom)
	notice_time = 4.0
	inventory_unsaved = true
	return true
# « Caillou » ou « Caillou × 3 » (tout un tas).
static func _thrown_name(value: Dictionary) -> String:
	var amount := Inventory.count(value)
	return Inventory.item_name(value) + (" × %d" % amount if amount > 1 else "")

# Objets qui ne tiennent plus dans l'inventaire : posés au sol devant le joueur, jamais perdus (chacun tel qu'il est).
func drop_items(value: Dictionary) -> void:
	if not is_instance_valid(ground) or not is_instance_valid(player):
		return
	var near := player.global_position - player.global_transform.basis.z * 0.6
	for unit in Inventory.units(value):
		ground.drop(unit, player.global_position + Vector3.UP, near, _rest_height)

# Message quand rien n'a pu être pris (inventory.add_to_selected).
func _refused_message(reason: String, value: Dictionary) -> String:
	match reason:
		"occupee":
			return "Case choisie occupée : choisissez une case vide (molette ou chiffres)."
		"lourd":
			return "Trop lourd (%s) : 4 kg par main, 8 kg à deux mains, 1 kg dans les poches." % Inventory.format_weight(Inventory.unit_weight(value))
		# 0.0.7.19 : volume et nombre.
		"encombrant":
			var first: Dictionary = value.pile[-1] if value.has("pile") and not value.pile.is_empty() else value
			return "Trop encombrant (%s) : 1,5 L par main, 3 L à deux mains, 0,5 L dans les poches." % Inventory.format_volume(Inventory.instance_volume(value.get("objet", ""), first))
		"nombre":
			return Inventory.count_rule(value)
		# 0.0.8.21 (#207) : ce qui passe entre les mailles du sac.
		"mailles":
			return "%s passe entre les mailles du sac : gardez-le en main ou en poche." % Inventory.item_name(value)
	return "Inventaire plein." if game_mode == Inventory.CREATIVE else ("Mains, poches et sacs pleins." if inventory.bag_worn(0) else "Mains et poches pleines.")

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
				var spots: Array = tree.get_meta("fruit_spots", Trees.fruit_spots(tree.get_meta("kind"), tree.get_meta("size"), tree.get_meta("form")))
				if spots.is_empty():
					continue
				var picked: Array = picked_fruits.get(str(tree.get_meta("id", "")), []) + tree.get_meta("fruit_hidden", [])
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
	# 0.0.7.12 : sans faire revenir les fruits des autres morceaux de l'arbre.
	Trees.apply_picked(tree, picked + tree.get_meta("fruit_hidden", []))
	var name: String = ("Pomme " + Inventory.APPLE_COLOR_NAMES[int(spot[3])]) if apple else "Noisette"
	show_choice("%s (%s)" % [name, Inventory.format_weight(Inventory.unit_weight(value))])
	return true

# R : ramasser l'objet visé (objet au sol ou petit caillou du monde), avec toutes ses caractéristiques.
# 0.0.7.5 (demande de l'utilisateur) : dans la case choisie de la barre ; barre pleine : dans une case libre de l'inventaire.
# Faux si rien n'est visé (R garde alors son autre usage : courir).
# 0.0.7.5 : aussi cueillir une pomme ou une noisette, seulement si la visée passe vraiment par elle.
# 0.0.8.15 (#238, demande de l'utilisateur) : clic de la molette sur un objet au sol (ou un caillou, un fruit). Survie :
# comme Ramasser (main, sinon l'autre main ou les poches, s'il reste de la place). Créatif : toujours dans la case choisie
# de la barre, même si on n'a pas cet objet ; ce qui y était va dans la première case libre de la grille.
func pick_aimed(hit: Dictionary) -> bool:
	if game_mode != Inventory.CREATIVE:
		return pick_up(hit)
	var chosen := inventory.selected()
	var before := inventory.take("bar", chosen)
	var took := pick_up(hit)
	if inventory.item("bar", chosen).is_empty():
		# 0.0.8.19 (signalé par l'utilisateur : la molette ne faisait rien en visant le sol) : en Créatif, aussi ce qu'on vise
		# dans le monde : la matière du sol (ou une motte sur l'herbe), une plante, un tronc d'arbre, la pierre d'un rocher.
		var copy := aimed_copy(hit)
		if copy.is_empty():
			# Rien pris (rien visé, trop loin) : la case reprend son objet.
			inventory.put("bar", chosen, before)
			return took
		inventory.put("bar", chosen, copy)
		show_choice(Inventory.item_name(copy))
	if not before.is_empty() and not Inventory.unlimited(before):
		for index in range(Inventory.GRID_SIZE):
			if inventory.usable("grid", index) and inventory.item("grid", index).is_empty():
				inventory.put("grid", index, before)
				break
	return true

# 0.0.8.19 : en Créatif, ce que vise la molette dans le monde (objet du catalogue, illimité) ; {} si rien.
# --- 0.0.8.25 (#140) : affichage de ce qu'on regarde ---
# En haut au centre, le nom de ce qu'on vise à portée : arbre (et sa pièce, couché, sans feuilles), objet au sol (tas de
# feuilles : combien), caillou, rocher, plante, matière du sol. Recalculé LOOKED_EVERY s (léger : une visée par fois).
const LOOKED_EVERY := 0.15

func _update_looked(delta: float) -> void:
	if not is_instance_valid(looked_label):
		return
	_looked_wait -= delta
	if _looked_wait > 0.0:
		return
	_looked_wait = LOOKED_EVERY
	var busy: bool = inventory_open or crafting_open or notebook_open or death_open or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	looked_label.text = "" if busy else looked_text(player.get_target())

func looked_text(hit: Dictionary) -> String:
	if not is_instance_valid(player):
		return ""
	var wood := aimed_wood(hit)
	if not wood.is_empty():
		var tree: Node3D = wood.tree
		var kind := int(tree.get_meta("kind", 0))
		var piece: Dictionary = TreeParts.skeleton(kind, int(tree.get_meta("size", 3)), int(tree.get_meta("form", 0))).pieces[int(wood.piece)]
		var name: String = Trees.KIND_NAMES[clampi(kind, 0, 3)].capitalize()
		var what := ("tige" if kind == Trees.HAZEL else "tronc") if piece.root else "branche"
		var state := ""
		if _tree_is_lying(tree):
			state = ", couché" + (", sans feuilles" if _stripped(tree) else "")
		return "%s (%s%s)" % [name, what, state]
	if hit.is_empty() or not is_instance_valid(hit.get("collider")):
		return ""
	if player.camera.global_position.distance_to(hit.position) > player.break_reach + 0.01:
		return ""
	var collider: Node = hit.collider
	if collider.is_in_group("ground_items"):
		var index: int = ground.index_of(collider)
		if index < 0:
			return ""
		var item: Dictionary = ground.entries[index].item
		if item.get("objet", "") == "feuilles":
			return "%s (%d)" % [Inventory.item_name(item), int(item.get("tas", 1))]
		return Inventory.item_name(item)
	if collider.is_in_group("pebbles"):
		return "Caillou"
	if collider.is_in_group("rocks"):
		return "Rocher"
	var copy := aimed_copy(hit)
	return Inventory.item_name(copy) if not copy.is_empty() else ""

func aimed_copy(hit: Dictionary) -> Dictionary:
	if hit.is_empty() or not is_instance_valid(hit.get("collider")) or not is_instance_valid(player):
		return {}
	if player.camera.global_position.distance_to(hit.position) > player.break_reach + 0.01:
		return {}
	var plant := aimed_plant(hit)
	if not plant.is_empty():
		return Inventory.catalog_item(PLANT_ITEMS[clampi(int(plant.plant.plante), 0, 2)])
	var collider: Node = hit.collider
	if collider.is_in_group("trees") and collider.has_meta("kind"):
		return Inventory.catalog_item("tronc:%d" % clampi(int(collider.get_meta("kind")), 0, 3))
	if collider.is_in_group("rocks"):
		return Inventory.catalog_item("pierre")
	if not collider.is_in_group("ground"):
		return {}
	if not aimed_grass(hit).is_empty():
		return Inventory.catalog_item(TURF_ITEM)
	var point := SmoothTerrain.point_of(hit.position - hit.normal * 0.3)
	var kind: int = terrain.materials.get(point, terrain.natural_kind(point))
	var id: String = {SmoothTerrain.SAND: "sable", SmoothTerrain.DIRT: "terre", SmoothTerrain.CLAY: "argile", SmoothTerrain.MUD: "boue", SmoothTerrain.GRAVEL: "gravier", SmoothTerrain.NEEDLES: "terre", SmoothTerrain.STONE: "pierre", SmoothTerrain.LIMESTONE: "calcaire", SmoothTerrain.DARK_STONE: "pierre_sombre", SmoothTerrain.FLINT: "silex"}.get(kind if kind >= 0 else SmoothTerrain.DIRT, "")
	return Inventory.catalog_item(id) if not id.is_empty() else {}

# 0.0.8.22 (demande de l'utilisateur) : R sur une branche ou une tige de noisetier couchée : elle se défait en ses bois au
# sol, pièce par pièce, et celui qu'on vise vient en main (main choisie, sinon l'autre main ou une poche), s'il n'est pas
# trop lourd ; sinon il reste au sol. 0.0.8.23 : d'abord ses feuilles tombent en tas (_strip_leaves, à ramasser avec R),
# le R suivant la défait ; un arbre abattu aussi (sa bûche reste au sol si elle est trop lourde). Faux si ce n'est pas
# un morceau couché.
func _pick_lying_wood(hit: Dictionary) -> bool:
	var node: Node3D = hit.collider.get_meta("arbre", hit.collider)
	if not is_instance_valid(node) or not node.has_meta("kind") or not _tree_is_lying(node) or node.has_meta("falling") or _legacy_cut(node):
		return false
	if player.camera.global_position.distance_to(hit.position) > player.break_reach + 0.01:
		_notify("Trop loin : %s m au plus." % str(snappedf(player.break_reach, 0.1)).replace(".", ","))
		return true
	var kind := int(node.get_meta("kind", 0))
	var size := int(node.get_meta("size", 3))
	var form := int(node.get_meta("form", 0))
	var part := int(node.get_meta("part", 0))
	var cuts := _cuts_of(node)
	var id := str(node.get_meta("id", ""))
	if not _stripped(node) and _leaf_triangles(node, part) > 0:
		var fallen := _strip_leaves(node)
		show_choice("%d feuilles tombées : ramassez-les avec R" % fallen)
		if is_instance_valid(player.hand_view):
			player.hand_view.grab()
		return true
	var local: Vector3 = _model_of(node).affine_inverse() * (hit.position as Vector3)
	var aimed := TreeParts.nearest_in_part(kind, size, form, cuts, part, local, 0.8)
	# Un arbre abattu jamais coupé : noté, pour qu'il soit bien fini une fois tout en bois (_all_wood).
	if not tree_cuts.has(id):
		tree_cuts[id] = {"coupes": [], "morceaux": {}, "v": 2}
	var kept := _part_to_wood(node, part, int(aimed.get("piece", -1)))
	_all_wood(id)
	if kept.is_empty():
		show_choice("Bois au sol : à ramasser avec R")
		return true
	var value := Inventory.single(kept[0])
	var result := inventory.add_to_selected(value)
	if result.added == 0:
		ground.drop(kept[0], kept[1], kept[1], _ground_at, 0.0)
		_notify(_refused_message(result.reason, value))
		return true
	show_choice("%s (%s)" % [Inventory.item_name(value), Inventory.format_weight(Inventory.unit_weight(value))])
	notebook_mark("ramasser")
	if is_instance_valid(player.hand_view):
		player.hand_view.grab()
	return true

func pick_up(hit: Dictionary) -> bool:
	var fruit := aimed_fruit(hit)
	if not fruit.is_empty():
		return _pick_fruit(fruit)
	# 0.0.8.23 : une branche, une tige ou un arbre couchés se visent comme pour les couper (aimed_wood : brindilles
	# comprises) ; avant, seulement par leur collision (leur pièce principale, et rien sous 6 cm d'épaisseur).
	var wood := aimed_wood(hit)
	if not wood.is_empty() and _tree_is_lying(wood.tree):
		return _pick_lying_wood({"collider": wood.tree, "position": wood.point})
	if hit.is_empty() or not is_instance_valid(hit.get("collider")):
		return false
	var collider: Node = hit.collider
	# 0.0.8.22 (demande de l'utilisateur) : une branche couchée (tombée d'un arbre) se ramasse aussi.
	if collider.is_in_group("trees"):
		return _pick_lying_wood(hit)
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
		# 0.0.8.23 : un tas de feuilles : toutes celles qui tiennent.
		if ground.entries[index].item.get("objet", "") == "feuilles":
			return _pick_leaf_pile(index)
		value = Inventory.single(ground.entries[index].item)
		value.erase("graine")
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
	notebook_mark("ramasser")
	# 0.0.8.17 (#224) : la main s'avance et attrape.
	if is_instance_valid(player.hand_view):
		player.hand_view.grab()
	return true

# --- 0.0.8.4 (#213, demandes de l'utilisateur) : récolter des fibres et des lianes ---
# R maintenu (Ramasser) Fibers.HARVEST_SECONDS en visant une ortie, du lin ou des herbes longues : 1 à 3 fibres (même
# graine : même nombre), la plante reste coupée (tige basse) ; en visant le tronc d'un tilleul à liane : une liane, qui
# disparaît du tronc. Dans la case choisie (comme ramasser) ; ce qui ne tient pas tombe au sol devant soi.
var cut_plants: Dictionary = {}
var cut_vines: Dictionary = {}
var harvest_key := ""
var harvest_time := 0.0
# 0.0.8.9 : R vient de ramasser un objet : pas de récolte avant de le relâcher.
var harvest_block := false

# Plante à fibres visée (cylindre autour de la plante, à portée de casse, rien de solide devant) : {} si aucune.
func aimed_plant(hit: Dictionary) -> Dictionary:
	if not is_instance_valid(player):
		return {}
	var origin: Vector3 = player.camera.global_position
	var direction: Vector3 = -player.camera.global_transform.basis.z
	var reach: float = player.break_reach
	if not hit.is_empty():
		reach = minf(reach, origin.distance_to(hit.position) + 0.15)
	var best := {}
	var here := _player_column()
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var column: Vector2i = here + Vector2i(dx, dz)
			for plant: Dictionary in plants_near(column):
				var id := Fibers.plant_id(plant)
				if cut_plants.has(id):
					continue
				var size: float = Plants.SIZES[int(plant.plante)] * float(plant.taille)
				var foot := Vector3(float(plant.x), terrain.height_at(float(plant.x), float(plant.z)) - 0.15, float(plant.z))
				# 0.0.8.4 (demande de l'utilisateur : sous certains angles, rien n'était récolté) : le regard doit passer près de
				# la tige (segment vertical du pied à AIM_HEIGHT de sa hauteur), sous n'importe quel angle, même de haut.
				var near := _ray_to_stem(origin, direction, reach, foot, size * Fibers.AIM_HEIGHT + 0.15)
				if near.is_empty() or near.gap > size * Fibers.AIM_RADIUS:
					continue
				if best.is_empty() or near.distance < best.distance:
					best = {"kind": "plante", "key": "plante/" + id, "id": id, "plant": plant, "column": column, "distance": near.distance}
	return best

# Plus courte distance entre le regard (de 0 à reach) et une tige verticale (pied, hauteur) : {gap, distance le long du
# regard}, ou {} si la tige est trop loin.
static func _ray_to_stem(origin: Vector3, direction: Vector3, reach: float, foot: Vector3, height: float) -> Dictionary:
	var w := origin - foot
	var b := direction.y
	var d := direction.dot(w)
	var e := w.y
	var denominator := 1.0 - b * b
	var t := 0.0
	var s := 0.0
	if denominator > 0.000001:
		t = (b * e - d) / denominator
	t = clampf(t, 0.0, reach)
	s = clampf(e + b * t, 0.0, height)
	# Recalcul du point du regard le plus proche du point de la tige trouvé.
	t = clampf((foot + Vector3.UP * s - origin).dot(direction), 0.0, reach)
	s = clampf(e + b * t, 0.0, height)
	var gap := (origin + direction * t).distance_to(foot + Vector3.UP * s)
	return {"gap": gap, "distance": t}

# Ce que R maintenu récolte : la plante visée, ou la liane du tilleul visé (la plus proche).
func aimed_harvest(hit: Dictionary) -> Dictionary:
	var plant := aimed_plant(hit)
	if not hit.is_empty() and is_instance_valid(hit.get("collider")):
		var tree: Node = hit.collider
		if tree.is_in_group("trees") and tree.get_meta("liane", false) == true and not tree.has_meta("falling") and not fallen_trees.has(str(tree.get_meta("id", ""))):
			var distance: float = player.camera.global_position.distance_to(hit.position)
			if distance <= player.break_reach + 0.01 and (plant.is_empty() or distance < plant.distance):
				return {"kind": "liane", "key": "liane/" + str(tree.get_meta("id", "")), "tree": tree, "distance": distance}
	if plant.is_empty():
		return aimed_grass(hit)
	return plant

# 0.0.8.8 : l'herbe du sol visée (terre herbeuse, à portée, pas encore arrachée) : {} sinon.
func aimed_grass(hit: Dictionary) -> Dictionary:
	if hit.is_empty() or not is_instance_valid(hit.get("collider")) or not is_instance_valid(player):
		return {}
	var collider: Node = hit.collider
	if collider.is_in_group("trees") or collider.is_in_group("ground_items") or collider.is_in_group("pebbles") or collider.is_in_group("rocks"):
		return {}
	var at: Vector3 = hit.position
	if player.camera.global_position.distance_to(at) > player.break_reach + 0.01 or hit.normal.y < 0.5:
		return {}
	# 0.0.8.9 (bug signalé par l'utilisateur : R n'arrachait rien) : le sol herbeux d'origine n'a pas de matière (-1).
	if _grass_skipped(at) or not ground_kind_under(at + Vector3.UP * 0.3) in [-1, SmoothTerrain.DIRT] or water_surface(Vector2(at.x, at.z)) > at.y + 0.05:
		return {}
	var cell := Vector2i(roundi(at.x / SmoothTerrain.STEP), roundi(at.z / SmoothTerrain.STEP))
	return {"kind": "herbe", "key": "herbe/%d:%d" % [cell.x, cell.y], "point": at, "distance": player.camera.global_position.distance_to(at)}

const FLAKE_TIP := "Conseil : avec un éclat tranchant en main, on récolte deux fois plus vite (O + F → Tailler → Éclat tranchant)."
const FLAKE_TIP_EVERY_MS := 60000
var flake_tip_at := -FLAKE_TIP_EVERY_MS

func step_harvest(delta: float, holding: bool) -> bool:
	if not holding:
		harvest_block = false
	if harvest_block:
		return false
	if not holding or not is_instance_valid(player):
		_harvest_stop()
		return false
	var target := aimed_harvest(player.get_target())
	if target.is_empty():
		_harvest_stop()
		return false
	# 0.0.8.4 (demande de l'utilisateur : le lin, en touffes serrées, ne se récoltait presque jamais) : passer d'une plante à
	# une autre en visant ne remet pas le temps à zéro (seulement de plante à liane, ou en ne visant plus rien).
	if target.kind != harvest_key.get_slice("/", 0):
		harvest_key = target.key
		harvest_time = 0.0
	harvest_time += delta
	var seconds := Fibers.HARVEST_SECONDS_CREATIVE if game_mode == Inventory.CREATIVE else (Fibers.HARVEST_SECONDS_FLAKE if holding_flake() else Fibers.HARVEST_SECONDS)
	if target.kind == "herbe":
		seconds = minf(seconds, Fibers.GRASS_SECONDS)
	# 0.0.8.21 (demande de l'utilisateur) : à mains nues, un petit conseil (au plus une fois par minute) : l'éclat tranchant
	# récolte deux fois plus vite.
	elif harvest_time <= delta and game_mode == Inventory.SURVIVAL and not holding_flake() and Time.get_ticks_msec() - flake_tip_at > FLAKE_TIP_EVERY_MS:
		flake_tip_at = Time.get_ticks_msec()
		_notify(FLAKE_TIP)
	show_ring(harvest_time / seconds)
	# 0.0.8.4 (demande de l'utilisateur) : la main droite saisit la plante (ou la liane) et tire par petits coups.
	if is_instance_valid(player.hand_view):
		player.hand_view.pull(harvest_time / seconds, harvest_time)
	if harvest_time < seconds:
		return false
	_harvest_stop()
	return harvest(target)

func _harvest_stop() -> void:
	harvest_key = ""
	harvest_time = 0.0
	if is_instance_valid(player) and is_instance_valid(player.hand_view):
		player.hand_view.pull(0.0, 0.0)


# 0.0.8.8 (demande de l'utilisateur) : arracher l'herbe autour du point visé (Fibers.GRASS_RADIUS) ; l'herbe arrachée
# tombe là, au sol (ramassable). Enregistré dans objets.json (« herbe_arrachee » : cases de 50 cm).
var pulled_grass: Dictionary = {}

# 0.0.8.15 : l'herbe enlevée (grow faux) ou qui repousse (vrai : gazon posé, même sur un sol creusé) autour de at.
func _set_grass(at: Vector3, grow: bool) -> void:
	var reach := ceili(Fibers.GRASS_RADIUS / SmoothTerrain.STEP)
	var center := Vector2i(roundi(at.x / SmoothTerrain.STEP), roundi(at.z / SmoothTerrain.STEP))
	var tiles := {}
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var cell := center + Vector2i(dx, dz)
			if (Vector2(cell) * SmoothTerrain.STEP).distance_to(Vector2(at.x, at.z)) > Fibers.GRASS_RADIUS:
				continue
			if grow:
				pulled_grass.erase(cell)
				turf_cells[cell] = true
			else:
				pulled_grass[cell] = true
				turf_cells.erase(cell)
			tiles[Vector2i(floori(cell.x * SmoothTerrain.STEP / SmoothTerrain.ZONE_SIZE), floori(cell.y * SmoothTerrain.STEP / SmoothTerrain.ZONE_SIZE))] = true
	for tile in tiles:
		if lawn_tiles.has(tile):
			_rebuild_lawn_tile(tile)
	objects_dirty = true

func pull_grass(at: Vector3, collect: bool = false) -> bool:
	# Ramassée (mode « récupérer des objets ») : dans la case choisie ; sinon (ou si elle ne tient pas) : au sol.
	_set_grass(at, false)
	var picked := 0
	if collect:
		picked = int(inventory.add_to_selected({"objet": Fibers.GRASS_ITEM, "pile": [{}]}).added)
	if picked == 0 and is_instance_valid(ground):
		ground.drop({"objet": Fibers.GRASS_ITEM}, at + Vector3.UP * 0.25, at, _rest_height, 0.0)
	objects_dirty = true
	show_choice("Herbe arrachée")
	return true

# 0.0.8.9 (demande de l'utilisateur) : clic gauche maintenu sur l'herbe, modes « casser / arracher » (l'herbe arrachée
# reste au sol) et « casser / récupérer des objets » (elle est ramassée) : Fibers.GRASS_SECONDS, la main tire.
var weed_time := 0.0

func step_weed(delta: float, holding: bool) -> bool:
	if not holding or not is_instance_valid(player) or not player.left_mode in [1, 3]:
		if weed_time > 0.0 and is_instance_valid(player) and is_instance_valid(player.hand_view):
			player.hand_view.pull(0.0, 0.0)
		weed_time = 0.0
		return false
	# 0.0.8.15 (#239) : une plante visée s'arrache entière (avant l'herbe du sol).
	var hit: Dictionary = player.get_target()
	var target := aimed_plant(hit)
	if target.is_empty():
		target = aimed_grass(hit)
	if target.is_empty():
		weed_time = 0.0
		return false
	weed_time += delta
	var seconds := Fibers.HARVEST_SECONDS_CREATIVE if game_mode == Inventory.CREATIVE else (PULL_PLANT_SECONDS if target.kind == "plante" else Fibers.GRASS_SECONDS)
	show_ring(weed_time / seconds)
	if is_instance_valid(player.hand_view):
		player.hand_view.pull(weed_time / seconds, weed_time)
	if weed_time < seconds:
		return false
	weed_time = 0.0
	if is_instance_valid(player.hand_view):
		player.hand_view.pull(0.0, 0.0)
	if target.kind == "plante":
		return pull_plant(target, player.left_mode == 1)
	return pull_grass(target.point, player.left_mode == 1)
# 0.0.8.8 : un éclat tranchant dans une main (récolte plus rapide ; les orties piquent moins).
func holding_flake() -> bool:
	for index in Inventory.HANDS:
		var there := inventory.item("bar", index)
		if not there.is_empty() and Inventory.ITEMS.get(there.objet, {}).get("forme", "") == "eclat" and there.objet != "charbon":
			return true
	return false

func harvest(target: Dictionary) -> bool:
	if target.kind == "herbe":
		return pull_grass(target.point)
	var value := {}
	if target.kind == "plante":
		var plant: Dictionary = target.plant
		value = {"objet": Fibers.PLANT_ITEMS[int(plant.plante)], "pile": []}
		for index in range(Fibers.fiber_count(plant)):
			value.pile.append({})
		cut_plants[target.id] = true
		# 0.0.8.15 (#239) : une plante plantée par le joueur repousse après PLANT_REGROW_SECONDS de jeu.
		if plant.has("id"):
			plant_regrow[target.id] = played_total() + PLANT_REGROW_SECONDS
		# 0.0.8.8 : une ortie pique : à mains nues, beaucoup ; coupée avec un éclat, un peu.
		if int(plant.plante) == Plants.NETTLE:
			hurt(Fibers.NETTLE_CUT if holding_flake() else Fibers.NETTLE_PULL)
		_refresh_column_plants(target.column)
	else:
		var tree: Node3D = target.tree
		value = {"objet": Fibers.LIANE, "pile": [{}]}
		# 0.0.8.7 (demande de l'utilisateur) : on n'en prend qu'un morceau ; la liane du tronc raccourcit, et disparaît au
		# dernier (Fibers.LIANE_PARTS).
		var id := str(tree.get_meta("id", ""))
		cut_vines[id] = vines_taken(id) + 1
		_show_vine(tree)
	objects_dirty = true
	var amount := Inventory.count(value)
	var result := inventory.add_to_selected(value)
	var rest: int = amount - int(result.added)
	if rest > 0 and is_instance_valid(ground):
		var near := player.global_position - player.global_transform.basis.z * 0.8
		for unit in Inventory.units(value).slice(int(result.added)):
			ground.drop(unit, player.camera.global_position - player.global_transform.basis.z * 0.3, near, _rest_height, 0.15)
	var name := Inventory.plural_name(value) if amount > 1 else Inventory.item_name(value).to_lower()
	show_choice("%d %s récoltée%s" % [amount, name, "s" if amount > 1 else ""] + (" (%d au sol)" % rest if rest > 0 else ""))
	notebook_mark("recolter")
	return true


# 0.0.8.7 : morceaux de liane déjà pris sur un arbre (0 à Fibers.LIANE_PARTS ; anciens mondes : « true » = tout).
func vines_taken(id: String) -> int:
	var taken: Variant = cut_vines.get(id, 0)
	return Fibers.LIANE_PARTS if taken is bool and taken else int(taken)

# La liane du tronc selon ce qui reste : plus courte à chaque morceau pris, plus rien au dernier.
func _show_vine(tree: Node3D) -> void:
	var left := Fibers.LIANE_PARTS - vines_taken(str(tree.get_meta("id", "")))
	var climb: MeshInstance3D = tree.get_node_or_null("Modele/Liane")
	if left <= 0:
		tree.set_meta("liane", false)
		if climb != null:
			climb.queue_free()
		return
	if climb != null and left < Fibers.LIANE_PARTS:
		var base := Trees.trunk(int(tree.get_meta("kind", Trees.LINDEN)), int(tree.get_meta("size", 3)))
		climb.mesh = Plants.vine_mesh(base.x, (base.y + 1.5) * float(left) / Fibers.LIANE_PARTS)
func _refresh_column_plants(column: Vector2i) -> void:
	var kept: Array = []
	for node in column_objects.get(column, []):
		if is_instance_valid(node) and node.is_in_group("plants"):
			node.queue_free()
		else:
			kept.append(node)
	column_objects[column] = kept
	_show_column_plants(column)

# --- 0.0.8.15 (#239, demandes de l'utilisateur) : plantes et gazon dans l'inventaire ---
# Arracher une plante entière : clic gauche maintenu PULL_PLANT_SECONDS (mode « Casser / Arracher » : elle tombe au sol ;
# « Casser / Récupérer des objets » : dans la main) ; l'ortie pique à mains nues. R donne toujours les fibres. Planter :
# clic droit « Poser » avec la plante en main, sur la terre ou l'herbe (pas sous l'eau) ; coupée (R), une plante plantée
# repousse après PLANT_REGROW_SECONDS de jeu. Gazon : « Récupérer des matériaux » sur l'herbe donne une motte (l'herbe
# disparaît là) ; posée (clic droit), l'herbe repousse autour, même sur un sol creusé. Tout est enregistré (objets.json).
const PULL_PLANT_SECONDS := 1.2
const PLANT_REGROW_SECONDS := 600.0
const PLANT_ITEMS := ["plante_ortie", "plante_lin", "plante_herbe"]
const TURF_ITEM := "gazon"
const PLANT_GROUNDS := [-1, SmoothTerrain.DIRT, SmoothTerrain.NEEDLES, SmoothTerrain.CLAY, SmoothTerrain.MUD]
var removed_plants: Dictionary = {}
var planted_plants: Array = []
var plant_regrow: Dictionary = {}
var turf_cells: Dictionary = {}
var _regrow_check := 0.0

static func plant_column(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / SmoothTerrain.ZONE_SIZE), floori(z / SmoothTerrain.ZONE_SIZE))

# Plantes d'une colonne : celles de la graine (sans les arrachées) et celles plantées par le joueur.
func column_plants(column: Vector2i) -> Array:
	var list: Array = terrain.plants_in_zone(column).filter(func(plant: Dictionary): return not removed_plants.has(Fibers.plant_id(plant)))
	for plant: Dictionary in planted_plants:
		if plant_column(float(plant.x), float(plant.z)) == column:
			list.append(plant.duplicate())
	return list

func played_total() -> float:
	return float(world_stats.get("temps_de_jeu", 0.0)) + played_since_save

func _replant_column(column: Vector2i) -> void:
	_plant_cache.erase(column)
	if column_objects.has(column):
		_refresh_column_plants(column)

func pull_plant(target: Dictionary, collect: bool) -> bool:
	var plant: Dictionary = target.plant
	var id: String = target.id
	var value := {"objet": PLANT_ITEMS[clampi(int(plant.plante), 0, 2)], "pile": [{}]}
	if plant.has("id"):
		planted_plants = planted_plants.filter(func(other: Dictionary): return str(other.id) != id)
		plant_regrow.erase(id)
	else:
		removed_plants[id] = true
	cut_plants.erase(id)
	if int(plant.plante) == Plants.NETTLE:
		hurt(Fibers.NETTLE_CUT if holding_flake() else Fibers.NETTLE_PULL)
	_replant_column(target.column)
	objects_dirty = true
	var foot := Vector3(float(plant.x), terrain.height_at(float(plant.x), float(plant.z)), float(plant.z))
	var picked := 0
	if collect:
		picked = int(inventory.add_to_selected(value).added)
	if picked == 0 and is_instance_valid(ground):
		ground.drop({"objet": value.objet}, foot + Vector3.UP * 0.3, foot, _rest_height, 0.0)
	show_choice("Plante arrachée : %s" % Inventory.item_name(value).to_lower())
	return true

# Le sol visé convient-il à une plante ou au gazon (terre, herbe, pas sous l'eau, à portée) ? Message sinon.
func _plant_spot(hit: Dictionary, what: String) -> bool:
	if hit.is_empty() or not is_instance_valid(hit.get("collider")) or not hit.collider.is_in_group("ground") or hit.normal.y < 0.6:
		_notify("Visez la terre ou l'herbe pour %s." % what)
		return false
	if player.camera.global_position.distance_to(hit.position) > player.place_reach + 0.01:
		_notify("Trop loin : %s m au plus." % str(snappedf(player.place_reach, 0.1)).replace(".", ","))
		return false
	var at: Vector3 = hit.position
	if water_surface(Vector2(at.x, at.z)) > at.y + 0.05:
		_notify("Pas sous l'eau.")
		return false
	if not ground_kind_under(at + Vector3.UP * 0.3) in PLANT_GROUNDS:
		_notify("Seulement dans la terre ou l'herbe.")
		return false
	return true

func plant_held(hit: Dictionary) -> bool:
	if not _plant_spot(hit, "planter"):
		return false
	var one := inventory.pop_held()
	if one.is_empty():
		return false
	var at: Vector3 = hit.position
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([roundi(at.x * 100.0), roundi(at.z * 100.0), "plantee"])
	var plant := {"id": "p%d:%d" % [roundi(at.x * 100.0), roundi(at.z * 100.0)], "plante": clampi(int(Inventory.ITEMS.get(one.objet, {}).get("plante", 0)), 0, 2), "x": at.x, "z": at.z, "taille": rng.randf_range(0.85, 1.1), "rotation": rng.randf_range(0.0, 360.0)}
	planted_plants = planted_plants.filter(func(other: Dictionary): return str(other.id) != plant.id)
	planted_plants.append(plant)
	cut_plants.erase(plant.id)
	_replant_column(plant_column(at.x, at.z))
	objects_dirty = true
	show_choice("Planté : %s" % Inventory.item_name(one).to_lower())
	notebook_mark("planter")
	return true

func lay_turf(hit: Dictionary) -> bool:
	if not _plant_spot(hit, "poser le gazon"):
		return false
	if inventory.pop_held().is_empty():
		return false
	_set_grass(hit.position, true)
	show_choice("Gazon posé : l'herbe repousse")
	notebook_mark("planter")
	return true

func _step_regrow(delta: float) -> void:
	if plant_regrow.is_empty():
		return
	_regrow_check += delta
	if _regrow_check < 2.0:
		return
	_regrow_check = 0.0
	var now := played_total()
	for id: String in plant_regrow.keys():
		if now < float(plant_regrow[id]):
			continue
		plant_regrow.erase(id)
		cut_plants.erase(id)
		objects_dirty = true
		for plant: Dictionary in planted_plants:
			if str(plant.id) == id:
				_replant_column(plant_column(float(plant.x), float(plant.z)))

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
	# 0.0.8.15 (#239) : sur l'herbe : une motte de gazon (l'herbe disparaît là, le sol ne bouge pas).
	var turf := not aimed_grass(hit).is_empty()
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
	var id: String = TURF_ITEM if turf else GATHER_ITEMS[kind]
	gather_time += delta
	if gather_time < GATHER_SECONDS:
		show_ring(gather_time / GATHER_SECONDS)
		return false
	gather_time = 0.0
	if turf:
		var taken := inventory.add_to_selected({"objet": TURF_ITEM, "pile": [{}]})
		if taken.added == 0:
			_notify(_refused_message(taken.reason, {"objet": TURF_ITEM}))
			return false
		_set_grass(hit.position, false)
		show_choice("Motte de gazon (%s)" % Inventory.format_weight(Inventory.unit_weight({"objet": TURF_ITEM})))
		notebook_mark("recuperer")
		return true
	var result := inventory.add_to_selected({"objet": id, "nombre": 1})
	if result.added == 0:
		_notify(_refused_message(result.reason, {"objet": id}))
		return false
	_apply_terrain({point: [SmoothTerrain.DUG, -1]})
	show_choice("%s (%s)" % [handful_text(id), Inventory.format_weight(Inventory.unit_weight({"objet": id}))])
	notebook_mark("recuperer")
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

# 0.0.7.8 : any_surface (poser) : aussi sur un rocher, un caillou ou un bloc (demande de l'utilisateur : poser partout).
func _aimed_ground(hit: Dictionary, reach: float, any_surface: bool = false) -> bool:
	if not _valid_hit(hit, reach):
		# 0.0.6 : jamais un clic sans réponse : on dit pourquoi rien ne se passe.
		if hit.is_empty() or not is_instance_valid(hit.get("collider")):
			_notify("Rien à portée : visez le sol à moins de %s m." % str(snappedf(reach, 0.1)).replace(".", ","))
		elif player.camera.global_position.distance_to(hit.position) > reach + 0.01:
			_notify("Trop loin : %s m au plus." % str(snappedf(reach, 0.1)).replace(".", ","))
		else:
			_notify("Visez le sol pour le sculpter.")
		return false
	var surface: bool = hit.collider.is_in_group("ground") or (any_surface and (hit.collider.is_in_group("rocks") or hit.collider.is_in_group("pebbles") or hit.collider.is_in_group("blocks")))
	if not surface:
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

# --- 0.0.7.27 (#217) : durées de cassage selon la matière ---
# Survie, à mains nues, par sous-cellule de 50 cm (secondes). Le geste prend la somme de ses sous-cellules (× 0,8 par groupe
# de 4, gesture_factor) ; la pierre se
# casse une sous-cellule à la fois, très lentement et sans rien récupérer ; la Roche-mère jamais. Plus tard, les outils
# diviseront ces durées (pioche ÷ 6 sur la pierre, avec des morceaux ; pelle ÷ 3 sur la terre ; hache ÷ 4 sur le bois).
# Créatif : tout au rythme du clic (Intervalle de casse, 0,3 s par défaut), pierre comprise, sans pioche.
const DIG_SECONDS := {
	SmoothTerrain.SNOW: 0.3, SmoothTerrain.SAND: 0.4, SmoothTerrain.NEEDLES: 0.4, SmoothTerrain.MUD: 0.5,
	SmoothTerrain.DIRT: 0.6, SmoothTerrain.GRAVEL: 0.8, SmoothTerrain.CLAY: 1.0,
	# 0.0.7.28 (demande de l'utilisateur) : pierres deux fois plus rapides (avant : 15, 20 et 30 s).
	SmoothTerrain.LIMESTONE: 7.5, SmoothTerrain.STONE: 10.0, SmoothTerrain.COAL: 10.0,
	SmoothTerrain.DARK_STONE: 15.0, SmoothTerrain.FLINT: 15.0,
}
# 0.0.7.28 : en Survie, à mains nues, un rocher se creuse comme sa pierre (une sous-cellule à la fois), un caillou se casse
# en PEBBLE_HAND_SECONDS, sans rien récupérer.
const PEBBLE_HAND_SECONDS := 5.0
# Anneau de chargement seulement pour ce qui dure plus d'une demi-seconde.
const RING_FROM_SECONDS := 0.5
var dig_point: Variant = null
var dig_time := 0.0

static func dig_seconds(kind: int) -> float:
	if kind == SmoothTerrain.MOTHER_ROCK:
		return INF
	return DIG_SECONDS.get(kind if kind >= 0 else SmoothTerrain.DIRT, DIG_SECONDS[SmoothTerrain.DIRT])

func _kind_at(point: Vector3i) -> int:
	return terrain.materials.get(point, terrain.natural_kind(point))

# Ce que creuse le geste visé en Survie : {"cells": sous-cellules du geste, "seconds": durée, "stone": bool}, vide si rien.
func dig_plan(hit: Dictionary) -> Dictionary:
	var center := SmoothTerrain.point_of(hit.position - hit.normal * 0.3)
	if not _in_terrain_limits(center) or terrain.density(center) <= 0.0:
		return {}
	if terrain.is_stone(center):
		return {"center": center, "cells": 1, "seconds": dig_seconds(_kind_at(center)), "stone": true}
	var cells: int = SIZE_CELLS[player.brush_size]
	var total := 0.0
	for point in gesture_points(center, hit.normal, cells):
		if _in_terrain_limits(point) and terrain.density(point) > 0.0 and not terrain.is_stone(point):
			total += dig_seconds(_kind_at(point))
	return {"center": center, "cells": cells, "seconds": total * gesture_factor(cells), "stone": false}

# Demande de l'utilisateur (19.11.2026) : un geste plus grand va plus vite par sous-cellule : chaque groupe de 4 sous-cellules
# multiplie la durée par 0,8 (4 : 80 % de la somme, 8 : 64 %, 12 : 51 %…).
const GESTURE_DISCOUNT := 0.8

static func gesture_factor(cells: int) -> float:
	return pow(GESTURE_DISCOUNT, floori(cells / 4.0))

# Ce que casse la visée en Survie à mains nues : le sol (dig_plan), un rocher (sous-cellule visée, durée de sa pierre) ou un
# caillou (PEBBLE_HAND_SECONDS). « center » : la cible (changer de cible recommence).
func hand_plan(hit: Dictionary) -> Dictionary:
	if hit.collider.is_in_group("rocks"):
		var kind := SmoothTerrain.LIMESTONE if int(hit.collider.get_meta("look", 0)) == 1 else SmoothTerrain.STONE
		return {"center": [hit.collider.get_instance_id(), SmoothTerrain.point_of(hit.position - hit.normal * 0.15)], "cells": 1, "seconds": dig_seconds(kind), "stone": true}
	if hit.collider.is_in_group("pebbles"):
		return {"center": [hit.collider.get_instance_id()], "cells": 1, "seconds": PEBBLE_HAND_SECONDS, "stone": true}
	if not hit.collider.is_in_group("ground"):
		return {}
	return dig_plan(hit)

# Survie : clic gauche maintenu sur le sol : le temps s'accumule sur la sous-cellule visée (anneau au-delà de 0,5 s),
# puis le geste se fait. Changer de cible recommence.
func step_dig(delta: float, holding: bool, aimed: Dictionary = {}) -> bool:
	if not holding or game_mode != Inventory.SURVIVAL or not is_instance_valid(player) or player.left_mode != 0 or player.selected_type == PICKAXE:
		dig_point = null
		dig_time = 0.0
		return false
	# aimed : visée donnée (tests) ; sinon celle du joueur.
	var hit: Dictionary = aimed if not aimed.is_empty() else player.get_target()
	if not _valid_hit(hit, player.break_reach) or hit.collider.is_in_group("blocks") or _ground_wood(hit) >= 0 or not aimed_wood(hit).is_empty():
		dig_point = null
		dig_time = 0.0
		return false
	var plan := hand_plan(hit)
	if plan.is_empty() or plan.seconds <= 0.0 or is_inf(float(plan.seconds)):
		dig_time = 0.0
		return false
	# 0.0.8.10 (#202) : pioche en pierre en main : la pierre 4 fois plus vite (avec des éclats), la terre 2 fois.
	var work := "pierre" if plan.stone else "terre"
	var speed := tool_speed(work)
	var seconds: float = plan.seconds / speed
	if typeof(plan.center) != typeof(dig_point) or plan.center != dig_point:
		dig_point = plan.center
		dig_time = 0.0
	dig_time += delta
	if seconds > RING_FROM_SECONDS:
		show_ring(dig_time / seconds)
	if dig_time < seconds:
		return false
	dig_point = null
	dig_time = 0.0
	var pick: bool = speed > 1.0 and plan.stone
	if hit.collider.is_in_group("rocks"):
		use_tool(work, seconds)
		return mine_rock(hit.collider, hit, pick)
	if hit.collider.is_in_group("pebbles"):
		use_tool(work, seconds)
		return strike_pebble(hit.collider, true, pick)
	var stone_kind: int = _kind_at(plan.center) if plan.stone and plan.center is Vector3i else -1
	var done := sculpt(hit, false, -1, plan.cells, plan.stone)
	if done:
		_debris(hit.position, Color("#6f6b66") if plan.stone else Color("#6b4a2e"))
		if plan.stone:
			_impact_sound(hit.position)
		if pick and STONE_PIECES.has(stone_kind):
			drop_pieces(STONE_PIECES[stone_kind], 2, STONE_PIECE_WEIGHT, hit.position)
		use_tool(work, seconds)
	return done

# Creuser (add false) ou poser (add true, matière kind). limit (Survie) : sous-cellules posées au plus (ce qu'on tient).
func sculpt(hit: Dictionary, add: bool, kind: int = SmoothTerrain.DIRT, cells: int = 1, pickaxe: bool = false, limit: int = -1) -> bool:
	if not _aimed_ground(hit, player.place_reach if add else player.break_reach, add):
		return false
	var center := SmoothTerrain.point_of(hit.position + hit.normal * (0.15 if add else -0.3))
	var updates := {}
	var message := ""
	# 0.0.7.32 (#216, demande de l'utilisateur : la terre posée sur un rocher flottait au-dessus, jusqu'à 1 m mesuré) :
	# posé sur le dessus d'un rocher, d'un caillou ou d'un bloc, chaque sous-cellule du geste se pose sur la surface sous
	# son propre centre (le rocher descend sur les côtés), et une sous-cellule de joint juste dessous comble le vide quand
	# le dessous de la terre resterait plus de JOINT_GAP au-dessus. Rien dessous (bord du rocher) : pas d'appui, elle tombe.
	var on_object: bool = add and not hit.collider.is_in_group("ground") and hit.normal.y > 0.5
	for gesture_point in gesture_points(center, hit.normal, cells):
		var point: Vector3i = gesture_point
		var surface_y := NAN
		if on_object:
			surface_y = _surface_under(Vector3(point) * SmoothTerrain.STEP)
			if not is_nan(surface_y):
				point.y = roundi((surface_y + 0.15) / SmoothTerrain.STEP)
		if limit >= 0 and updates.size() >= limit:
			break
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
		var lowest := point
		if on_object and not is_nan(surface_y):
			var joint := point + Vector3i.DOWN
			if point.y * SmoothTerrain.STEP - BLOB_HALF > surface_y + JOINT_GAP and terrain.density(joint) <= 0.0 and not updates.has(joint) and _in_terrain_limits(joint) and not _inside_player(joint) and (limit < 0 or updates.size() < limit):
				updates[joint] = [SmoothTerrain.ADDED, kind]
				lowest = joint
		# 0.0.7.9 : posé sur un rocher, un caillou ou un bloc : appui juste dessous (sinon la matière tombait au travers).
		# 0.0.7.32 : sur le dessus, seulement s'il y a bien une surface dessous (au bord, elle tombe).
		if add and not hit.collider.is_in_group("ground") and (not on_object or not is_nan(surface_y)) and terrain.density(lowest + Vector3i.DOWN) <= 0.0:
			terrain.supports[lowest + Vector3i.DOWN] = true
			objects_dirty = true
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

# 0.0.7.32 (#216) : demi-hauteur d'une sous-cellule seule (terre lisse autour de son point) et vide toléré dessous.
const BLOB_HALF := 0.17
const JOINT_GAP := 0.03

# Haut de la surface (rocher, caillou, bloc ou sol) sous un point : rayon vers le bas ; NAN si rien à 1,5 m dessous.
func _surface_under(at: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 1.5)
	if is_instance_valid(player):
		query.exclude = [player.get_rid()]
	for attempt in range(6):
		var found := space.intersect_ray(query)
		if found.is_empty():
			return NAN
		var body: Object = found.collider
		if body is Node and (body.is_in_group("rocks") or body.is_in_group("pebbles") or body.is_in_group("blocks") or body.is_in_group("ground")):
			return found.position.y
		query.exclude = query.exclude + [found.rid]
	return NAN

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
	# 0.0.7.20 : un calcul de surface découpé en cours sur ces zones serait périmé : recommencé.
	terrain_edits += 1
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
const FALL_REFRESH_SECONDS := 0.45
var fall_refresh_time := 0.0
var fall_moved: Dictionary = {}

func _settle_terrain(delta: float) -> void:
	if terrain.unstable.is_empty():
		fall_time = 0.0
		if not fall_moved.is_empty():
			var waiting: Array = fall_moved.keys()
			fall_moved.clear()
			_refresh_terrain(waiting)
		return
	fall_time += delta
	if fall_time < FALL_SECONDS:
		return
	fall_time = 0.0
	var moved := terrain.settle_step()
	# 0.0.7.33 (demande de l'utilisateur : une chute faisait ramer) : les zones touchées sont refaites ensemble, au plus
	# toutes les FALL_REFRESH_SECONDS (avant : à chaque cran, 0,15 s), et dès que tout est retombé.
	for point in moved:
		fall_moved[point] = true
	fall_refresh_time += FALL_SECONDS
	if not fall_moved.is_empty() and (fall_refresh_time >= FALL_REFRESH_SECONDS or terrain.unstable.is_empty()):
		fall_refresh_time = 0.0
		var points: Array = fall_moved.keys()
		fall_moved.clear()
		_refresh_terrain(points)

# Tout laisser retomber d'un coup (tests, et avant d'enregistrer en quittant).
func settle_all(limit: int = 2000) -> void:
	var moved := fall_moved.duplicate()
	fall_moved.clear()
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
	# 0.0.8.1 (#205) : enregistré pendant l'écran de mort (on quitte, on met en pause) : déjà réapparu, au départ, vie pleine.
	var at: Vector3 = spawn_position() if death_open else player.position
	return {"format": Store.FORMAT, "position": [at.x, at.y, at.z],
		"regard_horizontal": player.rotation.y, "regard_vertical": player.camera.rotation.x,
		# 0.0.7.2 : inventaire (Survie et Créatif), barre d'objets et case en main.
		"inventaire": inventory.to_dict(),
		# 0.0.8 (#171) : points de vie (Survie).
		"vie": Health.MAX if death_open else health.value,
		# 0.0.8.2 (#231) : orbes de retour du début déjà données (ou monde ouvert en Créatif : jamais).
		"orbes_depart": start_orbs_given,
		# 0.0.8.16 (#208) : Carnet de route : cases et étapes cochées, message du début déjà montré.
		"carnet": notebook.to_array(), "carnet_vu": notebook_seen,
		# 0.0.8.27 (#160) : l'heure du jour (minutes).
		"heure": snappedf(day_time, 0.1)}

func _read_saved_player() -> Dictionary:
	if save_folder.is_empty():
		return {}
	var saved := Store.read_json(save_folder.path_join(Store.PLAYER_FILE), Store.valid_player)
	if saved.has("error"):
		_notify(saved.error)
		notice_time = 8.0
	return saved.get("data", {})

# --- 0.0.8 (#171, #204) : vie en Survie ---
# Barre en bas à gauche (health_bar.gd), dégâts de chute (player.gd, signal landed), régénération lente (health.gd).
# Un dégât : le bord de l'écran rougit un court instant, la vue tremble un peu, la barre clignote (pas de sang).
# Manger : un fruit en main, clic droit maintenu (anneau ; 0.0.8.3 : Health.eat_seconds, et on continue en restant appuyé) ; un clic court le pose comme avant.
const Health = preload("res://scripts/health.gd")
const HealthBar = preload("res://scripts/health_bar.gd")
const HURT_SECONDS := 0.5
const SHAKE := 0.05
# 0.0.8.3 : durée de chaque fruit : Health.eat_seconds (pomme 1 s, noisette 0,5 s).
const EAT_BRUSH := 3
var eat_chain := false
const EAT_TAP := 0.25
const HURT_SHADER := "shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 0.8);
	float edge = smoothstep(0.3, 0.75, length(d) * 1.4);
	COLOR = vec4(0.7, 0.0, 0.0, edge * strength * 0.65);
}"
var health := Health.new()
var health_bar: Control
var hurt_veil: ColorRect
var hurt_time := 0.0
# 0.0.8.9 (#242, demande de l'utilisateur) : force de l'effet selon les points perdus : une piqûre, à peine ; une grosse
# chute ou un arbre, un rouge marqué, plus long, et une vraie secousse de la vue (HURT_FULL points : effet entier).
var hurt_power := 1.0
const HURT_FULL := 30.0
var fall_ignored := false
var eat_time := -1.0

func survival() -> bool:
	return game_mode == Inventory.SURVIVAL

func _create_health_hud(layer: CanvasLayer) -> void:
	hurt_veil = ColorRect.new()
	hurt_veil.name = "HurtVeil"
	hurt_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = HURT_SHADER
	hurt_veil.material = look
	hurt_veil.visible = false
	layer.add_child(hurt_veil)
	health_bar = HealthBar.new()
	health_bar.text_scale = text_scale
	layer.add_child(health_bar)
	health_bar.value = health.value
	health_bar.visible = survival()

func _on_landed(height: float, water: float) -> void:
	if fall_ignored:
		fall_ignored = false
		return
	# Dans l'eau (assez profonde pour ralentir la marche) : rien.
	if water > PlayerScript.WADE_DEPTH:
		return
	hurt(Health.fall_damage(height, ground_kind_under(player.position) == SmoothTerrain.SAND))

# Dégâts en Survie ; rend les points perdus. À 0 : retour au point de départ (0.0.8.1 : écran de mort, #205).
func hurt(points: int) -> int:
	if not survival() or points <= 0:
		return 0
	var lost := health.damage(points)
	if lost > 0:
		hurt_power = maxf(clampf(lost / HURT_FULL, 0.15, 1.0), hurt_power if hurt_time > 0.0 else 0.0)
		hurt_time = HURT_SECONDS * (0.6 + 0.8 * hurt_power)
		inventory_unsaved = true
		if is_instance_valid(health_bar):
			health_bar.hurt()
	if health.dead() and not death_open:
		_out_of_strength()
	return lost

# --- 0.0.8.1 (#205, demandes de l'utilisateur) : mort et réapparition ---
# Vie à 0 : petit écran « À bout de forces… » (rien de gore), la souris libérée, puis « Revenir au départ » : point de
# départ, vie pleine. Objets portés (mains et poches) : selon le réglage du monde, ils tombent sur place, éparpillés
# autour (au sol comme des objets jetés, enregistrés dans objets.json, sans limite de temps) ou on les garde.
var death_items := "drop"
var death_open := false
var death_layer: CanvasLayer
var death_note: Label
var death_button: Button
const DEATH_SPREAD := Vector2(0.2, 1.2)

func _out_of_strength() -> void:
	death_open = true
	hurt_time = 0.0
	player.actions.cancel()
	close_inventory(false)
	close_crafting(false)
	eat_time = -1.0
	var dropped := 0
	if death_items != "keep":
		dropped = drop_all_items(player.global_position)
	inventory_unsaved = true
	player.release_controls()
	_show_death_screen(dropped)

# Tout ce qu'on porte tombe autour de « at », un par un ; rend le nombre d'objets tombés.
func drop_all_items(at: Vector3) -> int:
	if not is_instance_valid(ground):
		return 0
	var count := 0
	# 0.0.8.21 (#207) : aussi ce que contiennent les sacs, puis les sacs eux-mêmes.
	var dropped := []
	for place in inventory.carried_places():
		dropped.append_array(Inventory.units(inventory.remove(place[0], place[1], true)))
	for which in [1, 0]:
		var worn := inventory.take_off_bag(which)
		if not worn.is_empty():
			dropped.append(worn)
	if not dropped.is_empty():
		for unit in dropped:
			var angle := randf() * TAU
			var reach := randf_range(DEATH_SPREAD.x, DEATH_SPREAD.y)
			var near := at + Vector3(cos(angle) * reach, 0.0, sin(angle) * reach)
			ground.drop(unit, at + Vector3.UP * 1.0, near, _rest_height, 0.1)
			count += 1
	return count

func _show_death_screen(dropped: int) -> void:
	if not is_instance_valid(death_layer):
		death_layer = CanvasLayer.new()
		death_layer.name = "DeathScreen"
		death_layer.layer = 5
		add_child(death_layer)
		var veil := ColorRect.new()
		veil.color = Color(0.05, 0.04, 0.08, 0.72)
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		death_layer.add_child(veil)
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		box.grow_vertical = Control.GROW_DIRECTION_BOTH
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", roundi(14 * text_scale))
		death_layer.add_child(box)
		var title := Label.new()
		title.text = "À bout de forces…"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", roundi(34 * text_scale))
		title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.82))
		box.add_child(title)
		death_note = Label.new()
		death_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		death_note.add_theme_font_size_override("font_size", roundi(17 * text_scale))
		box.add_child(death_note)
		death_button = Button.new()
		death_button.text = "Revenir au départ"
		death_button.add_theme_font_size_override("font_size", roundi(20 * text_scale))
		death_button.custom_minimum_size = Vector2(260, 46) * text_scale
		death_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		death_button.pressed.connect(respawn)
		box.add_child(death_button)
	if death_items == "keep":
		death_note.text = "Vous gardez vos objets."
	elif dropped > 0:
		death_note.text = "Vos objets sont restés là où vous êtes tombé : allez les rechercher."
	else:
		death_note.text = "Vous ne portiez rien."
	death_layer.visible = true
	death_button.grab_focus()

# Réapparition au point de départ (plus tard : au lit), vie pleine.
func respawn() -> void:
	if not death_open:
		return
	death_open = false
	if is_instance_valid(death_layer):
		death_layer.visible = false
	health.reset()
	_go_to_start()
	inventory_unsaved = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _go_to_start() -> void:
	player.actions.cancel()
	player.position = spawn_position()
	player.velocity = Vector3.ZERO
	player.airborne = false
	_build_around_now()

# 0.0.8.11 (rapport Web : après « Revenir au point de départ », quelques secondes de relief simplifié seul, sans arbres ni
# rochers) : la vue suit tout de suite, et les 3 × 3 colonnes autour du joueur sont construites aussitôt, avec leurs
# arbres, leur herbe et leurs plantes ; le reste par la file, comme en marchant.
func _build_around_now() -> void:
	if not is_inside_tree() or not is_instance_valid(player):
		return
	var center := Vector2i(floori(player.position.x / SmoothTerrain.ZONE_SIZE), floori(player.position.z / SmoothTerrain.ZONE_SIZE))
	update_terrain_view(false, center)
	var near := {}
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var column := center + Vector2i(dx, dz)
			near[column] = true
			if shown_columns.has(column) and not built_columns.has(column):
				terrain_queue.erase(column)
				column_height_rows.erase(column)
				_show_column(column)
	var others: Array = []
	for entry: Array in tree_queue:
		if near.has(entry[0]) and built_columns.has(entry[0]):
			_make_column_tree(entry[0], entry[1])
		else:
			others.append(entry)
	tree_queue = others
	_rebuild_dirty_series()
	for column: Vector2i in near:
		if detail_queue.has(column):
			detail_queue.erase(column)
			_rebuild_lawn_tile(column)
			_show_column_plants(column)

# 0.0.8.1 (#188) : Créatif : revenir au point de départ (touche H par défaut, ou bouton de la pause).
func go_home() -> bool:
	if game_mode != Inventory.CREATIVE:
		_notify("En Survie, pas de retour direct au point de départ.")
		return false
	_go_to_start()
	_notify("Retour au point de départ.")
	return true


# 0.0.8.8 (demande de l'utilisateur) : marcher dans des orties pique, tant qu'on y reste (Survie) : NETTLE_WALK point toutes
# les NETTLE_TICK s, avec l'effet de dégât.
var nettle_time := 0.0

func _step_nettles(delta: float) -> void:
	nettle_time += delta
	if nettle_time < Fibers.NETTLE_TICK:
		return
	nettle_time = 0.0
	if in_nettles():
		if hurt(Fibers.NETTLE_WALK) > 0 and notice_time <= 0.0:
			_notify("Les orties piquent !")

# 0.0.8.11 (rapport Web) : plantes de la graine d'une colonne, gardées (avant : refaites pour 9 colonnes toutes les 0,5 s
# dans les orties, et à chaque image en visant une plante). En lecture seule ; au plus PLANT_CACHE_MAX colonnes gardées.
const PLANT_CACHE_MAX := 64
var _plant_cache := {}

func plants_near(column: Vector2i) -> Array:
	if not _plant_cache.has(column):
		if _plant_cache.size() >= PLANT_CACHE_MAX:
			_plant_cache.clear()
		_plant_cache[column] = column_plants(column)
	return _plant_cache[column]

func in_nettles() -> bool:
	if not is_instance_valid(player) or player.flying or player.swimming:
		return false
	var feet: Vector3 = player.global_position
	var here := _player_column()
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for plant: Dictionary in plants_near(here + Vector2i(dx, dz)):
				if int(plant.plante) != Plants.NETTLE or cut_plants.has(Fibers.plant_id(plant)):
					continue
				var size: float = Plants.SIZES[Plants.NETTLE] * float(plant.taille)
				if Vector2(feet.x - float(plant.x), feet.z - float(plant.z)).length() > size * 0.35:
					continue
				if feet.y < terrain.height_at(float(plant.x), float(plant.z)) + size * 0.8:
					return true
	return false
func _update_health(delta: float) -> void:
	var on := survival()
	if on:
		health.step(delta)
		if not death_open:
			_step_nettles(delta)
	if is_instance_valid(health_bar):
		health_bar.visible = on
		health_bar.value = health.value
	if hurt_time <= 0.0 and not is_instance_valid(hurt_veil):
		return
	hurt_time = maxf(0.0, hurt_time - delta) if on else 0.0
	var k := clampf(hurt_time / HURT_SECONDS, 0.0, 1.0) * hurt_power
	if is_instance_valid(hurt_veil):
		hurt_veil.visible = k > 0.0
		(hurt_veil.material as ShaderMaterial).set_shader_parameter("strength", k)
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if is_instance_valid(camera):
		camera.h_offset = randf_range(-1.0, 1.0) * SHAKE * 2.0 * k * k
		camera.v_offset = randf_range(-1.0, 1.0) * SHAKE * 2.0 * k * k

# Manger (#204) : seulement en Survie, un fruit en main, pinceau « Poser ».
func can_eat() -> bool:
	return hold_use() == "manger"

# 0.0.8.2 : ce que fait le clic droit maintenu avec l'objet en main (Survie, pinceau « Poser ») : « manger » un fruit,
# « orbe » : utiliser l'orbe de retour (#231) ; « » : rien (le clic droit pose comme avant).
func hold_use() -> String:
	if not survival():
		return ""
	var held := inventory.held()
	# 0.0.8.3 (demandes de l'utilisateur) : un fruit se mange dans tous les modes du clic droit ; le mode « Manger » sert
	# à ne rien poser par erreur. 0.0.8.7 (#243) : hors du mode « Manger », viser une surface (à portée) pose l'objet, à
	# répétition en maintenant ; viser le vide (le ciel, rien à portée) mange. L'orbe : en mode Poser.
	if Health.food_points(held) > 0:
		if player.brush == EAT_BRUSH or not aiming_surface():
			return "manger"
		return ""
	if player.brush != 0:
		return ""
	if ReturnOrb.is_orb(held):
		return "orbe"
	return ""

# 0.0.8.7 (#243) : vise-t-on une surface où poser, à portée de pose ?
func aiming_surface() -> bool:
	if not is_instance_valid(player):
		return false
	var hit: Dictionary = player.get_target()
	if hit.is_empty() or not is_instance_valid(hit.get("collider")):
		return false
	return player.camera.global_position.distance_to(hit.position) <= player.place_reach + 0.01

# Clic droit appuyé : rend vrai s'il commence à manger ou à utiliser l'orbe (la pose attend le relâchement).
# Clic droit « Manger » : toujours vrai (il ne pose jamais rien).
func eat_press() -> bool:
	eat_chain = false
	if hold_use().is_empty():
		if is_instance_valid(player) and player.brush == EAT_BRUSH:
			_notify("Rien à manger en main." if survival() else "On mange seulement en Survie.")
			return true
		return false
	eat_time = 0.0
	return true

# Clic droit relâché : un clic court pose l'objet (comme avant 0.0.8), sauf avec le clic droit « Manger » ou après avoir
# déjà mangé en restant appuyé.
func eat_release(hit: Dictionary) -> void:
	if eat_time < 0.0:
		return
	var quick: bool = eat_time < EAT_TAP and not eat_chain and player.brush != EAT_BRUSH
	eat_time = -1.0
	eat_chain = false
	if quick:
		# Clic court : l'action du mode (Poser : l'objet est posé ; Aplanir, Lisser : le geste).
		if player.brush == 0:
			put_down_held(hit)
		else:
			place_target(hit, player.selected_type)

func step_eat(delta: float, holding: bool) -> bool:
	# 0.0.8.17 (#224) : la main revient quand on ne mange plus.
	if eat_time < 0.0 or not holding:
		if is_instance_valid(player) and is_instance_valid(player.hand_view):
			player.hand_view.eat(0.0)
	if eat_time < 0.0:
		return false
	var use := hold_use()
	if not holding or use.is_empty():
		eat_time = -1.0
		return false
	eat_time += delta
	if eat_time < EAT_TAP and not eat_chain:
		return false
	if use == "manger" and health.full():
		_notify("Vie pleine : pas besoin de manger.")
		return false
	# 0.0.8.3 : chaque fruit sa durée (noisette plus rapide).
	var seconds := ReturnOrb.USE_SECONDS if use == "orbe" else Health.eat_seconds(inventory.held())
	show_ring(eat_time / seconds)
	# 0.0.8.17 (#224) : le fruit monte vers la bouche.
	if use == "manger" and is_instance_valid(player.hand_view):
		player.hand_view.eat(eat_time / seconds)
	if eat_time < seconds:
		return false
	if use == "orbe":
		use_orb()
		eat_time = -1.0
		return true
	eat_held()
	# 0.0.8.3 (demande de l'utilisateur) : en restant appuyé, on mange le suivant (relâcher pour s'arrêter).
	eat_time = 0.0
	eat_chain = true
	return true

# 0.0.8.2 (#231) : l'orbe en main ramène au point de départ, puis disparaît.
func use_orb() -> bool:
	if not ReturnOrb.is_orb(inventory.held()):
		return false
	inventory.pop_held()
	_go_to_start()
	inventory_unsaved = true
	_notify("Orbe de retour : vous voici au point de départ.")
	return true

# 0.0.8.2 (#231, demande de l'utilisateur) : en Survie, une fois par monde : une orbe de retour dans une poche (au sol à
# ses pieds si les poches sont pleines) et une deuxième posée au sol près du point de départ, en réserve. Aussi pour les
# mondes de Survie d'avant 0.0.8.2, à leur première ouverture ; un monde ouvert en Créatif n'en reçoit jamais (pas au
# changement de mode). Retenu dans joueur.json (« orbes_depart »).
var start_orbs_given := false

func give_start_orbs() -> int:
	if start_orbs_given:
		return 0
	start_orbs_given = true
	if not survival() or not is_instance_valid(ground):
		return 0
	var orb := {"objet": ReturnOrb.ID}
	var given := 0
	var placed := false
	for index in Inventory.POCKETS:
		if inventory.item("bar", index).is_empty() and inventory.usable("bar", index):
			inventory.put("bar", index, Inventory.single(orb))
			placed = not inventory.item("bar", index).is_empty()
			if placed:
				break
	if not placed:
		ground.drop(orb, player.global_position + Vector3.UP, player.global_position, _rest_height, 0.2)
	given += 1
	var reserve := spawn_position() + ReturnOrb.RESERVE_OFFSET
	ground.drop(orb, reserve + Vector3.UP * 0.5, reserve, _rest_height, 0.0)
	given += 1
	inventory_unsaved = true
	objects_dirty = true
	return given

# Mange le fruit en main ; rend les points regagnés.
func eat_held() -> int:
	if Health.food_points(inventory.held()) <= 0:
		return 0
	var eaten := inventory.pop_held()
	var points := Health.food_points(eaten)
	var gained := health.heal(points)
	var old: bool = eaten.get("objet") == "pomme" and int(eaten.get("couleur", 1)) == Health.BROWN
	var what: String = "Vieille pomme" if old else str(Inventory.ITEMS.get(eaten.get("objet", ""), {}).get("nom", "Fruit"))
	_notify("%s mangée : +%d de vie." % [what, gained])
	inventory_unsaved = true
	notebook_mark("manger")
	return gained

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

# 0.0.7.23 : sur le Web, aussi WEB_SAVE_DELAY s après un changement (arbre coupé, terrain, objet, inventaire), une fois
# que plus rien ne tombe : le navigateur recopie ses fichiers dans son stockage un peu après coup ; enregistré seulement en
# fermant l'onglet, le dernier changement pouvait être perdu (mesures Web du 17.11.2026 : un arbre coupé revenu debout).
const WEB_SAVE_DELAY := 0.5
const WEB_MOVE_SAVE := 8.0
var saved_at := Vector3.ZERO
var unsaved_time := 0.0
var inventory_unsaved := false

func _save_due(delta: float) -> bool:
	if autosave_time >= AUTOSAVE_SECONDS:
		return true
	if not OS.has_feature("web") and not web_save_test:
		return false
	# 0.0.7.25 (mesures Web) : aussi le terrain creusé ou posé (terrain_dirty, oublié avant : un trou perdu même 10 s après),
	# et la place du joueur dès qu'il a bougé de WEB_MOVE_SAVE mètres.
	var moved: bool = is_instance_valid(player) and player.global_position.distance_to(saved_at) > WEB_MOVE_SAVE
	if objects_dirty or not dirty_zones.is_empty() or not terrain_dirty.is_empty() or inventory_unsaved or moved:
		unsaved_time += delta
		# 0.0.7.24 : 0,5 s (avant 2 s : une coupe perdue en rechargeant tout de suite, mesures Web) ; un arbre qui tombe
		# n'attend plus (il est enregistré couché) ; le sable qui coule, si (l'enregistrement le poserait d'un coup).
		return unsaved_time >= WEB_SAVE_DELAY and terrain.unstable.is_empty()
	unsaved_time = 0.0
	return false

# Tests : comme sur le Web.
var web_save_test := false
func save_now() -> bool:
	autosave_time = 0.0
	unsaved_time = 0.0
	inventory_unsaved = false
	if save_folder.is_empty() or not is_instance_valid(player):
		return true
	saved_at = player.global_position
	# 0.0.5.11 : ce qui tombe encore est posé à sa place avant d'enregistrer.
	settle_all()
	var ok := Store.write_json(save_folder.path_join(Store.PLAYER_FILE), player_data())
	world_stats.temps_de_jeu = float(world_stats.get("temps_de_jeu", 0.0)) + played_since_save
	played_since_save = 0.0
	ok = WorldMetadata.write_stats(save_folder, world_stats) and ok
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
	# 0.0.8.9 : modes « arracher » et « récupérer des objets » : l'herbe visée s'arrache (step_weed), on ne creuse pas.
	if is_instance_valid(player) and player.left_mode in [1, 3] and not aimed_grass(hit).is_empty():
		return false
	# 0.0.6.9 : les arbres ne se coupent pas (série 0.0.6).
	if not hit.is_empty() and is_instance_valid(hit.get("collider")) and hit.collider.is_in_group("trees"):
		return false
	# 0.0.7.14 (l'utilisateur : « quand j'essaie de casser des troncs, parfois ça creuse ») : bois au sol visé, ou branche
	# devant le sol visé : on casse (step_chop), on ne creuse jamais.
	if _ground_wood(hit) >= 0 or not aimed_wood(hit).is_empty():
		return false
	# 0.0.7.17 : « Récupérer des matériaux » ne casse rien (step_gather).
	if player.left_mode == 2:
		return false
	# 0.0.5.19 : un rocher se mine à la pioche (sinon un message).
	# 0.0.6.3 : un caillou se casse à la pioche, en 1 à 3 coups selon sa taille.
	if not hit.is_empty() and is_instance_valid(hit.get("collider")) and hit.collider.is_in_group("pebbles"):
		if not _valid_hit(hit, player.break_reach):
			return false
		# 0.0.7.27 (#217) : en Créatif, à mains nues aussi.
		# 0.0.7.28 : en Survie à mains nues, en maintenant le clic (step_dig, sans rien récupérer).
		if player.selected_type != PICKAXE and game_mode != Inventory.CREATIVE:
			return false
		return strike_pebble(hit.collider)
	if not hit.is_empty() and is_instance_valid(hit.get("collider")) and hit.collider.is_in_group("rocks"):
		if not _valid_hit(hit, player.break_reach):
			return false
		if player.selected_type != PICKAXE and game_mode != Inventory.CREATIVE:
			return false
		return mine_rock(hit.collider, hit)
	# 0.0.7.17 : « Casser / Récupérer des objets » ne creuse jamais le terrain.
	if player.left_mode == 1:
		return false
	# 0.0.7.27 (#217) : en Survie à mains nues, le sol se creuse en maintenant le clic (step_dig, durée selon la matière) ;
	# le clic seul dit seulement pourquoi rien ne se passe.
	if game_mode == Inventory.SURVIVAL and player.selected_type != PICKAXE:
		if not _aimed_ground(hit, player.break_reach):
			return false
		var plan := dig_plan(hit)
		if plan.is_empty():
			var aimed := SmoothTerrain.point_of(hit.position - hit.normal * 0.3)
			_notify("Roche-mère : incassable." if aimed.y <= terrain.mother_rock_top else "Rien à creuser ici.")
		return false
	# 0.0.7.27 (#217) : en Créatif, les mains cassent la pierre comme la pioche.
	var pickaxe: bool = player.selected_type == PICKAXE or game_mode == Inventory.CREATIVE
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
	# 0.0.8.3 : clic droit « Manger » : il ne pose jamais rien.
	if player.brush == EAT_BRUSH:
		return false
	# 0.0.8.15 (#239) : une plante en main se plante, une motte de gazon se pose (l'herbe repousse).
	var held_form: String = Inventory.ITEMS.get(inventory.held().get("objet", ""), {}).get("forme", "")
	if player.brush == 0 and held_form == "plante":
		return plant_held(hit)
	if player.brush == 0 and held_form == "gazon":
		return lay_turf(hit)
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
	var limit := -1
	if game_mode == Inventory.SURVIVAL:
		limit = Inventory.count(inventory.held())
		cells = mini(cells, limit)
		if cells <= 0:
			_notify("Rien à poser en main.")
			return false
	# 0.0.7.32 : les joints sous la terre posée sur un rocher comptent aussi (une poignée chacun).
	var done := sculpt(hit, true, kind, cells, false, limit)
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

# --- 0.0.7.17 : menu des actions (B + T, action_menu.gd) ---
# Clic gauche : 0 Creuser / Casser (creuse le terrain, coupe le bois visé), 1 Casser / Récupérer des objets (ne creuse
# jamais : clic maintenu casse, clic court ramasse), 2 Récupérer des matériaux (clic maintenu : une poignée de terre,
# de sable…). Clic droit : le pinceau (Poser, Aplanir, Lisser). R reste le raccourci pour ramasser.
const ActionMenu = preload("res://scripts/action_menu.gd")
# 0.0.8.9 (demande de l'utilisateur) : « casser / arracher » (3) : arrache les mauvaises herbes, qui restent au sol ;
# « casser / récupérer des objets » (1) arrache aussi l'herbe, et la ramasse.
const LEFT_MODES := ["creuser / casser", "casser / récupérer des objets", "récupérer des matériaux", "casser / arracher"]
var action_menu: Control

static func action_hint(left_mode: int, brush: int) -> String:
	return "Clic gauche : %s · clic droit : %s · changer : B + T · taille : B + molette · inventaire : O + I" % [LEFT_MODES[clampi(left_mode, 0, LEFT_MODES.size() - 1)], BRUSH_NAMES[clampi(brush, 0, BRUSH_NAMES.size() - 1)].to_lower()]

func open_action_menu() -> void:
	notebook_mark("actions")
	if is_instance_valid(action_menu) and is_instance_valid(player):
		action_menu.open(player.left_mode, player.brush)

func _on_action_chosen(row: int, index: int) -> void:
	if row == 0:
		player.left_mode = index
		show_choice("Clic gauche : " + ActionMenu.ROWS[0][index])
	else:
		player.brush = index
		show_choice("Clic droit : " + ActionMenu.ROWS[1][index])
	var exploration: Label = find_child("ExplorationNotice", true, false)
	if exploration != null:
		exploration.text = action_hint(player.left_mode, player.brush)

# 0.0.8.5 : calque de l'interface du jeu (caché pendant la fabrication).
var hud_layer: CanvasLayer
func _create_hud() -> void:
	var layer := CanvasLayer.new()
	hud_layer = layer
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
	exploration.text = action_hint(0, 0)
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
	# 0.0.7.8 : anneau de chargement autour de la croix (abattre, couper, récupérer).
	ring = ProgressRing.new()
	layer.add_child(ring)
	# 0.0.7.2 : barre d'objets en bas au centre, écran d'inventaire (inventory_ui.gd) ; les messages juste au-dessus.
	inventory_ui = InventoryUI.new()
	add_child(inventory_ui)
	inventory_ui.setup(inventory, text_scale)
	inventory_ui.overflow.connect(drop_items)
	# 0.0.7.17 : menu des actions (B + T), au-dessus des messages.
	action_menu = ActionMenu.new()
	action_menu.text_scale = text_scale
	action_menu.bottom_margin = inventory_ui.hud_height() + 56.0
	layer.add_child(action_menu)
	action_menu.chosen.connect(_on_action_chosen)
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
	# 0.0.8.27 (#160) : l'heure, en haut à droite sous les coordonnées (0.0.8.28 : sous la mini-carte).
	clock_label = Label.new()
	clock_label.name = "Heure"
	clock_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	clock_label.offset_left = -280
	clock_label.offset_right = -18
	clock_label.offset_top = 18 + roundi(104 * text_scale)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_label.add_theme_font_size_override("font_size", roundi(18 * text_scale))
	clock_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	clock_label.add_theme_constant_override("shadow_outline_size", 3)
	clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_label.text = DayNight.clock_text(day_time)
	layer.add_child(clock_label)
	# 0.0.8.25 (#140) : ce qu'on regarde (à portée), en haut au centre.
	looked_label = Label.new()
	looked_label.name = "Regard"
	looked_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	looked_label.offset_left = -300
	looked_label.offset_right = 300
	looked_label.offset_top = 14
	looked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	looked_label.add_theme_font_size_override("font_size", roundi(17 * text_scale))
	looked_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	looked_label.add_theme_constant_override("shadow_outline_size", 3)
	looked_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(looked_label)
	_create_health_hud(layer)

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
		if is_instance_valid(action_menu):
			action_menu.text_scale = text_scale
			action_menu.queue_redraw()

# 0.0.5.9 : choix du joueur (matière, pinceau, taille), en bas, seulement quand il change.
func show_choice(message: String) -> void:
	_notify(message)

func _notify(message: String) -> void:
	notice = message
	notice_time = 2.5

# 0.0.7.20 : chronomètre par tâche (tools/mesure_perf.gd) : éteint en jeu ; allumé, il garde pour chaque tâche le temps
# total, le plus long et le nombre de fois où elle a pris plus de 20 ms (une image à 50 images/s).
var perf_on := false
var perf := {}
var perf_slow: Array = []

func _perf(name: String, since: int) -> void:
	var spent := (Time.get_ticks_usec() - since) / 1000.0
	var entry: Dictionary = perf.get(name, {"total": 0.0, "max": 0.0, "lentes": 0})
	entry.total += spent
	entry.max = maxf(entry.max, spent)
	if spent > 20.0:
		entry.lentes += 1
	perf[name] = entry

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	# 0.0.7.24 : sans le travail de fond de l'image d'avant (sinon le budget, un quart de l'image, se nourrissait de lui-même :
	# 90 à 110 ms par image mesurées sur le Web).
	frame_usec = lerpf(frame_usec, maxf(delta * 1_000_000.0 - last_work_usec, 1000.0), 0.1)
	_end_warm()
	_step_ui_prewarm()
	if perf_on:
		_process_measured(delta)
		return
	_update_fps(delta)
	_update_ring()
	_update_day(delta)
	_update_looked(delta)
	_update_health(delta)
	if not sliding_trees.is_empty():
		_update_slides(delta)
	_update_collisions()
	_update_underwater()
	_update_water(delta)
	# Sauvegarde régulière (petits fichiers, seulement les zones modifiées : pas de saccade).
	played_since_save += delta
	_step_regrow(delta)
	_step_notebook()
	autosave_time += delta
	if _save_due(delta):
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
	var work_at := Time.get_ticks_usec()
	_process_background_work()
	last_work_usec = Time.get_ticks_usec() - work_at
	_update_pebble_blocks()
	# Image calme (rien à construire) : un modèle d'arbre de plus préparé d'avance.
	if terrain_queue.is_empty() and far_queue.is_empty() and tree_queue.is_empty():
		Trees.warm_next()
	hint.text = notice if notice_time > 0.0 else (ground_wood_hint(hit) if captured else "")
	_update_coordinates()


# 0.0.7.21 : travail de fond (terrain, arbres, lointain) dans un seul budget par image, selon la limite d'images par
# seconde : l'image garde le temps du rendu et du jeu (FRAME_BASE_USEC). Avant : chaque file avait le sien (jusqu'à
# 15 ms en tout : images sous 100 par seconde en marchant). Terrain la moitié, arbres jusqu'aux trois quarts, lointain
# le reste ; s'il reste du temps, encore du terrain. Ouverture du monde : le plus grand budget.
const FRAME_BASE_USEC := 5000
const WORK_MIN_USEC := 1500
const WORK_MAX_USEC := 8000
const SLOW_WORK_MAX_USEC := 30000
# Durée moyenne d'une image (µs), pour le budget à petit nombre d'images.
var frame_usec := 16_000.0
var last_work_usec := 0.0
# 0.0.7.24 : plafond du budget à petit nombre d'images sur le Web (rendu Compatibility).
const SLOW_WORK_MAX_WEB_USEC := 15000

func work_budget() -> int:
	if behind_loading:
		return LOADING_WORK_USEC if is_compat() else LOADING_WORK_PC_USEC
	if opening_columns:
		return WORK_MAX_USEC
	var fps: int = Engine.max_fps if Engine.max_fps > 0 else 144
	var budget := int(1_000_000.0 / fps) - FRAME_BASE_USEC
	# 0.0.7.23 : sous 30 images par seconde (PC bon marché, Web : 8 à 13 mesurées), un quart de la durée réelle de l'image,
	# au plus SLOW_WORK_MAX_USEC : à 8 images par seconde, le monde se construisait 6 à 7 fois moins vite qu'à 60.
	if frame_usec > 33_000.0:
		budget = maxi(budget, mini(int(frame_usec * 0.25), SLOW_WORK_MAX_WEB_USEC if is_compat() else SLOW_WORK_MAX_USEC))
		return budget
	# Web (rendu Compatibility) : le rendu y prend bien plus de l'image.
	if is_compat():
		budget = mini(budget, 4000)
	return clampi(budget, WORK_MIN_USEC, WORK_MAX_USEC)


# 0.0.7.22 (demande de l'utilisateur) : sol de cette place construit ? Colonne affichée mais pas encore construite : non,
# et elle passe en tête de la file (le joueur attend au bord, player._stay_on_loaded_ground). Hors de la vue ou du
# monde : oui (rien à attendre).
func ground_ready(at: Vector3) -> bool:
	var column := Vector2i(floori(at.x / SmoothTerrain.ZONE_SIZE), floori(at.z / SmoothTerrain.ZONE_SIZE))
	if built_columns.has(column) or not shown_columns.has(column):
		return true
	var index := terrain_queue.find(column)
	if index > 0:
		terrain_queue.remove_at(index)
		terrain_queue.push_front(column)
	elif index < 0:
		terrain_queue.push_front(column)
	return false

func _process_background_work() -> void:
	var budget := work_budget()
	var start := Time.get_ticks_usec()
	var at := start
	# Une colonne à 2 zones ou moins attend (la file va des plus proches aux plus loin) : surtout le terrain.
	if not terrain_queue.is_empty():
		var first: Vector2i = terrain_queue[0]
		var ring := maxi(absi(first.x - view_center.x), absi(first.y - view_center.y))
		# 0.0.7.34 : derrière l'écran de chargement sur PC, les colonnes proches (9 × 9) d'abord, presque tout le budget ;
		# leurs arbres, herbe et plantes avec le reste ; le lointain ensuite (avant : partagé, 22 colonnes par seconde).
		if behind_loading and not is_compat() and ring <= NEAR_REVEAL_ZONES:
			_process_terrain_queue(budget * 7 / 8)
			_process_tree_queue(maxi(start + budget * 15 / 16 - Time.get_ticks_usec(), 300))
			_process_detail_queue(maxi(start + budget - Time.get_ticks_usec(), 300))
			if perf_on:
				_perf("terrain_file", at)
			return
		# Colonnes proches faites : leurs détails et l'horizon avant les colonnes plus loin (faites en jouant).
		if behind_loading and not is_compat():
			_process_tree_queue(maxi(budget / 4, 300))
			_process_detail_queue(maxi(start + budget * 5 / 8 - Time.get_ticks_usec(), 300))
			_process_far_queue(maxi(start + budget - Time.get_ticks_usec(), FAR_MIN_USEC))
			return
		if ring <= 2:
			# Juste à côté du joueur : trois quarts du budget pour le terrain, le reste pour le lointain (0.0.7.24 : avant,
			# tout pour le terrain ; en vol rapide, il y a toujours une colonne proche en attente, le lointain n'avançait
			# plus et le paysage disparaissait, mesures Web). Les arbres attendent.
			_process_terrain_queue(budget * 3 / 4)
			if perf_on:
				_perf("terrain_file", at)
				at = Time.get_ticks_usec()
			_process_far_queue(maxi(start + budget - Time.get_ticks_usec(), FAR_MIN_USEC))
			if perf_on:
				_perf("lointain", at)
			return
	_process_terrain_queue(budget / 2)
	if perf_on:
		_perf("terrain_file", at)
		at = Time.get_ticks_usec()
	_process_tree_queue(maxi(start + budget * 5 / 8 - Time.get_ticks_usec(), 300))
	_process_detail_queue(maxi(start + budget * 3 / 4 - Time.get_ticks_usec(), 300))
	if perf_on:
		_perf("arbres_file", at)
		at = Time.get_ticks_usec()
	_process_far_queue(maxi(start + budget - Time.get_ticks_usec(), FAR_MIN_USEC))
	if perf_on:
		_perf("lointain", at)
		at = Time.get_ticks_usec()
	var left := start + budget - Time.get_ticks_usec()
	if left > 500 and not terrain_queue.is_empty():
		_process_terrain_queue(left)
		if perf_on:
			_perf("terrain_file", at)
# Même chose que _process, chaque tâche chronométrée (mesures seulement).
func _process_measured(delta: float) -> void:
	var at := Time.get_ticks_usec()
	_update_fps(delta)
	_update_ring()
	_update_day(delta)
	_update_health(delta)
	if not sliding_trees.is_empty():
		_update_slides(delta)
	_perf("hud", at)
	at = Time.get_ticks_usec()
	_update_collisions()
	_perf("collisions", at)
	at = Time.get_ticks_usec()
	_update_underwater()
	_update_water(delta)
	_perf("eau", at)
	played_since_save += delta
	_step_regrow(delta)
	_step_notebook()
	autosave_time += delta
	if _save_due(delta):
		at = Time.get_ticks_usec()
		save_now()
		_perf("sauvegarde", at)
	notice_time = maxf(0.0, notice_time - delta)
	at = Time.get_ticks_usec()
	var hit: Dictionary = player.get_target()
	selection.visible = false
	_perf("visee", at)
	var here := player_coordinates()
	at = Time.get_ticks_usec()
	if Zones.zone_of(here) != zone_center:
		update_zones(here)
	_perf("zones_liste", at)
	at = Time.get_ticks_usec()
	process_zone_queue()
	_perf("zones_file", at)
	at = Time.get_ticks_usec()
	_settle_terrain(delta)
	_perf("gravite", at)
	at = Time.get_ticks_usec()
	_process_hide_queue()
	_perf("cacher", at)
	at = Time.get_ticks_usec()
	update_terrain_view(false, Vector2i(floori(player.position.x / SmoothTerrain.ZONE_SIZE), floori(player.position.z / SmoothTerrain.ZONE_SIZE)))
	_perf("terrain_vue", at)
	at = Time.get_ticks_usec()
	var work_at := Time.get_ticks_usec()
	_process_background_work()
	last_work_usec = Time.get_ticks_usec() - work_at
	_perf("travail_de_fond", at)
	at = Time.get_ticks_usec()
	_update_pebble_blocks()
	_perf("cailloux", at)
	if terrain_queue.is_empty() and far_queue.is_empty() and tree_queue.is_empty():
		at = Time.get_ticks_usec()
		Trees.warm_next()
		_perf("arbres_avance", at)
	hint.text = notice if notice_time > 0.0 else (ground_wood_hint(hit) if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "")
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
Menu des actions (B + T, molette pour choisir, T pour l'autre ligne) : clic gauche creuser / casser, casser / récupérer des objets ou récupérer des matériaux ; clic droit poser, aplanir ou lisser.
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
%s" % [coordinates_text(), who, WorldMetadata.stats_text(creation_text, world_stats, float(world_stats.get("temps_de_jeu", 0.0)) + played_since_save), zones_text(), _world_info_body(level)]

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
	# 0.0.8.13 : monde fermé : les fils de calcul du terrain s'arrêtent.
	if what == NOTIFICATION_PREDELETE and terrain_workers != null:
		terrain_workers.stop()
		terrain_workers = null
	if is_instance_valid(fps_label) and what in [NOTIFICATION_PAUSED,NOTIFICATION_UNPAUSED]:
		fps_label.visible = what == NOTIFICATION_UNPAUSED
		fps_elapsed = 0.0

func _read_creation_date() -> void:
	creation_text = WorldMetadata.read_creation(save_folder)
	world_stats = WorldMetadata.opened(save_folder)

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

# 0.0.7.24 : qualité changée en jeu : sol simplifié et densité de l'herbe appliqués tout de suite (avant : à la prochaine
# ouverture du monde).
func set_simple_ground(value: bool) -> void:
	simple_ground = value
	TerrainMaterials.set_simple(value)

func set_grass_density(density: String) -> void:
	if density == grass_density:
		return
	grass_density = density
	TerrainMaterials.density = density
	for tile: Vector2i in lawn_tiles.keys():
		_rebuild_lawn_tile(tile)

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
	# 0.0.7.8 : arbres tombés et arbres coupés.
	var fallen: Variant = data.get("arbres_tombes", {})
	if fallen is Dictionary:
		for id in fallen:
			if fallen[id] is Dictionary and fallen[id].get("direction") is Array and fallen[id].direction.size() == 2:
				fallen_trees[str(id)] = fallen[id]
	for id in data.get("arbres_coupes", []):
		cut_trees[str(id)] = true
	# 0.0.7.12 : coupes par branches et tiges (tree_cuts).
	var parts: Variant = data.get("arbres_branches", {})
	if parts is Dictionary:
		for id in parts:
			if parts[id] is Dictionary and parts[id].get("coupes") is Array and parts[id].get("morceaux") is Dictionary:
				tree_cuts[str(id)] = parts[id]
				# 0.0.8.23 : morceaux dont les feuilles sont tombées (nombres entiers ; lus en nombres à virgule).
				if parts[id].has("nus"):
					var bare: Variant = parts[id].nus
					parts[id].nus = bare.filter(func(value): return value is int or value is float).map(func(value): return int(value)) if bare is Array else []
	# 0.0.7.9 : appuis du terrain sur les rochers.
	for point in data.get("appuis", []):
		if point is Array and point.size() == 3:
			terrain.supports[Vector3i(int(point[0]), int(point[1]), int(point[2]))] = true
	# 0.0.7.5 : fruits cueillis, par arbre (numéros des fruits du modèle, trees.gd fruit_spots).
	for id in data.get("branches_ramassees", []):
		picked_branches[str(id)] = true
	for cell in data.get("herbe_arrachee", []):
		if cell is Array and cell.size() == 2:
			pulled_grass[Vector2i(int(cell[0]), int(cell[1]))] = true
	for id in data.get("plantes_coupees", []):
		cut_plants[str(id)] = true
	# 0.0.8.15 (#239) : plantes arrachées, plantées, repousse, gazon posé.
	for id in data.get("plantes_arrachees", []):
		removed_plants[str(id)] = true
	for plant in data.get("plantes_plantees", []):
		if plant is Dictionary and plant.has("id") and plant.has("x") and plant.has("z"):
			planted_plants.append({"id": str(plant.id), "plante": clampi(int(plant.get("plante", 0)), 0, 2), "x": float(plant.x), "z": float(plant.z), "taille": float(plant.get("taille", 1.0)), "rotation": float(plant.get("rotation", 0.0))})
	var regrow: Variant = data.get("plantes_repousse", {})
	if regrow is Dictionary:
		for id in regrow:
			plant_regrow[str(id)] = float(regrow[id])
	for cell in data.get("gazon_pose", []):
		if cell is Array and cell.size() == 2:
			turf_cells[Vector2i(int(cell[0]), int(cell[1]))] = true
	for id in data.get("lianes_coupees", []):
		cut_vines[str(id)] = Fibers.LIANE_PARTS
	# 0.0.8.7 : morceaux pris par arbre.
	var vines: Variant = data.get("lianes_recoltees", {})
	if vines is Dictionary:
		for id in vines:
			cut_vines[str(id)] = clampi(int(vines[id]), 0, Fibers.LIANE_PARTS)
	for id in data.get("rejets_casses", []):
		broken_shoots[str(id)] = true
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
func _show_column_objects(column: Vector2i, progressive := false) -> void:
	_hide_column_objects(column)
	var at := Time.get_ticks_usec()
	_show_column_pebbles(column)
	_show_column_river(column)
	if perf_on:
		_perf("objets_cailloux_riviere", at)
		at = Time.get_ticks_usec()
	for rock in terrain.rocks_in_zone(column):
		if not mined_rocks.has(rock.id):
			var made := _make_rock(rock, rock.id)
			if made != null:
				made.set_meta("column", column)
				_column_object(column, made)
	if perf_on:
		_perf("objets_rochers", at)
		at = Time.get_ticks_usec()
	# 0.0.6.9 (#149) : arbres fruitiers de la colonne (génération 21), détaillés de près, simplifiés au loin.
	var column_trees: Array = terrain.trees_in_zone(column)
	if perf_on:
		_perf("objets_arbres_liste", at)
		at = Time.get_ticks_usec()
	for tree in column_trees:
		# 0.0.7.20 : en se déplaçant, quelques arbres par image (tree_queue) : avant, tous ceux d'une colonne d'un coup
		# (jusqu'à 100 ms en forêt). À l'ouverture et autour du joueur, tout de suite.
		if progressive:
			tree_queue.append([column, tree])
		else:
			_make_column_tree(column, tree)
	_rebuild_dirty_series()
	if perf_on:
		_perf("objets_arbres", at)
		at = Time.get_ticks_usec()
	# 0.0.6.16 (#182) : plantes à fibres de la colonne (génération 27). 0.0.7.25 : en se déplaçant, plus tard (detail_queue).
	if not progressive:
		_show_column_plants(column)
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


# Arbres des colonnes à créer, [colonne, arbre de la graine], quelques-uns par image (TREE_BUDGET_USEC).
var tree_queue: Array = []
const TREE_BUDGET_USEC := 3000


func _show_column_plants(column: Vector2i) -> void:
	var plant_list: Array = column_plants(column)
	if plant_list.is_empty():
		return
	for plant: Dictionary in plant_list:
		if cut_plants.has(Fibers.plant_id(plant)):
			plant.coupee = true
	for node in Plants.column_nodes(plant_list, terrain.height_at):
		node.set_meta("column", column)
		_rocks_parent().add_child(node)
		_column_object(column, node)

# 0.0.7.25 : détails des colonnes construites en se déplaçant (herbe, plantes), une colonne à la fois, après le terrain.
var detail_queue: Array = []

func _process_detail_queue(budget_usec: int) -> void:
	var deadline := Time.get_ticks_usec() + budget_usec
	while not detail_queue.is_empty() and Time.get_ticks_usec() < deadline:
		# La plus proche du joueur d'abord.
		var best := 0
		for index in range(1, detail_queue.size()):
			if Vector2(detail_queue[index] - view_center).length_squared() < Vector2(detail_queue[best] - view_center).length_squared():
				best = index
		var column: Vector2i = detail_queue[best]
		detail_queue.remove_at(best)
		if not built_columns.has(column):
			continue
		_rebuild_lawn_tile(column)
		_show_column_plants(column)
	# 0.0.7.26 : branches mortes et rejets après l'herbe et les plantes.
	while detail_queue.is_empty() and Time.get_ticks_usec() < deadline and _process_one_stick_column():
		pass
func _process_tree_queue(budget_usec: int = TREE_BUDGET_USEC) -> void:
	var deadline := Time.get_ticks_usec() + budget_usec
	while not tree_queue.is_empty() and Time.get_ticks_usec() < deadline:
		var next: Array = tree_queue.pop_front()
		if built_columns.has(next[0]):
			_make_column_tree(next[0], next[1])
	_rebuild_dirty_series()

func _make_column_tree(column: Vector2i, tree: Dictionary) -> void:
	# 0.0.7.8 : arbre coupé : plus là.
	var id := str(tree.id)
	if cut_trees.has(id):
		return
	# 0.0.7.21 : arbre intact (ni tombé ni coupé) : dessiné en série avec ceux de sa colonne (_rebuild_series).
	var intact: bool = not fallen_trees.has(id) and tree_cuts.get(id, {}).get("coupes", []).is_empty()
	# 0.0.8.4 (#213) : liane récoltée : plus sur le tronc.
	var vine: bool = tree.get("liane", false) == true and vines_taken(id) < Fibers.LIANE_PARTS
	var made := Trees.tree_body(int(tree.espece), int(tree.get("classe", 3)), vine, int(tree.get("forme", 0)), intact)
	made.set_meta("liane", vine)
	made.position = Vector3(tree.x, terrain.height_at(tree.x, tree.z) - 0.05, tree.z)
	made.rotation.y = deg_to_rad(float(tree.rotation))
	made.scale = Vector3.ONE * float(tree.taille)
	made.set_meta("id", tree.id)
	# 0.0.8.7 : liane dont des morceaux ont été pris : plus courte.
	if vine and vines_taken(id) > 0:
		_show_vine(made)
	if picked_fruits.has(id):
		Trees.apply_picked(made, picked_fruits[id])
	made.set_meta("column", column)
	_rocks_parent().add_child(made)
	_column_object(column, made)
	if intact:
		_add_stem_collisions(made)
		series_dirty[column] = true
		return
	_restore_fallen(made)
	_restore_pieces(made)
	_restore_parts(made)


# 0.0.7.25 (mesures Web : la caméra entrait dans les troncs d'un arbre à plusieurs tiges) : une collision par tige
# principale et par grosse branche basse (sous BRANCH_COLLISION_TOP m, au moins BRANCH_COLLISION_RADIUS de rayon), le long
# de leur axe (squelette de tree_parts.gd), STEM_COLLISIONS_MAX au plus ; en plus du tronc au pied (Trees.tree_body).
# 0.0.8.11 (rapport Web : la caméra entrait encore dans les noisetiers, 9 à 11 tiges) : d'abord toutes les tiges, puis les
# branches basses (avant : dans l'ordre du squelette, 8 au plus : des tiges restaient sans collision).
const STEM_COLLISIONS_MAX := 12
const BRANCH_COLLISION_TOP := 2.2
const BRANCH_COLLISION_RADIUS := 0.05
const STEM_COLLISION_LENGTH := 2.5

func _add_stem_collisions(tree: Node3D) -> void:
	var model: Node3D = tree.get_node_or_null("Modele")
	if model == null:
		return
	var pieces: Array = TreeParts.skeleton(int(tree.get_meta("kind")), int(tree.get_meta("size")), int(tree.get_meta("form"))).pieces.duplicate()
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.root and a.tip.y > 0.5) and not (b.root and b.tip.y > 0.5))
	var added := 0
	for piece: Dictionary in pieces:
		if added >= STEM_COLLISIONS_MAX:
			break
		var radius: float = maxf(piece.profile[0], piece.profile[1])
		var stem: bool = piece.root and piece.tip.y > 0.5
		var low_branch: bool = not piece.root and piece.start.y < BRANCH_COLLISION_TOP and radius >= BRANCH_COLLISION_RADIUS
		if not stem and not low_branch:
			continue
		var length := minf(float(piece.length), STEM_COLLISION_LENGTH)
		var direction: Vector3 = piece.direction
		var shape := CylinderShape3D.new()
		shape.radius = maxf(radius, 0.03)
		shape.height = length
		var collision := CollisionShape3D.new()
		collision.name = "Tige"
		collision.shape = shape
		var basis := Basis(Quaternion(Vector3.UP, direction.normalized())) if absf(direction.normalized().dot(Vector3.UP)) < 0.9999 else Basis.IDENTITY
		collision.transform = model.transform * Transform3D(basis, piece.start + direction * length * 0.5)
		tree.add_child(collision)
		added += 1
# 0.0.7.21 : arbres intacts dessinés en série, par colonne et par modèle (espèce, taille, forme) : un dessin par modèle
# au lieu d'un par arbre (en forêt : bien moins de dessins par image, surtout sur le Web). Colonne → ses nœuds.
var column_series: Dictionary = {}
var series_dirty: Dictionary = {}

func _rebuild_series(column: Vector2i) -> void:
	series_dirty.erase(column)
	for node in column_series.get(column, []):
		if is_instance_valid(node):
			node.free()
	column_series.erase(column)
	var groups := {}
	for tree in column_objects.get(column, []):
		if not is_instance_valid(tree) or not tree.has_meta("series"):
			continue
		var key := Vector3i(int(tree.get_meta("kind")), int(tree.get_meta("size")), int(tree.get_meta("form")))
		if not groups.has(key):
			groups[key] = []
		var model: Node3D = tree.get_node("Modele")
		groups[key].append(tree.transform * model.transform)
	var made: Array = []
	for key: Vector3i in groups:
		for node in Trees.series_nodes(key.x, key.y, key.z, groups[key]):
			_rocks_parent().add_child(node)
			made.append(node)
	if not made.is_empty():
		column_series[column] = made

func _rebuild_dirty_series() -> void:
	for column: Vector2i in series_dirty.keys():
		_rebuild_series(column)

# L'arbre quitte la série (on le coupe, il tombe) : il reprend ses propres modèles, aussitôt dessinés à la même place.
func _leave_series(tree: Node3D) -> void:
	if not is_instance_valid(tree) or not tree.has_meta("series"):
		return
	tree.remove_meta("series")
	Trees.add_meshes(tree.get_node("Modele"), int(tree.get_meta("kind")), int(tree.get_meta("size")), int(tree.get_meta("form")))
	_rebuild_series(tree.get_meta("column", Vector2i(999999, 0)))
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
		# 0.0.8.11 : les petits cailloux ne projettent plus d'ombre (les rochers, si).
		drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rocks_parent().add_child(drawn)
		nodes.append(drawn)
	if not nodes.is_empty():
		pebble_blocks[block] = nodes

# whole : cassé d'un coup (Survie à mains nues, 0.0.7.28) ; pieces_drop faux : rien à récupérer.
func strike_pebble(body: StaticBody3D, whole := false, pieces_drop := true) -> bool:
	var id: String = body.get_meta("id")
	var kind: Vector2i = body.get_meta("pebble")
	var column: Vector2i = body.get_meta("column")
	var at := body.global_position
	_debris(at, Color("#6f6b66"))
	_impact_sound(at)
	pebble_hits[id] = pebble_hits.get(id, 0) + 1
	if whole or pebble_hits[id] >= Rocks.PEBBLE_HITS[kind.x - 1]:
		pebble_hits.erase(id)
		broken_pebbles[id] = true
		objects_dirty = true
		# 0.0.7.3 : le caillou cassé donne des éclats (250 g au plus chacun), qui tombent à côté du joueur.
		var weight: float = Inventory.PEBBLE_WEIGHTS[kind.x - 1]
		var pieces := maxi(1, ceili(weight / 250.0))
		if pieces_drop:
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
	tree_queue = tree_queue.filter(func(next: Array): return next[0] != column)
	detail_queue.erase(column)
	for node in column_series.get(column, []):
		if is_instance_valid(node):
			node.free()
	column_series.erase(column)
	series_dirty.erase(column)
	_hide_column_pebbles(column)
	_hide_column_sticks(column)

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

# pieces_drop : faux en Survie à mains nues (0.0.7.28) : rien à récupérer.
func mine_rock(body: StaticBody3D, hit: Dictionary = {}, pieces_drop := true) -> bool:
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
	if pieces_drop:
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
	# 0.0.7.26 (#212) : branches mortes de la graine ramassées, rejets cassés.
	data.branches_ramassees = picked_branches.keys()
	data.rejets_casses = broken_shoots.keys()
	# 0.0.8.4 (#213) : plantes à fibres récoltées et lianes récoltées (identifiant de l'arbre).
	data.plantes_coupees = cut_plants.keys()
	# 0.0.8.7 : morceaux de liane pris par arbre (avant : seulement les arbres, liane entière).
	data.erase("lianes_coupees")
	data.lianes_recoltees = cut_vines.duplicate()
	# 0.0.8.8 : herbe arrachée (cases de 50 cm).
	data.herbe_arrachee = pulled_grass.keys().map(func(cell): return [cell.x, cell.y])
	# 0.0.8.15 (#239) : plantes arrachées (de la graine), plantées par le joueur, leur repousse, gazon posé.
	data.plantes_arrachees = removed_plants.keys()
	data.plantes_plantees = planted_plants.duplicate(true)
	data.plantes_repousse = plant_regrow.duplicate()
	data.gazon_pose = turf_cells.keys().map(func(cell): return [cell.x, cell.y])
	data.arbres_tombes = fallen_trees.duplicate(true)
	data.arbres_coupes = cut_trees.keys()
	data.arbres_branches = tree_cuts.duplicate(true)
	data.appuis = terrain.supports.keys().map(func(point: Vector3i): return [point.x, point.y, point.z])
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
# 0.0.7.24 : le lointain avance toujours un peu à chaque image (jamais affamé par le terrain).
const FAR_MIN_USEC := 800
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
		# 0.0.7.24 (demande de l'utilisateur) : aussi au-delà de la limite du monde (avant : vide bleu pâle) : le relief
		# simplifié continue jusqu'à la distance lointaine ; on ne peut pas y aller (le joueur reste à la limite).
		for x in range(here.x - reach, here.x + reach + 1):
			for z in range(here.y - reach, here.y + reach + 1):
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
		if far_surveys.size() >= FAR_SURVEYS_MAX:
			_forget_far_surveys()
		far_surveys[key] = FarTerrain.new_survey(tile, cell)
	return far_surveys[key]

# 0.0.8.14 (rapport d'optimisation : 2 256 relevés gardés après deux tours du monde en vol, environ 15 Ko chacun) : au-delà de
# FAR_SURVEYS_MAX, ceux des carrés loin de la vue sont oubliés (refaits par les fils de calcul si on y revient).
const FAR_SURVEYS_MAX := 400

func _forget_far_surveys() -> void:
	var here := FarTerrain.tile_of(far_center)
	var keep := int(ceil(float(far_distance) / FarTerrain.TILE_ZONES)) + 3
	for key: Vector3i in far_surveys.keys():
		if maxi(absi(key.x - here.x), absi(key.y - here.y)) > keep and not worker_far.has(key):
			far_surveys.erase(key)

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

func _process_far_queue(budget_usec: int = FAR_BUDGET_USEC) -> void:
	# Beaucoup de carrés à faire à l'ouverture du monde : deux fois plus de temps par image. 0.0.6.18 (#175) : seulement
	# à l'ouverture (en vol, la file dépasse souvent 20 carrés : 8 ms par image en plus du terrain, des à-coups).
	var deadline := Time.get_ticks_usec() + (budget_usec * 2 if far_opening and far_queue.size() > 20 else budget_usec)
	if far_queue.is_empty():
		far_opening = false
	# 0.0.8.13 : relevés faits par les fils de calcul ; ici, seulement le maillage d'un relevé fini.
	var by_workers := _workers_on()
	if by_workers and not far_queue.is_empty():
		_dispatch_worker_far()
	while not far_queue.is_empty() and Time.get_ticks_usec() < deadline:
		if by_workers:
			var front := _far_survey(far_queue[0])
			if front.next < front.side:
				return
		if not _build_far_tile(far_queue[0], deadline):
			return
		far_queue.pop_front()

func _set_hud_visible(on: bool) -> void:
	if is_instance_valid(hud_layer):
		hud_layer.visible = on
	if is_instance_valid(inventory_ui):
		inventory_ui.visible = on
