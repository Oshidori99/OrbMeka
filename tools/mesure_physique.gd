extends SceneTree
# 0.0.8.29 (demande de l'utilisateur : physique et gravité « pas 100 % ») : état des lieux mesuré, sans fenêtre.
#   & '<Godot console>' --headless --path . --script res://tools/mesure_physique.gd -- <partie>
# Parties : cailloux, pioche, arbres, branches, tailles, terrain. Lignes « MESURE … ».
# Le sol est mesuré ici par des rayons sur les collisions (terrain et rochers), sans passer par les fonctions de pose
# du jeu : la mesure ne partage pas leurs erreurs.
const Store = preload("res://scripts/world_store.gd")
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
const WorldScene = preload("res://scenes/world.tscn")
const Inventory = preload("res://scripts/inventory.gd")
const Rocks = preload("res://scripts/rocks.gd")
const Trees = preload("res://scripts/trees.gd")
const TreeParts = preload("res://scripts/tree_parts.gd")
const GroundItems = preload("res://scripts/ground_items.gd")
const FOLDER := "res://.godot/mesure-physique-monde"
const KIND_NAMES := ["pommier", "noisetier", "pin", "tilleul"]
var w: Node3D
var seed_value := 70621
var last_on_rock := false
var in_rock := 0
var in_rock_hidden := 0

func _initialize() -> void:
	call_deferred("_run")

func out(text: String) -> void:
	print("MESURE " + text)

func frames(count: int) -> void:
	for index in range(count):
		await process_frame
		await physics_frame

func cm(value: float) -> String:
	return "%.1f" % (value * 100.0)

func stats(values: Array) -> String:
	if values.is_empty():
		return "aucun"
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += value
	return "n=%d min=%.1f med=%.1f p95=%.1f max=%.1f moy=%.1f" % [sorted.size(), sorted[0], sorted[sorted.size() / 2], sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))], sorted[-1], total / sorted.size()]

# Sol (terrain ou rocher) sous un point : rayon vers le bas ; NAN sans mesure. skip : RID à ignorer.
func ground_y(x: float, z: float, top: float, skip: Array = []) -> float:
	var space: PhysicsDirectSpaceState3D = w.get_world_3d().direct_space_state
	for shift in [Vector3.ZERO, Vector3(0.04, 0.0, 0.04)]:
		var from: Vector3 = Vector3(x, top, z) + shift
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 60.0, 1)
		var excluded := skip.duplicate()
		excluded.append(w.player.get_rid())
		for attempt in range(8):
			query.exclude = excluded
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				break
			if is_instance_valid(hit.collider) and (hit.collider.is_in_group("ground") or hit.collider.is_in_group("rocks")):
				last_on_rock = hit.collider.is_in_group("rocks")
				return hit.position.y
			excluded.append(hit.rid)
	return NAN

func slope_at(x: float, z: float, reach := 1.0) -> float:
	var t = w.terrain
	var gx: float = (t.height_at(x + reach, z) - t.height_at(x - reach, z)) / (2.0 * reach)
	var gz: float = (t.height_at(x, z + reach) - t.height_at(x, z - reach)) / (2.0 * reach)
	return rad_to_deg(atan(Vector2(gx, gz).length()))

func downhill_at(x: float, z: float, reach := 2.0) -> Vector3:
	var t = w.terrain
	var gx: float = (t.height_at(x + reach, z) - t.height_at(x - reach, z)) / (2.0 * reach)
	var gz: float = (t.height_at(x, z + reach) - t.height_at(x, z - reach)) / (2.0 * reach)
	var down := Vector3(-gx, 0.0, -gz)
	return down.normalized() if down.length() > 0.001 else Vector3.FORWARD

func go_to(spot: Vector3) -> void:
	w.player.global_position = Vector3(spot.x, w.terrain.height_at(spot.x, spot.z) + 0.05, spot.z)
	await frames(30)
	w.finish_terrain()
	await frames(4)

# Endroits : plat, pente moyenne, pente forte, autour de l'origine.
func find_sites() -> Dictionary:
	var sites := {}
	var wanted := {"plat": Vector2(0.0, 3.0), "pente15": Vector2(12.0, 18.0), "pente30": Vector2(26.0, 36.0)}
	for ring in range(1, 30):
		for x in range(-ring, ring + 1):
			for z in range(-ring, ring + 1):
				if maxi(absi(x), absi(z)) != ring:
					continue
				var at := Vector2(x * 4.0, z * 4.0)
				# La même pente sur 6 m autour (pas une bosse isolée).
				var here := slope_at(at.x, at.y, 2.0)
				var low := here
				var high := here
				for d in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
					var s := slope_at(at.x + d.x, at.y + d.y, 2.0)
					low = minf(low, s)
					high = maxf(high, s)
				for key in wanted:
					if not sites.has(key) and low >= wanted[key].x and high <= wanted[key].y and not rock_near(at):
						sites[key] = Vector3(at.x, w.terrain.height_at(at.x, at.y), at.y)
		if sites.size() == wanted.size():
			break
	for key in sites:
		out("endroit %s : %s, pente %.1f°" % [key, str(sites[key]), slope_at(sites[key].x, sites[key].z, 2.0)])
	return sites

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var part: String = args[0] if args.size() > 0 else "cailloux"
	if args.size() > 1:
		seed_value = int(args[1])
	Store.delete_folder(FOLDER)
	w = WorldScene.instantiate()
	w.terrain_seed = seed_value
	w.generation_options = load("res://scripts/world_generation.gd").defaults()
	w.save_folder = FOLDER
	w.load_distance = 4
	w.game_mode = Inventory.CREATIVE
	root.add_child(w)
	await frames(5)
	w.player.set_physics_process(false)
	w.finish_terrain()
	await frames(3)
	out("partie %s, graine %d, génération %s" % [part, seed_value, str(w.generation_options.get("version", "?"))])
	match part:
		"cailloux":
			await part_pebbles()
		"pioche":
			await part_carving()
		"arbres":
			await part_fell()
		"branches":
			await part_branches()
		"tailles":
			await part_sizes()
		"debug":
			await part_debug()
		"noisetier":
			await part_hazel()
		"terrain":
			await part_terrain()
	root.remove_child(w)
	w.free()
	Store.delete_folder(FOLDER)
	quit(0)

# ---------------------------------------------------------------- Cailloux et rochers de la graine
func unique_points(mesh: Mesh, limit := 100000) -> Array:
	var seen := {}
	for surface in range(mesh.get_surface_count()):
		var points: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for point in points:
			seen[point.snappedf(0.0005)] = true
	var list: Array = seen.keys()
	if list.size() > limit:
		var kept := []
		var stride := float(list.size()) / limit
		for index in range(limit):
			kept.append(list[int(index * stride)])
		return kept
	return list

