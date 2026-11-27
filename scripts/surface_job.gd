extends RefCounted
# 0.0.7.20 (mesures : 27 à 100 ms d'un coup pour la surface d'une zone, d'où les à-coups en traversant une forêt) : le
# calcul de la surface lisse d'une zone (smooth_terrain.gd zone_surface, même résultat au sommet près) découpé en étapes
# qui reprennent d'une image à l'autre : préparation, hauteurs (ligne par ligne), grottes (boule par boule), sous-cellules
# (ligne par ligne), faces (ligne par ligne). step(budget) avance jusqu'à épuiser le temps donné ; done et result.
# Un seul fil (Web compris) : aucun risque avec les mémoires du terrain.

var t  # le terrain (smooth_terrain.gd)
var zone: Vector3i
var done := false
var result: Array = []

var _stage := 0
var _x := 0
var _axis := 0
var _cave := 0
# Données de la zone (comme les variables de zone_surface).
var origin: Vector3i
var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var uvs := PackedVector2Array()
var uvs2 := PackedVector2Array()
var ore_colors := PackedColorArray()
var indices := PackedInt32Array()
var nearby: Array = []
var cave_nodes: Array = []
var y_low := 0
var y_high := 0
var size := 0
var height := 0
var start: Vector3i
var values := PackedFloat32Array()
var tops := PackedFloat64Array()
var cave_low := PackedInt32Array()
var cave_high := PackedInt32Array()
var kinds := {}
var corner_at := [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
var corner_place := PackedVector3Array()
var offsets := PackedInt32Array()
var edge_from := PackedInt32Array()
var edge_to := PackedInt32Array()
var paint_of := PackedVector4Array()
var wet_of := PackedVector2Array()
var cover_of := PackedVector2Array()
var ore_of := PackedColorArray()
var cell_slot := PackedInt32Array()
var cell_vertex := PackedVector3Array()
var cell_normal := PackedVector3Array()
var cell_color := PackedColorArray()
var cell_uv := PackedVector2Array()
var cell_uv2 := PackedVector2Array()
var cell_ores := PackedColorArray()
var corners := PackedFloat32Array()
var low_cells := PackedInt32Array()
var high_cells := PackedInt32Array()
var slab_low := PackedInt32Array()
var slab_high := PackedInt32Array()
var known_kinds := PackedInt32Array()
var used := PackedInt32Array()
var triangle := PackedInt32Array()
var axes := [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)]
# 0.0.8.52 (lot Ombres, partie 2, demande de l'utilisateur : de meilleures ombres sous terre, même en Performance) : coins
# et creux assombris dans les grottes et là où on a creusé ou posé. Pour chaque sommet, la part de matière pleine dans un
# cube de 2 m autour de lui (5 × 5 × 5 points, lue dans des sommes cumulées : 8 lectures) ; un sol plat ou une pente en
# ont la moitié : rien ; un coin, un fond de galerie en ont plus : assombris (de 0 à OCCLUSION_MAX ; shader du sol,
# CUSTOM1). Seulement près des points « mêlés » (grotte, changement) : le sol de la graine ailleurs ne coûte rien (mesuré :
# calculé partout, la construction du terrain prenait 5 fois plus de temps). Les points sont lus comme le sol (graine,
# grottes, changements), OCCLUSION_MARGIN points autour de la zone : deux zones voisines donnent la même valeur à leurs
# sommets communs (pas de couture). Sommet par sommet : à sa place dans sa sous-cellule (pas de bandes).
const OCCLUSION_RADIUS := 2
const OCCLUSION_MARGIN := 2
const OCCLUSION_DEAD := 0.03
const OCCLUSION_GAIN := 3.2
const OCCLUSION_MAX := 0.75
const BOX_POINTS := 125.0
# Points mêlés dans le cube pour l'assombrissement entier (moins : en partie, pour un passage doux vers le sol naturel).
const MIXED_FULL := 6.0
static var occlusion_on := true
var occ_active := false
var occ := PackedFloat32Array()
var occ_mixed := PackedFloat32Array()
var occ_sums := PackedFloat32Array()
var mixed_sums := PackedFloat32Array()
var occ_box := PackedFloat32Array()
var mixed_box := PackedFloat32Array()
var occ_nodes: Array = []
var ox := 0
var oy := 0
var oz := 0
var ostart: Vector3i
var _occ_x := 0
var cell_occlusion := PackedFloat32Array()
var occlusions := PackedFloat32Array()

