extends SceneTree
# 0.0.4.17 : mentions de licence obligatoires (Godot, licence MIT, et ses composants) et sons CC0 :
# Paramètres → Licences (dernier onglet), polices de secours pour le Web, et docs/LICENCES.txt, copié à côté du jeu dans les zips et sur itch.io.
const Licences = preload("res://scripts/licences.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
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
	root.size = Vector2i(1280, 720)
	var summary := Licences.summary()
	check(summary.contains("Godot Engine contributors") and summary.contains("Permission is hereby granted") and summary.contains("THE SOFTWARE IS PROVIDED \"AS IS\""), "Godot MIT notice in full")
	check(summary.contains("IgnasD") and summary.contains("AntumDeluge") and summary.contains("Joseph Sardin") and summary.contains("CC0"), "CC0 sounds credited")
	check(summary.contains("FreeType") and summary.count("\n· ") >= 20, "Godot components listed")
	# Le fichier livré avec le jeu doit suivre le texte du jeu : sinon, le refaire (voir scripts/licences.gd).
	var file_text := FileAccess.get_file_as_string("res://docs/LICENCES.txt")
	check(file_text == Licences.full_text(), "docs/LICENCES.txt up to date with this Godot version")
	check(file_text.contains("=== TEXTES DES LICENCES ===") and file_text.contains("--- Expat ---") and file_text.contains("--- FTL ---"), "full license texts included")
	var build := FileAccess.get_file_as_string("res://.github/workflows/build.yml")
	var dev := FileAccess.get_file_as_string("res://.github/workflows/dev.yml")
	check(build.contains("LICENCES.txt") and dev.contains("cp docs/LICENCES.txt out/web/"), "LICENCES.txt put next to the game in zips and on itch.io")
	var fixture := "res://.godot/licences-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = load("res://scripts/user_settings.gd").new(fixture)
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	current_scene = app
	await process_frame
	# Paramètres → Licences, dernier onglet (Windows et Web).
	check(app.SETTINGS_SECTIONS.keys()[-1] == "licences" and app.SETTINGS_SECTIONS.licences == "Licences", "Licences: last tab of Paramètres")
	app.show_page("settings")
	app.settings_tabs.licences.pressed.emit()
	check(app.settings_sections.licences.visible and app.licences_text.text == summary and app.licences_text.is_visible_in_tree(), "Licences tab shows the notices")
	check(summary.contains("DejaVu Sans") and summary.contains("Noto Emoji") and file_text.contains("--- Police Noto Emoji ---") and file_text.contains("SIL OPEN FONT LICENSE"), "fonts credited, licence texts included")
	# Polices de secours : seulement dans un navigateur (ici forcées pour le test).
	UiTheme.use_web_fonts(true)
	var fallbacks: Array = ThemeDB.fallback_font.fallbacks
	check(fallbacks.size() == 2 and fallbacks[0].has_char(0x21BB) and fallbacks[0].has_char(0x232B) and fallbacks[0].has_char(0x25BE) and fallbacks[1].has_char(0x1F5D1) and fallbacks[1].has_char(0x1F4CB), "web: symbols (↻ ⌫ ▾) and emojis (🗑 📋) found in the fallback fonts")
	var missing := []
	for glyph in ["→", "↑", "↓", "←", "⌫", "↻", "−", "▼", "✕", "▶", "➕", "▾", "▸", "🗑", "✏", "📋", "™", "⚙", "…", "—"]:
		var code: int = String(glyph).unicode_at(0)
		if not (ThemeDB.fallback_font.has_char(code) or fallbacks.any(func(font): return font.has_char(code))):
			missing.append(glyph)
	check(missing.is_empty(), "every symbol of the menus can be drawn on the web (missing: %s)" % str(missing))
	root.remove_child(app)
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d licence checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
