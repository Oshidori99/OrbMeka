extends CanvasLayer
# 0.0.8.5 (#211, demandes de l'utilisateur) : écran de fabrication, ouvert avec O + F (Contrôles, modifiable). Le monde est
# figé derrière (dernière image, floutée ; la 3D du monde n'est plus dessinée : léger, aussi sur le Web). À gauche : les
# actions (Tresser, Tailler ; Fendre, Assembler, Ficeler grisées : « bientôt »), puis les objets possibles : un clic les
# met dans une main. À droite, une petite scène à part : les deux mains et ce qu'elles tiennent. Tresser : clic gauche
# maintenu dans la scène (anneau) ; Tailler : un clic par coup (la main gauche frappe, des éclats sautent, la pierre
# change de forme). Règles : crafting_rules.gd. Échap ou O + F : fermer.
signal closed

const Rules = preload("res://scripts/crafting_rules.gd")
const Inventory = preload("res://scripts/inventory.gd")
const FirstPersonHand = preload("res://scripts/first_person_hand.gd")
const StoneHeads = preload("res://scripts/stone_heads.gd")
const ProgressRing = preload("res://scripts/progress_ring.gd")
const InventoryUI = preload("res://scripts/inventory_ui.gd")
const Fibers = preload("res://scripts/fibers.gd")
const CraftingIcons = preload("res://scripts/crafting_icons.gd")
const SLOT := 46.0
const PANEL_WIDTH := 380.0
const HAND_LEFT := Vector3(-0.14, -0.2, -0.42)
const HAND_RIGHT := Vector3(0.14, -0.2, -0.42)

var world: Node
var inventory: Inventory
var text_scale := 1.0
var root: Control
var background: TextureRect
var panel: PanelContainer
var action_buttons := {}
var action_name: Label
var choice_box: VBoxContainer
var status: Label
var view: SubViewport
var view_box: SubViewportContainer
var camera: Camera3D
var hands: Array = []
var ring: Control
var shaped: MeshInstance3D
var chips: Array = []
# Les cases habituelles (mains et poches ; Créatif : la barre), sous la scène, à jour en direct.
var slot_row: HBoxContainer
var slots: Array = []

var action := ""
var head := "hache"
var picks := {}
var hold_time := 0.0
var holding := false
var hits := 0

func setup(world_node: Node, inventory_ref: Inventory, skin: String, stone_look: Callable, scale: float) -> void:
	world = world_node
	inventory = inventory_ref
	text_scale = scale
	name = "Fabrication"
	layer = 4
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var veil := ColorRect.new()
	veil.color = Color(0.04, 0.05, 0.08, 0.45)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	root.add_child(row)
	_build_panel(row)
	_build_scene(row, skin, stone_look)
	inventory.changed.connect(_on_inventory_changed)
	visible = false

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.set_content_margin_all(roundf(12 * text_scale))
	return style

func _label(text: String, size: int, color := Color(0.95, 0.95, 0.92)) -> Label:
	var made := Label.new()
	made.text = text
	made.add_theme_font_size_override("font_size", roundi(size * text_scale))
	made.add_theme_color_override("font_color", color)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return made

func _button(text: String, parent: Node, pressed: Callable) -> Button:
	var made := Button.new()
	made.text = text
	made.add_theme_font_size_override("font_size", roundi(15 * text_scale))
	made.alignment = HORIZONTAL_ALIGNMENT_LEFT
	made.focus_mode = Control.FOCUS_NONE
	made.pressed.connect(pressed)
	parent.add_child(made)
	return made

