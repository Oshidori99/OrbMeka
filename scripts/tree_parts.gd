extends RefCounted
# 0.0.7.12 (demande de l'utilisateur) : branches et tiges d'un modèle d'arbre, pour couper SEULEMENT ce qu'on vise.
# Dans les modèles Blender (assets/trees), chaque tronc, tige (noisetier) ou branche est un tube d'écorce séparé, et chaque
# feuille une petite pièce : on retrouve les tubes (« pièces »), leur axe, leur épaisseur le long de l'axe, et à quelle
# pièce chacune est attachée (la plus proche de son bout de départ). Chaque feuille, fruit ou trou appartient à la pièce
# la plus proche. Une coupe [pièce, t] (t : mètres depuis le départ de la pièce, repère du modèle) détache tout ce qui est
# au-delà : la fin de la pièce, ses branches attachées plus loin que t et tout ce qu'elles portent.
# Les morceaux d'un arbre : 0 = ce qui reste en place ; k = détaché par la coupe k (sans ce que les coupes suivantes ont
# détaché de lui). Calculé une fois par modèle (sauf les morceaux, par liste de coupes).
const Trees = preload("res://scripts/trees.gd")

const ROOT_HEIGHT := 0.12
# Profil d'épaisseur : rayons moyens sur PROFILE_BINS tranches le long de chaque pièce.
const PROFILE_BINS := 8

static var _skeletons: Dictionary = {}
static var _assignments: Dictionary = {}

static func _key(kind: int, size: int, form: int) -> String:
	return "%d_%d_%d" % [kind, clampi(size, 1, Trees.SIZES), clampi(form, 0, Trees.FORMS - 1)]

# --- Squelette ---

