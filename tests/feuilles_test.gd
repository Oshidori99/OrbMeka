extends SceneTree
# 0.0.8.23 (demandes de l'utilisateur : « il faut qu'on enlève nous-mêmes les feuilles », « d'abord les feuilles tombent
# et on peut les récupérer avec R », « elles restent de la même taille », « quand le tas a 20 feuilles, un nouveau tas
# apparaît ») :
# - R sur une tige couchée : ses feuilles tombent en tas de 20 au plus, sous elle ; elle reste, nue ;
# - les tas sont faits des plaques du feuillage, à la même taille que sur l'arbre, dessinés ensemble ;
# - rouvert : la tige revient nue, les tas aussi ;
# - R sur la tige nue : elle se défait en bois ; R sur un tas : ses feuilles en main ;
# - un tas pas plein est complété d'abord ; les tas ont leur propre limite ;
# - un arbre abattu : R fait tomber ses feuilles, puis le défait en bûches ;
# - aucune feuille ne disparaît : un morceau qui devient du bois laisse tomber les siennes (un rameau garde les siennes).
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

# Triangles de feuilles dessinés par un morceau.
func drawn_leaves(node: Node3D) -> int:
	var detail: MeshInstance3D = node.get_node("Modele/Detail")
	var leaves := Trees.material(int(node.get_meta("kind", 0)), "leaves")
	var count := 0
	for surface in range(detail.mesh.get_surface_count()):
		if detail.mesh.surface_get_material(surface) == leaves:
			count += detail.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size() / 3
	return count

func piles(ground: Node) -> Array:
	return ground.entries.filter(func(entry): return entry.item.get("objet", "") == "feuilles")

func leaves_in(list: Array) -> int:
	var total := 0
	for entry in list:
		total += int(entry.item.get("tas", 1))
	return total

func wood_items(world: Node3D) -> Array:
	return world.ground.entries.filter(func(entry): return Inventory.ITEMS.get(entry.item.get("objet", ""), {}).get("forme", "") == "bois")

func at_ground(world: Node3D, point: Vector3) -> Vector3:
	return Vector3(point.x, world.terrain.height_at(point.x, point.z), point.z)

