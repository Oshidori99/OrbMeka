extends Node3D
# 0.0.7.6 (demande de l'utilisateur, issue #201) : main droite vue à la première personne, en bas à droite, petite pour
# laisser voir le jeu. Elle tient l'objet choisi dans la barre : petit tas de la matière (terre, sable…), caillou, éclat,
# pomme ou noisette ; main vide : la main seule. La pioche garde son propre dessin (player.gd), la main est alors cachée.
# Modèle : assets/hands/main_droite.glb, fait dans Blender (sources_blender/main/generer_main.py), couleur de peau du
# personnage choisi. Elle descend un peu quand on creuse ou qu'on pose (nudge). Sans ombre ; enfant de la caméra.
const Inventory = preload("res://scripts/inventory.gd")
const Rocks = preload("res://scripts/rocks.gd")
const Trees = preload("res://scripts/trees.gd")
const ReturnOrb = preload("res://scripts/return_orb.gd")
const Fibers = preload("res://scripts/fibers.gd")
const StoneHeads = preload("res://scripts/stone_heads.gd")
const ToolModels = preload("res://scripts/tool_models.gd")
const CharacterPreview = preload("res://scripts/character_preview.gd")
const MODEL := "res://assets/hands/main_droite.glb"
# Place du poignet (repère de la caméra), taille ; doigts vers l'avant et un peu vers le centre, paume tournée vers soi.
const REST := Vector3(0.41, -0.29, -0.47)
const SCALE := 0.8
# Objet tenu : au creux de la paume (repère de la main), jamais plus grand que MAX_ITEM (pour ne pas cacher le jeu).
const PALM := Vector3(0.0, 0.014, -0.045)
# 0.0.8.7 (#245, demande de l'utilisateur : tout paraissait trop petit en main) : 15 cm (avant 7 cm).
const MAX_ITEM := 0.15
const Plants = preload("res://scripts/plants.gd")
const GroundItems = preload("res://scripts/ground_items.gd")

var hand: Node3D
# 0.0.7.10 : main gauche : la main droite en miroir gauche-droite (pouce toujours en haut), à gauche de l'écran.
var left := false
var rest := REST
var held: Node3D
var skin_material: StandardMaterial3D
# Matière des pierres du monde selon l'aspect (0 pierre, 1 calcaire, 2 silex) ; vide : couleur unie.
var stone_material := Callable()
var _materials := {}
var _tween: Tween

func setup(skin_id: String, stone: Callable = Callable(), left_hand: bool = false) -> void:
	left = left_hand
	name = "MainGauche" if left else "Main"
	stone_material = stone
	var fingers := Vector3(-0.3, 0.32, -1.0).normalized()
	var palm := Vector3(0.0, 1.0, 0.75).normalized()
	palm = (palm - fingers * palm.dot(fingers)).normalized()
	# Dans Godot (export glTF), le modèle a les doigts vers -Z, la paume vers +Y et le pouce vers +X.
	basis = Basis(fingers.cross(palm), palm, -fingers).scaled(Vector3.ONE * SCALE)
	rest = REST
	if left:
		# Miroir par le plan vertical de la caméra (gauche ↔ droite) : le haut reste en haut.
		var mirror := Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
		basis = mirror * basis
		rest = _rest_for(false)
	position = rest
	var scene: PackedScene = load(MODEL) if ResourceLoader.exists(MODEL) else null
	if scene != null:
		hand = scene.instantiate()
		add_child(hand)
		# 0.0.8.17 (#224) : le modèle porte ses poses (formes de mélange, sources_blender/main/generer_main.py).
		var shapes: Array = hand.find_children("*", "MeshInstance3D", true, false)
		if not shapes.is_empty():
			pose_mesh = shapes[0]
	held = Node3D.new()
	held.name = "Tenu"
	held.position = PALM
	add_child(held)
	set_skin(skin_id)

# 0.0.8.21 (signalé par l'utilisateur : mains trop blanches sur le Web) : en rendu Compatibility (Web), la lumière est plus
# forte (world.gd, COMPAT_AMBIENT) : la peau claire saturait en blanc (mesuré sur captures : #dcc1a0 au PC, #ffffff au
# Web). La couleur des mains et des objets tenus y est assombrie (comme les feuilles des arbres, trees.gd).
# Le Web enlève aussi un peu de couleur (saturation 0,68) : elle est un peu renforcée ici.
const WEB_TONE := 0.52
const WEB_SATURATION := 1.4
static var _web := RenderingServer.get_current_rendering_method() == "gl_compatibility"

