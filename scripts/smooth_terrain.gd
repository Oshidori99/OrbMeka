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
# Profondeur et hauteur qu'on peut sculpter, en points (−3,5 m à +4 m).
# 0.0.5.12 : sous le gazon, 4 m de terre (points −1 à −7), puis 4 m de pierre (STONE_TOP à −15),
# puis la Roche-mère (dès BEDROCK_TOP, à 8 m sous le sol), incassable, qui porte le monde.
# La pierre ne tombe jamais ; 0.0.5.13 : elle se casse avec la pioche (sélection), jusqu'à la Roche-mère.
const LOW_POINT := -7
const STONE_TOP := -8
const BEDROCK_TOP := -16
const HIGH_POINT := 8
const MAX_CHANGES := 20000
# Valeurs posées par un geste : une sous-cellule creusée ou ajoutée.
const DUG := -0.5
const ADDED := 0.5

# Point (indice de la grille, en pas de 50 cm) → densité changée ; rangés aussi par zone et par colonne.
var changes: Dictionary = {}
var by_zone: Dictionary = {}
var columns: Dictionary = {}

# 0.0.5.14 : petites collines de terre selon la graine (étape 4, #121, début), aplaties autour des endroits
# donnés (apparition, plage). Sans setup() (tests) : sol plat à Y 0.
# 0.0.5.15 (demandes de l'utilisateur) : collines jusqu'à 3 m, surtout douces ; petites bosses partout ;
# par zone de 8 m (CHUNK), au hasard de la graine : environ 1 sur 9 a une crête abrupte (ça monte puis
# ça tombe d'un coup), environ 1 sur 9 un trou, petit ou gros (jamais jusqu'à la pierre : 3,5 m au plus) ;
# environ 1 sur 8 est un petit désert (une zone), 1 sur 12 le départ d'un grand désert (3 ou 4 zones).
# Le gazon couvre tout le sol de la graine, trous compris ; les déserts sont en sable.
const HILL_HEIGHT := 3.0
const HILL_SIZE := 40.0
const BUMP_HEIGHT := 0.25
const DEEPEST := -3.5
const CHUNK := 8.0
const FEATURE_CHANCE := 1.0 / 9.0
const SMALL_DESERT_CHANCE := 1.0 / 8.0
const BIG_DESERT_CHANCE := 1.0 / 12.0
# Épaisseur du sable sous un désert (m), puis la terre.
const DESERT_SAND := 2.0
var _noise: FastNoiseLite
var _bumps: FastNoiseLite
var _warp: FastNoiseLite
var _seed := 0
var _flat_spots: Array = []
var _heights: Dictionary = {}
var _chunks: Dictionary = {}
var _deserts: Dictionary = {}

func setup(terrain_seed: int, flat_spots: Array = []) -> void:
	_seed = terrain_seed
	_noise = FastNoiseLite.new()
	_noise.seed = terrain_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0 / HILL_SIZE
	_noise.fractal_octaves = 3
	_bumps = FastNoiseLite.new()
	_bumps.seed = terrain_seed + 1
	_bumps.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_bumps.frequency = 1.0 / 9.0
	_warp = FastNoiseLite.new()
	_warp.seed = terrain_seed + 2
	_warp.frequency = 1.0 / 6.0
	_flat_spots = flat_spots
	_heights.clear()
	_chunks.clear()
	_deserts.clear()

# Ce que la graine met dans une zone de 8 m : crête, trou, désert (toujours pareil pour une graine).
func _chunk(chunk: Vector2i) -> Dictionary:
	if _chunks.has(chunk):
		return _chunks[chunk]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, chunk.x, chunk.y])
	var corner := Vector2(chunk) * CHUNK
	var info := {}
	if rng.randf() < FEATURE_CHANCE:
		info.hole = [corner + Vector2(rng.randf_range(2.0, 6.0), rng.randf_range(2.0, 6.0)), rng.randf_range(0.8, -DEEPEST - 0.1), rng.randf_range(1.5, 4.0)]
	if rng.randf() < FEATURE_CHANCE:
		var angle := rng.randf() * TAU
		info.ridge = [corner + Vector2(rng.randf_range(2.0, 6.0), rng.randf_range(2.0, 6.0)), Vector2(cos(angle), sin(angle)), rng.randf_range(1.2, 2.4), rng.randf_range(3.0, 5.0), rng.randf_range(2.5, 4.0)]
	info.small_desert = rng.randf() < SMALL_DESERT_CHANCE
	if rng.randf() < BIG_DESERT_CHANCE:
		var around := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
		info.big_desert = [Vector2i.ZERO] + around.slice(0, rng.randi_range(2, 3))
	_chunks[chunk] = info
	return info