func _init(terrain, which: Vector3i) -> void:
	t = terrain
	zone = which

# Tout d'un coup (zone_surface).
func run() -> Array:
	while not done:
		step(1 << 40)
	return result

# Avance jusqu'à épuiser budget_usec (au moins une petite étape). Vrai quand la surface est finie.
func step(budget_usec: int) -> bool:
	var started := Time.get_ticks_usec()
	while not done:
		_advance()
		if Time.get_ticks_usec() - started >= budget_usec:
			break
	return done

func _finish(value: Array) -> void:
	result = value
	done = true

func _advance() -> void:
	match _stage:
		0:
			_prepare()
		1:
			_heights_row()
		2:
			_cave_ball()
		3:
			_tables()
		4:
			_cells_row()
		5:
			_faces_row()
		6:
			_occlusion_slab()
		7:
			_occlusion_sum()

# Étape 0 : points changés autour, hauteurs extrêmes, grottes, tableaux.
func _prepare() -> void:
	origin = zone * t.POINTS
	var lowest := INF
	var highest := -INF
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				for point: Vector3i in t.by_zone.get(zone + Vector3i(dx, dy, dz), {}):
					nearby.append(point)
					lowest = minf(lowest, point.y)
					highest = maxf(highest, point.y)
	var ground: Vector2 = t.zone_heights(zone)
	lowest = minf(lowest, floorf(ground.x / t.STEP))
	highest = maxf(highest, ceilf(ground.y / t.STEP))
	cave_nodes = t.caves_in_zone(zone)
	if not cave_nodes.is_empty():
		lowest = minf(lowest, origin.y - 1)
		highest = maxf(highest, origin.y + t.POINTS + 1)
	y_low = maxi(maxi(origin.y - 1, int(lowest) - 2), t.mother_rock_top - 2)
	y_high = mini(mini(origin.y + t.POINTS, int(highest) + 2), t.HIGH_POINT + 2)
	if y_low >= y_high:
		_finish([vertices, normals, colors, uvs, uvs2, PackedFloat32Array(), indices])
		return
	size = t.POINTS + 2
	height = y_high - y_low + 1
	start = Vector3i(origin.x - 1, y_low, origin.z - 1)
	values.resize(size * height * size)
	tops.resize(size * size)
	cave_low.resize(size * size)
	cave_high.resize(size * size)
	cave_low.fill(height)
	cave_high.fill(-1)
	_x = 0
	_stage = 1

# Étape 1 : une ligne de hauteurs du sol et de densités.
func _heights_row() -> void:
	var x := _x
	for z in range(size):
		var top: float = t.ground_height(Vector2i(start.x + x, start.z + z))
		tops[x * size + z] = top
		for y in range(height):
			values[(x * height + y) * size + z] = clampf(top - (y_low + y) * t.STEP, -1.0, 1.0)
	_x += 1
	if _x >= size:
		_cave = 0
		_stage = 2

