extends SceneTree
# 0.0.6.9 (#149, #138) : premiers arbres fruitiers (génération 21). Même graine = mêmes arbres ; quelques-uns seulement,
# seuls ou par 2 à 3 ; jamais dans l'eau, le sable, la boue ni sur une pente raide ; anciens mondes inchangés ;
# modèle détaillé de près, simplifié au loin, rien au-delà ; collision du tronc ; pas de coupe.
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
const Generation = preload("res://scripts/world_generation.gd")
const Trees = preload("res://scripts/trees.gd")
const SEED := 397857267
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

func terrain_for(seed_value: int, options: Dictionary) -> RefCounted:
	var terrain := SmoothTerrain.new()
	terrain.setup(seed_value, [[Vector2(0.5, 0.5), 9.0]], options)
	return terrain

func all_trees(terrain: RefCounted) -> Array:
	var result := []
	var half: int = terrain.half_zones
	for x in range(-half, half):
		for z in range(-half, half):
			result.append_array(terrain.trees_in_zone(Vector2i(x, z)))
	return result

func _run() -> void:
	var options := Generation.defaults()
	check(Generation.VERSION == 21 and options.fruit_trees == 14 and Generation.describe(options).contains("pommiers et noisetiers"), "generation 21: fruit trees setting, described in the world information")
	var terrain := terrain_for(SEED, options)
	var trees := all_trees(terrain)
	var again := all_trees(terrain_for(SEED, options))
	check(trees == again, "same seed, same trees (%d)" % trees.size())
	check(all_trees(terrain_for(SEED + 1, options)) != trees, "another seed, other trees")
	var kinds := [0, 0]
	var groups := {}
	var variants_ok := true
	for tree in trees:
		kinds[int(tree.espece)] += 1
		var area: String = str(tree.id).get_slice("_", 0) + "_" + str(tree.id).get_slice("_", 1)
		groups[area] = groups.get(area, 0) + 1
		variants_ok = variants_ok and int(tree.variante) >= 0 and int(tree.variante) < Trees.VARIANTS
	check(trees.size() > 100 and trees.size() < 1000 and kinds[0] > 0 and kinds[1] > 0 and variants_ok, "a few trees only: %d apple trees, %d hazels in a 512 m world" % kinds)
	check(groups.values().max() <= 3 and groups.values().has(1) and groups.values().has(3), "alone or in small groups of 2 to 3")
	var dry := true
	var sandless := true
	var gentle := true
	for tree in trees:
		var at := Vector2(tree.x, tree.z)
		var column := Vector2i(roundi(at.x / SmoothTerrain.STEP), roundi(at.y / SmoothTerrain.STEP))
		var ground: float = terrain.ground_height(column)
		dry = dry and terrain.water_level_at(at) < ground - 0.3 and terrain.lake_at(at).is_empty()
		var river: Dictionary = terrain.river_near(at)
		dry = dry and (river.is_empty() or river.distance > river.width + SmoothTerrain.RIVER_BANK)
		sandless = sandless and not terrain.is_desert(at) and terrain.surface_kind(column) in [-1, SmoothTerrain.DIRT] and not terrain.muddy(column)
		var slope := Vector2(terrain.ground_height(column + Vector2i(2, 0)) - terrain.ground_height(column - Vector2i(2, 0)), terrain.ground_height(column + Vector2i(0, 2)) - terrain.ground_height(column - Vector2i(0, 2))) / 2.0
		gentle = gentle and slope.length() <= SmoothTerrain.TREE_SLOPE
	check(dry, "no tree in a lake, a river or on its bank")
	check(sandless, "no tree on sand, mud, gravel, snow or stone: only on grass")
	check(gentle, "no tree on a steep slope")
	# Anciens mondes : génération 20 sans arbre, relief identique.
	var old_options := options.duplicate()
	old_options.version = 20
	old_options.erase("fruit_trees")
	var old := terrain_for(SEED, old_options)
	check(all_trees(old).is_empty(), "generation 20 worlds get no trees")
	var same := true
	for index in range(200):
		var column := Vector2i(index * 37 % 900 - 450, index * 53 % 900 - 450)
		same = same and old.ground_height(column) == terrain.ground_height(column) and old.surface_kind(column) == terrain.surface_kind(column)
	check(same, "the relief and the ground do not change with the trees")
	# Modèles : 3 variantes par espèce, pommes et noisettes, simplifiés au loin.
	var models_ok := true
	for kind in [Trees.APPLE, Trees.HAZEL]:
		for variant in range(Trees.VARIANTS):
			var near: ArrayMesh = Trees.mesh(kind, variant)
			var far: ArrayMesh = Trees.mesh(kind, variant, true)
			var near_count := 0
			var far_count := 0
			for surface in range(near.get_surface_count()):
				near_count += near.surface_get_array_len(surface)
			for surface in range(far.get_surface_count()):
				far_count += far.surface_get_array_len(surface)
			models_ok = models_ok and near.get_surface_count() == 3 and far.get_surface_count() == 2 and far_count * 8 < near_count
	check(models_ok, "apple trees and hazels, 3 variants each, with fruit; far models at least 8 times lighter")
	# Dans le monde : détaillé de près, simplifié au loin, rien au-delà ; tronc solide ; pas de coupe.
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	world.generation_options = options
	world.terrain_seed = SEED
	root.add_child(world)
	world.player.set_physics_process(false)
	var tree: Dictionary = trees[0]
	world.update_terrain_view(true, Vector2i(floori(tree.x / 8.0), floori(tree.z / 8.0)))
	world.finish_terrain()
	var shown: Array = get_nodes_in_group_safe("trees").filter(func(node): return node.get_meta("id", "") == tree.id)
	check(shown.size() == 1, "the tree is shown in the world")
	if shown.size() == 1:
		var body: StaticBody3D = shown[0]
		var detail: MeshInstance3D = body.get_node("Detail")
		var far: MeshInstance3D = body.get_node("Loin")
		check(detail.visibility_range_end == Trees.DETAIL_END and far.visibility_range_begin == Trees.DETAIL_END and far.visibility_range_end == Trees.FAR_END, "detailed up to %d m, simplified up to %d m, then nothing" % [Trees.DETAIL_END, Trees.FAR_END])
		check(body.get_children().any(func(child): return child is CollisionShape3D and child.shape is CylinderShape3D), "the trunk is solid")
		var ground: float = world.terrain.height_at(tree.x, tree.z)
		check(absf(body.position.y - ground) < 0.2, "standing on the ground")
		world.player.selected_type = world.PICKAXE
		var hit := {"collider": body, "position": body.position + Vector3(0, 1, 0), "normal": Vector3.RIGHT}
		check(not world.break_target(hit) and not world.place_target(hit, SmoothTerrain.DIRT) and is_instance_valid(body), "trees are not cut nor built on (series 0.0.6)")
	root.remove_child(world)
	world.free()
	print("RESULT: %d tree checks, %d failures" % [checks, failures])
	quit(failures)

func get_nodes_in_group_safe(group: String) -> Array:
	return Array(root.get_tree().get_nodes_in_group(group))
