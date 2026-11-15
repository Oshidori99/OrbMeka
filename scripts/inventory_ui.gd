extends CanvasLayer
# 0.0.7.2 : affichage de l'inventaire (inventory.gd).
# En jeu : la barre d'objets en bas au centre (case en main encadrée).
# Écran d'inventaire (O + I, modifiable ; Échap ou O + I pour fermer) : un panneau un peu transparent au centre,
# le monde reste visible autour.
# - Créatif : onglets de catégories en haut (Matériaux naturels, Outils), la grille de 5 × 10 et, plus bas, la barre de 10.
# - Survie (0.0.7.3) : pas de grille ni de cases grisées : seulement les deux mains et les quatre poches, le poids sous
#   chaque case et le total des poches (en bas à droite en jeu).
# Clic gauche : prendre ou poser (s'empile sur un objet identique, sinon échange) ; clic droit : vider la case (Créatif) ;
# clic droit sur un objet d'une catégorie : dans la première case libre.
# 0.0.7.3 : icônes rondes pour les matières (demande de l'utilisateur), cailloux en ovale, éclats anguleux.
const Inventory = preload("res://scripts/inventory.gd")
const HUD_SLOT := 46.0
const PANEL_SLOT := 48.0
const GAP := 6

# Une case dessinée (barre, grille, catégorie ou objet tenu par la souris) ; « note » : poids écrit sous la case.
class Slot extends Control:
	signal clicked(button: int)
	var item := {}
	var locked := false
	var chosen := false
	var plain := false
	var side := 46.0
	var note := ""
	var note_size := 12
	# Contour clair : les matières sombres (silex, charbon) se voient sur le fond des cases.
	const RIM := Color(1, 1, 1, 0.28)

	func _init(box_side: float, with_note: bool = false, font_px: int = 12) -> void:
		side = box_side
		note_size = font_px
		custom_minimum_size = Vector2(side, side + (font_px + 6.0 if with_note else 0.0))
		size = custom_minimum_size

	func show_item(value: Dictionary, is_locked: bool = false, is_chosen: bool = false, weight_note: String = "") -> void:
		item = value
		locked = is_locked
		chosen = is_chosen
		note = weight_note
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
		var rect := Rect2(Vector2.ZERO, Vector2(side, side))
		if not plain:
			draw_rect(rect, Color(0.32, 0.32, 0.34, 0.5) if locked else Color(0.13, 0.14, 0.16, 0.85))
		if not item.is_empty():
			Slot.draw_icon(self, item, rect.grow(-side * 0.17))
			var amount := Inventory.count(item)
			if amount > 1:
				var font := ThemeDB.fallback_font
				var text := str(amount)
				var px := maxi(11, roundi(side * 0.28))
				var at := Vector2(side - 4.0 - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x, side - 5.0)
				draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 3, Color(0, 0, 0, 0.85))
				draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)
		if locked:
			draw_rect(rect, Color(0.55, 0.55, 0.57, 0.4))
		if not plain:
			if chosen:
				draw_rect(rect.grow(-1.5), Color(1.0, 0.9, 0.5), false, 3.0)
			else:
				draw_rect(rect.grow(-0.5), Color(1, 1, 1, 0.2), false, 1.0)
		if not note.is_empty():
			var font := ThemeDB.fallback_font
			var width := font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, note_size).x
			var at := Vector2((side - width) * 0.5, side + note_size + 2.0)
			draw_string_outline(font, at, note, HORIZONTAL_ALIGNMENT_LEFT, -1, note_size, 3, Color(0, 0, 0, 0.8))
			draw_string(font, at, note, HORIZONTAL_ALIGNMENT_LEFT, -1, note_size, Color(0.95, 0.95, 0.9))

	# Icône simple dessinée : rond de la couleur de la matière (relief clair en haut à gauche), caillou ovale,
	# éclat anguleux, ou pioche.
	static func draw_icon(canvas: CanvasItem, value: Dictionary, rect: Rect2) -> void:
		var spec: Dictionary = Inventory.ITEMS.get(value.get("objet", ""), {})
		if spec.is_empty():
			return
		var p := rect.position
		var w := rect.size.x
		var h := rect.size.y
		var center := rect.get_center()
		var color: Color = spec.couleur
		if spec.has("outil"):
			canvas.draw_line(p + Vector2(0.18 * w, 0.9 * h), p + Vector2(0.68 * w, 0.26 * h), Color("#7a5230"), maxf(2.0, w * 0.1))
			canvas.draw_polyline(PackedVector2Array([p + Vector2(0.28 * w, 0.06 * h), p + Vector2(0.56 * w, 0.14 * h), p + Vector2(0.8 * w, 0.32 * h), p + Vector2(0.94 * w, 0.6 * h)]), color, maxf(2.0, w * 0.1))
			return
		match spec.get("forme", ""):
			"eclat":
				var points := PackedVector2Array([p + Vector2(0.18 * w, 0.62 * h), p + Vector2(0.38 * w, 0.2 * h), p + Vector2(0.8 * w, 0.3 * h), p + Vector2(0.88 * w, 0.7 * h), p + Vector2(0.5 * w, 0.88 * h)])
				canvas.draw_colored_polygon(points, color)
				canvas.draw_colored_polygon(PackedVector2Array([points[1], points[2], center]), color.lightened(0.25))
				canvas.draw_colored_polygon(PackedVector2Array([points[3], points[4], center]), color.darkened(0.3))
				points.append(points[0])
				canvas.draw_polyline(points, RIM, 1.0, true)
			"caillou":
				var oval := PackedVector2Array()
				for step in range(24):
					var angle := TAU * step / 24.0
					oval.append(center + Vector2(cos(angle) * w * 0.46, sin(angle) * h * 0.34 + h * 0.06))
				canvas.draw_colored_polygon(oval, color.darkened(0.15))
				canvas.draw_circle(center + Vector2(-w * 0.1, -h * 0.02), w * 0.22, color.lightened(0.12))
				oval.append(oval[0])
				canvas.draw_polyline(oval, RIM, 1.0, true)
			_:
				canvas.draw_circle(center, w * 0.46, color.darkened(0.2))
				canvas.draw_arc(center, w * 0.46, 0.0, TAU, 32, RIM, 1.0, true)
				canvas.draw_circle(center + Vector2(-w * 0.06, -h * 0.06), w * 0.38, color)
				canvas.draw_circle(center + Vector2(-w * 0.16, -h * 0.16), w * 0.12, color.lightened(0.3))

