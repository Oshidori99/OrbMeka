extends SceneTree
const Timing = preload("res://scripts/action_timing.gd")
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
		await physics_frame

func _run() -> void:
	var timer := Timing.new()
	check(timer.set_break_pressed(true, true), "first break is immediate")
	check(not timer.set_break_pressed(true, true), "duplicate press does not break twice")
	check(not timer.tick_break(0.299, true, true), "no repeat before 300 ms")
	check(timer.tick_break(0.001, true, true), "repeat at 300 ms")
	check(timer.tick_break(0.3, true, true), "next repeat at 600 ms")
	check(timer.tick_break(2.0, true, true), "slow frame produces one break")
	check(not timer.tick_break(0.0, true, true), "no catch-up burst")
	check(not timer.tick_break(0.299, true, true), "full interval after slow frame")
	check(timer.tick_break(0.001, true, true), "normal cadence resumes")
	timer.set_break_pressed(false, true)
	check(not timer.tick_break(1.0, true, true), "release stops until new press")
	check(not timer.set_break_pressed(true, false), "inactive press cannot begin breaking")
	timer.set_break_pressed(true, true)
	check(not timer.tick_break(1.0, false, true), "inactive tick cancels breaking")
	check(not timer.tick_break(1.0, true, true), "reactivation with held button cannot restart")
	timer.set_break_pressed(true, true)
	check(not timer.tick_break(1.0, true, false), "sampled release also stops")
	timer.set_break_pressed(true, true)
	timer.set_place_pressed(true, true)
	check(timer.tick_break(0.3, true, true) and timer.tick_place(0.3, true, true), "break and place timers remain independent")
	check(not timer.tick_place(0.1, true, true), "placement waits for the next 300 ms interval")
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = world.player
	await frames(60)
	player.set_physics_process(false)
	# Isoler les actions des chargements de zones déclenchés par le déplacement de la fixture.
	world.set_process(false)
	player.position = Vector3(30.5, 0.0, 30.5)
	player.camera.rotation.x = 0
	for z in [28, 27, 26]:
		world.add_block(Vector3i(30, 1, z), 2)
	await frames(3)
	var count: int = world.blocks.size()
	check(not player.begin_breaking(), "visual exploration rejects immediate breaking")
	check(world.blocks.size() == count, "disabled breaking preserves blocks")
	await frames(3)
	check(not player.step_breaking(0.299, true, true), "gameplay break waits 299 ms")
	check(not player.step_breaking(0.001, true, true), "visual exploration rejects repeated breaking")
	check(world.blocks.size() == count, "disabled repetition preserves blocks")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	player._input(release)
	check(not player.step_breaking(1.0, true, true), "left release handler stops repeat")
	player.actions.set_break_pressed(true, true)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	player._unhandled_input(escape)
	check(not player.actions.breaking, "Escape cancels breaking")
	player.actions.set_break_pressed(true, true)
	player._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not player.actions.breaking, "focus loss cancels breaking")
	player._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not player.step_breaking(1.0, true, true), "focus recovery does not resume breaking")
	player.actions.set_break_pressed(true, true)
	paused = true
	check(not player.actions.breaking, "pause cancels breaking")
	paused = false
	check(not player.step_breaking(1.0, true, true), "unpause does not resume breaking")
	player.actions.set_break_pressed(true, true)
	var capture := InputEventMouseButton.new()
	capture.button_index = MOUSE_BUTTON_LEFT
	capture.pressed = true
	count = world.blocks.size()
	player._unhandled_input(capture)
	check(not player.actions.breaking and world.blocks.size() == count, "capture click never breaks a block or starts a hold")
	player.camera.rotation.x = -PI / 2.0 + 0.01
	check(not player.begin_breaking(), "base rejects immediate breaking")
	check(not player.step_breaking(0.3, true, true), "base rejects repeated breaking")
	player.actions.cancel()
	player.position.z = 40.5
	player.camera.rotation.x = 0
	check(not player.begin_breaking(), "out-of-reach blocks reject immediate breaking")
	check(not player.step_breaking(0.3, true, true), "out-of-reach blocks reject repeated breaking")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pointer never captured")
	print("RESULT: %d breaking checks, %d failures" % [checks, failures])
	root.remove_child(world)
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)