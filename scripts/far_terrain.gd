extends RefCounted
# 0.0.5.22 (#128) : niveaux de détail, notre propre méthode. Au-delà de la distance d'affichage (terrain détaillé :
# sous-cellules de 50 cm, herbe, collisions), le terrain lointain est un simple relief par carrés de 4 × 4 zones
# (32 m), un sommet tous les 2 m, coloré selon ce qu'on y verrait (herbe, sable, argile, boue, eau) ; ni herbe,
# ni collision, ni changements faits par le joueur. Il passe juste sous le bord du terrain détaillé (pas de trou).
const TILE_ZONES := 4
const TILE_METERS := 32.0
const CELL := 2.0
# Un peu plus bas que le vrai sol, pour rester caché sous le terrain détaillé là où ils se touchent.
const SINK := 0.2
const SKIRT := 3.0
const GRASS := Color(0.2, 0.32, 0.08)
const SAND := Color(0.56, 0.43, 0.25)
const CLAY := Color(0.27, 0.27, 0.22)
# Vus de loin, boue et argile restent proches du sol autour (plus de traînées presque noires).
const MUD := Color(0.19, 0.15, 0.09)
const WATER := Color(0.06, 0.17, 0.3)
const STONE := Color(0.3, 0.29, 0.27)
# 0.0.6 : neige et gravier vus de loin.
const SNOW := Color(0.82, 0.85, 0.9)
const GRAVEL := Color(0.31, 0.29, 0.26)
const NEEDLES := Color(0.36, 0.24, 0.13)

static var _material: ShaderMaterial

static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/far_terrain.gdshader")
		_material.set_shader_parameter("bare_tone", 0.85 if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 1.0)
	return _material

static func tile_of(zone: Vector2i) -> Vector2i:
	return Vector2i(floori(zone.x / float(TILE_ZONES)), floori(zone.y / float(TILE_ZONES)))

# Hauteur et couleur d'un point vu de loin (l'eau des lacs à son niveau).
# 0.0.5.23 : le point tombe sur une colonne : une seule hauteur à calculer (au lieu de 4), bien plus rapide.
static func _sample(terrain, at: Vector2) -> Array:
	var column := Vector2i(roundi(at.x / 0.5), roundi(at.y / 0.5))
	var height: float = terrain.ground_height(column)
	var level: float = terrain.water_level_at(at)
	if level > height:
		return [level, WATER]
	var top: int = terrain.surface_kind(column)
	var color := GRASS
	if top == terrain.SNOW:
		color = SNOW
	elif top == terrain.GRAVEL:
		color = GRAVEL
	elif top == terrain.NEEDLES:
		color = NEEDLES
	elif top == terrain.MUD:
		color = MUD
	elif top == terrain.CLAY:
		color = CLAY
	# Seulement les sommets rocheux : les petites plaques de pierre feraient des blocs gris au loin.
	elif top == terrain.STONE and terrain.mountain_stone(column) != INF:
		color = STONE
	elif terrain.is_desert(at):
		color = SAND
	return [height, color]

# 0.0.5.25 : relevé d'un carré en plusieurs fois (quelques colonnes par image, jamais d'à-coup) et gardé : refaire le
# trou du terrain détaillé ou revenir sur ses pas ne recalcule rien. « cell » : 2, 4 ou 8 m entre deux sommets.
static func new_survey(tile: Vector2i, cell: float) -> Dictionary:
	var side := int(TILE_METERS / cell) + 1
	var heights := PackedFloat32Array()
	heights.resize(side * side)
	var colors := PackedColorArray()
	colors.resize(side * side)
	return {"origin": Vector2(tile) * TILE_METERS, "cell": cell, "side": side, "next": 0, "heights": heights, "colors": colors}

# Avance le relevé jusqu'à l'heure limite (µs) ; vrai quand il est fini.
static func advance(terrain, survey: Dictionary, deadline: int) -> bool:
	var side: int = survey.side
	var origin: Vector2 = survey.origin
	var cell: float = survey.cell
	var heights: PackedFloat32Array = survey.heights
	var colors: PackedColorArray = survey.colors
	while survey.next < side:
		var i: int = survey.next
		for j in range(side):
			var sample := _sample(terrain, origin + Vector2(i, j) * cell)
			heights[i * side + j] = sample[0]
			colors[i * side + j] = sample[1]
		survey.next = i + 1
		survey.heights = heights
		survey.colors = colors
		if Time.get_ticks_usec() >= deadline:
			break
	return survey.next >= side

