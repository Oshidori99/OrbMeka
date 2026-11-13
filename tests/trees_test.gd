extends SceneTree
# 0.0.6.9 (#149, #138) : premiers arbres fruitiers (génération 21). Même graine = mêmes arbres ; quelques-uns seulement,
# seuls ou par 2 à 3 ; jamais dans l'eau, le sable, la boue ni sur une pente raide ; anciens mondes inchangés ;
# modèle détaillé de près, simplifié au loin, rien au-delà ; collision du tronc ; pas de coupe. 0.0.6.10 : modèles Blender.
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
	# 0.0.6.13 : arbres hors forêts, vérifiés en génération 23 (les forêts ont leur propre test, forests_test.gd).
	var options := Generation.defaults()
	options.version = 23
	# 0.0.6.14 : réglages des montagnes d'avant la version 25.
	if options.has("mountains"): options.mountains = 850
	if options.has("mountain_chains"): options.mountain_chains = 1400
	options.erase("forests")
	check(Generation.VERSION >= 23 and options.fruit_trees == 14 and options.other_trees == 16 and Generation.describe(options).contains("pommiers et noisetiers") and Generation.describe(options).contains("cinq tailles") and Generation.describe(options).contains("Pins sylvestres"), "generation 23: fruit trees, pines and lindens of five sizes, described in the world information")
	var terrain := terrain_for(SEED, options)
	var trees := all_trees(terrain)
	var again := all_trees(terrain_for(SEED, options))
	check(trees == again, "same seed, same trees (%d)" % trees.size())
	check(all_trees(terrain_for(SEED + 1, options)) != trees, "another seed, other trees")
	var kinds := [0, 0, 0, 0]
	var groups := {}
	var variants_ok := true
	for tree in trees:
		kinds[int(tree.espece)] += 1
		var area: String = str(tree.id).get_slice("_", 0) + "_" + str(tree.id).get_slice("_", 1)
		groups[area] = groups.get(area, 0) + 1
		variants_ok = variants_ok and int(tree.classe) >= 1 and int(tree.classe) <= Trees.SIZES
	check(trees.size() > 100 and trees.size() < 1500 and kinds[0] > 0 and kinds[1] > 0 and kinds[2] > 0 and kinds[3] > 0 and variants_ok, "a few trees only: %d apple trees, %d hazels, %d pines, %d lindens in a 512 m world" % kinds)
	check(groups.values().max() <= 3 and groups.values().has(1) and groups.values().has(3), "alone or in small groups of 2 to 3")
	# 0.0.6.11 (version 22) : cinq tailles, plus souvent la taille standard ; arbres d'un groupe à 5 m au moins.
	var by_size := [0, 0, 0, 0, 0]
	var spaced := true
	for tree in trees:
		by_size[int(tree.classe) - 1] += 1
		for other in trees:
			if other != tree and str(other.id).get_slice("_", 0) == str(tree.id).get_slice("_", 0) and str(other.id).get_slice("_", 1) == str(tree.id).get_slice("_", 1):
				spaced = spaced and Vector2(tree.x, tree.z).distance_to(Vector2(other.x, other.z)) >= SmoothTerrain.TREE_SPACING_BIG
	check(not by_size.has(0) and by_size[2] > by_size[0] and by_size[2] > by_size[4], "all five sizes, standard more common than the smallest and the biggest (%s)" % str(by_size))
	check(spaced, "trees of a group at least 5 m apart")
	var v21 := options.duplicate()
	v21.version = 21
	# 0.0.6.14 : réglages des montagnes d'avant la version 25.
	if v21.has("mountains"): v21.mountains = 850
	if v21.has("mountain_chains"): v21.mountain_chains = 1400
	v21.erase("other_trees")
	v21.erase("forests")
	var old_sizes := {}
	for tree in all_trees(terrain_for(SEED, v21)):
		old_sizes[int(tree.classe)] = true
	check(old_sizes.keys().all(func(size): return size in [2, 3, 4]) and old_sizes.size() == 3, "generation 21 worlds keep their three kinds (now sizes 2, 3, 4)")
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
		gentle = gentle and slope.length() <= (SmoothTerrain.PINE_SLOPE if int(tree.espece) == Trees.PINE else SmoothTerrain.TREE_SLOPE)
	check(dry, "no tree in a lake, a river or on its bank")
	check(sandless, "no tree on sand, mud, gravel, snow or stone: only on grass")
	check(gentle, "no tree on a steep slope (pines a little steeper)")
	# 0.0.6.12 (version 23) : pins surtout au pied des montagnes, tilleuls surtout ailleurs ; 7 m entre grands arbres d'un groupe.
	var near_mountains := [0, 0]
	var big_spaced := true
	for tree in trees:
		if int(tree.espece) >= Trees.PINE:
			if terrain._near_mountain_foot(Vector2(tree.x, tree.z)):
				near_mountains[int(tree.espece) - Trees.PINE] += 1
			for other in trees:
				if other != tree and str(other.id).begins_with("b") and str(other.id).get_slice("_", 0) == str(tree.id).get_slice("_", 0) and str(other.id).get_slice("_", 1) == str(tree.id).get_slice("_", 1):
					big_spaced = big_spaced and Vector2(tree.x, tree.z).distance_to(Vector2(other.x, other.z)) >= SmoothTerrain.BIG_TREE_SPACING
	check(near_mountains[0] > near_mountains[1] and near_mountains[0] * 2 > kinds[2], "pines mostly at the foot of mountains (%d of %d), lindens elsewhere" % [near_mountains[0], kinds[2]])
	check(big_spaced, "pines and lindens of a group at least 7 m apart")
	var v22 := options.duplicate()
	v22.version = 22
	# 0.0.6.14 : réglages des montagnes d'avant la version 25.
	if v22.has("mountains"): v22.mountains = 850
	if v22.has("mountain_chains"): v22.mountain_chains = 1400
	v22.erase("other_trees")
	v22.erase("forests")
	var v22_trees := all_trees(terrain_for(SEED, v22))
	check(v22_trees.all(func(tree): return int(tree.espece) < Trees.PINE) and v22_trees == trees.filter(func(tree): return int(tree.espece) < Trees.PINE), "generation 22 worlds keep exactly their fruit trees, without pines or lindens")
	# Anciens mondes : génération 20 sans arbre, relief identique.
	var old_options := options.duplicate()
	old_options.version = 20
	# 0.0.6.14 : réglages des montagnes d'avant la version 25.
	if old_options.has("mountains"): old_options.mountains = 850
	if old_options.has("mountain_chains"): old_options.mountain_chains = 1400
	old_options.erase("fruit_trees")
	old_options.erase("other_trees")
	old_options.erase("forests")
	var old := terrain_for(SEED, old_options)
	check(all_trees(old).is_empty(), "generation 20 worlds get no trees")
	var same := true
	for index in range(200):
		var column := Vector2i(index * 37 % 900 - 450, index * 53 % 900 - 450)
		same = same and old.ground_height(column) == terrain.ground_height(column) and old.surface_kind(column) == terrain.surface_kind(column)
	check(same, "the relief and the ground do not change with the trees")
	# 0.0.6.10 : modèles légers faits dans Blender (assets/trees) ; 0.0.6.11 : un modèle par taille, de plus en plus haut.
	var models_ok := true
	var heights := []
	for kind in [Trees.APPLE, Trees.HAZEL, Trees.PINE, Trees.LINDEN]:
		var last := 0.0
		for size in range(1, Trees.SIZES + 1):
			var near: ArrayMesh = Trees.mesh(kind, size)
			var far: ArrayMesh = Trees.mesh(kind, size, true)
			var high: float = near.get_aabb().size.y
			heights.append(snappedf(high, 0.1))
			models_ok = models_ok and near.get_surface_count() == (2 if kind == Trees.LINDEN else 3) and far.get_surface_count() >= 1 and Trees.triangles(near) < 15000 and Trees.triangles(far) * 5 < Trees.triangles(near) and high > last
			var leaves: StandardMaterial3D = near.surface_get_material(1)
			models_ok = models_ok and leaves.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and leaves.albedo_texture != null
			last = high
	check(models_ok, "Blender models, five sizes each, taller and taller, leaves with cut-out edges (%s m)" % str(heights))
	check(heights[2] > 7.0 and heights[2] < 8.0 and heights[7] > 5.3 and heights[7] < 6.3, "standard size: apple tree about 7.5 m, hazel about 5.8 m")
	check(heights[12] > 14.5 and heights[12] < 17.0 and heights[14] > 20.0 and heights[17] > 13.0 and heights[17] < 15.5, "pines 7 to 21 m (standard about 15 m), lindens 6 to 20 m (standard about 14 m)")
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
		var detail: MeshInstance3D = body.get_node("Modele/Detail")
		var far: MeshInstance3D = body.get_node("Modele/Loin")
		check(detail.visibility_range_end == Trees.DETAIL_END and far.visibility_range_begin == Trees.DETAIL_END and far.visibility_range_end == Trees.FAR_END, "detailed up to %d m, simplified up to %d m, then nothing" % [Trees.DETAIL_END, Trees.FAR_END])
		check(body.find_children("*", "CollisionShape3D", true, false).any(func(child): return child.shape is CylinderShape3D), "the trunk is solid")
		var ground: float = world.terrain.height_at(tree.x, tree.z)
		check(absf(body.position.y - ground) < 0.2, "standing on the ground")
		world.player.selected_type = world.PICKAXE
		var hit := {"collider": body, "position": body.position + Vector3(0, 1, 0), "normal": Vector3.RIGHT}
		check(not world.break_target(hit) and not world.place_target(hit, SmoothTerrain.DIRT) and is_instance_valid(body), "trees are not cut nor built on (series 0.0.6)")
	root.remove_child(world)
	world.free()
	# 0.0.6.21 (version 29, #177) : trois formes par espèce et taille ; la troisième des arbres à vrai tronc a un trou.
	var form_terrain := terrain_for(SEED, Generation.defaults())
	var form_counts := [0, 0, 0]
	for shaped in all_trees(form_terrain):
		form_counts[int(shaped.forme)] += 1
	check(Generation.VERSION >= 29 and form_counts.min() > 0 and form_counts.min() * 2 > form_counts.max(), "generation 29: three tree forms, about as many of each (%s)" % str(form_counts))
	check(all_trees(form_terrain) == all_trees(terrain_for(SEED, Generation.defaults())), "same seed, same tree forms")
	var form_old := Generation.defaults()
	form_old.version = 28
	check(all_trees(terrain_for(SEED, form_old)).all(func(tree): return not tree.has("forme")), "generation 28 worlds keep the first form only")
	var files_ok := true
	var holes_ok := true
	for kind in range(4):
		for size in range(1, 6):
			for form in range(3):
				files_ok = files_ok and ResourceLoader.exists(Trees._path(kind, size, false, form)) and ResourceLoader.exists(Trees._path(kind, size, true, form))
		var made: ArrayMesh = Trees.mesh(kind, 3, false, 2)
		var has_hole := false
		for surface in range(made.get_surface_count()):
			var look: StandardMaterial3D = made.surface_get_material(surface)
			has_hole = has_hole or look.albedo_color.is_equal_approx(Color(0.05, 0.035, 0.025))
		holes_ok = holes_ok and has_hole == (kind != Trees.HAZEL)
	check(files_ok and holes_ok, "Blender models for the three forms of every size; trunk hole on the third form of apple, pine and linden, not hazel")
	var formed: StaticBody3D = Trees.tree_body(Trees.LINDEN, 3, false, 1)
	check((formed.get_node("Modele/Detail") as MeshInstance3D).mesh == Trees.mesh(Trees.LINDEN, 3, false, 1), "a tree shows the model of its form")
	formed.free()
	print("RESULT: %d tree checks, %d failures" % [checks, failures])
	quit(failures)

func get_nodes_in_group_safe(group: String) -> Array:
	return Array(root.get_tree().get_nodes_in_group(group))
