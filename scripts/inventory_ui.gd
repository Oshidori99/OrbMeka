extends CanvasLayer
# 0.0.7.2 : affichage de l'inventaire (inventory.gd).
# En jeu : la barre d'objets en bas au centre (case en main encadrée).
# Écran d'inventaire (O + I, modifiable ; Échap ou O + I pour fermer) : un panneau un peu transparent au centre,
# le monde reste visible autour.
# - Créatif : onglets en images en haut (0.0.7.4 : cinq petits tas pour Matériaux naturels, la pioche pour Outils),
#   la grille de 5 × 10 et, plus bas, la barre de 10.
# - Survie (0.0.7.4) : une ligne pour les mains (image de main, les deux cases, « 100,0 g / 1,000 kg » à droite) et,
#   dessous, une ligne pour les poches (image de poche, les quatre cases, leur poids à droite).
# Sous chaque case : le nom de l'objet, puis, juste dessous, son poids (Survie ; rien sous une case vide).
# Clic gauche : prendre ou poser (s'empile sur un objet identique, sinon échange) ; clic droit : vider la case (Créatif) ;
# clic droit sur un objet d'une catégorie : dans la première case libre.
# Icônes : item_icons.gd (petits tas où l'on voit la texture), faites une seule fois.
const Inventory = preload("res://scripts/inventory.gd")
const ItemIcons = preload("res://scripts/item_icons.gd")
const HUD_SLOT := 46.0
const PANEL_SLOT := 48.0
const GAP := 6

# Une case dessinée (barre, grille, catégorie ou objet tenu par la souris) ; sous la case : nom puis poids.
class Slot extends Control:
	signal clicked(button: int)
	var item := {}
	var locked := false
	var chosen := false
	var plain := false
	var side := 46.0
	# 0.0.7.10 : largeur (une case double pour un objet porté à deux mains : les deux mains réunies).
	var width := 46.0
	var title := ""
	var note := ""
	var font_px := 11
	var with_text := false
	# 0.0.7.7 : silhouette grise d'une case vide (équipement à venir).
	var picture: Texture2D

	func _init(box_side: float, text_lines: bool = false, text_px: int = 11) -> void:
		side = box_side
		width = box_side
		font_px = text_px
		with_text = text_lines
		custom_minimum_size = Vector2(side, side + (2.0 * (font_px + 3.0) + 2.0 if with_text else 0.0))
		size = custom_minimum_size

	func set_width(new_width: float) -> void:
		width = new_width
		custom_minimum_size.x = width
		size.x = width
		queue_redraw()

	func show_item(value: Dictionary, is_locked: bool = false, is_chosen: bool = false, weight_note: String = "") -> void:
		item = value
		locked = is_locked
		chosen = is_chosen
		note = weight_note
		title = Inventory.item_name(value) if with_text else ""
		var name := Inventory.item_name(value)
		if not value.is_empty() and not Inventory.unlimited(value):
			name += " × %d (%s)" % [Inventory.count(value), Inventory.format_weight(Inventory.stack_weight(value))]
		tooltip_text = name
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			clicked.emit(event.button_index)
			accept_event()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, Vector2(width, side))
		var square := Rect2(Vector2((width - side) * 0.5, 0.0), Vector2(side, side))
		if not plain:
			draw_rect(rect, Color(0.32, 0.32, 0.34, 0.5) if locked else Color(0.13, 0.14, 0.16, 0.85))
		if not item.is_empty():
			var icon: Texture2D = ItemIcons.for_value(item)
			if icon != null:
				draw_texture_rect(icon, square.grow(-side * 0.08), false)
			var amount := Inventory.count(item)
			if amount > 1:
				var font := ThemeDB.fallback_font
				var text := str(amount)
				var px := maxi(11, roundi(side * 0.28))
				var at := Vector2(width - 4.0 - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x, side - 5.0)
				draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 3, Color(0, 0, 0, 0.85))
				draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)
		if item.is_empty() and picture != null:
			draw_texture_rect(picture, square.grow(-side * 0.12), false, Color(1, 1, 1, 0.45))
		if locked:
			draw_rect(rect, Color(0.55, 0.55, 0.57, 0.4))
		if not plain:
			if chosen:
				draw_rect(rect.grow(-1.5), Color(1.0, 0.9, 0.5), false, 3.0)
			else:
				draw_rect(rect.grow(-0.5), Color(1, 1, 1, 0.2), false, 1.0)
		if with_text:
			_text_line(title, side + font_px + 2.0, Color(0.97, 0.97, 0.93))
			_text_line(note, side + 2.0 * font_px + 5.0, Color(0.85, 0.88, 0.8))

	# Texte centré sous la case, raccourci (…) s'il dépasse un peu la largeur de la case.
	func _text_line(text: String, baseline: float, color: Color) -> void:
		if text.is_empty():
			return
		var font := ThemeDB.fallback_font
		var room := width + 10.0
		var shown := text
		while shown.length() > 2 and font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x > room:
			shown = shown.left(shown.length() - 2) + "…"
		var text_width := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
		var at := Vector2((width - text_width) * 0.5, baseline)
		draw_string_outline(font, at, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, 3, Color(0, 0, 0, 0.8))
		draw_string(font, at, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, color)

