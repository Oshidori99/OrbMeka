extends RefCounted
# 0.0.6 : trois listes de mondes (Paramètres généraux → Mondes) : « Par défaut » (worlds.json, user://mondes),
# « Sécurisés » (choisis par le joueur) et « Versions sécurisées » (anciennes générations). Chaque liste a son
# propre index et son propre dossier : les anciennes versions du jeu ne lisent que worlds.json, elles ne voient
# donc jamais les mondes mis en sécurité et ne peuvent pas les abîmer. Sous-dossiers (un seul niveau) et
# exceptions dans mondes-dossiers.json, que les anciennes versions ignorent aussi.
const Catalog = preload("res://scripts/world_catalog.gd")
const Store = preload("res://scripts/world_store.gd")
const Generation = preload("res://scripts/world_generation.gd")
const LISTS := ["default", "secure", "versions"]
const NAMES := {"default": "Par défaut", "secure": "Sécurisés", "versions": "Versions sécurisées"}
const ICONS := {"default": "🌍", "secure": "🔒", "versions": "🕰️"}
const HELP := {
	"default": "Mondes visibles par toutes les versions du jeu.",
	"secure": "Mondes mis à l'abri : seules les versions qui connaissent ces dossiers les voient, aucune ancienne version ne peut les modifier.",
	"versions": "Mondes d'une ancienne génération, mis à l'abri de la même façon ; les ramener dans « Par défaut » en fait une exception.",
}
const MAX_FOLDER_NAME := 32
var catalogs := {}
# Sous-dossiers de chaque liste, monde → sous-dossier, mondes anciens gardés dans « Par défaut » (exceptions).
var folders := {"default": [], "secure": [], "versions": []}
var placed := {}
var exceptions: Array = []
var organization_path: String
var last_error := ""

func _init(default_catalog: Catalog) -> void:
	var path: String = default_catalog.storage_path
	var base := Store.ROOT if path == "user://worlds.json" else path.get_basename()
	catalogs.default = default_catalog
	catalogs.secure = Catalog.new(base + "-securises.json", base + "-securises")
	catalogs.versions = Catalog.new(base + "-versions.json", base + "-versions")
	organization_path = base + "-dossiers.json"
	for list in LISTS:
		catalogs[list].siblings = LISTS.filter(func(other): return other != list).map(func(other): return catalogs[other])
	_read()

static func is_old(item: Dictionary) -> bool:
	return not item.is_empty() and int(item.get("generation", {}).get("version", 0)) < Generation.VERSION

func list_of(id: String) -> String:
	for list in LISTS:
		if not catalogs[list].find_world(id).is_empty():
			return list
	return ""

# Sous-dossier d'un monde dans sa liste ("" : à la racine, aussi si le dossier n'existe plus).
func folder_of(id: String) -> String:
	var folder: String = placed.get(id, "")
	return folder if folder in folders.get(list_of(id), []) else ""

func worlds_in(list: String, folder: String) -> Array:
	return catalogs[list].worlds.filter(func(item): return folder_of(item.id) == folder)

func create_folder(list: String, raw_name: String) -> bool:
	last_error = ""
	var clean := raw_name.strip_edges()
	if clean.is_empty() or clean.length() > MAX_FOLDER_NAME:
		last_error = "Saisissez un nom de dossier de 1 à %d caractères." % MAX_FOLDER_NAME
		return false
	for folder in folders[list]:
		if folder.nocasecmp_to(clean) == 0:
			last_error = "Un dossier porte déjà ce nom."
			return false
	folders[list].append(clean)
	return _write()

# Seulement un dossier vide : aucun monde n'est jamais supprimé ici.
func delete_folder(list: String, folder: String) -> bool:
	last_error = ""
	if not worlds_in(list, folder).is_empty():
		last_error = "Ce dossier contient encore des mondes."
		return false
	folders[list].erase(folder)
	return _write()

func put_in_folder(id: String, folder: String) -> bool:
	last_error = ""
	if not folder.is_empty() and not folder in folders.get(list_of(id), []):
		last_error = "Ce dossier n'existe plus."
		return false
	if folder.is_empty():
		placed.erase(id)
	else:
		placed[id] = folder
	return _write()

