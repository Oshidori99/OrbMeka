extends SceneTree
# 0.0.7.33 (demande de l'utilisateur : en posant de la terre sur un rocher près d'un précipice, tout le bord s'est mis à
# glisser, lent et lourd) : le sol d'origine ne glisse plus en talus ; seul ce qui est posé ou déplacé glisse, et ce qui
# n'a plus rien dessous tombe toujours. Un tas de sable posé s'étale encore. Les zones touchées par une chute sont refaites
# ensemble, moins souvent.
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
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
	var t: RefCounted = SmoothTerrain.new()
	t.setup(70621, [], Generation.defaults())
	# Bords raides du sol d'origine : un point du haut avec, à côté, 2 m de vide ou plus (plus raide que le talus).
	var edges: Array = []
	for x in range(-120, 120):
		for z in range(-120, 120):
			if edges.size() >= 40:
				break
			var top := _top(t, x, z)
			for side in SmoothTerrain.SIDES:
				if _top(t, x + side.x, z + side.z) <= top - 4:
					edges.append(Vector3i(x, top, z))
					break
	check(edges.size() >= 10, "steep edges of the original ground found (%d)" % edges.size())
	# Avant 0.0.7.33, chacun glissait (talus) et réveillait ses voisins : une avalanche le long du bord.
	for point: Vector3i in edges:
		t.wake(point)
	var moved := 0
	for step in range(200):
		moved += t.settle_step().size()
		if t.unstable.is_empty():
			break
	check(moved == 0, "the original ground of a cliff stays in place when woken (%d moves)" % moved)
	# Ce qui n'a plus rien dessous tombe toujours, même du sol d'origine (sable : jamais en plafond).
	var edge: Vector3i = edges[0]
	var under := edge + Vector3i.DOWN
	t.set_density(edge, t.density(edge), SmoothTerrain.SAND)
	t.set_density(under, SmoothTerrain.DUG)
	t.dug(under)
	for step in range(50):
		t.settle_step()
	check(t.density(edge) <= 0.0, "sand of the original ground with nothing under it still falls")
	# Un tas de sable posé s'étale encore (talus) sur du sol plat.
	var flat := SmoothTerrain.new()
	flat.setup(1, [], Generation.defaults())
	var base := Vector3i(0, _top(flat, 0, 0) + 1, 0)
	for y in range(4):
		flat.set_density(base + Vector3i(0, y, 0), SmoothTerrain.ADDED, SmoothTerrain.SAND)
		flat.wake(base + Vector3i(0, y, 0))
	var spread := 0
	for step in range(100):
		spread += flat.settle_step().size()
		if flat.unstable.is_empty():
			break
	check(spread > 0 and flat.density(base + Vector3i(0, 3, 0)) <= 0.0, "a placed pile of sand still spreads (%d moves)" % spread)
	# Le monde refait les zones d'une chute ensemble : moins de recalculs qu'à chaque cran.
	var world_script: Script = load("res://scripts/world.gd")
	check(world_script.FALL_REFRESH_SECONDS >= 3.0 * world_script.FALL_SECONDS, "zones of a fall rebuilt together, at most every %.2f s (each step: %.2f s)" % [world_script.FALL_REFRESH_SECONDS, world_script.FALL_SECONDS])
	# --- 0.0.8.34 (demandes de l'utilisateur : une crevasse ou une grotte ne s'effondre jamais d'un coup ; choix « près du
	# geste ») : le sol d'origine ne tombe que si le joueur creuse tout près (1 m), jamais en chaîne ; sable à 34° ; la
	# terre retombée ne se colle plus en mur. ---
	var cave := SmoothTerrain.new()
	cave.setup(70621, [], Generation.defaults())
	var ready: Array = []
	for x in range(-64, 64):
		for z in range(192, 320):
			var top := int(floor(cave.ground_height(Vector2i(x, z)) / SmoothTerrain.STEP)) + 2
			var above_solid: bool = cave.solid(Vector3i(x, top, z))
			for y in range(top - 1, top - 60, -1):
				var is_solid: bool = cave.solid(Vector3i(x, y, z))
				if above_solid and not is_solid:
					var over := Vector3i(x, y + 1, z)
					cave.loosened[over] = true
					if not cave.is_stone(over) and cave.fall_target(over) != over:
						ready.append(over)
					cave.loosened.erase(over)
				above_solid = is_solid
	check(ready.size() >= 20, "overhangs of the original ground that have nothing under them (%d)" % ready.size())
	# Seulement réveillés (un arbre coupé, de la terre posée à côté) : rien ne tombe.
	for point: Vector3i in ready:
		cave.wake(point)
	var woken_moves := 0
	for step in range(400):
		woken_moves += cave.settle_step().size()
		if cave.unstable.is_empty():
			break
	check(woken_moves == 0 and cave.changes.is_empty(), "woken without digging: nothing falls (%d moves ; before 0.0.8.34: up to 2 842 sub-cells in a chain)" % woken_moves)
	# Le joueur creuse juste dessous : seul le sol d'origine à 1 m du geste tombe, jamais plus loin.
	var most := 0
	var outside := 0
	var trials := 0
	for index in range(0, ready.size(), maxi(1, ready.size() / 12)):
		var gesture: Vector3i = ready[index] + Vector3i.DOWN
		var before: Dictionary = cave.changes.duplicate()
		cave.loosened.erase(ready[index])
		cave.dug(gesture)
		for step in range(4000):
			cave.settle_step()
			if cave.unstable.is_empty():
				break
		var fallen := 0
		for changed: Vector3i in cave.changes:
			if not before.has(changed) and float(cave.changes[changed]) <= 0.0 and cave.base_density(changed) > 0.0:
				fallen += 1
				if maxi(maxi(absi(changed.x - gesture.x), absi(changed.y - gesture.y)), absi(changed.z - gesture.z)) > SmoothTerrain.GESTURE_REACH:
					outside += 1
		most = maxi(most, fallen)
		trials += 1
	check(trials >= 8 and most >= 1 and most <= 125 and outside == 0, "dug right under them: only the original ground within 1 m of the dig falls (%d sub-cells at most, %d further away)" % [most, outside])
	check(cave.loosened.is_empty(), "once everything has fallen, no leave to fall is kept")
	# Tas de sable : jamais plus de deux marches pour trois pas (34°) ; tas de terre : plus de mur de plus de 1 m, et
	# rien qui reste collé en l'air.
	for spec in [[SmoothTerrain.SAND, 1, 2.0 / 3.0, "sand: 34° at most"], [SmoothTerrain.DIRT, 2, 2.0, "dirt: a steep slope, no wall higher than 1 m"]]:
		var pile := SmoothTerrain.new()
		pile.setup(1, [], Generation.defaults())
		var foot := Vector3i(0, _top(pile, 0, 0) + 1, 0)
		for y in range(12):
			for dx in range(2):
				for dz in range(2):
					pile.set_density(foot + Vector3i(dx, y, dz), SmoothTerrain.ADDED, spec[0])
					pile.wake(foot + Vector3i(dx, y, dz))
		for step in range(4000):
			pile.settle_step()
			if pile.unstable.is_empty():
				break
		var heights := {}
		var hanging := 0
		var kept := 0
		for placed: Vector3i in pile.changes:
			if float(pile.changes[placed]) <= 0.0:
				continue
			kept += 1
			var column := Vector2i(placed.x, placed.z)
			heights[column] = maxi(int(heights.get(column, -999)), placed.y)
			if not pile.solid(placed + Vector3i.DOWN):
				hanging += 1
		var highest_step := 0
		var steepest := 0.0
		for column: Vector2i in heights:
			for side in SmoothTerrain.SIDES:
				var beside := column + Vector2i(side.x, side.z)
				var here: int = heights[column]
				var there: int = int(heights.get(beside, _top(pile, beside.x, beside.y)))
				highest_step = maxi(highest_step, here - there)
				var far := column + Vector2i(side.x, side.z) * 3
				steepest = maxf(steepest, (here - int(heights.get(far, _top(pile, far.x, far.y)))) / 3.0)
		check(kept == 48 and hanging == 0, "the pile fell to the ground, nothing lost, nothing left hanging (%d of 48, %d hanging)" % [kept, hanging])
		check(highest_step <= int(spec[1]) and steepest <= float(spec[2]) + 0.001, "%s (highest step %d points, steepest slope over 1.5 m %.0f°)" % [spec[3], highest_step, rad_to_deg(atan(steepest))])
	check(world_script.BIG_FALL >= 4 and world_script.FALL_BUDGET_USEC <= 4000, "a fall is done at once, a few thousandths of a second per frame; shown step by step only from %d sub-cells of the original ground" % world_script.BIG_FALL)
	print("RESULT: %d cliff fall checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

# Plus haut point plein d'une colonne (en points de 50 cm).
static func _top(t: RefCounted, x: int, z: int) -> int:
	var y := 60
	while y > -40 and t.density(Vector3i(x, y, z)) <= 0.0:
		y -= 1
	return y
