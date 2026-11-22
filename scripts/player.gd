extends CharacterBody3D

# 0.0.4.15 : une vitesse a changé (↑ ↓, ⌫) : l'application met à jour les Attributs → Vitesses actuelles.
signal speeds_changed
# 0.0.8 (#171) : posé au sol après une chute ; hauteur (m) depuis le plus haut point en l'air, hauteur d'eau à l'arrivée.
signal landed(height: float, water: float)

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
const FirstPersonHand = preload("res://scripts/first_person_hand.gd")
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
# 0.0.5.10 : touches qui, tenues, font de la molette un réglage (taille du geste) : pas de changement de matière.
var wheel_modifiers: Array = Controls.wheel_modifiers(Controls.defaults())
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
# 0.0.7.2 : valeur de l'objet en main (case choisie de la barre d'objets, world.apply_held) : matière à poser,
# world.PICKAXE, ou -1 (main vide).
var selected_type := -1:
	set(value):
		selected_type = value
		if is_instance_valid(world):
			_update_pickaxe()
var world: Node3D
# 0.0.5.9 : pinceau du clic droit (0 poser, 1 aplanir, 2 lisser ; B + T) et taille du geste
# (0 : 1/8, 1 : 1/4, 2 : 1/2 bloc ; B + molette). Un texte en bas les rappelle au changement seulement.
var brush := 0
var brush_size := 0
# 0.0.7.17 : ce que fait le clic gauche (menu B + T) : 0 creuser / casser, 1 casser / récupérer des objets (clic court :
# ramasser), 2 récupérer des matériaux.
var left_mode := 0
const QUICK_CLICK := 0.25
var _break_pressed_at := 0
var wait_jump_release := false

func _ready() -> void:
	world = get_parent()
	# 0.0.7.6 (demande de l'utilisateur) : petites pentes plus faciles à monter (avant : 45°, défaut de Godot),
	# sans tout grimper ; un peu d'accroche au sol pour ne pas décoller dans les descentes.
	floor_max_angle = deg_to_rad(MAX_SLOPE_DEGREES)
	floor_snap_length = 0.25
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = EYE_HEIGHT
	camera.fov = DEFAULT_FOV
	camera.rotation.x = -0.12
	camera.current = true
	add_child(camera)
	view_camera = Camera3D.new()
	view_camera.name = "ViewCamera"
	camera.add_child(view_camera)
	_make_pickaxe()
	# 0.0.7.6 : main droite à la première personne, qui tient l'objet choisi (first_person_hand.gd).
	hand_view = FirstPersonHand.new()
	camera.add_child(hand_view)
	hand_view.setup(skin, Callable(world, "_kind_material") if world.has_method("_kind_material") else Callable())
	# 0.0.7.10 : main gauche, la même en miroir.
	left_hand_view = FirstPersonHand.new()
	camera.add_child(left_hand_view)
	left_hand_view.setup(skin, Callable(world, "_kind_material") if world.has_method("_kind_material") else Callable(), true)
	set_fov(camera.fov)
	# Capture only after the player explicitly clicks in the game.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	# Release must be observed even if a Control consumes the event.
	# Casser / Poser : touche ou bouton choisi dans Paramètres → Contrôles (0.0.3.12).
	if event.is_action_released("place_block"):
		actions.stop_placing()
		# 0.0.8 (#204) : un fruit en main, clic court : posé ; maintenu : mangé (world.step_eat).
		if is_instance_valid(world) and world.has_method("eat_release"):
			world.eat_release(get_target())
	if event.is_action_released("break_block"):
		actions.stop_breaking()
		# 0.0.7.17 : « Casser / Récupérer des objets » : un clic court ramasse l'objet visé (comme R).
		if left_mode == 1 and _break_pressed_at > 0 and Time.get_ticks_msec() - _break_pressed_at < QUICK_CLICK * 1000.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and is_instance_valid(world) and world.has_method("pick_up"):
			world.pick_up(get_target())
		_break_pressed_at = 0