func _build_panel(row: HBoxContainer) -> void:
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH * text_scale, 0)
	panel.add_theme_stylebox_override("panel", _style(Color(0.09, 0.1, 0.13, 0.9)))
	row.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", roundi(8 * text_scale))
	scroll.add_child(box)
	box.add_child(_label("Fabrication", 24, Color(1.0, 0.86, 0.55)))
	box.add_child(_label("Action", 15, Color(0.6, 0.85, 0.82)))
	# 0.0.8.8 (demande de l'utilisateur) : les actions en images (crafting_icons.gd), leur nom au survol et dessous.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", roundi(6 * text_scale))
	box.add_child(actions)
	for each in Rules.ACTIONS:
		var button := CraftingIcons.new(each, roundf(78 * text_scale))
		button.tooltip_text = Rules.ACTION_NAMES[each] + ("" if Rules.is_ready(each) else " (bientôt)")
		button.disabled = not Rules.is_ready(each)
		button.pressed.connect(func(): choose_action(each))
		actions.add_child(button)
		action_buttons[each] = button
	action_name = _label("", 17, Color(1.0, 0.95, 0.8))
	box.add_child(action_name)
	choice_box = VBoxContainer.new()
	choice_box.add_theme_constant_override("separation", roundi(5 * text_scale))
	box.add_child(choice_box)
	status = _label("", 15, Color(1.0, 0.95, 0.75))
	box.add_child(status)
	_button("Fermer (Échap)", box, func(): closed.emit())

func _build_scene(row: HBoxContainer, skin: String, stone_look: Callable) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	view_box = SubViewportContainer.new()
	view_box.stretch = true
	view_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_box.mouse_filter = Control.MOUSE_FILTER_STOP
	view_box.gui_input.connect(_scene_input)
	column.add_child(view_box)
	slot_row = HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", roundi(6 * text_scale))
	slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(slot_row)
	var bottom := Control.new()
	bottom.custom_minimum_size = Vector2(0, 8)
	column.add_child(bottom)
	view = SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	view_box.add_child(view)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	environment.ambient_light_energy = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	view.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0.0)
	sun.light_energy = 1.1
	view.add_child(sun)
	camera = Camera3D.new()
	camera.fov = 55.0
	camera.current = true
	view.add_child(camera)
	for left in [true, false]:
		var hand := FirstPersonHand.new()
		hand.setup(skin, stone_look, left)
		hand.rest = HAND_LEFT if left else HAND_RIGHT
		hand.position = hand.rest
		camera.add_child(hand)
		hands.append(hand)
	ring = ProgressRing.new()
	root.add_child(ring)

# --- Ouvrir, fermer ---

func open() -> void:
	visible = true
	# L'image du fond : celle d'après l'interface du jeu cachée (world.open_crafting), sans cet écran (une image plus tard).
	root.visible = false
	await get_tree().process_frame
	if not visible:
		return
	var shot: Image = get_viewport().get_texture().get_image() if get_viewport().get_texture() != null else null
	if shot != null and not shot.is_empty():
		var width := maxi(shot.get_width() / 8, 8)
		var height := maxi(shot.get_height() / 8, 8)
		shot.resize(width * 2, height * 2, Image.INTERPOLATE_BILINEAR)
		shot.resize(width, height, Image.INTERPOLATE_BILINEAR)
		background.texture = ImageTexture.create_from_image(shot)
	get_viewport().disable_3d = true
	root.visible = true
	choose_action(action if not action.is_empty() else "tresser")
	refresh_slots()

func close() -> void:
	visible = false
	get_viewport().disable_3d = false
	background.texture = null
	holding = false
	hold_time = 0.0
	ring.progress = 0.0

func is_open() -> bool:
	return visible

# --- Choix ---

func choose_action(next: String) -> void:
	if not Rules.is_ready(next):
		return
	action = next
	picks = {}
	hits = 0
	hold_time = 0.0
	for each in action_buttons:
		action_buttons[each].set_pressed_no_signal(each == action)
	if is_instance_valid(action_name):
		action_name.text = Rules.ACTION_NAMES.get(action, "")
	refresh()

func pick(role: String, choice: Dictionary) -> void:
	# 0.0.8.8 (demande de l'utilisateur) : en Survie, l'objet choisi va vraiment dans la case de sa main (case 1 : main
	# gauche, case 2 : main droite) ; ce qu'elle tenait va à sa place, dans une poche libre, ou au sol.
	var roles: Array = ROLES.get(action, [])
	var hand := roles.find(role)
	if inventory.mode == Inventory.SURVIVAL and hand >= 0 and hand < Inventory.HANDS.size() and roles.size() == 2:
		choice = _to_hand(choice, Inventory.HANDS[hand])
		for other in roles:
			if other != role and picks.has(other):
				picks[other] = _relocate(other, picks[other])
				if picks[other].is_empty():
					picks.erase(other)
	if choice.is_empty():
		refresh()
		return
	picks[role] = choice
	if role == "pierre":
		hits = 0
	refresh()

