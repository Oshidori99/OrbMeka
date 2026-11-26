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
const PANEL_MARGIN := 14.0
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
var slot_gap: Control
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
	# 0.0.8.11 (rapport Web : flou en gros pixels) : image lissée en l'agrandissant.
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	# 0.0.8.9 (demande de l'utilisateur) : bleu-violet, comme l'inventaire.
	panel.add_theme_stylebox_override("panel", _style(Color(0.13, 0.1, 0.25, 0.9)))
	# 0.0.8.11 (rapport Web : panneau collé au bord de l'écran, titre sans marge) : un peu d'air autour.
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, roundi(PANEL_MARGIN * text_scale))
	row.add_child(margin)
	margin.add_child(panel)
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
	# 0.0.8.40 : 10 actions : sur plusieurs lignes.
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", roundi(6 * text_scale))
	actions.add_theme_constant_override("v_separation", roundi(6 * text_scale))
	box.add_child(actions)
	for each in Rules.ACTIONS:
		# 0.0.8.21 : 6 actions (Nouer) : images un peu plus petites (avant 78), pour que le panneau garde sa largeur et ne
		# pousse pas la barre (elle reste à la place de celle du jeu).
		var button := CraftingIcons.new(each, roundf(66 * text_scale))
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
	# 0.0.8.12 (rapport Web 0.0.8.11 : barre décalée par rapport à la barre du jeu) : mêmes cases et même place que la barre
	# du jeu (inventory_ui.gd, en bas au centre de l'écran) ; la scène s'arrête au-dessus (bottom) ; poussée à droite
	# seulement si elle toucherait le panneau (place_slot_row).
	slot_row = HBoxContainer.new()
	slot_row.name = "BarreFabrication"
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", InventoryUI.GAP + 4)
	slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_row.anchor_left = 0.5
	slot_row.anchor_right = 0.5
	slot_row.anchor_top = 1.0
	slot_row.anchor_bottom = 1.0
	slot_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	slot_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	slot_row.offset_bottom = -6
	root.add_child(slot_row)
	slot_row.resized.connect(place_slot_row)
	var bottom := Control.new()
	bottom.custom_minimum_size = Vector2(0, _slot_side() + roundi(10 * text_scale) + 16.0)
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
	root.modulate = Color.WHITE
	# L'image du fond : celle d'après l'interface du jeu cachée (world.open_crafting), sans cet écran.
	# 0.0.8.11 (rapport Web : barre d'objets en double, l'ancienne floutée dans le fond) : deux images plus tard (sur le Web,
	# l'image lue est celle d'avant la dernière).
	root.visible = false
	for wait in range(BACKGROUND_WAIT_FRAMES):
		await get_tree().process_frame
		if not visible:
			return
	var shot: Image = get_viewport().get_texture().get_image() if get_viewport().get_texture() != null else null
	if shot != null and not shot.is_empty():
		background.texture = ImageTexture.create_from_image(soft_blur(shot))
	get_viewport().disable_3d = true
	root.visible = true
	choose_action(action if not action.is_empty() else "tresser")
	refresh_slots()
	place_slot_row.call_deferred()

