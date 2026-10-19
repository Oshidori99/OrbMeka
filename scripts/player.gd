extends CharacterBody3D

const ActionTiming = preload("res://scripts/action_timing.gd")

const SPEED := 5.5
const JUMP_SPEED := 8.4
const JUMP_GRAVITY := 14.0
const SENSITIVITY := 0.0025
const REACH := 5.0

var actions := ActionTiming.new()
var camera: Camera3D
# Local to the character: quicker flight while retaining the jump height.
var gravity: float = JUMP_GRAVITY
var selected_type := 0:
	set(value):
		selected_type = value
		if is_instance_valid(world):
			world.update_selected_block()
var world: Node3D

func _ready() -> void:
	world = get_parent()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.fov = 75.0
	camera.rotation.x = -0.12
	camera.current = true
	add_child(camera)
	# Capture only after the player explicitly clicks in the game.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	# Release must be observed even if a Control consumes the event.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		actions.stop_placing()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		actions.stop_breaking()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			release_controls()
		elif event.keycode == KEY_1 or event.physical_keycode == KEY_1:
			selected_type = 0
		elif event.keycode == KEY_2 or event.physical_keycode == KEY_2:
			selected_type = 1
		elif event.keycode == KEY_3 or event.physical_keycode == KEY_3:
			selected_type = 2
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * SENSITIVITY, deg_to_rad(-89.0), deg_to_rad(89.0))
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			actions.cancel()
			if event.button_index == MOUSE_BUTTON_LEFT and DisplayServer.get_name() != "headless":
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_block(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_block(1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			begin_breaking()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			begin_placement()

func cycle_block(direction: int) -> void:
	selected_type = wrapi(selected_type + direction, 0, world.BLOCK_NAMES.size())

func begin_breaking() -> bool:
	if actions.set_break_pressed(true, true):
		return world.break_target(get_target())
	return false

func step_breaking(delta: float, active: bool, button_held: bool) -> bool:
	if actions.tick_break(delta, active, button_held):
		return world.break_target(get_target())
	return false

func begin_placement() -> bool:
	if actions.set_place_pressed(true, true):
		return world.place_target(get_target(), selected_type)
	return false

func step_placement(delta: float, active: bool, button_held: bool) -> bool:
	if actions.tick_place(delta, active, button_held):
		return world.place_target(get_target(), selected_type)
	return false

func release_controls() -> void:
	actions.cancel()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		release_controls()

func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	var jump_requested := false
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		direction = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		jump_requested = Input.is_action_just_pressed("jump")
	var active := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	step_breaking(delta, active, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	step_placement(delta, active, Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	step_movement(delta, direction, jump_requested)

# The same movement step is used by gameplay and windowless physics tests.
func step_movement(delta: float, direction: Vector2, jump_requested: bool) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if actions.tick_jump(delta, is_on_floor(), jump_requested):
		velocity.y = JUMP_SPEED
	var movement := global_transform.basis * Vector3(direction.x, 0.0, direction.y).limit_length(1.0)
	velocity.x = movement.x * SPEED
	velocity.z = movement.z * SPEED
	move_and_slide()
	position.x = clampf(position.x, -58.0, 58.0)
	position.z = clampf(position.z, -58.0, 58.0)
	if position.y < -10.0:
		actions.cancel()
		position = world.spawn_position()
		velocity = Vector3.ZERO

func get_target() -> Dictionary:
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_transform.basis.z * REACH)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func overlaps_cell(cell: Vector3i) -> bool:
	var body_box := AABB(global_position + Vector3(-0.33, 0.01, -0.33), Vector3(0.66, 1.78, 0.66))
	return body_box.intersects(AABB(Vector3(cell), Vector3.ONE))