# Met un objet choisi (une unité précise) dans la case d'une main ; rend le choix à sa nouvelle place.
func _to_hand(choice: Dictionary, slot: int) -> Dictionary:
	if choice.get("creative", false) or choice.get("area", "") == "" or int(choice.get("unit", -1)) < 0:
		return choice
	var there := inventory.item("bar", slot)
	if choice.area == "bar" and choice.index == slot and Inventory.count(there) == 1:
		return choice
	if not Rules.still_there(inventory, choice):
		return {}
	var from_area: String = choice.area
	var from_index: int = choice.index
	var value := inventory.take_unit(from_area, from_index, choice.unit)
	var moved := {}
	if not inventory.item("bar", slot).is_empty():
		moved = inventory.remove("bar", slot, true)
	var rest := inventory._merge_into("bar", slot, Inventory.single(value))
	if not rest.is_empty():
		# Trop lourd pour une main : tout revient comme avant.
		inventory._merge_into("bar", slot, moved)
		inventory._merge_into(from_area, from_index, rest)
		status.text = "Trop lourd pour une main."
		return _relocate("", choice)
	if not moved.is_empty():
		var kept := inventory._merge_into(from_area, from_index, moved)
		if not kept.is_empty():
			var placed := inventory.add(kept)
			if world.has_method("_drop_units"):
				world._drop_units(kept, placed)
	inventory.changed.emit()
	return {"label": choice.label, "value": choice.value, "area": "bar", "index": slot, "unit": 0}

# Retrouve un objet choisi qui a pu changer de place (même objet, même rôle).
func _relocate(role: String, choice: Dictionary) -> Dictionary:
	if choice.get("creative", false) or Rules.still_there(inventory, choice):
		return choice
	var list := _list(role) if not role.is_empty() else []
	for other in list:
		if other.value == choice.value:
			return other
	return {}

func choose_head(next: String) -> void:
	head = next
	hits = 0
	refresh()

const ROLES := {"tresser": ["fibres"], "tailler": ["percuteur", "pierre"], "fendre": ["manche", "eclat"], "assembler": ["fendu", "tete"], "ficeler": ["a_ficeler", "lien"]}
const ROLE_TITLES := {"fibres": "Fibres (3 du même type)", "percuteur": "Main gauche : percuteur (un caillou)", "pierre": "Main droite : pierre à tailler (silex ou calcaire, taille 3 à 5)",
	"manche": "Main gauche : branche (2 à 5 cm, 40 cm à 1 m, pas pourrie)", "eclat": "Main droite : éclat tranchant",
	"fendu": "Main gauche : branche fendue", "tete": "Main droite : tête de hache ou de pioche",
	"a_ficeler": "Main gauche : hache ou pioche à ficeler", "lien": "Main droite : 3 ficelles du même type, ou 1 liane"}
const HOLD_ACTIONS := ["tresser", "fendre", "ficeler"]

func _list(role: String) -> Array:
	# 0.0.8.8 : un éclat tranchant se taille dans une pierre de taille 2 à 5.
	if role == "pierre" and head == "eclat":
		return Rules.choices(inventory, "pierre_eclat")
	if role in ["fibres", "percuteur", "pierre"]:
		return Rules.choices(inventory, role)
	return Rules.more_choices(inventory, role)

func refresh() -> void:
	shown_turns = -1
	for child in choice_box.get_children():
		child.queue_free()
	var roles: Array = ROLES.get(action, [])
	for role in roles:
		choice_box.add_child(_label(ROLE_TITLES[role], 15, Color(0.6, 0.85, 0.82)))
		var list := _list(role)
		# Un même objet n'est jamais dans les deux mains.
		for other in roles:
			if other != role:
				list = list.filter(func(choice): return not _same(choice, picks.get(other, {})))
		if list.is_empty():
			choice_box.add_child(_label("Rien qui convienne en main ou en poche." if inventory.mode == Inventory.SURVIVAL else "Rien qui convienne.", 14, Color(0.8, 0.8, 0.8)))
		for choice in list:
			var button := _button(choice.label, choice_box, func(): pick(role, choice))
			button.toggle_mode = true
			button.set_pressed_no_signal(_same(choice, picks.get(role, {})))
	if action == "tailler":
		choice_box.add_child(_label("Forme", 15, Color(0.6, 0.85, 0.82)))
		var forms := HBoxContainer.new()
		choice_box.add_child(forms)
		for each in ["hache", "pioche", "eclat"]:
			var button := _button(Rules.HEAD_NAMES[each], forms, func(): choose_head(each))
			button.toggle_mode = true
			button.set_pressed_no_signal(each == head)
	status.text = _hint()
	_show_hands()