# Étape 2 : une boule de grotte.
func _cave_ball() -> void:
	if _cave >= cave_nodes.size():
		_stage = 3
		return
	var node = cave_nodes[_cave]
	_cave += 1
	var middle: Vector3 = node.at / t.STEP - Vector3(start)
	var radius: float = node.radius
	var reach: float = (radius + 1.0) / t.STEP
	var reach2 := reach * reach
	var around := ceili(reach) + 1
	var near := middle.round()
	for x in range(maxi(0, int(near.x) - around), mini(size, int(near.x) + around + 1)):
		var dx := x - middle.x
		for z in range(maxi(0, int(near.z) - around), mini(size, int(near.z) + around + 1)):
			var dz := z - middle.z
			var flat := dx * dx + dz * dz
			if flat >= reach2:
				continue
			for y in range(maxi(0, int(near.y) - around), mini(height, int(near.y) + around + 1)):
				var dy := y - middle.y
				var far2 := flat + dy * dy
				if far2 >= reach2 or y_low + y <= t.mother_rock_top:
					continue
				var index := (x * height + y) * size + z
				values[index] = minf(values[index], clampf(Vector3(x, y, z).distance_to(middle) * t.STEP - radius, -1.0, 1.0))
				cave_low[x * size + z] = mini(cave_low[x * size + z], y)
				cave_high[x * size + z] = maxi(cave_high[x * size + z], y)

# Étape 3 : points changés, tables, hauteurs des sous-cellules à examiner.
func _tables() -> void:
	for point: Vector3i in nearby:
		var local := point - start
		if local.x >= 0 and local.y >= 0 and local.z >= 0 and local.x < size and local.y < height and local.z < size:
			values[(local.x * height + local.y) * size + local.z] = t.changes[point]
			if t.materials.has(point):
				kinds[local] = t.materials[point]
	for corner: Vector3i in corner_at:
		offsets.append((corner.x * height + corner.y) * size + corner.z)
		corner_place.append(Vector3(corner))
	edge_from = PackedInt32Array(t.EDGE_FROM)
	edge_to = PackedInt32Array(t.EDGE_TO)
	paint_of = PackedVector4Array(t.KIND_PAINT)
	wet_of = PackedVector2Array(t.KIND_WET)
	cover_of = PackedVector2Array(t.KIND_COVER)
	ore_of = PackedColorArray(t.KIND_ORE)
	cell_slot.resize(size * height * size)
	cell_slot.fill(-1)
	corners.resize(8)
	var free := nearby.is_empty()
	low_cells.resize((size - 1) * (size - 1))
	high_cells.resize((size - 1) * (size - 1))
	slab_low.resize(size - 1)
	slab_high.resize(size - 1)
	for x in range(size - 1):
		var slab_min := height
		var slab_max := -1
		for z in range(size - 1):
			var lowest_y := 0
			var highest_y := height - 2
			if free:
				var a := tops[x * size + z]
				var b := tops[x * size + z + 1]
				var c := tops[(x + 1) * size + z]
				var d := tops[(x + 1) * size + z + 1]
				lowest_y = maxi(0, ceili(minf(minf(a, b), minf(c, d)) / t.STEP) - 1 - y_low)
				highest_y = mini(height - 2, ceili(maxf(maxf(a, b), maxf(c, d)) / t.STEP) - 1 - y_low)
				var hollow_low := mini(mini(cave_low[x * size + z], cave_low[x * size + z + 1]), mini(cave_low[(x + 1) * size + z], cave_low[(x + 1) * size + z + 1]))
				var hollow_high := maxi(maxi(cave_high[x * size + z], cave_high[x * size + z + 1]), maxi(cave_high[(x + 1) * size + z], cave_high[(x + 1) * size + z + 1]))
				if hollow_high >= 0:
					hollow_low = maxi(0, hollow_low - 2)
					hollow_high = mini(height - 2, hollow_high + 1)
					if lowest_y > highest_y:
						lowest_y = hollow_low
						highest_y = hollow_high
					else:
						lowest_y = mini(lowest_y, hollow_low)
						highest_y = maxi(highest_y, hollow_high)
			low_cells[x * (size - 1) + z] = lowest_y
			high_cells[x * (size - 1) + z] = highest_y
			slab_min = mini(slab_min, lowest_y)
			slab_max = maxi(slab_max, highest_y)
		slab_low[x] = slab_min
		slab_high[x] = slab_max
	known_kinds.resize(size * height * size)
	known_kinds.fill(t.UNKNOWN_KIND)
	_x = 0
	_stage = 4
	if occlusion_on:
		_occlusion_prepare()

