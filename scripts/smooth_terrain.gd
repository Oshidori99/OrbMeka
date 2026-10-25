extends RefCounted
# 0.0.5.8 (étape 3 du Monde, #120) : terrain lisse sculptable, première version.
# Chaque bloc de 1 m est divisé en 2 × 2 × 2 = 8 sous-cellules de 50 cm (STEP). Une zone de 8 m
# contient donc 16 × 16 × 16 sous-cellules ; sa grille de points, bords compris, en a 17 par axe.
# Chaque point porte une densité : positive = plein (terre), négative ou nulle = air.
# Le sol de la graine est calculé (base_density), seuls les points changés sont gardés et enregistrés.
# Rendu lisse : « surface nets » (un sommet par sous-cellule traversée par la surface, au milieu des
# passages de la surface sur ses arêtes), une pièce par zone. Zone sans changement : simple carré plat.
const STEP := 0.5
const POINTS := 16
const ZONE_SIZE := 8
# Profondeur et hauteur qu'on peut sculpter, en points (−3,5 m à +4 m) ; la base reste dessous.
const LOW_POINT := -7
const HIGH_POINT := 8
const MAX_CHANGES := 20000
# Valeurs posées par un geste : une sous-cellule creusée ou ajoutée.
const DUG := -0.5
const ADDED := 0.5

# Point (indice de la grille, en pas de 50 cm) → densité changée ; rangés aussi par zone et par colonne.
var changes: Dictionary = {}
var by_zone: Dictionary = {}
var columns: Dictionary = {}

# Sol plat de la graine : surface à Y 0 (pas encore de relief, étape 4).
static func base_density(point: Vector3i) -> float:
	return clampf(-point.y * STEP, -1.0, 1.0)

func density(point: Vector3i) -> float:
	return changes.get(point, base_density(point))

static func point_zone(point: Vector3i) -> Vector3i:
	return Vector3i(floori(point.x / float(POINTS)), floori(point.y / float(POINTS)), floori(point.z / float(POINTS)))

static func point_of(position: Vector3) -> Vector3i:
	return Vector3i(roundi(position.x / STEP), roundi(position.y / STEP), roundi(position.z / STEP))

