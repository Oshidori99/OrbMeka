extends SceneTree
# 0.0.8.9 (bugs et demandes de l'utilisateur) : visée exacte (zones des objets au sol à leur vraie taille : avant, une
# boule d'un mètre autour des fibres, lianes, ficelles et outils prenait la place des objets voisins) ; objets couchés sur
# les pentes ; R et clic gauche (« casser / arracher » : au sol ; « casser / récupérer des objets » : ramassée)
# arrachent l'herbe (sol herbeux d'origine reconnu) ; effet de dégât selon sa force (#242) ; ficelage en croix sur la
# tête ; outil tenu le manche dressé.
const Settings = preload("res://scripts/user_settings.gd")
const Catalog = preload("res://scripts/world_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const ToolModels = preload("res://scripts/tool_models.gd")
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
	var fixture := "res://.godot/fixes-089-%d.json" % Time.get_ticks_usec()
	var settings := Settings.new(fixture)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.settings = settings
	app.catalog = Catalog.new(fixture + ".worlds")
	var made: Dictionary = app.catalog.create_world("Corrections", "78")
	app.catalog.set_game_mode(made.id, Catalog.GAME_SURVIVAL)
	root.add_child(app)
	current_scene = app
	await process_frame
	app.open_world(made.id)
	for i in range(600):
		if app.page == "playing":
			break
		await process_frame
	var world: Node3D = app.active_world
	# Zones de visée à la vraie taille.
	var spot: Vector3 = world.player.global_position + Vector3(2.0, 0.0, 0.0)
	world.ground.drop({"objet": "fibre_lin"}, spot + Vector3.UP, spot, world._rest_height, 0.0)
	world.ground.drop({"objet": "hache_pierre", "longueur": 0.6, "epaisseur": 3.0, "pierre": 1, "taille": 4, "lien": 1, "tours": 4}, spot + Vector3(0, 1, 1), spot + Vector3(0, 0, 1), world._rest_height, 0.0)
	var fibre_body: StaticBody3D = world.ground.bodies[-2]
	var tool_body: StaticBody3D = world.ground.bodies[-1]
	var fibre_shape: Shape3D = (fibre_body.get_child(0) as CollisionShape3D).shape
	var tool_shape: Shape3D = (tool_body.get_child(0) as CollisionShape3D).shape
	check(fibre_shape is BoxShape3D and fibre_shape.size.x < 0.3 and fibre_shape.size.y < 0.1, "a fibre: an aim box of its size (no more 1 m ball)")
	check(tool_shape is BoxShape3D and is_equal_approx(tool_shape.size.z, 0.6) and tool_shape.size.x < 0.2, "a tool: an aim box along its handle")
	# Sur une pente.
	var slope := Vector3.ZERO
	for x in range(-60, 60, 3):
		for z in range(-60, 60, 3):
			if slope == Vector3.ZERO:
				var n: Vector3 = world._rest_normal(Vector3(x, world.terrain.height_at(x, z), z))
				if n.y < 0.9 and n.y > 0.5:
					slope = Vector3(x, world.terrain.height_at(x, z), z)
	check(slope != Vector3.ZERO, "a slope found")
	world.ground.drop({"objet": "caillou", "taille": 2}, slope + Vector3.UP, slope, world._rest_height, 0.0)
	var placed: Transform3D = world.ground.place_of(world.ground.entries[-1], Basis())
	check(placed.basis.y.normalized().y < 0.95, "on a slope, a dropped object lies along the ground (tilted %.2f)" % placed.basis.y.normalized().y)
	# Herbe : sol herbeux d'origine reconnu ; clic gauche « casser / arracher » : au sol ; « récupérer » : ramassée.
	var grass := Vector3.ZERO
	for r in range(4, 70, 2):
		for a in range(0, 360, 20):
			var p := Vector3(cos(deg_to_rad(a)) * r, 0.0, sin(deg_to_rad(a)) * r)
			p.y = world.terrain.height_at(p.x, p.z)
			if grass == Vector3.ZERO and not world._grass_skipped(p) and world.ground_kind_under(p + Vector3.UP * 0.3) in [-1, 2]:
				grass = p
	check(grass != Vector3.ZERO, "grassy ground found")
	var hit := {"collider": world, "position": grass, "normal": Vector3.UP}
	world.player.global_position = grass + Vector3(1.2, 0.05, 0.0)
	check(world.aimed_grass(hit).get("kind") == "herbe", "the original grassy ground can be pulled (0.0.8.9 fix)")
	var before: int = world.ground.entries.size()
	world.player.left_mode = 3
	world.pull_grass(grass, world.player.left_mode == 1)
	check(world.ground.entries.size() == before + 1 and world.ground.entries[-1].item.objet == "herbe_arrachee", "Casser / Arracher: the pulled grass stays on the ground")
	for index in Inventory.HANDS + Inventory.POCKETS:
		world.inventory.put("bar", index, {})
	world.inventory.select(0)
	var other := grass + Vector3(1.5, 0.0, 1.5)
	other.y = world.terrain.height_at(other.x, other.z)
	world.player.left_mode = 1
	before = world.ground.entries.size()
	world.pull_grass(other, world.player.left_mode == 1)
	check(world.ground.entries.size() == before and world.inventory.item("bar", 0).get("objet") == "herbe_arrachee", "Casser / Récupérer des objets: the pulled grass is picked up")
	world.player.left_mode = 0
	# Effet de dégât selon sa force (#242).
	world.health.value = 100
	world.hurt(1)
	var small: float = world.hurt_power
	world.hurt_time = 0.0
	world.hurt(40)
	check(small < 0.3 and world.hurt_power >= 1.0, "a small hurt: a light effect (%.2f) ; a big one: the full effect" % small)
	# Ficelage en croix ; outil tenu le manche dressé.
	var axe := {"objet": "hache_pierre", "pierre": 1, "taille": 4, "essence": 1, "epaisseur": 3.0, "longueur": 0.6, "lien": 1, "tours": 6}
	var mesh := ToolModels.mesh(axe)
	check(mesh.get_surface_count() == 3 and mesh.surface_get_arrays(2)[Mesh.ARRAY_VERTEX].size() > 200, "binding: turns under the head and bands crossing over it")
	world.inventory.put("bar", 1, Inventory.single(axe))
	world.inventory.select(1)
	await process_frame
	var held: Node3D = world.player.hand_view.held.get_child(0) if world.player.hand_view.held.get_child_count() > 0 else null
	check(held != null and (world.player.hand_view.basis * held.basis * Vector3.UP).normalized().y > 0.4, "the stone axe held with its handle up, not crooked")
	app.return_to_worlds()
	root.remove_child(app)
	app.queue_free()
	await process_frame
	for menu in Settings.FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.file_path(menu)))
	print("RESULT: %d fixes checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
