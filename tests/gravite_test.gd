extends SceneTree
# 0.0.8.29 (demande de l'utilisateur : physique et gravité fiables, rien en l'air sans appui) : mesures.
# - Rocher taillé à la pioche (tout le tour, au hasard, par-dessous) : après chaque coup, aucun bout en l'air (avant :
#   21 rochers sur 21 finissaient avec un bout en l'air, jusqu'à 4 359 litres) ; un coup donne un caillou et un éclat.
# - Cailloux de la graine près du joueur : jamais à plus de 2 cm en l'air (avant : jusqu'à 23 cm), aucun sous un rocher
#   (génération 34 ; la génération 33 ne change pas).
# - Creuser sous un caillou, sous un rocher, sous un objet posé : ils redescendent sur le nouveau sol (avant : 1,4 à
#   2,8 m en l'air) ; un trou plus petit que le rocher ne le fait pas descendre ; un rocher descendu se taille encore.
const Store = preload("res://scripts/world_store.gd")
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
const WorldScene = preload("res://scenes/world.tscn")
const Inventory = preload("res://scripts/inventory.gd")
const Rocks = preload("res://scripts/rocks.gd")
const GroundItems = preload("res://scripts/ground_items.gd")
const FOLDER := "res://.godot/gravite-test-monde"
var checks := 0
var failures := 0
var w: Node3D

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func frames(count: int) -> void:
	for index in range(count):
		await process_frame
		await physics_frame

# Sol dessiné (terrain seulement) sous un point ; NAN sans mesure.
func ground_y(x: float, z: float, top: float, with_rocks := false) -> float:
	var space: PhysicsDirectSpaceState3D = w.get_world_3d().direct_space_state
	for shift in [Vector3.ZERO, Vector3(0.04, 0.0, 0.04)]:
		var from: Vector3 = Vector3(x, top, z) + shift
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0, 1)
		var excluded := [w.player.get_rid()]
		for attempt in range(8):
			query.exclude = excluded
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				break
			if is_instance_valid(hit.collider) and (hit.collider.is_in_group("ground") or (with_rocks and hit.collider.is_in_group("rocks"))):
				return hit.position.y
			excluded.append(hit.rid)
	return NAN

func points_of(mesh: Mesh, limit: int) -> Array:
	var seen := {}
	for surface in range(mesh.get_surface_count()):
		for point in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			seen[point.snappedf(0.0005)] = true
	var list: Array = seen.keys()
	if list.size() <= limit:
		return list
	var kept := []
	for index in range(limit):
		kept.append(list[int(index * float(list.size()) / limit)])
	return kept

# Litres d'un rocher taillé qui ne touchent plus le sol (même par d'autres morceaux).
func floating(body: Node) -> float:
	if not is_instance_valid(body) or body.is_queued_for_deletion() or not body.has_meta("grid"):
		return 0.0
	var grid: Dictionary = body.get_meta("grid")
	var removed: Array = w.carved_rocks.get(body.get_meta("id"), [])
	var values: PackedFloat32Array = Rocks.carved_values(grid, removed.map(func(entry): return Vector3(entry[0], entry[1], entry[2]) * SmoothTerrain.STEP))
	var count: int = grid.count
	var step: float = grid.step
	var origin: Vector3 = grid.origin
	var state := PackedByteArray()
	state.resize(count * count * count)
	var stack := PackedInt32Array()
	for x in range(count):
		for z in range(count):
			var at := origin + Vector3(x, 0, z) * step
			var ground: float = w.terrain.height_at(at.x, at.z)
			for y in range(count):
				var index := (x * count + y) * count + z
				if values[index] >= 0.0:
					continue
				state[index] = 1
				if origin.y + y * step <= ground + step * 1.5:
					state[index] = 2
					stack.append(index)
	while not stack.is_empty():
		var index: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var x := index / (count * count)
		var y := (index / count) % count
		var z := index % count
		for offset in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var nx: int = x + offset.x
			var ny: int = y + offset.y
			var nz: int = z + offset.z
			if nx < 0 or ny < 0 or nz < 0 or nx >= count or ny >= count or nz >= count:
				continue
			var next := (nx * count + ny) * count + nz
			if state[next] == 1:
				state[next] = 2
				stack.append(next)
	var cells := 0
	for index in range(state.size()):
		if state[index] == 1:
			cells += 1
	return cells * step * step * step * 1000.0