var inventory: RefCounted
var text_scale := 1.0
var hud_bar: HBoxContainer
var hud_slots: Array = []
var hud_gap: Control
var pockets_label: Label
var screen: Control
var panel: PanelContainer
var mode_label: Label
var creative_box: VBoxContainer
var grid_box: GridContainer
var bar_gap: Control
var bar_titles: HBoxContainer
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

func _note_px() -> int:
	return roundi(12 * text_scale)

func _build_hud() -> void:
	hud_bar = HBoxContainer.new()
	hud_bar.name = "HotBar"
	hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_bar.add_theme_constant_override("separation", GAP)
	hud_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	hud_bar.anchor_left = 0.5
	hud_bar.anchor_right = 0.5
	hud_bar.anchor_top = 1.0
	hud_bar.anchor_bottom = 1.0
	hud_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud_bar.offset_bottom = -10
	add_child(hud_bar)
	for index in range(Inventory.BAR_SIZE):
		var slot := Slot.new(roundf(HUD_SLOT * text_scale), true, _note_px())
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_bar.add_child(slot)
		hud_slots.append(slot)
		if index == Inventory.HANDS[-1]:
			# Survie : un peu d'espace entre les mains et les poches.
			hud_gap = Control.new()
			hud_gap.custom_minimum_size = Vector2(14, 0)
			hud_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hud_bar.add_child(hud_gap)
	pockets_label = _label("", 15)
	pockets_label.name = "PocketsWeight"
	pockets_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	pockets_label.add_theme_constant_override("shadow_outline_size", 3)
	pockets_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pockets_label.anchor_left = 1.0
	pockets_label.anchor_right = 1.0
	pockets_label.anchor_top = 1.0
	pockets_label.anchor_bottom = 1.0
	pockets_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pockets_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pockets_label.offset_right = -18
	pockets_label.offset_bottom = -14
	add_child(pockets_label)