var inventory: RefCounted
var text_scale := 1.0
var hud_bar: HBoxContainer
var hud_slots: Array = []
var hud_gap: Control
var weights_label: Label
var screen: Control
var panel: PanelContainer
var mode_label: Label
var creative_box: VBoxContainer
var grid_box: GridContainer
var creative_bar: HBoxContainer
var survival_box: VBoxContainer
var hands_weight: Label
var pockets_weight: Label
var tab_buttons: Array = []
var catalog: GridContainer
var catalog_slots: Array = []
var grid_slots: Array = []
var bar_slots: Array = []
var panel_gap: Control
var message: Label
var cursor: Slot
var cursor_item := {}
var cursor_from: Array = []
var category := 0
# 0.0.7.5 : onglet Inventaire (après les catégories) ; objets des onglets sur 2 lignes au plus.
const INVENTORY_TAB := 4
const CATALOG_ROWS := 2

func setup(owner_inventory: RefCounted, scale: float) -> void:
	inventory = owner_inventory
	text_scale = scale
	name = "Inventory"
	_build_hud()
	_build_screen()
	inventory.changed.connect(refresh)
	refresh()

func is_open() -> bool:
	return is_instance_valid(screen) and screen.visible

func _text_px() -> int:
	return roundi(11 * text_scale)

func _build_hud() -> void:
	hud_bar = HBoxContainer.new()
	hud_bar.name = "HotBar"
	hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_bar.add_theme_constant_override("separation", GAP + 4)
	hud_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	hud_bar.anchor_left = 0.5
	hud_bar.anchor_right = 0.5
	hud_bar.anchor_top = 1.0
	hud_bar.anchor_bottom = 1.0
	hud_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud_bar.offset_bottom = -6
	add_child(hud_bar)
	for index in range(Inventory.BAR_SIZE):
		var slot := Slot.new(roundf(HUD_SLOT * text_scale), true, _text_px())
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_bar.add_child(slot)
		hud_slots.append(slot)
		if index == Inventory.HANDS[-1]:
			# Survie : un peu d'espace entre les mains et les poches.
			hud_gap = Control.new()
			hud_gap.custom_minimum_size = Vector2(14, 0)
			hud_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hud_bar.add_child(hud_gap)
	# Poids portés, en bas à droite (Survie). 0.0.7.4 : 4 pixels plus grand (demande de l'utilisateur), mains et poches.
	weights_label = _label("", 19)
	weights_label.name = "CarriedWeight"
	weights_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	weights_label.add_theme_constant_override("shadow_outline_size", 4)
	weights_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weights_label.anchor_left = 1.0
	weights_label.anchor_right = 1.0
	weights_label.anchor_top = 1.0
	weights_label.anchor_bottom = 1.0
	weights_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	weights_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	weights_label.offset_right = -18
	weights_label.offset_bottom = -12
	add_child(weights_label)