func _unhandled_input(event: InputEvent) -> void:
	if Engine.get_process_frames() <= input_ready_frame:
		return
	# 0.0.7.2 : inventaire ouvert : ses clics et Échap sont à lui (la souris ne revient pas au jeu).
	if is_instance_valid(world) and (world.get("inventory_open") == true or world.get("death_open") == true or world.get("crafting_open") == true):
		return
	# Changer de vue en combinaison (0.0.5.10, touche modifiable) : arrive comme une action.
	if event is InputEventAction and event.is_action_pressed("change_view"):
		cycle_view()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			release_controls()
		# 0.0.7.2 : touches 1 à 9 et 0 : cases 1 à 10 de la barre d'objets (avant : 1 à 5, une matière ou la pioche).
		elif slot_key(event) >= 0:
			world.select_slot(slot_key(event))
		elif event.is_action_pressed("change_view", false, true):
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
	# 0.0.7.3 : Ramasser (R par défaut) : l'objet visé (au sol, ou un petit caillou), main gauche puis droite.
	if event.is_action_pressed("pick_up") and is_instance_valid(world) and world.has_method("pick_up"):
		# 0.0.8.9 : un objet ramassé : R, encore tenu, ne récolte ni n'arrache rien derrière lui.
		if world.pick_up(get_target()):
			world.set("harvest_block", true)
	# 0.0.7.29 : Jeter (J par défaut) : l'objet en main tombe au sol devant soi. 0.0.7.30 : aussi en Créatif ; Ctrl + J :
	# tout le tas ; Supprimer (D + E, Créatif) : rien ne tombe (0.0.7.31 : tout le tas).
	if event.is_action_pressed("throw") and is_instance_valid(world) and world.has_method("throw_held"):
		world.throw_held(Controls.throw_all(event))
	if event.is_action_pressed("delete_item") and is_instance_valid(world) and world.has_method("delete_held"):
		world.delete_held()
	# 0.0.7.31 (demande de l'utilisateur) : Détails (D + T) en jeu : l'inventaire s'ouvre sur les détails de l'objet en main.
	if event.is_action_pressed("show_details") and is_instance_valid(world) and world.has_method("show_held_details"):
		world.show_held_details()
	# Casser, poser, changer de bloc : touches ou boutons de Paramètres → Contrôles.
	# Un clic avec ↑, ↓ ou ⌫ (0.0.4.6) règle la casse ou la pose : il ne casse ni ne pose.
	if event.is_action_pressed("break_block"):
		if not click_modified():
			_break_pressed_at = Time.get_ticks_msec()
			begin_breaking()
	elif event.is_action_pressed("place_block"):
		if not click_modified():
			begin_placement()
	elif event.is_action_pressed("brush_next"):
		# 0.0.7.17 : B + T ouvre le menu des actions (molette : choisir, T : autre ligne).
		if is_instance_valid(world) and world.has_method("open_action_menu"):
			world.open_action_menu()
		else:
			cycle_brush()
	elif event.is_action_pressed("size_up") or event.is_action_pressed("size_down"):
		cycle_size(1 if event.is_action_pressed("size_up") else -1)
	elif (event.is_action_pressed("block_previous") or event.is_action_pressed("block_next")) and wheel_modifiers.any(func(code): return Input.is_physical_key_pressed(code)):
		pass # molette tenue avec B (taille du geste) : la matière ne change pas
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

# Case de la barre pour une touche chiffre (1 → 0, …, 9 → 8, 0 → 9) ; -1 pour une autre touche.
static func slot_key(event: InputEventKey) -> int:
	for code in [event.physical_keycode, event.keycode]:
		if code >= KEY_1 and code <= KEY_9:
			return code - KEY_1
		if code == KEY_0:
			return 9
	return -1

