@tool
extends EditorExportPlugin

# Même chemin que HISTORY_PATH dans scripts/app.gd.
const HISTORY_PATH := "res://docs/HISTORIQUE.txt"

func _get_name() -> String:
	return "OrbMekaHistory"

func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var file := FileAccess.open(HISTORY_PATH, FileAccess.READ)
	if file != null:
		add_file(HISTORY_PATH, file.get_buffer(file.get_length()), false)
	else:
		push_warning("HISTORIQUE.txt indisponible pour l'export.")
