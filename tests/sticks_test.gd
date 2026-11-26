extends SceneTree
# 0.0.7.26 (#212) : branches mortes au sol (génération 33) et rejets de noisetier : placés selon la graine, ramassés ou
# cassés, enregistrés ; qualités du bâton et note de manche.
const Generation = preload("res://scripts/world_generation.gd")
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
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

func _run() -> void:
	const SEED := 1864659616
	var terrain := SmoothTerrain.new()
	terrain.setup(SEED, [], Generation.defaults())
	check(Generation.VERSION >= 33, "generation 33 or later")
	var old_options := Generation.defaults()
	old_options.version = 32
	var old_terrain := SmoothTerrain.new()
	old_terrain.setup(SEED, [], old_options)
	# Une forêt et des zones hors forêt.
	var forest: Dictionary = terrain.forests()[0]
	var forest_zone := Vector2i(floori(forest.center.x / 8.0), floori(forest.center.y / 8.0))
	var in_forest := 0
	var forest_zones := 0
	var outside := 0
	var outside_zones := 0
	var hazel_shoots := 0
	var sample: Dictionary = {}
	for x in range(-12, 12):
		for z in range(-12, 12):
			var area := Vector2i(x, z) + forest_zone
			var branches: Array = terrain.dead_branches_in_zone(area)
			var center := (Vector2(area) + Vector2(0.5, 0.5)) * 8.0
			if not terrain.forest_at(center).is_empty():
				in_forest += branches.size()
				forest_zones += 1
			elif terrain.trees_in_zone(area).size() > 0:
				outside += branches.size()
				outside_zones += 1
			hazel_shoots += terrain.hazel_shoots_in_zone(area).size()
			if sample.is_empty() and not branches.is_empty():
				sample = branches[0]
	var forest_density := in_forest / maxf(forest_zones * 64.0, 1.0)
	var outside_density := outside / maxf(outside_zones * 64.0, 1.0)
	print("MESURE: forêt %d branches sur %d zones (une tous les %.1f m²), hors forêt %d sur %d zones avec arbres, %d rejets" % [in_forest, forest_zones, 1.0 / maxf(forest_density, 0.0001), outside, outside_zones, hazel_shoots])
	check(forest_density > 1.0 / 12.0 and forest_density > outside_density * 3.0, "many dead branches in forests, rare outside")
	check(hazel_shoots > 0, "straight shoots at the foot of hazels")
	check(not sample.is_empty() and sample.longueur >= 0.3 and sample.longueur <= 0.9 and sample.epaisseur >= 1.5 and sample.epaisseur <= 5.0, "a branch: 30 to 90 cm, 1.5 to 5 cm")
	check(terrain.dead_branches_in_zone(forest_zone) == terrain.dead_branches_in_zone(forest_zone), "same seed, same branches")
	check(old_terrain.dead_branches_in_zone(forest_zone).is_empty() and old_terrain.hazel_shoots_in_zone(forest_zone).is_empty(), "generation 32 worlds unchanged (no branches)")
	# Qualités et note de manche.
	var good := {"objet": "branche", "essence": 1, "longueur": 0.55, "epaisseur": 3.0}
	var bent := good.duplicate()
	bent.tordue = 1
	var pine := good.duplicate()
	pine.essence = 2
	check(Inventory.handle_quality(good) == 3 and Inventory.handle_quality(bent) == 0 and Inventory.handle_quality(pine) == 1, "handle: hazel excellent, bent bad, pine average")
	check(Inventory.item_name({"objet": "branche", "essence": 2, "morte": 1}) == "Branche morte de pin" and Inventory.item_name({"objet": "branche", "essence": 1, "rejet": 1}) == "Rejet de noisetier", "dead branch and shoot names")
	check(Inventory.wood_details(good).contains("manche excellent") and Inventory.wood_details(bent).contains("tordu"), "qualities shown in the details")
	# Dans le monde : branches posées autour du joueur, ramassées, enregistrées ; rejet cassé.
	var folder := "res://.godot/test-sticks-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	world.generation_options = Generation.defaults()
	world.terrain_seed = SEED
	world.save_folder = folder
	root.add_child(world)
	world.player.set_physics_process(false)
	var shoot_zone := Vector2i(999999, 0)
	for x in range(-30, 30):
		for z in range(-30, 30):
			if shoot_zone.x == 999999 and not world.terrain.hazel_shoots_in_zone(forest_zone + Vector2i(x, z)).is_empty():
				shoot_zone = forest_zone + Vector2i(x, z)
	var target := shoot_zone if shoot_zone.x != 999999 else forest_zone
	world.player.global_position = Vector3(target.x * 8.0 + 4.0, 40.0, target.y * 8.0 + 4.0)
	world.update_terrain_view(true, target)
	world.finish_terrain()
	world._refresh_sticks()
	while world._process_one_stick_column():
		pass
	var seeded: Array = world.ground.entries.filter(func(entry): return entry.item.has("graine"))
	check(seeded.size() > 0, "dead branches lie around the player (%d)" % seeded.size())
	check(world.ground.to_array().all(func(saved): return not saved.objet.has("graine")), "untouched seed branches are not saved one by one")
	var index: int = world.ground.entries.find(seeded[0])
	var id: String = seeded[0].item.graine
	var taken: Dictionary = world.ground.remove(index)
	check(world.picked_branches.has(id) and not taken.has("graine") and taken.morte == 1, "picked: remembered, a normal dead branch now")
	world.save_now()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("objets.json")))
	check(saved.get("branches_ramassees", []).has(id), "picked branches saved")
	world._hide_column_sticks(world._player_column())
	world._show_column_sticks(world._player_column())
	check(not world.ground.entries.any(func(entry): return entry.item.get("graine", "") == id), "a picked branch never comes back")
	# Recasser une branche morte : les deux longueurs montrées avant, bois mort vite, pourri plus vite, rejet vert lent.
	var lying: Dictionary = world.ground.entries.filter(func(entry): return entry.item.has("graine"))[0]
	world.player.global_position = (lying.position as Vector3) + Vector3(0.6, 0.0, 0.0)
	var aim := {"collider": world.ground.bodies[world.ground.entries.find(lying)], "position": lying.position}
	var hint: String = world.ground_wood_hint(aim)
	check(hint.begins_with("Casser ici : ") and hint.contains(" cm et "), "aiming a stick on the ground shows both lengths: " + hint)
	var dead := {"objet": "branche", "morte": 1}
	var rotten := {"objet": "branche", "morte": 1, "pourrie": 1}
	var green := {"objet": "branche", "rejet": 1}
	var living := {"objet": "branche"}
	check(world.ground_wood_seconds(rotten, 0.1) < world.ground_wood_seconds(dead, 0.1) and world.ground_wood_seconds(dead, 0.1) < world.ground_wood_seconds(living, 0.1) and world.ground_wood_seconds(living, 0.1) < world.ground_wood_seconds(green, 0.1), "rotten < dead < living < green shoot to break")
	var lying_id: String = lying.item.graine
	check(world.split_wood(world.ground.entries.find(lying), lying.position) and world.picked_branches.has(lying_id) and world.ground.entries.slice(-2).all(func(entry): return entry.item.get("morte", 0) == 1 and not entry.item.has("graine")), "broken in two: two dead halves, the branch counts as taken")
	var shoots: Array = get_nodes_in_group("shoots")
	check(not shoots.is_empty(), "shoots standing near the player (%d)" % shoots.size())
	if not shoots.is_empty():
		var shoot: Node3D = shoots[0]
		var shoot_id: String = shoot.get_meta("shoot").id
		var before: int = world.ground.entries.size()
		var done := false
		for step in range(200):
			done = world._step_break_shoot(1.0 / 60.0, shoot)
			if done:
				break
		check(done and world.broken_shoots.has(shoot_id) and world.ground.entries.size() == before + 1 and world.ground.entries[-1].item.get("rejet", 0) == 1, "a shoot breaks after about 2 s held, falls to the ground (Rejet de noisetier)")
	root.remove_child(world)
	world.free()
	print("RESULT: %d sticks checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
