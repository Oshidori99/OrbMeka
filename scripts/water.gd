extends RefCounted
# 0.0.6.6 (#124) : eau qui coule près du joueur. Chaque case de 50 cm × 50 cm a un fond (le haut du terrain) et une
# hauteur d'eau libre ; à chaque pas, l'eau passe vers les cases voisines plus basses, sans jamais se créer ni se perdre.
# Les lacs de la graine sont des réservoirs : l'eau qui en sort fait baisser leur niveau (volume ÷ surface), et un lac
# peut se vider. Seules les cases qui bougent sont calculées, et seulement autour du joueur.
# Sauvegarde dans le dossier du monde, seulement ce qui a changé : eau/lacs.json (niveaux des lacs qui ont bougé) et
# eau/cases.json (eau libre : case X, case Z, profondeur en millimètres).
const Store = preload("res://scripts/world_store.gd")
const CELL := 0.5
const AREA := 0.25
const STEP_SECONDS := 0.1
# 0.0.6.7 : tuyau entre deux cases (section en m²), pesanteur, petite perte d'élan, petits pas par dixième de seconde.
const PIPE := 0.5
const GRAVITY := 9.8
const DAMPING := 0.98
const SUBSTEPS := 4
const CALM := 0.0004
const MIN_DEPTH := 0.004
const REACH := 32.0
const FOLDER := "eau"
const LAKES_FILE := "lacs.json"
const CELLS_FILE := "cases.json"
const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var terrain
var depth: Dictionary = {}
var lake_levels: Dictionary = {}
var active: Dictionary = {}
var _floors: Dictionary = {}
# Débit sortant de chaque case vers ses 4 voisines (m³/s), gardé d'un pas à l'autre : c'est l'élan de l'eau.
var flux: Dictionary = {}
# Zones de 8 m (X, Z) dont l'eau libre est à redessiner, lacs dont le niveau a bougé.
var changed_zones: Dictionary = {}
var changed_lakes: Dictionary = {}
var dirty := false

func _init(world_terrain) -> void:
	terrain = world_terrain

static func column_of(at: Vector2) -> Vector2i:
	return Vector2i(roundi(at.x / CELL), roundi(at.y / CELL))

static func zone_of(column: Vector2i) -> Vector2i:
	return Vector2i(floori(column.x * CELL / 8.0), floori(column.y * CELL / 8.0))

func lake_level_now(lake: Dictionary) -> float:
	return lake_levels.get(terrain.lake_id(lake), terrain.lake_level(lake))

# Fond d'une case : le haut du terrain plein (creusé ou posé compris), cherché depuis un peu au-dessus du sol.
func floor_of(column: Vector2i) -> float:
	if _floors.has(column):
		return _floors[column]
	var top := ceili((terrain.ground_height(column) + 3.0) / CELL)
	var result: float = terrain.mother_rock_top * CELL
	for y in range(top, terrain.mother_rock_top, -1):
		var below: float = terrain.density(Vector3i(column.x, y, column.y))
		if below > 0.0:
			var above: float = terrain.density(Vector3i(column.x, y + 1, column.y))
			result = (y + below / maxf(below - above, 0.0001)) * CELL
			break
	_floors[column] = result
	return result

# Lac dont l'eau couvre cette case (son niveau actuel au-dessus du fond), sinon {}.
func lake_of(column: Vector2i) -> Dictionary:
	var lake: Dictionary = terrain.lake_at(Vector2(column) * CELL)
	if not lake.is_empty() and lake_level_now(lake) > floor_of(column) + MIN_DEPTH:
		return lake
	return {}

# Niveau de l'eau à cet endroit (lac ou eau libre), -INF sans eau.
func surface_at(at: Vector2) -> float:
	var column := column_of(at)
	var level := -INF
	var lake := lake_of(column)
	if not lake.is_empty():
		level = lake_level_now(lake)
	var free: float = depth.get(column, 0.0)
	if free > MIN_DEPTH:
		level = maxf(level, floor_of(column) + free)
	level = maxf(level, terrain.river_level_at(at))
	return level

