extends SceneTree
# 0.0.7.32 (#216, signalé par l'utilisateur : la terre posée sur un rocher flottait au-dessus) : terre posée sur le dessus
# des rochers, gestes de 1 et 4 sous-cellules : le dessous de la terre touche le rocher (3 cm de vide au plus ; avant :
# jusqu'à 1 m mesuré) ; ce qui dépasse du bord n'a pas d'appui et tombe ; en Survie, les joints comptent ; le sol lisse
# ne change pas.
const Store = preload("res://scripts/world_store.gd")
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
const WorldScene = preload("res://scenes/world.tscn")
const Inventory = preload("res://scripts/inventory.gd")
const FOLDER := "res://.godot/rocher-pose-test-monde"
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

func _rock(id: String) -> Node:
	for r in get_nodes_in_group("rocks"):
		if is_instance_valid(r) and not r.is_queued_for_deletion() and r.get_meta("id") == id:
			return r
	return null

func _run() -> void:
	Store.delete_folder(FOLDER)
	w = WorldScene.instantiate()
	w.terrain_seed = 70621
	w.generation_options = load("res://scripts/world_generation.gd").defaults()
	w.save_folder = FOLDER
	w.load_distance = 4
	root.add_child(w)
	w.finish_terrain()
	var ids: Array = get_nodes_in_group("rocks").filter(func(r): return r.get_meta("rock").x >= 4).map(func(r): return r.get_meta("id"))
	check(ids.size() >= 6, "big rocks around (%d)" % ids.size())
	var gaps: Array = []
	var unsupported := 0
	var floating_after := 0
	for id in ids.slice(0, 6):
		for cells in [1, 4]:
			for offset in [Vector2(0, 0), Vector2(0.7, 0.3), Vector2(-0.5, 0.8)]:
				var rock: Node = _rock(id)
				if rock == null:
					continue
				var base: Vector3 = rock.global_position
				w.player.global_position = base + Vector3(5.0, 3.0, 5.0)
				await physics_frame
				var space: PhysicsDirectSpaceState3D = w.get_world_3d().direct_space_state
				var top: Vector3 = base + Vector3(offset.x, 12.0, offset.y)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 30.0))
				if hit.is_empty() or not hit.collider.is_in_group("rocks") or hit.normal.y <= 0.5:
					continue
				w.player.camera.global_position = hit.position + Vector3(1.0, 1.5, 1.0)
				var before: Dictionary = w.terrain.changes.duplicate()
				w.sculpt(hit, true, SmoothTerrain.DIRT, cells)
				var added: Array = w.terrain.changes.keys().filter(func(point): return not before.has(point) and w.terrain.density(point) > 0.0)
				for point: Vector3i in added:
					var center := Vector3(point) * SmoothTerrain.STEP
					var rock_top := _rock_top(space, center)
					if is_nan(rock_top):
						if not w.terrain.supports.has(point + Vector3i.DOWN) or w.terrain.density(point + Vector3i.DOWN) > 0.0:
							unsupported += 1
						continue
					gaps.append(_bottom(center, rock_top) - rock_top)
				w.settle_all()
				for point: Vector3i in added:
					if is_nan(_rock_top(space, Vector3(point) * SmoothTerrain.STEP)) and w.terrain.density(point) > 0.0 and w.terrain.density(point + Vector3i.DOWN) <= 0.0 and not w.terrain.supports.has(point + Vector3i.DOWN):
						floating_after += 1
	check(gaps.size() >= 30, "earth placed on the top of rocks (%d sub-cells measured)" % gaps.size())
	check(not gaps.is_empty() and gaps.max() <= 0.05, "the earth touches the rock: largest gap %.2f m (before 0.0.7.32: up to 1 m)" % (gaps.max() if not gaps.is_empty() else 99.0))
	check(floating_after == 0, "past the edge of the rock: no artificial support, it falls (%d without the rock under them)" % unsupported)
	# Survie : les joints comptent (une poignée chacun), jamais plus que ce qu'on tient.
	var rock: Node = _rock(ids[mini(6, ids.size() - 1)])
	w.player.global_position = rock.global_position + Vector3(5.0, 3.0, 5.0)
	await physics_frame
	var space: PhysicsDirectSpaceState3D = w.get_world_3d().direct_space_state
	var top: Vector3 = rock.global_position + Vector3(0.0, 12.0, 0.0)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 30.0))
	check(not hit.is_empty() and hit.collider.is_in_group("rocks"), "a fresh rock top for the survival check")
	if not hit.is_empty() and hit.collider.is_in_group("rocks"):
		w.player.camera.global_position = hit.position + Vector3(1.0, 1.5, 1.0)
		var before: Dictionary = w.terrain.changes.duplicate()
		w.sculpt(hit, true, SmoothTerrain.DIRT, 4, false, 1)
		var placed: int = w.terrain.changes.keys().filter(func(point): return not before.has(point) and w.terrain.density(point) > 0.0).size()
		check(placed <= 1 and w.last_gesture_points == placed, "survival with one handful: at most one sub-cell placed, counted (%d)" % placed)
	# Le sol lisse : la même sous-cellule qu'avant (point visé + 15 cm le long de la normale).
	var ground_at := Vector3(3.2, 0.0, -2.7)
	ground_at.y = w.terrain.height_at(ground_at.x, ground_at.z)
	var piece: Node = null
	for body in get_nodes_in_group("ground"):
		piece = body
		break
	w.player.global_position = ground_at + Vector3(2.0, 0.2, 2.0)
	w.player.camera.global_position = ground_at + Vector3(1.0, 1.6, 1.0)
	var expected := SmoothTerrain.point_of(ground_at + Vector3.UP * 0.15)
	var before_ground: Dictionary = w.terrain.changes.duplicate()
	w.sculpt({"collider": piece, "position": ground_at, "normal": Vector3.UP}, true, SmoothTerrain.DIRT, 1)
	var new_points: Array = w.terrain.changes.keys().filter(func(point): return not before_ground.has(point))
	check(new_points == [expected], "on the smooth ground: the same sub-cell as before (%s, expected %s, %s)" % [str(new_points), str(expected), w.notice])
	root.remove_child(w)
	w.free()
	Store.delete_folder(FOLDER)
	print("RESULT: %d rock place checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _rock_top(space: PhysicsDirectSpaceState3D, center: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 3.0, center + Vector3.DOWN * 3.0)
	var hit := space.intersect_ray(q)
	var tries := 0
	while not hit.is_empty() and not hit.collider.is_in_group("rocks") and tries < 5:
		q.exclude = q.exclude + [hit.rid]
		hit = space.intersect_ray(q)
		tries += 1
	return hit.position.y if not hit.is_empty() and hit.collider.is_in_group("rocks") else NAN

# Dessous de la terre : en montant depuis un peu sous le haut du rocher, première hauteur où la densité interpolée du
# terrain devient positive.
func _bottom(center: Vector3, rock_top: float) -> float:
	var y := rock_top - 0.25
	while y < center.y + 0.5:
		if _density(Vector3(center.x, y, center.z)) > 0.0:
			return y
		y += 0.01
	return 99.0

func _density(p: Vector3) -> float:
	var g := p / SmoothTerrain.STEP
	var base := Vector3i(floori(g.x), floori(g.y), floori(g.z))
	var f := g - Vector3(base)
	var total := 0.0
	for dx in range(2):
		for dy in range(2):
			for dz in range(2):
				var weight := (f.x if dx else 1.0 - f.x) * (f.y if dy else 1.0 - f.y) * (f.z if dz else 1.0 - f.z)
				total += weight * w.terrain.density(base + Vector3i(dx, dy, dz))
	return total
