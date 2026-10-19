extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const TerrainGenerator = preload("res://scripts/terrain_generator.gd")
const DIRT := 2
const BLOCK_COLORS := [Color("#d8c291"), Color("#888b90"), Color("#855332")]
const BLOCK_NAMES := ["Sable", "Pierre", "Terre"]
const MAX_BLOCKS := 1200
const BASE_SIZE := Vector3(128, 1, 128)
const MAX_BUILD_HEIGHT := 25

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
	var bindings := {
		"move_forward": [KEY_W, KEY_Z, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_Q, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)

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
	# Check current blocks too, so respawning stays safe after construction.
	var top := 0
	for cell: Vector3i in blocks:
		if cell.x == 0 and cell.z == 8:
			top = maxi(top, cell.y + 1)
	return Vector3(0.5, top + 2.0, 8.5)

func _create_blocks() -> void:
	for x in range(-4, 5):
		for z in range(-5, 1):
			add_block(Vector3i(x, 0, z), 0 if (x + z) % 2 == 0 else 1)
	for x in range(-4, 0):
		for y in range(1, 3):
			add_block(Vector3i(x, y, -5), 0)
	for y in range(1, 4):
		add_block(Vector3i(4, y, -4), 1)
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

func _valid_hit(hit: Dictionary) -> bool:
	if hit.is_empty() or not is_instance_valid(hit.get("collider")):
		return false
	if player.camera.global_position.distance_to(hit.position) > player.REACH + 0.01:
		return false
	return hit.collider.is_in_group("blocks") or hit.collider.is_in_group("ground")

func break_target(hit: Dictionary) -> bool:
	if not _valid_hit(hit):
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
	if not _valid_hit(hit):
		return false
	var point: Vector3 = hit.position + hit.normal * 0.02
	var cell := Vector3i(floori(point.x), floori(point.y), floori(point.z))
	if cell.y < 0 or cell.y >= MAX_BUILD_HEIGHT or absi(cell.x) > 57 or absi(cell.z) > 57:
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

static func get_help_text() -> String:
	return "ZQSD / WASD / flèches : marcher. Souris : regarder. Espace : sauter.

Maintenir clic gauche : casser ; clic droit : poser.
Première action immédiate, puis répétition selon les paramètres des blocs.
Relâcher ou mettre en pause arrête la répétition.

Molette : changer de bloc.
Le sable reste immobile, même sans support.

Échap : pause et souris libre. Reprendre / Échap : retour direct au jeu.
Le clic de capture ne casse ni ne pose. F1 : liste des mondes.
F2 : Comment jouer. F3 : Informations du monde (jeu en pause).

Portée : %d blocs. Base protégée. Maximum : %d blocs présents.
Hauteur maximale : %d blocs au-dessus du sol plat, collines comprises.

Nom, graine et mode conservés ; constructions réinitialisées en quittant le monde." % [int(PlayerScript.REACH), MAX_BLOCKS, MAX_BUILD_HEIGHT]
func get_world_info_text() -> String:
	var span := TerrainGenerator.MAX_CELL - TerrainGenerator.MIN_CELL + 1
	var mode_line := "Mode : %s — %s" % [world_mode_text, "attributs de Paramètres → Attributs" if developer_mode else "attributs par défaut, non modifiables"]
	return "Monde : %s
Graine : %d
%s

Collines générées : %d
Hauteur maximale initiale des collines : %d blocs
Zone de génération : largeur %d × longueur %d blocs

Base plate : largeur %d × longueur %d blocs
Construction : hauteur maximale %d blocs au-dessus du sol plat.

Nom, graine et mode conservés ; constructions non sauvegardées." % [world_name, terrain_seed, mode_line, generated_hill_count, generated_max_height, span, span, int(BASE_SIZE.x), int(BASE_SIZE.z), MAX_BUILD_HEIGHT]