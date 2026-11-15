extends SceneTree
# 0.0.7.10 : nom automatique d'un monde créé sans nom (T + numéro suivant) et statistiques du monde (version de
# création, dernière ouverture, nombre d'ouvertures, temps de jeu) dans statistiques.json.
const Catalog = preload("res://scripts/world_catalog.gd")
const WorldMetadata = preload("res://scripts/world_metadata.gd")
const PATH := "res://.godot/test-world-stats/worlds.json"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	var folder := ProjectSettings.globalize_path(PATH.get_base_dir())
	if DirAccess.dir_exists_absolute(folder):
		Catalog.Store.delete_folder(PATH.get_base_dir())
	var catalog := Catalog.new(PATH)
	var first: Dictionary = catalog.create_world("")
	check(first.get("name") == "T1", "no name: T1 at first (%s)" % first.get("name"))
	catalog.create_world("T55")
	catalog.create_world("Autre")
	check(catalog.next_auto_name() == "T56", "next automatic name follows the highest T number (T56)")
	var auto: Dictionary = catalog.create_world("   ")
	check(auto.get("name") == "T56", "blank name becomes T56")
	var world_folder: String = catalog.world_folder(auto.id)
	var stats := WorldMetadata.read_stats(world_folder)
	check(stats.get("version_creation") == WorldMetadata.game_version() and int(stats.get("ouvertures", -1)) == 0, "creation version written")
	var opened := WorldMetadata.opened(world_folder)
	opened = WorldMetadata.opened(world_folder)
	check(int(opened.ouvertures) == 2 and str(opened.derniere_ouverture).length() == 19 and opened.version_ouverture == WorldMetadata.game_version(), "two openings counted with date and version")
	var text := WorldMetadata.stats_text("Création : 15/11/2026 à 10:00:00 (heure locale enregistrée)", opened, 3725.0)
	check(text.contains("Temps de jeu : 1 h 02 min") and text.contains("ouvertures : 2") and text.contains("version : " + WorldMetadata.game_version()), "statistics text")
	var old := WorldMetadata.stats_text("Création : inconnue", {}, 0.0)
	check(old.contains("version : inconnue") and old.contains("Ouvert le : inconnu"), "old world: unknown values")
	Catalog.Store.delete_folder(PATH.get_base_dir())
	print("RESULT: %d world stats checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
