extends Node
# 0.0.8.14 (rapport d'optimisation) : mesures du rendu dans la version Web, depuis la console de Chrome (F12), pour mesurer
# sur une petite carte graphique ce que coûte chaque sorte de chose (scripts/diagnostic.gd). Rien ne change pour le joueur :
# seulement des commandes à taper dans la console, dans un monde ouvert. Le résultat de chaque commande est écrit dans
# window.orbmekaResultat (texte JSON) :
#   orbmeka.aide()               liste des commandes, sortes, effets et endroits
#   orbmeka.aller("foret")       le joueur à un endroit de mesure (depart, foret, lac, riviere)
#   orbmeka.cacher("arbres")     masque une sorte, coupe un effet ou essaie un réglage plus léger ; orbmeka.montrer("arbres") remet
#   orbmeka.tout()               tout remis comme avant
#   orbmeka.mesurer(180)         mesure 180 images (résultat quand c'est fini : "fini": true)
#   orbmeka.etat()               monde construit ? choses de chaque sorte, ce qui est caché
const Diagnostic = preload("res://scripts/diagnostic.gd")

var app: Node
var _callbacks: Array = []
var _window: JavaScriptObject
# Mesure en cours : images restantes, et sommes.
var _left := 0
var _samples: Array = []
var _sums := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_window = JavaScriptBridge.get_interface("window")
	if _window == null:
		return
	var api: JavaScriptObject = JavaScriptBridge.create_object("Object")
	for pair in [["aide", _help], ["aller", _go], ["cacher", _hide], ["montrer", _show], ["tout", _all], ["mesurer", _measure], ["etat", _state]]:
		var callback := JavaScriptBridge.create_callback(pair[1])
		_callbacks.append(callback)
		api.set(pair[0], callback)
	_window.orbmeka = api

func _world() -> Node3D:
	var world: Variant = app.get("active_world")
	return world if is_instance_valid(world) else null

func _answer(value: Variant) -> void:
	_window.orbmekaResultat = JSON.stringify(value)

func _arg(args: Array, index: int, default: Variant) -> Variant:
	return args[index] if args.size() > index and args[index] != null else default

func _help(_args: Array) -> void:
	_answer({"commandes": ["aide()", "aller(nom)", "cacher(nom)", "montrer(nom)", "tout()", "mesurer(images)", "etat()"], "sortes": Diagnostic.SORTS, "effets": Diagnostic.EFFECTS, "reglages_a_essayer": Diagnostic.VARIANTS, "endroits": Diagnostic.SPOTS})

func _go(args: Array) -> void:
	var world := _world()
	_answer({"ok": world != null and Diagnostic.go_to_spot(world, str(_arg(args, 0, "depart")))})

func _toggle(args: Array, shown: bool) -> void:
	var world := _world()
	var name := str(_arg(args, 0, ""))
	var ok := world != null and (Diagnostic.show_sort(world, name, shown) if name in Diagnostic.SORTS else Diagnostic.set_effect(world, name, shown))
	_answer({"ok": ok, "nom": name, "montre": shown})

func _hide(args: Array) -> void:
	_toggle(args, false)

func _show(args: Array) -> void:
	_toggle(args, true)

func _all(_args: Array) -> void:
	var world := _world()
	if world != null:
		Diagnostic.restore_all(world)
	_answer({"ok": world != null})

func _state(_args: Array) -> void:
	var world := _world()
	if world == null:
		_answer({"monde": false})
		return
	_answer({"monde": true, "construit": Diagnostic.built(world), "choses": Diagnostic.counts(world), "joueur": [world.player.global_position.x, world.player.global_position.z]})

func _measure(args: Array) -> void:
	_left = clampi(int(_arg(args, 0, 180)), 10, 2000)
	_samples = []
	_sums = {"calcul": 0.0, "gpu": 0.0, "dessins": 0.0, "triangles": 0.0}
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_answer({"fini": false, "images": _left})

func _process(delta: float) -> void:
	if _left <= 0:
		return
	_left -= 1
	_samples.append(delta * 1000.0)
	_sums.calcul += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_sums.gpu += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	_sums.dessins += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_sums.triangles += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	if _left > 0:
		return
	var count := float(_samples.size())
	var sorted := _samples.duplicate()
	sorted.sort()
	var total := 0.0
	for value in _samples:
		total += value
	var world := _world()
	_answer({"fini": true, "images": _samples.size(), "images_par_seconde": snappedf(1000.0 * count / maxf(total, 0.001), 0.1),
		"ms_image_moyenne": snappedf(total / count, 0.01), "ms_image_p95": snappedf(sorted[int(count * 0.95)], 0.01), "ms_image_max": snappedf(sorted[-1], 0.01),
		"ms_calcul_godot": snappedf(_sums.calcul / count, 0.01), "ms_carte_graphique_godot": snappedf(_sums.gpu / count, 0.01),
		"dessins": roundi(_sums.dessins / count), "triangles": roundi(_sums.triangles / count),
		"memoire_godot_mo": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"construit": world != null and Diagnostic.built(world)})
