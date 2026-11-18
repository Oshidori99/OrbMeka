extends SceneTree
# 0.0.7.22 (demande de l'utilisateur) : sol pas encore construit devant : on s'arrête au bord, sans tomber ; la colonne
# passe en tête de la file ; on repart dès qu'elle est prête.
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
	world.world_name = "bord"
	root.add_child(world)
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	world.finish_terrain()
	for frame in range(10):
		await process_frame
	world.finish_terrain()
	# La colonne à l'est du joueur fait comme si elle n'était pas encore construite.
	var here: Vector2i = world._player_column()
	var east := here + Vector2i(1, 0)
	check(world.built_columns.has(east) and world.ground_ready(Vector3(east.x * 8.0 + 4.0, 0.0, here.y * 8.0 + 4.0)), "a built column is ready")
	world.built_columns.erase(east)
	# Monde en pause : la colonne reste « pas prête » le temps des vérifications (sinon, construite en quelques images).
	world.set_process(false)
	var edge: float = east.x * 8.0
	player.global_position = Vector3(edge - 3.0, world.terrain.height_at(edge - 3.0, here.y * 8.0 + 4.0) + 0.1, here.y * 8.0 + 4.0)
	player.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	for frame in range(120):
		await physics_frame
		player.step_movement(1.0 / 60.0, Vector2(0, -1), false)
	check(player.global_position.x < edge - player.LOADED_MARGIN + 0.2 and player.global_position.x > edge - 2.0, "walking toward a column not built yet: stops at its edge (%.2f m before)" % (edge - player.global_position.x))
	check(world.terrain_queue.size() > 0 and world.terrain_queue[0] == east, "the awaited column goes first in the queue")
	check(player.ground_wait > player.LOADED_NOTICE_AFTER and world.notice == "Chargement du terrain…", "after a moment: « Chargement du terrain… »")
	# Sur une colonne pas prête : on ne tombe pas.
	var inside := Vector3(east.x * 8.0 + 4.0, 0.0, here.y * 8.0 + 4.0)
	player.global_position = Vector3(inside.x, world.terrain.height_at(inside.x, inside.z) + 3.0, inside.z)
	var height: float = player.global_position.y
	for frame in range(30):
		await physics_frame
		player.step_movement(1.0 / 60.0, Vector2.ZERO, false)
	check(absf(player.global_position.y - height) < 0.01 and player.held_here, "standing over a column not built yet: no fall, waiting in place")
	# Prête : on repart, sans chute brutale.
	world.built_columns[east] = true
	for frame in range(20):
		await physics_frame
		player.step_movement(1.0 / 60.0, Vector2.ZERO, false)
	check(not player.held_here and player.velocity.y > -world.player.gravity * 0.5, "once built: moves again, no stored fall speed (%.1f m/s)" % player.velocity.y)
	player.global_position = Vector3(edge - 3.0, world.terrain.height_at(edge - 3.0, inside.z) + 0.1, inside.z)
	for frame in range(90):
		await physics_frame
		player.step_movement(1.0 / 60.0, Vector2(0, -1), false)
	check(player.global_position.x > edge + 1.0, "built: walks into it")
	print("RESULT: %d loaded edge checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