func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	return a.get("area") == b.get("area") and a.get("index") == b.get("index") and a.get("unit") == b.get("unit") and a.get("value") == b.get("value") and a.get("label") == b.get("label")

func ready_to_work() -> bool:
	for role in ROLES.get(action, []):
		if not picks.has(role):
			return false
	return true

func _hint() -> String:
	if not ready_to_work():
		return "Choisissez vos objets : ils viennent dans vos mains." + _owned_text()
	var text := ""
	match action:
		"tresser":
			text = "Clic gauche maintenu dans la scène (%d s) : tresser une ficelle de 33 cm." % roundi(Rules.BRAID_SECONDS)
		"tailler":
			var left := Rules.hits_for(picks.pierre.value, head) - hits
			text = "Cliquez dans la scène pour frapper : encore %d coup%s." % [left, "s" if left > 1 else ""]
		"fendre":
			text = "Clic gauche maintenu dans la scène (%d s) : fendre le bout de la branche." % roundi(Rules.SPLIT_SECONDS)
		"assembler":
			text = "Cliquez dans la scène : la tête glisse dans la fente."
		"ficeler":
			text = "Clic gauche maintenu dans la scène : un tour toutes les %s s ; relâchez pour finir (%d à %d tours)." % [str(Rules.TURN_SECONDS).replace(".", ","), Rules.TURNS_MIN, Rules.TURNS_MAX]
	return text + _owned_text()

# 0.0.8.8 (demande de l'utilisateur) : combien on a déjà de ce qu'on fabrique (« Vous avez 2 têtes de pioche. »).
func _owned_text() -> String:
	var id := Rules.result_id(action, picks, head)
	if id.is_empty():
		return ""
	var count := Rules.owned(inventory, id)
	var name: String = "branche fendue" if id == "branche_fendue" else str(Inventory.ITEMS.get(id, {}).get("nom", "")).to_lower()
	if count > 1:
		name = "branches fendues" if id == "branche_fendue" else Inventory.plural_name({"objet": id})
	return "\nVous avez %d %s." % [count, name] if count > 0 else "\nVous n'en avez pas encore."

# --- Les mains ---

func _show_hands() -> void:
	if hands.size() < 2:
		return
	if is_instance_valid(shaped):
		shaped.queue_free()
		shaped = null
	_clear_strands()
	if action == "tresser":
		# Les fibres tendues entre les deux mains (_draw_strands), pas dans les paumes.
		hands[0].show_item({})
		hands[1].show_item({})
		if picks.has("fibres"):
			_draw_strands(0.0)
		return
	var roles: Array = ROLES.get(action, [])
	for index in range(2):
		var role: String = roles[index] if index < roles.size() else ""
		var value: Dictionary = picks[role].value if picks.has(role) else {}
		hands[index].show_item(value)
	if action != "tailler" or not picks.has("pierre") or hits == 0 or head == "eclat":
		return
	# Coup après coup : la pierre prend la forme de la tête.
	hands[1].show_item({})
	shaped = MeshInstance3D.new()
	shaped.name = "PierreTaillee"
	var stone: Dictionary = picks.pierre.value
	shaped.mesh = StoneHeads.mesh(head, float(hits) / Rules.hits_for(stone, head), int(stone.get("forme", 1)))
	shaped.material_override = StoneHeads.material(Rules.KNAP_STONES.get(stone.objet, 1))
	shaped.scale = Vector3.ONE * StoneHeads.scale_for(head, int(stone.get("taille", 4)))
	shaped.position.y = 0.02
	hands[1].held.add_child(shaped)

# --- 0.0.8.6 (demande de l'utilisateur : l'animation d'avant n'était pas réaliste) : tresser ---
# Les 3 brins sont tendus d'une paume à l'autre ; en maintenant, la main droite roule et les brins s'enroulent en
# spirale, de plus en plus serrés, jusqu'à ne faire qu'une ficelle.
var strands: MeshInstance3D
var strand_material: StandardMaterial3D

