extends SceneTree
# 0.0.7.20 : la surface d'une zone calculée en petites étapes (surface_job.gd, une par image dans le jeu) est exactement
# celle calculée d'un coup, quel que soit le découpage, terrain creusé, posé et grottes compris ; aucune étape ne dure
# plus de quelques millisecondes (avant : 27 à 100 ms d'un bloc, les à-coups en forêt). Vérifié au sommet près contre
# l'ancien calcul lors de sa mise en place (243 zones identiques).
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
const Generation = preload("res://scripts/world_generation.gd")
const SurfaceJob = preload("res://scripts/surface_job.gd")
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
	var terrain := SmoothTerrain.new()
	terrain.setup(1864659616, [[Vector2(0.5, 0.5), 9.0]], Generation.defaults())
	for x in range(3):
		terrain.set_density(Vector3i(40 + x, -2, 40), SmoothTerrain.DUG)
		terrain.set_density(Vector3i(40 + x, 0, 41), 0.5, SmoothTerrain.SAND)
	var zones := [Vector3i(2, -1, 2), Vector3i(2, 0, 2)]
	for forest in terrain.forests().slice(0, 2):
		var base := Vector2i(floori(forest.center.x / 8.0), floori(forest.center.y / 8.0))
		for dx in range(-1, 2):
			for zone: Vector3i in terrain.surface_zones(base + Vector2i(dx, 0), base + Vector2i(dx, 0)):
				zones.append(zone)
	var caves: Array = terrain.cave_zones_near(Vector2i(0, 0), 6).slice(0, 12)
	zones.append_array(caves)
	terrain.zone_surface(zones[0])
	var same := 0
	var longest := 0.0
	var faces := 0
	for zone: Vector3i in zones:
		var whole: Array = terrain.zone_surface(zone)
		faces += whole[6].size()
		for budget in [1, 2000]:
			var job := SurfaceJob.new(terrain, zone)
			while not job.done:
				var at := Time.get_ticks_usec()
				job.step(budget)
				if budget == 2000:
					longest = maxf(longest, (Time.get_ticks_usec() - at) / 1000.0)
			var equal := whole.size() == job.result.size()
			for index in range(mini(whole.size(), job.result.size())):
				equal = equal and whole[index] == job.result[index]
			if equal:
				same += 1
	check(not caves.is_empty() and faces > 0, "zones with caves and surfaces to compare (%d zones)" % zones.size())
	check(same == zones.size() * 2, "step by step = all at once, whatever the steps (%d of %d)" % [same, zones.size() * 2])
	check(longest < 15.0, "no step longer than a few milliseconds (%.1f ms)" % longest)
	# 0.0.7.20 : choix des lacs et rivières de la graine en petites étapes (vitrine de l'accueil) = d'un coup.
	for seed in [3652994865, 1864659616]:
		var whole_seed := SmoothTerrain.new()
		whole_seed.setup(seed, [], Generation.defaults())
		var stepped := SmoothTerrain.new()
		stepped.setup(seed, [], Generation.defaults(), false)
		var steps := 0
		var slowest := 0.0
		while true:
			var at := Time.get_ticks_usec()
			var finished := stepped.prepare_step(1)
			slowest = maxf(slowest, (Time.get_ticks_usec() - at) / 1000.0)
			steps += 1
			if finished:
				break
		var same_heights := true
		for point in [Vector2(0, 0), Vector2(120.5, -40.0), Vector2(-300.0, 250.0), Vector2(6.5, 6.0)]:
			same_heights = same_heights and whole_seed.height_at(point.x, point.y) == stepped.height_at(point.x, point.y)
		check(str(whole_seed.rivers()) == str(stepped.rivers()) and str(whole_seed._lakes_chosen) == str(stepped._lakes_chosen) and str(whole_seed._lake_drops) == str(stepped._lake_drops) and same_heights, "seed %d: lakes and rivers prepared step by step = all at once (%d rivers, %d steps)" % [seed, stepped.rivers().size(), steps])
		whole_seed._crevasses_near(Vector2i.ZERO)
		whole_seed.caves_in_zone(Vector3i.ZERO)
		var cave_zones: Array = whole_seed.cave_zones_near(Vector2i(0, 0), 8).slice(0, 6)
		var same_caves := str(whole_seed._all_mountains()) == str(stepped._all_mountains()) and str(whole_seed._crevasse_zones) == str(stepped._crevasse_zones) and str(whole_seed._cave_zones) == str(stepped._cave_zones)
		for zone: Vector3i in cave_zones:
			same_caves = same_caves and whole_seed.zone_surface(zone) == stepped.zone_surface(zone)
		check(same_caves and not cave_zones.is_empty(), "seed %d: mountains, crevasses and caves step by step = all at once" % seed)
		print("seed %d: longest preparation step %.1f ms" % [seed, slowest])
		var finished_by_rivers := SmoothTerrain.new()
		finished_by_rivers.setup(seed, [], Generation.defaults(), false)
		finished_by_rivers.prepare_step(1)
		check(str(finished_by_rivers.rivers()) == str(whole_seed.rivers()), "seed %d: rivers() finishes a started preparation" % seed)
	print("RESULT: %d surface job checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
