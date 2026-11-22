extends SceneTree
# 0.0.8.14 (#247, demande de l'utilisateur) : sort du jeu les modèles et les couleurs utilisés par les images des menus
# (B + T, O + F, main et poche de l'inventaire), pour Blender : sources_blender/menus/modeles/*.glb et couleurs.json.
# Les images sont ensuite faites dans Blender par sources_blender/menus/generer_images_menus.py (mêmes formes et mêmes
# couleurs que dans le jeu). À relancer quand un de ces modèles ou une de ces couleurs change :
#   & '<Godot console>' --path . --position 20000,20000 --resolution 320x240 --script res://tools/modeles_menus.gd
const Inventory = preload("res://scripts/inventory.gd")
const Rocks = preload("res://scripts/rocks.gd")
const StoneHeads = preload("res://scripts/stone_heads.gd")
const ToolModels = preload("res://scripts/tool_models.gd")
const Trees = preload("res://scripts/trees.gd")
const CharacterPreview = preload("res://scripts/character_preview.gd")

const OUT := "res://sources_blender/menus/modeles/"

func _initialize() -> void:
	# Fenêtre hors écran : jamais la souris ni le clavier de l'utilisateur.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.gui_disable_input = true
	root.set_disable_input(true)
	process_frame.connect(func() -> void:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var made := 0
	# Seulement ce que les images utilisent. Cailloux (diamètre 1 ; tailles réelles dans couleurs.json : tailles_cailloux).
	for form in [2, 3, 4]:
		made += _export("caillou_%d" % form, Rocks.pebble_mesh(form), [_plain(Inventory.ITEMS.caillou.couleur, 0.9)])
	# Tête de hache taillée en calcaire (diamètre 1).
	made += _export("tete_hache_0", StoneHeads.mesh("hache", 1.0), [StoneHeads.material(0)])
	# Hache fabriquée (manche, tête de calcaire, lien de ficelle de lin) : le modèle du jeu, à sa taille.
	var tool := Inventory.catalog_item("hache_pierre")
	tool.pierre = 0
	made += _export("hache_ficelee_0", ToolModels.mesh(tool), [])
	made += _export("pomme", Trees._fruit_mesh(Trees.APPLE, false), [_plain(Inventory.APPLE_COLORS[1], 0.5)])
	var colors := {
		"objets": {},
		"pommes": Inventory.APPLE_COLORS.map(func(color: Color): return _rgb(color)),
		"tetes": StoneHeads.COLORS.map(func(color: Color): return _rgb(color)),
		"liens": ToolModels.BIND_COLORS.map(func(color: Color): return _rgb(color)),
		"peaux": {},
		"tailles_cailloux": Rocks.PEBBLE_SIZES,
		"tailles_tetes": {"hache": StoneHeads.scale_for("hache", 4), "pioche": StoneHeads.scale_for("pioche", 4)},
		"ecorce_eclaircie": [1.7, 1.55, 1.4],
	}
	for id in ["caillou", "caillou_calcaire", "caillou_silex", "eclat_pierre", "eclat_silex", "eclat_calcaire", "fibre_ortie", "fibre_lin", "fibre_herbe", "herbe_arrachee", "ficelle_ortie", "ficelle_lin", "ficelle_herbe", "liane", "sable", "terre"]:
		colors.objets[id] = _rgb(Inventory.ITEMS[id].couleur)
	for skin in CharacterPreview.SKINS:
		colors.peaux[skin] = _rgb(CharacterPreview.SKINS[skin].color)
	var file := FileAccess.open(OUT.path_join("couleurs.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(colors, "\t"))
	file.close()
	print("MODELES : %d modèles et couleurs.json dans %s" % [made, OUT])
	quit(0)

# Couleur sRGB (comme dans le code du jeu) : [r, g, b] de 0 à 1.
static func _rgb(color: Color) -> Array:
	return [snappedf(color.r, 0.0001), snappedf(color.g, 0.0001), snappedf(color.b, 0.0001)]

static func _plain(color: Color, roughness: float) -> StandardMaterial3D:
	var made := StandardMaterial3D.new()
	made.albedo_color = color
	made.roughness = roughness
	return made

# Un modèle, ses matières (celles données, sinon celles du modèle), en .glb.
func _export(name: String, mesh: Mesh, materials: Array) -> int:
	var copy := ArrayMesh.new()
	for surface in range(mesh.get_surface_count()):
		copy.add_surface_from_arrays(mesh.surface_get_primitive_type(surface), mesh.surface_get_arrays(surface))
		var look: Material = materials[surface] if surface < materials.size() else mesh.surface_get_material(surface)
		if look != null:
			copy.surface_set_material(surface, look)
	var holder := Node3D.new()
	holder.name = name
	var shown := MeshInstance3D.new()
	shown.name = name
	shown.mesh = copy
	holder.add_child(shown)
	root.add_child(holder)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var result := document.append_from_scene(holder, state)
	if result == OK:
		result = document.write_to_filesystem(state, ProjectSettings.globalize_path(OUT.path_join(name + ".glb")))
	holder.free()
	if result != OK:
		push_error("modèle %s : erreur %d" % [name, result])
		return 0
	return 1
