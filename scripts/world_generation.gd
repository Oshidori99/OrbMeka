extends RefCounted
# Paramètres propres au monde : une chance sur N par zone de 8 m (0 : jamais).
# Version 1 (0.0.5.16) : conservée telle quelle pour les mondes déjà créés avec elle.
# Version 2 (0.0.5.17) : génération standard des nouveaux mondes (relief moins plat, collines douces
# partout, déserts aux bords irréguliers) ; déserts moyens de 2 à 4 zones, grands de 4 à 6 (demande de
# l'utilisateur), plus rares par défaut (environ 1/6 du sol en désert, contre 1/3 avant). Les mondes sans
# paramètres (avant 0.0.5.16) gardent la génération de 0.0.5.15.
# Version 3 (0.0.5.18) : monde de 20 × 20 zones ; déserts moyens de 3 à 4 zones, grands de 6 à 7, environ 12 %
# du sol, plus de grands que de petits ; 3 ou 4 trous énormes jusque dans la pierre pour 256 zones.
# Version 4 (0.0.5.19) : rochers au hasard (7 tailles, plus de petits que de gros) et petits lacs.
# Version 5 (0.0.5.20) : lacs allongés (1 × 2 zones), boue au bord et au fond des lacs, argile dessous et en poches.
# Version 6 (0.0.5.21) : plus de petits ni de moyens déserts, grands de 7 à 9 zones (environ 8 % du sol) ;
# plus de lacs d'une zone : lacs de 2 zones et grands lacs d'environ 4 zones, bords irréguliers, entourés
# de boue et d'argile variées ; régions de boue d'environ 2 zones. Formes irrégulières, jamais de carrés.
# Version 7 (0.0.5.23) : moins de lacs et de déserts, mais plus grands : petits lacs de 2 à 3 zones (rares), moyens
# d'environ 10 zones (les plus courants), grands d'environ 16 zones (rares) ; grands déserts de 14 à 20 zones
# (environ 9 à 10 % du sol). Formes irrégulières. Montagnes (environ 7 % du sol), cœur de pierre et sommets rocheux.
const VERSION := 7
const VERSIONS := [1, 2, 3, 4, 5, 6, 7]
# Chance la plus rare qu'on peut régler : 1 sur MAX_CHANCE par zone (64 avant 0.0.5.18, 400 avant 0.0.5.23).
const MAX_CHANCE := 2000
const STANDARD_SMALL_DENOMINATOR := 8
const STANDARD_GROUP_DENOMINATOR := 12
const STANDARD_FEATURE_DENOMINATOR := 9
const STANDARD_HILL_HEIGHT := 3.0
const SPECS := [
	{"key":"small_deserts", "label":"Petits déserts (1 zone)", "default":133, "until":5},
	{"key":"medium_deserts", "label":"Déserts moyens (3 à 4 zones)", "default":100, "until":5},
	{"key":"large_deserts", "label":"Grands déserts (14 à 20 zones)", "default":200},
	{"key":"low_hills", "label":"Collines douces de 1 bloc", "default":6},
	{"key":"high_hills", "label":"Collines douces de 2 à 3 blocs", "default":12},
	{"key":"steep_hills", "label":"Crêtes abruptes", "default":9},
	{"key":"smooth_holes", "label":"Trous aux bords doux", "default":12},
	{"key":"steep_holes", "label":"Trous aux bords abrupts", "default":18},
	{"key":"deep_holes", "label":"Trous bien profonds", "default":0},
	{"key":"stone_holes", "label":"Trous énormes : 2 à 3 blocs dans la pierre", "default":72},
	{"key":"rocks", "label":"Rochers (tailles 1 à 7)", "default":2, "since":4},
	{"key":"lakes", "label":"Petits lacs (1 zone)", "default":24, "since":4, "until":5},
	{"key":"long_lakes", "label":"Lacs allongés (1 × 2 zones)", "default":48, "since":5, "until":5},
	{"key":"lakes_2", "label":"Lacs (environ 2 zones)", "default":26, "since":6, "until":6},
	{"key":"lakes_4", "label":"Grands lacs (environ 4 zones)", "default":55, "since":6, "until":6},
	{"key":"lakes_small", "label":"Petits lacs (2 à 3 zones)", "default":500, "since":7},
	{"key":"lakes_medium", "label":"Lacs moyens (environ 10 zones)", "default":180, "since":7},
	{"key":"lakes_large", "label":"Grands lacs (environ 16 zones)", "default":450, "since":7},
	{"key":"mountains", "label":"Montagnes (20 à 32 blocs de haut, environ 50 zones)", "default":700, "since":7},
	{"key":"mud_regions", "label":"Régions de boue (environ 2 zones)", "default":70, "since":6},
	{"key":"clay", "label":"Poches d'argile dans la terre", "default":10, "since":5},
]
# Taille des déserts (nombre de zones, et case où ils tiennent) selon la version.
const DESERT_SIZES := {
	1: {"medium_desert": [4, 6, 3, 2], "big_desert": [8, 11, 4, 3]},
	2: {"medium_desert": [2, 4, 2, 2], "big_desert": [4, 6, 3, 2]},
	3: {"medium_desert": [3, 4, 2, 2], "big_desert": [6, 7, 3, 3]},
	4: {"medium_desert": [3, 4, 2, 2], "big_desert": [6, 7, 3, 3]},
	5: {"medium_desert": [3, 4, 2, 2], "big_desert": [6, 7, 3, 3]},
	6: {"medium_desert": [3, 4, 2, 2], "big_desert": [7, 9, 3, 3]},
	7: {"medium_desert": [3, 4, 2, 2], "big_desert": [14, 20, 5, 5]},
}
# 0.0.5.20 : monde de 48 × 48 zones (20 × 20 en 0.0.5.18, 16 × 16 avant).
const WORLD_ZONES := 2304

