extends SceneTree
const Timing = preload("res://scripts/action_timing.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func _run() -> void:
	var timer := Timing.new()
	check(timer.set_place_pressed(true, true), "first press requests immediate placement")
	check(not timer.set_place_pressed(true, true), "duplicate press does not create extra placement")
	check(not timer.tick_place(0.299, true, true), "no repeat before 300 ms")
	check(timer.tick_place(0.001, true, true), "one repeat at 300 ms")
	check(not timer.tick_place(0.299, true, true), "second interval also waits")
	check(timer.tick_place(0.001, true, true), "second repeat at 600 ms")
	check(timer.tick_place(2.0, true, true), "slow frame produces one repeat")
	check(not timer.tick_place(0.0, true, true), "no catch-up burst after slow frame")
	check(not timer.tick_place(0.299, true, true), "slow frame resets to a full interval")
	check(timer.tick_place(0.001, true, true), "repeat resumes after full interval")
	timer.set_place_pressed(false, true)
	check(not timer.tick_place(1.0, true, true), "release cancels repetition until fresh press")
	check(not timer.set_place_pressed(true, false), "inactive press cannot start placement")
	timer.set_place_pressed(true, true)
	check(not timer.tick_place(1.0, false, true), "inactive frame cancels pending repeat")
	check(not timer.tick_place(1.0, true, true), "regaining control with held button does not restart")
	timer.set_place_pressed(true, true)
	check(not timer.tick_place(1.0, true, false), "sampled release also cancels pending repeat")
	timer.tick_jump(0.0, true, false)
	check(timer.tick_jump(0.09, false, true), "jump accepted 90 ms after ledge")
	check(not timer.tick_jump(0.001, false, true), "coyote jump cannot be used twice")
	timer.cancel()
	timer.tick_jump(0.0, true, false)
	check(not timer.tick_jump(0.101, false, true), "jump rejected beyond 100 ms ledge tolerance")
	timer.cancel()
	check(not timer.tick_jump(0.0, false, true), "airborne press buffers without infinite jump")
	check(timer.tick_jump(0.10, true, false), "press 100 ms before landing is remembered")
	check(not timer.tick_jump(0.0, true, false), "buffer is consumed exactly once")
	timer.cancel()
	timer.tick_jump(0.0, false, true)
	check(not timer.tick_jump(0.121, true, false), "press older than 120 ms is discarded")
	timer.cancel()
	check(timer.tick_jump(0.0, true, true), "normal grounded jump is immediate")
	var repeated := false
	for index in range(180):
		repeated = timer.tick_jump(1.0 / 60.0, index > 80, false) or repeated
	check(not repeated, "holding Space without another press never auto-jumps")
	timer.tick_jump(0.0, false, true)
	timer.cancel()
	check(not timer.tick_jump(0.01, true, false), "cancelling control clears buffered jump")
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = world.player
	await frames(60)
	player.set_physics_process(false)
	# Isoler les actions des chargements de zones déclenchés par le déplacement de la fixture.
	world.set_process(false)
	player.position = Vector3(30.5, 0.0, 30.5)
	player.velocity = Vector3.ZERO
	player.camera.rotation.x = -0.7
	await frames(3)
	var count: int = world.blocks.size()
	# 0.0.5.8 : un clic droit ajoute du terrain lisse (50 cm), pas de bloc.
	check(player.begin_placement() and world.terrain.changes.size() == 1, "right click adds smooth ground")
	check(world.blocks.size() == count, "adding ground places no block")
	check(not player.step_placement(0.299, true, true), "gameplay repeat waits before interval")
	await frames(3)
	# Aim at a different cell while holding; the repeat must use the current ray.
	player.position.x += 2.0
	check(not player.step_placement(0.001, true, true), "visual exploration rejects repeated placement")
	check(world.blocks.size() == count, "disabled repetition preserves blocks")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	player._input(release)
	check(not player.step_placement(1.0, true, true), "actual release handler stops placement")
	player.actions.set_place_pressed(true, true)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	player._unhandled_input(escape)
	check(not player.actions.placing, "Escape clears repetition state")
	player.actions.set_place_pressed(true, true)
	player.actions.tick_jump(0.0, false, true)
	player._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not player.actions.placing and player.actions.jump_remaining == 0.0, "focus loss clears placement and jump buffer")
	player._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not player.step_placement(1.0, true, true), "focus recovery does not restart held placement")
	player.actions.set_place_pressed(true, true)
	paused = true
	check(not player.actions.placing, "scene pause cancels repetition")
	paused = false
	check(not player.step_placement(1.0, true, true), "unpause does not restart held placement")
	# Click-to-capture route never acts on blocks (headless never captures).
	player.actions.set_place_pressed(true, true)
	var capture := InputEventMouseButton.new()
	capture.button_index = MOUSE_BUTTON_LEFT
	capture.pressed = true
	count = world.blocks.size()
	player._unhandled_input(capture)
	check(not player.actions.placing and world.blocks.size() == count, "capture click clears old hold without modifying blocks")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "all tests leave OS pointer uncaptured")
	player.actions.cancel()
	player.camera.rotation.x = 0
	check(not player.begin_placement(), "empty ray blocks immediate placement")
	check(not player.step_placement(0.3, true, true), "empty ray also blocks repeated placement")
	# Repetition must still pass through the existing placement constraints.
	player.actions.cancel()
	player.camera.rotation.x = -PI / 2.0 + 0.01
	count = world.blocks.size()
	check(not player.begin_placement(), "immediate placement inside player is rejected")
	check(not player.step_placement(0.3, true, true) and world.blocks.size() == count, "repeat inside player is rejected without adding blocks")
	player.actions.cancel()
	player.camera.rotation.x = -0.7
	var saved_blocks: Dictionary = world.blocks
	world.blocks = saved_blocks.duplicate()
	for index in range(world.MAX_BLOCKS - world.blocks.size()):
		world.blocks[Vector3i(100 + index, 0, 100)] = null
	check(world.blocks.size() >= world.MAX_BLOCKS, "block capacity reached (terrain gestures do not use it)")
	check(not player.step_placement(0.3, true, true), "capacity also blocks repeated placement")
	world.blocks = saved_blocks
	player.actions.cancel()
	# Put a full column directly under the player to exercise the real ledge timer.
	player.position = Vector3(40.5, 2.0, 40.5)
	world.add_block(Vector3i(40, 0, 40), 2)
	player.set_physics_process(true)
	await frames(60)
	player.set_physics_process(false)
	player.actions.cancel()
	player.step_movement(1.0 / 60.0, Vector2.ZERO, false)
	player.position.x = 42.5
	player.step_movement(1.0 / 60.0, Vector2.ZERO, false)
	player.step_movement(0.05, Vector2.ZERO, true)
	check(player.velocity.y > 6.0, "real physics jumps shortly after walking off a block")
	var before_second := player.velocity.y
	player.step_movement(1.0 / 60.0, Vector2.ZERO, true)
	check(player.velocity.y < before_second, "real physics cannot jump a second time in air")
	# Late landing press: start just above the flat base while descending.
	player.actions.cancel()
	player.position = Vector3(45.5, 0.08, 45.5)
	player.velocity = Vector3(0, -3, 0)
	player.step_movement(1.0 / 60.0, Vector2.ZERO, false)
	player.step_movement(1.0 / 60.0, Vector2.ZERO, true)
	var bounced := false
	for index in range(5):
		await physics_frame
		player.step_movement(1.0 / 60.0, Vector2.ZERO, false)
		bounced = bounced or player.velocity.y > 6.0
	check(bounced, "real physics executes buffered press on landing")
	for index in range(180):
		await physics_frame
		player.step_movement(1.0 / 60.0, Vector2.ZERO, false)
	check(player.is_on_floor() and absf(player.position.y) < 0.05, "buffered jump lands without automatic repeat")
	print("RESULT: %d timing checks, %d failures" % [checks, failures])
	root.remove_child(world)
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)