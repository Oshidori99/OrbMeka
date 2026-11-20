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
const Controls = preload("res://scripts/controls.gd")
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
	# 0.0.7.29 : bouton « + » en haut à droite (sous-possibilités) ; case d'une sous-possibilité (fond vert sombre).
	signal more_clicked
	var more := false
	var variant := false
	# 0.0.7.30 : sous-possibilités ouvertes : le « + » devient un « − » blanc gras sur fond rouge (pour refermer).
	var opened := false
	# 0.0.7.31 : case choisie en glissant (cadre jaune) et ce qu'elle recevra (« +3 »).
	var drag_mark := ""
	var dragged := false

	func more_rect() -> Rect2:
		var badge := maxf(roundf(side * 0.3), 13.0)
		return Rect2(Vector2(width - badge - 2.0, 2.0), Vector2(badge, badge))

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
		# 0.0.7.18 : bois : sous la case, l'arbre seulement (le nom complet coupé ne se lisait pas) ; tout au survol.
		if with_text and value.get("objet", "") in ["tronc", "branche", "rameau"] and value.has("essence"):
			title = Inventory.ESSENCE_NAMES[clampi(int(value.essence), 0, 3)].capitalize()
		var name := Inventory.item_name(value)
		if not value.is_empty() and not Inventory.unlimited(value):
			name += " × %d (%s)" % [Inventory.count(value), Inventory.format_weight(Inventory.stack_weight(value))]
		# 0.0.7.26 (#212) : bâton : ses qualités et sa note de manche au survol.
		var wood := Inventory.wood_details(value)
		if not wood.is_empty():
			name += "\n" + wood.left(1).to_upper() + wood.substr(1)
		tooltip_text = name
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if more and not item.is_empty() and event.button_index == MOUSE_BUTTON_LEFT and more_rect().grow(2.0).has_point(event.position):
				more_clicked.emit()
				accept_event()
				return
			clicked.emit(event.button_index)
			accept_event()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, Vector2(width, side))
		var square := Rect2(Vector2((width - side) * 0.5, 0.0), Vector2(side, side))
		if not plain:
			draw_rect(rect, Color(0.32, 0.32, 0.34, 0.5) if locked else (Color(0.1, 0.22, 0.13, 0.92) if variant else Color(0.13, 0.14, 0.16, 0.85)))
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
		# 0.0.7.29 : « + » blanc un peu gras sur fond vert, en haut à droite ; 0.0.7.30 : ouvert, « − » blanc gras sur rouge.
		if more and not item.is_empty():
			var badge := more_rect()
			draw_rect(badge, Color("#d23c3c") if opened else Color("#2f9e4f"))
			draw_rect(badge, Color(1, 1, 1, 0.35), false, 1.0)
			var center := badge.get_center()
			var arm := badge.size.x * 0.3
			var thick := maxf(2.5, badge.size.x * 0.17)
			draw_line(center - Vector2(arm, 0.0), center + Vector2(arm, 0.0), Color.WHITE, thick + (1.0 if opened else 0.0))
			if not opened:
				draw_line(center - Vector2(0.0, arm), center + Vector2(0.0, arm), Color.WHITE, thick)
		if dragged:
			draw_rect(rect.grow(-1.5), Color(1.0, 0.85, 0.3), false, 3.0)
			if not drag_mark.is_empty():
				var mark_font := ThemeDB.fallback_font
				var mark_px := maxi(11, roundi(side * 0.26))
				var mark_at := Vector2(4.0, mark_px + 2.0)
				draw_string_outline(mark_font, mark_at, drag_mark, HORIZONTAL_ALIGNMENT_LEFT, -1, mark_px, 3, Color(0, 0, 0, 0.9))
				draw_string(mark_font, mark_at, drag_mark, HORIZONTAL_ALIGNMENT_LEFT, -1, mark_px, Color(1.0, 0.88, 0.4))
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

# 0.0.7.29 (demande de l'utilisateur) : zone « Jeter » avec une croix, sous la barre à droite : cliquer dessus avec l'objet
# tenu le jette (Créatif : il disparaît ; Survie : il tombe au sol devant soi). Lâcher l'objet hors de la fenêtre aussi.
class ThrowZone extends Control:
	signal clicked
	var font_px := 13

	func _init(height: float, px: int) -> void:
		font_px = px
		custom_minimum_size = Vector2(roundf(height * 2.6), roundf(height * 0.78))
		tooltip_text = "Jeter l'objet tenu (ou le lâcher hors de la fenêtre)"
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit()
			accept_event()

	func _draw() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.32, 0.1, 0.09, 0.85)
		box.border_color = Color(0.95, 0.45, 0.4, 0.8)
		box.set_border_width_all(1)
		box.set_corner_radius_all(8)
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		var mark := size.y * 0.5
		var center := Vector2(size.y * 0.55, size.y * 0.5)
		var arm := mark * 0.42
		var color := Color("#ff8a7a")
		draw_line(center + Vector2(-arm, -arm), center + Vector2(arm, arm), color, 3.0)
		draw_line(center + Vector2(-arm, arm), center + Vector2(arm, -arm), color, 3.0)
		var font := ThemeDB.fallback_font
		var at := Vector2(size.y * 1.05, (size.y + font_px * 0.72) * 0.5)
		draw_string(font, at, "Jeter", HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, Color.WHITE)

