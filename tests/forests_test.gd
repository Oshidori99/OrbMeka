extends SceneTree
# 0.0.6.13 (#138, génération 24) : forêts. Pinèdes au pied des montagnes, feuillus en plaine ; moyennement grandes et
# nombreuses (environ un cinquième du sol) ; arbres serrés au cœur, plus rares et plus petits en lisière, arbres fruitiers
# et noisetiers en lisière des feuillus ; clairières dans les grandes ; arbres isolés hors des forêts ; mondes anciens inchangés.
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
const Generation = preload("res://scripts/world_generation.gd")
const Trees = preload("res://scripts/trees.gd")
const SEED := 1755064997
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
	check(Generation.VERSION == 24 and options.forests == 230 and Generation.describe(options).contains("Forêts"), "generation 24: forests setting, described in the world information")
	var terrain := terrain_for(SEED, options)
	var started := Time.get_ticks_msec()
	var trees := all_trees(terrain)
	print("Arbres du monde en %d ms" % (Time.get_ticks_msec() - started))
	var forests: Array = terrain.forests()
	var kinds := [0, 0]
	var sizes_ok := true
	for forest in forests:
		kinds[forest.kind] += 1
		sizes_ok = sizes_ok and forest.radius >= 25.0 and forest.radius <= 40.0
	check(forests.size() >= 12 and forests.size() <= 26 and kinds[0] > 0 and kinds[1] > 0 and sizes_ok, "%d forests of 25 to 40 m: %d pine woods, %d broadleaf woods" % [forests.size(), kinds[0], kinds[1]])
	check(all_trees(terrain_for(SEED, options)) == trees, "same seed, same forests and trees (%d trees)" % trees.size())
	# Part du sol en forêt.
	var inside := 0
	var samples := 0
	for x in range(-250, 250, 5):
		for z in range(-250, 250, 5):
			samples += 1
			if not terrain.forest_at(Vector2(x, z)).is_empty():
				inside += 1
	var share := float(inside) / samples
	check(share > 0.10 and share < 0.32, "forests cover about a fifth of the ground (%d %%)" % roundi(share * 100.0))
	# Arbres des forêts : espèces, densité, lisières, clairières.
	var pine_wood_ok := true
	var core_kinds := [0, 0, 0, 0]
	var edge_kinds := [0, 0, 0, 0]
	var core_count := 0
	var edge_count := 0
	var core_sizes := 0.0
	var edge_sizes := 0.0
	var clearing_ok := true
	var isolated_outside := true
	for tree in trees:
		var at := Vector2(tree.x, tree.z)
		if not str(tree.id).begins_with("f"):
			isolated_outside = isolated_outside and terrain.forest_at(at).is_empty()
			continue
		var forest: Dictionary = forests[int(tree.foret)]
		var depth: float = terrain.forest_depth(at, forest)
		if forest.kind == SmoothTerrain.FOREST_PINE:
			pine_wood_ok = pine_wood_ok and int(tree.espece) == Trees.PINE
		elif depth >= 0.22:
			core_kinds[int(tree.espece)] += 1
		else:
			edge_kinds[int(tree.espece)] += 1
		if depth >= 0.5:
			core_count += 1
			core_sizes += int(tree.classe)
		elif depth < 0.22:
			edge_count += 1
			edge_sizes += int(tree.classe)
		for clearing in forest.clearings:
			if at.distance_to(clearing.center) < clearing.radius:
				clearing_ok = clearing_ok and clearing.lone and int(tree.classe) == 5
	check(pine_wood_ok, "pine woods hold only pines")
	check(core_kinds[Trees.LINDEN] > core_kinds[Trees.HAZEL] and core_kinds[Trees.HAZEL] > 0 and core_kinds[Trees.APPLE] == 0, "broadleaf woods: lindens with hazel undergrowth (%s)" % str(core_kinds))
	check(edge_kinds[Trees.APPLE] > 0 and edge_kinds[Trees.HAZEL] > edge_kinds[Trees.LINDEN], "broadleaf edges: hazels, apple trees and a few small lindens (%s)" % str(edge_kinds))
	check(core_count > 0 and edge_count > 0 and core_sizes / core_count > edge_sizes / edge_count + 1.0, "big trees in the heart, small ones at the edge (%.1f against %.1f)" % [core_sizes / maxf(1, core_count), edge_sizes / maxf(1, edge_count)])
	var core_area := 0.0
	var edge_area := 0.0
	for x in range(-250, 250, 2):
		for z in range(-250, 250, 2):
			var found: Dictionary = terrain.forest_at(Vector2(x, z))
			if not found.is_empty():
				if found.depth >= 0.5:
					core_area += 4.0
				elif found.depth < 0.22:
					edge_area += 4.0
	check(core_count / core_area > edge_count / edge_area * 1.3, "trees closer together in the heart than at the edge")
	check(clearing_ok and forests.any(func(forest): return not forest.clearings.is_empty()), "clearings in the big forests, empty or with one big tree")
	check(isolated_outside, "isolated trees stay outside the forests")
	check(trees.size() < 3500, "still light enough: %d trees in a 512 m world" % trees.size())
	# Mondes anciens : génération 23 sans forêt.
	var old_options := options.duplicate()
	old_options.version = 23
	old_options.erase("forests")
	var old := terrain_for(SEED, old_options)
	check(old.forests().is_empty() and all_trees(old).all(func(tree): return not str(tree.id).begins_with("f")), "generation 23 worlds get no forests")
	print("RESULT: %d forest checks, %d failures" % [checks, failures])
	quit(failures)
