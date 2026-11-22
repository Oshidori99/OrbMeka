extends CanvasLayer
# 0.0.8.16 (#208, demande de l'utilisateur) : écran du Carnet de route (O + C ; Échap ou O + C pour fermer).
# 0.0.8.19 (demande de l'utilisateur) : en arbre. Un plan (carnet.gd NODES) : la case « Départ » au centre, et trois branches
# de cases (image, deux ou trois mots dessous) reliées par des lignes : à gauche les commandes, en haut ce qu'on récupère, à
# droite ce qu'on fabrique ; plus c'est avancé, plus c'est loin du centre. Aspect propre à OrbMeka : bleu-violet, cases
# arrondies, lignes douces, départ au centre. Les cases faites : bord vert et ✓ ; celles qu'on ne peut pas encore faire
# (celle d'avant n'est pas faite) : plus pâles. Un clic sur une case : ses détails, à droite. On déplace la vue en glissant
# avec la souris (n'importe quel bouton), la molette rapproche ou éloigne. En bas : « Réinitialiser » (deux clics) et
# « Fermer ».
const Carnet = preload("res://scripts/carnet.gd")
const MenuImages = preload("res://scripts/menu_images.gd")
const ItemIcons = preload("res://scripts/item_icons.gd")

signal closed

const DONE_COLOR := Color(0.55, 0.9, 0.5)
const GOLD := Color(1.0, 0.86, 0.55)
const LINE_COLOR := Color(0.62, 0.55, 1.0, 0.65)
const TILE := 88.0
const SPACING := Vector2(124.0, 116.0)
# Assez grand pour lire les cases ; ce qui dépasse se voit en glissant.
const ZOOM_MIN := 0.62
const ZOOM_MAX := 1.4

var notebook: Carnet
var text_scale := 1.0
var root: Control
var view: Control
var plan: Control
var tiles := {}
var marks := {}
var detail_title: Label
var detail_keys: Label
var detail_state: Label
var detail_text: Label
var detail_image: TextureRect
var reset_button: Button
var chosen := "depart"
var zoom := 1.0
var _confirming := false
var _dragging := false
var _origin := Vector2.ZERO

func setup(book: Carnet, scale: float) -> void:
	notebook = book
	text_scale = scale
	name = "CarnetDeRoute"
	# Au-dessus de tout le jeu (textes F1, F3…), sous le message « qualité conseillée » (30).
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var veil := ColorRect.new()
	veil.color = Color(0.05, 0.04, 0.1, 0.62)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(veil)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, roundi(30 * text_scale))
	root.add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.12, 0.1, 0.23, 0.96), Color(0.62, 0.55, 1.0, 0.5), 14, 16))
	margin.add_child(panel)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", roundi(10 * text_scale))
	panel.add_child(page)
	page.add_child(_label("Carnet de route", 28, GOLD))
	page.add_child(_label("À gauche les commandes, en haut ce qu'on récupère, à droite ce qu'on fabrique : du plus facile (près du centre) au plus difficile. Un clic : les détails. Glisser : déplacer ; molette : rapprocher.", 14, Color(0.85, 0.84, 0.92)))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", roundi(14 * text_scale))
	page.add_child(body)
	_build_view(body)
	_build_details(body)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", roundi(12 * text_scale))
	page.add_child(footer)
	reset_button = _button("Réinitialiser", footer, _on_reset)
	reset_button.tooltip_text = "Tout décocher pour recommencer"
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(space)
	_button("Fermer (Échap ou O + C)", footer, func(): closed.emit())
	notebook.changed.connect(func(_id): refresh())
	visible = false

