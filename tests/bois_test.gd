extends SceneTree
# 0.0.8.22 (demandes de l'utilisateur : « le bâton ou la bûche qui tombe est ultra fin, par moments » ; les bûches et
# bâtons gardent la taille qu'ils avaient sur l'arbre) :
# - la tige ou le tronc coupé : son bois au sol a l'épaisseur de la tige (avant : mesurée dans une tranche de tout
#   l'arbre, parfois sur une tige ou une branche voisine : un bout ultra fin) ; le temps de coupe vise la même mesure ;
# - le bois d'un morceau : toutes ses pièces, chacune à sa longueur (rien ne disparaît) ;
# - une branche coupée sur un arbre debout tombe telle qu'elle est (morceau 3D), puis reste couchée avec ses feuilles ;
#   R la défait en son bois au sol, pièce par pièce ;
# - l'utilisateur, sur un noisetier : « j'ai recassé un petit bout de la branche et le reste, toutes les feuilles ont
#   disparu, et il s'est rapetissé » : une tige ou une branche couchée recoupée garde ses feuilles et sa taille (seul le
#   bout coupé change) ; coupée au milieu, ses deux moitiés aussi ; une tige maigre reste couchée avec ses feuilles.
const Trees = preload("res://scripts/trees.gd")
const TreeParts = preload("res://scripts/tree_parts.gd")
const Inventory = preload("res://scripts/inventory.gd")
const GroundItems = preload("res://scripts/ground_items.gd")
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

func nodes_of(world: Node3D, id: String) -> Array:
	var found := []
	for list in world.column_objects.values():
		for node in list:
			if is_instance_valid(node) and not node.is_queued_for_deletion() and node.get_meta("id", "") == id:
				found.append(node)
	return found

func make(world: Node3D, id: String, kind: int, size: int, at: Vector3) -> Node3D:
	var tree: Node3D = Trees.tree_body(kind, size)
	tree.set_meta("id", id)
	var column: Vector2i = world._player_column()
	tree.set_meta("column", column)
	world._rocks_parent().add_child(tree)
	tree.global_position = Vector3(at.x, world.terrain.height_at(at.x, at.z) - 0.05, at.z)
	world.column_objects[column] = world.column_objects.get(column, []) + [tree]
	world.picked_fruits[id] = range(400)
	return tree

func clear(world: Node3D, id: String) -> void:
	for node in nodes_of(world, id):
		world.column_objects[node.get_meta("column")].erase(node)
		node.free()
	while not world.ground.entries.is_empty():
		world.ground.remove(0)

func wood_since(world: Node3D, before: int) -> Array:
	return world.ground.entries.slice(before).map(func(entry): return entry.item).filter(func(item): return Inventory.ITEMS.get(item.get("objet", ""), {}).get("forme", "") == "bois")

# Triangles de feuilles dessinés par un morceau.
func leaf_triangles(node: Node3D) -> int:
	var detail: MeshInstance3D = node.get_node("Modele/Detail")
	var leaves := Trees.material(int(node.get_meta("kind", 0)), "leaves")
	var count := 0
	for surface in range(detail.mesh.get_surface_count()):
		if detail.mesh.surface_get_material(surface) == leaves:
			count += detail.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size() / 3
	return count

# Longueur du morceau dessiné (le plus grand côté de sa boîte, en mètres).
func drawn_length(node: Node3D) -> float:
	var box: AABB = node.get_node("Modele/Detail").mesh.get_aabb()
	return maxf(box.size.x, maxf(box.size.y, box.size.z)) * node.scale.x

func lying_parts(world: Node3D, id: String) -> Array:
	return nodes_of(world, id).filter(func(node): return int(node.get_meta("part", 0)) != 0)