var inventory: RefCounted
var text_scale := 1.0
var hud_bar: HBoxContainer
var hud_slots: Array = []
var hud_gap: Control
var weights_label: VBoxContainer
# 0.0.7.19 : barres et textes des mains et des poches : en jeu {"mains": [barre, texte], …}.
var hud_carried := {}
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
# 0.0.7.18 : après les onglets d'objets (Bois compris), toujours le dernier.
const INVENTORY_TAB := 5
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
	# Poids portés, en bas à droite (Survie). 0.0.7.19 (demande de l'utilisateur) : pour les mains et les poches, une petite
	# image (au lieu des mots), une barre (la limite la plus proche : poids ou volume) et le texte un peu plus petit.
	weights_label = VBoxContainer.new()
	weights_label.name = "CarriedWeight"
	weights_label.add_theme_constant_override("separation", 4)
	weights_label.anchor_left = 1.0
	weights_label.anchor_right = 1.0
	weights_label.anchor_top = 1.0
	weights_label.anchor_bottom = 1.0
	weights_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	weights_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	weights_label.offset_right = -18
	weights_label.offset_bottom = -12
	weights_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(weights_label)
	for what in ["mains", "poches"]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		weights_label.add_child(row)
		var icon := TextureRect.new()
		icon.texture = ItemIcons.hand() if what == "mains" else ItemIcons.pocket()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2.ONE * roundf(24 * text_scale)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var bar := FillBar.new(roundf(70 * text_scale), roundf(17 * text_scale), "kg")
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var text := _label("", 15)
		text.add_theme_color_override("font_shadow_color", Color.BLACK)
		text.add_theme_constant_override("shadow_outline_size", 4)
		row.add_child(text)
		hud_carried[what] = [bar, text]

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
	# 0.0.7.29 : objets de l'onglet et grille dans une zone qui défile (barre bien visible), les sous-possibilités pouvant
	# ajouter beaucoup de lignes.
	creative_scroll = ScrollContainer.new()
	creative_scroll.name = "CreativeScroll"
	creative_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scroll(creative_scroll)
	creative_box.add_child(creative_scroll)
	scroll_body = VBoxContainer.new()
	scroll_body.add_theme_constant_override("separation", GAP + 2)
	creative_scroll.add_child(scroll_body)
	# Objets de l'onglet choisi, sur plusieurs lignes s'il y en a beaucoup.
	catalog = _row(Inventory.COLUMNS)
	scroll_body.add_child(catalog)
	for index in range(Inventory.COLUMNS * CATALOG_ROWS):
		# 0.0.7.9 : le nom sous chaque objet (demande de l'utilisateur).
		var slot := Slot.new(side, true, _text_px())
		slot.clicked.connect(_on_catalog.bind(index))
		slot.more_clicked.connect(_toggle_more.bind(slot))
		catalog.add_child(slot)
		catalog_slots.append(slot)
	var separator := HSeparator.new()
	separator.add_theme_constant_override("separation", 6)
	creative_box.add_child(separator)
	# Grille de 5 lignes × 10 colonnes (Créatif).
	grid_box = _row(Inventory.COLUMNS)
	scroll_body.add_child(grid_box)
	for index in range(Inventory.GRID_SIZE):
		# 0.0.7.9 : le nom sous chaque objet (demande de l'utilisateur).
		var slot := Slot.new(side, true, _text_px())
		slot.clicked.connect(_on_slot.bind("grid", index))
		slot.more_clicked.connect(_toggle_more.bind(slot))
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
		slot.more_clicked.connect(_toggle_more.bind(slot))
		creative_bar.add_child(slot)
		creative_slots[index] = slot
	creative_throw = _throw_row(column)
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
	_throw_row(survival_box)
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
		slot.more_clicked.connect(_toggle_more.bind(slot))
		row.add_child(slot)
		slots[index] = slot
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filler.custom_minimum_size = Vector2(24, 0)
	row.add_child(filler)
	# 0.0.7.19 (demande de l'utilisateur) : le texte (poids et volume, un peu plus petit), puis dessous, centrées, deux
	# petites barres côte à côte : poids à gauche, volume à droite.
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(0, side)
	box.add_theme_constant_override("separation", 3)
	row.add_child(box)
	var weight := _label("", 13)
	weight.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(weight)
	var bars := HBoxContainer.new()
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.add_theme_constant_override("separation", 8)
	box.add_child(bars)
	var heavy := FillBar.new(roundf(62 * text_scale), roundf(16 * text_scale), "kg")
	heavy.tooltip_text = "Poids"
	var bulky := FillBar.new(roundf(62 * text_scale), roundf(16 * text_scale), "L")
	bulky.tooltip_text = "Volume"
	bars.add_child(heavy)
	bars.add_child(bulky)
	panel_bars[what] = [heavy, bulky]
	return weight

