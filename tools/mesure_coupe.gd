extends SceneTree
# 0.0.8.22 (l'utilisateur : « les perf sont horribles » après avoir coupé 2 arbres) : mesure avant / après la coupe.
# Un pommier (taille 3) et un noisetier (taille 5) devant le joueur : arbres debout, puis toutes les grosses branches du
# pommier et toutes les tiges du noisetier coupées (couchées), puis chaque morceau couché recoupé (bois au sol).
# À lancer AVEC fenêtre (CLAUDE.md : petite, sans bord, coin en bas à droite, sans clavier ni souris) :
#   & '<Godot console>' --path . --resolution 480x270 --script res://tools/mesure_coupe.gd
# Imprime des lignes « MESURE clé = valeur » : images par seconde, temps (jeu, physique, rendu), dessins, objets,
# triangles, et le temps de la visée du bois (aimed_wood) à chaque image.
const Trees = preload("res://scripts/trees.gd")
const TreeParts = preload("res://scripts/tree_parts.gd")
const Inventory = preload("res://scripts/inventory.gd")
const SIZE := Vector2i(480, 270)

func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(SIZE)
	var area := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	DisplayServer.window_set_position(area.end - SIZE)
	root.gui_disable_input = true
	root.set_disable_input(true)
	process_frame.connect(func() -> void:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	call_deferred("_run")

func report(key: String, value: Variant) -> void:
	print("MESURE %s = %s" % [key, str(value)])

func frames(count: int) -> void:
	for index in range(count):
		await process_frame

func measure(prefix: String, world: Node3D) -> void:
	await frames(60)
	var viewport := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var times := []
	var split := {"jeu": 0.0, "physique": 0.0, "rendu_cpu": 0.0, "rendu_gpu": 0.0, "visee_bois": 0.0}
	var last := Time.get_ticks_usec()
	var count := 240
	for index in range(count):
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		split.jeu += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		split.physique += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		split.rendu_cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport) + RenderingServer.get_frame_setup_time_cpu()
		split.rendu_gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
		var at := Time.get_ticks_usec()
		world.aimed_wood(world.player.get_target())
		split.visee_bois += (Time.get_ticks_usec() - at) / 1000.0
	var total := 0.0
	for value in times:
		total += value
	var sorted := times.duplicate()
	sorted.sort()
	for key in split:
		split[key] = snappedf(split[key] / count, 0.01)
	report(prefix + ".fps", snappedf(1000.0 * count / maxf(total, 0.001), 0.1))
	report(prefix + ".ms_p95", snappedf(sorted[int(count * 0.95)], 0.01))
	report(prefix + ".ms_max", snappedf(sorted[-1], 0.01))
	# Images qu'on verrait saccader à 60 images par seconde.
	report(prefix + ".images_plus_de_17ms", times.filter(func(value): return value > 17.0).size())
	report(prefix + ".temps_ms", str(split))
	report(prefix + ".dessins", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	report(prefix + ".objets", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	report(prefix + ".triangles", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var parts := 0
	for list in world.column_objects.values():
		for node in list:
			if is_instance_valid(node) and node.has_meta("kind") and int(node.get_meta("part", 0)) != 0:
				parts += 1
	report(prefix + ".morceaux_couches", parts)
	# Ce que dessinent les morceaux couchés (surfaces, ombre portée ou non).
	var kinds := {}
	for list in world.column_objects.values():
		for node in list:
			if not is_instance_valid(node) or not node.has_meta("kind") or int(node.get_meta("part", 0)) == 0:
				continue
			for drawn: GeometryInstance3D in node.find_children("*", "GeometryInstance3D", true, false):
				if not drawn.is_visible_in_tree():
					continue
				var mesh: Mesh = drawn.multimesh.mesh if drawn is MultiMeshInstance3D and drawn.multimesh != null else (drawn.mesh if drawn is MeshInstance3D else null)
				var surfaces := mesh.get_surface_count() if mesh != null else 0
				var key := "%s_%s_ombre%d" % [drawn.get_class().replace("Instance3D", ""), str(drawn.name).rstrip("0123456789@_"), int(drawn.cast_shadow)]
				kinds[key] = int(kinds.get(key, 0)) + surfaces
	report(prefix + ".surfaces_des_morceaux", str(kinds))
	report(prefix + ".objets_au_sol", world.ground.entries.size())
	report(prefix + ".cache_morceaux", TreeParts._assignments.size())

func make(world: Node3D, id: String, kind: int, size: int, at: Vector3) -> Node3D:
	var tree: Node3D = Trees.tree_body(kind, size)
	tree.set_meta("id", id)
	var column: Vector2i = world._player_column()
	tree.set_meta("column", column)
	world._rocks_parent().add_child(tree)
	tree.global_position = Vector3(at.x, world.terrain.height_at(at.x, at.z) - 0.05, at.z)
	world.column_objects[column] = world.column_objects.get(column, []) + [tree]
	return tree

func nodes_of(world: Node3D, id: String) -> Array:
	var found := []
	for list in world.column_objects.values():
		for node in list:
			if is_instance_valid(node) and not node.is_queued_for_deletion() and node.get_meta("id", "") == id:
				found.append(node)
	return found

var cut_costs := []

func _run() -> void:
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	world.game_mode = Inventory.CREATIVE
	root.add_child(world)
	await frames(240)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	var feet: Vector3 = player.global_position
	var apple := make(world, "mesure-pommier", Trees.APPLE, 3, feet + Vector3(-3.0, 0.0, -7.0))
	var hazel := make(world, "mesure-noisetier", Trees.HAZEL, 5, feet + Vector3(4.0, 0.0, -6.0))
	player.camera.look_at(feet + Vector3(0.0, 1.5, -7.0), Vector3.UP)
	await measure("1_debout", world)
	# Toutes les grosses branches du pommier, toutes les tiges du noisetier.
	var crown: Dictionary = TreeParts.skeleton(Trees.APPLE, 3, 0)
	for number in range(crown.pieces.size()):
		var piece: Dictionary = crown.pieces[number]
		if piece.root or piece.depth != 1 or piece.length < 0.5:
			continue
		var holder: Array = nodes_of(world, "mesure-pommier").filter(func(node): return TreeParts.assignment(Trees.APPLE, 3, 0, world._cuts_of(node)).ranges[int(node.get_meta("part", 0))].has(number))
		if holder.is_empty() or holder[0].has_meta("falling"):
			continue
		var at := Time.get_ticks_usec()
		world.cut_wood(holder[0], number, 0.05, world._model_of(holder[0]) * (piece.start + piece.direction * 0.05))
		cut_costs.append((Time.get_ticks_usec() - at) / 1000.0)
		await frames(2)
	report("coupe_branche_ms", str(cut_costs.map(func(v): return snappedf(v, 0.1))))
	cut_costs.clear()
	var bush: Dictionary = TreeParts.skeleton(Trees.HAZEL, 5, 0)
	for number in range(bush.pieces.size()):
		var piece: Dictionary = bush.pieces[number]
		if not piece.root or piece.tip.y < 0.5:
			continue
		var holder: Array = nodes_of(world, "mesure-noisetier").filter(func(node): return int(node.get_meta("part", 0)) == 0)
		if holder.is_empty():
			break
		var at := Time.get_ticks_usec()
		world.cut_wood(holder[0], number, 0.35, world._model_of(holder[0]) * (piece.start + piece.direction * 0.35))
		cut_costs.append((Time.get_ticks_usec() - at) / 1000.0)
		await frames(2)
	report("coupe_tige_ms", str(cut_costs.map(func(v): return snappedf(v, 0.1))))
	cut_costs.clear()
	# Les chutes et les poses : la plus longue image pendant 150 images.
	var worst := 0.0
	var last := Time.get_ticks_usec()
	for index in range(150):
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
	report("chutes.image_la_plus_longue_ms", snappedf(worst, 0.1))
	await measure("2_coupes", world)
	# Chaque morceau couché recoupé au milieu de sa pièce principale.
	for id in ["mesure-pommier", "mesure-noisetier"]:
		for node in nodes_of(world, id):
			if not is_instance_valid(node) or int(node.get_meta("part", 0)) == 0 or node.has_meta("falling"):
				continue
			var kind := int(node.get_meta("kind", 0))
			var size := int(node.get_meta("size", 3))
			var main: Array = TreeParts.main_span(kind, size, 0, world._cuts_of(node), int(node.get_meta("part", 0)))
			if main.is_empty():
				continue
			var at := Time.get_ticks_usec()
			world.cut_wood(node, int(main[0]), (float(main[1]) + float(main[2])) * 0.5, node.global_position)
			cut_costs.append((Time.get_ticks_usec() - at) / 1000.0)
			await frames(2)
	report("recoupe_ms", str(cut_costs.map(func(v): return snappedf(v, 0.1))))
	await frames(120)
	await measure("3_recoupes", world)
	# 0.0.8.23 : R sur chaque morceau couché : ses feuilles tombent en tas (le morceau reste, nu).
	cut_costs.clear()
	for id in ["mesure-pommier", "mesure-noisetier"]:
		for node in nodes_of(world, id):
			if not is_instance_valid(node) or int(node.get_meta("part", 0)) == 0 or node.has_meta("falling") or world._stripped(node):
				continue
			var at := Time.get_ticks_usec()
			world._strip_leaves(node)
			cut_costs.append((Time.get_ticks_usec() - at) / 1000.0)
			await frames(2)
	report("feuilles_tombees_ms", str(cut_costs.map(func(v): return snappedf(v, 0.1))))
	report("tas_de_feuilles", world.ground.entries.filter(func(entry): return entry.item.get("objet", "") == "feuilles").size())
	await frames(60)
	await measure("4_feuilles", world)
	quit(0)
