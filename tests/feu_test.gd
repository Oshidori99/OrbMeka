extends SceneTree
# 0.0.8.44 (#214, #209, demandes de l'utilisateur) : écorce, archet à feu, feu de camp, torches.
# - Écorcer un bâton de pin : de l'écorce de pin ; un pin debout (« Récupérer des matériaux », hache) : de l'écorce de pin.
# - O + F : Monter un feu (4 cailloux, un bâton, de l'amadou), Faire un archet (branche souple + cordelette), Faire une
#   torche (bâton + 3 fibres ; + écorce de pin : torche forte).
# - Le feu posé, allumé à l'archet (clic droit maintenu 10 s), nourri au charbon ; la torche allumée au feu : sa lumière
#   en main ; elle brûle 10 h (forte : 5 h, 2 fois plus de lumière et de portée), puis devient un bâton brûlé ; un feu
#   sans bois s'éteint. Enregistré.
const Inventory = preload("res://scripts/inventory.gd")
const Rules = preload("res://scripts/crafting_rules.gd")
const Fire = preload("res://scripts/fire.gd")
const Trees = preload("res://scripts/trees.gd")
const ItemIcons = preload("res://scripts/item_icons.gd")
const DayNight = preload("res://scripts/day_night.gd")
const SmoothTerrain = preload("res://scripts/smooth_terrain.gd")
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

func frames(count: int) -> void:
	for index in range(count):
		await process_frame
		await physics_frame

func count_of(world: Node3D, id: String) -> int:
	return Rules.owned(world.inventory, id)