func part_pebbles() -> void:
	var places := [Vector3(0, 0, 0), Vector3(48, 0, 0), Vector3(0, 0, 48), Vector3(-48, 0, -48), Vector3(96, 0, 96), Vector3(-96, 0, 64)]
	var rows := []
	var rock_rows := []
	var seen_rocks := {}
	var seen := {}
	for place in places:
		await go_to(place)
		var here: Vector2i = w._player_column()
		for column: Vector2i in w.pebble_bodies:
			if maxi(absi(column.x - here.x), absi(column.y - here.y)) > 2:
				continue
			for spec: Array in w.pebble_bodies[column]:
				if seen.has(spec[0]):
					continue
				seen[spec[0]] = true
				var at: Vector3 = spec[4]
				var basis := Basis(Vector3.UP, deg_to_rad(float(spec[6]))).scaled(Vector3.ONE * float(spec[3]))
				var low := INF
				var high := -INF
				var below := 0
				var count := 0
				for v: Vector3 in unique_points(Rocks.pebble_mesh(int(spec[2]))):
					var p: Vector3 = at + basis * v
					var g := ground_y(p.x, p.z, at.y + 4.0)
					if is_nan(g):
						continue
					count += 1
					low = minf(low, p.y - g)
					high = maxf(high, p.y - g)
					if p.y < g:
						below += 1
				if count < 10:
					continue
				var center_ground := ground_y(at.x, at.z, at.y + 4.0)
				if last_on_rock:
					in_rock += 1
					if high < 0.0:
						in_rock_hidden += 1
					continue
				rows.append({"size": int(spec[1]), "d": float(spec[3]), "low": low, "high": high, "share": float(below) / count, "slope": slope_at(at.x, at.z, 0.5), "formula": w.terrain.height_at(at.x, at.z) - center_ground})
		for rock in get_nodes_in_group("rocks"):
			if not is_instance_valid(rock) or seen_rocks.has(rock.get_meta("id")):
				continue
			var column := Vector2i(floori(rock.global_position.x / 8.0), floori(rock.global_position.z / 8.0))
			if maxi(absi(column.x - here.x), absi(column.y - here.y)) > 2:
				continue
			seen_rocks[rock.get_meta("id")] = true
			var mesh: Mesh = null
			for child in rock.get_children():
				if child is MeshInstance3D and child.name != "Silex":
					mesh = child.mesh
			if mesh == null:
				continue
			var low := INF
			var below := 0
			var count := 0
			var under := []
			for v: Vector3 in unique_points(mesh, 400):
				var p: Vector3 = rock.global_transform * v
				var g := ground_y(p.x, p.z, rock.global_position.y + 12.0, [rock.get_rid()])
				if is_nan(g):
					continue
				count += 1
				low = minf(low, p.y - g)
				if p.y < g:
					below += 1
			if count < 20:
				continue
			rock_rows.append({"size": int(rock.get_meta("rock").x), "low": low, "share": float(below) / count, "slope": slope_at(rock.global_position.x, rock.global_position.z, 1.0)})
	out("cailloux sur le terrain : %d ; cailloux placés là où il y a un rocher : %d (dont %d entièrement dans le rocher)" % [rows.size(), in_rock, in_rock_hidden])
	out("cailloux, écart formule du sol − sol réel au centre (cm) : " + stats(rows.map(func(r): return r.formula * 100.0)))
	out("cailloux, point le plus bas au-dessus du sol (cm, > 0 = en l'air) : " + stats(rows.map(func(r): return r.low * 100.0)))
	out("cailloux en l'air (plus bas point > 1 cm au-dessus du sol) : %d ; > 3 cm : %d" % [rows.filter(func(r): return r.low > 0.01).size(), rows.filter(func(r): return r.low > 0.03).size()])
	out("cailloux, part des points sous le sol (%%) : " + stats(rows.map(func(r): return r.share * 100.0)))
	out("cailloux enterrés à plus de 50 %% : %d ; à plus de 75 %% : %d ; entièrement (dessus sous le sol) : %d" % [rows.filter(func(r): return r.share > 0.5).size(), rows.filter(func(r): return r.share > 0.75).size(), rows.filter(func(r): return r.high < 0.0).size()])
	for band in [[0.0, 10.0], [10.0, 25.0], [25.0, 90.0]]:
		var some := rows.filter(func(r): return r.slope >= band[0] and r.slope < band[1])
		out("  pente %d-%d° : %d cailloux ; enterrés > 50 %% : %d ; en l'air > 1 cm : %d ; part sous le sol moy %.0f %%" % [band[0], band[1], some.size(), some.filter(func(r): return r.share > 0.5).size(), some.filter(func(r): return r.low > 0.01).size(), _mean(some.map(func(r): return r.share * 100.0))])
	for size in range(1, 8):
		var some := rows.filter(func(r): return r.size == size)
		if not some.is_empty():
			out("  taille %d (%.0f cm) : %d ; part sous le sol moy %.0f %% ; enterrés > 50 %% : %d" % [size, Rocks.PEBBLE_SIZES[size - 1] * 100.0, some.size(), _mean(some.map(func(r): return r.share * 100.0)), some.filter(func(r): return r.share > 0.5).size()])
	out("rochers mesurés : %d" % rock_rows.size())
	out("rochers, point le plus bas au-dessus du sol (cm) : " + stats(rock_rows.map(func(r): return r.low * 100.0)))
	out("rochers en l'air (> 2 cm) : %d ; part sous le sol (%%) : %s" % [rock_rows.filter(func(r): return r.low > 0.02).size(), stats(rock_rows.map(func(r): return r.share * 100.0))])
	out("rochers enterrés à plus de 50 %% : %d" % rock_rows.filter(func(r): return r.share > 0.5).size())
	# Creuser sous un caillou et sous un rocher : restent-ils en l'air ?
	await go_to(Vector3(0, 0, 0))
	var home: Vector2i = w._player_column()
	var tried := 0
	var near_specs := []
	for column: Vector2i in w.pebble_bodies:
		if maxi(absi(column.x - home.x), absi(column.y - home.y)) <= 1:
			for spec: Array in w.pebble_bodies[column]:
				near_specs.append([column, spec])
	for pair in near_specs:
		var spec: Array = pair[1]
		var here: Vector2i = pair[0]
		if tried >= 5:
			break
		tried += 1
		var at: Vector3 = spec[4]
		var before := ground_y(at.x, at.z, at.y + 4.0)
		var dug := []
		var base: Vector3i = SmoothTerrain.point_of(at)
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				for dy in range(-3, 2):
					var point := base + Vector3i(dx, dy, dz)
					if w.terrain.density(point) > 0.0:
						w.terrain.set_density(point, SmoothTerrain.DUG)
						dug.append(point)
		w._refresh_terrain(dug)
		w.finish_terrain()
		await frames(3)
		var after := ground_y(at.x, at.z, at.y + 4.0)
		var still: bool = w.pebble_bodies.get(here, []).any(func(other): return other[0] == spec[0] and (other[4] as Vector3).distance_to(at) < 0.001)
		out("creusé sous un caillou (taille %d) : sol %.2f → %.2f m ; caillou resté à sa place : %s ; en l'air de %s cm" % [int(spec[1]), before, after, str(still), cm(at.y - after)])
	var rock_done := 0
	for rock in get_nodes_in_group("rocks"):
		if rock_done >= 3 or not is_instance_valid(rock) or rock.global_position.distance_to(w.player.global_position) > 14.0:
			continue
		rock_done += 1
		var at: Vector3 = rock.global_position
		var size: float = Rocks.SIZES[int(rock.get_meta("rock").x) - 1]
		var before := ground_y(at.x, at.z, at.y + 12.0, [rock.get_rid()])
		var dug := []
		var base: Vector3i = SmoothTerrain.point_of(Vector3(at.x, before, at.z))
		var reach := ceili(size / SmoothTerrain.STEP * 0.5) + 2
		for dx in range(-reach, reach + 1):
			for dz in range(-reach, reach + 1):
				for dy in range(-5, 2):
					var point := base + Vector3i(dx, dy, dz)
					if w.terrain.density(point) > 0.0:
						w.terrain.set_density(point, SmoothTerrain.DUG)
						dug.append(point)
		var y_before: float = rock.global_position.y
		w._refresh_terrain(dug)
		w.finish_terrain()
		await frames(10)
		if not is_instance_valid(rock):
			out("creusé sous un rocher : il a disparu")
			continue
		var low := INF
		for child in rock.get_children():
			if child is MeshInstance3D and child.name != "Silex":
				for v: Vector3 in unique_points(child.mesh, 300):
					var p: Vector3 = rock.global_transform * v
					var g := ground_y(p.x, p.z, at.y + 12.0, [rock.get_rid()])
					if not is_nan(g):
						low = minf(low, p.y - g)
		out("creusé sous un rocher (%.1f m) : il a bougé de %s cm ; son point le plus bas est à %s cm au-dessus du sol" % [size, cm(rock.global_position.y - y_before), cm(low)])

