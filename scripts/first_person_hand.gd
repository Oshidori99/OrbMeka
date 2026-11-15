extends Node3D
# 0.0.7.6 (demande de l'utilisateur, issue #201) : main droite vue à la première personne, en bas à droite, petite pour
# laisser voir le jeu. Elle tient l'objet choisi dans la barre : petit tas de la matière (terre, sable…), caillou, éclat,
# pomme ou noisette ; main vide : la main seule. La pioche garde son propre dessin (player.gd), la main est alors cachée.
# Modèle : assets/hands/main_droite.glb, fait dans Blender (sources_blender/main/generer_main.py), couleur de peau du
# personnage choisi. Elle descend un peu quand on creuse ou qu'on pose (nudge). Sans ombre ; enfant de la caméra.
const Inventory = preload("res://scripts/inventory.gd")
const Rocks = preload("res://scripts/rocks.gd")
const Trees = preload("res://scripts/trees.gd")
const CharacterPreview = preload("res://scripts/character_preview.gd")
const MODEL := "res://assets/hands/main_droite.glb"
# Place du poignet (repère de la caméra), taille ; doigts vers l'avant et un peu vers le centre, paume tournée vers soi.
const REST := Vector3(0.41, -0.29, -0.47)
const SCALE := 0.8
# Objet tenu : au creux de la paume (repère de la main), jamais plus grand que MAX_ITEM (pour ne pas cacher le jeu).
const PALM := Vector3(0.0, 0.014, -0.045)
const MAX_ITEM := 0.07

var hand: Node3D
var held: Node3D
var skin_material: StandardMaterial3D
# Matière des pierres du monde selon l'aspect (0 pierre, 1 calcaire, 2 silex) ; vide : couleur unie.
var stone_material := Callable()
var _materials := {}
var _tween: Tween

func setup(skin_id: String, stone: Callable = Callable()) -> void:
	name = "Main"
	stone_material = stone
	var fingers := Vector3(-0.3, 0.32, -1.0).normalized()
	var palm := Vector3(0.0, 1.0, 0.75).normalized()
	palm = (palm - fingers * palm.dot(fingers)).normalized()
	# Dans Godot (export glTF), le modèle a les doigts vers -Z, la paume vers +Y et le pouce vers +X.
	basis = Basis(fingers.cross(palm), palm, -fingers).scaled(Vector3.ONE * SCALE)
	position = REST
	var scene: PackedScene = load(MODEL) if ResourceLoader.exists(MODEL) else null
	if scene != null:
		hand = scene.instantiate()
		add_child(hand)
	held = Node3D.new()
	held.name = "Tenu"
	held.position = PALM
	add_child(held)
	set_skin(skin_id)

func set_skin(skin_id: String) -> void:
	if skin_material == null:
		skin_material = StandardMaterial3D.new()
		skin_material.roughness = 0.7
	skin_material.albedo_color = CharacterPreview.tone_color(skin_id)
	if hand != null:
		for node in hand.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_override = skin_material
			(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# L'objet en main (case choisie de la barre) ; {} : main vide.
func show_item(value: Dictionary) -> void:
	for child in held.get_children():
		child.queue_free()
	visible = value.get("objet", "") != "pioche"
	if value.is_empty() or not Inventory.ITEMS.has(value.get("objet", "")):
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
				size = minf(Rocks.PEBBLE_SIZES[clampi(int(shown.get("taille", 2)), 1, 7) - 1], MAX_ITEM) if spec.forme == "caillou" else 0.05
				made.material_override = _stone(spec)
				made.scale = Vector3(size, size * (1.0 if spec.forme == "caillou" else 0.6), size)
				made.position.y = size * 0.25
			"fruit":
				made.mesh = Trees._fruit_mesh(Trees.APPLE if id == "pomme" else Trees.HAZEL, id == "pomme" and int(shown.get("couleur", 1)) == 4)
				size = minf(float(shown.get("diametre", Inventory.APPLE_SIZES[1] if id == "pomme" else 0.025)), MAX_ITEM)
				if id == "pomme" and int(shown.get("couleur", 1)) != 4:
					made.material_override = _plain(Inventory.APPLE_COLORS[clampi(int(shown.get("couleur", 1)), 0, 4)])
				made.scale = Vector3.ONE * size * 0.5
				made.position.y = size * 0.45
			# 0.0.7.8 : bâton ou tronc en travers de la paume (raccourci pour ne pas cacher le jeu).
			"bois":
				var stick := CylinderMesh.new()
				stick.top_radius = 0.42
				stick.bottom_radius = 0.5
				stick.height = 1.0
				stick.radial_segments = 8
				made.mesh = stick
				var thick := minf(float(shown.get("epaisseur", 3.0)) / 100.0, 0.05)
				made.material_override = Trees.material(clampi(int(shown.get("essence", 0)), 0, 3), "bark")
				made.scale = Vector3(thick, minf(float(shown.get("longueur", 1.0)), 0.3), thick)
				made.rotation.z = PI * 0.5
				made.position.y = thick * 0.5
	# La paume regarde vers +Y (repère de la main) : l'objet repose dessus.
	made.position = Vector3(0.0, made.position.y, 0.0)
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
		made.albedo_color = color
		made.roughness = 0.6
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
		made.albedo_color = Color(minf(color.r * 1.5, 1.0), minf(color.g * 1.5, 1.0), minf(color.b * 1.5, 1.0))
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
	position = REST
	_tween = create_tween()
	_tween.tween_property(self, "position", REST + Vector3(-0.01, -0.03, 0.02), 0.08).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", REST, 0.14).set_ease(Tween.EASE_IN_OUT)
