extends RefCounted
# Contrôles modifiables (0.0.3.12). Les flèches ← → restent toujours actives pour aller de côté.
# 0.0.4.20 : chaque action a jusqu'à MAX_OPTIONS options (Avancer, Avancer (2)…), chacune une
# combinaison : {"options": [{"steps": [[touche, touche], [touche]]}]} : les touches d'une étape
# s'appuient en même temps, les étapes l'une après l'autre (SEQUENCE_MS au plus entre deux),
# MAX_KEYS touches au plus. Une touche : {"key": code physique} ou {"mouse": bouton} ; {} = pas
# encore choisie. Les défauts ci-dessous gardent l'ancienne écriture (une touche, ou « second » :
# la même = deux fois de suite, une autre = en même temps), convertie par normalize(), comme les
# anciens controles.json (0.0.3.12 à 0.0.4.19).
# Touches gardées pour le jeu, jamais attribuables : Échap (pause, « aucune » pendant
# le choix d'une touche), F1, F2, F3 (raccourcis des menus), F4 (vue, 0.0.4.9).

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
	# 0.0.4.7 : tout le déplacement avec ↑ / ↓ + A (avant : la flèche seule) ; ⌫ + A le remet par défaut.
	# Une touche de déplacement tenue avec ↑, ↓ ou ⌫ ne fait pas bouger (A ne va pas à gauche).
	"speed_up": {"label": "Tout plus vite", "default": {"key": KEY_UP, "second": {"key": KEY_A}}, "fixed": []},
	"speed_down": {"label": "Tout moins vite", "default": {"key": KEY_DOWN, "second": {"key": KEY_A}}, "fixed": []},
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
	"move_reset": {"label": "Déplacement par défaut", "default": {"key": KEY_BACKSPACE, "second": {"key": KEY_A}}, "fixed": []},
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

const RESERVED_KEYS :=[KEY_ESCAPE, KEY_F1, KEY_F2, KEY_F3, KEY_F4]
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "Clic gauche", MOUSE_BUTTON_RIGHT: "Clic droit", MOUSE_BUTTON_MIDDLE: "Clic molette", MOUSE_BUTTON_XBUTTON1: "Bouton souris 4", MOUSE_BUTTON_XBUTTON2: "Bouton souris 5", MOUSE_BUTTON_WHEEL_UP: "Molette haut", MOUSE_BUTTON_WHEEL_DOWN: "Molette bas"}

static func defaults() -> Dictionary:
	var result := {}
	for action in ACTIONS:
		result[action] = default_for(action)
	return result

# Liaison par défaut d'une action ; « by_letter » : la touche qui porte cette lettre
# sur le clavier du joueur, quelle que soit sa disposition.
static func default_for(action: String) -> Dictionary:
	var binding := normalize(ACTIONS[action].default)
	if ACTIONS[action].get("by_letter", false):
		for combo in binding.options:
			for chord in combo.steps:
				for part in chord:
					if part.has("key"):
						part.key = physical_for_letter(part.key)
	return binding

static func physical_for_letter(letter: int) -> int:
	if DisplayServer.get_name() == "headless":
		return letter
	for code in range(KEY_A, KEY_Z + 1):
		if DisplayServer.keyboard_get_keycode_from_physical(code) == letter:
			return code
	return letter

# 0.0.4.20 : limites et délai entre deux étapes (« appuyer après », double appui compris).
const MAX_KEYS := 4
const MAX_OPTIONS := 3
const SEQUENCE_MS := 500

# --- Format ---

