extends SceneTree
# 0.0.7.21 : garde-fou de vitesse (demande de l'utilisateur : rester au-dessus de 100 images par seconde quand le jeu
# grandit). Sans fenêtre (pas de carte graphique) : seulement le calcul. En traversant une forêt, le travail de fond
# (terrain, arbres, lointain) reste dans son budget par image, aucune tâche ne bloque une image, et le monde suit
# (colonnes proches construites). Marges larges : l'Action GitHub calcule 2 à 3 fois moins vite qu'un PC.
const Generation = preload("res://scripts/world_generation.gd")
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
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	world.generation_options = Generation.defaults()
	world.terrain_seed = 1864659616
	world.world_name = "garde-fou"
	root.add_child(world)
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	# La forêt la plus proche (de pins si possible), traversée à 10 m/s (une image = 1/60 s).
	var nearest := {}
	for forest in world.terrain.forests():
		var distance: float = (forest.center as Vector2).length() - (10000.0 if forest.kind == world.terrain.FOREST_PINE else 0.0)
		if nearest.is_empty() or distance < nearest.distance:
			nearest = {"forest": forest, "distance": distance}
	var forest: Dictionary = nearest.forest
	var from := Vector3(forest.center.x - forest.radius - 10.0, 0.0, forest.center.y)
	player.global_position = Vector3(from.x, world.terrain.height_at(from.x, from.z) + 2.0, from.z)
	for frame in range(120):
		await process_frame
	Engine.max_fps = 100
	var budget: int = world.work_budget()
	world.perf = {}
	world.perf_on = true
	var unbuilt_frames := 0
	var frames := 600
	for frame in range(frames):
		var x: float = from.x + frame * 10.0 / 60.0
		player.global_position = Vector3(x, world.terrain.height_at(x, from.z) + 1.0, from.z)
		await process_frame
		var here: Vector2i = world._player_column()
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				if world.shown_columns.has(here + Vector2i(dx, dz)) and not world.built_columns.has(here + Vector2i(dx, dz)):
					unbuilt_frames += 1
	world.perf_on = false
	var work: Dictionary = world.perf.get("travail_de_fond", {"max": 0.0, "total": 0.0})
	var slowest := ""
	var slowest_ms := 0.0
	for name in world.perf:
		if name != "travail_de_fond" and world.perf[name].max > slowest_ms:
			slowest_ms = world.perf[name].max
			slowest = name
	print("MESURE: budget %.1f ms, travail de fond moyen %.2f ms, max %.1f ms ; tâche la plus longue : %s %.1f ms" % [budget / 1000.0, work.total / frames, work.max, slowest, slowest_ms])
	check(budget == 5000, "100 images par seconde au plus : 5 ms de travail de fond par image")
	check(work.total / frames < budget / 1000.0 * 1.5, "background work stays within its budget on average (%.2f ms)" % (work.total / frames))
	check(work.max < 45.0, "no background work blocks an image (%.1f ms at most)" % work.max)
	check(slowest_ms < 45.0, "no task blocks an image (%s: %.1f ms)" % [slowest, slowest_ms])
	check(unbuilt_frames < frames / 20, "the world keeps up at 10 m/s (columns around not ready: %d frames)" % unbuilt_frames)
	print("RESULT: %d perf guard checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
