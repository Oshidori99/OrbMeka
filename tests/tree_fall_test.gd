extends SceneTree
# Arbres abattus et coupés : temps selon l'épaisseur visée (5 s par tranche de 10 cm, 40 cm au plus à mains nues,
# 0.0.7.11), anneau, chute vers le joueur, arbre couché sur le sol, gardé une fois rouvert.
# 0.0.7.12 : couper SEULEMENT la pièce visée (tree_parts.gd) : tronc couché coupé en deux (pied nu = bûche à sa taille,
# le haut écarté et tourné), une branche cassée = un bâton à sa taille (les autres restent), une seule tige de noisetier
# tombe, abattre plus haut laisse une souche ; tailles justes ; rouvert ; ramassé avec R.
const Trees = preload("res://scripts/trees.gd")
const TreeParts = preload("res://scripts/tree_parts.gd")
const Inventory = preload("res://scripts/inventory.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func frames(count: int) -> void:
	for index in range(count):
		await process_frame
		await physics_frame

func make_tree(world: Node3D, id: String, kind: int, size: int, at: Vector3) -> Node3D:
	var tree: Node3D = Trees.tree_body(kind, size)
	tree.set_meta("id", id)
	var column: Vector2i = world._player_column()
	tree.set_meta("column", column)
	world._rocks_parent().add_child(tree)
	tree.global_position = Vector3(at.x, world.terrain.height_at(at.x, at.z) - 0.05, at.z)
	world.column_objects[column] = world.column_objects.get(column, []) + [tree]
	return tree

func parts_of(world: Node3D, id: String) -> Array:
	return world.column_objects[world._player_column()].filter(func(node): return is_instance_valid(node) and not node.is_queued_for_deletion() and node.get_meta("id", "") == id)

func look(player: Node3D, point: Vector3) -> void:
	player.camera.look_at(point)
	await frames(2)

func new_wood(world: Node3D, before: int) -> Array:
	return world.ground.entries.slice(before).map(func(entry): return entry.item)

func _run() -> void:
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	world.set_game_mode(Inventory.SURVIVAL)
	var feet: Vector3 = player.global_position
	world.picked_fruits["pommier-essai"] = range(300)
	# --- A. Pommier visé près du pied : temps selon l'épaisseur, puis il tombe en entier, depuis la racine. ---
	var apple := make_tree(world, "pommier-essai", Trees.APPLE, 1, feet + Vector3(1.6, 0.0, 0.0))
	await frames(5)
	await look(player, apple.global_position + Vector3.UP * 0.3)
	var foot_aim: Dictionary = world.aimed_wood(player.get_target())
	var skeleton: Dictionary = TreeParts.skeleton(Trees.APPLE, 1, 0)
	check(not foot_aim.is_empty() and foot_aim.tree == apple and skeleton.pieces[foot_aim.piece].root, "aiming at the trunk near its foot")
	check(not world.step_chop(0.01, true) and world.chop_thickness > 0.05 and world.chop_thickness <= 0.40, "thickness measured at the aimed point (%.1f cm)" % (world.chop_thickness * 100.0))
	var expected: float = maxf(2.5 * world.chop_thickness / 0.1, 0.5)
	check(is_equal_approx(world.chop_seconds, expected), "chop time from thickness: 2.5 s per 10 cm (%.2f s)" % world.chop_seconds)
	check(world.MAX_HAND_THICKNESS == 0.40 and is_equal_approx(world.CHOP_SECONDS * 0.40 / 0.1, 10.0), "40 cm at most by hand, 10 s for 40 cm")
	check(Trees.has_leaves(Trees.APPLE, 1, 0, -1.0, 0.9) and Trees.is_bare_wood(Trees.APPLE, 1, 0, -1.0, 0.9), "a trunk with a few low leafy twigs is bare wood")
	check(not world.step_chop(world.chop_seconds * 0.5 - 0.01, true), "half way not cut yet")
	world._update_ring()
	check(world.ring.visible and absf(world.ring.progress - 0.5) < 0.01, "the ring is half full")
	check(world.step_chop(world.chop_seconds * 0.5 + 0.1, true) and apple.has_meta("falling") and parts_of(world, "pommier-essai").size() == 1, "aimed near the foot: the whole tree falls from the root")
	await frames(150)
	var up: Vector3 = apple.global_basis.y.normalized()
	var toward: Vector3 = (feet - apple.global_position) * Vector3(1, 0, 1)
	check(absf(up.y) < 0.25 and up.dot(toward.normalized()) > 0.7, "lying down, fallen toward the player")
	check(world.fallen_trees.has("pommier-essai") and world.fallen_trees["pommier-essai"].has("position"), "the fallen tree is remembered")
	var detail: MeshInstance3D = apple.get_node("Modele/Detail")
	var points: PackedVector3Array = detail.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var below := 0
	for index in range(0, points.size(), 7):
		var at: Vector3 = detail.global_transform * points[index]
		if at.y < world._ground_at(at, apple) - 0.1:
			below += 1
	check(below == 0, "branches pushed above the ground (%d points below)" % below)
	var again := make_tree(world, "pommier-essai", Trees.APPLE, 1, feet + Vector3(1.6, 0.0, 0.0))
	world._restore_fallen(again)
	check(absf(again.global_basis.y.normalized().y) < 0.25 and again.global_position.distance_to(apple.global_position) < 0.05, "restored lying at the same place")
	world.column_objects[world._player_column()].erase(again)
	again.free()
	# --- B. Tronc couché coupé sous les premières branches : le pied nu devient une bûche, le haut reste couché. ---
	world.set_game_mode(Inventory.CREATIVE)
	var trunk := 0
	for number in range(skeleton.pieces.size()):
		if skeleton.pieces[number].root and skeleton.pieces[number].length > skeleton.pieces[trunk].length:
			trunk = number
	var stem: Dictionary = skeleton.pieces[trunk]
	var scale: float = apple.scale.x
	await look(player, world._model_of(apple) * (stem.start + stem.direction * 0.6))
	var trunk_aim: Dictionary = world.aimed_wood(player.get_target())
	check(not trunk_aim.is_empty() and trunk_aim.tree == apple and trunk_aim.piece == trunk and absf(trunk_aim.t - 0.6) < 0.15, "aiming at the lying trunk (t %.2f)" % trunk_aim.get("t", -1.0))
	var pivot: Vector3 = world._model_of(apple) * (stem.start + stem.direction * float(trunk_aim.get("t", 0.6)))
	var lying_basis: Basis = apple.global_basis
	var before: int = world.ground.entries.size()
	check(world.step_chop(1.1, true), "cut (creative: 1 s)")
	await frames(30)
	var cuts: Array = world.tree_cuts.get("pommier-essai", {}).get("coupes", [])
	check(cuts.size() == 1 and int(cuts[0][0]) == trunk and absf(float(cuts[0][1]) - float(trunk_aim.get("t", 0.0))) < 0.002, "cut where aimed (%s)" % str(cuts))
	var cut_t: float = float(cuts[0][1]) if not cuts.is_empty() else 0.6
	# Le pied nu devient une bûche au sol (dessinée en série, légère), à sa vraie taille et à sa place.
	var wood: Array = new_wood(world, before)
	check(wood.size() == 1 and wood[0].objet == "tronc" and absf(wood[0].longueur - cut_t * scale) < 0.03, "the bare foot is one log at its real length (%.2f m, cut at %.2f m)" % [wood[0].longueur if not wood.is_empty() else 0.0, cut_t * scale])
	var flare: float = Trees.wood_thickness(Trees.APPLE, 1, 0, Vector3(0.0, 0.05, 0.0)) * scale
	var foot_thickness: float = Trees.wood_thickness(Trees.APPLE, 1, 0, Vector3(0.0, 0.4, 0.0)) * scale
	check(not wood.is_empty() and wood[0].epaisseur >= wood[0].fin and absf(wood[0].epaisseur / 100.0 - foot_thickness) < foot_thickness * 0.15 and wood[0].epaisseur / 100.0 < flare * 0.99, "the log has the trunk's real diameter (%.1f to %.1f cm, trunk %.1f cm, root flare %.1f cm)" % [wood[0].fin if not wood.is_empty() else 0.0, wood[0].epaisseur if not wood.is_empty() else 0.0, foot_thickness * 100.0, flare * 100.0])
	var log_spot: Vector3 = world.ground.entries[before].position if world.ground.entries.size() > before else Vector3.INF
	check(log_spot.distance_to(pivot * Vector3(1, 0, 1) + Vector3(0, log_spot.y, 0)) < cut_t * scale, "the log lies where the foot was")
	var pieces := parts_of(world, "pommier-essai")
	check(pieces.size() == 1 and int(pieces[0].get_meta("part", 0)) == 1, "the leafy top stays, lying")
	var top: Node3D = pieces[0] if not pieces.is_empty() else apple
	var cut_end: Vector3 = world._model_of(top) * (stem.start + stem.direction * cut_t)
	check(absf(cut_end.distance_to(pivot) - world.CUT_GAP) < 0.03, "a visible gap at the cut (%.2f m)" % cut_end.distance_to(pivot))
	var turn: float = top.global_basis.y.normalized().angle_to(lying_basis.y.normalized())
	check(absf(turn - world.CUT_TURN) < 0.03, "the cut piece is turned aside (%.1f°)" % rad_to_deg(turn))
	check(top.get_node("Modele").get_children().any(func(child): return child.name.begins_with("Coupe") and child.mesh.get_surface_count() > 0), "light wood face on the cut end")
	var span: Array = TreeParts.main_span(Trees.APPLE, 1, 0, cuts, 1)
	check(span.size() == 3 and int(span[0]) == trunk and absf(float(span[1]) - cut_t) < 0.002 and absf(float(span[2]) - stem.length) < 0.01, "the top goes from the cut to the treetop: log + top = the whole trunk")
	# --- C. Une branche du haut cassée : seulement elle, un bâton à sa taille ; les autres restent. ---
	var branch := -1
	var sibling := -1
	for number in range(skeleton.pieces.size()):
		var piece: Dictionary = skeleton.pieces[number]
		if piece.parent == trunk and piece.attach > cut_t + 0.1 and piece.length > 0.5:
			if branch < 0:
				branch = number
			elif sibling < 0:
				sibling = number
	var bough: Dictionary = skeleton.pieces[branch]
	var share_before := TreeParts.leaf_share(Trees.APPLE, 1, 0, cuts, 1)
	await look(player, world._model_of(top) * (bough.start + bough.direction * bough.length * 0.5))
	var branch_aim: Dictionary = world.aimed_wood(player.get_target())
	# (Une autre branche peut être devant : c'est elle qu'on vise alors.)
	check(not branch_aim.is_empty() and branch_aim.tree == top and not skeleton.pieces[branch_aim.piece].root, "aiming at one branch")
	if not branch_aim.is_empty():
		branch = branch_aim.piece
		bough = skeleton.pieces[branch]
	before = world.ground.entries.size()
	check(world.step_chop(1.1, true), "the branch is broken")
	await frames(30)
	cuts = world.tree_cuts["pommier-essai"].coupes
	var stick: Array = new_wood(world, before)
	var broken_t: float = float(cuts[-1][1])
	check(cuts.size() == 2 and int(cuts[-1][0]) == branch and stick.size() == 1 and absf(stick[0].longueur - (bough.length - broken_t) * scale) < 0.03, "it is one stick at its real length (%.2f m)" % (stick[0].longueur if not stick.is_empty() else 0.0))
	var share_after := TreeParts.leaf_share(Trees.APPLE, 1, 0, cuts, 1)
	check(share_after < share_before and share_after > share_before * 0.5, "only this branch's leaves are gone (%.0f%% then %.0f%%)" % [share_before * 100.0, share_after * 100.0])
	check(sibling < 0 or TreeParts.assignment(Trees.APPLE, 1, 0, cuts).ranges[1].has(sibling), "the other branches stay")
	check(parts_of(world, "pommier-essai").size() == 1, "no new lying piece for a branch")
	# 0.0.7.12 : avec ses feuilles : un rameau, nommé selon son arbre (un seul petit feuillage pour tous).
	check(not stick.is_empty() and stick[0].objet == "rameau" and Inventory.item_name(stick[0]) == "Rameau de pommier" and Inventory.item_name({"objet": "rameau", "essence": Trees.HAZEL}) == "Tige de noisetier", "a leafy branch is a twig named after its tree")
	check(world.ground.get_children().any(func(child): return child is MultiMeshInstance3D and child.multimesh.mesh == world.ground.leaf_tuft()), "its leaves are drawn on the ground")
	# --- D. Noisetier : une tige coupée à 1 m : seulement elle tombe, les autres restent debout. ---
	var hazel := make_tree(world, "noisetier-essai", Trees.HAZEL, 1, feet + Vector3(0.0, 0.0, 1.9))
	world.picked_fruits["noisetier-essai"] = range(300)
	await frames(5)
	var bush: Dictionary = TreeParts.skeleton(Trees.HAZEL, 1, 0)
	var stems: Array = []
	for number in range(bush.pieces.size()):
		if bush.pieces[number].root and bush.pieces[number].tip.y > 0.5:
			stems.append(number)
	check(stems.size() >= 3, "the hazel has several stems (%d)" % stems.size())
	# La tige la plus proche du joueur, visée à 1 m de son pied.
	stems.sort_custom(func(a, b): return (world._model_of(hazel) * bush.pieces[a].tip).distance_to(feet) < (world._model_of(hazel) * bush.pieces[b].tip).distance_to(feet))
	var cane: Dictionary = bush.pieces[stems[0]]
	await look(player, world._model_of(hazel) * (cane.start + cane.direction * 1.0))
	var cane_aim: Dictionary = world.aimed_wood(player.get_target())
	check(not cane_aim.is_empty() and cane_aim.tree == hazel and bush.pieces[cane_aim.piece].root, "aiming at one hazel stem")
	var aimed_stem: int = cane_aim.get("piece", stems[0])
	check(world.step_chop(1.1, true) and not hazel.has_meta("falling") and not world.fallen_trees.has("noisetier-essai"), "the bush stays standing")
	var falling := parts_of(world, "noisetier-essai").filter(func(node): return node.has_meta("falling"))
	check(falling.size() == 1, "only the cut stem falls")
	await frames(150)
	var hazel_cuts: Array = world.tree_cuts["noisetier-essai"].coupes
	var others := stems.filter(func(number): return number != aimed_stem)
	check(others.all(func(number): return TreeParts.assignment(Trees.HAZEL, 1, 0, hazel_cuts).ranges[0].has(number) and absf(TreeParts.assignment(Trees.HAZEL, 1, 0, hazel_cuts).ranges[0][number].y - bush.pieces[number].length) < 0.2), "the other stems stay whole")
	var state: String = world.tree_cuts["noisetier-essai"].morceaux.get("1", {}).get("etat", "")
	check(state in ["couche", "bois"], "the stem has fallen and lies (%s)" % state)
	var cane_span: Array = TreeParts.main_span(Trees.HAZEL, 1, 0, hazel_cuts, 1)
	check(cane_span.size() == 3 and int(cane_span[0]) == aimed_stem and absf(float(cane_span[1]) - float(hazel_cuts[0][1])) < 0.002, "the fallen stem starts at the cut")
	if state == "couche":
		var lying_cane: Array = parts_of(world, "noisetier-essai").filter(func(node): return int(node.get_meta("part", 0)) == 1)
		check(lying_cane.size() == 1 and absf(lying_cane[0].global_basis.y.normalized().y) < 0.5, "the stem lies on the ground")
	# Rouvert : la tige couchée revient à sa place.
	var saved_cane: Dictionary = world.tree_cuts["noisetier-essai"].morceaux.get("1", {})
	var reopened := make_tree(world, "noisetier-essai", Trees.HAZEL, 1, feet + Vector3(0.0, 0.0, 1.9))
	var count_before: int = parts_of(world, "noisetier-essai").size()
	world._restore_fallen(reopened)
	world._restore_parts(reopened)
	var count_after: int = parts_of(world, "noisetier-essai").size()
	check(count_after == count_before + (1 if saved_cane.get("etat", "") == "couche" else 0), "reopened: the bush and its lying stem come back")
	for node in parts_of(world, "noisetier-essai"):
		if node != hazel and (node == reopened or (int(node.get_meta("part", 0)) == 1 and count_after > count_before and node == parts_of(world, "noisetier-essai")[-1])):
			world.column_objects[world._player_column()].erase(node)
			node.free()
	# --- E. Pommier debout coupé à 65 cm (sous ses branches) : une souche reste, le haut tombe depuis la coupe. ---
	world.picked_fruits["pommier-haut"] = range(300)
	# Le haut couché du premier pommier (entre le joueur et ce nouvel arbre) retiré de l'essai.
	for node in parts_of(world, "pommier-essai"):
		world.column_objects[world._player_column()].erase(node)
		node.free()
	var tall := make_tree(world, "pommier-haut", Trees.APPLE, 1, feet + Vector3(0.0, 0.0, -1.9))
	await frames(5)
	var high_point: Vector3 = world._model_of(tall) * (stem.start + stem.direction * 0.65)
	await look(player, high_point)
	var high_aim: Dictionary = world.aimed_wood(player.get_target())
	check(not high_aim.is_empty() and high_aim.tree == tall and high_aim.piece == trunk, "aiming at the trunk at 65 cm (%s, %s)" % [str(high_aim.get("tree")), str(high_aim.get("piece"))])
	world.step_chop(1.1, true)
	check(not tall.has_meta("falling") and not world.fallen_trees.has("pommier-haut") and parts_of(world, "pommier-haut").size() == 2, "a stump stays, the top falls")
	var stump_height := 0.0
	for child in tall.get_children():
		if child is CollisionShape3D:
			stump_height = child.shape.height
	var high_t: float = float(world.tree_cuts["pommier-haut"].coupes[0][1])
	check(absf(stump_height - (stem.start + stem.direction * high_t).y) < 0.1, "the stump is as high as the cut (%.2f m)" % stump_height)
	await frames(150)
	# --- F. Ramasser le bâton (R). ---
	world.inventory.select(5)
	var index: int = world.ground.entries.size() - 1
	for at in range(world.ground.entries.size()):
		if world.ground.entries[at].item.get("objet") == "branche" or world.ground.entries[at].item.get("objet") == "tronc":
			index = at
	await look(player, world.ground.entries[index].position)
	world.pick_up({"collider": world.ground.bodies[index], "position": world.ground.entries[index].position})
	check(world.inventory.item("bar", 5).get("objet") in ["tronc", "branche"], "R picks up the piece of wood")
	# --- F2. 0.0.7.14 : recasser le bois au sol là où on vise ; jamais de trou en le visant. ---
	# Les morceaux tombés (leurs branches passeraient au-dessus du bâton) retirés de l'essai.
	for id in ["pommier-haut", "noisetier-essai", "pommier-essai"]:
		for node in parts_of(world, id):
			world.column_objects[world._player_column()].erase(node)
			node.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 14
	var rod := Inventory.wood_piece("rameau", Trees.HAZEL, 3.0, 1.0, rng)
	rod.epaisseur = 4.0
	rod.fin = 2.0
	rod.rotation = 0.0
	var rod_spot: Vector3 = feet + Vector3(1.0, 0.0, -1.0)
	var ground_before: int = world.ground.entries.size()
	world.ground.drop(rod, rod_spot, rod_spot, world._ground_at, 0.0)
	await frames(3)
	var rod_index: int = world.ground.entries.size() - 1
	var rod_entry: Dictionary = world.ground.entries[rod_index]
	# Visé à 30 cm du gros bout (l'axe va du gros bout vers le petit, le long de +z pour une rotation 0).
	var rod_point: Vector3 = (rod_entry.position as Vector3) + Vector3(0.0, 0.0, -0.2)
	await look(player, rod_point)
	var rod_hit: Dictionary = player.get_target()
	check(not rod_hit.is_empty() and rod_hit.collider == world.ground.bodies[rod_index], "aiming at the stick on the ground")
	check(not world.break_target(rod_hit), "aiming at wood on the ground never digs")
	var whole_weight: float = float(rod_entry.item.poids)
	var rod_share: float = world._wood_share(rod_entry, rod_hit.get("position", rod_point))
	world.set_game_mode(Inventory.CREATIVE)
	check(world._step_chop_parts(1.1, rod_hit), "the stick on the ground is cut in two")
	var halves: Array = world.ground.entries.slice(ground_before).map(func(entry): return entry.item)
	halves.sort_custom(func(a, b): return a.epaisseur > b.epaisseur)
	# Coupé au point touché (le dessus du bâton, à quelques centimètres du point visé).
	check(absf(rod_share - 0.3) < 0.1, "cut near the aimed point (%.2f of the stick)" % rod_share)
	check(halves.size() == 2 and absf(halves[0].longueur - rod_share) < 0.015 and absf(halves[1].longueur - (1.0 - rod_share)) < 0.015, "each half has its real length (%s)" % str(halves.map(func(h): return h.longueur)))
	check(halves.size() == 2 and halves[0].epaisseur == 4.0 and absf(halves[0].fin - halves[1].epaisseur) < 0.01 and halves[1].fin == 2.0 and absf(halves[0].fin - lerpf(4.0, 2.0, rod_share)) < 0.06, "thicknesses follow along the stick (%s)" % str(halves.map(func(h): return [h.epaisseur, h.fin])))
	check(halves.size() == 2 and halves[0].objet in ["tronc", "branche"] and halves[1].objet == "rameau", "the leaves stay on the thin half")
	check(halves.size() == 2 and absf(halves[0].poids + halves[1].poids - whole_weight) <= 2.0, "the weights add up (%s g)" % str(halves.map(func(h): return h.poids)))
	# Un tronc au sol se recasse aussi.
	var log_piece := Inventory.wood_piece("tronc", Trees.APPLE, 15.0, 1.2, rng)
	log_piece.rotation = 0.0
	world.ground.drop(log_piece, rod_spot + Vector3(1.0, 0.0, 0.0), rod_spot + Vector3(1.0, 0.0, 0.0), world._ground_at, 0.0)
	await frames(3)
	var log_index: int = world.ground.entries.size() - 1
	await look(player, world.ground.entries[log_index].position)
	var log_hit: Dictionary = player.get_target()
	var before_log: int = world.ground.entries.size()
	check(world._step_chop_parts(1.1, log_hit) and world.ground.entries.size() == before_log + 1, "a log on the ground is cut in two too")
	# --- G. Trop épais à mains nues en Survie (plus de 40 cm) : impossible. ---
	world.set_game_mode(Inventory.SURVIVAL)
	# Les morceaux tombés (posés sur leurs branches, entre le joueur et ce tilleul) retirés de l'essai.
	for id in ["pommier-haut", "noisetier-essai"]:
		for node in parts_of(world, id):
			world.column_objects[world._player_column()].erase(node)
			node.free()
	var big := make_tree(world, "tilleul-essai", Trees.LINDEN, 5, feet + Vector3(-3.0, 0.0, 0.0))
	await frames(3)
	await look(player, big.global_position + Vector3.UP * 0.6)
	check(not world.step_chop(30.0, true) and world.chop_thickness > 0.40 and not big.has_meta("falling") and parts_of(world, "tilleul-essai").size() == 1, "a trunk thicker than 40 cm cannot be cut by hand (%.0f cm)" % (world.chop_thickness * 100.0))
	root.remove_child(world)
	world.queue_free()
	await process_frame
	print("RESULT: %d tree fall checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