# 0.0.7.2 : molette (Case précédente / suivante) : case ouverte suivante de la barre d'objets.
func cycle_block(direction: int) -> void:
	world.cycle_slot(direction)

# Pioche tenue en main, en vue à la première personne, quand elle est choisie.
var pickaxe: Node3D
const PICKAXE_REST := Vector3(-0.35, 0.45, 0.02)
const PICKAXE_PLACE := Vector3(0.34, -0.32, -0.6)
# 0.0.8.7 (demande de l'utilisateur) : champ de vision par défaut 60° (avant 75° : tout paraissait plus petit et plus
# loin qu'en vrai). Les mains et la pioche se placent selon lui (set_fov).
const DEFAULT_FOV := 60.0

func _make_pickaxe() -> void:
	pickaxe = Node3D.new()
	pickaxe.name = "Pickaxe"
	pickaxe.position = PICKAXE_PLACE
	pickaxe.rotation = PICKAXE_REST
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#7a5230")
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("#8d9196")
	iron.metallic = 0.6
	iron.roughness = 0.45
	# Manche, douille, puis deux bras de fer qui s'affinent et descendent en pointe de chaque côté.
	var parts := [[Vector3(0.035, 0.55, 0.035), Vector3.ZERO, 0.0, wood], [Vector3(0.07, 0.07, 0.065), Vector3(0, 0.27, 0), 0.0, iron]]
	for side in [-1.0, 1.0]:
		parts.append([Vector3(0.14, 0.05, 0.05), Vector3(side * 0.1, 0.262, 0), side * -0.2, iron])
		parts.append([Vector3(0.1, 0.034, 0.034), Vector3(side * 0.205, 0.228, 0), side * -0.45, iron])
		parts.append([Vector3(0.05, 0.018, 0.018), Vector3(side * 0.262, 0.193, 0), side * -0.7, iron])
	for part in parts:
		var mesh := BoxMesh.new()
		mesh.size = part[0]
		mesh.material = part[3]
		var piece := MeshInstance3D.new()
		piece.mesh = mesh
		piece.position = part[1]
		piece.rotation.z = part[2]
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pickaxe.add_child(piece)
	camera.add_child(pickaxe)
	_update_pickaxe()

var hand_view: Node3D
var left_hand_view: Node3D
var _left_item := {}
const PICKAXE_KIND := 3

# 0.0.7.6 : objet montré dans la main (world.apply_held).
func show_held(value: Dictionary) -> void:
	if is_instance_valid(hand_view):
		hand_view.show_item(value)
		hand_view.visible = view == "first" and value.get("objet", "") != "pioche"
	if is_instance_valid(left_hand_view):
		left_hand_view.visible = view == "first"

# 0.0.7.10 : ce que tient chaque main (main gauche à gauche de l'écran, main droite à droite).
func show_hands(left_value: Dictionary, right_value: Dictionary, both_hands: bool = false) -> void:
	_left_item = left_value
	if is_instance_valid(left_hand_view):
		left_hand_view.show_item(left_value)
		left_hand_view.set_both(both_hands)
	if is_instance_valid(hand_view):
		hand_view.set_both(both_hands)
	show_held(right_value)

func _update_pickaxe() -> void:
	if is_instance_valid(pickaxe) and is_instance_valid(world):
		pickaxe.visible = selected_type == world.PICKAXE and view == "first"
	if is_instance_valid(hand_view):
		hand_view.visible = view == "first" and selected_type != PICKAXE_KIND
	if is_instance_valid(left_hand_view):
		left_hand_view.visible = view == "first"

# Coup de pioche : elle s'abat puis revient (0,25 s).
func swing_pickaxe() -> void:
	if not is_instance_valid(pickaxe) or not pickaxe.visible:
		return
	var tween := create_tween()
	tween.tween_property(pickaxe, "rotation", PICKAXE_REST + Vector3(-1.1, 0, 0), 0.1).set_ease(Tween.EASE_IN)
	tween.tween_property(pickaxe, "rotation", PICKAXE_REST, 0.15).set_ease(Tween.EASE_OUT)