# --- 0.0.8.52 : coins assombris près des grottes et de ce qui a été creusé ou posé ---
# Seulement là où le sol n'est plus celui de la graine (grottes, changements) : ailleurs, aucun calcul (le sol naturel
# reste comme avant ; l'ouverture d'un monde ne ralentit pas). La grille ne couvre que ces endroits, avec leur marge.
func _occlusion_prepare() -> void:
	_occ_x = 0
	var read_low := start - Vector3i.ONE * OCCLUSION_MARGIN
	var read_high := start + Vector3i(size - 1, height - 1, size - 1) + Vector3i.ONE * OCCLUSION_MARGIN
	var low := Vector3i(1 << 30, 1 << 30, 1 << 30)
	var high := -low
	for point: Vector3i in nearby:
		if point.x >= read_low.x and point.y >= read_low.y and point.z >= read_low.z and point.x <= read_high.x and point.y <= read_high.y and point.z <= read_high.z:
			low = low.min(point)
			high = high.max(point)
	var seen := {}
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				for node in t.caves_in_zone(zone + Vector3i(dx, dy, dz)):
					var key := str(node.at)
					if seen.has(key):
						continue
					seen[key] = true
					var reach: float = (node.radius + 1.0) / t.STEP
					var middle: Vector3 = node.at / t.STEP
					var node_low := Vector3i(floori(middle.x - reach), floori(middle.y - reach), floori(middle.z - reach)).max(read_low)
					var node_high := Vector3i(ceili(middle.x + reach), ceili(middle.y + reach), ceili(middle.z + reach)).min(read_high)
					if node_low.x > node_high.x or node_low.y > node_high.y or node_low.z > node_high.z:
						continue
					occ_nodes.append(node)
					low = low.min(node_low)
					high = high.max(node_high)
	if low.x > high.x:
		_stage = 4
		return
	# Les sommets assombris : à OCCLUSION_RADIUS + 1 de ces points ; leur cube : encore OCCLUSION_RADIUS autour.
	var spread := Vector3i.ONE * (2 * OCCLUSION_RADIUS + 1)
	ostart = (low - spread).max(read_low)
	var oend := (high + spread).min(read_high)
	ox = oend.x - ostart.x + 1
	oy = oend.y - ostart.y + 1
	oz = oend.z - ostart.z + 1
	occ.resize(ox * oy * oz)
	occ_mixed.resize(ox * oy * oz)
	occ_mixed.fill(0.0)
	# Sol de la graine, colonne par colonne (valeurs du terrain lues une fois : plus rapide).
	var step: float = t.STEP
	var rock_top: int = t.mother_rock_top
	for x in range(ox):
		for z in range(oz):
			var top: float = t.ground_height(Vector2i(ostart.x + x, ostart.z + z))
			var base := (x * oy) * oz + z
			for y in range(oy):
				occ[base + y * oz] = clampf(top - (ostart.y + y) * step, -1.0, 1.0)
	# Grottes (comme base_density) : là où une boule creuse, le point est « mêlé ».
	for node in occ_nodes:
		var radius: float = node.radius
		var reach: float = (radius + 1.0) / step
		var middle: Vector3 = node.at / step
		for x in range(maxi(0, floori(middle.x - reach) - ostart.x), mini(ox, ceili(middle.x + reach) - ostart.x + 1)):
			for y in range(maxi(0, floori(middle.y - reach) - ostart.y), mini(oy, ceili(middle.y + reach) - ostart.y + 1)):
				if ostart.y + y <= rock_top:
					continue
				for z in range(maxi(0, floori(middle.z - reach) - ostart.z), mini(oz, ceili(middle.z + reach) - ostart.z + 1)):
					var index := (x * oy + y) * oz + z
					var carved: float = clampf(Vector3(ostart.x + x, ostart.y + y, ostart.z + z).distance_to(middle) * step - radius, -1.0, 1.0)
					if carved < occ[index]:
						occ[index] = carved
						occ_mixed[index] = 1.0
	# Changements (creusé, posé).
	for point: Vector3i in nearby:
		var local := point - ostart
		if local.x >= 0 and local.y >= 0 and local.z >= 0 and local.x < ox and local.y < oy and local.z < oz:
			var index := (local.x * oy + local.y) * oz + local.z
			occ[index] = t.changes[point]
			occ_mixed[index] = 1.0
	occ_sums.resize((ox + 1) * (oy + 1) * (oz + 1))
	occ_sums.fill(0.0)
	mixed_sums.resize((ox + 1) * (oy + 1) * (oz + 1))
	mixed_sums.fill(0.0)
	occ_box.resize(ox * oy * oz)
	occ_box.fill(-1.0)
	mixed_box.resize(ox * oy * oz)
	occ_active = true
	_stage = 6

