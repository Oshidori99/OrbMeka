extends SceneTree
# Run with --headless: no window, pointer capture or operating-system input.
const TerrainGenerator = preload("res://scripts/terrain_generator.gd")
var failures := 0
var checks := 0
var world: Node3D

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func move_steps(player: CharacterBody3D, count: int, direction: Vector2, jump := false) -> void:
	player.set_physics_process(false)
	for index in range(count):
		await physics_frame
		player.step_movement(1.0 / 60.0, direction, jump and index == 0)
	player.set_physics_process(true)

func _run() -> void:
	var heights := TerrainGenerator.generate_heights()
	var cells := TerrainGenerator.generate_cells()
	check(heights == TerrainGenerator.generate_heights(), "same seed reproduces identical heights")
	check(cells == TerrainGenerator.generate_cells(), "same seed reproduces identical ordered cells")
	check(heights != TerrainGenerator.generate_heights(TerrainGenerator.SEED + 1), "another seed changes the hills")
	var max_height := 0
	var filled := true
	var clear_spawn := true
	for column: Vector2i in heights:
		max_height = maxi(max_height, heights[column])
		if column.x >= -5 and column.x <= 5 and column.y >= -6 and column.y <= 10:
			clear_spawn = false
		for y in range(heights[column]):
			if not cells.has(Vector3i(column.x, y, column.y)):
				filled = false
	check(max_height == 3, "hills have modest maximum height of three blocks")
	check(filled, "hill columns are filled without underground gaps")
	check(clear_spawn, "spawn and original construction area remain clear")
	check(cells.size() > 0 and cells.size() < 1000, "terrain stays small and leaves construction capacity")
	print("TERRAIN: seed=%d, columns=%d, dirt blocks=%d" % [TerrainGenerator.SEED, heights.size(), cells.size()])
	world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(60)
	var player: CharacterBody3D = world.player
	check(world.blocks.size() == cells.size() + 74, "terrain and all 74 original blocks are present")
	var dirt_matches := true
	for cell in cells:
		if not world.blocks.has(cell) or world.blocks[cell].get_meta("kind") != world.DIRT:
			dirt_matches = false
	check(dirt_matches, "every generated cell is a breakable dirt block")
	check(player.is_on_floor(), "player lands safely at spawn")
	check(absf(player.position.y) < 0.05, "spawn feet rest on protected base")
	var spawn_clear := true
	for cell: Vector3i in world.blocks:
		if player.overlaps_cell(cell):
			spawn_clear = false
	check(spawn_clear, "spawn capsule does not intersect any block")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "startup leaves mouse free")
	check(ProjectSettings.get_setting("application/config/version") == "0.0.5", "project version is 0.0.5")
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump"]:
		check(InputMap.has_action(action), "input binding: " + action)
	# Marche testée dans l'aire dégagée (l'apparition en 0, 0 fait face aux blocs de démonstration).
	player.position = Vector3(0.5, 0.02, 8.5)
	player.velocity = Vector3.ZERO
	await frames(10)
	var start := player.position
	await move_steps(player, 30, Vector2(0, -1))
	check(player.position.z < start.z - 2.0, "shared movement step walks forward")
	await move_steps(player, 14, Vector2.ZERO, true)
	check(player.position.y > 0.5, "shared movement step jumps")
	await frames(100)
	check(player.is_on_floor(), "character lands after jumping")
	player.position = Vector3(0.5, 0.02, 2.5)
	player.velocity = Vector3.ZERO
	player.camera.rotation.x = -0.3
	await frames(5)
	var hit: Dictionary = player.get_target()
	check(not hit.is_empty() and hit.collider.is_in_group("blocks"), "camera ray finds nearby original blocks")
	var count: int = world.blocks.size()
	check(world.break_target(hit), "original demonstration block is breakable")
	check(world.blocks.size() == count - 1, "breaking removes exactly one block")
	await frames(2)
	player.position = Vector3(0.5, 0.02, 5.5)
	player.camera.rotation.x = -0.7
	await frames(4)
	hit = player.get_target()
	check(not hit.is_empty() and hit.collider.is_in_group("ground"), "camera ray targets protected base")
	count = world.blocks.size()
	check(not world.break_target(hit), "base remains unbreakable")
	check(world.blocks.size() == count, "base protection preserves block count")
	check(world.place_target(hit, world.DIRT), "dirt can be placed on base")
	check(world.blocks.size() == count + 1, "placing creates exactly one block")
	var placed_cell := Vector3i(floori(hit.position.x), 0, floori(hit.position.z))
	check(world.blocks.has(placed_cell) and world.blocks[placed_cell].get_meta("kind") == world.DIRT, "placed dirt uses the third material")
	check(not world.place_target(hit, world.DIRT), "duplicate placement is rejected")
	var ground := world.get_node("Ground")
	var self_hit := {"collider": ground, "position": Vector3(0.5, 0, 5.5), "normal": Vector3.UP}
	check(not world.place_target(self_hit, 0), "placement inside player is rejected")
	var far_hit := {"collider": ground, "position": Vector3(40, 0, 40), "normal": Vector3.UP}
	check(not world.place_target(far_hit, 0), "placement beyond five metres is rejected")
	check(not world.break_target(far_hit), "breaking beyond five metres is rejected")
	check(not world.place_target({}, 0), "empty target cannot place")
	check(not world.break_target({}), "empty target cannot break")
	var summit := Vector2i.ZERO
	for column: Vector2i in heights:
		if heights[column] == max_height:
			summit = column
			break
	player.position = Vector3(summit.x + 0.5, max_height + 2.0, summit.y + 0.5)
	player.velocity = Vector3.ZERO
	player.camera.rotation.x = -PI / 2.0 + 0.01
	await frames(90)
	check(player.is_on_floor() and absf(player.position.y - max_height) < 0.05, "hill collision supports player at summit")
	hit = player.get_target()
	check(not hit.is_empty() and hit.collider.get_meta("kind", -1) == world.DIRT, "camera ray targets generated hill dirt")
	count = world.blocks.size()
	check(world.break_target(hit), "generated hill dirt breaks through existing interaction")
	check(world.blocks.size() == count - 1, "breaking hill removes exactly one generated cell")
	await frames(60)
	check(player.is_on_floor() and absf(player.position.y - (max_height - 1)) < 0.05, "player falls onto the next dirt layer after mining")
	for index in range(max_height - 1):
		hit = player.get_target()
		world.break_target(hit)
		await frames(60)
	hit = player.get_target()
	check(not hit.is_empty() and hit.collider.is_in_group("ground"), "mining a hill exposes protected base")
	check(not world.break_target(hit), "base under mined hill remains protected")
	check(player.is_on_floor() and absf(player.position.y) < 0.05, "base still supports player after mining entire column")
	player.position = Vector3(30, 0.02, 30)
	player.camera.rotation.x = 0
	await frames(3)
	check(player.get_target().is_empty(), "distant blocks are outside ray reach")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	player._unhandled_input(event)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape keeps mouse free")
	event.keycode = KEY_2
	player._unhandled_input(event)
	check(player.selected_type == 1, "key 2 selects stone")
	event.keycode = KEY_3
	player._unhandled_input(event)
	check(player.selected_type == 2, "key 3 selects dirt")
	# Exercise all three slots through the selection handler and real physics rays.
	player.position = Vector3(30.5, 0.02, 30.5)
	player.velocity = Vector3.ZERO
	player.camera.rotation.x = -0.7
	await frames(5)
	check(world.BLOCK_NAMES == ["Sable", "Pierre", "Terre"], "material names are sand, stone and dirt")
	var expected_colors := [Color("#d8c291"), Color("#888b90"), Color("#855332")]
	for kind in range(3):
		event.keycode = [KEY_1, KEY_2, KEY_3][kind]
		player._unhandled_input(event)
		check(player.selected_type == kind, "number key selects material %d" % kind)
		check(world.materials[kind].albedo_color == expected_colors[kind], "material %d uses expected simple color" % kind)
		hit = player.get_target()
		check(world.place_target(hit, player.selected_type), "selected material %d can be placed" % kind)
		await frames(3)
		hit = player.get_target()
		check(not hit.is_empty() and hit.collider.get_meta("kind", -1) == kind, "placed material %d is targeted correctly" % kind)
		check(world.break_target(hit), "selected material %d can be broken" % kind)
		await frames(3)
	# The upper accepted cell is y=24: its top is 25 m above the flat base.
	player.set_physics_process(false)
	player.position = Vector3(31.5, 26.0, 30.5)
	player.camera.rotation.x = -PI / 2.0 + 0.01
	world.add_block(Vector3i(31, 23, 30), 1)
	await frames(3)
	hit = player.get_target()
	check(world.place_target(hit, 0), "sand can be placed with its top at the 25-block limit")
	await frames(3)
	hit = player.get_target()
	check(not world.place_target(hit, 0), "placement above 25 blocks is rejected")
	var support: Node = world.blocks[Vector3i(31, 23, 30)]
	var support_hit := {"collider": support, "position": Vector3(31.5, 24, 30.5), "normal": Vector3.UP}
	check(world.break_target(support_hit), "support below sand can be broken")
	await frames(15)
	check(world.blocks.has(Vector3i(31, 24, 30)) and world.blocks[Vector3i(31, 24, 30)].position.y == 24.5, "unsupported sand remains stationary")
	player.position = Vector3(30.5, 0.02, 30.5)
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	world.add_block(Vector3i(0, 0, 0), world.DIRT)
	player.position.y = -11
	await frames(3)
	check(player.position.y > 0.99 and absf(player.position.x - 0.5) < 0.01 and absf(player.position.z - 0.5) < 0.01, "fall recovery respawns at 0, 0 on top of newly built blocks")
	await frames(90)
	check(player.is_on_floor() and absf(player.position.y - 1.0) < 0.05, "safe respawn lands on construction without overlap")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	root.remove_child(world)
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)