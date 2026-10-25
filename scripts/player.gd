extends CharacterBody3D

# 0.0.4.15 : une vitesse a changé (↑ ↓, ⌫) : l'application met à jour les Attributs → Vitesses actuelles.
signal speeds_changed

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
# 0.0.4.6 (#105) : réglages à part, ↑ ↓ + une touche : marche (walk_scale), course (run_scale),
# casse et pose (break_scale, place_scale : plus haut = plus rapide, mode développeur seulement).
# Limites : Attributs → Changer de vitesse en mode développeur, sinon DEFAULT_MIN à DEFAULT_MAX.
const DEFAULT_MIN := 0.75
const DEFAULT_MAX := 1.5
const SCALES := ["speed", "walk", "run", "break", "place"]
var walk_scale := 1.0
var run_scale := 1.0
var break_scale := 1.0
var place_scale := 1.0
var break_base := 0.3
var place_base := 0.3
# Touches qui font d'un clic un réglage de vitesse (Controls.click_modifiers, donné par l'application) ;
# 0.0.4.7 : déplacements bloqués pendant un réglage (Controls.blocked_moves, ex. A avec ↑).
const Controls = preload("res://scripts/controls.gd")
var click_modifiers: Array = Controls.click_modifiers(Controls.defaults())
var move_blocks: Dictionary = Controls.blocked_moves(Controls.defaults())
# Voler (0.0.4.5) : touche Voler (Espace deux fois) pour commencer ou arrêter ; sans gravité, Sauter monte,
# Se baisser descend. Vitesses dans Attributs → Voler ; ↑ ↓ les changent aussi.
const FLY_SPEED := 10.0
const FLY_VERTICAL := 7.0
# Plafond du vol (m au-dessus du sol plat).
const FLY_CEILING := 60.0
var flying := false
var fly_forward := FLY_SPEED
var fly_side := FLY_SPEED
var fly_back := FLY_SPEED
# Voler vite (0.0.4.8) : touche Courir en vol ; ↑ + R (run_scale) compte aussi.
const FLY_RUN_SPEED := 15.0
var fly_run_forward := FLY_RUN_SPEED
var fly_run_side := FLY_RUN_SPEED
var fly_run_back := FLY_RUN_SPEED
# Vues (0.0.4.9, #85) : F4 passe de la première personne à la vue de derrière, puis de devant.
# La caméra des yeux (camera) vise toujours ; view_camera, rattachée aux yeux, montre les deux autres
# vues à VIEW_DISTANCE, rapprochée si un bloc est entre les deux. Corps entier visible hors première personne.
const VIEWS := ["first", "back", "front"]
const VIEW_NAMES := {"first": "Première personne", "back": "Vue de derrière", "front": "Vue de devant"}
const VIEW_DISTANCE := 4.0
var view := "first"
var view_camera: Camera3D
var fly_up := FLY_VERTICAL
var fly_down := FLY_VERTICAL
var input_ready_frame := -1
var selected_type := 0:
	set(value):
		selected_type = value
		if is_instance_valid(world):
			world.update_selected_block()
