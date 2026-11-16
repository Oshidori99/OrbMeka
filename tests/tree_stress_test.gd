extends SceneTree
# 0.0.7.15 (demande de l'utilisateur : « coupe plein d'arbres, pose-toi toutes les questions ») : endurance de la coupe.
# Pour chaque espèce et plusieurs tailles : abattre en hauteur (ou une tige de noisetier), laisser tomber, couper le tronc
# couché plusieurs fois (coupes proches comprises, comme dans le monde T56), casser des branches, recouper au même
# endroit, recasser le bois au sol. Après chaque geste, on vérifie :
# - les tronçons de chaque pièce couvrent toute la pièce, une seule fois (rien de perdu, rien en double) ;
# - le bois au sol n'est jamais plus long que sa pièce ni plus épais que l'arbre (le tronc de 9,5 m de T56) ;
# - aucun morceau vide, aucun morceau couché qui flotte (un point touche le sol), un arbre lourd posé sur son tronc ;
# - une coupe au même endroit est refusée.
# Et un noisetier tombé sur un obstacle reste penché : un bout porté, l'autre au sol.
const Trees = preload("res://scripts/trees.gd")
const TreeParts = preload("res://scripts/tree_parts.gd")
const Inventory = preload("res://scripts/inventory.gd")
var checks := 0
var failures := 0
var rng := RandomNumberGenerator.new()

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

# Plus petite hauteur d'un morceau au-dessus du sol (un point sur 5) : proche de 0 = il touche.
func clearance(world: Node3D, node: Node3D) -> float:
	var detail: MeshInstance3D = node.get_node("Modele/Detail")
	var place: Transform3D = detail.global_transform
	var lowest := INF
	for surface in range(detail.mesh.get_surface_count()):
		var points: PackedVector3Array = detail.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for index in range(0, points.size(), 5):
			var at: Vector3 = place * points[index]
			lowest = minf(lowest, at.y - world._ground_at(at, node))
	return lowest

func invariants(world: Node3D, id: String, kind: int, size: int, scale: float, label: String) -> void:
	var cuts: Array = world.tree_cuts.get(id, {}).get("coupes", [])
	var made: Dictionary = TreeParts.skeleton(kind, size, 0)
	var ranges: Array = TreeParts.assignment(kind, size, 0, cuts).ranges
	var lost := 0
	for number in range(made.pieces.size()):
		var covered := 0.0
		for part in range(ranges.size()):
			if ranges[part].has(number):
				covered += ranges[part][number].y - ranges[part][number].x
		if absf(covered - made.pieces[number].length) > 0.002:
			lost += 1
	check(lost == 0, "%s: every piece fully covered by its parts (%d wrong)" % [label, lost])
	var longest := 0.0
	for piece in made.pieces:
		longest = maxf(longest, piece.length)
	var too_big: Array = world.ground.entries.filter(func(entry): return Inventory.ITEMS.get(entry.item.get("objet", ""), {}).get("forme", "") == "bois" and (float(entry.item.longueur) > longest * scale + 0.02 or float(entry.item.longueur) <= 0.0 or float(entry.item.epaisseur) > 150.0))
	check(too_big.is_empty(), "%s: no wood on the ground longer than its tree (%s)" % [label, str(too_big.map(func(entry): return entry.item.longueur))])
	for node in nodes_of(world, id):
		var detail: MeshInstance3D = node.get_node("Modele/Detail")
		check(detail.mesh != null and detail.mesh.get_surface_count() > 0, "%s: piece %d is not empty" % [label, int(node.get_meta("part", 0))])
		if world._tree_is_lying(node) and not node.has_meta("falling"):
			var gap := clearance(world, node)
			check(gap < 0.2, "%s: lying piece %d touches the ground (lowest %.2f m)" % [label, int(node.get_meta("part", 0)), gap])

func trunk_of(made: Dictionary) -> int:
	var trunk := 0
	for number in range(made.pieces.size()):
		if made.pieces[number].root and made.pieces[number].length > made.pieces[trunk].length:
			trunk = number
	return trunk

