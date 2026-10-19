extends SceneTree
# Jump trajectory measured through actual CharacterBody3D movement at 60 Hz.
var failures := 0
var checks := 0
const DT := 1.0 / 60.0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func step(player: CharacterBody3D, direction := Vector2.ZERO, jump := false) -> void:
	await physics_frame
	player.step_movement(DT, direction, jump)

func _run() -> void:
	var world: Node3D = load("res://world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	player.position = Vector3(45.5, 0.02, 45.5)
	player.velocity = Vector3.ZERO
	player.actions.cancel()
	for index in range(10):
		await step(player)
	var base := player.position.y
	var peak := 0.0
	var ascent := 0.0
	var flight := 0.0
	for index in range(180):
		await step(player, Vector2.ZERO, index == 0)
		if player.position.y - base > peak:
			peak = player.position.y - base
			ascent = (index + 1) * DT
		if index > 2 and player.is_on_floor():
			flight = (index + 1) * DT
			break
	print("JUMP_PROFILE: gravity=%.3f impulse=%.3f height=%.3f ascent=%.3f flight=%.3f" % [player.gravity, player.JUMP_SPEED, peak, ascent, flight])
	if not OS.get_cmdline_user_args().has("--measure-only"):
		check(flight >= 1.1 and flight <= 1.3, "jump returns to ground in about 1.2 seconds")
		check(peak >= 2.3 and peak <= 2.75, "jump retains approximately 2.5 metre height")
		check(ascent >= 0.55 and ascent <= 0.65, "ascent takes about 0.6 seconds")
		check(player.is_on_floor(), "jump lands without sticking or automatic bounce")
		# Move above a single block and land on it, using the real collision capsule.
		world.add_block(Vector3i(45, 0, 42), 2)
		await physics_frame
		player.position = Vector3(45.5, 0.02, 44.5)
		player.velocity = Vector3.ZERO
		player.actions.cancel()
		for index in range(5):
			await step(player)
		for index in range(110):
			await step(player, Vector2(0, -1) if index < 20 else Vector2.ZERO, index == 0)
		check(player.is_on_floor() and absf(player.position.y - 1.0) < 0.05, "jump can mount and land on a one metre block")
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "test never captures pointer")
		print("RESULT: %d trajectory checks, %d failures" % [checks, failures])
	root.remove_child(world)
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)