var world: Node3D
# 0.0.5.9 : pinceau du clic droit (0 poser, 1 aplanir, 2 lisser ; B + T) et taille du geste
# (0 : 1/8, 1 : 1/4, 2 : 1/2 bloc ; B + molette). Un texte en bas les rappelle au changement seulement.
var brush := 0
var brush_size := 0
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
	view_camera = Camera3D.new()
	view_camera.name = "ViewCamera"
	camera.add_child(view_camera)
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
			world.show_choice("Matière : %s" % world.BLOCK_NAMES[selected_type])
		elif event.keycode == KEY_2 or event.physical_keycode == KEY_2:
			selected_type = 2
			world.show_choice("Matière : %s" % world.BLOCK_NAMES[selected_type])
		elif event.keycode == KEY_3 or event.physical_keycode == KEY_3:
			selected_type = 2
			world.show_choice("Matière : %s" % world.BLOCK_NAMES[selected_type])
		elif (event.physical_keycode == KEY_T and Input.is_physical_key_pressed(KEY_B)) or (event.physical_keycode == KEY_B and Input.is_physical_key_pressed(KEY_T)):
			cycle_brush()
		elif event.keycode == KEY_F4:
			cycle_view()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# 0.0.4.17 : mouvement réel de la souris (screen_relative), pas agrandi selon la taille de
		# l'affichage : dans un navigateur (affichage plus petit que 1280 px), la vue tournait trop vite.
		turn_view(event.screen_relative * (WEB_MOUSE_FACTOR if OS.has_feature("web") else 1.0))
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			actions.cancel()
			if event.button_index == MOUSE_BUTTON_LEFT and DisplayServer.get_name() != "headless":
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	# Casser, poser, changer de bloc : touches ou boutons de Paramètres → Contrôles.
	# Un clic avec ↑, ↓ ou ⌫ (0.0.4.6) règle la casse ou la pose : il ne casse ni ne pose.
	if event.is_action_pressed("break_block"):
		if not click_modified():
			begin_breaking()
	elif event.is_action_pressed("place_block"):
		if not click_modified():
			begin_placement()
	elif (event.is_action_pressed("block_previous") or event.is_action_pressed("block_next")) and Input.is_physical_key_pressed(KEY_B):
		cycle_size(1 if event.is_action_pressed("block_next") else -1)
	elif event.is_action_pressed("block_previous"):
		cycle_block(-1)
	elif event.is_action_pressed("block_next"):
		cycle_block(1)

# 0.0.4.19 : dans un navigateur, les déplacements de la souris arrivent bien plus grands (verrouillage du
# pointeur, écrans à haute densité) : la vue tournait encore trop vite. Réduits pour le Web seulement.
const WEB_MOUSE_FACTOR := 0.4

# Rotation de la vue par un déplacement de souris (en pixels de l'écran).
func turn_view(motion: Vector2) -> void:
	rotate_y(-motion.x * sensitivity)
	camera.rotation.x = clampf(camera.rotation.x - motion.y * sensitivity, deg_to_rad(-89.0), deg_to_rad(89.0))

# 0.0.5.9 : seulement le sable et la terre (plus la pierre pour l'instant) ; 1 : sable, 2 ou 3 : terre.
func cycle_block(_direction: int) -> void:
	selected_type = 2 if selected_type == 0 else 0
	world.show_choice("Matière : %s" % world.BLOCK_NAMES[selected_type])

func cycle_brush() -> void:
	brush = wrapi(brush + 1, 0, world.BRUSH_NAMES.size())
	world.show_choice("Clic droit : %s" % world.BRUSH_NAMES[brush])

func cycle_size(direction: int) -> void:
	brush_size = wrapi(brush_size + direction, 0, world.SIZE_NAMES.size())
	world.show_choice("Taille du geste : %s" % world.SIZE_NAMES[brush_size])

# 0.0.5.8 : un clic = un geste sur le terrain lisse (creuser ou ajouter 50 cm) ; pas de répétition en maintenant.
func begin_breaking() -> bool:
	actions.cancel()
	return world.break_target(get_target())

func step_breaking(_delta: float, _active: bool, _button_held: bool) -> bool:
	actions.cancel()
	return false

func begin_placement() -> bool:
	actions.cancel()
	return world.place_target(get_target(), selected_type)

