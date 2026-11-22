extends RefCounted
# 0.0.8.13 « Plusieurs cœurs » (rapports de mesures Web, demande de l'utilisateur : aussi les PC bon marché) : les calculs du
# terrain faits sur d'autres cœurs. Chaque fil de calcul a SA copie du terrain (smooth_terrain.gd, même graine, mêmes
# options, préparée par lui-même : montagnes, lacs, rivières, grottes) : le terrain garde beaucoup de résultats en mémoire
# au fur et à mesure, deux fils ne doivent jamais écrire dans les mêmes. Le fil principal (celui des nœuds de Godot) envoie
# des travaux et reçoit des résultats (des nombres seulement : hauteurs, surfaces, relevés du lointain) ; il crée les
# maillages et les nœuds lui-même.
# Travaux : « colonne » (hauteurs du sol de la colonne et surfaces de ses zones qui ne sont pas plates ; seulement pour une
# colonne sans changement du joueur autour, la copie ne connaît que la graine), « lointain » (relevé d'un carré du lointain).
# Même graine = même monde : mêmes fonctions, mêmes nombres (tests/workers_test.gd compare avec le fil principal).
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
const FarTerrain = preload("res://scripts/far_terrain.gd")

# Fils de calcul : sur PC, selon le nombre de cœurs (au moins 1, au plus 2 : il reste toujours le fil principal, le rendu et
# le son) ; sur le Web (export avec fils), 2. Mesuré (PC, marche en forêt, temps du jeu par image) : sans fils 13,9 ms,
# 2 fils 10,0 ms, 3 fils 14,4 ms (les fils qui font tourner le code du jeu se gênent entre eux et gênent le fil principal :
# mémoire et objets communs de Godot).
const MAX_WORKERS := 2
const WEB_WORKERS := 2
# Mémoire d'une copie : au-delà, ses hauteurs et sols déjà calculés sont oubliés (recalculés au besoin, mêmes nombres).
const FORGET_AFTER := 150000

# Propriétaire (monde, écran de chargement) : toujours appeler stop() avant de lâcher cet objet (les fils travaillent sur
# lui ; Godot n'accepte pas d'appel de fonction pendant sa libération).
# Mesures et tests : MULTICOEUR=0 (variable d'environnement) coupe les fils de calcul (comme avant 0.0.8.13).
static func available() -> bool:
	if OS.get_environment("MULTICOEUR") == "0":
		return false
	# Web : seulement l'export avec fils (SharedArrayBuffer sur la page) ; sans, tout reste sur le fil principal.
	if OS.has_feature("web"):
		return OS.has_feature("threads")
	return OS.get_processor_count() >= 2

static func worker_count() -> int:
	# Mesures : COEURS=n (variable d'environnement) impose le nombre de fils de calcul.
	if not OS.get_environment("COEURS").is_empty():
		return clampi(int(OS.get_environment("COEURS")), 1, 8)
	if OS.has_feature("web"):
		return WEB_WORKERS
	# Tests sans fenêtre (plusieurs à la fois sur la même machine, PC ou Action GitHub) : un seul fil de calcul chacun.
	if DisplayServer.get_name() == "headless":
		return 1
	return clampi(OS.get_processor_count() - 2, 1, MAX_WORKERS)

var _threads: Array[Thread] = []
var _lock := Mutex.new()
var _wake := Semaphore.new()
# Travaux en attente : les colonnes d'abord (le sol sous les pieds), puis le lointain.
var _columns: Array = []
var _far: Array = []
var _results: Array = []
var _stopping := false
var _ready := 0
var _busy := 0

func start(terrain_seed: int, flat_spots: Array, options: Dictionary, count: int = worker_count()) -> void:
	for index in range(count):
		var thread := Thread.new()
		# Priorité basse : le fil principal (images, jeu) passe toujours avant, même sur un PC à 2 ou 4 cœurs.
		thread.start(_run.bind(terrain_seed, flat_spots.duplicate(true), options.duplicate(true)), Thread.PRIORITY_LOW)
		_threads.append(thread)

# Copies préparées (prêtes à calculer).
func ready_count() -> int:
	_lock.lock()
	var count := _ready
	_lock.unlock()
	return count

func is_ready() -> bool:
	return ready_count() > 0

# Travaux en attente ou en cours.
func pending_count() -> int:
	_lock.lock()
	var count := _columns.size() + _far.size() + _busy
	_lock.unlock()
	return count