func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()

# ---------------------------------------------------------------- Rochers entamés à la pioche
# Morceaux d'un rocher entamé qui ne touchent plus le sol : nombre de points de sa grille, volume, hauteur.
func floating(body: Node) -> Dictionary:
	if not is_instance_valid(body) or not body.has_meta("grid"):
		return {"cells": 0, "litres": 0.0, "left": 0}
	var grid: Dictionary = body.get_meta("grid")
	var removed: Array = w.carved_rocks.get(body.get_meta("id"), [])
	var values: PackedFloat32Array = Rocks.carved_values(grid, removed.map(func(entry): return Vector3(entry[0], entry[1], entry[2]) * SmoothTerrain.STEP))
	var count: int = grid.count
	var step: float = grid.step
	var origin: Vector3 = grid.origin
	var state := PackedByteArray()
	state.resize(count * count * count)
	var stack := PackedInt32Array()
	var inside := 0
	for x in range(count):
		for z in range(count):
			var at := origin + Vector3(x, 0, z) * step
			var ground: float = w.terrain.height_at(at.x, at.z)
			for y in range(count):
				var index := (x * count + y) * count + z
				if values[index] >= 0.0:
					continue
				inside += 1
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
	var lowest := INF
	for index in range(state.size()):
		if state[index] == 1:
			cells += 1
			var at := origin + Vector3(index / (count * count), (index / count) % count, index % count) * step
			lowest = minf(lowest, at.y - w.terrain.height_at(at.x, at.z))
	return {"cells": cells, "litres": cells * step * step * step * 1000.0, "left": inside, "low": lowest}

func part_carving() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var results := {"anneau": [], "hasard": [], "dessous": []}
	var used := {}
	for place in [Vector3(0, 0, 0), Vector3(48, 0, 0), Vector3(0, 0, 48), Vector3(-48, 0, -48), Vector3(96, 0, 96), Vector3(-96, 0, 64), Vector3(48, 0, -96)]:
		await go_to(place)
		var rocks := get_nodes_in_group("rocks").filter(func(r): return is_instance_valid(r) and not used.has(r.get_meta("id")) and r.get_meta("rock").x >= 3 and r.get_meta("rock").x <= 6 and r.global_position.distance_to(w.player.global_position) < 20.0)
		for rock in rocks:
			var mode: String = ["anneau", "hasard", "dessous"][used.size() % 3]
			used[rock.get_meta("id")] = true
			var size: float = Rocks.SIZES[int(rock.get_meta("rock").x) - 1]
			var center: Vector3 = rock.global_position
			var ground: float = w.terrain.height_at(center.x, center.z)
			var hits := 0
			var first := -1
			var worst := 0.0
			var worst_low := 0.0
			var last := {"cells": 0, "litres": 0.0}
			var space: PhysicsDirectSpaceState3D = w.get_world_3d().direct_space_state
			var aims := []
			if mode == "anneau":
				# Tout le tour, près du sol : on creuse la base.
				for depth in range(4):
					for height in [0.3, 0.8]:
						for turn in range(12):
							var dir := Vector3(cos(turn * TAU / 12.0), 0.0, sin(turn * TAU / 12.0))
							aims.append([center + dir * size + Vector3.UP * (ground + height - center.y), -dir])
			elif mode == "dessous":
				# D'un seul côté, près du sol, de plus en plus profond (on creuse sous le rocher).
				for depth in range(10):
					for height in [0.3, 0.8]:
						for side in [-0.5, 0.0, 0.5]:
							aims.append([center + Vector3(size, ground + height - center.y, side), Vector3.LEFT])
			else:
				for index in range(60):
					var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1), rng.randf_range(-1, 1)).normalized()
					aims.append([center + dir * (size + 2.0), -dir])
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
				var t0 := Time.get_ticks_usec()
				if not w.mine_rock(rock, {"position": hit.position, "normal": hit.normal}, false):
					continue
				hits += 1
				hit_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
				t0 = Time.get_ticks_usec()
				if is_instance_valid(rock) and not rock.is_queued_for_deletion():
					w._floating_rock_cubes(rock, w.carved_rocks.get(rock.get_meta("id"), []))
				flood_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
				await physics_frame
				if not is_instance_valid(rock) or rock.is_queued_for_deletion():
					break
				last = floating(rock)
				if last.cells > 0 and first < 0:
					first = hits
				if last.litres > worst:
					worst = last.litres
					worst_low = last.low
			results[mode].append({"size": size, "hits": hits, "first": first, "worst": worst, "low": worst_low, "end": last.litres})
			out("rocher %.1f m, %s : %d coups ; premier bout en l'air au coup %d ; pire : %.0f litres en l'air (à %s cm du sol) ; à la fin : %.0f litres" % [size, mode, hits, first, worst, cm(worst_low), last.litres])
		if used.size() >= 18:
			break
	out("coup de pioche sur un rocher (ms) : " + stats(hit_ms) + " ; dont une recherche de bout en l'air (ms) : " + stats(flood_ms))
	for mode in results:
		var list: Array = results[mode]
		var floaters := list.filter(func(r): return r.first > 0)
		out("BILAN pioche « %s » : %d rochers, %d avec un bout en l'air (%s) ; pire volume en l'air (litres) : %s" % [mode, list.size(), floaters.size(), ("au coup " + stats(floaters.map(func(r): return float(r.first)))) if not floaters.is_empty() else "-", stats(list.map(func(r): return r.worst))])

# ---------------------------------------------------------------- Arbres abattus
func make(id: String, kind: int, size: int, at: Vector3) -> Node3D:
	var tree: Node3D = Trees.tree_body(kind, size)
	tree.set_meta("id", id)
	var column: Vector2i = w._player_column()
	tree.set_meta("column", column)
	w._rocks_parent().add_child(tree)
	tree.global_position = Vector3(at.x, w.terrain.height_at(at.x, at.z) - 0.05, at.z)
	w.column_objects[column] = w.column_objects.get(column, []) + [tree]
	return tree

func nodes_of(id: String) -> Array:
	var found := []
	for list in w.column_objects.values():
		for node in list:
			if is_instance_valid(node) and not node.is_queued_for_deletion() and node.get_meta("id", "") == id:
				found.append(node)
	return found

func clear_tree(id: String) -> void:
	for node in nodes_of(id):
		var column: Vector2i = node.get_meta("column", Vector2i(999999, 0))
		if w.column_objects.has(column):
			w.column_objects[column].erase(node)
		node.free()
	w.fallen_trees.erase(id)
	w.tree_cuts.erase(id)
	w.cut_trees.erase(id)

func wait_still(id: String, limit := 900) -> void:
	var calm := 0
	var last := {}
	for index in range(limit):
		await frames(1)
		var moving := false
		for node in nodes_of(id):
			if node.has_meta("falling"):
				moving = true
			var key: int = node.get_instance_id()
			if last.has(key) and not (last[key] as Transform3D).is_equal_approx(node.global_transform):
				moving = true
			last[key] = node.global_transform
		for slide in w.sliding_trees:
			if is_instance_valid(slide.tree) and slide.tree.get_meta("id", "") == id:
				moving = true
		calm = 0 if moving else calm + 1
		if calm >= 25:
			return