func _box(color: Color, border: Color, radius: int, padding: float, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(roundf(padding * text_scale))
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
	made.focus_mode = Control.FOCUS_NONE
	made.pressed.connect(pressed)
	parent.add_child(made)
	return made

static func picture(image: String) -> Texture2D:
	var parts := image.split(":")
	if parts.size() != 2:
		return null
	return MenuImages.texture(parts[1]) if parts[0] == "menu" else ItemIcons.texture(parts[1])

# Centre d'une case dans le plan (le Départ en (0, 0)).
func center_of(id: String) -> Vector2:
	return Carnet.place_of(Carnet.node(id)) * SPACING * text_scale

func _build_view(body: HBoxContainer) -> void:
	view = Panel.new()
	view.add_theme_stylebox_override("panel", _box(Color(0.09, 0.075, 0.18, 0.9), Color(0.62, 0.55, 1.0, 0.25), 12, 0, 1))
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_stretch_ratio = 3.2
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.gui_input.connect(_on_view_input)
	view.resized.connect(fit)
	body.add_child(view)
	plan = Control.new()
	plan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plan.draw.connect(_draw_lines)
	view.add_child(plan)
	# Noms des branches, au-delà de leur première case.
	for branch: String in Carnet.BRANCHES:
		var label := _label(Carnet.BRANCH_NAMES[branch], 15, Color(0.6, 0.85, 0.82))
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var first: Vector2 = {"gauche": Vector2(-1, 0), "haut": Vector2(0, -1), "droite": Vector2(1, 0)}[branch] * SPACING * text_scale
		var shift: Vector2 = {"gauche": Vector2(-40, -TILE * 0.5 - 34), "haut": Vector2(TILE * 0.5 + 10, -12), "droite": Vector2(-40, -TILE * 0.5 - 34)}[branch] * text_scale
		label.position = first + shift
		plan.add_child(label)
	for entry: Dictionary in Carnet.NODES:
		var tile := Button.new()
		tile.name = "Case_" + entry.id
		tile.focus_mode = Control.FOCUS_NONE
		tile.text = entry.nom
		tile.icon = picture(entry.image)
		tile.expand_icon = true
		tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		tile.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tile.add_theme_font_size_override("font_size", roundi(14 * text_scale))
		# Toutes les cases de la même taille (le nom passe à la ligne s'il le faut).
		tile.clip_text = true
		tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tile.custom_minimum_size = Vector2(TILE, TILE + 18.0) * text_scale
		tile.add_theme_constant_override("icon_max_width", roundi(TILE * 0.62 * text_scale))
		tile.size = Vector2(TILE, TILE + 18.0) * text_scale
		tile.position = center_of(entry.id) - tile.size * 0.5
		tile.tooltip_text = "%s · %s" % [entry.nom, entry.touches]
		tile.pressed.connect(choose.bind(entry.id))
		plan.add_child(tile)
		tiles[entry.id] = tile
		var mark := _label("✓", 18, DONE_COLOR)
		mark.autowrap_mode = TextServer.AUTOWRAP_OFF
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.position = Vector2(tile.size.x - 22.0 * text_scale, 0.0)
		tile.add_child(mark)
		marks[entry.id] = mark

# Lignes entre chaque case et celle d'avant (courbes pour les embranchements) ; vertes une fois les deux faites.
func _draw_lines() -> void:
	for entry: Dictionary in Carnet.NODES:
		var parent: String = entry.get("parent", "")
		if parent.is_empty():
			continue
		var from := center_of(parent)
		var to := center_of(entry.id)
		var finished := notebook.is_done(entry.id) and notebook.is_done(parent)
		var color := Color(DONE_COLOR.r, DONE_COLOR.g, DONE_COLOR.b, 0.8) if finished else LINE_COLOR
		var points := PackedVector2Array()
		# Embranchement (la hache et la pioche, au bout à droite) : la ligne avance puis s'écarte.
		var bend := Vector2((to.x + from.x) * 0.5, from.y) if absf(to.y - from.y) > 1.0 and absf(to.x - from.x) > 1.0 else (from + to) * 0.5
		for step in range(17):
			var t := step / 16.0
			points.append(from.lerp(bend, t).lerp(bend.lerp(to, t), t))
		plan.draw_polyline(points, color, 4.0 * text_scale, true)

func _build_details(body: HBoxContainer) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color(0.17, 0.14, 0.32, 0.9), Color(0.62, 0.55, 1.0, 0.0), 10, 16, 0))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.0
	body.add_child(card)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", roundi(8 * text_scale))
	card.add_child(inside)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", roundi(12 * text_scale))
	inside.add_child(top)
	detail_image = TextureRect.new()
	detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	detail_image.custom_minimum_size = Vector2.ONE * roundf(84 * text_scale)
	top.add_child(detail_image)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	detail_title = _label("", 22, GOLD)
	names.add_child(detail_title)
	detail_keys = _label("", 15, Color(0.75, 0.85, 1.0))
	names.add_child(detail_keys)
	detail_state = _label("", 14, DONE_COLOR)
	inside.add_child(detail_state)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inside.add_child(scroll)
	detail_text = _label("", 14)
	detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(detail_text)