# Hauteur occupée par la barre en bas (pour placer les messages au-dessus).
func hud_height() -> float:
	return roundf(HUD_SLOT * text_scale) + _note_px() + 16.0

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
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

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
	# Créatif : onglets des catégories, puis leurs objets.
	creative_box = VBoxContainer.new()
	creative_box.add_theme_constant_override("separation", GAP)
	column.add_child(creative_box)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", GAP)
	creative_box.add_child(tabs)
	var group := ButtonGroup.new()
	for index in range(Inventory.CATEGORIES.size()):
		var tab := Button.new()
		tab.text = Inventory.CATEGORIES[index].nom
		tab.toggle_mode = true
		tab.button_group = group
		tab.focus_mode = Control.FOCUS_NONE
		tab.add_theme_font_size_override("font_size", roundi(15 * text_scale))
		tab.add_theme_stylebox_override("normal", _tab_style(0.08))
		tab.add_theme_stylebox_override("hover", _tab_style(0.16))
		tab.add_theme_stylebox_override("pressed", _tab_style(0.3))
		tab.add_theme_stylebox_override("hover_pressed", _tab_style(0.34))
		tab.pressed.connect(show_category.bind(index))
		tabs.add_child(tab)
		tab_buttons.append(tab)
	catalog = _row(Inventory.COLUMNS)
	creative_box.add_child(catalog)
	for index in range(Inventory.COLUMNS):
		var slot := Slot.new(side)
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
		var slot := Slot.new(side)
		slot.clicked.connect(_on_slot.bind("grid", index))
		grid_box.add_child(slot)
		grid_slots.append(slot)
	# Barre d'objets, séparée et plus bas (Survie : « Mains » et « Poches » au-dessus).
	panel_gap = Control.new()
	panel_gap.custom_minimum_size = Vector2(0, 14)
	column.add_child(panel_gap)
	bar_titles = HBoxContainer.new()
	bar_titles.add_theme_constant_override("separation", GAP)
	column.add_child(bar_titles)
	var hands_title := _label("Mains (400,0 g chacune)", 14)
	hands_title.custom_minimum_size = Vector2(side * 2 + GAP + 14, 0)
	bar_titles.add_child(hands_title)
	bar_titles.add_child(_label("Poches (150,0 g en tout)", 14))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", GAP)
	column.add_child(bar)
	for index in range(Inventory.BAR_SIZE):
		var slot := Slot.new(side, true, _note_px())
		slot.clicked.connect(_on_slot.bind("bar", index))
		bar.add_child(slot)
		bar_slots.append(slot)
		if index == Inventory.HANDS[-1]:
			bar_gap = Control.new()
			bar_gap.custom_minimum_size = Vector2(14, 0)
			bar.add_child(bar_gap)
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

func _hint() -> String:
	if inventory.mode == Inventory.CREATIVE:
		return "Clic gauche : prendre ou poser · clic droit : vider la case (sur une catégorie : dans la première case libre) · Échap : fermer"
	return "Clic gauche : prendre ou poser (les objets identiques s'empilent, selon le poids) · Échap : fermer"

# Poids écrit sous une case (Survie seulement ; rien sous une case vide).
func _note(index: int) -> String:
	if inventory.mode == Inventory.CREATIVE:
		return ""
	var value: Dictionary = inventory.item("bar", index)
	return "" if value.is_empty() else Inventory.format_weight(Inventory.stack_weight(value))

func refresh() -> void:
	if inventory == null:
		return
	var creative: bool = inventory.mode == Inventory.CREATIVE
	var shown: Array = inventory.bar_slots()
	for index in range(Inventory.BAR_SIZE):
		var chosen: bool = index == inventory.selected()
		var value: Dictionary = inventory.item("bar", index)
		hud_slots[index].visible = index in shown
		bar_slots[index].visible = index in shown
		hud_slots[index].show_item(value, false, chosen, _note(index))
		bar_slots[index].show_item(value, false, chosen, _note(index))
	for index in range(Inventory.GRID_SIZE):
		grid_slots[index].show_item(inventory.item("grid", index))
	hud_gap.visible = not creative
	bar_gap.visible = not creative
	bar_titles.visible = not creative
	grid_box.visible = creative
	panel_gap.visible = creative
	creative_box.visible = creative
	pockets_label.visible = not creative
	pockets_label.text = "Poches : %s / %s" % [Inventory.format_weight(inventory.pockets_weight()), Inventory.format_weight(Inventory.POCKETS_LIMIT)]
	mode_label.text = "Créatif" if creative else "Survie"
	if not message.has_meta("said"):
		message.text = _hint()

func show_category(index: int) -> void:
	category = clampi(index, 0, Inventory.CATEGORIES.size() - 1)
	tab_buttons[category].set_pressed_no_signal(true)
	var objects: Array = Inventory.CATEGORIES[category].objets
	for slot_index in range(catalog_slots.size()):
		var slot: Slot = catalog_slots[slot_index]
		slot.visible = slot_index < objects.size()
		slot.show_item({"objet": objects[slot_index]} if slot_index < objects.size() else {})

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
			_say("Trop lourd pour cette case : %s au plus." % Inventory.format_weight(inventory.room(area, index)))
			return
		cursor_item = rest
		if rest.is_empty():
			cursor_from = []
		elif not Inventory.same_kind(rest, before):
			cursor_from = [area, index]
	_show_cursor()

func _on_catalog(button: int, index: int) -> void:
	var objects: Array = Inventory.CATEGORIES[category].objets
	if index >= objects.size():
		return
	var value := {"objet": objects[index]}
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
		# Ce qui ne tient plus nulle part retourne au monde (inventory_overflow), jamais perdu.
		if not cursor_item.is_empty():
			overflow.emit(cursor_item)
	elif not cursor_from.is_empty() and inventory.item(cursor_from[0], cursor_from[1]).is_empty():
		inventory.put(cursor_from[0], cursor_from[1], cursor_item)
	cursor_item = {}
	cursor_from = []
	_show_cursor()

signal overflow(value: Dictionary)

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
