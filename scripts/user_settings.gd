extends RefCounted
const ORIGINAL_JUMP_SPEED := 8.4
const ORIGINAL_GRAVITY := 14.0
# Vitesse de marche unique avant 0.0.2.14 : défaut des trois directions.
const ORIGINAL_WALK_SPEED := 5.5
const SPECS := {
	"jump_height": {"label": "Hauteur du saut", "unit": "m", "default": ORIGINAL_JUMP_SPEED * ORIGINAL_JUMP_SPEED / (2.0 * ORIGINAL_GRAVITY), "min": 1.1, "max": 8.0},
	"jump_speed": {"label": "Vitesse de montée", "unit": "m/s", "default": ORIGINAL_JUMP_SPEED, "min": 3.0, "max": 16.0},
	"fall_gravity": {"label": "Gravité de descente", "unit": "m/s²", "default": ORIGINAL_GRAVITY, "min": 4.0, "max": 40.0},
	"place_ms": {"label": "Intervalle de pose", "unit": "ms", "default": 300.0, "min": 100.0, "max": 2000.0},
	"break_ms": {"label": "Intervalle de casse", "unit": "ms", "default": 300.0, "min": 100.0, "max": 2000.0},
	"walk_forward": {"label": "Avancer", "unit": "m/s", "default": ORIGINAL_WALK_SPEED, "min": 1.0, "max": 12.0},
	"walk_side": {"label": "Avancer de côté", "unit": "m/s", "default": ORIGINAL_WALK_SPEED, "min": 1.0, "max": 12.0},
	"walk_back": {"label": "Reculer", "unit": "m/s", "default": ORIGINAL_WALK_SPEED, "min": 1.0, "max": 12.0},
}
var values: Dictionary = {}
var storage_path: String
var last_error := ""
var load_notice := ""

func _init(path: String = "user://settings.json") -> void:
	storage_path = path
	for key in SPECS:
		values[key] = SPECS[key].default
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parser := JSON.new()
	if file == null or parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		load_notice = "Réglages illisibles : valeurs par défaut chargées."
		return
	for key in SPECS:
		# Réglage absent (fichier d'une version précédente) : défaut, sans avertissement.
		if not parser.data.has(key):
			continue
		var value: Variant = parser.data.get(key)
		if (value is int or value is float) and is_finite(float(value)) and value >= SPECS[key].min and value <= SPECS[key].max:
			values[key] = float(value)
		else:
			load_notice = "Certains réglages invalides ont repris leur valeur par défaut."

# Valeurs d'un monde en mode par défaut, quels que soient les réglages enregistrés.
static func default_values() -> Dictionary:
	var result := {}
	for key in SPECS:
		result[key] = SPECS[key].default
	return result

static func number_text(value: float) -> String:
	return str(snappedf(value, 0.001)).replace(".", ",")

func apply_texts(texts: Dictionary) -> bool:
	last_error = ""
	var candidate := {}
	for key in SPECS:
		var text: String = str(texts.get(key, "")).strip_edges().replace(",", ".")
		var value: float = SPECS[key].default
		if not text.is_empty():
			if text.to_lower().contains("e") or not text.is_valid_float():
				last_error = "%s : saisissez un nombre." % SPECS[key].label
				return false
			value = text.to_float()
		if not is_finite(value) or value < SPECS[key].min or value > SPECS[key].max:
			last_error = "%s : valeur entre %s et %s %s." % [SPECS[key].label, number_text(SPECS[key].min), number_text(SPECS[key].max), SPECS[key].unit]
			return false
		candidate[key] = value
	var file := FileAccess.open(storage_path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Impossible d'enregistrer les paramètres."
		return false
	file.store_string(JSON.stringify(candidate, "	"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(storage_path + ".tmp"), ProjectSettings.globalize_path(storage_path)) != OK:
		last_error = "Échec de l'enregistrement des paramètres."
		return false
	values = candidate
	load_notice = ""
	return true
