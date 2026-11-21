extends SceneTree
# 0.0.8 (#171, #204, demandes de l'utilisateur) : vie en Survie (rien en Créatif), barre en bas à gauche avec le nombre
# de points ; dégâts de chute au-delà de 4 m (8 par mètre, 75 % sur le sable, rien dans l'eau) ; régénération : 1 point
# toutes les 3 s après 6 s sans dégât ; manger (clic droit maintenu) : pomme 15, vieille pomme brune 5, noisette 3 ;
# clic court : le fruit est posé comme avant. Vie enregistrée dans joueur.json. Pomme brune : icône sans feuille.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Health = preload("res://scripts/health.gd")
const ItemIcons = preload("res://scripts/item_icons.gd")
const Store = preload("res://scripts/world_store.gd")
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
	# Règles seules.
	check(Health.fall_damage(4.0) == 0 and Health.fall_damage(5.0) == 8 and Health.fall_damage(8.0) == 32 and Health.fall_damage(12.0) == 64, "fall: nothing up to 4 m, then 8 points per meter")
	check(Health.fall_damage(8.0, true) == 24, "fall on sand: 75 % of the damage")
	check(Health.fall_damage(16.5) >= 100, "about 16.5 m: all the life")
	check(Health.food_points({"objet": "pomme", "couleur": 1}) == 15 and Health.food_points({"objet": "pomme", "couleur": 3}) == 5 and Health.food_points({"objet": "noisette"}) == 3 and Health.food_points({"objet": "caillou"}) == 0, "food: apple 15, old brown apple 5, hazelnut 3, pebble nothing")
	check(Inventory.APPLE_COLOR_NAMES[Health.BROWN] == "brune", "brown apple is color 3")
	var h := Health.new()
	h.damage(30)
	check(h.value == 70, "damage lowers the life")
	var t := 0.0
	while t < 5.9:
		h.step(0.1)
		t += 0.1
	check(h.value == 70, "no regeneration in the first 6 s after a hit")
	for i in range(31):
		h.step(0.1)
	check(h.value == 71, "then 1 point every 3 s (%d)" % h.value)
	h.heal(500)
	check(h.value == 100 and h.full(), "never above 100")
	# Icône : la pomme brune n'a plus de feuille verte.
	check(_green_pixels(ItemIcons._apple(Inventory.APPLE_COLORS[3], 3)) == 0 and _green_pixels(ItemIcons._apple(Inventory.APPLE_COLORS[1], 1)) > 5, "brown apple icon without its leaf, red apple keeps it")
	# En partie.
	root.size = Vector2i(1280, 720)
	var fixture := "res://.godot/health-%d.json" % Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	var settings := Settings.new(fixture)
	app.settings = settings
	app.catalog = Catalog.new(fixture + ".worlds")
	var made: Dictionary = app.catalog.create_world("Vie", "71")
	root.add_child(app)
	current_scene = app
	await process_frame
	app.open_world(made.id)
	for i in range(5):
		await process_frame
	var world: Node3D = app.active_world
	world.set_game_mode(Inventory.CREATIVE)
	await process_frame
	check(not world.health_bar.visible and world.hurt(30) == 0 and world.health.value == 100, "Créatif: no bar, no damage")
	world.set_game_mode(Inventory.SURVIVAL)
	world.fall_ignored = false
	await process_frame
	check(world.health_bar.visible and world.health_bar.value == 100, "Survie: the bar shows 100")
	var bar_rect: Rect2 = world.health_bar.get_global_rect()
	check(bar_rect.position.x < 1280 * 0.25 and bar_rect.end.y > 720 * 0.85 and bar_rect.size.x > bar_rect.size.y * 6.0, "bar thin, bottom left (%s)" % bar_rect)
	world._on_landed(8.0, 0.0)
	var on_sand: bool = world.ground_kind_under(world.player.position) == world.SmoothTerrain.SAND
	check(world.health.value == 100 - Health.fall_damage(8.0, on_sand), "a fall of 8 m hurts (%d)" % world.health.value)
	await process_frame
	check(world.health_bar.value == world.health.value and world.hurt_veil.visible, "bar follows, red edges shown")
	var before: int = world.health.value
	world._on_landed(20.0, 1.0)
	check(world.health.value == before, "falling into water: nothing")
	# Passage en Survie : la chute qui suit ne blesse pas.
	world.set_game_mode(Inventory.CREATIVE)
	world.set_game_mode(Inventory.SURVIVAL)
	world._on_landed(30.0, 0.0)
	check(world.health.value == before, "first fall after switching to Survie: nothing")
	# Manger : clic court = poser ; maintenu = manger.
	world.health.value = 50
	world.inventory.put("bar", 0, Inventory.single({"objet": "pomme", "taille": 2, "couleur": 1}))
	world.inventory.select(0)
	check(world.can_eat(), "an apple in hand can be eaten")
	check(world.eat_press(), "right click with a fruit: eating starts")
	for i in range(12):
		world.step_eat(0.1, true)
	check(world.health.value == 65 and world.inventory.held().is_empty(), "held 1 s: apple eaten, +15 (%d)" % world.health.value)
	world.inventory.put("bar", 0, Inventory.single({"objet": "pomme", "taille": 2, "couleur": 3}))
	world.eat_press()
	for i in range(12):
		world.step_eat(0.1, true)
	check(world.health.value == 70, "old brown apple: +5")
	world.inventory.put("bar", 0, Inventory.single({"objet": "noisette"}))
	world.eat_press()
	world.step_eat(0.1, true)
	world.eat_release({})
	check(world.health.value == 70, "short click: not eaten")
	world.health.value = 100
	world.inventory.put("bar", 0, Inventory.single({"objet": "noisette"}))
	world.eat_press()
	for i in range(12):
		world.step_eat(0.1, true)
	check(world.health.value == 100 and not world.inventory.held().is_empty(), "full life: nothing eaten")
	# À 0 : retour au point de départ, vie pleine.
	world.player.position = Vector3(20.0, world.player.position.y + 5.0, 20.0)
	world.hurt(500)
	check(world.death_open, "at 0: the death screen opens (0.0.8.1)")
	world.respawn()
	check(world.health.value == 100 and world.player.position.distance_to(world.spawn_position()) < 0.01, "back to the start, full life")
	# Enregistrée.
	world.hurt(12)
	check(world.player_data().get("vie") == 88, "life saved in joueur.json")
	world.save_now()
	var saved := Store.read_json(world.save_folder.path_join(Store.PLAYER_FILE), Store.valid_player)
	check(int(saved.get("data", {}).get("vie", -1)) == 88, "life written")
	app.return_to_worlds()
	app.open_world(made.id)
	for i in range(5):
		await process_frame
	check(app.active_world.health.value == 88, "life read again (%d)" % app.active_world.health.value)
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for menu in Settings.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.file_path(menu)))
	print("RESULT: %d health checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

static func _green_pixels(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c := image.get_pixel(x, y)
			if c.a > 0.5 and c.g > c.r + 0.1 and c.g > c.b + 0.05:
				count += 1
	return count
