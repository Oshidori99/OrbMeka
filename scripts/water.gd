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
# Part de la différence de niveau passée à un voisin par pas (au plus 4 voisins : jamais plus que l'eau présente).
const FLOW := 0.2
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
	return [bottom, level, lake]

# Un pas : l'eau des cases actives descend vers les voisines plus basses. Rien ne bouge loin du joueur.
func step(center: Vector2) -> void:
	if active.is_empty():
		return
	var gains := {}
	var lake_gains := {}
	var lakes := {}
	var next := {}
	for column: Vector2i in active.keys():
		if (Vector2(column) * CELL).distance_to(center) > REACH:
			next[column] = true
			continue
		var here := _height(column)
		var lake: Dictionary = here[2]
		var available: float = INF if not lake.is_empty() else depth.get(column, 0.0)
		if available <= MIN_DEPTH:
			continue
		var moves := []
		var total := 0.0
		for side: Vector2i in SIDES:
			var there := _height(column + side)
			var drop: float = here[1] - there[1]
			# Même lac des deux côtés : rien ne coule.
			if drop <= 0.001 or (not lake.is_empty() and not there[2].is_empty() and terrain.lake_id(lake) == terrain.lake_id(there[2])):
				continue
			var amount := drop * FLOW
			moves.append([column + side, amount, there[2]])
			total += amount
		if moves.is_empty():
			continue
		var scale := minf(1.0, available / total) if lake.is_empty() else 1.0
		for move in moves:
			var amount: float = move[1] * scale
			if lake.is_empty():
				gains[column] = gains.get(column, 0.0) - amount
			else:
				var lost: String = terrain.lake_id(lake)
				lakes[lost] = lake
				lake_gains[lost] = lake_gains.get(lost, 0.0) - amount * AREA
			var target: Vector2i = move[0]
			var target_lake: Dictionary = move[2]
			if target_lake.is_empty():
				gains[target] = gains.get(target, 0.0) + amount
			else:
				var won: String = terrain.lake_id(target_lake)
				lakes[won] = target_lake
				lake_gains[won] = lake_gains.get(won, 0.0) + amount * AREA
			next[column] = true
			next[target] = true
	for column: Vector2i in gains:
		var now: float = depth.get(column, 0.0) + gains[column]
		if now > MIN_DEPTH:
			depth[column] = now
		else:
			depth.erase(column)
		changed_zones[zone_of(column)] = true
	for id: String in lake_gains:
		var lake: Dictionary = lakes[id]
		lake_levels[id] = lake_level_now(lake) + lake_gains[id] / terrain.lake_area(lake)
		changed_lakes[id] = lake
	if not gains.is_empty() or not lake_gains.is_empty():
		dirty = true
	active = next

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
