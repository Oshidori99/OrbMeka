extends SceneTree
# 0.0.8.15 (#239, #238, demandes de l'utilisateur) : plantes entières et gazon dans l'inventaire (arracher, planter,
# repousse, motte de gazon, enregistrés) ; onglet Plantes du Créatif ; molette : prendre l'objet visé en main.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Fibers = preload("res://scripts/fibers.gd")
const ItemIcons = preload("res://scripts/item_icons.gd")
const Controls = preload("res://scripts/controls.gd")
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

# Un coup de regard imité : le sol (un corps du groupe « ground ») en x, z.
func ground_hit(world: Node3D, x: float, z: float) -> Dictionary:
	var floor_body: Node = world.get_tree().get_nodes_in_group("ground")[0]
	return {"collider": floor_body, "position": Vector3(x, world.terrain.height_at(x, z), z), "normal": Vector3.UP}

func _run() -> void:
	var plants_tab: Dictionary = Inventory.CATEGORIES.filter(func(category): return category.id == "plants")[0]
	check(plants_tab.objets.slice(0, 4) == ["plante_ortie", "plante_lin", "plante_herbe", "gazon"], "Créatif, Plantes tab: three whole plants and turf first")
	check(["plante_ortie", "plante_lin", "plante_herbe", "gazon"].all(func(id): return ItemIcons.texture(id) != null and float(Inventory.ITEMS[id].poids) > 0.0), "icons and weights")
	check(Controls.ACTIONS.has("pick_aimed") and Controls.ACTIONS.pick_aimed.default.mouse == MOUSE_BUTTON_MIDDLE, "middle click: take the aimed object (modifiable)")
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/plantes-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = Settings.new(fixture)
	app.catalog = Catalog.new(fixture + ".worlds")
	var made: Dictionary = app.catalog.create_world("Plantes", "78")
	app.catalog.set_game_mode(made.id, Catalog.GAME_SURVIVAL)
	root.add_child(app)
	current_scene = app
	await process_frame
	app.open_world(made.id)
	for i in range(5):
		await process_frame
	var world: Node3D = app.active_world
	world.finish_terrain()
	# Deux plantes de la graine près du départ.
	var found: Array = []
	for radius in range(0, 14):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if found.size() < 2 and maxi(absi(x), absi(z)) == radius:
					for plant: Dictionary in world.terrain.plants_in_zone(Vector2i(x, z)):
						if found.size() < 2:
							found.append([plant, Vector2i(x, z)])
	check(found.size() == 2, "two fibre plants found")
	var first: Dictionary = found[0][0]
	world.player.global_position = Vector3(first.x - 1.2, world.terrain.height_at(first.x, first.z) + 0.05, first.z)
	world.update_zones(world.player_coordinates(), true)
	await process_frame
	# Arracher (mode « Casser / Arracher ») : la plante disparaît, elle tombe au sol.
	var id := Fibers.plant_id(first)
	var on_ground: int = world.ground.entries.size()
	world.pull_plant({"kind": "plante", "plant": first, "id": id, "column": found[0][1]}, false)
	check(world.removed_plants.has(id) and not world.column_plants(found[0][1]).any(func(plant): return Fibers.plant_id(plant) == id), "pulled: gone from the world")
	check(world.ground.entries.size() == on_ground + 1 and str(world.ground.entries[-1].item.objet).begins_with("plante_"), "pulled with « Casser / Arracher »: the whole plant on the ground")
	# Arracher (mode « Casser / Récupérer des objets ») : dans la main.
	var second: Dictionary = found[1][0]
	world.inventory.put("bar", world.inventory.selected(), {})
	world.pull_plant({"kind": "plante", "plant": second, "id": Fibers.plant_id(second), "column": found[1][1]}, true)
	var held: Dictionary = world.inventory.held()
	check(str(held.get("objet", "")).begins_with("plante_"), "pulled with « Casser / Récupérer des objets »: in hand (%s)" % str(held.get("objet", "")))
	# Planter : clic droit « Poser » sur la terre ou l'herbe.
	var spot := Vector3(world.player.global_position.x + 1.0, 0.0, world.player.global_position.z + 0.3)
	world.inventory.put("bar", world.inventory.selected(), {"objet": "plante_lin", "pile": [{}]})
	var planted_ok: bool = world.plant_held(ground_hit(world, spot.x, spot.z))
	var column: Vector2i = world.plant_column(spot.x, spot.z)
	var planted: Array = world.column_plants(column).filter(func(plant): return plant.has("id"))
	check(planted_ok and world.planted_plants.size() == 1 and planted.size() == 1 and int(planted[0].plante) == 1 and world.inventory.held().is_empty(), "planted: a flax plant grows there, the hand is empty")
	# Coupée (R : fibres), elle repousse après PLANT_REGROW_SECONDS de jeu.
	var planted_id: String = str(planted[0].id)
	world.harvest({"kind": "plante", "plant": planted[0], "id": planted_id, "column": column})
	check(world.cut_plants.has(planted_id) and world.plant_regrow.has(planted_id), "cut (fibres): it will grow again")
	world._step_regrow(3.0)
	check(world.cut_plants.has(planted_id), "not yet")
	world.world_stats.temps_de_jeu = float(world.world_stats.get("temps_de_jeu", 0.0)) + world.PLANT_REGROW_SECONDS + 5.0
	world._step_regrow(3.0)
	check(not world.cut_plants.has(planted_id) and not world.plant_regrow.has(planted_id), "after %d s of play: grown again" % int(world.PLANT_REGROW_SECONDS))
	# Gazon : posé, l'herbe repousse (même sur un sol creusé).
	var turf_at := Vector3(spot.x - 0.6, 0.0, spot.z - 0.8)
	world._set_grass(Vector3(turf_at.x, world.terrain.height_at(turf_at.x, turf_at.z), turf_at.z), false)
	var at := Vector3(turf_at.x, world.terrain.height_at(turf_at.x, turf_at.z), turf_at.z)
	check(world._grass_skipped(at), "grass removed there")
	world.inventory.put("bar", world.inventory.selected(), {"objet": "gazon", "pile": [{}]})
	var laid: bool = world.lay_turf(ground_hit(world, turf_at.x, turf_at.z))
	check(laid and not world.turf_cells.is_empty() and not world._grass_skipped(at) and world.inventory.held().is_empty(), "turf laid: grass grows back")
	# Enregistré.
	world.objects_dirty = true
	world._save_objects()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_folder.path_join("objets.json")))
	check(saved.plantes_arrachees.size() == 2 and saved.plantes_plantees.size() == 1 and not saved.gazon_pose.is_empty(), "saved in objets.json (pulled, planted, turf)")
	# Molette, Survie : comme Ramasser.
	world.inventory.put("bar", world.inventory.selected(), {})
	var front: Vector3 = world.player.global_position + Vector3(0.6, 0.0, 0.0)
	world.ground.drop({"objet": "caillou", "taille": 2}, front + Vector3.UP * 0.3, front, world._rest_height, 0.0)
	# (le caillou tombe un court instant, puis peut être reposé si le sol vient de changer : sa case retrouvée par son numéro)
	var pebble_index: int = world.ground.entries.size() - 1
	for wait in range(20):
		await process_frame
		await physics_frame
	var body: Node3D = world.ground.bodies[pebble_index]
	world.player.camera.look_at(body.global_position)
	var picked: bool = world.pick_aimed({"collider": body, "position": body.global_position, "normal": Vector3.UP})
	check(str(world.inventory.held().get("objet", "")) == "caillou", "middle click (Survie): the pebble in hand (%s, %s)" % [str(picked), world.notice])
	# Molette, Créatif : dans la case choisie, ce qui y était va dans la grille.
	app.set_world_game_mode(Catalog.GAME_CREATIVE)
	await process_frame
	world.inventory.put("bar", world.inventory.selected(), {"objet": "fibre_lin", "pile": [{}]})
	world.ground.drop({"objet": "plante_ortie"}, front + Vector3.UP * 0.3, front, world._rest_height, 0.0)
	await process_frame
	body = world.ground.bodies[-1]
	world.pick_aimed({"collider": body, "position": body.global_position, "normal": Vector3.UP})
	var in_grid: bool = range(Inventory.GRID_SIZE).any(func(index): return str(world.inventory.item("grid", index).get("objet", "")) == "fibre_lin")
	check(str(world.inventory.held().get("objet", "")) == "plante_ortie" and in_grid, "middle click (Créatif): in the chosen slot, the old one in the grid")
	var before: Dictionary = world.inventory.held()
	world.pick_aimed({})
	check(world.inventory.held() == before, "middle click on nothing: nothing changes")
	# 0.0.8.19 (signalé par l'utilisateur : rien en visant le sol) : en Créatif, la matière du sol visé (ou une motte sur
	# l'herbe) dans la case choisie.
	world.inventory.put("bar", world.inventory.selected(), {})
	var feet: Vector3 = world.player.global_position
	world.pick_aimed(ground_hit(world, feet.x + 0.8, feet.z))
	var got := str(world.inventory.held().get("objet", ""))
	check(got in ["terre", "sable", "gazon", "pierre", "gravier", "argile", "boue", "calcaire", "silex", "pierre_sombre"], "middle click (Créatif) on the ground: its material in the chosen slot (%s)" % got)
	app.return_to_worlds()
	for path in [fixture, fixture + ".worlds"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d plants inventory checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
