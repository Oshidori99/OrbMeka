extends SceneTree
# 0.0.7.21 : calcule d'avance le squelette (branches et tiges, tree_parts.gd) des 60 modèles d'arbres et l'enregistre dans
# assets/trees/squelettes/ (à relancer si un modèle d'arbre change ; sinon le jeu recalcule, empreinte différente).
# Lancer : <Godot console> --headless --path . --script res://tools/squelettes.gd
const TreeParts = preload("res://scripts/tree_parts.gd")
const Trees = preload("res://scripts/trees.gd")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TreeParts.STORED_FOLDER))
	var written := 0
	for kind in range(Trees.FILES.size()):
		for size in range(1, Trees.SIZES + 1):
			for form in range(Trees.FORMS):
				var holder := Resource.new()
				holder.set_meta("empreinte", TreeParts.fingerprint(kind, size, form))
				holder.set_meta("squelette", TreeParts.compute_skeleton(kind, size, form))
				if ResourceSaver.save(holder, TreeParts.stored_path(kind, size, form), ResourceSaver.FLAG_COMPRESS) == OK:
					written += 1
	print("SQUELETTES %d enregistrés" % written)
	quit(0 if written == Trees.FILES.size() * Trees.SIZES * Trees.FORMS else 1)