# Un morceau couché : son bois et ses feuilles par rapport au vrai sol.
func lying(node: Node3D) -> Dictionary:
	var detail: MeshInstance3D = node.get_node_or_null("Modele/Detail")
	if detail == null or detail.mesh == null:
		return {}
	var kind := int(node.get_meta("kind", 0))
	var leaf_material := Trees.material(kind, "leaves")
	var place: Transform3D = detail.global_transform
	var total := 0
	for surface in range(detail.mesh.get_surface_count()):
		total += detail.mesh.surface_get_array_len(surface)
	var stride := maxi(1, total / 1800)
	var skip := []
	for tree in get_nodes_in_group("trees"):
		if tree is CollisionObject3D:
			skip.append(tree.get_rid())
	var top: float = node.global_position.y + 25.0
	var wood := []
	var leaves := []
	for surface in range(detail.mesh.get_surface_count()):
		var is_leaf: bool = detail.mesh.surface_get_material(surface) == leaf_material
		var points: PackedVector3Array = detail.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for index in range(0, points.size(), stride):
			var p: Vector3 = place * points[index]
			var g := ground_y(p.x, p.z, top, skip)
			if is_nan(g):
				continue
			(leaves if is_leaf else wood).append([p, p.y - g])
	if wood.is_empty():
		return {}
	var wood_low := INF
	var leaf_low := INF
	var deep_count := 0
	for each in wood:
		wood_low = minf(wood_low, each[1])
		if each[1] < -0.05:
			deep_count += 1
	for each in leaves:
		leaf_low = minf(leaf_low, each[1])
	# Sa pièce principale : hauteur du dessous de chaque bout, et appuis de part et d'autre du milieu.
	var size := int(node.get_meta("size", 3))
	var form := int(node.get_meta("form", 0))
	var part := int(node.get_meta("part", 0))
	var main := TreeParts.main_span(kind, size, form, w._cuts_of(node), part)
	var ends := [NAN, NAN]
	var one_sided := false
	var span_length := 0.0
	if not main.is_empty():
		var piece: Dictionary = TreeParts.skeleton(kind, size, form).pieces[main[0]]
		var model: Transform3D = w._model_of(node)
		var scale := node.scale.x
		var a: Vector3 = model * (piece.start + piece.direction * float(main[1]))
		var b: Vector3 = model * (piece.start + piece.direction * float(main[2]))
		span_length = a.distance_to(b)
		var index := 0
		for end in [[a, float(main[1])], [b, float(main[2])]]:
			var g := ground_y(end[0].x, end[0].z, top, skip)
			if not is_nan(g):
				ends[index] = end[0].y - TreeParts.true_thickness(piece, end[1]) * scale * 0.5 - g
			index += 1
		var along := (b - a)
		along.y = 0.0
		if along.length() > 0.3:
			along = along.normalized()
			var middle := 0.0
			for each in wood:
				middle += ((each[0] as Vector3) - a).dot(along)
			middle /= wood.size()
			var left := false
			var right := false
			for each in wood:
				if each[1] < 0.06:
					var x := ((each[0] as Vector3) - a).dot(along)
					left = left or x < middle
					right = right or x > middle
			for each in leaves:
				if each[1] < 0.15:
					var x := ((each[0] as Vector3) - a).dot(along)
					left = left or x < middle
					right = right or x > middle
			one_sided = not (left and right)
	return {"wood_low": wood_low, "leaf_low": leaf_low, "lowest": minf(wood_low, leaf_low), "deep_share": float(deep_count) / wood.size(), "ends": ends, "one_sided": one_sided, "length": span_length, "wood_points": wood.size(), "tilt": rad_to_deg(asin(clampf((node.global_basis.y.normalized()).y, -1.0, 1.0)))}

func describe(result: Dictionary) -> String:
	if result.is_empty():
		return "pas de modèle"
	return "bois le plus bas %s cm (négatif = dans le sol ; %.0f %% des points à plus de 5 cm dedans) ; feuilles le plus bas %s cm ; dessous des bouts de la pièce principale %s / %s cm ; appui d'un seul côté : %s" % [cm(result.wood_low), result.deep_share * 100.0, cm(result.leaf_low) if result.leaf_low < INF else "-", cm(result.ends[0]), cm(result.ends[1]), str(result.one_sided)]

var all_lying := []

func note(label: String, result: Dictionary) -> void:
	out(label + " : " + describe(result))
	if not result.is_empty():
		result.label = label
		all_lying.append(result)

func summary(title: String, list: Array) -> void:
	if list.is_empty():
		out("BILAN %s : rien" % title)
		return
	out("BILAN %s : %d morceaux" % [title, list.size()])
	out("  bois dans le sol : > 3 cm : %d ; > 10 cm : %d ; > 25 cm : %d ; profondeur (cm) %s" % [list.filter(func(r): return r.wood_low < -0.03).size(), list.filter(func(r): return r.wood_low < -0.10).size(), list.filter(func(r): return r.wood_low < -0.25).size(), stats(list.map(func(r): return maxf(-r.wood_low, 0.0) * 100.0))])
	out("  en l'air (rien à moins de 5 cm du sol, ni bois ni feuilles) : %d ; > 15 cm : %d ; hauteur du plus bas point (cm) %s" % [list.filter(func(r): return r.lowest > 0.05).size(), list.filter(func(r): return r.lowest > 0.15).size(), stats(list.map(func(r): return maxf(r.lowest, 0.0) * 100.0))])
	out("  appui d'un seul côté du milieu : %d" % list.filter(func(r): return r.one_sided).size())
	var high_ends := []
	for r in list:
		for end in r.ends:
			if not is_nan(end):
				high_ends.append(end * 100.0)
	out("  dessous des bouts de la pièce principale (cm) : " + stats(high_ends))

func part_fell() -> void:
	var sites := find_sites()
	for key in sites:
		var site: Vector3 = sites[key]
		var down := downhill_at(site.x, site.z)
		var directions := {"aval": down, "amont": -down, "travers": down.cross(Vector3.UP).normalized()} if key != "plat" else {"plat": Vector3.RIGHT}
		for kind in range(4):
			for size in [1, 3, 5]:
				for way in directions:
					var id := "mesure_%s_%d_%d_%s" % [key, kind, size, way]
					w.player.global_position = site + (directions[way] as Vector3) * 4.0
					w.player.global_position.y = w.terrain.height_at(w.player.global_position.x, w.player.global_position.z)
					await frames(2)
					var tree := make(id, kind, size, site)
					await frames(2)
					w.fell_tree(tree)
					await wait_still(id)
					for node in nodes_of(id):
						var result := lying(node)
						result["site"] = key
						note("abattu %s taille %d, %s, vers %s (glissé de %.1f m)" % [KIND_NAMES[kind], size, key, way, Vector2(node.global_position.x - site.x, node.global_position.z - site.z).length()], result)
					clear_tree(id)
					await frames(1)
	for key in sites:
		summary("arbres abattus, " + key, all_lying.filter(func(r): return r.site == key))
	summary("arbres abattus, tous", all_lying)

