extends RefCounted
# 0.0.8.44 (#214, #209, demandes de l'utilisateur) : le feu de camp et les torches. Modèles simples faits ici (les beaux
# modèles viendront de Blender, plus tard), lumières, durées. Une durée se compte en minutes du jeu (24 min réelles = une
# journée de 1 440 minutes, réglable par monde) :
# - torche : 10 heures de jeu, lumière jusqu'à 8 m ; torche forte (écorce de pin résineuse) : 5 heures, 2 fois plus de
#   lumière et 2 fois plus loin (16 m) ;
# - feu de camp : monté avec des cailloux, du bois et de l'amadou (O + F → Monter un feu), posé au sol (clic droit),
#   allumé à l'archet à feu (clic droit maintenu FIRE_LIGHT_SECONDS), nourri avec du bois ou du charbon (plus long) ;
#   éteint quand il n'a plus rien à brûler (on le nourrit et on le rallume).
const TORCH_MINUTES := {"torche": 600.0, "torche_forte": 300.0}
const TORCH_RANGE := {"torche": 8.0, "torche_forte": 16.0}
const TORCH_ENERGY := {"torche": 1.6, "torche_forte": 3.2}
# Le feu éclaire plus que la torche simple (demande de l'utilisateur), moins loin que la torche forte.
const FIRE_RANGE := 14.0
const FIRE_ENERGY := 3.0
# Ce qu'un feu neuf a à brûler (le bois de sa fabrication), puis ce qu'ajoute chaque morceau (minutes de jeu).
const FIRE_START := 120.0
const FUEL := {"branche": 60.0, "tronc": 120.0, "charbon": 180.0, "ecorce": 15.0, "ecorce_pin": 20.0}
const FIRE_MAX := 720.0
const FIRE_LIGHT_SECONDS := 10.0
const TORCH_LIGHT_SECONDS := 1.0
const FEED_SECONDS := 0.5
const FLAME := Color("#ffb062")
# Au plus ce nombre de lumières de feux et de torches posés à la fois (les plus proches ; le Web compte chaque lumière).
const MAX_LIGHTS := 8
const LIGHT_FADE_BEGIN := 30.0
const LIGHT_FADE_LENGTH := 15.0

static func is_lit(value: Dictionary) -> bool:
	return int(value.get("allume", 0)) == 1

static func is_torch(value: Dictionary) -> bool:
	return value.get("objet", "") in TORCH_MINUTES

static func is_fire(value: Dictionary) -> bool:
	return value.get("objet", "") == "feu_camp"

# Lumière d'un feu ou d'une torche allumés (portée, force).
static func light_spec(value: Dictionary) -> Vector2:
	if is_fire(value):
		return Vector2(FIRE_RANGE, FIRE_ENERGY)
	var id: String = value.get("objet", "torche")
	return Vector2(float(TORCH_RANGE.get(id, 8.0)), float(TORCH_ENERGY.get(id, 1.6)))

static func make_light(value: Dictionary) -> OmniLight3D:
	var made := OmniLight3D.new()
	made.name = "LumiereFeu"
	made.light_color = FLAME
	var spec := light_spec(value)
	made.omni_range = spec.x
	made.light_energy = spec.y
	made.shadow_enabled = false
	made.distance_fade_enabled = true
	made.distance_fade_begin = LIGHT_FADE_BEGIN
	made.distance_fade_length = LIGHT_FADE_LENGTH
	return made

# Une torche allumée qui brûle « minutes » de jeu de plus : elle-même, ou le bâton brûlé quand elle est finie.
static func burn(value: Dictionary, minutes: float) -> Dictionary:
	if not is_lit(value):
		return value
	var made := value.duplicate(true)
	made.brule = maxf(float(value.get("brule", 0.0)) - minutes, 0.0)
	if made.brule > 0.0:
		return made
	if is_fire(made):
		made.allume = 0
		return made
	# La torche finie : un bâton brûlé (court, noirci).
	var stick := {"objet": "branche", "brulee": 1, "essence": int(value.get("essence", 1)), "epaisseur": float(value.get("epaisseur", 3.0)), "fin": float(value.get("fin", 2.6)), "longueur": snappedf(float(value.get("longueur", 0.55)) * 0.8, 0.01), "poids": snappedf(float(value.get("poids", 260.0)) * 0.6, 1.0)}
	return stick