# Hauteur occupée par la barre en bas (pour placer les messages au-dessus).
func hud_height() -> float:
	return roundf(HUD_SLOT * text_scale) + 2.0 * (_text_px() + 3.0) + 12.0

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", roundi(font_size * text_scale))
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.93))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _row(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	return grid

func _tab_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, alpha)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(5)
	return style

func _picture(texture: Texture2D, side: float) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(side, side)
	picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture

func _build_screen() -> void:
	# Plein écran mais transparent : il arrête les clics (le monde ne reprend pas la souris), on voit le monde autour.
	screen = Control.new()
	screen.name = "InventoryScreen"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.visible = false
	screen.gui_input.connect(_on_background)
	add_child(screen)
	panel = PanelContainer.new()
	panel.name = "InventoryPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.8)
	style.border_color = Color(1, 1, 1, 0.14)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	screen.add_child(panel)
	var side := roundf(PANEL_SLOT * minf(text_scale, 1.2))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP + 2)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label("Inventaire", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	mode_label = _label("", 16)
	mode_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8, 0.85))
	header.add_child(mode_label)
	# Créatif : onglets en images (le nom en bulle d'aide), puis les objets de l'onglet choisi.
	creative_box = VBoxContainer.new()
	creative_box.add_theme_constant_override("separation", GAP)
	column.add_child(creative_box)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", GAP)
	creative_box.add_child(tabs)
	var group := ButtonGroup.new()
	var tab_px := roundi(side * 0.72)
	# 0.0.7.5 : onglets Matériaux naturels, Cailloux, Fruits, Outils, puis, tout à droite, Inventaire (la grille).
	for index in range(Inventory.CATEGORIES.size() + 1):
		if index == Inventory.CATEGORIES.size():
			var push := Control.new()
			push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tabs.add_child(push)
		var tab := Button.new()
		var id: String = Inventory.CATEGORIES[index].id if index < Inventory.CATEGORIES.size() else "inventory"
		tab.icon = ItemIcons.tab(id, tab_px)
		tab.tooltip_text = Inventory.CATEGORIES[index].nom if index < Inventory.CATEGORIES.size() else "Inventaire"
		tab.toggle_mode = true
		tab.button_group = group
		tab.focus_mode = Control.FOCUS_NONE
		tab.add_theme_stylebox_override("normal", _tab_style(0.08))
		tab.add_theme_stylebox_override("hover", _tab_style(0.16))
		tab.add_theme_stylebox_override("pressed", _tab_style(0.3))
		tab.add_theme_stylebox_override("hover_pressed", _tab_style(0.34))
		tab.pressed.connect(show_category.bind(index))
		tabs.add_child(tab)
		tab_buttons.append(tab)
	# Objets de l'onglet choisi, sur plusieurs lignes s'il y en a beaucoup.
	catalog = _row(Inventory.COLUMNS)
	creative_box.add_child(catalog)
	for index in range(Inventory.COLUMNS * CATALOG_ROWS):
		# 0.0.7.9 : le nom sous chaque objet (demande de l'utilisateur).
		var slot := Slot.new(side, true, _text_px())
		slot.clicked.connect(_on_catalog.bind(index))
		catalog.add_child(slot)
		catalog_slots.append(slot)
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 6)
	creative_box.add_child(separator)
	# Grille de 5 lignes × 10 colonnes (Créatif).
	grid_box = _row(Inventory.COLUMNS)
	column.add_child(grid_box)
	for index in range(Inventory.GRID_SIZE):
		# 0.0.7.9 : le nom sous chaque objet (demande de l'utilisateur).
		var slot := Slot.new(side, true, _text_px())
		slot.clicked.connect(_on_slot.bind("grid", index))
		grid_box.add_child(slot)
		grid_slots.append(slot)
	panel_gap = Control.new()
	panel_gap.custom_minimum_size = Vector2(0, 10)
	column.add_child(panel_gap)
	# Barre de 10 cases (Créatif), séparée et plus bas.
	creative_bar = HBoxContainer.new()
	creative_bar.add_theme_constant_override("separation", GAP)
	column.add_child(creative_bar)
	bar_slots.resize(Inventory.BAR_SIZE)
	var creative_slots := {}
	for index in range(Inventory.BAR_SIZE):
		var slot := Slot.new(side, true, _text_px())
		slot.clicked.connect(_on_slot.bind("bar", index))
		creative_bar.add_child(slot)
		creative_slots[index] = slot
	# Survie : ligne des mains, puis ligne des poches ; à droite (0.0.7.7), l'équipement à venir.
	survival_area = HBoxContainer.new()
	survival_area.add_theme_constant_override("separation", 24)
	column.add_child(survival_area)
	survival_box = VBoxContainer.new()
	survival_box.add_theme_constant_override("separation", GAP + 4)
	survival_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	survival_area.add_child(survival_box)
	_build_equipment(survival_area, side)
	var survival_slots := {}
	hands_weight = _survival_row(ItemIcons.hand(), Inventory.HANDS, side, survival_slots, "Mains")
	pockets_weight = _survival_row(ItemIcons.pocket(), Inventory.POCKETS, side, survival_slots, "Poches")
	_creative_bar_slots = creative_slots
	_survival_bar_slots = survival_slots
	message = _label("", 14)
	message.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85, 0.85))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(minf(side * 10 + GAP * 9, 560), roundf(20 * text_scale))
	column.add_child(message)
	cursor = Slot.new(side * 0.9)
	cursor.plain = true
	cursor.top_level = true
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.visible = false
	screen.add_child(cursor)
	show_category(0)

