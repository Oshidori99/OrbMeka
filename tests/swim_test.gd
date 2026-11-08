extends SceneTree
# 0.0.6.8 : nager. Dans un lac profond, le joueur remonte et flotte les yeux hors de l'eau ; Se baisser plonge,
# Sauter remonte, on avance plus lentement qu'à pied ; hors de l'eau, on ne nage pas ; une rivière pousse vers l'aval.
# 0.0.6.8 aussi : aucune zone de terrain oubliée (on voyait à travers les montagnes là où un sommet manquait).
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
const Settings = preload("res://scripts/user_settings.gd")
const DELTA := 1.0 / 60.0
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

func swim(player: CharacterBody3D, direction: Vector2, stroke: float, frames: int) -> void:
	for index in range(frames):
		await physics_frame
		player.step_swim(DELTA, direction, stroke, player.water_depth())

func _run() -> void:
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	world.generation_options = load("res://scripts/world_generation.gd").defaults()
	world.terrain_seed = 42
	root.add_child(world)
	await process_frame
	var terrain = world.terrain
	var player: CharacterBody3D = world.player
	player.apply_settings(Settings.default_values())
	# Un lac de plaine d'au moins 2,5 m de fond en son centre.
	var lake := {}
	var center := Vector2.ZERO
	for r in range(10, 250, 4):
		for angle in range(0, 360, 15):
			var found: Dictionary = terrain.lake_at(Vector2.from_angle(deg_to_rad(angle)) * r)
			if lake.is_empty() and not found.is_empty() and not found.has("on_mountain"):
				var middle: Vector2 = (found.start + found.end) / 2.0
				var bottom: float = terrain.ground_height(Vector2i(roundi(middle.x / 0.5), roundi(middle.y / 0.5)))
				if terrain.lake_level(found) - bottom > 2.5:
					lake = found
					center = middle
	check(not lake.is_empty(), "a deep plains lake to swim in")
	if lake.is_empty():
		quit(1)
		return
	var level: float = terrain.lake_level(lake)
	world.update_terrain_view(true, Vector2i(floori(center.x / 8.0), floori(center.y / 8.0)))
	world.finish_terrain()
	# Lâché au fond du lac, sans rien toucher : on remonte et on flotte.
	player.position = Vector3(center.x, terrain.ground_height(Vector2i(roundi(center.x / 0.5), roundi(center.y / 0.5))) + 0.2, center.y)
	player.velocity = Vector3.ZERO
	for index in range(300):
		await physics_frame
	var depth: float = player.water_depth()
	check(player.swimming, "deep water: the player swims")
	check(absf(depth - player.FLOAT_DEPTH) < 0.12 and player.position.y + player.eye_height > level, "floats at the surface, eyes out of the water (feet %.2f m under)" % depth)
	player.set_physics_process(false)
	# Se baisser : plonger ; Sauter : remonter.
	var before := player.position.y
	await swim(player, Vector2.ZERO, -1.0, 40)
	check(player.position.y < before - 0.8, "Se baisser dives (%.2f m)" % (before - player.position.y))
	before = player.position.y
	await swim(player, Vector2.ZERO, 1.0, 60)
	check(player.position.y > before + 0.5, "Sauter swims up (%.2f m)" % (player.position.y - before))
	await swim(player, Vector2.ZERO, 0.0, 120)
	# Nager : plus lent qu'à pied, le regard à l'horizontale ne fait pas plonger.
	player.rotation = Vector3.ZERO
	player.camera.rotation.x = 0.0
	var start := player.position
	await swim(player, Vector2(0, -1), 0.0, 60)
	var speed := Vector2(player.position.x - start.x, player.position.z - start.z).length()
	check(speed > 1.8 and speed < player.walk_forward, "swimming slower than walking (%.2f m/s)" % speed)
	check(absf(player.position.y - start.y) < 0.15, "swimming forward stays at the surface")
	# Regarder en bas en avançant : plonger.
	player.camera.rotation.x = -0.8
	before = player.position.y
	await swim(player, Vector2(0, -1), 0.0, 40)
	check(player.position.y < before - 0.5, "looking down while swimming forward dives")
	player.camera.rotation.x = 0.0
	# Sur la terre ferme : pas de nage.
	player.position = Vector3(0.5, 0.1, 0.5)
	player.set_physics_process(true)
	await physics_frame
	await physics_frame
	check(not player.swimming and player.wade == 1.0, "on dry land: no swimming, normal speed")
	player.set_physics_process(false)
	# Rivière : le courant pousse vers l'aval.
	var rivers: Array = terrain.rivers()
	check(not rivers.is_empty(), "this world has a river")
	if not rivers.is_empty():
		var river: Dictionary = rivers[0]
		var middle: int = river.points.size() / 2
		var a: Vector2 = river.points[middle]
		var b: Vector2 = river.points[middle + 1]
		var push: Vector2 = world.water_current((a + b) / 2.0)
		check(push.length() > 0.5 and push.dot(b - a) > 0.0, "the river current pushes downstream (%.2f m/s)" % push.length())
		check(world.water_current((a + b) / 2.0 + (b - a).orthogonal().normalized() * 30.0) == Vector2.ZERO, "no current away from the river")
	# Toutes les zones où passe le sol sont construites (avant : sommets oubliés, on voyait à travers).
	var half: int = 12
	var zones: Dictionary = terrain.surface_zones(Vector2i(-half, -half), Vector2i(half - 1, half - 1))
	var missing := 0
	for x in range(-half, half):
		for z in range(-half, half):
			var heights: Vector2 = terrain.zone_heights(Vector3i(x, 0, z))
			for y in range(floori((heights.x - 0.5) / 8.0), floori((heights.y + 0.5) / 8.0) + 1):
				if not zones.has(Vector3i(x, y, z)):
					missing += 1
	check(missing == 0, "every zone the ground passes through is drawn (%d missing)" % missing)
	root.remove_child(world)
	world.free()
	print("RESULT: %d swim checks, %d failures" % [checks, failures])
	quit(failures)