func _clear_strands() -> void:
	if is_instance_valid(strands):
		strands.queue_free()
		strands = null

func _draw_strands(share: float) -> void:
	if not picks.has("fibres"):
		return
	if not is_instance_valid(strands):
		strands = MeshInstance3D.new()
		strands.name = "Brins"
		strands.mesh = ImmediateMesh.new()
		camera.add_child(strands)
	if strand_material == null:
		strand_material = StandardMaterial3D.new()
		strand_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		strand_material.roughness = 0.9
	strand_material.albedo_color = Inventory.ITEMS[picks.fibres.fibres].couleur
	var a: Vector3 = camera.to_local(hands[0].held.global_position) + Vector3(0.02, 0.01, 0.0)
	var b: Vector3 = camera.to_local(hands[1].held.global_position) + Vector3(-0.02, 0.01, 0.0)
	var along := b - a
	var side := along.cross(Vector3.BACK).normalized()
	var up := along.cross(side).normalized()
	var radius := lerpf(0.008, 0.0018, share)
	var twists := lerpf(0.4, 7.0, share)
	var width := lerpf(0.0012, 0.0018, share)
	var mesh: ImmediateMesh = strands.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, strand_material)
	var steps := 40
	for strand in range(3):
		var previous := Vector3.ZERO
		for step in range(steps + 1):
			var t := float(step) / steps
			# Serré au milieu, un peu plus lâche près des mains ; légère courbe vers le bas.
			var loose := radius * (0.6 + 0.4 * absf(t - 0.5) * 2.0)
			var angle := t * twists * TAU + strand * TAU / 3.0 + hold_time * 2.0
			var point := a + along * t + side * cos(angle) * loose + up * sin(angle) * loose - up * 0.015 * sin(PI * t)
			if step > 0:
				var lift := Vector3.UP * width
				for corner in [previous - lift, point - lift, point + lift, previous - lift, point + lift, previous + lift]:
					mesh.surface_set_normal(Vector3.BACK)
					mesh.surface_add_vertex(corner)
			previous = point
	mesh.surface_end()

# --- Faire l'action ---

func _scene_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if action in HOLD_ACTIONS:
		var was := holding
		holding = event.pressed and ready_to_work()
		if was and not holding:
			release_hold()
	elif event.pressed and ready_to_work():
		if action == "tailler":
			strike()
		elif action == "assembler":
			assemble()

func _process(delta: float) -> void:
	if not visible:
		return
	if holding:
		match action:
			"tresser":
				step_braid(delta)
			"fendre":
				step_split(delta)
			"ficeler":
				step_bind(delta)
	for chip in chips.duplicate():
		if not is_instance_valid(chip):
			chips.erase(chip)
			continue
		var speed: Vector3 = chip.get_meta("speed")
		speed.y -= 3.0 * delta
		chip.set_meta("speed", speed)
		chip.position += speed * delta
		var life := float(chip.get_meta("life")) - delta
		chip.set_meta("life", life)
		if life <= 0.0:
			chip.queue_free()
			chips.erase(chip)

# Clic relâché pendant une action maintenue : tresser et fendre s'arrêtent (rien n'est fait) ; ficeler finit l'outil s'il
# a assez de tours.
func release_hold() -> bool:
	holding = false
	shown_turns = -1
	var done := false
	if action == "ficeler":
		done = finish_bind(floori(hold_time / Rules.TURN_SECONDS))
	hold_time = 0.0
	ring.progress = 0.0
	_rest_hands()
	if action == "tresser" and picks.has("fibres"):
		_draw_strands(0.0)
	return done

func _rest_hands() -> void:
	for hand in hands:
		hand.position = hand.rest
		hand.held.rotation = Vector3.ZERO
		hand.held.position = FirstPersonHand.PALM

