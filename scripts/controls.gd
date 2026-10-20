extends RefCounted
# Contrôles modifiables (0.0.3.12) : une touche ou un bouton de souris par action, ou aucun.
# Les flèches restent toujours actives pour marcher, en plus de la touche choisie.
# Une liaison : {"key": code physique} ou {"mouse": bouton} ; {} = aucune touche.
# Touches gardées pour le jeu, jamais attribuables : Échap (pause, « aucune » pendant
# le choix d'une touche), F1, F2, F3 (raccourcis des menus).

const ACTIONS := {
	"move_forward": {"label": "Avancer", "default": {"key": KEY_W}, "fixed": [KEY_UP]},
	"move_back": {"label": "Reculer", "default": {"key": KEY_S}, "fixed": [KEY_DOWN]},
	"move_left": {"label": "Aller à gauche", "default": {"key": KEY_A}, "fixed": [KEY_LEFT]},
	"move_right": {"label": "Aller à droite", "default": {"key": KEY_D}, "fixed": [KEY_RIGHT]},
	"jump": {"label": "Sauter", "default": {"key": KEY_SPACE}, "fixed": []},
	# 0.0.3.15 : maintenir pour se baisser (plus lent, chute plus lourde).
	"crouch": {"label": "Se baisser", "default": {"key": KEY_Y}, "fixed": []},
	"break_block": {"label": "Casser", "default": {"mouse": MOUSE_BUTTON_LEFT}, "fixed": []},
	"place_block": {"label": "Poser", "default": {"mouse": MOUSE_BUTTON_RIGHT}, "fixed": []},
	"block_previous": {"label": "Bloc précédent", "default": {"mouse": MOUSE_BUTTON_WHEEL_UP}, "fixed": []},
	"block_next": {"label": "Bloc suivant", "default": {"mouse": MOUSE_BUTTON_WHEEL_DOWN}, "fixed": []},
}
const RESERVED_KEYS := [KEY_ESCAPE, KEY_F1, KEY_F2, KEY_F3]
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "Clic gauche", MOUSE_BUTTON_RIGHT: "Clic droit", MOUSE_BUTTON_MIDDLE: "Clic molette", MOUSE_BUTTON_XBUTTON1: "Bouton souris 4", MOUSE_BUTTON_XBUTTON2: "Bouton souris 5", MOUSE_BUTTON_WHEEL_UP: "Molette haut", MOUSE_BUTTON_WHEEL_DOWN: "Molette bas"}

static func defaults() -> Dictionary:
	var result := {}
	for action in ACTIONS:
		result[action] = ACTIONS[action].default.duplicate()
	return result

# Liaison valide : vide, touche non réservée, ou bouton de souris connu (molette comprise).
static func is_valid(binding: Variant) -> bool:
	if not binding is Dictionary:
		return false
	if binding.is_empty():
		return true
	if binding.size() != 1:
		return false
	if binding.has("key"):
		return (binding.key is int or binding.key is float) and int(binding.key) > 0 and not int(binding.key) in RESERVED_KEYS
	if binding.has("mouse"):
		return (binding.mouse is int or binding.mouse is float) and MOUSE_NAMES.has(int(binding.mouse))
	return false

static func clean(binding: Dictionary) -> Dictionary:
	if binding.has("key"):
		return {"key": int(binding.key)}
	if binding.has("mouse"):
		return {"mouse": int(binding.mouse)}
	return {}

# Liaison tirée d'un appui (touche ou bouton de souris) ; {} si l'appui ne convient pas.
static func from_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return {"key": code} if code != 0 and not code in RESERVED_KEYS else {}
	if event is InputEventMouseButton and MOUSE_NAMES.has(event.button_index):
		return {"mouse": event.button_index}
	return {}

# Nom affiché : la lettre du clavier du joueur (Z sur AZERTY pour la place de W).
static func label(binding: Dictionary) -> String:
	if binding.has("mouse"):
		return MOUSE_NAMES.get(binding.mouse, "Souris")
	if binding.has("key"):
		var local: int = DisplayServer.keyboard_get_keycode_from_physical(binding.key) if DisplayServer.get_name() != "headless" else binding.key
		var name := OS.get_keycode_string(local if local != 0 else binding.key)
		return "Espace" if name == "Space" else name
	return "Aucune"

static func _event(binding: Dictionary) -> InputEvent:
	if binding.has("mouse"):
		var click := InputEventMouseButton.new()
		click.button_index = binding.mouse
		return click
	var key := InputEventKey.new()
	key.physical_keycode = binding.key
	return key

# Remplace les liaisons du jeu (InputMap) par celles choisies, flèches toujours gardées.
static func apply(bindings: Dictionary) -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var binding: Dictionary = bindings.get(action, ACTIONS[action].default)
		if not binding.is_empty():
			InputMap.action_add_event(action, _event(binding))
		for code in ACTIONS[action].fixed:
			InputMap.action_add_event(action, _event({"key": code}))

# Actions créées avec leurs touches par défaut si elles n'existent pas encore (scène seule).
static func ensure_defaults() -> void:
	# Une action déjà présente garde ses liaisons, même vide (« aucune touche » choisi).
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			InputMap.action_add_event(action, _event(ACTIONS[action].default))
			for code in ACTIONS[action].fixed:
				InputMap.action_add_event(action, _event({"key": code}))
