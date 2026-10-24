extends RefCounted
# Index des mondes (worlds.json, gardé tel quel : identifiant, nom, graine, mode). 0.0.5 : chaque monde a
# aussi son dossier (world_store.gd), avec monde.json, joueur.json et zones/ ; créé ici, copié, supprimé.
const Store = preload("res://scripts/world_store.gd")
const MAX_NAME_LENGTH := 48
const MAX_SEED := 4294967295
# Mode du monde : « default » garde les attributs par défaut ; « developer » utilise les
# réglages globaux (Paramètres → Attributs). 0.0.4.10 : retour au mode par défaut possible ; « developer_used »
# (mode développeur utilisé au moins une fois) reste alors vrai, définitivement (Informations du monde).
const MODE_DEFAULT := "default"
const MODE_DEVELOPER := "developer"
const MODE_NAMES := {MODE_DEFAULT: "Par défaut", MODE_DEVELOPER: "Mode développeur"}
var worlds: Array[Dictionary] = []
var last_error := ""
var load_error := ""
var storage_path: String
# Dossier des mondes : user://mondes ; à côté de l'index pour les tests (ex. « …-test-mondes »).
var worlds_root: String
# Message de réparation (monde.json illisible mis de côté et recréé), affiché dans Mes mondes.
var repair_note := ""
var rng := RandomNumberGenerator.new()

func _init(path: String = "user://worlds.json") -> void:
	storage_path = path
	worlds_root = Store.ROOT if path == "user://worlds.json" else path.get_basename() + "-mondes"
	rng.randomize()
	_load_worlds()
	if load_error.is_empty():
		_migrate_folders()

func world_folder(id: String) -> String:
	return Store.folder(worlds_root, id) if Store.valid_id(id) else ""

# Migration (0.0.5) : un monde sans dossier reçoit son monde.json, sans rien perdre de l'index.
func _migrate_folders() -> void:
	for item in worlds:
		if not Store.valid_id(item.id):
			continue
		var result := Store.read_json(world_folder(item.id).path_join(Store.BASE_FILE), Store.valid_base)
		if result.has("error"):
			repair_note = "« %s » : %s ; recréé depuis la liste des mondes." % [item.name, result.error]
		elif result.has("data"):
			item["created"] = str(result.data.get("creation", ""))
			continue
		if str(item.get("created", "")).is_empty():
			item["created"] = Time.get_datetime_string_from_system()
		_write_base(item)

func _write_base(item: Dictionary) -> bool:
	return Store.valid_id(item.id) and Store.write_json(world_folder(item.id).path_join(Store.BASE_FILE), Store.base_data(item))

func _write_base_for(id: String) -> void:
	for item in worlds:
		if item.id == id:
			_write_base(item)

func world_size(id: String) -> int:
	var path := world_folder(id)
	return 0 if path.is_empty() else Store.folder_size(path)

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
		# Avant 0.0.4.10 (sans developer_used) : utilisé si le monde est en mode développeur.
		var used: bool = item.get("developer_used", mode == MODE_DEVELOPER) == true or mode == MODE_DEVELOPER
		loaded.append({"id": item.id, "name": clean_name, "seed": int(seed_value), "mode": mode, "developer_used": used, "created": str(item.get("created", ""))})
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

func create_world(raw_name: String, raw_seed: String = "", mode: String = MODE_DEFAULT, developer_used: bool = false) -> Dictionary:
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
	var item := {"id": world_id, "name": world_name, "seed": terrain_seed, "mode": mode, "developer_used": developer_used or mode == MODE_DEVELOPER, "created": Time.get_datetime_string_from_system()}
	# Un reste de dossier au même identifiant (essai interrompu) ne doit rien apporter au nouveau monde.
	Store.delete_folder(world_folder(world_id))
	if not _write_base(item):
		last_error = "Impossible de créer le dossier du monde."
		return {}
	worlds.append(item)
	if not _save_worlds():
		worlds.pop_back()
		Store.delete_folder(world_folder(world_id))
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
			_write_base_for(id)
			return true
	last_error = "Ce monde n'existe plus."
	return false

# Mode développeur ; la mention « utilisé au moins une fois » est définitive.
func enable_developer_mode(id: String) -> bool:
	last_error = ""
	if not load_error.is_empty():
		last_error = load_error
		return false
	for index in range(worlds.size()):
		if worlds[index].id == id:
			if worlds[index].get("mode", MODE_DEFAULT) == MODE_DEVELOPER:
				return true
			var before: Dictionary = worlds[index].duplicate()
			worlds[index]["mode"] = MODE_DEVELOPER
			worlds[index]["developer_used"] = true
			if not _save_worlds():
				worlds[index] = before
				return false
			_write_base_for(id)
			return true
	last_error = "Ce monde n'existe plus."
	return false

# 0.0.4.10 : retour au mode par défaut ; developer_used reste vrai.
func disable_developer_mode(id: String) -> bool:
	last_error = ""
	if not load_error.is_empty():
		last_error = load_error
		return false
	for index in range(worlds.size()):
		if worlds[index].id == id:
			if worlds[index].get("mode", MODE_DEFAULT) == MODE_DEFAULT:
				return true
			worlds[index]["mode"] = MODE_DEFAULT
			if not _save_worlds():
				worlds[index]["mode"] = MODE_DEVELOPER
				return false
			_write_base_for(id)
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
			# 0.0.5 : dossier du monde supprimé (chemin tiré de l'identifiant, jamais du nom).
			Store.delete_folder(world_folder(id))
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
			var copy := create_world(copy_name, str(original.seed), original.get("mode", MODE_DEFAULT), original.get("developer_used", false))
			# 0.0.5 : la copie reprend aussi constructions et position (son monde.json reste le sien).
			if not copy.is_empty():
				var from := world_folder(id)
				var to := world_folder(copy.id)
				if DirAccess.dir_exists_absolute(from.path_join(Store.ZONES_DIR)):
					Store.copy_folder(from.path_join(Store.ZONES_DIR), to.path_join(Store.ZONES_DIR))
				if FileAccess.file_exists(from.path_join(Store.PLAYER_FILE)):
					DirAccess.copy_absolute(ProjectSettings.globalize_path(from.path_join(Store.PLAYER_FILE)), ProjectSettings.globalize_path(to.path_join(Store.PLAYER_FILE)))
			return copy
		number += 1
	return {}