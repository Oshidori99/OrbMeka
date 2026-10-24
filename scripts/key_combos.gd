extends RefCounted
# Combinaisons de touches (0.0.3.27 ; 0.0.4.20 : plusieurs options par action, étapes « en même
# temps » et « après ») : suit les appuis et dit quand une action à combinaison commence ou s'arrête.
# Étape : toutes ses touches tenues en même temps, dans n'importe quel ordre. Étapes suivantes : à
# Controls.SEQUENCE_MS au plus de la précédente (double appui : la même touche deux fois). L'action
# dure tant que la dernière étape est tenue. Les options d'une seule touche passent par l'InputMap.
# feed() et release_all() renvoient des changements [action, appuyée] ; l'application en fait
# des InputEventAction, pour que le jeu les lise comme les autres touches.
const Controls = preload("res://scripts/controls.gd")

# Combinaisons suivies : {"action", "steps": [[id, …], …], "progress": étapes déjà faites, "at": temps}.
var entries: Array = []
var held: Dictionary = {}
# Actions en cours : {action: nombre de combinaisons actives}.
var active: Dictionary = {}
# Combinaisons actives (index dans entries).
var active_entries: Dictionary = {}

func set_bindings(bindings: Dictionary) -> Array:
	var changes := release_all()
	entries.clear()
	for action in bindings:
		for combo in Controls.options(bindings[action]):
			if Controls.combo_kind(combo) in ["chord", "sequence"]:
				entries.append({"action": action, "steps": combo.steps.map(func(chord): return chord.map(func(part): return Controls.part_id(part))), "progress": 0, "at": 0})
	return changes

# Appui ou relâchement d'une touche (ou d'un bouton) ; now_ms : temps de l'appui.
func feed(event: InputEvent, now_ms: int) -> Array:
	var id := _event_id(event)
	if id.is_empty() or (event is InputEventKey and event.echo):
		return []
	var changes := []
	if event.pressed:
		held[id] = true
		for index in range(entries.size()):
			if active_entries.has(index):
				continue
			var entry: Dictionary = entries[index]
			var steps: Array = entry.steps
			# Étape attendue : la suivante, si elle arrive à temps ; sinon on repart de la première.
			if entry.progress > 0 and now_ms - entry.at > Controls.SEQUENCE_MS:
				entry.progress = 0
			var expected: int = entry.progress
			if id in steps[expected] and _chord_held(steps[expected]):
				_advance(index, expected, now_ms, changes)
			elif expected > 0 and id in steps[0] and _chord_held(steps[0]):
				entry.progress = 0
				_advance(index, 0, now_ms, changes)
			elif expected > 0 and not id in steps[expected]:
				entry.progress = 0
	else:
		held.erase(id)
		for index in active_entries.keys():
			var entry: Dictionary = entries[index]
			if id in entry.steps[-1]:
				active_entries.erase(index)
				_set_active(entry.action, -1, changes)
	return changes

# Étape « step » faite par l'appui : passe à la suivante, ou active l'action après la dernière.
func _advance(index: int, step: int, now_ms: int, changes: Array) -> void:
	var entry: Dictionary = entries[index]
	if step + 1 >= entry.steps.size():
		entry.progress = 0
		active_entries[index] = true
		_set_active(entry.action, 1, changes)
	else:
		entry.progress = step + 1
		entry.at = now_ms

func _chord_held(chord: Array) -> bool:
	return chord.all(func(id): return held.has(id))

func _set_active(action: String, delta: int, changes: Array) -> void:
	var before: int = active.get(action, 0)
	var after := maxi(0, before + delta)
	if after == 0:
		active.erase(action)
	else:
		active[action] = after
	if before == 0 and after > 0:
		changes.append([action, true])
	elif before > 0 and after == 0:
		changes.append([action, false])

# Tout relâcher (pause, fenêtre quittée, nouvelles touches).
func release_all() -> Array:
	var changes := []
	for action in active:
		changes.append([action, false])
	active.clear()
	active_entries.clear()
	held.clear()
	for entry in entries:
		entry.progress = 0
	return changes

static func _event_id(event: InputEvent) -> String:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return Controls.part_id({"key": code}) if code != 0 else ""
	if event is InputEventMouseButton:
		return Controls.part_id({"mouse": event.button_index})
	return ""
