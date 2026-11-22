extends SceneTree
# 0.0.8.4 (#213, #228, demandes de l'utilisateur) : R maintenu 1 s sur une ortie, du lin ou des herbes longues : 1 à 3
# fibres (même graine : même nombre), la plante reste coupée (tige basse, objets.json) ; sur un tilleul à liane : une
# liane, qui disparaît du tronc. Bois : âge et souplesse propres à chaque arbre (noisetier souple, pin raide).
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Fibers = preload("res://scripts/fibers.gd")
const Plants = preload("res://scripts/plants.gd")
const Trees = preload("res://scripts/trees.gd")
const ItemIcons = preload("res://scripts/item_icons.gd")
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
	# Objets.
	check(Fibers.PLANT_ITEMS.all(func(id): return Inventory.ITEMS.has(id) and Inventory.ITEMS[id].forme == "fibre") and Inventory.ITEMS.liane.forme == "liane", "items: three fibres and a liane")
	check(Inventory.ITEMS.fibre_ortie.nom == "Fibre d'ortie" and Inventory.ITEMS.fibre_lin.nom == "Fibre de lin" and Inventory.ITEMS.fibre_herbe.nom == "Fibre d'herbe", "names")
	check(Inventory.CATEGORIES.any(func(c): return c.id == "plants" and c.objets.has("liane")) and ItemIcons.tab("plants", 34) != null, "Créatif: a Plantes tab")
	check(Fibers.PLANT_ITEMS.all(func(id): return ItemIcons.texture(id) != null) and ItemIcons.texture("liane") != null, "icons")
	# Bois : propre à chaque arbre.
	check(Inventory.tree_wood("arbre-a", 0) == Inventory.tree_wood("arbre-a", 0), "same tree: same age and suppleness")
	var hazel := 0
	var pine := 0
	for index in range(200):
		hazel += Inventory.tree_wood("a%d" % index, Trees.HAZEL).y
		pine += Inventory.tree_wood("a%d" % index, Trees.PINE).y
	check(hazel > pine + 200, "hazel more supple than pine on average (%d / %d)" % [hazel, pine])
	var rng := RandomNumberGenerator.new()
	var piece := Inventory.wood_piece("branche", Trees.LINDEN, 3.0, 1.0, rng, Vector2i(5, 1))
	check(piece.age == 5 and piece.souplesse == 1, "a piece of wood keeps its tree's age and suppleness")
	# En partie : trouver une plante à fibres près du départ.
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/fibers-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = Catalog.new(fixture + ".worlds")
	var made: Dictionary = app.catalog.create_world("Fibres", "78")
	app.catalog.set_game_mode(made.id, Catalog.GAME_SURVIVAL)
	root.add_child(app)
	current_scene = app
	await process_frame
	app.open_world(made.id)
	for i in range(5):
		await process_frame
	var world: Node3D = app.active_world
	var found := {}
	var column := Vector2i.ZERO
	for radius in range(0, 14):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if found.is_empty() and maxi(absi(x), absi(z)) == radius:
					var list: Array = world.terrain.plants_in_zone(Vector2i(x, z))
					if not list.is_empty():
						found = list[0]
						column = Vector2i(x, z)
	check(not found.is_empty(), "a fibre plant found near the start")
	var foot: float = world.terrain.height_at(found.x, found.z)
	world.player.global_position = Vector3(found.x - 1.4, foot + 0.05, found.z)
	world.player.velocity = Vector3.ZERO
	world.player.look_at(Vector3(found.x, world.player.global_position.y, found.z))
	world.player.rotation.x = 0.0
	world.player.camera.rotation.x = -0.6
	world.update_zones(world.player_coordinates(), true)
	for i in range(30):
		await process_frame
	world.player.global_position = Vector3(found.x - 1.4, foot + 0.05, found.z)
	var target: Dictionary = world.aimed_harvest(world.player.get_target())
	check(target.get("kind") == "plante" and target.get("id") == Fibers.plant_id(found), "the plant is aimed (%s)" % target.get("kind", "rien"))
	world.inventory.select(0)
	world.inventory.put("bar", 0, {})
	world.step_harvest(0.5, true)
	check(not world.cut_plants.has(Fibers.plant_id(found)), "not before 1 s")
	world.step_harvest(0.6, true)
	var held: Dictionary = world.inventory.item("bar", 0)
	check(world.cut_plants.has(Fibers.plant_id(found)) and held.get("objet") == Fibers.PLANT_ITEMS[int(found.plante)] and Inventory.count(held) == Fibers.fiber_count(found) and Fibers.fiber_count(found) >= 1 and Fibers.fiber_count(found) <= 3, "held 1 s: %d fibres, the plant is cut" % Inventory.count(held))
	check(world.aimed_plant(world.player.get_target()).is_empty() or world.aimed_plant(world.player.get_target()).id != Fibers.plant_id(found), "a cut plant can't be harvested again")
	check(world.column_objects.get(column, []).any(func(n): return is_instance_valid(n) and n.is_in_group("plants")), "the column's plants are drawn again (cut one: low stem)")
	# Liane : un tilleul à liane posé pour l'essai.
	var linden := Trees.tree_body(Trees.LINDEN, 3, true)
	linden.set_meta("id", "tilleul-essai")
	linden.set_meta("liane", true)
	world.add_child(linden)
	world.inventory.put("bar", 1, {})
	world.inventory.select(1)
	check(world.harvest({"kind": "liane", "tree": linden, "key": "liane/tilleul-essai", "distance": 1.0}) and world.inventory.item("bar", 1).get("objet") == "liane" and world.cut_vines.has("tilleul-essai") and linden.get_meta("liane") == false, "a liane harvested from a linden")
	await process_frame
	check(linden.get_node_or_null("Modele/Liane") == null, "the liane is gone from the trunk")
	world.cut_vines["tilleul-graine"] = true
	world._make_column_tree(Vector2i(50, 50), {"id": "tilleul-graine", "espece": Trees.LINDEN, "classe": 3, "x": 400.0, "z": 400.0, "rotation": 0.0, "taille": 1.0, "liane": true})
	var regrown: Array = world.column_objects.get(Vector2i(50, 50), []).filter(func(n): return is_instance_valid(n) and n.get_meta("id", "") == "tilleul-graine")
	check(regrown.size() == 1 and regrown[0].get_meta("liane") == false and regrown[0].get_node_or_null("Modele/Liane") == null, "a harvested liane stays gone when the tree is built again")
	# Enregistré.
	world.objects_dirty = true
	world.save_now()
	app.return_to_worlds()
	app.open_world(made.id)
	for i in range(5):
		await process_frame
	world = app.active_world
	check(world.cut_plants.has(Fibers.plant_id(found)) and world.cut_vines.has("tilleul-essai"), "cut plants and lianes read again from objets.json")
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for menu in Settings.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.file_path(menu)))
	print("RESULT: %d fibre checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