# Liaison au format actuel, depuis n'importe quelle écriture (actuelle ou d'avant 0.0.4.20).
static func normalize(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {"options": []}
	if raw.has("options"):
		var all := []
		if raw.options is Array:
			for combo in raw.options:
				if combo is Dictionary and combo.get("steps") is Array:
					var steps := []
					for chord in combo.steps:
						if chord is Array and not chord.is_empty():
							steps.append(chord.map(func(part): return _clean_part(part) if part is Dictionary else {}))
					all.append({"steps": steps})
		return {"options": all}
	var first_part := _clean_part(raw)
	if first_part.is_empty():
		return {"options": []}
	var second_part: Dictionary = _clean_part(raw.second) if raw.get("second") is Dictionary else {}
	if second_part.is_empty():
		return single(first_part)
	if second_part == first_part:
		return {"options": [{"steps": [[first_part], [first_part.duplicate()]]}]}
	return {"options": [{"steps": [[first_part, second_part]]}]}

static func single(part: Dictionary) -> Dictionary:
	var clean_part := _clean_part(part)
	return {"options": [{"steps": [[clean_part]]}]} if not clean_part.is_empty() else {"options": []}

static func clean(raw: Variant) -> Dictionary:
	return normalize(raw)

# Liaison valide : ancienne écriture, ou options (MAX_OPTIONS au plus) dont chaque combinaison a des
# étapes non vides, des touches connues et non réservées (ou pas encore choisies), MAX_KEYS au plus.
static func is_valid(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	if not raw.has("options"):
		if raw.is_empty():
			return true
		if raw.has("second"):
			var rest: Dictionary = raw.duplicate()
			rest.erase("second")
			return _is_valid_part(rest) and _is_valid_part(raw.second)
		return _is_valid_part(raw)
	if not raw.options is Array or raw.options.size() > MAX_OPTIONS:
		return false
	for combo in raw.options:
		if not combo is Dictionary or not combo.get("steps") is Array:
			return false
		var count := 0
		for chord in combo.steps:
			if not chord is Array or chord.is_empty():
				return false
			for part in chord:
				if not (part is Dictionary and (part.is_empty() or _is_valid_part(part))):
					return false
				count += 1
		if count > MAX_KEYS:
			return false
	return true

static func _is_valid_part(part: Variant) -> bool:
	if not part is Dictionary or part.size() != 1:
		return false
	if part.has("key"):
		return (part.key is int or part.key is float) and int(part.key) > 0 and not int(part.key) in RESERVED_KEYS
	if part.has("mouse"):
		return (part.mouse is int or part.mouse is float) and MOUSE_NAMES.has(int(part.mouse))
	return false

static func _clean_part(part: Dictionary) -> Dictionary:
	if part.has("key"):
		return {"key": int(part.key)}
	if part.has("mouse"):
		return {"mouse": int(part.mouse)}
	return {}

# --- Lecture ---

static func options(binding: Dictionary) -> Array:
	return normalize(binding).options

static func combo_parts(combo: Dictionary) -> Array:
	var parts := []
	for chord in combo.get("steps", []):
		parts.append_array(chord)
	return parts

# Toutes les touches choisies (une pas encore choisie ne compte pas).
static func complete(combo: Dictionary) -> bool:
	var parts := combo_parts(combo)
	return not parts.is_empty() and parts.all(func(part): return not part.is_empty())

# "none" (rien de choisi), "single" (une touche), "chord" (en même temps), "sequence" (après).
static func combo_kind(combo: Dictionary) -> String:
	if not complete(combo):
		return "none"
	var steps: Array = combo.steps
	if steps.size() > 1:
		return "sequence"
	return "single" if steps[0].size() == 1 else "chord"

# Première option : "none", "single", "double" (une touche deux fois), "together" (en même temps) ou
# "sequence" (autres suites), comme avant 0.0.4.20.
static func kind(binding: Dictionary) -> String:
	var all := options(binding)
	if all.is_empty():
		return "none"
	var combo: Dictionary = all[0]
	match combo_kind(combo):
		"single":
			return "single"
		"chord":
			return "together"
		"sequence":
			var steps: Array = combo.steps
			return "double" if steps.size() == 2 and steps[0].size() == 1 and steps[0] == steps[1] else "sequence"
	return "none"

# Première touche de la première option ({} si aucune).
static func first(binding: Dictionary) -> Dictionary:
	var all := options(binding)
	if all.is_empty() or combo_parts(all[0]).is_empty():
		return {}
	return combo_parts(all[0])[0]

# Touches seules (une option d'une seule touche) de la liaison.
static func singles(binding: Dictionary) -> Array:
	return options(binding).filter(func(combo): return combo_kind(combo) == "single").map(func(combo): return combo.steps[0][0])

# Même combinaison : l'ordre des touches d'une même étape ne compte pas (« Maj + Z » = « Z + Maj »).
static func same_combo(a: Dictionary, b: Dictionary) -> bool:
	if not complete(a) or not complete(b) or a.steps.size() != b.steps.size():
		return false
	for index in range(a.steps.size()):
		var left: Array = a.steps[index].map(func(part): return part_id(part))
		var right: Array = b.steps[index].map(func(part): return part_id(part))
		left.sort()
		right.sort()
		if left != right:
			return false
	return true

# Une option de l'une est aussi une option de l'autre.
static func same(a: Dictionary, b: Dictionary) -> bool:
	for left in options(a):
		for right in options(b):
			if same_combo(left, right):
				return true
	return false

# --- Noms ---

# « Z », « Maj + Z », « Espace → Espace », « ↑ + A → X » ; « Aucune » si rien n'est choisi.
static func combo_label(combo: Dictionary) -> String:
	var steps: Array = combo.get("steps", [])
	if steps.is_empty():
		return "Aucune"
	return " → ".join(steps.map(func(chord): return " + ".join(chord.map(func(part): return part_label(part)))))

static func label(binding: Dictionary) -> String:
	var all := options(binding)
	return "Aucune" if all.is_empty() else " / ".join(all.map(func(combo): return combo_label(combo)))

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

# Code unique d'une touche ou d'un bouton, pour suivre les appuis.
static func part_id(part: Dictionary) -> String:
	return "key:%d" % part.key if part.has("key") else "mouse:%d" % part.get("mouse", 0)

# Touche tirée d'un appui (touche ou bouton de souris) ; {} si l'appui ne convient pas.
static func from_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return {"key": code} if code != 0 and not code in RESERVED_KEYS else {}
	if event is InputEventMouseButton and MOUSE_NAMES.has(event.button_index):
		return {"mouse": event.button_index}
	return {}

# --- Recherche par touche (0.0.4.20) ---

# Texte cherché → étapes de noms de touches : « , » « - » « → » séparent les étapes (après), espace
# ou « + » les touches d'une même étape (en même temps) ; parenthèses ignorées ; minuscules.
# Les noms en plusieurs mots (« Clic gauche ») restent entiers.
static func parse_key_query(text: String) -> Array:
	var query := text.to_lower().replace("(", " ").replace(")", " ")
	var names := MOUSE_NAMES.values().map(func(name): return str(name).to_lower())
	for index in range(names.size()):
		query = query.replace(names[index], "§%d§" % index)
	var steps := []
	for raw_step in query.replace("→", ",").replace("-", ",").split(",", false):
		var tokens := []
		for token in raw_step.replace("+", " ").split(" ", false):
			if token.begins_with("§") and token.ends_with("§"):
				tokens.append(names[int(token.trim_prefix("§").trim_suffix("§"))])
			else:
				tokens.append(token)
		if not tokens.is_empty():
			steps.append(tokens)
	return steps

# La combinaison correspond-elle au texte ? Une seule touche cherchée : toute combinaison qui la
# contient ; sinon, même nombre d'étapes et chaque touche cherchée dans l'étape correspondante.
static func combo_matches_keys(combo: Dictionary, query_steps: Array) -> bool:
	if query_steps.is_empty() or not complete(combo):
		return false
	var steps: Array = combo.steps.map(func(chord): return chord.map(func(part): return part_label(part).to_lower()))
	if query_steps.size() == 1 and query_steps[0].size() == 1:
		return steps.any(func(chord): return query_steps[0][0] in chord)
	if query_steps.size() != steps.size():
		return false
	for index in range(steps.size()):
		for token in query_steps[index]:
			if not token in steps[index]:
				return false
	return true

# --- Chevauchements et conflits ---

# Actions dont une touche seule fait aussi partie d'une combinaison de l'autre : les deux se
# déclenchent ensemble. Noms des actions, pour avertir le joueur.
static func overlaps(bindings: Dictionary, action: String) -> Array:
	var result := []
	var mine: Dictionary = bindings.get(action, {"options": []})
	for other in ACTIONS:
		if other == action:
			continue
		var theirs: Dictionary = bindings.get(other, {"options": []})
		if not _overlap(mine, theirs).is_empty() or not _overlap(theirs, mine).is_empty():
			result.append(ACTIONS[other].label)
	return result

# Combinaisons de « wide » qui contiennent une touche seule de « narrow ».
static func _overlap(narrow: Dictionary, wide: Dictionary) -> Array:
	var found := []
	var lone := singles(narrow)
	for combo in options(wide):
		if combo_kind(combo) in ["chord", "sequence"] and combo_parts(combo).any(func(part): return part in lone):
			found.append(combo)
	return found

# Conflits (bouton Conflits, 0.0.4.20) : la même combinaison pour deux actions, ou une touche seule
# d'une action dans la combinaison d'une autre, sauf quand le jeu l'évite déjà (A ou W tenus avec
# ↑ ↓ ⌫ ne font pas bouger, un clic avec ↑ ↓ ⌫ ne casse ni ne pose). [{"actions": [a, b], "text"}].
static func conflicts(bindings: Dictionary) -> Array:
	var result := []
	var names: Array = ACTIONS.keys()
	var blocked := blocked_moves(bindings)
	var clicks := click_modifiers(bindings)
	for i in range(names.size()):
		for j in range(names.size()):
			if i == j:
				continue
			var a: String = names[i]
			var b: String = names[j]
			var binding_a: Dictionary = bindings.get(a, {"options": []})
			var binding_b: Dictionary = bindings.get(b, {"options": []})
			if i < j:
				for left in options(binding_a):
					for right in options(binding_b):
						if same_combo(left, right):
							result.append({"actions": [a, b], "text": "%s et %s : même touche (%s)" % [ACTIONS[a].label, ACTIONS[b].label, combo_label(left)]})
			var lone := singles(binding_a)
			for combo in _overlap(binding_a, binding_b):
				var others: Array = combo_parts(combo).filter(func(part): return not part in lone)
				var handled := false
				if blocked.has(a) and others.any(func(part): return part.has("key") and part.key in blocked[a]):
					handled = true
				if a in ["break_block", "place_block"] and others.any(func(part): return part.has("key") and part.key in clicks):
					handled = true
				if not handled:
					result.append({"actions": [a, b], "text": "%s (%s) déclenche aussi %s" % [combo_label(combo), ACTIONS[b].label, ACTIONS[a].label]})
	return result

# --- Jeu ---

static func _event(binding: Dictionary) -> InputEvent:
	if binding.has("mouse"):
		var click := InputEventMouseButton.new()
		click.button_index = binding.mouse
		return click
	var key := InputEventKey.new()
	key.physical_keycode = binding.key
	return key

# Remplace les liaisons du jeu (InputMap) par celles choisies, flèches ← → toujours gardées.
# Les options d'une seule touche y figurent ; les autres, KeyCombos les déclenche (key_combos.gd).
static func apply(bindings: Dictionary) -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for part in singles(bindings.get(action, default_for(action))):
			InputMap.action_add_event(action, _event(part))
		for code in ACTIONS[action].fixed:
			InputMap.action_add_event(action, _event({"key": code}))

# Actions créées avec leurs touches par défaut si elles n'existent pas encore (scène seule).
static func ensure_defaults() -> void:
	# Une action déjà présente garde ses liaisons, même vide (« aucune touche » choisi).
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for part in singles(default_for(action)):
				InputMap.action_add_event(action, _event(part))
			for code in ACTIONS[action].fixed:
				InputMap.action_add_event(action, _event({"key": code}))

# 0.0.4.6 : actions qui changent ou remettent une vitesse ; avec un clic, ce clic ne casse ni ne pose.
const SPEED_ACTIONS := ["speed_up", "speed_down", "move_reset", "walk_up", "walk_down", "run_up", "run_down", "break_up", "break_down", "place_up", "place_down", "walk_reset", "run_reset", "break_reset", "place_reset", "speed_reset_all"]

# Étapes « en même temps » des réglages de vitesse.
static func _speed_chords(bindings: Dictionary) -> Array:
	var chords := []
	for action in SPEED_ACTIONS:
		for combo in options(bindings.get(action, default_for(action))):
			if complete(combo):
				for chord in combo.steps:
					if chord.size() > 1:
						chords.append(chord)
	return chords

# Touches qui, tenues avec un clic, en font un réglage de vitesse (ex. ↑ et ⌫ par défaut).
static func click_modifiers(bindings: Dictionary) -> Array:
	var result := []
	for chord in _speed_chords(bindings):
		if chord.any(func(part): return part.has("mouse")):
			for part in chord:
				if part.has("key") and not part.key in result:
					result.append(part.key)
	return result

# 0.0.4.7 : déplacements à ne pas faire pendant un réglage de vitesse : {action de déplacement:
# touches qui, tenues, la bloquent} (ex. A avec ↑ : réglage, pas un pas à gauche).
static func blocked_moves(bindings: Dictionary) -> Dictionary:
	var result := {}
	for move in ["move_forward", "move_back", "move_left", "move_right"]:
		var own := singles(bindings.get(move, default_for(move)))
		if own.is_empty():
			continue
		for chord in _speed_chords(bindings):
			if not chord.any(func(part): return part in own):
				continue
			for part in chord:
				if part.has("key") and not part in own:
					if not result.has(move):
						result[move] = []
					if not part.key in result[move]:
						result[move].append(part.key)
	return result

# Défauts de 0.0.4.3 à 0.0.4.6 (↑, ↓ seules) remplacés : un ancien controles.json les relit comme le nouveau défaut.
const FORMER_DEFAULTS := {"speed_up": {"key": KEY_UP}, "speed_down": {"key": KEY_DOWN}}

# 0.0.4.8 : parties du menu Contrôles, dans l'ordre d'affichage ; chaque action dans une seule.
# 0.0.4.20 : les remises par défaut (⌫) dans leur propre partie.
const GROUPS := {
	"Mouvements": ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "sprint", "fly"],
	"Blocs": ["break_block", "place_block", "block_previous", "block_next"],
	"Vitesses": ["speed_up", "speed_down", "walk_up", "walk_down", "run_up", "run_down", "break_up", "break_down", "place_up", "place_down"],
	"Vitesses — réinitialiser": ["move_reset", "walk_reset", "run_reset", "break_reset", "place_reset", "speed_reset_all"],
}
# Dernière partie, Menus : touches réservées, montrées sans pouvoir les changer.
const MENU_KEYS := [["Pause", "Échap"], ["Retour aux mondes", "F1"], ["Comment jouer", "F2"], ["Informations du monde", "F3"], ["Changer de vue", "F4"]]

# 0.0.4.20 : recherche par texte (partie ou nom) : un morceau du nom, ou les premières lettres des mots
# (« tpv » : Tout plus vite), ou le début de plusieurs mots dans l'ordre (« mar pl » : Marche plus vite).
# Sans majuscules ni accents.
static func plain(text: String) -> String:
	var result := text.to_lower()
	for pair in [["é", "e"], ["è", "e"], ["ê", "e"], ["à", "a"], ["â", "a"], ["ç", "c"], ["ô", "o"], ["û", "u"], ["î", "i"], ["—", " "], ["-", " "], ["(", " "], [")", " "]]:
		result = result.replace(pair[0], pair[1])
	return result.strip_edges()

static func text_matches(label: String, query: String) -> bool:
	var wanted := plain(query)
	if wanted.is_empty():
		return true
	var name := plain(label)
	if name.contains(wanted):
		return true
	var words: Array = Array(name.split(" ", false))
	var initials := "".join(words.map(func(word): return word.left(1)))
	if not wanted.contains(" ") and initials.contains(wanted):
		return true
	# Début de plusieurs mots, dans l'ordre.
	var pieces: Array = Array(wanted.split(" ", false))
	var at := 0
	for piece in pieces:
		while at < words.size() and not words[at].begins_with(piece):
			at += 1
		if at >= words.size():
			return false
		at += 1
	return true
