extends SceneTree
# 0.0.7.8 : abattre un arbre (8 s à mains nues en Survie, anneau de chargement), il tombe vers le joueur et se couche
# (branches au-dessus du sol), reste tombé une fois rouvert ; couper un petit arbre tombé en un tronc et des branches.
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
	check(not world.step_chop(4.0, true) and world.chop_time == 4.0, "half way after 4 s (survival: 8 s by hand)")
	world._update_ring()
	check(world.ring.visible and is_equal_approx(world.ring.progress, 0.5), "the ring is half full")
	check(world.step_chop(4.1, true) and tree.has_meta("falling"), "after 8 s the tree falls")
	await frames(150)
	var up: Vector3 = tree.global_basis.y.normalized()
	var toward: Vector3 = (feet - tree.global_position) * Vector3(1, 0, 1)
	check(absf(up.y) < 0.2 and up.dot(toward.normalized()) > 0.7, "lying down, fallen toward the player")
	check(world.fallen_trees.has("noisetier-essai") and world.fallen_trees["noisetier-essai"].has("position"), "the fallen tree is remembered")
	# Rien du modèle sous le sol (à quelques centimètres près).
	var detail: MeshInstance3D = tree.get_node("Modele/Detail")
	var points: PackedVector3Array = detail.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var below := 0
	var place: Transform3D = detail.global_transform
	for index in range(0, points.size(), 7):
		var at: Vector3 = place * points[index]
		if at.y < world.terrain.height_at(at.x, at.z) - 0.1:
			below += 1
	check(below == 0, "branches pushed above the ground (%d points below)" % below)
	# Rouvert : un nouvel arbre avec le même numéro est couché tout de suite.
	var again := make_tree(world, "noisetier-essai", feet + Vector3(1.6, 0.0, 0.0))
	world._restore_fallen(again)
	check(absf(again.global_basis.y.normalized().y) < 0.2 and again.global_position.distance_to(tree.global_position) < 0.05, "restored lying at the same place")
	world.column_objects[world._player_column()].erase(again)
	again.queue_free()
	# Couper (petit arbre) : un tronc et des branches au sol.
	world.set_game_mode(Inventory.CREATIVE)
	var before: int = world.ground.entries.size()
	var trunk_point: Vector3 = tree.global_position + tree.global_basis.y.normalized() * 0.3
	player.camera.look_at(trunk_point)
	await frames(2)
	var aimed: Dictionary = player.get_target()
	check(not aimed.is_empty() and aimed.collider == tree, "aiming at the fallen trunk")
	check(world.step_chop(1.1, true) and world.cut_trees.has("noisetier-essai") and not world.fallen_trees.has("noisetier-essai"), "a small fallen tree is cut (creative: 1 s)")
	await frames(30)
	var wood: Array = world.ground.entries.slice(before).map(func(entry): return entry.item)
	check(wood.size() == 4 and wood[0].objet == "tronc" and wood.slice(1).all(func(item): return item.objet == "branche"), "one trunk and three branches on the ground")
	check(wood.all(func(item): return item.essence == Trees.HAZEL and item.age >= 1 and item.age <= 5 and item.souplesse >= 1 and item.longueur > 0.3 and item.poids > 0.0), "each piece has its essence, age, suppleness, length and weight")
	check(not is_instance_valid(tree) or tree.is_queued_for_deletion(), "the tree is gone")
	# Ramasser une branche (R).
	world.inventory.select(5)
	var index: int = before + 1
	world.pick_up({"collider": world.ground.bodies[index], "position": world.ground.entries[index].position})
	check(world.inventory.item("bar", 5).get("objet") == "branche", "R picks up a branch")
	root.remove_child(world)
	world.queue_free()
	await process_frame
	print("RESULT: %d tree fall checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