func cycle_brush() -> void:
	brush = wrapi(brush + 1, 0, world.BRUSH_NAMES.size())
	world.show_choice("Clic droit : %s" % world.BRUSH_NAMES[brush])

func cycle_size(direction: int) -> void:
	brush_size = wrapi(brush_size + direction, 0, world.SIZE_NAMES.size())
	world.show_choice("Taille du geste : %s" % world.SIZE_NAMES[brush_size])

# 0.0.5.8 : un clic = un geste sur le terrain lisse. 0.0.5.14 : clic maintenu = le geste se répète
# (creuser, poser, aplanir ou lisser), au rythme de Attributs → Blocs (et ↑ ↓ + clic).
func begin_breaking() -> bool:
	actions.cancel()
	actions.set_break_pressed(true, true)
	return _break_once()

func step_breaking(delta: float, active: bool, button_held: bool) -> bool:
	if not actions.tick_break(delta, active, button_held):
		return false
	return _break_once()

func _break_once() -> bool:
	if selected_type == world.PICKAXE:
		swing_pickaxe()
	elif is_instance_valid(hand_view):
		hand_view.nudge()
	return world.break_target(get_target())

func begin_placement() -> bool:
	actions.cancel()
	if is_instance_valid(world) and world.has_method("eat_press") and world.eat_press():
		return false
	actions.set_place_pressed(true, true)
	if is_instance_valid(hand_view):
		hand_view.nudge()
	return world.place_target(get_target(), selected_type)

func step_placement(delta: float, active: bool, button_held: bool) -> bool:
	if not actions.tick_place(delta, active, button_held):
		return false
	if is_instance_valid(hand_view):
		hand_view.nudge()
	return world.place_target(get_target(), selected_type)

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
	set_fov(float(values.get("fov", DEFAULT_FOV)))
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
	# 0.0.6.8 : dans l'eau profonde, on nage (pas en vol).
	var depth := water_depth()
	if leaping and (velocity.y <= 0.0 or is_on_floor()):
		leaping = false
	swimming = not flying and not leaping and depth > SWIM_DEPTH
	wade = WADE_FACTOR if not flying and depth > WADE_DEPTH else 1.0
	# En vol, Se baisser sert à descendre ; en nageant, à plonger : on ne se baisse pas.
	if flying or swimming:
		crouching = false
		airborne = false
	else:
		update_crouch(active, Input.is_action_pressed("crouch"), Input.is_action_just_pressed("crouch"))
	# En vol, Espace monte : ce n'est pas un saut qui arrête la course (Maintenir conditionnel).
	# 0.0.7.3 : R + I maintenus (Récupérer une poignée) : R ne fait pas courir pendant ce temps.
	var breaking_held := active and Input.is_action_pressed("break_block") and not click_modified()
	# 0.0.7.17 : « Récupérer des matériaux » : le clic gauche maintenu prend une poignée (comme R + I).
	var gathering := active and (Input.is_action_pressed("gather") or (left_mode == 2 and breaking_held))
	update_run(active, Input.is_action_pressed("sprint") and not gathering, Input.is_action_just_pressed("sprint") and not gathering, direction != Vector2.ZERO, jump_requested and not flying)
	if is_instance_valid(world) and world.has_method("step_gather"):
		world.step_gather(delta, gathering)
	# 0.0.7.8 : clic gauche maintenu sur un arbre : l'abattre, puis le couper (anneau de chargement).
	if is_instance_valid(world) and world.has_method("step_chop"):
		world.step_chop(delta, breaking_held and left_mode != 2)
	# 0.0.7.27 (#217) : Survie : creuser en maintenant, durée selon la matière.
	if is_instance_valid(world) and world.has_method("step_dig"):
		world.step_dig(delta, breaking_held)
	# 0.0.8.9 : clic gauche maintenu sur l'herbe (modes « arracher », « récupérer des objets ») : l'arracher.
	if is_instance_valid(world) and world.has_method("step_weed"):
		world.step_weed(delta, breaking_held)
	# 0.0.8.4 (#213) : R maintenu (pas R + I) sur une plante à fibres ou une liane : la récolter.
	if is_instance_valid(world) and world.has_method("step_harvest"):
		world.step_harvest(delta, active and Input.is_action_pressed("pick_up") and not gathering)
	# 0.0.8 (#204) : manger, clic droit maintenu avec un fruit en main (Survie).
	if is_instance_valid(world) and world.has_method("step_eat"):
		world.step_eat(delta, active and Input.is_action_pressed("place_block") and not click_modified())
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
	elif swimming:
		var stroke := 0.0
		if active:
			stroke = float(Input.is_action_pressed("jump") and not wait_jump_release) - float(Input.is_action_pressed("crouch"))
		step_swim(delta, direction, stroke, depth, jump_requested)
	else:
		step_movement(delta, direction, jump_requested)
	update_view()

