extends RefCounted
# Contrôles modifiables (0.0.3.12) : une touche ou un bouton de souris par action, ou aucun.
# Les flèches ← → restent toujours actives pour aller de côté, en plus de la touche choisie
# (0.0.4.3 : ↑ ↓ ne font plus marcher, elles changent la vitesse).
# Une liaison : {"key": code physique} ou {"mouse": bouton} ; {} = aucune touche.
# 0.0.3.27 : deuxième touche facultative, {"key": …, "second": {"key" ou "mouse": …}} :
# la même touche = double appui (DOUBLE_PRESS_MS), une autre = les deux en même temps.
# Les anciens fichiers (une seule touche) restent valides tels quels.
# Touches gardées pour le jeu, jamais attribuables : Échap (pause, « aucune » pendant
# le choix d'une touche), F1, F2, F3 (raccourcis des menus).

const ACTIONS := {
	"move_forward": {"label": "Avancer", "default": {"key": KEY_W}, "fixed": []},
	"move_back": {"label": "Reculer", "default": {"key": KEY_S}, "fixed": []},
	"move_left": {"label": "Aller à gauche", "default": {"key": KEY_A}, "fixed": [KEY_LEFT]},
	"move_right": {"label": "Aller à droite", "default": {"key": KEY_D}, "fixed": [KEY_RIGHT]},
	"jump": {"label": "Sauter", "default": {"key": KEY_SPACE}, "fixed": []},
	# 0.0.3.15 : maintenir pour se baisser (plus lent, chute plus lourde).
	# Défaut par lettre (0.0.3.18) : la touche marquée Y sur le clavier du joueur
	# (QWERTZ suisse ou allemand : Y et Z sont inversés par rapport au QWERTY).
	"crouch": {"label": "Se baisser", "default": {"key": KEY_Y}, "by_letter": true, "fixed": []},
	# 0.0.3.24 : maintenir pour courir (plus rapide) ; défaut par lettre : R.
	"sprint": {"label": "Courir", "default": {"key": KEY_R}, "by_letter": true, "fixed": []},
	# 0.0.4.3 : changer la vitesse de marche et de course (← → seules restent pour se déplacer).
	"speed_up": {"label": "Plus vite", "default": {"key": KEY_UP}, "fixed": []},
	"speed_down": {"label": "Moins vite", "default": {"key": KEY_DOWN}, "fixed": []},
	# 0.0.4.6 (#105) : ↑ ou ↓ avec une autre touche : seulement la marche, la course, la casse ou
	# la pose (casse et pose : monde en mode développeur). ⌫ + la même touche : cette valeur par
	# défaut ; ⌫ deux fois : tout par défaut (remplace R + ↓ de 0.0.4.4, ancien « speed_reset » ignoré).
	"walk_up": {"label": "Marche plus vite", "default": {"key": KEY_UP, "second": {"key": KEY_W}}, "fixed": []},
	"walk_down": {"label": "Marche moins vite", "default": {"key": KEY_DOWN, "second": {"key": KEY_W}}, "fixed": []},
	"run_up": {"label": "Course plus vite", "default": {"key": KEY_UP, "second": {"key": KEY_R}}, "by_letter": true, "fixed": []},
	"run_down": {"label": "Course moins vite", "default": {"key": KEY_DOWN, "second": {"key": KEY_R}}, "by_letter": true, "fixed": []},
	"break_up": {"label": "Casse plus rapide", "default": {"key": KEY_UP, "second": {"mouse": MOUSE_BUTTON_LEFT}}, "fixed": []},
	"break_down": {"label": "Casse moins rapide", "default": {"key": KEY_DOWN, "second": {"mouse": MOUSE_BUTTON_LEFT}}, "fixed": []},
	"place_up": {"label": "Pose plus rapide", "default": {"key": KEY_UP, "second": {"mouse": MOUSE_BUTTON_RIGHT}}, "fixed": []},
	"place_down": {"label": "Pose moins rapide", "default": {"key": KEY_DOWN, "second": {"mouse": MOUSE_BUTTON_RIGHT}}, "fixed": []},
	"walk_reset": {"label": "Marche par défaut", "default": {"key": KEY_BACKSPACE, "second": {"key": KEY_W}}, "fixed": []},
	"run_reset": {"label": "Course par défaut", "default": {"key": KEY_BACKSPACE, "second": {"key": KEY_R}}, "by_letter": true, "fixed": []},
	"break_reset": {"label": "Casse par défaut", "default": {"key": KEY_BACKSPACE, "second": {"mouse": MOUSE_BUTTON_LEFT}}, "fixed": []},
	"place_reset": {"label": "Pose par défaut", "default": {"key": KEY_BACKSPACE, "second": {"mouse": MOUSE_BUTTON_RIGHT}}, "fixed": []},
	"speed_reset_all": {"label": "Tout par défaut", "default": {"key": KEY_BACKSPACE, "second": {"key": KEY_BACKSPACE}}, "fixed": []},
	# 0.0.4.5 : Espace deux fois (choix de l'utilisateur) pour voler, encore deux fois pour arrêter ;
	# le premier appui fait sauter. En vol, Sauter monte et Se baisser descend.
	"fly": {"label": "Voler", "default": {"key": KEY_SPACE, "second": {"key": KEY_SPACE}}, "fixed": []},
	"break_block": {"label": "Casser", "default": {"mouse": MOUSE_BUTTON_LEFT}, "fixed": []},
	"place_block": {"label": "Poser", "default": {"mouse": MOUSE_BUTTON_RIGHT}, "fixed": []},
	"block_previous": {"label": "Bloc précédent", "default": {"mouse": MOUSE_BUTTON_WHEEL_UP}, "fixed": []},
	"block_next": {"label": "Bloc suivant", "default": {"mouse": MOUSE_BUTTON_WHEEL_DOWN}, "fixed": []},
}
# Choix des Contrôles (0.0.3.18), enregistrés dans controles.json avec les touches.
# Se baisser : Maintenir = rester appuyé ; Basculer = un appui pour se baisser, un autre pour se relever.
# Courir (0.0.3.25) : en plus, Maintenir conditionnel = un appui lance la course jusqu'à une interruption.
# Chaque choix a sa catégorie dans Contrôles, avec son explication [−, Par défaut, +].
const OPTIONS := {
	"crouch_mode": {"label": "Mode pour se baisser", "options": {"hold": "Maintenir", "toggle": "Basculer"}, "default": "hold",
		"category": "Se baisser", "help": ["", "Maintenir la touche ou appuyer pour basculer.", "Maintenir : rester appuyé pour rester baissé. Basculer : un appui pour se baisser, un autre pour se relever."]},
	"run_mode": {"label": "Mode pour courir", "options": {"hold": "Maintenir", "latch": "Maintenir conditionnel", "toggle": "Basculer"}, "default": "hold",
		"category": "Courir", "help": ["", "Maintenir, lancer d'un appui, ou basculer.", "Maintenir : rester appuyé pour courir. Maintenir conditionnel : un appui lance la course ; elle s'arrête si l'on s'arrête, saute, se baisse ou met en pause, puis il faut réappuyer. Basculer : un appui pour courir, un autre pour marcher."]},
}

