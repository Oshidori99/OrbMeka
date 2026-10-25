extends RefCounted
# Paramètres propres au monde : une chance sur N par zone de 8 m.
# Version 1 : conserver cet algorithme pour les mondes déjà créés.
const VERSION := 1
const STANDARD_SMALL_DENOMINATOR := 8
const STANDARD_GROUP_DENOMINATOR := 12
const STANDARD_FEATURE_DENOMINATOR := 9
const STANDARD_HILL_HEIGHT := 3.0
const SPECS := [
	{"key":"small_deserts", "label":"Petits déserts (1 chunk)", "default":STANDARD_SMALL_DENOMINATOR},
	{"key":"medium_deserts", "label":"Déserts moyens (4 à 6 chunks)", "default":0},
	{"key":"large_deserts", "label":"Grands déserts (8 à 11 chunks)", "default":0},
	{"key":"low_hills", "label":"Collines lisses de 1 bloc", "default":0},
	{"key":"high_hills", "label":"Collines lisses de 2 à 3 blocs", "default":0},
	{"key":"steep_hills", "label":"Collines abruptes", "default":STANDARD_FEATURE_DENOMINATOR},
	{"key":"smooth_holes", "label":"Trous plutôt lisses", "default":STANDARD_FEATURE_DENOMINATOR},
	{"key":"steep_holes", "label":"Trous aux bords abrupts", "default":0},
	{"key":"deep_holes", "label":"Trous bien profonds", "default":0},
	{"key":"stone_holes", "label":"Grands trous : 2 à 3 blocs dans la pierre", "default":0},
]

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
	if value.size() != SPECS.size() + 1 or value.get("version") != VERSION:
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
	var result := {"version":VERSION}
	for spec in SPECS:
		result[spec.key] = int(value[spec.key])
	return result

# Groupes connexes, sans doublon ; chaque désert occupe exactement le nombre de chunks choisi
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

static func chunk_info(terrain_seed: int, chunk: Vector2i, options: Dictionary) -> Dictionary:
	var info := {"small_desert":false, "landforms":[]}
	for spec in SPECS:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([VERSION, terrain_seed, chunk.x, chunk.y, spec.key])
		var denominator: int = options[spec.key]
		if denominator == 0 or rng.randf() >= 1.0 / denominator:
			continue
		match spec.key:
			"small_deserts":
				info.small_desert = true
			"medium_deserts":
				info.medium_desert = cluster(rng,rng.randi_range(4,6),3,2)
			"large_deserts":
				info.big_desert = cluster(rng,rng.randi_range(8,11),4,3)
			_:
				var form := {"kind":spec.key, "center":Vector2(chunk)*8.0 + Vector2(rng.randf_range(1,7),rng.randf_range(1,7)), "direction":Vector2.from_angle(rng.randf()*TAU)}
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
	if key in ["low_hills","high_hills"]:
		return "relief continu standard jusqu’à 3 blocs, sans fréquence séparée"
	for spec in SPECS:
		if spec.key == key:
			return "absent du monde standard" if spec.default == 0 else "1 chance sur %d par chunk (monde standard)" % spec.default
	return ""