# Une case choisie : ses détails à droite.
func choose(id: String) -> void:
	var entry := Carnet.node(id)
	if entry.is_empty():
		return
	chosen = id
	detail_title.text = entry.nom
	detail_keys.text = entry.touches
	detail_text.text = entry.details
	detail_image.texture = picture(entry.image)
	if notebook.is_done(id):
		detail_state.text = "✓ Fait" if id != "depart" else "Le début de tout"
		detail_state.add_theme_color_override("font_color", DONE_COLOR)
	elif notebook.is_open(id):
		detail_state.text = "À faire maintenant"
		detail_state.add_theme_color_override("font_color", GOLD)
	else:
		detail_state.text = "Plus tard : d'abord « %s »" % Carnet.name_of(entry.parent)
		detail_state.add_theme_color_override("font_color", Color(0.75, 0.72, 0.85))
	_style_tiles()

func _style_tiles() -> void:
	for entry: Dictionary in Carnet.NODES:
		var tile: Button = tiles[entry.id]
		var finished := notebook.is_done(entry.id)
		var border := GOLD if entry.id == chosen else (DONE_COLOR if finished else Color(0.62, 0.55, 1.0, 0.55))
		var fill := Color(0.2, 0.17, 0.38, 0.97) if entry.id != "depart" else Color(0.26, 0.2, 0.44, 0.97)
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := _box(fill.lightened(0.08) if state == "hover" else fill, border, 14, 6, 3 if entry.id == chosen else 2)
			tile.add_theme_stylebox_override(state, style)
		tile.add_theme_color_override("font_color", DONE_COLOR if finished and entry.id != "depart" else Color(0.95, 0.95, 0.92))
		tile.modulate = Color.WHITE if finished or notebook.is_open(entry.id) else Color(1.0, 1.0, 1.0, 0.5)
		marks[entry.id].visible = finished and entry.id != "depart"
	plan.queue_redraw()

func refresh() -> void:
	choose(chosen)

# Tout le plan dans la vue, centré sur le Départ (pas plus grand que 100 %).
func fit() -> void:
	if view == null or view.size.x <= 0.0:
		return
	var low := Vector2.ZERO
	var high := Vector2.ZERO
	for entry: Dictionary in Carnet.NODES:
		low = low.min(center_of(entry.id))
		high = high.max(center_of(entry.id))
	var span := (high - low) + Vector2(TILE * 1.6, TILE * 2.0) * text_scale
	zoom = clampf(minf(view.size.x / span.x, view.size.y / span.y), ZOOM_MIN, 1.0)
	plan.scale = Vector2.ONE * zoom
	# Le Départ au milieu de la largeur ; en hauteur, tout le plan (la branche du haut est longue).
	plan.position = Vector2(view.size.x * 0.5, view.size.y * 0.5 - (low.y + high.y) * 0.5 * zoom)

func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			zoom_at(event.position, 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12)
			view.accept_event()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = event.pressed
			_origin = event.position
	elif event is InputEventMouseMotion and _dragging:
		plan.position += event.position - _origin
		_origin = event.position

# Rapprocher (factor > 1) ou éloigner, autour d'un point de la vue.
func zoom_at(point: Vector2, factor: float) -> void:
	var new_zoom := clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var anchor := (point - plan.position) / zoom
	zoom = new_zoom
	plan.scale = Vector2.ONE * zoom
	plan.position = point - anchor * zoom

func _on_reset() -> void:
	if not _confirming:
		_confirming = true
		reset_button.text = "Vraiment tout recommencer ? (cliquer encore)"
		return
	_confirming = false
	reset_button.text = "Réinitialiser"
	notebook.reset()

func open() -> void:
	_confirming = false
	_dragging = false
	reset_button.text = "Réinitialiser"
	visible = true
	refresh()
	fit.call_deferred()

func close() -> void:
	visible = false

func is_open() -> bool:
	return visible