# 0.0.7.7 (demande de l'utilisateur) : à droite de l'écran de Survie, ce qu'on pourra porter plus tard, deux cases de
# chaque, grisées et vides : sacs, paniers (bientôt), travois (deux bâtons qu'on traîne, plus tard), chariots (à roues,
# bien plus tard). Quand on en portera, leurs cases apparaîtront en bas à gauche (rien pour l'instant).
const EQUIPMENT := [["sac", "Sac (bientôt)"], ["panier", "Panier (bientôt)"], ["travois", "Travois : deux bâtons qu'on traîne (plus tard)"], ["chariot", "Chariot à roues (bien plus tard)"]]
var survival_area: HBoxContainer
var equipment_slots: Array = []

func _build_equipment(parent: Node, side: float) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	parent.add_child(box)
	box.add_child(_label("Équipement", 14))
	var grid := _row(2)
	box.add_child(grid)
	var small := roundf(side * 0.85)
	for kind in EQUIPMENT:
		for index in range(2):
			var slot := Slot.new(small)
			slot.locked = true
			slot.picture = ItemIcons.equipment(kind[0])
			slot.tooltip_text = kind[1]
			slot.name = "Equipement_%s_%d" % [kind[0], index]
			grid.add_child(slot)
			equipment_slots.append(slot)

var _creative_bar_slots := {}
var _survival_bar_slots := {}

