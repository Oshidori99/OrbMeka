extends RefCounted
# 0.0.8.2 (#231, demande de l'utilisateur) : orbe de retour, objet de Survie pour ne jamais rester coincé. 200 g, 2 dl
# (une boule ; dessinée de SIZE). Usage unique : en main, clic droit maintenu USE_SECONDS : retour au point de départ, puis elle
# disparaît ; un clic court la pose, comme un objet. Au début : une dans une poche et une deuxième posée au sol près du
# point de départ, en réserve. Le dessin est propre à OrbMeka : une boule turquoise lumineuse cerclée d'un anneau doré.
const ID := "orbe_retour"
const COLOR := Color("#3fd6c8")
const RING := Color("#e2b85a")
# 0.0.8.3 (demande de l'utilisateur) : dessinée plus grande (11 cm, avant 7) pour la voir dans l'herbe ; poids et volume
# inchangés (200 g, 2 dl). Brillante (reflets), elle luit et éclaire un peu autour d'elle au sol (LIGHT_*), de nuit aussi.
const SIZE := 0.11
const LIGHT_RANGE := 2.5
const LIGHT_ENERGY := 0.8
const USE_SECONDS := 1.0
# Orbe de réserve posée au sol, à côté du point de départ.
const RESERVE_OFFSET := Vector3(1.2, 0.0, 0.8)

static var _material: StandardMaterial3D
static var _ring_material: StandardMaterial3D
static var _mesh: ArrayMesh

# Boule de diamètre 1 (mise à SIZE par l'appelant) avec un fin anneau doré autour de l'équateur.
static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 20
	ball.rings = 10
	var ring := TorusMesh.new()
	ring.inner_radius = 0.5
	ring.outer_radius = 0.58
	ring.rings = 20
	ring.ring_segments = 6
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ball.get_mesh_arrays())
	_mesh.surface_set_material(0, material())
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ring.get_mesh_arrays())
	_mesh.surface_set_material(1, ring_material())
	return _mesh

static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = COLOR
		_material.roughness = 0.08
		_material.metallic = 0.2
		_material.metallic_specular = 0.9
		_material.clearcoat_enabled = true
		_material.clearcoat = 1.0
		_material.rim_enabled = true
		_material.rim = 0.6
		_material.emission_enabled = true
		_material.emission = COLOR
		_material.emission_energy_multiplier = 1.6
	return _material

static func ring_material() -> StandardMaterial3D:
	if _ring_material == null:
		_ring_material = StandardMaterial3D.new()
		_ring_material.albedo_color = RING
		_ring_material.metallic = 0.7
		_ring_material.roughness = 0.35
	return _ring_material

static func is_orb(value: Dictionary) -> bool:
	return value.get("objet", "") == ID

# Petite lumière turquoise d'une orbe posée (sans ombre, pour rester légère).
static func light() -> OmniLight3D:
	var made := OmniLight3D.new()
	made.name = "LumiereOrbe"
	made.light_color = COLOR
	made.light_energy = LIGHT_ENERGY
	made.omni_range = LIGHT_RANGE
	made.shadow_enabled = false
	# 0.0.8.11 (rapport Web : chaque lumière redessine tout ce qu'elle touche en rendu Compatibility) : éteinte au-delà de
	# LIGHT_FADE_BEGIN + LIGHT_FADE_LENGTH m de la caméra, en s'estompant (à cette distance, sa lueur de 2,5 m ne se voit
	# presque plus ; l'orbe elle-même reste brillante).
	made.distance_fade_enabled = true
	made.distance_fade_begin = LIGHT_FADE_BEGIN
	made.distance_fade_length = LIGHT_FADE_LENGTH
	return made

const LIGHT_FADE_BEGIN := 20.0
const LIGHT_FADE_LENGTH := 8.0