# urgent : avant les autres colonnes (le joueur attend au bord de celle-ci).
func add_column(column: Vector2i, urgent := false) -> void:
	_lock.lock()
	if urgent:
		_columns.push_front({"kind": "colonne", "column": column})
	else:
		_columns.append({"kind": "colonne", "column": column})
	_lock.unlock()
	_wake.post()

# Colonne sortie de la vue avant d'être commencée : retirée des travaux (vrai si elle y était encore).
func cancel_column(column: Vector2i) -> bool:
	_lock.lock()
	var found := -1
	for index in range(_columns.size()):
		if _columns[index].column == column:
			found = index
			break
	if found >= 0:
		_columns.remove_at(found)
	_lock.unlock()
	return found >= 0

func add_far(key: Vector3i, tile: Vector2i, cell: float) -> void:
	_lock.lock()
	_far.append({"kind": "lointain", "key": key, "tile": tile, "cell": cell})
	_lock.unlock()
	_wake.post()

# Résultats arrivés depuis le dernier appel (fil principal).
func take_results() -> Array:
	_lock.lock()
	var taken := _results
	_results = []
	_lock.unlock()
	return taken

# Arrêt (monde fermé) : les fils finissent leur travail en cours (ou leur préparation s'arrête à la prochaine tranche),
# puis s'arrêtent.
func stop() -> void:
	_lock.lock()
	_stopping = true
	_columns.clear()
	_far.clear()
	_lock.unlock()
	for thread in _threads:
		_wake.post()
	for thread in _threads:
		if thread.is_started():
			thread.wait_to_finish()
	_threads.clear()

# --- Dans chaque fil de calcul ---

const PREPARE_SLICE_USEC := 20000

func _is_stopping() -> bool:
	_lock.lock()
	var stopping := _stopping
	_lock.unlock()
	return stopping

func _run(terrain_seed: int, flat_spots: Array, options: Dictionary) -> void:
	var terrain := SmoothTerrain.new()
	terrain.setup(terrain_seed, flat_spots, options, false)
	# Préparation par tranches : un monde fermé tout de suite n'attend pas toute la préparation.
	while not terrain.prepare_step(PREPARE_SLICE_USEC):
		if _is_stopping():
			return
	_lock.lock()
	_ready += 1
	_lock.unlock()
	while true:
		_wake.wait()
		_lock.lock()
		if _stopping:
			_lock.unlock()
			break
		var job: Dictionary = {}
		if not _columns.is_empty():
			job = _columns.pop_front()
		elif not _far.is_empty():
			job = _far.pop_front()
		if not job.is_empty():
			_busy += 1
		_lock.unlock()
		if job.is_empty():
			continue
		var result := _column(terrain, job.column) if job.kind == "colonne" else _far_survey(terrain, job)
		if terrain._heights.size() > FORGET_AFTER:
			_forget_all(terrain)
		_lock.lock()
		_busy -= 1
		if not _stopping:
			_results.append(result)
		_lock.unlock()

# Hauteurs de la colonne (les mêmes points que la file du terrain, world._terrain_step) et surfaces de ses zones.
static func _column(terrain: SmoothTerrain, column: Vector2i) -> Dictionary:
	var heights := {}
	var points: int = SmoothTerrain.POINTS + 2
	for x in range(points):
		for z in range(points):
			var point := Vector2i(column.x * SmoothTerrain.POINTS - 1 + x, column.y * SmoothTerrain.POINTS - 1 + z)
			heights[point] = terrain.ground_height(point)
	var surfaces := {}
	var zones: Array = terrain.surface_zones(column, column).keys()
	for zone: Vector3i in zones:
		if not terrain.is_flat(zone):
			surfaces[zone] = terrain.zone_surface(zone)
	return {"kind": "colonne", "column": column, "heights": heights, "zones": zones, "surfaces": surfaces}

static func _far_survey(terrain: SmoothTerrain, job: Dictionary) -> Dictionary:
	var survey := FarTerrain.new_survey(job.tile, job.cell)
	FarTerrain.advance(terrain, survey, 1 << 62)
	return {"kind": "lointain", "key": job.key, "survey": survey}

static func _forget_all(terrain: SmoothTerrain) -> void:
	terrain._heights.clear()
	terrain._soils.clear()
	terrain._snow.clear()
	terrain._lifts.clear()
	terrain._desert_columns.clear()
	terrain._needle_columns.clear()
	terrain._surface_ys.clear()
