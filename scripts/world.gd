extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const TerrainGenerator = preload("res://scripts/terrain_generator.gd")
const Controls = preload("res://scripts/controls.gd")
const CharacterPreview = preload("res://scripts/character_preview.gd")
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
# Réglage Vidéo → Taille du texte, pour les textes affichés en jeu.
var text_scale := 1.0
var blocks: Dictionary = {}
var materials: Array[StandardMaterial3D] = []
var player: CharacterBody3D
var selection: MeshInstance3D
var selected_block_label: Label
var hint: Label
var coordinates_label: Label
var notice := ""
var notice_time := 0.0

func _ready() -> void:
	_setup_inputs()
	_setup_environment()
	for color in BLOCK_COLORS:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.85
		materials.append(material)
	_create_ground()
	_create_terrain()
	_create_blocks()
	player = PlayerScript.new()
	player.name = "Player"
	player.position = spawn_position()
	add_child(player)
	_create_selection()
	_create_hud()

func _setup_inputs() -> void:
	# Touches choisies dans Paramètres → Contrôles (0.0.3.12), appliquées par le menu ;
	# monde lancé seul (tests) : touches par défaut.
	Controls.ensure_defaults()

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
	environment.ambient_light_color = Color("#d7eaff")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

func _create_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.add_to_group("ground")
	ground.position = Vector3(0, -0.5, 0)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = BASE_SIZE
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#759a65")
	material.roughness = 1.0
	mesh.material_override = material
	ground.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	ground.add_child(collision)
	add_child(ground)

func _create_terrain() -> void:
	generated_hill_count = TerrainGenerator.generate_hills(terrain_seed).size()
	generated_max_height = 0
	for cell in TerrainGenerator.generate_cells(terrain_seed):
		generated_max_height = maxi(generated_max_height, cell.y + 1)
		add_block(cell, DIRT)

func spawn_position() -> Vector3:
	# Apparition en X 0, Y 0, Z 0 (Y 1 avant 0.0.3.22) : pieds posés sur le sol plat, au centre de la case 0, 0.
	# Les blocs posés depuis comptent aussi : on réapparaît dessus, sans chevauchement.
	var top := 0
	for cell: Vector3i in blocks:
		if cell.x == 0 and cell.z == 0:
			top = maxi(top, cell.y + 1)
	return Vector3(0.5, top + 0.01, 0.5)

# Coordonnées affichées : case des pieds, en blocs. Y = hauteur des pieds au-dessus du sol plat
# (0.0.3.22 ; Y 1 au sol avant) : Y 0 au sol, Y 3 au sommet d'une colline de 3 blocs.
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

# Blocs de démonstration, décalés d'une case vers -Z en 0.0.3.14 pour libérer l'apparition en 0, 0.
func _create_blocks() -> void:
	for x in range(-4, 5):
		for z in range(-6, 0):
			add_block(Vector3i(x, 0, z), 0 if (x + z) % 2 == 0 else 1)
	for x in range(-4, 0):
		for y in range(1, 3):
			add_block(Vector3i(x, y, -6), 0)
	for y in range(1, 4):
		add_block(Vector3i(4, y, -5), 1)
	for x in range(1, 4):
		for y in range(x):
			add_block(Vector3i(x, y, 2), 1)
	for x in range(-3, 0):
		add_block(Vector3i(x, 0, 4), 0)

func add_block(cell: Vector3i, kind: int) -> bool:
	if blocks.has(cell) or blocks.size() >= MAX_BLOCKS:
		return false
	if kind < 0 or kind >= materials.size():
		return false
	var block := StaticBody3D.new()
	block.name = "Block"
	block.position = Vector3(cell) + Vector3.ONE * 0.5
	block.set_meta("cell", cell)
	block.set_meta("kind", kind)
	block.add_to_group("blocks")
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.material_override = materials[kind]
	block.add_child(mesh)
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	block.add_child(collision)
	add_child(block)
	blocks[cell] = block
	return true

# reach : portée de l'action (casse ou pose), réglable dans Attributs → Blocs.
func _valid_hit(hit: Dictionary, reach: float) -> bool:
	if hit.is_empty() or not is_instance_valid(hit.get("collider")):
		return false
	if player.camera.global_position.distance_to(hit.position) > reach + 0.01:
		return false
	return hit.collider.is_in_group("blocks") or hit.collider.is_in_group("ground")

func break_target(hit: Dictionary) -> bool:
	if not _valid_hit(hit, player.break_reach):
		return false
	var collider: Node = hit.collider
	if not collider.is_in_group("blocks"):
		_notify("Le sol est indestructible. Visez un bloc ou une colline.")
		return false
	var cell: Vector3i = collider.get_meta("cell")
	blocks.erase(cell)
	remove_child(collider)
	collider.queue_free()
	return true

func place_target(hit: Dictionary, kind: int) -> bool:
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
	return add_block(cell, kind)

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
	selected_block_label = Label.new()
	selected_block_label.name = "SelectedBlock"
	selected_block_label.position = Vector2(18, 18)
	selected_block_label.add_theme_font_size_override("font_size", roundi(18 * text_scale))
	selected_block_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	selected_block_label.add_theme_constant_override("shadow_outline_size", 3)
	selected_block_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(selected_block_label)
	update_selected_block()
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