const BACKGROUND_WAIT_FRAMES := 2
# 0.0.8.11 (rapport Web : flou en gros pixels) : réduite peu à peu (moitié par moitié, chaque point mêlé à ses voisins) au
# huitième, puis agrandie en douceur au quart (courbes) ; affichée lissée (filtre linéaire).
static func soft_blur(shot: Image) -> Image:
	var target := Vector2i(maxi(shot.get_width() / 8, 8), maxi(shot.get_height() / 8, 8))
	while shot.get_width() / 2 >= target.x and shot.get_height() / 2 >= target.y:
		shot.resize(shot.get_width() / 2, shot.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	shot.resize(target.x, target.y, Image.INTERPOLATE_BILINEAR)
	shot.resize(target.x * 2, target.y * 2, Image.INTERPOLATE_CUBIC)
	return shot

# 0.0.8.11 (rapport Web : 196 ms à la première ouverture) : dessiné une fois derrière l'écran de chargement, presque
# transparent (world._step_ui_prewarm) : les mains, les images et les textes sont prêts à la première ouverture.
func prewarm(on: bool) -> void:
	if on:
		choose_action(action if not action.is_empty() else "tresser")
		refresh_slots()
	root.modulate = Color(1.0, 1.0, 1.0, 0.004) if on else Color.WHITE
	root.visible = true
	visible = on

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
	# Un choix « × n » (fibres, ficelles, cordelettes : area vide) n'a pas de place précise : vérifié en finissant.
	if choice.get("creative", false) or str(choice.get("area", "")).is_empty() or Rules.still_there(inventory, choice):
		return choice
	var list := _list(role) if not role.is_empty() else []
	for other in list:
		if other.value == choice.value:
			return other
	return {}

func _toggle_optional(role: String, choice: Dictionary) -> void:
	if _same(choice, picks.get(role, {})):
		picks.erase(role)
	else:
		picks[role] = choice
	refresh()

func choose_head(next: String) -> void:
	head = next
	hits = 0
	refresh()

const ROLES := {"tresser": ["fibres"], "tailler": ["percuteur", "pierre"], "fendre": ["manche", "eclat"], "assembler": ["fendu", "tete"], "ficeler": ["a_ficeler", "lien"], "nouer": ["filet", "bretelle"], "detresser": ["tresse"], "defaire": ["outil_fait"], "relier": ["outil_use", "lien"], "ecorcer": ["bois", "eclat"], "torche": ["baton_torche", "meche"], "archet": ["arc", "corde_arc"], "feu": ["pierres", "bois_feu", "amadou"]}
# 0.0.8.21 (#207) : tresser 3 ficelles donne une cordelette ; Nouer : le sac en filet.
const ROLE_TITLES := {"fibres": "3 fibres (une ficelle) ou 3 ficelles (une cordelette), du même type", "percuteur": "Main gauche : percuteur (un caillou)", "pierre": "Main droite : pierre à tailler (silex ou calcaire, taille 3 à 5)",
	"filet": "Main gauche : 4 cordelettes du même type (les mailles)", "bretelle": "Main droite : 1 cordelette ou 1 liane (la bretelle)",
	"manche": "Main gauche : branche (2 à 5 cm, 40 cm à 1 m : un manche ; 1 à 2,5 cm, 15 à 40 cm : une navette)", "eclat": "Main droite : éclat tranchant",
	"fendu": "Main gauche : branche fendue", "tete": "Main droite : tête de hache ou de pioche",
	"a_ficeler": "Main gauche : hache ou pioche à ficeler", "lien": "Main droite : 3 ficelles du même type, ou 1 liane",
	"tresse": "Une ficelle (3 fibres) ou une cordelette (3 ficelles)", "outil_fait": "Une hache ou une pioche (finie ou à ficeler)",
	"outil_use": "Main gauche : hache ou pioche en pierre (usée)", "bois": "Main gauche : bâton ou bûche (pas encore écorcé)",
	"baton_torche": "Main gauche : un bâton (2 à 5 cm, 30 cm à 1,2 m)", "meche": "Main droite : 3 fibres du même type (la mèche)",
	"arc": "Main gauche : une branche souple (1 à 3 cm, 40 cm à 1,2 m)", "corde_arc": "Main droite : une cordelette",
	"pierres": "4 cailloux (le cercle du feu)", "bois_feu": "Un bâton ou une bûche", "amadou": "De l'amadou : 3 fibres ou un morceau d'écorce"}
const HOLD_ACTIONS := ["tresser", "fendre", "ficeler", "nouer", "detresser", "relier", "ecorcer"]
# 0.0.8.24 (demande de l'utilisateur : l'éclat était pris tout seul) : objets facultatifs, proposés ; sans eux, l'action se
# fait quand même, plus lentement (tresser : un éclat tranchant, deux fois plus vite).
const OPTIONAL_ROLES := {"tresser": ["eclat_aide"], "ficeler": ["navette_aide"], "torche": ["resine_aide"]}
# Rôle (Rules.more_choices) des objets proposés ; 0.0.8.25 : la navette, pour ficeler deux fois plus vite.
const OPTIONAL_KINDS := {"eclat_aide": "eclat", "navette_aide": "navette", "resine_aide": "resine"}
const OPTIONAL_TITLES := {"eclat_aide": "Facultatif : un éclat tranchant (tresser deux fois plus vite)", "navette_aide": "Facultatif : une navette (ficeler deux fois plus vite)", "resine_aide": "Facultatif : de l'écorce de pin (une torche forte : 2 fois plus de lumière, 2 fois moins longtemps)"}

func _turn_seconds() -> float:
	return Rules.turn_seconds(picks.has("navette_aide"))

func _flake_chosen() -> bool:
	return picks.has("eclat_aide")

func _list(role: String) -> Array:
	# 0.0.8.8 : un éclat tranchant se taille dans une pierre de taille 2 à 5.
	if role == "pierre" and head == "eclat":
		return Rules.choices(inventory, "pierre_eclat")
	# 0.0.8.44 : la mèche (3 fibres) ; les cailloux et l'amadou du feu.
	if role == "meche":
		return Rules.wick_choices(inventory)
	if role in ["pierres", "amadou"]:
		return Rules.fire_choices(inventory, role)
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
			# 0.0.8.26 : un bâton trop long (une tige de noisetier fait 5 à 6 m) : le recouper au sol.
			if role == "manche":
				choice_box.add_child(_label("Un bâton trop long ? Posez-le et recoupez-le au sol (clic gauche maintenu dessus) : 40 cm à 1 m pour un manche.", 13, Color(0.85, 0.8, 0.6)))
		for choice in list:
			var button := _button(choice.label, choice_box, func(): pick(role, choice))
			button.toggle_mode = true
			button.set_pressed_no_signal(_same(choice, picks.get(role, {})))
	for role in OPTIONAL_ROLES.get(action, []):
		choice_box.add_child(_label(OPTIONAL_TITLES[role], 15, Color(0.6, 0.85, 0.82)))
		var offered := Rules.aid_choices(inventory, OPTIONAL_KINDS[role])
		if offered.is_empty():
			choice_box.add_child(_label(("Aucun%s en main ou en poche." if inventory.mode == Inventory.SURVIVAL else "Aucun%s.") % (" éclat tranchant" if role == "eclat_aide" else ("e écorce de pin" if role == "resine_aide" else "e navette")), 14, Color(0.8, 0.8, 0.8)))
		for choice in offered:
			# Cliquer encore sur l'éclat choisi le laisse de côté.
			var button := _button(choice.label, choice_box, func(): _toggle_optional(role, choice))
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
			var cordelette: bool = str(picks.fibres.get("fibres", "")).begins_with("ficelle_")
			var fast := _flake_chosen()
			text = "Clic gauche maintenu dans la scène (%s s) : tresser %s de 33 cm." % [str(Rules.braid_seconds(_flake_chosen())).replace(".", ","), "une cordelette (plus épaisse)" if cordelette else "une ficelle"]
			text += " Avec l'éclat choisi : deux fois plus vite." if fast else " Choisissez un éclat tranchant (facultatif) : deux fois plus vite."
		"nouer":
			text = "Clic gauche maintenu dans la scène : une rangée de mailles toutes les %s s ; relâchez pour finir (%d à %d rangées : plus il y en a, plus les mailles sont serrées)." % [str(Rules.ROW_SECONDS).replace(".", ","), Inventory.BAG_ROWS.x, Inventory.BAG_ROWS.y]
		"tailler":
			var left := Rules.hits_for(picks.pierre.value, head) - hits
			text = "Cliquez dans la scène pour frapper : encore %d coup%s." % [left, "s" if left > 1 else ""]
		"fendre":
			text = "Clic gauche maintenu dans la scène (%d s) : fendre le bout de la branche." % roundi(Rules.SPLIT_SECONDS)
		"assembler":
			text = "Cliquez dans la scène : la tête glisse dans la fente."
		"detresser":
			text = "Clic gauche maintenu dans la scène (%s s) : la ficelle redonne ses 3 fibres, la cordelette ses 3 ficelles." % str(Rules.UNTWIST_SECONDS).replace(".", ",")
		"torche":
			text = "Cliquez dans la scène : une torche (10 h de lumière), ou une torche forte avec l'écorce de pin (2 fois plus de lumière, 5 h). Elle s'allume à un feu de camp."
		"archet":
			text = "Cliquez dans la scène : l'archet à feu (pour allumer un feu de camp)."
		"feu":
			text = "Cliquez dans la scène : un feu de camp (2 h de bois), à poser au sol et à allumer à l'archet à feu."
		"defaire":
			text = "Cliquez dans la scène : la tête, le manche (branche fendue) et ce qui reste du lien."
		"relier":
			text = "Clic gauche maintenu dans la scène (%d s) : un lien neuf, l'outil retrouve des coups." % roundi(Rules.RELINK_SECONDS)
		"ecorcer":
			text = "Clic gauche maintenu dans la scène (%d s) : l'écorce part, le bois est plus léger." % roundi(Rules.BARK_SECONDS)
		"ficeler":
			text = "Clic gauche maintenu dans la scène : un tour toutes les %s s ; relâchez pour finir (%d à %d tours)." % [str(_turn_seconds()).replace(".", ","), Rules.TURNS_MIN, Rules.TURNS_MAX]
			text += " Avec la navette choisie : deux fois plus vite." if picks.has("navette_aide") else " Avec une navette (facultatif) : deux fois plus vite."
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
		elif action == "torche":
			make_torch()
		elif action == "archet":
			make_bow()
		elif action == "feu":
			make_fire()
		elif action == "defaire":
			undo()

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
			"detresser", "relier", "ecorcer":
				step_hold(delta)
			"nouer":
				step_knot(delta)
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
		done = finish_bind(floori(hold_time / _turn_seconds()))
	elif action == "nouer":
		done = finish_knot(floori(hold_time / Rules.ROW_SECONDS))
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
	# 0.0.8.21 (demande de l'utilisateur) : deux fois plus vite avec un éclat tranchant sur soi.
	var seconds := Rules.braid_seconds(_flake_chosen())
	var share := clampf(hold_time / seconds, 0.0, 1.0)
	ring.progress = share
	# Les mains tendent les brins (un peu plus écartées) ; la main droite roule d'avant en arrière.
	hands[0].position = hands[0].rest + Vector3(-0.015 * share, 0.0, 0.0)
	hands[1].position = hands[1].rest + Vector3(0.015 * share, 0.008 * sin(hold_time * 10.0), 0.0)
	# 0.0.8.17 (#224) : les doigts pincent les brins ; la main droite roule (la pince s'ouvre et se ferme un peu).
	hands[0]._go_pose("pince", 1.0)
	hands[1]._go_pose("pince", 0.75 + 0.25 * sin(hold_time * 10.0))
	for hand in hands:
		hand._gesture_left = 0.2
	_draw_strands(share)
	# 0.0.8.8 (demande de l'utilisateur) : tresser des fibres d'ortie pique un peu (Survie), chaque seconde.
	if picks.fibres.fibres == "fibre_ortie" and floori(hold_time) > floori(hold_time - delta) and world.has_method("hurt"):
		world.hurt(Fibers.NETTLE_BRAID)
	if hold_time < seconds:
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

# --- 0.0.8.44 (#214, #209) : Faire une torche, Faire un archet à feu, Monter un feu (un clic chacun) ---
func make_torch() -> bool:
	var stick: Dictionary = picks.get("baton_torche", {})
	var wick: Dictionary = picks.get("meche", {})
	if stick.is_empty() or wick.is_empty() or not Rules.still_there(inventory, stick):
		status.text = "Le bâton ou la mèche n'est plus là."
		picks = {}
		refresh()
		return false
	var strong := picks.has("resine_aide") and Rules.still_there(inventory, picks.resine_aide)
	if not Rules.take_fibres(inventory, wick):
		status.text = "Il faut 3 fibres du même type pour la mèche."
		picks.erase("meche")
		refresh()
		return false
	if strong:
		Rules.take_choice(inventory, picks.resine_aide)
	var found := Rules.more_choices(inventory, "baton_torche").filter(func(other): return other.value == stick.value)
	if not stick.get("creative", false) and (found.is_empty() or not Rules.take_choice(inventory, found[0])):
		status.text = "Le bâton n'est plus là."
		picks = {}
		refresh()
		return false
	var made := Rules.torch_result(stick.value, strong)
	world.give_crafted(made)
	if world.has_method("notebook_mark"):
		world.notebook_mark("torche_faite")
	picks = {}
	refresh()
	status.text = "%s prête : allumez-la à un feu de camp (clic droit maintenu en le visant)." % Inventory.ITEMS[made.objet].nom
	return true

func make_bow() -> bool:
	var stick: Dictionary = picks.get("arc", {})
	var cord: Dictionary = picks.get("corde_arc", {})
	if stick.is_empty() or cord.is_empty() or not Rules.still_there(inventory, stick) or not Rules.still_there(inventory, cord):
		status.text = "La branche ou la cordelette n'est plus là."
		picks = {}
		refresh()
		return false
	Rules.take_choice(inventory, cord)
	var found := Rules.more_choices(inventory, "arc").filter(func(other): return other.value == stick.value)
	if not stick.get("creative", false) and (found.is_empty() or not Rules.take_choice(inventory, found[0])):
		status.text = "La branche n'est plus là."
		picks = {}
		refresh()
		return false
	world.give_crafted(Rules.bow_result(stick.value, cord.value))
	if world.has_method("notebook_mark"):
		world.notebook_mark("archet")
	picks = {}
	refresh()
	status.text = "Archet à feu prêt : posez un feu de camp, puis visez-le, clic droit maintenu (10 s) pour l'allumer."
	return true

func make_fire() -> bool:
	var stones: Dictionary = picks.get("pierres", {})
	var wood: Dictionary = picks.get("bois_feu", {})
	var tinder: Dictionary = picks.get("amadou", {})
	if stones.is_empty() or wood.is_empty() or tinder.is_empty() or not Rules.still_there(inventory, wood):
		status.text = "Il manque les cailloux, le bois ou l'amadou."
		picks = {}
		refresh()
		return false
	var took_tinder: bool = Rules.take_fibres(inventory, tinder) if tinder.has("fibres") else Rules.take_choice(inventory, tinder)
	if not took_tinder or not Rules.take_stones(inventory, stones.get("creative", false)):
		status.text = "Il faut 4 cailloux et de l'amadou (3 fibres ou un morceau d'écorce)."
		picks = {}
		refresh()
		return false
	var found := Rules.more_choices(inventory, "bois_feu").filter(func(other): return other.value == wood.value)
	if not wood.get("creative", false) and (found.is_empty() or not Rules.take_choice(inventory, found[0])):
		status.text = "Le bois n'est plus là."
		picks = {}
		refresh()
		return false
	world.give_crafted(Rules.fire_result())
	if world.has_method("notebook_mark"):
		world.notebook_mark("feu_monte")
	picks = {}
	refresh()
	status.text = "Feu de camp monté : posez-le au sol (clic droit), puis allumez-le à l'archet à feu."
	return true

# --- 0.0.8.40 (#255 à #258) : Détresser, Défaire un outil, Refaire le lien, Écorcer ---
# Clic maintenu (Détresser, Refaire le lien, Écorcer) : les mains travaillent, l'anneau se remplit ; Défaire : un clic.
func _hold_seconds() -> float:
	match action:
		"detresser":
			return Rules.UNTWIST_SECONDS
		"relier":
			return Rules.RELINK_SECONDS
		"ecorcer":
			return Rules.BARK_SECONDS
	return 1.0

func step_hold(delta: float) -> bool:
	if not ready_to_work():
		return false
	hold_time += delta
	var seconds := _hold_seconds()
	ring.progress = clampf(hold_time / seconds, 0.0, 1.0)
	var push := absf(sin(hold_time * 8.0)) * 0.03
	hands[1].position = hands[1].rest + Vector3(-0.04 - push, 0.01, 0.0)
	for hand in hands:
		hand._go_pose("pince" if action == "detresser" else "prise", 1.0)
		hand._gesture_left = 0.2
	if hold_time < seconds:
		return false
	hold_time = 0.0
	holding = false
	ring.progress = 0.0
	_rest_hands()
	match action:
		"detresser":
			return untwist()
		"relier":
			return relink()
		"ecorcer":
			return bark()
	return false

func untwist() -> bool:
	var cord: Dictionary = picks.get("tresse", {})
	if cord.is_empty() or not Rules.take_choice(inventory, cord):
		status.text = "La ficelle n'est plus là."
		picks = {}
		refresh()
		return false
	var made := Rules.untwist_result(cord.value)
	world.give_crafted(made)
	if world.has_method("notebook_mark"):
		world.notebook_mark("detresser")
	picks.erase("tresse")
	refresh()
	status.text = "Détressée : %d %s. %s" % [Inventory.count(made), Inventory.plural_name(made).to_lower(), _hint()]
	return true

func undo() -> bool:
	var tool: Dictionary = picks.get("outil_fait", {})
	if tool.is_empty() or not Rules.take_choice(inventory, tool):
		status.text = "L'outil n'est plus là."
		picks = {}
		refresh()
		return false
	var parts := Rules.undo_results(tool.value)
	if world.has_method("notebook_mark"):
		world.notebook_mark("defaire")
	for part in parts:
		world.give_crafted(part)
	picks = {}
	refresh()
	status.text = "Défait : la tête, le manche%s." % (" et une ficelle usée" if parts.size() > 2 else "")
	return true

func relink() -> bool:
	var tool: Dictionary = picks.get("outil_use", {})
	var bind: Dictionary = picks.get("lien", {})
	if tool.is_empty() or bind.is_empty() or not Rules.still_there(inventory, tool):
		status.text = "L'outil ou le lien n'est plus là."
		picks = {}
		refresh()
		return false
	var creative: bool = bind.get("creative", false)
	var tied: bool = Rules.take_choice(inventory, bind) if bind.bind == "liane" else Rules.take_count(inventory, bind.bind, Rules.CORDS_PER_TOOL, creative)
	if not tied:
		status.text = "Il faut 3 ficelles du même type, ou une liane."
		picks.erase("lien")
		refresh()
		return false
	if not tool.get("creative", false):
		var found := Rules.more_choices(inventory, "outil_use").filter(func(other): return other.value == tool.value)
		if found.is_empty() or not Rules.take_choice(inventory, found[0]):
			status.text = "L'outil n'est plus là."
			picks = {}
			refresh()
			return false
	var made := Rules.relink_result(tool.value, bind.bind)
	world.give_crafted(made)
	if world.has_method("notebook_mark"):
		world.notebook_mark("relier")
	picks = {}
	refresh()
	var one := Inventory.flat(made.objet, made.pile[0])
	status.text = "%s : lien refait (%d coups sur %d)." % [Inventory.item_name(one), Inventory.tool_left(one), Inventory.tool_durability(one)]
	return true

func bark() -> bool:
	var wood: Dictionary = picks.get("bois", {})
	if wood.is_empty() or not Rules.still_there(inventory, picks.get("eclat", {})) or not Rules.take_choice(inventory, wood):
		status.text = "Le bois ou l'éclat n'est plus là."
		picks = {}
		refresh()
		return false
	var made := Rules.bark_result(wood.value)
	# 0.0.8.44 : l'écorce qui se détache (de pin : pour la torche forte).
	world.give_crafted(Rules.bark_piece(wood.value))
	world.give_crafted(made)
	if world.has_method("notebook_mark"):
		world.notebook_mark("ecorcer")
	picks.erase("bois")
	if picks.has("eclat") and not Rules.still_there(inventory, picks.eclat):
		picks.erase("eclat")
	refresh()
	status.text = "%s écorcé (plus léger). %s" % [Inventory.item_name(Inventory.flat(made.objet, made.pile[0])), _hint()]
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
		# 0.0.8.21 (signalé par l'utilisateur : on voyait « Éclat de silex » au lieu de la tête) : l'éclat d'abord, la tête
		# en dernier : elle arrive dans la première main (ce qu'on vient de faire), l'éclat passe dans l'autre.
		world.give_crafted(made[1])
		world.give_crafted(made[0])
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
	# 0.0.8.17 (#224) : la main qui frappe serre fort son caillou, l'autre tient la pierre.
	hammer._go_pose("prise", 1.0)
	hammer._gesture_left = 0.3
	hands[1]._go_pose("prise", 0.8)
	hands[1]._gesture_left = 0.3
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
	# 0.0.8.17 (#224) : les deux mains serrent (la branche, l'éclat qu'on enfonce).
	for hand in hands:
		hand._go_pose("prise", 1.0)
		hand._gesture_left = 0.2
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
		# 0.0.8.17 (#224) : la tête, pincée, glisse dans la fente.
		hands[1]._go_pose("pince", 1.0)
		hands[1]._gesture_left = 0.4
		var motion := create_tween()
		motion.tween_property(hands[1], "position", hands[0].rest + Vector3(0.06, 0.04, 0.0), 0.15)
		motion.tween_property(hands[1], "position", hands[1].rest, 0.2)
	picks.erase("fendu")
	picks.erase("tete")
	# 0.0.8.21 (demande de l'utilisateur) : l'outil assemblé reste dans la main gauche, et on passe à Ficeler (l'étape
	# suivante), lui déjà choisi.
	var made_flat := Inventory.flat(made.objet, made.pile[0])
	action = "ficeler"
	for each in action_buttons:
		action_buttons[each].set_pressed_no_signal(each == action)
	if is_instance_valid(action_name):
		action_name.text = Rules.ACTION_NAMES.get(action, "")
	var found: Array = _list("a_ficeler").filter(func(other): return other.value == made_flat)
	if not found.is_empty():
		picks["a_ficeler"] = found[0]
	elif stick.get("creative", false):
		picks["a_ficeler"] = {"label": Inventory.item_name(made_flat), "value": made_flat, "area": "", "index": -1, "unit": -1, "creative": true}
	refresh()
	status.text = "%s : assemblée, dans la main gauche. Il reste à la ficeler (choisissez le lien)." % Inventory.item_name(made_flat)
	return true

# Ficeler : clic maintenu ; la main droite tourne autour du haut du manche, un tour toutes les TURN_SECONDS.
var shown_turns := -1

func step_bind(delta: float) -> bool:
	if not ready_to_work():
		return false
	hold_time += delta
	var turns := mini(floori(hold_time / _turn_seconds()), Rules.TURNS_MAX)
	ring.progress = float(turns) / Rules.TURNS_MAX + fmod(hold_time, _turn_seconds()) / _turn_seconds() / Rules.TURNS_MAX
	var angle := hold_time / _turn_seconds() * TAU
	hands[1].position = hands[0].rest + Vector3(0.2 + cos(angle) * 0.03, 0.0 + sin(angle) * 0.02, sin(angle) * 0.03)
	# 0.0.8.17 (#224) : la main droite pince la ficelle en tournant, la gauche serre le manche.
	hands[1]._go_pose("pince", 1.0)
	hands[0]._go_pose("prise", 1.0)
	for hand in hands:
		hand._gesture_left = 0.2
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

# --- 0.0.8.21 (#207) : Nouer un sac en filet ---
# Clic maintenu : les deux mains font des nœuds (pincent, tirent), une rangée de mailles toutes les ROW_SECONDS ;
# relâcher (ou BAG_ROWS.y rangées) : le sac.
func step_knot(delta: float) -> bool:
	if not ready_to_work():
		return false
	hold_time += delta
	var rows := mini(floori(hold_time / Rules.ROW_SECONDS), Inventory.BAG_ROWS.y)
	ring.progress = clampf(hold_time / (Rules.ROW_SECONDS * Inventory.BAG_ROWS.y), 0.0, 1.0)
	var pull := absf(sin(hold_time / Rules.ROW_SECONDS * PI))
	hands[0].position = hands[0].rest + Vector3(-0.02 * pull, 0.01 * pull, 0.0)
	hands[1].position = hands[1].rest + Vector3(0.02 * pull, 0.01 * pull, 0.0)
	for hand in hands:
		hand._go_pose("pince", 0.7 + 0.3 * pull)
		hand._gesture_left = 0.2
	status.text = "Rangées de mailles : %d (relâchez pour finir, %d au moins, %d au plus)." % [rows, Inventory.BAG_ROWS.x, Inventory.BAG_ROWS.y]
	if rows < Inventory.BAG_ROWS.y:
		return false
	holding = false
	var done := finish_knot(rows)
	hold_time = 0.0
	ring.progress = 0.0
	_rest_hands()
	return done

func finish_knot(rows: int) -> bool:
	if rows < Inventory.BAG_ROWS.x:
		status.text = "Pas assez de rangées : %d au moins. Maintenez plus longtemps." % Inventory.BAG_ROWS.x
		return false
	var net: Dictionary = picks.get("filet", {})
	var strap: Dictionary = picks.get("bretelle", {})
	if net.is_empty() or strap.is_empty() or not Rules.net_ready(inventory, net, strap):
		status.text = "Il faut 4 cordelettes du même type, et une cordelette ou une liane pour la bretelle."
		picks = {}
		refresh()
		return false
	var strap_id: String = strap.bretelle
	var tied := false
	if strap_id == "liane":
		tied = Rules.take_choice(inventory, _relocate("bretelle", strap))
	else:
		tied = Rules.take_count(inventory, strap_id, 1, strap.get("creative", false))
	if not tied or not Rules.take_count(inventory, net.cordes, Rules.NET_CORDS, net.get("creative", false)):
		status.text = "Les cordelettes ou la liane ne sont plus là."
		picks = {}
		refresh()
		return false
	var made := Rules.bag_result(net.cordes, strap_id, rows)
	var worn: int = world.wear_crafted_bag(made) if world.has_method("wear_crafted_bag") else -1
	if worn < 0:
		world.give_crafted(made)
	picks = {}
	refresh()
	var flat := Inventory.flat(made.objet, made.pile[0])
	var where: String = ["sur l'épaule : cases 7 à 10", "sur l'autre épaule : ses cases sont dans l'inventaire (O + I)"][worn] if worn >= 0 else "en main"
	status.text = "Sac en filet noué (%d rangées) : il porte %s. Il est %s." % [rows, Inventory.format_weight(Inventory.bag_capacity(flat)), where]
	return true

# --- Cases d'inventaire (demande de l'utilisateur) ---

func refresh_slots() -> void:
	if not is_instance_valid(slot_row):
		return
	# 0.0.8.21 (#207) : en Survie, aussi les cases du sac porté (7 à 10).
	var shown: Array = Inventory.HANDS + Inventory.POCKETS + (Inventory.BAG if inventory.bag_worn(0) else []) if inventory.mode == Inventory.SURVIVAL else inventory.bar_slots()
	while slots.size() < shown.size():
		var slot = InventoryUI.Slot.new(_slot_side(), true, roundi(10 * text_scale))
		slot.show_title = false
		slot.custom_minimum_size.y = slot.side + slot.font_px + 5.0
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
	# Un peu d'espace entre les mains et les poches (Survie), comme la barre du jeu.
	if not is_instance_valid(slot_gap):
		slot_gap = Control.new()
		slot_gap.custom_minimum_size = Vector2(14, 0)
		slot_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_row.add_child(slot_gap)
	slot_row.move_child(slot_gap, mini(Inventory.HANDS.size(), slot_row.get_child_count() - 1))
	slot_gap.visible = inventory.mode == Inventory.SURVIVAL

# Taille des cases : celle de la barre du jeu.
func _slot_side() -> float:
	return roundf(InventoryUI.HUD_SLOT * text_scale)

# Centrée sur l'écran comme la barre du jeu ; poussée à droite seulement si elle toucherait le panneau.
func place_slot_row() -> void:
	if not is_instance_valid(slot_row) or not is_instance_valid(panel):
		return
	var width := slot_row.size.x
	var screen_width := root.size.x
	var left := maxf(screen_width * 0.5 - width * 0.5, panel.get_global_rect().end.x + PANEL_MARGIN * text_scale)
	slot_row.offset_left = left - screen_width * 0.5
	slot_row.offset_right = slot_row.offset_left + width

func _on_inventory_changed() -> void:
	if visible:
		refresh_slots()