# Réglages d'une version (0.0.5.19 : rochers et lacs seulement dès la version 4).
static func specs_for(version: int) -> Array:
	return SPECS.filter(func(spec): return spec.get("since", 1) <= version and version <= spec.get("until", 99))

static func defaults() -> Dictionary:
	var result := {"version": VERSION}
	for spec in specs_for(VERSION):
		result[spec.key] = spec.default
	return result

static func valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	var version: Variant = value.get("version")
	# JSON relit les nombres en décimaux (2.0) : comparer en entier.
	if not (version is int or version is float) or float(version) != int(version) or not int(version) in VERSIONS or value.size() != specs_for(int(version)).size() + 1:
		return false
	for spec in specs_for(int(value.version)):
		var n: Variant = value.get(spec.key)
		if not (n is int or n is float) or not is_finite(float(n)) or n != int(n) or n < 0 or n > MAX_CHANCE:
			return false
	return true

# JSON relit les nombres en flottants : stabiliser les options en entiers après validation.
static func normalized(value: Dictionary) -> Dictionary:
	if value.is_empty():
		return {}
	var result := {"version": int(value.version)}
	for spec in specs_for(int(value.version)):
		result[spec.key] = int(value[spec.key])
	return result

# 0.0.5.17 : estimations affichées dans l'écran Monde personnalisé (moyennes, pour le monde de WORLD_ZONES zones).
static func average_size(key: String, version: int = VERSION) -> float:
	if key == "small_deserts":
		return 1.0
	var size: Array = DESERT_SIZES[version]["medium_desert" if key == "medium_deserts" else "big_desert"]
	return (size[0] + size[1]) / 2.0

# Part du sol en désert (0 à 1), en comptant les recouvrements.
static func desert_share(options: Dictionary) -> float:
	var stays := 1.0
	for key in ["small_deserts", "medium_deserts", "large_deserts"]:
		var n: int = options.get(key, 0)
		if n > 0:
			stays *= pow(1.0 - 1.0 / n, average_size(key, options.get("version", VERSION)))
	return 1.0 - stays

# Groupes connexes, sans doublon ; chaque désert occupe exactement le nombre de zones choisi
# avant les éventuels recouvrements avec un autre désert.
static func cluster(rng: RandomNumberGenerator, count: int, width: int, height: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = [Vector2i.ZERO]
	var frontier: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN]
	while result.size() < count:
		var at: Vector2i = frontier.pop_at(rng.randi_range(0, frontier.size()-1))
		result.append(at)
		for side in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = at + side
			if next.x >= 0 and next.x < width and next.y >= 0 and next.y < height and not result.has(next) and not frontier.has(next):
				frontier.append(next)
	return result

# 0.0.5.23 : montagne (version 7), environ 8 à 10 fois une colline : 20 à 32 m de haut, 32 à 46 m de rayon,
# un peu allongée. Tirée seule (sans le reste de la zone) pour trouver vite les montagnes voisines.
static func mountain(rng: RandomNumberGenerator, zone: Vector2i) -> Dictionary:
	return {"center": Vector2(zone) * 8.0 + Vector2(rng.randf_range(0.0, 8.0), rng.randf_range(0.0, 8.0)), "height": rng.randf_range(20.0, 32.0), "radius": rng.randf_range(32.0, 46.0), "stretch": rng.randf_range(1.0, 1.35), "turn": rng.randf() * TAU}

static func zone_mountain(terrain_seed: int, zone: Vector2i, options: Dictionary) -> Dictionary:
	var denominator: int = options.get("mountains", 0)
	if denominator == 0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(options.version), terrain_seed, zone.x, zone.y, "mountains"])
	if rng.randf() >= 1.0 / denominator:
		return {}
	return mountain(rng, zone)

