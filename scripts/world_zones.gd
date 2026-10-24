extends RefCounted
# 0.0.5.1 (étape 2 du Monde) : le monde est découpé en zones de ZONE_SIZE m de côté, empilées en hauteur.
# L'affichage et les collisions sont faits par sections de SECTION_SIZE m : un changement ne recalcule
# que la section touchée (et sa voisine si le bloc est au bord).
# Sauvegarde : un fichier compressé par zone modifiée (zones/zone_X_Y_Z.bin), rien pour les autres.
# Choix de l'utilisateur (0.0.5.1) : zones de 8 m (puissance de 2 dans les trois dimensions), plus légères
# sur le Web ; 16 reste possible (ZONE_SIZE multiple de SECTION_SIZE).
# Étape 3 : chaque zone pourra stocker une grille de densité (DENSITY_POINTS³ points : 1 m = 2 × 2 × 2
# parties de 50 cm) à la place des blocs (champ « type » du fichier : « blocs » aujourd'hui, « densite » plus tard).
const ZONE_SIZE := 8
const SECTION_SIZE := 8
const DENSITY_STEP := 0.5
const DENSITY_POINTS := int(ZONE_SIZE / DENSITY_STEP)
const FORMAT := 2
const TYPE_BLOCKS := "blocs"
# Ancien fichier de l'étape 1 (0.0.5), gardé sous ce nom une fois converti en zones.
const STEP1_KEPT := "zones/modifications-etape1.json"
# Faces d'un bloc : normale, puis deux axes (u × v = normale) ; sommets dans le sens des aiguilles d'une montre vus de dehors.
const FACES := [
	[Vector3i(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3i(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3i(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
	[Vector3i(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3i(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3i(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
]

static func zone_of(cell: Vector3i) -> Vector3i:
	return Vector3i(floori(cell.x / float(ZONE_SIZE)), floori(cell.y / float(ZONE_SIZE)), floori(cell.z / float(ZONE_SIZE)))

static func section_of(cell: Vector3i) -> Vector3i:
	return Vector3i(floori(cell.x / float(SECTION_SIZE)), floori(cell.y / float(SECTION_SIZE)), floori(cell.z / float(SECTION_SIZE)))

static func zone_sections(zone: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var per := ZONE_SIZE / SECTION_SIZE
	for x in range(per):
		for y in range(per):
			for z in range(per):
				result.append(zone * per + Vector3i(x, y, z))
	return result

static func zone_file(zone: Vector3i) -> String:
	return "zones/zone_%d_%d_%d.bin" % [zone.x, zone.y, zone.z]

# Sections voisines à recalculer quand un bloc change au bord de la sienne.
static func touched_sections(cell: Vector3i) -> Array[Vector3i]:
	var own := section_of(cell)
	var result: Array[Vector3i] = [own]
	for face in FACES:
		var other := section_of(cell + face[0])
		if not result.has(other):
			result.append(other)
	return result

# Maillage fusionné (faces visibles seulement, couleur par sommet) et collisions des blocs visibles.
static func build_section(blocks: Dictionary, section: Vector3i, colors: Array, material: Material, box: Shape3D) -> StaticBody3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tints := PackedColorArray()
	var body := StaticBody3D.new()
	var origin := section * SECTION_SIZE
	for x in range(SECTION_SIZE):
		for y in range(SECTION_SIZE):
			for z in range(SECTION_SIZE):
				var cell := origin + Vector3i(x, y, z)
				if not blocks.has(cell):
					continue
				var color: Color = colors[blocks[cell]]
				var visible := false
				for face in FACES:
					var normal: Vector3i = face[0]
					if blocks.has(cell + normal):
						continue
					visible = true
					var u: Vector3 = face[1]
					var v: Vector3 = face[2]
					var start := Vector3(cell) + Vector3(maxi(normal.x, 0), maxi(normal.y, 0), maxi(normal.z, 0))
					for corner in [start, start + v, start + u + v, start, start + u + v, start + u]:
						vertices.append(corner)
						normals.append(Vector3(normal))
						tints.append(color)
				if visible:
					var collision := CollisionShape3D.new()
					collision.shape = box
					collision.position = Vector3(cell) + Vector3.ONE * 0.5
					body.add_child(collision)
	if vertices.is_empty():
		body.free()
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = tints
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	body.add_child(instance)
	body.name = "Section_%d_%d_%d" % [section.x, section.y, section.z]
	body.add_to_group("blocks")
	body.set_meta("section", section)
	return body

static func valid_zone(data: Dictionary) -> bool:
	if data.get("format") != FORMAT or data.get("type") != TYPE_BLOCKS:
		return false
	if not data.get("poses") is Array or not data.get("casses") is Array:
		return false
	for entry in data.poses:
		if not entry is Array or entry.size() != 4 or not entry.all(func(v): return v is int):
			return false
	for entry in data.casses:
		if not entry is Array or entry.size() != 3 or not entry.all(func(v): return v is int):
			return false
	return true

# Écriture sûre et compressée (fichier temporaire, puis remplacement).
static func write_zone(path: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var temporary := path + ".tmp"
	var file := FileAccess.open_compressed(temporary, FileAccess.WRITE, FileAccess.COMPRESSION_DEFLATE)
	if file == null:
		return false
	file.store_var(data)
	var error := file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK

# Comme world_store.read_json : {"data"}, {"missing"} ou {"error"} (fichier mis de côté, jamais écrasé).
static func read_zone(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"missing": true}
	var data: Variant = null
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_DEFLATE)
	if file != null:
		data = file.get_var()
		file.close()
	if data is Dictionary and valid_zone(data):
		return {"data": data}
	var kept := path + ".illisible-" + Time.get_datetime_string_from_system().replace(":", "-")
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(kept))
	return {"error": "Zone illisible mise de côté : %s" % kept.get_file()}

static func zone_data(zone: Vector3i, placed: Array, removed: Array) -> Dictionary:
	return {"format": FORMAT, "type": TYPE_BLOCKS, "zone": [zone.x, zone.y, zone.z], "taille": ZONE_SIZE, "poses": placed, "casses": removed}