# Relief rare d'une zone (et de ses voisines, qui peuvent déborder) au point « at » (m).
func _features(at: Vector2) -> float:
	var total := 0.0
	var here := Vector2i(floori(at.x / CHUNK), floori(at.y / CHUNK))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var info := _chunk(here + Vector2i(dx, dz))
			if info.has("hole"):
				var hole: Array = info.hole
				total -= hole[1] * (1.0 - smoothstep(hole[2] * 0.5, hole[2], at.distance_to(hole[0])))
			if info.has("ridge"):
				var ridge: Array = info.ridge
				var offset: Vector2 = at - ridge[0]
				var along: float = offset.dot(ridge[1])
				var across: float = absf(offset.dot(Vector2(-ridge[1].y, ridge[1].x)))
				var profile := 0.0
				if along > -ridge[3] and along <= 0.0:
					profile = smoothstep(0.0, 1.0, (along + ridge[3]) / ridge[3])
				elif along > 0.0 and along < 0.6:
					profile = 1.0 - along / 0.6
				total += ridge[2] * profile * (1.0 - smoothstep(ridge[4] * 0.6, ridge[4], across))
	return total

func _away_from_spots(at: Vector2, margin: float) -> float:
	var fade := 1.0
	for spot in _flat_spots:
		fade *= smoothstep(spot[1], spot[1] + margin, at.distance_to(spot[0]))
	return fade

# Désert au point « at » (m) : la zone (bord un peu irrégulier) est un petit désert ou fait partie d'un grand.
func is_desert(at: Vector2) -> bool:
	if _noise == null:
		return false
	var key := Vector2i(floori(at.x * 2.0), floori(at.y * 2.0))
	if _deserts.has(key):
		return _deserts[key]
	var warped := at + Vector2(_warp.get_noise_2d(at.x, at.y), _warp.get_noise_2d(at.x + 97.0, at.y - 31.0)) * 2.5
	var chunk := Vector2i(floori(warped.x / CHUNK), floori(warped.y / CHUNK))
	var desert: bool = _chunk(chunk).small_desert
	for dx in range(-1, 1):
		for dz in range(-1, 1):
			var info := _chunk(chunk + Vector2i(dx, dz))
			desert = desert or (info.has("big_desert") and Vector2i(-dx, -dz) in info.big_desert)
	# Jamais autour de l'apparition ni de la plage.
	desert = desert and _away_from_spots((Vector2(chunk) + Vector2(0.5, 0.5)) * CHUNK, 8.0) > 0.0
	_deserts[key] = desert
	return desert

# Hauteur du sol (m) au point de colonne (x, z) ; même graine = même hauteur (arrondie au millième).
func ground_height(column: Vector2i) -> float:
	if _noise == null:
		return 0.0
	if _heights.has(column):
		return _heights[column]
	var at := Vector2(column) * STEP
	var hill := clampf(_noise.get_noise_2d(at.x, at.y) * 1.6 - 0.15, 0.0, 1.0)
	var height := HILL_HEIGHT * pow(hill, 1.4) + _bumps.get_noise_2d(at.x, at.y) * BUMP_HEIGHT + _features(at)
	height = clampf(height * _away_from_spots(at, 7.0), DEEPEST, HILL_HEIGHT)
	height = roundf(height * 1000.0) / 1000.0
	_heights[column] = height
	return height

# Hauteur entre les points (herbe posée sur le sol de la graine).
func height_at(x: float, z: float) -> float:
	var cx := floori(x / STEP)
	var cz := floori(z / STEP)
	var fx := x / STEP - cx
	var fz := z / STEP - cz
	var low := lerpf(ground_height(Vector2i(cx, cz)), ground_height(Vector2i(cx + 1, cz)), fx)
	var high := lerpf(ground_height(Vector2i(cx, cz + 1)), ground_height(Vector2i(cx + 1, cz + 1)), fx)
	return lerpf(low, high, fz)

