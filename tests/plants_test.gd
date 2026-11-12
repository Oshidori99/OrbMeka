extends SceneTree
# 0.0.6.16 (#182, génération 27) : plantes à fibres et lianes. Orties en lisière et au bord de l'eau, lin et herbes longues
# dans les prairies, jamais dans l'eau, le sable ou sous les pins ; lianes sur des tilleuls des forêts de feuillus ;
# images faites dans Blender ; dessinées en peu de dessins ; même graine = mêmes plantes ; mondes anciens sans plantes.
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
const Generation = preload("res://scripts/world_generation.gd")
const Plants = preload("res://scripts/plants.gd")
const Trees = preload("res://scripts/trees.gd")
const SEED := 2114718997
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

func terrain_for(options: Dictionary) -> RefCounted:
	var terrain := SmoothTerrain.new()
	terrain.setup(SEED, [[Vector2(0.5, 0.5), 9.0]], options)
	return terrain

func plants_of(terrain: RefCounted) -> Array:
	var result := []
	for x in range(-12, 12):
		for z in range(-12, 12):
			result.append_array(terrain.plants_in_zone(Vector2i(x, z)))
	return result

func _run() -> void:
	var options := Generation.defaults()
	check(Generation.VERSION >= 27 and Generation.describe(options).contains("Plantes à fibres"), "generation 27: fibre plants, described in the world information")
	var terrain := terrain_for(options)
	var plants := plants_of(terrain)
	check(plants == plants_of(terrain_for(options)), "same seed, same plants (%d)" % plants.size())
	var kinds := [0, 0, 0]
	var place_ok := true
	var nettle_spot := true
	var flax_spot := true
	for plant in plants:
		kinds[int(plant.plante)] += 1
		var at := Vector2(plant.x, plant.z)
		var column := Vector2i(roundi(at.x / SmoothTerrain.STEP), roundi(at.y / SmoothTerrain.STEP))
		place_ok = place_ok and not terrain.is_desert(at) and terrain.surface_kind(column) in [-1, SmoothTerrain.DIRT] and not terrain.needle_floor(column) and terrain.water_level_at(at) < terrain.ground_height(column) - 0.1
		var found: Dictionary = terrain.forest_at(at)
		if int(plant.plante) == Plants.FLAX:
			flax_spot = flax_spot and (found.is_empty() or not found.forest.clearings.is_empty())
	check(kinds[0] > 20 and kinds[1] > 20 and kinds[2] > 20, "nettles, flax and tall grass all grow (%s)" % str(kinds))
	check(place_ok, "never in water, sand, mud, gravel, snow, stone or on pine needles")
	check(flax_spot, "flax in meadows and clearings, not under the trees")
	# Orties : près des lisières de feuillus ou de l'eau (à la tache près).
	var near := 0
	for plant in plants:
		if int(plant.plante) != Plants.NETTLE:
			continue
		var at := Vector2(plant.x, plant.z)
		var ok := false
		for dx in [-2.0, 0.0, 2.0]:
			for dz in [-2.0, 0.0, 2.0]:
				var probe := at + Vector2(dx, dz)
				var found: Dictionary = terrain.forest_at(probe)
				ok = ok or (not found.is_empty() and found.forest.kind != SmoothTerrain.FOREST_PINE)
		for lake in terrain._lakes_near(at):
			ok = ok or terrain._lake_distance(at, lake) < lake.radius + lake.get("bank", 0.0) + 9.0
		if terrain._rivers_on:
			var river: Dictionary = terrain.river_near(at)
			ok = ok or (not river.is_empty() and river.distance < river.width + SmoothTerrain.RIVER_BANK + 8.0)
		if ok:
			near += 1
	check(near * 10 >= kinds[0] * 9, "nettles at forest edges and near water (%d of %d)" % [near, kinds[0]])
	# Lianes : seulement sur des tilleuls du cœur des forêts de feuillus.
	var vines := 0
	var vines_ok := true
	for x in range(-32, 32):
		for z in range(-32, 32):
			for tree in terrain.trees_in_zone(Vector2i(x, z)):
				if tree.get("liane", false):
					vines += 1
					vines_ok = vines_ok and int(tree.espece) == Trees.LINDEN and terrain.forests()[int(tree.foret)].kind == SmoothTerrain.FOREST_BROADLEAF
	check(vines > 5 and vines_ok, "vines on lindens of broadleaf woods only (%d)" % vines)
	# Affichage : trois sortes en plaques avec image découpée, une MultiMesh par sorte ; liane enroulée.
	var nodes: Array = Plants.column_nodes(plants.slice(0, 40), func(x, z): return 0.0)
	var images_ok := true
	for kind in range(3):
		var made: ArrayMesh = Plants.mesh(kind)
		var material: StandardMaterial3D = made.surface_get_material(0)
		images_ok = images_ok and material.albedo_texture != null and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and made.surface_get_array_len(0) == 18
	check(images_ok and nodes.all(func(node): return node is MultiMeshInstance3D and node.visibility_range_end == Plants.VIEW_END), "Blender images on crossed cards, one MultiMesh per kind, shown up to %d m" % Plants.VIEW_END)
	var body := Trees.tree_body(Trees.LINDEN, 3, true)
	var vine: MeshInstance3D = body.get_node("Modele/Liane")
	check(vine != null and vine.mesh.get_aabb().size.y > 3.0 and vine.mesh.get_aabb().size.x < 1.2, "the vine winds around the trunk")
	body.free()
	for node in nodes:
		node.free()
	# Mondes anciens : pas de plantes ni de lianes.
	var old_options := options.duplicate()
	old_options.version = 26
	var old := terrain_for(old_options)
	check(plants_of(old).is_empty() and old.trees_in_zone(Vector2i(0, 0)).all(func(tree): return not tree.has("liane")), "generation 26 worlds get no plants nor vines")
	print("RESULT: %d plant checks, %d failures" % [checks, failures])
	quit(failures)
