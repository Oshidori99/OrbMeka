extends RefCounted
# 0.0.8 (#171, #204) : la vie en Survie, de 0 à 100 points (rien en Créatif). Dégâts de chute au-delà de FALL_SAFE m
# (FALL_PER_METER points par mètre, × SAND_FACTOR sur le sable, rien en tombant dans l'eau) ; régénération lente :
# REGEN_POINTS toutes les REGEN_SECONDS, après REGEN_DELAY s sans dégât. Manger un fruit redonne de la vie (FOOD).
# À 0 : retour au point de départ avec toute sa vie (0.0.8.1 : écran de mort et objets au sol, #205).

const MAX := 100
const FALL_SAFE := 4.0
const FALL_PER_METER := 8.0
const SAND_FACTOR := 0.75
const REGEN_DELAY := 6.0
const REGEN_SECONDS := 3.0
const REGEN_POINTS := 1
# Points rendus par fruit : pomme, pomme brune (vieille, couleur 3 : Inventory.APPLE_COLOR_NAMES), noisette.
const BROWN := 3
const FOOD := {"pomme": 15, "pomme_brune": 5, "noisette": 3}

var value := MAX
var since_damage := REGEN_DELAY
var regen_time := 0.0

static func fall_damage(height: float, on_sand: bool = false) -> int:
	if height <= FALL_SAFE:
		return 0
	var points := (height - FALL_SAFE) * FALL_PER_METER * (SAND_FACTOR if on_sand else 1.0)
	return maxi(1, roundi(points))

static func food_points(value: Dictionary) -> int:
	var id: String = value.get("objet", "")
	if id == "pomme" and int(value.get("couleur", 1)) == BROWN:
		return FOOD.pomme_brune
	return int(FOOD.get(id, 0))

func full() -> bool:
	return value >= MAX

func dead() -> bool:
	return value <= 0

# Rend les points vraiment perdus.
func damage(points: int) -> int:
	if points <= 0:
		return 0
	var lost := mini(points, value)
	value -= lost
	since_damage = 0.0
	regen_time = 0.0
	return lost

# Rend les points vraiment regagnés.
func heal(points: int) -> int:
	var gained := clampi(points, 0, MAX - value)
	value += gained
	return gained

func reset() -> void:
	value = MAX
	since_damage = REGEN_DELAY
	regen_time = 0.0

# Rend vrai si la vie a changé (régénération).
func step(delta: float) -> bool:
	since_damage += delta
	if value >= MAX or value <= 0 or since_damage < REGEN_DELAY:
		regen_time = 0.0
		return false
	regen_time += delta
	if regen_time < REGEN_SECONDS:
		return false
	regen_time -= REGEN_SECONDS
	return heal(REGEN_POINTS) > 0

func to_value() -> int:
	return value

func load_value(saved: Variant) -> void:
	value = clampi(int(saved), 1, MAX) if saved is float or saved is int else MAX