# 0.0.7.19 : petite barre comme la batterie d'un téléphone, le pourcentage dedans : vert, jaune dès 60 %, orange dès
# 80 %, rouge à 100 %. « unit » (kg ou L) écrit après le pourcentage.
class FillBar extends Control:
	var share := 0.0
	var unit := ""
	var bar_size := Vector2(60, 16)

	func _init(width: float, height: float, what: String) -> void:
		bar_size = Vector2(width, height)
		unit = what
		custom_minimum_size = bar_size
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_share(value: float, what: String = "") -> void:
		share = maxf(value, 0.0)
		if not what.is_empty():
			unit = what
		queue_redraw()

	static func color_for(value: float) -> Color:
		if value >= 0.999:
			return Color("#d64545")
		if value >= 0.8:
			return Color("#e88a2e")
		if value >= 0.6:
			return Color("#e8c93a")
		return Color("#5cb85c")

	func _draw() -> void:
		var cap := maxf(2.0, bar_size.x * 0.05)
		var body := Rect2(Vector2.ZERO, Vector2(bar_size.x - cap, bar_size.y))
		draw_rect(body, Color(0.05, 0.05, 0.06, 0.75))
		var inner := body.grow(-2.0)
		inner.size.x *= clampf(share, 0.0, 1.0)
		if inner.size.x > 0.5:
			draw_rect(inner, color_for(share))
		draw_rect(body, Color(0.9, 0.9, 0.9, 0.9), false, 1.5)
		draw_rect(Rect2(Vector2(body.end.x, bar_size.y * 0.3), Vector2(cap, bar_size.y * 0.4)), Color(0.9, 0.9, 0.9, 0.9))
		var font := get_theme_default_font()
		var size := maxi(int(bar_size.y * 0.68), 8)
		var text := "%d %%%s" % [roundi(share * 100.0), (" " + unit) if not unit.is_empty() else ""]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := Vector2((body.size.x - width) * 0.5, (bar_size.y + size * 0.72) * 0.5)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, 0.8))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)

var panel_bars := {}

func _hint() -> String:
	if inventory.mode == Inventory.CREATIVE:
		return "Clic gauche : prendre ou poser (glisser : partager le tas entre les cases) · clic droit avec un objet tenu : en poser un (glisser : un par case) ; sur un objet du haut : dans la première case libre · « + » : détails (ce qu'on a) ou variantes (en haut) · D + T : détails de l'objet en main · Jeter (au sol) : la croix, hors de la fenêtre ou J (Ctrl + J : tout le tas) · D + E : supprimer le tas · Échap : fermer"
	return "Clic gauche : prendre ou poser (glisser : partager le tas entre les cases ; mains : 4 kg et 1,5 L chacune, 8 kg et 3 L à deux ; poches : 500 g et 0,5 L) · clic droit avec un objet tenu : en poser un (glisser : un par case) · « + » : les détails · D + T : détails de l'objet en main · Jeter (au sol) : la croix, hors de la fenêtre ou J (Ctrl + J : tout le tas) · Échap : fermer"

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
	# 0.0.7.19 : poids et volume, barres (inventaire : les deux ; jeu : la limite la plus proche).
	for what in ["mains", "poches"]:
		var hands: bool = what == "mains"
		var text := "%s · %s" % [_carried(inventory.hands_weight() if hands else inventory.pockets_weight(), Inventory.HANDS_LIMIT if hands else Inventory.POCKETS_LIMIT), "%s / %s" % [Inventory.format_volume(inventory.hands_volume() if hands else inventory.pockets_volume()), Inventory.format_volume(Inventory.HANDS_VOLUME if hands else Inventory.POCKETS_VOLUME)]]
		var full: Dictionary = inventory.fill(what)
		(hands_weight if hands else pockets_weight).text = text
		var pair: Array = panel_bars.get("Mains" if hands else "Poches", [])
		if pair.size() == 2:
			pair[0].set_share(full.poids)
			pair[1].set_share(full.volume)
		var carried: Array = hud_carried.get(what, [])
		if carried.size() == 2:
			var heavier: bool = full.poids >= full.volume
			carried[0].set_share(full.poids if heavier else full.volume, "kg" if heavier else "L")
			carried[1].text = text
	mode_label.text = "Créatif" if creative else "Survie"
	if not message.has_meta("said"):
		message.text = _hint()
	creative_throw.visible = creative
	# 0.0.7.29 : « + » sur les cases de l'inventaire qui ont des sous-possibilités (jamais sur la barre du jeu).
	for slot in _panel_slots():
		slot.more = _has_more(slot.item, slot in catalog_slots)
		slot.queue_redraw()
	# Survie : détails ouverts refaits (ce qu'on porte a changé) ; 0.0.7.30 : Créatif, si l'objet de la case a changé.
	# 0.0.7.31 : pas les détails de l'objet tenu par la souris (D + T).
	if more_slot != null and is_instance_valid(more_slot) and more_value.is_empty() and (not creative or more_slot.item != more_item):
		_open_more(more_slot, more_sticky)
	_fit_scroll.call_deferred()

# index : un onglet d'objets (0 à 4) ou INVENTORY_TAB (la grille de 5 × 10, tout à droite).
func show_category(index: int) -> void:
	_close_more()
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
	_close_more()
	drag_button = 0
	drag_places = []
	_mark_drag()
	_drop_cursor()
	screen.visible = false
	hud_bar.visible = true

func _say(text: String) -> void:
	message.text = text
	message.set_meta("said", true)