# Le terrain a changé à ces points : fonds à revoir ; les cases et leurs voisines se remettent à couler.
func terrain_changed(points: Array) -> void:
	for point: Vector3i in points:
		var column := Vector2i(point.x, point.z)
		_floors.erase(column)
		active[column] = true
		for side: Vector2i in SIDES:
			active[column + side] = true

func _height(column: Vector2i) -> Array:
	var bottom := floor_of(column)
	var lake := lake_of(column)
	var level: float = bottom + depth.get(column, 0.0)
	if not lake.is_empty():
		level = maxf(level, lake_level_now(lake))
	# 0.0.6.7 : une rivière donne et emporte l'eau sans compter (sa source la remplit, elle va au lac).
	var river: float = terrain.river_level_at(Vector2(column) * CELL)
	var flowing_river := river > bottom + MIN_DEPTH
	if flowing_river:
		level = maxf(level, river)
	return [bottom, level, lake, flowing_river]

# 0.0.6.7 : écoulement avec élan (comme de vrais tuyaux entre cases voisines) : le débit vers une voisine plus basse
# grandit tant que la pente dure, puis l'eau se met à niveau en quelques secondes (avant : sans élan, une longue
# pente d'eau restait en place). Quatre petits pas par dixième de seconde, pour rester stable.
func step(center: Vector2) -> void:
	if active.is_empty():
		return
	for index in range(SUBSTEPS):
		_substep(center, STEP_SECONDS / SUBSTEPS)

func _substep(center: Vector2, dt: float) -> void:
	var heights := {}
	var columns := {}
	for column: Vector2i in active:
		if (Vector2(column) * CELL).distance_to(center) <= REACH:
			columns[column] = true
	var outflows := {}
	var lake_gains := {}
	var lakes := {}
	var gains := {}
	for column: Vector2i in columns:
		var here: Array = _height_cached(column, heights)
		var lake: Dictionary = here[2]
		var river_here: bool = here[3]
		var old: PackedFloat32Array = flux.get(column, PackedFloat32Array([0.0, 0.0, 0.0, 0.0]))
		var flows := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
		var total := 0.0
		for side in range(4):
			var there: Array = _height_cached(column + SIDES[side], heights)
			var drop: float = here[1] - there[1]
			# Même lac des deux côtés, ou rien au-dessus du fond de la voisine : rien ne coule.
			if not lake.is_empty() and not there[2].is_empty() and terrain.lake_id(lake) == terrain.lake_id(there[2]):
				continue
			if here[1] <= there[0] + 0.0005:
				continue
			var rate := maxf(0.0, old[side] * DAMPING + dt * GRAVITY * PIPE * drop / CELL)
			# Presque rien : l'eau est calme ici (elle s'endort, plus rien à calculer).
			if rate < CALM:
				rate = 0.0
			flows[side] = rate
			total += rate
		if total <= 0.0:
			flux.erase(column)
			continue
		# Jamais plus que l'eau présente (un lac, lui, donne sans compter : il baisse ensuite ; une rivière aussi).
		if lake.is_empty() and not river_here:
			var water: float = depth.get(column, 0.0) * AREA
			if total * dt > water:
				var scale := water / (total * dt)
				for side in range(4):
					flows[side] *= scale
		flux[column] = flows
		outflows[column] = flows
	for column: Vector2i in outflows:
		var flows: PackedFloat32Array = outflows[column]
		var lake: Dictionary = _height_cached(column, heights)[2]
		var river_source: bool = _height_cached(column, heights)[3]
		for side in range(4):
			var volume: float = flows[side] * dt
			if volume <= 0.0:
				continue
			var target: Vector2i = column + SIDES[side]
			var target_lake: Dictionary = _height_cached(target, heights)[2]
			var target_river: bool = _height_cached(target, heights)[3]
			if river_source and lake.is_empty():
				pass
			elif lake.is_empty():
				gains[column] = gains.get(column, 0.0) - volume
			else:
				var lost: String = terrain.lake_id(lake)
				lakes[lost] = lake
				lake_gains[lost] = lake_gains.get(lost, 0.0) - volume
			if target_river and target_lake.is_empty():
				pass
			elif target_lake.is_empty():
				gains[target] = gains.get(target, 0.0) + volume
			else:
				var won: String = terrain.lake_id(target_lake)
				lakes[won] = target_lake
				lake_gains[won] = lake_gains.get(won, 0.0) + volume
	var next := {}
	for column: Vector2i in active:
		if not columns.has(column):
			next[column] = true
	for column: Vector2i in gains:
		var now: float = depth.get(column, 0.0) + gains[column] / AREA
		if now > MIN_DEPTH:
			depth[column] = now
		else:
			depth.erase(column)
		changed_zones[zone_of(column)] = true
		next[column] = true
		for side: Vector2i in SIDES:
			next[column + side] = true
	for column: Vector2i in flux:
		next[column] = true
	for id: String in lake_gains:
		var lake: Dictionary = lakes[id]
		lake_levels[id] = lake_level_now(lake) + lake_gains[id] / terrain.lake_area(lake)
		changed_lakes[id] = lake
	if not gains.is_empty() or not lake_gains.is_empty():
		dirty = true
	active = next

