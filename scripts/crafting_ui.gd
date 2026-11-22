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
const SLOT := 46.0
const PANEL_WIDTH := 380.0
const HAND_LEFT := Vector3(-0.14, -0.2, -0.42)
const HAND_RIGHT := Vector3(0.14, -0.2, -0.42)
const STONE_SIZES := {3: 0.075, 4: 0.09, 5: 0.11}

var world: Node
var inventory: Inventory
var text_scale := 1.0
var root: Control
var background: TextureRect
var panel: PanelContainer
var action_buttons := {}
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
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", roundi(6 * text_scale))
	actions.add_theme_constant_override("v_separation", roundi(6 * text_scale))
	box.add_child(actions)
	for each in Rules.ACTIONS:
		var text: String = Rules.ACTION_NAMES[each] + ("" if Rules.is_ready(each) else " (bientôt)")
		var button := _button(text, actions, func(): choose_action(each))
		button.toggle_mode = true
		button.disabled = not Rules.is_ready(each)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_buttons[each] = button
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
	refresh()

func pick(role: String, choice: Dictionary) -> void:
	picks[role] = choice
	if role == "pierre":
		hits = 0
	refresh()

func choose_head(next: String) -> void:
	head = next
	hits = 0
	refresh()

func refresh() -> void:
	for child in choice_box.get_children():
		child.queue_free()
	var roles: Array = ["fibres"] if action == "tresser" else ["percuteur", "pierre"]
	for role in roles:
		var title: String = {"fibres": "Fibres (3 du même type)", "percuteur": "Main gauche : percuteur (un caillou)", "pierre": "Main droite : pierre à tailler (silex ou calcaire, taille 3 à 5)"}[role]
		choice_box.add_child(_label(title, 15, Color(0.6, 0.85, 0.82)))
		var list := Rules.choices(inventory, role)
		# La pierre choisie n'est pas proposée comme percuteur, et inversement.
		list = list.filter(func(choice): return not _same(choice, picks.get("pierre" if role == "percuteur" else "percuteur", {})))
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
		for each in ["hache", "pioche"]:
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
	if action == "tresser":
		return picks.has("fibres")
	return picks.has("percuteur") and picks.has("pierre")

func _hint() -> String:
	if action == "tresser":
		return "Clic gauche maintenu dans la scène (%d s) : tresser une ficelle de 33 cm." % roundi(Rules.BRAID_SECONDS) if picks.has("fibres") else "Choisissez vos fibres : elles viennent dans vos mains."
	if not ready_to_work():
		return "Choisissez le percuteur et la pierre : ils viennent dans vos mains."
	return "Cliquez dans la scène pour frapper : %d coup%s sur %d." % [hits, "s" if hits > 1 else "", Rules.hits_for(picks.pierre.value)]

# --- Les mains ---

func _show_hands() -> void:
	if hands.size() < 2:
		return
	if is_instance_valid(shaped):
		shaped.queue_free()
		shaped = null
	if action == "tresser":
		var fibre: Dictionary = {"objet": picks.fibres.fibres} if picks.has("fibres") else {}
		hands[0].show_item(fibre)
		hands[1].show_item(fibre)
		return
	hands[0].show_item(picks.percuteur.value if picks.has("percuteur") else {})
	if not picks.has("pierre"):
		hands[1].show_item({})
		return
	if hits == 0:
		hands[1].show_item(picks.pierre.value)
		return
	# Coup après coup : la pierre prend la forme de la tête.
	hands[1].show_item({})
	shaped = MeshInstance3D.new()
	shaped.name = "PierreTaillee"
	var stone: Dictionary = picks.pierre.value
	shaped.mesh = StoneHeads.mesh(head, float(hits) / Rules.hits_for(stone), int(stone.get("forme", 1)))
	shaped.material_override = StoneHeads.material(Rules.KNAP_STONES.get(stone.objet, 1))
	shaped.scale = Vector3.ONE * STONE_SIZES.get(int(stone.get("taille", 4)), 0.09)
	shaped.position.y = 0.02
	hands[1].held.add_child(shaped)

# --- Faire l'action ---

func _scene_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if action == "tresser":
		holding = event.pressed and ready_to_work()
		if not holding:
			hold_time = 0.0
			ring.progress = 0.0
	elif event.pressed and ready_to_work():
		strike()

func _process(delta: float) -> void:
	if not visible:
		return
	if holding and action == "tresser":
		step_braid(delta)
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

# Tresser : clic gauche maintenu ; les mains se rapprochent et tournent l'une contre l'autre.
func step_braid(delta: float) -> bool:
	if not ready_to_work():
		return false
	hold_time += delta
	var share := clampf(hold_time / Rules.BRAID_SECONDS, 0.0, 1.0)
	ring.progress = share
	for index in range(hands.size()):
		var hand: Node3D = hands[index]
		hand.position = hand.rest.lerp(Vector3(0.0, hand.rest.y, hand.rest.z), share * 0.45)
		hand.held.rotation.z = sin(hold_time * 9.0) * 0.6 * (1.0 if index == 0 else -1.0)
	if hold_time < Rules.BRAID_SECONDS:
		return false
	hold_time = 0.0
	holding = false
	ring.progress = 0.0
	for hand in hands:
		hand.position = hand.rest
		hand.held.rotation = Vector3.ZERO
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
	if hits < Rules.hits_for(picks.pierre.value):
		_show_hands()
		status.text = _hint()
		return false
	var stone: Dictionary = picks.pierre.value
	if not picks.pierre.get("creative", false):
		inventory.take_unit(picks.pierre.area, picks.pierre.index, picks.pierre.unit)
	var made: Array = Rules.knap_results(stone, head)
	for value in made:
		world.give_crafted(value)
	hits = 0
	var name: String = Inventory.item_name(Inventory.flat(made[0].objet, made[0].pile[0]))
	picks.erase("pierre")
	# Le percuteur a pu changer de place dans sa pile : on le retrouve.
	if picks.has("percuteur") and not Rules.still_there(inventory, picks.percuteur):
		picks.erase("percuteur")
	refresh()
	status.text = "%s taillée, et un éclat tranchant. %s" % [name, _hint()]
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
