extends SceneTree
# 0.0.8.53 (lot C1, demandes de l'utilisateur) : modèles faits dans Blender (sources_blender/feu/generer_feu.py) et images
# de la fabrication :
# - feu de camp éteint et allumé : le modèle Blender (pierres, bûches, cendre ; allumé : braises et flammes du jeu) ;
# - torche, torche forte : un bâton à l'écorce de son essence et la tête de son modèle ; archet : son modèle, sa branche à
#   l'écorce de son essence ; les autres bois : pas de modèle à part ;
# - chaque action de la fabrication a son image (plus d'image empruntée à une autre).
const Fire = preload("res://scripts/fire.gd")
const Trees = preload("res://scripts/trees.gd")
const CraftingUI = preload("res://scripts/crafting_ui.gd")
const CraftingIcons = preload("res://scripts/crafting_icons.gd")
const MenuImages = preload("res://scripts/menu_images.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in Fire.CAMPFIRE_MODELS.values() + Fire.TORCH_HEADS.values() + [Fire.BOW_MODEL]:
		check(ResourceLoader.exists(path) and Fire._model_mesh(path) != null, "model %s found" % path)
	var unlit := Fire.campfire_mesh(false)
	var lit := Fire.campfire_mesh(true)
	check(unlit.get_surface_count() >= 4 and lit.get_surface_count() == Fire._model_mesh(Fire.CAMPFIRE_MODELS[true]).get_surface_count() + 1, "campfire: the Blender model (stones, logs, ash) ; lit: embers, plus the game's flames (%d, %d surfaces)" % [unlit.get_surface_count(), lit.get_surface_count()])
	var torch := Fire.wood_model({"objet": "torche", "essence": 2})
	check(torch != null and torch.get_surface_count() >= 3 and torch.surface_get_material(0) == Trees.material(2, "bark"), "torch: a stick with its tree's bark, and its head (fibres, ties)")
	var strong := Fire.wood_model({"objet": "torche_forte", "essence": 1})
	check(strong != null and strong.get_surface_count() > torch.get_surface_count() - 1 and strong != torch, "strong torch: its own head (pine bark, resin, ties)")
	var bow := Fire.wood_model({"objet": "archet", "essence": 3})
	var bark_found := false
	for surface in range(bow.get_surface_count() if bow != null else 0):
		bark_found = bark_found or bow.surface_get_material(surface) == Trees.material(3, "bark")
	check(bow != null and bow.get_surface_count() == 2 and bark_found, "fire bow: its model, its branch with its tree's bark, its cord")
	check(Fire.wood_model({"objet": "branche", "essence": 1}) == null and Fire.wood_model({"objet": "tronc"}) == null, "other wood: no model of its own (a stick)")
	var missing := []
	for action in CraftingUI.ROLES:
		if not ResourceLoader.exists(MenuImages.path_of(action)):
			missing.append(action)
	check(missing.is_empty() and CraftingIcons.STAND_IN.is_empty(), "every crafting action has its own picture (missing: %s)" % str(missing))
	print("RESULT: %d model checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
