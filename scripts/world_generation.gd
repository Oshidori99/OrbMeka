extends RefCounted
# Paramètres propres au monde : une chance sur N par zone de 8 m (0 : jamais).
# Version 1 (0.0.5.16) : conservée telle quelle pour les mondes déjà créés avec elle.
# Version 2 (0.0.5.17) : génération standard des nouveaux mondes (relief moins plat, collines douces
# partout, déserts aux bords irréguliers) ; déserts moyens de 2 à 4 zones, grands de 4 à 6 (demande de
# l'utilisateur), plus rares par défaut (environ 1/6 du sol en désert, contre 1/3 avant). Les mondes sans
# paramètres (avant 0.0.5.16) gardent la génération de 0.0.5.15.
const VERSION := 2
const VERSIONS := [1, 2]
const STANDARD_SMALL_DENOMINATOR := 8
const STANDARD_GROUP_DENOMINATOR := 12
const STANDARD_FEATURE_DENOMINATOR := 9
const STANDARD_HILL_HEIGHT := 3.0
const SPECS := [
	{"key":"small_deserts", "label":"Petits déserts (1 zone)", "default":32},
	{"key":"medium_deserts", "label":"Déserts moyens (2 à 4 zones)", "default":48},
	{"key":"large_deserts", "label":"Grands déserts (4 à 6 zones)", "default":64},
	{"key":"low_hills", "label":"Collines douces de 1 bloc", "default":6},
	{"key":"high_hills", "label":"Collines douces de 2 à 3 blocs", "default":12},
	{"key":"steep_hills", "label":"Crêtes abruptes", "default":9},
	{"key":"smooth_holes", "label":"Trous aux bords doux", "default":12},
	{"key":"steep_holes", "label":"Trous aux bords abrupts", "default":18},
	{"key":"deep_holes", "label":"Trous bien profonds", "default":0},
	{"key":"stone_holes", "label":"Grands trous : 2 à 3 blocs dans la pierre", "default":0},
]
# Taille des déserts (nombre de zones, et case où ils tiennent) selon la version.
const DESERT_SIZES := {
	1: {"medium_desert": [4, 6, 3, 2], "big_desert": [8, 11, 4, 3]},
	2: {"medium_desert": [2, 4, 2, 2], "big_desert": [4, 6, 3, 2]},
}
const WORLD_ZONES := 256

static func defaults() -> Dictionary:
	var result := {"version": VERSION}
	for spec in SPECS:
		result[spec.key] = spec.default
	return result

static func valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	var version: Variant = value.get("version")
	# JSON relit les nombres en décimaux (2.0) : comparer en entier.
	if value.size() != SPECS.size() + 1 or not (version is int or version is float) or float(version) != int(version) or not int(version) in VERSIONS:
		return false
	for spec in SPECS:
		var n: Variant = value.get(spec.key)
		if not (n is int or n is float) or not is_finite(float(n)) or n != int(n) or n < 0 or n > 64:
			return false
	return true

# JSON relit les nombres en flottants : stabiliser les options en entiers après validation.
static func normalized(value: Dictionary) -> Dictionary:
	if value.is_empty():
		return {}
	var result := {"version": int(value.version)}
	for spec in SPECS:
		result[spec.key] = int(value[spec.key])
	return result

# 0.0.5.17 : estimations affichées dans l'écran Monde personnalisé (moyennes, pour le monde de 256 zones).
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

static func zone_info(terrain_seed: int, zone: Vector2i, options: Dictionary) -> Dictionary:
	var info := {"small_desert":false, "landforms":[]}
	for spec in SPECS:
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

# Ce que donne une chance sur n, en clair : combien de zones sur les 256 du monde, ou quelle part du sol.
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
	for spec in SPECS:
		var n: int = options.get(spec.key, 0)
		lines.append("· %s : %s" % [spec.label, "jamais" if n == 0 else ("dans chaque zone" if n == 1 else estimate_text(spec.key, n, version))])
	lines.append("Déserts en tout : environ %d %% du sol (sable sur 2 m, puis la terre ; il tombe et glisse)." % roundi(desert_share(options) * 100.0))
	lines.append(layers)
	return "\n".join(lines)
