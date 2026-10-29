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
const GRASS := Color(0.2, 0.32, 0.08)
const SAND := Color(0.56, 0.43, 0.25)
const CLAY := Color(0.24, 0.235, 0.22)
const MUD := Color(0.1, 0.07, 0.045)
const WATER := Color(0.1, 0.3, 0.36)
const STONE := Color(0.3, 0.29, 0.27)

static var _material: StandardMaterial3D

static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 1.0
		_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return _material

static func tile_of(zone: Vector2i) -> Vector2i:
	return Vector2i(floori(zone.x / float(TILE_ZONES)), floori(zone.y / float(TILE_ZONES)))

# Hauteur et couleur d'un point vu de loin (l'eau des lacs à son niveau).
static func _sample(terrain, at: Vector2) -> Array:
	var height: float = terrain.height_at(at.x, at.y)
	var level: float = terrain.water_level_at(at)
	if level > height:
		return [level, WATER]
	var column := Vector2i(roundi(at.x / 0.5), roundi(at.y / 0.5))
	var top: int = terrain.surface_kind(column)
	var color := GRASS
	if top == terrain.MUD:
		color = MUD
	elif top == terrain.CLAY:
		color = CLAY
	elif top == terrain.STONE:
		color = STONE
	elif terrain.is_desert(at):
		color = SAND
	return [height, color]

# Carré lointain ; « hole » : la partie couverte par le terrain détaillé (rien n'y est dessiné). Vide : null.
static func build(terrain, tile: Vector2i, hole: Rect2) -> ArrayMesh:
	var origin := Vector2(tile) * TILE_METERS
	var cells := int(TILE_METERS / CELL)
	var samples := []
	for i in range(cells + 1):
		for j in range(cells + 1):
			samples.append(_sample(terrain, origin + Vector2(i, j) * CELL))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for i in range(cells):
		for j in range(cells):
			if hole.has_point(origin + (Vector2(i, j) + Vector2(0.5, 0.5)) * CELL):
				continue
			var corners := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			# Sens des aiguilles d'une montre vu d'en haut, comme le terrain détaillé.
			for index in [0, 1, 2, 0, 2, 3]:
				var corner: Vector2i = corners[index]
				var sample: Array = samples[corner.x * (cells + 1) + corner.y]
				tool.set_color(sample[1])
				var at := origin + Vector2(corner) * CELL
				tool.add_vertex(Vector3(at.x, sample[0] - SINK, at.y))
			count += 1
	if count == 0:
		return null
	tool.generate_normals()
	return tool.commit()
