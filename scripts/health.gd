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
# 0.0.8.3 (demande de l'utilisateur) : une noisette se mange plus vite qu'une pomme (secondes).
const EAT_SECONDS := {"pomme": 1.0, "noisette": 0.5}

var value := MAX
var since_damage := REGEN_DELAY
var regen_time := 0.0

static func fall_damage(height: float, on_sand: bool = false) -> int:
	if height <= FALL_SAFE:
		return 0
	var points := (height - FALL_SAFE) * FALL_PER_METER * (SAND_FACTOR if on_sand else 1.0)
	return maxi(1, roundi(points))

# 0.0.8.2 (#229, demandes de l'utilisateur) : un arbre (ou le haut d'un arbre coupé) qui tombe blesse celui qui est
# dessous. De TREE_MIN (petit arbre) à TREE_MAX (très gros, tronc de TREE_BIG m) selon l'épaisseur du tronc ; et selon
# l'endroit touché : pile sous le tronc (TREE_BODY m de part et d'autre, la moitié de la largeur du joueur comprise) :
# tout ; plus loin, de moins en moins, jusqu'à quelques points en étant frôlé (TREE_GRAZE m plus loin) ; les branches du
# houppier, plus légères, la moitié. Hors de l'arbre couché : rien.
const TREE_MIN := 15.0
const TREE_MAX := 80.0
const TREE_SMALL := 0.1
const TREE_BIG := 0.45
const TREE_BODY := 0.35
const TREE_GRAZE := 0.7
const TREE_GRAZE_SHARE := 0.06
const TREE_CROWN_SHARE := 0.5

static func tree_strength(diameter: float) -> float:
	return lerpf(TREE_MIN, TREE_MAX, clampf(inverse_lerp(TREE_SMALL, TREE_BIG, diameter), 0.0, 1.0))

# base : pied de ce qui tombe ; direction : vers où il tombe (horizontale) ; length : sa longueur ; diameter : tronc ;
# crown_from : distance au pied où commence le houppier ; crown_radius : sa demi-largeur ; at : pieds du joueur.
static func tree_damage(base: Vector3, direction: Vector3, length: float, diameter: float, crown_from: float, crown_radius: float, at: Vector3) -> int:
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	var rel := Vector3(at.x - base.x, 0.0, at.z - base.z)
	var along := rel.dot(flat)
	if along < -TREE_BODY or along > length + TREE_BODY:
		return 0
	var side := (rel - flat * along).length()
	var body := diameter * 0.5 + TREE_BODY
	var share := 0.0
	if side <= body:
		share = 1.0
	elif side <= body + TREE_GRAZE:
		share = lerpf(1.0, TREE_GRAZE_SHARE, smoothstep(0.0, 1.0, (side - body) / TREE_GRAZE))
	if along >= crown_from and side > body and side <= maxf(crown_radius, body + TREE_GRAZE):
		var crown := lerpf(TREE_CROWN_SHARE, TREE_GRAZE_SHARE, clampf((side - body) / maxf(crown_radius - body, 0.01), 0.0, 1.0))
		share = maxf(share, crown)
	if share <= 0.0:
		return 0
	return maxi(1, roundi(tree_strength(diameter) * share))

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

static func eat_seconds(value: Dictionary) -> float:
	return float(EAT_SECONDS.get(value.get("objet", ""), 1.0))