# Sol de la graine : plein sous la hauteur du sol, air au-dessus (densité en mètres, bornée à ±1).
func base_density(point: Vector3i) -> float:
	return clampf(ground_height(Vector2i(point.x, point.z)) - point.y * STEP, -1.0, 1.0)

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
const STONE := 1

# Matière du sol de la graine : terre (-1, aspect du sol avec herbe), sable des déserts, pierre ou Roche-mère.
func natural_kind(point: Vector3i) -> int:
	if point.y <= STONE_TOP:
		return STONE
	# 0.0.5.15 : sable sous les déserts, sur DESERT_SAND mètres, puis la terre.
	var column := Vector2i(point.x, point.z)
	if is_desert(Vector2(column) * STEP) and point.y * STEP > ground_height(column) - DESERT_SAND:
		return SAND
	return -1

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

# Plus haute et plus basse hauteur du sol sur les colonnes que lit une zone (bords compris).
func zone_heights(zone: Vector3i) -> Vector2:
	var origin := zone * POINTS
	var low := INF
	var high := -INF
	for x in range(origin.x - 1, origin.x + POINTS + 2):
		for z in range(origin.z - 1, origin.z + POINTS + 2):
			var height := ground_height(Vector2i(x, z))
			low = minf(low, height)
			high = maxf(high, height)
	return Vector2(low, high)

# Zone plate : aucun point changé parmi ceux qu'elle lit, et pas de colline (0.0.5.14).
func is_flat(zone: Vector3i) -> bool:
	var low := zone * POINTS - Vector3i.ONE
	var high := zone * POINTS + Vector3i.ONE * POINTS
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				for point: Vector3i in by_zone.get(zone + Vector3i(dx, dy, dz), {}):
					if point.x >= low.x and point.y >= low.y and point.z >= low.z and point.x <= high.x and point.y <= high.y and point.z <= high.z:
						return false
	if _noise == null:
		return true
	# 0.0.5.15 : plate seulement sans bosse (hauteur 0 partout) ni désert (sable à peindre).
	var heights := zone_heights(zone)
	if heights.x != 0.0 or heights.y != 0.0:
		return false
	var origin := Vector2(zone.x, zone.z) * CHUNK
	for corner in [Vector2(0, 0), Vector2(CHUNK, 0), Vector2(0, CHUNK), Vector2(CHUNK, CHUNK), Vector2(CHUNK, CHUNK) / 2.0]:
		if is_desert(origin + corner):
			return false
	return true

# Zones qui ont une surface : le sol plat (zones juste sous Y 0), celles des collines (zones dès Y 0)
# et celles qui lisent un point changé.
static func ground_zone(zone: Vector3i) -> bool:
	return zone.y == -1

func surface_zones(low_zone: Vector2i, high_zone: Vector2i) -> Dictionary:
	var result := {}
	for x in range(low_zone.x, high_zone.x + 1):
		for z in range(low_zone.y, high_zone.y + 1):
			result[Vector3i(x, -1, z)] = true
			if _noise != null and zone_heights(Vector3i(x, 0, z)).y > 0.0:
				result[Vector3i(x, 0, z)] = true
	for point: Vector3i in changes:
		for zone in zones_using(point):
			if zone.x >= low_zone.x and zone.x <= high_zone.x and zone.z >= low_zone.y and zone.z <= high_zone.y:
				result[zone] = true
	return result

