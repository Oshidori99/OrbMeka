extends RefCounted
# Only identity, name, seed and mode are stored. Never block edits or player state.
const MAX_NAME_LENGTH := 48
const MAX_SEED := 4294967295
# Mode du monde : « default » garde les attributs par défaut ; « developer » utilise les
# réglages globaux (Paramètres → Attributs). Passage default → developer seulement, définitif.
const MODE_DEFAULT := "default"
const MODE_DEVELOPER := "developer"
const MODE_NAMES := {MODE_DEFAULT: "Par défaut", MODE_DEVELOPER: "Mode développeur"}
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
		# Monde d'avant 0.0.3 (sans mode) : par défaut.
		var mode: Variant = item.get("mode", MODE_DEFAULT)
		if not MODE_NAMES.has(mode):
			load_error = "Le mode d'un monde est invalide ; le fichier est conservé."
			return
		var clean_name: String = item.name.strip_edges()
		if item.id.is_empty() or clean_name.is_empty() or clean_name.length() > MAX_NAME_LENGTH or ids.has(item.id) or names.has(clean_name.to_lower()) or float(seed_value) != float(int(seed_value)) or seed_value < 0 or seed_value > 4294967295:
			load_error = "La liste contient un monde invalide ; le fichier est conservé."
			return
		ids.append(item.id)
		names.append(clean_name.to_lower())
		loaded.append({"id": item.id, "name": clean_name, "seed": int(seed_value), "mode": mode})
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

func create_world(raw_name: String, raw_seed: String = "", mode: String = MODE_DEFAULT) -> Dictionary:
	last_error = ""
	if not MODE_NAMES.has(mode):
		last_error = "Mode de monde inconnu."
		return {}
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
	var seed_text := raw_seed.strip_edges()
	var terrain_seed: int = rng.randi()
	if not seed_text.is_empty():
		if not seed_text.is_valid_int() or seed_text.length() > 10:
			last_error = "La graine doit être un entier de 0 à %d." % MAX_SEED
			return {}
		terrain_seed = seed_text.to_int()
		if terrain_seed < 0 or terrain_seed > MAX_SEED:
			last_error = "La graine doit être un entier de 0 à %d." % MAX_SEED
			return {}
	# World identity is independent of seed: identical terrain can have multiple entries.
	var used_ids := worlds.map(func(item: Dictionary): return item.id)
	var world_id := str(rng.randi())
	while used_ids.has(world_id):
		world_id = str(rng.randi())
	var item := {"id": world_id, "name": world_name, "seed": terrain_seed, "mode": mode}
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

# Aucune fonction inverse : le retour au mode par défaut est impossible.
func enable_developer_mode(id: String) -> bool:
	last_error = ""
	if not load_error.is_empty():
		last_error = load_error
		return false
	for index in range(worlds.size()):
		if worlds[index].id == id:
			if worlds[index].get("mode", MODE_DEFAULT) == MODE_DEVELOPER:
				return true
			worlds[index]["mode"] = MODE_DEVELOPER
			if not _save_worlds():
				worlds[index]["mode"] = MODE_DEFAULT
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
func duplicate_world(id: String) -> Dictionary:
	var original := find_world(id)
	if original.is_empty():
		last_error = "Ce monde n'existe plus."
		return {}
	var number := 1
	while true:
		var suffix := " (copie)" if number == 1 else " (copie %d)" % number
		var copy_name: String = original.name.left(MAX_NAME_LENGTH - suffix.length()) + suffix
		var exists := false
		for item in worlds:
			if item.name.nocasecmp_to(copy_name) == 0:
				exists = true
				break
		if not exists:
			return create_world(copy_name, str(original.seed), original.get("mode", MODE_DEFAULT))
		number += 1
	return {}