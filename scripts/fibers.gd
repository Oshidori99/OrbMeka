extends RefCounted
# 0.0.8.4 (#213, demandes de l'utilisateur) : fibres et lianes. Récolte : R maintenu HARVEST_SECONDS (Créatif :
# HARVEST_SECONDS_CREATIVE) sur une ortie, du lin ou des herbes longues : 1 à 3 fibres ; la plante reste coupée (tige
# basse, enregistrée dans objets.json, pas encore de repousse). Sur un tilleul à liane : une liane ; la liane disparaît
# du tronc. Modèles faits en code : une petite botte de brins (fibre), un rouleau (liane).
const PLANT_ITEMS := ["fibre_ortie", "fibre_lin", "fibre_herbe"]
const LIANE := "liane"
const HARVEST_SECONDS := 1.0
const HARVEST_SECONDS_CREATIVE := 0.3
const FIBERS_MIN := 1
const FIBERS_MAX := 3
# Plante coupée : hauteur gardée (part de sa hauteur).
const CUT_HEIGHT := 0.2
# Visée d'une plante : rayon (part de sa largeur) et hauteur (part de sa hauteur) du cylindre visé.
const AIM_RADIUS := 0.3
const AIM_HEIGHT := 0.8

static var _bundle: ArrayMesh
static var _coil: ArrayMesh

static func is_fiber(id: String) -> bool:
	return id in PLANT_ITEMS

# Identifiant stable d'une plante de la graine (sa place, au centimètre).
static func plant_id(plant: Dictionary) -> String:
	return "%d:%d" % [roundi(float(plant.x) * 100.0), roundi(float(plant.z) * 100.0)]

# Nombre de fibres d'une plante (même graine : même nombre).
static func fiber_count(plant: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(plant_id(plant) + "/fibres")
	return rng.randi_range(FIBERS_MIN, FIBERS_MAX)

# Botte de brins couchée (25 cm de long, en mètres), le long de x.
static func bundle_mesh() -> ArrayMesh:
	if _bundle != null:
		return _bundle
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 213
	for strand in range(7):
		var offset := Vector3(0.0, rng.randf_range(0.0, 0.012), rng.randf_range(-0.012, 0.012))
		var bend := rng.randf_range(-0.02, 0.02)
		var half := 0.125 + rng.randf_range(-0.02, 0.02)
		var width := 0.0025
		var a := offset + Vector3(-half, 0.0, 0.0)
		var b := offset + Vector3(half, 0.0, bend)
		for side in [Vector3.UP, Vector3.BACK]:
			var w: Vector3 = side * width
			surface.set_normal(Vector3.UP)
			surface.add_vertex(a - w)
			surface.add_vertex(b - w)
			surface.add_vertex(b + w)
			surface.add_vertex(a - w)
			surface.add_vertex(b + w)
			surface.add_vertex(a + w)
	_bundle = surface.commit()
	return _bundle

# Rouleau de liane (environ 20 cm de large), couché.
static func coil_mesh() -> ArrayMesh:
	if _coil != null:
		return _coil
	var ring := TorusMesh.new()
	ring.inner_radius = 0.075
	ring.outer_radius = 0.1
	ring.rings = 16
	ring.ring_segments = 6
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ring.get_mesh_arrays())
	_coil = made
	return _coil
