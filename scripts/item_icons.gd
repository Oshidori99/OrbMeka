extends RefCounted
# 0.0.7.4 : icônes des objets et des groupes de l'inventaire (demande de l'utilisateur : « des petits tas où l'on voit
# bien la texture », images plutôt que texte). Tout est fabriqué ici, dans le jeu, sans fichier ni téléchargement :
# - matières : un petit tas de la matière, éclairé en haut à gauche, avec sa texture (grains de sable, mottes de terre,
#   argile fendillée, boue luisante, graviers, morceaux de pierre) ;
# - caillou : galet ovale moucheté ; éclat : morceau anguleux à facettes ;
# - pioche, main, poche : petits dessins vectoriels (SVG écrits ici), style dessin de jeu vidéo.
# Performances (PC et Web) : chaque image est faite une seule fois, en SIZE pixels, puis gardée (_cache) ; rien par image.
const Inventory = preload("res://scripts/inventory.gd")
const SIZE := 48
static var _cache := {}

static func texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var spec: Dictionary = Inventory.ITEMS.get(id, {})
	if spec.is_empty():
		return null
	var image: Image
	if spec.has("outil"):
		image = _svg(PICKAXE_SVG, SIZE)
	else:
		match spec.get("forme", ""):
			"caillou":
				image = _pebble(spec.couleur, id.hash(), id == "caillou_silex")
			"eclat":
				image = _chip(spec.couleur, id.hash(), id == "eclat_silex" or id == "charbon")
			"fruit":
				image = _apple(Inventory.APPLE_COLORS[1], -1) if id == "pomme" else _hazelnut(spec.couleur)
			"orbe":
				image = _orb(spec.couleur)
			"bois":
				image = _stick(spec.couleur, id == "tronc", id.hash())
				if spec.get("feuilles", false):
					_leaves(image)
			_:
				image = _pile(id, spec.couleur)
	return _keep(id, image)

# 0.0.7.5 : icône d'un objet précis (une pomme a sa couleur).
static func for_value(value: Dictionary) -> Texture2D:
	var id: String = value.get("objet", "")
	if id == "pomme":
		var shown: Dictionary = value.pile[-1] if value.has("pile") and not value.pile.is_empty() else value
		var color := clampi(int(shown.get("couleur", 1)), 0, Inventory.APPLE_COLORS.size() - 1)
		var key := "pomme/%d" % color
		if _cache.has(key):
			return _cache[key]
		return _keep(key, _apple(Inventory.APPLE_COLORS[color], color))
	return texture(id)

# Onglets du Créatif (0.0.7.5) : un caillou, une pomme, un petit sac (Inventaire).
static func tab(id: String, height: int) -> Texture2D:
	match id:
		"natural":
			return natural_tab(height)
		"tools":
			return tools_tab(height)
		"inventory":
			var key := "#sac%d" % height
			return _cache[key] if _cache.has(key) else _keep(key, _svg(BAG_SVG, maxi(height, 12)))
	var source: Texture2D = texture("caillou" if id == "pebbles" else ("tronc" if id == "wood" else "pomme"))
	var image := source.get_image()
	image.resize(maxi(height, 12), maxi(height, 12), Image.INTERPOLATE_LANCZOS)
	var key := "#%s%d" % [id, height]
	return _cache[key] if _cache.has(key) else _keep(key, image)

static func hand() -> Texture2D:
	return _cache["#main"] if _cache.has("#main") else _keep("#main", _svg(HAND_SVG, SIZE))

static func pocket() -> Texture2D:
	return _cache["#poche"] if _cache.has("#poche") else _keep("#poche", _svg(POCKET_SVG, SIZE))