# 0.0.7.31 (demandes de l'utilisateur) : clic droit sur une case : ne vide plus la case (Créatif) ; avec un objet tenu, il
# en pose un seul ; bouton droit maintenu en glissant : un dans chaque case. Bouton gauche maintenu en glissant avec un
# objet tenu : à la fin, le tas est réparti à parts égales entre les cases choisies (le reste reste en main). Le glisser
# ne commence qu'avec un vrai bouton tenu (real) ; sinon (tests, clic simple), un clic gauche pose tout de suite.
func _on_slot(button: int, area: String, index: int) -> void:
	if not inventory.usable(area, index):
		return
	var real: bool = Input.is_mouse_button_pressed(button)
	if button == MOUSE_BUTTON_RIGHT:
		if cursor_item.is_empty():
			return
		_put_one([area, index])
		if real:
			_start_drag(MOUSE_BUTTON_RIGHT, [[area, index]])
		return
	if cursor_item.is_empty():
		if inventory.item(area, index).is_empty():
			return
		cursor_item = inventory.take(area, index)
		cursor_from = [area, index]
		if real:
			# Pris en appuyant : glisser vers d'autres cases les choisit (pas la case de départ tant qu'on ne l'a pas quittée).
			_start_drag(MOUSE_BUTTON_LEFT, [], [area, index])
		_show_cursor()
		return
	if real:
		_start_drag(MOUSE_BUTTON_LEFT, [[area, index]])
		return
	_put_cursor(area, index)

# Pose l'objet tenu dans une case (s'empile, sinon échange), comme avant 0.0.7.31.
func _put_cursor(area: String, index: int) -> void:
	var before: Dictionary = cursor_item
	var rest: Dictionary = inventory.put(area, index, cursor_item)
	if rest == before:
		_say_refusal(before)
		return
	cursor_item = rest
	if rest.is_empty():
		cursor_from = []
	elif not Inventory.same_kind(rest, before):
		cursor_from = [area, index]
	_show_cursor()

# 0.0.7.19 : dit pourquoi (poids, volume ou nombre).
func _say_refusal(value: Dictionary) -> void:
	match inventory.last_refusal:
		"encombrant":
			_say("Trop encombrant ici : 1,5 L par main, 3 L à deux mains, 0,5 L dans les poches.")
		"nombre":
			_say("%d %s au plus dans une main." % [Inventory.hand_count(value.get("objet", "")), Inventory.plural_name(value)])
		_:
			_say("Trop lourd ici : 4 kg par main, 8 kg à deux mains, 500 g dans les poches.")

# --- 0.0.7.31 : glisser l'objet tenu sur plusieurs cases ---
var drag_button := 0
var drag_places: Array = []
var drag_skip: Array = []

func _start_drag(button: int, places: Array, skip: Array = []) -> void:
	drag_button = button
	drag_places = places
	drag_skip = skip
	_mark_drag()

# La souris passe sur une case (bouton tenu) : elle est choisie si l'objet tenu peut y aller ; bouton droit : un objet posé.
func _drag_over(place: Array) -> void:
	if drag_button == 0 or cursor_item.is_empty():
		return
	if place != drag_skip:
		drag_skip = []
	if place.is_empty() or place == drag_skip or place in drag_places or not _can_drop(place):
		return
	drag_places.append(place)
	if drag_button == MOUSE_BUTTON_RIGHT:
		_put_one(place)
	_mark_drag()

# Bouton relâché : bouton gauche, une case : posé comme un clic ; plusieurs : réparti à parts égales.
func _end_drag() -> void:
	var button := drag_button
	var places := drag_places
	drag_button = 0
	drag_places = []
	drag_skip = []
	_mark_drag()
	if button != MOUSE_BUTTON_LEFT or cursor_item.is_empty():
		return
	if places.size() == 1:
		_put_cursor(places[0][0], places[0][1])
	elif places.size() > 1:
		_share(places)

# Une case vide ou du même genre (un objet illimité : seulement une case vide).
func _can_drop(place: Array) -> bool:
	if not inventory.usable(place[0], place[1]):
		return false
	var there: Dictionary = inventory.item(place[0], place[1])
	if there.is_empty():
		return true
	return not Inventory.unlimited(cursor_item) and not Inventory.unlimited(there) and Inventory.same_kind(there, cursor_item)

# Parts égales : le tas divisé par le nombre de cases (au moins 1 par case tant qu'il en reste) ; ce qui ne rentre pas
# (poids, volume, nombre) et le reste de la division restent en main. Un objet illimité : une copie dans chaque case.
func _share(places: Array) -> void:
	if Inventory.unlimited(cursor_item):
		for place in places:
			if inventory.item(place[0], place[1]).is_empty():
				inventory.put(place[0], place[1], cursor_item.duplicate(true))
		return
	var each := maxi(Inventory.count(cursor_item) / places.size(), 1)
	for place in places:
		if cursor_item.is_empty():
			break
		var parts: Array = Inventory._split(cursor_item, mini(each, Inventory.count(cursor_item)))
		var rest: Dictionary = inventory.put(place[0], place[1], parts[0])
		cursor_item = _join(parts[1], rest)
	if cursor_item.is_empty():
		cursor_from = []
	_show_cursor()

# Un seul objet de ce qu'on tient (le dernier pris) dans la case ; un objet illimité : une copie dans une case vide.
func _put_one(place: Array) -> void:
	if cursor_item.is_empty() or not _can_drop(place):
		return
	if Inventory.unlimited(cursor_item):
		inventory.put(place[0], place[1], cursor_item.duplicate(true))
		return
	var parts: Array = Inventory._split(cursor_item, Inventory.count(cursor_item) - 1)
	var rest: Dictionary = inventory.put(place[0], place[1], parts[1])
	if rest == parts[1]:
		_say_refusal(parts[1])
	cursor_item = _join(parts[0], rest)
	if cursor_item.is_empty():
		cursor_from = []
	_show_cursor()