func step_braid(delta: float) -> bool:
	if not ready_to_work():
		return false
	hold_time += delta
	var share := clampf(hold_time / Rules.BRAID_SECONDS, 0.0, 1.0)
	ring.progress = share
	# Les mains tendent les brins (un peu plus écartées) ; la main droite roule d'avant en arrière.
	hands[0].position = hands[0].rest + Vector3(-0.015 * share, 0.0, 0.0)
	hands[1].position = hands[1].rest + Vector3(0.015 * share, 0.008 * sin(hold_time * 10.0), 0.0)
	_draw_strands(share)
	# 0.0.8.8 (demande de l'utilisateur) : tresser des fibres d'ortie pique un peu (Survie), chaque seconde.
	if picks.fibres.fibres == "fibre_ortie" and floori(hold_time) > floori(hold_time - delta) and world.has_method("hurt"):
		world.hurt(Fibers.NETTLE_BRAID)
	if hold_time < Rules.BRAID_SECONDS:
		return false
	hold_time = 0.0
	holding = false
	ring.progress = 0.0
	_rest_hands()
	return braid()

func braid() -> bool:
	var choice: Dictionary = picks.get("fibres", {})
	if choice.is_empty() or not Rules.take_fibres(inventory, choice):
		status.text = "Il faut 3 fibres du même type."
		picks.erase("fibres")
		refresh()
		return false
	var cord := Rules.cord_for(choice.fibres)
	world.give_crafted(cord)
	var keep := Rules.choices(inventory, "fibres").filter(func(other): return other.get("fibres") == choice.fibres and other.get("creative", false) == choice.get("creative", false))
	if keep.is_empty():
		picks.erase("fibres")
	else:
		picks.fibres = keep[0]
	refresh()
	status.text = "%s tressée (33 cm). %s" % [Inventory.item_name(cord), _hint()]
	return true

# Tailler : un coup. La main gauche frappe la pierre, des éclats sautent, la pierre prend forme ; au dernier coup, la tête.
func strike() -> bool:
	if not ready_to_work() or not Rules.still_there(inventory, picks.pierre) or not Rules.still_there(inventory, picks.percuteur):
		status.text = "La pierre ou le percuteur n'est plus là."
		picks = {}
		refresh()
		return false
	hits += 1
	_strike_motion()
	if hits < Rules.hits_for(picks.pierre.value, head):
		_show_hands()
		status.text = _hint()
		return false
	var stone: Dictionary = picks.pierre.value
	var stone_slot := [picks.pierre.area, picks.pierre.index]
	if not picks.pierre.get("creative", false):
		inventory.take_unit(picks.pierre.area, picks.pierre.index, picks.pierre.unit)
	hits = 0
	var message := ""
	if head == "eclat":
		# 0.0.8.8 : un éclat tranchant ; la pierre, une taille plus petite, reste en main (la taille 2 est utilisée).
		var flaked: Array = Rules.flake_results(stone)
		var smaller: Dictionary = flaked[1]
		if not smaller.is_empty() and not picks.pierre.get("creative", false):
			var rest := inventory._merge_into(stone_slot[0], stone_slot[1], smaller)
			if not rest.is_empty():
				world.give_crafted(rest)
		world.give_crafted(flaked[0])
		message = "Un éclat tranchant%s." % ("" if not smaller.is_empty() else " (la pierre est entièrement utilisée)")
		if not smaller.is_empty() and picks.pierre.get("creative", false):
			picks.pierre.value = Inventory.flat(smaller.objet, smaller.pile[0])
	else:
		var made: Array = Rules.knap_results(stone, head)
		for value in made:
			world.give_crafted(value)
		message = "%s taillée, et un éclat tranchant." % Inventory.item_name(Inventory.flat(made[0].objet, made[0].pile[0]))
		picks.erase("pierre")
	# Ce qui est fabriqué va dans la première main : le percuteur et la pierre ont pu changer de place.
	for role in ["percuteur", "pierre"]:
		if picks.has(role) and not picks[role].get("creative", false):
			var found := _relocate(role, picks[role])
			if found.is_empty() and role == "pierre":
				# La pierre plus petite : la même, une taille de moins.
				var list := _list("pierre").filter(func(c): return c.value.get("objet") == stone.objet and int(c.value.get("taille", 0)) == int(stone.get("taille", 0)) - 1)
				found = list[0] if not list.is_empty() else {}
			if found.is_empty():
				picks.erase(role)
			else:
				picks[role] = found
	refresh()
	status.text = "%s %s" % [message, _hint()]
	return true

