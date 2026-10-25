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
	world.load_distance = 16
	world.relief = false
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
	check(SmoothTerrain.new().base_density(Vector3i(0, -1, 0)) > 0.0 and SmoothTerrain.new().base_density(Vector3i(0, 0, 0)) <= 0.0 and SmoothTerrain.new().base_density(Vector3i(0, 1, 0)) < 0.0, "seed ground: solid below Y 0, air from Y 0")
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
	data.set_density(Vector3i(4, -1, 4), SmoothTerrain.new().base_density(Vector3i(4, -1, 4)))
	check(data.changes.is_empty() and data.columns.is_empty(), "back to the seed value: nothing kept")
	var started := Time.get_ticks_usec()
	data.set_density(Vector3i(20, -2, 20), SmoothTerrain.DUG)
	data.zone_mesh(Vector3i(1, -1, 1))
	print("Zone lisse recalculée en %.1f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
	# Monde : toute la base couverte de terrain plat, la base indestructible dessous.
	var world := open(FOLDER)
	check(world.terrain_pieces.size() == 16 * 16, "flat smooth ground covers the 128 m base, one piece per zone")
	check(is_equal_approx(world.get_node("Ground").position.y + 0.5, -8.0), "Roche-mère (indestructible base) starts 8 m below the grass (0.0.5.12)")
	check(SmoothTerrain.LOW_POINT * SmoothTerrain.STEP == -3.5 and SmoothTerrain.STONE_TOP * SmoothTerrain.STEP == -4.0 and SmoothTerrain.BEDROCK_TOP * SmoothTerrain.STEP == -8.0, "layers: 4 m of dirt, then 4 m of stone, then Roche-mère")
	check(SmoothTerrain.new().natural_kind(Vector3i(0, -7, 0)) == -1 and SmoothTerrain.new().natural_kind(Vector3i(0, -8, 0)) == SmoothTerrain.STONE and SmoothTerrain.new().natural_kind(Vector3i(0, -15, 0)) == SmoothTerrain.STONE, "dirt down to 4 m, stone below")
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
	check(not world.break_target(deep) and world.notice.begins_with("La pierre se casse avec la pioche"), "without the pickaxe, stone does not break (0.0.5.13)")
	world.player.selected_type = world.PICKAXE
	check(world.player.pickaxe.visible and world.break_target(aim(world, Vector3(5.25, -4.0, 5.25))), "with the pickaxe (shown in hand), stone breaks")
	check(world.terrain.density(SmoothTerrain.point_of(Vector3(5.25, -4.3, 5.25))) <= 0.0 and world.find_children("Debris", "CPUParticles3D", true, false).size() > 0, "a stone sub-cell is removed, with flying chips")
	check(not world.break_target(aim(world, Vector3(5.25, -7.9, 5.25))) and world.notice == "Roche-mère : incassable.", "Roche-mère never breaks, even with the pickaxe")
	check(not world.place_target(aim(world, Vector3(6.25, 0.0, 6.25)), world.PICKAXE), "the pickaxe places nothing")
	world.player.selected_type = 0
	check(not world.player.pickaxe.visible, "pickaxe hidden when sand is chosen")
	# Fond d'un puits creusé jusqu'à la pierre : la surface est peinte en pierre, et la pierre ne tombe pas.
	var shaft := SmoothTerrain.new()
	for y in range(SmoothTerrain.LOW_POINT, 0):
		shaft.set_density(Vector3i(4, y, 4), SmoothTerrain.DUG)
	var stone_colors: PackedColorArray = shaft.zone_mesh(Vector3i(0, -1, 0))[2]
	var rocky := false
	for color in stone_colors:
		rocky = rocky or color.g < 0.5
	check(rocky, "the bottom of a 4 m shaft shows stone")
	check(shaft.fall_target(Vector3i(4, SmoothTerrain.STONE_TOP, 4)) == Vector3i(4, SmoothTerrain.STONE_TOP, 4) and shaft.solid(Vector3i(4, SmoothTerrain.BEDROCK_TOP - 3, 4)), "stone never falls; Roche-mère holds everything")
	# 0.0.5.14 : petites collines de terre selon la graine, plates autour de l'apparition.
	var hills := SmoothTerrain.new()
	hills.setup(4321, [[Vector2(0.5, 0.5), 9.0]])
	var again := SmoothTerrain.new()
	again.setup(4321, [[Vector2(0.5, 0.5), 9.0]])
	var tallest := 0.0
	var same_hills := true
	for x in range(-120, 121, 3):
		for z in range(-120, 121, 3):
			var column := Vector2i(x, z)
			tallest = maxf(tallest, hills.ground_height(column))
			same_hills = same_hills and hills.ground_height(column) == again.ground_height(column) and hills.ground_height(column) >= SmoothTerrain.DEEPEST and hills.ground_height(column) > SmoothTerrain.STONE_TOP * SmoothTerrain.STEP
	check(same_hills and tallest > 0.5 and tallest <= SmoothTerrain.HILL_HEIGHT, "same seed = same hills (up to 3 m, holes never down to the stone)")
	check(hills.ground_height(Vector2i(1, 1)) == 0.0 and hills.ground_height(Vector2i(10, -6)) == 0.0, "flat around the spawn")
	var other := SmoothTerrain.new()
	other.setup(99, [[Vector2(0.5, 0.5), 9.0]])
	var differs := false
	for x in range(-120, 121, 9):
		differs = differs or other.ground_height(Vector2i(x, 60)) != hills.ground_height(Vector2i(x, 60))
	check(differs, "another seed gives other hills")
	# 0.0.5.15 : crêtes, trous et déserts, à peu près aux fréquences demandées (sur 1600 zones).
	var counts := {"hole": 0, "ridge": 0, "small_desert": 0, "big_desert": 0}
	for x in range(-20, 20):
		for z in range(-20, 20):
			var info: Dictionary = hills._zone_info(Vector2i(x, z))
			for key in ["hole", "ridge", "big_desert"]:
				if info.has(key):
					counts[key] += 1
			if info.small_desert:
				counts.small_desert += 1
	print("Zones : ", counts)
	check(absf(counts.hole / 1600.0 - 1.0 / 9.0) < 0.03 and absf(counts.ridge / 1600.0 - 1.0 / 9.0) < 0.03, "about 1 zone in 9 has a hole, 1 in 9 an abrupt ridge")
	check(absf(counts.small_desert / 1600.0 - 1.0 / 8.0) < 0.03 and absf(counts.big_desert / 1600.0 - 1.0 / 12.0) < 0.03, "about 1 zone in 8 is a small desert, 1 in 12 starts a big one")
	var desert_at := Vector2.ZERO
	var hole_at := Vector2.ZERO
	for x in range(-20, 20):
		for z in range(-20, 20):
			var info: Dictionary = hills._zone_info(Vector2i(x, z))
			if info.small_desert and desert_at == Vector2.ZERO and hills.is_desert((Vector2(x, z) + Vector2(0.5, 0.5)) * 8.0):
				desert_at = (Vector2(x, z) + Vector2(0.5, 0.5)) * 8.0
			if info.has("hole") and info.hole[1] > 2.0 and hole_at == Vector2.ZERO and hills.height_at(info.hole[0].x, info.hole[0].y) < -1.0:
				hole_at = info.hole[0]
	var desert_point := Vector3i(roundi(desert_at.x / 0.5), floori(hills.height_at(desert_at.x, desert_at.y) / 0.5), roundi(desert_at.y / 0.5))
	check(desert_at != Vector2.ZERO and hills.natural_kind(desert_point) == SmoothTerrain.SAND and hills.natural_kind(desert_point + Vector3i(0, -6, 0)) != SmoothTerrain.SAND, "deserts are sand on top, dirt below")
	check(hole_at != Vector2.ZERO and hills.height_at(hole_at.x, hole_at.y) > SmoothTerrain.STONE_TOP * SmoothTerrain.STEP, "deep holes exist and stop before the stone")
	var started_hill := Time.get_ticks_usec()
	var hill_zone := Vector3i.ZERO
	for x in range(-8, 8):
		for z in range(-8, 8):
			if hills.zone_heights(Vector3i(x, 0, z)).y > 1.0:
				hill_zone = Vector3i(x, 0, z)
	var hill_mesh: Array = hills.zone_mesh(hill_zone)
	print("Zone de colline calculée en %.1f ms" % ((Time.get_ticks_usec() - started_hill) / 1000.0))
	var top_vertex := 0.0
	for vertex in hill_mesh[0]:
		top_vertex = maxf(top_vertex, vertex.y)
	check(hill_mesh[0].size() > 0 and top_vertex > 0.5 and outward(hill_mesh[0], hill_mesh[1]), "a hill zone gets a smooth surface, faces outward")
	var under_feet: Dictionary = aim(world, Vector3(0.25, 0.0, 0.25))
	world.player.global_position = Vector3(0.25, 0.0, 0.25)
	check(not world.place_target(under_feet, 0), "no ground added inside the player")
	# 0.0.5.9 : matière posée, tailles 1/8, 1/4, 1/2 bloc, aplanir et lisser.
	var player: CharacterBody3D = world.player
	player.selected_type = 0
	player.brush = 0
	player.brush_size = 2
	var before_size: int = world.terrain.changes.size()
	check(world.place_target(aim(world, Vector3(-30.25, 0.0, 10.25)), player.selected_type), "half-block gesture adds sand")
	var sand_point: Vector3i = SmoothTerrain.point_of(Vector3(-30.25, 0.15, 10.25))
	check(world.terrain.changes.size() - before_size == 4 and world.terrain.material(sand_point) == SmoothTerrain.SAND, "1/2 bloc = 4 sub-cells, sand remembered")
	var colors: PackedColorArray = world.terrain.zone_mesh(SmoothTerrain.point_zone(sand_point))[2]
	var sandy := false
	for color in colors:
		sandy = sandy or color.a < 0.5
	check(sandy, "sand shows on the smooth surface (vertex colour)")
	player.brush_size = 1
	before_size = world.terrain.changes.size()
	check(world.break_target(aim(world, Vector3(-30.25, 0.0, -10.25))) and world.terrain.changes.size() - before_size == 2, "1/4 bloc gesture digs 2 sub-cells")
	check(not world.place_target(aim(world, Vector3(30.25, 0.0, -30.25)), 1) or world.terrain.material(SmoothTerrain.point_of(Vector3(30.25, 0.15, -30.25))) == SmoothTerrain.DIRT, "stone is no longer placed: dirt instead")
	player.brush = 1
	player.brush_size = 2
	var mound := Vector3(10.25, 0.0, -20.25)
	for index in range(3):
		world.terrain.set_density(SmoothTerrain.point_of(mound) + Vector3i(0, index, 0), 0.5, SmoothTerrain.DIRT)
		world.terrain_dirty[SmoothTerrain.point_zone(SmoothTerrain.point_of(mound) + Vector3i(0, index, 0))] = true
	world.rebuild_terrain_piece(Vector3i(1, -1, -3))
	world.rebuild_terrain_piece(Vector3i(1, 0, -3))
	check(world.place_target(aim(world, mound), 2), "flatten works on a mound")
	var pit := SmoothTerrain.point_of(Vector3(-40.25, -0.3, -40.25))
	world.terrain.set_density(pit, SmoothTerrain.DUG)
	world.terrain_dirty[SmoothTerrain.point_zone(pit)] = true
	var before_materials: int = world.terrain.materials.size()
	world.place_target(aim(world, Vector3(-39.25, 0.0, -40.25)), 2)
	check(world.terrain.density(pit) <= 0.0 and world.terrain.materials.size() == before_materials, "flatten never fills a pit: no material added")
	check(world.terrain.density(SmoothTerrain.point_of(mound) + Vector3i(0, 2, 0)) <= 0.0, "flatten cuts the mound down to the aimed level")
	player.brush = 2
	world.terrain.set_density(SmoothTerrain.point_of(mound) + Vector3i(1, 1, 0), 0.5, SmoothTerrain.DIRT)
	world.terrain_dirty[SmoothTerrain.point_zone(SmoothTerrain.point_of(mound) + Vector3i(1, 1, 0))] = true
	var sharp: float = world.terrain.density(SmoothTerrain.point_of(mound) + Vector3i(1, 1, 0))
	check(world.place_target(aim(world, mound + Vector3(0.5, 0.5, 0)), 2) and world.terrain.density(SmoothTerrain.point_of(mound) + Vector3i(1, 1, 0)) < sharp, "smoothing softens a lone bump")
	var air_above := SmoothTerrain.point_of(mound) + Vector3i(0, 4, 0)
	check(world.terrain.density(air_above) <= 0.0, "smoothing adds no material in the air")
	player.brush = 0
	player.brush_size = 0
	check(world.BRUSH_NAMES == ["Poser", "Aplanir", "Lisser"] and world.SIZE_CELLS == [1, 2, 4], "three right-click brushes, three sizes")
	player.cycle_brush()
	check(player.brush == 1 and world.notice == "Clic droit : Aplanir", "B + T shows the new brush at the bottom")
	player.cycle_size(1)
	check(player.brush_size == 1 and world.notice == "Taille du geste : 1/4 de bloc", "B + wheel shows the gesture size at the bottom")
	player.brush = 0
	player.brush_size = 0
	world.notice_time = 0.0
	check(SmoothTerrain.HIGH_POINT * SmoothTerrain.STEP == 4.0, "placing limited to 4 blocks above the ground")
	# 0.0.5.11 : gravité. Un point de terre en l'air tombe jusqu'au sol.
	var floating: Vector3i = SmoothTerrain.point_of(Vector3(40.25, 2.0, 40.25))
	world.terrain.set_density(floating, 0.5, SmoothTerrain.DIRT)
	world.terrain.wake(floating)
	world.settle_all()
	var landed := Vector3i(floating.x, 0, floating.z)
	check(world.terrain.density(floating) <= 0.0 and world.terrain.density(landed) > 0.0 and world.terrain.material(landed) == SmoothTerrain.DIRT, "dirt with nothing below falls onto the ground")
	# Une colonne de sable s'étale (talus), une petite pile de terre tient.
	var sand_base: Vector3i = SmoothTerrain.point_of(Vector3(45.25, 0.0, 45.25))
	for height in range(3):
		world.terrain.set_density(sand_base + Vector3i(0, height, 0), 0.5, SmoothTerrain.SAND)
		world.terrain.wake(sand_base + Vector3i(0, height, 0))
	world.settle_all()
	check(world.terrain.density(sand_base + Vector3i(0, 2, 0)) <= 0.0 and world.terrain.density(sand_base + Vector3i(0, 1, 0)) <= 0.0, "a sand column spreads out instead of standing")
	var spread := 0
	for side in SmoothTerrain.SIDES:
		if world.terrain.density(sand_base + side) > 0.0:
			spread += 1
	check(spread == 2 and world.terrain.density(sand_base) > 0.0, "the sand slid to the sides, nothing lost")
	var dirt_base: Vector3i = SmoothTerrain.point_of(Vector3(50.25, 0.0, 45.25))
	for height in range(2):
		world.terrain.set_density(dirt_base + Vector3i(0, height, 0), 0.5, SmoothTerrain.DIRT)
		world.terrain.wake(dirt_base + Vector3i(0, height, 0))
	world.settle_all()
	check(world.terrain.density(dirt_base + Vector3i(0, 1, 0)) > 0.0, "a small dirt pile (1 m) holds")
	# Creuser sous de la terre posée la fait tomber ; un vide plus loin ne fait rien tomber.
	world.terrain.set_density(dirt_base + Vector3i(0, -1, 0), SmoothTerrain.DUG)
	world.terrain.wake(dirt_base + Vector3i(0, -1, 0))
	world.settle_all()
	check(world.terrain.density(dirt_base + Vector3i(0, -1, 0)) > 0.0 and world.terrain.density(dirt_base + Vector3i(0, 1, 0)) <= 0.0, "digging under the pile makes it fall into the hole")
	var far_hole: Vector3i = dirt_base + Vector3i(4, -2, 0)
	world.terrain.set_density(far_hole, SmoothTerrain.DUG)
	world.terrain.wake(far_hole)
	world.settle_all()
	check(world.terrain.density(dirt_base) > 0.0 and world.terrain.density(dirt_base + Vector3i(0, -1, 0)) > 0.0, "a hole 2 m away (not right below) does not make the pile fall")
	check(world.save_now(), "saved")
	var changed: Dictionary = world.terrain.changes.duplicate()
	var zone_file := FOLDER.path_join(Zones.zone_file(SmoothTerrain.point_zone(point)))
	var saved: Dictionary = Zones.read_zone(zone_file)
	check(saved.has("data") and saved.data.format == Zones.FORMAT and saved.data.densite.size() >= 1, "zone file stores only changed points (format 3)")
	close(world)
	world = open(FOLDER)
	var same: bool = world.terrain.changes.size() == changed.size()
	for key in changed:
		same = same and absf(world.terrain.changes.get(key, 9.0) - changed[key]) < 0.001
	check(same, "same sculpted terrain after reopening")
	check(world.terrain.material(sand_point) == SmoothTerrain.SAND, "same materials after reopening")
	world.finish_terrain()
	check(world.terrain_pieces[Vector3i(2, -1, 2)].get_child(1).shape is ConcavePolygonShape3D, "sculpted zone rebuilt at opening")
	# Format 2 (blocs seuls) toujours lisible.
	check(Zones.valid_zone({"format": 2, "type": "blocs", "poses": [[1, 0, 1, 2]], "casses": []}), "older zone files (format 2) still read")
	check(not Zones.valid_zone({"format": 3, "type": "blocs", "poses": [], "casses": [], "densite": [[1, 2, 3]]}), "malformed terrain entries rejected")
	close(world)
	Store.delete_folder(FOLDER)
	# Monde avec collines : apparition à Y 0, herbe posée sur les collines, terrain lointain fait peu à peu.
	var hilly: Node3D = WorldScene.instantiate()
	hilly.terrain_seed = 4321
	root.add_child(hilly)
	check(hilly.player_coordinates().y == 0 and not hilly.terrain_queue.is_empty(), "spawn on flat ground at Y 0; far hills built a few at a time")
	hilly.finish_terrain()
	var grass_up := false
	var TerrainMaterials = load("res://scripts/terrain_materials.gd")
	for tile_x in range(-8, 8):
		for tile_z in range(-8, 8, 4):
			for patch_at in TerrainMaterials.lawn_points(Vector2i(tile_x, tile_z), {}, 4321, Vector2.ZERO, 0.0, Callable(), hilly.terrain.height_at):
				grass_up = grass_up or patch_at.y > 0.3
	check(hilly.terrain_queue.is_empty() and grass_up, "grass grows on the hills")
	close(hilly)
	# 0.0.5.14 : B + molette haut = geste plus grand.
	var Controls = load("res://scripts/controls.gd")
	check(Controls.ACTIONS.size_up.default.second.mouse == MOUSE_BUTTON_WHEEL_UP and Controls.ACTIONS.size_down.default.second.mouse == MOUSE_BUTTON_WHEEL_DOWN, "B + wheel up makes the gesture bigger")
	# 0.0.5.17 : distance d'affichage comptée à l'horizontale (8 zones par défaut).
	var viewer: Node3D = WorldScene.instantiate()
	viewer.relief = false
	viewer.load_distance = 2
	root.add_child(viewer)
	viewer.finish_terrain()
	check(viewer.shown_columns.size() == 25 and viewer.lawn.get_child_count() > 0, "only the 5 × 5 columns around the player are shown (distance 2)")
	viewer.player.position = Vector3(36.0, 40.0, 4.0)
	viewer.update_terrain_view(false, Vector2i(4, 0))
	viewer.finish_terrain()
	check(viewer.column_shown(Vector2i(4, 0)) and viewer.column_shown(Vector2i(6, 2)) and not viewer.column_shown(Vector2i(-2, 0)), "walking (or flying 40 m high) shows the columns ahead, hides those behind")
	var under := false
	for zone in viewer.terrain_pieces:
		under = under or (zone.x == 4 and zone.z == 0)
	check(under and viewer.environment.fog_enabled and is_equal_approx(viewer.environment.fog_depth_end, 16.0), "the ground under a flying player is there; mist at the edge of the view")
	check(WorldScene.instantiate().load_distance == 8, "view distance 8 zones by default")
	close(viewer)
	print("RESULT: %d smooth terrain checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
