extends CanvasLayer
# 0.0.8.16 (#208, demande de l'utilisateur) : écran du Carnet de route (O + C ; Échap ou O + C pour fermer). Un grand
# panneau bleu-violet (le style d'OrbMeka) sur le jeu assombri : à gauche, les commandes en cases (image, nom, touches,
# ✓ une fois faites) ; au milieu, les détails de la case choisie ; à droite, le chemin des premiers outils, de haut en bas,
# chaque étape cochée une fois faite. En bas : « Réinitialiser » (deux clics : on confirme) et « Fermer ».
# Données et coches : carnet.gd ; images : menu_images.gd et item_icons.gd.
const Carnet = preload("res://scripts/carnet.gd")
const MenuImages = preload("res://scripts/menu_images.gd")
const ItemIcons = preload("res://scripts/item_icons.gd")

signal closed

const DONE_COLOR := Color(0.55, 0.9, 0.5)
const TODO_COLOR := Color(0.62, 0.6, 0.72)
const GOLD := Color(1.0, 0.86, 0.55)

var notebook: Carnet
var text_scale := 1.0
var root: Control
var case_buttons := {}
var step_marks := {}
var step_labels := {}
var detail_title: Label
var detail_keys: Label
var detail_text: Label
var detail_image: TextureRect
var reset_button: Button
var chosen := "deplacer"
var _confirming := false

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
		margin.add_theme_constant_override(side, roundi(36 * text_scale))
	root.add_child(margin)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.23, 0.96)
	style.border_color = Color(0.62, 0.55, 1.0, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(roundf(18 * text_scale))
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", roundi(12 * text_scale))
	panel.add_child(page)
	var title := _label("Carnet de route", 28, GOLD)
	page.add_child(title)
	page.add_child(_label("Les commandes du jeu (un clic : les détails) et le chemin pour fabriquer ses premiers outils. Ce qui est fait se coche tout seul.", 14, Color(0.85, 0.84, 0.92)))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", roundi(16 * text_scale))
	page.add_child(body)
	_build_cases(body)
	_build_details(body)
	_build_steps(body)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", roundi(12 * text_scale))
	page.add_child(footer)
	reset_button = _button("Réinitialiser", footer, _on_reset)
	reset_button.tooltip_text = "Tout décocher pour recommencer le chemin"
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(space)
	_button("Fermer (Échap ou O + C)", footer, func(): closed.emit())
	notebook.changed.connect(func(_id): refresh())
	visible = false

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

func _column(parent: Node, heading: String, ratio: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = ratio
	column.add_theme_constant_override("separation", roundi(8 * text_scale))
	parent.add_child(column)
	column.add_child(_label(heading, 18, Color(0.6, 0.85, 0.82)))
	return column

func _scroll(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", roundi(4 * text_scale))
	scroll.add_child(list)
	return list

static func picture(image: String) -> Texture2D:
	var parts := image.split(":")
	if parts.size() != 2:
		return null
	return MenuImages.texture(parts[1]) if parts[0] == "menu" else ItemIcons.texture(parts[1])

func _build_cases(body: HBoxContainer) -> void:
	var list := _scroll(_column(body, "Commandes", 1.0))
	for entry: Dictionary in Carnet.CASES:
		var button := Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		button.custom_minimum_size = Vector2(0, roundf(50 * text_scale))
		button.add_theme_constant_override("icon_max_width", roundi(42 * text_scale))
		button.add_theme_font_size_override("font_size", roundi(14 * text_scale))
		button.pressed.connect(choose.bind(entry.id))
		list.add_child(button)
		case_buttons[entry.id] = button

func _build_details(body: HBoxContainer) -> void:
	var column := _column(body, "Détails", 1.3)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.14, 0.32, 0.9)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(roundf(16 * text_scale))
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(card)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", roundi(10 * text_scale))
	card.add_child(inside)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", roundi(12 * text_scale))
	inside.add_child(top)
	detail_image = TextureRect.new()
	detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	detail_image.custom_minimum_size = Vector2.ONE * roundf(96 * text_scale)
	top.add_child(detail_image)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	detail_title = _label("", 22, GOLD)
	names.add_child(detail_title)
	detail_keys = _label("", 16, Color(0.75, 0.85, 1.0))
	names.add_child(detail_keys)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inside.add_child(scroll)
	detail_text = _label("", 15)
	detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(detail_text)

func _build_steps(body: HBoxContainer) -> void:
	var list := _scroll(_column(body, "Chemin : premiers outils", 1.1))
	for index in range(Carnet.STEPS.size()):
		var step: Dictionary = Carnet.STEPS[index]
		if index > 0:
			var arrow := _label("↓", 12, Color(0.62, 0.55, 1.0))
			arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			arrow.custom_minimum_size = Vector2(roundf(76 * text_scale), 0)
			arrow.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			list.add_child(arrow)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", roundi(10 * text_scale))
		list.add_child(row)
		# La coche d'abord (à droite, la barre de défilement la cachait).
		var mark := _label("○", 20, TODO_COLOR)
		mark.custom_minimum_size = Vector2(roundf(22 * text_scale), 0)
		row.add_child(mark)
		step_marks[step.id] = mark
		var icon := TextureRect.new()
		icon.texture = picture(step.image)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.custom_minimum_size = Vector2.ONE * roundf(40 * text_scale)
		row.add_child(icon)
		var text := _label("%d. %s" % [index + 1, step.nom], 14)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		step_labels[step.id] = text

# Une case choisie : ses détails au milieu.
func choose(id: String) -> void:
	chosen = id
	for key in case_buttons:
		case_buttons[key].set_pressed_no_signal(key == id)
	for entry: Dictionary in Carnet.CASES:
		if entry.id == id:
			detail_title.text = ("✓ " if notebook.is_done(id) else "") + entry.nom
			detail_keys.text = entry.touches
			detail_text.text = entry.details
			detail_image.texture = picture(entry.image)

func refresh() -> void:
	for entry: Dictionary in Carnet.CASES:
		var button: Button = case_buttons[entry.id]
		var finished := notebook.is_done(entry.id)
		button.text = "%s%s\n%s" % ["✓ " if finished else "", entry.nom, entry.touches]
		button.icon = picture(entry.image)
		button.add_theme_color_override("font_color", DONE_COLOR if finished else Color(0.95, 0.95, 0.92))
	for step: Dictionary in Carnet.STEPS:
		var finished := notebook.is_done(step.id)
		step_marks[step.id].text = "✓" if finished else "○"
		step_marks[step.id].add_theme_color_override("font_color", DONE_COLOR if finished else TODO_COLOR)
		step_labels[step.id].add_theme_color_override("font_color", DONE_COLOR if finished else Color(0.95, 0.95, 0.92))
	choose(chosen)

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
	reset_button.text = "Réinitialiser"
	refresh()
	visible = true

func close() -> void:
	visible = false

func is_open() -> bool:
	return visible