func _strike_motion() -> void:
	if hands.size() < 2 or not is_inside_tree():
		return
	var hammer: Node3D = hands[0]
	var target: Vector3 = hands[1].rest + Vector3(-0.07, 0.03, 0.0)
	var motion := create_tween()
	motion.tween_property(hammer, "position", target, 0.08).set_ease(Tween.EASE_IN)
	motion.tween_property(hammer, "position", hammer.rest, 0.16).set_ease(Tween.EASE_OUT)
	if world.has_method("_impact_sound") and is_instance_valid(world.get("player")):
		world._impact_sound(world.player.global_position)
	var stone: Dictionary = picks.pierre.value
	var color: Color = StoneHeads.COLORS[Rules.KNAP_STONES.get(stone.objet, 1)]
	var chip_material := StandardMaterial3D.new()
	chip_material.albedo_color = color
	for index in range(4):
		var chip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * randf_range(0.004, 0.009)
		chip.mesh = box
		chip.material_override = chip_material
		chip.position = hands[1].rest + Vector3(-0.03, 0.04, 0.0)
		chip.set_meta("speed", Vector3(randf_range(-0.35, 0.15), randf_range(0.2, 0.6), randf_range(-0.2, 0.2)))
		chip.set_meta("life", 0.5)
		camera.add_child(chip)
		chips.append(chip)

# --- 0.0.8.6 : Fendre, Assembler, Ficeler ---

# Fendre : clic maintenu ; la main droite enfonce l'éclat dans le bout de la branche par petits coups.
func step_split(delta: float) -> bool:
	if not ready_to_work():
		return false
	hold_time += delta
	var share := clampf(hold_time / Rules.SPLIT_SECONDS, 0.0, 1.0)
	ring.progress = share
	var push := absf(sin(hold_time * 7.0)) * 0.04
	hands[1].position = hands[1].rest + Vector3(-0.07 - push, 0.02, 0.0)
	if hold_time < Rules.SPLIT_SECONDS:
		return false
	hold_time = 0.0
	holding = false
	ring.progress = 0.0
	_rest_hands()
	return split()

func split() -> bool:
	var stick: Dictionary = picks.get("manche", {})
	if stick.is_empty() or not Rules.still_there(inventory, picks.get("eclat", {})) or not Rules.take_choice(inventory, stick):
		status.text = "La branche ou l'éclat n'est plus là."
		picks = {}
		refresh()
		return false
	var made := Rules.split_result(stick.value)
	world.give_crafted(made)
	picks.erase("manche")
	if picks.has("eclat") and not Rules.still_there(inventory, picks.eclat):
		picks.erase("eclat")
	refresh()
	status.text = "%s : prête à recevoir une tête. %s" % [Inventory.item_name(Inventory.flat(made.objet, made.pile[0])), _hint()]
	return true

# Assembler : un clic ; la main droite glisse la tête dans la fente.
func assemble() -> bool:
	var stick: Dictionary = picks.get("fendu", {})
	var stone: Dictionary = picks.get("tete", {})
	if stick.is_empty() or stone.is_empty() or not Rules.still_there(inventory, stick) or not Rules.still_there(inventory, stone):
		status.text = "La branche fendue ou la tête n'est plus là."
		picks = {}
		refresh()
		return false
	Rules.take_choice(inventory, stick)
	if not stone.get("creative", false):
		# La branche a pu être prise dans la même case : on retrouve la tête.
		var found := Rules.more_choices(inventory, "tete").filter(func(other): return other.value == stone.value)
		if found.is_empty() or not Rules.take_choice(inventory, found[0]):
			status.text = "La tête n'est plus là."
			picks = {}
			refresh()
			return false
	var made := Rules.assemble_result(stick.value, stone.value)
	world.give_crafted(made)
	if is_inside_tree():
		var motion := create_tween()
		motion.tween_property(hands[1], "position", hands[0].rest + Vector3(0.06, 0.04, 0.0), 0.15)
		motion.tween_property(hands[1], "position", hands[1].rest, 0.2)
	picks.erase("fendu")
	picks.erase("tete")
	refresh()
	status.text = "%s : il reste à la ficeler." % Inventory.item_name(Inventory.flat(made.objet, made.pile[0]))
	return true

# Ficeler : clic maintenu ; la main droite tourne autour du haut du manche, un tour toutes les TURN_SECONDS.
var shown_turns := -1