func _run() -> void:
	rng.seed = 715
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	world.set_game_mode(Inventory.CREATIVE)
	var feet: Vector3 = player.global_position
	var spot := feet + Vector3(0.0, 0.0, -4.0)
	for kind in [Trees.APPLE, Trees.HAZEL, Trees.PINE, Trees.LINDEN]:
		for size in [1, 2, 3]:
			var id := "essai-%d-%d" % [kind, size]
			var label := "%s %d" % [Trees.KIND_NAMES[kind], size]
			var tree := make(world, id, kind, size, spot)
			await frames(3)
			var made: Dictionary = TreeParts.skeleton(kind, size, 0)
			var trunk := trunk_of(made)
			# Noisetier : une de ses tiges ; sinon le tronc, plus haut que le pied (une souche reste).
			var stem: int = trunk
			if kind == Trees.HAZEL:
				for number in range(made.pieces.size()):
					if made.pieces[number].root and made.pieces[number].tip.y > 0.5:
						stem = number
						break
			var high: float = clampf(made.pieces[stem].length * 0.25, 0.6, 1.4)
			world.cut_wood(tree, stem, high, tree.global_position)
			check(nodes_of(world, id).size() == 2 and not world.fallen_trees.has(id), "%s: a stump stays, the top falls" % label)
			await frames(150)
			invariants(world, id, kind, size, tree.scale.x, label + " after the fall")
			# Le haut couché : coupes du tronc, dont deux très proches (23 cm, comme dans T56).
			var top: Node3D = null
			for node in nodes_of(world, id):
				if int(node.get_meta("part", 0)) == 1:
					top = node
			if top == null:
				check(false, "%s: the fallen top exists" % label)
				clear(world, id)
				continue
			var span: Array = TreeParts.main_span(kind, size, 0, world.tree_cuts[id].coupes, 1)
			var first: float = lerpf(float(span[1]), float(span[2]), 0.35)
			world.cut_wood(top, int(span[0]), first, top.global_position)
			invariants(world, id, kind, size, tree.scale.x, label + " after a cut of the lying trunk")
			var count: int = world.tree_cuts[id].coupes.size()
			world.cut_wood(top if is_instance_valid(top) and not top.is_queued_for_deletion() else nodes_of(world, id)[-1], int(span[0]), first + 0.01, top.global_position if is_instance_valid(top) else spot)
			check(world.tree_cuts[id].coupes.size() == count, "%s: a second cut at the same spot is refused" % label)
			# Coupe proche (23 cm plus loin) sur le morceau qui porte maintenant ce tronçon.
			var holder: Node3D = null
			for node in nodes_of(world, id):
				var spans: Dictionary = TreeParts.assignment(kind, size, 0, world.tree_cuts[id].coupes).ranges[int(node.get_meta("part", 0))]
				if spans.has(int(span[0])) and spans[int(span[0])].x <= first + 0.23 and spans[int(span[0])].y >= first + 0.23:
					holder = node
			if holder != null and first + 0.23 < float(span[2]) - 0.1:
				world.cut_wood(holder, int(span[0]), first + 0.23, holder.global_position)
				await frames(5)
				invariants(world, id, kind, size, tree.scale.x, label + " after two close cuts")
			# Trois branches cassées au hasard, sur les morceaux encore là.
			for attempt in range(3):
				var pieces_now: Array = nodes_of(world, id).filter(func(node): return world._tree_is_lying(node))
				if pieces_now.is_empty():
					break
				var node: Node3D = pieces_now[rng.randi_range(0, pieces_now.size() - 1)]
				var spans: Dictionary = TreeParts.assignment(kind, size, 0, world.tree_cuts[id].coupes).ranges[int(node.get_meta("part", 0))]
				var branches: Array = spans.keys().filter(func(number): return not made.pieces[number].root and spans[number].y - spans[number].x > 0.2)
				if branches.is_empty():
					break
				var branch: int = branches[rng.randi_range(0, branches.size() - 1)]
				var before: int = world.ground.entries.size()
				world.cut_wood(node, branch, lerpf(spans[branch].x, spans[branch].y, rng.randf_range(0.2, 0.6)), node.global_position)
				await frames(5)
				check(world.ground.entries.size() >= before, "%s: a broken branch drops wood" % label)
				invariants(world, id, kind, size, tree.scale.x, label + " after a broken branch")
			# Recasser un bois au sol, au milieu : deux moitiés dont les longueurs s'additionnent.
			if not world.ground.entries.is_empty():
				var index: int = world.ground.entries.size() - 1
				var item: Dictionary = world.ground.entries[index].item.duplicate()
				var halves_before: int = world.ground.entries.size()
				if float(item.longueur) > 0.2 and world.split_wood(index, world.ground.entries[index].position):
					var halves: Array = world.ground.entries.slice(halves_before - 1).map(func(entry): return entry.item)
					var total := 0.0
					for half in halves:
						total += float(half.longueur)
					check(halves.size() == 2 and absf(total - float(item.longueur)) < 0.03, "%s: wood on the ground splits in two halves adding up (%.2f m)" % [label, total])
			clear(world, id)
			world.tree_cuts.erase(id)
			world.fallen_trees.erase(id)
	# --- Noisetier tombé sur un obstacle : penché, un bout porté, l'autre au sol (physique d'un arbre léger). ---
	var block := StaticBody3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 0.6, 0.8)
	var shape := CollisionShape3D.new()
	shape.shape = box
	block.add_child(shape)
	world.add_child(block)
	var hazel := make(world, "noisetier-bosse", Trees.HAZEL, 1, spot)
	await frames(3)
	var bush: Dictionary = TreeParts.skeleton(Trees.HAZEL, 1, 0)
	var cane := -1
	for number in range(bush.pieces.size()):
		if bush.pieces[number].root and bush.pieces[number].tip.y > 0.5 and (cane < 0 or bush.pieces[number].length > bush.pieces[cane].length):
			cane = number
	# L'obstacle sous le bout de la tige quand elle tombe vers le joueur (+z).
	var tip_at: Vector3 = spot + Vector3(0.0, 0.0, bush.pieces[cane].length * 0.85)
	block.global_position = Vector3(tip_at.x, world.terrain.height_at(tip_at.x, tip_at.z) + 0.3, tip_at.z)
	await frames(3)
	world.cut_wood(hazel, cane, 0.6, hazel.global_position)
	await frames(150)
	var fallen: Node3D = null
	for node in nodes_of(world, "noisetier-bosse"):
		if int(node.get_meta("part", 0)) == 1:
			fallen = node
	check(fallen != null, "the hazel stem has fallen")
	if fallen != null:
		var axis: Vector3 = fallen.global_basis.y.normalized()
		var piece: Dictionary = bush.pieces[cane]
		var near_end: Vector3 = world._model_of(fallen) * (piece.start + piece.direction * 0.7)
		var far_end: Vector3 = world._model_of(fallen) * (piece.start + piece.direction * piece.length * 0.9)
		check(far_end.y > near_end.y + 0.15, "tilted: the end over the obstacle is higher (%.2f m over %.2f m)" % [far_end.y, near_end.y])
		check(clearance(world, fallen) < 0.15, "it still touches the ground somewhere (%.2f m)" % clearance(world, fallen))
		check(absf(axis.y) < 0.8, "it lies (not standing up)")
	# --- 0.0.7.16 : tous les arbres (4 espèces, tailles 1 à 5, 3 formes) : deux coupes à 6 cm l'une de l'autre, tout le
	# long du tronc et de 3 branches : le petit bout est toujours son propre morceau (jamais vide), le reste aussi. ---
	var wrong := []
	var tried := 0
	for kind in [Trees.APPLE, Trees.HAZEL, Trees.PINE, Trees.LINDEN]:
		for size in range(1, 6):
			for form in range(3):
				var made: Dictionary = TreeParts.skeleton(kind, size, form)
				var targets := [trunk_of(made)]
				for number in range(made.pieces.size()):
					if not made.pieces[number].root and made.pieces[number].length > 0.5 and targets.size() < 4:
						targets.append(number)
				for number in targets:
					var length: float = made.pieces[number].length
					var at := 0.2
					while at + 0.06 < length - 0.1:
						var cuts := [[number, at], [number, at + 0.06]]
						var ranges: Array = TreeParts.assignment(kind, size, form, cuts).ranges
						tried += 1
						var bit_ok: bool = ranges[1].has(number) and absf(ranges[1][number].x - at) < 0.001 and absf(ranges[1][number].y - (at + 0.06)) < 0.001
						var rest_ok: bool = ranges[2].has(number) and absf(ranges[2][number].x - (at + 0.06)) < 0.001
						if not bit_ok or not rest_ok:
							wrong.append("%s %d f%d piece %d at %.2f" % [Trees.KIND_NAMES[kind], size, form, number, at])
						at += 0.37
	check(wrong.is_empty() and tried > 500, "two cuts 6 cm apart, all trees, sizes and forms: never an empty piece (%d tried, %d wrong %s)" % [tried, wrong.size(), str(wrong.slice(0, 5))])
	# --- 0.0.7.16 : le pin du monde T56 (taille 2, forme 2) : deux coupes à 15 cm sur le tronc, sans triangle entre elles. ---
	var pine_cuts := [[5, 1.239], [5, 2.053], [5, 2.207]]
	var pine_ranges: Array = TreeParts.assignment(Trees.PINE, 2, 1, pine_cuts).ranges
	check(pine_ranges[3].has(5) and absf(pine_ranges[3][5].x - 2.207) < 0.001, "the third cut is not empty: the top beyond it is its own piece")
	check(pine_ranges[2].has(5) and absf(pine_ranges[2][5].x - 2.053) < 0.001 and absf(pine_ranges[2][5].y - 2.207) < 0.001, "the short trunk bit is its own piece (2.053 to 2.207)")
	check(TreeParts.leaf_share(Trees.PINE, 2, 1, pine_cuts, 2) < Trees.BARE_LEAF_SHARE, "the short bit is bare: it becomes wood to pick up")
	check(TreeParts.old_empty_cuts(Trees.PINE, 2, 1, pine_cuts) == [3], "with the old rule the third cut was empty")
	# Sauvegarde d'avant : la coupe vide est retirée à l'ouverture, l'arbre reste tel que le joueur le voyait.
	world.tree_cuts["pin-t56"] = {"coupes": pine_cuts.duplicate(true), "morceaux": {"1": {"etat": "bois"}, "2": {"etat": "bois"}, "3": {"etat": "bois"}}}
	var pine_node := make(world, "pin-t56", Trees.PINE, 2, spot + Vector3(6.0, 0.0, 0.0))
	pine_node.set_meta("form", 1)
	world._restore_parts(pine_node)
	var migrated: Dictionary = world.tree_cuts["pin-t56"]
	check(migrated.coupes.size() == 2 and not migrated.morceaux.has("3") and int(migrated.get("v", 0)) == 2, "an old save is repaired on opening (%s)" % str(migrated.coupes))
	root.remove_child(world)
	world.queue_free()
	await process_frame
	print("RESULT: %d tree stress checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
