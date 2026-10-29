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
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
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
# 0.0.5.23 : « cell » : un sommet tous les 2 m près du joueur, tous les 4 m plus loin (4 fois moins de calcul) ;
# une petite jupe le long des bords cache les fentes entre carrés de finesse différente.
static func build(terrain, tile: Vector2i, hole: Rect2, cell := CELL) -> ArrayMesh:
	var origin := Vector2(tile) * TILE_METERS
	var cells := int(TILE_METERS / cell)
	var samples := []
	for i in range(cells + 1):
		for j in range(cells + 1):
			samples.append(_sample(terrain, origin + Vector2(i, j) * cell))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for i in range(cells):
		for j in range(cells):
			if hole.has_point(origin + (Vector2(i, j) + Vector2(0.5, 0.5)) * cell):
				continue
			var corners := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			# Sens des aiguilles d'une montre vu d'en haut, comme le terrain détaillé.
			tool.set_smooth_group(0)
			for index in [0, 1, 2, 0, 2, 3]:
				var corner: Vector2i = corners[index]
				var sample: Array = samples[corner.x * (cells + 1) + corner.y]
				tool.set_color(sample[1])
				var at := origin + Vector2(corner) * cell
				tool.add_vertex(Vector3(at.x, sample[0] - SINK, at.y))
			count += 1
			# Jupe : les côtés de la cellule au bord du carré descendent de quelques mètres (matière visible des deux côtés).
			for side in range(4):
				var a: Vector2i = corners[side]
				var b: Vector2i = corners[(side + 1) % 4]
				if not ((side == 0 and j == 0) or (side == 1 and i == cells - 1) or (side == 2 and j == cells - 1) or (side == 3 and i == 0)):
					continue
				var sa: Array = samples[a.x * (cells + 1) + a.y]
				var sb: Array = samples[b.x * (cells + 1) + b.y]
				var pa := origin + Vector2(a) * cell
				var pb := origin + Vector2(b) * cell
				var top_a := Vector3(pa.x, sa[0] - SINK, pa.y)
				var top_b := Vector3(pb.x, sb[0] - SINK, pb.y)
				var low_a := top_a - Vector3(0, SKIRT, 0)
				var low_b := top_b - Vector3(0, SKIRT, 0)
				tool.set_smooth_group(1)
				for vertex in [top_a, top_b, low_b, top_a, low_b, low_a]:
					tool.set_color(sa[1])
					tool.add_vertex(vertex)
	if count == 0:
		return null
	tool.generate_normals()
	return tool.commit()