static func zone_info(terrain_seed: int, zone: Vector2i, options: Dictionary) -> Dictionary:
	var info := {"small_desert":false, "landforms":[]}
	for spec in specs_for(int(options.version)):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(options.version), terrain_seed, zone.x, zone.y, spec.key])
		var denominator: int = options[spec.key]
		if denominator == 0 or rng.randf() >= 1.0 / denominator:
			continue
		match spec.key:
			"small_deserts":
				info.small_desert = true
			"medium_deserts":
				var size: Array = DESERT_SIZES[int(options.version)].medium_desert
				info.medium_desert = cluster(rng, rng.randi_range(size[0], size[1]), size[2], size[3])
			"large_deserts":
				var size: Array = DESERT_SIZES[int(options.version)].big_desert
				info.big_desert = cluster(rng, rng.randi_range(size[0], size[1]), size[2], size[3])
			"rocks":
				# Un rocher (parfois deux), plutôt petit : tailles tirées avec plus de chances pour les petites.
				info.rocks = []
				for index in range(2 if rng.randf() < 0.25 else 1):
					info.rocks.append({"taille": _rock_size(rng), "forme": rng.randi_range(1, 7), "x": zone.x * 8.0 + rng.randf_range(0.5, 7.5), "z": zone.y * 8.0 + rng.randf_range(0.5, 7.5), "rotation": rng.randf_range(0.0, 360.0)})
			"lakes":
				# Petit lac : cuvette de 3,5 à 6 m de rayon, 0,8 à 1,8 m de fond, au milieu de la zone.
				info.lake = {"center": Vector2(zone) * 8.0 + Vector2(rng.randf_range(3, 5), rng.randf_range(3, 5)), "radius": rng.randf_range(3.5, 6.0), "depth": rng.randf_range(0.8, 1.8)}
			"long_lakes":
				# 0.0.5.20 : lac allongé sur deux zones (vers +X ou +Z) : bande arrondie de 2,5 à 3,5 m de demi-largeur.
				var start := Vector2(zone) * 8.0 + Vector2(rng.randf_range(3.5, 4.5), rng.randf_range(3.5, 4.5))
				var along := Vector2(1, 0) if rng.randf() < 0.5 else Vector2(0, 1)
				info.long_lake = {"start": start, "end": start + along * rng.randf_range(7.0, 9.0), "radius": rng.randf_range(2.5, 3.5), "depth": rng.randf_range(1.0, 2.0)}
			"clay":
				# 0.0.5.20 : poche d'argile dans la terre, de 0,5 à 1 m sous l'herbe, 1 à 2 m d'épaisseur.
				info.clay = {"center": Vector2(zone) * 8.0 + Vector2(rng.randf_range(1, 7), rng.randf_range(1, 7)), "radius": rng.randf_range(2.0, 4.0), "top": rng.randf_range(0.5, 1.0), "thickness": rng.randf_range(1.0, 2.0)}
			"lakes_2":
				# 0.0.5.21 : lac d'environ 2 zones, allongé dans une direction au hasard, bords irréguliers.
				var start := Vector2(zone) * 8.0 + Vector2(rng.randf_range(2.0, 6.0), rng.randf_range(2.0, 6.0))
				var along := Vector2.from_angle(rng.randf() * TAU)
				info.lake2 = {"start": start, "end": start + along * rng.randf_range(6.0, 9.0), "radius": rng.randf_range(3.5, 4.5), "depth": rng.randf_range(1.2, 2.2), "soils": rng.randi_range(0, 2), "turn": rng.randf() * TAU}
			"lakes_4":
				# 0.0.5.21 : grand lac d'environ 4 zones (8 m de rayon environ), bords irréguliers.
				var middle := Vector2(zone) * 8.0 + Vector2(rng.randf_range(2.0, 6.0), rng.randf_range(2.0, 6.0))
				info.lake4 = {"start": middle, "end": middle + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 3.0), "radius": rng.randf_range(6.5, 8.0), "depth": rng.randf_range(1.5, 2.6), "soils": rng.randi_range(0, 2), "turn": rng.randf() * TAU}
			"lakes_small", "lakes_medium", "lakes_large":
				# 0.0.5.23 : rayon, longueur du milieu et fond selon la taille (2 à 3, environ 10, environ 16 zones).
				var sizes := {"lakes_small": [4.5, 5.5, 3.0, 6.0, 1.5, 2.5], "lakes_medium": [11.0, 13.0, 0.0, 8.0, 2.5, 3.5], "lakes_large": [14.0, 16.0, 4.0, 12.0, 3.0, 4.0]}
				var size: Array = sizes[spec.key]
				var middle := Vector2(zone) * 8.0 + Vector2(rng.randf_range(1.0, 7.0), rng.randf_range(1.0, 7.0))
				info[spec.key] = {"start": middle, "end": middle + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(size[2], size[3]), "radius": rng.randf_range(size[0], size[1]), "depth": rng.randf_range(size[4], size[5]), "soils": rng.randi_range(0, 2), "turn": rng.randf() * TAU}
			"mountains":
				info.mountain = mountain(rng, zone)
			"mud_regions":
				# 0.0.5.21 : région de boue d'environ 2 zones (forme irrégulière), seule, hors des lacs.
				info.mud = {"center": Vector2(zone) * 8.0 + Vector2(rng.randf_range(1, 7), rng.randf_range(1, 7)), "radius": rng.randf_range(5.0, 7.0)}
			_:
				var form := {"kind":spec.key, "center":Vector2(zone)*8.0 + Vector2(rng.randf_range(1,7),rng.randf_range(1,7)), "direction":Vector2.from_angle(rng.randf()*TAU)}
				match spec.key:
					"low_hills":
						form.height = 1.0
						form.radius = rng.randf_range(4,7)
					"high_hills", "steep_hills":
						form.height = rng.randf_range(2,3)
						form.radius = rng.randf_range(5,7)
					"smooth_holes":
						form.height = -rng.randf_range(0.8,2.0)
						form.radius = rng.randf_range(3,5)
					"steep_holes":
						form.height = -rng.randf_range(1.5,3.2)
						form.radius = rng.randf_range(2,4)
					"deep_holes":
						form.height = -rng.randf_range(3.5,3.9)
						form.radius = rng.randf_range(3,5)
					"stone_holes":
						form.height = -rng.randf_range(6,7)
						form.radius = rng.randf_range(5,7)
				info.landforms.append(form)
	return info

