extends RefCounted
# 0.0.8.28 (#154, demandes de l'utilisateur) : la carte du monde, en 2D, comme une carte normale : couleur du sol (herbe,
# sable, neige…), l'eau en bleu, un peu de relief (ombré), les arbres en points verts.
# Ce qui est montré : les zones chargées autour du joueur, retenues au fil de la partie (« explorées », sauvegardées
# avec le joueur) ; « Tout voir » dessine une fois tout le monde (bouton de la grande carte).
# Léger : dessinée par carrés de TILE m (les carrés du terrain lointain), quelques rangées par image (budget en
# microsecondes), d'après la graine (FarTerrain._sample : hauteur et couleur, sans charger le monde) ; chaque carré
# dessiné une seule fois, gardé. L'image de la carte n'est envoyée à la carte graphique qu'au plus UPLOAD_EVERY s.
const FarTerrain = preload("res://scripts/far_terrain.gd")
const TILE := 32.0
const METERS_PER_PIXEL := 2.0
const TILE_PIXELS := 16
const UPLOAD_EVERY := 0.4
const UNKNOWN := Color(0.07, 0.08, 0.1, 1.0)
const TREE_COLOR := Color(0.09, 0.3, 0.07)
# Ombrage du relief : différence de hauteur (m) entre deux points voisins → éclairé (au nord-ouest) ou sombre.
const SHADE := 0.09

var half_meters := 384.0
var pixels := 384
var terrain
var cut_trees: Dictionary = {}
var explored: Dictionary = {}
var drawn: Dictionary = {}
var full: Image
var seen: Image
var full_texture: ImageTexture
var seen_texture: ImageTexture
var _queue: Array = []
var _row := 0
var _heights := PackedFloat32Array()
var _colors := PackedColorArray()
var _dirty := false
var _upload_wait := 0.0
var all_wanted := false

func setup(world_terrain, world_half_meters: float) -> void:
	terrain = world_terrain
	half_meters = world_half_meters
	pixels = int(ceil(half_meters * 2.0 / METERS_PER_PIXEL))
	full = Image.create(pixels, pixels, false, Image.FORMAT_RGBA8)
	full.fill(UNKNOWN)
	seen = Image.create(pixels, pixels, false, Image.FORMAT_RGBA8)
	seen.fill(UNKNOWN)
	full_texture = ImageTexture.create_from_image(full)
	seen_texture = ImageTexture.create_from_image(seen)

static func tile_of(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / TILE), floori(at.z / TILE))

# Point du monde → point de l'image (pixels).
func pixel_of(at: Vector3) -> Vector2:
	return Vector2((at.x + half_meters) / METERS_PER_PIXEL, (at.z + half_meters) / METERS_PER_PIXEL)

func _inside(tile: Vector2i) -> bool:
	var low := -int(half_meters / TILE)
	return tile.x >= low and tile.y >= low and tile.x < -low and tile.y < -low

# Les carrés chargés autour du joueur (rayon en m) deviennent explorés ; ceux pas encore dessinés vont dans la file.
func explore(at: Vector3, radius: float) -> void:
	var center := tile_of(at)
	var reach := int(ceil(radius / TILE))
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var tile := center + Vector2i(dx, dz)
			if not _inside(tile) or explored.has(tile):
				continue
			if Vector2(dx, dz).length() * TILE > radius + TILE:
				continue
			explored[tile] = true
			if drawn.has(tile):
				_copy_to_seen(tile)
			else:
				_queue.push_front(tile)

# « Tout voir » : tous les carrés du monde dans la file (après ceux déjà demandés).
func want_all() -> void:
	all_wanted = true
	var low := -int(half_meters / TILE)
	for x in range(low, -low):
		for z in range(low, -low):
			var tile := Vector2i(x, z)
			if not drawn.has(tile) and not _queue.has(tile):
				_queue.append(tile)

# Part du monde déjà dessinée (0 à 1).
func progress() -> float:
	var side := int(half_meters / TILE) * 2
	return float(drawn.size()) / maxf(float(side * side), 1.0)

func busy() -> bool:
	return not _queue.is_empty()

# Dessine des rangées jusqu'à « budget » microsecondes ; envoie l'image au plus toutes les UPLOAD_EVERY s.
func step(delta: float, budget: int) -> void:
	var stop := Time.get_ticks_usec() + budget
	while not _queue.is_empty() and Time.get_ticks_usec() < stop:
		_draw_row(_queue[0])
	_upload_wait -= delta
	if _dirty and _upload_wait <= 0.0:
		_upload_wait = UPLOAD_EVERY
		_dirty = false
		full_texture.update(full)
		seen_texture.update(seen)

func _draw_row(tile: Vector2i) -> void:
	var side := TILE_PIXELS + 1
	if _row == 0:
		_heights.resize(side * side)
		_colors.resize(side * side)
	# Une rangée de points (une de plus que de pixels : le relief se calcule avec le voisin).
	var z := tile.y * TILE + _row * METERS_PER_PIXEL
	for column in range(side):
		var x := tile.x * TILE + column * METERS_PER_PIXEL
		var sample: Array = FarTerrain._sample(terrain, Vector2(x, z))
		_heights[_row * side + column] = float(sample[0])
		_colors[_row * side + column] = sample[1]
	_row += 1
	if _row < side:
		return
	_row = 0
	_queue.pop_front()
	_finish_tile(tile)

