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
	check(Generation.VERSION >= 24 and options.forests == 230 and Generation.describe(options).contains("Forêts"), "generation 24: forests setting, described in the world information")
	var terrain := terrain_for(SEED, options)
	var started := Time.get_ticks_msec()
	var trees := all_trees(terrain)
	print("Arbres du monde en %d ms" % (Time.get_ticks_msec() - started))
	var forests: Array = terrain.forests()
	var kinds := [0, 0, 0]
	var sizes_ok := true
	for forest in forests:
		kinds[forest.kind] += 1
		sizes_ok = sizes_ok and forest.radius >= 25.0 and forest.radius <= 40.0
	check(forests.size() >= 12 and forests.size() <= 26 and kinds[0] > 0 and kinds[1] > 0 and sizes_ok, "%d forests of 25 to 40 m: %d pine woods, %d broadleaf woods, %d wild orchards" % [forests.size(), kinds[0], kinds[1], kinds[2]])
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
		elif forest.kind == SmoothTerrain.FOREST_ORCHARD:
			continue
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
	check(edge_kinds[Trees.APPLE] > 0 and edge_kinds[Trees.HAZEL] + edge_kinds[Trees.APPLE] > edge_kinds[Trees.LINDEN], "broadleaf edges: hazels, apple trees and a few small lindens (%s)" % str(edge_kinds))
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
	# 0.0.6.14 (version 25, #184) : montagnes plus grandes et plus douces ; pins plus haut sur leurs pentes.
	var mountain_slopes := []
	var heights := []
	for version in [24, 25]:
		var mountain_options := Generation.defaults()
		if version == 24:
			mountain_options.version = 24
			mountain_options.mountains = 850
			mountain_options.mountain_chains = 1400
		var land := terrain_for(2114718997, mountain_options)
		var total := 0.0
		var count := 0
		for x in range(-250, 250, 5):
			for z in range(-250, 250, 5):
				if land.mountain_lift(Vector2(x, z)) > 1.0:
					var c := Vector2i(x * 2, z * 2)
					total += Vector2(land.ground_height(c + Vector2i(2, 0)) - land.ground_height(c - Vector2i(2, 0)), land.ground_height(c + Vector2i(0, 2)) - land.ground_height(c - Vector2i(0, 2))).length() / 2.0
					count += 1
		mountain_slopes.append(total / maxf(1, count))
		heights.append(land._all_mountains().filter(func(found): return not found.get("sand", false)).map(func(found): return found.height).max())
	check(mountain_slopes[1] < mountain_slopes[0] * 0.9 and heights[1] > heights[0] and heights[1] <= 36.0, "generation 25: bigger mountains (up to %.0f m) with gentler slopes (%.2f against %.2f)" % [heights[1], mountain_slopes[1], mountain_slopes[0]])
	# 0.0.6.15 (version 26, #181) : sol d'aiguilles sous les pinèdes, vergers sauvages en plaine.
	var orchards := forests.filter(func(forest): return forest.kind == SmoothTerrain.FOREST_ORCHARD)
	var orchard_ok := not orchards.is_empty()
	var orchard_trees := 0
	for tree in trees:
		if str(tree.id).begins_with("f") and forests[int(tree.foret)].kind == SmoothTerrain.FOREST_ORCHARD:
			orchard_trees += 1
			orchard_ok = orchard_ok and int(tree.espece) in [Trees.APPLE, Trees.HAZEL]
	check(orchard_ok and orchard_trees > 0, "wild orchards: %d of %d forests, %d apple trees and hazels only" % [orchards.size(), forests.size(), orchard_trees])
	var litter := 0
	var litter_outside := 0
	for x in range(-250, 250, 3):
		for z in range(-250, 250, 3):
			var column := Vector2i(x * 2, z * 2)
			var top := Vector3i(column.x, floori(terrain.ground_height(column) / SmoothTerrain.STEP), column.y)
			if terrain.natural_kind(top) == SmoothTerrain.NEEDLES:
				var found: Dictionary = terrain.forest_at(Vector2(x, z))
				if found.is_empty() or found.forest.kind != SmoothTerrain.FOREST_PINE:
					litter_outside += 1
				else:
					litter += 1
	check(litter > 0 and litter_outside == 0 and terrain.natural_kind(Vector3i(0, -6, 0)) != SmoothTerrain.NEEDLES, "pine needles on the ground of pine woods only, a thin layer over the dirt")
	var v25 := options.duplicate()
	v25.version = 25
	var older := terrain_for(SEED, v25)
	check(not older.needle_floor(Vector2i(0, 0)) and older.forests().all(func(forest): return forest.kind != SmoothTerrain.FOREST_ORCHARD), "generation 25 worlds keep their ground and their forests")
	print("RESULT: %d forest checks, %d failures" % [checks, failures])
	quit(failures)
