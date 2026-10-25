extends SceneTree
# 0.0.5.8 : terrain lisse (étape 3, #120) : sous-cellules de 50 cm, sol plat lisse par zone, gestes
# creuser / ajouter, herbe retirée là où on sculpte, sauvegarde des seuls points changés.
const Store = preload("res://scripts/world_store.gd")
const Zones = preload("res://scripts/world_zones.gd")
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
const WorldScene = preload("res://scenes/world.tscn")
const FOLDER := "res://.godot/terrain-lisse-test-monde"
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

func open(folder: String) -> Node3D:
	var world: Node3D = WorldScene.instantiate()
	world.terrain_seed = 4321
	world.save_folder = folder
	world.load_distance = 2
	root.add_child(world)
	world.player.set_physics_process(false)
	return world

func close(world: Node3D) -> void:
	root.remove_child(world)
	world.free()

# Visée simulée sur le sol, depuis la caméra (dans la portée).
func aim(world: Node3D, at: Vector3, normal := Vector3.UP) -> Dictionary:
	var piece: Node = world.terrain_pieces[Vector3i(floori(at.x / 8.0), -1, floori(at.z / 8.0))]
	world.player.global_position = at + Vector3(1.5, 0.0, 0.0)
	return {"collider": piece, "position": at, "normal": normal}

# Triangles bien orientés : vus de dehors dans le sens des aiguilles d'une montre (comme les blocs).
func outward(vertices: PackedVector3Array, normals: PackedVector3Array) -> bool:
	for index in range(0, vertices.size(), 3):
		var a := vertices[index]
		var face := (vertices[index + 2] - a).cross(vertices[index + 1] - a)
		if face.length_squared() > 0.0000001 and face.dot(normals[index] + normals[index + 1] + normals[index + 2]) <= 0.0:
			return false
	return true

