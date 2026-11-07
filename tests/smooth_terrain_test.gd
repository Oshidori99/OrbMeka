extends SceneTree
# 0.0.5.8 : terrain lisse (étape 3, #120) : sous-cellules de 50 cm, sol plat lisse par zone, gestes
# creuser / ajouter, herbe retirée là où on sculpte, sauvegarde des seuls points changés.
const Store = preload("res://scripts/world_store.gd")
const Zones = preload("res://scripts/world_zones.gd")
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
const WorldScene = preload("res://scenes/world.tscn")
const FarTerrain = preload("res://scripts/far_terrain.gd")
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
	world.load_distance = 20
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
	check(world.terrain_pieces.size() == world.shown_columns.size() and world.shown_columns.size() == 41 * 41, "flat smooth ground: one piece per shown zone (0.0.5.20 : world of 48 × 48 zones, view 20)")
	check(is_equal_approx(world.get_node("Ground").position.y + 0.5, -8.0), "Roche-mère (indestructible base) starts 8 m below the grass (0.0.5.12)")
	check(SmoothTerrain.LOW_POINT * SmoothTerrain.STEP == -3.5 and SmoothTerrain.STONE_TOP * SmoothTerrain.STEP == -4.0 and SmoothTerrain.MOTHER_ROCK_TOP * SmoothTerrain.STEP == -8.0, "layers: 4 m of dirt, then 4 m of stone, then Roche-mère")
	# 0.0.5.26 (version 9) : 5 m de terre, 10 m de pierre, 10 m de pierre sombre, puis seulement la Roche-mère.
	var deep_land := SmoothTerrain.new()
	deep_land.setup(7, [], load("res://scripts/world_generation.gd").defaults())
	var far_column := func(y: int) -> int: return deep_land.natural_kind(Vector3i(0, y, 0))
	check(far_column.call(-9) != SmoothTerrain.STONE and far_column.call(-10) == SmoothTerrain.STONE and far_column.call(-29) == SmoothTerrain.STONE and far_column.call(-30) == SmoothTerrain.DARK_STONE and far_column.call(-49) == SmoothTerrain.DARK_STONE and far_column.call(-50) == SmoothTerrain.MOTHER_ROCK and far_column.call(-200) == SmoothTerrain.MOTHER_ROCK, "version 9: 5 m of dirt, 10 m of stone, 10 m of dark stone, then only Roche-mère")
	check(deep_land.solid(Vector3i(0, -50, 0)) and deep_land.fall_target(Vector3i(0, -50, 0)) == Vector3i(0, -50, 0), "Roche-mère carries everything at 25 m")
	deep_land.set_density(Vector3i(0, -35, 0), 0.5)
	check(deep_land.is_stone(Vector3i(0, -35, 0)), "dark stone needs the pickaxe, like stone")
	deep_land.set_density(Vector3i(0, -35, 0), -0.5)
	deep_land.set_density(Vector3i(0, -50, 0), -0.5)
	check(deep_land.zone_mesh(SmoothTerrain.point_zone(Vector3i(0, -50, 0)))[0].size() > 0 or deep_land.zone_mesh(SmoothTerrain.point_zone(Vector3i(0, -49, 0)))[0].size() > 0, "deep zones are drawn when dug")
	check(SmoothTerrain.new().natural_kind(Vector3i(0, -7, 0)) == -1 and SmoothTerrain.new().natural_kind(Vector3i(0, -8, 0)) == SmoothTerrain.STONE and SmoothTerrain.new().natural_kind(Vector3i(0, -15, 0)) == SmoothTerrain.STONE, "dirt down to 4 m, stone below")
	world.finish_terrain()
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
	check(shaft.fall_target(Vector3i(4, SmoothTerrain.STONE_TOP, 4)) == Vector3i(4, SmoothTerrain.STONE_TOP, 4) and shaft.solid(Vector3i(4, SmoothTerrain.MOTHER_ROCK_TOP - 3, 4)), "stone never falls; Roche-mère holds everything")
	# 0.0.5.18 : la Roche-mère a sa propre couleur (noire, teintée de rouge) au fond d'un puits creusé à la pioche.
	var to_mother_rock := SmoothTerrain.new()
	for y in range(SmoothTerrain.MOTHER_ROCK_TOP + 1, 0):
		to_mother_rock.set_density(Vector3i(4, y, 4), SmoothTerrain.DUG)
	var mother_rock_seen := false
	for color in to_mother_rock.zone_mesh(Vector3i(0, -1, 0))[2]:
		mother_rock_seen = mother_rock_seen or (color.r < 0.5 and color.g < 0.5)
	check(mother_rock_seen and to_mother_rock.natural_kind(Vector3i(0, SmoothTerrain.MOTHER_ROCK_TOP, 0)) == SmoothTerrain.MOTHER_ROCK, "Roche-mère painted black-red at the bottom of a shaft")
	# 0.0.5.18 : rochers, 7 tailles × 7 formes ; monde d'essai TestTailleRocher.
	var Rocks = load("res://scripts/rocks.gd")
	var grid: Dictionary = Rocks.size_shape_grid()
	check(grid.rochers.size() == 49 and Rocks.SIZES.size() == 7 and Rocks.SHAPES.size() == 7 and Rocks.SIZE_NAMES[0] == "minuscule" and Rocks.SIZE_NAMES[6] == "énorme", "7 sizes (minuscule to énorme) × 7 shapes")
	var growing := true
	for size in range(2, 8):
		growing = growing and Rocks.rock_mesh(size, 1).get_aabb().size.x > Rocks.rock_mesh(size - 1, 1).get_aabb().size.x
	var shapes_differ: bool = Rocks.rock_mesh(4, 2).get_aabb().size.y < Rocks.rock_mesh(4, 3).get_aabb().size.y * 0.5
	check(growing and shapes_differ and world.valid_objects(grid), "sizes grow from 1 to 7; a flat rock is lower than an upright one; layout file valid")
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
	check(SmoothTerrain.HIGH_POINT * SmoothTerrain.STEP == 40.0, "placing limited to 40 blocks high (mountains)")
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
	# 0.0.5.19 : rochers au hasard et petits lacs dans les nouveaux mondes (génération version 4), minés à la pioche.
	Store.delete_folder(FOLDER)
	var rock_world: Node3D = WorldScene.instantiate()
	rock_world.terrain_seed = 70621
	rock_world.generation_options = load("res://scripts/world_generation.gd").defaults()
	rock_world.save_folder = FOLDER
	rock_world.load_distance = 6
	root.add_child(rock_world)
	rock_world.finish_terrain()
	var rock_nodes := rock_world.get_tree().get_nodes_in_group("rocks")
	check(rock_nodes.size() > 40, "a new world has random rocks")
	var small_rocks := 0
	var huge_rocks := 0
	for each in rock_nodes:
		small_rocks += 1 if each.get_meta("rock").x <= 2 else 0
		huge_rocks += 1 if each.get_meta("rock").x == 7 else 0
	check(small_rocks > huge_rocks * 3, "more small_rocks rocks than huge_rocks ones")
	# 0.0.6 : un rocher se creuse une sous-cellule (cube de 50 cm) par coup, là où l'on frappe ; il disparaît vidé.
	var mined_target: StaticBody3D = rock_nodes[0]
	var carved_target: StaticBody3D = null
	for each in rock_nodes:
		if each.get_meta("rock").x < mined_target.get_meta("rock").x:
			mined_target = each
	for each in rock_nodes:
		if each != mined_target and each.get_meta("rock").x >= 3 and carved_target == null:
			carved_target = each
	var rock_id: String = mined_target.get_meta("id")
	rock_world.player.global_position = mined_target.global_position + Vector3(1.0, 0.0, 1.0)
	var rock_hit := {"collider": mined_target, "position": mined_target.global_position, "normal": Vector3.UP}
	rock_world.player.selected_type = 0
	check(not rock_world.break_target(rock_hit) and rock_world.notice.begins_with("Les rochers se cassent avec la pioche"), "without the pickaxe, a rock does not break")
	rock_world.player.selected_type = rock_world.PICKAXE
	var faces_before: int = mined_target.get_child(0).mesh.get_faces().size()
	rock_world.break_target(rock_hit)
	check(rock_world.carved_rocks.get(rock_id, []).size() == 1 and is_instance_valid(mined_target) and not mined_target.is_queued_for_deletion() and mined_target.get_child(0).mesh.get_faces().size() != faces_before, "one pickaxe hit removes one 50 cm sub-cell of a rock; its shape changes")
	# Frapper chaque sous-cellule du rocher : il finit vidé, puis disparaît.
	var rock_center: Vector3 = mined_target.global_position
	var low := SmoothTerrain.point_of(rock_center - Vector3.ONE * 2.0)
	var high := SmoothTerrain.point_of(rock_center + Vector3.ONE * 2.0)
	var strikes := 1
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for z in range(low.z, high.z + 1):
				if is_instance_valid(mined_target) and not mined_target.is_queued_for_deletion():
					rock_world.mine_rock(mined_target, {"position": Vector3(x, y, z) * 0.5 + Vector3.UP * 0.15, "normal": Vector3.UP})
					strikes += 1
	check(rock_world.mined_rocks.has(rock_id) and not rock_world.carved_rocks.has(rock_id) and strikes > 2, "a rock emptied hit after hit disappears (%d hits)" % strikes)
	var carved_id: String = carved_target.get_meta("id")
	rock_world.mine_rock(carved_target, {"position": carved_target.global_position + Vector3.UP * 0.2, "normal": Vector3.UP})
	rock_world.mine_rock(carved_target, {"position": carved_target.global_position + Vector3(0.5, 0.2, 0.0), "normal": Vector3.UP})
	var carved_faces: int = carved_target.get_child(0).mesh.get_faces().size()
	var carved_count: int = rock_world.carved_rocks.get(carved_id, []).size()
	check(carved_count >= 1, "a bigger rock keeps its hollows")
	# 0.0.6 : pierre du terrain : un coup = une sous-cellule ; pierre sombre : 2 coups ; Roche-mère : jamais.
	# Points pleins (pas dans une grotte).
	var stone_point := Vector3i(40, rock_world.terrain.stone_top - 2, 40)
	var dark_point := Vector3i(44, rock_world.terrain.deep_top - 2, 40)
	while rock_world.terrain.density(stone_point) <= 0.0:
		stone_point.x += 1
	while rock_world.terrain.density(dark_point) <= 0.0:
		dark_point.x += 1
	check(rock_world.terrain.natural_kind(stone_point) == SmoothTerrain.STONE and rock_world.terrain.natural_kind(dark_point) == SmoothTerrain.DARK_STONE, "stone and dark stone points found")
	var changes_before: int = rock_world.terrain.changes.size()
	rock_world._strike_stone(stone_point, Vector3(stone_point) * 0.5)
	check(rock_world.terrain.density(stone_point) <= 0.0 and rock_world.terrain.changes.size() == changes_before + 1, "one pickaxe hit on stone removes exactly one sub-cell")
	rock_world._strike_stone(dark_point, Vector3(dark_point) * 0.5)
	var dark_after_one: float = rock_world.terrain.density(dark_point)
	rock_world._strike_stone(dark_point, Vector3(dark_point) * 0.5)
	check(dark_after_one > 0.0 and rock_world.terrain.density(dark_point) <= 0.0, "dark stone is harder: two hits per sub-cell")
	check(not rock_world._in_terrain_limits(Vector3i(40, rock_world.terrain.mother_rock_top, 40)), "the bedrock never breaks")
	# Par le vrai geste (visée du sol, pioche) : une seule sous-cellule, même avec un grand pinceau.
	var ground_body: StaticBody3D = rock_world.terrain_pieces.values()[0]
	var face_point := Vector3i(48, rock_world.terrain.stone_top - 2, 46)
	while rock_world.terrain.density(face_point) <= 0.0 or not rock_world.terrain.is_stone(face_point):
		face_point.x += 1
	rock_world.player.global_position = Vector3(face_point) * 0.5 + Vector3(1.0, 0.0, 1.0)
	rock_world.player.brush_size = 2
	changes_before = rock_world.terrain.changes.size()
	check(rock_world.break_target({"collider": ground_body, "position": Vector3(face_point) * 0.5 + Vector3.UP * 0.3, "normal": Vector3.UP}) and rock_world.terrain.changes.size() == changes_before + 1, "aiming at stone with the pickaxe digs one sub-cell, whatever the brush size")
	rock_world.player.brush_size = 0
	check(rock_world.save_now() and FileAccess.get_file_as_string(FOLDER.path_join(Store.OBJECTS_FILE)).contains(rock_id) and FileAccess.get_file_as_string(FOLDER.path_join(Store.OBJECTS_FILE)).contains("rochers_entames"), "mined and carved rocks saved in objets.json")
	close(rock_world)
	var rock_world_again: Node3D = WorldScene.instantiate()
	rock_world_again.terrain_seed = 70621
	rock_world_again.generation_options = load("res://scripts/world_generation.gd").defaults()
	rock_world_again.save_folder = FOLDER
	rock_world_again.load_distance = 6
	root.add_child(rock_world_again)
	rock_world_again.finish_terrain()
	var came_back := false
	for each in rock_world_again.get_tree().get_nodes_in_group("rocks"):
		came_back = came_back or each.get_meta("id") == rock_id
	check(not came_back and rock_world_again.get_tree().get_nodes_in_group("rocks").size() > 0, "a mined rock never comes back")
	var reloaded_faces := -1
	for each in rock_world_again.get_tree().get_nodes_in_group("rocks"):
		if each.get_meta("id") == carved_id:
			reloaded_faces = each.get_child(0).mesh.get_faces().size()
	check(rock_world_again.carved_rocks.get(carved_id, []).size() == carved_count and reloaded_faces == carved_faces, "a carved rock comes back with the same hollows")
	check(rock_world_again.terrain.density(stone_point) <= 0.0 and rock_world_again.terrain.density(dark_point) <= 0.0, "dug stone sub-cells stay dug after reloading")
	close(rock_world_again)
	Store.delete_folder(FOLDER)
	var older_terrain := SmoothTerrain.new()
	var v3_options: Dictionary = load("res://scripts/world_generation.gd").defaults()
	v3_options.erase("rocks")
	v3_options.erase("lakes")
	v3_options.version = 3
	older_terrain.setup(70621, [], v3_options)
	var no_rocks := true
	for x in range(-10, 10):
		no_rocks = no_rocks and older_terrain.rocks_in_zone(Vector2i(x, 2)).is_empty() and older_terrain.lakes_in_zone(Vector2i(x, 2)).is_empty()
	check(no_rocks, "worlds made before version 4 get no rocks or lakes")
	# 0.0.5.20 : lacs de 1 zone et de 1 × 2 zones, boue au bord et au fond, argile dessous et en poches.
	var wet_land := SmoothTerrain.new()
	wet_land.setup(70621, [], load("res://scripts/world_generation.gd").defaults())
	var round_lakes := 0
	var long_lakes := 0
	var a_long_lake := {}
	var clay_found := false
	for x in range(-24, 24):
		for z in range(-24, 24):
			for lake in wet_land.lakes_in_zone(Vector2i(x, z)):
				if lake.radius > 10.5:
					long_lakes += 1
					a_long_lake = lake
				else:
					round_lakes += 1
	# 0.0.5.23 (version 7) : peu de petits lacs, des moyens (environ 10 zones), quelques grands (environ 16).
	check(round_lakes >= 1 and round_lakes < 12 and long_lakes > 4 and long_lakes < 20, "few small lakes, more medium and large ones (version 7) in a 48 × 48 world")
	# Montagnes : hautes (20 m et plus), cœur de pierre au sommet, jamais au départ.
	var summit := Vector2.ZERO
	var summit_height := 0.0
	for x in range(-24, 24):
		for z in range(-24, 24):
			var found: Dictionary = wet_land._zone_mountain(Vector2i(x, z))
			if not found.is_empty() and not found.get("sand", false) and wet_land.mountain_lift(found.center) > summit_height:
				summit = found.center
				summit_height = wet_land.mountain_lift(found.center)
	var top_column := Vector2i(roundi(summit.x / 0.5), roundi(summit.y / 0.5))
	var top_point := Vector3i(top_column.x, floori(wet_land.ground_height(top_column) / 0.5), top_column.y)
	check(summit_height > 18.0 and wet_land.natural_kind(top_point) == SmoothTerrain.STONE, "mountains of about 20 to 30 m with a stone summit")
	check(wet_land.mountain_lift(Vector2(0.5, 0.5)) == 0.0 and wet_land.surface_zones(Vector2i(floori(top_column.x / 16.0), floori(top_column.y / 16.0)), Vector2i(floori(top_column.x / 16.0), floori(top_column.y / 16.0))).has(Vector3i(floori(top_column.x / 16.0), 2, floori(top_column.y / 16.0))), "no mountain at the start; high zones of a mountain are drawn")
	var middle: Vector2 = a_long_lake.center
	var column := Vector2i(roundi(middle.x / 0.5), roundi(middle.y / 0.5))
	var floor_point := Vector3i(column.x, floori(wet_land.ground_height(column) / 0.5), column.y)
	check(wet_land.natural_kind(floor_point) in [SmoothTerrain.MUD, SmoothTerrain.CLAY] and wet_land.natural_kind(floor_point + Vector3i(0, -3, 0)) in [SmoothTerrain.CLAY, SmoothTerrain.STONE] and wet_land.muddy(column), "mud or clay at the bottom of a lake, clay (or stone under deep lakes) below, no grass")
	check(wet_land.ground_height(column) < a_long_lake.level, "the bottom of a lake is under its water")
	for x in range(-60, 60):
		for z in range(-60, 60, 3):
			var c := Vector2i(x, z)
			var depth := floori((wet_land.ground_height(c) - 1.0) / 0.5)
			clay_found = clay_found or (wet_land.natural_kind(Vector3i(x, depth, z)) == SmoothTerrain.CLAY and not wet_land.muddy(c))
	check(clay_found, "clay pockets in the dirt, away from lakes")
	# 0.0.5.21 : bandes de 4 à 5 m autour des lacs (argile ; boue et argile ; argile, herbe et boue) et régions de boue.
	var patterns := {}
	var mud_region_found := false
	for x in range(-24, 24):
		for z in range(-24, 24):
			for lake in wet_land.lakes_in_zone(Vector2i(x, z)):
				patterns[int(lake.soils)] = true
			var region: Dictionary = wet_land._zone_info(Vector2i(x, z)).get("mud", {})
			if not region.is_empty() and not mud_region_found:
				var inside := Vector2i(roundi(region.center.x / 0.5), roundi(region.center.y / 0.5))
				mud_region_found = wet_land._soil(inside).get("top", -1) == SmoothTerrain.MUD
	check(patterns.size() == 3 and mud_region_found, "three kinds of lake shores, and mud regions of about 2 zones")
	var dried := SmoothTerrain.new()
	dried.set_density(Vector3i(0, 3, 0), 0.5, SmoothTerrain.MUD)
	dried.set_density(Vector3i(0, 2, 0), 0.5, SmoothTerrain.MUD)
	check(dried.fall_target(Vector3i(0, 3, 0)) == Vector3i(0, 2, 0) or dried.fall_target(Vector3i(0, 3, 0)) != Vector3i(0, 3, 0), "mud slides like sand")
	# 0.0.5.22 (#128) : niveaux de détail : relief simplifié au-delà de la distance d'affichage, jusqu'à la distance lointaine.
	var far_world: Node3D = WorldScene.instantiate()
	far_world.generation_options = load("res://scripts/world_generation.gd").defaults()
	far_world.load_distance = 3
	far_world.far_distance = 16
	root.add_child(far_world)
	far_world.finish_terrain()
	check(far_world.far_tiles.size() > 20, "far terrain tiles around the detailed area")
	# 0.0.6 : tout le détail affiché : plus rien du lointain dessous, sauf 2 m sous son bord (pas de fente).
	var far_ok: bool = far_world.far_tiles.values()[0].mesh.get_faces().size() > 0
	for tile in far_world.far_tiles:
		for vertex in far_world.far_tiles[tile].mesh.get_faces():
			far_ok = far_ok and not far_world.near_area.grow(-2.1).has_point(Vector2(vertex.x, vertex.z))
	check(far_ok and far_world.environment.fog_depth_end == 16 * 8.0, "far terrain stops under the edge of the detailed terrain; mist at the far distance")
	var cells := {}
	for tile in far_world.far_tiles:
		cells[far_world.far_tiles[tile].get_meta("cell")] = true
	check(cells.has(2.0) and cells.has(4.0), "far terrain: a point every 2 m near the player, every 4 m further (faster)")
	# 0.0.6 : une colonne à portée mais pas encore affichée garde le relief lointain (plus de montagne coupée en avançant).
	var waiting := Vector2i(2, 1)
	far_world.built_columns.erase(waiting)
	far_world._far_follow_column(waiting)
	far_world.finish_terrain()
	var waiting_tile: Vector2i = FarTerrain.tile_of(waiting)
	var covers := false
	if far_world.far_tiles.has(waiting_tile):
		for vertex in far_world.far_tiles[waiting_tile].mesh.get_faces():
			covers = covers or Rect2(Vector2(waiting) * 8.0, Vector2.ONE * 8.0).grow(-1.0).has_point(Vector2(vertex.x, vertex.z))
	check(covers, "far terrain stays over a column in range that is not shown yet")
	far_world.built_columns[waiting] = true
	far_world._far_follow_column(waiting)
	far_world.finish_terrain()
	var uncovered: bool = not far_world.far_tiles.has(waiting_tile)
	if not uncovered:
		uncovered = true
		for vertex in far_world.far_tiles[waiting_tile].mesh.get_faces():
			uncovered = uncovered and not Rect2(Vector2(waiting) * 8.0, Vector2.ONE * 8.0).grow(-2.1).has_point(Vector2(vertex.x, vertex.z))
	check(uncovered, "once the column is shown, the far terrain leaves it")
	# 0.0.5.32 (version 10) : parfois un trou de boue, plus bas que ses bords, sans eau.
	var pit_found := {}
	for x in range(-24, 24):
		for z in range(-24, 24):
			var pit_info: Dictionary = wet_land._zone_info(Vector2i(x, z))
			if pit_info.has("mud_pit") and wet_land.water_level_at(pit_info.mud_pit.center) == -INF and wet_land.mountain_lift(pit_info.mud_pit.center) == 0.0:
				pit_found = pit_info.mud_pit
	var pit_column := Vector2i(roundi(pit_found.center.x / 0.5), roundi(pit_found.center.y / 0.5))
	var pit_top := Vector3i(pit_column.x, floori(wet_land.ground_height(pit_column) / 0.5), pit_column.y)
	check(wet_land.natural_kind(pit_top) == SmoothTerrain.MUD and wet_land.muddy(pit_column) and wet_land._mud_pit_depth(pit_found.center) >= 0.5, "mud pit: a hollow of mud, no grass")
	# 0.0.5.33 (version 11) : montagnes de sable dans les déserts, plus petites, en sable et sans pierre.
	var dune := {}
	var dune_land := SmoothTerrain.new()
	for dune_seed in range(1, 30):
		if not dune.is_empty():
			break
		dune_land = SmoothTerrain.new()
		dune_land.setup(dune_seed, [], load("res://scripts/world_generation.gd").defaults())
		for found in dune_land._all_mountains():
			if found.get("sand", false):
				dune = found
	var dune_column := Vector2i(roundi(dune.center.x / 0.5), roundi(dune.center.y / 0.5))
	var dune_top := Vector3i(dune_column.x, floori(dune_land.ground_height(dune_column) / 0.5), dune_column.y)
	check(dune.height <= 16.0 and dune_land.mountain_lift(dune.center) > 5.0 and dune_land.natural_kind(dune_top) == SmoothTerrain.SAND, "sand mountains: smaller, covered with sand")
	# 0.0.5.34 (version 12) : petits lacs sur des replats : fond sous l'eau, terrasse tout autour au-dessus de l'eau.
	var slope_lakes := 0
	var slope_ok := true
	for x in range(-24, 24):
		for z in range(-24, 24):
			for lake in wet_land.lakes_in_zone(Vector2i(x, z)):
				if lake.has("on_mountain"):
					slope_lakes += 1
					slope_ok = slope_ok and wet_land.height_at(lake.center.x, lake.center.y) < lake.level
					for outline_point: Vector2 in wet_land.lake_outline(lake):
						var rim: Vector2 = lake.center + outline_point
						slope_ok = slope_ok and wet_land.height_at(rim.x, rim.y) >= lake.level - 0.05
	var flat_shelf := true
	for x in range(-24, 24):
		for z in range(-24, 24):
			for lake in wet_land.lakes_in_zone(Vector2i(x, z)):
				if lake.has("on_mountain"):
					var side: Vector2 = lake.center + Vector2.RIGHT * (lake.radius + lake.wobble + 1.5)
					flat_shelf = flat_shelf and absf(wet_land.height_at(side.x, side.y) - lake.level) < 0.5
	check(slope_lakes > 0 and slope_ok and flat_shelf, "mountain lakes: on a flat shelf, water never spilling down the slope")
	# 0.0.5.37 (version 14) : grottes : du vide sous terre, des entrées, la Roche-mère jamais creusée.
	var cave_land := SmoothTerrain.new()
	cave_land.setup(70621, [[Vector2(0.5, 0.5), 9.0]], load("res://scripts/world_generation.gd").defaults())
	cave_land.caves_in_zone(Vector3i.ZERO)
	var a_node: Dictionary = {}
	var reaches_floor := false
	for zone: Vector3i in cave_land._cave_zones:
		for node in cave_land._cave_zones[zone]:
			a_node = node
			reaches_floor = reaches_floor or node.at.y - node.radius <= SmoothTerrain.layers_of(cave_land.generation_options)[3] * 0.5
	check(not a_node.is_empty() and cave_land.density(SmoothTerrain.point_of(a_node.at)) < 0.0 and reaches_floor, "caves carve the ground, some down to Roche-mère")
	var rock_ok := true
	for x in range(-100, 100, 3):
		for z in range(-100, 100, 3):
			rock_ok = rock_ok and cave_land.density(Vector3i(x, cave_land.mother_rock_top, z)) > 0.0
	check(rock_ok and cave_land.cave_open(Vector2i(1, 1)) == false, "Roche-mère never carved, no cave at the start")
	var cave_zone: Vector3i = cave_land._cave_zones.keys().filter(func(zone: Vector3i): return zone.y < -1)[0]
	check(cave_land.zone_mesh(cave_zone)[0].size() > 0 or cave_land.zone_mesh(cave_zone + Vector3i.UP)[0].size() > 0, "cave walls are drawn underground")
	# 0.0.5.37 : crevasses en éclair : un bout à peine creusé, l'autre très profond, zones basses dessinées.
	cave_land.caves_in_zone(Vector3i.ZERO)
	var last_piece := {}
	for x in range(-24, 24):
		for z in range(-24, 24):
			for crack in cave_land._crevasses_near(Vector2i(x, z)):
				if crack.to > 0.999:
					last_piece = crack
	var deep_end: Vector2 = last_piece.b
	var deep_column := Vector2i(roundi(deep_end.x / 0.5), roundi(deep_end.y / 0.5))
	var deep_area := Vector2i(floori(deep_end.x / 8.0), floori(deep_end.y / 8.0))
	check(cave_land.ground_height(deep_column) < -8.0 and cave_land.in_crevasse(deep_end) and cave_land.muddy(deep_column), "crevasse: very deep at its far end, no grass inside")
	check(cave_land.surface_zones(deep_area, deep_area).has(Vector3i(deep_area.x, floori(cave_land.ground_height(deep_column) / 8.0), deep_area.y)), "low zones of a crevasse are drawn")
	# Plus de retour au départ dans une grotte : seulement sous le monde.
	var deep_world: Node3D = WorldScene.instantiate()
	deep_world.generation_options = load("res://scripts/world_generation.gd").defaults()
	root.add_child(deep_world)
	deep_world.player.set_physics_process(false)
	deep_world.player.global_position = Vector3(40, -20, 40)
	deep_world.player.step_movement(1.0 / 60.0, Vector2.ZERO, false)
	check(deep_world.player.global_position.y < -19.0, "going down a cave does not send the player back to the start")
	deep_world.player.global_position = Vector3(40, -40, 40)
	deep_world.player.step_movement(1.0 / 60.0, Vector2.ZERO, false)
	check(deep_world.player.global_position.y > -10.0, "falling under the world still returns to the start")
	close(deep_world)
	# 0.0.5.31 : boue et argile un peu glissantes, surtout en descente ; l'argile moins que la boue.
	var player_script: Script = far_world.player.get_script()
	var slope := Vector3(0.5, 0.866, 0.0)
	var mud_slide: Vector2 = player_script.slip_motion(SmoothTerrain.MUD, slope, Vector2.ZERO, Vector2.ZERO, 1.0)
	var clay_slide: Vector2 = player_script.slip_motion(SmoothTerrain.CLAY, slope, Vector2.ZERO, Vector2.ZERO, 1.0)
	check(mud_slide.x > clay_slide.x and clay_slide.x > 0.0 and mud_slide.x <= 2.0, "on a slope mud slides downhill a little, clay less")
	check(player_script.slip_motion(SmoothTerrain.DIRT, slope, Vector2(3, 0), Vector2.ZERO, 0.016) == Vector2(3, 0), "other ground does not slide")
	check(player_script.slip_motion(SmoothTerrain.MUD, Vector3.UP, Vector2.ZERO, Vector2.ZERO, 1.0) == Vector2.ZERO, "standing on flat mud: no slide")
	var early: Vector2 = player_script.slip_motion(SmoothTerrain.MUD, Vector3.UP, Vector2(3, 0), Vector2.ZERO, 0.016)
	check(early.x > 0.0 and early.x < 3.0, "on flat mud the step only lags a little")
	far_world.terrain.set_density(Vector3i(100, 2, 100), 0.5, SmoothTerrain.MUD)
	check(far_world.ground_kind_under(Vector3(50.0, 1.3, 50.0)) == SmoothTerrain.MUD, "player finds the mud under the feet")
	# Dans le vrai déplacement : le joueur immobile sur une pente de boue descend, sur la même pente de terre non.
	var slide_distance := func(kind: int) -> float:
		var ramp := StaticBody3D.new()
		var ramp_shape := CollisionShape3D.new()
		var ramp_box := BoxShape3D.new()
		ramp_box.size = Vector3(60, 1, 60)
		ramp_shape.shape = ramp_box
		ramp.add_child(ramp_shape)
		ramp.position = Vector3(50, 40, 50)
		ramp.rotation_degrees = Vector3(0, 0, -25)
		far_world.add_child(ramp)
		far_world.player.global_position = Vector3(50, 42, 50)
		far_world.player.velocity = Vector3.ZERO
		var old_kind: Callable = far_world.get("test_ground_kind")
		far_world.set("test_ground_kind", func(): return kind)
		for frame in range(60):
			far_world.player.step_movement(1.0 / 60.0, Vector2.ZERO, false)
			await physics_frame
		var start: Vector3 = far_world.player.global_position
		for frame in range(120):
			far_world.player.step_movement(1.0 / 60.0, Vector2.ZERO, false)
			await physics_frame
		far_world.set("test_ground_kind", old_kind)
		var moved: float = absf(far_world.player.global_position.x - start.x)
		ramp.free()
		return moved
	far_world.player.set_physics_process(false)
	var on_dirt: float = await slide_distance.call(SmoothTerrain.DIRT)
	var on_clay: float = await slide_distance.call(SmoothTerrain.CLAY)
	var on_mud: float = await slide_distance.call(SmoothTerrain.MUD)
	print("glisse : terre %.2f, argile %.2f, boue %.2f m en 2 s" % [on_dirt, on_clay, on_mud])
	check(on_dirt < 0.05 and on_clay > 0.2 and on_mud > on_clay and on_mud < 8.0, "standing on a slope: mud slides a little, clay less, dirt not at all")
	far_world.player.set_physics_process(true)
	# 0.0.5.25 : relevé en plusieurs fois, identique à d'un coup ; gardé ; eau jamais au-dessus de la rive.
	var far_terrain_script = load("res://scripts/far_terrain.gd")
	var cut_survey: Dictionary = far_terrain_script.new_survey(Vector2i(2, -3), 4.0)
	var whole_survey: Dictionary = far_terrain_script.new_survey(Vector2i(2, -3), 4.0)
	var steps := 0
	while not far_terrain_script.advance(far_world.terrain, cut_survey, 0):
		steps += 1
	far_terrain_script.advance(far_world.terrain, whole_survey, far_world.FAR_NO_LIMIT)
	check(steps > 3 and cut_survey.heights == whole_survey.heights, "far survey spread over several frames gives the same relief")
	var kept: int = far_world.far_surveys.size()
	far_world.update_terrain_view(true)
	far_world.finish_terrain()
	check(far_world.far_surveys.size() == kept, "going over the same far tiles recomputes nothing")
	var dry_shore := true
	var lakes_seen := 0
	for x in range(-24, 24):
		for z in range(-24, 24):
			for lake in wet_land.lakes_in_zone(Vector2i(x, z)):
				lakes_seen += 1
				for outline_point: Vector2 in wet_land.lake_outline(lake):
					var on_shore: Vector2 = lake.center + outline_point
					dry_shore = dry_shore and wet_land.height_at(on_shore.x, on_shore.y) >= lake.level - 0.05
	check(lakes_seen > 0 and dry_shore, "water outline always ends on the shore, never over dry ground")
	far_world.far_distance = 0
	far_world.update_terrain_view(true)
	check(far_world.far_tiles.is_empty(), "far distance 0: no far terrain")
	close(far_world)
	# 0.0.6 (version 16) : neige sur environ 1 montagne sur 4, gravier au pied des montagnes ; rien en version 15.
	var snowy_count := 0
	var rocky_count := 0
	var snow_ok := true
	var gravel_found := false
	for seed_value in [42, 70621, 1040304241]:
		var cold := SmoothTerrain.new()
		cold.setup(seed_value, [], load("res://scripts/world_generation.gd").defaults())
		for found in cold._all_mountains():
			if found.get("sand", false):
				continue
			rocky_count += 1
			if not cold._snowy(found):
				continue
			snowy_count += 1
			var snow_top := Vector2i(roundi(found.center.x / 0.5), roundi(found.center.y / 0.5))
			var foot := Vector2i(roundi((found.center.x + found.radius * found.stretch * 1.2) / 0.5), roundi(found.center.y / 0.5))
			# Pied : sans neige (sauf si une autre montagne y monte, en chaîne).
			if cold.mountain_lift(Vector2(foot) * 0.5) == 0.0:
				snow_ok = snow_ok and cold.snow_depth(foot) == 0.0
			if cold._lift_of(found.center, found) > found.height * 0.7:
				snow_ok = snow_ok and cold.snow_depth(snow_top) > 0.0 and cold.surface_kind(snow_top) == SmoothTerrain.SNOW
		for found in cold._all_mountains():
			for angle in range(0, 360, 15):
				var at: Vector2 = found.center + Vector2.from_angle(deg_to_rad(angle)) * found.radius * 0.78
				gravel_found = gravel_found or cold.surface_kind(Vector2i(roundi(at.x / 0.5), roundi(at.y / 0.5))) == SmoothTerrain.GRAVEL
	check(rocky_count > 10 and snowy_count > 0 and snowy_count < rocky_count * 0.45 and snow_ok, "snow on about 1 mountain in 4, on the upper slopes only (%d of %d)" % [snowy_count, rocky_count])
	check(gravel_found, "gravel scree at the foot of mountains")
	var older := SmoothTerrain.new()
	var options_15: Dictionary = load("res://scripts/world_generation.gd").defaults()
	options_15.version = 15
	older.setup(42, [], options_15)
	var none_older := true
	for found in older._all_mountains():
		none_older = none_older and older.snow_depth(Vector2i(roundi(found.center.x / 0.5), roundi(found.center.y / 0.5))) == 0.0
	check(none_older, "worlds of version 15 never get snow (existing worlds never change)")
	# 0.0.6.3 (version 17) : lacs de montagne jamais collés : l'eau ne dépasse plus du sol ; version 16 inchangée.
	var floating_water := 0
	var lakes_17 := 0
	for seed_value in [42, 5, 1040304241]:
		var tidy := SmoothTerrain.new()
		tidy.setup(seed_value, [], load("res://scripts/world_generation.gd").defaults())
		tidy._mountain_lakes_of(Vector2i.ZERO)
		for zone in tidy._mountain_lake_zones:
			for lake in tidy._mountain_lake_zones[zone]:
				lakes_17 += 1
				var tidy_level: float = tidy.lake_level(lake)
				for p: Vector2 in tidy.lake_outline(lake):
					floating_water += 1 if tidy.height_at(lake.start.x + p.x, lake.start.y + p.y) < tidy_level - 0.05 else 0
	check(lakes_17 > 30 and floating_water == 0, "mountain lakes (version 17): water never floats past the ground (%d lakes)" % lakes_17)
	var options_16: Dictionary = load("res://scripts/world_generation.gd").defaults()
	options_16.version = 16
	var older_lakes := SmoothTerrain.new()
	older_lakes.setup(42, [], options_16)
	older_lakes._mountain_lakes_of(Vector2i.ZERO)
	var count_16 := 0
	for zone in older_lakes._mountain_lake_zones:
		count_16 += older_lakes._mountain_lake_zones[zone].size()
	check(count_16 == 55 and older_lakes.pebbles_in_zone(Vector2i(3, 3)).is_empty(), "version 16 worlds keep their lakes and get no pebbles")
	# 0.0.6.3 : cailloux : 7 tailles, le plus gros pas plus grand que le plus petit rocher ; même graine = mêmes cailloux.
	check(Rocks.PEBBLE_SIZES.size() == 7 and Rocks.PEBBLE_SIZES[6] <= Rocks.SIZES[0] and Rocks.PEBBLE_SIZES[0] < Rocks.PEBBLE_SIZES[6], "7 pebble sizes, the biggest no larger than the smallest rock")
	var pebbles_a := SmoothTerrain.new()
	var pebbles_b := SmoothTerrain.new()
	pebbles_a.setup(42, [], load("res://scripts/world_generation.gd").defaults())
	pebbles_b.setup(42, [], load("res://scripts/world_generation.gd").defaults())
	var same_pebbles := true
	var pebble_total := 0
	var on_gravel := 0
	var by_size := [0, 0, 0, 0, 0, 0, 0]
	for x in range(-16, 16):
		for z in range(-16, 16):
			var list_a: Array = pebbles_a.pebbles_in_zone(Vector2i(x, z))
			same_pebbles = same_pebbles and list_a == pebbles_b.pebbles_in_zone(Vector2i(x, z))
			for pebble in list_a:
				pebble_total += 1
				by_size[pebble.taille - 1] += 1
				on_gravel += 1 if pebbles_a.surface_kind(Vector2i(roundi(pebble.x / 0.5), roundi(pebble.z / 0.5))) == SmoothTerrain.GRAVEL else 0
	check(same_pebbles and pebble_total > 1000, "same seed, same pebbles (%d)" % pebble_total)
	check(by_size[0] > by_size[3] and by_size[3] > by_size[6] and on_gravel * 5 > pebble_total, "more small pebbles than big ones, many on the gravel")
	# Casse à la pioche : les petits en 1 coup, les gros en 3 ; cassés, ils ne reviennent pas.
	var pebble_folder := FOLDER + "-cailloux"
	Store.delete_folder(pebble_folder)
	var pebble_world: Node3D = WorldScene.instantiate()
	pebble_world.generation_options = load("res://scripts/world_generation.gd").defaults()
	pebble_world.terrain_seed = 42
	pebble_world.save_folder = pebble_folder
	pebble_world.load_distance = 4
	root.add_child(pebble_world)
	pebble_world.finish_terrain()
	var small_pebble: StaticBody3D = null
	var big_pebble: StaticBody3D = null
	for each in pebble_world.get_tree().get_nodes_in_group("pebbles"):
		if each.get_meta("pebble").x <= 4 and small_pebble == null:
			small_pebble = each
		if each.get_meta("pebble").x >= 5 and (big_pebble == null or each.get_meta("pebble").x > big_pebble.get_meta("pebble").x):
			big_pebble = each
	var big_id: String = big_pebble.get_meta("id")
	var needed: int = Rocks.PEBBLE_HITS[big_pebble.get_meta("pebble").x - 1]
	pebble_world.player.selected_type = pebble_world.PICKAXE
	var small_id: String = small_pebble.get_meta("id")
	pebble_world.player.global_position = small_pebble.global_position + Vector3(1.0, 0.0, 0.0)
	pebble_world.break_target({"collider": small_pebble, "position": small_pebble.global_position, "normal": Vector3.UP})
	check(pebble_world.broken_pebbles.has(small_id) and not is_instance_valid(small_pebble), "a small pebble breaks in one pickaxe hit")
	# Gros caillou : retrouvé par son identifiant (sa colonne de cailloux est refaite à chaque coup).
	var strikes_done := 0
	for each in pebble_world.get_tree().get_nodes_in_group("pebbles"):
		if is_instance_valid(each) and each.get_meta("id") == big_id:
			pebble_world.strike_pebble(each)
			strikes_done += 1
			break
	check(not pebble_world.broken_pebbles.has(big_id) and pebble_world.pebble_hits.get(big_id, 0) == 1, "a big pebble needs more hits")
	for more_hits in range(5):
		if pebble_world.broken_pebbles.has(big_id):
			break
		for each in pebble_world.get_tree().get_nodes_in_group("pebbles"):
			if is_instance_valid(each) and each.get_meta("id") == big_id:
				pebble_world.strike_pebble(each)
				strikes_done += 1
				break
	check(pebble_world.broken_pebbles.has(big_id) and strikes_done == needed and needed >= 2, "a big pebble breaks after its number of hits (%d)" % needed)
	check(pebble_world.save_now() and FileAccess.get_file_as_string(pebble_folder.path_join(Store.OBJECTS_FILE)).contains(small_id), "broken pebbles saved in objets.json")
	close(pebble_world)
	var pebble_again: Node3D = WorldScene.instantiate()
	pebble_again.generation_options = load("res://scripts/world_generation.gd").defaults()
	pebble_again.terrain_seed = 42
	pebble_again.save_folder = pebble_folder
	pebble_again.load_distance = 4
	root.add_child(pebble_again)
	pebble_again.finish_terrain()
	var back := false
	for each in pebble_again.get_tree().get_nodes_in_group("pebbles"):
		back = back or each.get_meta("id") == small_id
	check(not back and pebble_again.get_tree().get_nodes_in_group("pebbles").size() > 50, "a broken pebble never comes back")
	close(pebble_again)
	Store.delete_folder(pebble_folder)
	# 0.0.6 : sous l'eau : brume bleu-vert proche et voile ; en sortant, la brume normale revient.
	var lake_world: Node3D = WorldScene.instantiate()
	lake_world.generation_options = load("res://scripts/world_generation.gd").defaults()
	lake_world.terrain_seed = 42
	root.add_child(lake_world)
	lake_world.player.set_physics_process(false)
	var lake_spot := Vector2.INF
	for r in range(10, 240, 4):
		for angle in range(0, 360, 15):
			var at := Vector2.from_angle(deg_to_rad(angle)) * r
			if lake_spot == Vector2.INF and lake_world.terrain.water_level_at(at) > lake_world.terrain.height_at(at.x, at.y) + 1.5:
				lake_spot = at
	var surface: float = lake_world.terrain.water_level_at(lake_spot)
	var dry_fog: float = lake_world.environment.fog_depth_end
	lake_world.player.position = Vector3(lake_spot.x, surface - 2.6, lake_spot.y)
	await process_frame
	await process_frame
	check(lake_world.underwater and lake_world.underwater_veil.visible and lake_world.environment.fog_depth_end < 20.0, "underwater: close blue-green mist and a tinted veil")
	lake_world.player.position = Vector3(lake_spot.x, surface + 3.0, lake_spot.y)
	await process_frame
	await process_frame
	check(not lake_world.underwater and not lake_world.underwater_veil.visible and lake_world.environment.fog_depth_end == dry_fog, "out of the water: normal mist again")
	close(lake_world)
	print("RESULT: %d smooth terrain checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