static func skeleton(kind: int, size: int, form: int) -> Dictionary:
	var key := _key(kind, size, form)
	if _skeletons.has(key):
		return _skeletons[key]
	var full := Trees.mesh(kind, size, false, form)
	var bark_material := Trees.material(kind, "bark")
	var leaf_material := Trees.material(kind, "leaves")
	var pieces: Array = []
	var surfaces: Array = []
	# Écorce : pièces reliées par leurs triangles (ou par des sommets au même endroit).
	for surface in range(full.get_surface_count()):
		var arrays := full.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		# Tableaux ordinaires (partagés, modifiables dans le dictionnaire).
		var owners := []
		owners.resize(indices.size() / 3)
		owners.fill(-1)
		var params := []
		params.resize(indices.size() / 3)
		params.fill(0.0)
		var info := {"bark": full.surface_get_material(surface) == bark_material, "leaves": full.surface_get_material(surface) == leaf_material, "owner": owners, "param": params}
		surfaces.append(info)
		if not info.bark:
			continue
		var parent := PackedInt32Array()
		parent.resize(points.size())
		for index in range(points.size()):
			parent[index] = index
		var same := {}
		for index in range(points.size()):
			var spot := Vector3i((points[index] * 2000.0).round())
			if same.has(spot):
				_join(parent, index, same[spot])
			else:
				same[spot] = index
		for at in range(0, indices.size() - 2, 3):
			_join(parent, indices[at], indices[at + 1])
			_join(parent, indices[at], indices[at + 2])
		var groups := {}
		for at in range(0, indices.size() - 2, 3):
			var root := _find(parent, indices[at])
			# Tableaux ordinaires : un tableau « packed » lu dans un dictionnaire est une copie (append perdu).
			if not groups.has(root):
				groups[root] = {"triangles": [], "points": []}
			groups[root].triangles.append(at / 3)
			for corner in range(3):
				groups[root].points.append(points[indices[at + corner]])
		for root in groups:
			var piece := _shape(PackedVector3Array(groups[root].points))
			piece.surface = surface
			piece.triangles = groups[root].triangles
			pieces.append(piece)
	# Ordre fixe (numéros gardés dans la sauvegarde) : par bout de départ.
	pieces.sort_custom(func(a, b): return [a.low.y, a.low.x, a.low.z] < [b.low.y, b.low.x, b.low.z])
	_link(pieces)
	# Paramètre de chaque triangle d'écorce le long de sa pièce.
	for number in range(pieces.size()):
		var piece: Dictionary = pieces[number]
		var arrays := full.surface_get_arrays(piece.surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var corners := PackedVector3Array()
		for triangle in piece.triangles:
			var at: int = triangle * 3
			var center := (points[indices[at]] + points[indices[at + 1]] + points[indices[at + 2]]) / 3.0
			surfaces[piece.surface].owner[triangle] = number
			surfaces[piece.surface].param[triangle] = along(piece, center)
			corners.append_array([points[indices[at]], points[indices[at + 1]], points[indices[at + 2]]])
		# 0.0.7.13 : triangles de la pièce (vraie tranche : true_thickness).
		piece.corners = corners
	# Feuilles, trous, cônes : à la pièce la plus proche.
	var grid := _grid(pieces)
	var leaves := 0
	for surface in range(surfaces.size()):
		var info: Dictionary = surfaces[surface]
		if info.bark:
			continue
		var arrays := full.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for at in range(0, indices.size() - 2, 3):
			var center := (points[indices[at]] + points[indices[at + 1]] + points[indices[at + 2]]) / 3.0
			var number := _nearest(pieces, grid, center)
			info.owner[at / 3] = number
			info.param[at / 3] = along(pieces[number], center) if number >= 0 else 0.0
			if info.leaves:
				leaves += 1
	var fruits := []
	for spot in Trees.fruit_spots(kind, size, form):
		var number := _nearest(pieces, grid, spot[0])
		fruits.append([number, along(pieces[number], spot[0]) if number >= 0 else 0.0])
	var made := {"pieces": pieces, "surfaces": surfaces, "leaves": leaves, "fruits": fruits}
	_skeletons[key] = made
	return made

static func _find(parent: PackedInt32Array, index: int) -> int:
	while parent[index] != index:
		parent[index] = parent[parent[index]]
		index = parent[index]
	return index

static func _join(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[ra] = rb

# Axe d'une pièce (direction principale de ses sommets), ses deux bouts et son épaisseur le long de l'axe.
static func _shape(points: PackedVector3Array) -> Dictionary:
	var mean := Vector3.ZERO
	for point in points:
		mean += point
	mean /= points.size()
	var xx := 0.0
	var xy := 0.0
	var xz := 0.0
	var yy := 0.0
	var yz := 0.0
	var zz := 0.0
	for point in points:
		var d := point - mean
		xx += d.x * d.x
		xy += d.x * d.y
		xz += d.x * d.z
		yy += d.y * d.y
		yz += d.y * d.z
		zz += d.z * d.z
	var axis := Vector3(0.3, 1.0, 0.2).normalized()
	for step in range(24):
		var next := Vector3(xx * axis.x + xy * axis.y + xz * axis.z, xy * axis.x + yy * axis.y + yz * axis.z, xz * axis.x + yz * axis.y + zz * axis.z)
		if next.length() < 0.000001:
			break
		axis = next.normalized()
	var low := INF
	var high := -INF
	for point in points:
		var p := (point - mean).dot(axis)
		low = minf(low, p)
		high = maxf(high, p)
	var a := mean + axis * low
	var b := mean + axis * high
	# Départ provisoire : le bout le plus bas (corrigé par _link pour les branches).
	if b.y < a.y:
		var swap := a
		a = b
		b = swap
	var piece := {"low": a, "start": a, "tip": b, "length": maxf(a.distance_to(b), 0.001), "parent": -1, "attach": 0.0, "depth": 0}
	piece.direction = (b - a) / piece.length
	piece.profile = _profile(piece, points)
	# Rayon typique (médiane : une branche courbée gonfle certaines tranches).
	var sorted: Array = Array(piece.profile)
	sorted.sort()
	piece.radius = float(sorted[sorted.size() / 2])
	piece.root = a.y < ROOT_HEIGHT
	return piece

static func _profile(piece: Dictionary, points: PackedVector3Array) -> PackedFloat32Array:
	var sums := PackedFloat32Array()
	var counts := PackedInt32Array()
	sums.resize(PROFILE_BINS)
	counts.resize(PROFILE_BINS)
	for point in points:
		var t := clampf((point - piece.start).dot(piece.direction) / piece.length, 0.0, 0.9999)
		var bin := int(t * PROFILE_BINS)
		var on_axis: Vector3 = piece.start + piece.direction * (t * piece.length)
		sums[bin] += point.distance_to(on_axis)
		counts[bin] += 1
	var profile := PackedFloat32Array()
	profile.resize(PROFILE_BINS)
	var last := 0.0
	for bin in range(PROFILE_BINS):
		if counts[bin] > 0:
			last = sums[bin] / counts[bin]
		profile[bin] = last
	# Tranches vides au début : la première épaisseur connue.
	for bin in range(PROFILE_BINS - 1, -1, -1):
		if counts[bin] > 0:
			last = profile[bin]
		elif profile[bin] == 0.0:
			profile[bin] = last
	return profile

# Chaque branche part du bout le plus proche d'une autre pièce au moins aussi épaisse (sa « mère ») ; les pièces qui
# partent du sol (tronc, tiges, racines) n'ont pas de mère.
static func _link(pieces: Array) -> void:
	# Des plus épaisses aux plus fines : une branche choisit sa mère parmi les pièces de départ et celles déjà reliées
	# (jamais de boucle, même pour deux branches qui partent du même point).
	var order: Array = range(pieces.size())
	order.sort_custom(func(a, b): return pieces[a].radius > pieces[b].radius or (pieces[a].radius == pieces[b].radius and a < b))
	var linked := {}
	for number in range(pieces.size()):
		if pieces[number].root:
			linked[number] = true
	for number in order:
		var piece: Dictionary = pieces[number]
		if piece.root:
			continue
		var best := INF
		var best_parent := -1
		var best_start := 0
		for end in range(2):
			var spot: Vector3 = piece.start if end == 0 else piece.tip
			for other in linked:
				if other == number:
					continue
				var gap := _segment_distance(pieces[other], spot) - float(pieces[other].radius)
				if gap < best:
					best = gap
					best_parent = other
					best_start = end
		if best_start == 1:
			var swap: Vector3 = piece.start
			piece.start = piece.tip
			piece.tip = swap
			piece.direction = -piece.direction
			var profile: PackedFloat32Array = piece.profile
			profile.reverse()
			piece.profile = profile
		piece.parent = best_parent
		if best_parent >= 0:
			piece.attach = along(pieces[best_parent], piece.start)
		linked[number] = true
	# Pas de boucle : une pièce qui remonte jusqu'à elle-même devient une pièce de départ.
	for number in range(pieces.size()):
		var seen := {number: true}
		var at: int = pieces[number].parent
		var depth := 0
		while at >= 0:
			depth += 1
			if seen.has(at):
				pieces[number].parent = -1
				depth = 0
				break
			seen[at] = true
			at = pieces[at].parent
		pieces[number].depth = depth
	for number in range(pieces.size()):
		var chain := []
		var at: int = number
		while pieces[at].parent >= 0:
			chain.append([pieces[at].parent, pieces[at].attach])
			at = pieces[at].parent
		pieces[number].chain = chain

static func along(piece: Dictionary, point: Vector3) -> float:
	return clampf((point - piece.start).dot(piece.direction), 0.0, piece.length)

static func _segment_distance(piece: Dictionary, point: Vector3) -> float:
	return point.distance_to(piece.start + piece.direction * along(piece, point))

# 0.0.7.13 (l'utilisateur : « des petits arbres cotés comme des gros ») : vrai diamètre d'une pièce à t mètres de son
# départ (repère du modèle) : tranche de SES triangles par le plan perpendiculaire à son axe, puis la largeur la plus
# petite sur 18 directions (une tranche un peu oblique d'une branche courbée reste juste). Le profil (thickness) mesurait
# la distance moyenne à l'axe : presque le double sur une branche courbée.
static func true_thickness(piece: Dictionary, t: float) -> float:
	var corners: PackedVector3Array = piece.get("corners", PackedVector3Array())
	var axis: Vector3 = piece.direction
	var center: Vector3 = piece.start + axis * clampf(t, 0.0, piece.length)
	var side: Vector3 = axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var other: Vector3 = axis.cross(side).normalized()
	var flat := PackedVector2Array()
	for at in range(0, corners.size() - 2, 3):
		for edge in [[0, 1], [1, 2], [2, 0]]:
			var a: Vector3 = corners[at + edge[0]]
			var b: Vector3 = corners[at + edge[1]]
			var da := (a - center).dot(axis)
			var db := (b - center).dot(axis)
			if da * db < 0.0:
				var point := a.lerp(b, da / (da - db)) - center
				flat.append(Vector2(point.dot(side), point.dot(other)))
	if flat.size() < 3:
		return thickness(piece, t)
	var thinnest := INF
	for step in range(18):
		var across := Vector2.from_angle(PI * step / 18.0)
		var low := INF
		var high := -INF
		for point in flat:
			low = minf(low, point.dot(across))
			high = maxf(high, point.dot(across))
		thinnest = minf(thinnest, high - low)
	return clampf(thinnest, 0.005, 1.5)

# Épaisseur approchée (diamètre, repère du modèle) d'une pièce à t mètres de son départ : rapide, pour viser.
static func thickness(piece: Dictionary, t: float) -> float:
	var bin := clampi(int(t / piece.length * PROFILE_BINS), 0, PROFILE_BINS - 1)
	return maxf(piece.profile[bin] * 2.0, 0.005)

static func _grid(pieces: Array) -> Dictionary:
	var grid := {}
	for number in range(pieces.size()):
		var piece: Dictionary = pieces[number]
		var box := AABB(piece.start, Vector3.ZERO).expand(piece.tip).grow(piece.radius + 0.5)
		for x in range(floori(box.position.x), floori(box.end.x) + 1):
			for y in range(floori(box.position.y), floori(box.end.y) + 1):
				for z in range(floori(box.position.z), floori(box.end.z) + 1):
					var cell := Vector3i(x, y, z)
					if not grid.has(cell):
						grid[cell] = []
					grid[cell].append(number)
	return grid

static func _nearest(pieces: Array, grid: Dictionary, point: Vector3) -> int:
	var cell := Vector3i(floori(point.x), floori(point.y), floori(point.z))
	var choices: Array = grid.get(cell, range(pieces.size()))
	var best := INF
	var found := -1
	for number in choices:
		var gap := _segment_distance(pieces[number], point)
		if gap < best:
			best = gap
			found = number
	return found

# --- Coupes et morceaux ---

# Vrai si la coupe [pièce, t] détache ce point (pièce owner, t param).
static func detaches(pieces: Array, cut: Array, owner: int, param: float) -> bool:
	if owner < 0:
		return false
	var number := int(cut[0])
	if owner == number:
		return param > float(cut[1])
	for link in pieces[owner].chain:
		if int(link[0]) == number:
			return float(link[1]) > float(cut[1])
	return false

# Morceau de chaque triangle (par surface) pour une liste de coupes : le plus petit ensemble détaché qui le contient.
static func assignment(kind: int, size: int, form: int, cuts: Array) -> Dictionary:
	var key := _key(kind, size, form) + str(cuts)
	if _assignments.has(key):
		return _assignments[key]
	var made := skeleton(kind, size, form)
	var pieces: Array = made.pieces
	var sizes := []
	for cut in cuts:
		var count := 0
		for info in made.surfaces:
			for triangle in range(info.owner.size()):
				if detaches(pieces, cut, info.owner[triangle], info.param[triangle]):
					count += 1
		sizes.append(count)
	var parts := []
	var leaves := PackedInt32Array()
	leaves.resize(cuts.size() + 1)
	var ranges := []
	for part in range(cuts.size() + 1):
		ranges.append({})
	for info in made.surfaces:
		var of := PackedInt32Array()
		of.resize(info.owner.size())
		for triangle in range(info.owner.size()):
			of[triangle] = _part_of(pieces, cuts, sizes, info.owner[triangle], info.param[triangle])
			if info.leaves:
				leaves[of[triangle]] += 1
		parts.append(of)
	# 0.0.7.15 : étendue exacte de chaque pièce dans chaque morceau, d'une coupe à l'autre (tronçons entre les coupes de
	# la pièce, chacun au morceau de son milieu). Avant : d'après les centres des triangles, qui confondait deux coupes
	# proches (monde T56 : un tronçon de 23 cm devenu un tronc de 9,5 m) et oubliait un tronçon trop court.
	for number in range(pieces.size()):
		var bounds := [0.0, float(pieces[number].length)]
		for cut in cuts:
			if int(cut[0]) == number:
				bounds.append(clampf(float(cut[1]), 0.0, pieces[number].length))
		bounds.sort()
		for index in range(bounds.size() - 1):
			var low: float = bounds[index]
			var high: float = bounds[index + 1]
			if high - low < 0.0005:
				continue
			var spans: Dictionary = ranges[_part_of(pieces, cuts, sizes, number, (low + high) * 0.5)]
			spans[number] = Vector2(minf(spans[number].x, low), maxf(spans[number].y, high)) if spans.has(number) else Vector2(low, high)
	var fruits := PackedInt32Array()
	for fruit in made.fruits:
		fruits.append(_part_of(pieces, cuts, sizes, fruit[0], fruit[1]))
	var result := {"parts": parts, "leaves": leaves, "ranges": ranges, "fruits": fruits}
	if _assignments.size() > 64:
		_assignments.clear()
	_assignments[key] = result
	return result

# 0.0.7.16 (monde T56 : deux coupes à 15 cm sur un tronc de pin, sans triangle ni branche entre elles : même taille,
# la première gagnait et la seconde restait vide, le petit bout collé au haut) : à taille égale, l'ensemble le plus
# petit est celui de la pièce la plus profonde, puis la coupe la plus loin sur la pièce.
static func _part_of(pieces: Array, cuts: Array, sizes: Array, owner: int, param: float) -> int:
	var best := 0
	for index in range(cuts.size()):
		if not detaches(pieces, cuts[index], owner, param):
			continue
		if best == 0 or _smaller(pieces, cuts, sizes, index, best - 1):
			best = index + 1
	return best

static func _smaller(pieces: Array, cuts: Array, sizes: Array, a: int, b: int) -> bool:
	if sizes[a] != sizes[b]:
		return sizes[a] < sizes[b]
	var depth_a: int = pieces[int(cuts[a][0])].depth
	var depth_b: int = pieces[int(cuts[b][0])].depth
	if depth_a != depth_b:
		return depth_a > depth_b
	return float(cuts[a][1]) > float(cuts[b][1])

# Ancienne règle (jusqu'à 0.0.7.15) : à taille égale, la première coupe gagnait. Coupes devenues vides ainsi, à retirer
# d'une sauvegarde ancienne (world.gd, _restore_parts) : leurs numéros (1 = première coupe).
static func old_empty_cuts(kind: int, size: int, form: int, cuts: Array) -> Array:
	var sizes := _sizes_for(kind, size, form, cuts)
	var empty := []
	for index in range(cuts.size()):
		for earlier in range(index):
			if sizes[earlier] == sizes[index] and int(cuts[earlier][0]) == int(cuts[index][0]) and float(cuts[earlier][1]) < float(cuts[index][1]):
				empty.append(index + 1)
				break
	return empty

# Modèle d'un morceau (seulement ses triangles).
static func part_mesh(kind: int, size: int, form: int, cuts: Array, part: int) -> ArrayMesh:
	var full := Trees.mesh(kind, size, false, form)
	var made_skeleton := skeleton(kind, size, form)
	var pieces: Array = made_skeleton.pieces
	var parts: Array = assignment(kind, size, form, cuts).parts
	# Pièces coupées : leurs tronçons entre les coupes, et le morceau de chacun. Un triangle d'écorce qui traverse une
	# coupe (les troncs sont faits de longues bandes) est gardé des deux côtés, ses sommets ramenés au plan de coupe :
	# coupe nette, sans dents de scie.
	var sizes := _sizes_for(kind, size, form, cuts)
	var limits := {}
	for cut in cuts:
		var number := int(cut[0])
		if limits.has(number):
			continue
		var bounds := [0.0, float(pieces[number].length)]
		for other in cuts:
			if int(other[0]) == number:
				bounds.append(float(other[1]))
		bounds.sort()
		var mine := []
		for index in range(bounds.size() - 1):
			var low: float = bounds[index]
			var high: float = bounds[index + 1]
			if high - low > 0.0005 and _part_of(pieces, cuts, sizes, number, (low + high) * 0.5) == part:
				mine.append(Vector2(low, high))
		limits[number] = mine
	var made := ArrayMesh.new()
	for surface in range(full.get_surface_count()):
		var arrays := full.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var of: PackedInt32Array = parts[surface]
		var owners: Array = made_skeleton.surfaces[surface].owner
		var bark: bool = made_skeleton.surfaces[surface].bark
		var kept := PackedInt32Array()
		var clamped := {}
		var extra := points.size()
		var new_points := []
		var sources := []
		for triangle in range(of.size()):
			var owner: int = owners[triangle]
			if bark and limits.has(owner):
				# Écorce d'une pièce coupée : par l'étendue de ses sommets, pas par son centre.
				var piece: Dictionary = pieces[owner]
				var params := []
				for corner in range(3):
					params.append((points[indices[triangle * 3 + corner]] - piece.start).dot(piece.direction))
				var low: float = params.min()
				var high: float = params.max()
				for span in limits[owner]:
					var from := maxf(low, span.x if span.x > 0.0 else -INF)
					var to := minf(high, span.y if span.y < piece.length else INF)
					if to - from <= 0.0005:
						continue
					# Sommets propres à ce tronçon (un sommet peut être ramené différemment de chaque côté).
					for corner in range(3):
						var index: int = indices[triangle * 3 + corner]
						var key := "%d/%s" % [index, str(span)]
						if not clamped.has(key):
							var param: float = params[corner]
							var moved: Vector3 = points[index]
							if span.y < piece.length and param > span.y:
								moved -= piece.direction * (param - span.y)
							elif span.x > 0.0 and param < span.x:
								moved += piece.direction * (span.x - param)
							clamped[key] = extra + new_points.size()
							new_points.append(moved)
							sources.append(index)
						kept.append(clamped[key])
					break
				continue
			if of[triangle] == part:
				kept.append_array([indices[triangle * 3], indices[triangle * 3 + 1], indices[triangle * 3 + 2]])
		if kept.is_empty():
			continue
		if not new_points.is_empty():
			# Sommets ajoutés : copies des sommets d'origine (normales, UV…), à leur place ramenée. Nombre de sommets figé
			# avant (le tableau des sommets est partagé : il grandit pendant la boucle).
			var base_count := extra
			for kind_index in range(Mesh.ARRAY_MAX):
				if kind_index == Mesh.ARRAY_INDEX or arrays[kind_index] == null:
					continue
				var source = arrays[kind_index].duplicate()
				var stride: int = source.size() / base_count
				for at in range(sources.size()):
					for value in range(stride):
						source.append(source[sources[at] * stride + value])
				arrays[kind_index] = source
			var grown: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for at in range(new_points.size()):
				grown[extra + at] = new_points[at]
			arrays[Mesh.ARRAY_VERTEX] = grown
			points = grown
		var count := points.size()
		var remap := {}
		var order := PackedInt32Array()
		for index in kept:
			if not remap.has(index):
				remap[index] = order.size()
				order.append(index)
		for kind_index in range(Mesh.ARRAY_MAX):
			if kind_index == Mesh.ARRAY_INDEX or arrays[kind_index] == null:
				continue
			var source = arrays[kind_index]
			var stride: int = source.size() / count
			var packed = source.slice(0, 0)
			for index in order:
				for value in range(stride):
					packed.append(source[index * stride + value])
			arrays[kind_index] = packed
		for at in range(kept.size()):
			kept[at] = remap[kept[at]]
		arrays[Mesh.ARRAY_INDEX] = kept
		made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		made.surface_set_material(made.get_surface_count() - 1, full.surface_get_material(surface))
	return made

# Faces coupées d'un morceau : un disque de bois clair à chaque coupe qui le borde (son bout coupé et ceux qu'on lui a
# retirés), perpendiculaire à la pièce coupée.
static func cut_faces(kind: int, size: int, form: int, cuts: Array, part: int) -> ArrayMesh:
	var pieces: Array = skeleton(kind, size, form).pieces
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var sizes := _sizes_for(kind, size, form, cuts)
	for index in range(cuts.size()):
		var piece: Dictionary = pieces[int(cuts[index][0])]
		var t := float(cuts[index][1])
		# Les deux morceaux de part et d'autre de cette coupe.
		var before := _part_of(pieces, cuts, sizes, int(cuts[index][0]), maxf(t - 0.002, 0.0))
		var after := _part_of(pieces, cuts, sizes, int(cuts[index][0]), minf(t + 0.002, piece.length))
		if part != before and part != after:
			continue
		var center: Vector3 = piece.start + piece.direction * t
		var radius := true_thickness(piece, t) * 0.5
		var axis: Vector3 = piece.direction
		var side: Vector3 = axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
		var other: Vector3 = axis.cross(side).normalized()
		var sides := 10
		for corner in range(sides):
			var a := TAU * corner / sides
			var b := TAU * (corner + 1) / sides
			points.append_array([center, center + (side * cos(a) + other * sin(a)) * radius, center + (side * cos(b) + other * sin(b)) * radius])
			for repeat in range(3):
				normals.append(piece.direction)
			uvs.append_array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 0.0)])
	var made := ArrayMesh.new()
	if not points.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		made.surface_set_material(0, Trees.cut_material())
	return made