func step_bind(delta: float) -> bool:
	if not ready_to_work():
		return false
	hold_time += delta
	var turns := mini(floori(hold_time / Rules.TURN_SECONDS), Rules.TURNS_MAX)
	ring.progress = float(turns) / Rules.TURNS_MAX + fmod(hold_time, Rules.TURN_SECONDS) / Rules.TURN_SECONDS / Rules.TURNS_MAX
	var angle := hold_time / Rules.TURN_SECONDS * TAU
	hands[1].position = hands[0].rest + Vector3(0.2 + cos(angle) * 0.03, 0.0 + sin(angle) * 0.02, sin(angle) * 0.03)
	status.text = "Tours : %d (relâchez pour finir, %d au moins, %d au plus)." % [turns, Rules.TURNS_MIN, Rules.TURNS_MAX]
	# Chaque tour se voit sur le manche (le lien et ses tours sur l'outil de la main gauche).
	if turns != shown_turns:
		shown_turns = turns
		var preview: Dictionary = picks.a_ficeler.value.duplicate()
		if turns > 0:
			preview.lien = int(Rules.BINDS.get(picks.lien.bind, 1))
			preview.tours = turns
		hands[0].show_item(preview)
	if turns < Rules.TURNS_MAX:
		return false
	holding = false
	var done := finish_bind(turns)
	hold_time = 0.0
	ring.progress = 0.0
	_rest_hands()
	return done

func finish_bind(turns: int) -> bool:
	if turns < Rules.TURNS_MIN:
		status.text = "Pas assez de tours : %d au moins. Maintenez plus longtemps." % Rules.TURNS_MIN
		return false
	var tool: Dictionary = picks.get("a_ficeler", {})
	var bind: Dictionary = picks.get("lien", {})
	if tool.is_empty() or bind.is_empty() or not Rules.still_there(inventory, tool):
		status.text = "L'outil ou le lien n'est plus là."
		picks = {}
		refresh()
		return false
	var creative: bool = bind.get("creative", false)
	var tied := false
	if bind.bind == "liane":
		tied = Rules.take_choice(inventory, bind)
	else:
		tied = Rules.take_count(inventory, bind.bind, Rules.CORDS_PER_TOOL, creative)
	if not tied:
		status.text = "Il faut 3 ficelles du même type, ou une liane."
		picks.erase("lien")
		refresh()
		return false
	# L'outil a pu changer de place : on le retrouve.
	if not tool.get("creative", false):
		var found := Rules.more_choices(inventory, "a_ficeler").filter(func(other): return other.value == tool.value)
		if found.is_empty() or not Rules.take_choice(inventory, found[0]):
			status.text = "L'outil n'est plus là."
			picks = {}
			refresh()
			return false
	var made := Rules.bind_result(tool.value, bind.bind, turns)
	world.give_crafted(made)
	picks = {}
	refresh()
	status.text = "%s ficelée (%d tours) !" % [Inventory.item_name(Inventory.flat(made.objet, made.pile[0])), turns]
	return true

# --- Cases d'inventaire (demande de l'utilisateur) ---

func refresh_slots() -> void:
	if not is_instance_valid(slot_row):
		return
	var shown: Array = Inventory.HANDS + Inventory.POCKETS if inventory.mode == Inventory.SURVIVAL else inventory.bar_slots()
	while slots.size() < shown.size():
		var slot = InventoryUI.Slot.new(roundf(SLOT * text_scale), true, roundi(11 * text_scale))
		slot.show_title = false
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_row.add_child(slot)
		slots.append(slot)
	for at in range(slots.size()):
		var slot: Control = slots[at]
		slot.visible = at < shown.size()
		if not slot.visible:
			continue
		var index: int = shown[at]
		var value := inventory.item("bar", index)
		var note := "" if value.is_empty() or inventory.mode == Inventory.CREATIVE else Inventory.format_weight(Inventory.stack_weight(value))
		slot.show_item(value, false, false, note)
		# Un peu d'espace entre les mains et les poches (Survie).
		slot.custom_minimum_size.x = roundf(SLOT * text_scale) + (14.0 if inventory.mode == Inventory.SURVIVAL and index == Inventory.HANDS[-1] else 0.0)

func _on_inventory_changed() -> void:
	if visible:
		refresh_slots()
