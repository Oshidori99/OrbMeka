extends SceneTree
# 0.0.4.18 : dépôt public. Launcher par Internet (API GitHub, sans compte), GitHub CLI en secours ;
# pas de launcher dans la version Web ; fichier LICENSE (tous droits réservés) ; aucun autre jeu cité.
const Launcher = preload("res://scripts/launcher.gd")
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

# Fichiers texte du projet (hors cache .godot et Archives), pour y chercher un mot.
func text_files(path: String, found: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub in [".godot", ".git", "Archives", "export_templates"]:
			text_files(path.path_join(sub), found)
	for file in dir.get_files():
		if file.get_extension() in ["gd", "md", "txt", "yml", "cfg", "godot", "tscn"] or file == "LICENSE":
			found.append(path.path_join(file))

func _run() -> void:
	# Lecture de la réponse de l'API.
	var api := '[{"tag_name": "v0.0.4.18", "draft": false}, {"tag_name": "v0.0.4.17"}, {"tag_name": "v9", "draft": true}, {"name": "sans tag"}]'
	check(Launcher.tags_from_api(api) == ["v0.0.4.18", "v0.0.4.17"], "release tags read from the GitHub API, drafts left out")
	check(Launcher.tags_from_api("pas du json").is_empty() and Launcher.tags_from_api("{}").is_empty(), "bad answer: no tags")
	check(Launcher.split_url("https://api.github.com/repos/a/b?x=1") == ["api.github.com", "/repos/a/b?x=1"] and Launcher.split_url("https://github.com") == ["github.com", "/"], "URL split into host and path")
	check(Launcher.split_url("http://example.com/x").is_empty() and Launcher.http_get("http://example.com/").code == 0, "https only")
	check(Launcher.ZIP_URL % [Launcher.REPO, "0.0.4.18", "0.0.4.18"] == "https://github.com/Oshidori99/OrbMeka/releases/download/v0.0.4.18/OrbMeka-0.0.4.18-windows.zip", "Windows zip address of a version")
	var source := FileAccess.get_file_as_string("res://scripts/launcher.gd")
	check(source.contains("if refresh_online():") and source.contains("_run([\"release\", \"list\""), "Internet first, GitHub CLI as a fallback")
	# Version Web à part.
	var app_source := FileAccess.get_file_as_string("res://scripts/app.gd")
	check(app_source.contains("launcher_button.visible = not OS.has_feature(\"web\")") and app_source.contains("quit_button.visible = not OS.has_feature(\"web\")"), "no launcher nor Quitter in the Web version")
	# LICENSE.
	var license := FileAccess.get_file_as_string("res://LICENSE")
	check(license.contains("Tous droits réservés") and license.contains("All rights reserved") and license.contains("docs/LICENCES.txt") and license.contains("CC0"), "LICENSE: all rights reserved, third-party parts keep their licenses")
	# Aucun autre jeu cité dans le dépôt public.
	var files := []
	text_files("res://", files)
	var cited := []
	for path in files:
		if FileAccess.get_file_as_string(path).to_lower().contains("mine" + "craft"):
			cited.append(path)
	check(files.size() > 50 and cited.is_empty(), "no other game named in the repository (%d files, %s)" % [files.size(), str(cited)])
	print("RESULT: %d public launcher checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