# 0.0.6.8 : nager. Eau plus haute que SWIM_DEPTH au-dessus des pieds (lacs, eau libre) : on nage. Sans rien toucher,
# on remonte et on flotte, les yeux juste hors de l'eau (pieds à FLOAT_DEPTH sous la surface). Sauter maintenu : monter ;
# Se baisser maintenu : plonger ; avancer en regardant vers le bas plonge aussi, vers le haut fait remonter. Courir : nager vite.
# Sauter à la surface contre une rive ou sur le fond : on sort de l'eau d'un bond. Dans l'eau peu profonde (WADE_DEPTH),
# on marche moins vite ; une rivière emporte doucement vers l'aval.
const SWIM_DEPTH := 1.1
const FLOAT_DEPTH := 1.35
const WADE_DEPTH := 0.45
const WADE_FACTOR := 0.7
const SWIM_SPEED := 2.6
const SWIM_RUN_SPEED := 4.2
const SWIM_UP := 2.5
const SWIM_DOWN := 2.5
const SWIM_FLOAT_UP := 1.0
const WATER_DRAG := 10.0
const LEAP_FACTOR := 0.8
var swimming := false
var leaping := false
var wade := 1.0

# Hauteur d'eau au-dessus des pieds (m), 0 hors de l'eau.
func water_depth() -> float:
	if not is_instance_valid(world) or not world.has_method("water_surface"):
		return 0.0
	return maxf(0.0, world.water_surface(Vector2(position.x, position.z)) - position.y)

