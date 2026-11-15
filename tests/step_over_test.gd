extends SceneTree
# 0.0.7.7 : pentes raides plus lentes en montée ; petits obstacles enjambés en avançant (sans sauter), hauts : bloqués.
const PlayerScript = preload("res://scripts/player.gd")
const DELTA := 1.0 / 60.0
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

func box(world: Node3D, size: Vector3, center: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var made := BoxShape3D.new()
	made.size = size
	shape.shape = made
	body.add_child(shape)
	world.add_child(body)
	body.global_position = center
	return body

# Avance tout droit (vers -Z) pendant « frames » images ; rend la position finale.
func walk(player: CharacterBody3D, frames: int) -> Vector3:
	for index in range(frames):
		await physics_frame
		player.step_movement(DELTA, Vector2(0.0, -1.0), false)
	return player.global_position

func _run() -> void:
	# Pente : plat ou descente, vitesse normale ; montée raide, plus lente ; de côté, presque pas ralenti.
	var steep := Vector3(0.0, cos(deg_to_rad(45.0)), sin(deg_to_rad(45.0)))
	check(is_equal_approx(PlayerScript.slope_factor(Vector3.UP, Vector2(0, -1)), 1.0), "flat ground: full speed")
	check(PlayerScript.slope_factor(steep, Vector2(0, -1)) < 0.65, "steep slope uphill: much slower")
	check(is_equal_approx(PlayerScript.slope_factor(steep, Vector2(0, 1)), 1.0), "downhill: full speed")
	check(PlayerScript.slope_factor(steep, Vector2(1, 0)) > 0.95, "across the slope: almost full speed")
	var gentle := Vector3(0.0, cos(deg_to_rad(8.0)), sin(deg_to_rad(8.0)))
	check(is_equal_approx(PlayerScript.slope_factor(gentle, Vector2(0, -1)), 1.0), "gentle slope: full speed")
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var player: CharacterBody3D = world.player
	player.set_physics_process(false)
	world.set_process(false)
	# Sol plat d'essai, bien au-dessus du terrain.
	box(world, Vector3(20, 1, 20), Vector3(0, 29.5, 0))
	box(world, Vector3(2.0, 0.3, 0.4), Vector3(0, 30.15, -2.0))
	box(world, Vector3(2.0, 0.9, 0.4), Vector3(4.0, 30.45, -2.0))
	player.global_position = Vector3(0, 30.05, 0)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	for index in range(20):
		await physics_frame
		player.step_movement(DELTA, Vector2.ZERO, false)
	check(player.is_on_floor(), "standing on the test floor")
	var low := await walk(player, 90)
	check(low.z < -3.0 and absf(low.y - 30.0) < 0.1, "a 30 cm stone is stepped over without jumping (z %.2f, y %.2f)" % [low.z, low.y])
	player.global_position = Vector3(4.0, 30.05, 0)
	player.velocity = Vector3.ZERO
	for index in range(10):
		await physics_frame
		player.step_movement(DELTA, Vector2.ZERO, false)
	var high := await walk(player, 90)
	check(high.z > -2.0, "a 90 cm wall still blocks (z %.2f)" % high.z)
	root.remove_child(world)
	world.queue_free()
	await process_frame
	print("RESULT: %d step over checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