# Sommets, normales (pente du relief), couleurs ; la jupe (mêmes sommets, plus bas) à la suite. Une fois par relevé.
static func _prepare(survey: Dictionary) -> void:
	var side: int = survey.side
	var cell: float = survey.cell
	var origin: Vector2 = survey.origin
	var heights: PackedFloat32Array = survey.heights
	var colors: PackedColorArray = survey.colors
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	vertices.resize(side * side)
	normals.resize(side * side)
	for i in range(side):
		for j in range(side):
			var at := origin + Vector2(i, j) * cell
			vertices[i * side + j] = Vector3(at.x, heights[i * side + j] - SINK, at.y)
			var left := maxi(i - 1, 0)
			var right := mini(i + 1, side - 1)
			var back := maxi(j - 1, 0)
			var front := mini(j + 1, side - 1)
			var slope_x := (heights[right * side + j] - heights[left * side + j]) / ((right - left) * cell)
			var slope_z := (heights[i * side + front] - heights[i * side + back]) / ((front - back) * cell)
			normals[i * side + j] = Vector3(-slope_x, 1.0, -slope_z).normalized()
	var lower := PackedInt32Array()
	lower.resize(side * side)
	var skirt_colors := colors.duplicate()
	for i in range(side):
		for j in range(side):
			if i == 0 or j == 0 or i == side - 1 or j == side - 1:
				var index := i * side + j
				lower[index] = vertices.size()
				vertices.append(vertices[index] - Vector3(0.0, SKIRT, 0.0))
				normals.append(normals[index])
				skirt_colors.append(colors[index])
	survey.vertices = vertices
	survey.normals = normals
	survey.all_colors = skirt_colors
	survey.lower = lower

# Maillage d'un relevé fini ; « hole » : la partie couverte par le terrain détaillé (rien n'y est dessiné). Vide : null.
# 0.0.6 : trou aussi là où le terrain détaillé est vraiment affiché (shown : colonnes de zones finies) ; le lointain
# reste ailleurs, même à portée, tant que le détail n'est pas prêt (plus de montagne coupée en avançant vite).
static func _covered(at: Vector2, shown: Dictionary) -> bool:
	var zone_meters := TILE_METERS / TILE_ZONES
	for dx in [-2.0, 0.0, 2.0]:
		for dz in [-2.0, 0.0, 2.0]:
			if not shown.has(Vector2i(floori((at.x + dx) / zone_meters), floori((at.y + dz) / zone_meters))):
				return false
	return true

static func mesh_of(survey: Dictionary, hole: Rect2, shown: Dictionary = {}) -> ArrayMesh:
	if not survey.has("vertices"):
		_prepare(survey)
	var side: int = survey.side
	var cell: float = survey.cell
	var origin: Vector2 = survey.origin
	var lower: PackedInt32Array = survey.lower
	var indices := PackedInt32Array()
	for i in range(side - 1):
		for j in range(side - 1):
			var middle := origin + (Vector2(i, j) + Vector2(0.5, 0.5)) * cell
			if hole.has_point(middle) or (not shown.is_empty() and _covered(middle, shown)):
				continue
			var a := i * side + j
			var b := (i + 1) * side + j
			var c := (i + 1) * side + j + 1
			var d := i * side + j + 1
			# Sens des aiguilles d'une montre vu d'en haut, comme le terrain détaillé.
			indices.append_array([a, b, c, a, c, d])
			# Jupe sur les bords du carré, visible des deux côtés : cache les fentes entre carrés de finesse différente.
			if j == 0:
				_skirt(indices, a, b, lower)
			if i == side - 2:
				_skirt(indices, b, c, lower)
			if j == side - 2:
				_skirt(indices, c, d, lower)
			if i == 0:
				_skirt(indices, d, a, lower)
	if indices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = survey.vertices
	arrays[Mesh.ARRAY_NORMAL] = survey.normals
	arrays[Mesh.ARRAY_COLOR] = survey.all_colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _skirt(indices: PackedInt32Array, a: int, b: int, lower: PackedInt32Array) -> void:
	indices.append_array([a, b, lower[b], a, lower[b], lower[a], a, lower[b], b, a, lower[a], lower[b]])

# Carré entier, d'un coup (vitrine, tests).
static func build(terrain, tile: Vector2i, hole: Rect2, cell := CELL) -> ArrayMesh:
	var survey := new_survey(tile, cell)
	advance(terrain, survey, 9223372036854775807)
	return mesh_of(survey, hole)