# Onglet Matériaux naturels : un tas de pierre, de terre et de sable.
static func natural_tab(height: int) -> Texture2D:
	var key := "#naturels%d" % height
	if _cache.has(key):
		return _cache[key]
	# 0.0.7.5 (demande de l'utilisateur) : une seule image carrée, un tas de pierre (derrière), de terre et de sable.
	var small := maxi(height, 12)
	var image := Image.create(small, small, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# [matière, taille, gauche, bas] en fractions de l'image.
	for placed in [["pierre", 0.72, 0.14, 0.76], ["terre", 0.62, 0.0, 1.0], ["sable", 0.62, 0.38, 1.0]]:
		var pile := _pile(placed[0], Inventory.ITEMS[placed[0]].couleur)
		var side := roundi(small * placed[1])
		pile.resize(side, side, Image.INTERPOLATE_LANCZOS)
		image.blend_rect(pile, Rect2i(0, 0, side, side), Vector2i(roundi(small * placed[2]), roundi(small * placed[3]) - side))
	return _keep(key, image)

static func tools_tab(height: int) -> Texture2D:
	var key := "#outils%d" % height
	return _cache[key] if _cache.has(key) else _keep(key, _svg(PICKAXE_SVG, maxi(height, 12)))

static func _keep(key: String, image: Image) -> Texture2D:
	var made := ImageTexture.create_from_image(image)
	_cache[key] = made
	return made

static func _svg(source: String, size: int) -> Image:
	var image := Image.new()
	if image.load_svg_from_string(source, size / 64.0) != OK or image.is_empty():
		image = Image.create(size, size, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
	return image

# --- Bruit (toujours le même pour un même objet) ---

static func _hash(x: int, y: int, salt: int) -> float:
	var h: int = (x * 374761393 + y * 668265263 + salt * 982451653) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0

static func _noise(x: float, y: float, cell: float, salt: int) -> float:
	var gx := x / cell
	var gy := y / cell
	var ix := floori(gx)
	var iy := floori(gy)
	var fx := smoothstep(0.0, 1.0, gx - ix)
	var fy := smoothstep(0.0, 1.0, gy - iy)
	var top := lerpf(_hash(ix, iy, salt), _hash(ix + 1, iy, salt), fx)
	var bottom := lerpf(_hash(ix, iy + 1, salt), _hash(ix + 1, iy + 1, salt), fx)
	return lerpf(top, bottom, fy)

static func _blank() -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image

# Ombre douce sous l'objet (seulement là où il n'y a rien).
static func _shadow(image: Image, center: Vector2, radius: Vector2) -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			var d := Vector2((x + 0.5 - center.x) / radius.x, (y + 0.5 - center.y) / radius.y).length()
			if d < 1.0 and image.get_pixel(x, y).a < 0.01:
				image.set_pixel(x, y, Color(0, 0, 0, 0.32 * (1.0 - d * d)))

# --- Tas de matière ---

const LUMPY := {"sable": 0.4, "terre": 1.2, "argile": 0.6, "boue": 0.5, "gravier": 1.6}

static func _pile(id: String, base: Color) -> Image:
	var image := _blank()
	var salt := id.hash() & 0xffff
	var stone := not LUMPY.has(id)
	var center_x := SIZE * 0.5
	var half := SIZE * 0.44
	var floor_y := SIZE * 0.84
	var height := SIZE * (0.5 if id != "sable" else 0.46)
	var lumps: float = LUMPY.get(id, 2.2)
	_shadow(image, Vector2(center_x + 1.5, floor_y + 1.0), Vector2(half * 1.06, SIZE * 0.09))
	var gravel := _gravel_stones(salt) if id == "gravier" else []
	var seeds := _chunk_seeds(salt) if stone else []
	for x in range(SIZE):
		var u := (x + 0.5 - center_x) / half
		if absf(u) >= 1.0:
			continue
		var top := floor_y - height * pow(1.0 - u * u, 0.7) + (_noise(x, 0.0, 4.0, salt) - 0.5) * 2.0 * lumps
		var bottom := floor_y + SIZE * 0.035 * sqrt(1.0 - u * u)
		for y in range(maxi(floori(top), 0), mini(ceili(bottom) + 1, SIZE)):
			var cover := clampf(minf(y + 0.5 - top, bottom - (y + 0.5)) + 0.5, 0.0, 1.0)
			if cover <= 0.0:
				continue
			var v := clampf((y + 0.5 - top) / maxf(bottom - top, 1.0), 0.0, 1.0)
			# Lumière en haut à gauche, plus sombre en bas (contre le sol).
			var light := 0.82 + 0.3 * (1.0 - v) - 0.2 * u
			light *= lerpf(1.0, 0.72, smoothstep(0.7, 1.0, v))
			var color := base * _grain(id, x, y, salt, u, v, gravel, seeds)
			color = Color(color.r * light, color.g * light, color.b * light)
			# Fin liseré clair sur le haut du tas : les matières sombres se voient sur le fond des cases.
			if y + 0.5 - top < 1.5 and u < 0.4:
				color = color.lerp(Color(1, 1, 1), 0.18)
			color.a = cover
			image.set_pixel(x, y, color.clamp())
	return image

static func _grain(id: String, x: int, y: int, salt: int, u: float, v: float, gravel: Array, seeds: Array) -> Color:
	var g := _hash(x, y, salt)
	match id:
		"sable":
			# Plein de tout petits grains clairs et sombres.
			var m := 1.0 + (g - 0.5) * 0.24 + (_noise(x, y, 3.0, salt + 1) - 0.5) * 0.1
			if g > 0.93:
				m += 0.24
			elif g < 0.06:
				m -= 0.28
			return Color(m, m, m * 0.97)
		"terre":
			# Mottes (taches plus claires) et miettes sombres.
			var clump := _noise(x, y, 4.0, salt + 2)
			var m := 0.82 + 0.34 * clump + (g - 0.5) * 0.12
			if clump > 0.72:
				m += 0.14
			if g < 0.08:
				m *= 0.62
			return Color(m, m, m)
		"argile":
			# Lisse et grise, fendillée, un peu luisante en haut à gauche.
			var m := 0.95 + 0.1 * _noise(x, y, 9.0, salt + 3) + (g - 0.5) * 0.04
			if absf(_noise(x, y, 6.0, salt + 4) - 0.5) < 0.035:
				m *= 0.7
			m += 0.16 * maxf(0.0, 1.0 - Vector2(u + 0.35, v - 0.2).length() * 2.2)
			return Color(m, m, m * 1.03)
		"boue":
			# Sombre et mouillée : reflets brillants.
			var m := 0.88 + 0.16 * _noise(x, y, 7.0, salt + 5) + (g - 0.5) * 0.06
			if g > 0.975 and v < 0.65:
				return Color(2.4, 2.3, 2.1)
			m += 0.35 * maxf(0.0, 1.0 - Vector2(u + 0.25, v - 0.15).length() * 3.0)
			return Color(m, m, m)
		"gravier":
			for stone in gravel:
				var d: Vector2 = (Vector2(x + 0.5, y + 0.5) - stone[0]) / stone[1]
				if d.length() <= 1.0:
					var lit := 1.05 - 0.3 * d.x - 0.32 * d.y - (0.3 if d.length() > 0.82 else 0.0)
					return Color(stone[2] * lit, stone[2] * lit * stone[3], stone[2] * lit * stone[3] * 0.98)
			return Color(0.42, 0.4, 0.38)
	return _chunks(id, x, y, salt, g, seeds)

# Graviers : petits cailloux de teintes voisines, les derniers devant.
static func _gravel_stones(salt: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var list := []
	for index in range(46):
		var at := Vector2(rng.randf_range(SIZE * 0.08, SIZE * 0.92), rng.randf_range(SIZE * 0.3, SIZE * 0.9))
		list.append([at, rng.randf_range(2.2, 4.2), rng.randf_range(0.78, 1.22), rng.randf_range(0.92, 1.05)])
	list.reverse()
	return list

# Morceaux de pierre : facettes (cellules autour de points) séparées par des fentes sombres.
static func _chunk_seeds(salt: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var list := []
	for index in range(10):
		list.append([Vector2(rng.randf_range(0.0, SIZE), rng.randf_range(SIZE * 0.25, SIZE)), rng.randf_range(0.8, 1.2), Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()])
	return list

static func _chunks(id: String, x: int, y: int, salt: int, g: float, seeds: Array) -> Color:
	var at := Vector2(x + 0.5, y + 0.5)
	var first := INF
	var second := INF
	var cell: Array = seeds[0]
	for seed: Array in seeds:
		var d := at.distance_to(seed[0])
		if d < first:
			second = first
			first = d
			cell = seed
		elif d < second:
			second = d
	var facet: float = cell[1] + 0.12 * (at - cell[0]).normalized().dot(cell[2])
	if id == "silex":
		facet = 0.65 + (facet - 0.8) * 1.8
	var m := facet + (g - 0.5) * 0.1
	if id == "calcaire" and g > 0.95:
		m *= 0.78
	if second - first < 1.1:
		m *= 0.58
	if id == "silex" and _hash(x, y, salt + 9) > 0.985:
		return Color(2.2, 2.2, 2.4)
	return Color(m, m, m * (1.06 if id == "silex" else 1.0))

# --- Caillou et éclat ---

# 0.0.7.6 : rognon de silex comme dans le monde (demande de l'utilisateur) : croûte blanchâtre et taches sombres,
# toujours le même.
static func _pebble(base: Color, salt: int, flint: bool = false) -> Image:
	var image := _blank()
	var center := Vector2(SIZE * 0.5, SIZE * 0.56)
	var radius := Vector2(SIZE * 0.4, SIZE * 0.29)
	_shadow(image, center + Vector2(2.0, radius.y * 0.75), Vector2(radius.x * 1.02, SIZE * 0.08))
	var light := Vector3(-0.5, -0.6, 0.62).normalized()
	for y in range(SIZE):
		for x in range(SIZE):
			var d := Vector2((x + 0.5 - center.x) / radius.x, (y + 0.5 - center.y) / radius.y)
			var r := d.length()
			if r >= 1.0:
				continue
			var normal := Vector3(d.x, d.y, sqrt(1.0 - r * r)).normalized()
			var g := _hash(x, y, salt)
			var m := 0.55 + 0.6 * maxf(normal.dot(light), 0.0) + (g - 0.5) * 0.14 + (_noise(x, y, 5.0, salt) - 0.5) * 0.16
			if g < 0.05:
				m *= 0.7
			var tone := base
			if flint:
				tone = Color("#3b3b42") if _noise(x, y, 7.0, salt + 3) > 0.6 else Color("#d6d1c4")
			var color := Color(tone.r * m, tone.g * m, tone.b * m)
			color.a = clampf((1.0 - r) * radius.y, 0.0, 1.0)
			image.set_pixel(x, y, color.clamp())
	return image

static func _chip(base: Color, salt: int, glassy: bool) -> Image:
	var image := _blank()
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var center := Vector2(SIZE * 0.5, SIZE * 0.55)
	var corners := PackedVector2Array()
	for index in range(6):
		var angle := TAU * index / 6.0 + rng.randf_range(-0.3, 0.3)
		corners.append(center + Vector2(cos(angle) * SIZE * rng.randf_range(0.3, 0.42), sin(angle) * SIZE * rng.randf_range(0.22, 0.32)))
	_shadow(image, center + Vector2(2.0, SIZE * 0.24), Vector2(SIZE * 0.38, SIZE * 0.08))
	var shades := []
	for index in range(corners.size()):
		shades.append(rng.randf_range(0.65, 1.25) if glassy else rng.randf_range(0.78, 1.15))
	for y in range(SIZE):
		for x in range(SIZE):
			# Couverture sur 2 × 2 points : bords nets mais lisses.
			var inside := 0
			for sub in [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.25, 0.75), Vector2(0.75, 0.75)]:
				if Geometry2D.is_point_in_polygon(Vector2(x, y) + sub, corners):
					inside += 1
			if inside == 0:
				continue
			var at := Vector2(x + 0.5, y + 0.5) - center
			var facet := wrapi(floori((at.angle() + PI) / TAU * corners.size()), 0, corners.size())
			var g := _hash(x, y, salt)
			var m: float = shades[facet] + (g - 0.5) * 0.12 - 0.15 * at.y / SIZE
			if glassy and g > 0.97:
				m += 0.8
			var color := Color(base.r * m, base.g * m, base.b * m)
			color = color.lerp(Color(1, 1, 1), 0.12) if at.y < -SIZE * 0.12 else color
			# Bord un peu plus clair : les éclats sombres (silex, charbon) se voient sur le fond des cases.
			if inside < 4:
				color = color.lerp(Color(1, 1, 1), 0.3)
			color.a = inside / 4.0
			image.set_pixel(x, y, color.clamp())
	return image

# --- Bois (0.0.7.8) : bâton en diagonale, écorce rayée, bout coupé clair ; tronc plus épais. ---

static func _stick(base: Color, trunk: bool, salt: int) -> Image:
	var image := _blank()
	var start := Vector2(SIZE * 0.14, SIZE * 0.82)
	var end := Vector2(SIZE * 0.86, SIZE * 0.2)
	var radius := SIZE * (0.15 if trunk else 0.075)
	var along := (end - start).normalized()
	var across := Vector2(-along.y, along.x)
	_shadow(image, (start + end) * 0.5 + Vector2(2.0, radius + 3.0), Vector2((end - start).length() * 0.45, SIZE * 0.06))
	for y in range(SIZE):
		for x in range(SIZE):
			var at := Vector2(x + 0.5, y + 0.5)
			var distance := _segment_distance(at, start, end)
			if distance >= radius:
				continue
			var t := (at - start).dot(along)
			var side := (at - start).dot(across) / radius
			var m := 0.62 + 0.4 * (1.0 - absf(side + 0.35)) + (_noise(t * 0.25, side * 6.0, 1.0, salt) - 0.5) * 0.35
			var color := Color(base.r * m, base.g * m, base.b * m)
			# Bout coupé : bois clair et cernes.
			if (end - at).dot(along) < radius * 0.5:
				var ring := (at - end).length() / radius
				color = Color("#d9b47c").darkened(0.18 * (1.0 if fmod(ring * 4.0, 1.0) < 0.25 else 0.0))
			color.a = clampf(radius - distance, 0.0, 1.0)
			image.set_pixel(x, y, color.clamp())
	return image

# 0.0.7.12 : rameau : quelques feuilles vertes le long du bout fin du bâton (une seule icône pour tous).
static func _leaves(image: Image) -> void:
	var spots := [[0.55, 0.42, 0.9], [0.66, 0.3, -0.6], [0.74, 0.36, 0.4], [0.62, 0.52, -1.2], [0.8, 0.22, 0.2], [0.47, 0.5, 0.7]]
	for spot in spots:
		var center := Vector2(SIZE * spot[0], SIZE * spot[1])
		var along := Vector2.from_angle(spot[2])
		var across := Vector2(-along.y, along.x)
		for y in range(SIZE):
			for x in range(SIZE):
				var offset := Vector2(x + 0.5, y + 0.5) - center
				var u := offset.dot(along) / (SIZE * 0.11)
				var v := offset.dot(across) / (SIZE * 0.05)
				var inside := 1.0 - (u * u + v * v)
				if inside <= 0.0:
					continue
				var shade := 0.75 + 0.25 * (1.0 - absf(v)) - (0.12 if absf(v) < 0.12 else 0.0)
				var leaf := Color(0.33 * shade, 0.58 * shade, 0.22 * shade, clampf(inside * 6.0, 0.0, 1.0))
				image.set_pixel(x, y, image.get_pixel(x, y).blend(leaf))

# --- Fruits (0.0.7.5) ---

static func _segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var along := clampf((point - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return point.distance_to(a + (b - a) * along)

# Pomme ronde, creusée en haut, avec reflet, petits points clairs, queue et feuille. color_index 4 : moitié rouge,
# moitié jaune (rouge du côté du soleil, en haut à gauche).
static func _apple(base: Color, color_index: int) -> Image:
	var image := _blank()
	# 0.0.8 (demande de l'utilisateur) : la pomme brune est vieille : pas de feuille (une feuille la faisait jeune).
	var old := color_index == 3
	var center := Vector2(SIZE * 0.5, SIZE * 0.57)
	var radius := Vector2(SIZE * 0.36, SIZE * 0.34)
	_shadow(image, center + Vector2(2.0, radius.y * 0.85), Vector2(radius.x * 0.95, SIZE * 0.07))
	var light := Vector3(-0.45, -0.6, 0.66).normalized()
	for y in range(SIZE):
		for x in range(SIZE):
			var d := Vector2((x + 0.5 - center.x) / radius.x, (y + 0.5 - center.y) / radius.y)
			# Un peu plus large en haut qu'en bas.
			d.x *= 1.0 + 0.08 * d.y
			var r := d.length()
			if r >= 1.0:
				continue
			var normal := Vector3(d.x, d.y, sqrt(1.0 - r * r)).normalized()
			var color := base
			if color_index == 4:
				color = Inventory.APPLE_COLORS[1].lerp(Inventory.APPLE_COLORS[2], smoothstep(-0.5, 0.7, d.x * 0.8 + d.y * 0.6))
			var m := 0.5 + 0.62 * maxf(normal.dot(light), 0.0)
			# Creux de la queue, en haut au milieu.
			m *= 1.0 - 0.35 * maxf(0.0, 1.0 - Vector2(d.x * 2.6, (d.y + 0.82) * 3.2).length())
			var g := _hash(x, y, 77)
			if g > 0.965:
				m += 0.28 if not old else -0.2
			# 0.0.8 : pomme brune (vieille) : quelques taches plus sombres, peau ridée.
			if old:
				m *= 1.0 - 0.3 * smoothstep(0.55, 0.75, _hash(floori(x / 3.0), floori(y / 3.0), 31)) - 0.06 * sin(d.x * 14.0 + d.y * 5.0)
			var shade := Color(color.r * m, color.g * m, color.b * m)
			# Reflet brillant (presque mat sur une vieille pomme).
			var spot := maxf(0.0, 1.0 - Vector2(d.x + 0.38, d.y + 0.38).length() * 4.0)
			shade = shade.lerp(Color(1, 1, 1), spot * (0.15 if old else 0.7))
			shade.a = clampf((1.0 - r) * radius.y, 0.0, 1.0)
			image.set_pixel(x, y, shade.clamp())
	# Queue brune et feuille verte.
	var stem_a := Vector2(SIZE * 0.5, SIZE * 0.3)
	var stem_b := Vector2(SIZE * 0.56, SIZE * 0.12)
	var leaf := Vector2(SIZE * 0.66, SIZE * 0.17)
	for y in range(SIZE):
		for x in range(SIZE):
			var at := Vector2(x + 0.5, y + 0.5)
			var stem := _segment_distance(at, stem_a, stem_b)
			if stem < 1.6:
				image.set_pixel(x, y, Color("#2e1c0e" if old else "#4a2e17").lerp(image.get_pixel(x, y), clampf(stem - 0.6, 0.0, 1.0)))
				continue
			if old:
				continue
			var local := (at - leaf).rotated(0.5)
			var e := Vector2(local.x / (SIZE * 0.13), local.y / (SIZE * 0.06)).length()
			if e < 1.0:
				var green := Color("#4f8f2a") * (1.05 - 0.25 * (local.y / (SIZE * 0.06)))
				green.a = clampf((1.0 - e) * SIZE * 0.06, 0.0, 1.0)
				image.set_pixel(x, y, image.get_pixel(x, y).blend(green.clamp()))
	return image

# 0.0.8.2 (#231) : orbe de retour : boule turquoise lumineuse (cœur clair, halo doux) cerclée d'un anneau doré incliné.
static func _orb(base: Color) -> Image:
	var image := _blank()
	var center := Vector2(SIZE * 0.5, SIZE * 0.52)
	var radius := SIZE * 0.32
	_shadow(image, center + Vector2(1.0, radius * 0.95), Vector2(radius * 0.85, SIZE * 0.06))
	var light := Vector3(-0.45, -0.6, 0.66).normalized()
	var ring_color := Color("#e2b85a")
	for y in range(SIZE):
		for x in range(SIZE):
			var at := Vector2(x + 0.5, y + 0.5)
			var d := (at - center) / radius
			var r := d.length()
			var pixel := Color(0, 0, 0, 0)
			# Halo autour de la boule.
			if r >= 1.0 and r < 1.35:
				pixel = Color(base.r, base.g, base.b, 0.35 * (1.35 - r) / 0.35)
			elif r < 1.0:
				var normal := Vector3(d.x, d.y, sqrt(1.0 - r * r))
				var m := 0.55 + 0.55 * maxf(normal.dot(light), 0.0)
				var color := base.lerp(Color(0.85, 1.0, 0.98), 0.55 * (1.0 - r) * (1.0 - r))
				pixel = Color(color.r * m, color.g * m, color.b * m)
				var spot := maxf(0.0, 1.0 - Vector2(d.x + 0.35, d.y + 0.38).length() * 4.0)
				pixel = pixel.lerp(Color.WHITE, spot * 0.8)
				pixel.a = clampf((1.0 - r) * radius, 0.0, 1.0)
			# Anneau doré (ellipse inclinée) : devant la boule en bas, caché derrière en haut.
			var ring := (at - center).rotated(-0.35)
			var e := Vector2(ring.x / (radius * 1.25), ring.y / (radius * 0.38)).length()
			if absf(e - 1.0) < 0.09 and (ring.y > 0.0 or r >= 1.0):
				var gold := ring_color * (1.1 - 0.3 * (ring.y / (radius * 0.38)))
				gold.a = 1.0
				pixel = pixel.blend(gold.clamp()) if pixel.a > 0.0 else gold.clamp()
			if pixel.a > 0.0:
				image.set_pixel(x, y, pixel.clamp())
	return image

# Noisette : coque brune luisante, base plus claire et rugueuse, petite pointe.
static func _hazelnut(base: Color) -> Image:
	var image := _blank()
	var center := Vector2(SIZE * 0.5, SIZE * 0.55)
	var radius := Vector2(SIZE * 0.3, SIZE * 0.33)
	_shadow(image, center + Vector2(2.0, radius.y * 0.85), Vector2(radius.x * 0.95, SIZE * 0.06))
	var light := Vector3(-0.45, -0.6, 0.66).normalized()
	for y in range(SIZE):
		for x in range(SIZE):
			var d := Vector2((x + 0.5 - center.x) / radius.x, (y + 0.5 - center.y) / radius.y)
			# Plus pointue en haut.
			d.x *= 1.0 + 0.35 * maxf(0.0, -d.y)
			var r := d.length()
			if r >= 1.0:
				continue
			var normal := Vector3(d.x, d.y, sqrt(1.0 - r * r)).normalized()
			var m := 0.5 + 0.62 * maxf(normal.dot(light), 0.0)
			var color := base
			# Base claire et rugueuse (là où la noisette tenait à sa collerette).
			if d.y > 0.45:
				color = Color("#c9a675")
				m *= 0.85 + 0.3 * _hash(x, y, 13)
			else:
				m += (_noise(x * 0.6, y * 3.0, 3.0, 21) - 0.5) * 0.25
			var shade := Color(color.r * m, color.g * m, color.b * m)
			shade = shade.lerp(Color(1, 1, 1), maxf(0.0, 1.0 - Vector2(d.x + 0.35, d.y + 0.3).length() * 4.0) * 0.55)
			shade.a = clampf((1.0 - r) * radius.y, 0.0, 1.0)
			image.set_pixel(x, y, shade.clamp())
	return image

# --- Dessins vectoriels (originaux, faits pour OrbMeka) ---

# 0.0.7.7 : silhouettes de l'équipement à venir (cases grisées de l'écran de Survie) : sac, panier, travois, chariot.
static func equipment(kind: String) -> Texture2D:
	var key := "#equipement_" + kind
	if _cache.has(key):
		return _cache[key]
	var source: String = {"sac": BAG_SVG, "panier": BASKET_SVG, "travois": TRAVOIS_SVG, "chariot": CART_SVG}.get(kind, BAG_SVG)
	return _keep(key, _svg(source, SIZE))

const BASKET_SVG := "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
<path d='M16 28 Q16 8 32 8 Q48 8 48 28' fill='none' stroke='#3a2414' stroke-width='5' stroke-linecap='round'/>
<path d='M16 28 Q16 8 32 8 Q48 8 48 28' fill='none' stroke='#c99a5b' stroke-width='2.4' stroke-linecap='round'/>
<path d='M8 28 H56 L50 56 H14 Z' fill='#c99a5b' stroke='#3a2414' stroke-width='3' stroke-linejoin='round'/>
<path d='M11 36 H53 M12 44 H52 M13 51 H51' stroke='#8a6233' stroke-width='2'/>
<path d='M20 28 L21 56 M32 28 V56 M44 28 L43 56' stroke='#8a6233' stroke-width='2'/>
</svg>"

# 0.0.7.9 (demande de l'utilisateur) : travois traîné, vu de côté : une bande de sol en bas, les deux bâtons qui montent
# doucement vers la droite (le bout tenu), le bout arrière couché sur le sol avec des traces derrière, la charge ficelée
# dessus (avant : il avait l'air de flotter).
const TRAVOIS_SVG := "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
<path d='M1 55 H63 V62 H1 Z' fill='#7a5a34' stroke='#3a2414' stroke-width='2'/>
<path d='M1 55 H63' stroke='#6f9a3c' stroke-width='3'/>
<path d='M2 58.5 H11 M4 60.5 H9' stroke='#4a341c' stroke-width='1.6' stroke-linecap='round'/>
<path d='M10 53 L60 25 M16 54 L62 31' stroke='#3a2414' stroke-width='6' stroke-linecap='round'/>
<path d='M10 53 L60 25 M16 54 L62 31' stroke='#b07a42' stroke-width='3' stroke-linecap='round'/>
<path d='M22 46 L26 50 M34 39 L38 44 M46 32 L50 37' stroke='#3a2414' stroke-width='4' stroke-linecap='round'/>
<path d='M22 46 L26 50 M34 39 L38 44 M46 32 L50 37' stroke='#d9a46a' stroke-width='2' stroke-linecap='round'/>
<path d='M19 47 Q19 31 31 29 Q41 27 44 34 Z' fill='#8c5b2c' stroke='#3a2414' stroke-width='2.4' stroke-linejoin='round'/>
<path d='M25 43 L29 30 M35 37 L37 28' stroke='#e1b54c' stroke-width='1.6'/>
</svg>"

const CART_SVG := "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
<path d='M8 20 H48 L44 40 H12 Z' fill='#b07a42' stroke='#3a2414' stroke-width='3' stroke-linejoin='round'/>
<path d='M48 22 L58 14' stroke='#3a2414' stroke-width='4' stroke-linecap='round'/>
<path d='M18 26 V36 M28 26 V36 M38 26 V36' stroke='#8a6233' stroke-width='2'/>
<ellipse cx='30' cy='56' rx='24' ry='3' fill='#000000' opacity='0.28'/>
<circle cx='19' cy='46' r='8' fill='#6d747b' stroke='#22272c' stroke-width='3'/>
<circle cx='39' cy='46' r='8' fill='#6d747b' stroke='#22272c' stroke-width='3'/>
<circle cx='19' cy='46' r='2.2' fill='#22272c'/>
<circle cx='39' cy='46' r='2.2' fill='#22272c'/>
</svg>"

const BAG_SVG := "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
<path d='M22 20 Q22 8 32 8 Q42 8 42 20' fill='none' stroke='#3a2414' stroke-width='5' stroke-linecap='round'/>
<path d='M22 20 Q22 8 32 8 Q42 8 42 20' fill='none' stroke='#a7743f' stroke-width='2.4' stroke-linecap='round'/>
<path d='M14 24 Q12 56 20 58 H44 Q52 56 50 24 Z' fill='#b07a42' stroke='#3a2414' stroke-width='3' stroke-linejoin='round'/>
<path d='M14 24 H50 V31 H14 Z' fill='#8c5b2c' stroke='#3a2414' stroke-width='2.4' stroke-linejoin='round'/>
<rect x='28' y='27' width='8' height='9' rx='2' fill='#e1b54c' stroke='#5a3d10' stroke-width='1.6'/>
<path d='M20 38 Q19 50 23 54' fill='none' stroke='#d9a46a' stroke-width='2' stroke-linecap='round'/>
</svg>"

const PICKAXE_SVG := "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
<path d='M15 57 L40 17' stroke='#2b1c12' stroke-width='9' stroke-linecap='round'/>
<path d='M15 57 L40 17' stroke='#a8743f' stroke-width='5' stroke-linecap='round'/>
<path d='M17 52 L37 20' stroke='#d39a5e' stroke-width='1.6' stroke-linecap='round'/>
<path d='M8 27 Q30 0 58 21 L56 26 Q34 13 12 31 Z' fill='#9aa1a8' stroke='#22272c' stroke-width='2.6' stroke-linejoin='round'/>
<path d='M14 25 Q31 7 52 19' fill='none' stroke='#e9eef2' stroke-width='2' stroke-linecap='round'/>
<rect x='33' y='12' width='11' height='10' rx='2' transform='rotate(32 38.5 17)' fill='#6d747b' stroke='#22272c' stroke-width='2.4'/>
</svg>"

const HAND_SVG := "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
<g fill='#3b2618' stroke='#3b2618' stroke-width='5' stroke-linejoin='round'>
<rect x='17' y='29' width='31' height='27' rx='11'/>
<rect x='17' y='12' width='7.5' height='26' rx='3.75'/>
<rect x='25.5' y='7' width='7.5' height='30' rx='3.75'/>
<rect x='34' y='8' width='7.5' height='29' rx='3.75'/>
<rect x='42.5' y='14' width='7' height='24' rx='3.5'/>
<rect x='4' y='31' width='20' height='8' rx='4' transform='rotate(-38 16 35)'/>
</g>
<g fill='#f3c79b'>
<rect x='17' y='29' width='31' height='27' rx='11'/>
<rect x='17' y='12' width='7.5' height='26' rx='3.75'/>
<rect x='25.5' y='7' width='7.5' height='30' rx='3.75'/>
<rect x='34' y='8' width='7.5' height='29' rx='3.75'/>
<rect x='42.5' y='14' width='7' height='24' rx='3.5'/>
<rect x='4' y='31' width='20' height='8' rx='4' transform='rotate(-38 16 35)'/>
</g>
<path d='M20 16 L20 22 M29 11 L29 17 M38 12 L38 18 M46 18 L46 23' stroke='#fbe3c8' stroke-width='2' stroke-linecap='round'/>
</svg>"

const POCKET_SVG := "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>
<path d='M11 9 H53 V42 L32 58 L11 42 Z' fill='#3f6aa3' stroke='#18263b' stroke-width='3' stroke-linejoin='round'/>
<path d='M11 9 H53 V20 H11 Z' fill='#4c7bb8' stroke='#18263b' stroke-width='2.4' stroke-linejoin='round'/>
<path d='M15 24 H49 V40 L32 53 L15 40 Z' fill='none' stroke='#f0b860' stroke-width='1.8' stroke-dasharray='3 2.4'/>
<path d='M14 15 H50' fill='none' stroke='#f0b860' stroke-width='1.6' stroke-dasharray='3 2.4'/>
<circle cx='16' cy='24' r='2.6' fill='#e1b54c' stroke='#6b4d14' stroke-width='1'/>
<circle cx='48' cy='24' r='2.6' fill='#e1b54c' stroke='#6b4d14' stroke-width='1'/>
<path d='M22 30 Q26 28 30 31' fill='none' stroke='#86a8d6' stroke-width='1.6' stroke-linecap='round'/>
</svg>"
