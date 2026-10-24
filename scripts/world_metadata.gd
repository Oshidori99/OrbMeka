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