# Maillage lisse d'une zone (coordonnées du monde) : [sommets, normales, couleurs], triangles dans le sens
# des aiguilles d'une montre vus de dehors, comme les blocs. Vide si la surface ne passe pas.
# 0.0.5.14 : seulement les hauteurs où la surface peut passer (sol de la graine, points changés), sans
# fonction appelée par point : bien plus rapide.
func zone_mesh(zone: Vector3i) -> Array:
	var origin := zone * POINTS
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var nearby: Array = []
	var lowest := INF
	var highest := -INF
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				for point: Vector3i in by_zone.get(zone + Vector3i(dx, dy, dz), {}):
					nearby.append(point)
					lowest = minf(lowest, point.y)
					highest = maxf(highest, point.y)
	var ground := zone_heights(zone)
	lowest = minf(lowest, floorf(ground.x / STEP))
	highest = maxf(highest, ceilf(ground.y / STEP))
	var y_low := maxi(maxi(origin.y - 1, int(lowest) - 2), BEDROCK_TOP - 2)
	var y_high := mini(mini(origin.y + POINTS, int(highest) + 2), HIGH_POINT + 2)
	if y_low >= y_high:
		return [vertices, normals, colors]
	var size := POINTS + 2
	var height := y_high - y_low + 1
	var start := Vector3i(origin.x - 1, y_low, origin.z - 1)
	var values := PackedFloat32Array()
	values.resize(size * height * size)
	for x in range(size):
		for z in range(size):
			var top := ground_height(Vector2i(start.x + x, start.z + z))
			for y in range(height):
				values[(x * height + y) * size + z] = clampf(top - (y_low + y) * STEP, -1.0, 1.0)
	var kinds := {}
	for point: Vector3i in nearby:
		var local := point - start
		if local.x >= 0 and local.y >= 0 and local.z >= 0 and local.x < size and local.y < height and local.z < size:
			values[(local.x * height + local.y) * size + local.z] = changes[point]
			if materials.has(point):
				kinds[local] = materials[point]
	# Décalages des 8 coins d'une sous-cellule dans le tableau.
	var corner_at := [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
	var offsets := PackedInt32Array()
	for corner: Vector3i in corner_at:
		offsets.append((corner.x * height + corner.y) * size + corner.z)
	# Un sommet par sous-cellule traversée : moyenne des passages sur ses 12 arêtes ; normale = pente de la densité.
	var cell_vertex := {}
	var cell_normal := {}
	var cell_color := {}
	var corners := PackedFloat32Array()
	corners.resize(8)
	for x in range(size - 1):
		for y in range(height - 1):
			for z in range(size - 1):
				var base := (x * height + y) * size + z
				var solid := 0
				for index in range(8):
					var value := values[base + offsets[index]]
					corners[index] = value
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
						var a := corners[index]
						var b := corners[index | axis]
						if (a > 0.0) == (b > 0.0):
							continue
						sum += Vector3(corner_at[index]).lerp(Vector3(corner_at[index | axis]), a / (a - b))
						count += 1
				var cell := Vector3i(x, y, z)
				cell_vertex[cell] = (Vector3(start + cell) + sum / count) * STEP
				var slope := Vector3(
					corners[1] + corners[3] + corners[5] + corners[7] - corners[0] - corners[2] - corners[4] - corners[6],
					corners[2] + corners[3] + corners[6] + corners[7] - corners[0] - corners[1] - corners[4] - corners[5],
					corners[4] + corners[5] + corners[6] + corners[7] - corners[0] - corners[1] - corners[2] - corners[3])
				cell_normal[cell] = (-slope).normalized() if slope.length_squared() > 0.000001 else Vector3.UP
				# Couleur des sommets (0.0.5.9) : alpha 0 = sable posé, bleu 0 = terre nue posée, blanc = sol de la graine ;
				# 0.0.5.12 : vert 0 = pierre.
				var paint := Vector3.ZERO
				var weight := 0
				for index in range(8):
					if corners[index] > 0.0:
						var corner: Vector3i = cell + corner_at[index]
						var kind: int = kinds.get(corner, natural_kind(start + corner))
						paint += Vector3(1.0 if kind == SAND else 0.0, 1.0 if kind == DIRT else 0.0, 1.0 if kind == STONE else 0.0)
						weight += 1
				paint /= maxf(weight, 1)
				cell_color[cell] = Color(1.0, 1.0 - paint.z, 1.0 - paint.y, 1.0 - paint.x)
	# Une face par arête traversée, entre les 4 sous-cellules qui la partagent ; la zone garde les arêtes
	# qui partent de ses propres points (pas de double avec la zone voisine).
	var axes := [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)]
	for axis_index in range(3):
		var axis: Vector3i = axes[axis_index]
		var side_a: Vector3i = axes[(axis_index + 1) % 3]
		var side_b: Vector3i = axes[(axis_index + 2) % 3]
		var step := (axis.x * height + axis.y) * size + axis.z
		for x in range(1, size - 1):
			for y in range(maxi(1, origin.y - y_low), mini(height - 1, origin.y + POINTS - y_low)):
				if y + axis.y >= height:
					continue
				for z in range(1, size - 1):
					var index := (x * height + y) * size + z
					var first := values[index]
					if (first > 0.0) == (values[index + step] > 0.0):
						continue
					var point := Vector3i(x, y, z)
					var quad := [point, point - side_a, point - side_a - side_b, point - side_b]
					if not (cell_vertex.has(quad[0]) and cell_vertex.has(quad[1]) and cell_vertex.has(quad[2]) and cell_vertex.has(quad[3])):
						continue
					var outward := Vector3(axis) if first > 0.0 else -Vector3(axis)
					# 0.0.5.14 : face coupée selon la diagonale qui garde les deux triangles tournés vers dehors
					# (sur les pentes, l'autre coupe pouvait retourner un petit triangle).
					var split := [[0, 1, 2], [0, 2, 3]]
					var p0: Vector3 = cell_vertex[quad[0]]
					var p1: Vector3 = cell_vertex[quad[1]]
					var p2: Vector3 = cell_vertex[quad[2]]
					var p3: Vector3 = cell_vertex[quad[3]]
					var facing := absf((p2 - p0).cross(p1 - p0).dot(outward)) + absf((p3 - p0).cross(p2 - p0).dot(outward))
					var other_facing := absf((p3 - p1).cross(p2 - p1).dot(outward)) + absf((p0 - p1).cross(p3 - p1).dot(outward))
					var folded := signf((p2 - p0).cross(p1 - p0).dot(outward)) != signf((p3 - p0).cross(p2 - p0).dot(outward))
					var other_folded := signf((p3 - p1).cross(p2 - p1).dot(outward)) != signf((p0 - p1).cross(p3 - p1).dot(outward))
					if (folded and not other_folded) or (folded == other_folded and other_facing > facing):
						split = [[1, 2, 3], [1, 3, 0]]
					for triangle in split:
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

