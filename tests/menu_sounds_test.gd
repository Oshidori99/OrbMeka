extends SceneTree
# 0.0.4.11 (#96) : sons des menus fabriqués par le code ; survol, clic, retour ; volume dans
# Paramètres généraux → Son (0 = muet), enregistré dans parametres-generaux.json.
const Settings = preload("res://scripts/user_settings.gd")
const MenuSounds = preload("res://scripts/menu_sounds.gd")
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
	# Sons générés.
	for sound in MenuSounds.SOUNDS:
		var spec: Array = MenuSounds.SOUNDS[sound]
		var stream: AudioStreamWAV = MenuSounds.make_tone(spec[0], spec[1], spec[2], spec[3])
		var loudest := 0
		for index in range(0, stream.data.size(), 2):
			loudest = maxi(loudest, absi(stream.data.decode_s16(index)))
		check(stream.data.size() == int(MenuSounds.RATE * spec[2]) * 2 and loudest > 1000 and loudest <= 32767, "%s: short generated sound (%d samples)" % [sound, stream.data.size() / 2])
		check(absi(stream.data.decode_s16(stream.data.size() - 2)) < 200, "%s: fades out, no click at the end" % sound)
	check(MenuSounds.SOUNDS.hover[3] < MenuSounds.SOUNDS.click[3], "hover softer than click")
	# Réglage.
	check(Settings.SPECS.menu_volume.default == 60.0 and Settings.SPECS.menu_volume.min == 0.0 and "menu_volume" in Settings.GENERAL_KEYS and Settings.menu_of("menu_volume") == "general", "Volume des menus: 60 %, 0 to 100, general settings")
	var fixture := "res://.godot/menu-sounds-%d.json" % Time.get_ticks_usec()
	var blank := Settings.new(fixture)
	var file := FileAccess.open(blank.file_path("general"), FileAccess.WRITE)
	file.store_string('{"mouse_sensitivity": 120.0}')
	file.close()
	var legacy := Settings.new(fixture)
	check(legacy.values.menu_volume == 60.0 and legacy.values.mouse_sensitivity == 120.0 and legacy.load_notice.is_empty(), "old parametres-generaux.json: volume by default, no warning")
	# Menus.
	var settings := Settings.new(fixture + ".app")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	current_scene = app
	await process_frame
	var sounds: Node = app.menu_sounds
	check(is_instance_valid(sounds) and sounds.players.size() == 3 and is_equal_approx(sounds.volume, 60.0), "sounds ready, at the saved volume")
	sounds.played.clear()
	app.play_button.mouse_entered.emit()
	app.settings_button.pressed.emit()
	check(sounds.played == ["hover", "click"], "hover then click on a home button (%s)" % str(sounds.played))
	sounds.played.clear()
	app.settings_back_button.pressed.emit()
	check(sounds.played.has("back"), "Retour: back sound")
	app.show_page("settings")
	check(app.setting_fields.has("menu_volume") and app.setting_sliders.has("menu_volume"), "volume field and slider in Paramètres généraux")
	app.setting_fields.menu_volume.text = "0"
	app._autosave()
	check(settings.values.menu_volume == 0.0 and sounds.volume == 0.0, "volume 0 saved and applied")
	sounds.played.clear()
	app.settings_back_button.pressed.emit()
	check(sounds.played.is_empty(), "volume 0: silent")
	check(Settings.new(fixture + ".app").values.menu_volume == 0.0, "volume reloads")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d menu sound checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
