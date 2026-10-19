@tool
extends EditorExportPlugin

func _get_name() -> String:
	return "OrbMekaHistory"

func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var file := FileAccess.open("res://HISTORIQUE.txt", FileAccess.READ)
	if file != null:
		add_file("res://HISTORIQUE.txt", file.get_buffer(file.get_length()), false)
	else:
		push_warning("HISTORIQUE.txt indisponible pour l'export.")