func _height_cached(column: Vector2i, heights: Dictionary) -> Array:
	if not heights.has(column):
		heights[column] = _height(column)
	return heights[column]

# Volume d'eau libre (m³), pour vérifier que rien ne se crée ni ne se perd.
func free_volume() -> float:
	var total := 0.0
	for column: Vector2i in depth:
		total += depth[column] * AREA
	return total

# Surfaces d'eau libre d'une zone de 8 m : un carré par case, à la hauteur de l'eau.
func zone_faces(zone: Vector2i) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var low := zone * 16
	for x in range(low.x, low.x + 16):
		for z in range(low.y, low.y + 16):
			var column := Vector2i(x, z)
			var free: float = depth.get(column, 0.0)
			if free <= MIN_DEPTH * 2.0:
				continue
			var y := floor_of(column) + free
			var a := Vector3(x * CELL - CELL / 2.0, y, z * CELL - CELL / 2.0)
			var b := a + Vector3(CELL, 0, 0)
			var c := a + Vector3(CELL, 0, CELL)
			var d := a + Vector3(0, 0, CELL)
			faces.append_array([a, c, b, a, d, c])
	return faces

func save(folder: String) -> bool:
	if folder.is_empty() or not dirty:
		return true
	var cells := []
	for column: Vector2i in depth:
		cells.append([column.x, column.y, roundi(depth[column] * 1000.0)])
	var ok := Store.write_json(folder.path_join(FOLDER).path_join(LAKES_FILE), {"format": 1, "niveaux": lake_levels})
	ok = Store.write_json(folder.path_join(FOLDER).path_join(CELLS_FILE), {"format": 1, "cases": cells}) and ok
	if ok:
		dirty = false
	return ok

func load_from(folder: String) -> void:
	if folder.is_empty():
		return
	var lakes := Store.read_json(folder.path_join(FOLDER).path_join(LAKES_FILE), func(data): return data.get("niveaux") is Dictionary)
	if lakes.has("data"):
		for id in lakes.data.niveaux:
			if id is String and (lakes.data.niveaux[id] is float or lakes.data.niveaux[id] is int):
				lake_levels[id] = float(lakes.data.niveaux[id])
	var cells := Store.read_json(folder.path_join(FOLDER).path_join(CELLS_FILE), func(data): return data.get("cases") is Array)
	if cells.has("data"):
		for entry in cells.data.cases:
			if entry is Array and entry.size() == 3:
				var column := Vector2i(int(entry[0]), int(entry[1]))
				depth[column] = float(entry[2]) / 1000.0
				changed_zones[zone_of(column)] = true
				active[column] = true