func update_selected_block() -> void:
	if is_instance_valid(selected_block_label) and is_instance_valid(player):
		selected_block_label.text = "Bloc sélectionné : %s" % BLOCK_NAMES[player.selected_type]

func _notify(message: String) -> void:
	notice = message
	notice_time = 2.5

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	notice_time = maxf(0.0, notice_time - delta)
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var hit: Dictionary = player.get_target()
	selection.visible = captured and not hit.is_empty() and hit.collider.is_in_group("blocks")
	if selection.visible:
		selection.global_position = hit.collider.global_position
	hint.text = notice if notice_time > 0.0 else ""
	_update_coordinates()

# level : 0 = −, 1 = Par défaut, 2 = + (textes complets d'avant 0.0.3.3), selon Synthèse des textes.
static func get_help_text(level: int = 2) -> String:
	if level == 0:
		return "ZQSD : marcher. Espace : sauter. Clic gauche : casser ; clic droit : poser.
Molette : bloc. Échap : pause. F1 : mondes."
	if level == 1:
		return "ZQSD / WASD / flèches : marcher. Souris : regarder. Espace : sauter.
Y : se baisser. R : courir (mode dans Contrôles).
Maintenir clic gauche : casser ; clic droit : poser. Molette : changer de bloc.
Échap : pause. F1 : liste des mondes. F2 : Comment jouer. F3 : Informations.
Portée : %d blocs. Maximum : %d blocs, hauteur %d (Y 0 sur le sol plat).
Constructions réinitialisées en quittant le monde.
Touches modifiables : Paramètres → Contrôles." % [int(PlayerScript.REACH), MAX_BLOCKS, MAX_BUILD_HEIGHT]
	return "ZQSD / WASD / flèches : marcher. Souris : regarder. Espace : sauter.
Y : se baisser. R : courir. Modes dans Contrôles : Maintenir, Basculer,
et pour courir Maintenir conditionnel (un appui lance la course ; s'arrêter,
sauter, se baisser ou la pause l'arrêtent, puis il faut réappuyer sur R).

Maintenir clic gauche : casser ; clic droit : poser.
Première action immédiate, puis répétition selon les paramètres des blocs.
Relâcher ou mettre en pause arrête la répétition.

Molette : changer de bloc.
Le sable reste immobile, même sans support.

Échap : pause et souris libre. Reprendre / Échap : retour direct au jeu.
Le clic de capture ne casse ni ne pose. F1 : liste des mondes.
F2 : Comment jouer. F3 : Informations du monde (jeu en pause).

Portée : %d blocs. Base protégée. Maximum : %d blocs présents.
Hauteur maximale : %d blocs au-dessus du sol plat, collines comprises (sommet à Y %d).
Construction : %s.
%s

Nom, graine et mode conservés ; constructions réinitialisées en quittant le monde.
Touches modifiables (clavier, clics, molette) : Paramètres → Contrôles, aussi depuis la pause." % [int(PlayerScript.REACH), MAX_BLOCKS, MAX_BUILD_HEIGHT, MAX_BUILD_HEIGHT, build_range_text(), COORDINATES_NOTE]

func get_world_info_text(level: int = 2) -> String:
	# Position du joueur (0.0.3.14), en tête, à tous les niveaux de détail.
	var who: String = CharacterPreview.CHARACTERS.get(player.character, CharacterPreview.CHARACTERS.boy14).name
	if CharacterPreview.is_human(player.character):
		who += ", " + CharacterPreview.SKINS.get(player.skin, CharacterPreview.SKINS.light).name.to_lower()
	return "Votre position actuelle : %s
Personnage : %s
%s" % [coordinates_text(), who, _world_info_body(level)]

func _world_info_body(level: int) -> String:
	var span := TerrainGenerator.MAX_CELL - TerrainGenerator.MIN_CELL + 1
	if level == 0:
		return "Monde : %s · Graine : %d
Mode : %s" % [world_name, terrain_seed, world_mode_text]
	if level == 1:
		return "Monde : %s
Graine : %d
Mode : %s
Collines : %d, jusqu'à %d blocs. Base %d × %d.
Constructions non sauvegardées." % [world_name, terrain_seed, world_mode_text, generated_hill_count, generated_max_height, int(BASE_SIZE.x), int(BASE_SIZE.z)]
	var mode_line := "Mode : %s — %s" % [world_mode_text, "attributs de Paramètres → Attributs" if developer_mode else "attributs par défaut, non modifiables"]
	return "Monde : %s
Graine : %d
%s

Collines générées : %d
Hauteur maximale initiale des collines : %d blocs (sommet à Y %d)
Zone de génération : largeur %d × longueur %d blocs (%s)

Base plate : largeur %d × longueur %d blocs (%s), sol à Y 0
Construction : hauteur maximale %d blocs au-dessus du sol plat (sommet à Y %d), %s.
%s

Nom, graine et mode conservés ; constructions non sauvegardées." % [world_name, terrain_seed, mode_line, generated_hill_count, generated_max_height, generated_max_height, span, span, generation_range_text(), int(BASE_SIZE.x), int(BASE_SIZE.z), base_range_text(), MAX_BUILD_HEIGHT, MAX_BUILD_HEIGHT, build_range_text(), COORDINATES_NOTE]
