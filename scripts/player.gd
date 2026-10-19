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
var jump_height := JUMP_SPEED * JUMP_SPEED / (2.0 * JUMP_GRAVITY)
var jump_speed := JUMP_SPEED
var rise_gravity := JUMP_GRAVITY
var input_ready_frame := -1
var selected_type := 0:
	set(value):
		selected_type = value
		if is_instance_valid(world):
			world.update_selected_block()
var world: Node3D
var wait_jump_release := false

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
	if Engine.get_process_frames() <= input_ready_frame:
		return
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

func apply_settings(values: Dictionary) -> void:
	jump_height = values.jump_height
	jump_speed = values.jump_speed
	rise_gravity = jump_speed * jump_speed / (2.0 * jump_height)
	gravity = values.fall_gravity
	actions.place_interval = values.place_ms / 1000.0
	actions.break_interval = values.break_ms / 1000.0
	actions.cancel()

func resume_controls() -> void:
	release_controls()
	input_ready_frame = Engine.get_process_frames()
	# Space can activate the Resume button; that press must not also jump.
	wait_jump_release = Input.is_action_pressed("jump")
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		release_controls()

func _physics_process(delta: float) -> void:
	if not Input.is_action_pressed("jump"):
		wait_jump_release = false
	var direction := Vector2.ZERO
	var jump_requested := false
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		direction = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		jump_requested = Input.is_action_just_pressed("jump") and not wait_jump_release
	var active := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	step_breaking(delta, active, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	step_placement(delta, active, Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	step_movement(delta, direction, jump_requested)

# The same movement step is used by gameplay and windowless physics tests.
func step_movement(delta: float, direction: Vector2, jump_requested: bool) -> void:
	if actions.tick_jump(delta, is_on_floor(), jump_requested):
		velocity.y = jump_speed
	# Integrate both sides of the apex independently, including a mid-step apex.
	var remaining := delta
	var vertical_distance := 0.0
	var end_speed := velocity.y
	if end_speed > 0.0:
		var up_time := minf(remaining, end_speed / rise_gravity)
		vertical_distance = end_speed * up_time - 0.5 * rise_gravity * up_time * up_time
		end_speed -= rise_gravity * up_time
		remaining -= up_time
	if remaining > 0.0:
		vertical_distance += end_speed * remaining - 0.5 * gravity * remaining * remaining
		end_speed -= gravity * remaining
	velocity.y = vertical_distance / delta if delta > 0.0 else 0.0
	var movement := global_transform.basis * Vector3(direction.x, 0.0, direction.y).limit_length(1.0)
	velocity.x = movement.x * SPEED
	velocity.z = movement.z * SPEED
	move_and_slide()
	velocity.y = 0.0 if is_on_floor() or is_on_ceiling() else end_speed
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