static func default_text(key: String) -> String:
	for spec in SPECS:
		if spec.key == key:
			return "jamais dans le monde standard" if spec.default == 0 else "1 chance sur %d par zone (monde standard)" % spec.default
	return ""

# Ce que donne une chance sur n, en clair : combien de zones sur les WORLD_ZONES du monde, ou quelle part du sol.
static func estimate_text(key: String, n: int, version: int = VERSION) -> String:
	if n <= 0:
		return "Jamais"
	var starts := WORLD_ZONES / float(n)
	if key.ends_with("deserts"):
		var share := 1.0 - pow(1.0 - 1.0 / n, average_size(key, version))
		return "1 chance sur %d par zone : environ %d désert(s) dans le monde, %d %% du sol" % [n, roundi(starts), roundi(share * 100.0)]
	return "1 chance sur %d par zone : environ %d dans le monde (%d zones)" % [n, roundi(starts), WORLD_ZONES]

# 0.0.5.17 : comment un monde a été généré, en clair (Informations du monde → Génération du monde).
static func describe(options: Dictionary) -> String:
	var layers := "Sous-sol : 4 m de terre, 4 m de pierre (à la pioche), puis la Roche-mère incassable.\nToujours plat autour de l'apparition et de la plage. Même graine et mêmes réglages : même monde."
	if options.is_empty():
		return "Génération d'avant 0.0.5.16 (monde ancien, gardée telle quelle) :\ncollines douces jusqu'à 3 m, petites bosses ; par zone de 8 m : crête abrupte 1 chance sur 9, trou 1 sur 9,\npetit désert 1 sur 8, grand désert (3 ou 4 zones) 1 sur 12.\n" + layers
	var version := int(options.get("version", VERSION))
	var standard := options == defaults()
	var lines := ["%s (génération version %d)." % ["Génération standard" if standard else "Génération personnalisée", version]]
	if version >= 2:
		lines.append("Relief continu : collines douces jusqu'à 3 m, longues ondulations, petites bosses ; les trous se creusent dedans.")
	lines.append("Chances par zone de 8 m (le monde en compte %d) :" % WORLD_ZONES)
	for spec in specs_for(version):
		var n: int = options.get(spec.key, 0)
		lines.append("· %s : %s" % [spec.label, "jamais" if n == 0 else ("dans chaque zone" if n == 1 else estimate_text(spec.key, n, version))])
	lines.append("Déserts en tout : environ %d %% du sol (sable sur 2 m, puis la terre ; il tombe et glisse)." % roundi(desert_share(options) * 100.0))
	lines.append(layers)
	return "\n".join(lines)

# Taille d'un rocher au hasard : 1 (minuscule) bien plus souvent que 7 (énorme).
const ROCK_WEIGHTS := [30, 24, 18, 12, 8, 5, 3]

static func _rock_size(rng: RandomNumberGenerator) -> int:
	var total := 0
	for weight in ROCK_WEIGHTS:
		total += weight
	var pick := rng.randi_range(1, total)
	for index in range(ROCK_WEIGHTS.size()):
		pick -= ROCK_WEIGHTS[index]
		if pick <= 0:
			return index + 1
	return 1
