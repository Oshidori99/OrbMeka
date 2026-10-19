extends RefCounted
# Only identity, name and seed are stored. Never block edits or player state.
const MAX_NAME_LENGTH := 48
var worlds: Array[Dictionary] = []
var last_error := ""
var load_error := ""
var storage_path: String
var rng := RandomNumberGenerator.new()

func _init(path: String = "user://worlds.json") -> void:
	storage_path = path
	rng.randomize()
	_load_worlds()

func _load_worlds() -> void:
	if not FileAccess.file_exists(storage_path):
		return
	var file := FileAccess.open(storage_path, FileAccess.READ)
	if file == null:
		load_error = "La liste des mondes ne peut pas être lue."
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		load_error = "La liste des mondes est illisible ; le fichier est conservé."
		return
	var data: Variant = parser.data
	if not data is Dictionary or data.get("version") != 1 or not data.get("worlds") is Array:
		load_error = "La liste des mondes est illisible ; le fichier est conservé."
		return
	var loaded: Array[Dictionary] = []
	var ids: Array[String] = []
	var names: Array[String] = []
	for item in data.worlds:
		if not item is Dictionary or not item.get("id") is String or not item.get("name") is String:
			load_error = "La liste contient un monde invalide ; le fichier est conservé."
			return
		var seed_value: Variant = item.get("seed")
		if not (seed_value is int or seed_value is float):
			load_error = "Une graine est invalide ; le fichier est conservé."
			return
		var clean_name: String = item.name.strip_edges()
		if item.id.is_empty() or clean_name.is_empty() or clean_name.length() > MAX_NAME_LENGTH or ids.has(item.id) or names.has(clean_name.to_lower()) or float(seed_value) != float(int(seed_value)) or seed_value < 0 or seed_value > 4294967295:
			load_error = "La liste contient un monde invalide ; le fichier est conservé."
			return
		ids.append(item.id)
		names.append(clean_name.to_lower())
		loaded.append({"id": item.id, "name": clean_name, "seed": int(seed_value)})
	worlds = loaded

func _save_worlds() -> bool:
	var temporary := storage_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Impossible d'enregistrer la liste des mondes."
		return false
	file.store_string(JSON.stringify({"version": 1, "worlds": worlds}, "	"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "L'enregistrement de la liste a échoué."
		return false
	var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(storage_path))
	if result != OK:
		last_error = "Impossible de remplacer la liste des mondes."
		return false
	return true

func create_world(raw_name: String) -> Dictionary:
	last_error = ""
	if not load_error.is_empty():
		last_error = load_error
		return {}
	var world_name := raw_name.strip_edges()
	if world_name.is_empty():
		last_error = "Saisissez un nom pour ce monde."
		return {}
	if world_name.length() > MAX_NAME_LENGTH:
		last_error = "Le nom doit contenir au maximum 48 caractères."
		return {}
	for item in worlds:
		if item.name.nocasecmp_to(world_name) == 0:
			last_error = "Un monde porte déjà ce nom."
			return {}
	var terrain_seed: int = rng.randi()
	var used_ids := worlds.map(func(item: Dictionary): return item.id)
	while used_ids.has(str(terrain_seed)):
		terrain_seed = rng.randi()
	var item := {"id": str(terrain_seed), "name": world_name, "seed": terrain_seed}
	worlds.append(item)
	if not _save_worlds():
		worlds.pop_back()
		return {}
	return item.duplicate()

func find_world(id: String) -> Dictionary:
	for item in worlds:
		if item.id == id:
			return item.duplicate()
	return {}
func rename_world(id: String, raw_name: String) -> bool:
	last_error = ""
	if not load_error.is_empty():
		last_error = load_error
		return false
	var clean_name := raw_name.strip_edges()
	if clean_name.is_empty() or clean_name.length() > MAX_NAME_LENGTH:
		last_error = "Saisissez un nom de 1 à 48 caractères."
		return false
	for item in worlds:
		if item.id != id and item.name.nocasecmp_to(clean_name) == 0:
			last_error = "Un monde porte déjà ce nom."
			return false
	for index in range(worlds.size()):
		if worlds[index].id == id:
			var old_name: String = worlds[index].name
			worlds[index].name = clean_name
			if not _save_worlds():
				worlds[index].name = old_name
				return false
			return true
	last_error = "Ce monde n'existe plus."
	return false

func delete_world(id: String) -> bool:
	last_error = ""
	if not load_error.is_empty():
		last_error = load_error
		return false
	for index in range(worlds.size()):
		if worlds[index].id == id:
			var removed: Dictionary = worlds[index]
			worlds.remove_at(index)
			# Only rewrite this catalog; never derive a file path from a world name.
			if not _save_worlds():
				worlds.insert(index, removed)
				return false
			return true
	last_error = "Ce monde n'existe plus."
	return false