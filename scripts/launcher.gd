extends RefCounted
# Launcher (0.0.4) : liste les Releases GitHub, télécharge la version choisie (zip Windows) dans
# user://launcher/<version>/, puis la lance. Windows seulement (caché dans la version Web).
# 0.0.4.18 : dépôt public : passe directement par Internet (API GitHub, sans compte ni jeton) ;
# GitHub CLI (gh), s'il est connecté, reste en secours (dépôt privé, Internet indisponible).
# Les noms des versions viennent de docs/HISTORIQUE.txt (celui de main sur GitHub, sinon celui du jeu).
const REPO := "Oshidori99/OrbMeka"
# Dossier des versions installées (les tests en prennent un autre).
static var root := "user://launcher"
const LOCAL_HISTORY := "res://docs/HISTORIQUE.txt"
const GH_PATHS := ["C:/Program Files/GitHub CLI/gh.exe", "gh"]
const API_RELEASES := "https://api.github.com/repos/%s/releases?per_page=100&page=%d"
const RAW_HISTORY := "https://raw.githubusercontent.com/%s/main/docs/HISTORIQUE.txt"
const ZIP_URL := "https://github.com/%s/releases/download/v%s/OrbMeka-%s-windows.zip"
const HTTP_TIMEOUT_MS := 60000

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

# Dernières versions jouées (0.0.4.1), la plus récente en dernier : <root>/versions-jouees.json.
const PLAYED_MAX := 6

static func played_path() -> String:
	return root.path_join("versions-jouees.json")

static func played() -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(played_path())) if FileAccess.file_exists(played_path()) else null
	if not data is Array:
		return []
	return data.filter(func(item): return item is String).slice(-PLAYED_MAX)

static func note_played(version: String) -> void:
	var list := played()
	list.erase(version)
	list.append(version)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var file := FileAccess.open(played_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(list.slice(-PLAYED_MAX)))
		file.close()

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

# Lit les Releases et les noms (bloquant : appelé dans un fil à part) : Internet d'abord, gh sinon.
func refresh() -> bool:
	error = ""
	if refresh_online():
		return true
	var listed := _run(["release", "list", "-R", REPO, "-L", "500", "--json", "tagName", "-q", ".[].tagName"])
	if listed.code != 0:
		error = "Versions indisponibles : pas d'Internet, ou GitHub injoignable (GitHub CLI non connecté en secours)."
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

# Télécharge et décompresse le zip Windows d'une version (bloquant, fil à part) : Internet d'abord, gh sinon.
func install(version: String) -> bool:
	error = ""
	var dir := ProjectSettings.globalize_path(folder(version))
	DirAccess.make_dir_recursive_absolute(dir)
	var download := http_get(ZIP_URL % [REPO, version, version])
	if download.code == 200 and download.body.size() > 0:
		var zip_file := FileAccess.open(dir.path_join("OrbMeka-%s-windows.zip" % version), FileAccess.WRITE)
		if zip_file != null:
			zip_file.store_buffer(download.body)
			zip_file.close()
	else:
		var result := _run(["release", "download", "v" + version, "-R", REPO, "-p", "*windows.zip", "-D", dir, "--clobber"])
		if result.code != 0:
			error = "Téléchargement impossible (Internet, puis GitHub CLI) : " + result.text.strip_edges().left(200)
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

# 0.0.4.18 : versions et noms par Internet (dépôt public) ; faux si GitHub ne répond pas (privé, hors ligne).
func refresh_online() -> bool:
	var tags := []
	for page in range(1, 6):
		var answer := http_get(API_RELEASES % [REPO, page])
		if answer.code != 200:
			return false
		var page_tags := tags_from_api(answer.body.get_string_from_utf8())
		tags.append_array(page_tags)
		if page_tags.size() < 100:
			break
	if tags.is_empty():
		return false
	var history := http_get(RAW_HISTORY % REPO)
	var text: String = history.body.get_string_from_utf8() if history.code == 200 else ""
	if names_from_history(text).is_empty():
		text = FileAccess.get_file_as_string(LOCAL_HISTORY)
	versions = build_list(tags, names_from_history(text))
	return true

# Tags des Releases dans la réponse de l'API GitHub (liste JSON), dans le même ordre (récente d'abord).
static func tags_from_api(text: String) -> Array:
	var data: Variant = JSON.parse_string(text)
	if not data is Array:
		return []
	var tags := []
	for release in data:
		if release is Dictionary and release.get("tag_name") is String and not release.get("draft", false):
			tags.append(release.tag_name)
	return tags

# https://hôte/chemin → ["hôte", "/chemin"] ; [] si l'adresse n'est pas en https.
static func split_url(url: String) -> Array:
	if not url.begins_with("https://"):
		return []
	var rest := url.trim_prefix("https://")
	var slash := rest.find("/")
	return [rest, "/"] if slash == -1 else [rest.left(slash), rest.substr(slash)]

# Requête GET bloquante (dans le fil du launcher), en https seulement, redirections suivies (les zips
# des Releases passent par un autre serveur de GitHub). Renvoie {"code", "body"} ; code 0 si échec.
static func http_get(url: String, redirects := 5) -> Dictionary:
	var parts := split_url(url)
	if parts.is_empty():
		return {"code": 0, "body": PackedByteArray()}
	var client := HTTPClient.new()
	if client.connect_to_host(parts[0], 443, TLSOptions.client()) != OK:
		return {"code": 0, "body": PackedByteArray()}
	var start := Time.get_ticks_msec()
	while client.get_status() in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]:
		client.poll()
		OS.delay_msec(10)
		if Time.get_ticks_msec() - start > HTTP_TIMEOUT_MS:
			return {"code": 0, "body": PackedByteArray()}
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"code": 0, "body": PackedByteArray()}
	client.request(HTTPClient.METHOD_GET, parts[1], ["User-Agent: OrbMeka-Launcher", "Accept: */*"])
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
	if not client.has_response():
		return {"code": 0, "body": PackedByteArray()}
	var code := client.get_response_code()
	var headers := client.get_response_headers_as_dictionary()
	if code in [301, 302, 303, 307, 308] and redirects > 0:
		var location: String = str(headers.get("Location", headers.get("location", "")))
		client.close()
		return http_get(location, redirects - 1)
	var body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.is_empty():
			OS.delay_msec(5)
		else:
			body.append_array(chunk)
		if Time.get_ticks_msec() - start > HTTP_TIMEOUT_MS * 5:
			break
	client.close()
	return {"code": code, "body": body}