func rock_low(rock: Node3D) -> float:
	var low := INF
	for child in rock.get_children():
		if child is MeshInstance3D and child.name != "Silex":
			for v: Vector3 in points_of(child.mesh, 300):
				var p: Vector3 = rock.global_transform * v
				var g := ground_y(p.x, p.z, rock.global_position.y + 12.0)
				if not is_nan(g):
					low = minf(low, p.y - g)
	return low

func dig(base: Vector3i, reach: int, down: int) -> void:
	var dug := []
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			for dy in range(-down, 3):
				var point := base + Vector3i(dx, dy, dz)
				if w.terrain.density(point) > 0.0:
					w.terrain.set_density(point, SmoothTerrain.DUG)
					dug.append(point)
	w._refresh_terrain(dug)

func go_to(spot: Vector3) -> void:
	w.player.global_position = Vector3(spot.x, w.terrain.height_at(spot.x, spot.z) + 0.05, spot.z)
	await frames(30)
	w.finish_terrain()
	await frames(6)

func _run() -> void:
	Store.delete_folder(FOLDER)
	w = WorldScene.instantiate()
	w.terrain_seed = 70621
	w.generation_options = load("res://scripts/world_generation.gd").defaults()
	w.save_folder = FOLDER
	w.load_distance = 4
	w.game_mode = Inventory.CREATIVE
	root.add_child(w)
	await frames(5)
	w.player.set_physics_process(false)
	w.finish_terrain()
	await frames(6)
	# --- A. Rochers taillés : jamais un bout en l'air ; un caillou et un éclat par coup. ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var used := {}
	var hits_total := 0
	var worst_floating := 0.0
	var fallen_bits := 0
	var slowest := 0.0
	var pebbles_before: int = w.ground.entries.filter(func(entry): return GroundItems._kind(entry.item) == "caillou").size()
	var chips_before: int = w.ground.entries.filter(func(entry): return GroundItems._kind(entry.item) == "eclat").size()
	for place in [Vector3(0, 0, 0), Vector3(48, 0, 0), Vector3(0, 0, 48), Vector3(-48, 0, -48)]:
		if used.size() >= 6:
			break
		await go_to(place)
		for rock in get_nodes_in_group("rocks"):
			if used.size() >= 6:
				break
			if not is_instance_valid(rock) or used.has(rock.get_meta("id")) or rock.get_meta("rock").x < 3 or rock.get_meta("rock").x > 5 or rock.global_position.distance_to(w.player.global_position) > 20.0:
				continue
			var mode: int = used.size() % 3
			used[rock.get_meta("id")] = true
			var size: float = Rocks.SIZES[int(rock.get_meta("rock").x) - 1]
			var center: Vector3 = rock.global_position
			var ground: float = w.terrain.height_at(center.x, center.z)
			var aims := []
			if mode == 0:
				for depth in range(4):
					for height in [0.3, 0.8]:
						for turn in range(12):
							var dir := Vector3(cos(turn * TAU / 12.0), 0.0, sin(turn * TAU / 12.0))
							aims.append([center + dir * size + Vector3.UP * (ground + height - center.y), -dir])
			elif mode == 1:
				for index in range(60):
					var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1), rng.randf_range(-1, 1)).normalized()
					aims.append([center + dir * (size + 2.0), -dir])
			else:
				for depth in range(10):
					for height in [0.3, 0.8]:
						for side in [-0.5, 0.0, 0.5]:
							aims.append([center + Vector3(size, ground + height - center.y, side), Vector3.LEFT])
			var space: PhysicsDirectSpaceState3D = w.get_world_3d().direct_space_state
			for aim in aims:
				if not is_instance_valid(rock) or rock.is_queued_for_deletion() or w.mined_rocks.has(rock.get_meta("id")):
					break
				var query := PhysicsRayQueryParameters3D.create(aim[0], aim[0] + aim[1] * (size * 2.0 + 4.0), 1)
				var hit := {}
				var excluded := [w.player.get_rid()]
				for attempt in range(6):
					query.exclude = excluded
					hit = space.intersect_ray(query)
					if hit.is_empty() or hit.collider == rock:
						break
					excluded.append(hit.rid)
				if hit.is_empty() or hit.collider != rock:
					continue
				var cubes_before: int = w.carved_rocks.get(rock.get_meta("id"), []).size()
				var at := Time.get_ticks_usec()
				if not w.mine_rock(rock, {"position": hit.position, "normal": hit.normal}):
					continue
				slowest = maxf(slowest, (Time.get_ticks_usec() - at) / 1000.0)
				hits_total += 1
				if w.carved_rocks.get(rock.get_meta("id"), []).size() > cubes_before + 1:
					fallen_bits += 1
				await physics_frame
				worst_floating = maxf(worst_floating, floating(rock))
	check(used.size() >= 6 and hits_total >= 100, "rocks carved all around, at random and from below (%d rocks, %d hits)" % [used.size(), hits_total])
	check(worst_floating <= 0.0, "after every hit, nothing left in the air (worst: %.0f litres ; before 0.0.8.29: up to 4 359 litres)" % worst_floating)
	check(fallen_bits >= 5, "bits that no longer held fell (%d times)" % fallen_bits)
	var pebbles_now: int = w.ground.entries.filter(func(entry): return GroundItems._kind(entry.item) == "caillou").size()
	var chips_now: int = w.ground.entries.filter(func(entry): return GroundItems._kind(entry.item) == "eclat").size()
	check(pebbles_now - pebbles_before >= mini(hits_total, 40) and chips_now > chips_before, "each hit gives a small pebble and a chip (%d pebbles, %d chips on the ground)" % [pebbles_now - pebbles_before, chips_now - chips_before])
	check(slowest < 60.0 or OS.get_environment("GITHUB_ACTIONS") == "true", "a pickaxe hit on a rock stays short: %.1f ms at most (the time is judged on the PC only)" % slowest)
	# --- B. Cailloux de la graine près du joueur : sur le sol, aucun sous un rocher. ---
	await go_to(Vector3(0, 0, 0))
	await frames(6)
	var measured := 0
	var highest := -INF
	var buried := 0
	var home: Vector2i = w._player_column()
	for column: Vector2i in w.column_pebbles:
		for spec: Array in w.pebble_bodies.get(column, []):
			var at: Vector3 = spec[4]
			var basis := Basis(Vector3.UP, deg_to_rad(float(spec[6]))).scaled(Vector3.ONE * float(spec[3]))
			var low := INF
			var below := 0
			var count := 0
			for v: Vector3 in points_of(Rocks.pebble_mesh(int(spec[2])), 60):
				var p: Vector3 = at + basis * v
				var g := ground_y(p.x, p.z, at.y + 4.0)
				if is_nan(g):
					continue
				count += 1
				low = minf(low, p.y - g)
				if p.y < g:
					below += 1
			if count < 10:
				continue
			measured += 1
			highest = maxf(highest, low)
			if below > count * 0.75:
				buried += 1
	check(measured >= 60, "pebbles measured near the player (%d)" % measured)
	check(highest <= 0.02, "no pebble in the air: the highest is %.1f cm above the ground (before: up to 23 cm)" % (highest * 100.0))
	check(buried == 0, "no pebble more than three quarters in the ground (%d)" % buried)
	var under := 0
	var under_before := 0
	var fewer := true
	var counted := 0
	for x in range(-10, 10):
		for z in range(-10, 10):
			var zone := Vector2i(x, z)
			w.terrain._pebbles_clear_of_rocks = false
			var before: Array = w.terrain.pebbles_in_zone(zone)
			w.terrain._pebbles_clear_of_rocks = true
			var now: Array = w.terrain.pebbles_in_zone(zone)
			counted += now.size()
			var ids := before.map(func(pebble): return pebble.id)
			for pebble in now:
				fewer = fewer and pebble.id in ids
				if w.terrain._under_rock(Vector2(pebble.x, pebble.z), 0.0):
					under += 1
			under_before += before.size() - now.size()
	check(counted > 1000 and under == 0 and under_before > 0 and fewer, "generation 34: no pebble under a rock (%d pebbles ; %d taken away, the others are the same as in generation 33)" % [counted, under_before])
	# --- C. Creuser sous un caillou : il redescend sur le nouveau sol. ---
	var tried := 0
	var pebble_gap := 0.0
	var pebble_fall := INF
	for column: Vector2i in w.column_pebbles.keys():
		if tried >= 4 or maxi(absi(column.x - home.x), absi(column.y - home.y)) > 1:
			continue
		var specs: Array = w.pebble_bodies.get(column, [])
		if specs.is_empty():
			continue
		var spec: Array = specs[0]
		var id: String = spec[0]
		var start: Vector3 = spec[4]
		tried += 1
		dig(SmoothTerrain.point_of(start), 2, 3)
		await frames(8)
		for other: Array in w.pebble_bodies.get(column, []):
			if other[0] == id:
				var at: Vector3 = other[4]
				var g := ground_y(at.x, at.z, start.y + 3.0)
				pebble_gap = maxf(pebble_gap, absf(at.y - float(other[9]) - g))
				pebble_fall = minf(pebble_fall, start.y - at.y)
				var node: Node3D = null
				for body in w.column_pebbles.get(column, []):
					if is_instance_valid(body) and body.get_meta("id") == id:
						node = body
				check(node != null and node.position.distance_to(at) < 0.001, "the pebble's collision followed it")
	check(tried >= 3 and pebble_gap <= 0.03 and pebble_fall > 0.8, "ground dug under %d pebbles: they came down %.2f m or more and rest %.1f cm from the new ground at most (before: 1.4 to 1.8 m in the air)" % [tried, pebble_fall, pebble_gap * 100.0])
	# --- D. Creuser sous un rocher : sous tout son appui, il descend ; sous un côté seulement, il reste. ---
	var rocks := get_nodes_in_group("rocks").filter(func(r): return is_instance_valid(r) and not used.has(r.get_meta("id")) and not w.carved_rocks.has(r.get_meta("id")) and r.global_position.distance_to(w.player.global_position) < 30.0 and r.get_meta("rock").x <= 4)
	check(rocks.size() >= 2, "untouched rocks near the player (%d)" % rocks.size())
	if rocks.size() >= 2:
		var bridge: Node3D = rocks[0]
		await go_to(bridge.global_position + Vector3(4.0, 0.0, 4.0))
		var size: float = Rocks.SIZES[int(bridge.get_meta("rock").x) - 1]
		var beside: Vector3 = bridge.global_position + Vector3(size * 0.5 + 0.6, 0.0, 0.0)
		var height: float = bridge.global_position.y
		dig(SmoothTerrain.point_of(Vector3(beside.x, w.terrain.height_at(beside.x, beside.z), beside.z)), 0, 4)
		await frames(40)
		check(absf(bridge.global_position.y - height) < 0.001 and float(bridge.get_meta("drop", 0.0)) == 0.0, "a hole beside a rock: it does not move")
		var rock: Node3D = rocks[1]
		await go_to(rock.global_position + Vector3(4.0, 0.0, 4.0))
		size = Rocks.SIZES[int(rock.get_meta("rock").x) - 1]
		height = rock.global_position.y
		var low_before := rock_low(rock)
		var under_rock: Vector3 = rock.global_position
		dig(SmoothTerrain.point_of(Vector3(under_rock.x, w.terrain.height_at(under_rock.x, under_rock.z), under_rock.z)), ceili(size / SmoothTerrain.STEP * 0.5) + 2, 4)
		await frames(60)
		var low_after := rock_low(rock)
		check(height - rock.global_position.y > 1.0 and low_after <= 0.05 and low_after > -size * 0.5, "ground dug under a whole rock: it came down %.2f m ; its lowest point is %.1f cm from the new ground (before the dig: %.1f cm ; before 0.0.8.29: 2.5 to 2.8 m in the air)" % [height - rock.global_position.y, low_after * 100.0, low_before * 100.0])
		check(is_equal_approx(float(rock.get_meta("drop", 0.0)), w._rock_drop(rock.global_position.x, rock.global_position.z, int(rock.get_meta("rock").x))), "its place comes from the dug ground alone (nothing more to save)")
		# Le rocher descendu se taille encore, là où on le frappe.
		var top: Vector3 = rock.global_position + Vector3.UP * (size + 1.0)
		var space: PhysicsDirectSpaceState3D = w.get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * (size * 2.0 + 2.0), 1)
		query.exclude = [w.player.get_rid()]
		var hit := space.intersect_ray(query)
		check(not hit.is_empty() and hit.collider == rock and w.mine_rock(rock, {"position": hit.position, "normal": hit.normal}), "the rock that came down is still carved")
		if not hit.is_empty() and hit.collider == rock:
			await frames(2)
			var cube: Array = w.carved_rocks.get(rock.get_meta("id"), [[0, 0, 0]])[0]
			var carved_at: Vector3 = Vector3(cube[0], cube[1], cube[2]) * SmoothTerrain.STEP - Vector3.UP * float(rock.get_meta("drop", 0.0))
			check(carved_at.distance_to(hit.position) < 0.75, "carved where it was hit (%.2f m from the hit)" % carved_at.distance_to(hit.position))
			var again := space.intersect_ray(query)
			check(again.is_empty() or again.collider != rock or again.position.y < hit.position.y - 0.1, "its shape changed at the hit (what lies under the hit is %.2f m lower)" % (hit.position.y - (again.position.y if not again.is_empty() else hit.position.y)))
			check(floating(rock) <= 0.0, "nothing in the air on the rock that came down")
	# --- E. Creuser sous un objet posé : il redescend. ---
	var spot: Vector3 = w.player.global_position + Vector3(2.5, 0.0, 1.5)
	spot.y = ground_y(spot.x, spot.z, spot.y + 4.0)
	var index: int = w.ground.drop({"objet": "eclat_pierre", "poids": 125.0}, spot + Vector3.UP * 0.02, spot, w._rest_height, 0.0)
	await frames(4)
	var item_start: Vector3 = w.ground.entries[index].position
	dig(SmoothTerrain.point_of(spot), 1, 3)
	await frames(10)
	var item_now: Vector3 = w.ground.entries[index].position
	var item_ground := ground_y(item_now.x, item_now.z, item_start.y + 2.0)
	check(item_start.y - item_now.y > 0.8 and absf(item_now.y - GroundItems.lift(w.ground.entries[index].item) - item_ground) <= 0.03, "ground dug under an object: it came down %.2f m and rests %.1f cm from the new ground" % [item_start.y - item_now.y, absf(item_now.y - GroundItems.lift(w.ground.entries[index].item) - item_ground) * 100.0])
	check(w.ground.bodies[index].get_meta("ground_index") == index and absf(w.ground.bodies[index].global_position.y - item_now.y) < 0.05, "the object can still be aimed at where it now lies")
	root.remove_child(w)
	w.free()
	Store.delete_folder(FOLDER)
	print("RESULT: %d gravity checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