# Deux tas du même genre réunis (ce qui reste en main).
static func _join(a: Dictionary, b: Dictionary) -> Dictionary:
	if a.is_empty():
		return b
	if b.is_empty():
		return a
	var joined := a.duplicate(true)
	if joined.has("pile"):
		joined.pile.append_array(b.get("pile", []))
	else:
		joined.nombre = Inventory.count(a) + Inventory.count(b)
	return joined

# Cadres jaunes des cases choisies ; bouton gauche : la part de chacune (« +3 »).
func _mark_drag() -> void:
	for slot in _panel_slots():
		if slot.dragged:
			slot.dragged = false
			slot.drag_mark = ""
			slot.queue_redraw()
	if drag_places.is_empty():
		return
	var mark := ""
	if drag_button == MOUSE_BUTTON_LEFT and not Inventory.unlimited(cursor_item):
		mark = "+%d" % maxi(Inventory.count(cursor_item) / drag_places.size(), 1)
	for place in drag_places:
		var slot := _slot_for(place)
		if slot != null:
			slot.dragged = true
			slot.drag_mark = mark
			slot.queue_redraw()

# Case de l'écran d'inventaire pour [zone, numéro].
func _slot_for(place: Array) -> Slot:
	if place[0] == "grid":
		return grid_slots[place[1]] if place[1] < grid_slots.size() else null
	var slots: Dictionary = _creative_bar_slots if inventory.mode == Inventory.CREATIVE else _survival_bar_slots
	return slots.get(place[1])

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
# 0.0.7.29 : clic gauche hors de la fenêtre avec un objet tenu : il est jeté (demande de l'utilisateur).
func _on_background(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not cursor_item.is_empty():
			throw_cursor()
		else:
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
		_watch_more()

# 0.0.7.10 : case simple ou double (deux cases et l'écart entre elles).
func _set_double(slot: Slot, double: bool) -> void:
	var gap := 0.0
	if slot.get_parent() is BoxContainer or slot.get_parent() is GridContainer:
		gap = float(slot.get_parent().get_theme_constant("separation" if slot.get_parent() is BoxContainer else "h_separation"))
	slot.set_width(slot.side * 2.0 + gap if double else slot.side)

# --- 0.0.7.29 (demande de l'utilisateur) : jeter, sous-possibilités, défilement ---
var creative_scroll: ScrollContainer
var scroll_body: VBoxContainer
var creative_throw: Control
var more_slot: Slot = null
var more_nodes: Array = []
var more_sticky := false
var more_frame := 0

# Barre de défilement large et bien visible.
func _style_scroll(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 14
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(6)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.95, 0.85, 0.45, 0.9)
	grabber.set_corner_radius_all(6)
	var grabber_hover := grabber.duplicate()
	grabber_hover.bg_color = Color(1.0, 0.92, 0.6, 1.0)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	bar.add_theme_stylebox_override("grabber_pressed", grabber_hover)

# Zone qui défile : la hauteur de son contenu, au plus la moitié de l'écran.
func _fit_scroll() -> void:
	if creative_scroll == null or scroll_body == null or not is_inside_tree():
		return
	var body := scroll_body.get_combined_minimum_size()
	var limit := maxf(get_viewport().get_visible_rect().size.y * 0.5, 160.0)
	creative_scroll.custom_minimum_size = Vector2(body.x + 18.0, minf(body.y, limit))

# Ligne « Jeter » : la zone à droite, sous la barre.
func _throw_row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ThrowRow"
	parent.add_child(row)
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(push)
	var zone := ThrowZone.new(roundf(PANEL_SLOT * minf(text_scale, 1.2)), roundi(14 * text_scale))
	zone.name = "Throw"
	zone.clicked.connect(throw_cursor)
	row.add_child(zone)
	return row

# Jette l'objet tenu par la souris : il tombe au sol devant soi (world.drop_items). 0.0.7.30 (demande de l'utilisateur) :
# en Créatif aussi (un objet illimité : une copie tombe) ; supprimer : D + E (Créatif).
func throw_cursor() -> void:
	if cursor_item.is_empty():
		_say("Prenez d'abord un objet, puis cliquez sur Jeter (ou lâchez-le hors de la fenêtre).")
		return
	var thrown := cursor_item
	cursor_item = {}
	cursor_from = []
	_discard(thrown)
	_show_cursor()

# Au sol devant soi, ou supprimé (delete : Créatif, D + E).
func _discard(thrown: Dictionary, delete: bool = false) -> void:
	var amount := Inventory.count(thrown)
	var label := Inventory.item_name(thrown) + (" × %d" % amount if amount > 1 else "")
	if delete:
		_say("%s supprimé." % label)
	else:
		overflow.emit(thrown)
		_say("%s jeté au sol." % label)

# 0.0.7.30 (demandes de l'utilisateur) : touches Jeter (J, au sol, Survie et Créatif) et Supprimer (D + E, Créatif) dans
# l'inventaire : l'objet tenu par la souris s'il y en a un, sinon celui de la case sous la souris ; rien sinon. Un seul
# objet (le dernier pris), ou tout le tas (all : Ctrl ; D + E : toujours tout). Jeter un objet illimité : une copie tombe, il reste.
func throw_key(all: bool = false, delete: bool = false) -> bool:
	if delete and inventory.mode != Inventory.CREATIVE:
		_say("En Survie, on ne supprime rien : J pour jeter au sol.")
		return false
	if not cursor_item.is_empty():
		if Inventory.unlimited(cursor_item):
			if delete:
				_discard(cursor_item, true)
				cursor_item = {}
				cursor_from = []
				_show_cursor()
			else:
				_discard(cursor_item.duplicate(true))
			return true
		var thrown: Dictionary
		if all or Inventory.count(cursor_item) <= 1:
			thrown = cursor_item
			cursor_item = {}
			cursor_from = []
		else:
			var parts: Array = Inventory._split(cursor_item, Inventory.count(cursor_item) - 1)
			cursor_item = parts[0]
			thrown = parts[1]
		_discard(thrown, delete)
		_show_cursor()
		return true
	var place := _place_under_mouse()
	if place.is_empty():
		return false
	var there: Dictionary = inventory.item(place[0], place[1])
	if Inventory.unlimited(there) and not delete:
		_discard(there.duplicate(true))
		return true
	var removed: Dictionary = inventory.remove(place[0], place[1], all)
	if removed.is_empty():
		return false
	_discard(removed, delete)
	return true

# Case de l'inventaire (pas un objet du haut ni une variante) sous la souris, avec un objet (any : vide aussi) :
# [zone, numéro] ou [].
func _place_under_mouse(any: bool = false) -> Array:
	var mouse := screen.get_global_mouse_position()
	var places := []
	for index in range(grid_slots.size()):
		places.append([grid_slots[index], "grid", index])
	for slots in [_creative_bar_slots, _survival_bar_slots]:
		for index in slots:
			places.append([slots[index], "bar", index])
	for place in places:
		var slot: Slot = place[0]
		if slot.is_visible_in_tree() and (any or not slot.item.is_empty()) and slot.get_global_rect().has_point(mouse):
			return [place[1], place[2]]
	return []

# Cases de l'écran d'inventaire (pas celles de la barre du jeu).
func _panel_slots() -> Array:
	var slots: Array = catalog_slots + grid_slots
	slots.append_array(_creative_bar_slots.values())
	slots.append_array(_survival_bar_slots.values())
	return slots

# « + » : Survie, sur tout objet porté (ses détails). 0.0.7.31 (demande de l'utilisateur : distinguer ce qu'on a de ce qui
# existe) : Créatif, objets du haut (top) : seulement s'ils ont des variantes ; objets qu'on a : toujours (leurs détails).
func _has_more(value: Dictionary, top: bool = false) -> bool:
	if value.is_empty() or inventory == null:
		return false
	if top and inventory.mode == Inventory.CREATIVE:
		return not Inventory.variants(value).is_empty()
	return true

func _toggle_more(slot: Slot, sticky := false) -> void:
	if more_slot == slot:
		_close_more()
	else:
		_open_more(slot, sticky)

func _close_more() -> void:
	for node in more_nodes:
		if is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.queue_free()
	more_nodes = []
	more_cards = []
	more_value = {}
	if is_instance_valid(more_slot):
		more_slot.opened = false
		more_slot.queue_redraw()
	more_slot = null
	more_sticky = false
	_fit_scroll.call_deferred()

# Ouvre les sous-possibilités sous la ligne de la case : une ligne complète (même pas remplie), le reste descend.
# sticky (D + T) : reste ouvert jusqu'à D + T ou Échap ; sinon, fermé dès que la souris quitte la case et ses lignes.
# value (0.0.7.31, D + T) : les détails de cet objet (tenu par la souris), montrés sous la case en main.
func _open_more(slot: Slot, sticky := false, value: Dictionary = {}) -> void:
	_close_more()
	if not is_instance_valid(slot):
		return
	var creative: bool = inventory.mode == Inventory.CREATIVE
	var top: bool = slot in catalog_slots
	if value.is_empty() and not _has_more(slot.item, top):
		return
	var subject: Dictionary = value if not value.is_empty() else slot.item
	# 0.0.7.30 : cartes de détails, Créatif aussi. 0.0.7.31 (demande de l'utilisateur) : Créatif, objets du haut : seulement
	# leurs variantes ; objets qu'on a : seulement leurs cartes.
	var cards := [] if creative and top else _detail_cards(subject, not value.is_empty())
	var entries := _more_entries(subject) if creative and top else []
	if cards.is_empty() and entries.is_empty():
		return
	more_slot = slot
	more_item = slot.item
	more_value = value
	slot.opened = true
	slot.queue_redraw()
	more_sticky = sticky
	more_frame = Engine.get_process_frames()
	var flow := _cards_flow(cards)
	var parent := slot.get_parent()
	if creative and parent is GridContainer:
		var columns: int = parent.columns
		var shown: Array = parent.get_children().filter(func(child): return child.visible)
		var at := shown.find(slot)
		var row_end := mini((at / columns + 1) * columns, shown.size())
		var insert_at: int = shown[row_end - 1].get_index() + 1
		var cells := []
		# Ligne de la case pas pleine (dernière ligne) : complétée par des vides, la suite commence à la ligne suivante.
		for missing in range((at / columns + 1) * columns - row_end):
			cells.append(_spacer(slot))
		# Une ligne de vides, de la hauteur des cartes, montrées par-dessus (une grille ne peut pas avoir de ligne entière).
		if not cards.is_empty():
			var card_row := []
			for column in range(columns):
				var spacer := _spacer(slot)
				spacer.custom_minimum_size.y = 0.0
				card_row.append(spacer)
			card_row[0].add_child(flow)
			more_cards = [flow, card_row]
			cells.append_array(card_row)
		else:
			flow.free()
		cells.append_array(entries)
		while cells.size() % columns != 0:
			cells.append(_spacer(slot))
		for index in range(cells.size()):
			parent.add_child(cells[index])
			parent.move_child(cells[index], insert_at + index)
		more_nodes = cells
		_sync_cards()
	else:
		var holder: Control = flow
		if not entries.is_empty():
			# Variantes hors d'une grille : dans leur propre zone qui défile (environ 3 lignes), sous les cartes s'il y en a.
			var grid := GridContainer.new()
			grid.columns = Inventory.COLUMNS
			grid.add_theme_constant_override("h_separation", GAP)
			grid.add_theme_constant_override("v_separation", GAP)
			for entry in entries:
				grid.add_child(entry)
			var scroll := ScrollContainer.new()
			scroll.name = "MoreScroll"
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			_style_scroll(scroll)
			scroll.add_child(grid)
			var rows := ceili(entries.size() / float(Inventory.COLUMNS))
			var line: float = slot.custom_minimum_size.y + GAP
			scroll.custom_minimum_size = Vector2(Inventory.COLUMNS * (slot.custom_minimum_size.x + GAP) + 18.0, minf(rows, 3.3) * line)
			if cards.is_empty():
				flow.free()
				holder = scroll
			else:
				holder = VBoxContainer.new()
				holder.add_theme_constant_override("separation", GAP)
				holder.add_child(flow)
				holder.add_child(scroll)
		holder.name = "MoreRow"
		var row := parent
		var container := row.get_parent()
		container.add_child(holder)
		container.move_child(holder, row.get_index() + 1)
		more_nodes = [holder]
	_fit_scroll.call_deferred()

# 0.0.7.30 : cartes côte à côte, à la ligne quand la place manque.
func _cards_flow(cards: Array) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.name = "Cards"
	flow.add_theme_constant_override("h_separation", GAP)
	flow.add_theme_constant_override("v_separation", GAP)
	for card in cards:
		flow.add_child(card)
	return flow

# Cartes montrées par-dessus une ligne de vides de la grille : la largeur de la grille, la hauteur des cartes.
var more_cards: Array = []
var more_item := {}
var more_value := {}

func _sync_cards() -> void:
	if more_cards.size() != 2 or not is_instance_valid(more_cards[0]):
		return
	var flow: Control = more_cards[0]
	var row: Array = more_cards[1]
	var grid: Control = row[0].get_parent()
	if grid == null:
		return
	if absf(flow.size.x - grid.size.x) > 0.5:
		flow.size.x = grid.size.x
	var height: float = flow.get_combined_minimum_size().y
	if absf(flow.size.y - height) > 0.5:
		flow.size.y = height
	if absf(row[0].custom_minimum_size.y - height) > 0.5:
		for spacer in row:
			spacer.custom_minimum_size.y = height
		_fit_scroll.call_deferred()

static func _spacer(slot: Control) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = slot.custom_minimum_size
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

# Créatif : une case par variante (prendre comme un objet du haut).
func _more_entries(value: Dictionary) -> Array:
	var side := roundf(PANEL_SLOT * minf(text_scale, 1.2))
	var result := []
	for variant in Inventory.variants(value):
		var slot := Slot.new(side, true, _text_px())
		slot.variant = true
		slot.show_item(variant)
		var label: Array = Inventory.variant_label(variant)
		slot.title = label[0]
		slot.note = label[1]
		slot.tooltip_text = "\n".join(Inventory.detail_lines(variant))
		slot.clicked.connect(_on_variant.bind(variant))
		result.append(slot)
	return result

# Cartes de détails. Survie : une carte par objet porté du même genre (mains et poches). 0.0.7.30 (demande de
# l'utilisateur) : Créatif : les objets de la case (un tas : une carte par objet, au plus CARDS_SHOWN, puis « … et N
# autres »), ou l'objet du haut lui-même.
const CARDS_SHOWN := 12

# only (0.0.7.31, objet tenu par la souris) : seulement cet objet, en Survie aussi.
func _detail_cards(value: Dictionary, only: bool = false) -> Array:
	var side := roundf(PANEL_SLOT * minf(text_scale, 1.2))
	var result := []
	var stacks := []
	if only or inventory.mode == Inventory.CREATIVE:
		stacks = [value]
	else:
		var kind := _kind_of(value)
		for index in Inventory.HANDS + Inventory.POCKETS:
			var there: Dictionary = inventory.item("bar", index)
			if not there.is_empty() and _kind_of(there) == kind:
				stacks.append(there)
	var hidden := 0
	for there in stacks:
		if there.has("pile"):
			for instance in there.pile:
				if inventory.mode == Inventory.CREATIVE and result.size() >= CARDS_SHOWN:
					hidden += 1
				else:
					result.append(_detail_card(Inventory.flat(there.objet, instance), 1, side))
		elif Inventory.unlimited(there):
			result.append(_detail_card(there, 1, side))
		else:
			result.append(_detail_card({"objet": there.objet}, Inventory.count(there), side))
	if hidden > 0:
		var more := _label("… et %d autres" % hidden, 12)
		more.name = "MoreCards"
		result.append(more)
	return result

# Genre pour les détails de Survie : tous les bois ensemble, tous les cailloux… sinon l'objet lui-même.
static func _kind_of(value: Dictionary) -> String:
	var form: String = Inventory.ITEMS.get(value.get("objet", ""), {}).get("forme", "")
	return form if not form.is_empty() else str(value.get("objet", ""))

func _detail_card(value: Dictionary, amount: int, side: float) -> Control:
	var card := PanelContainer.new()
	card.name = "DetailCard"
	# 0.0.7.30 (demande de l'utilisateur) : plus compactes : marges et image plus petites, le nom en haut, puis deux
	# détails par ligne (le poids toujours en dernier) ; tous les détails, un par ligne, au survol de la carte.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.22, 0.13, 0.92)
	style.border_color = Color(0.45, 0.8, 0.5, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(4)
	style.content_margin_left = 5
	style.content_margin_right = 7
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.add_child(_picture(ItemIcons.for_value(value), roundf(side * 0.6)))
	var lines: Array = Inventory.detail_lines(value)
	if amount > 1:
		lines.insert(1, "Nombre : %d" % amount)
	card.tooltip_text = "\n".join(lines)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var title := _label(lines[0], 12)
	title.name = "Title"
	title.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
	column.add_child(title)
	var details := GridContainer.new()
	details.name = "Details"
	details.columns = 2
	details.add_theme_constant_override("h_separation", 10)
	details.add_theme_constant_override("v_separation", 0)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(details)
	for line in lines.slice(1):
		details.add_child(_label(line, 11))
	return card

func _on_variant(button: int, value: Dictionary) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		var free: Array = inventory.first_free()
		if free.is_empty():
			_say("Plus de case libre.")
		else:
			inventory.put(free[0], free[1], value.duplicate(true))
		return
	cursor_item = value.duplicate(true)
	cursor_from = []
	_show_cursor()

# Sous-possibilités ouvertes au « + » : fermées dès que la souris quitte la case et ses lignes.
func _watch_more() -> void:
	if more_slot == null:
		return
	if not is_instance_valid(more_slot) or not more_slot.is_visible_in_tree() or (more_slot.item.is_empty() and more_value.is_empty()):
		_close_more()
		return
	_sync_cards()
	if more_sticky or Engine.get_process_frames() - more_frame < 3:
		return
	var area := more_slot.get_global_rect()
	for node in more_nodes:
		if is_instance_valid(node) and node is Control and node.is_visible_in_tree():
			area = area.merge(node.get_global_rect())
	if not area.grow(6.0).has_point(screen.get_global_mouse_position()):
		_close_more()

func _slot_under_mouse() -> Slot:
	var mouse := screen.get_global_mouse_position()
	for slot in _panel_slots():
		if slot.is_visible_in_tree() and not slot.item.is_empty() and slot.get_global_rect().has_point(mouse):
			return slot
	return null

# Détails (D + T, 0.0.7.30 ; D seul avant) : ouvre (ou ferme) les sous-possibilités de la case sous la souris ; Échap
# ferme d'abord ces sous-possibilités. Les combinaisons de deux touches arrivent comme des actions (key_combos.gd).
func _input(event: InputEvent) -> void:
	if not is_open():
		return
	# 0.0.7.31 : glisser l'objet tenu (bouton tenu) : les cases survolées sont choisies ; relâché : posé ou réparti.
	if drag_button != 0:
		if event is InputEventMouseMotion:
			_drag_over(_place_under_mouse(true))
		elif event is InputEventMouseButton and not event.pressed and event.button_index == drag_button:
			_drag_over(_place_under_mouse(true))
			_end_drag()
	if not (event is InputEventKey or event is InputEventAction) or not event.is_pressed() or event.is_echo():
		return
	# 0.0.7.30 (demandes de l'utilisateur) : Jeter (J) dans l'inventaire, en Survie et en Créatif ; Supprimer (D + E,
	# Créatif ; 0.0.7.31 : tout le tas).
	if event.is_action_pressed("throw"):
		throw_key(Controls.throw_all(event))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("delete_item"):
		throw_key(true, true)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.keycode == KEY_ESCAPE and more_slot != null:
		_close_more()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("show_details"):
		show_held_details()
		get_viewport().set_input_as_handled()

# 0.0.7.31 (demande de l'utilisateur) : Détails (D + T) : toujours l'objet en main : celui tenu par la souris s'il y en a
# un, sinon celui de la case en main ; D + T de nouveau (ou Échap) referme.
func show_held_details() -> void:
	if more_slot != null:
		_close_more()
		return
	var hand := _hand_slot()
	if hand == null:
		return
	if not cursor_item.is_empty():
		_open_more(hand, true, cursor_item)
	elif hand.item.is_empty():
		_say("Rien en main.")
	else:
		_open_more(hand, true)

# Case de l'écran d'inventaire de l'objet en main (objet lourd à deux mains : sa case).
func _hand_slot() -> Slot:
	var index: int = inventory.selected()
	var heavy: int = inventory.two_handed()
	if heavy >= 0 and index in Inventory.HANDS:
		index = heavy
	return _slot_for(["bar", index])
