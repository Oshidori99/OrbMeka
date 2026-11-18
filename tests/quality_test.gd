extends SceneTree
# 0.0.7.21 : Paramètres → Vidéo → Qualité d'affichage : Performance, Équilibré (défaut sur PC), Beauté (l'affichage d'avant),
# Personnalisé dès qu'un réglage ne correspond plus ; ombres et anticrénelage appliqués au jeu.
const Settings = preload("res://scripts/user_settings.gd")
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
	var fixture := "res://.godot/quality-test-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	check(settings.values.quality == "balanced" and settings.values.grass_density == "reduced" and settings.values.shadows == "medium" and settings.values.antialiasing == "on" and settings.values.view_distance == 8.0 and settings.values.grass_zones == 4.0, "PC defaults: Équilibré (reduced grass, medium shadows, same distances)")
	var web := {}
	for key in Settings.SPECS:
		web[key] = Settings.default_of(key, true)
	for key in Settings.CHOICES:
		web[key] = Settings.choice_default(key, true)
	check(web.quality == "performance" and Settings.matching_preset(web, true) == "performance" and web.view_distance == 5.0, "Web defaults: Performance with the short Web distances")
	check(Settings.PRESETS.beauty.grass_density == "medium" and Settings.PRESETS.beauty.shadows == "far" and Settings.PRESETS.beauty.view_distance == 16.0 and Settings.PRESETS.beauty.far_extra == 24.0, "Beauté: the look of before (medium grass, shadows to 64 m), 16 zones and +24 since 0.0.7.22")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = load("res://scripts/world_catalog.gd").new(fixture + ".worlds")
	root.add_child(app)
	current_scene = app
	await process_frame
	app.show_page("settings")
	app.show_settings_section("video")
	await process_frame
	var keys: Array = app.GENERAL_CATEGORIES.video["Jeu"].keys
	check(keys[0] == "quality" and keys.has("shadows") and keys.has("antialiasing") and app.choice_buttons.quality.size() == 4, "quality first in Vidéo → Jeu, four buttons, then shadows and antialiasing")
	app._choose("quality", "performance")
	check(settings.values.quality == "performance" and settings.values.grass_density == "low" and settings.values.shadows == "near" and settings.values.antialiasing == "off" and settings.values.view_distance == 6.0 and app.setting_fields.view_distance.text == Settings.number_text(6.0) and app.choice_buttons.shadows.near.button_pressed, "Performance sets every quality setting, shown at once")
	check(app.get_viewport().msaa_3d == Viewport.MSAA_DISABLED, "Performance turns antialiasing off")
	app._choose("quality", "beauty")
	check(settings.values.quality == "beauty" and settings.values.grass_density == "medium" and settings.values.shadows == "far" and settings.values.view_distance == 16.0 and settings.values.far_extra == 24.0 and app.get_viewport().msaa_3d == Viewport.MSAA_2X, "Beauté sets the look of before")
	app._choose("shadows", "near")
	check(settings.values.quality == "custom" and app.choice_buttons.quality.custom.button_pressed and settings.values.shadows == "near", "changing one setting by hand: Personnalisé")
	app._choose("shadows", "far")
	check(settings.values.quality == "beauty", "back to the preset values: Beauté again")
	# Distance lointaine en plus de la distance d'affichage (« +16 »), demande de l'utilisateur.
	app._choose("quality", "balanced")
	check(app.setting_fields.far_extra.text == "+16" and app.setting_sliders.far_extra.value == 16.0, "far distance shown as what it adds: +16")
	app.setting_fields.far_extra.text = "+20"
	app.apply_user_settings()
	check(settings.values.far_extra == 20.0 and app.setting_fields.far_extra.text == "+20" and settings.values.quality == "custom", "typing +20 works (Personnalisé)")
	app._choose("quality", "balanced")
	var reread := Settings.new(fixture)
	check(reread.values.quality == "balanced" and reread.values.grass_density == "reduced" and reread.values.shadows == "medium", "quality saved and read back")
	# Ancien fichier (avant 0.0.7.21) : herbe moyenne, sans ombres ni qualité : ombres moyennes par défaut, donc ni Beauté
	# ni Équilibré : Personnalisé.
	var old_file := FileAccess.open(reread.file_path("video"), FileAccess.WRITE)
	old_file.store_string(JSON.stringify({"grass_density": "medium", "view_distance": 16.0, "far_distance": 32.0}))
	old_file.close()
	var old_values: Dictionary = Settings.new(fixture).values
	check(old_values.quality == "custom" and old_values.far_extra == 16.0 and old_values.view_distance == 16.0, "an old file: far distance 32 with view 16 reads as +16 ; Personnalisé")
	# Ombres dans le jeu.
	app.settings.apply_texts(app.settings.values.merged({"shadows": "near", "quality": "custom"}, true))
	app.open_world(app.catalog.create_world("Qualité", "8").id)
	await process_frame
	check(app.active_world.shadow_quality == "near" and is_equal_approx(app.active_world.sun_light.directional_shadow_max_distance, 32.0) and app.active_world.sun_light.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL, "near shadows: 32 m, one level")
	app.active_world.set_shadows("far")
	check(is_equal_approx(app.active_world.sun_light.directional_shadow_max_distance, 64.0) and app.active_world.sun_light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "far shadows: 64 m, two levels (as before)")
	# 0.0.7.23 : Performance sur le Web : sans ombres, herbe très basse ; « Aucune » coupe les ombres du soleil.
	var web_performance: Dictionary = Settings.preset_values("performance", true)
	check(web_performance.shadows == "off" and web_performance.grass_density == "minimal" and Settings.preset_values("performance", false).shadows == "near", "Performance on the Web: no shadows, very low grass (PC: near shadows)")
	app.active_world.set_shadows("off")
	check(not app.active_world.sun_light.shadow_enabled and app.active_world.shadow_quality == "off", "shadows « Aucune »: the sun casts none")
	app.active_world.set_shadows("medium")
	check(app.active_world.sun_light.shadow_enabled, "shadows back on")
	# 0.0.7.24 : ancienne Performance du Web reprise en nouvelle ; sol simplifié et herbe appliqués tout de suite en jeu.
	var old_web := Settings.OLD_WEB_PERFORMANCE.duplicate()
	check(Settings.upgrade_web(old_web, true) and old_web.shadows == "off" and old_web.grass_density == "minimal" and Settings.matching_preset(old_web, true) == "performance", "old Web Performance settings become the new Performance")
	var custom_web := Settings.OLD_WEB_PERFORMANCE.duplicate()
	custom_web.shadows = "far"
	check(not Settings.upgrade_web(custom_web, true) and not Settings.upgrade_web(Settings.OLD_WEB_PERFORMANCE.duplicate(), false), "changed by the player, or on PC: kept as is")
	app.active_world.set_simple_ground(true)
	check(app.active_world.block_material.get_shader_parameter("simple_look") == true, "simple ground applied at once in game")
	app.active_world.set_simple_ground(false)
	check(app.active_world.block_material.get_shader_parameter("simple_look") == false, "and back")
	var tiles: int = app.active_world.lawn_tiles.size()
	app.active_world.set_grass_density("minimal")
	check(app.active_world.grass_density == "minimal" and app.active_world.lawn_tiles.size() == tiles, "grass density applied at once (lawn rebuilt)")
	# 0.0.7.24 : sur le Web, Équilibré et Beauté moins loin, résolution 3D 75 % (Performance 60 %) ; appliquée tout de suite.
	var web_balanced: Dictionary = Settings.preset_values("balanced", true)
	var web_beauty: Dictionary = Settings.preset_values("beauty", true)
	check(web_balanced.view_distance == 6.0 and web_balanced.far_extra == 10.0 and web_beauty.view_distance == 8.0 and web_beauty.far_extra == 16.0 and web_beauty.resolution_3d == 100.0 and web_performance.resolution_3d == 100.0 and Settings.preset_values("beauty", false).view_distance == 16.0, "Web: Équilibré 6/+10, Beauté 8/+16, 3D resolution 100 % (0.0.7.25); PC unchanged")
	# 0.0.7.25 : préréglages Web de 0.0.7.24 (60 ou 75 %) repris à 100 %.
	var old_24: Dictionary = Settings.preset_values("balanced", true)
	old_24.resolution_3d = 75.0
	check(Settings.upgrade_web(old_24, true) and old_24.resolution_3d == 100.0 and Settings.matching_preset(old_24, true) == "balanced", "0.0.7.24 Web presets (75 %) back to 100 %")
	app.settings.apply_texts(app.settings.values.merged({"resolution_3d": "60"}, true))
	app.apply_appearance()
	check(is_equal_approx(app.get_viewport().scaling_3d_scale, 0.6), "3D resolution applied (60 %)")
	app.settings.apply_texts(app.settings.values.merged({"resolution_3d": "100"}, true))
	app.apply_appearance()
	print("RESULT: %d quality checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