# ---------------------------------------------------------------- Branches et tiges coupées, puis recoupées
func part_branches() -> void:
	var sites := find_sites()
	var wood_before: int = w.ground.entries.size()
	var recuts := []
	for key in ["plat", "pente15", "pente30"]:
		if not sites.has(key):
			continue
		var site: Vector3 = sites[key]
		var down := downhill_at(site.x, site.z)
		for spec in [[Trees.APPLE, 3], [Trees.APPLE, 5], [Trees.HAZEL, 3], [Trees.HAZEL, 5], [Trees.PINE, 3], [Trees.LINDEN, 3], [Trees.LINDEN, 5]]:
			var kind: int = spec[0]
			var size: int = spec[1]
			var id := "branches_%s_%d_%d" % [key, kind, size]
			w.player.global_position = site + down.cross(Vector3.UP).normalized() * 4.0
			w.player.global_position.y = w.terrain.height_at(w.player.global_position.x, w.player.global_position.z)
			await frames(2)
			var tree := make(id, kind, size, site)
			await frames(2)
			var made: Dictionary = TreeParts.skeleton(kind, size, 0)
			var done := 0
			for number in range(made.pieces.size()):
				if done >= 6:
					break
				var piece: Dictionary = made.pieces[number]
				var is_stem: bool = kind == Trees.HAZEL and piece.root and piece.tip.y > 0.5
				var is_branch: bool = kind != Trees.HAZEL and not piece.root and piece.depth == 1 and piece.length >= 0.5
				if not is_stem and not is_branch:
					continue
				var holder: Array = nodes_of(id).filter(func(node): return not node.has_meta("falling") and int(node.get_meta("part", 0)) == 0)
				if holder.is_empty():
					break
				var t := 0.35 if is_stem else 0.05
				w.cut_wood(holder[0], number, t, w._model_of(holder[0]) * (piece.start + piece.direction * t))
				done += 1
				await frames(3)
			await wait_still(id)
			var parts := nodes_of(id).filter(func(node): return int(node.get_meta("part", 0)) != 0)
			for node in parts:
				var result := lying(node)
				result["site"] = key
				result["step"] = "coupe"
				note("coupé %s taille %d, %s, morceau %d" % [KIND_NAMES[kind], size, key, int(node.get_meta("part", 0))], result)
			# Recoupe : le bout (à 70 % de sa pièce principale) ; le reste ne doit pas changer.
			for node in parts:
				if not is_instance_valid(node) or node.is_queued_for_deletion():
					continue
				var part := int(node.get_meta("part", 0))
				var main: Array = TreeParts.main_span(kind, size, 0, w._cuts_of(node), part)
				if main.is_empty():
					continue
				var before: Transform3D = node.global_transform
				var share_before: float = TreeParts.leaf_share(kind, size, 0, w._cuts_of(node), part)
				var box_before: Vector3 = w._world_box(node).size
				var others := {}
				for other in nodes_of(id):
					others[other.get_instance_id()] = other.global_transform
				var entries_before: int = w.ground.entries.size()
				var t := lerpf(float(main[1]), float(main[2]), 0.7)
				var cuts_before: int = w._cuts_of(node).size()
				w.cut_wood(node, int(main[0]), t, node.global_position)
				if w._cuts_of(node).size() == cuts_before:
					continue
				await wait_still(id, 300)
				var row := {"label": "%s taille %d, %s, morceau %d" % [KIND_NAMES[kind], size, key, part], "gone": not is_instance_valid(node) or node.is_queued_for_deletion(), "wood": w.ground.entries.size() - entries_before}
				if not row.gone:
					row["move"] = node.global_position.distance_to(before.origin)
					row["turn"] = rad_to_deg(before.basis.orthonormalized().get_rotation_quaternion().angle_to(node.global_basis.orthonormalized().get_rotation_quaternion()))
					var cuts_now: Array = w._cuts_of(node)
					row["share"] = TreeParts.leaf_share(kind, size, 0, cuts_now, part) / maxf(share_before, 0.000001)
					var box_now: Vector3 = w._world_box(node).size
					row["box"] = box_now.length() / maxf(box_before.length(), 0.001)
					var result := lying(node)
					result["site"] = key
					result["step"] = "recoupe"
					note("  recoupé, le reste : " + row.label, result)
				var others_moved := 0.0
				for other in nodes_of(id):
					if other != node and others.has(other.get_instance_id()):
						others_moved = maxf(others_moved, other.global_position.distance_to((others[other.get_instance_id()] as Transform3D).origin))
				row["others"] = others_moved
				for other in nodes_of(id):
					if not others.has(other.get_instance_id()):
						var result := lying(other)
						result["site"] = key
						result["step"] = "bout"
						note("  recoupé, le bout : " + row.label, result)
				recuts.append(row)
				out("  recoupe %s : reste %s ; déplacé de %s cm, tourné de %.1f° ; feuilles gardées %.0f %% ; taille %.0f %% ; bois au sol +%d ; autres morceaux déplacés de %s cm" % [row.label, "disparu (devenu bois)" if row.gone else "gardé", cm(row.get("move", 0.0)), row.get("turn", 0.0), row.get("share", 0.0) * 100.0, row.get("box", 0.0) * 100.0, row.wood, cm(others_moved)])
			# Tout ce qui reste devient son bois au sol (comme avec R, feuilles tombées).
			for node in nodes_of(id):
				if is_instance_valid(node) and int(node.get_meta("part", 0)) != 0 and not node.is_queued_for_deletion():
					w._part_to_wood(node, int(node.get_meta("part", 0)))
			await frames(40)
			# Le bois au sol de cet arbre : centre et bouts par rapport au vrai sol.
			_measure_wood(wood_before, key, KIND_NAMES[kind])
			wood_before = w.ground.entries.size()
			clear_tree(id)
			await frames(1)
	for step in ["coupe", "recoupe", "bout"]:
		summary("branches et tiges, " + step, all_lying.filter(func(r): return r.step == step))
	for key in ["plat", "pente15", "pente30"]:
		summary("branches et tiges, " + key, all_lying.filter(func(r): return r.site == key))
	var kept := recuts.filter(func(r): return not r.gone)
	out("BILAN recoupes : %d ; reste gardé : %d ; reste devenu bois : %d" % [recuts.size(), kept.size(), recuts.size() - kept.size()])
	out("  reste déplacé (cm) : %s" % stats(kept.map(func(r): return r.move * 100.0)))
	out("  reste tourné (°) : %s" % stats(kept.map(func(r): return r.turn)))
	out("  feuilles gardées par le reste (%%) : %s" % stats(kept.map(func(r): return r.share * 100.0)))
	out("  autres morceaux de l'arbre déplacés (cm) : %s" % stats(recuts.map(func(r): return r.others * 100.0)))
	out("BILAN bois au sol : %d bois" % wood_rows.size())
	out("  centre : dessous au-dessus du sol (cm, + en l'air, − dedans) : %s" % stats(wood_rows.map(func(r): return r.center * 100.0)))
	out("  un bout en l'air de plus de 5 cm : %d ; de plus de 20 cm : %d ; hauteur (cm) %s" % [wood_rows.filter(func(r): return r.air > 0.05).size(), wood_rows.filter(func(r): return r.air > 0.20).size(), stats(wood_rows.map(func(r): return maxf(r.air, 0.0) * 100.0))])
	out("  un bout dans le sol de plus de 5 cm : %d ; de plus de 20 cm : %d ; profondeur (cm) %s" % [wood_rows.filter(func(r): return r.sunk > 0.05).size(), wood_rows.filter(func(r): return r.sunk > 0.20).size(), stats(wood_rows.map(func(r): return maxf(r.sunk, 0.0) * 100.0))])
	for band in [[0.0, 0.5], [0.5, 1.5], [1.5, 99.0]]:
		var some := wood_rows.filter(func(r): return r.length >= band[0] and r.length < band[1])
		out("  longueur %.1f-%.1f m : %d ; bout en l'air > 5 cm : %d ; bout dans le sol > 5 cm : %d" % [band[0], band[1], some.size(), some.filter(func(r): return r.air > 0.05).size(), some.filter(func(r): return r.sunk > 0.05).size()])
	for key in ["plat", "pente15", "pente30"]:
		var some := wood_rows.filter(func(r): return r.site == key)
		out("  %s : %d ; bout en l'air > 5 cm : %d ; bout dans le sol > 5 cm : %d" % [key, some.size(), some.filter(func(r): return r.air > 0.05).size(), some.filter(func(r): return r.sunk > 0.05).size()])