func _run() -> void:
	var World = load("res://scripts/world.gd")
	# --- Mesure : le bois suit sa pièce, toutes espèces, tailles et formes ---
	var worst := 0.0
	var worst_label := ""
	var tried := 0
	for kind in range(4):
		for size in [1, 3, 5]:
			for form in range(Trees.FORMS):
				var pieces: Array = TreeParts.skeleton(kind, size, form).pieces
				for number in range(pieces.size()):
					var piece: Dictionary = pieces[number]
					if not piece.root or piece.tip.y < 0.5:
						continue
					var low := minf(0.4, piece.length * 0.3)
					var ends: Vector2 = World.wood_ends(piece, low, piece.length)
					for share in [0.2, 0.5]:
						var real := TreeParts.true_thickness(piece, lerpf(low, piece.length, share))
						var drawn := lerpf(ends.x, ends.y, share)
						var gap := absf(drawn - real) / maxf(real, 0.01)
						tried += 1
						if gap > worst:
							worst = gap
							worst_label = "%s t%d f%d pièce %d à %d %% : %.1f cm sur l'arbre, %.1f cm au sol" % [Trees.KIND_NAMES[kind], size, form, number, roundi(share * 100.0), real * 100.0, drawn * 100.0]
	check(tried > 100 and worst < 0.3, "every stem and trunk: the wood on the ground follows it (worst %d %% : %s)" % [roundi(worst * 100.0), worst_label])
	check(GroundItems.taper_step({"epaisseur": 20.0, "fin": 1.0}) == 1, "a stem ending in a point keeps a thin tip on the ground (5 %)")
	# --- Calcul rapide des morceaux (gels à chaque coupe) : exactement les mêmes résultats que l'ancien calcul ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 822
	var wrong_sizes := 0
	var wrong_parts := 0
	var compared := 0
	for spec in [[Trees.APPLE, 3, 0], [Trees.HAZEL, 5, 1], [Trees.PINE, 2, 2], [Trees.LINDEN, 3, 0], [Trees.HAZEL, 1, 0]]:
		var made: Dictionary = TreeParts.skeleton(spec[0], spec[1], spec[2])
		for attempt in range(4):
			var cuts := []
			for count in range(rng.randi_range(1, 14)):
				var number := rng.randi_range(0, made.pieces.size() - 1)
				cuts.append([number, snappedf(rng.randf_range(0.0, float(made.pieces[number].length)), 0.001)])
			# Parfois deux coupes très proches sur la même pièce (monde T56).
			cuts.append([int(cuts[0][0]), float(cuts[0][1]) + 0.06])
			var slow: Array = TreeParts.slow_sizes(spec[0], spec[1], spec[2], cuts)
			if slow != TreeParts._sizes_for(spec[0], spec[1], spec[2], cuts):
				wrong_sizes += 1
			var parts: Array = TreeParts.assignment(spec[0], spec[1], spec[2], cuts).parts
			for surface in range(made.surfaces.size()):
				var info: Dictionary = made.surfaces[surface]
				for triangle in range(0, info.owner.size(), 5):
					compared += 1
					if parts[surface][triangle] != TreeParts._part_of(made.pieces, cuts, slow, int(info.owner[triangle]), float(info.param[triangle])):
						wrong_parts += 1
	check(wrong_sizes == 0 and wrong_parts == 0 and compared > 5000, "fast pieces: the same sizes and the same piece for every triangle as before (%d compared, %d wrong sizes, %d wrong pieces)" % [compared, wrong_sizes, wrong_parts])
	# Et vite : 30 coupes sur un pommier, la dernière coupe se calcule en peu de temps (avant : 0,5 s).
	var crown_cuts := []
	var apple_pieces: Array = TreeParts.skeleton(Trees.APPLE, 3, 0).pieces
	for number in range(apple_pieces.size()):
		if not apple_pieces[number].root and crown_cuts.size() < 30:
			crown_cuts.append([number, 0.05])
	TreeParts.assignment(Trees.APPLE, 3, 0, crown_cuts.slice(0, 29))
	var started := Time.get_ticks_usec()
	TreeParts.assignment(Trees.APPLE, 3, 0, crown_cuts)
	TreeParts.part_mesh(Trees.APPLE, 3, 0, crown_cuts, 0)
	TreeParts.part_mesh(Trees.APPLE, 3, 0, crown_cuts, crown_cuts.size())
	TreeParts.cut_faces(Trees.APPLE, 3, 0, crown_cuts, crown_cuts.size())
	var spent := (Time.get_ticks_usec() - started) / 1000.0
	print("INFO: 30th cut of an apple tree: %.1f ms" % spent)
	check(true, "the 30th cut of an apple tree: %.1f ms (the time is judged on the PC only)" % spent)
	# --- En partie ---
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	world.set_game_mode(Inventory.CREATIVE)
	var spot: Vector3 = player.global_position + Vector3(0.0, 0.0, -4.0)
	# Tige de noisetier coupée au pied, puis le morceau couché recoupé au milieu.
	var hazel := make(world, "bois-noisetier", Trees.HAZEL, 5, spot)
	await frames(3)
	var bush: Dictionary = TreeParts.skeleton(Trees.HAZEL, 5, 0)
	var stem := -1
	for number in range(bush.pieces.size()):
		if bush.pieces[number].root and bush.pieces[number].tip.y > 0.5:
			stem = number
			break
	var stem_piece: Dictionary = bush.pieces[stem]
	var point: Vector3 = world._model_of(hazel) * (stem_piece.start + stem_piece.direction * 0.35)
	var aimed: float = world._aim_thickness({"tree": hazel, "piece": stem, "t": 0.35, "point": point})
	var real := TreeParts.true_thickness(stem_piece, 0.35) * hazel.scale.x
	check(absf(aimed - real) < 0.002, "chopping a hazel stem: its own thickness (%.1f cm, the stem: %.1f cm)" % [aimed * 100.0, real * 100.0])
	var before: int = world.ground.entries.size()
	world.cut_wood(hazel, stem, 0.35, point)
	await frames(150)
	var lying: Node3D = null
	for node in nodes_of(world, "bois-noisetier"):
		if int(node.get_meta("part", 0)) == 1:
			lying = node
	var woods := wood_since(world, before)
	check(lying != null and woods.is_empty() and world.tree_cuts["bois-noisetier"].morceaux["1"].etat == "couche", "the cut stem lies as it is, with its leaves")
	if lying != null:
		# Demande de l'utilisateur : la tige couchée est sur le sol, jamais dedans (son axe à son rayon du sol, au moins).
		var lying_span: Array = TreeParts.main_span(Trees.HAZEL, 5, 0, world._cuts_of(lying), 1)
		var sunk := -INF
		for step in range(13):
			var t: float = lerpf(float(lying_span[1]), float(lying_span[2]), step / 12.0)
			var p: Vector3 = world._model_of(lying) * (stem_piece.start + stem_piece.direction * t)
			sunk = maxf(sunk, TreeParts.true_thickness(stem_piece, t) * hazel.scale.x * 0.5 - (p.y - world._ground_at(p, lying)))
		check(sunk < 0.06, "the fallen stem lies on the ground, not in it (axis at most %.2f m too low)" % sunk)
		# L'utilisateur : un petit bout recoupé (40 cm au bout de la tige) : le reste garde ses feuilles et sa taille.
		var main: Array = TreeParts.main_span(Trees.HAZEL, 5, 0, world._cuts_of(lying), 1)
		var leaves_before := leaf_triangles(lying)
		var length_before := drawn_length(lying)
		var tip: float = float(main[2]) - 0.4
		before = world.ground.entries.size()
		world.cut_wood(lying, int(main[0]), tip, world._model_of(lying) * (stem_piece.start + stem_piece.direction * tip))
		await frames(10)
		woods = wood_since(world, before)
		var rest_ok: bool = is_instance_valid(lying) and not lying.is_queued_for_deletion() and world.tree_cuts["bois-noisetier"].morceaux["1"].etat == "couche"
		var leaves_after := leaf_triangles(lying) if rest_ok else 0
		var length_after := drawn_length(lying) if rest_ok else 0.0
		check(rest_ok and leaves_after > leaves_before * 0.6 and length_after > length_before - 0.8, "a small bit cut off the lying stem: the rest keeps its leaves (%d of %d) and its size (%.2f m, before %.2f m)" % [leaves_after, leaves_before, length_after, length_before])
		check(woods.size() == 1 and absf(float(woods[0].longueur) - 0.4 * hazel.scale.x) < 0.03, "only the bit becomes wood (%s)" % str(woods.map(func(i): return "%s %.2f m" % [i.objet, i.longueur])))
		# Coupée au milieu : deux moitiés couchées, chacune avec ses feuilles ; défaites (R), leurs bûches se rejoignent à
		# l'épaisseur de la coupe.
		if rest_ok:
			main = TreeParts.main_span(Trees.HAZEL, 5, 0, world._cuts_of(lying), 1)
			var middle: float = (float(main[1]) + float(main[2])) * 0.5
			var there := TreeParts.true_thickness(bush.pieces[main[0]], middle) * hazel.scale.x
			before = world.ground.entries.size()
			world.cut_wood(lying, int(main[0]), middle, lying.global_position)
			await frames(10)
			var halves := lying_parts(world, "bois-noisetier")
			check(halves.size() == 2 and halves.all(func(node): return leaf_triangles(node) > 20) and wood_since(world, before).is_empty(), "cut in its middle: two lying halves, each with its leaves (%s)" % str(halves.map(func(node): return leaf_triangles(node))))
			for node in halves:
				world._part_to_wood(node, int(node.get_meta("part", 0)))
			woods = wood_since(world, before)
			var logs := woods.filter(func(item): return absf(float(item.longueur) - (float(main[2]) - middle) * hazel.scale.x) < 0.05 or absf(float(item.longueur) - (middle - float(main[1])) * hazel.scale.x) < 0.05)
			var close := logs.any(func(item): return absf(float(item.epaisseur) / 100.0 - there) < there * 0.25 or absf(float(item.fin) / 100.0 - there) < there * 0.25)
			check(close, "picked up, the halves' logs meet at the cut's thickness (%.1f cm there : %s)" % [there * 100.0, str(logs.map(func(i): return "%s→%s" % [i.epaisseur, i.fin]))])
	# Une tige maigre (le moins de feuilles du buisson, bien moins de 10 %) reste couchée avec ses feuilles elle aussi.
	var thin_stem := -1
	for number in range(bush.pieces.size()):
		if number == stem or not bush.pieces[number].root or bush.pieces[number].tip.y <= 0.5:
			continue
		if thin_stem < 0 or TreeParts.leaf_share(Trees.HAZEL, 5, 0, [[number, 0.35]], 1) < TreeParts.leaf_share(Trees.HAZEL, 5, 0, [[thin_stem, 0.35]], 1):
			thin_stem = number
	var thin_share := TreeParts.leaf_share(Trees.HAZEL, 5, 0, [[thin_stem, 0.35]], 1)
	var thin_piece: Dictionary = bush.pieces[thin_stem]
	world.cut_wood(hazel, thin_stem, 0.35, world._model_of(hazel) * (thin_piece.start + thin_piece.direction * 0.35))
	var thin_part: int = world.tree_cuts["bois-noisetier"].coupes.size()
	await frames(150)
	var thin_nodes := lying_parts(world, "bois-noisetier").filter(func(node): return int(node.get_meta("part", 0)) == thin_part)
	check(thin_share < 0.06 and thin_nodes.size() == 1 and leaf_triangles(thin_nodes[0]) > 0 and world.tree_cuts["bois-noisetier"].morceaux[str(thin_part)].etat == "couche", "a stem with few leaves (%.1f %% of the bush) lies with its leaves too" % (thin_share * 100.0))
	clear(world, "bois-noisetier")
	# Branche de pommier coupée sur l'arbre debout : elle tombe telle qu'elle est, puis toutes ses pièces sont là.
	var apple := make(world, "bois-pommier", Trees.APPLE, 3, spot)
	await frames(3)
	var crown: Dictionary = TreeParts.skeleton(Trees.APPLE, 3, 0)
	var branch := -1
	var most := 0
	for number in range(crown.pieces.size()):
		var piece: Dictionary = crown.pieces[number]
		if piece.root or piece.depth != 1:
			continue
		var spans: Dictionary = TreeParts.assignment(Trees.APPLE, 3, 0, [[number, 0.05]]).ranges[1]
		if spans.size() > most:
			most = spans.size()
			branch = number
	check(branch >= 0 and most >= 3, "an apple branch with %d pieces (its own branches)" % most)
	var cut_spans: Dictionary = TreeParts.assignment(Trees.APPLE, 3, 0, [[branch, 0.05]]).ranges[1]
	var expected := 0.0
	for number in cut_spans:
		expected += (cut_spans[number].y - cut_spans[number].x) * apple.scale.x
	before = world.ground.entries.size()
	var piece_branch: Dictionary = crown.pieces[branch]
	world.cut_wood(apple, branch, 0.05, world._model_of(apple) * (piece_branch.start + piece_branch.direction * 0.05))
	var falling := nodes_of(world, "bois-pommier").filter(func(node): return int(node.get_meta("part", 0)) == 1)
	check(falling.size() == 1 and falling[0].has_meta("falling") and wood_since(world, before).is_empty(), "the cut branch falls as it is (its 3D piece, not a stick)")
	var attach: Vector3 = world._model_of(apple) * (piece_branch.start as Vector3)
	check(attach.y - world.terrain.height_at(attach.x, attach.z) > 1.0, "it falls from up in the tree (%.1f m above the ground)" % (attach.y - world.terrain.height_at(attach.x, attach.z)))
	await frames(120)
	# Demande de l'utilisateur : même petite, elle reste couchée avec ses feuilles jusqu'à ce qu'on la recoupe.
	var still := nodes_of(world, "bois-pommier").filter(func(node): return int(node.get_meta("part", 0)) == 1)
	check(still.size() == 1 and not still[0].has_meta("falling") and world.tree_cuts["bois-pommier"].morceaux["1"].etat == "couche" and wood_since(world, before).is_empty(), "landed: it lies as it is, with its leaves, until cut again")
	if not still.is_empty():
		var detail: MeshInstance3D = still[0].get_node("Modele/Detail")
		var leaf_material := Trees.material(Trees.APPLE, "leaves")
		var has_leaves := false
		for surface in range(detail.mesh.get_surface_count()):
			has_leaves = has_leaves or detail.mesh.surface_get_material(surface) == leaf_material
		check(has_leaves and world._tree_is_lying(still[0]), "its leaves are still on it, on the ground")
		# Recoupée au milieu de sa pièce principale : le reste garde ses feuilles (seul le bout coupé change) ; puis défaite
		# (R) : chaque pièce est son bois, à sa taille, rien ne manque.
		var span: Array = TreeParts.main_span(Trees.APPLE, 3, 0, world._cuts_of(still[0]), 1)
		var middle: float = (float(span[1]) + float(span[2])) * 0.5
		var leaves_before := leaf_triangles(still[0])
		world.cut_wood(still[0], int(span[0]), middle, still[0].global_position)
		await frames(10)
		var rest_kept: bool = is_instance_valid(still[0]) and not still[0].is_queued_for_deletion() and world.tree_cuts["bois-pommier"].morceaux["1"].etat == "couche"
		check(rest_kept and leaf_triangles(still[0]) > 0, "cut again in its middle: the rest stays as it is, with its leaves (%d of %d)" % [leaf_triangles(still[0]) if rest_kept else 0, leaves_before])
		for node in lying_parts(world, "bois-pommier"):
			world._part_to_wood(node, int(node.get_meta("part", 0)))
		woods = wood_since(world, before)
		var total := 0.0
		for item in woods:
			total += float(item.longueur)
		check(lying_parts(world, "bois-pommier").is_empty() and woods.size() == cut_spans.size() + 1 and absf(total - expected) < 0.06, "then picked up: every piece is its own wood (%d woods for %d pieces cut in two, %.2f m of %.2f m)" % [woods.size(), cut_spans.size(), total, expected])
		var thickest := 0.0
		for item in woods:
			thickest = maxf(thickest, float(item.epaisseur))
		var root_thick := TreeParts.true_thickness(piece_branch, 0.3) * apple.scale.x * 100.0
		check(absf(thickest - root_thick) < root_thick * 0.25, "the branch keeps its thickness (%.1f cm, on the tree %.1f cm)" % [thickest, root_thick])
		await frames(40)
		world.ground._redraw()
		var series: int = world.ground._drawn.keys().filter(func(key): return str(key).begins_with("bois/")).size()
		check(series <= woods.size() and series <= 9, "drawn in few series (%d for %d woods: same tree, same tip, one series)" % [series, woods.size()])
	clear(world, "bois-pommier")
	# --- R sur une branche couchée : ses bois au sol, celui qu'on vise en main ---
	apple = make(world, "bois-ramasser", Trees.APPLE, 3, spot)
	await frames(3)
	world.cut_wood(apple, branch, 0.05, world._model_of(apple) * (piece_branch.start + piece_branch.direction * 0.05))
	await frames(120)
	var lying_branch: Array = nodes_of(world, "bois-ramasser").filter(func(node): return int(node.get_meta("part", 0)) == 1)
	check(lying_branch.size() == 1, "another branch cut: it lies")
	if not lying_branch.is_empty():
		var node: Node3D = lying_branch[0]
		# Viser sa pièce la plus fine (un rameau ou un bâton léger).
		var spans_now: Dictionary = TreeParts.assignment(Trees.APPLE, 3, 0, world._cuts_of(node)).ranges[1]
		var thinnest := -1
		for number in spans_now:
			if thinnest < 0 or TreeParts.true_thickness(crown.pieces[number], spans_now[number].x) < TreeParts.true_thickness(crown.pieces[thinnest], spans_now[thinnest].x):
				thinnest = number
		var aim_point: Vector3 = world._model_of(node) * (crown.pieces[thinnest].start + crown.pieces[thinnest].direction * ((spans_now[thinnest].x + spans_now[thinnest].y) * 0.5))
		player.global_position = aim_point + Vector3(0.0, -0.5, 1.0)
		player.camera.global_position = aim_point + Vector3(0.0, 0.3, 1.0)
		player.camera.look_at(aim_point)
		for index in Inventory.HANDS + Inventory.POCKETS:
			world.inventory.put("bar", index, {})
		world.inventory.select(Inventory.HANDS[1])
		before = world.ground.entries.size()
		# 0.0.8.23 (« il faut qu'on enlève nous-mêmes les feuilles ») : le premier R fait tomber ses feuilles en tas ; elle
		# reste, nue ; le suivant la défait.
		var stripped: bool = world.pick_up({"collider": node, "position": aim_point})
		await frames(5)
		var leaf_piles: Array = world.ground.entries.slice(before).filter(func(entry): return entry.item.get("objet", "") == "feuilles")
		check(stripped and is_instance_valid(node) and not node.is_queued_for_deletion() and world._stripped(node) and not leaf_piles.is_empty() and wood_since(world, before).is_empty(), "R on the lying branch: first its leaves fall, in piles (%d), it stays" % leaf_piles.size())
		var took: bool = world.pick_up({"collider": node, "position": aim_point})
		await frames(5)
		var held: Dictionary = world.inventory.held()
		check(took and nodes_of(world, "bois-ramasser").filter(func(other): return int(other.get_meta("part", 0)) == 1).is_empty(), "R again on the bare branch: it comes apart into its woods")
		check(Inventory.ITEMS.get(held.get("objet", ""), {}).get("forme", "") == "bois" and wood_since(world, before).size() == spans_now.size() - 1, "the aimed piece is in hand (%s), the others on the ground (%d)" % [Inventory.item_name(held), wood_since(world, before).size()])
	clear(world, "bois-ramasser")
	# --- Survie : une branche qui tombe sur le joueur le blesse ---
	world.set_game_mode(Inventory.SURVIVAL)
	world.health.value = world.health.MAX
	apple = make(world, "bois-blesse", Trees.APPLE, 3, spot)
	await frames(3)
	var center: Vector3 = world._model_of(apple) * (piece_branch.start + piece_branch.direction * piece_branch.length * 0.5)
	player.global_position = Vector3(center.x, world.terrain.height_at(center.x, center.z), center.z)
	world.cut_wood(apple, branch, 0.05, world._model_of(apple) * (piece_branch.start + piece_branch.direction * 0.05))
	await frames(120)
	var lost: int = world.health.MAX - world.health.value
	check(lost > 0 and lost <= 80, "a branch falling on the player hurts (−%d)" % lost)
	world.health.value = world.health.MAX
	clear(world, "bois-blesse")
	world.queue_free()
	await frames(2)
	# --- 0.0.8.32 : épaisseur d'une pièce = le tour de sa tranche / pi (le diamètre rond qui lui ressemble), pas sa largeur
	# la plus petite ; les rameaux de côté ne comptent pas ; une tranche oblique ne grossit pas la pièce de plus de 30 %. ---
	var square := _prism(4, 0.05, Vector3.ZERO, 1.0)
	var square_side := 0.05 * sqrt(2.0)
	check(absf(TreeParts.true_thickness(square, 0.5) - 4.0 * square_side / PI) < 0.001, "a four-sided branch: its girth over pi (%.1f cm ; its smallest width, used before, is %.1f cm)" % [TreeParts.true_thickness(square, 0.5) * 100.0, square_side * 100.0])
	var round := _prism(12, 0.05, Vector3.ZERO, 1.0)
	check(absf(TreeParts.true_thickness(round, 0.5) - 0.1) < 0.004, "a round branch keeps its diameter (%.1f cm for 10 cm)" % (TreeParts.true_thickness(round, 0.5) * 100.0))
	var with_twig := _prism(4, 0.05, Vector3.ZERO, 1.0)
	with_twig.corners.append_array(_prism(4, 0.01, Vector3(0.3, 0.0, 0.0), 1.0).corners)
	check(absf(TreeParts.true_thickness(with_twig, 0.5) - TreeParts.true_thickness(square, 0.5)) < 0.0005, "a twig beside the branch does not make it thicker")
	var leaning := _prism(12, 0.05, Vector3.ZERO, 2.0)
	check(absf(TreeParts.true_thickness(leaning, 0.5) - 0.1 * 1.3) < 0.004, "a slanted slice of a curved branch: at most 30 %% more (%.1f cm for 10 cm)" % (TreeParts.true_thickness(leaning, 0.5) * 100.0))
	print("RESULT: %d wood checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

# Pièce d'essai : un prisme droit à « sides » côtés (rayon donné), le long de l'axe de la pièce (vers le haut, 1 m),
# décalé de « offset » ; « stretch » : étiré d'autant dans un sens (la tranche oblique d'une branche courbée).
func _prism(sides: int, radius: float, offset: Vector3, stretch: float) -> Dictionary:
	var corners := PackedVector3Array()
	for index in range(sides):
		var a := Vector3(cos(index * TAU / sides) * stretch, 0.0, sin(index * TAU / sides)) * radius + offset
		var b := Vector3(cos((index + 1) * TAU / sides) * stretch, 0.0, sin((index + 1) * TAU / sides)) * radius + offset
		var up := Vector3.UP
		corners.append_array([a - up * 0.5, b - up * 0.5, a + up * 1.5, b - up * 0.5, b + up * 1.5, a + up * 1.5])
	return {"corners": corners, "start": Vector3.ZERO, "direction": Vector3.UP, "length": 1.0, "profile": PackedFloat32Array([radius]), "root": false}
