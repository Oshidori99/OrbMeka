extends SceneTree
# 0.0.4.12 : choisir un personnage le fait parler (humains : synthèse vocale du système, plus aiguë
# pour les jeunes, phrases selon l'âge) ou crier (animaux : cris fabriqués par le jeu).
# Volume : Paramètres généraux → Son → Volume des personnages.
const Settings = preload("res://scripts/user_settings.gd")
const CharacterPreview = preload("res://scripts/character_preview.gd")
const Voices = preload("res://scripts/character_voices.gd")
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
	# Chaque personnage a une voix ou un cri.
	for id in CharacterPreview.CHARACTERS:
		check(Voices.PITCHES.has(id) != Voices.is_animal(id), "voice or call: " + id)
	check(Voices.LINES["9 ans"].has("Jouons ensemble !") and Voices.LINES["14 ans"] != Voices.LINES["9 ans"] and Voices.LINES.adulte != Voices.LINES["14 ans"], "own lines per age; the 9-year-olds play together")
	check(Voices.PITCHES.girl9[0] > Voices.PITCHES.girl14[0] and Voices.PITCHES.boy9[0] > Voices.PITCHES.boy14[0] and Voices.PITCHES.boy14[0] > Voices.PITCHES.man[0], "younger: higher voice")
	for id in Voices.ANIMAL_CALLS:
		var stream: AudioStreamWAV = Voices.make_call(Voices.ANIMAL_CALLS[id])
		var loudest := 0
		for index in range(0, stream.data.size(), 2):
			loudest = maxi(loudest, absi(stream.data.decode_s16(index)))
		check(stream.data.size() > 2000 and loudest > 3000, "generated call: " + id)
	var cat: AudioStreamWAV = Voices.make_call(Voices.ANIMAL_CALLS.cat)
	var turtle: AudioStreamWAV = Voices.make_call(Voices.ANIMAL_CALLS.turtle)
	check(cat.data != turtle.data, "each animal sounds different")
	# Réglage.
	check(Settings.SPECS.character_volume.default == 80.0 and "character_volume" in Settings.GENERAL_KEYS and Settings.menu_of("character_volume") == "general", "Volume des personnages: 80 %, general settings")
	check(ProjectSettings.get_setting("audio/general/text_to_speech") == true, "system text to speech enabled")
	# Choisir dans Paramètres → Personnage.
	var fixture := "res://.godot/character-voices-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	current_scene = app
	await process_frame
	app.show_page("settings")
	var voices: Node = app.character_voices
	check(is_instance_valid(voices) and is_equal_approx(voices.volume, 80.0), "voices ready at the saved volume")
	app._choose_character("girl9", "brown")
	check(voices.last.get("character") == "girl9" and Voices.LINES["9 ans"].has(voices.last.get("text")) and voices.last.pitch == Voices.PITCHES.girl9[0], "girl 9: a child line, high voice (%s)" % voices.last.get("text"))
	var first_line: String = voices.last.text
	app._choose_character("boy9", "light")
	check(voices.last.text != first_line, "lines take turns")
	app._choose_character("girl14", "light")
	check(Voices.LINES["14 ans"].has(voices.last.text), "girl 14: a 14-year-old line")
	app._choose_character("man", "dark")
	check(Voices.LINES.adulte.has(voices.last.text) and voices.last.pitch < 1.0, "man: adult line, low voice")
	app._choose_character("fox", "")
	check(voices.last == {"character": "fox", "call": "fox"} and voices.animal_player.stream == voices.animal_stream("fox"), "fox: its call")
	check(settings.values.character == "fox", "the choice is still saved")
	# Muet.
	app.setting_fields.character_volume.text = "0"
	app._autosave()
	voices.last = {}
	app._choose_character("cat", "")
	check(voices.volume == 0.0 and voices.last.is_empty(), "volume 0: silent")
	check(Settings.new(fixture).values.character_volume == 0.0, "volume saved")
	root.remove_child(app)
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture + ".worlds"))
	print("RESULT: %d character voice checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