# Une ligne de Survie : image (non cliquable), les cases un peu décalées à droite, et le poids tout à droite.
func _survival_row(picture: Texture2D, indexes: Array, side: float, slots: Dictionary, what: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	survival_box.add_child(row)
	var image := _picture(picture, side)
	image.tooltip_text = what
	row.add_child(image)
	var shift := Control.new()
	shift.custom_minimum_size = Vector2(8, 0)
	row.add_child(shift)
	for index in indexes:
		var slot := Slot.new(side, true, _text_px())
		slot.clicked.connect(_on_slot.bind("bar", index))
		row.add_child(slot)
		slots[index] = slot
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filler.custom_minimum_size = Vector2(24, 0)
	row.add_child(filler)
	var weight := _label("", 15)
	weight.custom_minimum_size = Vector2(0, side)
	weight.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	weight.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(weight)
	return weight

func _hint() -> String:
	if inventory.mode == Inventory.CREATIVE:
		return "Clic gauche : prendre ou poser · clic droit : vider la case (sur un objet du haut : dans la première case libre) · Échap : fermer"
	return "Clic gauche : prendre ou poser (les objets identiques s'empilent, selon le poids) · Échap : fermer"

# Poids écrit sous une case (Survie seulement ; rien sous une case vide).
func _note(index: int) -> String:
	if inventory.mode == Inventory.CREATIVE:
		return ""
	var value: Dictionary = inventory.item("bar", index)
	return "" if value.is_empty() else Inventory.format_weight(Inventory.stack_weight(value))

func _carried(weight: float, limit: float) -> String:
	return "%s / %s" % [Inventory.format_weight(weight), Inventory.format_weight(limit)]

func refresh() -> void:
	if inventory == null:
		return
	var creative: bool = inventory.mode == Inventory.CREATIVE
	var shown: Array = inventory.bar_slots()
	bar_slots.clear()
	for index in range(Inventory.BAR_SIZE):
		var chosen: bool = index == inventory.selected()
		var value: Dictionary = inventory.item("bar", index)
		hud_slots[index].visible = index in shown
		# 0.0.7.8 : objet porté à deux mains : l'autre main grisée.
		var heavy: int = inventory.two_handed()
		var busy: bool = heavy >= 0 and index in Inventory.HANDS and index != heavy
		# 0.0.7.10 : les deux mains réunies en une case double ; l'autre main disparaît de la barre.
		chosen = chosen or (heavy == index and inventory.selected() in Inventory.HANDS)
		hud_slots[index].show_item(value, busy, chosen, _note(index))
		_set_double(hud_slots[index], index == heavy)
		var panel_slot: Slot = _creative_bar_slots[index] if creative or not _survival_bar_slots.has(index) else _survival_bar_slots[index]
		bar_slots.append(panel_slot)
		for slot in [_creative_bar_slots.get(index), _survival_bar_slots.get(index)]:
			if slot != null:
				slot.show_item(value, busy, chosen, _note(index))
				_set_double(slot, index == heavy)
				slot.visible = not busy
	for index in range(Inventory.GRID_SIZE):
		grid_slots[index].show_item(inventory.item("grid", index))
	hud_gap.visible = not creative
	# 0.0.7.5 : en Créatif, la grille seulement dans l'onglet Inventaire ; sinon les objets de l'onglet et la barre.
	grid_box.visible = creative and category == INVENTORY_TAB
	catalog.visible = category != INVENTORY_TAB
	panel_gap.visible = creative
	creative_box.visible = creative
	creative_bar.visible = creative
	survival_box.visible = not creative
	survival_area.visible = not creative
	weights_label.visible = not creative
	var hands_text := _carried(inventory.hands_weight(), Inventory.HANDS_LIMIT)
	var pockets_text := _carried(inventory.pockets_weight(), Inventory.POCKETS_LIMIT)
	hands_weight.text = hands_text
	pockets_weight.text = pockets_text
	weights_label.text = "Mains : %s\nPoches : %s" % [hands_text, pockets_text]
	mode_label.text = "Créatif" if creative else "Survie"
	if not message.has_meta("said"):
		message.text = _hint()

# index : un onglet d'objets (0 à 3) ou INVENTORY_TAB (la grille de 5 × 10, tout à droite).
func show_category(index: int) -> void:
	category = clampi(index, 0, INVENTORY_TAB)
	tab_buttons[category].set_pressed_no_signal(true)
	var objects: Array = Inventory.CATEGORIES[category].objets if category < INVENTORY_TAB else []
	for slot_index in range(catalog_slots.size()):
		var slot: Slot = catalog_slots[slot_index]
		slot.visible = slot_index < objects.size()
		slot.show_item(Inventory.catalog_item(objects[slot_index]) if slot_index < objects.size() else {})
	if inventory != null:
		refresh()

func open() -> void:
	message.remove_meta("said")
	message.text = _hint()
	refresh()
	screen.visible = true
	hud_bar.visible = false

func close() -> void:
	_drop_cursor()
	screen.visible = false
	hud_bar.visible = true

func _say(text: String) -> void:
	message.text = text
	message.set_meta("said", true)

func _on_slot(button: int, area: String, index: int) -> void:
	if not inventory.usable(area, index):
		return
	if button == MOUSE_BUTTON_RIGHT:
		if inventory.mode == Inventory.CREATIVE:
			inventory.take(area, index)
		return
	if cursor_item.is_empty():
		if inventory.item(area, index).is_empty():
			return
		cursor_item = inventory.take(area, index)
		cursor_from = [area, index]
	else:
		var before: Dictionary = cursor_item
		var rest: Dictionary = inventory.put(area, index, cursor_item)
		if rest == before:
			_say("Trop lourd ici : %s au plus." % Inventory.format_weight(inventory.room(area, index)))
			return
		cursor_item = rest
		if rest.is_empty():
			cursor_from = []
		elif not Inventory.same_kind(rest, before):
			cursor_from = [area, index]
	_show_cursor()

func _on_catalog(button: int, index: int) -> void:
	if category >= INVENTORY_TAB:
		return
	var objects: Array = Inventory.CATEGORIES[category].objets
	if index >= objects.size():
		return
	var value := Inventory.catalog_item(objects[index])
	if button == MOUSE_BUTTON_RIGHT:
		var free: Array = inventory.first_free()
		if free.is_empty():
			_say("Plus de case libre.")
		else:
			inventory.put(free[0], free[1], value)
		return
	cursor_item = value
	cursor_from = []
	_show_cursor()

# Clic hors des cases : l'objet tenu retourne d'où il vient (pris dans une catégorie : il disparaît).
func _on_background(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_drop_cursor()

signal overflow(value: Dictionary)

func _drop_cursor() -> void:
	if cursor_item.is_empty():
		return
	if not Inventory.unlimited(cursor_item):
		if not cursor_from.is_empty():
			cursor_item = inventory.put(cursor_from[0], cursor_from[1], cursor_item)
		if not cursor_item.is_empty():
			var added: int = inventory.add(cursor_item)
			cursor_item = cursor_item.duplicate()
			cursor_item.nombre = Inventory.count(cursor_item) - added
			if cursor_item.nombre <= 0:
				cursor_item = {}
		# Ce qui ne tient plus nulle part est posé au sol (world.drop_items), jamais perdu.
		if not cursor_item.is_empty():
			overflow.emit(cursor_item)
	elif not cursor_from.is_empty() and inventory.item(cursor_from[0], cursor_from[1]).is_empty():
		inventory.put(cursor_from[0], cursor_from[1], cursor_item)
	cursor_item = {}
	cursor_from = []
	_show_cursor()

func _show_cursor() -> void:
	cursor.show_item(cursor_item)
	cursor.visible = not cursor_item.is_empty()
	_follow_mouse()

func _follow_mouse() -> void:
	if cursor.visible:
		cursor.global_position = screen.get_global_mouse_position() - cursor.size * 0.5

func _process(_delta: float) -> void:
	if is_open():
		_follow_mouse()

# 0.0.7.10 : case simple ou double (deux cases et l'écart entre elles).
func _set_double(slot: Slot, double: bool) -> void:
	var gap := 0.0
	if slot.get_parent() is BoxContainer or slot.get_parent() is GridContainer:
		gap = float(slot.get_parent().get_theme_constant("separation" if slot.get_parent() is BoxContainer else "h_separation"))
	slot.set_width(slot.side * 2.0 + gap if double else slot.side)