var wood_rows := []
var hit_ms := []
var flood_ms := []

func _measure_wood(from: int, site: String, name: String) -> void:
	var skip := []
	for tree in get_nodes_in_group("trees"):
		if tree is CollisionObject3D:
			skip.append(tree.get_rid())
	for index in range(from, w.ground.entries.size()):
		var entry: Dictionary = w.ground.entries[index]
		if GroundItems._kind(entry.item) != "bois":
			continue
		var place: Transform3D = w.ground.place_of(entry, GroundItems._basis(entry.item))
		var length := float(entry.item.get("longueur", 1.0))
		var axis: Vector3 = place.basis.y.normalized()
		var big := float(entry.item.get("epaisseur", 3.0)) / 200.0
		var small := float(entry.item.get("fin", entry.item.get("epaisseur", 3.0))) / 200.0
		var center_ground := ground_y(place.origin.x, place.origin.z, place.origin.y + 6.0, skip)
		if is_nan(center_ground) or absf(center_ground - w.terrain.height_at(place.origin.x, place.origin.z)) > 2.5 or Vector2(place.origin.x - w.player.global_position.x, place.origin.z - w.player.global_position.z).length() > 14.0:
			continue
		var air := -INF
		var sunk := -INF
		for end in [place.origin + axis * length * 0.5, place.origin - axis * length * 0.5]:
			var g := ground_y(end.x, end.z, place.origin.y + 6.0, skip)
			if is_nan(g) or absf(g - w.terrain.height_at(end.x, end.z)) > 2.5:
				continue
			# En l'air même avec son gros rayon ; dans le sol même avec son petit rayon.
			air = maxf(air, end.y - big - g)
			sunk = maxf(sunk, g - (end.y - small))
		if air == -INF:
			continue
		wood_rows.append({"site": site, "name": name, "length": length, "center": place.origin.y - (big + small) * 0.5 - center_ground, "air": air, "sunk": sunk})

# ---------------------------------------------------------------- Tailles du bois : le dessin du bâton contre le vrai modèle
func part_sizes() -> void:
	var rows := []
	await go_to(Vector3(0, 0, 0))
	for kind in range(4):
		for size in range(1, 6):
			var id := "tailles_%d_%d" % [kind, size]
			var tree := make(id, kind, size, Vector3(6, 0, 6))
			await frames(1)
			var scale := tree.scale.x
			var made: Dictionary = TreeParts.skeleton(kind, size, 0)
			var full := Trees.mesh(kind, size, false, 0)
			# Sommets du bois de chaque pièce : (t le long de la pièce, point).
			var by_piece := {}
			var tris := {}
			for surface in range(made.surfaces.size()):
				var info: Dictionary = made.surfaces[surface]
				if info.leaves or surface >= full.get_surface_count():
					continue
				var arrays := full.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var owners: Array = info.owner
				for triangle in range(owners.size()):
					var owner: int = owners[triangle]
					if owner < 0:
						continue
					if not by_piece.has(owner):
						by_piece[owner] = {}
					for corner in range(3):
						by_piece[owner][indices[triangle * 3 + corner] + surface * 1000000] = points[indices[triangle * 3 + corner]]
						if not tris.has(owner):
							tris[owner] = PackedVector3Array()
						tris[owner].append(points[indices[triangle * 3 + corner]])
			var items: Array = w._part_wood_items(tree, 0)
			for each in items:
				var wood: Dictionary = each[0]
				var number: int = each[2]
				var piece: Dictionary = made.pieces[number]
				if not by_piece.has(number):
					continue
				var direction: Vector3 = (piece.direction as Vector3).normalized()
				var ts := []
				for p: Vector3 in by_piece[number].values():
					ts.append((p - (piece.start as Vector3)).dot(direction))
				var t_low: float = ts.min()
				var t_high: float = ts.max()
				var true_length := (t_high - t_low) * scale
				var drawn_length := float(wood.longueur)
				var ends: Vector2 = w.wood_ends(piece, 0.0, float(piece.length))
				var first := float(wood.epaisseur) if ends.x >= ends.y else float(wood.fin)
				var second := float(wood.fin) if ends.x >= ends.y else float(wood.epaisseur)
				# Cinq tranches le long de la pièce : vrai diamètre = périmètre de la boucle du bois autour de l'axe / pi.
				var corners: PackedVector3Array = tris.get(number, PackedVector3Array())
				var side: Vector3 = direction.cross(Vector3.UP if absf(direction.y) < 0.9 else Vector3.RIGHT).normalized()
				var other: Vector3 = direction.cross(side).normalized()
				var worst := 0.0
				var worst_cm := 0.0
				var signed := []
				var bands := 0
				for band in range(5):
					var t_mean := float(piece.length) * (band + 0.5) / 5.0
					var center: Vector3 = (piece.start as Vector3) + direction * t_mean
					if piece.root and center.y < 0.35:
						continue
					var true_cm := loop_diameter(corners, center, direction, side, other) * scale * 100.0
					var drawn_cm := lerpf(first, second, clampf(t_mean / maxf(float(piece.length), 0.001), 0.0, 1.0))
					if true_cm < 0.3:
						continue
					bands += 1
					var error := (drawn_cm - true_cm) / true_cm
					signed.append(error * 100.0)
					if absf(error) > absf(worst):
						worst = error
						worst_cm = drawn_cm - true_cm
				if bands == 0:
					continue
				rows.append({"kind": kind, "size": size, "number": number, "objet": wood.objet, "length_error": (drawn_length - true_length) / maxf(true_length, 0.001) * 100.0, "length_cm": (drawn_length - true_length) * 100.0, "true_length": true_length, "worst": worst * 100.0, "worst_cm": worst_cm, "mean": _mean(signed), "thick": float(wood.epaisseur), "root": piece.root, "depth": int(piece.get("depth", 0))})
			clear_tree(id)
	out("pièces comparées : %d (4 espèces × 5 tailles, forme 0)" % rows.size())
	out("longueur dessinée − vraie (%%) : " + stats(rows.map(func(r): return r.length_error)))
	out("longueur dessinée − vraie (cm) : " + stats(rows.map(func(r): return r.length_cm)))
	out("longueur fausse de plus de 5 %% : %d ; de plus de 15 %% : %d" % [rows.filter(func(r): return absf(r.length_error) > 5.0).size(), rows.filter(func(r): return absf(r.length_error) > 15.0).size()])
	out("épaisseur dessinée − vraie, pire tranche de chaque pièce (%%) : " + stats(rows.map(func(r): return r.worst)))
	out("épaisseur dessinée − vraie, moyenne des tranches (%%) : " + stats(rows.map(func(r): return r.mean)))
	out("épaisseur fausse (pire tranche) de plus de 15 %% : %d ; de plus de 30 %% : %d ; de plus de 50 %% : %d" % [rows.filter(func(r): return absf(r.worst) > 15.0).size(), rows.filter(func(r): return absf(r.worst) > 30.0).size(), rows.filter(func(r): return absf(r.worst) > 50.0).size()])
	for label in [["tronc ou tige (pied)", func(r): return r.root], ["grosses branches (≥ 4 cm)", func(r): return not r.root and r.thick >= 4.0], ["petites branches (< 4 cm)", func(r): return not r.root and r.thick < 4.0]]:
		var some := rows.filter(label[1])
		out("  %s : %d ; longueur (%%) %s ; épaisseur moyenne (%%) %s ; pire tranche fausse > 30 %% : %d" % [label[0], some.size(), stats(some.map(func(r): return r.length_error)), stats(some.map(func(r): return r.mean)), some.filter(func(r): return absf(r.worst) > 30.0).size()])
	for kind in range(4):
		var some := rows.filter(func(r): return r.kind == kind)
		out("  %s : %d ; longueur fausse > 5 %% : %d ; épaisseur moyenne (%%) %s ; pire tranche > 30 %% : %d" % [KIND_NAMES[kind], some.size(), some.filter(func(r): return absf(r.length_error) > 5.0).size(), stats(some.map(func(r): return r.mean)), some.filter(func(r): return absf(r.worst) > 30.0).size()])
	var worst_rows := rows.duplicate()
	worst_rows.sort_custom(func(a, b): return absf(a.worst_cm) > absf(b.worst_cm))
	for r in worst_rows.slice(0, 8):
		out("  pire : %s taille %d pièce %d (%s, %.2f m, %.1f cm) : épaisseur %+.0f %% (%+.1f cm) ; longueur %+.0f %%" % [KIND_NAMES[r.kind], r.size, r.number, r.objet, r.true_length, r.thick, r.worst, r.worst_cm, r.length_error])

