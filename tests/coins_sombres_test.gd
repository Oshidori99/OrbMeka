extends SceneTree
# 0.0.8.52 (lot Ombres, partie 2) : coins assombris du terrain (surface_job.gd, CUSTOM1) :
# - sol de la graine sans grotte ni changement : rien d'assombri (aucun calcul) ;
# - une salle creusée : ses coins (sol contre mur) assombris, le milieu du sol presque pas ;
# - deux zones voisines donnent la même valeur à leurs sommets communs (pas de couture) ;
# - une zone lit les points de son coin − 3 à son coin + 18 (zones_using) ;
# - l'occlusion à l'écran (SSAO) seulement avec les ombres « Loin » (Beauté) sur PC.
const Generation = preload("res://scripts/world_generation.gd")
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
const WorldScript = preload("res://scripts/world.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

# Assombrissement de chaque sommet d'une zone, par position (arrondie au millimètre).
func shades(terrain: RefCounted, zone: Vector3i) -> Dictionary:
	var surface: Array = terrain.zone_surface(zone)
	var result := {}
	if surface.size() < 8:
		return result
	var points: PackedVector3Array = surface[0]
	var values: PackedFloat32Array = surface[7]
	for index in range(points.size()):
		result[(points[index] * 1000.0).round()] = values[index]
	return result

func _run() -> void:
	var terrain := SmoothTerrain.new()
	terrain.setup(3463503054, WorldScript.flat_spots(), Generation.defaults(), false)
	terrain.prepare_step(1 << 40)
	# Sol naturel au départ (pas de grotte autour) : rien d'assombri.
	var natural := shades(terrain, Vector3i(0, -1, 0))
	check(not natural.is_empty() and natural.values().all(func(value): return value == 0.0), "natural ground: nothing darkened (%d vertices)" % natural.size())
	# Une salle de 3 m × 3 m × 2 m creusée à 4 m sous le sol, à cheval sur deux zones (limite x = 16).
	var floor_y := floori(terrain.ground_height(Vector2i(16, 8)) / SmoothTerrain.STEP) - 8
	for x in range(13, 19):
		for z in range(5, 11):
			for y in range(floor_y, floor_y + 4):
				terrain.set_density(Vector3i(x, y, z), -1.0)
	var zone_a := SmoothTerrain.point_zone(Vector3i(15, floor_y, 8))
	var zone_b := SmoothTerrain.point_zone(Vector3i(16, floor_y, 8))
	check(zone_a != zone_b, "the room crosses a zone border (%s, %s)" % [str(zone_a), str(zone_b)])
	var a := shades(terrain, zone_a)
	var b := shades(terrain, zone_b)
	var shared := 0
	var same := true
	for key in a:
		if b.has(key):
			shared += 1
			same = same and absf(float(a[key]) - float(b[key])) < 0.001
	check(shared > 10 and same, "the same darkness on both sides of the zone border (%d shared vertices)" % shared)
	# Coin sol-mur (près de x = 13, z = 5, au sol) contre milieu du sol.
	var corner := 0.0
	var middle := 1.0
	var floor_height := (floor_y - 0.5) * SmoothTerrain.STEP
	for key in a:
		var at := Vector3(key) / 1000.0
		if absf(at.y - floor_height) > 0.35:
			continue
		if at.x < 13.0 * SmoothTerrain.STEP + 0.45 and at.z < 5.0 * SmoothTerrain.STEP + 0.45:
			corner = maxf(corner, float(a[key]))
	for key in a.keys() + b.keys():
		var at := Vector3(key) / 1000.0
		var value: float = a.get(key, b.get(key, 0.0))
		if absf(at.y - floor_height) < 0.35 and absf(at.x - 16.0 * SmoothTerrain.STEP) < 0.4 and absf(at.z - 8.0 * SmoothTerrain.STEP) < 0.4:
			middle = minf(middle, value)
	check(corner > 0.2 and middle < corner * 0.6, "a dug room: its floor-wall corner darkened (%.2f), the middle of its floor much less (%.2f)" % [corner, middle])
	check(SmoothTerrain.zones_using(Vector3i(-3, 0, 0)).has(Vector3i(0, 0, 0)) and SmoothTerrain.zones_using(Vector3i(18, 0, 0)).has(Vector3i(0, 0, 0)) and not SmoothTerrain.zones_using(Vector3i(19, 0, 0)).has(Vector3i(0, 0, 0)), "a zone reads its corner − 3 to its corner + 18 (dug points around redraw it)")
	# SSAO : Beauté (ombres Loin) sur PC seulement.
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	for index in range(3):
		await process_frame
	world.set_shadows("far")
	var beauty: bool = world.environment.ssao_enabled
	world.set_shadows("medium")
	check(beauty != world.is_compat() and not world.environment.ssao_enabled, "screen occlusion (SSAO) only with « Loin » shadows (Beauté), not on the Web")
	world.queue_free()
	await process_frame
	print("RESULT: %d dark corner checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