func _run() -> void:
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await frames(10)
	world.player.set_physics_process(false)
	world.set_game_mode(Inventory.SURVIVAL)
	var inv: RefCounted = world.inventory
	for index in Inventory.HANDS + Inventory.POCKETS:
		inv.put("bar", index, {})
	# Les objets : images, catalogue, durées.
	for id in ["ecorce", "ecorce_pin", "archet", "feu_camp", "torche", "torche_forte"]:
		check(Inventory.ITEMS.has(id) and ItemIcons.texture(id) != null, "%s: an item with its picture" % id)
	check(Fire.FIRE_RANGE > Fire.TORCH_RANGE.torche and Fire.FIRE_ENERGY > Fire.TORCH_ENERGY.torche and is_equal_approx(Fire.TORCH_MINUTES.torche, 600.0) and is_equal_approx(Fire.TORCH_MINUTES.torche_forte, 300.0) and is_equal_approx(Fire.TORCH_RANGE.torche_forte, 2.0 * Fire.TORCH_RANGE.torche) and is_equal_approx(Fire.TORCH_ENERGY.torche_forte, 2.0 * Fire.TORCH_ENERGY.torche), "torch: 10 h, 8 m ; strong torch: 5 h, twice the light and the reach ; the campfire lights more than a torch")
	check(Rules.bark_piece({"objet": "branche", "essence": Trees.PINE}).objet == "ecorce_pin" and Rules.bark_piece({"objet": "branche", "essence": Trees.APPLE}).objet == "ecorce", "barking pine wood gives pine bark (resinous) ; other wood: bark")
	# Fabrication dans O + F (Survie, avec ce qu'on porte).
	world.toggle_crafting()
	await frames(2)
	var ui: CanvasLayer = world.crafting_ui
	# Le feu : 4 cailloux, un bâton, 3 fibres.
	inv._store().bar[Inventory.POCKETS[0]] = {"objet": "caillou", "pile": [{"taille": 2}, {"taille": 2}, {"taille": 3}, {"taille": 2}]}
	inv._store().bar[Inventory.POCKETS[1]] = {"objet": "fibre_lin", "pile": [{}, {}, {}, {}, {}, {}, {}, {}, {}]}
	inv._store().bar[Inventory.HANDS[0]] = {"objet": "branche", "pile": [{"essence": 1, "epaisseur": 3.0, "fin": 2.5, "longueur": 0.6, "poids": 300.0}]}
	ui.choose_action("feu")
	ui.pick("pierres", Rules.fire_choices(inv, "pierres")[0])
	ui.pick("bois_feu", Rules.more_choices(inv, "bois_feu")[0])
	ui.pick("amadou", Rules.fire_choices(inv, "amadou")[0])
	check(ui.make_fire() and count_of(world, "feu_camp") == 1 and count_of(world, "caillou") == 0 and count_of(world, "fibre_lin") == 6, "Monter un feu: 4 pebbles, a stick and 3 fibres make a campfire")
	# L'archet : une branche souple et une cordelette.
	var fire_kit: Dictionary = inv.take("bar", Inventory.HANDS[0]) if inv.item("bar", Inventory.HANDS[0]).get("objet") == "feu_camp" else {}
	for place in Rules.places(inv):
		if inv.item(place[0], place[1]).get("objet") == "feu_camp":
			fire_kit = inv.take(place[0], place[1])
	inv._store().bar[Inventory.HANDS[0]] = {"objet": "branche", "pile": [{"essence": 1, "epaisseur": 1.8, "fin": 1.4, "longueur": 0.7, "poids": 120.0}]}
	inv._store().bar[Inventory.HANDS[1]] = {"objet": "cordelette_lin", "pile": [{"longueur": 0.33}]}
	ui.choose_action("archet")
	ui.pick("arc", Rules.more_choices(inv, "arc")[0])
	ui.pick("corde_arc", Rules.more_choices(inv, "corde_arc")[0])
	check(ui.make_bow() and count_of(world, "archet") == 1 and count_of(world, "cordelette_lin") == 0, "Faire un archet à feu: a supple branch and a cord")
	# La torche forte : bâton, 3 fibres, écorce de pin.
	var bow: Dictionary = {}
	for place in Rules.places(inv):
		if inv.item(place[0], place[1]).get("objet") == "archet":
			bow = inv.take(place[0], place[1])
	inv._store().bar[Inventory.HANDS[0]] = {"objet": "branche", "pile": [{"essence": 2, "epaisseur": 3.0, "fin": 2.6, "longueur": 0.55, "poids": 260.0}]}
	inv._store().bar[Inventory.HANDS[1]] = {"objet": "ecorce_pin", "pile": [{}]}
	ui.choose_action("torche")
	ui.pick("baton_torche", Rules.more_choices(inv, "baton_torche")[0])
	ui.pick("meche", Rules.wick_choices(inv)[0])
	ui.picks.resine_aide = Rules.aid_choices(inv, "resine")[0]
	check(ui.make_torch() and count_of(world, "torche_forte") == 1 and count_of(world, "ecorce_pin") == 0 and count_of(world, "fibre_lin") == 3, "Faire une torche with pine bark: a strong torch")
	world.toggle_crafting()
	await frames(2)
	# Le feu posé devant soi, allumé à l'archet.
	var torch: Dictionary = {}
	for place in Rules.places(inv):
		if inv.item(place[0], place[1]).get("objet") == "torche_forte":
			torch = inv.take(place[0], place[1])
	var spot: Vector3 = world.player.global_position + Vector3(1.6, 0.0, 0.0)
	spot.y = world._rest_height(spot)
	var fire_index: int = world.ground.drop(Inventory.flat("feu_camp", fire_kit.pile[0]), spot + Vector3.UP * 0.2, spot, world._rest_height, 0.0)
	for wait in range(60):
		if not world.ground.entries[fire_index].has("hidden"):
			break
		await frames(1)
	await frames(8)
	var body: Node3D = world.ground.bodies[fire_index]
	world.player.camera.look_at(body.global_position + Vector3.UP * 0.1)
	await frames(2)
	check(world.aimed_fire() == fire_index, "the campfire on the ground can be aimed at")
	inv.put("bar", Inventory.HANDS[0], bow)
	inv.select(Inventory.HANDS[0])
	check(world.hold_use() == "allumer", "bow in hand, aiming at the fire: right click held lights it")
	world.eat_press()
	for step in range(110):
		world.step_eat(0.1, true)
	var fire: Dictionary = world.ground.entries[fire_index].item
	check(Fire.is_lit(fire) and float(fire.brule) > 100.0, "after 10 s: the fire burns (%s left)" % Inventory.burn_text(float(fire.get("brule", 0.0))))
	await frames(3)
	check(world.ground._glows.size() >= 1 and world.ground._glows[0][0].omni_range == Fire.FIRE_RANGE, "the fire lights around it")
	# 0.0.8.45 : un clic droit court nourrit (avant : il fallait maintenir).
	inv._store().bar[Inventory.HANDS[0]] = {"objet": "branche", "pile": [{"essence": 1, "epaisseur": 3.0, "longueur": 0.5, "poids": 250.0}]}
	var quick_before: float = float(world.ground.entries[fire_index].item.brule)
	world.eat_press()
	check(float(world.ground.entries[fire_index].item.brule) > quick_before + 50.0 and inv.item("bar", Inventory.HANDS[0]).is_empty(), "a quick right click with a stick feeds the fire (+1 h)")
	# Nourrir au charbon.
	inv._store().bar[Inventory.HANDS[0]] = {"objet": "charbon", "pile": [{}]}
	var before: float = float(world.ground.entries[fire_index].item.brule)
	world.eat_press()
	for step in range(10):
		world.step_eat(0.1, true)
	check(float(world.ground.entries[fire_index].item.brule) > before + 170.0 and inv.item("bar", Inventory.HANDS[0]).is_empty(), "coal makes it burn 3 h more")
	# La torche allumée au feu : sa lumière en main.
	inv.put("bar", Inventory.HANDS[0], torch)
	world.eat_press()
	for step in range(15):
		world.step_eat(0.1, true)
	var held: Dictionary = inv.held()
	var lit_torch: Dictionary = Inventory.flat(held.objet, held.pile[-1])
	check(held.objet == "torche_forte" and Fire.is_lit(lit_torch) and is_equal_approx(float(lit_torch.brule), 300.0) and Inventory.item_name(held).begins_with("Torche forte allumée"), "the strong torch lit at the fire: 5 h of light")
	world._update_fire(1.1)
	check(is_instance_valid(world.hand_light) and world.hand_light.visible and is_equal_approx(world.hand_light.omni_range, Fire.TORCH_RANGE.torche_forte), "its light in the hand (16 m)")
	# 0.0.8.51 (lot Ombres) : la nuit, la torche tenue et le feu font des ombres (le terrain en fait pour eux, pas pour le
	# soleil) ; pas en plein jour dehors ; aucune avec « Ombres : Aucune ».
	world.day_time = 60.0
	world.set_shadows("medium")
	var fire_light: OmniLight3D = world.ground._glows[0][0]
	var fill: OmniLight3D = world.hand_light.get_node_or_null("Rebond")
	check(world.hand_light.shadow_enabled and fire_light.shadow_enabled and fill != null and fill.visible, "at night: the torch in hand and the fire cast shadows, with a little light bounced back (« Rebond »)")
	check(world.hand_light.shadow_caster_mask & Fire.BODY_SHADOW_LAYER == 0 and fire_light.shadow_caster_mask & Fire.BODY_SHADOW_LAYER != 0, "the held torch makes no shadow of the player's own body (the fire does)")
	var piece: Node3D = world.terrain_pieces.values()[0]
	var drawn: MeshInstance3D = piece.get_child(0)
	check(drawn.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and drawn.layers == world.TERRAIN_SHADOW_LAYER and world.sun_light.shadow_caster_mask & world.TERRAIN_SHADOW_LAYER == 0, "the ground casts shadows for fires and torches, not for the sun (light 0.0.8.11)")
	world.day_time = 720.0
	world.sky_open = 1.0
	world._apply_light_shadows()
	check(not world.hand_light.shadow_enabled and not fire_light.shadow_enabled, "in full daylight outside: no fire or torch shadows (not seen under the sun)")
	world.day_time = 60.0
	world.set_shadows("off")
	check(not world.hand_light.shadow_enabled and not fire_light.shadow_enabled, "« Ombres : Aucune » : none at all")
	world.set_shadows("medium")
	world.warm_left = 0
	world.day_count = int(round((0.5 - DayNight.MOON_START) * 28.0))
	world.apply_day_light()
	var full_moon: bool = world.sun_light.shadow_enabled
	world.day_count = int(round((1.0 - DayNight.MOON_START) * 28.0))
	world.apply_day_light()
	check(full_moon and not world.sun_light.shadow_enabled, "the full moon casts shadows, the new moon does not")
	world.day_time = 720.0
	world.apply_day_light()
	# Elle brûle, puis devient un bâton brûlé ; le feu sans bois s'éteint.
	var burnt := Fire.burn(lit_torch, 400.0)
	check(burnt.objet == "branche" and int(burnt.brulee) == 1 and Inventory.item_name(burnt) == "Bâton brûlé", "burnt out: a burnt stick")
	check(not Fire.is_lit(Fire.burn({"objet": "feu_camp", "allume": 1, "brule": 10.0}, 20.0)), "a fire with nothing left to burn goes out")
	var left_before: float = float(lit_torch.brule)
	world._burn_wait = 0.0
	world._update_fire(0.0)
	var after: Dictionary = Inventory.flat(inv.held().objet, inv.held().pile[-1])
	check(float(after.brule) < left_before, "a lit torch burns in the hand (%s left)" % Inventory.burn_text(float(after.brule)))
	# Enregistré : la torche allumée (joueur), le feu (objets du monde).
	var saved := Inventory._read(Inventory.single(after))
	check(int(saved.pile[0].get("allume", 0)) == 1 and float(saved.pile[0].get("brule", 0.0)) > 0.0, "a lit torch is saved lit, with its time left")
	var array: Array = world.ground.to_array()
	check(array.any(func(entry): return entry.objet.get("objet") == "feu_camp" and int(entry.objet.pile[0].get("allume", 0)) == 1 if entry.objet.has("pile") else int(entry.objet.get("allume", 0)) == 1), "the lit fire is saved with the world")
	# Un pin debout : de l'écorce de pin avec une hache.
	var pine: Node3D = Trees.tree_body(Trees.PINE, 3)
	pine.set_meta("id", "feu-pin")
	var column: Vector2i = world._player_column()
	pine.set_meta("column", column)
	world._rocks_parent().add_child(pine)
	var foot: Vector3 = world.player.global_position + Vector3(-1.4, 0.0, 0.0)
	pine.global_position = Vector3(foot.x, world.terrain.height_at(foot.x, foot.z) - 0.05, foot.z)
	world.column_objects[column] = world.column_objects.get(column, []) + [pine]
	await frames(3)
	world.player.camera.look_at(pine.global_position + Vector3.UP * 1.2)
	await frames(2)
	inv._store().bar[Inventory.HANDS[0]] = {"objet": "hache_pierre", "pile": [{"pierre": 1, "taille": 5, "essence": 1, "epaisseur": 3.5, "longueur": 0.6, "lien": 1, "tours": 8, "poids": 870.0}]}
	inv._store().bar[Inventory.HANDS[1]] = {}
	inv.select(Inventory.HANDS[0])
	var bark_before := count_of(world, "ecorce_pin")
	var got := false
	for step in range(50):
		got = world.step_gather(0.1, true) or got
	check(got and count_of(world, "ecorce_pin") == bark_before + 1 and is_instance_valid(pine) and not world._tree_is_lying(pine), "a standing pine: pine bark with an axe (4 s), the tree stays")
	# 0.0.8.51 : une torche posée dans une galerie creusée à 6 m sous terre : dessinée au fond, sa lumière aussi (avant :
	# le bois sous terre était dessiné sur le sol du dessus).
	var room: Vector3 = world.player.global_position + Vector3(4.0, 0.0, 3.0)
	var floor_point := SmoothTerrain.point_of(Vector3(room.x, world.terrain.height_at(room.x, room.z) - 6.0, room.z))
	var dug := []
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			for dy in range(0, 5):
				var point := floor_point + Vector3i(dx, dy, dz)
				if world.terrain.density(point) > 0.0:
					world.terrain.set_density(point, SmoothTerrain.DUG)
					dug.append(point)
	world._refresh_terrain(dug)
	world.finish_terrain()
	await frames(10)
	var bottom := Vector3(floor_point) * SmoothTerrain.STEP
	var torch_index: int = world.ground.drop({"objet": "torche", "essence": 1, "epaisseur": 3.0, "fin": 2.6, "longueur": 0.55, "allume": 1, "brule": 600.0, "poids": 260.0}, bottom + Vector3.UP * 0.3, bottom, world._rest_height, 0.0)
	var placed: Dictionary = world.ground.entries[torch_index]
	var drawn_at: Transform3D = world.ground.place_of(placed, Basis())
	check(absf(drawn_at.origin.y - placed.position.y) < 0.3 and placed.position.y < bottom.y + 0.3, "a torch put down in a gallery 6 m underground is drawn on its floor (%.2f m, floor %.2f m)" % [drawn_at.origin.y, bottom.y])
	world.queue_free()
	await frames(2)
	print("RESULT: %d fire checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