static func default_options() -> Dictionary:
	var result := {}
	for option in OPTIONS:
		result[option] = OPTIONS[option].default
	return result

const RESERVED_KEYS :=[KEY_ESCAPE, KEY_F1, KEY_F2, KEY_F3]
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "Clic gauche", MOUSE_BUTTON_RIGHT: "Clic droit", MOUSE_BUTTON_MIDDLE: "Clic molette", MOUSE_BUTTON_XBUTTON1: "Bouton souris 4", MOUSE_BUTTON_XBUTTON2: "Bouton souris 5", MOUSE_BUTTON_WHEEL_UP: "Molette haut", MOUSE_BUTTON_WHEEL_DOWN: "Molette bas"}

static func defaults() -> Dictionary:
	var result := {}
	for action in ACTIONS:
		result[action] = default_for(action)
	return result

# Liaison par défaut d'une action ; « by_letter » : la touche qui porte cette lettre
# sur le clavier du joueur, quelle que soit sa disposition.
static func default_for(action: String) -> Dictionary:
	var binding: Dictionary = ACTIONS[action].default.duplicate(true)
	if ACTIONS[action].get("by_letter", false) and binding.has("key"):
		binding.key = physical_for_letter(binding.key)
		if binding.has("second") and binding.second.has("key"):
			binding.second.key = physical_for_letter(binding.second.key)
	return binding