func step_swim(delta: float, direction: Vector2, stroke: float, depth: float, jump_requested := false) -> void:
	var step := direction.limit_length(1.0)
	var speed := (SWIM_RUN_SPEED if running else SWIM_SPEED) * speed_scale * (run_scale if running else walk_scale)
	var movement := global_transform.basis * Vector3(step.x * speed, 0.0, step.y * speed)
	camera.position.y = move_toward(camera.position.y, eye_height, 4.0 * delta)
	# Avancer en regardant vers le bas (plus de 20°) : plonger ; vers le haut, sous l'eau : remonter.
	var pitch := camera.rotation.x
	var look := 0.0
	if step.y < 0.0 and (pitch < -0.35 or (pitch > 0.35 and depth > FLOAT_DEPTH + 0.2)):
		look = sin(pitch) * -step.y * speed
		movement *= cos(pitch)
	var target_y := clampf((depth - FLOAT_DEPTH) * 3.0, -2.0, SWIM_FLOAT_UP)
	if stroke > 0.0:
		target_y = minf(SWIM_UP, (depth - FLOAT_DEPTH + 0.25) * 4.0)
	elif stroke < 0.0:
		target_y = -SWIM_DOWN
	elif look != 0.0:
		target_y = minf(look, (depth - FLOAT_DEPTH) * 3.0) if look > 0.0 else look
	velocity.y = move_toward(velocity.y, target_y, WATER_DRAG * delta)
	var current: Vector2 = world.water_current(Vector2(position.x, position.z)) if world.has_method("water_current") else Vector2.ZERO
	var flat := Vector2(velocity.x, velocity.z).move_toward(Vector2(movement.x, movement.z) + current, WATER_DRAG * 1.5 * delta)
	velocity.x = flat.x
	velocity.z = flat.y
	# Sortir de l'eau : un bond depuis la surface, contre la rive ou depuis le fond.
	if jump_requested and depth < FLOAT_DEPTH + 0.3 and (is_on_wall() or is_on_floor()):
		velocity.y = jump_speed * LEAP_FACTOR
		leaping = true
	_stay_on_loaded_ground(delta)
	move_and_slide()
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	position.x = clampf(position.x, -world.build_limit - 1.0, world.build_limit + 1.0)
	position.z = clampf(position.z, -world.build_limit - 1.0, world.build_limit + 1.0)

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
	_update_pickaxe()
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
	if is_instance_valid(hand_view):
		hand_view.set_skin(skin)
	if is_instance_valid(left_hand_view):
		left_hand_view.set_skin(skin)
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
# 0.0.7.6 : Contrôles → Arrêter de voler au sol (Exception, par défaut) : en volant, descendre jusqu'à toucher le sol
# arrête le vol (seulement après avoir quitté le sol, pour pouvoir décoller).
var fly_stop_on_ground := true
var fly_airborne := false

func update_fly(active: bool, just_pressed: bool) -> void:
	# 0.0.7.9 (demande de l'utilisateur) : pas de vol en Survie.
	if is_instance_valid(world) and world.get("game_mode") == "survival":
		flying = false
		return
	if active and just_pressed:
		flying = not flying
		fly_airborne = false
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
	_stay_on_loaded_ground(delta)
	move_and_slide()
	if fly_stop_on_ground:
		if not is_on_floor():
			fly_airborne = true
		elif fly_airborne and vertical < 0.0:
			flying = false
			fly_airborne = false
	velocity.y = 0.0
	position.x = clampf(position.x, -world.build_limit - 1.0, world.build_limit + 1.0)
	position.z = clampf(position.z, -world.build_limit - 1.0, world.build_limit + 1.0)
	position.y = minf(position.y, FLY_CEILING)

# 0.0.5.31 : boue et argile un peu glissantes, surtout en descente ; l'argile moins que la boue.
# [vitesse du glissement vers le bas d'une pente, réaction aux pas : plus c'est grand, moins ça glisse]
const SLIP := {5: [4.0, 10.0], 4: [1.8, 16.0]}
const MAX_SLOPE_DEGREES := 52.0
# 0.0.7.8 : vitesse selon ce que portent les mains (inventory.gd carry_factor : 1 à 0,6), à pied et à la nage.
var carry_slow := 1.0
const SLIP_FLAT := 0.12

# Déplacement voulu sur ce sol. Sur plat : presque normal, juste un petit retard ; en pente : on est tiré vers le bas.
static func slip_motion(kind: int, normal: Vector3, wanted: Vector2, current: Vector2, delta: float) -> Vector2:
	if not SLIP.has(kind):
		return wanted
	var downhill := Vector2(normal.x, normal.z)
	var steep := downhill.length()
	var target := wanted
	if steep > SLIP_FLAT:
		target += downhill * SLIP[kind][0]
	return current.lerp(target, clampf(SLIP[kind][1] * delta, 0.0, 1.0))

# 0.0.7.7 (demande de l'utilisateur) : vitesse en montée selon la pente (1 : plat ou descente ; SLOPE_SLOWEST au plus
# raide qu'on puisse monter). Seule la part du pas qui va vers le haut de la pente compte.
const SLOPE_EASY_DEGREES := 12.0
const SLOPE_SLOWEST := 0.5

