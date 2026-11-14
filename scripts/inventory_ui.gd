extends CanvasLayer
# 0.0.7.2 : affichage de l'inventaire (inventory.gd).
# En jeu : la barre d'objets de 10 cases, en bas au centre (case choisie encadrée, cases fermées grisées).
# Écran d'inventaire (O + I, modifiable ; Échap ou O + I pour fermer) : un panneau un peu transparent au centre,
# le monde reste visible autour. Créatif : onglets de catégories en haut (Matériaux naturels, Outils), puis la
# grille de 5 × 10 et, plus bas et séparée, la barre. Survie : tout est grisé sauf les 4 cases de droite de la barre.
# Clic gauche : prendre ou poser (échange si la case est occupée) ; clic droit : vider la case (Créatif) ;
# clic droit sur un objet d'une catégorie : dans la première case libre.
const Inventory = preload("res://scripts/inventory.gd")
const HUD_SLOT := 46.0
const PANEL_SLOT := 48.0
const GAP := 6

# Une case dessinée (barre, grille, catégorie ou objet tenu par la souris).
class Slot extends Control:
	signal clicked(button: int)
	var item := {}
	var locked := false
	var chosen := false
	var plain := false

	func _init(side: float) -> void:
		custom_minimum_size = Vector2(side, side)
		size = custom_minimum_size

	func show_item(value: Dictionary, is_locked: bool = false, is_chosen: bool = false) -> void:
		item = value
		locked = is_locked
		chosen = is_chosen
		tooltip_text = Inventory.item_name(value)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			clicked.emit(event.button_index)
			accept_event()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if not plain:
			draw_rect(rect, Color(0.32, 0.32, 0.34, 0.5) if locked else Color(0.13, 0.14, 0.16, 0.85))
		if not item.is_empty():
			Slot.draw_icon(self, item, rect.grow(-size.x * 0.17))
		if locked:
			draw_rect(rect, Color(0.55, 0.55, 0.57, 0.4))
		if not plain:
			if chosen:
				draw_rect(rect.grow(-1.5), Color(1.0, 0.9, 0.5), false, 3.0)
			else:
				draw_rect(rect.grow(-0.5), Color(1, 1, 1, 0.2), false, 1.0)

	# Icône simple dessinée : petit cube de la couleur de la matière, ou pioche.
	static func draw_icon(canvas: CanvasItem, value: Dictionary, rect: Rect2) -> void:
		var spec: Dictionary = Inventory.ITEMS.get(value.get("objet", ""), {})
		if spec.is_empty():
			return
		var p := rect.position
		var w := rect.size.x
		var h := rect.size.y
		if spec.has("outil"):
			var wood := Color("#7a5230")
			var iron: Color = spec.couleur
			canvas.draw_line(p + Vector2(0.18 * w, 0.9 * h), p + Vector2(0.68 * w, 0.26 * h), wood, maxf(2.0, w * 0.1))
			canvas.draw_polyline(PackedVector2Array([p + Vector2(0.28 * w, 0.06 * h), p + Vector2(0.56 * w, 0.14 * h), p + Vector2(0.8 * w, 0.32 * h), p + Vector2(0.94 * w, 0.6 * h)]), iron, maxf(2.0, w * 0.1))
			return
		var color: Color = spec.couleur
		var top := PackedVector2Array([p + Vector2(0.5 * w, 0.05 * h), p + Vector2(0.95 * w, 0.28 * h), p + Vector2(0.5 * w, 0.5 * h), p + Vector2(0.05 * w, 0.28 * h)])
		var left := PackedVector2Array([p + Vector2(0.05 * w, 0.28 * h), p + Vector2(0.5 * w, 0.5 * h), p + Vector2(0.5 * w, 0.97 * h), p + Vector2(0.05 * w, 0.74 * h)])
		var right := PackedVector2Array([p + Vector2(0.5 * w, 0.5 * h), p + Vector2(0.95 * w, 0.28 * h), p + Vector2(0.95 * w, 0.74 * h), p + Vector2(0.5 * w, 0.97 * h)])
		canvas.draw_colored_polygon(top, color.lightened(0.22))
		canvas.draw_colored_polygon(left, color)
		canvas.draw_colored_polygon(right, color.darkened(0.25))

var inventory: RefCounted
var text_scale := 1.0
var hud_bar: HBoxContainer
var hud_slots: Array = []
var screen: Control
var panel: PanelContainer
var mode_label: Label
var creative_box: VBoxContainer
var tab_buttons: Array = []
var catalog: GridContainer
var catalog_slots: Array = []
var grid_slots: Array = []
var bar_slots: Array = []
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

func _build_hud() -> void:
	hud_bar = HBoxContainer.new()
	hud_bar.name = "HotBar"
	hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_bar.add_theme_constant_override("separation", GAP)
	hud_bar.anchor_left = 0.5
	hud_bar.anchor_right = 0.5
	hud_bar.anchor_top = 1.0
	hud_bar.anchor_bottom = 1.0
	hud_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud_bar.offset_bottom = -14
	add_child(hud_bar)
	for index in range(Inventory.BAR_SIZE):
		var slot := Slot.new(roundf(HUD_SLOT * text_scale))
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_bar.add_child(slot)
		hud_slots.append(slot)

# Hauteur occupée par la barre en bas (pour placer les messages au-dessus).
func hud_height() -> float:
	return roundf(HUD_SLOT * text_scale) + 14.0

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
	# Grille de 5 lignes × 10 colonnes.
	var grid := _row(Inventory.COLUMNS)
	column.add_child(grid)
	for index in range(Inventory.GRID_SIZE):
		var slot := Slot.new(side)
		slot.clicked.connect(_on_slot.bind("grid", index))
		grid.add_child(slot)
		grid_slots.append(slot)
	# Barre d'objets, séparée et plus bas.
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	column.add_child(gap)
	var bar := _row(Inventory.BAR_SIZE)
	column.add_child(bar)
	for index in range(Inventory.BAR_SIZE):
		var slot := Slot.new(side)
		slot.clicked.connect(_on_slot.bind("bar", index))
		bar.add_child(slot)
		bar_slots.append(slot)
	message = _label("", 14)
	message.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85, 0.85))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(0, roundf(20 * text_scale))
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
	return "Survie : seules les 4 cases de droite de la barre servent pour l'instant · Échap : fermer"

func refresh() -> void:
	if inventory == null:
		return
	var creative: bool = inventory.mode == Inventory.CREATIVE
	for index in range(Inventory.BAR_SIZE):
		var locked: bool = not inventory.usable("bar", index)
		var chosen: bool = index == inventory.selected()
		hud_slots[index].show_item(inventory.item("bar", index), locked, chosen)
		bar_slots[index].show_item(inventory.item("bar", index), locked, chosen)
	for index in range(Inventory.GRID_SIZE):
		grid_slots[index].show_item(inventory.item("grid", index), not inventory.usable("grid", index))
	mode_label.text = "Créatif" if creative else "Survie"
	creative_box.visible = creative
	if message.text.is_empty() or not message.has_meta("said"):
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
		_say("Case fermée en Survie : seules les 4 cases de droite de la barre servent pour l'instant.")
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
		var before: Dictionary = inventory.put(area, index, cursor_item)
		cursor_item = before
		cursor_from = [area, index] if not before.is_empty() else []
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
	if not cursor_from.is_empty():
		var place: Array = cursor_from if inventory.item(cursor_from[0], cursor_from[1]).is_empty() else inventory.first_free()
		if not place.is_empty():
			inventory.put(place[0], place[1], cursor_item)
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
