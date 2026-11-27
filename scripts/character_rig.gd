extends RefCounted
# 0.0.8.54 (lot C1, #224, #225, #230, demandes de l'utilisateur) : les bras (et les jambes) des personnages qui bougent,
# et l'objet tenu dans leurs mains, vus de dos, de face, dans leur ombre et dans la vitrine de l'accueil.
# Squelette des modèles humains (sources_blender/personnages/equiper_personnages.py) : Bassin, Dos, Poitrine, Cou, Tete ;
# Epaule, Bras, AvantBras, Main ; Cuisse, Jambe, Pied (.G : gauche du personnage, .D : droite). Les os des bras et des
# jambes descendent : une rotation autour de leur axe X les fait aller vers l'avant (angle négatif) ou l'arrière.
# Poses calculées à chaque image (aucune animation enregistrée : léger) :
# - repos : bras le long du corps ; en marchant, bras et jambes se balancent (pas plus vite en courant) ;
# - objet tenu : l'avant-bras levé devant (une main, ou les deux pour un objet porté à deux mains) ;
# - gestes (comme la main à la première personne) : « dig » (frapper, creuser : le bras monte puis s'abat), « place »
#   (poser : le bras se tend vers le sol devant), « grab » (ramasser : pareil, plus bas), « eat » (manger : la main à la
#   bouche).
const ARM_BONES := ["Epaule", "Bras", "AvantBras", "Main"]
const LEG_BONES := ["Cuisse", "Jambe", "Pied"]
const GESTURE_SECONDS := {"dig": 0.45, "place": 0.4, "grab": 0.5, "eat": 0.6, "fetch": 0.38}
# Balancement en marchant : angle des bras et des jambes (radians) à pleine vitesse de marche, pas par seconde.
const WALK_ARM := 0.42
const WALK_LEG := 0.5
const WALK_STEPS := 1.9

var skeleton: Skeleton3D
var _ids := {}
var _rest := {}
var _hands := {}
var holding := {"G": false, "D": false}
var both_hands := false
var gesture := ""
var gesture_time := 0.0
var gesture_side := "D"
var _phase := 0.0
var _walk := 0.0

static func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found != null:
			return found
	return null

# Prépare le squelette d'un modèle (rend faux s'il n'en a pas : modèle simple, animal sans squelette).
func setup(model: Node) -> bool:
	skeleton = find_skeleton(model)
	if skeleton == null:
		return false
	for bone in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(bone)
		_ids[bone_name] = bone
		_rest[bone_name] = skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	for tag in ["G", "D"]:
		if _ids.has("Main." + tag):
			var hand := BoneAttachment3D.new()
			hand.name = "Main" + tag
			hand.bone_name = "Main." + tag
			skeleton.add_child(hand)
			_hands[tag] = hand
	# 0.0.8.56 (lot C2) : un animal (os Corps, Tete) : il se dandine en marchant (update_animal).
	animal = _ids.has("Corps") and not _ids.has("Bras.G")
	return animal or (_ids.has("Bras.G") and _ids.has("Bras.D"))

var animal := false
# Animal qui marche : balancement du corps (de côté), petit saut à chaque pas, la tête qui hoche ; à l'arrêt, la tête
# bouge un peu (il respire).
const ANIMAL_WADDLE := 0.16
const ANIMAL_HOP := 0.035
const ANIMAL_NOD := 0.1
var _idle := 0.0

func update_animal(delta: float, speed: float) -> void:
	_walk = move_toward(_walk, clampf(speed / 3.0, 0.0, 1.0), delta * 4.0)
	_phase = fmod(_phase + delta * TAU * 2.2 * maxf(_walk, 0.0001), TAU)
	_idle = fmod(_idle + delta, TAU * 10.0)
	var step := sin(_phase)
	if _ids.has("Corps"):
		var bone: int = _ids["Corps"]
		var rotation := Quaternion(Vector3.FORWARD, step * ANIMAL_WADDLE * _walk) * Quaternion(Vector3.RIGHT, -0.08 * _walk)
		skeleton.set_bone_pose_rotation(bone, _rest["Corps"] * rotation)
		var origin: Vector3 = skeleton.get_bone_rest(bone).origin
		skeleton.set_bone_pose_position(bone, origin + Vector3(0.0, absf(step) * ANIMAL_HOP * _walk, 0.0))
	if _ids.has("Tete"):
		var nod := sin(_phase * 2.0) * ANIMAL_NOD * _walk + sin(_idle * 1.3) * 0.04 * (1.0 - _walk)
		var look := sin(_idle * 0.5) * 0.12 * (1.0 - _walk)
		skeleton.set_bone_pose_rotation(_ids["Tete"], _rest["Tete"] * Quaternion(Vector3.RIGHT, nod) * Quaternion(Vector3.UP, look))