func step_placement(_delta: float, _active: bool, _button_held: bool) -> bool:
	actions.cancel()
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
	place_base = values.place_ms / 1000.0
	break_base = values.break_ms / 1000.0
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
	fly_forward = float(values.get("fly_forward", FLY_SPEED))
	fly_side = float(values.get("fly_side", FLY_SPEED))
	fly_back = float(values.get("fly_back", FLY_SPEED))
	fly_run_forward = float(values.get("fly_run_forward", FLY_RUN_SPEED))
	fly_run_side = float(values.get("fly_run_side", FLY_RUN_SPEED))
	fly_run_back = float(values.get("fly_run_back", FLY_RUN_SPEED))
	fly_up = float(values.get("fly_up", FLY_VERTICAL))
	fly_down = float(values.get("fly_down", FLY_VERTICAL))
	speed_max = float(values.get("speed_max", 200.0)) / 100.0
	speed_min = float(values.get("speed_min", 50.0)) / 100.0
	speed_up_rate = float(values.get("speed_up_rate", 40.0)) / 100.0
	speed_down_rate = float(values.get("speed_down_rate", 40.0)) / 100.0
	# 0.0.4.15 : en mode développeur, les vitesses actuelles viennent des Attributs ; sinon, celles
	# de la partie restent (monde par défaut : non enregistrées). Toujours dans les limites.
	for scale in SCALES:
		var current: float = float(values.get("current_" + scale, 100.0)) / 100.0 if developer() else get(scale + "_scale")
		set(scale + "_scale", clampf(current, scale_min(), scale_max()))
	_apply_intervals()
	character = str(values.get("character", "boy14"))
	skin = str(values.get("skin", "light"))
	sync_body()
	_sync_body_view()
	eye_height = float(values.get("eye_height", EYE_HEIGHT))
	camera.position.y = eye_height
	break_reach = float(values.get("break_reach", REACH))
	place_reach = float(values.get("place_reach", REACH))
	sensitivity = SENSITIVITY * float(values.get("mouse_sensitivity", 100.0)) / 100.0
	# Champ de vision réglé (Vidéo → Jeu), valable dans tous les mondes.
	camera.fov = float(values.get("fov", 75.0))
	view_camera.fov = camera.fov
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
		direction = (Vector2(move_strength("move_right") - move_strength("move_left"), move_strength("move_back") - move_strength("move_forward"))).limit_length(1.0)
		jump_requested = Input.is_action_just_pressed("jump") and not wait_jump_release
	var active := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	update_fly(active, Input.is_action_just_pressed("fly"))
	# En vol, Se baisser sert à descendre : on ne se baisse pas.
	if flying:
		crouching = false
	else:
		update_crouch(active, Input.is_action_pressed("crouch"), Input.is_action_just_pressed("crouch"))
	# En vol, Espace monte : ce n'est pas un saut qui arrête la course (Maintenir conditionnel).
	update_run(active, Input.is_action_pressed("sprint"), Input.is_action_just_pressed("sprint"), direction != Vector2.ZERO, jump_requested and not flying)
	var changes := {}
	var resets := []
	for target in ["walk", "run", "break", "place"]:
		var faster := Input.is_action_pressed(target + "_up")
		if faster != Input.is_action_pressed(target + "_down"):
			changes[target] = 1.0 if faster else -1.0
		if Input.is_action_pressed(target + "_reset"):
			resets.append(target)
	if Input.is_action_pressed("move_reset"):
		resets.append("speed")
	update_speed(delta, active, Input.is_action_pressed("speed_up"), Input.is_action_pressed("speed_down"), Input.is_action_pressed("speed_reset_all"), changes, resets)
	var modified := click_modified()
	step_breaking(delta, active, Input.is_action_pressed("break_block") and not modified)
	step_placement(delta, active, Input.is_action_pressed("place_block") and not modified)
	if flying:
		var vertical := 0.0
		if active:
			vertical = float(Input.is_action_pressed("jump") and not wait_jump_release) - float(Input.is_action_pressed("crouch"))
		step_flight(delta, direction, vertical)
	else:
		step_movement(delta, direction, jump_requested)
	update_view()

# Vues (0.0.4.9) : F4, dans l'ordre de VIEWS.
func cycle_view() -> void:
	set_view(VIEWS[(VIEWS.find(view) + 1) % VIEWS.size()])

func set_view(name: String) -> void:
	view = name if name in VIEWS else "first"
	view_camera.fov = camera.fov
	if view == "first":
		camera.current = true
	else:
		view_camera.current = true
	_sync_body_view()
	update_view()

# Place la caméra de vue derrière (+Z des yeux) ou devant (-Z, tournée vers le joueur),
# plus près si un bloc la cacherait.
func update_view() -> void:
	if view == "first" or not is_inside_tree():
		return
	var side := 1.0 if view == "back" else -1.0
	view_camera.rotation = Vector3(0.0, 0.0 if view == "back" else PI, 0.0)
	var origin := camera.global_position
	var wanted := camera.global_transform * Vector3(0.0, 0.0, side * VIEW_DISTANCE)
	var query := PhysicsRayQueryParameters3D.create(origin, wanted)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var distance := VIEW_DISTANCE
	if not hit.is_empty():
		distance = maxf(0.3, origin.distance_to(hit.position) - 0.2)
	view_camera.position = Vector3(0.0, 0.0, side * distance)

