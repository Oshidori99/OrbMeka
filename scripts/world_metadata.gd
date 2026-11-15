extends RefCounted
# Lecture seule : l'affichage ne répare ni ne réécrit les métadonnées du monde.
const UNKNOWN := "Création : inconnue"

static func read_creation(folder: String) -> String:
	if folder.is_empty():
		return UNKNOWN
	var path := folder.path_join("monde.json")
	if not FileAccess.file_exists(path):
		return UNKNOWN
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) == OK and parser.data is Dictionary:
		return format_creation_date(parser.data.get("creation"))
	return UNKNOWN

# Les dates existantes sont locales, sans fuseau : garder l'heure enregistrée.
static func format_creation_date(value: Variant) -> String:
	if not value is String or value.length() != 19:
		return UNKNOWN
	if value[4] != "-" or value[7] != "-" or value[10] != "T" or value[13] != ":" or value[16] != ":":
		return UNKNOWN
	for part in [value.substr(0,4),value.substr(5,2),value.substr(8,2),value.substr(11,2),value.substr(14,2),value.substr(17,2)]:
		if not part.is_valid_int() or part.begins_with("-") or part.begins_with("+"):
			return UNKNOWN
	var year := int(value.substr(0,4))
	var month := int(value.substr(5,2))
	var day := int(value.substr(8,2))
	var hour := int(value.substr(11,2))
	var minute := int(value.substr(14,2))
	var second := int(value.substr(17,2))
	if year < 1 or month < 1 or month > 12 or hour > 23 or minute > 59 or second > 59:
		return UNKNOWN
	var leap := year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
	var days := [31,29 if leap else 28,31,30,31,30,31,31,30,31,30,31]
	if day < 1 or day > days[month-1]:
		return UNKNOWN
	return "Création : %02d/%02d/%04d à %02d:%02d:%02d (heure locale enregistrée)" % [day,month,year,hour,minute,second]

# 0.0.7.10 (demande de l'utilisateur) : statistiques d'un monde, dans son dossier (statistiques.json, jamais lu par les
# anciennes versions) : version qui l'a créé, dernière ouverture (date, heure, version), nombre d'ouvertures, temps de
# jeu (en secondes, pauses non comptées). Rien ne quitte l'ordinateur ; rien sur le joueur lui-même.
const STATS_FILE := "statistiques.json"

static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))

static func read_stats(folder: String) -> Dictionary:
	if folder.is_empty():
		return {}
	var path := folder.path_join(STATS_FILE)
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) == OK and parser.data is Dictionary:
		return parser.data
	return {}

static func write_stats(folder: String, stats: Dictionary) -> bool:
	if folder.is_empty():
		return true
	var file := FileAccess.open(folder.path_join(STATS_FILE), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(stats, "\t"))
	return true

# Monde créé : la version du jeu qui l'a créé.
static func start_stats(folder: String) -> bool:
	return write_stats(folder, {"version_creation": game_version(), "ouvertures": 0, "temps_de_jeu": 0.0})

# Monde ouvert : une ouverture de plus, date et version de cette ouverture (les précédentes valeurs sont gardées).
static func opened(folder: String) -> Dictionary:
	var stats := read_stats(folder)
	stats.ouvertures = int(stats.get("ouvertures", 0)) + 1
	stats.derniere_ouverture = Time.get_datetime_string_from_system()
	stats.version_ouverture = game_version()
	if not stats.has("temps_de_jeu"):
		stats.temps_de_jeu = 0.0
	write_stats(folder, stats)
	return stats

static func duration_text(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	if minutes < 60:
		return "%d min" % minutes
	return "%d h %02d min" % [minutes / 60, minutes % 60]

static func stats_text(creation: String, stats: Dictionary, played: float) -> String:
	var created_with := str(stats.get("version_creation", ""))
	var last := str(stats.get("derniere_ouverture", ""))
	var lines := [
		"%s · version : %s" % [creation, created_with if not created_with.is_empty() else "inconnue"],
		"Ouvert le : %s (version %s) · ouvertures : %d" % [format_creation_date(last).trim_prefix("Création : ").trim_suffix(" (heure locale enregistrée)") if not last.is_empty() else "inconnu", str(stats.get("version_ouverture", "?")), int(stats.get("ouvertures", 0))],
		"Temps de jeu : %s%s" % [duration_text(played), " (compté depuis 0.0.7.10)" if created_with.is_empty() else ""],
	]
	return "\n".join(lines)
