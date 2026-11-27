extends SceneTree
# 0.0.8.11 « Web plus rapide » (rapport de mesures Web 0.0.8.9) : plantes gardées par colonne (orties), lumières des orbes
# estompées au loin, terrain et petits objets sans ombre projetée, collisions de toutes les tiges des noisetiers, retour au
# point de départ construit tout de suite, fabrication et inventaire préparés d'avance, fond de la fabrication, plantes
# avec mipmaps, chargement à 80 ms par image.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const ReturnOrb = preload("res://scripts/return_orb.gd")
const CraftingUI = preload("res://scripts/crafting_ui.gd")
const TreeParts = preload("res://scripts/tree_parts.gd")
const Trees = preload("res://scripts/trees.gd")
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
	var fixture := "res://.godot/web-speed-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(fixture)
	app.catalog = Catalog.new(fixture + ".worlds")
	var made: Dictionary = app.catalog.create_world("Vitesse", "78")
	app.catalog.set_game_mode(made.id, Catalog.GAME_CREATIVE)
	root.add_child(app)
	current_scene = app
	await process_frame
	app.open_world(made.id)
	for i in range(600):
		if app.page == "playing":
			break
		await process_frame
	var world: Node3D = app.active_world
	world.finish_terrain()
	# Plantes d'une colonne gardées (orties toutes les 0,5 s, visée) : la même liste, sans la refaire.
	var column: Vector2i = world._player_column()
	var first: Array = world.plants_near(column)
	check(world.plants_near(column) == first and str(first) == str(world.terrain.plants_in_zone(column)), "plants of a column kept (same list as the seed's)")
	# Lumière d'une orbe posée : estompée au loin.
	var light: OmniLight3D = ReturnOrb.light()
	check(light.distance_fade_enabled and light.distance_fade_begin == ReturnOrb.LIGHT_FADE_BEGIN and light.distance_fade_begin + light.distance_fade_length <= 30.0, "orb light fades out beyond about 28 m")
	light.free()
	# Terrain : reçoit les ombres ; 0.0.8.51 : n'en projette que pour les feux et les torches (sa couche n'est pas dans les
	# ombres du soleil : léger comme en 0.0.8.11).
	var casting := 0
	for zone in world.terrain_pieces:
		var piece: Node = world.terrain_pieces[zone]
		for child in piece.get_children():
			if child is GeometryInstance3D and child.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and (child.layers & world.sun_light.shadow_caster_mask) != 0:
				casting += 1
	check(not world.terrain_pieces.is_empty() and casting == 0, "terrain pieces cast no sun shadow (%d pieces)" % world.terrain_pieces.size())
	# Noisetiers : toutes les tiges solides (jusqu'à 11), avant les branches basses.
	var all_stems := true
	for size in range(1, Trees.SIZES + 1):
		var stems := 0
		for piece: Dictionary in TreeParts.skeleton(Trees.HAZEL, size, 0).pieces:
			if piece.root and piece.tip.y > 0.5:
				stems += 1
		all_stems = all_stems and stems <= world.STEM_COLLISIONS_MAX
	check(all_stems and world.STEM_COLLISIONS_MAX == 12, "every hazel stem gets its collision (12 at most, stems first)")
	# Retour au point de départ : les 3 × 3 colonnes autour construites aussitôt.
	world.player.position = Vector3(300.0, 40.0, 300.0)
	for i in range(5):
		await process_frame
	world.go_home()
	var home: Vector2i = world._player_column()
	var around := true
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var spot := home + Vector2i(dx, dz)
			around = around and (world.built_columns.has(spot) or not world.shown_columns.has(spot))
	check(around and world.view_center == home, "back to the start: the 3 × 3 columns around are built at once")
	# Fabrication : créée d'avance possible, fond pris deux images plus tard, flou doux et lissé, panneau avec marge.
	world._prepare_crafting()
	var crafting: CanvasLayer = world.crafting_ui
	check(is_instance_valid(crafting) and CraftingUI.BACKGROUND_WAIT_FRAMES == 2 and crafting.background.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR and crafting.panel.get_parent() is MarginContainer, "crafting: ready ahead, background two images later, smooth, panel with margin")
	var shot := Image.create(1280, 720, false, Image.FORMAT_RGB8)
	shot.fill(Color(0.2, 0.5, 0.3))
	var blurred: Image = CraftingUI.soft_blur(shot)
	check(blurred.get_width() == 320 and blurred.get_height() == 180, "soft blur: an eighth then a quarter of the screen (%d × %d)" % [blurred.get_width(), blurred.get_height()])
	crafting.prewarm(true)
	world.inventory_ui.prewarm(true)
	check(crafting.visible and crafting.root.modulate.a < 0.01 and world.inventory_ui.screen.visible and world.inventory_ui.screen.modulate.a < 0.01, "prewarm: crafting and inventory drawn almost transparent")
	crafting.prewarm(false)
	world.inventory_ui.prewarm(false)
	check(not crafting.visible and crafting.root.modulate.a == 1.0 and not world.inventory_ui.screen.visible and world.inventory_ui.screen.modulate.a == 1.0, "then hidden and back to normal")
	world.open_crafting()
	await process_frame
	await process_frame
	await process_frame
	check(world.crafting_open and crafting.root.visible and crafting.root.modulate.a == 1.0, "crafting opens normally after the prewarm")
	# 0.0.8.12 (rapport Web 0.0.8.11) : la barre de la fabrication à la place de la barre du jeu (mêmes cases, même hauteur, centrée).
	await process_frame
	var hud: Rect2 = world.inventory_ui.hud_bar.get_global_rect()
	var own: Rect2 = crafting.slot_row.get_global_rect()
	check(absf(own.end.y - hud.end.y) < 1.0 and absf(own.size.y - hud.size.y) < 1.0 and (absf(own.get_center().x - hud.get_center().x) < 1.0 or absf(own.position.x - crafting.panel.get_global_rect().end.x - crafting.PANEL_MARGIN * crafting.text_scale) < 1.0), "crafting bar exactly where the game bar is (%s, game %s)" % [str(own), str(hud)])
	world.close_crafting(false)
	# Plantes : images avec mipmaps (plus de colonnes pixelisées au loin).
	var mipmaps := true
	for name in ["ortie", "lin", "herbe_longue", "liane"]:
		mipmaps = mipmaps and FileAccess.get_file_as_string("res://assets/plants/%s.png.import" % name).contains("mipmaps/generate=true")
	check(mipmaps, "plant images have mipmaps")
	# Résolution 3D : sans effet sous 100 % sur le Web (dans le code ; le test tourne sur PC).
	check(FileAccess.get_file_as_string("res://scripts/app_base.gd").contains("scaling_3d_scale = 1.0 if OS.has_feature(\"web\")"), "Web: 3D resolution always 100 %")
	app.return_to_worlds()
	for path in [fixture, fixture + ".worlds"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d web speed checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