# Déplace un monde (son dossier sur le disque et sa ligne d'index) d'une liste à l'autre. En cas d'échec,
# tout revient comme avant ; jamais rien d'effacé.
func move_world(id: String, to: String) -> bool:
	last_error = ""
	var from := list_of(id)
	if from.is_empty() or not to in LISTS:
		last_error = "Ce monde n'existe plus."
		return false
	if from == to:
		return true
	var source: Catalog = catalogs[from]
	var target: Catalog = catalogs[to]
	if not source.load_error.is_empty() or not target.load_error.is_empty():
		last_error = source.load_error if not source.load_error.is_empty() else target.load_error
		return false
	var index := -1
	for each in range(source.worlds.size()):
		if source.worlds[each].id == id:
			index = each
	var original: Dictionary = source.worlds[index]
	for item in target.worlds + target.unreadable_worlds:
		if item is Dictionary and (item.get("id") == id or str(item.get("name", "")).nocasecmp_to(original.name) == 0):
			last_error = "« %s » existe déjà dans « %s » : renommez-le d'abord." % [original.name, NAMES[to]]
			return false
	var item: Dictionary = original.duplicate(true)
	item.folder = Store.unique_folder_name(item.name, target._taken_folders())
	var from_folder := source._item_folder(original)
	var to_folder := target.worlds_root.path_join(item.folder)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.worlds_root))
	var moved := DirAccess.dir_exists_absolute(from_folder)
	if moved and DirAccess.rename_absolute(ProjectSettings.globalize_path(from_folder), ProjectSettings.globalize_path(to_folder)) != OK:
		last_error = "Impossible de déplacer le dossier du monde."
		return false
	target.worlds.append(item)
	var saved := target._save_worlds()
	if saved:
		source.worlds.remove_at(index)
		saved = source._save_worlds()
		if not saved:
			source.worlds.insert(index, original)
			target.worlds.pop_back()
			target._save_worlds()
	else:
		target.worlds.pop_back()
	if not saved:
		if moved:
			DirAccess.rename_absolute(ProjectSettings.globalize_path(to_folder), ProjectSettings.globalize_path(from_folder))
		last_error = "Impossible d'enregistrer le déplacement ; le monde reste où il était."
		return false
	placed.erase(id)
	# Un monde ancien ramené dans « Par défaut » devient une exception : il n'est plus rangé automatiquement.
	if to == "default" and is_old(item):
		if not id in exceptions:
			exceptions.append(id)
	else:
		exceptions.erase(id)
	_write()
	return true

# Paramètres → Mondes : range les mondes anciens de « Par défaut » dans « Versions sécurisées », sauf les exceptions.
func auto_secure() -> int:
	var count := 0
	for item in catalogs.default.worlds.duplicate():
		if is_old(item) and not item.id in exceptions and move_world(item.id, "versions"):
			count += 1
	return count

func _read() -> void:
	var result := Store.read_json(organization_path, func(data): return data is Dictionary)
	if not result.has("data"):
		return
	var data: Dictionary = result.data
	var saved_folders: Variant = data.get("folders", {})
	if saved_folders is Dictionary:
		for list in LISTS:
			for folder in saved_folders.get(list, []) if saved_folders.get(list) is Array else []:
				if folder is String and not folder.strip_edges().is_empty() and folder.length() <= MAX_FOLDER_NAME and not folder in folders[list]:
					folders[list].append(folder)
	var saved_placed: Variant = data.get("placed", {})
	if saved_placed is Dictionary:
		for id in saved_placed:
			if id is String and saved_placed[id] is String:
				placed[id] = saved_placed[id]
	var saved_exceptions: Variant = data.get("exceptions", [])
	if saved_exceptions is Array:
		exceptions = saved_exceptions.filter(func(id): return id is String)

func _write() -> bool:
	if Store.write_json(organization_path, {"version": 1, "folders": folders, "placed": placed, "exceptions": exceptions}):
		return true
	last_error = "Impossible d'enregistrer les dossiers des mondes."
	return false