static func slope_factor(normal: Vector3, move: Vector2) -> float:
	if move.length() < 0.001 or normal.y >= 0.999:
		return 1.0
	var angle := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
	var steep := clampf((angle - SLOPE_EASY_DEGREES) / (MAX_SLOPE_DEGREES - SLOPE_EASY_DEGREES), 0.0, 1.0)
	var downhill := Vector2(normal.x, normal.z).normalized()
	var uphill := clampf(-move.normalized().dot(downhill), 0.0, 1.0)
	return lerpf(1.0, SLOPE_SLOWEST, steep * uphill)

# 0.0.7.7 (demande de l'utilisateur) : enjamber. Un obstacle bas devant soi (caillou, marche du terrain), jusqu'à
# STEP_HEIGHT, se passe en avançant, sans sauter : le corps monte d'un coup sur l'obstacle, la vue suit en douceur.
# Seulement au sol et s'il y a la place au-dessus et un appui de l'autre côté.
const STEP_HEIGHT := 0.45

func step_over(motion: Vector3) -> bool:
	var blocked := KinematicCollision3D.new()
	if not is_on_floor() or motion.length() < 0.0005 or not test_move(global_transform, motion, blocked):
		return false
	# Seulement contre un bord presque vertical (une pente se monte en marchant, elle ne s'enjambe pas).
	if blocked.get_normal().y > cos(floor_max_angle):
		return false
	var up := Vector3(0.0, STEP_HEIGHT, 0.0)
	if test_move(global_transform, up):
		return false
	var raised := global_transform.translated(up)
	# Un peu plus loin que le pas : le pied doit passer par-dessus le bord.
	var ahead_motion := motion.normalized() * maxf(motion.length(), 0.12)
	if test_move(raised, ahead_motion):
		return false
	var ahead := raised.translated(ahead_motion)
	var landing := KinematicCollision3D.new()
	if not test_move(ahead, -up - Vector3(0.0, 0.05, 0.0), landing):
		return false
	if landing.get_normal().y < cos(floor_max_angle):
		return false
	var rise: float = (ahead.origin + landing.get_travel()).y - global_position.y
	if rise <= 0.02:
		return false
	global_position.y += rise + 0.01
	camera.position.y = maxf(camera.position.y - rise, 0.2)
	return true

# The same movement step is used by gameplay and windowless physics tests.

# 0.0.7.22 (demande de l'utilisateur) : sol pas encore construit devant (PC lent, vol rapide) : on s'arrête au bord
# (LOADED_MARGIN avant), en glissant le long si un seul côté manque ; sous les pieds : on attend sur place, sans tomber.
# Au-delà d'un court moment, « Chargement du terrain… ». Le monde construit cette colonne en premier (ground_ready).
const LOADED_MARGIN := 0.6
const LOADED_NOTICE_AFTER := 0.3
var ground_wait := 0.0
# Sol pas construit sous les pieds : immobile, la chute ne prend pas de vitesse pendant l'attente.
var held_here := false