# Une tranche (x) : matière pleine (1), vide (0) ou entre les deux près de la surface ; sommes cumulées sur y et z.
func _occlusion_slab() -> void:
	var inverse: float = 1.0 / t.STEP
	var i := _occ_x
	var row := oz + 1
	var base := (i + 1) * (oy + 1) * row
	for z in range(oz):
		var running := 0.0
		var running_mixed := 0.0
		for y in range(oy):
			var index := (i * oy + y) * oz + z
			running += clampf(0.5 + occ[index] * inverse, 0.0, 1.0)
			running_mixed += occ_mixed[index]
			var at := base + (y + 1) * row + z + 1
			occ_sums[at] = occ_sums[at - 1] + running
			mixed_sums[at] = mixed_sums[at - 1] + running_mixed
	_occ_x += 1
	if _occ_x >= ox:
		_occ_x = 1
		_stage = 7

# Sommes cumulées sur x (une tranche à la fois) ; puis le maillage reprend (sous-cellules).
func _occlusion_sum() -> void:
	var plane := (oy + 1) * (oz + 1)
	var to := (_occ_x + 1) * plane
	var from := _occ_x * plane
	for index in range(plane):
		occ_sums[to + index] += occ_sums[from + index]
		mixed_sums[to + index] += mixed_sums[from + index]
	_occ_x += 1
	if _occ_x >= ox:
		_stage = 4

# Somme d'un cube de 5 × 5 × 5 points dans une grille de sommes cumulées.
func _box_sum(sums: PackedFloat32Array, x: int, y: int, z: int) -> float:
	var row := oz + 1
	var plane := (oy + 1) * row
	var x0 := (x - OCCLUSION_RADIUS) * plane
	var x1 := (x + OCCLUSION_RADIUS + 1) * plane
	var y0 := (y - OCCLUSION_RADIUS) * row
	var y1 := (y + OCCLUSION_RADIUS + 1) * row
	var z0 := z - OCCLUSION_RADIUS
	var z1 := z + OCCLUSION_RADIUS + 1
	return sums[x1 + y1 + z1] - sums[x0 + y1 + z1] - sums[x1 + y0 + z1] - sums[x1 + y1 + z0] \
		+ sums[x0 + y0 + z1] + sums[x0 + y1 + z0] + sums[x1 + y0 + z0] - sums[x0 + y0 + z0]

# Part pleine et nombre de points mêlés du cube autour d'un point de la grille (gardés).
func _occlusion_box(x: int, y: int, z: int) -> Vector2:
	var index := (x * oy + y) * oz + z
	if occ_box[index] < 0.0:
		occ_box[index] = _box_sum(occ_sums, x, y, z) / BOX_POINTS
		mixed_box[index] = _box_sum(mixed_sums, x, y, z)
	return Vector2(occ_box[index], mixed_box[index])