# --- Modèles simples ---
static var _meshes := {}

static func _part(tool: SurfaceTool, mesh: PrimitiveMesh, place: Transform3D) -> void:
	tool.append_from(mesh, 0, place)

# Feu de camp : un cercle de pierres, trois bûches croisées ; allumé : des flammes au milieu.
static func campfire_mesh(lit: bool) -> ArrayMesh:
	var key := "feu/%d" % int(lit)
	if _meshes.has(key):
		return _meshes[key]
	var made := ArrayMesh.new()
	var stones := SurfaceTool.new()
	stones.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone := SphereMesh.new()
	stone.radius = 0.09
	stone.height = 0.12
	stone.radial_segments = 6
	stone.rings = 3
	for index in range(8):
		var angle := TAU * index / 8.0
		_part(stones, stone, Transform3D(Basis().scaled(Vector3(1.0, 0.8, 1.15)), Vector3(cos(angle) * 0.33, 0.04, sin(angle) * 0.33)))
	stones.generate_normals()
	stones.commit(made)
	var logs := SurfaceTool.new()
	logs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.035
	log_mesh.bottom_radius = 0.045
	log_mesh.height = 0.5
	log_mesh.radial_segments = 6
	log_mesh.rings = 1
	for index in range(3):
		var angle := TAU * index / 3.0
		var lean := Basis(Vector3(cos(angle), 0.0, sin(angle)).cross(Vector3.UP).normalized(), 1.15)
		_part(logs, log_mesh, Transform3D(Basis(Vector3.UP, -angle) * lean, Vector3(cos(angle) * 0.08, 0.1, sin(angle) * 0.08)))
	logs.generate_normals()
	logs.commit(made)
	made.surface_set_material(0, _material("pierre", Color("#7d7a75"), false))
	made.surface_set_material(1, _material("bois_brule" if lit else "bois", Color("#3b2a1e") if lit else Color("#6b4a2e"), false))
	if lit:
		_add_flame(made, Vector3(0.0, 0.08, 0.0), 0.34)
	_meshes[key] = made
	return made

# Flammes : trois cônes lumineux (sans ombre).
static func _add_flame(made: ArrayMesh, at: Vector3, height: float) -> void:
	var flames := SurfaceTool.new()
	flames.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = height * 0.32
	cone.height = height
	cone.radial_segments = 6
	cone.rings = 1
	for index in range(3):
		var angle := TAU * index / 3.0
		var shift := Vector3(cos(angle), 0.0, sin(angle)) * height * 0.12
		var tall := 1.0 - 0.18 * index
		_part(flames, cone, Transform3D(Basis().scaled(Vector3(1.0, tall, 1.0)), at + shift + Vector3.UP * height * 0.5 * tall))
	flames.generate_normals()
	flames.commit(made)
	made.surface_set_material(made.get_surface_count() - 1, _material("flamme", FLAME, true))

# Le bout d'une torche allumée (au bout du bâton, repère du bâton : y de 0 à 1) : une flamme.
static func torch_flame_mesh() -> ArrayMesh:
	if _meshes.has("torche"):
		return _meshes.torche
	var made := ArrayMesh.new()
	_add_flame(made, Vector3.ZERO, 0.16)
	_meshes.torche = made
	return made

static var _materials := {}

static func _material(key: String, color: Color, glowing: bool) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var made := StandardMaterial3D.new()
	made.albedo_color = color
	made.roughness = 0.9
	if glowing:
		made.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		made.emission_enabled = true
		made.emission = color
	_materials[key] = made
	return made
