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

# 0.0.8.6 (demande de l'utilisateur : la liane était un petit anneau parfait, pas réaliste et perdu dans l'herbe) : une
# vraie liane d'environ 3 m, épaisse d'environ 1,5 cm, enroulée en boucles irrégulières d'environ 40 cm, couchée, avec
# quelques feuilles. Deux surfaces : la tige (vert-brun) et les feuilles (vertes, visibles des deux côtés).
const LIANE_LENGTH := 3.0
const LIANE_RADIUS := 0.0075
static var _stem_material: StandardMaterial3D
static var _leaf_material: StandardMaterial3D

static func coil_mesh() -> ArrayMesh:
	if _coil != null:
		return _coil
	var rng := RandomNumberGenerator.new()
	rng.seed = 2131
	# Le chemin : des boucles de rayon un peu différent, qui se décalent et montent à peine les unes sur les autres.
	var path := PackedVector3Array()
	var steps := 90
	var turns := LIANE_LENGTH / (TAU * 0.2)
	for index in range(steps + 1):
		var t := float(index) / steps
		var angle := t * turns * TAU
		var loop := 0.17 + 0.05 * sin(t * 7.0) + rng.randf_range(-0.008, 0.008)
		var drift := Vector3(0.04 * sin(t * 5.0), 0.0, 0.05 * cos(t * 3.0))
		path.append(Vector3(cos(angle) * loop, LIANE_RADIUS + 0.01 * (0.5 + 0.5 * sin(angle * 0.5 + t * 4.0)), sin(angle) * loop) + drift)
	var stem := SurfaceTool.new()
	stem.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	for index in range(steps):
		var a := path[index]
		var b := path[index + 1]
		var along := (b - a).normalized()
		var side := along.cross(Vector3.UP).normalized()
		var up := side.cross(along).normalized()
		for k in range(sides):
			var angle_a := TAU * k / sides
			var angle_b := TAU * (k + 1) / sides
			var oa := (side * cos(angle_a) + up * sin(angle_a)) * LIANE_RADIUS
			var ob := (side * cos(angle_b) + up * sin(angle_b)) * LIANE_RADIUS
			for corner in [[a, oa], [b, oa], [b, ob], [a, oa], [b, ob], [a, ob]]:
				stem.set_normal((corner[1] as Vector3).normalized())
				stem.add_vertex(corner[0] + corner[1])
	_coil = ArrayMesh.new()
	_coil.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, stem.commit_to_arrays())
	_coil.surface_set_material(0, _liane_material(false))
	# Feuilles : une tous les quelques pas, en forme de cœur allongé, à plat un peu relevées.
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(4, steps, 7):
		var at := path[index]
		var along := (path[index + 1] - at).normalized()
		var out := along.cross(Vector3.UP).normalized() * (1.0 if index % 2 == 0 else -1.0)
		var size := rng.randf_range(0.035, 0.05)
		var tip := at + out * size * 1.6 + Vector3.UP * 0.012
		var left := at + out * size * 0.6 + along * size * 0.5 + Vector3.UP * 0.008
		var right := at + out * size * 0.6 - along * size * 0.5 + Vector3.UP * 0.008
		for corner in [at, left, tip, at, tip, right]:
			leaves.set_normal(Vector3.UP)
			leaves.add_vertex(corner)
	_coil.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, leaves.commit_to_arrays())
	_coil.surface_set_material(1, _liane_material(true))
	return _coil

static func _liane_material(leaf: bool) -> StandardMaterial3D:
	if leaf and _leaf_material != null:
		return _leaf_material
	if not leaf and _stem_material != null:
		return _stem_material
	var made := StandardMaterial3D.new()
	made.albedo_color = Color("#4f7a2c") if leaf else Color("#5d6b34")
	made.roughness = 0.9
	if leaf:
		made.cull_mode = BaseMaterial3D.CULL_DISABLED
		_leaf_material = made
	else:
		_stem_material = made
	return made

# 0.0.8.5 : rouleau de ficelle (environ 9 cm de large), plus fin que la liane.
static var _cord: ArrayMesh

static func cord_mesh() -> ArrayMesh:
	if _cord != null:
		return _cord
	var ring := TorusMesh.new()
	ring.inner_radius = 0.035
	ring.outer_radius = 0.045
	ring.rings = 14
	ring.ring_segments = 5
	_cord = ArrayMesh.new()
	_cord.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ring.get_mesh_arrays())
	return _cord