func _run() -> void:
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	world.set_game_mode(Inventory.CREATIVE)
	var spot: Vector3 = player.global_position + Vector3(0.0, 0.0, -4.0)
	# --- Une tige de noisetier coupée, couchée avec ses feuilles ---
	var hazel := make(world, "feuilles-noisetier", Trees.HAZEL, 5, spot)
	await frames(3)
	var bush: Dictionary = TreeParts.skeleton(Trees.HAZEL, 5, 0)
	var stem := -1
	for number in range(bush.pieces.size()):
		if bush.pieces[number].root and bush.pieces[number].tip.y > 0.5:
			stem = number
			break
	var stem_piece: Dictionary = bush.pieces[stem]
	world.cut_wood(hazel, stem, 0.35, world._model_of(hazel) * (stem_piece.start + stem_piece.direction * 0.35))
	await frames(150)
	var lying: Node3D = null
	for node in nodes_of(world, "feuilles-noisetier"):
		if int(node.get_meta("part", 0)) == 1:
			lying = node
	check(lying != null and drawn_leaves(lying) > 0, "the cut stem lies with its leaves")
	if lying == null:
		quit(1)
		return
	var triangles: int = TreeParts.assignment(Trees.HAZEL, 5, 0, world._cuts_of(lying)).leaves[1]
	var expected: int = triangles / world.LEAF_TRIANGLES
	var span: Array = TreeParts.main_span(Trees.HAZEL, 5, 0, world._cuts_of(lying), 1)
	var on_stem: Vector3 = world._model_of(lying) * (stem_piece.start + stem_piece.direction * ((float(span[1]) + float(span[2])) * 0.5))
	player.camera.global_position = on_stem + Vector3(0.0, 0.6, 1.2)
	# --- R sur la tige : ses feuilles tombent en tas de 20 au plus ; elle reste, nue ---
	var took: bool = world._pick_lying_wood({"collider": lying, "position": on_stem})
	await frames(30)
	var fallen := piles(world.ground)
	var count := leaves_in(fallen)
	check(took and absi(count - expected) <= 2 and fallen.all(func(entry): return int(entry.item.tas) <= Inventory.LEAF_PILE), "R: all its leaves fall (%d leaves, %d on the stem), in piles of 20 at most" % [count, expected])
	check(fallen.size() == ceili(count / float(Inventory.LEAF_PILE)), "a new pile only when the last one has 20 (%d piles for %d leaves)" % [fallen.size(), count])
	var lowest_gap := INF
	var highest_gap := -INF
	var farthest := 0.0
	for entry in fallen:
		var at: Vector3 = entry.position
		var ground: float = world._ground_at(at, lying)
		lowest_gap = minf(lowest_gap, at.y - ground)
		highest_gap = maxf(highest_gap, at.y - ground)
		var local: Vector3 = world._model_of(lying).affine_inverse() * at
		var axis: Vector3 = stem_piece.start + stem_piece.direction * clampf(TreeParts.along(stem_piece, local), 0.0, stem_piece.length)
		farthest = maxf(farthest, Vector2(local.x - axis.x, local.z - axis.z).length() * lying.scale.x)
	check(lowest_gap > -0.05 and highest_gap < 0.05, "the piles lie on the ground (%.2f to %.2f m)" % [lowest_gap, highest_gap])
	check(farthest < 3.0, "under the stem, where the leaves were (at most %.1f m from it)" % farthest)
	check(is_instance_valid(lying) and not lying.is_queued_for_deletion() and world._stripped(lying) and drawn_leaves(lying) == 0 and world.tree_cuts["feuilles-noisetier"].morceaux["1"].etat == "couche", "the stem stays, bare (no leaf drawn)")
	check(wood_items(world).is_empty(), "no wood yet: it is still the stem")
	# --- Les tas : les plaques du feuillage, à la taille de l'arbre, dessinés ensemble ---
	var plate := Trees.leaf_plate(Trees.HAZEL)
	var heap := GroundItems.leaf_pile_mesh(Trees.HAZEL, GroundItems.LEAF_PILE_STEPS)
	var corners: PackedVector3Array = heap.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var side: float = corners[0].distance_to(corners[1])
	check(plate > 0.4 and plate < 0.8 and absf(side - plate) < 0.01 and corners.size() == Inventory.LEAF_PILE * 6, "a full pile: 20 plates of the tree's leaves, same size (%.2f m, on the tree %.2f m)" % [side, plate])
	world.ground._redraw()
	var shown_key := "tas/%d/%d" % [Trees.HAZEL, GroundItems.LEAF_PILE_STEPS]
	check(world.ground._drawn.has(shown_key) and world.ground._drawn[shown_key].material_override == Trees.material(Trees.HAZEL, "leaves"), "drawn with the tree's own leaves")
	var series: int = world.ground._drawn.keys().filter(func(key): return str(key).begins_with("tas/")).size()
	check(series <= 2, "all the piles drawn together (%d series for %d piles)" % [series, fallen.size()])
	# --- Rouvert : la tige revient nue, les tas aussi ---
	var saved_ground: Array = world.ground.to_array()
	var reopened := make(world, "feuilles-noisetier", Trees.HAZEL, 5, spot)
	world._restore_parts(reopened)
	var back: Array = nodes_of(world, "feuilles-noisetier").filter(func(node): return int(node.get_meta("part", 0)) == 1 and node != lying)
	check(back.size() == 1 and drawn_leaves(back[0]) == 0, "reopened: the stem comes back bare")
	for node in [reopened] + back:
		world.column_objects[node.get_meta("column")].erase(node)
		node.free()
	var copy := GroundItems.new()
	root.add_child(copy)
	copy.from_array(saved_ground)
	check(leaves_in(piles(copy)) == count and copy._pile_count == fallen.size(), "reopened: the piles come back with their leaves (%d)" % leaves_in(piles(copy)))
	copy.queue_free()
	# --- R sur la tige nue : elle se défait en bois (plus de feuilles à faire tomber) ---
	world._pick_lying_wood({"collider": lying, "position": on_stem})
	await frames(30)
	check(not is_instance_valid(lying) or lying.is_queued_for_deletion(), "R on the bare stem: it comes apart")
	check(wood_items(world).size() >= 2 and leaves_in(piles(world.ground)) == count, "into its wood (%d), with no more leaves falling" % wood_items(world).size())
	check(wood_items(world).all(func(entry): return entry.item.objet != "rameau"), "bare: its thin pieces are bare branches, not leafy twigs")
	# --- R sur un tas : ses feuilles en main (Survie) ---
	world.set_game_mode(Inventory.SURVIVAL)
	for index in Inventory.HANDS + Inventory.POCKETS:
		world.inventory.put("bar", index, {})
	world.inventory.select(Inventory.HANDS[1])
	var full_index := -1
	for index in range(world.ground.entries.size()):
		if world.ground.entries[index].item.get("objet", "") == "feuilles" and int(world.ground.entries[index].item.tas) == Inventory.LEAF_PILE:
			full_index = index
			break
	var piles_before := piles(world.ground).size()
	var pile_at: Vector3 = world.ground.entries[full_index].position
	player.camera.global_position = pile_at + Vector3(0.05, 1.4, 0.6)
	player.camera.look_at(pile_at)
	# 0.0.8.25 (#140) : ce qu'on regarde, en haut de l'écran.
	var looked: String = world.looked_text({"collider": world.ground.bodies[full_index], "position": pile_at})
	check(looked == "Feuilles de noisetier (20)", "looking at a pile: « %s »" % looked)
	var picked: bool = world.pick_up({"collider": world.ground.bodies[full_index], "position": pile_at})
	var held: Dictionary = world.inventory.held()
	check(picked and held.get("objet", "") == "feuilles" and Inventory.count(held) == Inventory.LEAF_PILE and Inventory.item_name(held) == "Feuilles de noisetier", "R on a pile: its 20 leaves in hand (%s ×%d)" % [Inventory.item_name(held), Inventory.count(held)])
	check(piles(world.ground).size() == piles_before - 1, "and the pile is gone")
	check(is_equal_approx(Inventory.stack_weight(held), 30.0) and is_equal_approx(Inventory.stack_volume(held), 0.5), "light but bulky: 20 leaves, 30 g, 0.5 L")
	world.set_game_mode(Inventory.CREATIVE)
	clear(world, "feuilles-noisetier")
	# --- Un tas pas plein est complété d'abord ; puis un nouveau tas ---
	var here := at_ground(world, spot + Vector3(3.0, 0.0, 0.0))
	world.ground.drop({"objet": "feuilles", "essence": Trees.APPLE, "tas": 7}, here, here, world._ground_at, 0.0)
	world.ground.drop({"objet": "feuilles", "essence": Trees.APPLE, "tas": 18}, here + Vector3(0.2, 0.0, 0.0), here + Vector3(0.2, 0.0, 0.0), world._ground_at, 0.0)
	var counts: Array = piles(world.ground).map(func(entry): return int(entry.item.tas))
	check(counts == [20, 5], "a pile that is not full is filled first, then a new pile (%s)" % str(counts))
	world.ground.drop({"objet": "feuilles", "essence": Trees.HAZEL, "tas": 3}, here, here, world._ground_at, 0.0)
	check(piles(world.ground).size() == 3, "never mixed with another tree's leaves")
	# --- Les tas ont leur propre limite : jamais les autres objets ---
	clear(world, "rien")
	world.ground.drop(Inventory.catalog_item("branche:0"), here, here, world._ground_at, 0.0)
	for index in range(GroundItems.MAX_LEAF_PILES + 5):
		var far := at_ground(world, spot + Vector3(-20.0 + (index % 40) * 1.0, 0.0, -10.0 - (index / 40) * 1.0))
		world.ground.drop({"objet": "feuilles", "essence": Trees.APPLE, "tas": Inventory.LEAF_PILE}, far, far, world._ground_at, 0.0)
	check(piles(world.ground).size() == GroundItems.MAX_LEAF_PILES and world.ground._pile_count == GroundItems.MAX_LEAF_PILES and wood_items(world).size() == 1, "at most %d piles: the oldest pile goes, never another object" % GroundItems.MAX_LEAF_PILES)
	clear(world, "rien")
	# --- Arbre abattu : R fait tomber ses feuilles, puis le défait en bûches ---
	var apple := make(world, "feuilles-pommier", Trees.APPLE, 1, spot + Vector3(1.6, 0.0, 0.0))
	await frames(3)
	var crown: Dictionary = TreeParts.skeleton(Trees.APPLE, 1, 0)
	var trunk := 0
	for number in range(crown.pieces.size()):
		if crown.pieces[number].root and crown.pieces[number].length > crown.pieces[trunk].length:
			trunk = number
	world.fell_tree(apple)
	await frames(160)
	var foot: Vector3 = world._model_of(apple) * (crown.pieces[trunk].start + crown.pieces[trunk].direction * 0.5)
	player.camera.global_position = foot + Vector3(0.0, 0.6, 1.0)
	var felled_leaves: int = TreeParts.assignment(Trees.APPLE, 1, 0, []).leaves[0] / world.LEAF_TRIANGLES
	world._pick_lying_wood({"collider": apple, "position": foot})
	await frames(30)
	check(is_instance_valid(apple) and world._stripped(apple) and drawn_leaves(apple) == 0 and absi(leaves_in(piles(world.ground)) - felled_leaves) <= 2, "felled tree: R makes all its leaves fall (%d of %d), it stays, bare" % [leaves_in(piles(world.ground)), felled_leaves])
	world._pick_lying_wood({"collider": apple, "position": foot})
	await frames(30)
	check(wood_items(world).any(func(entry): return entry.item.objet == "tronc") and world.cut_trees.has("feuilles-pommier") and not world.fallen_trees.has("feuilles-pommier"), "then R again: logs and branches, the tree is done")
	clear(world, "feuilles-pommier")
	# --- Aucune feuille ne disparaît : un morceau feuillu qui devient du bois laisse tomber les siennes ---
	var hazel2 := make(world, "feuilles-noisetier-2", Trees.HAZEL, 5, spot + Vector3(-3.0, 0.0, 0.0))
	await frames(3)
	world.cut_wood(hazel2, stem, 0.35, world._model_of(hazel2) * (stem_piece.start + stem_piece.direction * 0.35))
	await frames(150)
	var leafy: Node3D = null
	for node in nodes_of(world, "feuilles-noisetier-2"):
		if int(node.get_meta("part", 0)) == 1:
			leafy = node
	check(leafy != null, "a second stem lies")
	if leafy != null:
		var all_leaves: int = TreeParts.assignment(Trees.HAZEL, 5, 0, world._cuts_of(leafy)).leaves[1] / world.LEAF_TRIANGLES
		world._part_to_wood(leafy, 1)
		await frames(30)
		var twigs: Array = wood_items(world).filter(func(entry): return entry.item.objet == "rameau")
		var dropped := leaves_in(piles(world.ground))
		# 0.0.8.30 : plus de rameau feuillu : toutes ses feuilles tombent, ses pièces fines sont des bâtons.
		check(dropped >= all_leaves - 2 and dropped > 0 and twigs.is_empty(), "turned into wood with its leaves: they all fall in piles (%d of %d), no leafy twig (%d)" % [dropped, all_leaves, twigs.size()])
	# 0.0.8.30 : un rameau d'avant, relu d'un monde enregistré, devient un bâton.
	check(Inventory._read({"objet": "rameau", "pile": [{"essence": 1, "epaisseur": 2.5, "fin": 2.0, "longueur": 0.5, "poids": 100.0}]}).get("objet", "") == "branche", "an old leafy twig read from a saved world is a plain stick")
	clear(world, "feuilles-noisetier-2")
	world.queue_free()
	await frames(2)
	print("RESULT: %d leaves checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