# ---------------------------------------------------------------- Terrain : talus, surplombs de la graine
func part_terrain() -> void:
	var sites := find_sites()
	var t = w.terrain
	var flat: Vector3 = sites.get("plat", Vector3.ZERO)
	await go_to(flat)
	# Tas : une colonne de 6 m de matière posée, qu'on laisse retomber.
	var shift := 0
	for spec in [["sable", SmoothTerrain.SAND], ["terre", SmoothTerrain.DIRT]]:
		var base: Vector3i = SmoothTerrain.point_of(flat + Vector3(shift, 0.3, 0))
		shift += 24
		while t.density(base) > 0.0:
			base += Vector3i.UP
		var before: Dictionary = t.changes.duplicate()
		for wide in [0]:
			for y in range(12):
				for dx in range(2):
					for dz in range(2):
						var point := base + Vector3i(dx, y, dz)
						t.set_density(point, SmoothTerrain.ADDED, spec[1])
						t.wake(point)
		var start := Time.get_ticks_msec()
		var steps := 0
		while not t.unstable.is_empty() and steps < 20000:
			t.settle_step()
			steps += 1
		var took := Time.get_ticks_msec() - start
		# Profil du tas : hauteur (en points de 50 cm) à chaque distance du centre.
		var profile := []
		for d in range(0, 12):
			var top := 0
			for y in range(-4, 14):
				if t.density(base + Vector3i(d, y, 0)) > 0.0 and not before.has(base + Vector3i(d, y, 0)) and t.changes.has(base + Vector3i(d, y, 0)):
					top = maxi(top, y + 1)
			profile.append(top)
		var radius := 0
		for d in range(profile.size()):
			if profile[d] > 0:
				radius = d + 1
		out("tas de %s (48 points posés en colonne de 6 m) : profil des hauteurs en points de 50 cm depuis le centre %s ; pente moyenne %.0f° ; %d pas de chute, %d ms" % [spec[0], str(profile), rad_to_deg(atan(float(profile[0]) / maxf(radius, 1))), steps, took])
	# Surplombs de la graine : matière meuble ou terre qui tomberait dès qu'on la réveille (on creuse ou pose à côté).
	for place in [Vector3(0, 0, 0), Vector3(128, 0, 0), Vector3(0, 0, 128), Vector3(-128, 0, -128), Vector3(128, 0, 128)]:
		var start := Time.get_ticks_msec()
		var origin: Vector3i = SmoothTerrain.point_of(place)
		var overhangs := 0
		var latent := []
		var held := 0
		var stone := 0
		var by_kind := {}
		for x in range(origin.x - 64, origin.x + 64):
			for z in range(origin.z - 64, origin.z + 64):
				var top: int = int(floor(t.ground_height(Vector2i(x, z)) / SmoothTerrain.STEP)) + 2
				var above_solid: bool = t.solid(Vector3i(x, top, z))
				for y in range(top - 1, top - 60, -1):
					var point := Vector3i(x, y, z)
					var is_solid: bool = t.solid(point)
					if above_solid and not is_solid:
						# Le point du dessus est plein, celui-ci vide : surplomb.
						var over := point + Vector3i.UP
						overhangs += 1
						if t.is_stone(over):
							stone += 1
						elif t.fall_target(over) != over:
							latent.append(over)
							var kind: int = t.materials.get(over, t.natural_kind(over))
							by_kind[kind] = int(by_kind.get(kind, 0)) + 1
						else:
							held += 1
					above_solid = is_solid
		out("surplombs autour de %s (64 × 64 m, 30 m de profondeur) : %d ; en pierre : %d ; terre tenue par les côtés : %d ; prêts à tomber si on les réveille : %d (par matière %s) ; %d ms" % [str(place), overhangs, stone, held, latent.size(), str(by_kind), Time.get_ticks_msec() - start])
		# Chaîne : on réveille un seul point prêt à tomber, combien de points bougent ?
		var chains := []
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for trial in range(mini(6, latent.size())):
			var point: Vector3i = latent[rng.randi_range(0, latent.size() - 1)]
			if t.fall_target(point) == point:
				continue
			t.wake(point)
			var moved := {}
			var steps := 0
			while not t.unstable.is_empty() and steps < 4000:
				for changed in t.settle_step():
					moved[changed] = true
				steps += 1
			chains.append(moved.size() / 2)
		if not chains.is_empty():
			out("  un seul point réveillé → points qui tombent en chaîne : %s" % str(chains))