# Une zone lit les points de son coin − 1 à son coin + 16 : zones qui dépendent d'un point.
static func zones_using(point: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for x in range(ceili((point.x - POINTS) / float(POINTS)), floori((point.x + 1) / float(POINTS)) + 1):
		for y in range(ceili((point.y - POINTS) / float(POINTS)), floori((point.y + 1) / float(POINTS)) + 1):
			for z in range(ceili((point.z - POINTS) / float(POINTS)), floori((point.z + 1) / float(POINTS)) + 1):
				result.append(Vector3i(x, y, z))
	return result

# 0.0.5.9 : matière d'un point posé (0 sable, 2 terre, comme les blocs) ; sans matière : sol de la graine.
var materials: Dictionary = {}
const SAND := 0
const DIRT := 2

func material(point: Vector3i) -> int:
	return materials.get(point, -1)

func set_density(point: Vector3i, value: float, kind: int = -1) -> void:
	# Millièmes, comme dans le fichier : le terrain rouvert est exactement le même.
	value = roundf(value * 1000.0) / 1000.0
	var zone := point_zone(point)
	var column := Vector2i(point.x, point.z)
	if changes.has(point):
		changes.erase(point)
		by_zone[zone].erase(point)
		columns[column] -= 1
		if columns[column] == 0:
			columns.erase(column)
	if kind >= 0 and value > 0.0:
		materials[point] = kind
	elif value <= 0.0:
		materials.erase(point)
	if is_equal_approx(value, base_density(point)) and not materials.has(point):
		return
	changes[point] = value
	if not by_zone.has(zone):
		by_zone[zone] = {}
	by_zone[zone][point] = true
	columns[column] = columns.get(column, 0) + 1

# Herbe : seulement là où rien n'a été sculpté (colonne du point et ses voisines).
func column_changed(column: Vector2i) -> bool:
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if columns.has(column + Vector2i(dx, dz)):
				return true
	return false

# Sauvegarde : points changés d'une zone, densité en millièmes (nombres entiers), puis la matière si posée (0.0.5.9).
func zone_entries(zone: Vector3i) -> Array:
	var result: Array = []
	for point: Vector3i in by_zone.get(zone, {}):
		var entry := [point.x, point.y, point.z, roundi(changes[point] * 1000.0)]
		if materials.has(point):
			entry.append(materials[point])
		result.append(entry)
	return result

func load_entries(entries: Array) -> void:
	for entry in entries:
		set_density(Vector3i(entry[0], entry[1], entry[2]), clampf(entry[3] / 1000.0, -1.0, 1.0), entry[4] if entry.size() > 4 and entry[4] in [SAND, DIRT] else -1)

# Zone plate : aucun point changé parmi ceux qu'elle lit.
func is_flat(zone: Vector3i) -> bool:
	var low := zone * POINTS - Vector3i.ONE
	var high := zone * POINTS + Vector3i.ONE * POINTS
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				for point: Vector3i in by_zone.get(zone + Vector3i(dx, dy, dz), {}):
					if point.x >= low.x and point.y >= low.y and point.z >= low.z and point.x <= high.x and point.y <= high.y and point.z <= high.z:
						return false
	return true

# Zones qui ont une surface : le sol plat (zones juste sous Y 0) et celles qui lisent un point changé.
static func ground_zone(zone: Vector3i) -> bool:
	return zone.y == -1

func surface_zones(low_zone: Vector2i, high_zone: Vector2i) -> Dictionary:
	var result := {}
	for x in range(low_zone.x, high_zone.x + 1):
		for z in range(low_zone.y, high_zone.y + 1):
			result[Vector3i(x, -1, z)] = true
	for point: Vector3i in changes:
		for zone in zones_using(point):
			if zone.x >= low_zone.x and zone.x <= high_zone.x and zone.z >= low_zone.y and zone.z <= high_zone.y:
				result[zone] = true
	return result

# Maillage lisse d'une zone (coordonnées du monde) : [sommets, normales], triangles dans le sens
# des aiguilles d'une montre vus de dehors, comme les blocs. Vide si la surface ne passe pas.
func zone_mesh(zone: Vector3i) -> Array:
	var origin := zone * POINTS
	# Hauteurs utiles seulement : là où la surface peut passer (sol, points changés).
	var y_low := maxi(origin.y - 1, LOW_POINT - 2)
	var y_high := mini(origin.y + POINTS, HIGH_POINT + 2)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	if y_low >= y_high:
		return [vertices, normals, colors]
	var size := POINTS + 2
	var height := y_high - y_low + 1
	var start := Vector3i(origin.x - 1, y_low, origin.z - 1)
	var values := PackedFloat32Array()
	values.resize(size * height * size)
	var kinds := {}
	for y in range(height):
		var base := base_density(Vector3i(0, y_low + y, 0))
		for x in range(size):
			for z in range(size):
				values[(x * height + y) * size + z] = base
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				for point: Vector3i in by_zone.get(zone + Vector3i(dx, dy, dz), {}):
					var local := point - start
					if local.x >= 0 and local.y >= 0 and local.z >= 0 and local.x < size and local.y < height and local.z < size:
						values[(local.x * height + local.y) * size + local.z] = changes[point]
						if materials.has(point):
							kinds[local] = materials[point]
	var at := func(local: Vector3i) -> float:
		return values[(local.x * height + local.y) * size + local.z]
	# Un sommet par sous-cellule traversée : moyenne des passages sur ses 12 arêtes ; normale = pente de la densité.
	var cell_vertex := {}
	var cell_normal := {}
	var cell_color := {}
	for x in range(size - 1):
		for y in range(height - 1):
			for z in range(size - 1):
				var corners: Array[float] = []
				var solid := 0
				for index in range(8):
					var value: float = at.call(Vector3i(x + (index & 1), y + ((index >> 1) & 1), z + ((index >> 2) & 1)))
					corners.append(value)
					if value > 0.0:
						solid += 1
				if solid == 0 or solid == 8:
					continue
				var sum := Vector3.ZERO
				var count := 0
				for index in range(8):
					for axis in [1, 2, 4]:
						if index & axis:
							continue
						var a: float = corners[index]
						var b: float = corners[index | axis]
						if (a > 0.0) == (b > 0.0):
							continue
						var t := a / (a - b)
						var from := Vector3(index & 1, (index >> 1) & 1, (index >> 2) & 1)
						var to := Vector3((index | axis) & 1, ((index | axis) >> 1) & 1, ((index | axis) >> 2) & 1)
						sum += from.lerp(to, t)
						count += 1
				var cell := Vector3i(x, y, z)
				cell_vertex[cell] = (Vector3(start + cell) + sum / count) * STEP
				var slope := Vector3(
					corners[1] + corners[3] + corners[5] + corners[7] - corners[0] - corners[2] - corners[4] - corners[6],
					corners[2] + corners[3] + corners[6] + corners[7] - corners[0] - corners[1] - corners[4] - corners[5],
					corners[4] + corners[5] + corners[6] + corners[7] - corners[0] - corners[1] - corners[2] - corners[3])
				cell_normal[cell] = (-slope).normalized() if slope.length_squared() > 0.000001 else Vector3.UP
				# Couleur des sommets (0.0.5.9) : alpha 0 = sable posé, bleu 0 = terre nue posée, blanc = sol de la graine.
				var paint := Vector2.ZERO
				var weight := 0
				for index in range(8):
					if corners[index] > 0.0:
						var kind: int = kinds.get(Vector3i(x + (index & 1), y + ((index >> 1) & 1), z + ((index >> 2) & 1)), -1)
						paint += Vector2(1.0 if kind == SAND else 0.0, 1.0 if kind == DIRT else 0.0)
						weight += 1
				paint /= maxf(weight, 1)
				cell_color[cell] = Color(1.0, 1.0, 1.0 - paint.y, 1.0 - paint.x)
	# Une face par arête traversée, entre les 4 sous-cellules qui la partagent ; la zone garde les arêtes
	# qui partent de ses propres points (pas de double avec la zone voisine).
	var axes := [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)]
	for axis_index in range(3):
		var axis: Vector3i = axes[axis_index]
		var side_a: Vector3i = axes[(axis_index + 1) % 3]
		var side_b: Vector3i = axes[(axis_index + 2) % 3]
		for x in range(1, size - 1):
			for y in range(maxi(1, origin.y - y_low), mini(height - 1, origin.y + POINTS - y_low)):
				for z in range(1, size - 1):
					var point := Vector3i(x, y, z)
					var next := point + axis
					if next.y >= height:
						continue
					var first: float = at.call(point)
					if (first > 0.0) == (at.call(next) > 0.0):
						continue
					var quad := [point, point - side_a, point - side_a - side_b, point - side_b]
					if quad.any(func(cell): return not cell_vertex.has(cell)):
						continue
					var outward := Vector3(axis) if first > 0.0 else -Vector3(axis)
					for triangle in [[0, 1, 2], [0, 2, 3]]:
						var a: Vector3 = cell_vertex[quad[triangle[0]]]
						var b: Vector3 = cell_vertex[quad[triangle[1]]]
						var c: Vector3 = cell_vertex[quad[triangle[2]]]
						var order := [quad[triangle[0]], quad[triangle[1]], quad[triangle[2]]]
						if (c - a).cross(b - a).dot(outward) < 0.0:
							order = [order[0], order[2], order[1]]
						for cell in order:
							vertices.append(cell_vertex[cell])
							normals.append(cell_normal[cell])
							colors.append(cell_color[cell])
	return [vertices, normals, colors]

# Carré plat d'une zone sans changement (8 m, du milieu de la sous-cellule −1 au bord suivant).
static func flat_mesh() -> ArrayMesh:
	var low := -STEP / 2.0
	var high := float(ZONE_SIZE)
	var corners := [Vector3(low, 0, low), Vector3(high, 0, low), Vector3(high, 0, high), Vector3(low, 0, high)]
	var vertices := PackedVector3Array([corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]])
	var normals := PackedVector3Array()
	for index in range(6):
		normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
