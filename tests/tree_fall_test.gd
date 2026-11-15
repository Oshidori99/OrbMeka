extends SceneTree
# 0.0.7.9 : abattre un arbre (temps selon l'épaisseur du bois visé, anneau de chargement), il tombe vers le joueur et
# se couche (branches au-dessus du sol), reste tombé une fois rouvert ; le couper en deux là où on vise ; 30 cm au plus (0.0.7.10).
const Trees = preload("res://scripts/trees.gd")
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

func make_tree(world: Node3D, id: String, at: Vector3) -> Node3D:
	var tree: Node3D = Trees.tree_body(Trees.HAZEL, 1)
	tree.set_meta("id", id)
	var column: Vector2i = world._player_column()
	tree.set_meta("column", column)
	world._rocks_parent().add_child(tree)
	tree.global_position = Vector3(at.x, world.terrain.height_at(at.x, at.z) - 0.05, at.z)
	world.column_objects[column] = world.column_objects.get(column, []) + [tree]
	return tree

func _run() -> void:
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	world.set_game_mode(Inventory.SURVIVAL)
	var feet: Vector3 = player.global_position
	var tree := make_tree(world, "noisetier-essai", feet + Vector3(1.6, 0.0, 0.0))
	await frames(5)
	player.camera.look_at(tree.global_position + Vector3.UP * 0.5)
	await frames(2)
	var first_aim: Dictionary = player.get_target()
	check(not first_aim.is_empty() and first_aim.collider == tree, "aiming at the trunk (" + (str(first_aim.collider.name) + " at " + str(first_aim.position) if not first_aim.is_empty() else "nothing") + ", tree at " + str(tree.global_position) + ", eye at " + str(player.camera.global_position) + ")")
	# 0.0.7.10 : temps selon l'épaisseur du bois visé : 8 s par tranche de 10 cm.
	check(not world.step_chop(0.01, true) and world.chop_thickness > 0.0 and world.chop_thickness <= 0.15, "thickness measured at the aimed point (%.1f cm)" % (world.chop_thickness * 100.0))
	var standing_thickness: float = world.chop_thickness
	var expected: float = maxf(8.0 * world.chop_thickness / 0.1, 0.5)
	check(is_equal_approx(world.chop_seconds, expected), "chop time from thickness (%.2f s)" % world.chop_seconds)
	check(not world.step_chop(world.chop_seconds * 0.5 - 0.01, true), "half way not cut yet")
	world._update_ring()
	check(world.ring.visible and absf(world.ring.progress - 0.5) < 0.01, "the ring is half full")
	check(world.step_chop(world.chop_seconds * 0.5 + 0.1, true) and tree.has_meta("falling"), "then the tree falls")
	await frames(150)
	var up: Vector3 = tree.global_basis.y.normalized()
	var toward: Vector3 = (feet - tree.global_position) * Vector3(1, 0, 1)
	check(absf(up.y) < 0.2 and up.dot(toward.normalized()) > 0.7, "lying down, fallen toward the player")
	check(world.fallen_trees.has("noisetier-essai") and world.fallen_trees["noisetier-essai"].has("position"), "the fallen tree is remembered")
	# Rien du modèle sous le vrai sol (à quelques centimètres près).
	var detail: MeshInstance3D = tree.get_node("Modele/Detail")
	var points: PackedVector3Array = detail.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var below := 0
	var place: Transform3D = detail.global_transform
	for index in range(0, points.size(), 7):
		var at: Vector3 = place * points[index]
		if at.y < world._ground_at(at, tree) - 0.1:
			below += 1
	check(below == 0, "branches pushed above the ground (%d points below)" % below)
	# Rouvert : un nouvel arbre avec le même numéro est couché tout de suite.
	var again := make_tree(world, "noisetier-essai", feet + Vector3(1.6, 0.0, 0.0))
	world._restore_fallen(again)
	check(absf(again.global_basis.y.normalized().y) < 0.2 and again.global_position.distance_to(tree.global_position) < 0.05, "restored lying at the same place")
	world.column_objects[world._player_column()].erase(again)
	again.queue_free()
	# 0.0.7.9 : couper en deux à l'endroit visé : le bas (bois nu) devient un tronc ou une branche au sol, à sa longueur ;
	# le haut (branches et feuilles) reste couché à sa place, avec sa forme.
	world.set_game_mode(Inventory.CREATIVE)
	var before: int = world.ground.entries.size()
	var trunk_point: Vector3 = tree.global_position + tree.global_basis.y.normalized() * 0.15
	player.camera.look_at(trunk_point)
	await frames(2)
	var aimed: Dictionary = player.get_target()
	check(not aimed.is_empty() and aimed.collider.get_meta("arbre", aimed.collider) == tree, "aiming at the fallen trunk")
	check(world.step_chop(1.1, true) and world.fallen_trees["noisetier-essai"].get("cuts", []).size() == 1, "cut in two (creative: 1 s)")
	await frames(30)
	var wood: Array = world.ground.entries.slice(before).map(func(entry): return entry.item)
	check(wood.size() == 1 and wood[0].objet in ["tronc", "branche"], "the bare lower part is one piece of wood on the ground")
	var cut_at: float = world.fallen_trees["noisetier-essai"].cuts[0]
	check(not wood.is_empty() and absf(wood[0].longueur - cut_at * tree.scale.x) < 0.02, "its length is the real one (%.2f m)" % (wood[0].longueur if not wood.is_empty() else 0.0))
	check(wood.all(func(item): return item.essence == Trees.HAZEL and item.age >= 1 and item.age <= 5 and item.souplesse >= 1 and item.poids > 0.0), "it has its essence, age, suppleness and weight")
	check(is_instance_valid(tree) and tree.has_meta("range") and absf(float(tree.get_meta("range")[0]) - cut_at) < 0.002 and not world.cut_trees.has("noisetier-essai"), "the leafy top stays, lying")
	var kept: int = tree.get_node("Modele/Detail").mesh.get_surface_count()
	check(kept >= 1, "the top keeps its shape")
	# Comme en jouant (0.0.7.9) : on s'approche du haut couché (seul le tronc est solide), on le recoupe dans la couronne,
	# une fente se voit entre les deux morceaux, et le bois coupé a la taille du tronc.
	var wood_piece: Dictionary = wood[0]

	check(wood_piece.epaisseur >= wood_piece.fin and wood_piece.epaisseur / 100.0 >= standing_thickness * 0.95, "the cut wood keeps its real thickness (%.1f to %.1f cm)" % [wood_piece.fin, wood_piece.epaisseur])
	var solid_shapes: int = tree.get_children().filter(func(child): return child is CollisionShape3D).size()
	var aim: Node = tree.get_node_or_null("Visee")
	check(solid_shapes <= 1 and aim != null and aim.collision_layer == 2 and (player.collision_mask & 2) == 0, "only the trunk is solid, the crown can be walked into and still aimed at")
	var axis: Vector3 = tree.global_basis.y.normalized()
	var crown_spot: Vector3 = tree.global_position + axis * 1.2 + axis.cross(Vector3.UP).normalized() * 0.6
	var standing := Transform3D(Basis.IDENTITY, Vector3(crown_spot.x, world._ground_at(crown_spot, tree) + 0.4, crown_spot.z))
	var blocked := KinematicCollision3D.new()
	var hit_crown: bool = player.test_move(standing, -axis.cross(Vector3.UP).normalized() * 0.5, blocked)
	check(not hit_crown, "the player walks into the lying crown")
	var crown_cut: Vector3 = tree.global_position + axis * 1.4
	player.camera.look_at(crown_cut)
	await frames(2)
	var crown_aim: Dictionary = player.get_target()
	check(not crown_aim.is_empty() and crown_aim.collider.get_meta("arbre", crown_aim.collider) == tree, "aiming at the crown")
	var pieces_before: int = world.column_objects[world._player_column()].filter(func(node): return is_instance_valid(node) and node.get_meta("id", "") == "noisetier-essai").size()
	world.step_chop(1.1, true)
	var pieces: Array = world.column_objects[world._player_column()].filter(func(node): return is_instance_valid(node) and node.get_meta("id", "") == "noisetier-essai")
	check(pieces.size() == pieces_before + 1, "the crown is cut in two")
	if pieces.size() >= 2:
		var gap: float = pieces[-1].global_position.distance_to(pieces[0].global_position)
		check(absf(gap - world.CUT_GAP) < 0.03, "a visible gap between the two pieces (%.2f m)" % gap)
	# Rouvert : le haut seulement.
	var reopened := make_tree(world, "noisetier-essai", feet + Vector3(1.6, 0.0, 0.0))
	world._restore_fallen(reopened)
	world._restore_pieces(reopened)
	check(reopened.has_meta("range") and absf(float(reopened.get_meta("range")[0]) - cut_at) < 0.002, "reopened: only the top is there")
	world.column_objects[world._player_column()].erase(reopened)
	reopened.queue_free()
	# Ramasser le morceau de bois (R).
	world.inventory.select(5)
	var index: int = before
	# Viser le morceau ; les noisettes du haut (toujours là) mises de côté pour ce test.
	world.picked_fruits["noisetier-essai"] = range(200)
	player.camera.look_at(world.ground.entries[index].position)
	await frames(2)
	world.pick_up({"collider": world.ground.bodies[index], "position": world.ground.entries[index].position})
	check(world.inventory.item("bar", 5).get("objet") in ["tronc", "branche"], "R picks up the piece of wood")
	# Trop épais à mains nues en Survie (plus de 30 cm) : impossible.
	world.set_game_mode(Inventory.SURVIVAL)
	var big: Node3D = Trees.tree_body(Trees.LINDEN, 5)
	big.set_meta("id", "tilleul-essai")
	big.set_meta("column", world._player_column())
	world._rocks_parent().add_child(big)
	big.global_position = Vector3(feet.x - 2.5, world.terrain.height_at(feet.x - 2.5, feet.z) - 0.05, feet.z)
	await frames(3)
	player.camera.look_at(big.global_position + Vector3.UP * 0.6)
	await frames(2)
	var big_aim: Dictionary = player.get_target()
	check(not big_aim.is_empty() and big_aim.collider == big and not world.step_chop(30.0, true) and world.chop_thickness > 0.30 and not big.has_meta("falling"), "a trunk thicker than 30 cm cannot be cut by hand (%.0f cm)" % (world.chop_thickness * 100.0))
	root.remove_child(world)
	world.queue_free()
	await process_frame
	print("RESULT: %d tree fall checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