static func _sizes_for(kind: int, size: int, form: int, cuts: Array) -> Array:
	var made := skeleton(kind, size, form)
	var sizes := []
	for cut in cuts:
		var count := 0
		for info in made.surfaces:
			for triangle in range(info.owner.size()):
				if detaches(made.pieces, cut, info.owner[triangle], info.param[triangle]):
					count += 1
		sizes.append(count)
	return sizes

# Part des feuilles de l'arbre portées par un morceau.
static func leaf_share(kind: int, size: int, form: int, cuts: Array, part: int) -> float:
	var total: int = skeleton(kind, size, form).leaves
	if total == 0:
		return 0.0
	return float(assignment(kind, size, form, cuts).leaves[part]) / total

# Pièce principale d'un morceau (la plus proche du pied) et son étendue [début, fin] (mètres le long de la pièce).
static func main_span(kind: int, size: int, form: int, cuts: Array, part: int) -> Array:
	var pieces: Array = skeleton(kind, size, form).pieces
	var spans: Dictionary = assignment(kind, size, form, cuts).ranges[part]
	# Moins profonde d'abord ; à égalité, la plus longue pièce (le tronc plutôt qu'une racine).
	var best := -1
	for number in spans:
		if best < 0 or pieces[number].depth < pieces[best].depth or (pieces[number].depth == pieces[best].depth and pieces[number].length > pieces[best].length):
			best = number
	if best < 0:
		return []
	# Bouts exacts : d'une coupe à l'autre (étendues calculées par assignment).
	var span: Vector2 = spans[best]
	return [best, span.x, span.y]