static func physical_for_letter(letter: int) -> int:
	if DisplayServer.get_name() == "headless":
		return letter
	for code in range(KEY_A, KEY_Z + 1):
		if DisplayServer.keyboard_get_keycode_from_physical(code) == letter:
			return code
	return letter

# Deux appuis de la même touche au plus à cet intervalle : un double appui.
const DOUBLE_PRESS_MS := 300

# Liaison valide : vide, touche non réservée, ou bouton de souris connu (molette comprise),
# avec au plus une deuxième touche du même genre.
static func is_valid(binding: Variant) -> bool:
	if not binding is Dictionary:
		return false
	if binding.is_empty():
		return true
	if binding.has("second"):
		var rest: Dictionary = binding.duplicate()
		rest.erase("second")
		return _is_valid_part(rest) and _is_valid_part(binding.second)
	return _is_valid_part(binding)

static func _is_valid_part(part: Variant) -> bool:
	if not part is Dictionary or part.size() != 1:
		return false
	if part.has("key"):
		return (part.key is int or part.key is float) and int(part.key) > 0 and not int(part.key) in RESERVED_KEYS
	if part.has("mouse"):
		return (part.mouse is int or part.mouse is float) and MOUSE_NAMES.has(int(part.mouse))
	return false

static func clean(binding: Dictionary) -> Dictionary:
	var result := _clean_part(binding)
	if not result.is_empty() and binding.get("second") is Dictionary and not _clean_part(binding.second).is_empty():
		result.second = _clean_part(binding.second)
	return result

static func _clean_part(part: Dictionary) -> Dictionary:
	if part.has("key"):
		return {"key": int(part.key)}
	if part.has("mouse"):
		return {"mouse": int(part.mouse)}
	return {}

# Première et deuxième touche d'une liaison ({} si absente).
static func first(binding: Dictionary) -> Dictionary:
	return _clean_part(binding)

static func second(binding: Dictionary) -> Dictionary:
	return _clean_part(binding.get("second", {}))

# "single", "double" (même touche deux fois), "together" (deux touches en même temps) ou "none".
static func kind(binding: Dictionary) -> String:
	if first(binding).is_empty():
		return "none"
	if second(binding).is_empty():
		return "single"
	return "double" if second(binding) == first(binding) else "together"

# Liaison faite d'une première touche et d'une deuxième facultative.
static func combine(first_part: Dictionary, second_part: Dictionary) -> Dictionary:
	var result := _clean_part(first_part)
	if not result.is_empty() and not second_part.is_empty():
		result.second = _clean_part(second_part)
	return result

# Même combinaison : « Maj + Z » vaut « Z + Maj ».
static func same(a: Dictionary, b: Dictionary) -> bool:
	if kind(a) != kind(b):
		return false
	if kind(a) == "together":
		return (first(a) == first(b) and second(a) == second(b)) or (first(a) == second(b) and second(a) == first(b))
	return first(a) == first(b)

# Actions dont la touche seule fait aussi partie de cette combinaison (ou l'inverse) :
# les deux se déclenchent ensemble. Noms des actions, pour avertir le joueur.
static func overlaps(bindings: Dictionary, action: String) -> Array:
	var result := []
	var binding: Dictionary = bindings.get(action, {})
	for other in ACTIONS:
		var other_binding: Dictionary = bindings.get(other, {})
		if other == action or kind(binding) == "none" or kind(other_binding) == "none":
			continue
		var mine := [first(binding), second(binding)]
		var theirs := [first(other_binding), second(other_binding)]
		if (kind(other_binding) == "single" and kind(binding) != "single" and mine.has(first(other_binding))) \
				or (kind(binding) == "single" and kind(other_binding) != "single" and theirs.has(first(binding))):
			result.append(ACTIONS[other].label)
	return result