func _run() -> void:
	Store.delete_folder(FOLDER)
	# Échelle confirmée : bloc de 1 m = 2 × 2 × 2 = 8 sous-cellules de 50 cm ; zone de 8 m = 16 par axe, 17 points.
	check(SmoothTerrain.STEP == 0.5 and SmoothTerrain.POINTS == 16 and SmoothTerrain.POINTS + 1 == 17, "50 cm sub-cells: 16 per 8 m zone axis, 17 grid points with both edges")
	check(int(1.0 / SmoothTerrain.STEP) ** 3 == 8 and Zones.DENSITY_POINTS == SmoothTerrain.POINTS, "a 1 m block holds 8 sub-cells, zone files use the same grid")
	check(SmoothTerrain.base_density(Vector3i(0, -1, 0)) > 0.0 and SmoothTerrain.base_density(Vector3i(0, 0, 0)) <= 0.0 and SmoothTerrain.base_density(Vector3i(0, 1, 0)) < 0.0, "seed ground: solid below Y 0, air from Y 0")
	# Le même maillage qu'un sol plat, calculé : surface à Y 0 avec normales vers le haut.
	var data := SmoothTerrain.new()
	var flat: Array = data.zone_mesh(Vector3i(0, -1, 0))
	var level := true
	for vertex in flat[0]:
		level = level and is_equal_approx(vertex.y, 0.0)
	check(flat[0].size() == 16 * 16 * 6 and level and outward(flat[0], flat[1]), "computed flat zone: 16 × 16 sub-cells at Y 0, faces upward")
	check(data.zone_mesh(Vector3i(0, 0, 0))[0].is_empty() and data.zone_mesh(Vector3i(0, -2, 0))[0].is_empty(), "no surface above or deep below the flat ground")
	data.set_density(Vector3i(4, -1, 4), SmoothTerrain.DUG)
	var dug: Array = data.zone_mesh(Vector3i(0, -1, 0))
	var lowest := 0.0
	for vertex in dug[0]:
		lowest = minf(lowest, vertex.y)
	check(lowest < -0.4 and lowest > -1.0 and outward(dug[0], dug[1]), "one dug sub-cell: smooth pit about 50 cm deep, faces outward")
	check(not data.is_flat(Vector3i(0, -1, 0)) and data.is_flat(Vector3i(1, -1, 1)), "only zones reading the changed point are recomputed")
	check(SmoothTerrain.zones_using(Vector3i(16, -1, 3)).has(Vector3i(0, -1, 0)) and SmoothTerrain.zones_using(Vector3i(16, -1, 3)).has(Vector3i(1, -1, 0)), "border point belongs to both neighbouring zones")
	data.set_density(Vector3i(4, -1, 4), SmoothTerrain.base_density(Vector3i(4, -1, 4)))
	check(data.changes.is_empty() and data.columns.is_empty(), "back to the seed value: nothing kept")
	var started := Time.get_ticks_usec()
	data.set_density(Vector3i(20, -2, 20), SmoothTerrain.DUG)
	data.zone_mesh(Vector3i(1, -1, 1))
	print("Zone lisse recalculée en %.1f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
	# Monde : toute la base couverte de terrain plat, la base indestructible dessous.
	var world := open(FOLDER)
	check(world.terrain_pieces.size() == 16 * 16, "flat smooth ground covers the 128 m base, one piece per zone")
	check(world.get_node("Ground").position.y + 0.5 <= SmoothTerrain.LOW_POINT * SmoothTerrain.STEP, "indestructible base lies under the deepest dig")
	var spot := Vector3(20.25, 0.0, 20.25)
	var grass_before := 0
	for tile in world.lawn.get_children():
		grass_before += tile.multimesh.instance_count
	check(world.break_target(aim(world, spot)), "left click digs the flat ground")
	var point: Vector3i = SmoothTerrain.point_of(spot + Vector3.DOWN * 0.3)
	check(world.terrain.density(point) <= 0.0 and world.terrain.changes.size() == 1, "one 50 cm sub-cell removed")
	var piece: StaticBody3D = world.terrain_pieces[Vector3i(2, -1, 2)]
	check(piece.get_child(1).shape is ConcavePolygonShape3D, "sculpted zone gets a smooth collision")
	var grass_after := 0
	for tile in world.lawn.get_children():
		grass_after += tile.multimesh.instance_count
	check(grass_after < grass_before, "grass removed over the pit")
	check(world.place_target(aim(world, Vector3(-20.25, 0.0, -20.25)), 0), "right click adds ground")
	var raised: Vector3i = SmoothTerrain.point_of(Vector3(-20.25, 0.15, -20.25))
	check(world.terrain.density(raised) > 0.0, "one 50 cm sub-cell added above the ground")
	var deep: Dictionary = aim(world, Vector3(5.25, SmoothTerrain.LOW_POINT * SmoothTerrain.STEP - 0.1, 5.25))
	check(not world.break_target(deep), "digging below 3.5 m is refused")
	var under_feet: Dictionary = aim(world, Vector3(0.25, 0.0, 0.25))
	world.player.global_position = Vector3(0.25, 0.0, 0.25)
	check(not world.place_target(under_feet, 0), "no ground added inside the player")
	var changed: Dictionary = world.terrain.changes.duplicate()
	check(world.save_now(), "saved")
	var zone_file := FOLDER.path_join(Zones.zone_file(SmoothTerrain.point_zone(point)))
	var saved: Dictionary = Zones.read_zone(zone_file)
	check(saved.has("data") and saved.data.format == Zones.FORMAT and saved.data.densite.size() >= 1, "zone file stores only changed points (format 3)")
	close(world)
	world = open(FOLDER)
	check(world.terrain.changes == changed, "same sculpted terrain after reopening")
	check(world.terrain_pieces[Vector3i(2, -1, 2)].get_child(1).shape is ConcavePolygonShape3D, "sculpted zone rebuilt at opening")
	# Format 2 (blocs seuls) toujours lisible.
	check(Zones.valid_zone({"format": 2, "type": "blocs", "poses": [[1, 0, 1, 2]], "casses": []}), "older zone files (format 2) still read")
	check(not Zones.valid_zone({"format": 3, "type": "blocs", "poses": [], "casses": [], "densite": [[1, 2, 3]]}), "malformed terrain entries rejected")
	close(world)
	Store.delete_folder(FOLDER)
	print("RESULT: %d smooth terrain checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