# Assombrissement d'un sommet de la sous-cellule « cell » (repère du maillage) : 0 hors des endroits mêlés.
func _vertex_occlusion(cell: Vector3i, place: Vector3) -> float:
	if not occ_active:
		return 0.0
	var corner := start + cell - ostart
	if corner.x < OCCLUSION_RADIUS or corner.y < OCCLUSION_RADIUS or corner.z < OCCLUSION_RADIUS or corner.x + 1 + OCCLUSION_RADIUS >= ox or corner.y + 1 + OCCLUSION_RADIUS >= oy or corner.z + 1 + OCCLUSION_RADIUS >= oz:
		return 0.0
	var f: Vector3 = (place / t.STEP - Vector3(start + cell)).clamp(Vector3.ZERO, Vector3.ONE)
	var c00 := _occlusion_box(corner.x, corner.y, corner.z).lerp(_occlusion_box(corner.x + 1, corner.y, corner.z), f.x)
	var c10 := _occlusion_box(corner.x, corner.y + 1, corner.z).lerp(_occlusion_box(corner.x + 1, corner.y + 1, corner.z), f.x)
	var c01 := _occlusion_box(corner.x, corner.y, corner.z + 1).lerp(_occlusion_box(corner.x + 1, corner.y, corner.z + 1), f.x)
	var c11 := _occlusion_box(corner.x, corner.y + 1, corner.z + 1).lerp(_occlusion_box(corner.x + 1, corner.y + 1, corner.z + 1), f.x)
	var both := c00.lerp(c10, f.y).lerp(c01.lerp(c11, f.y), f.z)
	if both.y <= 0.0:
		return 0.0
	return clampf((both.x - 0.5 - OCCLUSION_DEAD) * OCCLUSION_GAIN, 0.0, OCCLUSION_MAX) * clampf(both.y / MIXED_FULL, 0.0, 1.0)

# Étape 4 : une ligne de sous-cellules traversées : leur sommet, sa normale, ses couleurs.
func _cells_row() -> void:
	var x := _x
	for z in range(size - 1):
		for y in range(low_cells[x * (size - 1) + z], high_cells[x * (size - 1) + z] + 1):
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
			for edge in range(12):
				var one := edge_from[edge]
				var other := edge_to[edge]
				var a := corners[one]
				var b := corners[other]
				if (a > 0.0) == (b > 0.0):
					continue
				sum += corner_place[one].lerp(corner_place[other], a / (a - b))
				count += 1
			var cell := Vector3i(x, y, z)
			cell_slot[base] = cell_vertex.size()
			cell_vertex.append((Vector3(start + cell) + sum / count) * t.STEP)
			cell_occlusion.append(_vertex_occlusion(cell, cell_vertex[cell_vertex.size() - 1]) if occlusion_on else 0.0)
			var slope := Vector3(
				corners[1] + corners[3] + corners[5] + corners[7] - corners[0] - corners[2] - corners[4] - corners[6],
				corners[2] + corners[3] + corners[6] + corners[7] - corners[0] - corners[1] - corners[4] - corners[5],
				corners[4] + corners[5] + corners[6] + corners[7] - corners[0] - corners[1] - corners[2] - corners[3])
			cell_normal.append((-slope).normalized() if slope.length_squared() > 0.000001 else Vector3.UP)
			var paint := Vector4.ZERO
			var wet := Vector2.ZERO
			var cover := Vector2.ZERO
			var ore := Color(0.0, 0.0, 0.0, 0.0)
			var weight := 0
			for index in range(8):
				if corners[index] > 0.0:
					var kind_at: int = base + offsets[index]
					var kind: int = known_kinds[kind_at]
					if kind == t.UNKNOWN_KIND:
						var corner: Vector3i = cell + corner_at[index]
						kind = kinds[corner] if kinds.has(corner) else t.natural_kind(start + corner)
						known_kinds[kind_at] = kind
					var slot := kind + 1
					if slot < 0 or slot >= t.KIND_SLOTS:
						slot = 0
					paint += paint_of[slot]
					wet += wet_of[slot]
					cover += cover_of[slot]
					ore += ore_of[slot]
					weight += 1
			paint /= maxf(weight, 1)
			cell_color.append(Color(1.0 - paint.w, 1.0 - paint.z, 1.0 - paint.y, 1.0 - paint.x))
			cell_uv.append(wet / maxf(weight, 1))
			cell_uv2.append(cover / maxf(weight, 1))
			cell_ores.append(ore / maxf(weight, 1))
	_x += 1
	if _x >= size - 1:
		used.resize(cell_vertex.size())
		used.fill(-1)
		triangle.resize(3)
		_axis = 0
		_x = 1
		_stage = 5

