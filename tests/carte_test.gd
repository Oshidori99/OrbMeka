extends SceneTree
# 0.0.8.28 (#154, demandes de l'utilisateur) : la carte : mini-carte en haut à droite (l'heure et les coordonnées
# dessous), les zones chargées (explorées, sauvegardées), en 2D avec relief, l'eau en bleu, les arbres en points verts ;
# grande carte O + M avec « Tout voir » ; menu Carte dans les Paramètres ; léger (dessinée peu à peu).
const ItemIcons = preload("res://scripts/item_icons.gd")
const WorldMap = preload("res://scripts/world_map.gd")
const Controls = preload("res://scripts/controls.gd")
const UserSettings = preload("res://scripts/user_settings.gd")
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

# Deux couleurs pareilles une fois rangées dans l'image (8 bits par couleur).
func near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01

func frames(count: int) -> void:
	for index in range(count):
		await process_frame

func _run() -> void:
	check(Controls.ACTIONS.map.default.key == KEY_O and Controls.ACTIONS.map.default.second.key == KEY_M, "O + M opens the map")
	check(UserSettings.CHOICES.has("map_show") and UserSettings.CHOICES.map_size.default == "medium" and UserSettings.menu_of("map_zoom") == "video", "map settings (shown, size, zoom, orientation), saved with Vidéo")
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	var map = world.world_map
	check(map != null and map.pixels == roundi(world._half_zones() * 8.0 * 2.0 / WorldMap.METERS_PER_PIXEL), "a map of the whole world, 2 m per pixel (%d px)" % (map.pixels if map != null else 0))
	# Le joueur est là : ses carrés chargés deviennent explorés, puis se dessinent peu à peu.
	var spent := 0
	var longest := 0
	for index in range(400):
		var before := Time.get_ticks_usec()
		world._update_map(1.0 / 60.0)
		var took := Time.get_ticks_usec() - before
		longest = maxi(longest, took)
		spent += took
		if not map.busy():
			break
	check(map.explored.has(WorldMap.tile_of(world.player.global_position)) and map.explored.size() >= 9, "the loaded zones around the player are explored (%d squares of 32 m)" % map.explored.size())
	check(not map.busy() and map.drawn.size() >= map.explored.size(), "and drawn (%d squares, %.0f ms in all)" % [map.drawn.size(), spent / 1000.0])
	check(longest < 9000 or OS.get_environment("GITHUB_ACTIONS") == "true", "a little at a time: at most %.1f ms in a frame (the time is judged on the PC only)" % (longest / 1000.0))
	var here: Vector2 = map.pixel_of(world.player.global_position)
	var color: Color = map.seen.get_pixelv(Vector2i(here))
	check(not near(color, WorldMap.UNKNOWN) and color.a == 1.0, "the map shows the ground where the player is (%s)" % color.to_html(false))
	var far_pixel: Color = map.seen.get_pixelv(Vector2i(2, 2))
	check(near(far_pixel, WorldMap.UNKNOWN), "unexplored places stay dark (%s, %s, player %s)" % [far_pixel.to_html(), WorldMap.UNKNOWN.to_html(), str(here)])
	# Les arbres : des points verts (au moins un dans les carrés dessinés, s'il y a des arbres).
	var trees := 0
	for tile in map.drawn:
		for dx in range(4):
			for dz in range(4):
				trees += world.terrain.trees_in_zone(Vector2i(tile.x * 4 + dx, tile.y * 4 + dz)).size()
	var green := 0
	for tile in map.drawn:
		var origin := Vector2i(roundi((tile.x * WorldMap.TILE + map.half_meters) / 2.0), roundi((tile.y * WorldMap.TILE + map.half_meters) / 2.0))
		for x in range(16):
			for y in range(16):
				if near(map.seen.get_pixelv(origin + Vector2i(x, y)), WorldMap.TREE_COLOR):
					green += 1
	check(trees == 0 or green > 0, "trees as green dots (%d dots for %d trees)" % [green, trees])
	# L'eau en bleu (couleur du terrain lointain).
	check(WorldMap.UNKNOWN.b < 0.2, "water drawn in blue (terrain colors)")
	# Mini-carte en haut à droite, l'heure dessous.
	check(is_instance_valid(world.minimap) and world.minimap.visible and world.minimap.size.x >= 120.0 and world.clock_label.offset_top > world.minimap.offset_bottom, "minimap at the top right, the clock under it")
	world.set_map_options({"map_show": "on", "map_size": "large", "map_zoom": "4", "map_north": "turning"})
	check(is_equal_approx(world.minimap.size.x, 230.0) and not world.minimap.north_fixed and is_equal_approx(world.minimap.zoom, 4.0), "settings: large, close, turning")
	world.set_map_options({"map_show": "off"})
	check(not world.minimap.visible and world.clock_label.offset_top < 30.0, "hidden: the clock goes back to the top")
	world.set_map_options({"map_show": "on", "map_size": "medium", "map_zoom": "2", "map_north": "fixed"})
	# Grande carte.
	world.toggle_map()
	check(world.map_open and world.big_map_ui.visible and not world.minimap.visible, "O + M: the big map, over the game")
	world.big_map_ui.toggle_all()
	check(world.big_map_ui.show_all and map.busy() and map.all_wanted, "« Tout voir »: the whole world is drawn in the background")
	world.big_map_ui.toggle_all()
	check(not world.big_map_ui.show_all, "clicked again: only what was explored")
	world.toggle_map()
	check(not world.map_open and world.minimap.visible, "closed: the minimap is back")
	# Sauvegarde.
	var saved: Array = world.player_data().carte
	var again := WorldMap.new()
	again.setup(world.terrain, map.half_meters)
	again.from_array(saved)
	check(saved.size() == map.explored.size() and again.explored.size() == map.explored.size(), "explored squares saved and read again (%d)" % saved.size())
	# --- 0.0.8.35 (#252) : points de repère. M + R en jeu ; « Ajouter un repère » sur la grande carte, nommé ; enregistrés.
	check(Controls.ACTIONS.waypoint.default.key == KEY_M and Controls.ACTIONS.waypoint.default.second.key == KEY_R, "M + R places a waypoint")
	world.add_waypoint_here()
	check(map.waypoints.size() == 1 and map.waypoints[0].nom == "Repère 1" and absf(float(map.waypoints[0].x) - world.player.global_position.x) < 0.1, "M + R: « Repère 1 » where the player stands")
	world.toggle_map()
	world.big_map_ui.add_here()
	check(map.waypoints.size() == 2 and world.big_map_ui.chosen == 1 and world.big_map_ui.name_edit.has_focus(), "« Ajouter un repère » on the big map: a second one, chosen, its name to type")
	world.big_map_ui.name_edit.text = "Lac des pins"
	world.big_map_ui.name_edit.text_changed.emit("Lac des pins")
	check(map.waypoints[1].nom == "Lac des pins", "named as one likes")
	world.big_map_ui._choose(0)
	world.big_map_ui.remove_chosen()
	check(map.waypoints.size() == 1 and map.waypoints[0].nom == "Lac des pins", "« Supprimer » removes the chosen one")
	world.toggle_map()
	var kept: Array = world.player_data().reperes
	var read_again := WorldMap.new()
	read_again.waypoints_from_array(kept)
	check(read_again.waypoints.size() == 1 and read_again.waypoints[0].nom == "Lac des pins", "waypoints saved and read again")
	world.minimap.queue_redraw()
	await frames(2)
	# --- 0.0.8.35 : l'écran de jeu : plus d'aide à gauche ; ce qu'on vise avec son image ; rappel du carnet. ---
	check(not world.find_child("ExplorationNotice", true, false).visible, "no help on the left (it is in the notebook)")
	check(world.notebook_reminder.visible and world.notebook_reminder.text == "O + C : carnet de route", "a new world: « O + C : carnet de route » at the bottom")
	world.open_notebook()
	world.close_notebook()
	check(not world.notebook_reminder.visible and world.player_data().carnet_ouvert, "once the notebook was opened: gone for good in this world")
	check(world.looked_item({}) == "" and ItemIcons.texture("gazon") != null and ItemIcons.texture("terre") != null, "what is aimed at: a picture for each kind (turf, earth…)")
	# --- 0.0.8.39 (demandes de l'utilisateur) : « + » et nom en bas à droite, couleur au choix, Échap ferme la carte. ---
	world.toggle_map()
	var tools: Control = world.big_map_ui.find_child("Reperes", true, false)
	check(tools != null and world.big_map_ui.add_button.text == "+" and world.big_map_ui.add_button.get_index() + 1 == world.big_map_ui.name_edit.get_index(), "bottom right: « + », then the name to its right")
	world.big_map_ui._choose(0)
	world.big_map_ui.set_color(3)
	check(map.waypoints[0].couleur == 3 and world.big_map_ui.color_buttons.size() == WorldMap.WAYPOINT_COLORS.size(), "the colour of a waypoint can be chosen")
	world.toggle_map()
	world.queue_free()
	await frames(2)
	print("RESULT: %d map checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
