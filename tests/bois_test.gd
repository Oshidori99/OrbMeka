extends SceneTree
# 0.0.8.22 (demandes de l'utilisateur : « le bâton ou la bûche qui tombe est ultra fin, par moments » ; les bûches et
# bâtons gardent la taille qu'ils avaient sur l'arbre) :
# - la tige ou le tronc coupé : son bois au sol a l'épaisseur de la tige (avant : mesurée dans une tranche de tout
#   l'arbre, parfois sur une tige ou une branche voisine : un bout ultra fin) ; le temps de coupe vise la même mesure ;
# - le bois d'un morceau : toutes ses pièces, chacune à sa longueur (rien ne disparaît) ;
# - une branche coupée sur un arbre debout tombe telle qu'elle est (morceau 3D), puis se pose : couchée telle quelle, ou
#   son bois au sol, pièce par pièce.
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
	if lying == null:
		var logs := woods.filter(func(item): return float(item.longueur) > stem_piece.length * hazel.scale.x * 0.8)
		check(logs.size() == 1 and absf(float(logs[0].epaisseur) / 100.0 - real) < real * 0.2, "the cut stem became wood: a log as thick as the stem (%s cm, the stem: %.1f cm)" % [str(logs.map(func(i): return i.epaisseur)), real * 100.0])
		check(woods.size() > 1, "and its branches too, each its own wood (%d)" % woods.size())
	else:
		var main: Array = TreeParts.main_span(Trees.HAZEL, 5, 0, world._cuts_of(lying), 1)
		var middle: float = (float(main[1]) + float(main[2])) * 0.5
		var there := TreeParts.true_thickness(bush.pieces[main[0]], middle) * hazel.scale.x
		before = world.ground.entries.size()
		world.cut_wood(lying, int(main[0]), middle, lying.global_position)
		await frames(10)
		woods = wood_since(world, before)
		var logs := woods.filter(func(item): return absf(float(item.longueur) - (float(main[2]) - middle) * hazel.scale.x) < 0.05 or absf(float(item.longueur) - (middle - float(main[1])) * hazel.scale.x) < 0.05)
		var close := logs.any(func(item): return absf(float(item.epaisseur) / 100.0 - there) < there * 0.25 or absf(float(item.fin) / 100.0 - there) < there * 0.25)
		check(close, "the lying stem cut in its middle (%.1f cm there): its logs meet at that thickness (%s)" % [there * 100.0, str(logs.map(func(i): return "%s→%s" % [i.epaisseur, i.fin]))])
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
	var still := nodes_of(world, "bois-pommier").filter(func(node): return int(node.get_meta("part", 0)) == 1)
	woods = wood_since(world, before)
	if still.is_empty():
		var total := 0.0
		for item in woods:
			total += float(item.longueur)
		check(woods.size() == cut_spans.size() and absf(total - expected) < 0.05, "landed, almost without leaves: every piece is its own wood (%d of %d, %.2f m of %.2f m)" % [woods.size(), cut_spans.size(), total, expected])
		var thickest := 0.0
		for item in woods:
			thickest = maxf(thickest, float(item.epaisseur))
		var root_thick := TreeParts.true_thickness(piece_branch, 0.3) * apple.scale.x * 100.0
		check(absf(thickest - root_thick) < root_thick * 0.25, "the branch keeps its thickness (%.1f cm, on the tree %.1f cm)" % [thickest, root_thick])
		world.ground._redraw()
		var series: int = world.ground._drawn.keys().filter(func(key): return str(key).begins_with("bois/")).size()
		check(series <= woods.size() and series <= 8, "drawn in few series (%d for %d woods: same tree, same tip, one series)" % [series, woods.size()])
	else:
		check(not still[0].has_meta("falling") and world.tree_cuts["bois-pommier"].morceaux["1"].etat == "couche", "landed with its leaves: it lies as it is, to cut again")
	clear(world, "bois-pommier")
	world.queue_free()
	await frames(2)
	print("RESULT: %d wood checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