func _stay_on_loaded_ground(delta: float) -> void:
	if not is_instance_valid(world) or not world.has_method("ground_ready"):
		return
	var blocked := false
	held_here = false
	if not world.ground_ready(global_position):
		velocity = Vector3.ZERO
		held_here = true
		blocked = true
	else:
		for axis in [Vector3(velocity.x, 0.0, 0.0), Vector3(0.0, 0.0, velocity.z)]:
			if axis.length() < 0.001:
				continue
			if not world.ground_ready(global_position + axis * delta + axis.normalized() * LOADED_MARGIN):
				blocked = true
				if axis.x != 0.0:
					velocity.x = 0.0
				else:
					velocity.z = 0.0
	ground_wait = ground_wait + delta if blocked else 0.0
	if ground_wait > LOADED_NOTICE_AFTER and world.has_method("_notify"):
		world._notify("Chargement du terrain…")
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
	# 0.0.6.8 : dans l'eau peu profonde, on avance moins vite.
	var local := Vector3(step.x * side, 0.0, step.y * (forward if step.y < 0.0 else back)) * wade * carry_slow
	# Caméra un peu plus basse quand on est baissé.
	var eye := maxf(0.2, eye_height - CROUCH_DROP) if crouching else eye_height
	camera.position.y = move_toward(camera.position.y, eye, 4.0 * delta)
	var movement := global_transform.basis * local
	# 0.0.7.7 : en montée sur une pente raide, on marche moins vite (jusqu'à moitié moins près de la pente maximale).
	if is_on_floor():
		var slowed := slope_factor(get_floor_normal(), Vector2(movement.x, movement.z))
		movement.x *= slowed
		movement.z *= slowed
	if is_on_floor() and is_instance_valid(world) and world.has_method("ground_kind_under"):
		var slip := slip_motion(world.ground_kind_under(position), get_floor_normal(), Vector2(movement.x, movement.z), Vector2(velocity.x, velocity.z), delta)
		movement.x = slip.x
		movement.z = slip.y
	# Rivière : le courant pousse aussi quand on y marche.
	if wade < 1.0 and is_instance_valid(world) and world.has_method("water_current"):
		var current: Vector2 = world.water_current(Vector2(position.x, position.z)) * 0.6
		movement.x += current.x
		movement.z += current.y
	velocity.x = movement.x
	velocity.z = movement.z
	_stay_on_loaded_ground(delta)
	step_over(Vector3(velocity.x, 0.0, velocity.z) * delta)
	move_and_slide()
	velocity.y = 0.0 if is_on_floor() or is_on_ceiling() or held_here else end_speed
	track_fall()
	position.x = clampf(position.x, -world.build_limit - 1.0, world.build_limit + 1.0)
	position.z = clampf(position.z, -world.build_limit - 1.0, world.build_limit + 1.0)
	# 0.0.5.37 : retour au départ seulement sous le monde (les grottes descendent jusqu'à la Roche-mère).
	if position.y < world.terrain.mother_rock_top * world.SmoothTerrain.STEP - 3.0:
		actions.cancel()
		position = world.spawn_position()
		velocity = Vector3.ZERO
		airborne = false

# 0.0.8 (#171) : hauteur de chute. En l'air, on garde le plus haut point atteint ; posé au sol, la chute est la différence.
# Le vol et la nage remettent à zéro (on ne se blesse pas en arrivant de là), le sol pas encore construit aussi.
var airborne := false
var fall_top := 0.0

func track_fall() -> void:
	if held_here:
		airborne = false
		return
	if is_on_floor():
		if airborne:
			airborne = false
			landed.emit(fall_top - position.y, water_depth())
		return
	if not airborne:
		airborne = true
		fall_top = position.y
	else:
		fall_top = maxf(fall_top, position.y)

func get_target() -> Dictionary:
	var origin := camera.global_position
	# Rayon jusqu'à la plus grande portée ; chaque action vérifie ensuite la sienne.
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_transform.basis.z * maxf(break_reach, place_reach))
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func overlaps_cell(cell: Vector3i) -> bool:
	var body_box := AABB(global_position + Vector3(-0.33, 0.01, -0.33), Vector3(0.66, 1.78, 0.66))
	return body_box.intersects(AABB(Vector3(cell), Vector3.ONE))

func set_fov(fov: float) -> void:
	camera.fov = fov
	if is_instance_valid(view_camera):
		view_camera.fov = fov
	var scale := FirstPersonHand.scale_for_fov(fov)
	for hand in [hand_view, left_hand_view]:
		if is_instance_valid(hand):
			hand.set_view_scale(scale)
	if is_instance_valid(pickaxe):
		pickaxe.position = Vector3(PICKAXE_PLACE.x * scale, PICKAXE_PLACE.y * scale, PICKAXE_PLACE.z)