static func web_tone(color: Color) -> Color:
	if not _web:
		return color
	var toned := Color.from_hsv(color.h, minf(color.s * WEB_SATURATION, 1.0), color.v * WEB_TONE, color.a)
	return toned

func set_skin(skin_id: String) -> void:
	if skin_material == null:
		skin_material = StandardMaterial3D.new()
		skin_material.roughness = 0.7
	skin_material.albedo_color = web_tone(CharacterPreview.tone_color(skin_id))
	if hand != null:
		for node in hand.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_override = skin_material
			(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# L'objet en main (case choisie de la barre) ; {} : main vide.
func show_item(value: Dictionary) -> void:
	var grip := Vector3.ZERO
	for child in held.get_children():
		child.queue_free()
	visible = value.get("objet", "") != "pioche"
	if value.is_empty() or not Inventory.ITEMS.has(value.get("objet", "")):
		hold_pose = ["", 0.0]
		_go_pose("", 0.0)
		return
	var id: String = value.objet
	var spec: Dictionary = Inventory.ITEMS[id]
	var shown: Dictionary = value.pile[-1] if value.has("pile") and not value.pile.is_empty() else value
	var made := MeshInstance3D.new()
	made.name = "Objet"
	made.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var size := 0.06
	if spec.has("matiere"):
		# Petit tas de la matière, posé dans la paume.
		var dome := SphereMesh.new()
		dome.radius = 0.5
		dome.height = 0.5
		dome.is_hemisphere = true
		made.mesh = dome
		made.material_override = _pile_material(id, spec.couleur)
		size = 0.065
		made.scale = Vector3(size, size * 0.9, size)
	else:
		match spec.get("forme", ""):
			"caillou", "eclat":
				made.mesh = Rocks.pebble_mesh(clampi(int(shown.get("forme", 1)), 1, 7))
				# 0.0.8.21 (demande de l'utilisateur : on le voyait mal) : éclat en main plus grand (avant 5 cm).
				size = minf(Rocks.PEBBLE_SIZES[clampi(int(shown.get("taille", 2)), 1, 7) - 1], _max_item()) if spec.forme == "caillou" else 0.08
				made.material_override = _stone(spec)
				made.scale = Vector3(size, size * (1.0 if spec.forme == "caillou" else 0.6), size)
				made.position.y = size * 0.25
			"fruit":
				made.mesh = Trees._fruit_mesh(Trees.APPLE if id == "pomme" else Trees.HAZEL, id == "pomme" and int(shown.get("couleur", 1)) == 4)
				size = minf(float(shown.get("diametre", Inventory.APPLE_SIZES[1] if id == "pomme" else 0.025)), _max_item())
				if id == "pomme" and int(shown.get("couleur", 1)) != 4:
					made.material_override = _plain(Inventory.APPLE_COLORS[clampi(int(shown.get("couleur", 1)), 0, 4)])
				made.scale = Vector3.ONE * size * 0.5
				made.position.y = size * 0.45
			# 0.0.8.4 (#213) : fibres (petite botte) et liane (rouleau) dans la paume.
			"fibre", "liane", "ficelle":
				made.mesh = Fibers.bundle_mesh() if spec.forme == "fibre" else (Fibers.coil_mesh() if spec.forme == "liane" else Fibers.cord_mesh())
				made.material_override = null if spec.forme == "liane" else _plain(spec.couleur)
				size = 0.6 if spec.forme == "fibre" else (0.3 if spec.forme == "liane" else 0.8)
				made.scale = Vector3.ONE * size
				made.position.y = 0.01
			# 0.0.8.6 (#211) : outil (à ficeler ou ficelé) en travers de la paume, raccourci pour ne pas cacher le jeu.
			"outil_brut", "outil_pierre":
				made.mesh = ToolModels.mesh(shown)
				# 0.0.8.9 (bug signalé par l'utilisateur : la pioche était de travers) : tenu comme un vrai outil, en repère de
				# la caméra : le manche dressé vers l'avant et un peu vers le centre, la tête en haut, la main sur le bas du manche.
				# 0.0.8.7 (#245) : 70 % de sa vraie taille.
				var want := Basis(Vector3.BACK, 0.35 * (-1.0 if left else 1.0)) * Basis(Vector3.RIGHT, -0.75)
				want = want.scaled(Vector3.ONE * 0.7)
				made.basis = basis.inverse() * want
				grip = basis.inverse() * (want * Vector3(0.0, -0.12, 0.0))
			# 0.0.8.5 (#211) : tête taillée dans la paume.
			"tete":
				made.mesh = StoneHeads.mesh("hache" if id == "tete_hache" else "pioche", 1.0)
				made.material_override = StoneHeads.material(int(shown.get("pierre", 1)))
				size = StoneHeads.scale_for("hache" if id == "tete_hache" else "pioche", int(shown.get("taille", 4)))
				made.scale = Vector3.ONE * size
				made.position.y = size * 0.2
			# 0.0.8.2 (#231) : orbe de retour, posée dans la paume.
			"orbe":
				made.mesh = ReturnOrb.mesh()
				size = minf(ReturnOrb.SIZE, _max_item())
				made.scale = Vector3.ONE * size
				made.position.y = size * 0.5
			# 0.0.7.8 : bâton ou tronc en travers de la paume (raccourci pour ne pas cacher le jeu).
			"bois":
				var stick := CylinderMesh.new()
				stick.top_radius = 0.42
				stick.bottom_radius = 0.5
				stick.height = 1.0
				stick.radial_segments = 8
				made.mesh = stick
				# 0.0.8.7 (demande de l'utilisateur : le bois paraissait plus petit qu'en vrai) : jusqu'à 10 cm (20 cm à deux mains)
				# d'épaisseur et 50 cm de long (avant 5 cm, 12 cm et 30 cm).
				var thick := minf(float(shown.get("epaisseur", 3.0)) / 100.0, 0.1 if not both else 0.2)
				made.material_override = Trees.material(clampi(int(shown.get("essence", 0)), 0, 3), "bark")
				made.scale = Vector3(thick, minf(float(shown.get("longueur", 1.0)), 0.5), thick)
				made.rotation.z = PI * 0.5
				made.position.y = thick * 0.5
			# 0.0.8.15 (#239) : plante arrachée (debout, petite) et motte de gazon, dans la paume.
			"plante":
				made.mesh = Plants.mesh(clampi(int(spec.get("plante", 0)), 0, 2))
				size = 0.22 / Plants.SIZES[clampi(int(spec.get("plante", 0)), 0, 2)]
				made.scale = Vector3.ONE * size
			"gazon":
				made.mesh = GroundItems.turf_mesh()
				made.scale = Vector3.ONE * 0.55
				made.position.y = 0.012
	# 0.0.8.17 (#224) : la main serre ce qu'elle tient (selon l'objet).
	hold_pose = _hold_pose_for(spec)
	_go_pose(hold_pose[0], hold_pose[1])
	# La paume regarde vers +Y (repère de la main) : l'objet repose dessus.
	made.position = grip if grip != Vector3.ZERO else Vector3(0.0, made.position.y, 0.0)
	held.add_child(made)

func _stone(spec: Dictionary) -> Material:
	var look: int = int(spec.get("aspect", -1))
	if look >= 0 and stone_material.is_valid():
		return stone_material.call(look)
	return _plain(spec.couleur)

func _plain(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var made := StandardMaterial3D.new()
		made.albedo_color = web_tone(color)
		made.roughness = 0.6
		# 0.0.8.4 : brins de fibres plats : visibles des deux côtés.
		made.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = made
	return _materials[key]

# Tas de matière : couleur de la matière, avec du grain (bruit fait une fois par matière).
func _pile_material(id: String, color: Color) -> StandardMaterial3D:
	var key := "tas/" + id
	if not _materials.has(key):
		var noise := FastNoiseLite.new()
		noise.frequency = 0.35 if id in ["sable", "gravier"] else 0.12
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR if id == "gravier" else FastNoiseLite.TYPE_SIMPLEX
		var grain := NoiseTexture2D.new()
		grain.width = 64
		grain.height = 64
		grain.seamless = true
		grain.noise = noise
		var made := StandardMaterial3D.new()
		made.albedo_texture = grain
		made.albedo_color = web_tone(Color(minf(color.r * 1.5, 1.0), minf(color.g * 1.5, 1.0), minf(color.b * 1.5, 1.0)))
		made.roughness = 0.95 if id != "boue" else 0.35
		made.uv1_scale = Vector3(2.0, 2.0, 2.0)
		_materials[key] = made
	return _materials[key]

# Petit mouvement quand on creuse ou qu'on pose.
func nudge() -> void:
	if not is_inside_tree():
		return
	if _tween != null:
		_tween.kill()
	position = rest
	_tween = create_tween()
	_tween.tween_property(self, "position", rest + Vector3(0.01 if left else -0.01, -0.03, 0.02), 0.08).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", rest, 0.14).set_ease(Tween.EASE_IN_OUT)

# 0.0.7.10 (demande de l'utilisateur) : objet lourd porté à deux mains : les deux mains glissent vers le centre de
# l'écran (l'objet tenu entre elles), puis reviennent à leur place quand on le lâche.
const TWO_HANDS_REST := Vector3(0.15, -0.25, -0.5)
var both := false

func set_both(value: bool) -> void:
	if value == both:
		return
	both = value
	rest = _rest_for(both)
	# Main droite : l'objet glisse au milieu, entre les deux mains (repère de la caméra ramené à celui de la main).
	if is_instance_valid(held) and not left:
		held.position = PALM + (basis.inverse() * Vector3(-TWO_HANDS_REST.x, 0.03, 0.0) if both else Vector3.ZERO)
	if not is_inside_tree():
		position = rest
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", rest, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

# Objet tenu : petit dans une main ; plus grand (jusqu'à 16 cm) porté à deux mains, entre elles.
func _max_item() -> float:
	return 0.16 if both else MAX_ITEM

# 0.0.8.4 (demande de l'utilisateur) : récolter (R maintenu) : la main s'avance vers la plante, la saisit et tire par
# petits coups pendant que l'anneau se remplit ; share : 0 à 1 (0 : elle revient à sa place).
const PULL_REACH := Vector3(-0.08, -0.14, -0.2)
var pulling := false

func pull(share: float, time: float) -> void:
	if share <= 0.0:
		if pulling:
			pulling = false
			_go_pose(hold_pose[0], hold_pose[1])
			if is_inside_tree():
				if _tween != null:
					_tween.kill()
				_tween = create_tween()
				_tween.tween_property(self, "position", rest + Vector3(0.0, 0.04, 0.03), 0.1).set_ease(Tween.EASE_OUT)
				_tween.tween_property(self, "position", rest, 0.18).set_ease(Tween.EASE_IN_OUT)
			else:
				position = rest
		return
	if not pulling and _tween != null:
		_tween.kill()
	if not pulling:
		_go_pose("prise", 1.0)
	pulling = true
	var reach := minf(share * 3.0, 1.0)
	var tug := sin(time * 16.0) * 0.012 * reach
	var toward := Vector3(-PULL_REACH.x if left else PULL_REACH.x, PULL_REACH.y, PULL_REACH.z)
	position = rest + toward * reach + Vector3(0.0, tug, -tug * 0.6)

# 0.0.8.7 (demande de l'utilisateur : à 60° de champ de vision, les bras sortaient de l'écran) : la place des mains suit le
# champ de vision (réglée pour 75°) : plus il est étroit, plus elles se rapprochent du centre.
var view_scale := 1.0

static func scale_for_fov(fov: float) -> float:
	return tan(deg_to_rad(clampf(fov, 30.0, 120.0)) * 0.5) / tan(deg_to_rad(75.0) * 0.5)

func _rest_for(two: bool) -> Vector3:
	var base := TWO_HANDS_REST if two else REST
	return Vector3(base.x * (-1.0 if left else 1.0) * view_scale, base.y * view_scale, base.z)

func set_view_scale(value: float) -> void:
	view_scale = value
	rest = _rest_for(both)
	if not pulling:
		position = rest

# --- 0.0.8.17 (#224, demande de l'utilisateur) : animations des bras et des mains à la première personne ---
# La main a des poses (formes de mélange du modèle) : prise (serrer), griffe (creuser), ouverte (poser), pince (pouce et
# index). Elle passe de l'une à l'autre en douceur (POSE_SPEED). Au repos, elle serre ce qu'elle tient (hold_pose) ;
# gestes : creuser (griffe qui gratte vers soi), poser (main ouverte qui pousse), ramasser (elle s'avance ouverte, se
# ferme, revient), récolter et arracher (elle serre et tire), manger (le fruit monte vers la bouche).
const POSES := ["prise", "griffe", "ouverte", "pince"]
const POSE_SPEED := 14.0
const DIG_REACH := Vector3(-0.03, -0.09, -0.12)
const GRAB_REACH := Vector3(-0.06, -0.16, -0.22)
const PLACE_REACH := Vector3(-0.02, -0.06, -0.14)
const MOUTH := Vector3(-0.3, 0.12, 0.05)
var pose_mesh: MeshInstance3D
var hold_pose := ["", 0.0]
var _pose_goal := {}
var _pose_now := {}
var _gesture_left := 0.0

static func _hold_pose_for(spec: Dictionary) -> Array:
	if spec.has("matiere"):
		return ["prise", 0.25]
	match spec.get("forme", ""):
		"caillou", "eclat", "fruit", "tete", "orbe":
			return ["prise", 0.55]
		"fibre", "ficelle", "plante":
			return ["pince", 0.7]
		"liane", "gazon":
			return ["prise", 0.35]
		"outil_brut", "outil_pierre", "bois":
			return ["prise", 0.9]
	return ["", 0.0]

# Pose voulue (une seule à la fois ; "" : la main de base).
func _go_pose(name: String, amount: float) -> void:
	for each in POSES:
		_pose_goal[each] = amount if each == name else 0.0

func pose_value(name: String) -> float:
	return float(_pose_now.get(name, 0.0))

func _process(delta: float) -> void:
	if _gesture_left > 0.0:
		_gesture_left -= delta
		if _gesture_left <= 0.0 and not pulling:
			_go_pose(hold_pose[0], hold_pose[1])
	if pose_mesh == null or pose_mesh.mesh == null:
		return
	var step := minf(1.0, delta * POSE_SPEED)
	for name: String in _pose_goal:
		var now := lerpf(float(_pose_now.get(name, 0.0)), float(_pose_goal[name]), step)
		if absf(now - float(_pose_now.get(name, 0.0))) < 0.0005 and absf(now - float(_pose_goal[name])) < 0.001:
			now = float(_pose_goal[name])
		_pose_now[name] = now
		var index := pose_mesh.find_blend_shape_by_name(name)
		if index >= 0:
			pose_mesh.set_blend_shape_value(index, now)

func _side(offset: Vector3) -> Vector3:
	return Vector3(-offset.x if left else offset.x, offset.y, offset.z)

func _gesture(pose: String, amount: float, reach: Vector3, out_seconds: float, back_seconds: float, turn: float = 0.0) -> void:
	_go_pose(pose, amount)
	_gesture_left = out_seconds + back_seconds
	if not is_inside_tree() or pulling:
		return
	if _tween != null:
		_tween.kill()
	position = rest
	rotation.x = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", rest + _side(reach), out_seconds).set_ease(Tween.EASE_OUT)
	if turn != 0.0:
		_tween.tween_property(self, "rotation:x", turn, out_seconds).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_property(self, "position", rest, back_seconds).set_ease(Tween.EASE_IN_OUT)
	if turn != 0.0:
		_tween.tween_property(self, "rotation:x", 0.0, back_seconds).set_ease(Tween.EASE_IN_OUT)

# Creuser, casser à la main : les doigts en griffe grattent vers soi.
func dig() -> void:
	_gesture("griffe", 1.0, DIG_REACH, 0.09, 0.16, -0.35)

# Poser : la main s'ouvre et pousse vers l'avant.
func place() -> void:
	_gesture("ouverte", 0.8, PLACE_REACH, 0.08, 0.15)

# Ramasser : la main s'avance ouverte vers le sol, se ferme sur l'objet, revient.
func grab() -> void:
	_go_pose("ouverte", 0.9)
	_gesture_left = 0.45
	if not is_inside_tree() or pulling:
		return
	if _tween != null:
		_tween.kill()
	position = rest
	_tween = create_tween()
	_tween.tween_property(self, "position", rest + _side(GRAB_REACH), 0.13).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): _go_pose("prise", 1.0))
	_tween.tween_interval(0.06)
	_tween.tween_property(self, "position", rest, 0.2).set_ease(Tween.EASE_IN_OUT)

# Manger (share : 0 à 1 ; 0 : la main revient) : le fruit monte vers la bouche, en bas au milieu de l'écran.
var eating := false

func eat(share: float) -> void:
	if share <= 0.0:
		if eating:
			eating = false
			_go_pose(hold_pose[0], hold_pose[1])
			position = rest
			rotation.x = 0.0
		return
	if not eating and _tween != null:
		_tween.kill()
	eating = true
	_go_pose("prise", 0.8)
	var reach := smoothstep(0.0, 0.35, share)
	var chew := sin(share * 40.0) * 0.008 * reach
	position = rest + _side(MOUTH) * reach + Vector3(0.0, chew, 0.0)
	rotation.x = 0.5 * reach
