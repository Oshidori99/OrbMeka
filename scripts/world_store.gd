extends RefCounted
# 0.0.5 : un dossier par monde (user://mondes/<identifiant>/) :
#   monde.json            nom, graine, mode, date de création, version du format
#   joueur.json           position et regard
#   zones/modifications.json  blocs posés et cassés par rapport au terrain recalculé avec la graine
# Écriture sûre (fichier temporaire, puis remplacement). Un fichier illisible n'est jamais écrasé :
# il est renommé « <nom>.illisible-<date> » et gardé dans le dossier.
# Étapes suivantes du Monde : zones de 8 m (format 2), terrain lisse par densité (format 3).
const ROOT := "user://mondes"
const BASE_FILE := "monde.json"
const PLAYER_FILE := "joueur.json"
# 0.0.5.18 : objets posés dans le monde (rochers pour l'instant ; monde d'essai TestTailleRocher).
const OBJECTS_FILE := "objets.json"
const ZONES_DIR := "zones"
const CHANGES_FILE := "zones/modifications.json"
const FORMAT := 1
const CHANGES_FORMAT := 1

# Identifiants : chiffres seulement (jamais de chemin tiré d'un nom de monde).
static func valid_id(id: String) -> bool:
	return not id.is_empty() and id.is_valid_int() and not id.begins_with("-")

static func folder(root: String, id: String) -> String:
	return root.path_join(id)

static func write_json(path: String, data: Variant) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "	"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK

# Résultat : {"data": …} si lisible, {"missing": true} si absent, {"error": message} si illisible
# (le fichier est alors mis de côté, jamais supprimé).
static func read_json(path: String, check: Callable) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"missing": true}
	var file := FileAccess.open(path, FileAccess.READ)
	var data: Variant = null
	if file != null:
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) == OK:
			data = parser.data
		file.close()
	if data is Dictionary and check.call(data):
		return {"data": data}
	var kept := path + ".illisible-" + Time.get_datetime_string_from_system().replace(":", "-")
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(kept))
	return {"error": "Fichier illisible mis de côté : %s" % kept.get_file()}

static func base_data(item: Dictionary) -> Dictionary:
	return {"format": FORMAT, "id": item.id, "nom": item.name, "graine": item.seed, "mode": item.get("mode", "default"),
		"mode_developpeur_utilise": item.get("developer_used", false), "creation": item.get("created", ""), "terrain": "blocs", "generation": item.get("generation", {}).duplicate(true)}

static func valid_base(data: Dictionary) -> bool:
	return preload("res://scripts/world_generation.gd").valid(data.get("generation", {})) and data.get("id") is String and data.get("nom") is String and (data.get("graine") is float or data.get("graine") is int)

static func valid_player(data: Dictionary) -> bool:
	var at: Variant = data.get("position")
	return at is Array and at.size() == 3 and at.all(func(v): return v is float or v is int) and (data.get("regard_horizontal") is float or data.get("regard_horizontal") is int) and (data.get("regard_vertical") is float or data.get("regard_vertical") is int)

static func valid_changes(data: Dictionary) -> bool:
	if data.get("format") != float(CHANGES_FORMAT) and data.get("format") != CHANGES_FORMAT:
		return false
	if not data.get("poses") is Array or not data.get("casses") is Array:
		return false
	for entry in data.poses:
		if not entry is Array or entry.size() != 4 or not entry.all(func(v): return v is float or v is int):
			return false
	for entry in data.casses:
		if not entry is Array or entry.size() != 3 or not entry.all(func(v): return v is float or v is int):
			return false
	return true

static func copy_folder(from: String, to: String) -> bool:
	var dir := DirAccess.open(from)
	if dir == null:
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(to))
	for sub in dir.get_directories():
		if not copy_folder(from.path_join(sub), to.path_join(sub)):
			return false
	for name in dir.get_files():
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(from.path_join(name)), ProjectSettings.globalize_path(to.path_join(name))) != OK:
			return false
	return true

static func delete_folder(path: String) -> bool:
	var dir := DirAccess.open(path)
	if dir == null:
		return not DirAccess.dir_exists_absolute(path)
	for sub in dir.get_directories():
		delete_folder(path.path_join(sub))
	for name in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(name)))
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK

static func folder_size(path: String) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	var total := 0
	for sub in dir.get_directories():
		total += folder_size(path.path_join(sub))
	for name in dir.get_files():
		var file := FileAccess.open(path.path_join(name), FileAccess.READ)
		if file != null:
			total += file.get_length()
	return total

static func size_text(bytes: int) -> String:
	if bytes < 1024:
		return "%d o" % bytes
	return ("%.1f Ko" % (bytes / 1024.0)).replace(".", ",")
