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
					indices.append(mapped)
	_x += 1
	if _x >= size - 1:
		_x = 1
		_axis += 1
		if _axis >= 3:
			_finish([vertices, normals, colors, uvs, uvs2, ore_colors.to_byte_array().to_float32_array(), indices])