# Hors première personne : le corps entier (la copie pour l'ombre est montrée), sans la tête coupée.
func _sync_body_view() -> void:
	if not is_instance_valid(body) or not is_instance_valid(body_shadow):
		return
	var whole := view != "first"
	body.visible = not whole
	for node in body_shadow.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if whole else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

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
# en courant, baissé ou en vol, même à l'arrêt ; les deux ensemble s'annulent. Rien en pause ou souris libre.
# 0.0.4.6 : changes = {cible: +1 ou -1} pour ↑ ↓ + une touche (la flèche seule ne compte alors pas) ;
# resets = cibles remises à 100 % (⌫ + touche) ; reset_all (⌫ deux fois) : tout à 100 %.
# Casse et pose ne changent que dans un monde en mode développeur.
func update_speed(delta: float, active: bool, up: bool, down: bool, reset_all: bool = false, changes: Dictionary = {}, resets: Array = []) -> void:
	if not active:
		return
	if reset_all:
		for scale in SCALES:
			set(scale + "_scale", 1.0)
		_apply_intervals()
		speeds_changed.emit()
		return
	for target in resets:
		set(target + "_scale", 1.0)
	if changes.is_empty() and up != down:
		changes = {"speed": 1.0 if up else -1.0}
	for target in changes:
		if target in ["break", "place"] and not developer():
			continue
		var rate := speed_up_rate if changes[target] > 0.0 else speed_down_rate
		set(target + "_scale", clampf(get(target + "_scale") + changes[target] * rate * delta, scale_min(), scale_max()))
	_apply_intervals()
	if not changes.is_empty() or not resets.is_empty():
		speeds_changed.emit()

func developer() -> bool:
	return is_instance_valid(world) and world.get("developer_mode") == true

func scale_min() -> float:
	return speed_min if developer() else DEFAULT_MIN

func scale_max() -> float:
	return speed_max if developer() else DEFAULT_MAX

# Intervalles de casse et de pose : plus la rapidité est haute, plus ils sont courts.
func _apply_intervals() -> void:
	actions.break_interval = break_base / break_scale
	actions.place_interval = place_base / place_scale

func click_modified() -> bool:
	return click_modifiers.any(func(code): return Input.is_physical_key_pressed(code))

# Force d'une touche de déplacement, 0 si elle sert à un réglage de vitesse (↑ + A : pas à gauche).
func move_strength(action: String) -> float:
	if move_blocks.get(action, []).any(func(code): return Input.is_physical_key_pressed(code)):
		return 0.0
	return Input.get_action_strength(action)

# Voler (0.0.4.5) : chaque appui sur la touche Voler commence ou arrête le vol (rien en pause).
func update_fly(active: bool, just_pressed: bool) -> void:
	if active and just_pressed:
		flying = not flying
		velocity.y = 0.0

# Un pas de vol : sans gravité ; vertical > 0 monte, < 0 descend. ↑ ↓ (speed_scale) comptent aussi.
func step_flight(delta: float, direction: Vector2, vertical: float) -> void:
	var step := direction.limit_length(1.0)
	var side := fly_run_side if running else fly_side
	var forward := fly_run_forward if running else fly_forward
	var back := fly_run_back if running else fly_back
	var local := Vector3(step.x * side, 0.0, step.y * (forward if step.y < 0.0 else back)) * speed_scale * (run_scale if running else 1.0)
	camera.position.y = move_toward(camera.position.y, eye_height, 4.0 * delta)
	var movement := global_transform.basis * local
	velocity = Vector3(movement.x, (fly_up if vertical > 0.0 else fly_down) * vertical * speed_scale, movement.z)
	move_and_slide()
	velocity.y = 0.0
	position.x = clampf(position.x, -58.0, 58.0)
	position.z = clampf(position.z, -58.0, 58.0)
	position.y = minf(position.y, FLY_CEILING)

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
	# 0.0.4.6 : la course suit aussi run_scale, la marche (et la marche baissée) walk_scale.
	var own := run_scale if running and not crouching else walk_scale
	var side := (crouch_side if crouching else (run_side if running else walk_side)) * speed_scale * own
	var forward := (crouch_forward if crouching else (run_forward if running else walk_forward)) * speed_scale * own
	var back := (crouch_back if crouching else (run_back if running else walk_back)) * speed_scale * own
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
