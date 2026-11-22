extends SceneTree
# 0.0.8.14 (rapport d'optimisation) : fuite d'objets corrigée (zones vides), copies du terrain des fils de calcul qui oublient
# leurs colonnes, relevés du lointain limités, détails fins du sol au loin, mipmaps des feuilles et de l'écorce, taille de la
# carte des ombres (réglage, préréglages, anciens fichiers), qualité Performance proposée une fois sur un PC lent, module de
# diagnostic (sortes, effets, réglages à essayer) et console de mesure du Web.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Generation = preload("res://scripts/world_generation.gd")
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
const TerrainWorkers = preload("res://scripts/terrain_workers.gd")
const WorldScript = preload("res://scripts/world.gd")
const Diagnostic = preload("res://scripts/diagnostic.gd")
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
	# --- Réglage « Taille de la carte des ombres » ---
	check(Settings.CHOICES.shadow_size.options.keys() == ["512", "1024", "2048", "4096", "8192"], "shadow map sizes: only 512, 1024, 2048, 4096, 8192")
	check(Settings.PRESETS.performance.shadow_size == "1024" and Settings.PRESETS.balanced.shadow_size == "2048" and Settings.PRESETS.beauty.shadow_size == "4096", "presets: Performance 1024, Balanced 2048, Beauty 4096")
	check(Settings.preset_values("beauty", true).shadow_size == "2048" and Settings.preset_values("performance", true).shadow_size == "1024", "Web: Beauty keeps 2048, Performance 1024")
	check(WorldScript.shadow_atlas_size(8192) == 8192 and WorldScript.shadow_atlas_size(512) == 512 and WorldScript.shadow_atlas_size(3000) == 2048 and WorldScript.SHADOW_ATLAS_WEB_MAX == 4096, "PC: any of the 5 sizes; unknown size → 2048; Web at most 4096")
	# Ancien fichier (sans la taille) : celle de sa qualité, la qualité reste la même (pas « Personnalisé »).
	var old_fixture := "res://.godot/optimisation-old-%d.json" % Time.get_ticks_usec()
	var writer := Settings.new(old_fixture)
	writer.values.merge(Settings.preset_values("beauty", false), true)
	writer.values.erase("shadow_size")
	var part := {}
	for key in writer.values:
		if Settings.menu_of(key) == "video":
			part[key] = writer.values[key]
	writer._write(writer.file_path("video"), part)
	var reader := Settings.new(old_fixture)
	check(reader.values.shadow_size == "4096" and reader.values.quality == "beauty", "an old settings file in Beauty gets 4096 and stays Beauty (%s, %s)" % [reader.values.shadow_size, reader.values.quality])
	check(Settings.new("res://.godot/optimisation-new-%d.json" % Time.get_ticks_usec()).values.shadow_size == "2048", "new player on PC: 2048 (Balanced)")
	# --- Mipmaps des feuilles, de l'écorce et des plantes ---
	var mipmaps := true
	for name in ["feuilles_noisetier", "feuilles_pin", "feuilles_pommier", "feuilles_tilleul", "ecorce_noisetier", "ecorce_pin", "ecorce_pommier", "ecorce_tilleul"]:
		mipmaps = mipmaps and FileAccess.get_file_as_string("res://assets/trees/%s.png.import" % name).contains("mipmaps/generate=true")
	check(mipmaps, "tree leaf and bark images have mipmaps")
	# --- Shader du sol : détails fins remplacés par leur moyenne au loin ---
	var shader_text := FileAccess.get_file_as_string("res://shaders/terrain_surface.gdshader")
	check(shader_text.contains("const float FINE_NEAR = 14.0;") and shader_text.contains("fine_step(0.71, 0.91, p*34.0, earth_fine, 0.0526)") and shader_text.contains("float earth_fine = simple_look ? 0.0 : fine_fade;"), "ground shader: fine details averaged beyond 14 to 24 m (Performance unchanged up close)")
	# --- Fils de calcul : colonne oubliée une fois calculée ---
	var terrain := SmoothTerrain.new()
	terrain.setup(78, WorldScript.flat_spots(), Generation.defaults(), false)
	terrain.prepare_step(1 << 40)
	var before := terrain._heights.size()
	var result: Dictionary = TerrainWorkers._column(terrain, Vector2i(5, -3))
	check(result.heights.size() == 18 * 18 and terrain._heights.size() <= before + 40 and not terrain._surface_ys.has(Vector2i(5, -3)), "a worker copy forgets a column once computed (%d heights kept → %d)" % [before, terrain._heights.size()])
	check(TerrainWorkers.FORGET_AFTER == 40000, "worker copies empty their caches beyond 40 000 heights")
	# --- Dans le monde ---
	var fixture := "res://.godot/optimisation-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(fixture)
	app.catalog = Catalog.new(fixture + ".worlds")
	var made: Dictionary = app.catalog.create_world("Optimisation", "78")
	app.catalog.set_game_mode(made.id, Catalog.GAME_CREATIVE)
	root.add_child(app)
	current_scene = app
	await process_frame
	check(WorldScript.shadow_atlas == 2048, "the game applies the shadow map size of the settings (2048 in Balanced)")
	app.open_world(made.id)
	var world: Node3D = app.active_world
	world.finish_terrain()
	await process_frame
	# Fuite : une zone vide (haut dans le ciel) ne laisse plus d'objet jamais libéré.
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for y in range(20, 30):
		world.rebuild_terrain_piece(Vector3i(0, y, 0))
	await process_frame
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) == orphans, "empty terrain zones leave no orphan object (%d → %d)" % [orphans, Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	# Relevés du lointain : au-delà de 400, ceux loin de la vue sont oubliés.
	for index in range(world.FAR_SURVEYS_MAX + 20):
		world.far_surveys[Vector3i(500 + index, 500, 2)] = {"next": 0, "side": 1}
	var fresh := Vector2i(-3000, -3000)
	world._far_survey(fresh)
	var fakes_left: int = world.far_surveys.keys().filter(func(key: Vector3i): return key.x >= 500 and key.y == 500).size()
	check(fakes_left == 0 and world.far_surveys.size() < world.FAR_SURVEYS_MAX and world.far_surveys.has(Vector3i(fresh.x, fresh.y, int(world._far_cell(fresh)))), "far surveys: beyond 400, those far from the view are forgotten (%d kept, %d far ones left)" % [world.far_surveys.size(), fakes_left])
	# Diagnostic : masquer une sorte, couper un effet, essayer un réglage, tout remettre.
	var counts := Diagnostic.counts(world)
	check(counts.terrain > 0 and counts.herbe > 0 and counts.joueur > 0, "diagnostic: drawn things sorted (%s)" % str(counts))
	var shown_terrain: int = Diagnostic.sorted(world).terrain.filter(func(node): return node.visible).size()
	Diagnostic.show_sort(world, "terrain", false)
	var hidden_ok: bool = Diagnostic.sorted(world).terrain.all(func(node): return not node.visible)
	Diagnostic.set_effect(world, "brume", false)
	Diagnostic.set_effect(world, "sol_detaille", false)
	var effects_ok: bool = not world.environment.fog_enabled and world.TerrainMaterials.simple
	Diagnostic.restore_all(world)
	check(hidden_ok and effects_ok and Diagnostic.sorted(world).terrain.filter(func(node): return node.visible).size() == shown_terrain and world.environment.fog_enabled and not world.TerrainMaterials.simple, "diagnostic: hide, switch off, then everything back as before")
	check(Diagnostic.spot_target(world, "depart").size() == 2 and Diagnostic.spot_target(world, "foret").size() == 2 and Diagnostic.go_to_spot(world, "lac"), "diagnostic: measuring spots found (start, forest, lake)")
	# Console du Web : le script se charge et a ses commandes.
	var console: Script = load("res://scripts/web_diagnostic.gd")
	var methods := console.get_script_method_list().map(func(method): return method.name)
	check(["_help", "_go", "_hide", "_show", "_all", "_measure", "_state"].all(func(name): return name in methods), "Web measuring console: commands present")
	# --- Qualité conseillée sur un PC lent ---
	var hint: CanvasLayer = app.quality_hint
	check(hint != null and not hint.visible and not app.settings.quality_hint_done, "quality hint ready, not shown yet")
	check(not hint.decide(45.0), "a fast PC (45 images per second): no message")
	check(hint.decide(18.0) and hint.visible and paused and app.settings.quality_hint_done and FileAccess.get_file_as_string(app.settings.menus_path()).contains("\"qualite_conseillee\": true"), "a slow PC (18 images per second): the message, game paused, remembered in menus.json")
	check(hint.message.text.contains("18 images par seconde") and hint.keep_button.text == "Garder Équilibré", "message: measured speed and current quality")
	hint.choose(true)
	await process_frame
	check(app.settings.values.quality == "performance" and app.settings.values.shadow_size == "1024" and not paused and not hint.visible and WorldScript.shadow_atlas == 1024, "« Passer en Performance »: quality and shadow map 1024 applied, game resumed")
	check(not hint.decide(10.0) and Settings.new(fixture).quality_hint_done, "never twice (also after a restart)")
	app.return_to_worlds()
	for path in [fixture, fixture + ".worlds", old_fixture]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d optimisation checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