func has_bone(bone_name: String) -> bool:
	return _ids.has(bone_name)

# L'objet montré dans une main (tag « G » ou « D ») : remplace le précédent ; null : main vide.
func hold(tag: String, item: Node3D) -> void:
	holding[tag] = item != null
	var hand: BoneAttachment3D = _hands.get(tag)
	if hand == null:
		if item != null:
			item.free()
		return
	for child in hand.get_children():
		child.queue_free()
	if item != null:
		hand.add_child(item)

func held_node(tag: String) -> Node3D:
	var hand: BoneAttachment3D = _hands.get(tag)
	if hand == null or hand.get_child_count() == 0:
		return null
	return hand.get_child(hand.get_child_count() - 1)

func play(name: String, side: String = "D") -> void:
	if not GESTURE_SECONDS.has(name):
		return
	gesture = name
	gesture_side = side
	gesture_time = 0.0

func _turn(bone_name: String, forward: float, out: float = 0.0, twist: float = 0.0) -> void:
	if not _ids.has(bone_name):
		return
	var rotation := Quaternion(Vector3.RIGHT, -forward) * Quaternion(Vector3.FORWARD, out) * Quaternion(Vector3.UP, twist)
	skeleton.set_bone_pose_rotation(_ids[bone_name], _rest[bone_name] * rotation)

# Une image : speed : vitesse de marche (m/s, 0 à l'arrêt) ; gestures : gestes et objets tenus montrés (sinon : repos et
# marche seulement, par exemple pour le corps vu à la première personne).
func update(delta: float, speed: float, gestures: bool = true) -> void:
	if skeleton == null:
		return
	if animal:
		update_animal(delta, speed)
		return
	_walk = move_toward(_walk, clampf(speed / 4.0, 0.0, 1.0), delta * 4.0)
	_phase = fmod(_phase + delta * TAU * WALK_STEPS * maxf(_walk, 0.0001) * (0.6 + 0.4 * clampf(speed / 4.0, 0.0, 2.0)), TAU)
	var swing := sin(_phase) * _walk
	var share := 0.0
	if gesture != "":
		gesture_time += delta
		share = gesture_time / float(GESTURE_SECONDS[gesture])
		if share >= 1.0:
			gesture = ""
			share = 0.0
	for tag in ["G", "D"]:
		var side := 1.0 if tag == "G" else -1.0
		var arm_swing := swing * WALK_ARM * side
		var upper := arm_swing
		var lower := 0.12
		var hand := 0.0
		if gestures and (holding[tag] or (both_hands and holding["G"] != holding["D"])):
			# Objet tenu : le bras un peu devant, l'avant-bras levé (à deux mains : les deux, un peu plus haut).
			upper = 0.18 + arm_swing * 0.3
			lower = 0.85 if not both_hands else 1.05
			hand = -0.15
		if gestures and gesture != "" and (tag == gesture_side or both_hands):
			var curve := sin(share * PI)
			match gesture:
				"dig":
					# Le bras monte haut, puis s'abat devant (le haut du geste au premier tiers).
					var up := sin(minf(share / 0.4, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.4, 1.0, share))
					var down := smoothstep(0.35, 0.65, share) * (1.0 - smoothstep(0.7, 1.0, share))
					upper = lerpf(upper, 2.3, up) + down * 0.4
					lower = lerpf(lower, 0.5, up) + down * 0.2
				"place", "grab":
					upper = lerpf(upper, 1.1 if gesture == "place" else 0.9, curve)
					lower = lerpf(lower, 0.25, curve)
					hand = lerpf(hand, 0.4, curve)
				"eat":
					upper = lerpf(upper, 0.6, curve)
					lower = lerpf(lower, 2.1, curve)
				"fetch":
					# Prendre dans une poche ou le sac : la main descend à la hanche, un peu en arrière, puis revient.
					upper = lerpf(upper, -0.45, curve)
					lower = lerpf(lower, 0.35, curve)
					hand = lerpf(hand, 0.3, curve)
		_turn("Bras." + tag, upper, side * 0.06)
		_turn("AvantBras." + tag, lower)
		_turn("Main." + tag, hand)
		var leg := -swing * WALK_LEG * side
		_turn("Cuisse." + tag, leg)
		_turn("Jambe." + tag, -maxf(0.0, -leg) * 1.2 - 0.05 * _walk)
		_turn("Pied." + tag, maxf(0.0, -leg) * 0.4)
	_turn("Dos", 0.04 * _walk)
	_turn("Tete", -0.03 * _walk)
