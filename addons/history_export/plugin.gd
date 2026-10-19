@tool
extends EditorPlugin

var history_exporter := preload("res://addons/history_export/history_exporter.gd").new()

func _enter_tree() -> void:
	add_export_plugin(history_exporter)

func _exit_tree() -> void:
	remove_export_plugin(history_exporter)