# Fruits d'un modèle cachés pour un morceau (ceux qui sont sur un autre morceau).
static func hidden_fruits(kind: int, size: int, form: int, cuts: Array, part: int) -> Array:
	var hidden := []
	var fruits: PackedInt32Array = assignment(kind, size, form, cuts).fruits
	for number in range(fruits.size()):
		if fruits[number] != part:
			hidden.append(number)
	return hidden

# --- Visée ---

# Rayon (repère du modèle) contre les pièces d'un morceau (cylindres le long de leur axe, un peu élargis pour viser
# facilement les brindilles) : la plus proche touchée {piece, t, distance, point} ou {}.
static func ray(kind: int, size: int, form: int, cuts: Array, part: int, origin: Vector3, direction: Vector3, reach: float) -> Dictionary:
	var pieces: Array = skeleton(kind, size, form).pieces
	var spans: Dictionary = assignment(kind, size, form, cuts).ranges[part]
	var best := {}
	for number in spans:
		var piece: Dictionary = pieces[number]
		var span: Vector2 = spans[number]
		var low := maxf(span.x - 0.06, 0.0)
		var high := minf(span.y + 0.06, piece.length)
		var a: Vector3 = piece.start + piece.direction * low
		var b: Vector3 = piece.start + piece.direction * high
		var found := _ray_segment(origin, direction, a, b)
		if found.is_empty():
			continue
		var t: float = low + found.s * (high - low)
		var radius := thickness(piece, t) * 0.5 + 0.03
		if found.gap > radius or found.distance < 0.0 or found.distance > reach:
			continue
		var distance: float = found.distance - sqrt(maxf(radius * radius - found.gap * found.gap, 0.0))
		if best.is_empty() or distance < best.distance:
			best = {"piece": number, "t": clampf(t, span.x, span.y), "distance": distance, "point": origin + direction * distance}
	return best