# Code unique d'une touche ou d'un bouton, pour suivre les appuis.
static func part_id(part: Dictionary) -> String:
	return "key:%d" % part.key if part.has("key") else "mouse:%d" % part.get("mouse", 0)

# Liaison tirée d'un appui (touche ou bouton de souris) ; {} si l'appui ne convient pas.
static func from_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return {"key": code} if code != 0 and not code in RESERVED_KEYS else {}
	if event is InputEventMouseButton and MOUSE_NAMES.has(event.button_index):
		return {"mouse": event.button_index}
	return {}

# Nom complet : « Z », « Z deux fois » ou « Maj + Z ».
static func label(binding: Dictionary) -> String:
	match kind(binding):
		"double":
			return part_label(first(binding)) + " deux fois"
		"together":
			return part_label(first(binding)) + " + " + part_label(second(binding))
	return part_label(first(binding))

# Nom d'une touche : la lettre du clavier du joueur (Z sur AZERTY pour la place de W).
static func part_label(binding: Dictionary) -> String:
	if binding.has("mouse"):
		return MOUSE_NAMES.get(binding.mouse, "Souris")
	if binding.has("key"):
		var local: int = DisplayServer.keyboard_get_keycode_from_physical(binding.key) if DisplayServer.get_name() != "headless" else binding.key
		var name := OS.get_keycode_string(local if local != 0 else binding.key)
		# Flèches en symboles (0.0.4.3 : ↑ ↓ par défaut pour la vitesse).
		return {"Space": "Espace", "Up": "↑", "Down": "↓", "Left": "←", "Right": "→", "Backspace": "⌫"}.get(name, name)
	return "Aucune"

static func _event(binding: Dictionary) -> InputEvent:
	if binding.has("mouse"):
		var click := InputEventMouseButton.new()
		click.button_index = binding.mouse
		return click
	var key := InputEventKey.new()
	key.physical_keycode = binding.key
	return key

# Remplace les liaisons du jeu (InputMap) par celles choisies, flèches ← → toujours gardées.
# Une liaison à deux touches n'y figure pas : KeyCombos la déclenche (voir key_combos.gd).
static func apply(bindings: Dictionary) -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var binding: Dictionary = bindings.get(action, default_for(action))
		if kind(binding) == "single":
			InputMap.action_add_event(action, _event(first(binding)))
		for code in ACTIONS[action].fixed:
			InputMap.action_add_event(action, _event({"key": code}))

# Actions créées avec leurs touches par défaut si elles n'existent pas encore (scène seule).
static func ensure_defaults() -> void:
	# Une action déjà présente garde ses liaisons, même vide (« aucune touche » choisi).
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			# Défaut à deux touches : déclenché par KeyCombos, pas par l'InputMap.
			if kind(default_for(action)) == "single":
				InputMap.action_add_event(action, _event(default_for(action)))
			for code in ACTIONS[action].fixed:
				InputMap.action_add_event(action, _event({"key": code}))

# 0.0.4.6 : actions qui changent ou remettent une vitesse ; avec un clic, ce clic ne casse ni ne pose.
const SPEED_ACTIONS := ["speed_up", "speed_down", "walk_up", "walk_down", "run_up", "run_down", "break_up", "break_down", "place_up", "place_down", "walk_reset", "run_reset", "break_reset", "place_reset", "speed_reset_all"]

# Touches qui, tenues avec un clic, en font un réglage de vitesse (ex. ↑ et ⌫ par défaut).
static func click_modifiers(bindings: Dictionary) -> Array:
	var result := []
	for action in SPEED_ACTIONS:
		var binding: Dictionary = bindings.get(action, default_for(action))
		if kind(binding) != "together":
			continue
		for pair in [[first(binding), second(binding)], [second(binding), first(binding)]]:
			if pair[0].has("key") and pair[1].has("mouse") and not pair[0].key in result:
				result.append(pair[0].key)
	return result
