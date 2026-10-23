extends RefCounted
# Launcher (0.0.4), pour le propriétaire seul tant que le dépôt est privé :
# liste les Releases GitHub, télécharge la version choisie (zip Windows) dans
# user://launcher/<version>/, puis la lance. Passe par GitHub CLI (gh), déjà connecté
# sur le PC : aucun jeton n'est gardé par le jeu. Windows seulement.
# Les noms des versions viennent de docs/HISTORIQUE.txt (celui de main sur GitHub, sinon celui du jeu).
const REPO := "Oshidori99/OrbMeka"
# Dossier des versions installées (les tests en prennent un autre).
static var root := "user://launcher"
const LOCAL_HISTORY := "res://docs/HISTORIQUE.txt"
const GH_PATHS := ["C:/Program Files/GitHub CLI/gh.exe", "gh"]

# Versions connues, de la plus récente à la plus ancienne : {"version", "name"}.
var versions: Array = []
var error := ""

static func supported() -> bool:
	return OS.has_feature("windows") and not OS.has_feature("web")

static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))

# Groupe d'affichage : les trois premiers nombres (« 0.0.3 » pour 0.0.3.27).
static func group_of(version: String) -> String:
	return ".".join(version.split(".").slice(0, 3))

# « 0.0.3.27 — Titre » de l'historique → {"0.0.3.27": "Titre"}.
static func names_from_history(text: String) -> Dictionary:
	var result := {}
	var pattern := RegEx.create_from_string("^(\\d+(?:\\.\\d+)+) — (.+)$")
	for line in text.split("\n"):
		var found := pattern.search(line.strip_edges())
		if found != null:
			result[found.get_string(1)] = found.get_string(2)
	return result

# Liste des versions à partir des tags des Releases (« v0.0.3.27 ») et des noms.
static func build_list(tags: Array, names: Dictionary) -> Array:
	var result := []
	for tag in tags:
		var version := str(tag).trim_prefix("v")
		result.append({"version": version, "name": names.get(version, "")})
	return result

static func folder(version: String) -> String:
	return root.path_join(version)

# Exécutable installé de cette version, ou "" si elle n'est pas encore téléchargée.
static func executable(version: String) -> String:
	var dir := DirAccess.open(folder(version))
	if dir == null:
		return ""
	for file in dir.get_files():
		if file.get_extension().to_lower() == "exe" and not file.to_lower().contains("console"):
			return ProjectSettings.globalize_path(folder(version).path_join(file))
	return ""

static func gh() -> String:
	for path in GH_PATHS:
		if path == "gh" or FileAccess.file_exists(path):
			return path
	return ""

static func _run(arguments: Array) -> Dictionary:
	var output := []
	var code := OS.execute(gh(), PackedStringArray(arguments), output, true)
	return {"code": code, "text": "".join(output)}

# Lit les Releases et les noms (bloquant : appelé dans un fil à part).
func refresh() -> bool:
	error = ""
	var listed := _run(["release", "list", "-R", REPO, "-L", "500", "--json", "tagName", "-q", ".[].tagName"])
	if listed.code != 0:
		error = "GitHub CLI introuvable ou non connecté : versions indisponibles."
		return false
	# Contenu en base64 : les accents et « — » arrivent intacts, quelle que soit la console.
	var history := _run(["api", "repos/%s/contents/docs/HISTORIQUE.txt" % REPO, "-q", ".content"])
	var encoded: String = history.text.replace("\n", "").replace("\r", "").strip_edges()
	var text: String = Marshalls.base64_to_utf8(encoded) if history.code == 0 else ""
	if names_from_history(text).is_empty():
		text = FileAccess.get_file_as_string(LOCAL_HISTORY)
	var tags := Array(listed.text.strip_edges().split("\n", false))
	versions = build_list(tags, names_from_history(text))
	return true

# Télécharge et décompresse le zip Windows d'une version (bloquant, fil à part).
func install(version: String) -> bool:
	error = ""
	var dir := ProjectSettings.globalize_path(folder(version))
	DirAccess.make_dir_recursive_absolute(dir)
	var result := _run(["release", "download", "v" + version, "-R", REPO, "-p", "*windows.zip", "-D", dir, "--clobber"])
	if result.code != 0:
		error = "Téléchargement impossible : " + result.text.strip_edges().left(200)
		return false
	for file in DirAccess.get_files_at(dir):
		if file.get_extension().to_lower() == "zip":
			if not _unzip(dir.path_join(file), dir):
				error = "Archive illisible : " + file
				return false
			DirAccess.remove_absolute(dir.path_join(file))
	if executable(version).is_empty():
		error = "Aucun programme trouvé dans la version " + version
		return false
	return true

static func _unzip(zip_path: String, destination: String) -> bool:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return false
	for entry in zip.get_files():
		if entry.ends_with("/"):
			continue
		# Contenu à plat : seul le nom du fichier compte (le zip contient l'exe et ses fichiers).
		var target := destination.path_join(entry.get_file())
		var file := FileAccess.open(target, FileAccess.WRITE)
		if file == null:
			zip.close()
			return false
		file.store_buffer(zip.read_file(entry))
		file.close()
	zip.close()
	return true

# Lance une version installée ; renvoie son numéro de processus (-1 en cas d'échec).
static func launch(version: String) -> int:
	var path := executable(version)
	if path.is_empty():
		return -1
	return OS.create_process(path, PackedStringArray([]))