# Diamètre (m, repère du modèle) de la boucle de bois qui entoure l'axe dans le plan perpendiculaire en « center » :
# les triangles sont tranchés par le plan, les segments reliés en boucles ; on garde celle qui entoure l'axe (pas les
# rameaux à côté) ; diamètre = périmètre / pi. 0 sans boucle.
func loop_diameter(corners: PackedVector3Array, center: Vector3, axis: Vector3, side: Vector3, other: Vector3) -> float:
	var segments := []
	for at in range(0, corners.size() - 2, 3):
		var found := []
		for edge in [[0, 1], [1, 2], [2, 0]]:
			var a: Vector3 = corners[at + edge[0]]
			var b: Vector3 = corners[at + edge[1]]
			var da := (a - center).dot(axis)
			var db := (b - center).dot(axis)
			if (da < 0.0) != (db < 0.0):
				var p := a.lerp(b, da / (da - db)) - center
				found.append(Vector2(p.dot(side), p.dot(other)))
		if found.size() == 2:
			segments.append(found)
	if segments.size() < 3:
		return 0.0
	var parent := {}
	var find := func(key: Vector2i) -> Vector2i:
		while parent[key] != key:
			parent[key] = parent[parent[key]]
			key = parent[key]
		return key
	for segment in segments:
		var ka := Vector2i((segment[0] as Vector2) * 2000.0)
		var kb := Vector2i((segment[1] as Vector2) * 2000.0)
		if not parent.has(ka):
			parent[ka] = ka
		if not parent.has(kb):
			parent[kb] = kb
		var ra: Vector2i = find.call(ka)
		var rb: Vector2i = find.call(kb)
		if ra != rb:
			parent[ra] = rb
	var groups := {}
	for segment in segments:
		var key: Vector2i = find.call(Vector2i((segment[0] as Vector2) * 2000.0))
		if not groups.has(key):
			groups[key] = {"perimeter": 0.0, "low": Vector2(INF, INF), "high": Vector2(-INF, -INF), "count": 0}
		var group: Dictionary = groups[key]
		group.perimeter += (segment[0] as Vector2).distance_to(segment[1])
		group.count += 1
		for p: Vector2 in segment:
			group.low = Vector2(minf(group.low.x, p.x), minf(group.low.y, p.y))
			group.high = Vector2(maxf(group.high.x, p.x), maxf(group.high.y, p.y))
	var best := 0.0
	var nearest := INF
	var nearest_value := 0.0
	for group in groups.values():
		if group.count < 3:
			continue
		var low: Vector2 = group.low
		var high: Vector2 = group.high
		var middle := (low + high) * 0.5
		if low.x <= 0.0 and low.y <= 0.0 and high.x >= 0.0 and high.y >= 0.0:
			best = maxf(best, group.perimeter / PI)
		if middle.length() < nearest:
			nearest = middle.length()
			nearest_value = group.perimeter / PI
	return best if best > 0.0 else nearest_value

func part_debug() -> void:
	var sites := find_sites()
	var site: Vector3 = sites["pente15"]
	var down := downhill_at(site.x, site.z)
	w.player.global_position = site + down.cross(Vector3.UP).normalized() * 4.0
	w.player.global_position.y = w.terrain.height_at(w.player.global_position.x, w.player.global_position.z)
	await frames(2)
	# Y a-t-il une grotte sous l'endroit ?
	var column: Vector3i = SmoothTerrain.point_of(site)
	var line := ""
	for y in range(column.y + 4, column.y - 30, -1):
		line += "#" if w.terrain.solid(Vector3i(column.x, y, column.z)) else "."
	out("colonne sous l'endroit (du haut vers le bas, 50 cm par signe) : " + line)
	var tree := make("debug", Trees.PINE, 3, site)
	await frames(2)
	var made: Dictionary = TreeParts.skeleton(Trees.PINE, 3, 0)
	for number in range(made.pieces.size()):
		var piece: Dictionary = made.pieces[number]
		if piece.root or piece.depth != 1 or piece.length < 0.5:
			continue
		var at: Vector3 = w._model_of(tree) * (piece.start + piece.direction * 0.05)
		out("branche %d : départ à %.2f m au-dessus du sol ; sol du jeu sous elle %.2f ; sol mesuré %.2f ; sol de la graine %.2f" % [number, at.y - ground_y(at.x, at.z, at.y + 20.0), w._ground_at(at, tree), ground_y(at.x, at.z, at.y + 20.0), w.terrain.height_at(at.x, at.z)])
		w.cut_wood(tree, number, 0.05, at)
		await wait_still("debug")
		for node in nodes_of("debug"):
			if int(node.get_meta("part", 0)) != 0:
				var box: AABB = w._world_box(node)
				var middle := box.get_center()
				out("  morceau %d : origine du nœud %s ; boîte du modèle de y %.2f à %.2f ; sol mesuré au milieu %.2f ; sol du jeu au milieu %.2f ; sol du jeu vu depuis l'origine du nœud %.2f" % [int(node.get_meta("part", 0)), str(node.global_position.snappedf(0.01)), box.position.y, box.end.y, ground_y(middle.x, middle.z, middle.y + 30.0), w._ground_at(middle, node), w._ground_at(Vector3(middle.x, node.global_position.y, middle.z), node)])
		break

# Un rocher de la graine à moins de « reach » m (les essais d'arbres se font sur le terrain nu).
func rock_near(at: Vector2, reach := 16.0) -> bool:
	var zone := Vector2i(floori(at.x / 8.0), floori(at.y / 8.0))
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			for rock in w.terrain.rocks_in_zone(zone + Vector2i(dx, dz)):
				if Vector2(float(rock.x), float(rock.z)).distance_to(at) < reach + Rocks.SIZES[int(rock.taille) - 1] * 0.5:
					return true
	return false

# ---------------------------------------------------------------- Noisetier : rameaux feuillus ou bâtons ?
# 0.0.8.30 (demande de l'utilisateur : « c'est plus possible d'avoir des bâtons ») : sur des noisetiers, des tiges coupées
# puis leurs petites branches recoupées, et des tiges défaites sans enlever les feuilles : ce qu'on obtient.
func part_hazel() -> void:
	var sites := find_sites()
	var site: Vector3 = sites.get("plat", Vector3.ZERO)
	var counts := {}
	var handles := 0
	var before: int = w.ground.entries.size()
	for size in [3, 5]:
		var id := "noisetier_%d" % size
		w.player.global_position = site + Vector3(4.0, 0.0, 0.0)
		await frames(2)
		var tree := make(id, Trees.HAZEL, size, site)
		await frames(2)
		var made: Dictionary = TreeParts.skeleton(Trees.HAZEL, size, 0)
		var done := 0
		for number in range(made.pieces.size()):
			var piece: Dictionary = made.pieces[number]
			if done >= 4 or not piece.root or piece.tip.y <= 0.5:
				continue
			var holder: Array = nodes_of(id).filter(func(node): return not node.has_meta("falling") and int(node.get_meta("part", 0)) == 0)
			if holder.is_empty():
				break
			w.cut_wood(holder[0], number, 0.35, w._model_of(holder[0]) * (piece.start + piece.direction * 0.35))
			done += 1
			await frames(3)
		await wait_still(id)
		var parts := nodes_of(id).filter(func(node): return int(node.get_meta("part", 0)) != 0)
		var turn := 0
		for node in parts:
			if not is_instance_valid(node) or node.is_queued_for_deletion():
				continue
			var part := int(node.get_meta("part", 0))
			turn += 1
			if turn % 2 == 0:
				# Comme le joueur qui casse une petite branche de côté, là où sont les feuilles.
				var spans: Dictionary = TreeParts.assignment(Trees.HAZEL, size, 0, w._cuts_of(node)).ranges[part]
				var main: Array = TreeParts.main_span(Trees.HAZEL, size, 0, w._cuts_of(node), part)
				var cut_done := 0
				for number in spans:
					if cut_done >= 3 or main.is_empty() or number == int(main[0]):
						continue
					var span: Vector2 = spans[number]
					if span.y - span.x < 0.25 or not is_instance_valid(node) or node.is_queued_for_deletion():
						continue
					w.cut_wood(node, number, span.x + 0.06, node.global_position)
					cut_done += 1
					await frames(3)
			# Puis tout le morceau défait en bois, sans avoir fait tomber ses feuilles.
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				w._part_to_wood(node, part)
			await frames(3)
		await frames(30)
		clear_tree(id)
	for index in range(before, w.ground.entries.size()):
		var item: Dictionary = w.ground.entries[index].item
		var key := str(item.get("objet", "?"))
		counts[key] = int(counts.get(key, 0)) + 1
		if load("res://scripts/crafting_rules.gd").good_handle(item):
			handles += 1
	out("noisetiers (tailles 3 et 5), tiges coupées, recoupées et défaites : objets au sol %s ; bons manches possibles : %d" % [str(counts), handles])
