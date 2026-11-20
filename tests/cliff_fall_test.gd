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
	t.wake(under)
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
	print("RESULT: %d cliff fall checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

# Plus haut point plein d'une colonne (en points de 50 cm).
static func _top(t: RefCounted, x: int, z: int) -> int:
	var y := 60
	while y > -40 and t.density(Vector3i(x, y, z)) <= 0.0:
		y -= 1
	return y
