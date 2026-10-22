extends RefCounted
# Deux touches par action (0.0.3.27) : suit les appuis et dit quand une action à deux
# touches commence ou s'arrête. Double appui : deux appuis de la même touche au plus à
# Controls.DOUBLE_PRESS_MS, l'action dure tant que le second appui est tenu.
# En même temps : l'action dure tant que les deux touches sont tenues, dans n'importe quel ordre.
# feed() et release_all() renvoient des changements [action, appuyée] ; l'application en fait
# des InputEventAction, pour que le jeu les lise comme les autres touches.
const Controls = preload("res://scripts/controls.gd")

var combos: Dictionary = {}
var held: Dictionary = {}
var last_press: Dictionary = {}
var active: Dictionary = {}

func set_bindings(bindings: Dictionary) -> Array:
	var changes := release_all()
	combos.clear()
	for action in bindings:
		var binding: Dictionary = bindings[action]
		if Controls.kind(binding) in ["double", "together"]:
			combos[action] = {"kind": Controls.kind(binding), "first": Controls.part_id(Controls.first(binding)), "second": Controls.part_id(Controls.second(binding))}
	return changes

# Appui ou relâchement d'une touche (ou d'un bouton) ; now_ms : temps de l'appui.
func feed(event: InputEvent, now_ms: int) -> Array:
	var id := _event_id(event)
	if id.is_empty() or (event is InputEventKey and event.echo):
		return []
	var changes := []
	if event.pressed:
		held[id] = true
		var double_press: bool = last_press.has(id) and now_ms - last_press[id] <= Controls.DOUBLE_PRESS_MS
		last_press[id] = now_ms
		for action in combos:
			var combo: Dictionary = combos[action]
			if active.has(action) or not id in [combo.first, combo.second]:
				continue
			var other: String = combo.second if id == combo.first else combo.first
			if (combo.kind == "double" and double_press) or (combo.kind == "together" and held.has(other)):
				active[action] = true
				changes.append([action, true])
		if double_press:
			last_press.erase(id)
	else:
		held.erase(id)
		for action in combos:
			if active.has(action) and id in [combos[action].first, combos[action].second]:
				active.erase(action)
				changes.append([action, false])
	return changes

# Tout relâcher (pause, fenêtre quittée, nouvelles touches).
func release_all() -> Array:
	var changes := []
	for action in active:
		changes.append([action, false])
	active.clear()
	held.clear()
	last_press.clear()
	return changes

static func _event_id(event: InputEvent) -> String:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return Controls.part_id({"key": code}) if code != 0 else ""
	if event is InputEventMouseButton:
		return Controls.part_id({"mouse": event.button_index})
	return ""