func _finish_tile(tile: Vector2i) -> void:
	var side := TILE_PIXELS + 1
	var origin := Vector2i(roundi((tile.x * TILE + half_meters) / METERS_PER_PIXEL), roundi((tile.y * TILE + half_meters) / METERS_PER_PIXEL))
	for row in range(TILE_PIXELS):
		for column in range(TILE_PIXELS):
			var here := _heights[row * side + column]
			var slope := (here - _heights[row * side + column + 1]) + (here - _heights[(row + 1) * side + column])
			var light := clampf(1.0 + slope * SHADE, 0.72, 1.28)
			var color: Color = _colors[row * side + column]
			# Les couleurs du terrain lointain sont faites pour la 3D (assez sombres) : un peu éclaircies sur la carte.
			color = Color(minf(color.r * 1.7 * light, 1.0), minf(color.g * 1.7 * light, 1.0), minf(color.b * 1.7 * light, 1.0), 1.0)
			var pixel := origin + Vector2i(column, row)
			if pixel.x >= 0 and pixel.y >= 0 and pixel.x < pixels and pixel.y < pixels:
				full.set_pixelv(pixel, color)
	# Les arbres de ses zones : un point vert (ceux qu'on a coupés : non).
	if terrain.has_method("trees_in_zone"):
		var zones := int(TILE / 8.0)
		for dx in range(zones):
			for dz in range(zones):
				for tree: Dictionary in terrain.trees_in_zone(Vector2i(tile.x * zones + dx, tile.y * zones + dz)):
					if cut_trees.has(str(tree.get("id", ""))):
						continue
					var at := Vector2i(roundi((float(tree.x) + half_meters) / METERS_PER_PIXEL), roundi((float(tree.z) + half_meters) / METERS_PER_PIXEL))
					if at.x >= 0 and at.y >= 0 and at.x < pixels and at.y < pixels:
						full.set_pixelv(at, TREE_COLOR)
	drawn[tile] = true
	if explored.has(tile):
		_copy_to_seen(tile)
	_dirty = true

func _copy_to_seen(tile: Vector2i) -> void:
	var origin := Vector2i(roundi((tile.x * TILE + half_meters) / METERS_PER_PIXEL), roundi((tile.y * TILE + half_meters) / METERS_PER_PIXEL))
	seen.blit_rect(full, Rect2i(origin, Vector2i(TILE_PIXELS, TILE_PIXELS)), origin)
	_dirty = true

# Sauvegarde : les carrés explorés [[x, z], …] ; relus : redessinés peu à peu.
func to_array() -> Array:
	return explored.keys().map(func(tile: Vector2i): return [tile.x, tile.y])

func from_array(data: Variant) -> void:
	if not data is Array:
		return
	for entry in data:
		if entry is Array and entry.size() == 2 and (entry[0] is float or entry[0] is int) and (entry[1] is float or entry[1] is int):
			var tile := Vector2i(int(entry[0]), int(entry[1]))
			if _inside(tile) and not explored.has(tile):
				explored[tile] = true
				_queue.append(tile)

# --- 0.0.8.35 (#252, demandes de l'utilisateur) : points de repère. Un bouton « Ajouter un repère » sur la grande carte
# (O + M), ou M + R en jeu : un repère là où l'on est, nommé comme on veut (grande carte). Vus sur les deux cartes (sur
# la mini-carte, au bord quand ils sont loin) avec leur distance. Enregistrés dans joueur.json (« reperes »).
const WAYPOINT_COLORS := [Color("#ff6b6b"), Color("#ffd166"), Color("#06d6a0"), Color("#4cc9f0"), Color("#b388ff"), Color("#ff9f1c")]
const MAX_WAYPOINTS := 64
const MAX_NAME := 24
# {"nom": String, "x": float, "z": float, "couleur": int}
var waypoints: Array = []

func add_waypoint(at: Vector3) -> Dictionary:
	if waypoints.size() >= MAX_WAYPOINTS:
		return {}
	var number := waypoints.size() + 1
	var names := waypoints.map(func(point): return point.nom)
	while names.has("Repère %d" % number):
		number += 1
	var point := {"nom": "Repère %d" % number, "x": snappedf(at.x, 0.1), "z": snappedf(at.z, 0.1), "couleur": waypoints.size() % WAYPOINT_COLORS.size()}
	waypoints.append(point)
	return point

func rename_waypoint(index: int, name: String) -> void:
	if index >= 0 and index < waypoints.size():
		var clean := name.strip_edges().left(MAX_NAME)
		if not clean.is_empty():
			waypoints[index].nom = clean

func remove_waypoint(index: int) -> void:
	if index >= 0 and index < waypoints.size():
		waypoints.remove_at(index)

static func waypoint_color(point: Dictionary) -> Color:
	return WAYPOINT_COLORS[clampi(int(point.get("couleur", 0)), 0, WAYPOINT_COLORS.size() - 1)]

func waypoints_to_array() -> Array:
	return waypoints.duplicate(true)

func waypoints_from_array(data: Variant) -> void:
	waypoints = []
	if not data is Array:
		return
	for entry in data:
		if entry is Dictionary and entry.get("nom") is String and (entry.get("x") is float or entry.get("x") is int) and (entry.get("z") is float or entry.get("z") is int) and waypoints.size() < MAX_WAYPOINTS:
			waypoints.append({"nom": str(entry.nom).left(MAX_NAME), "x": float(entry.x), "z": float(entry.z), "couleur": clampi(int(entry.get("couleur", 0)), 0, WAYPOINT_COLORS.size() - 1)})

# Dessine un repère (pastille de sa couleur, bord noir).
static func draw_waypoint(canvas: CanvasItem, at: Vector2, point: Dictionary, radius: float) -> void:
	canvas.draw_circle(at, radius + 1.5, Color(0, 0, 0, 0.85))
	canvas.draw_circle(at, radius, waypoint_color(point))