# Étape 5 : une ligne de faces (une face par arête traversée, entre les 4 sous-cellules qui la partagent).
func _faces_row() -> void:
	var axis: Vector3i = axes[_axis]
	var side_a: Vector3i = axes[(_axis + 1) % 3]
	var side_b: Vector3i = axes[(_axis + 2) % 3]
	var step := (axis.x * height + axis.y) * size + axis.z
	var step_a := (side_a.x * height + side_a.y) * size + side_a.z
	var step_b := (side_b.x * height + side_b.y) * size + side_b.z
	var x := _x
	for y in range(maxi(maxi(1, origin.y - y_low), slab_low[x]), mini(mini(height - 1, origin.y + t.POINTS - y_low), slab_high[x] + 1)):
		if y + axis.y >= height:
			continue
		for z in range(1, size - 1):
			if y < low_cells[x * (size - 1) + z] or y > high_cells[x * (size - 1) + z]:
				continue
			var index := (x * height + y) * size + z
			var first := values[index]
			if (first > 0.0) == (values[index + step] > 0.0):
				continue
			var q0 := cell_slot[index]
			var q1 := cell_slot[index - step_a]
			var q2 := cell_slot[index - step_a - step_b]
			var q3 := cell_slot[index - step_b]
			if q0 < 0 or q1 < 0 or q2 < 0 or q3 < 0:
				continue
			var outward := Vector3(axis) if first > 0.0 else -Vector3(axis)
			var p0 := cell_vertex[q0]
			var p1 := cell_vertex[q1]
			var p2 := cell_vertex[q2]
			var p3 := cell_vertex[q3]
			var facing := absf((p2 - p0).cross(p1 - p0).dot(outward)) + absf((p3 - p0).cross(p2 - p0).dot(outward))
			var other_facing := absf((p3 - p1).cross(p2 - p1).dot(outward)) + absf((p0 - p1).cross(p3 - p1).dot(outward))
			var folded := signf((p2 - p0).cross(p1 - p0).dot(outward)) != signf((p3 - p0).cross(p2 - p0).dot(outward))
			var other_folded := signf((p3 - p1).cross(p2 - p1).dot(outward)) != signf((p0 - p1).cross(p3 - p1).dot(outward))
			var turned := (folded and not other_folded) or (folded == other_folded and other_facing > facing)
			for half in range(2):
				if turned:
					triangle[0] = q1
					triangle[1] = q2 if half == 0 else q3
					triangle[2] = q3 if half == 0 else q0
				else:
					triangle[0] = q0
					triangle[1] = q1 if half == 0 else q2
					triangle[2] = q2 if half == 0 else q3
				var a := cell_vertex[triangle[0]]
				if (cell_vertex[triangle[2]] - a).cross(cell_vertex[triangle[1]] - a).dot(outward) < 0.0:
					var swap := triangle[1]
					triangle[1] = triangle[2]
					triangle[2] = swap
				for corner in range(3):
					var slot := triangle[corner]
					var mapped := used[slot]
					if mapped < 0:
						mapped = vertices.size()
						used[slot] = mapped
						vertices.append(cell_vertex[slot])
						normals.append(cell_normal[slot])
						colors.append(cell_color[slot])
						uvs.append(cell_uv[slot])
						uvs2.append(cell_uv2[slot])
						ore_colors.append(cell_ores[slot])
						occlusions.append(cell_occlusion[slot])
					indices.append(mapped)
	_x += 1
	if _x >= size - 1:
		_x = 1
		_axis += 1
		if _axis >= 3:
			_finish([vertices, normals, colors, uvs, uvs2, ore_colors.to_byte_array().to_float32_array(), indices, occlusions])
