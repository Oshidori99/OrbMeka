extends CharacterBody3D

const ActionTiming = preload("res://scripts/action_timing.gd")

const SPEED := 5.5
const JUMP_SPEED := 8.4
const JUMP_GRAVITY := 14.0
const SENSITIVITY := 0.0025
# Sensibilité réglée (Paramètres généraux → Souris), 100 % = SENSITIVITY.
var sensitivity := SENSITIVITY
const REACH := 5.0
# Portées réglables (Attributs → Blocs, 0.0.3.13) ; REACH reste la portée par défaut.
var break_reach := REACH
var place_reach := REACH

var actions := ActionTiming.new()
var camera: Camera3D
# Local to the character: quicker flight while retaining the jump height.
var gravity: float = JUMP_GRAVITY
var jump_height := JUMP_SPEED * JUMP_SPEED / (2.0 * JUMP_GRAVITY)
var jump_speed := JUMP_SPEED
var rise_gravity := JUMP_GRAVITY
# Vitesses de marche réglables (Paramètres → Attributs → Marche).
var walk_forward := SPEED
var walk_side := SPEED
var walk_back := SPEED
# Se baisser (0.0.3.15) : touche de Contrôles maintenue ; vitesses et gravité dans Attributs.
const CROUCH_SPEED := 1.5
const CROUCH_GRAVITY := 28.0
const EYE_HEIGHT := 1.62
const CROUCH_DROP := 0.32
# Hauteur des yeux réglable (Attributs → Vue, 0.0.3.17) ; baissé : un peu plus bas.
var eye_height := EYE_HEIGHT
var crouching := false
var crouch_toggle := false
var crouch_latched := false
# Personnage choisi (Paramètres → Personnage, 0.0.3.16) ; corps visible en regardant en bas (0.0.3.26).
var character := "boy14"
var skin := "light"
const CharacterPreview = preload("res://scripts/character_preview.gd")
const CharacterModel = preload("res://scripts/character_model.gd")
# Part de la hauteur d'un humain gardée sous le cou ; recul du corps derrière la caméra (m).
const BODY_NECK := 0.52
const BODY_BACK := 0.3
const BODY_SHADER := "shader_type spatial;
render_mode cull_disabled;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform float roughness = 0.8;
uniform vec3 emission = vec3(0.0);
uniform mat4 to_body;
uniform float neck = 100.0;
varying float body_y;
void vertex() {
	body_y = (to_body * vec4(VERTEX, 1.0)).y;
}
void fragment() {
	if (body_y > neck) {
		discard;
	}
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb;
	ROUGHNESS = roughness;
	EMISSION = emission;
}"
var body: Node3D
var body_shadow: Node3D
var body_key := ""
var body_shader: Shader
var crouch_forward := CROUCH_SPEED
var crouch_side := CROUCH_SPEED
var crouch_back := CROUCH_SPEED
var crouch_gravity := CROUCH_GRAVITY
# Courir (0.0.3.24) : touche de Contrôles (mode dans Contrôles, 0.0.3.25) ; vitesses dans Attributs → Courir.
const RUN_SPEED := 8.5
var running := false
# Mode pour courir (0.0.3.25) : "hold" (Maintenir), "latch" (Maintenir conditionnel), "toggle" (Basculer).
var run_mode := "hold"
var run_latched := false
var run_forward := RUN_SPEED
var run_side := RUN_SPEED
var run_back := RUN_SPEED
# Plus vite / Moins vite (0.0.4.3, ↑ ↓) : marche, course et, depuis 0.0.4.4, baissé multipliés par speed_scale
# (1 = vitesse normale), entre speed_min et speed_max ; gardé jusqu'au prochain changement.
var speed_scale := 1.0
var speed_max := 2.0
var speed_min := 0.5
var speed_up_rate := 0.4
var speed_down_rate := 0.4
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
	camera.position.y = EYE_HEIGHT
	camera.fov = 75.0
	camera.rotation.x = -0.12
	camera.current = true
	add_child(camera)
	# Capture only after the player explicitly clicks in the game.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	# Release must be observed even if a Control consumes the event.
	# Casser / Poser : touche ou bouton choisi dans Paramètres → Contrôles (0.0.3.12).
	if event.is_action_released("place_block"):
		actions.stop_placing()
	if event.is_action_released("break_block"):
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
		rotate_y(-event.relative.x * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * sensitivity, deg_to_rad(-89.0), deg_to_rad(89.0))
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			actions.cancel()
			if event.button_index == MOUSE_BUTTON_LEFT and DisplayServer.get_name() != "headless":
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	# Casser, poser, changer de bloc : touches ou boutons de Paramètres → Contrôles.
	if event.is_action_pressed("break_block"):
		begin_breaking()
	elif event.is_action_pressed("place_block"):
		begin_placement()
	elif event.is_action_pressed("block_previous"):
		cycle_block(-1)
	elif event.is_action_pressed("block_next"):
		cycle_block(1)

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
	update_run(false, false, false, false, false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func apply_settings(values: Dictionary) -> void:
	jump_height = values.jump_height
	jump_speed = values.jump_speed
	rise_gravity = jump_speed * jump_speed / (2.0 * jump_height)
	gravity = values.fall_gravity
	actions.place_interval = values.place_ms / 1000.0
	actions.break_interval = values.break_ms / 1000.0
	walk_forward = values.walk_forward
	walk_side = values.walk_side
	walk_back = values.walk_back
	crouch_forward = float(values.get("crouch_forward", CROUCH_SPEED))
	crouch_side = float(values.get("crouch_side", CROUCH_SPEED))
	crouch_back = float(values.get("crouch_back", CROUCH_SPEED))
	crouch_gravity = float(values.get("crouch_gravity", CROUCH_GRAVITY))
	run_forward = float(values.get("run_forward", RUN_SPEED))
	run_side = float(values.get("run_side", RUN_SPEED))
	run_back = float(values.get("run_back", RUN_SPEED))
	speed_max = float(values.get("speed_max", 200.0)) / 100.0
	speed_min = float(values.get("speed_min", 50.0)) / 100.0
	speed_up_rate = float(values.get("speed_up_rate", 40.0)) / 100.0
	speed_down_rate = float(values.get("speed_down_rate", 40.0)) / 100.0
	speed_scale = clampf(speed_scale, speed_min, speed_max)
	character = str(values.get("character", "boy14"))
	skin = str(values.get("skin", "light"))
	sync_body()
	eye_height = float(values.get("eye_height", EYE_HEIGHT))
	camera.position.y = eye_height
	break_reach = float(values.get("break_reach", REACH))
	place_reach = float(values.get("place_reach", REACH))
	sensitivity = SENSITIVITY * float(values.get("mouse_sensitivity", 100.0)) / 100.0
	# Champ de vision réglé (Vidéo → Jeu), valable dans tous les mondes.
	camera.fov = float(values.get("fov", 75.0))
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
	update_crouch(active, Input.is_action_pressed("crouch"), Input.is_action_just_pressed("crouch"))
	update_run(active, Input.is_action_pressed("sprint"), Input.is_action_just_pressed("sprint"), direction != Vector2.ZERO, jump_requested)
	update_speed(delta, active, Input.is_action_pressed("speed_up"), Input.is_action_pressed("speed_down"), Input.is_action_pressed("speed_reset"))
	step_breaking(delta, active, Input.is_action_pressed("break_block"))
	step_placement(delta, active, Input.is_action_pressed("place_block"))
	step_movement(delta, direction, jump_requested)

# Corps en première personne (0.0.3.26) : le modèle du personnage, aux pieds du joueur, tourné avec lui.
# La caméra garde la hauteur des yeux réglée, même pour un petit personnage ou un animal.
# Humain : la tête, juste sous la caméra, cacherait la vue vers le bas ; elle est coupée au cou
# pour l'œil, mais une copie entière garde l'ombre au sol (ombre seule).
func sync_body() -> void:
	var key := character + ":" + skin
	if key == body_key or not CharacterPreview.CHARACTERS.has(character):
		return
	body_key = key
	for old in [body, body_shadow]:
		if is_instance_valid(old):
			remove_child(old)
			old.queue_free()
	body = _place_body(CharacterModel.build(character, skin), "Body")
	body_shadow = null
	if not CharacterPreview.is_human(character):
		return
	var bounds := _body_bounds(body)
	var neck := bounds.position.y + bounds.size.y * BODY_NECK
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var to_body := _to_body(mesh_instance, body)
		var whole: Material = mesh_instance.material_override
		mesh_instance.material_override = null
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var base: Material = mesh_instance.get_surface_override_material(surface)
			if base == null:
				base = whole if whole else mesh_instance.mesh.surface_get_material(surface)
			mesh_instance.set_surface_override_material(surface, _cut_material(base, to_body, neck))
	body_shadow = _place_body(CharacterModel.build(character, skin), "BodyShadow")
	for node in body_shadow.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

# Tourné vers l'avant du joueur (-Z), semelles posées au sol, centré un peu en arrière de la caméra.
func _place_body(model: Node3D, node_name: String) -> Node3D:
	model.name = node_name
	model.rotation.y = PI
	add_child(model)
	var bounds := _body_bounds(model)
	var center := bounds.get_center() * model.scale
	model.position = Vector3(center.x, -bounds.position.y * model.scale.y, center.z + BODY_BACK)
	return model

# Boîte du modèle dans son propre repère (sans sa position ni sa rotation).
func _body_bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = _to_body(node, model) * (node as MeshInstance3D).get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds

func _to_body(node: Node3D, model: Node3D) -> Transform3D:
	var placed := Transform3D()
	var step: Node = node
	while step != model:
		placed = (step as Node3D).transform * placed
		step = step.get_parent()
	return placed

func _cut_material(base: Material, to_body: Transform3D, neck: float) -> ShaderMaterial:
	if body_shader == null:
		body_shader = Shader.new()
		body_shader.code = BODY_SHADER
	var material := ShaderMaterial.new()
	material.shader = body_shader
	material.set_shader_parameter("to_body", Projection(to_body))
	material.set_shader_parameter("neck", neck)
	if base is StandardMaterial3D:
		var standard := base as StandardMaterial3D
		material.set_shader_parameter("albedo", standard.albedo_color)
		material.set_shader_parameter("roughness", standard.roughness)
		if standard.albedo_texture:
			material.set_shader_parameter("albedo_texture", standard.albedo_texture)
		if standard.emission_enabled:
			material.set_shader_parameter("emission", standard.emission * standard.emission_energy_multiplier)
	return material

# Se baisser (0.0.3.18) : Maintenir = tant que la touche est enfoncée ;
# Basculer = chaque appui change l'état, gardé même touche relâchée.
func update_crouch(active: bool, held: bool, just_pressed: bool) -> void:
	if not active:
		crouching = crouch_latched if crouch_toggle else false
		return
	if crouch_toggle:
		if just_pressed:
			crouch_latched = not crouch_latched
		crouching = crouch_latched
	else:
		crouch_latched = false
		crouching = held

# Courir (0.0.3.25) : Maintenir = tant que la touche est enfoncée ; Basculer = chaque appui
# change l'état ; Maintenir conditionnel = un appui lance la course, arrêtée dès qu'on
# s'arrête (touche relâchée), saute, se baisse ou perd le jeu (pause, menu, focus) ;
# il faut alors réappuyer, même si la touche est restée enfoncée.
func update_run(active: bool, held: bool, just_pressed: bool, moving: bool, jumped: bool) -> void:
	if not active:
		if run_mode != "toggle":
			run_latched = false
		running = run_latched
		return
	match run_mode:
		"toggle":
			if just_pressed:
				run_latched = not run_latched
			running = run_latched
		"latch":
			if just_pressed:
				run_latched = true
			# Touche encore enfoncée à l'arrêt : la course démarre au premier pas.
			if jumped or crouching or (not moving and not held):
				run_latched = false
			running = run_latched
		_:
			run_latched = false
			running = held

# Plus vite / Moins vite (0.0.4.3), maintenus : la vitesse change peu à peu, en marchant comme
# en courant ou baissé, même à l'arrêt ; les deux ensemble s'annulent. Rien en pause ou souris libre.
# Vitesse par défaut (0.0.4.4, R + ↓) : retour à 100 %, même si ↓ est tenue avec.
func update_speed(delta: float, active: bool, up: bool, down: bool, reset: bool = false) -> void:
	if not active:
		return
	if reset:
		speed_scale = 1.0
		return
	if up == down:
		return
	if up:
		speed_scale = minf(speed_scale + speed_up_rate * delta, speed_max)
	else:
		speed_scale = maxf(speed_scale - speed_down_rate * delta, speed_min)

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
	# Baissé : plus lourd, la chute est tirée par la gravité « baissé ».
	var fall_gravity := crouch_gravity if crouching else gravity
	if remaining > 0.0:
		vertical_distance += end_speed * remaining - 0.5 * fall_gravity * remaining * remaining
		end_speed -= fall_gravity * remaining
	velocity.y = vertical_distance / delta if delta > 0.0 else 0.0
	# direction.y < 0 : avancer ; > 0 : reculer ; direction.x : de côté.
	var step := direction.limit_length(1.0)
	# Baissé l'emporte sur courir.
	# Plus vite / Moins vite : marche, course et baissé (0.0.4.4) ensemble ; leurs écarts restent.
	var side := (crouch_side if crouching else (run_side if running else walk_side)) * speed_scale
	var forward := (crouch_forward if crouching else (run_forward if running else walk_forward)) * speed_scale
	var back := (crouch_back if crouching else (run_back if running else walk_back)) * speed_scale
	var local := Vector3(step.x * side, 0.0, step.y * (forward if step.y < 0.0 else back))
	# Caméra un peu plus basse quand on est baissé.
	var eye := maxf(0.2, eye_height - CROUCH_DROP) if crouching else eye_height
	camera.position.y = move_toward(camera.position.y, eye, 4.0 * delta)
	var movement := global_transform.basis * local
	velocity.x = movement.x
	velocity.z = movement.z
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
	# Rayon jusqu'à la plus grande portée ; chaque action vérifie ensuite la sienne.
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_transform.basis.z * maxf(break_reach, place_reach))
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func overlaps_cell(cell: Vector3i) -> bool:
	var body_box := AABB(global_position + Vector3(-0.33, 0.01, -0.33), Vector3(0.66, 1.78, 0.66))
	return body_box.intersects(AABB(Vector3(cell), Vector3.ONE))