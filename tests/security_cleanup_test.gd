extends SceneTree
# 0.0.4.21 : sécurité du launcher (numéros de version simples, serveurs de GitHub seulement, zip vérifié
# par son empreinte SHA-256) et place dans AppData (seules les versions jouées récemment restent
# installées, bouton Supprimer) ; restes du premier commit retirés, prototypes rangés.
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

# Fausse version installée : dossier avec un petit .exe.
func fake_install(version: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Launcher.folder(version)))
	var file := FileAccess.open(Launcher.folder(version).path_join("OrbMeka.exe"), FileAccess.WRITE)
	file.store_string("x")
	file.close()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	# Numéros de version.
	check(Launcher.valid_version("0.0.4.21") and Launcher.valid_version("1.2") and not Launcher.valid_version("../../x") and not Launcher.valid_version("0.0.4.21/../..") and not Launcher.valid_version("0.0.4.21 ") and not Launcher.valid_version(""), "only plain version numbers")
	check(Launcher.folder("..\\..\\Windows").is_empty() and Launcher.executable("../x").is_empty(), "a tricky name never gives a folder")
	check(Launcher.build_list(["v0.0.4.20", "v../../evil", "vx"], {}).map(func(item): return item.version) == ["0.0.4.20"], "tricky release tags left out")
	var launcher := Launcher.new()
	check(not launcher.install("../../evil") and launcher.error.begins_with("Numéro de version refusé"), "install refuses a tricky version")
	# Serveurs.
	check(Launcher.http_get("https://example.com/x").code == 0 and Launcher.http_get("https://github.com.evil.io/x").code == 0, "only GitHub servers")
	check("objects.githubusercontent.com" in Launcher.ALLOWED_HOSTS and "release-assets.githubusercontent.com" in Launcher.ALLOWED_HOSTS, "GitHub download servers allowed (redirections)")
	# Empreintes.
	var api := '[{"tag_name": "v0.0.4.20", "assets": [{"name": "OrbMeka-0.0.4.20-web.zip", "digest": "sha256:aa"}, {"name": "OrbMeka-0.0.4.20-windows.zip", "digest": "sha256:bb"}]}, {"tag_name": "v0.0.2.6", "assets": [{"name": "OrbMeka-0.0.2.6-windows.zip"}]}]'
	check(Launcher.digests_from_api(api) == {"0.0.4.20": "sha256:bb"}, "Windows zip digest read from the API")
	var fixture := "res://.godot/security-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
	var sample := fixture.path_join("sample.zip")
	var file := FileAccess.open(sample, FileAccess.WRITE)
	file.store_string("OrbMeka")
	file.close()
	var digest := "sha256:" + FileAccess.get_sha256(sample)
	check(Launcher.digest_matches(sample, digest) and not Launcher.digest_matches(sample, "sha256:" + "0".repeat(64)) and not Launcher.digest_matches(sample, "md5:x"), "file checked against its SHA-256")
	var source := FileAccess.get_file_as_string("res://scripts/launcher.gd")
	check(source.contains("not digest_matches(dir.path_join(file), digests[version])") and source.contains("DirAccess.remove_absolute(dir.path_join(file))"), "a wrong digest: zip deleted, never opened")
	# Place : versions jouées gardées, les autres supprimées.
	var saved_root := Launcher.root
	Launcher.root = fixture.path_join("launcher")
	for version in ["0.0.2.6", "0.0.3.26", "0.0.4.1", "0.0.4.2"]:
		fake_install(version)
	Launcher.note_played("0.0.4.1")
	Launcher.note_played("0.0.4.2")
	var removed := Launcher.cleanup("0.0.3.26")
	check(removed == ["0.0.2.6"] and Launcher.installed().size() == 3, "not played recently and not running: removed (%s)" % str(removed))
	check(Launcher.remove_version("0.0.4.1") and not Launcher.installed().has("0.0.4.1") and not Launcher.remove_version("0.0.9.9"), "one version removed on demand")
	# Bouton Supprimer dans le launcher.
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = load("res://scripts/user_settings.gd").new(fixture + ".json")
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	app.launcher_online = false
	root.add_child(app)
	current_scene = app
	await process_frame
	app.launcher.versions = [{"version": "0.0.4.2", "name": "Deux"}, {"version": "0.0.3.26", "name": "Un"}]
	app.open_launcher(false)
	if Launcher.supported():
		check(app.launcher_remove_buttons.has("0.0.4.2") and app.launcher_remove_buttons.has("0.0.3.26"), "installed versions have a Supprimer button")
		app.launcher_remove_buttons["0.0.3.26"].pressed.emit()
		check(not Launcher.installed().has("0.0.3.26") and app.launcher_status.text.contains("supprimée") and app.launcher_play_buttons["0.0.3.26"].text == "Installer et jouer", "Supprimer removes it, it can be installed again")
	else:
		check(true, "outside Windows: no install, nothing to remove")
		check(true, "outside Windows: no install, nothing to remove")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	Launcher.root = saved_root
	# Fichiers rangés.
	check(not FileAccess.file_exists("res://main.tscn") and not FileAccess.file_exists("res://project.godot.before-prototype"), "leftovers of the first commit removed")
	check(not DirAccess.dir_exists_absolute("res://idee") and FileAccess.file_exists("res://docs/idees/personnages/renard-1.png") and FileAccess.file_exists("res://docs/idees/personnages/.gdignore"), "character prototypes in docs/idees/personnages/")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d security/cleanup checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