# Pièce d'un morceau la plus proche d'un point (repère du modèle), à moins de « within » : {piece, t, distance} ou {}.
static func nearest_in_part(kind: int, size: int, form: int, cuts: Array, part: int, point: Vector3, within: float) -> Dictionary:
	var pieces: Array = skeleton(kind, size, form).pieces
	var spans: Dictionary = assignment(kind, size, form, cuts).ranges[part]
	var best := {}
	for number in spans:
		var piece: Dictionary = pieces[number]
		var span: Vector2 = spans[number]
		var t := clampf(along(piece, point), span.x, span.y)
		var gap: float = point.distance_to(piece.start + piece.direction * t) - thickness(piece, t) * 0.5
		if gap < within and (best.is_empty() or gap < best.distance):
			best = {"piece": number, "t": t, "distance": gap}
	return best

# Points les plus proches entre le rayon et le segment [a, b] : s (0 à 1 sur le segment), distance le long du rayon, écart.
static func _ray_segment(origin: Vector3, direction: Vector3, a: Vector3, b: Vector3) -> Dictionary:
	var u := direction
	var v := b - a
	var w := origin - a
	var uu := u.dot(u)
	var uv := u.dot(v)
	var vv := v.dot(v)
	var uw := u.dot(w)
	var vw := v.dot(w)
	var denominator := uu * vv - uv * uv
	var s := 0.0
	if denominator > 0.000001 and vv > 0.000001:
		s = clampf((uu * vw - uv * uw) / denominator, 0.0, 1.0)
	var on_segment := a + v * s
	var distance := (on_segment - origin).dot(u) / uu
	var on_ray := origin + u * distance
	return {"s": s, "distance": distance, "gap": on_ray.distance_to(on_segment)}
