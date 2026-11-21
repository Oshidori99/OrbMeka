extends SceneTree
# 0.0.8.2 (#231, #229, demandes de l'utilisateur) : orbe de retour (200 g, 2 dl, usage unique : clic droit maintenu,
# retour au point de départ, elle disparaît ; clic court : posée) ; au début en Survie : une en poche, une au sol près
# du départ ; une fois par monde, aussi pour les anciens mondes de Survie ; jamais pour un monde ouvert en Créatif.
# Arbre qui tombe : 15 à 80 points selon sa taille, tout pile dessous, très peu en étant frôlé, dégradé entre les deux.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Health = preload("res://scripts/health.gd")
const ReturnOrb = preload("res://scripts/return_orb.gd")
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
	# Objet.
	var orb := {"objet": ReturnOrb.ID}
	check(Inventory.ITEMS.has(ReturnOrb.ID) and Inventory.ITEMS[ReturnOrb.ID].nom == "Orbe de retour", "item: Orbe de retour")
	check(is_equal_approx(Inventory.instance_weight(ReturnOrb.ID, {}), 200.0) and is_equal_approx(Inventory.instance_volume(ReturnOrb.ID, {}), 0.2), "200 g, 2 dl")
	check(Inventory.is_object(orb) and Inventory.valid_item(Inventory.single(orb)), "a single object, valid in a slot")
	var icon: Image = ItemIcons.texture(ReturnOrb.ID).get_image()
	check(_count(icon, func(c: Color): return c.a > 0.5 and c.g > 0.6 and c.b > 0.55 and c.r < 0.6) > 50 and _count(icon, func(c: Color): return c.a > 0.5 and c.r > 0.7 and c.g > 0.5 and c.b < 0.5) > 5, "icon: turquoise orb with a golden ring")
	# Arbre qui tombe.
	var base := Vector3.ZERO
	var east := Vector3.RIGHT
	check(Health.tree_damage(base, east, 8.0, 0.45, 3.0, 2.0, Vector3(2.0, 0.0, 0.0)) == 80, "very big tree right on top: 80")
	check(Health.tree_damage(base, east, 3.0, 0.1, 1.0, 1.0, Vector3(1.0, 0.0, 0.0)) == 15, "small tree right on top: 15")
	var full := Health.tree_damage(base, east, 6.0, 0.3, 3.0, 2.0, Vector3(1.5, 0.0, 0.0))
	var half := Health.tree_damage(base, east, 6.0, 0.3, 3.0, 2.0, Vector3(1.5, 0.0, 0.85))
	var graze := Health.tree_damage(base, east, 6.0, 0.3, 3.0, 2.0, Vector3(1.5, 0.0, 1.18))
	check(full > half and half > graze and graze >= 1 and graze <= 5, "under the trunk %d > between %d > grazed %d (a few points)" % [full, half, graze])
	check(Health.tree_damage(base, east, 6.0, 0.3, 3.0, 2.0, Vector3(1.5, 0.0, 2.5)) == 0 and Health.tree_damage(base, east, 6.0, 0.3, 3.0, 2.0, Vector3(-2.0, 0.0, 0.0)) == 0 and Health.tree_damage(base, east, 6.0, 0.3, 3.0, 2.0, Vector3(8.0, 0.0, 0.0)) == 0, "beside, behind or beyond the tree: nothing")
	var crown := Health.tree_damage(base, east, 6.0, 0.3, 3.0, 2.0, Vector3(4.5, 0.0, 1.6))
	check(crown > 0 and crown < full / 2, "branches of the crown: less (%d)" % crown)
	# En partie.
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/orb-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = Catalog.new(fixture + ".worlds")
	var survival_world: Dictionary = app.catalog.create_world("Orbe", "75")
	app.catalog.set_game_mode(survival_world.id, Catalog.GAME_SURVIVAL)
	var creative_world: Dictionary = app.catalog.create_world("Orbe créatif", "76")
	root.add_child(app)
	current_scene = app
	await process_frame
	app.open_world(survival_world.id)
	for i in range(5):
		await process_frame
	var world: Node3D = app.active_world
	var pocket := Inventory.POCKETS.filter(func(i): return ReturnOrb.is_orb(world.inventory.item("bar", i)))
	check(pocket.size() == 1 and Inventory.count(world.inventory.item("bar", pocket[0])) == 1, "Survie: one orb in a pocket")
	var reserve: Array = world.ground.entries.filter(func(e): return ReturnOrb.is_orb(e.item))
	var spot: Vector3 = world.spawn_position() + ReturnOrb.RESERVE_OFFSET
	check(reserve.size() == 1 and Vector2(reserve[0].position.x - spot.x, reserve[0].position.z - spot.z).length() < 0.3, "and a second one on the ground near the start")
	check(world.player_data().get("orbes_depart") == true, "given once, remembered in joueur.json")
	# Usage : clic droit maintenu, retour au départ, l'orbe disparaît.
	world.inventory.select(pocket[0])
	world.player.position = world.spawn_position() + Vector3(25.0, 6.0, 25.0)
	check(world.hold_use() == "orbe" and world.eat_press(), "right click held with the orb: starts")
	world.step_eat(0.5, true)
	check(world.player.position.distance_to(world.spawn_position()) > 10.0, "not before the ring is full")
	for i in range(8):
		world.step_eat(0.1, true)
	check(world.player.position.distance_to(world.spawn_position()) < 0.01 and world.inventory.held().is_empty(), "held 1 s: back to the start, the orb is gone")
	# Arbre en partie : Survie seulement.
	var hit := {"base": world.player.global_position, "direction": Vector3.RIGHT, "length": 6.0, "diameter": 0.3, "crown_from": 3.0, "crown_radius": 2.0}
	hit.base -= Vector3(1.5, 0.0, 0.0)
	var lost: int = world._tree_hurts(hit)
	check(lost == full and world.health.value == 100 - full, "a tree falling on the player in Survie hurts (%d)" % lost)
	world.save_now()
	app.return_to_worlds()
	app.open_world(survival_world.id)
	for i in range(5):
		await process_frame
	world = app.active_world
	check(world.ground.entries.filter(func(e): return ReturnOrb.is_orb(e.item)).size() == 1 and Inventory.POCKETS.all(func(i): return not ReturnOrb.is_orb(world.inventory.item("bar", i))), "reopened: no new orbs (reserve still on the ground)")
	app.return_to_worlds()
	# Créatif : jamais, même passé ensuite en Survie.
	app.open_world(creative_world.id)
	for i in range(5):
		await process_frame
	world = app.active_world
	check(world.ground.entries.filter(func(e): return ReturnOrb.is_orb(e.item)).is_empty(), "Créatif: no orb")
	world.set_game_mode(Inventory.SURVIVAL)
	check(world._tree_hurts({"base": world.player.global_position, "direction": Vector3.RIGHT, "length": 6.0, "diameter": 0.3, "crown_from": 3.0, "crown_radius": 2.0}) > 0, "switched to Survie: trees hurt")
	world.save_now()
	app.catalog.set_game_mode(creative_world.id, Catalog.GAME_SURVIVAL)
	app.return_to_worlds()
	app.open_world(creative_world.id)
	for i in range(5):
		await process_frame
	world = app.active_world
	check(world.ground.entries.filter(func(e): return ReturnOrb.is_orb(e.item)).is_empty() and Inventory.POCKETS.all(func(i): return not ReturnOrb.is_orb(world.inventory.item("bar", i))), "opened first in Créatif, then Survie: still no orb (not on a mode change)")
	world.set_game_mode(Inventory.CREATIVE)
	check(world._tree_hurts({"base": world.player.global_position, "direction": Vector3.RIGHT, "length": 6.0, "diameter": 0.3, "crown_from": 3.0, "crown_radius": 2.0}) == 0, "Créatif: trees never hurt")
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for menu in Settings.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.file_path(menu)))
	print("RESULT: %d return orb checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

static func _count(image: Image, test: Callable) -> int:
	var total := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if test.call(image.get_pixel(x, y)):
				total += 1
	return total