# 0.0.5.11 : gravité de la terre et du sable. Un point plein sans rien dessous tombe d'un cran ; posé
# mais trop en hauteur par rapport au côté, il glisse en bas sur le côté (talus). Le sable glisse dès
# 1 m de dénivelé sur 50 cm (talus de 45° au plus) : on peut en faire une petite pile qui s'étale ;
# la terre tient mieux (1,5 m : talus plus raide). Le sol de la graine se comporte comme la terre.
# Un vide plus loin (pas juste dessous ni à côté) ne fait rien tomber. Points à vérifier : unstable.
var unstable: Dictionary = {}
const SIDES := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

# Pierre en place (de la graine) : ne tombe jamais.
func is_stone(point: Vector3i) -> bool:
	return density(point) > 0.0 and materials.get(point, natural_kind(point)) == STONE

func solid(point: Vector3i) -> bool:
	# La Roche-mère porte tout (jamais changée : on ne casse que jusqu'à la pierre au-dessus).
	return point.y <= BEDROCK_TOP or density(point) > 0.0

# Après un changement : le point, ceux au-dessus et autour sont à vérifier.
func wake(point: Vector3i) -> void:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				unstable[point + Vector3i(dx, dy, dz)] = true

# Où tombe ou glisse ce point (lui-même s'il tient).
func fall_target(point: Vector3i) -> Vector3i:
	if point.y <= BEDROCK_TOP or not solid(point) or is_stone(point):
		return point
	var below := point + Vector3i.DOWN
	if not solid(below):
		return below
	# Talus : un côté libre, et assez de vide en dessous de ce côté.
	var drop := 2 if materials.get(point, natural_kind(point)) == SAND else 3
	var first := absi(hash(point)) % 4
	for turn in range(4):
		var side: Vector3i = point + SIDES[(first + turn) % 4]
		if solid(side):
			continue
		var free := true
		for depth in range(1, drop):
			free = free and not solid(side + Vector3i.DOWN * depth)
		if free:
			return side + Vector3i.DOWN
	return point

# Un pas de chute : au plus « limit » points vérifiés, du plus bas au plus haut ; renvoie les points changés.
func settle_step(limit: int = 96) -> Array[Vector3i]:
	var moved: Array[Vector3i] = []
	if unstable.is_empty():
		return moved
	var points: Array = unstable.keys()
	points.sort_custom(func(a: Vector3i, b: Vector3i): return a.y < b.y)
	for point: Vector3i in points.slice(0, limit):
		unstable.erase(point)
		var target := fall_target(point)
		if target == point or absi(target.x) > 2 * 57 or absi(target.z) > 2 * 57:
			continue
		var value := density(point)
		var kind: int = materials.get(point, natural_kind(point))
		if kind < 0:
			kind = DIRT
		set_density(target, maxf(value, ADDED), kind)
		set_density(point, DUG)
		moved.append_array([point, target])
		wake(point)
		wake(target)
	return moved
